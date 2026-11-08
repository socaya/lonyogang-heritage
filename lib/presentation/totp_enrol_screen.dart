import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../data/credentials_store.dart';
import 'components.dart';
import 'widgets.dart';

/// Minimal TOTP-seed enrolment screen. Calls the backend's
/// `POST /identity/totp` endpoint, shows the Base32 seed and the
/// otpauth:// URL so the user can either type the seed into their
/// authenticator app or paste the URL into a QR scanner that accepts raw
/// strings. The server already sealed the seed under the KMS envelope by
/// the time the response lands.
class TotpEnrolScreen extends StatefulWidget {
  final Uri baseUri;
  final CredentialsStore credentials;
  const TotpEnrolScreen({
    super.key,
    required this.baseUri,
    required this.credentials,
  });
  @override
  State<TotpEnrolScreen> createState() => _TotpEnrolScreenState();
}

class _TotpEnrolScreenState extends State<TotpEnrolScreen> {
  // Match the remote_sync + attachment_syncer posture so a hung backend
  // can't block this screen indefinitely.
  static const Duration _deadline = Duration(seconds: 20);
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  String? _secret;
  String? _otpauthUrl;
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _http.close(force: true);
    super.dispose();
  }

  Future<void> _enrol() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final creds = await widget.credentials.load();
      if (creds == null) throw StateError('Not signed in');
      final uri = widget.baseUri.resolve('/identity/totp');
      final req = await _http.postUrl(uri);
      req.headers.set('authorization', 'Bearer ${creds.accessToken}');
      req.headers.contentType = ContentType.json;
      final res = await req.close().timeout(_deadline);
      final body = await res.transform(utf8.decoder).join().timeout(_deadline);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('HTTP ${res.statusCode}: $body', uri: uri);
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      setState(() {
        _secret = decoded['secret'] as String;
        _otpauthUrl = decoded['otpauthUrl'] as String;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          Text('Enrol a TOTP second factor',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'Set up a time-based one-time passcode (TOTP) so the next sign-in needs both your password and a six-digit code from your authenticator app.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 22),
          if (_secret == null)
            PrimaryCTA(
              label: _working ? 'Generating…' : 'Generate TOTP seed',
              loading: _working,
              showArrow: false,
              onPressed: _enrol,
            )
          else ...[
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BASE32 SEED',
                    style: TextStyle(
                        color: LG.sage,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SelectableText(_secret!,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    onPressed: () => _copy('Seed', _secret!),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy seed')),
              ]),
            ),
            const SizedBox(height: 12),
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('OTPAUTH URL',
                    style: TextStyle(
                        color: LG.sage,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SelectableText(_otpauthUrl!,
                    style: const TextStyle(fontSize: 12, color: LG.muted)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    onPressed: () => _copy('otpauth URL', _otpauthUrl!),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy otpauth URL')),
              ]),
            ),
            const SizedBox(height: 18),
            const SecurityNotice(
              title: 'TOTP is a shared secret',
              message:
                  'Give the seed to exactly one authenticator app (Aegis, 1Password, Google Authenticator). If you lose that device, run this enrolment again from a signed-in session to issue a new seed.',
              icon: Icons.verified_user_outlined,
            ),
            const SizedBox(height: 14),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done', style: TextStyle(color: LG.muted))),
          ],
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 10),
          Text('Remove TOTP',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'If you still hold the authenticator app, you can take the second factor off. The server demands a current code so a stolen session cannot do this.',
            style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _working ? null : _disable,
            icon: const Icon(Icons.remove_moderator_outlined),
            label: const Text('Remove TOTP…'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: LG.negative, fontSize: 12)),
          ],
        ],
      );

  Future<void> _disable() async {
    final code = await _promptCode();
    if (code == null || code.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final creds = await widget.credentials.load();
      if (creds == null) throw StateError('Not signed in');
      final uri = widget.baseUri.resolve('/identity/totp');
      final req = await _http.openUrl('DELETE', uri);
      req.headers.set('authorization', 'Bearer ${creds.accessToken}');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'code': code}));
      final res = await req.close().timeout(_deadline);
      final body =
          await res.transform(utf8.decoder).join().timeout(_deadline);
      if (res.statusCode == 401) {
        throw const HttpException('TOTP code did not match.');
      }
      if (res.statusCode != 204 && res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}: $body', uri: uri);
      }
      if (!mounted) return;
      setState(() {
        _secret = null;
        _otpauthUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('TOTP removed. Sign-in no longer requires a code.')));
    } catch (err) {
      setState(() => _error = '$err');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _promptCode() async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Current TOTP code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '6-digit code'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Remove')),
        ],
      ),
    );
  }
}

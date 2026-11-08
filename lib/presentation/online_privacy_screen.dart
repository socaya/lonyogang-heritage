import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../data/credentials_store.dart';
import '../data/remote_sync.dart';
import 'components.dart';
import 'online_scope.dart';
import 'sessions_screen.dart';
import 'totp_enrol_screen.dart';
import 'widgets.dart';

/// Lets a signed-in user exercise their Uganda DPPA 2019 data-subject
/// rights directly from the device — view the current profile, download
/// a portable export, and request erasure of the account. All calls go
/// through the authenticated backend using the saved
/// [RemoteSyncCredentials].
class OnlinePrivacyScreen extends StatefulWidget {
  final Uri baseUri;
  final CredentialsStore credentials;
  const OnlinePrivacyScreen({
    super.key,
    required this.baseUri,
    required this.credentials,
  });
  @override
  State<OnlinePrivacyScreen> createState() => _OnlinePrivacyScreenState();
}

class _OnlinePrivacyScreenState extends State<OnlinePrivacyScreen> {
  final _http = HttpClient();
  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _http.close(force: true);
    super.dispose();
  }

  Future<RemoteSyncCredentials?> _creds() async {
    final creds = await widget.credentials.load();
    if (creds == null) setState(() => _error = 'Not signed in');
    return creds;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final creds = await _creds();
      if (creds == null) return;
      final uri = widget.baseUri.resolve('/me');
      final req = await _http.getUrl(uri);
      req.headers.set('authorization', 'Bearer ${creds.accessToken}');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}: $body', uri: uri);
      }
      setState(() => _profile = jsonDecode(body) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final creds = await _creds();
      if (creds == null) return;
      final uri = widget.baseUri.resolve('/me/export');
      final req = await _http.getUrl(uri);
      req.headers.set('authorization', 'Bearer ${creds.accessToken}');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}: $body', uri: uri);
      }
      await Clipboard.setData(ClipboardData(text: body));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'DSAR export copied to clipboard. Save it somewhere safe before wiping the device.')));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _erase() async {
    final password = await _promptPassword();
    if (password == null || password.isEmpty) return;
    final confirmed = await confirmActionSheet(
      context,
      title: 'Erase online account?',
      consequence:
          'The server account is tombstoned and every encrypted event, attachment and session is deleted. The device remains unchanged — your local vault is still there until you reset it from Settings. This cannot be undone.',
      confirmLabel: 'Erase account',
    );
    if (!confirmed) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final creds = await _creds();
      if (creds == null) return;
      final uri = widget.baseUri.resolve('/me');
      final req = await _http.deleteUrl(uri);
      req.headers.set('authorization', 'Bearer ${creds.accessToken}');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'password': password}));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 401) {
        throw const HttpException('Re-authentication failed. Check the password.');
      }
      if (res.statusCode != 204 && res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}: $body', uri: uri);
      }
      await widget.credentials.clear();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Online account erased. Credentials cleared on device.')));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Ask for the current online password before firing a destructive call
  /// like DELETE /me — the server enforces this too, but asking up-front
  /// keeps the UX honest.
  Future<String?> _promptPassword() async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm with your online password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Continue')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          Text('Online privacy',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'Exercise your Uganda DPPA 2019 data-subject rights. All calls go through your authenticated session; the server keeps a Merkle-chained audit entry for every action.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 22),
          if (_loading)
            const LoadingState(message: 'Fetching profile')
          else if (_profile != null)
            SoftCard(
              child: Column(children: [
                InfoLabel(label: 'Email', value: '${_profile!['email']}'),
                InfoLabel(
                    label: 'Phone',
                    value: _profile!['phone']?.toString() ?? '—'),
                InfoLabel(
                    label: 'Display name',
                    value: _profile!['displayName']?.toString() ?? '—'),
                InfoLabel(
                    label: 'Status',
                    value: '${_profile!['status']}',
                    valueColor: _profile!['status'] == 'active' ? LG.sage : LG.negative),
                InfoLabel(
                    label: 'Verified',
                    value: _profile!['verifiedAt'] ?? 'Pending'),
                InfoLabel(
                    label: 'Marketing consent',
                    value: _profile!['marketingConsentAt'] ?? 'Not granted'),
              ]),
            )
          else if (_error != null)
            ErrorState(
              message: _error!,
              onRetry: _load,
            ),
          const SizedBox(height: 20),
          PrimaryCTA(
            label: _working ? 'Working…' : 'Download DSAR export',
            loading: _working,
            showArrow: false,
            onPressed: _profile == null ? null : _export,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _profile == null || _working
                ? null
                : () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => TotpEnrolScreen(
                              baseUri: widget.baseUri,
                              credentials: widget.credentials,
                            )));
                  },
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Enrol TOTP second factor'),
          ),
          const SizedBox(height: 10),
          Builder(builder: (context) {
            final remote = OnlineScope.maybeOf(context)?.sync;
            if (remote == null) return const SizedBox.shrink();
            return Column(children: [
              OutlinedButton.icon(
                onPressed: _profile == null || _working
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => SessionsScreen(sync: remote))),
                icon: const Icon(Icons.devices_other),
                label: const Text('Active sessions'),
              ),
              const SizedBox(height: 10),
            ]);
          }),
          OutlinedButton.icon(
            onPressed: _profile == null || _working ? null : _erase,
            icon: const Icon(Icons.delete_forever, color: LG.negative),
            label: const Text('Erase online account',
                style: TextStyle(color: LG.negative)),
          ),
          const SizedBox(height: 18),
          const SecurityNotice(
            title: 'Keep a copy',
            message:
                'The DSAR export is handed to the clipboard as JSON. Paste it into a safe place before you erase the account or reset the device.',
            icon: Icons.copy_outlined,
          ),
        ],
      );
}

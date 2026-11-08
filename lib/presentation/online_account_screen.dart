import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../data/credentials_store.dart';
import '../data/remote_sync.dart';
import 'components.dart';
import 'widgets.dart';

/// Real online account onboarding — sign-up, OTP verification and sign-in
/// against the backend documented in docs/ONLINE_SERVICE_PLAN.md. Reachable
/// only when the client has been built with a `LONYOGANG_BACKEND_URL` and
/// a [RemoteSyncService] wired into [main.dart].
class OnlineAccountScreen extends StatefulWidget {
  final RemoteSyncService sync;
  final CredentialsStore credentials;
  const OnlineAccountScreen({super.key, required this.sync, required this.credentials});
  @override
  State<OnlineAccountScreen> createState() => _OnlineAccountScreenState();
}

enum _Stage { form, verify, done }

class _OnlineAccountScreenState extends State<OnlineAccountScreen> {
  _Stage _stage = _Stage.form;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _displayName = TextEditingController();
  String _composedPhone = '+256 ';
  bool _busy = false;
  String? _error;
  String? _accountId;
  final _emailCode = TextEditingController();
  final _phoneCode = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _displayName.dispose();
    _emailCode.dispose();
    _phoneCode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await widget.sync.signUp(
        email: _email.text.trim(),
        password: _password.text,
        phone: _composedPhone.trim().isEmpty ? null : _composedPhone.trim(),
        displayName:
            _displayName.text.trim().isEmpty ? null : _displayName.text.trim(),
      );
      setState(() {
        _stage = _Stage.verify;
        _accountId = account.accountId;
        if (account.emailCode != null) _emailCode.text = account.emailCode!;
        if (account.phoneCode != null) _phoneCode.text = account.phoneCode!;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final accountId = _accountId;
    if (accountId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.sync.verify(
        accountId: accountId,
        channel: 'email',
        code: _emailCode.text.trim(),
      );
      if (_composedPhone.trim().length > 4 && _phoneCode.text.trim().isNotEmpty) {
        await widget.sync.verify(
          accountId: accountId,
          channel: 'phone',
          code: _phoneCode.text.trim(),
        );
      }
      final deviceId = DateTime.now().microsecondsSinceEpoch.toRadixString(16)
          .padLeft(32, '0')
          .substring(0, 32);
      final deviceUuid =
          '${deviceId.substring(0, 8)}-${deviceId.substring(8, 12)}-${deviceId.substring(12, 16)}-${deviceId.substring(16, 20)}-${deviceId.substring(20, 32)}';
      await widget.sync.signIn(
        email: _email.text.trim(),
        password: _password.text,
        deviceId: deviceUuid,
      );
      setState(() => _stage = _Stage.done);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          const Center(child: BrandMark(height: 32)),
          const SizedBox(height: 28),
          Text(_stage == _Stage.form ? 'Create online account' : 'Verify your identity',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'Create a server-backed account so your encrypted portfolio can sync between devices.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          if (_stage == _Stage.form) ..._formStage(context),
          if (_stage == _Stage.verify) ..._verifyStage(context),
          if (_stage == _Stage.done)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(children: [
                  Icon(Icons.check_circle, color: LG.sage, size: 48),
                  SizedBox(height: 12),
                  Text('Signed in. Your device is syncing.',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: LG.negative, fontSize: 12)),
          ],
          const SizedBox(height: 18),
          const SecurityNotice(
            title: 'Encrypted on this device',
            message:
                'Your portfolio is AES-GCM encrypted before any event is uploaded. The server only sees ciphertext and a few plaintext integrity assertions (e.g. beneficiary cap).',
          ),
        ],
      );

  List<Widget> _formStage(BuildContext context) => [
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(children: [
            FormFieldBlock(
              title: 'Email',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                decoration: const InputDecoration(hintText: 'you@example.com'),
                validator: (v) => isLikelyEmail(v ?? '') ? null : 'Enter a valid email',
              ),
            ),
            FormFieldBlock(
              title: 'Password',
              help: 'At least 10 characters.',
              child: TextFormField(
                controller: _password,
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 10) ? 'At least 10 characters' : null,
              ),
            ),
            FormFieldBlock(
              title: 'Mobile number (optional)',
              child: PhoneField(
                controller: _phone,
                onChanged: (composed) => _composedPhone = composed,
              ),
            ),
            FormFieldBlock(
              title: 'Display name (optional)',
              child: TextFormField(
                controller: _displayName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Your name as shown in-app'),
              ),
            ),
          ]),
        ),
        PrimaryCTA(
          label: _busy ? 'Creating…' : 'Create account',
          loading: _busy,
          onPressed: _signUp,
        ),
      ];

  List<Widget> _verifyStage(BuildContext context) => [
        FormFieldBlock(
          title: 'Email verification code',
          help: 'Check your inbox for the six-digit code.',
          child: TextFormField(
            controller: _emailCode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
          ),
        ),
        _ResendButton(
          channel: 'email',
          onPressed: _busy ? null : () => _resend('email'),
          cooldown: _emailResendCooldown,
        ),
        if (_composedPhone.trim().length > 4) ...[
          FormFieldBlock(
            title: 'SMS verification code',
            help: 'Enter the code we texted to your phone.',
            child: TextFormField(
              controller: _phoneCode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
            ),
          ),
          _ResendButton(
            channel: 'phone',
            onPressed: _busy ? null : () => _resend('phone'),
            cooldown: _phoneResendCooldown,
          ),
        ],
        PrimaryCTA(
          label: _busy ? 'Verifying…' : 'Verify and sign in',
          loading: _busy,
          onPressed: _verify,
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _stage = _Stage.form),
          child: const Text('Back', style: TextStyle(color: LG.muted)),
        ),
      ];

  Future<void> _resend(String channel) async {
    final accountId = _accountId;
    if (accountId == null) return;
    try {
      await widget.sync.resendOtp(accountId: accountId, channel: channel);
      _startCooldown(channel);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('New $channel code dispatched. Check your inbox.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  int _emailResendCooldown = 0;
  int _phoneResendCooldown = 0;
  Timer? _resendTimer;

  void _startCooldown(String channel) {
    setState(() {
      if (channel == 'email') _emailResendCooldown = 60;
      if (channel == 'phone') _phoneResendCooldown = 60;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_emailResendCooldown > 0) _emailResendCooldown--;
        if (_phoneResendCooldown > 0) _phoneResendCooldown--;
      });
      if (_emailResendCooldown == 0 && _phoneResendCooldown == 0) t.cancel();
    });
  }
}

class _ResendButton extends StatelessWidget {
  final String channel;
  final VoidCallback? onPressed;
  final int cooldown;
  const _ResendButton({
    required this.channel,
    required this.onPressed,
    required this.cooldown,
  });
  @override
  Widget build(BuildContext context) {
    final blocked = cooldown > 0;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: blocked ? null : onPressed,
        child: Text(
          blocked
              ? 'Resend $channel in $cooldown s'
              : 'Resend $channel code',
          style: const TextStyle(color: LG.muted),
        ),
      ),
    );
  }
}

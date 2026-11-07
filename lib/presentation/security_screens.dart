import 'package:flutter/material.dart';

import '../core/design.dart';
import '../data/biometric.dart';
import '../data/portfolio_store.dart';
import 'widgets.dart';
import 'wealth_screens.dart';

/// First screen shown whenever the vault has a passphrase set and no key is
/// in memory. Gated by [AppRoot] so the rest of the UI never renders stale
/// cleartext from a previous session.
class UnlockScreen extends StatefulWidget {
  final PortfolioStore store;
  const UnlockScreen({super.key, required this.store});
  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final passphrase = TextEditingController();
  final form = GlobalKey<FormState>();
  final biometric = BiometricGateway();
  bool working = false;
  String? error;
  bool biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await biometric.isAvailable();
    if (mounted) setState(() => biometricAvailable = available);
  }

  @override
  void dispose() {
    passphrase.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await widget.store.unlock(passphrase.text);
    } catch (e) {
      setState(() => error = 'Could not unlock: $e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _biometric() async {
    if (!widget.store.vault.hasBiometricStash) return;
    final ok = await biometric.authenticate('Unlock your portfolio');
    if (!ok) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await widget.store.unlockWithBiometrics();
    } catch (e) {
      setState(() => error = 'Biometric unlock failed: $e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: LG.hPad, vertical: 30),
            child: Form(
              key: form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const BrandMark(height: 48),
                const SizedBox(height: 40),
                Text('Unlock your portfolio',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                const Text(
                    'Enter the passphrase you set when you turned on encryption on this device.',
                    style: TextStyle(color: LG.muted, height: 1.5)),
                const SizedBox(height: 28),
                FormFieldBlock(
                    title: 'Passphrase',
                    child: TextFormField(
                      controller: passphrase,
                      autofocus: true,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: '••••••••'),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'At least 8 characters'
                          : null,
                    )),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(error!,
                          style: const TextStyle(color: LG.negative, fontSize: 12))),
                ElevatedButton(
                    onPressed: working ? null : _submit,
                    child: Text(working ? 'Checking…' : 'Unlock')),
                if (biometricAvailable &&
                    widget.store.vault.hasBiometricStash) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                      onPressed: working ? null : _biometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use biometrics')),
                ],
                const SizedBox(height: 24),
                const Text(
                    'Lost your passphrase? The encrypted data on this device cannot be recovered without it. Restore from an unencrypted JSON export if you kept one.',
                    style: TextStyle(fontSize: 12, color: LG.muted, height: 1.5)),
              ]),
            ),
          ),
        ),
      );
}

class EncryptionSetupScreen extends StatefulWidget {
  final PortfolioStore store;
  const EncryptionSetupScreen({super.key, required this.store});
  @override
  State<EncryptionSetupScreen> createState() => _EncryptionSetupScreenState();
}

class _EncryptionSetupScreenState extends State<EncryptionSetupScreen> {
  final passphrase = TextEditingController();
  final confirm = TextEditingController();
  final form = GlobalKey<FormState>();
  final biometric = BiometricGateway();
  bool working = false;
  bool biometricAvailable = false;
  String? message;

  @override
  void initState() {
    super.initState();
    biometric.isAvailable().then((v) {
      if (mounted) setState(() => biometricAvailable = v);
    });
  }

  @override
  void dispose() {
    passphrase.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    if (!form.currentState!.validate()) return;
    if (passphrase.text != confirm.text) {
      setState(() => message = 'Passphrases do not match');
      return;
    }
    setState(() {
      working = true;
      message = null;
    });
    try {
      await widget.store.enablePassphrase(passphrase.text);
      if (mounted) setState(() => message = 'Encryption enabled');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not enable: $e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _disable() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Remove encryption?'),
                content: const Text(
                    'Your portfolio will be written back to this device as unprotected JSON until you re-enable a passphrase.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Remove'))
                ]));
    if (ok != true) return;
    await widget.store.disablePassphrase();
    if (mounted) setState(() => message = 'Encryption removed');
  }

  Future<void> _linkBiometric() async {
    final gated = await biometric.authenticate(
        'Link this device\'s biometrics to your passphrase');
    if (!gated) return;
    try {
      await widget.store.vault.enableBiometricStash(passphrase.text);
      if (mounted) setState(() => message = 'Biometrics linked');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not link biometrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final hasPassphrase = widget.store.vault.hasPassphrase;
        return WealthPage(
            title: 'Encryption',
            subtitle:
                'Lock this device\'s copy of your portfolio behind a passphrase and optional biometrics.',
            children: [
              SoftCard(
                  color: hasPassphrase ? LG.sageSoft : LG.white,
                  child: Row(children: [
                    Icon(hasPassphrase ? Icons.lock : Icons.lock_open,
                        color: hasPassphrase ? LG.sage : LG.muted),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            hasPassphrase
                                ? 'Encryption is enabled. Your data is AES-GCM encrypted on this device.'
                                : 'Your data is currently stored in cleartext on this device.',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)))
                  ])),
              const SizedBox(height: 24),
              if (!hasPassphrase) ...[
                Form(
                    key: form,
                    child: Column(children: [
                      FormFieldBlock(
                          title: 'Choose a passphrase',
                          help:
                              'At least 8 characters. There is no recovery.',
                          child: TextFormField(
                              controller: passphrase,
                              obscureText: true,
                              validator: (v) => (v == null || v.length < 8)
                                  ? 'At least 8 characters'
                                  : null)),
                      FormFieldBlock(
                          title: 'Confirm passphrase',
                          child: TextFormField(
                              controller: confirm,
                              obscureText: true,
                              validator: (v) => (v == null || v.length < 8)
                                  ? 'At least 8 characters'
                                  : null)),
                      ElevatedButton(
                          onPressed: working ? null : _enable,
                          child: Text(
                              working ? 'Encrypting…' : 'Enable encryption')),
                    ])),
              ] else ...[
                if (biometricAvailable) ...[
                  FormFieldBlock(
                      title: 'Link biometrics (optional)',
                      help:
                          'Verify your passphrase once more to allow biometrics to unlock the vault on this device.',
                      child: TextFormField(
                          controller: passphrase,
                          obscureText: true,
                          decoration:
                              const InputDecoration(hintText: 'Current passphrase'))),
                  OutlinedButton.icon(
                      onPressed: _linkBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(widget.store.vault.hasBiometricStash
                          ? 'Re-link biometrics'
                          : 'Link biometrics')),
                  if (widget.store.vault.hasBiometricStash)
                    TextButton(
                        onPressed: () => widget.store.vault.clearBiometricStash(),
                        child: const Text('Remove biometric link',
                            style: TextStyle(color: LG.negative))),
                ],
                const SizedBox(height: 10),
                TextButton(
                    onPressed: _disable,
                    child: const Text('Remove passphrase',
                        style: TextStyle(color: LG.negative))),
              ],
              if (message != null) ...[
                const SizedBox(height: 14),
                Text(message!, style: const TextStyle(color: LG.sage, fontSize: 12))
              ],
              const SizedBox(height: 20),
              const Text(
                  'Only this device holds the encrypted portfolio. There is no cloud key recovery. Keep an unencrypted JSON export in a safe place or a trusted physical backup.',
                  style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5)),
            ]);
      });
}

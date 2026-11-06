import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/wealth_store.dart';
import 'components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.store});
  final WealthStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(26, 50, 26, 35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BrandLockup(),
        const Spacer(),
        const Text('Your wealth.\nOne view.', style: TextStyle(
          color: LG.navy, fontSize: 42, height: 1.06,
          fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 17),
        const Text('Track investments, savings, properties, debts and the legacy you are building — privately, in one place.',
          style: TextStyle(color: LG.muted, fontSize: 16, height: 1.5)),
        const Spacer(),
        const InfoStrip(title: 'Your private vault', body:
          'Records are stored encrypted on this device. No external accounts are connected.'),
        const SizedBox(height: 26),
        LgAction('Create private vault',
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => CreateVaultScreen(store: store)))),
        const SizedBox(height: 12),
        const Center(child: Text('An independent portfolio tracker. No custody or trading.',
          textAlign: TextAlign.center,
          style: TextStyle(color: LG.muted, fontSize: 11.5))),
      ]),
    )),
  );
}

class CreateVaultScreen extends StatefulWidget {
  const CreateVaultScreen({super.key, required this.store});
  final WealthStore store;
  @override
  State<CreateVaultScreen> createState() => _CreateVaultScreenState();
}

class _CreateVaultScreenState extends State<CreateVaultScreen> {
  final form = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final email = TextEditingController();
  final pin = TextEditingController();
  final confirm = TextEditingController();
  int step = 0;
  bool busy = false;
  @override
  void dispose() {
    fullName.dispose(); email.dispose(); pin.dispose(); confirm.dispose();
    super.dispose();
  }
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (step == 0) { setState(() => step = 1); return; }
    if (pin.text != confirm.text) {
      showFailure(context, 'PINs do not match.'); return;
    }
    setState(() => busy = true);
    try {
      await widget.store.register(name: fullName.text, email: email.text, pin: pin.text);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: [
        Row(children: [
          IconButton(onPressed: () => step == 0
            ? Navigator.pop(context) : setState(() => step = 0),
            icon: const Icon(Icons.arrow_back_rounded)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: LG.sageSoft, borderRadius: BorderRadius.circular(30)),
            child: Text(step == 0 ? '01 / 02' : '02 / 02',
              style: const TextStyle(color: LG.sageDark, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 22),
        const BrandLockup(compact: true),
        const SizedBox(height: 42),
        Text(step == 0 ? 'Create your account' : 'Secure your account',
          style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(step == 0
            ? 'Your assets, investments and legacy — in one place.'
            : 'Protect your private wealth records with a local access PIN.',
          style: const TextStyle(color: LG.muted, fontSize: 15)),
        const SizedBox(height: 34),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(step == 0 ? 'ACCOUNT DETAILS' : 'VAULT SECURITY',
            style: const TextStyle(color: LG.sageDark, fontWeight: FontWeight.w800,
              fontSize: 12, letterSpacing: 1.8)),
          Text('Step ${step + 1} of 2', style: const TextStyle(color: LG.muted)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Container(height: 4, decoration: BoxDecoration(
            color: LG.gold, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 4, decoration: BoxDecoration(
            color: step == 1 ? LG.gold : LG.line,
            borderRadius: BorderRadius.circular(4)))),
        ]),
        const SizedBox(height: 36),
        Form(key: form, child: Column(children: step == 0 ? [
          LgInput(label: 'Full name', controller: fullName,
            hint: 'As shown on your official ID', validator: (v) =>
              (v ?? '').trim().length < 2 ? 'Enter your name' : null),
          const SizedBox(height: 22),
          LgInput(label: 'Email address (optional)', controller: email,
            hint: 'name@example.com', keyboardType: TextInputType.emailAddress,
            validator: (v) => (v ?? '').trim().isNotEmpty && !(v!.contains('@'))
              ? 'Enter a valid email or leave it blank' : null),
          const SizedBox(height: 22),
          const LgInput(label: 'Reporting currency', hint: 'UGX — Uganda Shilling',
            enabled: false),
          const SizedBox(height: 34),
          const InfoStrip(title: 'Private by design',
            body: 'We only keep your records in this device vault. Cloud sign-in is not enabled.'),
        ] : [
          LgInput(label: 'Create access PIN', controller: pin,
            hint: 'At least 6 digits', obscure: true,
            keyboardType: TextInputType.number,
            validator: (v) => v == null || !RegExp(r'^\d{6,}$').hasMatch(v)
              ? 'Use at least 6 digits' : null),
          const SizedBox(height: 22),
          LgInput(label: 'Confirm access PIN', controller: confirm,
            hint: 'Repeat your PIN', obscure: true,
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v != pin.text ? 'PINs must match' : null),
          const SizedBox(height: 32),
          const InfoStrip(icon: Icons.shield_outlined,
            title: 'Encrypted portfolio',
            body: 'Your records and document attachments are stored using an encrypted local database.'),
          const SizedBox(height: 18),
          const Text('Important: this local vault has no server recovery. Keep your device and access PIN secure.',
            style: TextStyle(color: LG.muted, height: 1.45)),
        ])),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
        child: LgAction(step == 0 ? 'Continue' : 'Create encrypted vault',
          onPressed: busy ? null : submit, busy: busy)),
    ])),
  );
}

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.store});
  final WealthStore store;
  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final pin = TextEditingController();
  bool busy = false;
  bool biometric = false;
  int failures = 0;
  @override
  void initState() {
    super.initState();
    widget.store.repo.isBiometricEnabled().then((value) {
      if (mounted) setState(() => biometric = value);
    });
  }
  @override
  void dispose() { pin.dispose(); super.dispose(); }
  Future<void> unlock({bool useBiometric = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final ok = useBiometric
          ? await widget.store.loginBiometric()
          : await widget.store.loginPin(pin.text);
      if (!ok && mounted) {
        failures++;
        pin.clear();
        showFailure(context, 'Unable to unlock vault. Check your PIN or device authentication.');
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BrandLockup(),
        const Spacer(),
        Text('Welcome back', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        const Text('Unlock your encrypted personal wealth vault.',
          style: TextStyle(color: LG.muted, fontSize: 16)),
        const SizedBox(height: 32),
        LgInput(label: 'Access PIN', controller: pin, obscure: true,
          hint: 'Enter your PIN', keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        if (failures > 0) const Text('Your local data remains securely locked.',
          style: TextStyle(color: LG.muted, fontSize: 13)),
        const SizedBox(height: 25),
        LgAction('Unlock vault', onPressed: busy ? null : unlock, busy: busy,
          icon: Icons.lock_open_rounded),
        if (biometric) ...[
          const SizedBox(height: 15),
          TextButton.icon(onPressed: busy ? null : () => unlock(useBiometric: true),
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Unlock with biometrics')),
        ],
        const Spacer(),
        const Center(child: Text('Local-only portfolio · No password recovery service',
          style: TextStyle(color: LG.muted, fontSize: 12))),
      ]),
    )),
  );
}

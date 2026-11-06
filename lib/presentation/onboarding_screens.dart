import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import 'components.dart';
import 'widgets.dart';

/// Visible launch screen while we load the portfolio off disk. On load
/// completion we hand off to the onward route via [onReady]. This is a real
/// Flutter screen — not a splash image embedded in the Android launcher.
class SplashScreen extends StatefulWidget {
  final PortfolioStore store;
  final Future<void> Function(BuildContext context) onReady;
  final Duration minimumVisible;
  const SplashScreen({
    super.key,
    required this.store,
    required this.onReady,
    this.minimumVisible = const Duration(milliseconds: 650),
  });
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final waited = Future<void>.delayed(widget.minimumVisible);
    await Future.wait([waited, widget.store.load()]);
    if (!mounted) return;
    await widget.onReady(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: LG.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(LG.hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                const Center(child: BrandMark(height: 72)),
                const SizedBox(height: 36),
                const Center(
                  child: Text(
                    'Your wealth, in one steady view.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: LG.muted, fontSize: 14, height: 1.5),
                  ),
                ),
                const Spacer(flex: 3),
                const Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Loading your local portfolio',
                    style: TextStyle(color: LG.muted, fontSize: 12),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
}

/// Canonical flat **Create Account** (step 1 of 2). This is a *prototype*
/// flow until a real identity backend exists — the spec permits the visuals
/// to live in the app but requires a truthful gated label.
class CreateAccountStep1Screen extends StatefulWidget {
  final void Function(CreateAccountDraft draft)? onContinue;
  const CreateAccountStep1Screen({super.key, this.onContinue});
  @override
  State<CreateAccountStep1Screen> createState() => _CreateAccountStep1ScreenState();
}

class _CreateAccountStep1ScreenState extends State<CreateAccountStep1Screen> {
  final form = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  String composedPhone = '+256 ';
  bool acceptedTerms = false;

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: AppHeader(step: 1, totalSteps: 2, showBrand: true),
        children: [
          const Center(child: BrandMark(height: 32)),
          const SizedBox(height: 28),
          Text('Create your account',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'Set up a private LonyoGang owner profile. This is a design preview — no live account is registered yet.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          const StepProgress(
              currentStep: 1, totalSteps: 2, eyebrow: 'Account details'),
          const SizedBox(height: 22),
          Form(
            key: form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(children: [
              FormFieldBlock(
                title: 'Full name',
                child: TextFormField(
                  controller: fullName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Your legal name'),
                  validator: (v) =>
                      isLikelyName(v ?? '') ? null : 'Enter at least two characters',
                ),
              ),
              FormFieldBlock(
                title: 'Email',
                child: TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration:
                      const InputDecoration(hintText: 'you@example.com'),
                  validator: (v) =>
                      isLikelyEmail(v ?? '') ? null : 'Enter a valid email',
                ),
              ),
              FormFieldBlock(
                title: 'Mobile number',
                help:
                    'We store this locally only. No SMS or verification is sent in preview mode.',
                child: PhoneField(
                  controller: phone,
                  onChanged: (composed) => composedPhone = composed,
                ),
              ),
              _TermsCheckbox(
                value: acceptedTerms,
                onChanged: (v) => setState(() => acceptedTerms = v),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const SecurityNotice(
            title: 'Private by design',
            message:
                'Your draft stays on this device. There are no servers to leak it to and no third-party analytics until account services are connected.',
          ),
          const SizedBox(height: 22),
          PrimaryCTA(
            label: 'Continue',
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              if (!acceptedTerms) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Accept the terms to continue')));
                return;
              }
              if (!isLikelyPhone(composedPhone)) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Enter a plausible mobile number')));
                return;
              }
              final draft = CreateAccountDraft(
                  fullName: fullName.text.trim(),
                  email: email.text.trim(),
                  phone: composedPhone.trim());
              widget.onContinue?.call(draft);
              if (!context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => CreateAccountStep2Screen(draft: draft)));
            },
          ),
          const SizedBox(height: 10),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Sign in instead',
                      style: TextStyle(color: LG.muted)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const RecoverAccountScreen())),
                  child: const Text('Recover access',
                      style: TextStyle(color: LG.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _PrototypeDisclaimer(),
        ],
      );
}

class CreateAccountDraft {
  final String fullName;
  final String email;
  final String phone;
  const CreateAccountDraft(
      {required this.fullName, required this.email, required this.phone});
}

/// Canonical flat **Create Account** (step 2 of 2). Shows the security
/// posture choices and makes it explicit the device is the whole scope.
class CreateAccountStep2Screen extends StatefulWidget {
  final CreateAccountDraft draft;
  const CreateAccountStep2Screen({super.key, required this.draft});
  @override
  State<CreateAccountStep2Screen> createState() => _CreateAccountStep2ScreenState();
}

class _CreateAccountStep2ScreenState extends State<CreateAccountStep2Screen> {
  bool enablePasskey = true;
  bool enableBiometric = true;
  final recovery = TextEditingController();

  @override
  void dispose() {
    recovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(step: 2, totalSteps: 2),
        children: [
          const Center(child: BrandMark(height: 32)),
          const SizedBox(height: 28),
          Text('Secure your account',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'Choose how you want to unlock your device copy. Server-backed passkey enrolment is not available yet; this preview protects data on-device only.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          const StepProgress(
              currentStep: 2, totalSteps: 2, eyebrow: 'Security'),
          const SizedBox(height: 22),
          _OptionTile(
            title: 'Passkey (device demonstration)',
            subtitle:
                'Simulates a WebAuthn-style credential tied to this device. No real server credential is created in the preview.',
            value: enablePasskey,
            onChanged: (v) => setState(() => enablePasskey = v),
            icon: Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 12),
          _OptionTile(
            title: 'Biometric unlock',
            subtitle:
                'Uses this device\'s fingerprint or face check once encryption is enabled under More → Encryption.',
            value: enableBiometric,
            onChanged: (v) => setState(() => enableBiometric = v),
            icon: Icons.fingerprint,
          ),
          const SizedBox(height: 20),
          FormFieldBlock(
            title: 'Recovery contact (optional)',
            help:
                'Reminds you who to call if you lose access. Stored locally; no message is sent.',
            child: TextFormField(
              controller: recovery,
              decoration: const InputDecoration(
                  hintText: 'Phone number or email of a trusted contact'),
            ),
          ),
          const SizedBox(height: 10),
          const SecurityNotice(
            title: 'No server recovery yet',
            message:
                'If you forget a passphrase set later, data on this device cannot be restored without an unencrypted JSON export. A cloud recovery option will arrive with the server implementation.',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 22),
          PrimaryCTA(
            label: 'Continue to verification',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) =>
                      OtpVerificationScreen(channel: widget.draft.email)));
            },
          ),
          const SizedBox(height: 18),
          const _PrototypeDisclaimer(),
        ],
      );
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => SoftCard(
        onTap: () => onChanged(!value),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: LG.sageSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: LG.sage),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        const TextStyle(color: LG.muted, fontSize: 12, height: 1.4)),
              ])),
          const SizedBox(width: 8),
          Switch.adaptive(
              value: value,
              activeTrackColor: LG.sageSoft,
              onChanged: onChanged),
        ]),
      );
}

/// Six-digit OTP entry screen. Purely a design preview: no verification is
/// performed because no OTP is sent in this environment.
class OtpVerificationScreen extends StatefulWidget {
  final String channel;
  const OtpVerificationScreen({super.key, required this.channel});
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final controller = TextEditingController();
  final focus = FocusNode();
  int cooldown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => cooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => cooldown--);
      if (cooldown <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          const Center(child: BrandMark(height: 32)),
          const SizedBox(height: 28),
          Text('Verify your identity',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
              'Enter the six-digit code we would send to ${widget.channel}. The preview does not send a real code — any six digits will proceed the design flow.',
              style: const TextStyle(color: LG.muted, fontSize: 14, height: 1.5)),
          const SizedBox(height: 28),
          _OtpBoxes(controller: controller, focusNode: focus),
          const SizedBox(height: 22),
          PrimaryCTA(
            label: 'Continue',
            onPressed: () async {
              if (controller.text.trim().length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter all six digits')));
                return;
              }
              Navigator.of(context).popUntil((route) => route.isFirst);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Code accepted in design preview. No real verification was performed.')));
            },
          ),
          const SizedBox(height: 14),
          Center(
              child: TextButton(
                  onPressed: cooldown > 0 ? null : _startCooldown,
                  child: Text(cooldown > 0
                      ? 'Resend available in $cooldown s'
                      : 'Resend code'))),
          const SizedBox(height: 18),
          const _PrototypeDisclaimer(),
        ],
      );
}

class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _OtpBoxes({required this.controller, required this.focusNode});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) {
          final char = i < controller.text.length ? controller.text[i] : '';
          return GestureDetector(
            onTap: () => focusNode.requestFocus(),
            child: Container(
              width: 44,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LG.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LG.line),
              ),
              child: i == controller.text.length
                  ? SizedBox(
                      width: 1,
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        showCursor: true,
                        style: const TextStyle(
                            color: Colors.transparent, fontSize: 1),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onChanged: (_) => (context as Element).markNeedsBuild(),
                      ),
                    )
                  : Text(char,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: LG.navy)),
            ),
          );
        }),
      );
}

/// Account recovery initiation. Prototype only: never confirms whether an
/// account actually exists (anti-enumeration language per spec A10).
class RecoverAccountScreen extends StatefulWidget {
  const RecoverAccountScreen({super.key});
  @override
  State<RecoverAccountScreen> createState() => _RecoverAccountScreenState();
}

class _RecoverAccountScreenState extends State<RecoverAccountScreen> {
  final form = GlobalKey<FormState>();
  final destination = TextEditingController();

  @override
  void dispose() {
    destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          const Center(child: BrandMark(height: 32)),
          const SizedBox(height: 28),
          Text('Recover access',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'Enter the email or phone number you used when you set up your account. If it matches, we would send recovery instructions there.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          Form(
            key: form,
            child: FormFieldBlock(
              title: 'Account identifier',
              child: TextFormField(
                controller: destination,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'you@example.com or +256 700 123 456'),
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Enter your email or phone'
                    : null,
              ),
            ),
          ),
          const SecurityNotice(
            title: 'Privacy-preserving response',
            message:
                'We do not confirm or deny whether an account exists. If it does, you will receive recovery instructions after backend services are connected.',
            icon: Icons.shield_moon_outlined,
          ),
          const SizedBox(height: 22),
          PrimaryCTA(
            label: 'Send recovery instructions',
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'If an account exists, recovery steps will be sent once the server is connected.')));
            },
          ),
          const SizedBox(height: 18),
          const _PrototypeDisclaimer(),
        ],
      );
}

/// Multi-step portfolio setup. This supersedes the single-field Welcome
/// prompt with: owner name → selected asset classes → confirmation. Real
/// data is persisted through [PortfolioStore.setOwner] on the final step.
class PortfolioSetupScreen extends StatefulWidget {
  final PortfolioStore store;
  const PortfolioSetupScreen({super.key, required this.store});
  @override
  State<PortfolioSetupScreen> createState() => _PortfolioSetupScreenState();
}

class _PortfolioSetupScreenState extends State<PortfolioSetupScreen> {
  int step = 0;
  final name = TextEditingController();
  final Set<String> picks = {'Investments', 'Savings', 'Property'};
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (name.text.trim().length < 2) return;
    setState(() => saving = true);
    try {
      await widget.store.setOwner(name.text);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: AppHeader(step: step + 1, totalSteps: 3),
        children: [
          const Center(child: BrandMark(height: 32)),
          const SizedBox(height: 24),
          StepProgress(
              currentStep: step + 1,
              totalSteps: 3,
              eyebrow: 'Create your portfolio'),
          const SizedBox(height: 22),
          if (step == 0) ..._stepName(context),
          if (step == 1) ..._stepPicks(context),
          if (step == 2) ..._stepConfirm(context),
        ],
      );

  List<Widget> _stepName(BuildContext context) => [
        Text('What should we call your portfolio?',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        const Text(
            'This is a label you will see at the top of every screen. It never leaves this device.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5)),
        const SizedBox(height: 22),
        FormFieldBlock(
          title: 'Portfolio name',
          child: TextFormField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. My family wealth'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        PrimaryCTA(
            label: 'Continue',
            onPressed: isLikelyName(name.text)
                ? () async => setState(() => step = 1)
                : null),
      ];

  List<Widget> _stepPicks(BuildContext context) => [
        Text('What do you plan to track?',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        const Text(
            'Choose any combination. You can enable more categories later; we will not add things you did not choose.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5)),
        const SizedBox(height: 22),
        for (final category in const [
          ('Investments', Icons.trending_up_rounded,
              'Shares, funds, government securities, SACCO units'),
          ('Savings', Icons.savings_outlined,
              'Bank accounts, NSSF, fixed deposits'),
          ('Property', Icons.home_outlined,
              'Land, residential, rental, commercial'),
          ('Other assets', Icons.inventory_2_outlined,
              'Vehicles, equipment, valuable personal effects'),
          ('Liabilities', Icons.account_balance_outlined,
              'Mortgages, loans, SACCO balances'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              onTap: () => setState(() {
                if (picks.contains(category.$1)) {
                  picks.remove(category.$1);
                } else {
                  picks.add(category.$1);
                }
              }),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: LG.sageSoft,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(category.$2, color: LG.sage),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(category.$1,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(category.$3,
                          style: const TextStyle(
                              color: LG.muted, fontSize: 12, height: 1.4)),
                    ])),
                Icon(
                  picks.contains(category.$1)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: picks.contains(category.$1) ? LG.sage : LG.muted,
                )
              ]),
            ),
          ),
        const SizedBox(height: 10),
        PrimaryCTA(
            label: 'Continue',
            onPressed:
                picks.isEmpty ? null : () async => setState(() => step = 2)),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
              onPressed: () => setState(() => step = 0),
              child: const Text('Back', style: TextStyle(color: LG.muted))),
        ),
      ];

  List<Widget> _stepConfirm(BuildContext context) => [
        Text('Ready to begin',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        const Text(
            'Here is what we will set up on this device. You can change everything later.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5)),
        const SizedBox(height: 22),
        SoftCard(
            child: Column(children: [
          InfoLabel(label: 'Portfolio name', value: name.text.trim()),
          InfoLabel(label: 'Currency', value: 'UGX'),
          InfoLabel(label: 'Tracked categories', value: picks.join(', ')),
          const InfoLabel(label: 'Storage', value: 'On this device only'),
          const InfoLabel(label: 'Account type', value: 'Local preview'),
        ])),
        const SizedBox(height: 14),
        const SecurityNotice(
          title: 'No fake balances will be loaded',
          message:
              'We create an empty portfolio. You can optionally load the SRS demonstration data from Settings later.',
        ),
        const SizedBox(height: 22),
        PrimaryCTA(
          label: saving ? 'Creating…' : 'Create portfolio',
          loading: saving,
          onPressed: _finish,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
              onPressed: () => setState(() => step = 1),
              child: const Text('Back', style: TextStyle(color: LG.muted))),
        ),
      ];
}

/// Fallback route used whenever a navigation request points at a deleted,
/// archived or unknown entity. Offers a recovery path instead of crashing.
class NotFoundScreen extends StatelessWidget {
  final String? attemptedTarget;
  const NotFoundScreen({super.key, this.attemptedTarget});
  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.search_off_rounded, size: 56, color: LG.muted),
          const SizedBox(height: 16),
          Text("We couldn't find that record",
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            attemptedTarget == null
                ? 'The item may have been archived, restored elsewhere, or imported from an older export. No data has been lost.'
                : "The route '$attemptedTarget' did not resolve to any active entity. It may have been archived or imported from an older export.",
            style: const TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 22),
          PrimaryCTA(
            label: 'Return home',
            showArrow: false,
            onPressed: () async =>
                Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back',
                    style: TextStyle(color: LG.muted))),
          ),
        ],
      );
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TermsCheckbox({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              color: value ? LG.sage : LG.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'I agree to the ',
                  style:
                      const TextStyle(color: LG.muted, fontSize: 13, height: 1.45),
                  children: [
                    TextSpan(
                      text: 'LonyoGang Preview Terms',
                      style: TextStyle(
                          color: LG.navy,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: LG.navy.withValues(alpha: 0.3)),
                    ),
                    const TextSpan(text: ' and the data-handling notice.'),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
}

class _PrototypeDisclaimer extends StatelessWidget {
  const _PrototypeDisclaimer();
  @override
  Widget build(BuildContext context) => const Center(
        child: Text(
          'Design preview · No real account is created or verified.',
          textAlign: TextAlign.center,
          style: TextStyle(color: LG.muted, fontSize: 11),
        ),
      );
}

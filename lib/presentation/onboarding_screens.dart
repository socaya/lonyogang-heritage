import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../data/remote_sync.dart';
import 'components.dart';
import 'online_scope.dart';
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
        backgroundColor: LG.navyDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(LG.hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                const Center(child: ColoredBox(color: LG.ivory, child: Padding(padding: EdgeInsets.all(16), child: BrandMark(height: 72)))),
                const SizedBox(height: 36),
                const Center(
                  child: Text(
                    'Your wealth, in one steady view.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: LG.ivory, fontSize: 14, height: 1.5),
                  ),
                ),
                const Spacer(flex: 3),
                const Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: LG.gold))),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Loading your local portfolio',
                    style: TextStyle(color: LG.ivory, fontSize: 12),
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
          Text(
            'Enter your details to create a LonyoGang Heritage account. You will verify your contact details before signing in.',
            style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 14, height: 1.5),
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
                    'Use a number you can access for account verification.',
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
                'Your details are submitted to the configured account service when you create your account.',
          ),
          const SizedBox(height: 22),
          PrimaryCTA(
            label: 'Continue',
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              if (!acceptedTerms) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Acknowledge the data-handling notice to continue')));
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
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const SignInScreen())),
                  child: Text('Sign in instead',
                      style: TextStyle(color: LG.adaptive(context,LG.muted))),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const RecoverAccountScreen())),
                  child: Text('Recover access',
                      style: TextStyle(color: LG.adaptive(context,LG.muted))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      );
}

class CreateAccountDraft {
  final String fullName;
  final String email;
  final String phone;
  /// Password the user entered on step 2. Only used to drive the backend
  /// signUp when an online scope is configured. Kept in memory until the
  /// signup call completes.
  final String? password;
  /// Set after a successful backend signUp so the OTP screen can verify
  /// the right accountId. Null in design-preview mode.
  final String? accountId;
  const CreateAccountDraft(
      {required this.fullName,
      required this.email,
      required this.phone,
      this.password,
      this.accountId});

  CreateAccountDraft copyWith({String? password, String? accountId}) =>
      CreateAccountDraft(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password ?? this.password,
        accountId: accountId ?? this.accountId,
      );
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
  bool showPassword=false;
  final confirmPassword=TextEditingController();
  final password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    confirmPassword.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    final remote=OnlineScope.maybeOf(context)?.sync;
    if(remote==null){setState(()=>_error='Account registration requires a configured server.');return;}
    if(password.text.length<10){setState(()=>_error='Password must be at least 10 characters.');return;}
    if(password.text!=confirmPassword.text){setState(()=>_error='Passwords do not match.');return;}
    setState((){_busy=true;_error=null;});
    try{
      final account=await remote.signUp(email:widget.draft.email,password:password.text,
        phone:widget.draft.phone.isEmpty?null:widget.draft.phone,displayName:widget.draft.fullName);
      if(!mounted)return;
      password.clear();
      confirmPassword.clear();
      final draft=CreateAccountDraft(fullName:widget.draft.fullName,email:widget.draft.email,phone:widget.draft.phone,accountId:account.accountId);
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder:(_)=>OtpVerificationScreen(channel:draft.email,draft:draft)));
    }catch(_){if(mounted)setState(()=>_error='Could not create account. Check your details and connection.');}
    finally{if(mounted)setState(()=>_busy=false);}
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
          Text(
            'Choose a password for your online account. Contact verification follows.',
            style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          const StepProgress(
              currentStep: 2, totalSteps: 2, eyebrow: 'Security'),
          const SizedBox(height: 22),
          FormFieldBlock(title:'Password',required:true,help:'Use at least 10 characters.',child:TextFormField(
            controller:password,enabled:!_busy,obscureText:!showPassword,autofillHints:const [AutofillHints.newPassword],
            decoration:InputDecoration(hintText:'Choose a strong password',suffixIcon:IconButton(tooltip:showPassword?'Hide password':'Show password',onPressed:()=>setState(()=>showPassword=!showPassword),icon:Icon(showPassword?Icons.visibility_off:Icons.visibility))),
          )),
          FormFieldBlock(title:'Confirm password',required:true,child:TextFormField(controller:confirmPassword,enabled:!_busy,obscureText:!showPassword,autofillHints:const [AutofillHints.newPassword])),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!,
                style: TextStyle(color: LG.adaptive(context,LG.negative), fontSize: 12)),
          ],
          const SizedBox(height: 10),
          const SecurityNotice(
            title: 'Account and vault security',
            message:
                'Your online password is separate from the local vault passphrase. You can configure device encryption and biometric unlock after setup.',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 22),
          PrimaryCTA(
            label: _busy ? 'Creating account…' : 'Continue to verification',
            loading: _busy,
            onPressed: _continue,
          ),
          const SizedBox(height: 18),
        ],
      );
}

/// Registration contact verification, separate from sign-in challenges.
class OtpVerificationScreen extends StatefulWidget {
  final String channel;
  final CreateAccountDraft? draft;
  const OtpVerificationScreen({super.key, required this.channel, this.draft});
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final controller=TextEditingController();
  int cooldown=60;
  Timer? timer;
  bool busy=false,phoneStage=false;
  String? error;
  String get channel=>phoneStage?'phone':'email';
  @override void initState(){super.initState();startCooldown();}
  void startCooldown(){
    timer?.cancel();cooldown=60;
    timer=Timer.periodic(const Duration(seconds:1),(t){if(!mounted){t.cancel();return;}setState(()=>cooldown--);if(cooldown<=0)t.cancel();});
  }
  @override void dispose(){timer?.cancel();controller.dispose();super.dispose();}
  Future<void> submit() async{
    if(busy)return;
    if(!RegExp(r'^\d{6}$').hasMatch(controller.text)){setState(()=>error='Enter all six digits.');return;}
    final remote=OnlineScope.maybeOf(context)?.sync;
    final draft=widget.draft;
    if(remote==null||draft?.accountId==null){setState(()=>error='Registration verification is unavailable.');return;}
    setState((){busy=true;error=null;});
    try{
      final status=await remote.verify(accountId:draft!.accountId!,channel:channel,code:controller.text);
      if(!mounted)return;
      if(status=='active'){
        controller.clear();
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder:(_)=>const SignInScreen()),(r)=>r.isFirst);
      }else if(!phoneStage&&draft.phone.isNotEmpty){
        setState((){phoneStage=true;controller.clear();startCooldown();});
      }else{setState(()=>error='Account verification is not complete. Contact support if the problem persists.');}
    }catch(_){if(mounted)setState(()=>error='Verification failed. Check your code and try again.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> resend() async{
    if(busy||cooldown>0)return;
    final remote=OnlineScope.maybeOf(context)?.sync;
    final id=widget.draft?.accountId;
    if(remote==null||id==null)return;
    setState(()=>busy=true);
    try{await remote.resendOtp(accountId:id,channel:channel);if(mounted)setState((){controller.clear();error=null;startCooldown();});}
    catch(_){if(mounted)setState(()=>error='Could not resend. Try again later.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>AppPage(appBar:const AppHeader(),children:[
    const Center(child:BrandMark(height:32)),const SizedBox(height:28),
    PageHeading(phoneStage?'Verify mobile number':'Verify email address',subtitle:'Enter the registration code sent to ${phoneStage?'your mobile number':'your email address'}. You will sign in separately after verification.'),
    FormFieldBlock(title:'Registration code',child:TextField(controller:controller,enabled:!busy,keyboardType:TextInputType.number,autofillHints:const [AutofillHints.oneTimeCode],inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(6)])),
    if(error!=null)Text(error!,style:TextStyle(color:LG.adaptive(context,LG.negative))),
    PrimaryCTA(label:'Verify registration',loading:busy,onPressed:submit),
    TextButton(onPressed:busy||cooldown>0?null:resend,child:Text(cooldown>0?'Resend in $cooldown s':'Resend code')),
  ]);
}

/// Password entry is separate from the authenticator challenge screen.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override State<SignInScreen> createState()=>_SignInScreenState();
}
class _SignInScreenState extends State<SignInScreen> {
  final form=GlobalKey<FormState>();
  final email=TextEditingController();
  final password=TextEditingController();
  bool busy=false;
  String? error;
  @override void dispose(){email.dispose();password.dispose();super.dispose();}
  Future<void> submit() async {
    if(busy||!form.currentState!.validate())return;
    final scope=OnlineScope.maybeOf(context);
    final remote=scope?.sync;
    if(scope==null||remote==null){
      setState(()=>error='Online sign-in is unavailable. Connect to a configured server.');
      return;
    }
    setState((){busy=true;error=null;});
    final address=email.text.trim();
    try{
      final deviceId=await scope.credentials.deviceId();
      if(!mounted)return;
      final challenge=await remote.beginSignIn(email:address,password:password.text,deviceId:deviceId);
      if(!mounted){try{await remote.cancelSignIn(challenge);}catch(_){}return;}
      password.clear();
      final verified=await Navigator.of(context).push<bool>(MaterialPageRoute(builder:(_)=>challenge.method=='totp'
        ?AuthenticatorSignInScreen(remote:remote,challenge:challenge)
        :EmailOtpSignInScreen(remote:remote,challenge:challenge)));
      if(verified!=true){try{await remote.cancelSignIn(challenge);}catch(_){}return;}
      if(!mounted)return;
      password.clear();
      Navigator.of(context).popUntil((r)=>r.isFirst);
      unawaited(scope.onSignInSuccess?.call()??remote.sync());
    } on HttpException catch(e){
      if(mounted)setState(()=>error=e.message.contains('bad_credentials')?'Email or password is incorrect.':'Sign-in failed. Try again.');
    } catch(_){if(mounted)setState(()=>error='Unable to sign in. Check your connection and try again.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>AppPage(appBar:const AppHeader(),children:[
    const Center(child:BrandMark(height:32)),
    const SizedBox(height:28),
    const PageHeading('Welcome back',subtitle:'Sign in to your LonyoGang Heritage account.'),
    Form(key:form,child:Column(children:[
      FormFieldBlock(title:'Email',required:true,child:TextFormField(controller:email,enabled:!busy,keyboardType:TextInputType.emailAddress,
        autofillHints:const [AutofillHints.email],textInputAction:TextInputAction.next,
        validator:(v)=>isLikelyEmail(v??'')?null:'Enter a valid email')),
      FormFieldBlock(title:'Password',required:true,child:TextFormField(controller:password,enabled:!busy,obscureText:true,
        autofillHints:const [AutofillHints.password],validator:(v)=>v==null||v.isEmpty?'Enter your password':null)),
    ])),
    if(error!=null)Text(error!,style:TextStyle(color:LG.adaptive(context,LG.negative))),
    Align(alignment:Alignment.centerRight,child:TextButton(onPressed:busy?null:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const RecoverAccountScreen())),child:const Text('Forgot password?'))),
    PrimaryCTA(label:'Continue',loading:busy,onPressed:submit),
    if(OnlineScope.maybeOf(context)?.sync==null)
      const SecurityNotice(title:'Offline access',message:'Online sign-in requires a configured server. Your existing local portfolio is managed separately.'),
  ]);
}

/// Separate server-selected verification routes.
class AuthenticatorSignInScreen extends StatelessWidget {
  final RemoteSyncService remote;
  final SignInChallenge challenge;
  const AuthenticatorSignInScreen({super.key,required this.remote,required this.challenge});
  @override Widget build(BuildContext context)=>_SignInVerification(remote:remote,challenge:challenge,email:false);
}
class EmailOtpSignInScreen extends StatelessWidget {
  final RemoteSyncService remote;
  final SignInChallenge challenge;
  const EmailOtpSignInScreen({super.key,required this.remote,required this.challenge});
  @override Widget build(BuildContext context)=>_SignInVerification(remote:remote,challenge:challenge,email:true);
}
class _SignInVerification extends StatefulWidget {
  final RemoteSyncService remote;
  final SignInChallenge challenge;
  final bool email;
  const _SignInVerification({required this.remote,required this.challenge,required this.email});
  @override State<_SignInVerification> createState()=>_SignInVerificationState();
}
class _SignInVerificationState extends State<_SignInVerification> {
  final form=GlobalKey<FormState>();
  final code=TextEditingController();
  bool busy=false;
  String? error;
  late DateTime resendAt;
  Timer? timer;
  int resends=0;
  bool get expired=>!widget.challenge.expiresAt.isAfter(DateTime.now());
  int get cooldown=>(resendAt.difference(DateTime.now()).inMilliseconds/1000).ceil().clamp(0,3600).toInt();
  @override void initState(){
    super.initState();
    resendAt=DateTime.now().add(Duration(seconds:widget.challenge.resendAfterSeconds));
    timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState((){});});
  }
  @override void dispose(){timer?.cancel();code.dispose();super.dispose();}
  Future<void> submit() async {
    if(busy||expired||!form.currentState!.validate())return;
    setState((){busy=true;error=null;});
    try{
      await widget.remote.finishSignIn(widget.challenge,code.text);
      if(mounted){setState(()=>busy=false);Navigator.of(context).pop(true);}
    }catch(_){
      if(mounted)setState(()=>error='Verification failed. Check the code or return to sign in.');
    }finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> resend() async {
    if(busy||expired||cooldown>0||resends>=2||!widget.email)return;
    setState((){busy=true;error=null;});
    try{
      final seconds=await widget.remote.resendSignIn(widget.challenge);
      if(mounted)setState((){resendAt=DateTime.now().add(Duration(seconds:seconds));resends++;code.clear();});
    }catch(_){if(mounted)setState(()=>error='Could not resend the code. Wait or sign in again.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>PopScope(canPop:!busy,child:AppPage(appBar:const AppHeader(),children:[
    const Center(child:BrandMark(height:32)),
    const SizedBox(height:28),
    Icon(widget.email?Icons.mail_outline:Icons.shield_outlined,color:LG.adaptive(context,LG.sage),size:48),
    PageHeading(widget.email?'Email verification':'Authenticator verification',subtitle:widget.email
      ?'Enter the six-digit code sent to ${widget.challenge.maskedDestination??"your verified email"}.'
      :'Open your authenticator app and enter the current six-digit code.'),
    Form(key:form,child:FormFieldBlock(title:widget.email?'Verification code':'Authenticator code',child:TextFormField(
      controller:code,enabled:!busy&&!expired,keyboardType:TextInputType.number,autofillHints:const [AutofillHints.oneTimeCode],
      inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(6)],
      validator:(v)=>v?.length==6?null:'Enter six digits',
    ))),
    if(expired)Text('Verification expired. Return to sign in.',style:TextStyle(color:LG.adaptive(context,LG.negative))),
    if(error!=null)Text(error!,style:TextStyle(color:LG.adaptive(context,LG.negative))),
    PrimaryCTA(label:'Verify and sign in',loading:busy,onPressed:expired?null:submit),
    if(widget.email)TextButton(onPressed:busy||expired||cooldown>0||resends>=2?null:resend,
      child:Text(resends>=2?'Resend limit reached':cooldown>0?'Resend in $cooldown s':'Resend code')),
    TextButton(onPressed:busy?null:()=>Navigator.of(context).pop(false),child:const Text('Cancel and return to sign in')),
  ]));
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
  bool _busy = false;

  @override
  void dispose() {
    destination.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!form.currentState!.validate()) return;
    final scope = OnlineScope.maybeOf(context);
    final remote = scope?.sync;
    setState(() => _busy = true);
    try {
      // Only email is accepted by /identity/password/reset/begin today;
      // the phone branch is still spec-only. For either input we respond
      // with the same privacy-preserving UX so the UI never discloses
      // which channels the user actually configured.
      if (remote != null && isLikelyEmail(destination.text.trim())) {
        await remote.beginPasswordReset(email: destination.text.trim());
      } else {
        // Small artificial delay so the preview/no-backend case matches
        // the wall-clock shape of the real one; prevents the UI from
        // revealing "backend configured" through a conspicuous timing gap.
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } catch (_) {
      // Silent failure is the spec-mandated behaviour: never tell the
      // caller whether an account exists or whether the server reached
      // the mailer. Any error becomes the same UX as success.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'If an account matches, recovery instructions have been sent.')));
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
          Text(
            'Enter the email or phone number you used when you set up your account. If it matches, we would send recovery instructions there.',
            style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 14, height: 1.5),
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
            label: _busy ? 'Sending…' : 'Send recovery instructions',
            loading: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const PasswordResetCompleteScreen())),
              child: Text('I already have a reset code',
                  style: TextStyle(color: LG.adaptive(context,LG.muted))),
            ),
          ),
          const SizedBox(height: 18),
        ],
      );
}

/// Second half of the password-reset flow: the user pastes the code the
/// server sent to their email (plus the email itself) and picks a new
/// password. Only functional when an OnlineScope is wired; otherwise the
/// screen stays as a design preview so the surface area is visible.
class PasswordResetCompleteScreen extends StatefulWidget {
  const PasswordResetCompleteScreen({super.key});
  @override
  State<PasswordResetCompleteScreen> createState() =>
      _PasswordResetCompleteScreenState();
}

class _PasswordResetCompleteScreenState
    extends State<PasswordResetCompleteScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final token = TextEditingController();
  final password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    email.dispose();
    token.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!form.currentState!.validate()) return;
    final scope = OnlineScope.maybeOf(context);
    final remote = scope?.sync;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (remote == null) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Preview: password would be reset once the backend is connected.')));
        return;
      }
      await remote.completePasswordReset(
        email: email.text.trim(),
        token: token.text.trim(),
        newPassword: password.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password updated. Sign in with the new password.')));
    } on HttpException catch (err) {
      setState(() {
        _busy = false;
        _error = err.message.contains('token_invalid')
            ? 'That reset code is not valid or has expired.'
            : 'Reset failed: ${err.message}';
      });
    } catch (err) {
      setState(() {
        _busy = false;
        _error = 'Reset failed: $err';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          const Center(child: BrandMark(height: 32)),
          const SizedBox(height: 28),
          Text('Choose a new password',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            'Paste the reset code from the email the server sent you. All existing sessions are revoked when the password changes.',
            style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          Form(
            key: form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(children: [
              FormFieldBlock(
                title: 'Email',
                child: TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'you@example.com'),
                  validator: (v) =>
                      isLikelyEmail(v ?? '') ? null : 'Enter the account email',
                ),
              ),
              FormFieldBlock(
                title: 'Reset code',
                child: TextFormField(
                  controller: token,
                  decoration: const InputDecoration(
                      hintText: 'Paste the code from the reset email'),
                  validator: (v) => (v == null || v.trim().length < 6)
                      ? 'Enter the reset code from the email'
                      : null,
                ),
              ),
              FormFieldBlock(
                title: 'New password',
                child: TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration:
                      const InputDecoration(hintText: 'At least 10 characters'),
                  validator: (v) => (v == null || v.length < 10)
                      ? 'At least 10 characters'
                      : null,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!,
                    style: TextStyle(color: LG.adaptive(context,LG.negative), fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 22),
          PrimaryCTA(
            label: _busy ? 'Resetting…' : 'Reset password',
            loading: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 18),
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
        Text(
            'This is a label you will see at the top of every screen. It never leaves this device.',
            style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 14, height: 1.5)),
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
        Text(
            'Choose any combination. You can enable more categories later; we will not add things you did not choose.',
            style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 14, height: 1.5)),
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
                      color: LG.adaptive(context,LG.sageSoft),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(category.$2, color: LG.adaptive(context,LG.sage)),
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
                          style: TextStyle(
                              color: LG.adaptive(context,LG.muted), fontSize: 12, height: 1.4)),
                    ])),
                Icon(
                  picks.contains(category.$1)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: LG.adaptive(context,picks.contains(category.$1) ? LG.sage : LG.muted),
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
              child: Text('Back', style: TextStyle(color: LG.adaptive(context,LG.muted)))),
        ),
      ];

  List<Widget> _stepConfirm(BuildContext context) => [
        Text('Ready to begin',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
            'Here is what we will set up on this device. You can change everything later.',
            style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 14, height: 1.5)),
        const SizedBox(height: 22),
        SoftCard(
            child: Column(children: [
          InfoLabel(label: 'Portfolio name', value: name.text.trim()),
          InfoLabel(label: 'Currency', value: 'UGX'),
          InfoLabel(label: 'Tracked categories', value: picks.join(', ')),
          const InfoLabel(label: 'Storage', value: 'On this device only'),
          const InfoLabel(label: 'Account type', value: 'Local portfolio'),
        ])),
        const SizedBox(height: 14),
        const SecurityNotice(
          title: 'Start with an empty portfolio',
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
              child: Text('Back', style: TextStyle(color: LG.adaptive(context,LG.muted)))),
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
          Icon(Icons.search_off_rounded, size: 56, color: LG.adaptive(context,LG.muted)),
          const SizedBox(height: 16),
          Text("We couldn't find that record",
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            attemptedTarget == null
                ? 'The item may have been archived, restored elsewhere, or imported from an older export. No data has been lost.'
                : "The route '$attemptedTarget' did not resolve to any active entity. It may have been archived or imported from an older export.",
            style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 14, height: 1.5),
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
                child: Text('Go back',
                    style: TextStyle(color: LG.adaptive(context,LG.muted)))),
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
              color: LG.adaptive(context,value ? LG.sage : LG.muted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'I understand the ',
                  style:
                      TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 13, height: 1.45),
                  children: [
                    TextSpan(
                      text: 'account data-handling notice',
                      style: TextStyle(
                          color: LG.adaptive(context,LG.navy),
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: LG.adaptive(context,LG.navy).withValues(alpha: 0.3)),
                    ),
                    const TextSpan(text: ''),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
}


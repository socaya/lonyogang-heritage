import 'package:flutter/material.dart';

import '../core/design.dart';
import 'components.dart';
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

class _UnlockScreenState extends State<UnlockScreen>{
  final passphrase=TextEditingController();
  final form=GlobalKey<FormState>();
  bool working=false,showPassphrase=false;
  String? error;
  @override void dispose(){passphrase.dispose();super.dispose();}
  Future<void> submit()async{
    if(working||!form.currentState!.validate())return;
    setState((){working=true;error=null;});
    try{
      await widget.store.unlock(passphrase.text);
      if(mounted)passphrase.clear();
    }on ArgumentError{
      if(mounted)setState(()=>error='Incorrect passphrase. Try again.');
    }catch(_){
      if(mounted)setState(()=>error='Unable to open the vault. Your saved records have not been reset.');
    }finally{if(mounted)setState(()=>working=false);}
  }
  @override Widget build(BuildContext context)=>AppPage(children:[
    const SizedBox(height:28),
    const BrandMark(height:48),
    const SizedBox(height:32),
    Icon(Icons.lock_outline,size:40,color:LG.adaptive(context,LG.sage)),
    const SizedBox(height:16),
    const PageHeading('Unlock your portfolio',subtitle:'Enter the local vault passphrase to access your encrypted records.'),
    Form(key:form,child:FormFieldBlock(title:'Vault passphrase',required:true,child:TextFormField(
      controller:passphrase,enabled:!working,obscureText:!showPassphrase,autocorrect:false,enableSuggestions:false,
      textInputAction:TextInputAction.done,onFieldSubmitted:(_)=>submit(),
      decoration:InputDecoration(suffixIcon:IconButton(tooltip:showPassphrase?'Hide passphrase':'Show passphrase',onPressed:working?null:()=>setState(()=>showPassphrase=!showPassphrase),icon:Icon(showPassphrase?Icons.visibility_off:Icons.visibility))),
      validator:(v)=>v==null||v.isEmpty?'Enter your vault passphrase':null,
    ))),
    if(error!=null)Semantics(liveRegion:true,child:Text(error!,style:TextStyle(color:LG.adaptive(context,LG.negative)))),
    const SizedBox(height:16),
    PrimaryCTA(label:'Unlock portfolio',loading:working,onPressed:submit,showArrow:false),
    const SizedBox(height:20),
    const SecurityNotice(title:'Passphrase required',message:'Biometric vault unlock is unavailable. Your online account password cannot unlock this device’s encrypted records. Keep your vault passphrase safe.'),
  ]);
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
  bool working = false;
  String? message;

  @override
  void dispose() {
    passphrase.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    if (working || !form.currentState!.validate()) return;
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
      if (mounted){passphrase.clear();confirm.clear();setState(() => message = 'Encryption enabled');}
    } catch (e) {
      if (mounted) setState(() => message = 'Could not enable encryption. Try again.');
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final hasPassphrase = widget.store.vault.hasPassphrase;
        return WealthPage(
            title: 'Encryption',
            subtitle:
                'Lock this device\'s copy of your portfolio behind a vault passphrase.',
            children: [
              SoftCard(
                  color: hasPassphrase ? LG.sageSoft : LG.white,
                  child: Row(children: [
                    Icon(hasPassphrase ? Icons.lock : Icons.lock_open,
                        color: LG.adaptive(context,hasPassphrase ? LG.sage : LG.muted)),
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
                const SecurityNotice(title:'Biometric unlock unavailable',message:'Use your vault passphrase until secure device-backed biometric protection is supported.'),
                const SizedBox(height: 10),
                TextButton(
                    onPressed: _disable,
                    child: Text('Remove passphrase',
                        style: TextStyle(color: LG.adaptive(context,LG.negative)))),
              ],
              if (message != null) ...[
                const SizedBox(height: 14),
                Text(message!, style: TextStyle(color: LG.adaptive(context,LG.sage), fontSize: 12))
              ],
              const SizedBox(height: 20),
              Text(
                  'Only this device holds the encrypted portfolio. There is no cloud key recovery. Keep an unencrypted JSON export in a safe place or a trusted physical backup.',
                  style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 12, height: 1.5)),
            ]);
      });
}

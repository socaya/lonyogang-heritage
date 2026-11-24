import 'package:flutter/material.dart';
import '../core/appearance.dart';
import '../core/design.dart';
import 'components.dart';
import 'widgets.dart';

String appearanceLabel(ThemeMode mode)=>switch(mode){
  ThemeMode.system=>'System',ThemeMode.light=>'Light',ThemeMode.dark=>'Dark',
};

class AppearanceSettingsTile extends StatelessWidget {
  const AppearanceSettingsTile({super.key});
  @override Widget build(BuildContext context){
    final controller=AppearanceScope.maybeOf(context);
    if(controller==null)return const SizedBox.shrink();
    return SoftCard(padding:EdgeInsets.zero,child:ListTile(
      leading:Icon(Icons.brightness_6_outlined,color:LG.adaptive(context,LG.sage)),
      title:const Text('App appearance'),
      subtitle:Text(appearanceLabel(controller.mode)),
      trailing:const Icon(Icons.chevron_right),
      onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const AppearanceScreen())),
    ));
  }
}

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});
  @override State<AppearanceScreen> createState()=>_AppearanceScreenState();
}
class _AppearanceScreenState extends State<AppearanceScreen>{
  bool busy=false;
  String? error;
  Future<void> change(AppearanceController controller,ThemeMode mode)async{
    if(busy||controller.mode==mode)return;
    setState((){busy=true;error=null;});
    try{await controller.setMode(mode);}
    catch(_){if(mounted)setState(()=>error='Could not save your appearance. Try again.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final controller=AppearanceScope.maybeOf(context);
    return AppPage(appBar:const AppHeader(),children:[
      const PageHeading('Appearance',subtitle:'Choose how LonyoGang Heritage looks on this device.'),
      if(controller==null)const Text('Appearance settings are unavailable.') else ...[
        SoftCard(padding:EdgeInsets.zero,child:Column(children:[
          for(final mode in ThemeMode.values)...[
            if(mode!=ThemeMode.values.first)const Divider(),
            ListTile(
              leading:Icon(switch(mode){ThemeMode.system=>Icons.settings_brightness,ThemeMode.light=>Icons.light_mode_outlined,ThemeMode.dark=>Icons.dark_mode_outlined}),
              title:Text(appearanceLabel(mode)),
              subtitle:Text(switch(mode){ThemeMode.system=>'Follow your device settings',ThemeMode.light=>'Warm ivory and navy',ThemeMode.dark=>'Deep navy and gold'}),
              enabled:!busy,
              selected:controller.mode==mode,
              trailing:Icon(controller.mode==mode?Icons.radio_button_checked:Icons.radio_button_unchecked),
              onTap:()=>change(controller,mode),
            ),
          ],
        ])),
        if(busy)const LinearProgressIndicator(),
        if(error!=null)...[const SizedBox(height:12),Semantics(liveRegion:true,child:Text(error!,style:TextStyle(color:LG.adaptive(context,LG.negative))))],
        const SizedBox(height:24),
        const Text('Your choice is saved on this device. Financial records and security settings are unchanged.'),
      ],
    ]);
  }
}

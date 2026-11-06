import 'package:flutter/material.dart';
import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/models.dart';
import 'widgets.dart';
import 'screens.dart';
import 'security_screens.dart';
import 'forms.dart';

class AppRoot extends StatefulWidget {
  final PortfolioStore store;
  const AppRoot({super.key,required this.store});
  @override State<AppRoot> createState()=>_AppRootState();
}
class _AppRootState extends State<AppRoot> {
  int tab=0;
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:widget.store,builder:(context,_) {
    if(widget.store.vault.hasPassphrase && !widget.store.isUnlocked){
      return UnlockScreen(store:widget.store);
    }
    if(!widget.store.state.onboardingDone)return WelcomeScreen(store:widget.store);
    return Scaffold(
      body:SafeArea(child:IndexedStack(index:tab,children:[
        HomeScreen(store:widget.store,onNavigate:(v)=>setState(()=>tab=v),onAdd:()=>openCreateSheet(context,widget.store)),
        PortfolioScreen(store:widget.store),
        const SizedBox.shrink(),
        ReportsScreen(store:widget.store),
        MoreScreen(store:widget.store),
      ])),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(idx){
        if(idx==2){openCreateSheet(context,widget.store);}else{setState(()=>tab=idx);}
      },destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded),label:'Home'),
        NavigationDestination(icon:Icon(Icons.pie_chart_outline),selectedIcon:Icon(Icons.pie_chart),label:'Portfolio'),
        NavigationDestination(icon:Icon(Icons.add_circle_outline,color:LG.gold,size:28),label:'Add'),
        NavigationDestination(icon:Icon(Icons.bar_chart_outlined),selectedIcon:Icon(Icons.bar_chart_rounded),label:'Reports'),
        NavigationDestination(icon:Icon(Icons.more_horiz),label:'More'),
      ]),
    );
  });
}

void openCreateSheet(BuildContext context,PortfolioStore store) {
  showModalBottomSheet<void>(context:context,showDragHandle:true,backgroundColor:LG.canvas,
    isScrollControlled:true,builder:(sheetContext)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,8,20,24),child:
      Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Add to your wealth',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:16),
        ...[
          (Icons.trending_up_rounded,'Investment',()=>AssetForm(store:store,kind:AssetKind.investment)),
          (Icons.home_outlined,'Property',()=>AssetForm(store:store,kind:AssetKind.property)),
          (Icons.savings_outlined,'Savings',()=>AssetForm(store:store,kind:AssetKind.savings)),
          (Icons.inventory_2_outlined,'Other asset',()=>AssetForm(store:store,kind:AssetKind.other)),
          (Icons.account_balance_outlined,'Liability / loan',()=>LiabilityForm(store:store)),
          (Icons.receipt_long_outlined,'Transaction',()=>EventForm(store:store)),
        ].map((item)=>ListTile(leading:Icon(item.$1,color:LG.sage),title:Text(item.$2),
          trailing:const Icon(Icons.chevron_right,color:LG.muted),onTap:(){
            Navigator.pop(sheetContext);
            Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>item.$3()));
          })),
      ]))));
}

class WelcomeScreen extends StatefulWidget {
  final PortfolioStore store;
  const WelcomeScreen({super.key,required this.store});
  @override State<WelcomeScreen> createState()=>_WelcomeScreenState();
}
class _WelcomeScreenState extends State<WelcomeScreen> {
  final name=TextEditingController();
  final form=GlobalKey<FormState>();
  @override void dispose(){name.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:SingleChildScrollView(
    padding:const EdgeInsets.symmetric(horizontal:LG.hPad,vertical:30),child:Form(key:form,child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        const BrandMark(height:52),const SizedBox(height:70),
        Text('Your wealth.\nOne view.',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize:42,height:1.13)),
        const SizedBox(height:20),const Text('A home for your investments, property, savings and lasting worth.',
          style:TextStyle(color:LG.muted,fontSize:16,height:1.55)),
        const SizedBox(height:34),const PrivacyBanner(),const SizedBox(height:36),
        const Text('GET STARTED',style:TextStyle(color:LG.sage,fontWeight:FontWeight.w800,letterSpacing:1.5,fontSize:12)),
        const SizedBox(height:12),const Text('What should we call your portfolio?',style:TextStyle(fontWeight:FontWeight.w700)),
        const SizedBox(height:8),TextFormField(controller:name,textCapitalization:TextCapitalization.words,
          textInputAction:TextInputAction.done,decoration:const InputDecoration(hintText:'e.g. My family wealth'),
          validator:(v)=>v==null||v.trim().length<2?'Enter at least two characters':null),
        const SizedBox(height:18),ElevatedButton(onPressed:()async{
          if(!form.currentState!.validate())return;
          await widget.store.setOwner(name.text);
        },child:const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Text('Create local portfolio'),SizedBox(width:12),Icon(Icons.arrow_forward)])),
        const SizedBox(height:14),Center(child:TextButton(onPressed:() async{
          await widget.store.loadDemo();
        },child:const Text('Explore with sample data'))),
        const SizedBox(height:24),const Text('No real account or cloud sign-in is created in this preview.',
          style:TextStyle(fontSize:12,color:LG.muted),textAlign:TextAlign.center),
      ])))));
}

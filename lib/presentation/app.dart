import 'package:flutter/material.dart';
import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/models.dart';
import 'components.dart';
import 'widgets.dart';
import 'screens.dart';
import 'security_screens.dart';
import 'onboarding_screens.dart';
import 'forms.dart';
import 'online_scope.dart';

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
        HomeScreen(store:widget.store,onNavigate:(v)=>setState(()=>tab=v==3?2:v),onAdd:()=>openCreateSheet(context,widget.store)),
        PortfolioScreen(store:widget.store),
        ReportsScreen(store:widget.store),
        MoreScreen(store:widget.store),
      ])),
      floatingActionButton: tab == 1 ? FloatingActionButton.extended(
        backgroundColor: LG.navy,
        foregroundColor: LG.white,
        onPressed: () => openCreateSheet(context, widget.store),
        icon: const Icon(Icons.add), label: const Text('Add record'),
      ) : null,
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(idx){
        setState(()=>tab=idx);
      },destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded),label:'Home'),
        NavigationDestination(icon:Icon(Icons.pie_chart_outline),selectedIcon:Icon(Icons.pie_chart),label:'Portfolio'),
        NavigationDestination(icon:Icon(Icons.bar_chart_outlined),selectedIcon:Icon(Icons.bar_chart_rounded),label:'Reports'),
        NavigationDestination(icon:Icon(Icons.more_horiz),label:'More'),
      ]),
    );
  });
}

void openCreateSheet(BuildContext context,PortfolioStore store) {
  showModalBottomSheet<void>(context:context,showDragHandle:true,backgroundColor:LG.adaptive(context,LG.canvas),
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
        ].map((item)=>ListTile(leading:Icon(item.$1,color:LG.adaptive(context,LG.sage)),title:Text(item.$2),
          trailing:Icon(Icons.chevron_right,color:LG.adaptive(context,LG.muted)),onTap:(){
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
class _WelcomeScreenState extends State<WelcomeScreen>{
  bool busy=false;
  Future<void> demo()async{
    if(busy)return;
    final confirmed=await confirmActionSheet(context,title:'Explore sample data?',consequence:'Load an illustrative portfolio instead of starting with empty records. Sample values are not your actual wealth.',confirmLabel:'Load sample portfolio',destructive:false);
    if(!mounted||!confirmed||busy)return;
    setState(()=>busy=true);
    try{await widget.store.loadDemo();}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not load sample data. Try again.')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final online=OnlineScope.maybeOf(context)?.sync!=null;
    return AppPage(children:[
      const SizedBox(height:28),
      const BrandMark(height:48),
      const SizedBox(height:32),
      const PageHeading('Your wealth.\nYour heritage.',subtitle:'Keep your investments, property, savings and financial obligations in one place.'),
      const SizedBox(height:8),
      const SecurityNotice(title:'Your portfolio, your control',message:'Start with records on this device. Set up a vault passphrase in Security to protect your local records.'),
      const SizedBox(height:28),
      PrimaryCTA(label:'Create local portfolio',onPressed:busy?null:()async{
        await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>PortfolioSetupScreen(store:widget.store)));
      }),
      if(online)...[
        const SizedBox(height:12),
        OutlinedButton(onPressed:busy?null:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const CreateAccountStep1Screen())),child:const Text('Create online account')),
        Center(child:TextButton(onPressed:busy?null:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const SignInScreen())),child:const Text('Already have an account? Sign in'))),
      ]else...[
        const SizedBox(height:12),
        Text('Online account services are not configured. Local portfolio features remain available.',style:Theme.of(context).textTheme.bodySmall),
      ],
      const SizedBox(height:12),
      Center(child:TextButton(onPressed:busy?null:demo,child:Text(busy?'Loading sample data…':'Explore with sample data'))),
    ]);
  }
}

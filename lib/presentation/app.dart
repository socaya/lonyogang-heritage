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

class WelcomeScreen extends StatelessWidget {
  final PortfolioStore store;
  const WelcomeScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: LG.canvas,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: LG.hPad, vertical: 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const BrandMark(height: 48),
              const SizedBox(height: 56),
              Text('Your wealth.\nOne view.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 42, height: 1.13)),
              const SizedBox(height: 18),
              const Text(
                  'A home for your investments, property, savings and lasting worth.',
                  style: TextStyle(color: LG.muted, fontSize: 16, height: 1.55)),
              const SizedBox(height: 28),
              const SecurityNotice(
                title: 'Local preview mode',
                message:
                    'Everything stays on this device. Enable a passphrase from More → Encryption once you have real data worth protecting.',
              ),
              const SizedBox(height: 32),
              PrimaryCTA(
                label: 'Create local portfolio',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PortfolioSetupScreen(store: store)));
                },
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () async => store.loadDemo(),
                  child: const Text('Explore with sample data'),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const CreateAccountStep1Screen())),
                  child: const Text('View account design preview',
                      style: TextStyle(color: LG.muted)),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'No real account or cloud sign-in is created in this preview.',
                  style: TextStyle(fontSize: 12, color: LG.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ]),
          ),
        ),
      );
}

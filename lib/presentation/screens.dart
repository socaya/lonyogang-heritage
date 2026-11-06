import 'package:flutter/material.dart';
import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/finance.dart';
import '../domain/models.dart';
import 'widgets.dart';
import 'forms.dart';

Widget paddedBody(List<Widget> children)=>ListView(padding:const EdgeInsets.fromLTRB(22,18,22,28),children:children);

class HomeScreen extends StatelessWidget {
  final PortfolioStore store;final ValueChanged<int> onNavigate;final VoidCallback onAdd;
  const HomeScreen({super.key,required this.store,required this.onNavigate,required this.onAdd});
  @override Widget build(BuildContext context){
    final total=store.totals;final assets=store.state.assets.where((x)=>!x.archived).toList();
    return paddedBody([
      Row(children:[const BrandMark(height:30),const Spacer(),IconButton(tooltip:'Reminders',
        onPressed:()=>push(context,RemindersScreen(store:store)),icon:const Icon(Icons.notifications_none_rounded))]),
      const SizedBox(height:32),Text('Good morning,',style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:LG.muted)),
      Text(store.state.ownerName,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:24),
      SoftCard(color:LG.navy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[Text('TOTAL NET WORTH',style:TextStyle(color:Color(0xFFC3D3D6),fontSize:11,fontWeight:FontWeight.w700,letterSpacing:1.1)),
          Spacer(),Icon(Icons.visibility_outlined,color:Color(0xFFC3D3D6),size:18)]),const SizedBox(height:12),
        FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(LG.money(total.netWorth),
          style:const TextStyle(fontSize:31,fontWeight:FontWeight.w800,color:Colors.white))),
        const SizedBox(height:10),const Text('Owner-attributable assets minus liabilities',
          style:TextStyle(fontSize:11,color:Color(0xFFB9C9CF))),
      ])),const SizedBox(height:14),Row(children:[
        Expanded(child:SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Total assets',style:TextStyle(color:LG.muted,fontSize:12)),const SizedBox(height:8),
          FittedBox(child:Text(LG.money(total.grossAssets,compact:true),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)))]))),
        const SizedBox(width:12),Expanded(child:SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Total liabilities',style:TextStyle(color:LG.muted,fontSize:12)),const SizedBox(height:8),
          FittedBox(child:Text(LG.money(total.liabilities,compact:true),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)))]))),
      ]),const SizedBox(height:24),SectionTitle('Wealth composition',action:TextButton(
        onPressed:()=>onNavigate(3),child:const Text('View reports'))),
      SoftCard(child:WealthBreakdown(values:{'Investments':total.investments,'Properties':total.property,
        'Savings':total.savings,'Other assets':total.other})),
      const SizedBox(height:20),SectionTitle('Your assets',action:TextButton(onPressed:()=>onNavigate(1),child:const Text('View all'))),
      if(assets.isEmpty)EmptySection(title:'Start building your portfolio',detail:'Add an investment, property or savings account.',onAdd:onAdd)
      else ...assets.take(3).map((a)=>Padding(padding:const EdgeInsets.only(bottom:8),child:AssetTile(asset:a,
        onTap:()=>push(context,AssetDetails(store:store,asset:a))))),
      const SizedBox(height:18),const PrivacyBanner(),
    ]);
  }
}

class PortfolioScreen extends StatefulWidget {
  final PortfolioStore store;
  const PortfolioScreen({super.key,required this.store});
  @override State<PortfolioScreen> createState()=>_PortfolioScreenState();
}
class _PortfolioScreenState extends State<PortfolioScreen> {
  AssetKind? filter;
  @override Widget build(BuildContext context){
    final assets=widget.store.state.assets.where((x)=>!x.archived&&(filter==null||x.kind==filter)).toList();
    return paddedBody([
      const SizedBox(height:8),const PageHeading('Your portfolio',subtitle:'Every asset and account in one view.'),
      SizedBox(height:42,child:ListView(scrollDirection:Axis.horizontal,children:[
        choice('All assets',null),const SizedBox(width:8),...AssetKind.values.map((k)=>Padding(
          padding:const EdgeInsets.only(right:8),child:choice(assetTitle(k),k)))
      ])),const SizedBox(height:22),
      Row(children:[Expanded(child:Text('${assets.length} assets',style:Theme.of(context).textTheme.titleMedium)),
        Text(LG.money(assets.fold<int>(0,(n,a)=>n+a.attributableUgx),compact:true),
          style:const TextStyle(fontWeight:FontWeight.w800))]),const SizedBox(height:16),
      if(assets.isEmpty)const EmptySection(title:'Nothing here yet',detail:'Choose Add to create your first asset.')
      else ...assets.map((a)=>Padding(padding:const EdgeInsets.only(bottom:10),child:AssetTile(asset:a,
        onTap:()=>push(context,AssetDetails(store:widget.store,asset:a))))),
      const SizedBox(height:16),SectionTitle('Liabilities',action:TextButton(onPressed:()=>push(context,
        DebtsScreen(store:widget.store)),child:const Text('View all'))),
      SoftCard(child:InfoLabel(label:'Outstanding debt',value:LG.money(widget.store.totals.liabilities))),
    ]);
  }
  Widget choice(String label,AssetKind? kind){final selected=filter==kind;return ChoiceChip(
    label:Text(label),selected:selected,onSelected:(_)=>setState(()=>filter=kind),
    selectedColor:LG.sageSoft,backgroundColor:LG.white,side:BorderSide.none,
    labelStyle:TextStyle(color:selected?LG.sage:LG.navy,fontWeight:FontWeight.w700,fontSize:12));}
}

class AssetDetails extends StatelessWidget {
  final PortfolioStore store;final WealthAsset asset;
  const AssetDetails({super.key,required this.store,required this.asset});
  @override Widget build(BuildContext context) {
    final linked=store.state.liabilities.where((x)=>!x.archived&&x.propertyId==asset.id).toList();
    return ScreenPage(title:'Asset details',children:[
      Row(children:[Icon(assetIcon(asset.kind),color:LG.sage),const SizedBox(width:10),
        Expanded(child:Text(asset.name,style:Theme.of(context).textTheme.titleLarge))]),
      const SizedBox(height:20),SoftCard(color:LG.sageSoft,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('YOUR ATTRIBUTABLE VALUE',style:TextStyle(color:LG.sage,fontSize:11,fontWeight:FontWeight.w800)),
        const SizedBox(height:10),Text(LG.money(asset.attributableUgx),style:Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height:8),Pill(asset.status.name),
      ])),const SizedBox(height:16),SoftCard(child:Column(children:[
        InfoLabel(label:'Asset class',value:assetTitle(asset.kind)),
        InfoLabel(label:'Category',value:asset.category.isEmpty?'Not specified':asset.category),
        InfoLabel(label:'Full estimated / stated value',value:LG.money(asset.valueUgx)),
        InfoLabel(label:'Economic ownership',value:'${(asset.ownershipBps/100).toStringAsFixed(2)}%'),
        InfoLabel(label:'Valuation as of',value:LG.date(asset.valuedAt)),
        InfoLabel(label:'Recorded value source',value:asset.status.name),
        if(asset.costUgx>0)InfoLabel(label:'Original cost',value:LG.money(asset.costUgx)),
        if(asset.institution.isNotEmpty)InfoLabel(label:'Institution',value:asset.institution),
        if(asset.location.isNotEmpty)InfoLabel(label:'Location',value:asset.location),
      ])),
      if(asset.kind==AssetKind.property)...[
        const SizedBox(height:18),const SectionTitle('Property equity'),
        SoftCard(child:Column(children:[InfoLabel(label:'Owned property value',value:LG.money(asset.attributableUgx)),
          InfoLabel(label:'Linked mortgage debt',value:LG.money(linked.fold<int>(0,(a,x)=>a+x.outstandingUgx))),
          const Divider(),InfoLabel(label:'Property equity',value:LG.money(propertyEquity(asset,store.state.liabilities)))])),
        const SizedBox(height:8),const Text('Mortgage balances are deducted once in consolidated net worth.',
          style:TextStyle(color:LG.muted,fontSize:11)),
      ],
      if(asset.notes.isNotEmpty)...[const SizedBox(height:18),const SectionTitle('Notes'),SoftCard(child:Text(asset.notes))],
      const SizedBox(height:24),ElevatedButton.icon(onPressed:()=>push(context,
        AssetForm(store:store,kind:asset.kind,existing:asset)),icon:const Icon(Icons.edit_outlined),label:const Text('Edit asset')),
      const SizedBox(height:10),TextButton(onPressed:()=>confirmArchive(context,()=>store.archiveAsset(asset)),
        child:const Text('Archive asset',style:TextStyle(color:LG.negative))),
    ]);
  }
}

class DebtsScreen extends StatelessWidget {
  final PortfolioStore store;
  const DebtsScreen({super.key,required this.store});
  @override Widget build(BuildContext context) {
    final debts=store.state.liabilities.where((x)=>!x.archived).toList();
    return ScreenPage(title:'Liabilities',subtitle:'Track loans and mortgages separately from assets.',children:[
      SoftCard(color:LG.navy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('TOTAL OUTSTANDING',style:TextStyle(color:Colors.white70,fontSize:12)),
        const SizedBox(height:8),Text(LG.money(store.totals.liabilities),style:const TextStyle(fontSize:27,color:Colors.white,fontWeight:FontWeight.w800))])),
      const SizedBox(height:18),
      if(debts.isEmpty)const EmptySection(title:'No liabilities recorded',detail:'Add loans and mortgages for an accurate net-worth view.')
      else ...debts.map((d)=>Padding(padding:const EdgeInsets.only(bottom:10),child:SoftCard(onTap:()=>push(context,LiabilityForm(store:store,existing:d)),
        child:Column(children:[Row(children:[const Icon(Icons.account_balance_outlined,color:LG.sage),const SizedBox(width:12),
          Expanded(child:Text(d.name,style:const TextStyle(fontWeight:FontWeight.w700))),
          Text(LG.money(d.outstandingUgx,compact:true),style:const TextStyle(fontWeight:FontWeight.w800))]),
          const SizedBox(height:8),InfoLabel(label:'As of',value:LG.date(d.asOf))])))),
      const SizedBox(height:18),ElevatedButton.icon(onPressed:()=>push(context,LiabilityForm(store:store)),
        icon:const Icon(Icons.add),label:const Text('Add liability')),
    ]);
  }
}

class ReportsScreen extends StatelessWidget {
  final PortfolioStore store;
  const ReportsScreen({super.key,required this.store});
  @override Widget build(BuildContext context) {
    final total=store.totals;
    return paddedBody([
      const SizedBox(height:10),const PageHeading('Reports & insights',subtitle:'Understand your financial standing and legacy.'),
      SoftCard(color:LG.navy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('NET WORTH',style:TextStyle(color:Colors.white70,fontSize:11,letterSpacing:1.1)),
        const SizedBox(height:7),Text(LG.money(total.netWorth),style:const TextStyle(color:Colors.white,fontSize:29,fontWeight:FontWeight.w800)),
        const SizedBox(height:4),const Text('Current values • user-entered / estimated',
          style:TextStyle(color:Colors.white70,fontSize:11)),
      ])),const SizedBox(height:20),const SectionTitle('Statement of financial position'),
      SoftCard(child:Column(children:[
        InfoLabel(label:'Gross financial holdings',value:LG.money(total.investments+total.savings)),
        InfoLabel(label:'Owner-attributable property',value:LG.money(total.property)),
        InfoLabel(label:'Other assets',value:LG.money(total.other)),const Divider(),
        InfoLabel(label:'Gross assets',value:LG.money(total.grossAssets)),
        InfoLabel(label:'Liabilities',value:'− ${LG.money(total.liabilities)}',valueColor:LG.negative),
        const Divider(),InfoLabel(label:'Net worth',value:LG.money(total.netWorth)),
      ])),const SizedBox(height:22),const SectionTitle('Asset allocation'),
      SoftCard(child:WealthBreakdown(values:{'Investments':total.investments,'Property':total.property,
        'Savings':total.savings,'Other':total.other})),
      const SizedBox(height:22),const SectionTitle('Cashflow records'),
      SoftCard(child:Column(children:[
        InfoLabel(label:'Recorded net external contributions',value:LG.money(externalContributions(store.state.events))),
        InfoLabel(label:'Recorded net income after costs',value:LG.money(realizedIncome(store.state.events))),
        const SizedBox(height:8),const Text('Returns (TWR / XIRR): N/A until dated valuations and eligible cash-flow history are available.',
          style:TextStyle(fontSize:11,color:LG.muted,height:1.5)),
      ])),const SizedBox(height:16),const PrivacyBanner(),
    ]);
  }
}

class TransactionsScreen extends StatelessWidget {
  final PortfolioStore store;
  const TransactionsScreen({super.key,required this.store});
  @override Widget build(BuildContext context) {
    final events=[...store.state.events]..sort((a,b)=>b.occurredAt.compareTo(a.occurredAt));
    return ScreenPage(title:'Transactions',subtitle:'A record of money movements and income.',children:[
      if(events.isEmpty)const EmptySection(title:'No transactions yet',detail:'Add contributions, income, rental receipts or expenses.')
      else ...events.map((e)=>Padding(padding:const EdgeInsets.only(bottom:8),child:SoftCard(child:Row(children:[
        Icon(e.kind==EventKind.reversal?Icons.undo:Icons.receipt_long_outlined,color:LG.sage),
        const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(e.description,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:4),
          Text('${e.kind.name} · ${LG.date(e.occurredAt)}',style:const TextStyle(fontSize:11,color:LG.muted)),
          if(eventIsReversed(e,events))const Text('Reversed',style:TextStyle(color:LG.negative,fontSize:11)),
        ])),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text(LG.money(e.amountUgx,compact:true),style:const TextStyle(fontWeight:FontWeight.w800)),
          if(e.kind!=EventKind.reversal&&!eventIsReversed(e,events))
            TextButton(onPressed:()=>confirmArchive(context,()=>store.reverseEvent(e),text:'Reverse this posted entry?'),
              child:const Text('Reverse',style:TextStyle(fontSize:11))),
        ])])))),
      const SizedBox(height:18),ElevatedButton.icon(onPressed:()=>push(context,EventForm(store:store)),
        icon:const Icon(Icons.add),label:const Text('Record transaction')),
    ]);
  }
}

class MoreScreen extends StatelessWidget {
  final PortfolioStore store;
  const MoreScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>paddedBody([
    const SizedBox(height:8),const PageHeading('More',subtitle:'Your wealth records, planning and preferences.'),
    SoftCard(child:Row(children:[CircleAvatar(backgroundColor:LG.sageSoft,child:Text(store.state.ownerName.isEmpty?'LG':store.state.ownerName.substring(0,1).toUpperCase(),
      style:const TextStyle(fontWeight:FontWeight.w800,color:LG.sage))),const SizedBox(width:13),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(store.state.ownerName,style:const TextStyle(fontWeight:FontWeight.w700)),
        const Text('On-device portfolio',style:TextStyle(fontSize:11,color:LG.muted))]))])),
    const SizedBox(height:20),SoftCard(child:Column(children:[
      _moreItem(context,Icons.account_balance_outlined,'Liabilities',DebtsScreen(store:store)),
      _moreItem(context,Icons.receipt_long_outlined,'Transactions',TransactionsScreen(store:store)),
      _moreItem(context,Icons.track_changes_outlined,'Wealth goals',GoalsScreen(store:store)),
      _moreItem(context,Icons.family_restroom_outlined,'Heritage & trusted contacts',LegacyScreen(store:store)),
      _moreItem(context,Icons.notifications_none_outlined,'Reminders',RemindersScreen(store:store)),
      _moreItem(context,Icons.settings_outlined,'Settings & data export',SettingsScreen(store:store)),
    ])),const SizedBox(height:18),const PrivacyBanner(),
  ]);
  Widget _moreItem(BuildContext context,IconData icon,String name,Widget target)=>ListTile(
    contentPadding:EdgeInsets.zero,leading:Icon(icon,color:LG.sage),title:Text(name,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
    trailing:const Icon(Icons.chevron_right,color:LG.muted,size:20),onTap:()=>push(context,target));
}

class ScreenPage extends StatelessWidget {
  final String title;final String? subtitle;final List<Widget> children;
  const ScreenPage({super.key,required this.title,this.subtitle,required this.children});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BrandMark(height:28)),
    body:SafeArea(child:paddedBody([PageHeading(title,subtitle:subtitle),...children])));
}

void push(BuildContext context,Widget page)=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>page));
void snack(BuildContext context,String message)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));

Future<void> confirmArchive(BuildContext context,Future<void> Function() action,{String text='Archive this entry?'})async{
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(text),
    content:const Text('This change will be saved on the device.'),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
      TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirm'))]));
  if(ok!=true || !context.mounted)return;
  await action();if(context.mounted){Navigator.maybePop(context);snack(context,'Saved');}
}

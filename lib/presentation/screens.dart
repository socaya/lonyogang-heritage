import 'package:flutter/material.dart';
import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/finance.dart';
import '../domain/models.dart';
import 'widgets.dart';
import 'forms.dart';
import 'wealth_screens.dart';
import 'legacy_screens.dart';
import 'account_screens.dart';
import 'analysis_screens.dart';
import 'detail_screens.dart';
import 'security_screens.dart';

Widget paddedBody(List<Widget> children)=>ListView(padding:const EdgeInsets.fromLTRB(22,18,22,28),children:children);

class HomeScreen extends StatelessWidget {
  final PortfolioStore store;final ValueChanged<int> onNavigate;final VoidCallback onAdd;
  const HomeScreen({super.key,required this.store,required this.onNavigate,required this.onAdd});
  @override Widget build(BuildContext context){
    final total=store.totals;final assets=store.state.assets.where((x)=>!x.archived).toList();
    return paddedBody([
      Row(children:[const BrandMark(height:30),const Spacer(),IconButton(tooltip:'Search',
        onPressed:()=>push(context,PortfolioSearchScreen(store:store)),icon:const Icon(Icons.search_rounded)),
        IconButton(tooltip:'Notifications',onPressed:()=>push(context,NotificationsCenterScreen(store:store)),
          icon:const Icon(Icons.notifications_none_rounded))]),
      const SizedBox(height:32),Text('Good morning,',style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:LG.muted)),
      Text(store.state.ownerName,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:24),
      Semantics(container:true,label:'Total net worth ${LG.money(total.netWorth)}, owner-attributable assets minus liabilities',
        child:SoftCard(color:LG.navy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[Text('TOTAL NET WORTH',style:TextStyle(color:Color(0xFFC3D3D6),fontSize:11,fontWeight:FontWeight.w700,letterSpacing:1.1)),
          Spacer(),Icon(Icons.visibility_outlined,color:Color(0xFFC3D3D6),size:18)]),const SizedBox(height:12),
        FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(LG.money(total.netWorth),
          style:const TextStyle(fontSize:31,fontWeight:FontWeight.w800,color:Colors.white))),
        const SizedBox(height:10),const Text('Owner-attributable assets minus liabilities',
          style:TextStyle(fontSize:11,color:Color(0xFFB9C9CF))),
      ]))),const SizedBox(height:14),Row(children:[
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
      const SizedBox(height:18),HomeRecentActivity(store:store),
      const SizedBox(height:18),const PrivacyBanner(),
    ]);
  }
}

/// Short summary of the most recent non-reversed ledger entries, rendered on
/// Home per spec B06. Tap-through opens the transaction detail. Hidden
/// entirely when the ledger is empty to avoid an uninformative empty card.
class HomeRecentActivity extends StatelessWidget {
  final PortfolioStore store;
  const HomeRecentActivity({super.key,required this.store});
  @override Widget build(BuildContext context){
    final events=store.state.events.where((e)=>e.kind!=EventKind.reversal
      && !eventIsReversed(e,store.state.events)).toList()
      ..sort((a,b)=>b.occurredAt.compareTo(a.occurredAt));
    if(events.isEmpty)return const SizedBox.shrink();
    final recent=events.take(3).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SectionTitle('Recent activity',action:TextButton(
        onPressed:()=>push(context,TransactionsScreen(store:store)),
        child:const Text('View all'))),
      ...recent.map((e)=>Padding(padding:const EdgeInsets.only(bottom:8),
        child:SoftCard(onTap:()=>push(context,TransactionDetailScreen(store:store,event:e)),
          padding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
          child:Row(children:[
            Container(width:40,height:40,decoration:BoxDecoration(color:LG.sageSoft,
              borderRadius:BorderRadius.circular(12)),
              child:const Icon(Icons.receipt_long_outlined,color:LG.sage,size:20)),
            const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(e.description,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontWeight:FontWeight.w700,fontSize:14)),
              Text('${e.kind.name} · ${LG.date(e.occurredAt)}',
                style:const TextStyle(color:LG.muted,fontSize:11)),
            ])),Text(LG.money(e.amountUgx,compact:true),
              style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13)),
            const SizedBox(width:6),const Icon(Icons.chevron_right,color:LG.muted,size:18),
          ])))),
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
      const SizedBox(height:16),SoftCard(onTap:()=>push(context,ValuationHistoryScreen(store:store,asset:asset)),
        child:const Row(children:[Icon(Icons.history,color:LG.sage),SizedBox(width:12),
          Expanded(child:Text('Valuation history',style:TextStyle(fontWeight:FontWeight.w700))),
          Icon(Icons.chevron_right,color:LG.muted)])),
      const SizedBox(height:10),SoftCard(onTap:()=>push(context,AssetPerformanceScreen(store:store,asset:asset)),
        child:const Row(children:[Icon(Icons.insights_outlined,color:LG.sage),SizedBox(width:12),
          Expanded(child:Text('Performance',style:TextStyle(fontWeight:FontWeight.w700))),
          Icon(Icons.chevron_right,color:LG.muted)])),
      if(asset.kind==AssetKind.property)...[const SizedBox(height:10),
        SoftCard(onTap:()=>push(context,RentalIncomeScreen(store:store)),child:const Row(children:[
          Icon(Icons.real_estate_agent_outlined,color:LG.sage),SizedBox(width:12),
          Expanded(child:Text('Recorded property income',style:TextStyle(fontWeight:FontWeight.w700))),
          Icon(Icons.chevron_right,color:LG.muted)]))],
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
      else ...debts.map((d)=>Padding(padding:const EdgeInsets.only(bottom:10),child:SoftCard(
        onTap:()=>push(context,LiabilityDetailScreen(store:store,liability:d)),
        child:Column(children:[Row(children:[const Icon(Icons.account_balance_outlined,color:LG.sage),const SizedBox(width:12),
          Expanded(child:Text(d.name,style:const TextStyle(fontWeight:FontWeight.w700))),
          Text(LG.money(d.outstandingUgx,compact:true),style:const TextStyle(fontWeight:FontWeight.w800)),
          const SizedBox(width:6),const Icon(Icons.chevron_right,color:LG.muted,size:18)]),
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
      ])),const SizedBox(height:22),const SectionTitle('Returns per asset'),
      ReturnsList(store:store),
      const SizedBox(height:16),const SectionTitle('More analysis'),
      SoftCard(child:Column(children:[
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.account_balance_wallet_outlined,color:LG.sage),
          title:const Text('Financial position'),trailing:const Icon(Icons.chevron_right,color:LG.muted),
          onTap:()=>push(context,WealthStatementScreen(store:store))),
        const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.payments_outlined,color:LG.sage),
          title:const Text('Cash flow & income'),trailing:const Icon(Icons.chevron_right,color:LG.muted),
          onTap:()=>push(context,CashFlowScreen(store:store))),
        const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.home_work_outlined,color:LG.sage),
          title:const Text('Rental income'),trailing:const Icon(Icons.chevron_right,color:LG.muted),
          onTap:()=>push(context,RentalIncomeScreen(store:store))),
        const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.tune_outlined,color:LG.sage),
          title:const Text('Target allocation & drift'),trailing:const Icon(Icons.chevron_right,color:LG.muted),
          onTap:()=>push(context,AllocationScreen(store:store))),
        const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.insights_outlined,color:LG.sage),
          title:const Text('Historical wealth trend'),trailing:const Icon(Icons.chevron_right,color:LG.muted),
          onTap:()=>push(context,HistoricalTrendScreen(store:store))),
      ])),const SizedBox(height:16),const PrivacyBanner(),
    ]);
  }
}

class ReturnsList extends StatelessWidget {
  final PortfolioStore store;
  const ReturnsList({super.key,required this.store});
  @override Widget build(BuildContext context){
    final now=DateTime.now();
    final rows=store.state.assets.where((a)=>!a.archived)
      .map((a)=>(a,assetReturns(a,store.state.valuations,store.state.events,now)))
      .where((row)=>row.$2.hasAny).toList();
    if(rows.isEmpty){
      return const SoftCard(child:Text(
        'Returns appear here once an asset has at least two dated valuations and any linked cashflows.',
        style:TextStyle(color:LG.muted,fontSize:12,height:1.5)));
    }
    String fmt(double? v)=>v==null?'—':'${(v*100).toStringAsFixed(1)}%';
    return SoftCard(child:Column(children:[
      for(final row in rows)InkWell(
        onTap:()=>push(context,AssetPerformanceScreen(store:store,asset:row.$1)),
        borderRadius:BorderRadius.circular(10),
        child:Padding(padding:const EdgeInsets.symmetric(vertical:8),
          child:Row(children:[Expanded(child:Text(row.$1.name,
            style:const TextStyle(fontWeight:FontWeight.w700))),
            Text('TWR ${fmt(row.$2.twr)}   XIRR ${fmt(row.$2.xirr)}',
              style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
            const SizedBox(width:6),
            const Icon(Icons.chevron_right,color:LG.muted,size:18)]))),
      const SizedBox(height:4),const Text(
        'Tap an asset to see its cashflows and valuation history. TWR is annualized; XIRR uses contributions, withdrawals and recorded distributions plus the current value.',
        style:TextStyle(color:LG.muted,fontSize:11,height:1.4)),
    ]));
  }
}

class TransactionsScreen extends StatelessWidget {
  final PortfolioStore store;
  const TransactionsScreen({super.key,required this.store});
  @override Widget build(BuildContext context) {
    final events=[...store.state.events]..sort((a,b)=>b.occurredAt.compareTo(a.occurredAt));
    return ScreenPage(title:'Transactions',subtitle:'A record of money movements and income.',children:[
      if(events.isEmpty)const EmptySection(title:'No transactions yet',detail:'Add contributions, income, rental receipts or expenses.')
      else ...events.map((e)=>Padding(padding:const EdgeInsets.only(bottom:8),child:SoftCard(
        onTap:()=>push(context,TransactionDetailScreen(store:store,event:e)),
        child:Row(children:[
        Icon(e.kind==EventKind.reversal?Icons.undo:Icons.receipt_long_outlined,color:LG.sage),
        const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(e.description,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:4),
          Text('${e.kind.name} · ${LG.date(e.occurredAt)}',style:const TextStyle(fontSize:11,color:LG.muted)),
          if(eventIsReversed(e,events))const Text('Reversed',style:TextStyle(color:LG.negative,fontSize:11)),
        ])),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text(LG.money(e.amountUgx,compact:true),style:const TextStyle(fontWeight:FontWeight.w800)),
          const SizedBox(height:4),
          const Icon(Icons.chevron_right,color:LG.muted,size:18),
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
    const SizedBox(height:8),const PageHeading('More',subtitle:'Your wealth records, plans and preferences.'),
    SoftCard(onTap:()=>push(context,ProfileScreen(store:store)),child:Row(children:[
      CircleAvatar(backgroundColor:LG.sageSoft,child:Text(store.state.ownerName.isEmpty?'LG':store.state.ownerName.substring(0,1).toUpperCase(),
        style:const TextStyle(fontWeight:FontWeight.w800,color:LG.sage))),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(store.state.ownerName,style:const TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:4),const Text('On-device portfolio',style:TextStyle(color:LG.muted,fontSize:12))])),
      const Icon(Icons.chevron_right,color:LG.muted),
    ])),
    const SizedBox(height:22),const SectionTitle('Your financial position'),
    SoftCard(child:Column(children:[
      _moreItem(context,Icons.search_rounded,'Search portfolio',PortfolioSearchScreen(store:store)),
      const Divider(),_moreItem(context,Icons.account_balance_wallet_outlined,'Financial position',WealthStatementScreen(store:store)),
      const Divider(),_moreItem(context,Icons.savings_outlined,'Investments & savings',InvestmentOverviewScreen(store:store)),
      const Divider(),_moreItem(context,Icons.account_balance_outlined,'Liabilities',DebtsScreen(store:store)),
      const Divider(),_moreItem(context,Icons.receipt_long_outlined,'Transactions',TransactionsScreen(store:store)),
      const Divider(),_moreItem(context,Icons.payments_outlined,'Cash flow & income',CashFlowScreen(store:store)),
      const Divider(),_moreItem(context,Icons.home_work_outlined,'Property income',RentalIncomeScreen(store:store)),
    ])),
    const SizedBox(height:22),const SectionTitle('Plan & protect'),
    SoftCard(child:Column(children:[
      _moreItem(context,Icons.track_changes_outlined,'Wealth goals',GoalsScreen(store:store)),
      const Divider(),_moreItem(context,Icons.tune_outlined,'Target allocation',AllocationScreen(store:store)),
      const Divider(),_moreItem(context,Icons.event_repeat_outlined,'Scheduled contributions',ScheduledContributionsScreen(store:store)),
      const Divider(),_moreItem(context,Icons.currency_exchange_outlined,'FX reference rates',FxRatesScreen(store:store)),
      const Divider(),_moreItem(context,Icons.family_restroom_outlined,'Beneficiaries & legacy',BeneficiariesScreen(store:store)),
      const Divider(),_moreItem(context,Icons.people_outline,'Trusted contacts',LegacyScreen(store:store)),
      const Divider(),_moreItem(context,Icons.folder_copy_outlined,'Document records',DocumentsScreen(store:store)),
      const Divider(),_moreItem(context,Icons.notifications_none_outlined,'Notifications',NotificationsCenterScreen(store:store)),
      const Divider(),_moreItem(context,Icons.event_available_outlined,'Reminders',RemindersScreen(store:store)),
    ])),
    const SizedBox(height:22),const SectionTitle('Account & support'),
    SoftCard(child:Column(children:[
      _moreItem(context,Icons.person_outline,'Profile',ProfileScreen(store:store)),
      const Divider(),_moreItem(context,Icons.shield_outlined,'Security & privacy',SecurityCenterScreen(store:store)),
      const Divider(),_moreItem(context,Icons.lock_outline,'Encryption',EncryptionSetupScreen(store:store)),
      const Divider(),_moreItem(context,Icons.credit_card_outlined,'Subscription & billing',const SubscriptionScreen()),
      const Divider(),_moreItem(context,Icons.archive_outlined,'Archived records',ArchivedRecordsScreen(store:store)),
      const Divider(),_moreItem(context,Icons.storage_outlined,'Data & sync status',DataSyncStatusScreen(store:store)),
      const Divider(),_moreItem(context,Icons.settings_outlined,'Settings & data export',SettingsScreen(store:store)),
      const Divider(),_moreItem(context,Icons.help_outline,'Help',const HelpCenterScreen()),
      const Divider(),_moreItem(context,Icons.info_outline,'About LonyoGang',const AboutScreen()),
    ])),const SizedBox(height:18),const PrivacyBanner(),
  ]);
  Widget _moreItem(BuildContext context,IconData icon,String name,Widget target)=>ListTile(
    contentPadding:EdgeInsets.zero,leading:Icon(icon,color:LG.sage),title:Text(name,
      style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
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

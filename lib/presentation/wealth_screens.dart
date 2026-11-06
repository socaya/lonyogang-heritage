import 'package:flutter/material.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/finance.dart';
import '../domain/models.dart';
import 'forms.dart';
import 'screens.dart';
import 'widgets.dart';

void openWealthPage(BuildContext context,Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>page));
}

/// A reusable, flat page layout with the same generous content gutters as the
/// approved 6.7-inch Android reference screens.
class WealthPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const WealthPage({super.key,required this.title,this.subtitle='',required this.children});
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const BrandMark(height:29)),
    body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(24,18,24,36),children:[
      PageHeading(title,subtitle:subtitle.isEmpty?null:subtitle),...children,
    ])),
  );
}

class WealthStatementScreen extends StatelessWidget {
  final PortfolioStore store;
  const WealthStatementScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
    final t=store.totals;
    return WealthPage(title:'Financial position',subtitle:'The wealth you own, the amounts you owe, and your net worth.',children:[
      SoftCard(color:LG.navy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('CURRENT NET WORTH',style:TextStyle(color:Colors.white70,fontSize:11,letterSpacing:1.4,fontWeight:FontWeight.w800)),
        const SizedBox(height:12),FittedBox(child:Text(LG.money(t.netWorth),style:const TextStyle(color:LG.white,fontSize:30,fontWeight:FontWeight.w800))),
        const SizedBox(height:10),const Text('Based on recorded balances and estimates',style:TextStyle(color:Colors.white70,fontSize:12)),
      ])),const SizedBox(height:24),
      const SectionTitle('Statement of position'),
      SoftCard(child:Column(children:[
        InfoLabel(label:'Investments',value:LG.money(t.investments)),
        InfoLabel(label:'Savings',value:LG.money(t.savings)),
        InfoLabel(label:'Attributable property',value:LG.money(t.property)),
        InfoLabel(label:'Other assets',value:LG.money(t.other)),
        const Divider(),InfoLabel(label:'Total gross assets',value:LG.money(t.grossAssets)),
        InfoLabel(label:'Loans and mortgages',value:LG.money(t.liabilities),valueColor:LG.negative),
        const Divider(),InfoLabel(label:'Net worth',value:LG.money(t.netWorth)),
      ])),
      const SizedBox(height:24),const SectionTitle('Asset allocation'),
      SoftCard(child:WealthBreakdown(values:{'Investments':t.investments,'Properties':t.property,
        'Savings':t.savings,'Other':t.other})),
      const SizedBox(height:18),
      const SoftCard(color:LG.sageSoft,child:Text(
        'Values reflect the ownership shares and last dates you recorded. This is not a bank statement, certified valuation or verified ownership record.',
        style:TextStyle(color:LG.muted,height:1.5,fontSize:12))),
      const SizedBox(height:16),
      OutlinedButton.icon(onPressed:()=>openWealthPage(context,CashFlowScreen(store:store)),
        icon:const Icon(Icons.account_balance_wallet_outlined),label:const Text('See cash flow & income')),
    ]);
  });
}

class InvestmentOverviewScreen extends StatelessWidget {
  final PortfolioStore store;
  const InvestmentOverviewScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
    final assets=store.state.assets.where((x)=>!x.archived&&(x.kind==AssetKind.investment||x.kind==AssetKind.savings)).toList();
    final invested=assets.where((x)=>x.kind==AssetKind.investment).fold<int>(0,(a,x)=>a+x.attributableUgx);
    final saved=assets.where((x)=>x.kind==AssetKind.savings).fold<int>(0,(a,x)=>a+x.attributableUgx);
    return WealthPage(title:'Financial holdings',subtitle:'Investments, deposits and savings recorded in your portfolio.',children:[
      Row(children:[
        Expanded(child:SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Investments',style:TextStyle(color:LG.muted,fontSize:12)),
          const SizedBox(height:8),FittedBox(child:Text(LG.money(invested,compact:true),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)))]))),
        const SizedBox(width:12),
        Expanded(child:SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Savings',style:TextStyle(color:LG.muted,fontSize:12)),
          const SizedBox(height:8),FittedBox(child:Text(LG.money(saved,compact:true),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)))]))),
      ]),const SizedBox(height:22),const SectionTitle('Holdings'),
      if(assets.isEmpty)const EmptySection(title:'No holdings yet',detail:'Record an investment or savings balance to get started.')
      else ...assets.map((a)=>Padding(padding:const EdgeInsets.only(bottom:10),child:AssetTile(asset:a,onTap:()=>openWealthPage(context,AssetDetails(store:store,asset:a))))),
      const SizedBox(height:14),
      ElevatedButton.icon(onPressed:()=>openWealthPage(context,AssetForm(store:store,kind:AssetKind.investment)),
        icon:const Icon(Icons.add),label:const Text('Add investment')),
      const SizedBox(height:10),
      OutlinedButton.icon(onPressed:()=>openWealthPage(context,AssetForm(store:store,kind:AssetKind.savings)),
        icon:const Icon(Icons.savings_outlined),label:const Text('Record savings')),
    ]);
  });
}

class PortfolioSearchScreen extends StatefulWidget {
  final PortfolioStore store;
  const PortfolioSearchScreen({super.key,required this.store});
  @override State<PortfolioSearchScreen> createState()=>_PortfolioSearchScreenState();
}
class _PortfolioSearchScreenState extends State<PortfolioSearchScreen> {
  final search=TextEditingController();
  String filter='All';
  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:widget.store,builder:(context,_){
    final q=search.text.trim().toLowerCase();
    final assets=widget.store.state.assets.where((a)=>!a.archived&&(a.name.toLowerCase().contains(q)||
      a.category.toLowerCase().contains(q)||a.institution.toLowerCase().contains(q))).toList();
    final debts=widget.store.state.liabilities.where((d)=>!d.archived&&(d.name.toLowerCase().contains(q)||
      d.lender.toLowerCase().contains(q))).toList();
    final events=widget.store.state.events.where((e)=>e.description.toLowerCase().contains(q)).toList()
      ..sort((a,b)=>b.occurredAt.compareTo(a.occurredAt));
    return WealthPage(title:'Search your wealth',subtitle:'Find assets, liabilities and activity quickly.',children:[
      TextField(controller:search,onChanged:(_)=>setState((){}),autofocus:false,
        decoration:const InputDecoration(prefixIcon:Icon(Icons.search,color:LG.sage),hintText:'Search your portfolio')),
      const SizedBox(height:16),
      SizedBox(height:40,child:ListView(scrollDirection:Axis.horizontal,children:[
        for(final name in ['All','Assets','Debts','Activity'])
          Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(name),selected:filter==name,
            onSelected:(_)=>setState(()=>filter=name),side:BorderSide.none,
            selectedColor:LG.sageSoft,backgroundColor:LG.white)),
      ])),
      const SizedBox(height:24),
      if(filter=='All'||filter=='Assets')...[
        SectionTitle('Assets ('+assets.length.toString()+')'),
        if(assets.isEmpty)const EmptySection(title:'No matching assets',detail:'Try another search term.')
        else ...assets.map((a)=>Padding(padding:const EdgeInsets.only(bottom:9),child:
          AssetTile(asset:a,onTap:()=>openWealthPage(context,AssetDetails(store:widget.store,asset:a))))),
      ],
      if(filter=='All'||filter=='Debts')...[
        SectionTitle('Liabilities ('+debts.length.toString()+')'),
        ...debts.map((d)=>Padding(padding:const EdgeInsets.only(bottom:8),child:SoftCard(
          onTap:()=>openWealthPage(context,LiabilityForm(store:widget.store,existing:d)),
          child:Row(children:[const Icon(Icons.account_balance_outlined,color:LG.sage),
            const SizedBox(width:12),Expanded(child:Text(d.name)),
            Text(LG.money(d.outstandingUgx,compact:true),style:const TextStyle(fontWeight:FontWeight.w800))])))),
        if(debts.isEmpty)const Text('No matching liabilities',style:TextStyle(color:LG.muted)),
      ],
      if(filter=='All'||filter=='Activity')...[
        SectionTitle('Transactions ('+events.length.toString()+')'),
        ...events.take(30).map((e)=>Padding(padding:const EdgeInsets.only(bottom:8),child:SoftCard(child:Row(children:[
          const Icon(Icons.receipt_long_outlined,color:LG.sage),const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(e.description,style:const TextStyle(fontWeight:FontWeight.w700)),
            Text(LG.date(e.occurredAt),style:const TextStyle(color:LG.muted,fontSize:12))])),
          Text(LG.money(e.amountUgx,compact:true),style:const TextStyle(fontWeight:FontWeight.w700))])))),
        if(events.isEmpty)const Text('No matching transactions',style:TextStyle(color:LG.muted)),
      ],
    ]);
  });
}

class CashFlowScreen extends StatefulWidget {
  final PortfolioStore store;
  const CashFlowScreen({super.key,required this.store});
  @override State<CashFlowScreen> createState()=>_CashFlowScreenState();
}
class _CashFlowScreenState extends State<CashFlowScreen> {
  int days=365;
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:widget.store,builder:(context,_){
    final all=widget.store.state.events;
    final since=DateTime.now().subtract(Duration(days:days));
    final shown=all.where((e)=>(days==0||!e.occurredAt.isBefore(since))&&
      e.kind!=EventKind.reversal&&!eventIsReversed(e,all)).toList()
      ..sort((a,b)=>b.occurredAt.compareTo(a.occurredAt));
    final income=shown.where((e)=>[EventKind.dividend,EventKind.interest,EventKind.rent].contains(e.kind))
      .fold<int>(0,(n,e)=>n+e.amountUgx);
    final costs=shown.where((e)=>[EventKind.fee,EventKind.tax,EventKind.expense].contains(e.kind))
      .fold<int>(0,(n,e)=>n+e.amountUgx);
    final contributions=externalContributions(shown);
    return WealthPage(title:'Cash flow & income',subtitle:'Recorded activity only; not an investment-return calculation.',children:[
      Wrap(spacing:8,children:[for(final option in [30,90,365,0])
        ChoiceChip(label:Text(option==0?'All':option==365?'1 year':option==90?'90 days':'30 days'),
          selected:days==option,onSelected:(_)=>setState(()=>days=option),
          backgroundColor:LG.white,selectedColor:LG.sageSoft,side:BorderSide.none)]),
      const SizedBox(height:20),SoftCard(color:LG.navy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('RECORDED NET INCOME',style:TextStyle(color:Colors.white70,fontSize:11,letterSpacing:1.2)),
        const SizedBox(height:10),Text(LG.money(income-costs),style:const TextStyle(color:Colors.white,fontSize:26,fontWeight:FontWeight.w800)),
      ])),const SizedBox(height:14),
      SoftCard(child:Column(children:[
        InfoLabel(label:'Dividends, interest and rent',value:LG.money(income)),
        InfoLabel(label:'Expenses, fees and taxes',value:LG.money(costs),valueColor:LG.negative),
        InfoLabel(label:'Net external contributions',value:LG.money(contributions)),
      ])),const SizedBox(height:22),SectionTitle('Activity ('+shown.length.toString()+')'),
      if(shown.isEmpty)const EmptySection(title:'No activity in this period',detail:'Record transactions to populate this report.')
      else ...shown.map((e)=>Padding(padding:const EdgeInsets.only(bottom:8),child:SoftCard(child:Row(children:[
        const Icon(Icons.receipt_long_outlined,color:LG.sage),const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(e.description,style:const TextStyle(fontWeight:FontWeight.w700)),
          Text(e.kind.name+' · '+LG.date(e.occurredAt),style:const TextStyle(color:LG.muted,fontSize:11)),
        ])),Text(LG.money(e.amountUgx,compact:true),style:const TextStyle(fontWeight:FontWeight.w800)),
      ])))),
      const SizedBox(height:12),const Text(
        'Transfers do not count as income. Reversed entries are excluded. Balances and valuation changes must be reconciled separately.',
        style:TextStyle(color:LG.muted,fontSize:12,height:1.5)),
      const SizedBox(height:18),ElevatedButton.icon(onPressed:()=>openWealthPage(context,EventForm(store:widget.store)),
        icon:const Icon(Icons.add),label:const Text('Record transaction')),
    ]);
  });
}

class RentalIncomeScreen extends StatelessWidget {
  final PortfolioStore store;
  const RentalIncomeScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
    final properties=store.state.assets.where((a)=>!a.archived&&a.kind==AssetKind.property).toList();
    final all=store.state.events;
    return WealthPage(title:'Property income',subtitle:'Cash receipts and costs linked to your properties.',children:[
      if(properties.isEmpty)const EmptySection(title:'No properties recorded',detail:'Add a property to associate rental income.')
      else ...properties.map((a){
        final entries=all.where((e)=>e.assetId==a.id&&e.kind!=EventKind.reversal&&!eventIsReversed(e,all)).toList();
        final rent=entries.where((e)=>e.kind==EventKind.rent).fold<int>(0,(s,e)=>s+e.amountUgx);
        final costs=entries.where((e)=>[EventKind.expense,EventKind.fee,EventKind.tax].contains(e.kind))
            .fold<int>(0,(s,e)=>s+e.amountUgx);
        return Padding(padding:const EdgeInsets.only(bottom:14),child:SoftCard(child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(a.name,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
          const SizedBox(height:14),InfoLabel(label:'Recorded rent received',value:LG.money(rent)),
          InfoLabel(label:'Recorded property costs',value:LG.money(costs),valueColor:LG.negative),
          const Divider(),InfoLabel(label:'Recorded net rental income',value:LG.money(rent-costs)),
          const SizedBox(height:8),
          TextButton(onPressed:()=>openWealthPage(context,EventForm(store:store)),
            child:const Text('Record income or expense')),
        ])));
      }),
      const SizedBox(height:8),const Text(
        'These amounts come from your transaction log, not bank feeds or rent-collection services. Select the relevant property when posting entries.',
        style:TextStyle(color:LG.muted,fontSize:12,height:1.5)),
    ]);
  });
}

class ValuationHistoryScreen extends StatelessWidget {
  final PortfolioStore store;
  final WealthAsset asset;
  const ValuationHistoryScreen({super.key,required this.store,required this.asset});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
    final history=store.state.valuations.where((v)=>v.assetId==asset.id).toList()
      ..sort((a,b)=>b.asOf.compareTo(a.asOf));
    final current=store.state.assets.firstWhere((x)=>x.id==asset.id,orElse:()=>asset);
    return WealthPage(title:'Valuation history',subtitle:current.name,children:[
      SoftCard(color:LG.sageSoft,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('CURRENT RECORDED FULL VALUE',style:TextStyle(color:LG.sage,fontWeight:FontWeight.w800,fontSize:11)),
        const SizedBox(height:8),Text(LG.money(current.valueUgx),style:Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height:6),Text('As of '+LG.date(current.valuedAt),style:const TextStyle(color:LG.muted,fontSize:12)),
      ])),const SizedBox(height:22),
      const SectionTitle('Previous valuations'),
      if(history.isEmpty)const EmptySection(title:'No history yet',detail:'Save a new valuation to begin tracking sources and dates.')
      else ...history.map((v)=>Padding(padding:const EdgeInsets.only(bottom:9),child:SoftCard(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[const Icon(Icons.event_note_outlined,color:LG.sage),const SizedBox(width:10),
            Expanded(child:Text(LG.date(v.asOf),style:const TextStyle(fontWeight:FontWeight.w700))),
            Text(LG.money(v.fullValueUgx,compact:true),style:const TextStyle(fontWeight:FontWeight.w800))]),
          const SizedBox(height:7),Text('Source: '+v.source,style:const TextStyle(color:LG.muted,fontSize:12)),
          if(v.notes.isNotEmpty)Text(v.notes,style:const TextStyle(color:LG.muted,fontSize:12)),
        ])))),
      const SizedBox(height:14),ElevatedButton.icon(onPressed:()=>openWealthPage(context,ValuationForm(store:store,asset:current)),
        icon:const Icon(Icons.add),label:const Text('Record valuation')),
      const SizedBox(height:16),const Text('Estimates remain estimates. Historical valuations do not by themselves establish investment performance.',
        style:TextStyle(color:LG.muted,fontSize:12,height:1.5)),
    ]);
  });
}

class ValuationForm extends StatefulWidget {
  final PortfolioStore store; final WealthAsset asset;
  const ValuationForm({super.key,required this.store,required this.asset});
  @override State<ValuationForm> createState()=>_ValuationFormState();
}
class _ValuationFormState extends State<ValuationForm> {
  final key=GlobalKey<FormState>();
  final amount=TextEditingController();
  final source=TextEditingController();
  final notes=TextEditingController();
  late DateTime date=widget.asset.valuedAt.isAfter(DateTime.now())
    ? widget.asset.valuedAt : DateTime.now();
  bool saving=false;
  @override void dispose(){amount.dispose();source.dispose();notes.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BrandMark(height:28)),
    body:SafeArea(child:Form(key:key,child:ListView(padding:const EdgeInsets.all(24),children:[
      const PageHeading('Record valuation',subtitle:'An auditable value and date for an existing asset.'),
      Text(widget.asset.name,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:20),
      FormFieldBlock(title:'Full valuation (UGX)',help:'Enter the total value before any ownership share.',
        child:TextFormField(controller:amount,keyboardType:TextInputType.number,
          validator:(v){final n=int.tryParse((v??'').replaceAll(',',''));return n==null||n<0?'Enter a valid amount':null;},
          decoration:const InputDecoration(hintText:'0'))),
      FormFieldBlock(title:'Source',child:TextFormField(controller:source,
        validator:(v)=>v==null||v.trim().isEmpty?'Required':null,
        decoration:const InputDecoration(hintText:'Statement, appraisal, own estimate...'))),
      FormFieldBlock(title:'Valuation date',child:SoftCard(onTap:()async{
        final picked=await showDatePicker(context:context,initialDate:date,
          firstDate:widget.asset.valuedAt,lastDate:DateTime.now().add(const Duration(days:365)));
        if(picked!=null)setState(()=>date=picked);
      },child:Row(children:[const Icon(Icons.calendar_today_outlined,color:LG.sage),
        const SizedBox(width:12),Text(LG.date(date))]))),
      FormFieldBlock(title:'Notes (optional)',child:TextFormField(controller:notes,maxLines:3)),
      const SizedBox(height:12),ElevatedButton(onPressed:saving?null:()async{
        if(!key.currentState!.validate())return;
        setState(()=>saving=true);
        try{
          await widget.store.recordValuation(widget.asset.id,int.parse(amount.text.replaceAll(',','')),
            date,source.text,notes:notes.text);
          if(context.mounted)Navigator.pop(context);
        }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
        finally{if(mounted)setState(()=>saving=false);}
      },child:Text(saving?'Saving...':'Save valuation')),
    ]))));
}

class ArchivedRecordsScreen extends StatelessWidget {
  final PortfolioStore store;
  const ArchivedRecordsScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
    final assets=store.state.assets.where((a)=>a.archived).toList();
    final debts=store.state.liabilities.where((d)=>d.archived).toList();
    final docs=store.state.documents.where((d)=>d.archived).toList();
    return WealthPage(title:'Archived records',subtitle:'Restore items without re-entering them.',children:[
      const SectionTitle('Assets'),
      if(assets.isEmpty)const Text('No archived assets',style:TextStyle(color:LG.muted))
      else ...assets.map((a)=>SoftCard(child:ListTile(contentPadding:EdgeInsets.zero,
        title:Text(a.name),subtitle:Text(LG.money(a.attributableUgx)),
        trailing:TextButton(onPressed:()=>store.restoreAsset(a),child:const Text('Restore'))))),
      const SizedBox(height:16),const SectionTitle('Liabilities'),
      if(debts.isEmpty)const Text('No archived debts',style:TextStyle(color:LG.muted))
      else ...debts.map((d)=>SoftCard(child:ListTile(contentPadding:EdgeInsets.zero,
        title:Text(d.name),subtitle:Text(LG.money(d.outstandingUgx)),
        trailing:TextButton(onPressed:()=>store.restoreLiability(d),child:const Text('Restore'))))),
      const SizedBox(height:16),const SectionTitle('Document records'),
      if(docs.isEmpty)const Text('No archived document records',style:TextStyle(color:LG.muted))
      else ...docs.map((d)=>SoftCard(child:ListTile(contentPadding:EdgeInsets.zero,
        title:Text(d.title),subtitle:Text(d.category),
        trailing:TextButton(onPressed:()=>store.restoreDocument(d),child:const Text('Restore'))))),
    ]);
  });
}

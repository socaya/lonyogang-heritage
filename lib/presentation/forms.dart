import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/models.dart';
import 'widgets.dart';
import 'screens.dart';

int? parseAmount(String s)=>int.tryParse(s.replaceAll(RegExp(r'[ ,]'),''));
String? requireAmount(String? v){final n=parseAmount(v??'');return n==null||n<0?'Enter a valid non-negative UGX amount':null;}

class AssetForm extends StatefulWidget {
  final PortfolioStore store;final AssetKind kind;final WealthAsset? existing;
  const AssetForm({super.key,required this.store,required this.kind,this.existing});
  @override State<AssetForm> createState()=>_AssetFormState();
}
class _AssetFormState extends State<AssetForm>{
  final key=GlobalKey<FormState>();
  late final name=TextEditingController(text:widget.existing?.name??'');
  late final category=TextEditingController(text:widget.existing?.category??'');
  late final amount=TextEditingController(text:widget.existing?.valueUgx.toString()??'');
  late final owned=TextEditingController(text:((widget.existing?.ownershipBps??10000)/100).toStringAsFixed(0));
  late final cost=TextEditingController(text:widget.existing?.costUgx.toString()??'');
  late final institution=TextEditingController(text:widget.existing?.institution??'');
  late final location=TextEditingController(text:widget.existing?.location??'');
  late final notes=TextEditingController(text:widget.existing?.notes??'');
  late DateTime date=widget.existing?.valuedAt??DateTime.now();
  late RecordStatus status=widget.existing?.status??RecordStatus.userEntered;
  bool saving=false;
  @override void dispose(){for(final c in [name,category,amount,owned,cost,institution,location,notes]){c.dispose();}super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.existing==null?'Add ${assetTitle(widget.kind).toLowerCase()}':'Edit asset')),
    body:SafeArea(child:Form(key:key,child:ListView(padding:const EdgeInsets.symmetric(horizontal:22,vertical:16),children:[
      PageHeading(widget.existing==null?'New ${assetTitle(widget.kind).toLowerCase()}':'Update ${widget.existing!.name}',
        subtitle:'Capture value, ownership and the date of the source.'),
      FormFieldBlock(title:'Asset name',child:TextFormField(controller:name,decoration:const InputDecoration(hintText:'e.g. Unit trust / Rental house'),
        validator:(v)=>v==null||v.trim().isEmpty?'Required':null)),
      FormFieldBlock(title:'Type or category',child:TextFormField(controller:category,decoration:const InputDecoration(hintText:'e.g. Government bonds'))),
      FormFieldBlock(title:'Current value (UGX)',help:'Full market or account value before your ownership share.',
        child:TextFormField(controller:amount,keyboardType:TextInputType.number,
          inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:const InputDecoration(hintText:'0'),validator:requireAmount)),
      FormFieldBlock(title:'Ownership share (%)',child:TextFormField(controller:owned,
        keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(hintText:'100'),
        validator:(s){final d=double.tryParse(s??'');return d==null||d<0||d>100?'Enter 0–100%':null;})),
      FormFieldBlock(title:'Acquisition / original cost (UGX)',child:TextFormField(controller:cost,
        keyboardType:TextInputType.number,decoration:const InputDecoration(hintText:'Optional; enter 0 if unknown'),
        validator:(v)=>v!.trim().isEmpty?null:requireAmount(v))),
      if(widget.kind==AssetKind.property)FormFieldBlock(title:'Property location',child:TextFormField(
        controller:location,decoration:const InputDecoration(hintText:'District / area')))
      else FormFieldBlock(title:'Institution or provider',child:TextFormField(controller:institution,
        decoration:const InputDecoration(hintText:'Bank, SACCO, fund or other provider'))),
      FormFieldBlock(title:'Valuation date',child:SoftCard(onTap:()async{final d=await showDatePicker(context:context,
        firstDate:DateTime(1990),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:date);
        if(d!=null)setState(()=>date=d);},child:Row(children:[const Icon(Icons.calendar_today_outlined,color:LG.sage,size:18),
          const SizedBox(width:12),Text(LG.date(date)),const Spacer(),const Icon(Icons.chevron_right,color:LG.muted)]))),
      FormFieldBlock(title:'Valuation status',child:DropdownButtonFormField<RecordStatus>(initialValue:status,
        items:RecordStatus.values.map((x)=>DropdownMenuItem(value:x,child:Text(x.name))).toList(),
        onChanged:(v)=>setState(()=>status=v??status))),
      FormFieldBlock(title:'Notes (optional)',child:TextFormField(controller:notes,maxLines:3,
        decoration:const InputDecoration(hintText:'Valuation source, relevant context...'))),
      const SizedBox(height:10),ElevatedButton(onPressed:saving?null:save,child:Text(saving?'Saving...':'Save asset')),
      const SizedBox(height:24),
    ]))));
  Future<void> save() async {
    if(!key.currentState!.validate())return;
    setState(()=>saving=true);
    try{
      final a=WealthAsset(id:widget.existing?.id??makeId(),name:name.text.trim(),kind:widget.kind,
        category:category.text.trim(),valueUgx:parseAmount(amount.text)!,
        ownershipBps:(double.parse(owned.text)*100).round(),costUgx:parseAmount(cost.text)??0,
        institution:institution.text.trim(),location:location.text.trim(),status:status,valuedAt:date,notes:notes.text.trim());
      await widget.store.upsertAsset(a);
      if(mounted)Navigator.pop(context);
    }catch(e){if(mounted)snack(context,'Could not save asset: $e');}
    finally{if(mounted)setState(()=>saving=false);}
  }
}

class LiabilityForm extends StatefulWidget {
  final PortfolioStore store;final Liability? existing;
  const LiabilityForm({super.key,required this.store,this.existing});
  @override State<LiabilityForm> createState()=>_LiabilityFormState();
}
class _LiabilityFormState extends State<LiabilityForm>{
  final key=GlobalKey<FormState>();
  late final name=TextEditingController(text:widget.existing?.name??'');
  late final lender=TextEditingController(text:widget.existing?.lender??'');
  late final amount=TextEditingController(text:widget.existing?.outstandingUgx.toString()??'');
  late final note=TextEditingController(text:widget.existing?.notes??'');
  late String? propertyId=widget.existing?.propertyId;
  @override void dispose(){name.dispose();lender.dispose();amount.dispose();note.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final properties=widget.store.state.assets.where((x)=>x.kind==AssetKind.property&&!x.archived).toList();
    if(propertyId!=null&&!properties.any((x)=>x.id==propertyId))propertyId=null;
    return Scaffold(appBar:AppBar(title:const Text('Liability')),body:SafeArea(child:Form(key:key,child:ListView(
      padding:const EdgeInsets.all(22),children:[
      PageHeading(widget.existing==null?'Add liability':'Edit liability',subtitle:'Record the amount you owe — including mortgages.'),
      FormFieldBlock(title:'Liability name',child:TextFormField(controller:name,decoration:const InputDecoration(hintText:'e.g. Mortgage'),
        validator:(v)=>v==null||v.trim().isEmpty?'Required':null)),
      FormFieldBlock(title:'Lender',child:TextFormField(controller:lender,decoration:const InputDecoration(hintText:'Optional'))),
      FormFieldBlock(title:'Outstanding balance (UGX)',child:TextFormField(controller:amount,keyboardType:TextInputType.number,
        inputFormatters:[FilteringTextInputFormatter.digitsOnly],validator:requireAmount,
        decoration:const InputDecoration(hintText:'0'))),
      FormFieldBlock(title:'Link to property (optional)',help:'A linked mortgage is counted only once in net worth.',
        child:DropdownButtonFormField<String?>(initialValue:propertyId,items:[
          const DropdownMenuItem<String?>(value:null,child:Text('Not linked')),
          ...properties.map((p)=>DropdownMenuItem<String?>(value:p.id,child:Text(p.name))),
        ],onChanged:(v)=>setState(()=>propertyId=v))),
      FormFieldBlock(title:'Notes',child:TextFormField(controller:note,maxLines:3)),
      const SizedBox(height:16),ElevatedButton(onPressed:()async{
        if(!key.currentState!.validate())return;
        await widget.store.upsertLiability(Liability(id:widget.existing?.id??makeId(),name:name.text.trim(),
          lender:lender.text.trim(),outstandingUgx:parseAmount(amount.text)!,propertyId:propertyId,
          asOf:DateTime.now(),notes:note.text.trim()));
        if(context.mounted)Navigator.pop(context);
      },child:const Text('Save liability')),
      if(widget.existing!=null)TextButton(onPressed:()=>confirmArchive(context,()=>widget.store.archiveLiability(widget.existing!)),
        child:const Text('Archive liability',style:TextStyle(color:LG.negative)))
    ]))));
  }
}

class EventForm extends StatefulWidget {
  final PortfolioStore store;
  const EventForm({super.key,required this.store});
  @override State<EventForm> createState()=>_EventFormState();
}
class _EventFormState extends State<EventForm>{
  final form=GlobalKey<FormState>();
  final desc=TextEditingController();final amt=TextEditingController();final notes=TextEditingController();
  EventKind kind=EventKind.contribution;String? assetId;DateTime day=DateTime.now();
  @override void dispose(){desc.dispose();amt.dispose();notes.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Record transaction')),
    body:SafeArea(child:Form(key:form,child:ListView(padding:const EdgeInsets.all(22),children:[
      const PageHeading('New transaction',subtitle:'Post an immutable entry to your portfolio activity log.'),
      FormFieldBlock(title:'Description',child:TextFormField(controller:desc,decoration:const InputDecoration(hintText:'e.g. Savings contribution'),
        validator:(v)=>v==null||v.trim().isEmpty?'Required':null)),
      FormFieldBlock(title:'Type',child:DropdownButtonFormField<EventKind>(initialValue:kind,
        items:EventKind.values.where((x)=>x!=EventKind.reversal).map((x)=>DropdownMenuItem(value:x,child:Text(x.name))).toList(),
        onChanged:(v)=>setState(()=>kind=v??kind))),
      FormFieldBlock(title:'Amount (UGX)',child:TextFormField(controller:amt,keyboardType:TextInputType.number,
        inputFormatters:[FilteringTextInputFormatter.digitsOnly],validator:requireAmount)),
      FormFieldBlock(title:'Related asset (optional)',child:DropdownButtonFormField<String?>(initialValue:assetId,
        items:[const DropdownMenuItem(value:null,child:Text('Portfolio-level entry')),...widget.store.state.assets.where((x)=>!x.archived)
          .map((a)=>DropdownMenuItem(value:a.id,child:Text(a.name)))],onChanged:(v)=>setState(()=>assetId=v))),
      FormFieldBlock(title:'Date',child:SoftCard(onTap:()async{final picked=await showDatePicker(context:context,initialDate:day,
        firstDate:DateTime(1990),lastDate:DateTime.now().add(const Duration(days:365)));
        if(picked!=null)setState(()=>day=picked);},child:Row(children:[const Icon(Icons.calendar_today_outlined,color:LG.sage),
        const SizedBox(width:12),Text(LG.date(day))]))),
      FormFieldBlock(title:'Notes',child:TextFormField(controller:notes,maxLines:3)),
      const SizedBox(height:10),const SoftCard(color:LG.sageSoft,child:Text(
        'An activity entry does not automatically change asset valuations. Update the asset value separately after reconciling statements.',
        style:TextStyle(color:LG.muted,fontSize:12,height:1.5))),
      const SizedBox(height:18),ElevatedButton(onPressed:()async{
        if(!form.currentState!.validate())return;
        await widget.store.postEvent(LedgerEvent(id:makeId(),description:desc.text.trim(),kind:kind,
          amountUgx:parseAmount(amt.text)!,occurredAt:day,assetId:assetId,notes:notes.text));
        if(context.mounted)Navigator.pop(context);
      },child:const Text('Post transaction')),
    ]))));
}

class GoalsScreen extends StatelessWidget {
  final PortfolioStore store;
  const GoalsScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>ScreenPage(title:'Wealth goals',subtitle:'Make long-term progress visible.',children:[
    if(store.state.goals.isEmpty)const EmptySection(title:'No goals yet',detail:'Create a goal to track your financial priorities.')
    else ...store.state.goals.map((g)=>Padding(padding:const EdgeInsets.only(bottom:10),child:SoftCard(child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(g.name,
        style:const TextStyle(fontWeight:FontWeight.w800))),IconButton(icon:const Icon(Icons.delete_outline,color:LG.muted),
        onPressed:()=>store.deleteGoal(g.id))]),
        const SizedBox(height:10),LinearProgressIndicator(value:g.targetUgx<=0?0:(g.savedUgx/g.targetUgx).clamp(0.0,1.0).toDouble(),
          minHeight:8,color:LG.sage,backgroundColor:LG.sageSoft,borderRadius:BorderRadius.circular(7)),
        const SizedBox(height:9),Text('${LG.money(g.savedUgx)} of ${LG.money(g.targetUgx)}',
          style:const TextStyle(fontSize:12,color:LG.muted))])))),
    const SizedBox(height:16),ElevatedButton.icon(onPressed:()=>_goalDialog(context,store),icon:const Icon(Icons.add),label:const Text('Add wealth goal')),
  ]);
}
Future<void> _goalDialog(BuildContext context,PortfolioStore store)async{
  final name=TextEditingController(),target=TextEditingController(),saved=TextEditingController(text:'0');
  final form=GlobalKey<FormState>();
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Create goal'),content:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextFormField(controller:name,decoration:const InputDecoration(labelText:'Goal name'),validator:(v)=>v!.trim().isEmpty?'Required':null),
    const SizedBox(height:10),TextFormField(controller:target,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Target (UGX)'),
      validator:(v){final n=parseAmount(v??'');return n==null||n<=0?'Enter positive target':null;}),
    const SizedBox(height:10),TextFormField(controller:saved,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Saved so far (UGX)'),validator:requireAmount),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),
    TextButton(onPressed:()async{if(!form.currentState!.validate())return;
      await store.addGoal(WealthGoal(id:makeId(),name:name.text.trim(),targetUgx:parseAmount(target.text)!,savedUgx:parseAmount(saved.text)!));
      if(c.mounted)Navigator.pop(c);},child:const Text('Save'))]));
  name.dispose();target.dispose();saved.dispose();
}

class LegacyScreen extends StatelessWidget {
  final PortfolioStore store;
  const LegacyScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>ScreenPage(title:'Heritage & legacy',
    subtitle:'Organise trusted contacts and estate-planning notes.',children:[
    const SoftCard(color:LG.sageSoft,child:Row(children:[Icon(Icons.shield_outlined,color:LG.sage),SizedBox(width:12),
      Expanded(child:Text('Contacts are private notes, not legally binding nominations or instructions.',
        style:TextStyle(fontSize:12,color:LG.muted,height:1.5)))])),
    const SizedBox(height:18),const SectionTitle('Trusted contacts'),
    if(store.state.contacts.isEmpty)const EmptySection(title:'No trusted contacts',detail:'Record a contact without sharing access to your portfolio.')
    else ...store.state.contacts.map((c)=>Padding(padding:const EdgeInsets.only(bottom:9),child:SoftCard(child:Row(children:[
      const CircleAvatar(backgroundColor:LG.sageSoft,child:Icon(Icons.person_outline,color:LG.sage)),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(c.name,style:const TextStyle(fontWeight:FontWeight.w800)),Text(c.relationship,style:const TextStyle(color:LG.muted,fontSize:12)),
        if(c.instructions.isNotEmpty)Text(c.instructions,style:const TextStyle(color:LG.muted,fontSize:11))])),
      IconButton(onPressed:()=>store.removeContact(c.id),icon:const Icon(Icons.delete_outline,color:LG.muted))])))),
    const SizedBox(height:16),ElevatedButton.icon(onPressed:()=>_contactDialog(context,store),
      icon:const Icon(Icons.person_add_alt_1_outlined),label:const Text('Add trusted contact')),
  ]);
}
Future<void> _contactDialog(BuildContext context,PortfolioStore store)async{
  final name=TextEditingController(),relation=TextEditingController(),note=TextEditingController();
  final key=GlobalKey<FormState>();
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Trusted contact'),content:Form(key:key,
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextFormField(controller:name,decoration:const InputDecoration(labelText:'Name'),validator:(v)=>v!.trim().isEmpty?'Required':null),
      const SizedBox(height:10),TextFormField(controller:relation,decoration:const InputDecoration(labelText:'Relationship'),validator:(v)=>v!.trim().isEmpty?'Required':null),
      const SizedBox(height:10),TextFormField(controller:note,decoration:const InputDecoration(labelText:'Notes')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),
      TextButton(onPressed:()async{if(!key.currentState!.validate())return;
        await store.addContact(LegacyContact(id:makeId(),name:name.text.trim(),relationship:relation.text.trim(),instructions:note.text.trim()));
        if(c.mounted)Navigator.pop(c);},child:const Text('Save'))]));
  name.dispose();relation.dispose();note.dispose();
}

class RemindersScreen extends StatelessWidget {
  final PortfolioStore store;
  const RemindersScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>ScreenPage(title:'Reminders',
    subtitle:'Dates and tasks you want to keep in view.',children:[
    if(store.state.reminders.isEmpty)const EmptySection(title:'No reminders',detail:'Record a maturity, rent, renewal or contribution date.')
    else ...([...store.state.reminders]..sort((a,b)=>a.dueAt.compareTo(b.dueAt))).map((r)=>Padding(
      padding:const EdgeInsets.only(bottom:8),child:SoftCard(child:CheckboxListTile(
        contentPadding:EdgeInsets.zero,value:r.completed,activeColor:LG.sage,
        onChanged:(_)=>store.toggleReminder(r.id),title:Text(r.title,style:TextStyle(
          decoration:r.completed?TextDecoration.lineThrough:null,fontWeight:FontWeight.w700,fontSize:14)),
        subtitle:Text(LG.date(r.dueAt)),controlAffinity:ListTileControlAffinity.leading)))),
    const SizedBox(height:16),ElevatedButton.icon(onPressed:()=>_reminderDialog(context,store),icon:const Icon(Icons.add_alert_outlined),label:const Text('Add reminder')),
    const SizedBox(height:12),const Text('In this offline preview, reminders appear in-app only. System notifications are not yet enabled.',
      style:TextStyle(color:LG.muted,fontSize:11)),
  ]);
}
Future<void> _reminderDialog(BuildContext context,PortfolioStore store)async{
  final controller=TextEditingController();DateTime due=DateTime.now().add(const Duration(days:7));
  await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
    title:const Text('Add reminder'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:controller,decoration:const InputDecoration(labelText:'Reminder title')),
      const SizedBox(height:14),TextButton.icon(onPressed:()async{final p=await showDatePicker(context:ctx,
        initialDate:due,firstDate:DateTime(2020),lastDate:DateTime(2100));if(p!=null)setDialog(()=>due=p);},
        icon:const Icon(Icons.calendar_month),label:Text(LG.date(due))),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
      TextButton(onPressed:()async{if(controller.text.trim().isEmpty)return;
        await store.addReminder(ReminderRecord(id:makeId(),title:controller.text.trim(),dueAt:due));
        if(ctx.mounted)Navigator.pop(ctx);},child:const Text('Save'))])));
  controller.dispose();
}

class SettingsScreen extends StatelessWidget {
  final PortfolioStore store;
  const SettingsScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>ScreenPage(title:'Settings & data',subtitle:'Your data stays on this device in preview mode.',children:[
    const PrivacyBanner(),const SizedBox(height:20),const SectionTitle('Local data management'),
    SoftCard(child:Column(children:[ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.upload_file_outlined,color:LG.sage),
      title:const Text('Export portfolio JSON'),subtitle:const Text('Copies unencrypted JSON to clipboard'),
      trailing:const Icon(Icons.chevron_right,color:LG.muted),onTap:()=>_export(context,store)),
      const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.download_outlined,color:LG.sage),
      title:const Text('Import portfolio JSON'),subtitle:const Text('Replaces current local portfolio after confirmation'),
      trailing:const Icon(Icons.chevron_right,color:LG.muted),onTap:()=>_import(context,store)),
      const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.science_outlined,color:LG.sage),
      title:const Text('Load demo portfolio'),subtitle:const Text('Replaces local records with sample SRS data'),
      trailing:const Icon(Icons.chevron_right,color:LG.muted),onTap:()async{
        final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Replace portfolio?'),
          content:const Text('This overwrites your local entries with demonstration data.'),actions:[
            TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
            TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Load demo'))]));
        if(yes==true)await store.loadDemo();
      }),
    ])),const SizedBox(height:22),const SectionTitle('About'),
    const SoftCard(child:Column(children:[InfoLabel(label:'App',value:'LonyoGang Heritage'),
      InfoLabel(label:'Prototype version',value:'0.3.0'),
      InfoLabel(label:'Default currency',value:'UGX'),
      InfoLabel(label:'Cloud synchronization',value:'Unavailable'),
      InfoLabel(label:'Encrypted local storage',value:'Not implemented'),
      InfoLabel(label:'Subscription / payments',value:'Not connected'),
    ])),
  ]);
}
Future<void> _export(BuildContext context,PortfolioStore store)async{
  final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Unencrypted export'),
    content:const Text('Copying the portfolio to the system clipboard makes its information readable by other apps. Do not export sensitive personal data in preview mode.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
      TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Copy JSON'))]));
  if(yes!=true)return;
  await Clipboard.setData(ClipboardData(text:store.exportJson()));
  if(context.mounted)snack(context,'Portfolio JSON copied to clipboard');
}
Future<void> _import(BuildContext context,PortfolioStore store)async{
  final controller=TextEditingController();
  final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Import portfolio JSON'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Text('This overwrites your current local portfolio. Save an export first.',style:TextStyle(fontSize:12,color:LG.muted)),
      const SizedBox(height:12),TextField(controller:controller,maxLines:6,decoration:const InputDecoration(hintText:'Paste exported JSON here')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
      TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Replace data'))]));
  if(yes==true){try{await store.importJson(controller.text);
    if(context.mounted)snack(context,'Portfolio imported');
    }catch(e){if(context.mounted)snack(context,'Import rejected: $e');}}
  controller.dispose();
}

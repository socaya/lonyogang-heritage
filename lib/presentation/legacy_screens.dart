import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../data/remote_sync.dart';
import '../domain/models.dart';
import 'components.dart';
import 'detail_screens.dart';
import 'forms.dart';
import 'online_privacy_screen.dart';
import 'online_scope.dart';
import 'security_screens.dart';
import 'transparency_screen.dart';
import 'widgets.dart';
import 'wealth_screens.dart';

class DocumentsScreen extends StatefulWidget {
  final PortfolioStore store;
  const DocumentsScreen({super.key,required this.store});
  @override State<DocumentsScreen> createState()=>_DocumentsScreenState();
}
class _DocumentsScreenState extends State<DocumentsScreen> {
  final query=TextEditingController();
  String category='All';
  @override void dispose(){query.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:widget.store,builder:(context,_){
    final docs=widget.store.state.documents.where((d)=>!d.archived &&
        (category=='All'||d.category==category)&&
        (d.title.toLowerCase().contains(query.text.toLowerCase())||
         d.category.toLowerCase().contains(query.text.toLowerCase()))).toList()
       ..sort((a,b)=>a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final encryptionOn=widget.store.vault.hasPassphrase;
    return WealthPage(title:'Documents & records',subtitle:'A private catalog of important financial and property records.',children:[
      SoftCard(color:LG.sageSoft,child:Row(children:[
        const Icon(Icons.info_outline,color:LG.sage),const SizedBox(width:12),
        Expanded(child:Text(encryptionOn
          ?'Attachments are AES-GCM encrypted on this device under your vault key.'
          :'Attachments are stored on this device with a per-file key. Enable a passphrase to lock them to your vault.',
          style:const TextStyle(color:LG.muted,fontSize:12,height:1.5)))])),
      const SizedBox(height:18),
      TextField(controller:query,onChanged:(_)=>setState((){}),
        decoration:const InputDecoration(prefixIcon:Icon(Icons.search,color:LG.sage),hintText:'Find a document record')),
      const SizedBox(height:14),SizedBox(height:38,child:ListView(scrollDirection:Axis.horizontal,children:[
        for(final item in ['All','Property','Investment','Insurance','Identity','Other'])
          Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(item),selected:category==item,
            onSelected:(_)=>setState(()=>category=item),backgroundColor:LG.white,
            selectedColor:LG.sageSoft,side:BorderSide.none)),
      ])),
      const SizedBox(height:20),
      if(docs.isEmpty)const AppEmptyState(title:'No document records',
        detail:'Create a record for a deed, policy, contract or statement.',
        icon:Icons.folder_outlined)
      else ...docs.map((d){
        final overdue=d.expiresAt!=null&&d.expiresAt!.isBefore(DateTime.now());
        final hasFile=d.attachment!=null;
        return Padding(padding:const EdgeInsets.only(bottom:10),child:SoftCard(
          onTap:()=>openWealthPage(context,DocumentDetailScreen(store:widget.store,document:d)),
          child:Row(children:[
            Container(width:44,height:44,decoration:BoxDecoration(color:LG.sageSoft,borderRadius:BorderRadius.circular(12)),
              child:Icon(hasFile?Icons.lock_outline:Icons.description_outlined,color:LG.sage)),
            const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(d.title,style:const TextStyle(fontWeight:FontWeight.w700)),
              const SizedBox(height:5),Text(d.expiresAt==null?d.category:'${d.category} · Expires ${LG.date(d.expiresAt!)}',
                style:TextStyle(color:overdue?LG.negative:LG.muted,fontSize:12)),
              if(hasFile)const Text('Encrypted file attached',
                style:TextStyle(color:LG.sage,fontSize:11,fontWeight:FontWeight.w700)),
            ])),const Icon(Icons.chevron_right,color:LG.muted),
          ])));
      }),
      const SizedBox(height:14),
      ElevatedButton.icon(onPressed:()=>openWealthPage(context,DocumentFormScreen(store:widget.store)),
        icon:const Icon(Icons.add),label:const Text('Add document record')),
    ]);
  });
}

class DocumentFormScreen extends StatefulWidget {
  final PortfolioStore store;
  final DocumentRecord? existing;
  const DocumentFormScreen({super.key, required this.store, this.existing});
  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final key = GlobalKey<FormState>();
  late final title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late String category = widget.existing?.category ?? 'Property';
  late String? linkedAssetId = widget.existing?.linkedAssetId;
  late DateTime? issued = widget.existing?.issuedAt;
  late DateTime? expires = widget.existing?.expiresAt;
  bool saving = false;
  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = widget.store.state.assets.where((x) => !x.archived).toList();
    if (linkedAssetId != null && !assets.any((a) => a.id == linkedAssetId)) {
      linkedAssetId = null;
    }
    return AppPage(
      appBar: const AppHeader(),
      children: [
        PageHeading(
            widget.existing == null
                ? 'New document record'
                : 'Edit document record',
            subtitle:
                'Capture references and renewal dates. Attachments are managed from the detail page after saving.'),
        Form(
            key: key,
            child: Column(children: [
              FormFieldBlock(
                  title: 'Document name',
                  child: TextFormField(
                      controller: title,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: const InputDecoration(
                          hintText: 'e.g. Property insurance certificate'))),
              FormFieldBlock(
                  title: 'Category',
                  child: DropdownButtonFormField<String>(
                      initialValue: category,
                      items: ['Property', 'Investment', 'Insurance', 'Identity', 'Other']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) => setState(() => category = v ?? category))),
              FormFieldBlock(
                  title: 'Related asset (optional)',
                  child: DropdownButtonFormField<String?>(
                      initialValue: linkedAssetId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('No linked asset')),
                        ...assets.map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis)))
                      ],
                      onChanged: (v) => setState(() => linkedAssetId = v))),
              FormFieldBlock(
                  title: 'Issue date',
                  child: SoftCard(
                      onTap: () async {
                        // Issue dates are always in the past: a document
                        // can't have been issued tomorrow. Clamp the picker
                        // so an accidental tap into next year is impossible.
                        final today = DateTime.now();
                        final v = await showDatePicker(
                            context: context,
                            initialDate: issued ?? today,
                            firstDate: DateTime(1950),
                            lastDate: today);
                        if (v != null) setState(() => issued = v);
                      },
                      child: Row(children: [
                        const Icon(Icons.event_outlined, color: LG.sage),
                        const SizedBox(width: 10),
                        Text(issued == null
                            ? 'Choose issue date'
                            : LG.date(issued!)),
                        const Spacer(),
                        if (issued != null)
                          IconButton(
                              tooltip: 'Clear issue date',
                              onPressed: () => setState(() => issued = null),
                              icon: const Icon(Icons.close,
                                  color: LG.muted, size: 18)),
                      ]))),
              FormFieldBlock(
                  title: 'Expiry or renewal date',
                  child: SoftCard(
                      onTap: () async {
                        final v = await showDatePicker(
                            context: context,
                            initialDate: expires ?? DateTime.now(),
                            firstDate: DateTime(1950),
                            lastDate: DateTime(2100));
                        if (v != null) setState(() => expires = v);
                      },
                      child: Row(children: [
                        const Icon(Icons.event_available_outlined,
                            color: LG.sage),
                        const SizedBox(width: 10),
                        Text(expires == null
                            ? 'No expiry set'
                            : LG.date(expires!)),
                        const Spacer(),
                        if (expires != null)
                          IconButton(
                              tooltip: 'Clear expiry',
                              onPressed: () => setState(() => expires = null),
                              icon: const Icon(Icons.close,
                                  color: LG.muted, size: 18)),
                      ]))),
              FormFieldBlock(
                  title: 'Notes (optional)',
                  child: TextFormField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          hintText:
                              'Storage location or renewal instructions (no secrets)'))),
            ])),
        PrimaryCTA(
          label: saving ? 'Saving…' : 'Save document record',
          loading: saving,
          onPressed: () async {
            if (!key.currentState!.validate()) return;
            if (issued != null &&
                expires != null &&
                expires!.isBefore(issued!)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Expiry cannot precede issue date')));
              return;
            }
            if (issued != null && issued!.isAfter(DateTime.now())) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Issue date cannot be in the future')));
              return;
            }
            setState(() => saving = true);
            try {
              final record = DocumentRecord(
                  id: widget.existing?.id ?? makeId(),
                  title: title.text.trim(),
                  category: category,
                  linkedAssetId: linkedAssetId,
                  issuedAt: issued,
                  expiresAt: expires,
                  notes: notes.text.trim(),
                  attachment: widget.existing?.attachment);
              await widget.store.upsertDocument(record);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$e')));
            } finally {
              if (mounted) setState(() => saving = false);
            }
          },
        ),
        const SizedBox(height: 18),
        const Text(
            'Attachments, previews and removal live on the document detail page. Metadata captured here stays on this device only.',
            style: TextStyle(fontSize: 12, color: LG.muted, height: 1.5)),
      ],
    );
  }
}

class BeneficiariesScreen extends StatelessWidget {
  final PortfolioStore store;
  const BeneficiariesScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
    final people=store.state.beneficiaries;
    final total=people.fold<int>(0,(s,p)=>s+p.intendedShareBps);
    return WealthPage(title:'Legacy planning',subtitle:'Organise intended beneficiaries and trusted contacts.',children:[
      const SoftCard(color:LG.sageSoft,child:Row(children:[
        Icon(Icons.shield_outlined,color:LG.sage,size:26),SizedBox(width:12),
        Expanded(child:Text('Planning notes only. These records do not grant access, transfer property or replace a valid will or formal beneficiary nomination.',
          style:TextStyle(color:LG.muted,fontSize:12,height:1.5)))])),
      const SizedBox(height:22),
      SoftCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('INTENDED ALLOCATION',style:TextStyle(color:LG.sage,fontWeight:FontWeight.w800,fontSize:11,letterSpacing:1.1)),
        const SizedBox(height:8),Text('${(total/100).toStringAsFixed(0)}% planned',
          style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),LinearProgressIndicator(value:(total/10000).clamp(0.0,1.0).toDouble(),
          color:LG.gold,backgroundColor:LG.sageSoft,minHeight:8,borderRadius:BorderRadius.circular(8)),
        const SizedBox(height:8),const Text('Percentages are non-binding intentions, not a legal division of assets.',
          style:TextStyle(color:LG.muted,fontSize:11)),
      ])),const SizedBox(height:22),SectionTitle('Beneficiaries (${people.length})'),
      if(people.isEmpty)const EmptySection(title:'No intended beneficiaries',detail:'Create a planning entry. Avoid sensitive identification numbers in this preview.')
      else ...people.map((p)=>Padding(padding:const EdgeInsets.only(bottom:9),
        child:SoftCard(onTap:()=>openWealthPage(context,BeneficiaryFormScreen(store:store,existing:p)),child:Row(children:[
          const CircleAvatar(backgroundColor:LG.sageSoft,child:Icon(Icons.person_outline,color:LG.sage)),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(p.name,style:const TextStyle(fontWeight:FontWeight.w800)),
            Text(p.relationship,style:const TextStyle(color:LG.muted,fontSize:12)),
          ])),
          Text('${(p.intendedShareBps/100).toStringAsFixed(0)}%',
            style:const TextStyle(color:LG.sage,fontWeight:FontWeight.w800)),
          const Icon(Icons.chevron_right,color:LG.muted),
        ])))),
      const SizedBox(height:14),
      ElevatedButton.icon(onPressed:()=>openWealthPage(context,BeneficiaryFormScreen(store:store)),
        icon:const Icon(Icons.add),label:const Text('Add planning entry')),
      const SizedBox(height:20),const SectionTitle('Other continuity records'),
      SoftCard(onTap:()=>openWealthPage(context,LegacyScreen(store:store)),child:const Row(children:[
        Icon(Icons.people_outline,color:LG.sage),SizedBox(width:12),
        Expanded(child:Text('Trusted contacts',style:TextStyle(fontWeight:FontWeight.w700))),
        Icon(Icons.chevron_right,color:LG.muted),
      ])),
      const SizedBox(height:10),
      SoftCard(onTap:()=>openWealthPage(context,DocumentsScreen(store:store)),child:const Row(children:[
        Icon(Icons.folder_outlined,color:LG.sage),SizedBox(width:12),
        Expanded(child:Text('Document records',style:TextStyle(fontWeight:FontWeight.w700))),
        Icon(Icons.chevron_right,color:LG.muted),
      ])),
    ]);
  });
}

class BeneficiaryFormScreen extends StatefulWidget {
  final PortfolioStore store; final BeneficiaryRecord? existing;
  const BeneficiaryFormScreen({super.key,required this.store,this.existing});
  @override State<BeneficiaryFormScreen> createState()=>_BeneficiaryFormScreenState();
}
class _BeneficiaryFormScreenState extends State<BeneficiaryFormScreen> {
  final key=GlobalKey<FormState>();
  late final name=TextEditingController(text:widget.existing?.name??'');
  late final relation=TextEditingController(text:widget.existing?.relationship??'');
  late final share=TextEditingController(text:((widget.existing?.intendedShareBps??0)/100).toStringAsFixed(0));
  late final notes=TextEditingController(text:widget.existing?.notes??'');
  @override void dispose(){for(final c in [name,relation,share,notes]){c.dispose();}super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BrandMark(height:28)),
    body:SafeArea(child:Form(key:key,child:ListView(padding:const EdgeInsets.all(24),children:[
      PageHeading(widget.existing==null?'New legacy note':'Edit legacy note',
        subtitle:'Record an intention without granting anyone account access.'),
      FormFieldBlock(title:'Name',child:TextFormField(controller:name,validator:(v)=>v==null||v.trim().isEmpty?'Required':null)),
      FormFieldBlock(title:'Relationship',child:TextFormField(controller:relation,validator:(v)=>v==null||v.trim().isEmpty?'Required':null)),
      FormFieldBlock(title:'Intended share (%)',help:'All planned beneficiary shares combined must not exceed 100%.',
        child:TextFormField(controller:share,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          validator:(v){final n=double.tryParse(v??'');return n==null||n<0||n>100?'Enter 0–100%':null;})),
      FormFieldBlock(title:'Planning notes',child:TextFormField(controller:notes,maxLines:3)),
      const SizedBox(height:10),
      ElevatedButton(onPressed:()async{
        if(!key.currentState!.validate())return;
        try{
          await widget.store.upsertBeneficiary(BeneficiaryRecord(id:widget.existing?.id??makeId(),
            name:name.text.trim(),relationship:relation.text.trim(),
            intendedShareBps:(double.parse(share.text)*100).round(),notes:notes.text.trim()));
          if(context.mounted)Navigator.pop(context);
        }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
      },child:const Text('Save planning note')),
      if(widget.existing!=null)...[const SizedBox(height:12),
        TextButton(onPressed:()async{
          await widget.store.deleteBeneficiary(widget.existing!.id);
          if(context.mounted)Navigator.pop(context);
        },child:const Text('Remove planning note',style:TextStyle(color:LG.negative)))],
      const SizedBox(height:14),const Text('Consult a qualified adviser for enforceable nominations or succession documents.',
        style:TextStyle(color:LG.muted,fontSize:12,height:1.5)),
    ]))));
}

enum LocalAlertSource { reminder, documentExpiry, staleValuation }

class LocalAlert {
  final LocalAlertSource source;
  final String sourceId;
  final String title;
  final String detail;
  final IconData icon;
  final bool urgent;
  final DateTime occurrence;
  const LocalAlert({
    required this.source,
    required this.sourceId,
    required this.title,
    required this.detail,
    required this.icon,
    required this.urgent,
    required this.occurrence,
  });
}

/// Composes a dismissal key the way `buildLocalAlerts` does — exported so
/// the UI can dismiss the exact same alert it's currently showing.
String localAlertKey(LocalAlertSource source, String sourceId, DateTime occurrence) {
  return '${source.name}:$sourceId:${occurrence.toIso8601String()}';
}

List<LocalAlert> buildLocalAlerts(PortfolioState state, DateTime now) {
  final out = <LocalAlert>[];
  bool isDismissed(LocalAlertSource s, String id, DateTime occ) =>
      state.dismissedAlertKeys.contains(localAlertKey(s, id, occ));
  if (state.notificationOptions.upcomingReminders) {
    for (final r in state.reminders.where((x) => !x.completed)) {
      final delta = r.dueAt.difference(now).inDays;
      if (delta <= 30) {
        if (isDismissed(LocalAlertSource.reminder, r.id, r.dueAt)) continue;
        out.add(LocalAlert(
          source: LocalAlertSource.reminder,
          sourceId: r.id,
          title: r.title,
          detail: delta < 0 ? 'Overdue · ${LG.date(r.dueAt)}' : 'Due ${LG.date(r.dueAt)}',
          icon: Icons.notifications_none_rounded,
          urgent: delta < 0,
          occurrence: r.dueAt,
        ));
      }
    }
  }
  if (state.notificationOptions.expiringDocuments) {
    for (final d in state.documents.where((x) => !x.archived && x.expiresAt != null)) {
      final delta = d.expiresAt!.difference(now).inDays;
      if (delta <= 60) {
        if (isDismissed(LocalAlertSource.documentExpiry, d.id, d.expiresAt!)) continue;
        out.add(LocalAlert(
          source: LocalAlertSource.documentExpiry,
          sourceId: d.id,
          title: d.title,
          detail: delta < 0 ? 'Record expired' : 'Renew by ${LG.date(d.expiresAt!)}',
          icon: Icons.description_outlined,
          urgent: delta < 0,
          occurrence: d.expiresAt!,
        ));
      }
    }
  }
  if (state.notificationOptions.staleValuations) {
    for (final a in state.assets.where((x) => !x.archived)) {
      if (now.difference(a.valuedAt).inDays > 365) {
        if (isDismissed(LocalAlertSource.staleValuation, a.id, a.valuedAt)) continue;
        out.add(LocalAlert(
          source: LocalAlertSource.staleValuation,
          sourceId: a.id,
          title: a.name,
          detail: 'Recorded value is more than 12 months old',
          icon: Icons.update_rounded,
          urgent: false,
          occurrence: a.valuedAt,
        ));
      }
    }
  }
  return out..sort((a, b) => a.occurrence.compareTo(b.occurrence));
}

class NotificationsCenterScreen extends StatelessWidget {
  final PortfolioStore store;
  const NotificationsCenterScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final alerts = buildLocalAlerts(store.state, DateTime.now());
        return WealthPage(
            title: 'Notifications',
            subtitle: 'Useful reminders from your local wealth records.',
            children: [
              Row(children: [
                Expanded(
                    child: Text('${alerts.length} items',
                        style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(
                    onPressed: () => openWealthPage(
                        context, NotificationPreferencesScreen(store: store)),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Preferences')),
              ]),
              const SizedBox(height: 12),
              if (alerts.isEmpty)
                const AppEmptyState(
                    title: 'You are up to date',
                    detail:
                        'Upcoming reminders, document renewals and stale valuations will appear here.',
                    icon: Icons.notifications_none_rounded)
              else
                ...alerts.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Semantics(
                        label: '${a.title}, ${a.detail}',
                        button: true,
                        child: SoftCard(
                          onTap: () => openWealthPage(
                              context,
                              NotificationDetailScreen(store: store, alert: a)),
                          child: Row(children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: a.urgent
                                        ? const Color(0xFFF8EAE7)
                                        : LG.sageSoft,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Icon(a.icon,
                                    color: a.urgent ? LG.negative : LG.sage)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(a.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(a.detail,
                                      style: const TextStyle(
                                          color: LG.muted, fontSize: 12)),
                                ])),
                            IconButton(
                                tooltip: 'Dismiss',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded,
                                    color: LG.muted, size: 20),
                                onPressed: () async {
                                  final messenger =
                                      ScaffoldMessenger.maybeOf(context);
                                  await store.dismissAlert(localAlertKey(
                                      a.source, a.sourceId, a.occurrence));
                                  messenger?.showSnackBar(const SnackBar(
                                      content: Text('Alert dismissed')));
                                }),
                            const Icon(Icons.chevron_right, color: LG.muted),
                          ]),
                        ),
                      ),
                    )),
              const SizedBox(height: 22),
              const Text(
                  'Tap an alert to see its origin record. OS-level scheduling is wired via flutter_local_notifications when the platform permits it; this list always stays in sync with your state.',
                  style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5)),
            ]);
      });
}

class NotificationDetailScreen extends StatelessWidget {
  final PortfolioStore store;
  final LocalAlert alert;
  const NotificationDetailScreen(
      {super.key, required this.store, required this.alert});
  @override
  Widget build(BuildContext context) => WealthPage(
        title: 'Alert',
        subtitle: alert.title,
        children: [
          SoftCard(
              color: alert.urgent ? const Color(0xFFF8EAE7) : LG.sageSoft,
              child: Row(children: [
                Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: LG.white,
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(alert.icon,
                        color: alert.urgent ? LG.negative : LG.sage)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_sourceLabel(alert.source),
                          style: const TextStyle(
                              color: LG.sage,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(alert.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18)),
                    ])),
                StatusChip(
                    label: alert.urgent ? 'Needs attention' : 'Upcoming',
                    tone: alert.urgent ? StatusTone.danger : StatusTone.info),
              ])),
          const SizedBox(height: 18),
          SoftCard(
              child: Column(children: [
            InfoLabel(label: 'When', value: LG.date(alert.occurrence)),
            InfoLabel(label: 'Detail', value: alert.detail),
            InfoLabel(label: 'Source', value: _sourceLabel(alert.source)),
          ])),
          const SizedBox(height: 22),
          PrimaryCTA(
            label: 'Open source record',
            showArrow: false,
            onPressed: () async => _openSource(context),
          ),
          const SizedBox(height: 10),
          TextButton(
              onPressed: () => openWealthPage(
                  context, NotificationPreferencesScreen(store: store)),
              child: const Text('Adjust alert preferences',
                  style: TextStyle(color: LG.muted))),
          const SizedBox(height: 16),
          const Text(
              'Alerts are derived from your state. If you dislike a specific alert, change the trigger (mark the reminder complete, archive the document, record a fresh valuation) or disable the category from preferences.',
              style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5)),
        ],
      );

  Future<void> _openSource(BuildContext context) async {
    switch (alert.source) {
      case LocalAlertSource.reminder:
        openWealthPage(context, RemindersScreen(store: store));
      case LocalAlertSource.documentExpiry:
        final doc = store.state.documents.firstWhere(
            (d) => d.id == alert.sourceId,
            orElse: () => DocumentRecord(
                id: alert.sourceId,
                title: alert.title,
                category: 'Other',
                archived: true));
        openWealthPage(context, DocumentDetailScreen(store: store, document: doc));
      case LocalAlertSource.staleValuation:
        final asset = store.state.assets.firstWhere(
            (a) => a.id == alert.sourceId,
            orElse: () => WealthAsset(
                id: alert.sourceId,
                name: alert.title,
                kind: AssetKind.other,
                valueUgx: 0,
                valuedAt: DateTime(1970)));
        openWealthPage(context, ValuationHistoryScreen(store: store, asset: asset));
    }
  }

  static String _sourceLabel(LocalAlertSource s) => switch (s) {
        LocalAlertSource.reminder => 'Reminder',
        LocalAlertSource.documentExpiry => 'Document renewal',
        LocalAlertSource.staleValuation => 'Stale valuation',
      };
}

class NotificationPreferencesScreen extends StatelessWidget {
  final PortfolioStore store;
  const NotificationPreferencesScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
    final options=store.state.notificationOptions;
    return WealthPage(title:'Alert preferences',subtitle:'Choose which local reminders appear in your inbox.',children:[
      SoftCard(child:Column(children:[
        SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,title:const Text('Upcoming reminders'),
          subtitle:const Text('Tasks due in the next 30 days'),
          value:options.upcomingReminders,activeTrackColor:LG.sageSoft,
          onChanged:(v)=>store.updateNotificationOptions(options.copyWith(upcomingReminders:v))),
        const Divider(),
        SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,title:const Text('Document expirations'),
          subtitle:const Text('Renewals due within 60 days'),
          value:options.expiringDocuments,activeTrackColor:LG.sageSoft,
          onChanged:(v)=>store.updateNotificationOptions(options.copyWith(expiringDocuments:v))),
        const Divider(),
        SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,title:const Text('Stale asset values'),
          subtitle:const Text('Valuations older than one year'),
          value:options.staleValuations,activeTrackColor:LG.sageSoft,
          onChanged:(v)=>store.updateNotificationOptions(options.copyWith(staleValuations:v))),
      ])),const SizedBox(height:18),
      const SoftCard(color:LG.sageSoft,child:Text(
        'Preferences apply only to the on-screen notification center. No system notifications, SMS or email are sent.',
        style:TextStyle(color:LG.muted,fontSize:12,height:1.5))),
    ]);
  });
}

class ProfileScreen extends StatefulWidget {
  final PortfolioStore store;
  const ProfileScreen({super.key,required this.store});
  @override State<ProfileScreen> createState()=>_ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
  late final name=TextEditingController(text:widget.store.state.ownerName);
  final key=GlobalKey<FormState>();
  @override void dispose(){name.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>WealthPage(title:'Portfolio profile',
    subtitle:'The local profile name shown on your device.',children:[
    const SoftCard(color:LG.sageSoft,child:Text(
      'This is not an authenticated online identity. Do not enter official identity numbers or sensitive credentials.',
      style:TextStyle(color:LG.muted,fontSize:12,height:1.5))),
    const SizedBox(height:26),Form(key:key,child:Column(children:[
      FormFieldBlock(title:'Portfolio owner / display name',child:TextFormField(controller:name,
        validator:(v)=>v==null||v.trim().length<2?'Enter at least 2 characters':null)),
      const SizedBox(height:8),ElevatedButton(onPressed:()async{
        if(!key.currentState!.validate())return;
        await widget.store.setOwner(name.text);
        if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Profile updated')));
      },child:const Text('Save profile')),
    ])),const SizedBox(height:24),
    const SectionTitle('Account status'),
    const SoftCard(child:Column(children:[
      InfoLabel(label:'Account mode',value:'On-device preview'),
      InfoLabel(label:'Email verification',value:'Not connected'),
      InfoLabel(label:'Cloud sync',value:'Not available'),
    ])),
  ]);
}

class SecurityCenterScreen extends StatelessWidget {
  final PortfolioStore store;
  const SecurityCenterScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:store,builder:(context,_){
    final encryptionOn=store.vault.hasPassphrase;
    final biometricLinked=store.vault.hasBiometricStash;
    return WealthPage(
      title:'Security & privacy',subtitle:'The protection currently active on this device.',children:[
      SoftCard(color:encryptionOn?LG.sageSoft:LG.white,child:Row(children:[
        Icon(encryptionOn?Icons.shield:Icons.shield_outlined,
          color:encryptionOn?LG.sage:LG.muted,size:30),const SizedBox(width:14),
        Expanded(child:Text(encryptionOn
          ?'Your vault is encrypted on this device with AES-GCM 256 under a passphrase-derived key.'
          :'Your portfolio is stored in cleartext on this device. Enable a passphrase to protect it.',
          style:const TextStyle(fontSize:12,color:LG.muted,height:1.5)))])),
      const SizedBox(height:22),const SectionTitle('Security readiness'),
      SoftCard(child:Column(children:[
        InfoLabel(label:'Passphrase lock',
          value:encryptionOn?'Enabled':'Not set',
          valueColor:encryptionOn?LG.sage:LG.muted),
        InfoLabel(label:'Biometric unlock',
          value:biometricLinked?'Linked':'Not linked',
          valueColor:biometricLinked?LG.sage:LG.muted),
        const InfoLabel(label:'Encryption algorithm',value:'AES-GCM 256'),
        const InfoLabel(label:'Key derivation',value:'PBKDF2-HMAC-SHA256 · 120,000 rounds'),
        const InfoLabel(label:'Cloud backup',value:'Not connected'),
        const InfoLabel(label:'Multi-device sync',value:'Not connected'),
        const InfoLabel(label:'Data import / export',value:'Manual JSON (unencrypted)'),
      ])),
      const SizedBox(height:18),
      ElevatedButton.icon(onPressed:()=>openWealthPage(context,EncryptionSetupScreen(store:store)),
        icon:Icon(encryptionOn?Icons.manage_accounts:Icons.lock),
        label:Text(encryptionOn?'Manage encryption':'Enable encryption')),
      const SizedBox(height:10),
      OutlinedButton.icon(onPressed:()=>openWealthPage(context,SettingsScreen(store:store)),
        icon:const Icon(Icons.settings_backup_restore),label:const Text('Data management settings')),
      const SizedBox(height:10),
      // Online privacy (data-subject rights, erasure, export) belongs on the
      // security surface: a user looking for "how do I delete my data" starts
      // here, not under Account. Only surface the entry when the device has
      // an online session configured — otherwise the screen has nothing to
      // show.
      Builder(builder:(context){
        final scope=OnlineScope.maybeOf(context);
        final remote=scope?.sync;
        final baseUri=remote?.baseUri;
        if(baseUri==null||scope==null||remote==null)return const SizedBox.shrink();
        return Column(children:[
          OutlinedButton.icon(
            onPressed:()=>openWealthPage(context,OnlinePrivacyScreen(
              baseUri:baseUri,
              credentials:scope.credentials)),
            icon:const Icon(Icons.policy_outlined),
            label:const Text('Online privacy & data rights')),
          const SizedBox(height:10),
          OutlinedButton.icon(
            onPressed:()=>openWealthPage(context,TransparencyScreen(sync:remote)),
            icon:const Icon(Icons.verified_outlined),
            label:const Text('Audit transparency')),
        ]);
      }),
      const SizedBox(height:18),const Text(
        'This device is the only place holding your passphrase or derived key — there is no server-side recovery. Keep an unencrypted JSON export in a safe physical location.',
        style:TextStyle(color:LG.muted,fontSize:12,height:1.55)),
    ]);
  });
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = OnlineScope.maybeOf(context);
    final remote = scope?.sync;
    // Backend not configured → show the honest "payments not connected"
    // panel so the user never thinks a subscription might exist silently.
    if (remote == null) return const _SubscriptionDesignPreview();
    return FutureBuilder<RemoteSubscription>(
      future: remote.getSubscription(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const WealthPage(
              title: 'Subscription & billing',
              subtitle: 'Fetching current tier from the backend.',
              children: [LoadingState(message: 'Loading subscription')]);
        }
        if (snap.hasError) {
          return WealthPage(
              title: 'Subscription & billing',
              subtitle: 'Could not reach the billing service.',
              children: [
                ErrorState(
                    message: '${snap.error}',
                    onRetry: () async {
                      (context as Element).markNeedsBuild();
                    }),
              ]);
        }
        final sub = snap.data!;
        return WealthPage(
          title: 'Subscription & billing',
          subtitle: 'Current tier on this account.',
          children: [
            SoftCard(
              color: sub.status == 'active' ? LG.sageSoft : LG.white,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_tierLabel(sub.tier),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Status: ${sub.status}',
                    style: const TextStyle(color: LG.muted, fontSize: 12)),
                if (sub.currentPeriodEnd != null) ...[
                  const SizedBox(height: 4),
                  Text('Renews ${LG.date(sub.currentPeriodEnd!)}',
                      style: const TextStyle(color: LG.muted, fontSize: 12)),
                ],
                if (sub.provider != null) ...[
                  const SizedBox(height: 4),
                  Text('Provider: ${sub.provider}',
                      style: const TextStyle(color: LG.muted, fontSize: 12)),
                ],
              ]),
            ),
            const SizedBox(height: 22),
            const SectionTitle('What this tier covers'),
            SoftCard(
                child: Column(children: [
              InfoLabel(
                  label: 'Attachment quota',
                  value: _quotaLabel(sub.tier)),
              const InfoLabel(
                  label: 'Multi-device sync', value: 'Included'),
              const InfoLabel(
                  label: 'Audit trail + anchors', value: 'Included'),
              InfoLabel(
                  label: 'Bank-feed aggregation',
                  value: sub.tier == 'free' ? 'Not included' : 'Included'),
            ])),
            const SizedBox(height: 22),
            const Text(
                'Changes take effect at the start of the next billing period. Payment provider interactions remain subject to local law.',
                style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5)),
          ],
        );
      },
    );
  }

  static String _tierLabel(String tier) {
    switch (tier) {
      case 'legacy':
        return 'Legacy';
      case 'heritage':
        return 'Heritage';
      default:
        return 'Free';
    }
  }

  static String _quotaLabel(String tier) {
    switch (tier) {
      case 'legacy':
        return '10 GB';
      case 'heritage':
        return '2 GB';
      default:
        return '100 MB';
    }
  }
}

/// The original hard-coded panel. Still shown when the device was built
/// without a backend URL so the user is never misled about what the
/// preview can actually do.
class _SubscriptionDesignPreview extends StatelessWidget {
  const _SubscriptionDesignPreview();
  @override
  Widget build(BuildContext context) => const WealthPage(
          title: 'Subscription & billing',
          subtitle: 'How LonyoGang will offer ongoing access.',
          children: [
            SoftCard(
                color: LG.sageSoft,
                child: Row(children: [
                  Icon(Icons.info_outline, color: LG.sage),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          'Payments are not connected in this preview. No subscription or charge has been created.',
                          style: TextStyle(
                              color: LG.muted, fontSize: 12, height: 1.5))),
                ])),
            SizedBox(height: 22),
            SectionTitle('Planned personal portfolio access'),
            SoftCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Personal wealth tracking',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 12),
                  InfoLabel(label: 'Owner', value: 'One personal portfolio'),
                  InfoLabel(
                      label: 'Assets & net worth',
                      value: 'Included in design'),
                  InfoLabel(
                      label: 'Properties & savings',
                      value: 'Included in design'),
                  InfoLabel(
                      label: 'Legacy planning',
                      value: 'Included in design'),
                  InfoLabel(label: 'Billing price', value: 'Not finalized'),
                  InfoLabel(
                      label: 'Payment service', value: 'Not available'),
                ])),
            SizedBox(height: 22),
            Text(
                'Prices, billing cycles, eligibility and cancellation terms must be approved before paid subscriptions can be offered.',
                style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5)),
          ]);
}

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});
  @override State<HelpCenterScreen> createState()=>_HelpCenterScreenState();
}
class _HelpCenterScreenState extends State<HelpCenterScreen> {
  @override Widget build(BuildContext context)=>WealthPage(title:'Help & guidance',
    subtitle:'Answers to common questions about the portfolio.',children:[
    SoftCard(child:Column(children:[
      for(final qa in <(String,String)>[
        ('How is net worth calculated?','Net worth equals your attributable recorded assets minus all active liabilities, including any linked mortgage just once.'),
        ('Are property values verified?','No. Values are manually entered and tagged with dates and source information.'),
        ('Does LonyoGang hold my money?','No. It is a tracking and personal record-keeping application, not a bank or broker.'),
        ('What does the Stale badge mean on an asset?','The recorded valuation is more than 12 months old. Record a fresh valuation to clear the flag; the old history is kept for TWR and XIRR.'),
        ('How do TWR and XIRR differ?','Time-weighted return (TWR) uses only your dated valuations, so contributions and withdrawals do not distort it. XIRR folds contributions, distributions and the current value together, giving a money-weighted return. Both appear on the Performance screen for each asset.'),
        ('What is the target allocation screen for?','Set a target weight for each asset in basis points (100% = 10,000 bps). Drift shows how far actual holdings are from the plan without changing any value.'),
        ('Can I attach files to a document record?','Yes. Open a document, tap Attach encrypted file. The file is AES-GCM encrypted under your vault key (or a per-file key if you have not set a passphrase) and SHA-256 verified on every read.'),
        ('What does enabling encryption actually protect?','We derive an AES-GCM 256 key from your passphrase with PBKDF2-HMAC-SHA-256 (120k iterations). The portfolio payload on disk is then ciphertext. Biometric unlock stores a device-scoped wrap of the passphrase for faster entry; it is additive, not a replacement.'),
        ('What happens if I forget my passphrase?','This preview has no server-side recovery. The encrypted data on this device cannot be unlocked. Keep an unencrypted JSON export (Settings → Export) in a safe place, or use the demo portfolio until you are ready for real values.'),
        ('How do scheduled contributions work?','Each schedule has a next-fire date and a frequency. Tap Post now to append a normal ledger contribution and advance the next-fire date. Reversals still work on the posted entries.'),
        ('Can I transfer assets to beneficiaries?','No. Legacy planning entries are non-binding notes and cannot transfer ownership.'),
        ('How do I start over on this device?','Settings → Reset portfolio wipes every record, deletes encrypted attachments and disables the passphrase. There is no undo, so export first if you want a backup.'),
      ])ExpansionTile(title:Text(qa.$1,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:14)),
        iconColor:LG.sage,collapsedIconColor:LG.muted,tilePadding:EdgeInsets.zero,
        childrenPadding:const EdgeInsets.only(bottom:16),
        children:[Align(alignment:Alignment.centerLeft,child:Text(qa.$2,
          style:const TextStyle(color:LG.muted,fontSize:13,height:1.5)))]),
    ])),const SizedBox(height:20),
    OutlinedButton.icon(onPressed:()async{
      await Clipboard.setData(const ClipboardData(text:'LonyoGang Heritage preview feedback'));
      if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Feedback subject copied. Use your preferred support channel.')));}
    },icon:const Icon(Icons.copy_outlined),label:const Text('Copy feedback subject')),
  ]);
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override Widget build(BuildContext context)=>const WealthPage(title:'About LonyoGang',
    subtitle:'Your wealth and what it means for tomorrow.',children:[
    Center(child:BrandMark(height:58)),SizedBox(height:26),
    SoftCard(child:Text(
      'LonyoGang combines the Acholi words Lonyo (wealth) and Gang (home). The traditional granary symbolizes stewardship, family assets and lasting heritage.',
      style:TextStyle(fontSize:14,height:1.65))),
    SizedBox(height:18),SectionTitle('Product purpose'),
    SoftCard(child:Column(children:[
      InfoLabel(label:'Product',value:'LonyoGang Heritage'),
      InfoLabel(label:'Version',value:'0.3.0 preview'),
      InfoLabel(label:'Financial reporting',value:'UGX'),
      InfoLabel(label:'Main use',value:'Personal wealth records'),
    ])),SizedBox(height:18),
    Text('The app does not provide custody, investments, financial advice, property conveyancing or legal estate services.',
      style:TextStyle(color:LG.muted,fontSize:12,height:1.5)),
  ]);
}

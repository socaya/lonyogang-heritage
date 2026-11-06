import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import '../state/wealth_store.dart';
import 'components.dart';
import 'reports.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.store});
  final WealthStore store;
  @override
  Widget build(BuildContext context) => LgPage(title: 'More',
    subtitle: 'Organise your wealth, obligations and financial legacy.',
    children: [
      SoftCard(color: LG.sageSoft, child: Row(children: [
        CircleAvatar(backgroundColor: LG.white,
          child: Text(Fmt.initials(store.profile?.name ?? '?'),
            style: const TextStyle(color: LG.sageDark, fontWeight: FontWeight.w800))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(store.profile?.name ?? 'Your vault',
            style: const TextStyle(color: LG.navy, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(store.profile?.email.isEmpty ?? true ? 'Private local account' : store.profile!.email,
            style: const TextStyle(color: LG.muted, fontSize: 12)),
        ])),
      ])),
      const SizedBox(height: 27),
      const SectionHeading('Manage your wealth'),
      _entry(context, 'Liabilities & loans', Icons.credit_card_outlined,
        LiabilitiesScreen(store: store)),
      _entry(context, 'Transaction history', Icons.receipt_long_outlined,
        TransactionsScreen(store: store)),
      _entry(context, 'Beneficiaries & legacy', Icons.people_alt_outlined,
        LegacyScreen(store: store)),
      _entry(context, 'Documents vault', Icons.folder_copy_outlined,
        DocumentsScreen(store: store)),
      _entry(context, 'Reminders', Icons.event_note_outlined,
        RemindersScreen(store: store)),
      const SizedBox(height: 22),
      const SectionHeading('Account'),
      _entry(context, 'Settings & privacy', Icons.tune_rounded,
        SettingsScreen(store: store)),
      const SizedBox(height: 18),
      const InfoStrip(icon: Icons.lock_outline_rounded, title: 'Your wealth stays yours',
        body: 'This release operates locally with an encrypted vault. It does not connect to banks or execute financial transactions.'),
    ]);
  Widget _entry(BuildContext context, String title, IconData icon, Widget page) =>
    Padding(padding: const EdgeInsets.only(bottom: 9),
      child: SoftCard(onTap: () => Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => page)),
        child: Row(children: [
          Icon(icon, color: LG.sageDark, size: 22),
          const SizedBox(width: 13),
          Expanded(child: Text(title, style: const TextStyle(
            color: LG.navy, fontWeight: FontWeight.w700))),
          const Icon(Icons.chevron_right_rounded, color: LG.muted),
        ])));
}

class LegacyScreen extends StatelessWidget {
  const LegacyScreen({super.key, required this.store});
  final WealthStore store;
  @override
  Widget build(BuildContext context) => LgPage(
    title: 'Heritage & legacy', showBack: true,
    subtitle: 'Maintain private beneficiary and continuity records.',
    trailing: IconButton(onPressed: () => edit(context),
      icon: const Icon(Icons.person_add_alt_1_outlined), tooltip: 'Add beneficiary'),
    children: [
      const InfoStrip(icon: Icons.family_restroom_outlined,
        title: 'Your legacy matters',
        body: 'These private records help organise important contacts. They are not a will, legal nomination or ownership transfer.'),
      const SizedBox(height: 25),
      SectionHeading('Beneficiary contacts',
        trailing: Text('${store.beneficiaries.length}',
          style: const TextStyle(color: LG.muted))),
      if (store.beneficiaries.isEmpty)
        const EmptyHint(title: 'No contacts recorded',
          detail: 'Add trusted family or beneficiary contacts to your personal records.',
          icon: Icons.people_outline_rounded)
      else ...store.beneficiaries.map((b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(child: Row(children: [
          CircleAvatar(backgroundColor: LG.sageSoft,
            child: Text(Fmt.initials(b.name),
              style: const TextStyle(color: LG.sageDark, fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.name, style: const TextStyle(color: LG.navy,
              fontWeight: FontWeight.w800)),
            Text('${b.relationship} · ${b.contact}',
              style: const TextStyle(color: LG.muted, fontSize: 12)),
            Text(b.nominationConfirmed ? 'Nomination evidence recorded' : 'Contact only',
              style: const TextStyle(color: LG.sageDark, fontSize: 11.5)),
          ])),
          PopupMenuButton<String>(onSelected: (v) async {
            if (v == 'edit') { edit(context, b); return; }
            if (!await askConfirm(context, 'Remove contact?',
              'This contact will be deleted from the encrypted vault.')) return;
            try { await store.deleteBeneficiary(b.id); }
            catch (e) { if (context.mounted) showFailure(context, e); }
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ]),
        ])))),
      const SizedBox(height: 20),
      LgAction('Add beneficiary contact', onPressed: () => edit(context),
        icon: Icons.person_add_alt_outlined),
    ]);
  void edit(BuildContext context, [WealthBeneficiary? b]) =>
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => BeneficiaryEditor(store: store, existing: b)));
}

class BeneficiaryEditor extends StatefulWidget {
  const BeneficiaryEditor({super.key, required this.store, this.existing});
  final WealthStore store;
  final WealthBeneficiary? existing;
  @override
  State<BeneficiaryEditor> createState() => _BeneficiaryEditorState();
}
class _BeneficiaryEditorState extends State<BeneficiaryEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final relationship = TextEditingController();
  final contact = TextEditingController();
  final notes = TextEditingController();
  bool nominated = false, busy = false;
  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    name.text = b?.name ?? ''; relationship.text = b?.relationship ?? '';
    contact.text = b?.contact ?? ''; notes.text = b?.notes ?? '';
    nominated = b?.nominationConfirmed ?? false;
  }
  @override
  void dispose() { name.dispose(); relationship.dispose(); contact.dispose(); notes.dispose(); super.dispose(); }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.store.saveBeneficiary(WealthBeneficiary(
        id: widget.existing?.id ?? WealthStore.uuid.v4(), name: name.text.trim(),
        relationship: relationship.text.trim(), contact: contact.text.trim(),
        notes: notes.text.trim(), nominationConfirmed: nominated,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => LgPage(
    title: widget.existing == null ? 'Add legacy contact' : 'Edit legacy contact',
    showBack: true, subtitle: 'Private records, not legal appointment.',
    bottom: LgAction('Save contact', busy: busy, onPressed: busy ? null : save),
    children: [
      Form(key: form, child: Column(children: [
        LgInput(label: 'Full name', controller: name,
          validator: (s) => (s ?? '').trim().isEmpty ? 'Name required' : null),
        const SizedBox(height: 18),
        LgInput(label: 'Relationship', controller: relationship,
          hint: 'e.g. Child, spouse, trusted contact'),
        const SizedBox(height: 18),
        LgInput(label: 'Contact information', controller: contact,
          hint: 'Phone or email'),
        const SizedBox(height: 18),
        LgInput(label: 'Notes (optional)', controller: notes, maxLines: 4),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
          value: nominated, activeThumbColor: LG.sageDark,
          onChanged: (v) => setState(() => nominated = v),
          title: const Text('I have nomination evidence',
            style: TextStyle(color: LG.navy, fontWeight: FontWeight.w700)),
          subtitle: const Text('A personal record only; no official verification')),
        const SizedBox(height: 22),
        const InfoStrip(title: 'Legal arrangements are separate',
          body: 'Maintain legally valid nominations, wills and property documents through appropriate institutions.'),
      ])),
    ]);
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.store});
  final WealthStore store;
  @override
  Widget build(BuildContext context) => LgPage(title: 'Reminders', showBack: true,
    subtitle: 'Plan contributions, valuations, rent and payment dates.',
    trailing: IconButton(onPressed: () => edit(context),
      icon: const Icon(Icons.add_rounded), tooltip: 'Add reminder'),
    children: [
      const InfoStrip(icon: Icons.notifications_none_rounded,
        title: 'In-app reminders',
        body: 'Due dates are visible inside the app. System push notifications are not enabled in this offline release.'),
      const SizedBox(height: 22),
      if (store.reminders.isEmpty) const EmptyHint(title: 'No reminders',
        detail: 'Add a date you want to keep track of.')
      else ...store.reminders.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: SoftCard(color: r.done ? LG.surface : LG.white,
          child: Row(children: [
            Checkbox(value: r.done, activeColor: LG.sageDark, onChanged: (v) async {
              try {
                await store.saveReminder(WealthReminder(
                  id: r.id, title: r.title, dueAt: r.dueAt,
                  assetId: r.assetId, details: r.details, done: v ?? false));
              } catch (e) { if (context.mounted) showFailure(context, e); }
            }),
            const SizedBox(width: 7),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: TextStyle(color: LG.navy,
                decoration: r.done ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.w700)),
              Text(Fmt.date(r.dueAt), style: TextStyle(color: r.done
                ? LG.muted : (r.dueAt.isBefore(DateTime.now()) ? LG.danger : LG.sageDark),
                fontSize: 12)),
            ])),
            PopupMenuButton<String>(onSelected: (v) async {
              if (v == 'edit') { edit(context, r); return; }
              if (!await askConfirm(context, 'Delete reminder?',
                'Remove this date from your records?')) return;
              try { await store.deleteReminder(r.id); }
              catch (e) { if (context.mounted) showFailure(context, e); }
            }, itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ]),
          ])))),
      const SizedBox(height: 18),
      LgAction('Add reminder', onPressed: () => edit(context), icon: Icons.add_rounded),
    ]);
  void edit(BuildContext context, [WealthReminder? r]) => Navigator.push(
    context, MaterialPageRoute<void>(
      builder: (_) => ReminderEditor(store: store, existing: r)));
}

class ReminderEditor extends StatefulWidget {
  const ReminderEditor({super.key, required this.store, this.existing});
  final WealthStore store;
  final WealthReminder? existing;
  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final detail = TextEditingController();
  late DateTime due;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    title.text = widget.existing?.title ?? '';
    detail.text = widget.existing?.details ?? '';
    due = widget.existing?.dueAt ?? DateTime.now().add(const Duration(days: 7));
  }
  @override
  void dispose() { title.dispose(); detail.dispose(); super.dispose(); }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.store.saveReminder(WealthReminder(
        id: widget.existing?.id ?? WealthStore.uuid.v4(),
        title: title.text.trim(), details: detail.text.trim(), dueAt: due,
        assetId: widget.existing?.assetId ?? '', done: widget.existing?.done ?? false,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => LgPage(
    title: 'Reminder details', showBack: true, bottom:
      LgAction('Save reminder', onPressed: busy ? null : save, busy: busy),
    children: [Form(key: form, child: Column(children: [
      LgInput(label: 'Title', controller: title,
        hint: 'e.g. Review property insurance',
        validator: (s) => (s ?? '').trim().isEmpty ? 'Title required' : null),
      const SizedBox(height: 20),
      SoftCard(color: LG.sageSoft, child: Row(children: [
        const Icon(Icons.event_outlined, color: LG.sageDark),
        const SizedBox(width: 12),
        Expanded(child: Text(Fmt.date(due), style: const TextStyle(
          color: LG.navy, fontWeight: FontWeight.w700))),
        TextButton(onPressed: () async {
          final next = await showDatePicker(context: context, initialDate: due,
            firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (next != null) setState(() => due = next);
        }, child: const Text('Choose date')),
      ])),
      const SizedBox(height: 20),
      LgInput(label: 'Details (optional)', controller: detail, maxLines: 3),
    ]))]);
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.store});
  final WealthStore store;
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool busy = false;
  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final picked = await FilePicker.pickFiles(type: FileType.any,
        allowMultiple: false, withData: true);
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final Uint8List bytes = file.bytes ??
        (file.path == null ? Uint8List(0) : await File(file.path!).readAsBytes());
      if (bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
        throw StateError('File must be between 1 byte and 12 MB.');
      }
      final name = file.name;
      final mime = name.toLowerCase().endsWith('.pdf') ? 'application/pdf'
        : name.toLowerCase().endsWith('.jpg') || name.toLowerCase().endsWith('.jpeg')
        ? 'image/jpeg' : name.toLowerCase().endsWith('.png')
        ? 'image/png' : 'application/octet-stream';
      await widget.store.addDocument(WealthDocument(
        id: WealthStore.uuid.v4(), name: name, mime: mime,
        assetId: '', addedAt: DateTime.now(), byteCount: bytes.length,
      ), bytes);
    } catch (e) { if (mounted) showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> exportDocument(WealthDocument doc) async {
    final allow = await askConfirm(context, 'Share decrypted document?',
      'The chosen app will receive an unencrypted copy. Use only a destination you trust.',
      confirmLabel: 'Continue');
    if (!allow) return;
    try {
      final bytes = await widget.store.repo.documentBytes(doc.id);
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: doc.mime, name: doc.name)],
        fileNameOverrides: [doc.name],
        text: 'Document from my LonyoGang private vault.',
      ));
    } catch (e) { if (mounted) showFailure(context, e); }
  }

  @override
  Widget build(BuildContext context) => LgPage(
    title: 'Document vault', showBack: true,
    subtitle: 'Keep evidence, statements and title references inside encrypted storage.',
    trailing: IconButton(onPressed: busy ? null : pick,
      icon: const Icon(Icons.add_rounded), tooltip: 'Import document'),
    children: [
      const InfoStrip(icon: Icons.lock_outline_rounded,
        title: 'Encrypted at rest',
        body: 'Attachments are stored as encrypted SQLCipher records. Sharing exports a decrypted copy outside the vault.'),
      const SizedBox(height: 24),
      if (widget.store.documents.isEmpty)
        const EmptyHint(title: 'No documents stored',
          detail: 'Add a PDF, image, statement or supporting evidence from this device.',
          icon: Icons.folder_open_outlined)
      else ...widget.store.documents.map((d) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: SoftCard(child: Row(children: [
          const Icon(Icons.insert_drive_file_outlined, color: LG.sageDark),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: LG.navy, fontWeight: FontWeight.w700)),
            Text('${(d.byteCount / 1024).toStringAsFixed(1)} KB · ${Fmt.date(d.addedAt)}',
              style: const TextStyle(color: LG.muted, fontSize: 12)),
          ])),
          PopupMenuButton<String>(onSelected: (v) async {
            if (v == 'share') { await exportDocument(d); return; }
            if (!await askConfirm(context, 'Delete document?',
              'The encrypted attachment will be permanently removed from this device.')) return;
            try { await widget.store.deleteDocument(d.id); }
            catch (e) { if (context.mounted) showFailure(context, e); }
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'share', child: Text('Open / share copy')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ]),
        ])))),
      const SizedBox(height: 17),
      LgAction('Add document', onPressed: busy ? null : pick,
        busy: busy, icon: Icons.file_upload_outlined),
    ]);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});
  final WealthStore store;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  bool biometric = false, busy = false;
  @override
  void initState() {
    super.initState();
    name.text = widget.store.profile?.name ?? '';
    email.text = widget.store.profile?.email ?? '';
    widget.store.repo.isBiometricEnabled().then((v) {
      if (mounted) setState(() => biometric = v);
    });
  }
  @override
  void dispose() { name.dispose(); email.dispose(); super.dispose(); }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.store.updateProfile(name.text, email.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated in your encrypted vault.')));
    } catch (e) { if (mounted) showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }

  String _csv(String text) {
    // Prevent spreadsheet formula injection when exporting editable user strings.
    var safe = text.replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (RegExp(r'^[=+@\-]').hasMatch(safe)) safe = "'$safe";
    return '"${safe.replaceAll('"', '""')}"';
  }

  Future<void> exportCsv() async {
    if (!await askConfirm(context, 'Export a readable report?',
      'CSV files are not encrypted. Only share your personal financial data with destinations you trust.',
      confirmLabel: 'Export')) return;
    final out = StringBuffer('Record,Category,Name,Amount UGX,Date,Details\n');
    for (final a in widget.store.assets) {
      out.writeln('asset,${_csv(a.kind.label)},${_csv(a.name)},${a.valueUgx},${Fmt.date(a.valuedAt)},${_csv(sourceLabel(a.valuationSource))}');
    }
    for (final d in widget.store.debts) {
      out.writeln('liability,debt,${_csv(d.name)},-${d.balanceUgx},,${_csv(d.lender)}');
    }
    for (final e in widget.store.entries) {
      out.writeln('transaction,${_csv(e.type.name)},${_csv(e.category)},${e.amountUgx},${Fmt.date(e.occurredAt)},${_csv(e.notes)}');
    }
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(
          Uint8List.fromList(out.toString().codeUnits),
          name: 'lonyogang-wealth-export.csv', mimeType: 'text/csv')],
        fileNameOverrides: const ['lonyogang-wealth-export.csv'],
      ));
    } catch (e) { if (mounted) showFailure(context, e); }
  }

  Future<void> erase() async {
    final sure = await askConfirm(context, 'Erase your entire vault?',
      'Permanently deletes all records, encrypted documents and the local account from this device. This cannot be undone. Export your information first.',
      confirmLabel: 'Erase permanently');
    if (!sure) return;
    try {
      await widget.store.erase();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) { if (mounted) showFailure(context, e); }
  }

  @override
  Widget build(BuildContext context) => LgPage(title: 'Settings & privacy', showBack: true,
    subtitle: 'Control access, data exports and information held on this device.',
    children: [
      const SectionHeading('My profile'),
      LgInput(label: 'Full name', controller: name),
      const SizedBox(height: 18),
      LgInput(label: 'Email (not linked to cloud sign-in)', controller: email,
        keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 17),
      LgAction('Save profile', onPressed: busy ? null : save, busy: busy,
        icon: Icons.check_rounded),
      const SizedBox(height: 30),
      const SectionHeading('Account security'),
      SoftCard(child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero, value: biometric,
        activeThumbColor: LG.sageDark,
        title: const Text('Biometric unlocking',
          style: TextStyle(color: LG.navy, fontWeight: FontWeight.w800)),
        subtitle: const Text('Use enrolled biometrics to unlock the local vault.'),
        onChanged: (value) async {
          try {
            await widget.store.repo.setBiometrics(value);
            if (mounted) setState(() => biometric = value);
          } catch (e) { if (mounted) showFailure(context, e); }
        },
      )),
      const SizedBox(height: 10),
      SoftCard(onTap: () async {
        await widget.store.lock();
        if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
      }, child: const Row(children: [
        Icon(Icons.lock_outline_rounded, color: LG.sageDark),
        SizedBox(width: 13),
        Expanded(child: Text('Lock vault now', style: TextStyle(
          color: LG.navy, fontWeight: FontWeight.w700))),
        Icon(Icons.chevron_right_rounded, color: LG.muted),
      ])),
      const SizedBox(height: 27),
      const SectionHeading('Data & ownership'),
      SoftCard(onTap: exportCsv, child: const Row(children: [
        Icon(Icons.file_download_outlined, color: LG.sageDark),
        SizedBox(width: 13),
        Expanded(child: Text('Export my records (CSV)', style: TextStyle(
          color: LG.navy, fontWeight: FontWeight.w700))),
        Icon(Icons.chevron_right_rounded, color: LG.muted),
      ])),
      const SizedBox(height: 10),
      SoftCard(onTap: erase, child: const Row(children: [
        Icon(Icons.delete_forever_outlined, color: LG.danger),
        SizedBox(width: 13),
        Expanded(child: Text('Erase local vault', style: TextStyle(
          color: LG.danger, fontWeight: FontWeight.w700))),
        Icon(Icons.chevron_right_rounded, color: LG.danger),
      ])),
      const SizedBox(height: 26),
      const InfoStrip(icon: Icons.info_outline,
        title: 'What this release does not do',
        body: 'No bank sync, identity verification, cloud recovery, trading or paid subscription processing. Those require approved server services and compliance review.'),
      const SizedBox(height: 25),
      const Center(child: Text('LonyoGang Heritage · Offline private vault',
        style: TextStyle(color: LG.muted, fontSize: 12))),
    ]);
}

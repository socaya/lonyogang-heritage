import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import '../state/wealth_store.dart';
import 'components.dart';

Future<DateTime?> pickWealthDate(BuildContext context, DateTime initial) =>
  showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1950),
    lastDate: DateTime(2100), helpText: 'Select record date');

String? _validatePositive(String? text) {
  final n = Fmt.parseUgx(text ?? '');
  return n == null || n <= 0 ? 'Enter an amount greater than zero (UGX)' : null;
}

String? _validateNonNegative(String? text) {
  final n = Fmt.parseUgx(text ?? '');
  return n == null || n < 0 ? 'Enter a non-negative amount (UGX)' : null;
}

class AssetEditor extends StatefulWidget {
  const AssetEditor({super.key, required this.store,
    this.initialKind = AssetKind.investment, this.existing});
  final WealthStore store;
  final AssetKind initialKind;
  final WealthAsset? existing;
  @override
  State<AssetEditor> createState() => _AssetEditorState();
}

class _AssetEditorState extends State<AssetEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final amount = TextEditingController();
  final cost = TextEditingController();
  final ownership = TextEditingController();
  final institution = TextEditingController();
  final location = TextEditingController();
  final notes = TextEditingController();
  late AssetKind kind;
  late ValuationSource source;
  late DateTime acquired;
  late DateTime valued;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    kind = a?.kind ?? widget.initialKind;
    source = a?.valuationSource ?? ValuationSource.ownerEstimate;
    acquired = a?.acquiredAt ?? DateTime.now();
    valued = a?.valuedAt ?? DateTime.now();
    name.text = a?.name ?? '';
    amount.text = a?.valueUgx.toString() ?? '';
    cost.text = a?.costUgx.toString() ?? '0';
    ownership.text = a == null ? '100' : (a.ownershipBps / 100).toStringAsFixed(2);
    institution.text = a?.institution ?? '';
    location.text = a?.location ?? '';
    notes.text = a?.notes ?? '';
  }
  @override
  void dispose() {
    for (final c in [name, amount, cost, ownership, institution, location, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final pct = double.tryParse(ownership.text);
    if (pct == null || !pct.isFinite || pct <= 0 || pct > 100) {
      showFailure(context, 'Ownership must be greater than 0% and at most 100%.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.saveAsset(WealthAsset(
        id: widget.existing?.id ?? WealthStore.uuid.v4(),
        name: name.text.trim(), kind: kind,
        valueUgx: Fmt.parseUgx(amount.text)!,
        costUgx: Fmt.parseUgx(cost.text)!,
        ownershipBps: (pct * 100).round(),
        valuedAt: valued, valuationSource: source, acquiredAt: acquired,
        institution: institution.text.trim(),
        location: location.text.trim(), notes: notes.text.trim(),
        archived: widget.existing?.archived ?? false,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => LgPage(
    title: widget.existing == null ? 'Add an asset' : 'Edit asset',
    showBack: true,
    subtitle: 'Record value, ownership and the source of every figure.',
    bottom: LgAction('Save asset', busy: busy, onPressed: busy ? null : save,
      icon: Icons.check_rounded),
    children: [
      Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<AssetKind>(initialValue: kind,
          decoration: const InputDecoration(labelText: 'Asset category'),
          items: AssetKind.values.map((e) => DropdownMenuItem(
            value: e, child: Text(e.label))).toList(),
          onChanged: (v) { if (v != null) setState(() => kind = v); }),
        const SizedBox(height: 20),
        LgInput(label: 'Asset name', hint: 'e.g. Rental house — Gulu', controller: name,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Asset name is required' : null),
        const SizedBox(height: 20),
        LgInput(label: 'Current full asset value (UGX)',
          controller: amount, keyboardType: TextInputType.number,
          hint: '0', validator: _validateNonNegative),
        const SizedBox(height: 20),
        LgInput(label: 'Original acquisition cost (UGX)',
          controller: cost, keyboardType: TextInputType.number,
          hint: '0', validator: _validateNonNegative),
        const SizedBox(height: 20),
        LgInput(label: 'Your economic ownership (%)', controller: ownership,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            final n = double.tryParse(v ?? '');
            return n == null || n <= 0 || n > 100 ? 'Enter 0.01–100' : null;
          }),
        const SizedBox(height: 20),
        LgInput(label: 'Institution / provider (optional)',
          controller: institution, hint: 'e.g. SACCO, bank or custodian'),
        const SizedBox(height: 20),
        LgInput(label: 'Location (optional)', controller: location,
          hint: 'District, town or property address'),
        const SizedBox(height: 20),
        DropdownButtonFormField<ValuationSource>(initialValue: source,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Valuation source'),
          items: ValuationSource.values.map((e) => DropdownMenuItem(
            value: e, child: Text(sourceLabel(e)))).toList(),
          onChanged: (v) { if (v != null) setState(() => source = v); }),
        const SizedBox(height: 22),
        _dateRow(context, 'Valuation date', valued, (d) => setState(() => valued = d)),
        const SizedBox(height: 14),
        _dateRow(context, 'Acquisition date', acquired, (d) => setState(() => acquired = d)),
        const SizedBox(height: 20),
        LgInput(label: 'Notes (optional)', controller: notes,
          hint: 'Reference, evidence or details', maxLines: 3),
        const SizedBox(height: 24),
        const InfoStrip(icon: Icons.info_outline_rounded,
          title: 'Values are self-reported',
          body: 'An owner estimate is not an official valuation. Entries and cash flows do not automatically alter this balance.'),
        const SizedBox(height: 22),
      ])),
    ]);
}

Widget _dateRow(BuildContext context, String title, DateTime value,
    ValueChanged<DateTime> choose) => SoftCard(color: LG.surface,
      child: Row(children: [
        const Icon(Icons.calendar_today_outlined, color: LG.sageDark, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: LG.muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(Fmt.date(value), style: const TextStyle(color: LG.navy,
            fontWeight: FontWeight.w700)),
        ])),
        TextButton(onPressed: () async {
          final date = await pickWealthDate(context, value);
          if (date != null) choose(date);
        }, child: const Text('Change')),
      ]));

class DebtEditor extends StatefulWidget {
  const DebtEditor({super.key, required this.store, this.existing});
  final WealthStore store;
  final WealthDebt? existing;
  @override
  State<DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends State<DebtEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final lender = TextEditingController();
  final amount = TextEditingController();
  final interest = TextEditingController();
  final notes = TextEditingController();
  String linked = '';
  DateTime? due;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    name.text = d?.name ?? ''; lender.text = d?.lender ?? '';
    amount.text = d?.balanceUgx.toString() ?? '';
    interest.text = (d?.interestBps ?? 0) == 0
      ? '' : ((d!.interestBps) / 100).toStringAsFixed(2);
    notes.text = d?.notes ?? '';
    linked = d?.linkedAssetId ?? ''; due = d?.dueAt;
  }
  @override
  void dispose() {
    for (final c in [name, lender, amount, interest, notes]) { c.dispose(); }
    super.dispose();
  }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final bps = ((double.tryParse(interest.text) ?? 0) * 100).round();
    if (bps < 0 || bps > 100000) {
      showFailure(context, 'Interest rate must be 0% to 1,000%.'); return;
    }
    setState(() => busy = true);
    try {
      await widget.store.saveDebt(WealthDebt(
        id: widget.existing?.id ?? WealthStore.uuid.v4(), name: name.text.trim(),
        balanceUgx: Fmt.parseUgx(amount.text)!, lender: lender.text.trim(),
        linkedAssetId: linked, interestBps: bps, dueAt: due, notes: notes.text.trim(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => LgPage(
    title: widget.existing == null ? 'Record a liability' : 'Edit liability',
    showBack: true,
    subtitle: 'Outstanding balances reduce your net worth exactly once.',
    bottom: LgAction('Save liability', busy: busy, onPressed: busy ? null : save),
    children: [
      Form(key: form, child: Column(children: [
        LgInput(label: 'Liability name', controller: name, hint: 'e.g. Home mortgage',
          validator: (v) => (v ?? '').trim().isEmpty ? 'Name required' : null),
        const SizedBox(height: 19),
        LgInput(label: 'Outstanding balance (UGX)', controller: amount,
          keyboardType: TextInputType.number, hint: '0',
          validator: _validateNonNegative),
        const SizedBox(height: 19),
        LgInput(label: 'Lender / creditor (optional)', controller: lender),
        const SizedBox(height: 19),
        DropdownButtonFormField<String>(initialValue: linked,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Linked asset (optional)'),
          items: [
            const DropdownMenuItem(value: '', child: Text('No linked asset')),
            ...widget.store.activeAssets.map((a) => DropdownMenuItem(
              value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => setState(() => linked = v ?? '')),
        const SizedBox(height: 19),
        LgInput(label: 'Annual interest rate (%) (optional)', controller: interest,
          keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 19),
        _dateRow(context, 'Due / maturity date', due ?? DateTime.now(),
          (d) => setState(() => due = d)),
        const SizedBox(height: 19),
        LgInput(label: 'Notes (optional)', controller: notes, maxLines: 3),
        const SizedBox(height: 26),
        const InfoStrip(title: 'Prevent double counting',
          body: 'Link a mortgage to its property, but enter its outstanding balance only here. Equity will be computed from ownership-adjusted value minus linked debts.'),
      ])),
    ]);
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({super.key, required this.store, this.existing});
  final WealthStore store;
  final WealthEntry? existing;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final form = GlobalKey<FormState>();
  final category = TextEditingController();
  final amount = TextEditingController();
  final notes = TextEditingController();
  late EntryType type;
  late DateTime occurred;
  String assetId = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    type = e?.type ?? EntryType.income;
    occurred = e?.occurredAt ?? DateTime.now();
    category.text = e?.category ?? '';
    amount.text = e?.amountUgx.toString() ?? '';
    notes.text = e?.notes ?? ''; assetId = e?.assetId ?? '';
  }
  @override
  void dispose() { category.dispose(); amount.dispose(); notes.dispose(); super.dispose(); }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.store.saveEntry(WealthEntry(
        id: widget.existing?.id ?? WealthStore.uuid.v4(), type: type,
        amountUgx: Fmt.parseUgx(amount.text)!, category: category.text.trim(),
        occurredAt: occurred, assetId: assetId, notes: notes.text.trim(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) showFailure(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => LgPage(
    title: 'Record a transaction', showBack: true,
    subtitle: 'Capture income, expenses, contributions and withdrawals accurately.',
    bottom: LgAction('Save transaction', busy: busy, onPressed: busy ? null : save),
    children: [
      Form(key: form, child: Column(children: [
        DropdownButtonFormField<EntryType>(initialValue: type,
          decoration: const InputDecoration(labelText: 'Transaction type'),
          items: EntryType.values.map((e) => DropdownMenuItem(
            value: e, child: Text(e.name[0].toUpperCase() + e.name.substring(1)))).toList(),
          onChanged: (v) { if (v != null) setState(() => type = v); }),
        const SizedBox(height: 19),
        LgInput(label: 'Description / category', controller: category,
          hint: 'e.g. Rent received, bank interest',
          validator: (v) => (v ?? '').trim().isEmpty ? 'Description required' : null),
        const SizedBox(height: 19),
        LgInput(label: 'Amount (UGX)', controller: amount,
          keyboardType: TextInputType.number, validator: _validatePositive),
        const SizedBox(height: 19),
        DropdownButtonFormField<String>(initialValue: assetId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Related asset (optional)'),
          items: [
            const DropdownMenuItem(value: '', child: Text('No specific asset')),
            ...widget.store.activeAssets.map((a) => DropdownMenuItem(
              value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => setState(() => assetId = v ?? '')),
        const SizedBox(height: 19),
        _dateRow(context, 'Transaction date', occurred,
          (d) => setState(() => occurred = d)),
        const SizedBox(height: 19),
        LgInput(label: 'Notes / reference (optional)', controller: notes, maxLines: 3),
        const SizedBox(height: 26),
        const InfoStrip(icon: Icons.info_outline,
          title: 'Recorded cash movement',
          body: 'A transaction updates your cash-flow report. It does not automatically change a separately reported asset valuation or balance.'),
      ])),
    ]);
}

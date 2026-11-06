import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/finance.dart';
import '../domain/models.dart';
import 'widgets.dart';
import 'wealth_screens.dart';

/// Target allocations, actual weights, and the resulting drift. Expressed as
/// basis points to match the rest of the domain model.
class AllocationScreen extends StatelessWidget {
  final PortfolioStore store;
  const AllocationScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final drifts = allocationDrift(store.state.assets, store.state.targetWeightsBps);
        final activeAssets = store.state.assets.where((a) => !a.archived).toList();
        return WealthPage(
            title: 'Target allocation',
            subtitle:
                'Compare your recorded weights against the mix you want to hold.',
            children: [
              if (drifts.isEmpty)
                const EmptySection(
                    title: 'No targets yet',
                    detail:
                        'Set target percentages for one or more assets to see drift here.')
              else ...drifts.map((d) {
                final driftPct = d.driftBps / 100;
                final color = driftPct.abs() < 5
                    ? LG.sage
                    : driftPct < 0
                        ? LG.gold
                        : LG.navy;
                return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(d.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                          Text('${driftPct >= 0 ? '+' : ''}${driftPct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w800))
                        ]),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: (d.actualBps / 10000).clamp(0, 1).toDouble(),
                          minHeight: 8,
                          color: LG.sage,
                          backgroundColor: LG.sageSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 6),
                        Text(
                            'Target ${(d.targetBps / 100).toStringAsFixed(1)}% · Actual ${(d.actualBps / 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: LG.muted, fontSize: 12)),
                      ],
                    )));
              }),
              const SizedBox(height: 16),
              const SectionTitle('Set targets'),
              ...activeAssets.map((a) => SoftCard(
                      child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                          child: Text(a.name,
                              style: const TextStyle(fontWeight: FontWeight.w700))),
                      SizedBox(
                          width: 90,
                          child: TextFormField(
                              initialValue:
                                  ((store.state.targetWeightsBps[a.id] ?? 0) / 100)
                                      .toStringAsFixed(1),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                  isDense: true, suffixText: '%'),
                              onFieldSubmitted: (v) {
                                final value = double.tryParse(v);
                                if (value == null) return;
                                final bps = (value * 100).round().clamp(0, 10000);
                                store.setTargetWeight(a.id, bps);
                              }))
                    ]),
                  ))),
              const SizedBox(height: 12),
              const Text(
                  'Submit each row with your keyboard\'s Done action. Targets do not change recorded values; they just show how far your portfolio has drifted from your plan.',
                  style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5)),
            ]);
      });
}

class FxRatesScreen extends StatefulWidget {
  final PortfolioStore store;
  const FxRatesScreen({super.key, required this.store});
  @override
  State<FxRatesScreen> createState() => _FxRatesScreenState();
}

class _FxRatesScreenState extends State<FxRatesScreen> {
  final currency = TextEditingController();
  final amount = TextEditingController();
  DateTime asOf = DateTime.now();
  final source = TextEditingController();

  @override
  void dispose() {
    currency.dispose();
    amount.dispose();
    source.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final c = currency.text.trim().toUpperCase();
    final a = int.tryParse(amount.text.replaceAll(',', ''));
    if (c.length != 3 || a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a 3-letter code and positive quote')));
      return;
    }
    await widget.store.upsertFxRate(FxRate(
        currency: c, ugxPerUnit: a, asOf: asOf, source: source.text.trim()));
    currency.clear();
    amount.clear();
    source.clear();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final rates = [...widget.store.state.fxRates]
          ..sort((a, b) => b.asOf.compareTo(a.asOf));
        return WealthPage(
            title: 'FX reference rates',
            subtitle:
                'Private, user-entered rates used only for display. There is no live FX feed.',
            children: [
              const SoftCard(
                  color: LG.sageSoft,
                  child: Row(children: [
                    Icon(Icons.info_outline, color: LG.sage),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            'Enter the UGX amount equivalent to one unit of the foreign currency, along with the date the quote applies to. Older quotes are kept so historical values stay auditable.',
                            style: TextStyle(
                                color: LG.muted, fontSize: 12, height: 1.5)))
                  ])),
              const SizedBox(height: 18),
              FormFieldBlock(
                  title: 'Currency',
                  child: TextField(
                      controller: currency,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(hintText: 'USD / EUR / KES'))),
              FormFieldBlock(
                  title: 'UGX per unit',
                  child: TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: '3,900'))),
              FormFieldBlock(
                  title: 'As of',
                  child: SoftCard(
                      onTap: () async {
                        final v = await showDatePicker(
                            context: context,
                            initialDate: asOf,
                            firstDate: DateTime(1990),
                            lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (v != null) setState(() => asOf = v);
                      },
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, color: LG.sage),
                        const SizedBox(width: 10),
                        Text(LG.date(asOf))
                      ]))),
              FormFieldBlock(
                  title: 'Source (optional)',
                  child: TextField(
                      controller: source,
                      decoration:
                          const InputDecoration(hintText: 'Bank statement, bureau...'))),
              ElevatedButton(
                  onPressed: _submit, child: const Text('Save FX rate')),
              const SizedBox(height: 22),
              const SectionTitle('Recorded rates'),
              if (rates.isEmpty)
                const EmptySection(
                    title: 'No FX rates yet',
                    detail: 'Add one above to start building a history.')
              else ...rates.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                      child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('${r.currency} · UGX ${LG.money(r.ugxPerUnit)}',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                              '${LG.date(r.asOf)}${r.source.isEmpty ? '' : ' · ${r.source}'}',
                              style: const TextStyle(color: LG.muted, fontSize: 12)),
                        ])),
                    IconButton(
                        onPressed: () =>
                            widget.store.removeFxRate(r.currency, r.asOf),
                        icon: const Icon(Icons.delete_outline, color: LG.muted)),
                  ])))),
            ]);
      });
}

class ScheduledContributionsScreen extends StatelessWidget {
  final PortfolioStore store;
  const ScheduledContributionsScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final now = DateTime.now();
        final schedules = [...store.state.scheduled]
          ..sort((a, b) => a.nextFire.compareTo(b.nextFire));
        final due = dueSchedules(store.state.scheduled, now);
        return WealthPage(
            title: 'Scheduled contributions',
            subtitle:
                'Recurring contributions you plan to post automatically on due dates.',
            children: [
              if (due.isNotEmpty) ...[
                const SectionTitle('Due now'),
                ...due.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                        color: LG.sageSoft,
                        child: Row(children: [
                          const Icon(Icons.event_available, color: LG.sage),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(s.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                    '${LG.money(s.amountUgx, compact: true)} · ${s.frequency.name}',
                                    style: const TextStyle(color: LG.muted, fontSize: 12))
                              ])),
                          TextButton(
                              onPressed: () => store.fireSchedule(s),
                              child: const Text('Post now'))
                        ])))),
                const SizedBox(height: 18),
              ],
              const SectionTitle('All schedules'),
              if (schedules.isEmpty)
                const EmptySection(
                    title: 'Nothing scheduled',
                    detail: 'Add a recurring contribution to see upcoming postings here.')
              else ...schedules.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => ScheduleForm(store: store, existing: s))),
                      child: Row(children: [
                        Switch.adaptive(
                            value: s.active,
                            activeTrackColor: LG.sageSoft,
                            onChanged: (v) =>
                                store.pauseSchedule(s.id, active: v)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(s.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(
                                  '${LG.money(s.amountUgx, compact: true)} · ${s.frequency.name} · next ${LG.date(s.nextFire)}',
                                  style: const TextStyle(color: LG.muted, fontSize: 12)),
                            ])),
                        const Icon(Icons.chevron_right, color: LG.muted),
                      ])))),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute<void>(builder: (_) => ScheduleForm(store: store))),
                  icon: const Icon(Icons.add),
                  label: const Text('New scheduled contribution')),
              const SizedBox(height: 12),
              const Text(
                  'Posting a scheduled entry creates a normal, reversible ledger event and advances the next due date by the chosen frequency.',
                  style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5)),
            ]);
      });
}

class ScheduleForm extends StatefulWidget {
  final PortfolioStore store;
  final ScheduledContribution? existing;
  const ScheduleForm({super.key, required this.store, this.existing});
  @override
  State<ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<ScheduleForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late final amount = TextEditingController(
      text: widget.existing?.amountUgx.toString() ?? '');
  late ContributionFrequency frequency =
      widget.existing?.frequency ?? ContributionFrequency.monthly;
  late DateTime nextFire = widget.existing?.nextFire ??
      DateTime.now().add(const Duration(days: 30));
  late String? assetId = widget.existing?.assetId;

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets =
        widget.store.state.assets.where((x) => !x.archived).toList();
    return Scaffold(
        appBar: AppBar(title: const BrandMark(height: 28)),
        body: SafeArea(
            child: Form(
                key: form,
                child: ListView(padding: const EdgeInsets.all(22), children: [
                  PageHeading(
                      widget.existing == null
                          ? 'New scheduled contribution'
                          : 'Edit scheduled contribution',
                      subtitle:
                          'A recurring ledger entry you commit to posting on each due date.'),
                  FormFieldBlock(
                      title: 'Name',
                      child: TextFormField(
                          controller: name,
                          decoration: const InputDecoration(
                              hintText: 'e.g. Monthly SACCO contribution'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null)),
                  FormFieldBlock(
                      title: 'Amount (UGX)',
                      child: TextFormField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            final n = int.tryParse((v ?? '').replaceAll(',', ''));
                            return n == null || n <= 0
                                ? 'Enter a positive UGX amount'
                                : null;
                          })),
                  FormFieldBlock(
                      title: 'Frequency',
                      child: DropdownButtonFormField<ContributionFrequency>(
                          initialValue: frequency,
                          items: ContributionFrequency.values
                              .map((f) =>
                                  DropdownMenuItem(value: f, child: Text(f.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => frequency = v ?? frequency))),
                  FormFieldBlock(
                      title: 'Next due date',
                      child: SoftCard(
                          onTap: () async {
                            final v = await showDatePicker(
                                context: context,
                                initialDate: nextFire,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 30)),
                                lastDate: DateTime(2100));
                            if (v != null) setState(() => nextFire = v);
                          },
                          child: Row(children: [
                            const Icon(Icons.event_available_outlined,
                                color: LG.sage),
                            const SizedBox(width: 10),
                            Text(LG.date(nextFire))
                          ]))),
                  FormFieldBlock(
                      title: 'Associated asset (optional)',
                      child: DropdownButtonFormField<String?>(
                          initialValue: assetId,
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('Portfolio-level')),
                            ...assets.map((a) => DropdownMenuItem(
                                value: a.id, child: Text(a.name)))
                          ],
                          onChanged: (v) => setState(() => assetId = v))),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      onPressed: () async {
                        if (!form.currentState!.validate()) return;
                        final n = int.parse(amount.text.replaceAll(',', ''));
                        await widget.store.upsertSchedule(ScheduledContribution(
                            id: widget.existing?.id ?? makeId(),
                            name: name.text.trim(),
                            amountUgx: n,
                            assetId: assetId,
                            frequency: frequency,
                            nextFire: nextFire,
                            lastFired: widget.existing?.lastFired,
                            active: widget.existing?.active ?? true));
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Save schedule')),
                  if (widget.existing != null) ...[
                    const SizedBox(height: 10),
                    TextButton(
                        onPressed: () async {
                          await widget.store.deleteSchedule(widget.existing!.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Delete schedule',
                            style: TextStyle(color: LG.negative))),
                  ],
                ]))));
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../domain/finance.dart';
import '../domain/models.dart';
import '../state/wealth_store.dart';
import 'components.dart';
import 'editors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.store});
  final WealthStore store;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int period = 1; // Current calendar year
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final from = switch (period) {
      0 => null,
      1 => DateTime(now.year, 1, 1),
      _ => now.subtract(const Duration(days: 30)),
    };
    final income = amountFor(widget.store.entries, EntryType.income, from: from);
    final outgoings = amountFor(widget.store.entries, EntryType.expense, from: from);
    final breakdown = widget.store.allocationMap;
    final positiveTotal = breakdown.values.fold<int>(0, (s, v) => s + v);
    return LgPage(title: 'Reports & insights',
      subtitle: 'Understand your assets, financial position and recorded cash flow.',
      children: [
        SoftCard(color: LG.sageSoft,
          child: Row(children: [
            const Icon(Icons.insights_outlined, color: LG.sageDark, size: 26),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Net worth today', style: TextStyle(color: LG.muted, fontSize: 12)),
              const SizedBox(height: 3),
              MoneyLabel(widget.store.worth, large: true),
            ])),
            IconButton(onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => NetWorthScreen(store: widget.store))),
              icon: const Icon(Icons.chevron_right_rounded, color: LG.sageDark)),
          ])),
        const SizedBox(height: 25),
        const SectionHeading('Asset allocation'),
        SoftCard(child: positiveTotal == 0
          ? const EmptyHint(title: 'No allocation data', detail: 'Add asset values to see your mix.')
          : Row(children: [
              SizedBox(width: 126, height: 126,
                child: CustomPaint(painter: AllocationPainter(breakdown))),
              const SizedBox(width: 14),
              Expanded(child: Column(children: [
                for (final kind in AssetKind.values) Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _sliceColor(kind))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(kind.label,
                      style: const TextStyle(color: LG.muted, fontSize: 11.5))),
                    Text('${((breakdown[kind] ?? 0) / positiveTotal * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: LG.navy,
                        fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ]),
                ),
              ])),
            ])),
        const SizedBox(height: 26),
        SectionHeading('Cash flow', trailing: DropdownButton<int>(
          value: period, underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 0, child: Text('All time')),
            DropdownMenuItem(value: 1, child: Text('This year')),
            DropdownMenuItem(value: 2, child: Text('Last 30 days')),
          ],
          onChanged: (v) { if (v != null) setState(() => period = v); },
        )),
        SoftCard(child: Column(children: [
          _reportRow('Recorded income', income, LG.sageDark),
          const SizedBox(height: 17),
          _reportRow('Recorded expenses', outgoings, LG.gold),
          const Divider(height: 28),
          _reportRow('Net operating cash flow', income - outgoings, LG.navy),
        ])),
        const SizedBox(height: 26),
        const SectionHeading('Financial statements'),
        _link(context, 'Net worth statement', Icons.account_balance_wallet_outlined,
          NetWorthScreen(store: widget.store)),
        const SizedBox(height: 8),
        _link(context, 'Liabilities and mortgages', Icons.credit_card_outlined,
          LiabilitiesScreen(store: widget.store)),
        const SizedBox(height: 8),
        _link(context, 'Transactions ledger', Icons.receipt_long_outlined,
          TransactionsScreen(store: widget.store)),
        const SizedBox(height: 24),
        const InfoStrip(icon: Icons.info_outline,
          title: 'No invented returns',
          body: 'This report uses recorded balances and cash flows. Market performance and returns are not estimated without complete dated data.'),
      ]);
  }

  Widget _reportRow(String title, int amount, Color color) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(color: LG.muted))),
    Text(Fmt.money(amount), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
  ]);

  Widget _link(BuildContext context, String label, IconData icon, Widget page) =>
    SoftCard(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)),
      child: Row(children: [
        Icon(icon, color: LG.sageDark),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(
          color: LG.navy, fontWeight: FontWeight.w700))),
        const Icon(Icons.chevron_right_rounded, color: LG.muted),
      ]));
}

Color _sliceColor(AssetKind kind) => switch (kind) {
  AssetKind.investment => LG.sageDark,
  AssetKind.property => LG.gold,
  AssetKind.saving => LG.navy,
  AssetKind.other => LG.muted,
};

class AllocationPainter extends CustomPainter {
  AllocationPainter(this.slices);
  final Map<AssetKind, int> slices;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2 - 9;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final total = slices.values.fold<int>(0, (s,v) => s + v);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 18
      ..color = LG.line..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi*2, false, base);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final kind in AssetKind.values) {
      final value = slices[kind] ?? 0;
      if (value <= 0) continue;
      final sweep = math.pi * 2 * (value / total);
      canvas.drawArc(rect, start, sweep, false, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 18
        ..strokeCap = StrokeCap.butt..color = _sliceColor(kind));
      start += sweep;
    }
  }
  @override
  bool shouldRepaint(covariant AllocationPainter oldDelegate) =>
      oldDelegate.slices.toString() != slices.toString();
}

class NetWorthScreen extends StatelessWidget {
  const NetWorthScreen({super.key, required this.store});
  final WealthStore store;
  @override
  Widget build(BuildContext context) {
    final b = store.allocationMap;
    return LgPage(title: 'Net worth statement', showBack: true,
      subtitle: 'Your ownership-adjusted assets less all outstanding liabilities.',
      children: [
        SoftCard(color: LG.navy,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CONSOLIDATED NET WORTH', style: TextStyle(
              color: LG.sageSoft, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(Fmt.money(store.worth),
              style: const TextStyle(fontSize: 27, color: LG.white,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('As recorded ${Fmt.date(DateTime.now())} · UGX',
              style: const TextStyle(color: Color(0xFFD6E0E4), fontSize: 12)),
          ])),
        const SizedBox(height: 27),
        const SectionHeading('Owned asset composition'),
        SoftCard(child: Column(children: [
          for (final kind in AssetKind.values) ...[
            _line(kind.label, b[kind] ?? 0),
            const Divider(height: 24),
          ],
          _line('Total owned assets', store.gross, strong: true),
        ])),
        const SizedBox(height: 25),
        const SectionHeading('Liabilities'),
        SoftCard(child: Column(children: [
          if (store.debts.isEmpty)
            const Text('No liabilities recorded.', style: TextStyle(color: LG.muted)),
          for (final debt in store.debts) ...[
            _line(debt.name, -debt.balanceUgx),
            const Divider(height: 24),
          ],
          _line('Total outstanding debt', -store.outstanding, strong: true),
        ])),
        const SizedBox(height: 27),
        SoftCard(color: LG.sageSoft, child: _line('Your net worth', store.worth, strong: true)),
        const SizedBox(height: 24),
        const InfoStrip(icon: Icons.info_outline_rounded,
          title: 'About this statement',
          body: 'The report uses your economic ownership share and current self-reported valuations. Linked mortgages are subtracted from net worth once, not once per view.'),
      ]);
  }

  Widget _line(String label, int amount, {bool strong = false}) => Row(children: [
    Expanded(child: Text(label, style: TextStyle(color: strong ? LG.navy : LG.muted,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
    const SizedBox(width: 8),
    Text(Fmt.money(amount), style: TextStyle(color: amount < 0 ? LG.danger : LG.navy,
      fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
  ]);
}

class LiabilitiesScreen extends StatelessWidget {
  const LiabilitiesScreen({super.key, required this.store});
  final WealthStore store;
  @override
  Widget build(BuildContext context) => LgPage(
    title: 'Liabilities', showBack: true,
    subtitle: 'Borrowings and obligations that affect your financial position.',
    trailing: IconButton(onPressed: () => _edit(context),
      icon: const Icon(Icons.add_rounded), tooltip: 'Add debt'),
    children: [
      SoftCard(color: LG.sageSoft, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TOTAL OUTSTANDING', style: TextStyle(color: LG.sageDark,
          fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        MoneyLabel(store.outstanding, large: true),
      ])),
      const SizedBox(height: 26),
      if (store.debts.isEmpty) const EmptyHint(title: 'No liabilities yet',
        detail: 'Record debts, SACCO loans and mortgages to calculate net worth accurately.',
        icon: Icons.credit_card_off_rounded)
      else ...store.debts.map((d) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.credit_card_rounded, color: LG.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(d.name, style: const TextStyle(
              color: LG.navy, fontWeight: FontWeight.w800))),
            PopupMenuButton<String>(onSelected: (s) async {
              if (s == 'edit') { _edit(context, d); return; }
              if (!await askConfirm(context, 'Delete liability?',
                  'This will remove this outstanding balance from net worth.')) { return; }
              try { await store.deleteDebt(d.id); }
              catch (e) { if (context.mounted) showFailure(context, e); }
            }, itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ]),
          ]),
          const SizedBox(height: 10),
          MoneyLabel(d.balanceUgx),
          const SizedBox(height: 5),
          Text(d.linkedAssetId.isEmpty ? (d.lender.isEmpty ? 'Unlinked debt' : d.lender)
            : 'Linked to ${store.assets.where((a) => a.id == d.linkedAssetId).firstOrNull?.name ?? 'unavailable asset'}',
            style: const TextStyle(color: LG.muted, fontSize: 12)),
          if (d.dueAt != null) Text('Due ${Fmt.date(d.dueAt!)}',
            style: const TextStyle(color: LG.muted, fontSize: 12)),
        ])))),
      const SizedBox(height: 16),
      LgAction('Add liability', onPressed: () => _edit(context), icon: Icons.add_rounded),
    ]);
  void _edit(BuildContext context, [WealthDebt? debt]) =>
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => DebtEditor(store: store, existing: debt)));
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, required this.store});
  final WealthStore store;
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  EntryType? filter;
  @override
  Widget build(BuildContext context) {
    final data = widget.store.entries.where((e) => filter == null || e.type == filter).toList();
    return LgPage(title: 'Transactions', showBack: true,
      subtitle: 'An auditable record of cash income, costs and contributions.',
      trailing: IconButton(onPressed: () => _edit(context),
        icon: const Icon(Icons.add_rounded), tooltip: 'New transaction'),
      children: [
        Row(children: [
          Expanded(child: SoftCard(color: LG.sageSoft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Income', style: TextStyle(color: LG.muted, fontSize: 12)),
              const SizedBox(height: 7),
              Text(Fmt.money(widget.store.income, compact: true),
                style: const TextStyle(color: LG.sageDark, fontWeight: FontWeight.w800)),
            ]))),
          const SizedBox(width: 12),
          Expanded(child: SoftCard(color: const Color(0xFFF8F1E5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Expenses', style: TextStyle(color: LG.muted, fontSize: 12)),
              const SizedBox(height: 7),
              Text(Fmt.money(widget.store.expenses, compact: true),
                style: const TextStyle(color: LG.navy, fontWeight: FontWeight.w800)),
            ]))),
        ]),
        const SizedBox(height: 20),
        DropdownButtonFormField<EntryType?>(initialValue: filter,
          decoration: const InputDecoration(labelText: 'Filter transactions'),
          items: [
            const DropdownMenuItem<EntryType?>(value: null, child: Text('All transaction types')),
            ...EntryType.values.map((v) => DropdownMenuItem<EntryType?>(
              value: v, child: Text(v.name[0].toUpperCase() + v.name.substring(1)))),
          ],
          onChanged: (v) => setState(() => filter = v)),
        const SizedBox(height: 22),
        if (data.isEmpty) const EmptyHint(
          title: 'No transactions', detail: 'Record income, expenses and contributions to start.',
          icon: Icons.receipt_long_outlined)
        else ...data.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(child: Row(children: [
            Icon(e.type == EntryType.income ? Icons.south_west_rounded
              : Icons.north_east_rounded,
              color: e.type == EntryType.income ? LG.sageDark : LG.gold),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.category, style: const TextStyle(
                color: LG.navy, fontWeight: FontWeight.w800)),
              Text('${e.type.name} · ${Fmt.date(e.occurredAt)}',
                style: const TextStyle(color: LG.muted, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(Fmt.money(e.amountUgx, compact: true),
                style: const TextStyle(fontWeight: FontWeight.w800, color: LG.navy)),
              PopupMenuButton<String>(padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_horiz_rounded, size: 19, color: LG.muted),
                onSelected: (v) async {
                  if (v == 'edit') { _edit(context, e); return; }
                  if (!await askConfirm(context, 'Delete transaction?',
                    'Removing this record changes your cash-flow totals.')) { return; }
                  try { await widget.store.deleteEntry(e.id); }
                  catch (err) { if (context.mounted) showFailure(context, err); }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ]),
            ]),
          ])))),
        const SizedBox(height: 12),
        LgAction('Record transaction', onPressed: () => _edit(context), icon: Icons.add_rounded),
      ]);
  }
  void _edit(BuildContext context, [WealthEntry? entry]) =>
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => EntryEditor(store: widget.store, existing: entry)));
}

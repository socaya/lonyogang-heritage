import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import '../state/wealth_store.dart';
import 'components.dart';
import 'organize.dart';
import 'reports.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store, required this.onPortfolio,
    required this.onReports, required this.onAdd});
  final WealthStore store;
  final VoidCallback onPortfolio, onReports, onAdd;

  @override
  Widget build(BuildContext context) {
    final name = store.profile?.name ?? 'there';
    final firstName = name.split(' ').first;
    final today = DateTime.now();
    final unresolved = store.reminders.where((r) => !r.done && !r.dueAt.isAfter(
      today.add(const Duration(days: 7)))).toList();
    final breakdown = store.allocationMap;
    return Scaffold(body: SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      children: [
        Row(children: [
          CircleAvatar(backgroundColor: LG.sageSoft,
            child: Text(Fmt.initials(name), style: const TextStyle(
              fontWeight: FontWeight.w800, color: LG.sageDark))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Good to see you,', style: TextStyle(color: LG.muted, fontSize: 12)),
            Text(firstName, style: const TextStyle(color: LG.navy,
              fontWeight: FontWeight.w800, fontSize: 18)),
          ])),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => RemindersScreen(store: store))),
            icon: const Icon(Icons.notifications_none_rounded, color: LG.navy),
            tooltip: 'Reminders'),
        ]),
        const SizedBox(height: 23),
        Container(padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: LG.navy,
            borderRadius: BorderRadius.circular(19)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Text('TOTAL NET WORTH', style: TextStyle(color: Color(0xFFCAD7D9),
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              Spacer(),
              Icon(Icons.shield_outlined, size: 19, color: LG.sageSoft),
            ]),
            const SizedBox(height: 14),
            Text(Fmt.money(store.worth), style: const TextStyle(
              color: LG.white, fontWeight: FontWeight.w800,
              fontSize: 30, letterSpacing: -0.5)),
            const SizedBox(height: 13),
            Text('Owned assets: ${Fmt.money(store.gross, compact:true)}  ·  Debt: ${Fmt.money(store.outstanding, compact:true)}',
              style: const TextStyle(color: Color(0xFFCCD8DE), fontSize: 12.5)),
            const SizedBox(height: 12),
            const Text('Based on recorded valuations and balances · UGX',
              style: TextStyle(color: Color(0xFFB5C9D0), fontSize: 11)),
          ])),
        const SizedBox(height: 27),
        SectionHeading('Your portfolio', trailing: TextButton(
          onPressed: onPortfolio, child: const Text('View all'))),
        GridView.count(crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.6,
          crossAxisSpacing: 11, mainAxisSpacing: 11,
          children: AssetKind.values.map((kind) => SoftCard(
            color: LG.white, onTap: onPortfolio,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(assetIcon(kind), color: kind == AssetKind.property ? LG.gold : LG.sageDark, size: 22),
              const Spacer(),
              Text(kind.label, style: const TextStyle(color: LG.muted, fontSize: 12)),
              Text(Fmt.money(breakdown[kind] ?? 0, compact: true),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: LG.navy, fontSize: 15, fontWeight: FontWeight.w800)),
            ]))).toList()),
        const SizedBox(height: 28),
        SectionHeading('Portfolio position', trailing: TextButton(
          onPressed: onReports, child: const Text('Insights'))),
        SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _positionRow('Owned asset value', store.gross, LG.sageDark),
          const SizedBox(height: 15),
          _positionRow('Outstanding liabilities', store.outstanding, LG.gold),
          const Divider(height: 26),
          _positionRow('Net worth', store.worth, LG.navy, strong: true),
          const SizedBox(height: 12),
          const Text('Current position, not a guaranteed liquidation value.',
            style: TextStyle(color: LG.muted, fontSize: 11.5)),
        ])),
        const SizedBox(height: 28),
        SectionHeading('Recent activity', trailing: TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => TransactionsScreen(store: store))),
          child: const Text('View all'))),
        if (store.entries.isEmpty)
          SoftCard(child: const EmptyHint(title: 'No transactions yet',
            detail: 'Record your first income, cost or contribution to build a cash-flow history.',
            icon: Icons.receipt_long_outlined))
        else ...store.entries.take(3).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(child: Row(children: [
            Icon(item.type == EntryType.income ? Icons.south_west_rounded
              : Icons.north_east_rounded, color: item.type == EntryType.income
                ? LG.sageDark : LG.gold),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.category, style: const TextStyle(fontWeight: FontWeight.w700, color: LG.navy)),
              Text(Fmt.date(item.occurredAt), style: const TextStyle(color: LG.muted, fontSize: 12)),
            ])),
            Text(Fmt.money(item.amountUgx, compact: true),
              style: const TextStyle(color: LG.navy, fontWeight: FontWeight.w700)),
          ])))),
        if (unresolved.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionHeading('Due soon', trailing: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => RemindersScreen(store: store))), child: const Text('All reminders'))),
          ...unresolved.take(2).map((r) => Padding(padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(color: LG.sageSoft, child: Row(children: [
              const Icon(Icons.event_note_outlined, color: LG.sageDark),
              const SizedBox(width: 12),
              Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(Fmt.date(r.dueAt), style: const TextStyle(fontSize: 11, color: LG.muted)),
            ])))),
        ],
        const SizedBox(height: 20),
        LgAction('Add to my portfolio', onPressed: onAdd, icon: Icons.add_rounded),
      ],
    )));
  }

  Widget _positionRow(String label, int value, Color color, {bool strong = false}) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(child: Text(label, style: TextStyle(color: strong ? LG.navy : LG.muted,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
      Text(Fmt.money(value, compact: true), style: TextStyle(color: color,
        fontSize: strong ? 19 : 16, fontWeight: FontWeight.w800)),
    ]);
}

import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../domain/finance.dart';
import '../domain/models.dart';
import '../state/wealth_store.dart';
import 'components.dart';
import 'editors.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key, required this.store});
  final WealthStore store;
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}
class _PortfolioScreenState extends State<PortfolioScreen> {
  AssetKind? selected;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.store.activeAssets.where((a) =>
      (selected == null || a.kind == selected) &&
      (a.name.toLowerCase().contains(query.toLowerCase()) ||
        a.institution.toLowerCase().contains(query.toLowerCase()) ||
        a.location.toLowerCase().contains(query.toLowerCase()))
    ).toList();
    final total = list.fold<int>(0, (s,a) => s + ownedValue(a));
    return LgPage(title: 'My portfolio',
      subtitle: 'All the assets you own, recorded in one place.',
      trailing: IconButton(icon: const Icon(Icons.add_rounded, color: LG.navy),
        tooltip: 'Add an asset',
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => AssetEditor(store: widget.store)))),
      children: [
        SoftCard(color: LG.sageSoft, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OWNED ASSET VALUE', style: TextStyle(
            color: LG.sageDark, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          MoneyLabel(total, large: true),
          const SizedBox(height: 5),
          Text('${list.length} assets displayed · UGX', style: const TextStyle(color: LG.muted)),
        ])),
        const SizedBox(height: 19),
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filter('All', null),
            ...AssetKind.values.map((kind) => _filter(kind.label, kind)),
          ])),
        const SizedBox(height: 17),
        TextField(onChanged: (s) => setState(() => query = s),
          decoration: const InputDecoration(hintText: 'Search name, location or provider',
            prefixIcon: Icon(Icons.search_rounded, color: LG.muted))),
        const SizedBox(height: 23),
        SectionHeading('Assets', trailing: Text('${list.length}',
          style: const TextStyle(color: LG.muted))),
        if (list.isEmpty) const EmptyHint(
          title: 'No assets to show', detail: 'Add an asset or change the search filter.',
          icon: Icons.account_balance_wallet_outlined)
        else ...list.map((asset) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: SoftCard(
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => AssetDetailScreen(store: widget.store, id: asset.id))),
            child: Row(children: [
              Container(width: 45, height: 45,
                decoration: BoxDecoration(color: LG.sageSoft, borderRadius: BorderRadius.circular(13)),
                child: Icon(assetIcon(asset.kind), color: LG.sageDark)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asset.name, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: LG.navy, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${asset.kind.label} · ${Fmt.date(asset.valuedAt)}',
                  style: const TextStyle(color: LG.muted, fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.money(ownedValue(asset), compact: true),
                  style: const TextStyle(color: LG.navy, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(valuationIsStale(asset, DateTime.now()) ? 'Review value' : sourceLabel(asset.valuationSource),
                  style: TextStyle(color: valuationIsStale(asset, DateTime.now())
                    ? LG.danger : LG.muted, fontSize: 11)),
              ]),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: LG.muted, size: 17),
            ]),
          ))),
        const SizedBox(height: 18),
        const InfoStrip(icon: Icons.info_outline_rounded,
          title: 'Valuation transparency',
          body: 'Owner estimates and provider statements are not independently verified. Review dates and sources regularly.'),
        const SizedBox(height: 20),
      ]);
  }

  Widget _filter(String label, AssetKind? kind) {
    final active = selected == kind;
    return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
      label: Text(label), selected: active, showCheckmark: false,
      backgroundColor: LG.white, selectedColor: LG.sageSoft,
      labelStyle: TextStyle(color: active ? LG.sageDark : LG.muted,
        fontWeight: active ? FontWeight.w800 : FontWeight.w500),
      side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      onSelected: (_) => setState(() => selected = kind),
    ));
  }
}

class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({super.key, required this.store, required this.id});
  final WealthStore store;
  final String id;
  @override
  Widget build(BuildContext context) {
    final matches = store.assets.where((a) => a.id == id).toList();
    if (matches.isEmpty) return const Scaffold(body: Center(child: Text('Asset not found')));
    final asset = matches.first;
    final links = store.debts.where((d) => d.linkedAssetId == asset.id).toList();
    final valuations = store.valuations.where((v) => v.assetId == id).toList();
    final transactions = store.entries.where((t) => t.assetId == id).take(5).toList();
    return LgPage(title: asset.name, showBack: true,
      subtitle: asset.kind.label, trailing: IconButton(
        tooltip: 'Edit asset', icon: const Icon(Icons.edit_outlined),
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => AssetEditor(store: store, existing: asset)))),
      children: [
        SoftCard(color: LG.sageSoft, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR OWNED VALUE', style: TextStyle(color: LG.sageDark,
            fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          MoneyLabel(ownedValue(asset), large: true),
          const SizedBox(height: 7),
          Text('${Fmt.percent(asset.ownershipBps)} ownership · ${sourceLabel(asset.valuationSource)}',
            style: const TextStyle(color: LG.muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text('As recorded ${Fmt.date(asset.valuedAt)}',
            style: const TextStyle(color: LG.muted, fontSize: 12)),
        ])),
        const SizedBox(height: 22),
        const SectionHeading('Asset information'),
        SoftCard(child: Column(children: [
          _detail('Full property/holding value', Fmt.money(asset.valueUgx)),
          const Divider(height: 24),
          _detail('Original cost (recorded)', Fmt.money(asset.costUgx)),
          if (asset.institution.isNotEmpty) ...[
            const Divider(height: 24),
            _detail('Provider / institution', asset.institution),
          ],
          if (asset.location.isNotEmpty) ...[
            const Divider(height: 24), _detail('Location', asset.location),
          ],
          const Divider(height: 24),
          _detail('Acquired', Fmt.date(asset.acquiredAt)),
          if (links.isNotEmpty) ...[
            const Divider(height: 24),
            _detail('Linked debt', Fmt.money(links.fold<int>(0, (s,d) => s + d.balanceUgx))),
            const Divider(height: 24),
            _detail('Equity in this asset', Fmt.money(propertyEquity(asset, links))),
          ],
        ])),
        const SizedBox(height: 22),
        SectionHeading('Valuation history', trailing: Text('${valuations.length} records',
          style: const TextStyle(color: LG.muted, fontSize: 12))),
        if (valuations.isEmpty) const EmptyHint(title: 'No valuations', detail: 'Add a valuation in Edit asset.')
        else SoftCard(child: Column(children: valuations.take(8).map((v) => ListTile(
          contentPadding: EdgeInsets.zero, title: Text(Fmt.money(v.valueUgx),
            style: const TextStyle(fontWeight: FontWeight.w800, color: LG.navy)),
          subtitle: Text('${Fmt.date(v.recordedAt)} · ${sourceLabel(v.source)}',
            style: const TextStyle(fontSize: 12, color: LG.muted)),
        )).toList())),
        if (transactions.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionHeading('Related transactions'),
          SoftCard(child: Column(children: transactions.map((t) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.category),
            subtitle: Text(Fmt.date(t.occurredAt)),
            trailing: Text(Fmt.money(t.amountUgx, compact: true)),
          )).toList())),
        ],
        if (asset.notes.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionHeading('Notes'),
          SoftCard(child: Text(asset.notes)),
        ],
        const SizedBox(height: 28),
        OutlinedButton.icon(onPressed: () async {
          if (!await askConfirm(context, 'Archive this asset?',
            'The asset will be removed from active net-worth totals but preserved in your records.',
            confirmLabel: 'Archive')) return;
          try {
            await store.archiveAsset(id);
            if (context.mounted) Navigator.pop(context);
          } catch (e) { if (context.mounted) showFailure(context, e); }
        }, icon: const Icon(Icons.archive_outlined), label: const Text('Archive asset')),
      ]);
  }
  Widget _detail(String key, String value) => Row(children: [
    Expanded(child: Text(key, style: const TextStyle(color: LG.muted, fontSize: 12.5))),
    const SizedBox(width: 10),
    Flexible(child: Text(value, textAlign: TextAlign.right,
      style: const TextStyle(color: LG.navy, fontWeight: FontWeight.w700, fontSize: 13))),
  ]);
}

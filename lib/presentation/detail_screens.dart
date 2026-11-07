import 'package:flutter/material.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/finance.dart';
import '../domain/models.dart';
import 'components.dart';
import 'forms.dart';
import 'widgets.dart';
import 'wealth_screens.dart';

/// Shows the full context of a single ledger entry (E05). Offers a reverse
/// action only when the entry is not itself a reversal and has not already
/// been reversed.
class TransactionDetailScreen extends StatelessWidget {
  final PortfolioStore store;
  final LedgerEvent event;
  const TransactionDetailScreen(
      {super.key, required this.store, required this.event});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final current = store.state.events
            .firstWhere((e) => e.id == event.id, orElse: () => event);
        final reversed = eventIsReversed(current, store.state.events);
        final reversal = current.kind == EventKind.reversal
            ? store.state.events.firstWhere(
                (e) => e.id == current.reversalOf,
                orElse: () => current)
            : null;
        final linkedAsset = current.assetId == null
            ? null
            : store.state.assets.firstWhere(
                (a) => a.id == current.assetId,
                orElse: () => WealthAsset(
                    id: current.assetId!,
                    name: 'Archived asset',
                    kind: AssetKind.other,
                    valueUgx: 0,
                    valuedAt: DateTime(1970)));

        return WealthPage(
            title: 'Transaction',
            subtitle: current.description,
            children: [
              SoftCard(
                  color: current.kind == EventKind.reversal
                      ? const Color(0xFFF8EAE7)
                      : LG.sageSoft,
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: LG.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(_iconFor(current.kind),
                          color:
                              current.kind == EventKind.reversal ? LG.negative : LG.sage),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(current.kind.name,
                              style: const TextStyle(
                                  color: LG.muted,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(LG.money(current.amountUgx),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 20)),
                        ])),
                    if (reversed) const StatusChip(label: 'Reversed', tone: StatusTone.danger)
                  ])),
              const SizedBox(height: 18),
              SoftCard(
                  child: Column(children: [
                InfoLabel(label: 'Recorded on', value: LG.date(current.occurredAt)),
                InfoLabel(label: 'Entry type', value: current.kind.name),
                if (linkedAsset != null)
                  InfoLabel(label: 'Linked asset', value: linkedAsset.name),
                if (current.notes.isNotEmpty)
                  InfoLabel(label: 'Notes', value: current.notes),
                if (current.reversalOf != null && reversal != null)
                  InfoLabel(
                      label: 'Reverses entry',
                      value: reversal.description),
              ])),
              if (!reversed && current.kind != EventKind.reversal) ...[
                const SizedBox(height: 20),
                PrimaryCTA(
                  label: 'Reverse this entry',
                  showArrow: false,
                  onPressed: () async {
                    final confirm = await confirmActionSheet(context,
                        title: 'Append a reversal?',
                        consequence:
                            'The original entry stays in the ledger. A new reversal entry will be appended so totals reconcile.',
                        confirmLabel: 'Append reversal');
                    if (!confirm) return;
                    try {
                      await store.reverseEvent(current);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not reverse: $e')));
                    }
                  },
                ),
              ],
              if (current.kind == EventKind.reversal) ...[
                const SizedBox(height: 16),
                const SecurityNotice(
                  title: 'This is a reversal entry',
                  message:
                      'Reversal entries exist to document corrections. They are append-only and cannot themselves be reversed.',
                  icon: Icons.info_outline,
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                  'The transaction ledger is append-only. Every reversal preserves the original entry so audit history stays intact.',
                  style: TextStyle(color: LG.muted, fontSize: 12, height: 1.5)),
            ]);
      });

  static IconData _iconFor(EventKind kind) => switch (kind) {
        EventKind.contribution => Icons.input,
        EventKind.withdrawal => Icons.output,
        EventKind.dividend => Icons.payments_outlined,
        EventKind.interest => Icons.percent_rounded,
        EventKind.rent => Icons.home_work_outlined,
        EventKind.fee => Icons.monetization_on_outlined,
        EventKind.tax => Icons.receipt_long_outlined,
        EventKind.expense => Icons.shopping_cart_outlined,
        EventKind.transfer => Icons.swap_horiz,
        EventKind.adjustment => Icons.tune,
        EventKind.reversal => Icons.undo,
      };
}

/// Liability detail screen (E02) accessed by tapping a row on DebtsScreen
/// or from the portfolio search. Keeps edit + archive discoverable without
/// requiring the user to go through the form each time.
class LiabilityDetailScreen extends StatelessWidget {
  final PortfolioStore store;
  final Liability liability;
  const LiabilityDetailScreen(
      {super.key, required this.store, required this.liability});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final current = store.state.liabilities.firstWhere(
            (l) => l.id == liability.id,
            orElse: () => liability);
        final linkedProperty = current.propertyId == null
            ? null
            : store.state.assets.firstWhere(
                (a) => a.id == current.propertyId,
                orElse: () => WealthAsset(
                    id: current.propertyId!,
                    name: 'Archived property',
                    kind: AssetKind.property,
                    valueUgx: 0,
                    valuedAt: DateTime(1970)));
        return WealthPage(
            title: 'Liability',
            subtitle: current.name,
            children: [
              SoftCard(
                  color: LG.navy,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('OUTSTANDING BALANCE',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(LG.money(current.outstandingUgx),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('As of ${LG.date(current.asOf)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
              const SizedBox(height: 18),
              SoftCard(
                  child: Column(children: [
                if (current.lender.isNotEmpty)
                  InfoLabel(label: 'Lender', value: current.lender),
                if (current.principalUgx > 0)
                  InfoLabel(
                      label: 'Original principal',
                      value: LG.money(current.principalUgx)),
                if (current.dueAt != null)
                  InfoLabel(label: 'Due', value: LG.date(current.dueAt!)),
                if (linkedProperty != null)
                  InfoLabel(
                      label: 'Linked property', value: linkedProperty.name),
                if (current.notes.isNotEmpty)
                  InfoLabel(label: 'Notes', value: current.notes),
                InfoLabel(
                    label: 'Archived',
                    value: current.archived ? 'Yes' : 'No',
                    valueColor:
                        current.archived ? LG.negative : LG.navy),
              ])),
              if (linkedProperty != null) ...[
                const SizedBox(height: 14),
                const SecurityNotice(
                  title: 'Linked mortgage',
                  message:
                      'Because this liability is linked to a property, net worth already subtracts it once from the owner-attributable property value. It is not double-counted.',
                  icon: Icons.account_balance_outlined,
                ),
              ],
              const SizedBox(height: 22),
              PrimaryCTA(
                label: 'Edit liability',
                showArrow: false,
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => LiabilityForm(store: store, existing: current)));
                },
              ),
              const SizedBox(height: 10),
              if (!current.archived)
                TextButton(
                    onPressed: () async {
                      final confirm = await confirmActionSheet(context,
                          title: 'Archive this liability?',
                          consequence:
                              'Archived liabilities are excluded from net worth. You can restore them from Settings → Archived records.',
                          confirmLabel: 'Archive');
                      if (!confirm) return;
                      await store.archiveLiability(current);
                      if (!context.mounted) return;
                      Navigator.of(context).maybePop();
                    },
                    child: const Text('Archive liability',
                        style: TextStyle(color: LG.negative)))
              else
                TextButton(
                    onPressed: () async {
                      await store.restoreLiability(current);
                      if (!context.mounted) return;
                      Navigator.of(context).maybePop();
                    },
                    child: const Text('Restore liability',
                        style: TextStyle(color: LG.sage))),
            ]);
      });
}

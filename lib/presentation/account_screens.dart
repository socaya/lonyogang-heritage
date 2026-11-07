import 'package:flutter/material.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import 'components.dart';
import 'widgets.dart';
import 'wealth_screens.dart';

/// Data and sync status (I11). Surfaces what is persisted, when it was last
/// saved, what protections are in place, and that no remote sync exists —
/// the spec wants this clearly labelled rather than silently implied.
class DataSyncStatusScreen extends StatelessWidget {
  final PortfolioStore store;
  const DataSyncStatusScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final encrypted = store.vault.hasPassphrase;
        final attachments = store.state.documents
            .where((d) => !d.archived && d.attachment != null)
            .length;
        final lastSaved = store.lastSavedAt;
        return WealthPage(
            title: 'Data & sync',
            subtitle:
                'How your records are stored on this device. No remote sync is active.',
            children: [
              SoftCard(
                  color: encrypted ? LG.sageSoft : LG.white,
                  child: Row(children: [
                    Icon(encrypted ? Icons.lock : Icons.devices_outlined,
                        color: encrypted ? LG.sage : LG.muted, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            encrypted
                                ? 'Your portfolio is AES-GCM encrypted on this device under a passphrase-derived key.'
                                : 'Your portfolio is stored in cleartext on this device. Enable a passphrase from More → Encryption to protect it.',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.45))),
                  ])),
              const SizedBox(height: 18),
              const SectionTitle('Local state'),
              SoftCard(
                  child: Column(children: [
                InfoLabel(
                    label: 'Owner name',
                    value: store.state.ownerName.isEmpty
                        ? 'Not set'
                        : store.state.ownerName),
                InfoLabel(
                    label: 'Onboarding',
                    value:
                        store.state.onboardingDone ? 'Complete' : 'Incomplete'),
                InfoLabel(
                    label: 'Demo data loaded',
                    value: store.isDemo ? 'Yes' : 'No'),
                InfoLabel(
                    label: 'Last saved',
                    value: lastSaved == null
                        ? 'Never'
                        : '${LG.date(lastSaved)} at ${lastSaved.hour.toString().padLeft(2, '0')}:${lastSaved.minute.toString().padLeft(2, '0')}'),
                if (store.loadError != null)
                  InfoLabel(
                      label: 'Last error',
                      value: store.loadError!,
                      valueColor: LG.negative),
              ])),
              const SizedBox(height: 18),
              const SectionTitle('What is being tracked'),
              SoftCard(
                  child: Column(children: [
                InfoLabel(
                    label: 'Active assets',
                    value: store.state.assets
                        .where((a) => !a.archived)
                        .length
                        .toString()),
                InfoLabel(
                    label: 'Active liabilities',
                    value: store.state.liabilities
                        .where((l) => !l.archived)
                        .length
                        .toString()),
                InfoLabel(
                    label: 'Ledger entries',
                    value: store.state.events.length.toString()),
                InfoLabel(
                    label: 'Valuation samples',
                    value: store.state.valuations.length.toString()),
                InfoLabel(
                    label: 'Documents with files',
                    value: attachments.toString()),
                InfoLabel(
                    label: 'FX rates recorded',
                    value: store.state.fxRates.length.toString()),
                InfoLabel(
                    label: 'Active schedules',
                    value: store.state.scheduled
                        .where((s) => s.active)
                        .length
                        .toString()),
              ])),
              const SizedBox(height: 18),
              const SectionTitle('Remote state'),
              const SoftCard(
                  child: Column(children: [
                InfoLabel(label: 'Cloud sync', value: 'Not connected'),
                InfoLabel(label: 'Server account', value: 'Not configured'),
                InfoLabel(label: 'Multi-device access', value: 'Not available'),
                InfoLabel(label: 'Server-backed recovery', value: 'Not available'),
              ])),
              const SizedBox(height: 18),
              const SecurityNotice(
                title: 'No silent cloud backup',
                message:
                    'This preview intentionally never uploads your portfolio. Use JSON export under Settings → Data management to make an offline backup; keep it somewhere safe.',
                icon: Icons.cloud_off_outlined,
              ),
            ]);
      });
}

/// Entry-point shown in Settings that triggers the full local data reset
/// (I10). Separated from SettingsScreen so the confirmActionSheet copy
/// can be audited in one place.
Future<void> runLocalReset(BuildContext context, PortfolioStore store) async {
  final confirmed = await confirmActionSheet(
    context,
    title: 'Reset local portfolio?',
    consequence:
        'Every asset, liability, ledger entry, valuation, schedule, document record and encrypted attachment on this device will be removed. Encryption will be turned off. An unencrypted JSON export can be imported again afterwards. This cannot be undone.',
    confirmLabel: 'Reset everything',
  );
  if (!confirmed) return;
  await store.resetLocal();
  if (!context.mounted) return;
  Navigator.of(context).popUntil((r) => r.isFirst);
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Local portfolio reset. You can start over or import a JSON export.')));
}

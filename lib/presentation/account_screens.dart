import 'package:flutter/material.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../data/remote_sync.dart';
import '../data/resource_hydrator.dart';
import '../data/sync.dart';
import '../data/sync_reducer.dart';
import 'components.dart';
import 'online_account_screen.dart';
import 'online_privacy_screen.dart';
import 'online_scope.dart';
import 'widgets.dart';
import 'wealth_screens.dart';

/// Data and sync status (I11). Surfaces what is persisted, when it was last
/// saved, what protections are in place, and that no remote sync exists —
/// the spec wants this clearly labelled rather than silently implied.
class DataSyncStatusScreen extends StatelessWidget {
  final PortfolioStore store;
  final SyncService? sync;
  const DataSyncStatusScreen({super.key, required this.store, this.sync});
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
              if (store.loadError != null) ...[
                const SizedBox(height: 10),
                ErrorState(
                  message: store.loadError!,
                  retryLabel: 'Retry load',
                  onRetry: () async {
                    await store.load();
                  },
                ),
              ],
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
              _RemoteStatusCard(sync: sync),
              _OnlineAccountCta(sync: sync),
              _ResourceHydrateCta(store: store),
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

/// Compact widget that listens to [SyncService.status] (when supplied) and
/// renders honest "Not connected" state otherwise. Never claims connectivity
/// unless the service itself reports [SyncStatus.ready].
class _RemoteStatusCard extends StatelessWidget {
  final SyncService? sync;
  const _RemoteStatusCard({required this.sync});
  @override
  Widget build(BuildContext context) {
    final service = sync;
    if (service == null) {
      return const SoftCard(
          child: Column(children: [
        InfoLabel(label: 'Cloud sync', value: 'Not connected'),
        InfoLabel(label: 'Server account', value: 'Not configured'),
        InfoLabel(label: 'Multi-device access', value: 'Not available'),
        InfoLabel(label: 'Server-backed recovery', value: 'Not available'),
      ]));
    }
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: service.status,
      builder: (context, status, _) {
        final connected = status == SyncStatus.ready || status == SyncStatus.syncing;
        return SoftCard(
            child: Column(children: [
          InfoLabel(
              label: 'Cloud sync',
              value: describeSyncStatus(status),
              valueColor: connected ? LG.sage : null),
          InfoLabel(
              label: 'Server account',
              value: connected ? 'Configured' : 'Not configured'),
          InfoLabel(
              label: 'Multi-device access',
              value: connected ? 'Available' : 'Not available'),
          InfoLabel(
              label: 'Server-backed recovery',
              value: connected ? 'Available' : 'Not available'),
          if (service.lastError != null) ...[
            const Divider(),
            InfoLabel(
                label: 'Last sync error',
                value: service.lastError!,
                valueColor: LG.negative),
          ],
        ]));
      },
    );
  }
}

/// Offers the real online onboarding flow when the app was launched with
/// a backend URL. Hidden when `sync` is null or already a Noop so the UI
/// never advertises a service that cannot actually run.
class _OnlineAccountCta extends StatelessWidget {
  final SyncService? sync;
  const _OnlineAccountCta({required this.sync});
  @override
  Widget build(BuildContext context) {
    final scope = OnlineScope.maybeOf(context);
    final remote = scope?.sync;
    if (remote == null) return const SizedBox.shrink();
    return FutureBuilder<bool>(
      future: scope!.credentials.load().then((c) => c != null),
      builder: (context, snap) {
        final signedIn = snap.data ?? false;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(children: [
            PrimaryCTA(
              label: signedIn ? 'Switch online account' : 'Connect online account',
              showArrow: false,
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => OnlineAccountScreen(
                          sync: remote,
                          credentials: scope.credentials,
                        )));
              },
            ),
            if (signedIn) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => OnlinePrivacyScreen(
                            baseUri: remote.baseUri,
                            credentials: scope.credentials,
                          )));
                },
                icon: const Icon(Icons.policy_outlined),
                label: const Text('Online privacy & data-subject rights'),
              ),
            ],
          ]),
        );
      },
    );
  }
}

/// "Rehydrate from server" entry. Pulls every supported resource kind
/// from /resources/:kind and feeds each row through the SyncReducer so
/// the local portfolio converges with the server's view. Useful on a
/// fresh install, or after a conflict the user wants to resolve by
/// trusting the server's state.
class _ResourceHydrateCta extends StatefulWidget {
  final PortfolioStore store;
  const _ResourceHydrateCta({required this.store});
  @override
  State<_ResourceHydrateCta> createState() => _ResourceHydrateCtaState();
}

class _ResourceHydrateCtaState extends State<_ResourceHydrateCta> {
  bool _busy = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final scope = OnlineScope.maybeOf(context);
    final remote = scope?.sync;
    if (remote == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton.icon(
          onPressed: _busy || !widget.store.isUnlocked
              ? null
              : () => _run(remote),
          icon: const Icon(Icons.cloud_download_outlined),
          label: Text(_busy ? 'Rehydrating…' : 'Rehydrate from server'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 6),
          Text(_status!,
              style: const TextStyle(color: LG.muted, fontSize: 12)),
        ],
      ]),
    );
  }

  Future<void> _run(RemoteSyncService remote) async {
    final confirmed = await confirmActionSheet(
      context,
      title: 'Rehydrate from server?',
      consequence:
          'Pulls every record the server has on file for this account and merges it into the local portfolio under the vault content key. Existing local entries with the same id will be overwritten with the server copy.',
      confirmLabel: 'Rehydrate',
    );
    if (!confirmed) return;
    setState(() {
      _busy = true;
      _status = 'Starting…';
    });
    try {
      final hydrator = ResourceHydrator(
        remote: remote,
        reducer: SyncReducer(widget.store,
            attachmentSyncer: widget.store.attachmentSyncer),
      );
      final result = await hydrator.hydrate(onProgress: (tick) {
        setState(() => _status = '${tick.kind}: +${tick.applied}');
      });
      setState(() => _status =
          'Done: ${result.applied} applied, ${result.skipped} skipped');
    } catch (err) {
      setState(() => _status = 'Rehydration failed: $err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
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

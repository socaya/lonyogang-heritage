import 'dart:async';

import 'package:flutter/foundation.dart';

import 'remote_sync.dart';
import 'sync_reducer.dart';

/// One kind we know how to pull back from the REST layer, in the order
/// we want the reducer to replay them. Beneficiaries and alerts land
/// last so earlier upserts (assets, liabilities, documents) are already
/// present when the final merge runs.
const List<String> _hydrationOrder = [
  'asset',
  'liability',
  'ledger_event',
  'valuation',
  'document_record',
  'goal',
  'reminder',
  'trusted_contact',
  'schedule',
  'fx_rate',
  'beneficiary_batch',
  'alert_dismissal',
];

/// Progress ticks emitted by [ResourceHydrator.hydrate]. The UI uses this
/// to render a step counter while a new device is pulling its state.
class HydrationProgress {
  final String kind;
  final int applied;
  final int skipped;
  final int total;
  const HydrationProgress({
    required this.kind,
    required this.applied,
    required this.skipped,
    required this.total,
  });
}

/// Pulls the current state of every supported resource kind from the
/// server and hands each row to [SyncReducer], which decrypts it under
/// the vault content key and merges it into the local portfolio.
///
/// This is the "new install" bootstrap path. The periodic sync still
/// uses /sync/events for ordered incremental delivery; the hydrator is
/// used exactly once per device when the outbox cursor is absent, or on
/// demand from Settings when the user wants to force-reconcile.
class ResourceHydrator {
  ResourceHydrator({required this.remote, required this.reducer});

  final RemoteSyncService remote;
  final SyncReducer reducer;

  /// Runs through every kind in order. Emits a [HydrationProgress] tick
  /// per kind through [onProgress] so the caller can update the UI.
  /// Returns a running total of applied + skipped rows.
  Future<HydrationProgress> hydrate({
    void Function(HydrationProgress tick)? onProgress,
  }) async {
    int applied = 0;
    int skipped = 0;
    for (final kind in _hydrationOrder) {
      final rows = await remote.listResources(kind, includeDeleted: true);
      for (final row in rows) {
        if (row.isDeleted) {
          // Translate the server-side tombstone into the matching
          // *_delete call on the local store. Without this a deletion
          // made on device A would stay invisible to a device-B fresh
          // hydrate until the /sync/events pull caught up.
          if (await _applyDeletion(kind, row.id)) {
            applied += 1;
          } else {
            skipped += 1;
          }
          continue;
        }
        // Shape the RemoteResource into the same envelope the reducer
        // already understands from /sync/events pulls.
        final record = RemoteSyncEventRecord(
          id: '${row.kind}:${row.id}:${row.version}',
          deviceId: row.deviceId,
          payloadType: row.kind,
          payload: row.ciphertext,
          prevHash: row.prevHash,
          hash: Uint8List(0),
          integrity: row.integrity,
          receivedAt: row.updatedAt,
          createdAt: row.createdAt,
        );
        final applied1 = await reducer.apply(record);
        if (applied1) {
          applied += 1;
        } else {
          skipped += 1;
        }
      }
      onProgress?.call(HydrationProgress(
        kind: kind,
        applied: applied,
        skipped: skipped,
        total: applied + skipped,
      ));
    }
    return HydrationProgress(
      kind: 'done',
      applied: applied,
      skipped: skipped,
      total: applied + skipped,
    );
  }

  /// Applies a tombstone by calling the matching mutation on the store.
  /// Returns true if the record was present locally and removed; false
  /// if it was already absent.
  Future<bool> _applyDeletion(String kind, String id) async {
    final store = reducer.store;
    switch (kind) {
      case 'goal':
        if (!store.state.goals.any((g) => g.id == id)) return false;
        await store.deleteGoal(id);
        return true;
      case 'reminder':
        if (!store.state.reminders.any((r) => r.id == id)) return false;
        await store.removeReminder(id);
        return true;
      case 'trusted_contact':
        if (!store.state.contacts.any((c) => c.id == id)) return false;
        await store.removeContact(id);
        return true;
      case 'schedule':
        if (!store.state.scheduled.any((s) => s.id == id)) return false;
        await store.deleteSchedule(id);
        return true;
      case 'document_record':
        if (!store.state.documents.any((d) => d.id == id)) return false;
        // Documents are archived rather than hard-deleted. Server-side
        // tombstone + local archive is close enough for a heritage
        // tracker; a future "purge" job can walk archived documents.
        final existing =
            store.state.documents.firstWhere((d) => d.id == id);
        await store.upsertDocument(existing.copyWith(archived: true));
        return true;
      case 'asset':
        {
          final existing = store.state.assets
              .where((a) => a.id == id)
              .cast<dynamic>()
              .firstOrNull;
          if (existing == null) return false;
          await store.archiveAsset(existing);
          return true;
        }
      case 'liability':
        {
          final existing = store.state.liabilities
              .where((l) => l.id == id)
              .cast<dynamic>()
              .firstOrNull;
          if (existing == null) return false;
          await store.archiveLiability(existing);
          return true;
        }
      case 'beneficiary_batch':
        // Deletion of the whole batch means "no beneficiaries". Server
        // publishes this by tombstoning the /resources/beneficiary_batch/all
        // row; replay by clearing the local list.
        for (final b in [...store.state.beneficiaries]) {
          await store.deleteBeneficiary(b.id);
        }
        return true;
      default:
        return false;
    }
  }
}

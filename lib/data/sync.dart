import 'package:flutter/foundation.dart';

/// Status surface for the eventual online-sync integration. The 0.4 client
/// ships only [NoopSyncService]; the enum and interface exist so the UI can
/// render honest state and so the backend plan (`docs/ONLINE_SERVICE_PLAN.md`)
/// can bolt in without rewriting screens.
enum SyncStatus {
  /// User has not configured an account yet. Default on first run.
  disconnected,

  /// The client is in the middle of bootstrapping an account or restoring
  /// credentials from secure storage.
  connecting,

  /// Credentials are present; the client is idle and in sync with the
  /// server. Reserved for the real [RemoteSyncService]; [NoopSyncService]
  /// never reports this state so no screen can claim connectivity falsely.
  ready,

  /// An exchange is in progress.
  syncing,

  /// The last exchange failed. The error reason is exposed via [SyncService.lastError].
  error,

  /// Credentials are present but the device cannot reach the server right now.
  offline,
}

/// Minimal contract every implementation must honour. The 0.4 UI only
/// consumes [status] and [lastError]; the push/pull primitives are reserved
/// for later phases described in the online-service plan.
abstract class SyncService {
  ValueListenable<SyncStatus> get status;
  String? get lastError;
  Future<void> sync();
  Future<void> wipeLocalCredentials();
}

/// Default implementation used throughout 0.4. Never reports `ready`; every
/// call is a no-op. Replace at `main()` wire-up when the real client ships.
class NoopSyncService implements SyncService {
  final ValueNotifier<SyncStatus> _status =
      ValueNotifier<SyncStatus>(SyncStatus.disconnected);
  @override
  ValueListenable<SyncStatus> get status => _status;
  @override
  String? get lastError => null;
  @override
  Future<void> sync() async {
    // Intentional no-op. Keeps the UI honest — nothing has been synchronised.
  }
  @override
  Future<void> wipeLocalCredentials() async {}
}

/// Human-readable label for [SyncStatus], centralised so that status text is
/// consistent across the DataSyncStatusScreen and any future place we surface
/// the state (e.g. a More-tab badge).
String describeSyncStatus(SyncStatus status) => switch (status) {
      SyncStatus.disconnected => 'Not connected',
      SyncStatus.connecting => 'Connecting…',
      SyncStatus.ready => 'Ready',
      SyncStatus.syncing => 'Syncing…',
      SyncStatus.error => 'Sync error',
      SyncStatus.offline => 'Offline',
    };

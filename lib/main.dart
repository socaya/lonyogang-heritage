import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/design.dart';
import 'data/attachment_syncer.dart';
import 'data/credentials_store.dart';
import 'data/notifications.dart';
import 'data/portfolio_store.dart';
import 'data/remote_sync.dart';
import 'data/resource_hydrator.dart';
import 'data/resource_publisher.dart';
import 'data/sync.dart';
import 'data/sync_outbox.dart';
import 'data/sync_reducer.dart';
import 'presentation/app.dart';
import 'presentation/onboarding_screens.dart';
import 'presentation/online_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final outbox = SyncOutbox();
  final NotificationScheduler scheduler =
      kIsWeb ? NoopNotificationScheduler() : LocalNotificationScheduler();
  final credentials = CredentialsStore();
  final backendBase = Uri.tryParse(
    const String.fromEnvironment('LONYOGANG_BACKEND_URL', defaultValue: ''),
  );
  final hasBackend = backendBase != null && backendBase.toString().isNotEmpty;
  final AttachmentSyncer? attachmentSyncer = hasBackend
      ? AttachmentSyncer(baseUri: backendBase, credentials: credentials)
      : null;
  // Build the RemoteSyncService first so the PortfolioStore can mirror
  // its writes to /resources/:kind/:id as well as the outbox.
  RemoteSyncService? remoteSync;
  PortfolioStore lateStore;
  final reducerHolder = <SyncReducer>[];
  if (hasBackend) {
    remoteSync = RemoteSyncService(
      baseUri: backendBase,
      credentialsLoader: credentials.load,
      credentialsSaver: credentials.save,
      outboxLoader: outbox.snapshot,
      pullHandler: (record) async {
        if (reducerHolder.isNotEmpty) {
          await reducerHolder.first.apply(record);
        }
      },
    );
  }
  lateStore = PortfolioStore(
    outbox: outbox,
    attachmentSyncer: attachmentSyncer,
    resourcePublisher:
        remoteSync == null ? null : ResourcePublisher(remote: remoteSync),
  );
  final reducer = SyncReducer(lateStore, attachmentSyncer: attachmentSyncer);
  reducerHolder.add(reducer);
  final store = lateStore;
  final SyncService sync = remoteSync ?? NoopSyncService();
  runApp(LonyoGangApp(
    store: store,
    scheduler: scheduler,
    sync: sync,
    credentials: credentials,
  ));
}

/// Root MaterialApp. Displays [SplashScreen] while the portfolio loads on
/// first launch; thereafter renders [AppRoot], which gates on vault lock
/// state and onboarding completion. Tests can inject a pre-loaded store or
/// shorten the splash via [splashDuration].
class LonyoGangApp extends StatefulWidget {
  final PortfolioStore store;
  final NotificationScheduler? scheduler;
  final SyncService? sync;
  final CredentialsStore? credentials;
  final Duration? splashDuration;
  const LonyoGangApp(
      {super.key,
      required this.store,
      this.scheduler,
      this.sync,
      this.credentials,
      this.splashDuration});
  @override
  State<LonyoGangApp> createState() => _LonyoGangAppState();
}

class _LonyoGangAppState extends State<LonyoGangApp>
    with WidgetsBindingObserver {
  bool _schedulerReady = false;
  Timer? _syncTimer;
  Timer? _syncDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_syncScheduler);
    widget.store.addListener(_scheduleRemoteSync);
    _startSyncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_syncScheduler);
    widget.store.removeListener(_scheduleRemoteSync);
    _syncTimer?.cancel();
    _syncDebounce?.cancel();
    super.dispose();
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _runRemoteSync(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Pause the sync cadence while we're not visible so the radio
        // and battery aren't drained by background pulls. The debounce
        // timer is cancelled too — we'll start a fresh cycle on resume.
        _syncTimer?.cancel();
        _syncTimer = null;
        _syncDebounce?.cancel();
        _syncDebounce = null;
        break;
      case AppLifecycleState.resumed:
        // Fire one immediate sync to catch up on anything missed while
        // backgrounded, then resume the 2-minute cadence.
        unawaited(_runRemoteSync());
        _startSyncTimer();
        break;
      case AppLifecycleState.inactive:
        // Brief transition (e.g. phone call overlay) — keep the timer.
        break;
    }
  }

  void _scheduleRemoteSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), _runRemoteSync);
  }

  Future<void> _runRemoteSync() async {
    final sync = widget.sync;
    if (sync == null) return;
    try {
      // Opportunistic attachment upload retry — picks up anything that
      // was attached while offline so the document rows the outbox has
      // already pushed get their serverId back-filled on the next tick.
      await widget.store.retryPendingAttachments();
      await sync.sync();
    } catch (_) {
      // Transient network issues are swallowed; the status surface in
      // DataSyncStatusScreen renders the resulting state.
    }
  }

  Future<void> _syncScheduler() async {
    final scheduler = widget.scheduler;
    if (scheduler == null || !_schedulerReady) return;
    try {
      await scheduler.syncWith(
          computeScheduledAlerts(widget.store.state, DateTime.now()));
    } catch (_) {
      // Platform channel may not be available (tests, unsupported devices).
    }
  }

  Future<void> _primeScheduler() async {
    final scheduler = widget.scheduler;
    if (scheduler == null) return;
    try {
      await scheduler.initialize();
      _schedulerReady = true;
      await _syncScheduler();
    } catch (e) {
      debugPrint('Notification scheduler unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = widget.sync;
    final remote = syncService is RemoteSyncService ? syncService : null;
    return OnlineScope(
      sync: remote,
      credentials: widget.credentials ?? CredentialsStore(),
      onSignInSuccess: remote == null
          ? null
          : () async {
              // Opportunistic hydrate on sign-in: only when the local
              // store looks essentially empty (fresh-install signal).
              // A returning user who signs out and back in keeps their
              // local state and relies on the /sync/events pull to
              // reconcile — otherwise this would overwrite any edits
              // that hadn't finished syncing yet.
              final s = widget.store.state;
              final looksEmpty = s.assets.isEmpty &&
                  s.liabilities.isEmpty &&
                  s.events.isEmpty &&
                  s.goals.isEmpty &&
                  s.documents.isEmpty &&
                  s.scheduled.isEmpty;
              if (widget.store.isUnlocked &&
                  widget.store.vault.activeKey != null &&
                  looksEmpty) {
                try {
                  await ResourceHydrator(
                    remote: remote,
                    reducer: SyncReducer(widget.store,
                        attachmentSyncer: widget.store.attachmentSyncer),
                  ).hydrate();
                } catch (_) {
                  // Hydration is best-effort; fall through to the event stream.
                }
              }
              // Populate the local ownerName from the server-known
              // displayName so a fresh install renders "Hi, <name>"
              // right away instead of the empty-state greeting.
              try {
                final me = await remote.fetchMe();
                final name = me['displayName']?.toString().trim();
                if (name != null &&
                    name.isNotEmpty &&
                    widget.store.state.ownerName.isEmpty) {
                  await widget.store.setOwner(name);
                }
              } catch (_) {
                // Profile fetch failed → leave ownerName as-is; the
                // user can still edit it from Profile.
              }
              await remote.sync();
            },
      child: MaterialApp(
        title: 'LonyoGang Heritage',
        debugShowCheckedModeBanner: false,
        theme: LG.theme,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => NotFoundScreen(attemptedTarget: settings.name)),
        home: widget.store.isLoaded
            ? AppRoot(store: widget.store)
            : SplashScreen(
                store: widget.store,
                minimumVisible:
                    widget.splashDuration ?? const Duration(milliseconds: 650),
                onReady: (context) async {
                  await _primeScheduler();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                      builder: (_) => AppRoot(store: widget.store)));
                },
              ),
      ),
    );
  }
}

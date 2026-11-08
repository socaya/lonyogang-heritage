import 'package:flutter/widgets.dart';

import '../data/credentials_store.dart';
import '../data/remote_sync.dart';

/// InheritedWidget that lets any screen reach the active [RemoteSyncService]
/// without routing it through every widget constructor. Boots to null when
/// the app was built without a backend URL — callers must handle the absent
/// case gracefully (and usually hide the online-only UI entirely).
class OnlineScope extends InheritedWidget {
  final RemoteSyncService? sync;
  final CredentialsStore credentials;
  /// Fired by the sign-in flows after credentials have been persisted so
  /// the app shell can hydrate the vault from /resources (new-device
  /// install), start a /sync/events pull, and transition the UI. Wired
  /// in main.dart; null in tests that only need the scope for widget
  /// wiring.
  final Future<void> Function()? onSignInSuccess;
  const OnlineScope({
    super.key,
    required this.sync,
    required this.credentials,
    this.onSignInSuccess,
    required super.child,
  });

  static OnlineScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnlineScope>();

  @override
  bool updateShouldNotify(covariant OnlineScope oldWidget) =>
      oldWidget.sync != sync ||
      oldWidget.credentials != credentials ||
      oldWidget.onSignInSuccess != onSignInSuccess;
}

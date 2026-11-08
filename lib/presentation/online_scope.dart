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
  const OnlineScope({
    super.key,
    required this.sync,
    required this.credentials,
    required super.child,
  });

  static OnlineScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnlineScope>();

  @override
  bool updateShouldNotify(covariant OnlineScope oldWidget) =>
      oldWidget.sync != sync || oldWidget.credentials != credentials;
}

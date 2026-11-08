import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/crypto.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/data/remote_sync.dart';
import 'package:lonyogang_heritage/data/sync_outbox.dart';
import 'package:lonyogang_heritage/data/sync_reducer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Replaying a pulled event does not re-emit it to the outbox',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');

    final vaultKey = store.vault.activeKey!;
    final contentKey = await SyncOutbox.deriveContentKey(vaultKey);

    // Encrypt a goal payload as a remote event.
    final payload = {
      'id': 'remote-goal',
      'name': 'Peer goal',
      'targetUgx': 100,
      'savedUgx': 0,
    };
    final ciphertext = await VaultCrypto.encryptBytes(
        utf8.encode(jsonEncode(payload)), contentKey);

    // deviceId must differ from the store's own, so the reducer treats
    // the event as a cross-device replay rather than our own write.
    final record = RemoteSyncEventRecord(
      id: 'evt-1',
      deviceId: 'other-device',
      payloadType: 'goal',
      payload: Uint8List.fromList(ciphertext),
      prevHash: null,
      hash: Uint8List(0),
      integrity: null,
      receivedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final reducer = SyncReducer(store);
    final beforeCount = (await outbox.snapshot()).length;
    final applied = await reducer.apply(record);
    final afterCount = (await outbox.snapshot()).length;

    expect(applied, isTrue);
    expect(store.state.goals.any((g) => g.id == 'remote-goal'), isTrue);
    // Critical: the replay must NOT have added a new outbox entry —
    // otherwise devices ping-pong each other forever.
    expect(afterCount, beforeCount);
  });
}

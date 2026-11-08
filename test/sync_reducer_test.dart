import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/crypto.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/data/remote_sync.dart';
import 'package:lonyogang_heritage/data/sync_outbox.dart';
import 'package:lonyogang_heritage/data/sync_reducer.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('applies an incoming encrypted asset event and upserts it locally',
      () async {
    final store = PortfolioStore();
    await store.load();
    await store.setOwner('Sync owner');
    await store.enablePassphrase('passphrase-of-length-12');
    final vaultKey = store.vault.activeKey!;
    final contentKey = await SyncOutbox.deriveContentKey(vaultKey);
    final reducer = SyncReducer(store);

    final asset = WealthAsset(
      id: 'remote-asset-1',
      name: 'Imported plot',
      kind: AssetKind.property,
      valueUgx: 42000000,
      ownershipBps: 10000,
      valuedAt: DateTime(2026, 11, 1),
    );
    final cipher = await VaultCrypto.encryptBytes(
        utf8.encode(jsonEncode(asset.toJson())), contentKey);

    final record = RemoteSyncEventRecord(
      id: 'srv-event-1',
      deviceId: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
      payloadType: 'asset',
      payload: cipher,
      prevHash: null,
      hash: cipher.sublist(0, 32),
      integrity: null,
      receivedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final applied = await reducer.apply(record);
    expect(applied, isTrue);
    expect(store.state.assets.any((a) => a.id == 'remote-asset-1'), isTrue);
    expect(
        store.state.assets.firstWhere((a) => a.id == 'remote-asset-1').name,
        'Imported plot');
  });

  test('ignores an event emitted by this device to prevent echo loops',
      () async {
    final store = PortfolioStore();
    await store.load();
    await store.setOwner('Self owner');
    await store.enablePassphrase('passphrase-of-length-12');
    final reducer = SyncReducer(store);

    final record = RemoteSyncEventRecord(
      id: 'echo-1',
      deviceId: store.deviceId,
      payloadType: 'asset',
      payload: Uint8List(0),
      prevHash: null,
      hash: Uint8List(0),
      integrity: null,
      receivedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    final applied = await reducer.apply(record);
    expect(applied, isTrue);
    expect(store.state.assets, isEmpty);
  });

  test('skips an event whose ciphertext cannot be decrypted under the key',
      () async {
    final store = PortfolioStore();
    await store.load();
    await store.setOwner('Bad key owner');
    await store.enablePassphrase('passphrase-of-length-12');
    final reducer = SyncReducer(store);

    final record = RemoteSyncEventRecord(
      id: 'opaque-1',
      deviceId: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
      payloadType: 'asset',
      payload: Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
      prevHash: null,
      hash: Uint8List(0),
      integrity: null,
      receivedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    final applied = await reducer.apply(record);
    expect(applied, isFalse);
    expect(store.state.assets, isEmpty);
  });
}

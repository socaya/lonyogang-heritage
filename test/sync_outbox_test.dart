import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/crypto.dart';
import 'package:lonyogang_heritage/data/sync_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('records encrypted entries that round-trip under the derived content key',
      () async {
    final vaultKey = await VaultCrypto.deriveKey('passphrase-of-length-12', List<int>.filled(16, 1));
    final outbox = SyncOutbox();
    await outbox.load();
    await outbox.record(
      payloadType: 'asset',
      payload: {'id': 'a1', 'name': 'Plot'},
      integrity: {'ownership_bps': 8000},
      vaultKey: vaultKey,
      deviceId: '00000000-0000-0000-0000-000000000099',
    );
    final snapshot = await outbox.snapshot();
    expect(snapshot, hasLength(1));
    final entry = snapshot.single;
    expect(entry.payloadType, 'asset');
    expect(entry.integrity, {'ownership_bps': 8000});

    final contentKey = await SyncOutbox.deriveContentKey(vaultKey);
    final plaintextBytes = await VaultCrypto.decryptBytes(entry.payload, contentKey);
    final decoded = jsonDecode(utf8.decode(plaintextBytes)) as Map<String, dynamic>;
    expect(decoded['name'], 'Plot');
  });

  test('persists across reloads and markAccepted drops ids', () async {
    final vaultKey = await VaultCrypto.deriveKey('passphrase-of-length-12', List<int>.filled(16, 2));
    final outbox = SyncOutbox();
    await outbox.record(
      payloadType: 'ledger_event',
      payload: {'id': 'e1'},
      integrity: {'amount_ugx': 1000},
      vaultKey: vaultKey,
      deviceId: '00000000-0000-0000-0000-000000000098',
    );
    expect(outbox.length, 1);

    final reloaded = SyncOutbox();
    await reloaded.load();
    expect(reloaded.length, 1);
    await reloaded.markAccepted(['nope']);
    expect(reloaded.length, 1);
    final id = (await reloaded.snapshot()).single.id;
    await reloaded.markAccepted([id]);
    expect(reloaded.length, 0);
  });

  test('deriveContentKey yields a stable 32-byte key per vault key', () async {
    final vaultKey = await VaultCrypto.deriveKey('passphrase-of-length-12', List<int>.filled(16, 3));
    final a = await SyncOutbox.deriveContentKey(vaultKey);
    final b = await SyncOutbox.deriveContentKey(vaultKey);
    final aBytes = await a.extractBytes();
    final bBytes = await b.extractBytes();
    expect(aBytes, bBytes);
    expect(aBytes.length, 32);
  });
}

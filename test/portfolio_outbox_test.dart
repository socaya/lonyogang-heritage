import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/crypto.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/data/sync_outbox.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('PortfolioStore records encrypted events into the outbox on write',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');

    final before = (await outbox.snapshot()).length;
    await store.upsertAsset(WealthAsset(
      id: 'asset-1',
      name: 'Plot A',
      kind: AssetKind.property,
      valueUgx: 75000000,
      valuedAt: DateTime(2026, 11, 1),
    ));
    final after = await outbox.snapshot();
    expect(after.length, before + 1);
    final entry = after.last;
    expect(entry.payloadType, 'asset');
    expect(entry.integrity?['ownership_bps'], 10000);

    // The ciphertext decrypts to the same asset JSON we handed in.
    final contentKey = await SyncOutbox.deriveContentKey(store.vault.activeKey!);
    final plain = await VaultCrypto.decryptBytes(entry.payload, contentKey);
    final decoded = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    expect(decoded['name'], 'Plot A');
    expect(decoded['valueUgx'], 75000000);
  });

  test('ledger_event integrity hint carries the UGX amount', () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.postEvent(LedgerEvent(
      id: 'tx-1',
      description: 'Dividend',
      kind: EventKind.dividend,
      amountUgx: 12345,
      occurredAt: DateTime(2026, 11, 1),
    ));
    final entry =
        (await outbox.snapshot()).firstWhere((e) => e.payloadType == 'ledger_event');
    expect(entry.integrity?['amount_ugx'], 12345);
  });

  test('beneficiary_batch integrity hint carries the combined basis points',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.upsertBeneficiary(const BeneficiaryRecord(
      id: 'b1',
      name: 'Partner',
      relationship: 'Spouse',
      intendedShareBps: 6000,
    ));
    final entry = (await outbox.snapshot())
        .firstWhere((e) => e.payloadType == 'beneficiary_batch');
    expect(entry.integrity?['combined_bps'], 6000);
  });
}

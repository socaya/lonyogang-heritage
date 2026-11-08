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

  test('deleting a beneficiary ships the surviving batch with new combined_bps',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.upsertBeneficiary(const BeneficiaryRecord(
      id: 'a', name: 'A', relationship: 'Spouse', intendedShareBps: 4000,
    ));
    await store.upsertBeneficiary(const BeneficiaryRecord(
      id: 'b', name: 'B', relationship: 'Child', intendedShareBps: 3000,
    ));
    await store.deleteBeneficiary('a');
    // The last beneficiary_batch should reflect the surviving set.
    final batches = (await outbox.snapshot())
        .where((e) => e.payloadType == 'beneficiary_batch')
        .toList();
    expect(batches.last.integrity?['combined_bps'], 3000);
  });

  test('FX rate upsert + remove emit fx_rate and fx_rate_delete events',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.upsertFxRate(FxRate(
      currency: 'USD',
      ugxPerUnit: 3850,
      asOf: DateTime.utc(2026, 11, 7),
      source: 'manual',
    ));
    final afterUpsert = (await outbox.snapshot())
        .where((e) => e.payloadType == 'fx_rate')
        .toList();
    expect(afterUpsert, hasLength(1));
    expect(afterUpsert.first.integrity?['ugx_per_unit'], 3850);

    await store.removeFxRate('USD', DateTime.utc(2026, 11, 7));
    final afterRemove = (await outbox.snapshot())
        .where((e) => e.payloadType == 'fx_rate_delete')
        .toList();
    expect(afterRemove, hasLength(1));
  });

  test('setTargetWeight emits a target_weights event with the full map',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.setTargetWeight('asset-1', 6000);
    await store.setTargetWeight('asset-2', 4000);
    final events = (await outbox.snapshot())
        .where((e) => e.payloadType == 'target_weights')
        .toList();
    // Two upserts → two events; the latter carries combined 10000.
    expect(events, hasLength(2));
    expect(events.last.integrity?['combined_bps'], 10000);
  });

  test('schedule upsert + pause + delete each emit their own event', () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    final schedule = ScheduledContribution(
      id: 's1',
      name: 'SACCO',
      amountUgx: 100000,
      frequency: ContributionFrequency.monthly,
      nextFire: DateTime(2026, 11, 20),
    );
    await store.upsertSchedule(schedule);
    await store.pauseSchedule('s1', active: false);
    await store.deleteSchedule('s1');
    final types = (await outbox.snapshot()).map((e) => e.payloadType).toList();
    expect(types.where((t) => t == 'schedule').length, 2);
    expect(types.contains('schedule_delete'), isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/crypto.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/data/vault.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AES-GCM round trip preserves the payload', () async {
    final salt = VaultCrypto.newSalt();
    final key = await VaultCrypto.deriveKey('correct horse battery', salt);
    final envelope = await VaultCrypto.encryptString('hello UGX', key);
    expect(envelope['c'], isNotNull);
    expect(envelope['n'], isNotNull);
    expect(envelope['m'], isNotNull);
    final out = await VaultCrypto.decryptString(envelope, key);
    expect(out, 'hello UGX');
  });

  test('Wrong passphrase cannot unlock an encrypted vault', () async {
    final vault = Vault();
    await vault.load();
    await vault.enablePassphrase('passphrase-one',
        currentCleartext: '{"schemaVersion":1,"ownerName":"A","onboardingDone":true}');
    vault.lock();
    final second = Vault();
    await second.load();
    await expectLater(
        second.unlock('wrong-passphrase'), throwsArgumentError);
  });

  test('PortfolioStore survives an encrypt/lock/unlock cycle', () async {
    final store = PortfolioStore();
    await store.load();
    await store.setOwner('Encrypted owner');
    await store.upsertAsset(WealthAsset(
        id: 'a',
        name: 'Bank',
        kind: AssetKind.savings,
        valueUgx: 200000,
        valuedAt: DateTime(2026, 1, 1)));
    await store.enablePassphrase('strong-passphrase');
    store.vault.lock();
    expect(store.isUnlocked, isFalse);

    final fresh = PortfolioStore();
    await fresh.load();
    expect(fresh.vault.hasPassphrase, isTrue);
    expect(fresh.isUnlocked, isFalse);
    await fresh.unlock('strong-passphrase');
    expect(fresh.state.ownerName, 'Encrypted owner');
    expect(fresh.state.assets.single.name, 'Bank');
  });

  test('Disabling the passphrase writes cleartext back for compatibility',
      () async {
    final store = PortfolioStore();
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('hello-world');
    await store.disablePassphrase();
    expect(store.vault.hasPassphrase, isFalse);
    final fresh = PortfolioStore();
    await fresh.load();
    expect(fresh.state.ownerName, 'Owner');
  });
}

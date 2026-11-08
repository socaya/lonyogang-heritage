import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/data/sync_outbox.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upsertContact adds a new row and then edits it in place', () async {
    final store = PortfolioStore();
    await store.load();
    const a = LegacyContact(
      id: 'c1',
      name: 'Partner',
      relationship: 'Spouse',
      email: 'spouse@example.com',
    );
    await store.upsertContact(a);
    expect(store.state.contacts, hasLength(1));
    expect(store.state.contacts.single.email, 'spouse@example.com');
    const edited = LegacyContact(
      id: 'c1',
      name: 'Partner',
      relationship: 'Spouse',
      email: 'new@example.com',
      phone: '+256700123456',
    );
    await store.upsertContact(edited);
    expect(store.state.contacts, hasLength(1));
    expect(store.state.contacts.single.email, 'new@example.com');
    expect(store.state.contacts.single.phone, '+256700123456');
  });

  test('LegacyContact round-trips through JSON including new fields',
      () async {
    const c = LegacyContact(
      id: 'c2',
      name: 'Lawyer',
      relationship: 'Family lawyer',
      email: 'legal@example.com',
      phone: '+256777000000',
      instructions: 'Keep sealed envelope at firm office.',
    );
    final restored = LegacyContact.fromJson(c.toJson());
    expect(restored.email, 'legal@example.com');
    expect(restored.phone, '+256777000000');
    expect(restored.instructions, 'Keep sealed envelope at firm office.');
  });

  test('contact/goal/reminder mutations record outbox events', () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');

    await store.upsertContact(const LegacyContact(
        id: 'c', name: 'C', relationship: 'Rel', email: 'c@example.com'));
    await store.upsertGoal(const WealthGoal(
        id: 'g', name: 'Goal', targetUgx: 1000000, savedUgx: 0));
    await store.addReminder(ReminderRecord(
        id: 'r', title: 'Pay insurance', dueAt: DateTime(2027, 1, 1)));

    final types =
        (await outbox.snapshot()).map((e) => e.payloadType).toSet();
    expect(types, containsAll(['trusted_contact', 'goal', 'reminder']));

    await store.removeContact('c');
    await store.deleteGoal('g');
    await store.removeReminder('r');

    final deleteTypes =
        (await outbox.snapshot()).map((e) => e.payloadType).toSet();
    expect(deleteTypes,
        containsAll(['trusted_contact_delete', 'goal_delete', 'reminder_delete']));
  });
}

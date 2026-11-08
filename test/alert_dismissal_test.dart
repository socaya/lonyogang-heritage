import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/data/sync_outbox.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:lonyogang_heritage/presentation/legacy_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('dismissing a reminder alert suppresses it from buildLocalAlerts',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');

    final due = DateTime.now().add(const Duration(days: 3));
    await store.addReminder(ReminderRecord(
      id: 'r1',
      title: 'Pay insurance',
      dueAt: due,
    ));

    final before = buildLocalAlerts(store.state, DateTime.now());
    expect(before.any((a) => a.sourceId == 'r1'), isTrue);

    await store.dismissAlert(
      localAlertKey(LocalAlertSource.reminder, 'r1', due),
    );

    final after = buildLocalAlerts(store.state, DateTime.now());
    expect(after.any((a) => a.sourceId == 'r1'), isFalse);
  });

  test('dismissal is emitted as a sync event so it propagates across devices',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.dismissAlert('reminder:r1:2026-11-10T00:00:00.000');

    final entries = await outbox.snapshot();
    final dismissals =
        entries.where((e) => e.payloadType == 'alert_dismissal').toList();
    expect(dismissals, hasLength(1));
  });

  test('clearDismissedAlerts emits its own event and empties the set',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(outbox: outbox);
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.dismissAlert('x');
    await store.clearDismissedAlerts();
    expect(store.state.dismissedAlertKeys, isEmpty);
    final clears = (await outbox.snapshot())
        .where((e) => e.payloadType == 'alert_dismissal_clear')
        .toList();
    expect(clears, hasLength(1));
  });
}

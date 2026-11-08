import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/data/notifications.dart';
import 'package:lonyogang_heritage/domain/models.dart';

void main() {
  final now = DateTime(2026, 11, 6, 9);

  test('Reminders in range with upcomingReminders enabled produce alerts', () {
    final state = PortfolioState(
      reminders: [
        ReminderRecord(
            id: 'r1',
            title: 'Pay insurance',
            dueAt: now.add(const Duration(days: 5))),
        ReminderRecord(
            id: 'r2',
            title: 'Old',
            dueAt: now.subtract(const Duration(days: 1))),
      ],
    );
    final alerts = computeScheduledAlerts(state, now);
    expect(alerts.where((a) => a.kind == AlertKind.reminder).length, 1);
    expect(alerts.first.body, 'Pay insurance');
  });

  test('Expiring documents fire at a configurable lead time', () {
    final state = PortfolioState(documents: [
      DocumentRecord(
          id: 'd',
          title: 'Insurance',
          category: 'Insurance',
          expiresAt: now.add(const Duration(days: 30))),
    ]);
    final alerts = computeScheduledAlerts(state, now,
        documentLead: const Duration(days: 14));
    final alert = alerts.firstWhere(
        (a) => a.kind == AlertKind.documentExpiry);
    expect(
        alert.fireAt, now.add(const Duration(days: 30)).subtract(
            const Duration(days: 14)));
  });

  test('Scheduled contributions enqueue only their next fire inside a window',
      () {
    final state = PortfolioState(scheduled: [
      ScheduledContribution(
          id: 's1',
          name: 'SACCO',
          amountUgx: 100000,
          frequency: ContributionFrequency.monthly,
          nextFire: now.add(const Duration(days: 20))),
      ScheduledContribution(
          id: 's2',
          name: 'Deep future',
          amountUgx: 100000,
          frequency: ContributionFrequency.monthly,
          nextFire: now.add(const Duration(days: 365))),
    ]);
    final alerts = computeScheduledAlerts(state, now);
    final scheduled = alerts.where((a) => a.kind == AlertKind.scheduledContribution);
    expect(scheduled.length, 1);
  });

  test('Stale-valuation fires at the 1-year mark for a fresh asset', () {
    final state = PortfolioState(
      notificationOptions: const NotificationOptions(staleValuations: true),
      assets: [
        WealthAsset(
            id: 'a1',
            name: 'Village plot',
            kind: AssetKind.property,
            valueUgx: 1,
            ownershipBps: 10000,
            valuedAt: now.subtract(const Duration(days: 30))),
      ],
    );
    final alerts = computeScheduledAlerts(state, now);
    final stale = alerts.firstWhere((a) => a.kind == AlertKind.staleValuation);
    expect(stale.fireAt,
        now.subtract(const Duration(days: 30)).add(const Duration(days: 365)));
  });

  test('Already-stale valuation fires right now, not silently dropped', () {
    final state = PortfolioState(
      notificationOptions: const NotificationOptions(staleValuations: true),
      assets: [
        WealthAsset(
            id: 'ageing',
            name: 'Forgotten shares',
            kind: AssetKind.investment,
            valueUgx: 1,
            ownershipBps: 10000,
            valuedAt: now.subtract(const Duration(days: 500))),
      ],
    );
    final alerts = computeScheduledAlerts(state, now);
    final stale = alerts.firstWhere((a) => a.kind == AlertKind.staleValuation);
    expect(stale.fireAt, now);
    expect(stale.title, 'Valuation overdue');
  });

  test('NoopNotificationScheduler tracks what the UI synced', () async {
    final scheduler = NoopNotificationScheduler();
    await scheduler.syncWith([
      ScheduledAlert(
          id: 'a',
          title: 't',
          body: 'b',
          fireAt: DateTime(2027, 1, 1),
          kind: AlertKind.reminder),
    ]);
    expect((await scheduler.listPending()).length, 1);
  });
}

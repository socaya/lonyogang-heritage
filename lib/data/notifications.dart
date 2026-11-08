import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/finance.dart';
import '../domain/models.dart';

/// A dated alert the app wants to surface — either in-app through the
/// notifications center (today) or via a native scheduled notification (when
/// the platform permits it). The pure-Dart function [computeScheduledAlerts]
/// builds these from the active portfolio so that scheduling and UI listing
/// share one source of truth.
enum AlertKind { reminder, documentExpiry, scheduledContribution, staleValuation }

class ScheduledAlert {
  final String id;
  final String title;
  final String body;
  final DateTime fireAt;
  final AlertKind kind;
  const ScheduledAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.kind,
  });

  /// A stable 31-bit integer id derived from the string id so the OS can
  /// de-duplicate reschedules without us having to persist the mapping.
  int get nativeId {
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = ((hash << 5) - hash + code) & 0x7fffffff;
    }
    return hash;
  }
}

List<ScheduledAlert> computeScheduledAlerts(
    PortfolioState state, DateTime now,
    {Duration reminderLead = const Duration(days: 1),
    Duration documentLead = const Duration(days: 14),
    Duration staleAfter = const Duration(days: 365)}) {
  final out = <ScheduledAlert>[];
  final opts = state.notificationOptions;

  if (opts.upcomingReminders) {
    for (final r in state.reminders.where((x) => !x.completed)) {
      final fire = r.dueAt.subtract(reminderLead);
      if (fire.isAfter(now)) {
        out.add(ScheduledAlert(
          id: 'reminder-${r.id}',
          title: 'Reminder due soon',
          body: r.title,
          fireAt: fire,
          kind: AlertKind.reminder,
        ));
      }
    }
  }

  if (opts.expiringDocuments) {
    for (final d in state.documents.where((x) => !x.archived && x.expiresAt != null)) {
      final fire = d.expiresAt!.subtract(documentLead);
      if (fire.isAfter(now)) {
        out.add(ScheduledAlert(
          id: 'document-${d.id}',
          title: 'Document renewal approaching',
          body: '${d.title} expires on ${_formatDay(d.expiresAt!)}',
          fireAt: fire,
          kind: AlertKind.documentExpiry,
        ));
      }
    }
  }

  for (final s in dueSchedules(state.scheduled, now.add(const Duration(days: 30)))) {
    if (s.nextFire.isAfter(now)) {
      out.add(ScheduledAlert(
        id: 'schedule-${s.id}',
        title: 'Scheduled contribution due',
        body: '${s.name} · UGX ${_formatAmount(s.amountUgx)}',
        fireAt: s.nextFire,
        kind: AlertKind.scheduledContribution,
      ));
    }
  }

  if (opts.staleValuations) {
    // Two complementary cases:
    //   - still fresh → schedule a reminder for the moment it crosses the
    //     staleAfter window;
    //   - already stale → fire a "please re-value" alert right now so the
    //     user is not left ignorant about a year-old number.
    for (final a in state.assets.where((x) => !x.archived)) {
      final aging = now.difference(a.valuedAt);
      final fireAt = aging > staleAfter ? now : a.valuedAt.add(staleAfter);
      out.add(ScheduledAlert(
        id: 'stale-${a.id}',
        title: aging > staleAfter
            ? 'Valuation overdue'
            : 'Valuation getting stale',
        body: aging > staleAfter
            ? '${a.name} has not been revalued in over a year'
            : '${a.name} has not been revalued in a year',
        fireAt: fireAt,
        kind: AlertKind.staleValuation,
      ));
    }
  }

  return out..sort((a, b) => a.fireAt.compareTo(b.fireAt));
}

String _formatDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _formatAmount(int ugx) {
  final buf = ugx.toString();
  final parts = <String>[];
  for (var i = buf.length; i > 0; i -= 3) {
    parts.add(buf.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return parts.reversed.join(',');
}

/// Thin wrapper around `flutter_local_notifications`. All UI code depends on
/// this abstract contract so widget tests and the SR environment can use a
/// no-op implementation without pulling in platform channels.
abstract class NotificationScheduler {
  Future<void> initialize();
  Future<void> syncWith(List<ScheduledAlert> alerts);
  Future<List<int>> listPending();
  Future<void> cancelAll();
}

class NoopNotificationScheduler implements NotificationScheduler {
  final Set<int> _ids = <int>{};
  @override Future<void> initialize() async {}
  @override Future<void> cancelAll() async => _ids.clear();
  @override Future<List<int>> listPending() async => _ids.toList();
  @override Future<void> syncWith(List<ScheduledAlert> alerts) async {
    _ids
      ..clear()
      ..addAll(alerts.map((a) => a.nativeId));
  }
}

class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: false);
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin));
    _initialized = true;
  }

  @override Future<void> cancelAll() async => _plugin.cancelAll();

  @override Future<List<int>> listPending() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((p) => p.id).toList();
  }

  @override Future<void> syncWith(List<ScheduledAlert> alerts) async {
    if (!_initialized) await initialize();
    await _plugin.cancelAll();
    const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'lonyogang_reminders',
          'LonyoGang reminders',
          channelDescription: 'Portfolio reminders, document renewals and schedules',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails());
    for (final alert in alerts) {
      try {
        await _plugin.zonedSchedule(
          alert.nativeId,
          alert.title,
          alert.body,
          tz.TZDateTime.from(alert.fireAt, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('Could not schedule ${alert.id}: $e');
      }
    }
  }
}

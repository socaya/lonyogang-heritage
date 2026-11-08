import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../data/remote_sync.dart';
import 'components.dart';
import 'widgets.dart';

/// Lists the account's active and historical sessions and lets the user
/// revoke anything that isn't the session this device is currently signed
/// into. A revoked row doesn't disappear — the server keeps it as evidence
/// for the audit trail — but it flips to a muted "Revoked" state.
class SessionsScreen extends StatefulWidget {
  final RemoteSyncService sync;
  const SessionsScreen({super.key, required this.sync});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _loading = true;
  String? _error;
  List<RemoteSyncSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.sync.listSessions();
      rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() => _sessions = rows);
    } catch (err) {
      setState(() => _error = '$err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(RemoteSyncSession session) async {
    final confirmed = await confirmActionSheet(
      context,
      title: 'Revoke this session?',
      consequence:
          'The device currently using this session will be signed out. Nothing on that device is deleted — the next sign-in there issues a fresh session.',
      confirmLabel: 'Revoke',
    );
    if (!confirmed) return;
    try {
      await widget.sync.revokeSession(session.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session revoked.')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoke failed: $err')));
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          Text('Active sessions',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'Every device that has signed into this account. Revoke any you do not recognise — the device holding that session will be signed out on its next request.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const LoadingState(message: 'Fetching sessions')
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else if (_sessions.isEmpty)
            const AppEmptyState(
              title: 'No sessions on file',
              detail:
                  'This account has not signed in anywhere yet. Sign in from this device to open your first session.',
              icon: Icons.devices_other,
            )
          else
            ..._sessions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    child: Row(children: [
                      Icon(
                        s.isActive ? Icons.check_circle : Icons.history_toggle_off,
                        color: s.isActive ? LG.sage : LG.muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.userAgent ?? 'Unknown client',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              'Opened ${LG.date(s.createdAt)}'
                              '${s.revokedAt != null ? ' · Revoked ${LG.date(s.revokedAt!)}' : ''}'
                              '${s.refreshedAt != null && s.revokedAt == null ? ' · Refreshed ${LG.date(s.refreshedAt!)}' : ''}',
                              style: const TextStyle(
                                  color: LG.muted, fontSize: 12),
                            ),
                            Text('Device ${_shorten(s.deviceId)}',
                                style: const TextStyle(
                                    color: LG.muted, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (s.isActive)
                        IconButton(
                          tooltip: 'Revoke session',
                          icon: const Icon(Icons.logout, color: LG.muted),
                          onPressed: () => _revoke(s),
                        ),
                    ]),
                  ),
                )),
          const SizedBox(height: 18),
          const Text(
            'Revocation keeps the historical row for audit. If you lose a device entirely, revoke the session and then rotate the password from Recover Access to invalidate the refresh token too.',
            style: TextStyle(color: LG.muted, fontSize: 12, height: 1.55),
          ),
        ],
      );

  static String _shorten(String id) =>
      id.length <= 10 ? id : '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
}

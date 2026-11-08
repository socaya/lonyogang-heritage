import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../data/remote_sync.dart';
import 'components.dart';
import 'widgets.dart';

/// Shows the Merkle verification result for this account's audit chain
/// and the N most recent entries. The server computes both; we render
/// them so the user can confirm that every action taken on their behalf
/// is accounted for and still verifies.
class TransparencyScreen extends StatefulWidget {
  final RemoteSyncService sync;
  const TransparencyScreen({super.key, required this.sync});
  @override
  State<TransparencyScreen> createState() => _TransparencyScreenState();
}

class _TransparencyScreenState extends State<TransparencyScreen> {
  bool _loading = true;
  bool _anchoring = false;
  String? _error;
  RemoteAuditChain? _chain;
  List<RemoteAuditEntry> _entries = const [];
  List<RemoteAuditAnchor> _anchors = const [];

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
      final chain = await widget.sync.verifyAuditChain();
      final entries = await widget.sync.listAuditEntries(limit: 100);
      final anchors = await widget.sync.listAuditAnchors();
      anchors.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _chain = chain;
        _entries = entries;
        _anchors = anchors;
      });
    } catch (err) {
      setState(() => _error = '$err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAnchor() async {
    setState(() => _anchoring = true);
    try {
      final anchor = await widget.sync.runAuditAnchor();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(anchor == null
              ? 'No new entries to anchor.'
              : 'Anchor recorded over ${anchor.entryCount} entries.')));
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Anchor run failed: $err')));
    } finally {
      if (mounted) setState(() => _anchoring = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          Text('Audit transparency',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'Every action we take on your behalf writes a Merkle-chained audit entry. If the chain still verifies, the server has not silently rewritten its history.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const LoadingState(message: 'Verifying chain')
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else ...[
            SoftCard(
              color: (_chain?.verified ?? false) ? LG.sageSoft : const Color(0xFFF8EAE7),
              child: Row(children: [
                Icon(
                  (_chain?.verified ?? false)
                      ? Icons.verified_rounded
                      : Icons.gpp_bad_outlined,
                  color: (_chain?.verified ?? false) ? LG.sage : LG.negative,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_chain?.verified ?? false)
                            ? 'Chain verifies end-to-end'
                            : 'Chain verification failed',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_chain?.count ?? 0} entries on file'
                        '${_chain?.tipHashBase64 == null ? '' : ' · tip ${_shortHash(_chain!.tipHashBase64!)}'}'
                        '${_chain?.brokenAt == null ? '' : ' · broken at ${_chain!.brokenAt}'}',
                        style:
                            const TextStyle(color: LG.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            Row(children: [
              const Expanded(child: SectionTitle('Transparency anchors')),
              TextButton.icon(
                onPressed: _anchoring ? null : _runAnchor,
                icon: const Icon(Icons.push_pin_outlined, size: 18),
                label: Text(_anchoring ? 'Anchoring…' : 'Anchor now'),
              ),
            ]),
            if (_anchors.isEmpty)
              const SoftCard(
                child: Text(
                    'No anchors yet. Press "Anchor now" to freeze the current chain tip or wait for the scheduled job.',
                    style: TextStyle(color: LG.muted, fontSize: 12)),
              )
            else
              ..._anchors.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(
                                  a.verified
                                      ? Icons.push_pin
                                      : Icons.priority_high,
                                  color: a.verified ? LG.sage : LG.negative,
                                  size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${a.entryCount} entries · tip ${_shortHash(a.tipHashBase64)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              'Anchored ${LG.date(a.createdAt)}'
                              '${a.source == null ? '' : ' · source ${a.source}'}'
                              '${a.proofBase64 == null ? '' : ' · proof attached'}'
                              '${a.brokenAt == null ? '' : ' · broken at ${a.brokenAt}'}',
                              style: const TextStyle(
                                  color: LG.muted, fontSize: 11),
                            ),
                          ]),
                    ),
                  )),
            const SizedBox(height: 22),
            const SectionTitle('Recent activity'),
            if (_entries.isEmpty)
              const AppEmptyState(
                title: 'No audit entries',
                detail:
                    'No actions have been recorded yet. Anything that touches your account will appear here with its hash.',
                icon: Icons.inbox_outlined,
              )
            else
              ..._entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.action,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              '${LG.date(e.createdAt)}'
                              '${e.resource == null ? '' : ' · ${e.resource}'}',
                              style: const TextStyle(
                                  color: LG.muted, fontSize: 12),
                            ),
                            if (e.context != null) ...[
                              const SizedBox(height: 4),
                              Text('${e.context}',
                                  style: const TextStyle(
                                      color: LG.muted, fontSize: 11)),
                            ],
                            const SizedBox(height: 4),
                            Text(
                                'hash ${_shortHash(e.hashBase64)}'
                                '${e.prevHashBase64 == null ? ' · root' : ' · prev ${_shortHash(e.prevHashBase64!)}'}',
                                style: const TextStyle(
                                    color: LG.muted,
                                    fontSize: 11,
                                    fontFamily: 'monospace')),
                          ]),
                    ),
                  )),
          ],
          const SizedBox(height: 18),
          const Text(
            'Entries that touch personally identifying data are kept under Uganda DPPA 2019 s. 7(1). Deleting your account erases the account linkage but keeps the audit row.',
            style: TextStyle(color: LG.muted, fontSize: 12, height: 1.55),
          ),
        ],
      );

  static String _shortHash(String b64) =>
      b64.length <= 12 ? b64 : '${b64.substring(0, 6)}…${b64.substring(b64.length - 4)}';
}

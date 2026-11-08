import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../data/remote_sync.dart';
import 'components.dart';
import 'widgets.dart';

/// Lists the bank aggregation providers the backend has registered.
/// Stays honest about what is actually integrated: the backend currently
/// ships Mock, Stanbic and MTN MoMo adapters; which ones the deployment
/// has enabled depends on its environment variables.
class BankProvidersScreen extends StatefulWidget {
  final RemoteSyncService sync;
  const BankProvidersScreen({super.key, required this.sync});
  @override
  State<BankProvidersScreen> createState() => _BankProvidersScreenState();
}

class _BankProvidersScreenState extends State<BankProvidersScreen> {
  bool _loading = true;
  String? _error;
  List<String> _providers = const [];

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
      final rows = await widget.sync.listBankProviders();
      setState(() => _providers = rows);
    } catch (err) {
      setState(() => _error = '$err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          Text('Bank aggregation',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'What the backend can link against today. Linking requires the backend to hold valid OAuth credentials for the provider — if a provider is listed but your deployment has not been issued those credentials, the link flow will reject it.',
            style: TextStyle(color: LG.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const LoadingState(message: 'Fetching providers')
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else if (_providers.isEmpty)
            const AppEmptyState(
              title: 'No providers configured',
              detail:
                  'This deployment has no bank aggregation adapters registered. Only manual imports are available.',
              icon: Icons.account_balance_outlined,
            )
          else
            ..._providers.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    child: Row(children: [
                      const Icon(Icons.account_balance, color: LG.sage),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_pretty(p),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            const Text(
                                'Links go through the server; raw credentials never touch this device.',
                                style: TextStyle(
                                    color: LG.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                )),
          const SizedBox(height: 18),
          const Text(
            'The actual linking flow is not wired into this screen yet — it needs a per-provider OAuth consent step that varies by partner and deployment. This surface stays honest about what the server advertises until that path lands.',
            style: TextStyle(color: LG.muted, fontSize: 12, height: 1.55),
          ),
        ],
      );

  static String _pretty(String code) {
    switch (code) {
      case 'mock':
        return 'Mock (test fixtures)';
      case 'stanbic':
        return 'Stanbic Bank Uganda Partner API';
      case 'mtn_momo':
        return 'MTN Mobile Money Collections';
      default:
        return code;
    }
  }
}

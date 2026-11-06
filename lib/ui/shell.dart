import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../state/wealth_store.dart';
import '../domain/models.dart';

import 'home.dart';
import 'portfolio.dart';
import 'editors.dart';
import 'reports.dart';
import 'organize.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});
  final WealthStore store;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  void open(Widget page) => Navigator.push(context,
    MaterialPageRoute<void>(builder: (_) => page));

  void showAddMenu() {
    showModalBottomSheet<void>(context: context,
      backgroundColor: LG.canvas, showDragHandle: true, isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(alignment: Alignment.centerLeft,
            child: Text('Record your wealth', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 22, color: LG.navy))),
          const SizedBox(height: 17),
          _action(sheetContext, Icons.add_home_outlined, 'Add a property',
            AssetEditor(store: widget.store, initialKind: AssetKind.property)),
          _action(sheetContext, Icons.trending_up_rounded, 'Add an investment',
            AssetEditor(store: widget.store, initialKind: AssetKind.investment)),
          _action(sheetContext, Icons.savings_outlined, 'Add savings or an account',
            AssetEditor(store: widget.store, initialKind: AssetKind.saving)),
          _action(sheetContext, Icons.inventory_2_outlined, 'Add another asset',
            AssetEditor(store: widget.store, initialKind: AssetKind.other)),
          _action(sheetContext, Icons.credit_card_outlined, 'Record a liability',
            DebtEditor(store: widget.store)),
          _action(sheetContext, Icons.receipt_long_outlined, 'Record a transaction',
            EntryEditor(store: widget.store)),
        ]))));
  }

  Widget _action(BuildContext sheetContext, IconData icon, String label, Widget page) =>
    ListTile(leading: Icon(icon, color: LG.sageDark), title: Text(label,
      style: const TextStyle(color: LG.navy, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, color: LG.muted),
      onTap: () { Navigator.pop(sheetContext); open(page); });

  @override
  Widget build(BuildContext context) {
    final views = [
      HomeScreen(store: widget.store, onPortfolio: () => setState(() => index = 1),
        onReports: () => setState(() => index = 3), onAdd: showAddMenu),
      PortfolioScreen(store: widget.store),
      const SizedBox.shrink(),
      ReportsScreen(store: widget.store),
      MoreScreen(store: widget.store),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: views),
      bottomNavigationBar: SafeArea(top: false, child: Container(
        decoration: const BoxDecoration(color: LG.white,
          border: Border(top: BorderSide(color: LG.line, width: 0.6))),
        child: NavigationBar(
          backgroundColor: LG.white, indicatorColor: LG.sageSoft,
          height: 72, labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: index, onDestinationSelected: (selected) {
            if (selected == 2) { showAddMenu(); return; }
            setState(() => index = selected);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Portfolio'),
            NavigationDestination(icon: Icon(Icons.add_circle_rounded, color: LG.gold, size: 34),
              label: 'Add'),
            NavigationDestination(icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded), label: 'Reports'),
            NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
          ],
        )),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/format.dart';
import '../domain/models.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scale = compact ? 0.82 : 1.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/brand/theme1-granary.png', height: 70 * scale,
        width: 58 * scale, fit: BoxFit.contain,
        semanticLabel: 'LonyoGang Acholi granary emblem'),
      SizedBox(width: 7 * scale),
      Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('LONYO', style: TextStyle(fontSize: 22 * scale,
                color: LG.navy, fontWeight: FontWeight.w900, letterSpacing: -1.0)),
              Text('GANG', style: TextStyle(fontSize: 22 * scale,
                color: LG.gold, fontWeight: FontWeight.w900, letterSpacing: -1.0)),
            ]),
          Container(width: 75 * scale, height: 2 * scale, color: LG.gold),
          Text('H E R I T A G E', style: TextStyle(fontSize: 8.5 * scale,
            color: LG.navy, fontWeight: FontWeight.w800, letterSpacing: 0.15)),
        ]),
    ]);
  }
}

class LgPage extends StatelessWidget {
  const LgPage({super.key, required this.title, this.subtitle, required this.children,
    this.trailing, this.bottom, this.showBack = false});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing, bottom;
  final bool showBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 26),
        children: [
          Row(children: [
            if (showBack) ...[
              IconButton(onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded)), const SizedBox(width: 6),
            ],
            if (!showBack) const BrandLockup(compact: true),
            const Spacer(),
            ?trailing,
          ]),
          const SizedBox(height: 27),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: const TextStyle(color: LG.muted, fontSize: 14.5, height: 1.42)),
          ],
          const SizedBox(height: 26),
          ...children,
        ])),
      if (bottom != null) Padding(
        padding: const EdgeInsets.fromLTRB(24, 5, 24, 16), child: bottom),
    ])),
  );
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.color = LG.white,
    this.padding = const EdgeInsets.all(18), this.onTap});
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: child,
    );
    return onTap == null ? box : InkWell(onTap: onTap,
      borderRadius: BorderRadius.circular(18), child: box);
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.label, {super.key, this.trailing});
  final String label;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(
        color: LG.navy, fontWeight: FontWeight.w800, fontSize: 17))),
      ?trailing,
    ]),
  );
}

class LgAction extends StatelessWidget {
  const LgAction(this.label, {super.key, required this.onPressed, this.icon = Icons.arrow_forward_rounded,
    this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 54,
    child: FilledButton(onPressed: busy ? null : onPressed,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (busy) ...[
          const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: LG.white)),
          const SizedBox(width: 12),
        ],
        Text(label),
        const SizedBox(width: 16),
        if (!busy) Icon(icon, color: LG.gold, size: 22),
      ])),
  );
}

class LgInput extends StatelessWidget {
  const LgInput({super.key, required this.label, this.hint, this.controller,
    this.keyboardType, this.validator, this.maxLines = 1, this.obscure = false,
    this.prefix, this.suffix, this.onChanged, this.enabled = true});
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool obscure, enabled;
  final Widget? prefix, suffix;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: LG.navy, fontSize: 13)),
    const SizedBox(height: 7),
    TextFormField(controller: controller, keyboardType: keyboardType,
      validator: validator, maxLines: maxLines, obscureText: obscure,
      onChanged: onChanged, enabled: enabled,
      decoration: InputDecoration(hintText: hint, prefixIcon: prefix, suffixIcon: suffix),
    ),
  ]);
}

class InfoStrip extends StatelessWidget {
  const InfoStrip({super.key, required this.title, required this.body,
    this.icon = Icons.verified_user_outlined});
  final String title, body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SoftCard(color: LG.sageSoft,
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Icon(icon, color: LG.sageDark, size: 28),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: LG.navy)),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(color: LG.muted, fontSize: 13, height: 1.45)),
      ])),
    ]));
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.title, required this.detail, this.icon = Icons.inbox_outlined});
  final String title, detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      Icon(icon, color: LG.sage, size: 42),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(color: LG.navy,
          fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 8),
      Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: LG.muted)),
    ]));
}

class MoneyLabel extends StatelessWidget {
  const MoneyLabel(this.value, {super.key, this.large = false, this.color = LG.navy});
  final int value;
  final bool large;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(Fmt.money(value),
    maxLines: 1, overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: large ? 28 : 16, fontWeight: FontWeight.w800,
      letterSpacing: -0.5, color: color));
}

IconData assetIcon(AssetKind kind) => switch (kind) {
  AssetKind.investment => Icons.account_balance_outlined,
  AssetKind.property => Icons.home_outlined,
  AssetKind.saving => Icons.savings_outlined,
  AssetKind.other => Icons.inventory_2_outlined,
};

String sourceLabel(ValuationSource source) => switch (source) {
  ValuationSource.ownerEstimate => 'Owner estimate',
  ValuationSource.statement => 'Statement / provider',
  ValuationSource.licensedValuation => 'Independent valuation',
  ValuationSource.other => 'Other source',
};

Future<bool> askConfirm(BuildContext context, String title, String detail,
    {String confirmLabel = 'Delete'}) async {
  final result = await showDialog<bool>(context: context, builder: (context) =>
    AlertDialog(title: Text(title), content: Text(detail), actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(context, true),
        child: Text(confirmLabel, style: const TextStyle(color: LG.danger))),
    ]));
  return result ?? false;
}

void showFailure(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceAll('Exception:', '').trim())));
}

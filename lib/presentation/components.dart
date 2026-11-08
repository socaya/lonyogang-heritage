import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design.dart';
import '../domain/models.dart';
import 'widgets.dart';

/// Shared component library honoring the approved flat Theme 1 reference.
/// Every screen should compose these rather than re-inventing the surface,
/// header or input chrome.

/// The default page scaffold: canvas background, safe area, horizontal
/// gutter, keyboard-aware scroll. Use [slivers] for list-based pages;
/// [children] for short flat pages. Set [withPadding] to false when the body
/// already handles its own left/right insets (e.g. a full-bleed CTA bar).
class AppPage extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;
  final List<Widget> children;
  final EdgeInsets padding;
  final bool withScroll;
  final Color background;
  const AppPage({
    super.key,
    this.appBar,
    this.bottomBar,
    this.children = const [],
    this.padding = const EdgeInsets.fromLTRB(LG.hPad, 20, LG.hPad, 32),
    this.withScroll = true,
    this.background = LG.canvas,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: background,
        appBar: appBar,
        bottomNavigationBar: bottomBar,
        body: SafeArea(
          child: withScroll
              ? SingleChildScrollView(
                  padding: padding,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children))
              : Padding(
                  padding: padding,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children),
                ),
        ),
      );
}

/// A back button + optional step pill + compact brand, matching the top
/// chrome of the approved Create Account page.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBack;
  final int? step;
  final int? totalSteps;
  final bool showBrand;
  const AppHeader({
    super.key,
    this.onBack,
    this.step,
    this.totalSteps,
    this.showBrand = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final showStep = step != null && totalSteps != null;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(LG.hPad, 10, LG.hPad, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: 'Back',
                onPressed:
                    onBack ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: LG.navy),
              ),
            ),
            if (showBrand)
              const Expanded(child: Center(child: BrandMark(height: 28))),
            if (showStep)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: LG.sageSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${step!.toString().padLeft(2, '0')} / ${totalSteps!.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      color: LG.sage,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5),
                ),
              )
            else
              const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

/// Two-segment progress line as seen on the canonical Create Account
/// reference. Gold indicates the active segment, pale grey the remainder.
class StepProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String? eyebrow;
  const StepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.eyebrow,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: const TextStyle(
                color: LG.sage,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              for (var i = 0; i < totalSteps; i++) ...[
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i < currentStep ? LG.gold : LG.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < totalSteps - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      );
}

/// The dominant navy call-to-action. Supports loading and a discreet gold
/// trailing arrow. Hard-coded 52dp height per the spec geometry.
class PrimaryCTA extends StatelessWidget {
  final String label;
  final Future<void> Function()? onPressed;
  final bool loading;
  final bool showArrow;
  const PrimaryCTA({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onPressed != null && !loading,
        label: label,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed:
                (onPressed == null || loading) ? null : () => onPressed!(),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      if (showArrow) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 18, color: LG.gold),
                      ],
                    ],
                  ),
          ),
        ),
      );
}

/// A pale-sage informational panel used for honest privacy/security notes.
/// Carries a shield icon by default; override for a different semantic.
class SecurityNotice extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  const SecurityNotice({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.shield_outlined,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LG.sageSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: LG.sage, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(message,
                      style: const TextStyle(
                          fontSize: 12, color: LG.muted, height: 1.45)),
                ])),
          ],
        ),
      );
}

/// Semantic pill: estimated, user-entered, stale, overdue, archived. Keeps
/// color/text coupled so colour-blind users get the same signal.
enum StatusTone { info, warn, danger, positive, neutral }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;
  const StatusChip({super.key, required this.label, this.tone = StatusTone.info});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.info => (LG.sageSoft, LG.sage),
      StatusTone.positive => (LG.sageSoft, LG.sage),
      StatusTone.warn => (const Color(0xFFFBF3DD), const Color(0xFF8C6A1D)),
      StatusTone.danger => (const Color(0xFFF8EAE7), LG.negative),
      StatusTone.neutral => (LG.line, LG.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.2)),
    );
  }
}

/// UGX numeric input. Validates non-negative integers and prevents overflow
/// of the Dart int. Shows the UGX prefix inside the input to match the
/// reference money-entry pattern.
class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<int?>? onChanged;
  final bool required;
  final int? max;
  const MoneyField({
    super.key,
    required this.controller,
    this.hint,
    this.validator,
    this.onChanged,
    this.required = true,
    this.max,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          prefixText: 'UGX  ',
          hintText: hint ?? '0',
          prefixStyle: const TextStyle(
              color: LG.muted, fontWeight: FontWeight.w700, fontSize: 14),
        ),
        validator: validator ??
            (v) {
              final trimmed = (v ?? '').trim();
              if (trimmed.isEmpty) {
                return required ? 'Enter a UGX amount' : null;
              }
              final n = int.tryParse(trimmed);
              if (n == null || n < 0) return 'Enter a positive whole-UGX amount';
              if (max != null && n > max!) return 'Enter at most ${max!}';
              return null;
            },
        onChanged: (v) => onChanged?.call(int.tryParse(v)),
      );
}

/// Date selector that renders as a tappable soft tile and uses Material 3's
/// date picker. Bounds are optional; omit to allow any date.
class DateField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final IconData icon;
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.icon = Icons.calendar_today_outlined,
  });

  @override
  Widget build(BuildContext context) => SoftCard(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: firstDate ?? DateTime(1990),
            lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365 * 10)),
          );
          if (picked != null) onChanged(picked);
        },
        child: Row(children: [
          Icon(icon, color: LG.sage, size: 18),
          const SizedBox(width: 12),
          Text(LG.date(value), style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.expand_more, color: LG.muted),
        ]),
      );
}

/// Phone input with a country-code dropdown (default +256 Uganda). The
/// composed international-format string is emitted via [onChanged]; the
/// raw subscriber number stays in the controller for cursor stability.
class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? initialCountryCode;
  const PhoneField({
    super.key,
    required this.controller,
    this.onChanged,
    this.initialCountryCode = '+256',
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  static const _codes = <(String, String)>[
    ('+256', 'UG'),
    ('+254', 'KE'),
    ('+255', 'TZ'),
    ('+250', 'RW'),
    ('+211', 'SS'),
    ('+44', 'UK'),
    ('+1', 'US'),
  ];
  late String code = widget.initialCountryCode ?? '+256';

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: LG.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: code,
              onChanged: (v) {
                if (v == null) return;
                setState(() => code = v);
                widget.onChanged?.call('$code ${widget.controller.text}');
              },
              items: [
                for (final c in _codes)
                  DropdownMenuItem(
                      value: c.$1, child: Text('${c.$1} ${c.$2}', style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: '700 123 456'),
            onChanged: (v) => widget.onChanged?.call('$code $v'),
          ),
        ),
      ]);
}

/// A bottom-sheet confirmation for destructive or irreversible actions. The
/// consequence is spelled out in [consequence]; a cancel path is always
/// offered. Returns true if the user confirmed.
Future<bool> confirmActionSheet(BuildContext context, {
  required String title,
  required String consequence,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.warning_amber_rounded,
  bool destructive = true,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: LG.canvas,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(LG.hPad, 4, LG.hPad, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: destructive ? LG.negative : LG.sage),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: Theme.of(ctx).textTheme.titleLarge)),
            ]),
            const SizedBox(height: 10),
            Text(consequence,
                style: const TextStyle(color: LG.muted, height: 1.5)),
            const SizedBox(height: 18),
            PrimaryCTA(
              label: confirmLabel,
              showArrow: false,
              onPressed: () async => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(cancelLabel,
                    style: const TextStyle(color: LG.muted))),
          ],
        ),
      ),
    ),
  );
  return result == true;
}

/// Unobtrusive loading placeholder used only when a real async operation
/// is in flight. Avoids the shimmer-on-static-data anti-pattern.
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2)),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: const TextStyle(color: LG.muted)),
            ],
          ],
        ),
      );
}

/// Human-readable failure card with an optional retry. Preserves the form
/// values on the page; this widget only reports and offers retry.
class ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;
  final String retryLabel;
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });
  @override
  Widget build(BuildContext context) => SoftCard(
        color: const Color(0xFFF8EAE7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.error_outline, color: LG.negative),
            SizedBox(width: 10),
            Text('Something went wrong',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: LG.muted, height: 1.5)),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => onRetry!(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(retryLabel),
            ),
          ],
        ]),
      );
}

/// Supersedes the earlier [EmptySection] with a slightly richer API that
/// matches the spec's "helpful explanation plus working relevant action"
/// pattern. [EmptySection] stays in widgets.dart for back-compat.
class AppEmptyState extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const AppEmptyState({
    super.key,
    required this.title,
    required this.detail,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => SoftCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(children: [
            Icon(icon, size: 34, color: LG.sage),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: LG.muted, height: 1.45)),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}

/// Convenience: a compact header-row for a list page. Centralized so every
/// list uses the same gutter alignment the reference requires.
class ListHeaderRow extends StatelessWidget {
  final String leading;
  final String? trailing;
  const ListHeaderRow({super.key, required this.leading, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(children: [
          Expanded(
              child: Text(leading,
                  style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null)
            Text(trailing!,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      );
}

/// Pure-Dart helpers shared by onboarding/forms. Marked top-level so unit
/// tests can import them without pumping widgets.
bool isLikelyEmail(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  final at = s.indexOf('@');
  if (at < 1) return false;
  final domain = s.substring(at + 1);
  return domain.contains('.') && domain.length >= 3;
}

bool isLikelyName(String raw) => raw.trim().length >= 2;

/// Minimal E.164-ish plausibility check for a UG mobile number. We never
/// claim to verify the number; this guards obvious typos only.
bool isLikelyPhone(String composed) {
  final digits = composed.replaceAll(RegExp(r'[^\d]'), '');
  return digits.length >= 9 && digits.length <= 15;
}

/// Short helper to format basis points as a 0–100% string.
String formatShare(int bps) => '${(bps / 100).toStringAsFixed(bps % 100 == 0 ? 0 : 1)}%';

/// Helper that converts a [RecordStatus] to a [StatusChip]. Keeps the
/// semantic mapping in one place so new statuses are consistent.
StatusChip recordStatusChip(RecordStatus status) {
  final (label, tone) = switch (status) {
    RecordStatus.verified => ('Verified', StatusTone.positive),
    RecordStatus.userEntered => ('User entered', StatusTone.info),
    RecordStatus.estimated => ('Estimated', StatusTone.neutral),
    RecordStatus.stale => ('Stale', StatusTone.warn),
  };
  return StatusChip(label: label, tone: tone);
}

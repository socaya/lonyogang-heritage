import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/models.dart';
import 'forms.dart' show kOtherSentinel, parseDecimalAmount, requireDecimalAmount;
import 'widgets.dart';

const List<String> _kExpenseCategories = [
  'Food & groceries',
  'Transport',
  'Housing & utilities',
  'Healthcare',
  'Education',
  'Entertainment',
  'Personal care',
  'Clothing',
  'Communications & airtime',
  'Travel',
  'Family support',
  'Charity',
  'Taxes & fees',
];

const List<String> _kPaymentMethods = [
  'Cash',
  'Mobile money',
  'Bank card',
  'Bank transfer',
  'Cheque',
  'Credit card',
];

/// Full expenses browser. Shows a "today" and "this month" summary pair,
/// a category filter, and the list of non-archived expenses.
class ExpensesScreen extends StatefulWidget {
  final PortfolioStore store;
  const ExpensesScreen({super.key, required this.store});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final monthStart = DateTime(now.year, now.month, 1);
          final all = [...widget.store.state.expenses.where((e) => !e.archived)]
            ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
          final filtered = _filter == null
              ? all
              : all.where((e) => e.category == _filter).toList();
          final todaysTotal = all
              .where((e) => !e.occurredAt.isBefore(today))
              .fold<int>(0, (acc, e) => acc + e.amountUgx);
          final monthsTotal = all
              .where((e) => !e.occurredAt.isBefore(monthStart))
              .fold<int>(0, (acc, e) => acc + e.amountUgx);
          final categories = all.map((e) => e.category).toSet().toList()
            ..sort();
          return Scaffold(
            appBar: AppBar(title: const Text('Daily expenses')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ExpenseForm(store: widget.store))),
              backgroundColor: LG.gold,
              foregroundColor: LG.white,
              icon: const Icon(Icons.add),
              label: const Text('New expense'),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 100),
                children: [
                  const PageHeading('Daily expenses',
                      subtitle:
                          'Record every purchase, attach the receipt, track the month.'),
                  Row(children: [
                    Expanded(
                        child: _SummaryTile(
                            label: 'Today',
                            value: LG.money(todaysTotal, compact: true),
                            icon: Icons.today_outlined,
                            tint: LG.goldSoft,
                            iconColor: LG.gold)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _SummaryTile(
                            label: 'This month',
                            value: LG.money(monthsTotal, compact: true),
                            icon: Icons.calendar_month_outlined,
                            tint: LG.sageSoft,
                            iconColor: LG.sage)),
                  ]),
                  const SizedBox(height: 22),
                  if (categories.isNotEmpty)
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          LGFilterChip(
                            label: 'All',
                            selected: _filter == null,
                            onTap: () => setState(() => _filter = null),
                          ),
                          const SizedBox(width: 8),
                          for (final c in categories) ...[
                            LGFilterChip(
                                label: c,
                                selected: _filter == c,
                                onTap: () => setState(() => _filter = c)),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    const EmptySection(
                      title: 'No expenses recorded yet',
                      detail:
                          'Tap "New expense" to log a purchase and optionally scan the receipt.',
                      icon: Icons.receipt_long_outlined,
                    )
                  else
                    ...filtered.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ExpenseTile(
                            store: widget.store, expense: e))),
                ],
              ),
            ),
          );
        },
      );
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });
  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: tint, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: iconColor)),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: LG.muted, fontSize: 12.5)),
          const SizedBox(height: 4),
          FittedBox(
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.3))),
        ]),
      );
}

class _ExpenseTile extends StatelessWidget {
  final PortfolioStore store;
  final ExpenseRecord expense;
  const _ExpenseTile({required this.store, required this.expense});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (expense.category.isNotEmpty) expense.category,
      if (expense.merchant.isNotEmpty) expense.merchant,
      LG.date(expense.occurredAt),
    ].join(' · ');
    return SoftCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ExpenseForm(store: store, existing: expense))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: LG.goldSoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long_outlined,
                color: LG.gold, size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(expense.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: LG.muted, fontSize: 12.5)),
          if (expense.paymentMethod.isNotEmpty) ...[
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: LG.sageSoft,
                  borderRadius: BorderRadius.circular(999)),
              child: Text(expense.paymentMethod,
                  style: const TextStyle(
                      color: LG.sage,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('- ${LG.money(expense.amountUgx, compact: true)}',
              style: const TextStyle(
                  color: LG.negative,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5)),
          if (expense.receipt != null) ...[
            const SizedBox(height: 4),
            const Icon(Icons.attachment_rounded, color: LG.sage, size: 15),
          ],
        ]),
      ]),
    );
  }
}

/// Add / edit form. Supports scanning a receipt via the camera, picking
/// an image from the gallery, or picking any file. The receipt is
/// stored encrypted via the shared AttachmentStore.
class ExpenseForm extends StatefulWidget {
  final PortfolioStore store;
  final ExpenseRecord? existing;
  const ExpenseForm({super.key, required this.store, this.existing});
  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final formKey = GlobalKey<FormState>();
  late final description = TextEditingController(
      text: widget.existing?.description ?? '');
  late final merchant =
      TextEditingController(text: widget.existing?.merchant ?? '');
  late final amount = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.amountUgx.toString());
  late final customCategory = TextEditingController(
      text: _isCustomCategory(widget.existing?.category)
          ? widget.existing!.category
          : '');
  late final notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late String category = _initialCategoryChoice();
  late String paymentMethod =
      widget.existing?.paymentMethod ?? 'Cash';
  late String? assetId = widget.existing?.assetId;
  late DateTime date = widget.existing?.occurredAt ?? DateTime.now();
  late AttachmentRef? receipt = widget.existing?.receipt;
  bool busy = false;
  bool _attaching = false;

  bool _isCustomCategory(String? v) {
    if (v == null || v.isEmpty) return false;
    return !_kExpenseCategories.contains(v);
  }

  String _initialCategoryChoice() {
    final v = widget.existing?.category ?? '';
    if (v.isEmpty) return '';
    return _kExpenseCategories.contains(v) ? v : kOtherSentinel;
  }

  @override
  void dispose() {
    description.dispose();
    merchant.dispose();
    amount.dispose();
    customCategory.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cashAssets = widget.store.state.assets
        .where((a) => !a.archived &&
            (a.kind == AssetKind.savings ||
                a.kind == AssetKind.investment))
        .toList();
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.existing == null ? 'New expense' : 'Edit expense')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              PageHeading(
                  widget.existing == null ? 'New expense' : 'Edit expense',
                  subtitle:
                      'Keep the receipt with the record so you can audit a month later.'),
              FormFieldBlock(
                title: 'What was it',
                required: true,
                child: TextFormField(
                  controller: description,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Weekly groceries at Shoprite'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
              ),
              FormFieldBlock(
                title: 'Category',
                required: true,
                child: DropdownButtonFormField<String>(
                  initialValue: category.isEmpty ? null : category,
                  isExpanded: true,
                  items: [
                    ..._kExpenseCategories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c))),
                    const DropdownMenuItem(
                        value: kOtherSentinel, child: Text('Other…')),
                  ],
                  onChanged: (v) => setState(() => category = v ?? ''),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Pick a category' : null,
                ),
              ),
              if (category == kOtherSentinel)
                FormFieldBlock(
                  title: 'Custom category',
                  child: TextFormField(
                    controller: customCategory,
                    decoration: const InputDecoration(
                        hintText: 'Name this spend category'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Describe the category'
                        : null,
                  ),
                ),
              FormFieldBlock(
                title: 'Amount (UGX)',
                required: true,
                help:
                    'Decimals are rounded to the nearest shilling on save.',
                child: TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: const InputDecoration(hintText: '0'),
                  validator: requireDecimalAmount,
                ),
              ),
              FormFieldBlock(
                title: 'Merchant / where',
                child: TextFormField(
                  controller: merchant,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Shoprite Lugogo'),
                ),
              ),
              FormFieldBlock(
                title: 'Payment method',
                required: true,
                child: DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  isExpanded: true,
                  items: _kPaymentMethods
                      .map(
                          (p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => paymentMethod = v ?? paymentMethod),
                ),
              ),
              if (cashAssets.isNotEmpty)
                FormFieldBlock(
                  title: 'Draw from (optional)',
                  help:
                      'When set, the linked account value drops by this amount on save.',
                  child: DropdownButtonFormField<String?>(
                    initialValue: assetId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Not linked')),
                      ...cashAssets.map((a) => DropdownMenuItem<String?>(
                          value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setState(() => assetId = v),
                  ),
                ),
              FormFieldBlock(
                title: 'Date',
                required: true,
                child: SoftCard(
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (picked != null) setState(() => date = picked);
                  },
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: LG.sage, size: 18),
                    const SizedBox(width: 12),
                    Text(LG.date(date)),
                  ]),
                ),
              ),
              FormFieldBlock(
                title: 'Receipt',
                help:
                    'Scan with the camera, pick from the gallery, or attach any file. Stored encrypted on this device.',
                child: _ReceiptPicker(
                  receipt: receipt,
                  busy: _attaching,
                  onScan: () => _attachFromCamera(),
                  onGallery: () => _attachFromGallery(),
                  onFile: () => _attachFromFiles(),
                  onPreview: () => _previewReceipt(),
                  onClear: () => setState(() => receipt = null),
                ),
              ),
              FormFieldBlock(
                title: 'Notes',
                child: TextFormField(controller: notes, maxLines: 3),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: busy ? null : _save,
                child: Text(busy ? 'Saving…' : 'Save expense'),
              ),
              if (widget.existing != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await widget.store
                                .removeExpense(widget.existing!.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: const Text('Delete expense',
                        style: TextStyle(color: LG.negative)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _attachFromCamera() async {
    try {
      setState(() => _attaching = true);
      final picker = ImagePicker();
      final shot = await picker.pickImage(source: ImageSource.camera,
          imageQuality: 85);
      if (shot != null) await _ingestFile(shot.path, shot.name, mime: 'image/jpeg');
    } on PlatformException catch (e) {
      _snack('Camera unavailable: ${e.message}');
    } catch (e) {
      _snack('Scan failed: $e');
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _attachFromGallery() async {
    try {
      setState(() => _attaching = true);
      final picker = ImagePicker();
      final shot = await picker.pickImage(source: ImageSource.gallery,
          imageQuality: 85);
      if (shot != null) await _ingestFile(shot.path, shot.name, mime: 'image/jpeg');
    } catch (e) {
      _snack('Pick failed: $e');
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _attachFromFiles() async {
    try {
      setState(() => _attaching = true);
      final pick = await FilePicker.platform
          .pickFiles(type: FileType.any, withData: false);
      final path = pick?.files.single.path;
      if (path != null) {
        await _ingestFile(path, pick!.files.single.name);
      }
    } catch (e) {
      _snack('File pick failed: $e');
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _ingestFile(String path, String name, {String? mime}) async {
    final bytes = await File(path).readAsBytes();
    final guessedMime = mime ?? _guessMime(name);
    // Reuse the same encrypted AttachmentStore DocumentDetailScreen
    // uses, keyed on a per-expense pseudo-document id.
    final ref = await widget.store.attachments.write(
      documentId: 'expense-${widget.existing?.id ?? makeId()}',
      bytes: bytes,
      filename: name,
      mimeType: guessedMime,
      key: widget.store.vault.activeKey,
    );
    if (!mounted) return;
    setState(() => receipt = ref);
  }

  Future<void> _previewReceipt() async {
    if (receipt == null) return;
    try {
      final tmp = await widget.store.attachments
          .materialize(receipt!, key: widget.store.vault.activeKey);
      await OpenFilex.open(tmp.path);
    } catch (e) {
      _snack('Could not preview receipt: $e');
    }
  }

  String _guessMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final resolvedCategory = category == kOtherSentinel
          ? customCategory.text.trim()
          : category;
      final record = ExpenseRecord(
        id: widget.existing?.id ?? makeId(),
        description: description.text.trim(),
        category: resolvedCategory,
        merchant: merchant.text.trim(),
        amountUgx: parseDecimalAmount(amount.text) ?? 0,
        occurredAt: date,
        paymentMethod: paymentMethod,
        assetId: assetId,
        notes: notes.text.trim(),
        receipt: receipt,
      );
      await widget.store.upsertExpense(record);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Visual helper block that shows the current receipt metadata and the
/// three attach actions.
class _ReceiptPicker extends StatelessWidget {
  final AttachmentRef? receipt;
  final bool busy;
  final VoidCallback onScan;
  final VoidCallback onGallery;
  final VoidCallback onFile;
  final VoidCallback onPreview;
  final VoidCallback onClear;
  const _ReceiptPicker({
    required this.receipt,
    required this.busy,
    required this.onScan,
    required this.onGallery,
    required this.onFile,
    required this.onPreview,
    required this.onClear,
  });
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (receipt != null)
            SoftCard(
              color: LG.sageSoft,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.attachment_rounded, color: LG.sage),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(receipt!.originalFilename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(
                            '${_sizeHuman(receipt!.sizeBytes)} · ${receipt!.mimeType}',
                            style: const TextStyle(
                                color: LG.muted, fontSize: 11.5)),
                      ]),
                ),
                IconButton(
                    tooltip: 'Preview',
                    onPressed: onPreview,
                    icon: const Icon(Icons.open_in_new, color: LG.sage)),
                IconButton(
                    tooltip: 'Remove',
                    onPressed: onClear,
                    icon: const Icon(Icons.close, color: LG.muted)),
              ]),
            ),
          if (receipt == null)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onScan,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onGallery,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('File'),
                ),
              ),
            ]),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(
                  minHeight: 3,
                  color: LG.sage,
                  backgroundColor: LG.sageSoft),
            ),
        ],
      );

  static String _sizeHuman(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

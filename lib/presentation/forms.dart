import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/design.dart';
import '../data/portfolio_store.dart';
import '../domain/models.dart';
import 'account_screens.dart';
import 'bank_providers_screen.dart';
import 'components.dart';
import 'online_scope.dart';
import 'widgets.dart';
import 'screens.dart';

int? parseAmount(String s)=>int.tryParse(s.replaceAll(RegExp(r'[ ,]'),''));
String? requireAmount(String? v){final n=parseAmount(v??'');return n==null||n<0?'Enter a valid non-negative UGX amount':null;}

/// Parses "1,500.5" / "1500" / "1500.00" into a whole-UGX int. Accepts
/// commas as thousand separators. Returns null on blank + raises on
/// malformed so the caller can decide.
int? parseDecimalAmount(String s) {
  final trimmed = s.trim().replaceAll(',', '');
  if (trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed);
  if (parsed == null) return null;
  return parsed.round();
}

String? requireDecimalAmount(String? v) {
  if (v == null || v.trim().isEmpty) return 'Enter a value';
  final parsed = double.tryParse(v.replaceAll(',', ''));
  if (parsed == null || parsed < 0) return 'Enter a valid UGX amount';
  return null;
}

/// Liability types — presented as a dropdown on the LiabilityForm so
/// users pick a category instead of free-typing.
const List<String> kLiabilityTypes = [
  'Mortgage',
  'SACCO loan',
  'Bank loan',
  'Personal loan',
  'Credit card',
  'Overdraft',
  'Student loan',
  'Mobile money loan',
  'Family loan',
];

/// Sentinel reused across forms to mean "Other…, I'll type a name".
const String kOtherSentinel = '__other__';

class AssetForm extends StatefulWidget {
  final PortfolioStore store;final AssetKind kind;final WealthAsset? existing;
  const AssetForm({super.key,required this.store,required this.kind,this.existing});
  @override State<AssetForm> createState()=>_AssetFormState();
}
/// Category options per asset kind. "Other…" at the tail opens a free
/// text entry so the dropdown doesn't block an entry we didn't list.
const Map<AssetKind, List<String>> _kCategoryOptions = {
  AssetKind.investment: [
    'Equities / shares',
    'Mutual fund',
    'Unit trust',
    'Treasury bills',
    'Treasury bonds',
    'Corporate bonds',
    'SACCO shares',
    'Private equity',
    'Crypto',
  ],
  AssetKind.savings: [
    'Current account',
    'Savings account',
    'Fixed deposit',
    'SACCO savings',
    'Mobile money',
  ],
  AssetKind.property: [
    'Residential',
    'Commercial',
    'Land',
    'Agricultural',
    'Mixed-use',
  ],
  AssetKind.other: [
    'Vehicle',
    'Equipment',
    'Collectible',
    'Intellectual property',
  ],
};

/// Common Ugandan institutions pre-populated on the dropdown. Users can
/// still enter a name not in the list via the "Other…" option and that
/// value is remembered via PortfolioState.knownInstitutions.
const List<String> _kDefaultInstitutions = [
  'Stanbic Bank Uganda',
  'Centenary Bank',
  'DFCU Bank',
  'Standard Chartered Uganda',
  'Absa Bank Uganda',
  'Equity Bank Uganda',
  'KCB Bank Uganda',
  'Bank of Africa Uganda',
  'Housing Finance Bank',
  'Post Bank Uganda',
  'MTN MoMo',
  'Airtel Money',
  'Bank of Uganda (Treasuries)',
  'Uganda Securities Exchange',
  'Britam Asset Managers',
  'ICEA Lion Asset Management',
  'Sanlam Investments',
  'Old Mutual Investment Group',
  'Mazima Retirement Plan',
];

class _AssetFormState extends State<AssetForm> {
  final key = GlobalKey<FormState>();
  late final name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final customCategory = TextEditingController(
      text: _isCustomCategory(widget.existing?.category)
          ? widget.existing!.category
          : '');
  late final amount = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.valueUgx.toString());
  late final owned = TextEditingController(
      text: ((widget.existing?.ownershipBps ?? 10000) / 100)
          .toStringAsFixed(0));
  late final cost = TextEditingController(
      text: widget.existing == null ? '' : widget.existing!.costUgx.toString());
  late final customInstitution = TextEditingController(
      text: _isCustomInstitution(widget.existing?.institution)
          ? widget.existing!.institution
          : '');
  late final accountNumber = TextEditingController(
      text: widget.existing?.accountNumber ?? '');
  late final location =
      TextEditingController(text: widget.existing?.location ?? '');
  late final notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late String category = _initialCategoryChoice();
  late String institution = _initialInstitutionChoice();
  late DateTime date = widget.existing?.valuedAt ?? DateTime.now();
  late RecordStatus status =
      widget.existing?.status ?? RecordStatus.userEntered;
  late InterestFrequency interestFrequency =
      widget.existing?.interestFrequency ?? InterestFrequency.none;
  late final interestRate = TextEditingController(
      text: widget.existing == null || widget.existing!.interestRateBps == 0
          ? ''
          : (widget.existing!.interestRateBps / 100).toStringAsFixed(2));
  bool saving = false;

  bool _isCustomCategory(String? value) {
    if (value == null || value.isEmpty) return false;
    final options = _kCategoryOptions[widget.kind] ?? const [];
    return !options.contains(value);
  }

  bool _isCustomInstitution(String? value) {
    if (value == null || value.isEmpty) return false;
    final known = {
      ..._kDefaultInstitutions,
      ...widget.store.state.knownInstitutions,
    };
    return !known.contains(value);
  }

  String _initialCategoryChoice() {
    final existing = widget.existing?.category ?? '';
    final options = _kCategoryOptions[widget.kind] ?? const [];
    if (options.contains(existing)) return existing;
    if (existing.isNotEmpty) return kOtherSentinel;
    return '';
  }

  String _initialInstitutionChoice() {
    final existing = widget.existing?.institution ?? '';
    if (existing.isEmpty) return '';
    final known = {
      ..._kDefaultInstitutions,
      ...widget.store.state.knownInstitutions,
    };
    if (known.contains(existing)) return existing;
    return kOtherSentinel;
  }

  @override
  void dispose() {
    for (final c in [
      name,
      customCategory,
      amount,
      owned,
      cost,
      customInstitution,
      accountNumber,
      location,
      notes,
      interestRate,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions = _kCategoryOptions[widget.kind] ?? const [];
    final institutions = <String>{
      ..._kDefaultInstitutions,
      ...widget.store.state.knownInstitutions,
    }.toList()
      ..sort();
    final showInstitution = widget.kind != AssetKind.property;
    final showAccountNumber = widget.kind == AssetKind.investment ||
        widget.kind == AssetKind.savings;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null
              ? 'Add ${assetTitle(widget.kind).toLowerCase()}'
              : 'Edit asset')),
      body: SafeArea(
        child: Form(
          key: key,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            children: [
              PageHeading(
                  widget.existing == null
                      ? 'New ${assetTitle(widget.kind).toLowerCase()}'
                      : 'Update ${widget.existing!.name}',
                  subtitle:
                      'Capture value, ownership and the date of the source.'),
              FormFieldBlock(
                title: 'Asset name',
                required: true,
                child: TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Unit trust / Rental house'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
              ),
              FormFieldBlock(
                title: 'Type or category',
                required: true,
                child: DropdownButtonFormField<String>(
                  initialValue: category.isEmpty ? null : category,
                  isExpanded: true,
                  items: [
                    ...categoryOptions.map((o) =>
                        DropdownMenuItem(value: o, child: Text(o))),
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
                    decoration:
                        const InputDecoration(hintText: 'Describe the category'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Describe the category'
                        : null,
                  ),
                ),
              FormFieldBlock(
                title: 'Current value (UGX)',
                required: true,
                help:
                    'Full market or account value before your ownership share. Decimals are rounded to the nearest shilling.',
                child: TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: const InputDecoration(hintText: '0'),
                  validator: _validateDecimalAmount,
                ),
              ),
              FormFieldBlock(
                title: 'Ownership share (%)',
                child: TextFormField(
                  controller: owned,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(hintText: '100'),
                  validator: (s) {
                    final d = double.tryParse(s ?? '');
                    return d == null || d < 0 || d > 100
                        ? 'Enter 0–100%'
                        : null;
                  },
                ),
              ),
              FormFieldBlock(
                title: 'Acquisition / original cost (UGX)',
                child: TextFormField(
                  controller: cost,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: const InputDecoration(
                      hintText: 'Optional; enter 0 if unknown'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? null : _validateDecimalAmount(v),
                ),
              ),
              if (widget.kind == AssetKind.property)
                FormFieldBlock(
                  title: 'Property location',
                  child: TextFormField(
                    controller: location,
                    decoration:
                        const InputDecoration(hintText: 'District / area'),
                  ),
                ),
              if (showInstitution) ...[
                FormFieldBlock(
                  title: 'Institution or provider',
                  help:
                      'Pick from your previous choices or add a new one via "Other…".',
                  child: DropdownButtonFormField<String>(
                    initialValue: institution.isEmpty ? null : institution,
                    isExpanded: true,
                    items: [
                      ...institutions.map((o) =>
                          DropdownMenuItem(value: o, child: Text(o))),
                      const DropdownMenuItem(
                          value: kOtherSentinel, child: Text('Other…')),
                    ],
                    onChanged: (v) => setState(() => institution = v ?? ''),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Pick an institution'
                        : null,
                  ),
                ),
                if (institution == kOtherSentinel)
                  FormFieldBlock(
                    title: 'New institution name',
                    child: TextFormField(
                      controller: customInstitution,
                      decoration: const InputDecoration(
                          hintText: 'Bank, SACCO, fund or other provider'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter the institution name'
                          : null,
                    ),
                  ),
              ],
              if (showAccountNumber)
                FormFieldBlock(
                  title: 'Portfolio / account number',
                  help:
                      'Reference held by the institution. Stored encrypted on this device.',
                  child: TextFormField(
                    controller: accountNumber,
                    decoration: const InputDecoration(
                        hintText: 'e.g. CSD-12345 or your account number'),
                  ),
                ),
              if (widget.kind == AssetKind.investment ||
                  widget.kind == AssetKind.savings) ...[
                FormFieldBlock(
                  title: 'Interest frequency',
                  help:
                      'How often the institution credits interest or coupons. Pick "Not interest-bearing" to hide interest actions.',
                  child: DropdownButtonFormField<InterestFrequency>(
                    initialValue: interestFrequency,
                    isExpanded: true,
                    items: InterestFrequency.values
                        .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(interestFrequencyLabel(f))))
                        .toList(),
                    onChanged: (v) => setState(
                        () => interestFrequency = v ?? interestFrequency),
                  ),
                ),
                if (interestFrequency != InterestFrequency.none)
                  FormFieldBlock(
                    title:
                        'Current average rate per period (%)',
                    help:
                        'Rate at the frequency you selected. 0.9 for 0.9% monthly, 12.5 for 12.5% annual. Used to pre-fill the next interest posting.',
                    child: TextFormField(
                      controller: interestRate,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      decoration:
                          const InputDecoration(hintText: 'e.g. 0.9'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final d =
                            double.tryParse(v.replaceAll(',', ''));
                        if (d == null || d < 0 || d > 100) {
                          return 'Enter 0–100%';
                        }
                        return null;
                      },
                    ),
                  ),
              ],
              FormFieldBlock(
                title: 'Valuation date',
                child: SoftCard(
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                        initialDate: date);
                    if (d != null) setState(() => date = d);
                  },
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: LG.sage, size: 18),
                    const SizedBox(width: 12),
                    Text(LG.date(date)),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: LG.muted),
                  ]),
                ),
              ),
              FormFieldBlock(
                title: 'Valuation status',
                child: DropdownButtonFormField<RecordStatus>(
                  initialValue: status,
                  items: RecordStatus.values
                      .map((x) =>
                          DropdownMenuItem(value: x, child: Text(x.name)))
                      .toList(),
                  onChanged: (v) => setState(() => status = v ?? status),
                ),
              ),
              FormFieldBlock(
                title: 'Notes (optional)',
                child: TextFormField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Valuation source, relevant context...'),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving...' : 'Save asset'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Accepts "1,500.50" / "1500.5" / "1500" etc. Rounds to the nearest
  /// whole UGX shilling because the backend model stores integers.
  static String? _validateDecimalAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter a value';
    final parsed = double.tryParse(v.replaceAll(',', ''));
    if (parsed == null || parsed < 0) return 'Enter a valid UGX amount';
    return null;
  }

  static int _parseDecimalToInt(String v) =>
      double.parse(v.replaceAll(',', '')).round();

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => saving = true);
    try {
      final resolvedCategory = category == kOtherSentinel
          ? customCategory.text.trim()
          : category;
      final resolvedInstitution = institution == kOtherSentinel
          ? customInstitution.text.trim()
          : institution;
      final rawRate = interestRate.text.trim();
      final rateBps = rawRate.isEmpty ||
              interestFrequency == InterestFrequency.none
          ? 0
          : ((double.tryParse(rawRate.replaceAll(',', '')) ?? 0) * 100)
              .round();
      final a = WealthAsset(
          id: widget.existing?.id ?? makeId(),
          name: name.text.trim(),
          kind: widget.kind,
          category: resolvedCategory,
          valueUgx: _parseDecimalToInt(amount.text),
          ownershipBps: (double.parse(owned.text) * 100).round(),
          costUgx: cost.text.trim().isEmpty
              ? 0
              : _parseDecimalToInt(cost.text),
          institution: resolvedInstitution,
          accountNumber: accountNumber.text.trim(),
          location: location.text.trim(),
          status: status,
          valuedAt: date,
          notes: notes.text.trim(),
          interestFrequency: interestFrequency,
          interestRateBps: rateBps);
      await widget.store.upsertAsset(a);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) snack(context, 'Could not save asset: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class LiabilityForm extends StatefulWidget {
  final PortfolioStore store;final Liability? existing;
  const LiabilityForm({super.key,required this.store,this.existing});
  @override State<LiabilityForm> createState()=>_LiabilityFormState();
}
class _LiabilityFormState extends State<LiabilityForm> {
  final key = GlobalKey<FormState>();
  late final name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final customLender = TextEditingController(
      text: _isCustomLender(widget.existing?.lender)
          ? widget.existing!.lender
          : '');
  late final amount = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.outstandingUgx.toString());
  late final accountNumber = TextEditingController(
      text: widget.existing?.accountNumber ?? '');
  late final note =
      TextEditingController(text: widget.existing?.notes ?? '');
  late String category = _initialCategoryChoice();
  late String lender = _initialLenderChoice();
  late String? propertyId = widget.existing?.propertyId;

  bool _isCustomLender(String? v) {
    if (v == null || v.isEmpty) return false;
    final known = {
      ..._kDefaultInstitutions,
      ...widget.store.state.knownInstitutions,
    };
    return !known.contains(v);
  }

  String _initialCategoryChoice() {
    final v = widget.existing?.category ?? '';
    if (v.isEmpty) return '';
    return kLiabilityTypes.contains(v) ? v : kOtherSentinel;
  }

  String _initialLenderChoice() {
    final v = widget.existing?.lender ?? '';
    if (v.isEmpty) return '';
    final known = {
      ..._kDefaultInstitutions,
      ...widget.store.state.knownInstitutions,
    };
    return known.contains(v) ? v : kOtherSentinel;
  }

  @override
  void dispose() {
    name.dispose();
    customLender.dispose();
    amount.dispose();
    accountNumber.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final properties = widget.store.state.assets
        .where((x) => x.kind == AssetKind.property && !x.archived)
        .toList();
    if (propertyId != null && !properties.any((x) => x.id == propertyId)) {
      propertyId = null;
    }
    final lenders = <String>{
      ..._kDefaultInstitutions,
      ...widget.store.state.knownInstitutions,
    }.toList()
      ..sort();
    final customCategory = TextEditingController(
        text: category == kOtherSentinel &&
                widget.existing != null &&
                !kLiabilityTypes.contains(widget.existing!.category)
            ? widget.existing!.category
            : '');
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null
              ? 'Add liability'
              : 'Edit liability')),
      body: SafeArea(
        child: Form(
          key: key,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              PageHeading(
                  widget.existing == null
                      ? 'Add liability'
                      : 'Edit liability',
                  subtitle:
                      'Record what you owe — including mortgages, SACCO loans and cards.'),
              FormFieldBlock(
                title: 'Liability name',
                required: true,
                child: TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                      hintText: 'e.g. KCB SACCO loan'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
              ),
              FormFieldBlock(
                title: 'Liability type',
                required: true,
                child: DropdownButtonFormField<String>(
                  initialValue: category.isEmpty ? null : category,
                  isExpanded: true,
                  items: [
                    ...kLiabilityTypes.map(
                        (t) => DropdownMenuItem(value: t, child: Text(t))),
                    const DropdownMenuItem(
                        value: kOtherSentinel, child: Text('Other…')),
                  ],
                  onChanged: (v) => setState(() => category = v ?? ''),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Pick a type' : null,
                ),
              ),
              if (category == kOtherSentinel)
                FormFieldBlock(
                  title: 'Custom liability type',
                  child: TextFormField(
                    controller: customCategory,
                    decoration: const InputDecoration(
                        hintText: 'Describe the liability type'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Describe the type'
                        : null,
                  ),
                ),
              FormFieldBlock(
                title: 'Lender',
                required: true,
                help:
                    'Pick from your institutions or add a new one via "Other…".',
                child: DropdownButtonFormField<String>(
                  initialValue: lender.isEmpty ? null : lender,
                  isExpanded: true,
                  items: [
                    ...lenders.map(
                        (o) => DropdownMenuItem(value: o, child: Text(o))),
                    const DropdownMenuItem(
                        value: kOtherSentinel, child: Text('Other…')),
                  ],
                  onChanged: (v) => setState(() => lender = v ?? ''),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Pick a lender' : null,
                ),
              ),
              if (lender == kOtherSentinel)
                FormFieldBlock(
                  title: 'New lender name',
                  child: TextFormField(
                    controller: customLender,
                    decoration: const InputDecoration(
                        hintText: 'Bank, SACCO or individual'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter the lender name'
                        : null,
                  ),
                ),
              FormFieldBlock(
                title: 'Loan / account reference',
                help:
                    'The reference the lender holds. Stored encrypted on this device.',
                child: TextFormField(
                  controller: accountNumber,
                  decoration: const InputDecoration(
                      hintText: 'e.g. LN-7788-22 or your reference'),
                ),
              ),
              FormFieldBlock(
                title: 'Outstanding balance (UGX)',
                required: true,
                help:
                    'Current amount owed. Decimals are rounded to the nearest shilling.',
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
                title: 'Link to property (optional)',
                help:
                    'A linked mortgage is counted only once in net worth.',
                child: DropdownButtonFormField<String?>(
                  initialValue: propertyId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Not linked')),
                    ...properties.map((p) => DropdownMenuItem<String?>(
                        value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (v) => setState(() => propertyId = v),
                ),
              ),
              FormFieldBlock(
                title: 'Notes',
                child: TextFormField(controller: note, maxLines: 3),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (!key.currentState!.validate()) return;
                  final resolvedCategory = category == kOtherSentinel
                      ? customCategory.text.trim()
                      : category;
                  final resolvedLender = lender == kOtherSentinel
                      ? customLender.text.trim()
                      : lender;
                  await widget.store.upsertLiability(Liability(
                      id: widget.existing?.id ?? makeId(),
                      name: name.text.trim(),
                      category: resolvedCategory,
                      lender: resolvedLender,
                      accountNumber: accountNumber.text.trim(),
                      outstandingUgx: parseDecimalAmount(amount.text) ?? 0,
                      propertyId: propertyId,
                      asOf: DateTime.now(),
                      notes: note.text.trim()));
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save liability'),
              ),
              if (widget.existing != null)
                TextButton(
                  onPressed: () => confirmArchive(context,
                      () => widget.store.archiveLiability(widget.existing!)),
                  child: const Text('Archive liability',
                      style: TextStyle(color: LG.negative)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventForm extends StatefulWidget {
  final PortfolioStore store;
  const EventForm({super.key,required this.store});
  @override State<EventForm> createState()=>_EventFormState();
}
class _EventFormState extends State<EventForm>{
  final form=GlobalKey<FormState>();
  final desc=TextEditingController();final amt=TextEditingController();final notes=TextEditingController();
  EventKind kind=EventKind.contribution;String? assetId;DateTime day=DateTime.now();
  @override void dispose(){desc.dispose();amt.dispose();notes.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Record transaction')),
    body:SafeArea(child:Form(key:form,child:ListView(padding:const EdgeInsets.all(22),children:[
      const PageHeading('New transaction',
          subtitle:
              'Post an immutable entry to your portfolio activity log.'),
      FormFieldBlock(
          title: 'Description',
          required: true,
          child: TextFormField(
              controller: desc,
              decoration:
                  const InputDecoration(hintText: 'e.g. Savings contribution'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null)),
      FormFieldBlock(
          title: 'Type',
          required: true,
          child: DropdownButtonFormField<EventKind>(
              initialValue: kind,
              isExpanded: true,
              items: EventKind.values
                  .where((x) => x != EventKind.reversal)
                  .map((x) =>
                      DropdownMenuItem(value: x, child: Text(x.name)))
                  .toList(),
              onChanged: (v) => setState(() => kind = v ?? kind))),
      FormFieldBlock(
          title: 'Amount (UGX)',
          required: true,
          help:
              'Positive amount; decimals are rounded to the nearest shilling.',
          child: TextFormField(
              controller: amt,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
              ],
              validator: requireDecimalAmount)),
      FormFieldBlock(
          title: 'Related asset (optional)',
          child: DropdownButtonFormField<String?>(
              initialValue: assetId,
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Portfolio-level entry')),
                ...widget.store.state.assets
                    .where((x) => !x.archived)
                    .map((a) =>
                        DropdownMenuItem(value: a.id, child: Text(a.name)))
              ],
              onChanged: (v) => setState(() => assetId = v))),
      FormFieldBlock(
          title: 'Date',
          required: true,
          child: SoftCard(
              onTap: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: DateTime(1990),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)));
                if (picked != null) setState(() => day = picked);
              },
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, color: LG.sage),
                const SizedBox(width: 12),
                Text(LG.date(day))
              ]))),
      FormFieldBlock(
          title: 'Notes',
          child: TextFormField(controller: notes, maxLines: 3)),
      const SizedBox(height: 10),
      const SoftCard(
          color: LG.sageSoft,
          child: Text(
              'An activity entry does not automatically change asset valuations. Update the asset value separately after reconciling statements.',
              style:
                  TextStyle(color: LG.muted, fontSize: 13, height: 1.5))),
      const SizedBox(height: 22),
      ElevatedButton(
          onPressed: () async {
            if (!form.currentState!.validate()) return;
            await widget.store.postEvent(LedgerEvent(
                id: makeId(),
                description: desc.text.trim(),
                kind: kind,
                amountUgx: parseDecimalAmount(amt.text) ?? 0,
                occurredAt: day,
                assetId: assetId,
                notes: notes.text));
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Post transaction')),
    ]))));
}

class GoalsScreen extends StatelessWidget {
  final PortfolioStore store;
  const GoalsScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final goals = store.state.goals;
        return ScreenPage(
            title: 'Wealth goals',
            subtitle: 'Make long-term progress visible.',
            children: [
              if (goals.isEmpty)
                const AppEmptyState(
                  title: 'No goals yet',
                  detail: 'Create a goal to track your financial priorities.',
                  icon: Icons.track_changes_outlined,
                )
              else
                ...goals.map((g) {
                  final pct = g.targetUgx <= 0
                      ? 0.0
                      : (g.savedUgx / g.targetUgx).clamp(0.0, 1.0);
                  final overdueTail = g.targetDate != null &&
                          g.targetDate!.isBefore(DateTime.now())
                      ? ', overdue since ${LG.date(g.targetDate!)}'
                      : g.targetDate != null
                          ? ', due ${LG.date(g.targetDate!)}'
                          : '';
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Semantics(
                        label:
                            '${g.name}, ${(pct * 100).round()}% funded — ${LG.money(g.savedUgx)} of ${LG.money(g.targetUgx)}$overdueTail',
                        button: true,
                        child: SoftCard(
                          onTap: () => push(context, GoalForm(store: store, existing: g)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(g.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))),
                                  if (g.targetDate != null) ...[
                                    StatusChip(
                                        label: 'Due ${LG.date(g.targetDate!)}',
                                        tone: g.targetDate!.isBefore(DateTime.now())
                                            ? StatusTone.warn
                                            : StatusTone.info),
                                    const SizedBox(width: 6),
                                  ],
                                  const Icon(Icons.chevron_right, color: LG.muted),
                                ]),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                    value: pct.toDouble(),
                                    minHeight: 8,
                                    color: LG.sage,
                                    backgroundColor: LG.sageSoft,
                                    borderRadius: BorderRadius.circular(7)),
                                const SizedBox(height: 9),
                                Text(
                                    '${LG.money(g.savedUgx)} of ${LG.money(g.targetUgx)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: LG.muted)),
                              ]),
                        ),
                      ));
                }),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                  onPressed: () => push(context, GoalForm(store: store)),
                  icon: const Icon(Icons.add),
                  label: const Text('Add wealth goal')),
            ]);
      });
}

/// Full-screen goal editor (G02). Previously only a create AlertDialog existed;
/// this adds a real form with a target date and an Archive-equivalent remove.
class GoalForm extends StatefulWidget {
  final PortfolioStore store;
  final WealthGoal? existing;
  const GoalForm({super.key, required this.store, this.existing});
  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late final target =
      TextEditingController(text: widget.existing?.targetUgx.toString() ?? '');
  late final saved = TextEditingController(
      text: widget.existing?.savedUgx.toString() ?? '0');
  late DateTime? targetDate = widget.existing?.targetDate;
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    target.dispose();
    saved.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    final targetUgx = parseAmount(target.text)!;
    final savedUgx = parseAmount(saved.text) ?? 0;
    if (savedUgx > targetUgx) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved amount cannot exceed the target')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.upsertGoal(WealthGoal(
          id: widget.existing?.id ?? makeId(),
          name: name.text.trim(),
          targetUgx: targetUgx,
          savedUgx: savedUgx,
          targetDate: targetDate));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save goal: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirm = await confirmActionSheet(context,
        title: 'Remove this goal?',
        consequence:
            'Progress will be deleted. This does not change any linked asset balance.',
        confirmLabel: 'Remove');
    if (!confirm) return;
    await widget.store.deleteGoal(existing.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AppPage(
        appBar: const AppHeader(),
        children: [
          PageHeading(widget.existing == null ? 'New wealth goal' : 'Edit goal',
              subtitle:
                  'A target you want to reach, tracked against the amount you have already set aside.'),
          Form(
              key: form,
              child: Column(children: [
                FormFieldBlock(
                    title: 'Goal name',
                    child: TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                            hintText: 'e.g. Land purchase, school fees'),
                        validator: (v) => v == null || v.trim().length < 2
                            ? 'Enter at least two characters'
                            : null)),
                FormFieldBlock(
                    title: 'Target (UGX)',
                    child: MoneyField(
                        controller: target, hint: 'Required target amount')),
                FormFieldBlock(
                    title: 'Saved so far (UGX)',
                    child: MoneyField(
                        controller: saved,
                        required: false,
                        hint: 'Enter 0 if you have not started yet')),
                FormFieldBlock(
                    title: 'Target date (optional)',
                    help: 'Leave blank for an open-ended goal.',
                    child: SoftCard(
                        onTap: () async {
                          final v = await showDatePicker(
                              context: context,
                              initialDate: targetDate ??
                                  DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 30)),
                              lastDate: DateTime(2100));
                          if (v != null) setState(() => targetDate = v);
                        },
                        child: Row(children: [
                          const Icon(Icons.event_outlined,
                              color: LG.sage, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  targetDate == null
                                      ? 'No target date set'
                                      : LG.date(targetDate!),
                                  overflow: TextOverflow.ellipsis)),
                          if (targetDate != null)
                            IconButton(
                                tooltip: 'Clear target date',
                                onPressed: () => setState(() => targetDate = null),
                                icon: const Icon(Icons.close,
                                    color: LG.muted, size: 18))
                        ]))),
              ])),
          PrimaryCTA(
              label: saving ? 'Saving…' : 'Save goal',
              loading: saving,
              onPressed: _save),
          if (widget.existing != null) ...[
            const SizedBox(height: 10),
            TextButton(
                onPressed: _delete,
                child: const Text('Remove goal',
                    style: TextStyle(color: LG.negative))),
          ],
        ],
      );
}

class LegacyScreen extends StatelessWidget {
  final PortfolioStore store;
  const LegacyScreen({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final contacts = store.state.contacts;
        return ScreenPage(
          title: 'Heritage & legacy',
          subtitle: 'Organise trusted contacts and estate-planning notes.',
          children: [
            const SoftCard(
                color: LG.sageSoft,
                child: Row(children: [
                  Icon(Icons.shield_outlined, color: LG.sage),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          'Contacts are private notes, not legally binding nominations or instructions.',
                          style: TextStyle(
                              fontSize: 12, color: LG.muted, height: 1.5)))
                ])),
            const SizedBox(height: 18),
            const SectionTitle('Trusted contacts'),
            if (contacts.isEmpty)
              const EmptySection(
                  title: 'No trusted contacts',
                  detail:
                      'Record a contact without sharing access to your portfolio.')
            else
              ...contacts.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: SoftCard(
                      onTap: () => push(
                          context, ContactForm(store: store, existing: c)),
                      child: Row(children: [
                        const CircleAvatar(
                            backgroundColor: LG.sageSoft,
                            child:
                                Icon(Icons.person_outline, color: LG.sage)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                              Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Text(c.relationship,
                                  style: const TextStyle(
                                      color: LG.muted, fontSize: 12)),
                              if (c.email.isNotEmpty)
                                Text(c.email,
                                    style: const TextStyle(
                                        color: LG.muted, fontSize: 11)),
                              if (c.phone.isNotEmpty)
                                Text(c.phone,
                                    style: const TextStyle(
                                        color: LG.muted, fontSize: 11)),
                              if (c.instructions.isNotEmpty)
                                Text(c.instructions,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: LG.muted, fontSize: 11)),
                            ])),
                        const Icon(Icons.chevron_right, color: LG.muted),
                      ]),
                    ),
                  )),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: () => push(context, ContactForm(store: store)),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add trusted contact')),
          ],
        );
      });
}

/// Full-screen add/edit trusted contact form. Replaces the earlier dialog
/// so edits are reachable and the fields are consistent with the rest of
/// the app.
class ContactForm extends StatefulWidget {
  final PortfolioStore store;
  final LegacyContact? existing;
  const ContactForm({super.key, required this.store, this.existing});
  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final form = GlobalKey<FormState>();
  late final name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final relation =
      TextEditingController(text: widget.existing?.relationship ?? '');
  late final email =
      TextEditingController(text: widget.existing?.email ?? '');
  late final phone =
      TextEditingController(text: widget.existing?.phone ?? '');
  late final instructions =
      TextEditingController(text: widget.existing?.instructions ?? '');
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    relation.dispose();
    email.dispose();
    phone.dispose();
    instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final contact = LegacyContact(
        id: widget.existing?.id ?? makeId(),
        name: name.text.trim(),
        relationship: relation.text.trim(),
        instructions: instructions.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
      );
      await widget.store.upsertContact(contact);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      snack(context, 'Could not save contact: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await widget.store.removeContact(existing.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ScreenPage(
        title: widget.existing == null ? 'New trusted contact' : 'Edit contact',
        subtitle: 'Reachability notes only — no portfolio access is granted.',
        children: [
          Form(
            key: form,
            child: Column(children: [
              FormFieldBlock(
                  title: 'Name',
                  child: TextFormField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null)),
              FormFieldBlock(
                  title: 'Relationship',
                  child: TextFormField(
                      controller: relation,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          hintText: 'Spouse, lawyer, SACCO chair…'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null)),
              FormFieldBlock(
                  title: 'Email (optional)',
                  child: TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(hintText: 'them@example.com'))),
              FormFieldBlock(
                  title: 'Phone (optional)',
                  child: TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          hintText: '+256 700 123 456'))),
              FormFieldBlock(
                  title: 'Notes (optional)',
                  help:
                      'What should they know or do? Avoid identity numbers or passwords.',
                  child: TextFormField(
                      controller: instructions,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          hintText:
                              'Where documents live, instructions for next steps…'))),
            ]),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: saving ? null : _save,
              child: Text(saving ? 'Saving…' : 'Save contact')),
          if (widget.existing != null) ...[
            const SizedBox(height: 10),
            TextButton(
                onPressed: saving ? null : _delete,
                child: const Text('Remove contact',
                    style: TextStyle(color: LG.negative))),
          ],
        ],
      );
}

class RemindersScreen extends StatelessWidget {
  final PortfolioStore store;
  const RemindersScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>ScreenPage(title:'Reminders',
    subtitle:'Dates and tasks you want to keep in view.',children:[
    if(store.state.reminders.isEmpty)const EmptySection(title:'No reminders',detail:'Record a maturity, rent, renewal or contribution date.')
    else ...([...store.state.reminders]..sort((a,b)=>a.dueAt.compareTo(b.dueAt))).map((r)=>Padding(
      padding:const EdgeInsets.only(bottom:8),child:SoftCard(child:CheckboxListTile(
        contentPadding:EdgeInsets.zero,value:r.completed,activeColor:LG.sage,
        onChanged:(_)=>store.toggleReminder(r.id),title:Text(r.title,style:TextStyle(
          decoration:r.completed?TextDecoration.lineThrough:null,fontWeight:FontWeight.w700,fontSize:14)),
        subtitle:Text(LG.date(r.dueAt)),controlAffinity:ListTileControlAffinity.leading)))),
    const SizedBox(height:16),ElevatedButton.icon(onPressed:()=>_reminderDialog(context,store),icon:const Icon(Icons.add_alert_outlined),label:const Text('Add reminder')),
    const SizedBox(height:12),const Text('In this offline preview, reminders appear in-app only. System notifications are not yet enabled.',
      style:TextStyle(color:LG.muted,fontSize:11)),
  ]);
}
Future<void> _reminderDialog(BuildContext context,PortfolioStore store)async{
  final controller=TextEditingController();DateTime due=DateTime.now().add(const Duration(days:7));
  await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
    title:const Text('Add reminder'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:controller,decoration:const InputDecoration(labelText:'Reminder title')),
      const SizedBox(height:14),TextButton.icon(onPressed:()async{final p=await showDatePicker(context:ctx,
        initialDate:due,firstDate:DateTime(2020),lastDate:DateTime(2100));if(p!=null)setDialog(()=>due=p);},
        icon:const Icon(Icons.calendar_month),label:Text(LG.date(due))),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
      TextButton(onPressed:()async{if(controller.text.trim().isEmpty)return;
        await store.addReminder(ReminderRecord(id:makeId(),title:controller.text.trim(),dueAt:due));
        if(ctx.mounted)Navigator.pop(ctx);},child:const Text('Save'))])));
  controller.dispose();
}

class SettingsScreen extends StatelessWidget {
  final PortfolioStore store;
  const SettingsScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>ScreenPage(title:'Settings & data',subtitle:'Your data stays on this device in preview mode.',children:[
    const PrivacyBanner(),const SizedBox(height:20),const SectionTitle('Local data management'),
    SoftCard(child:Column(children:[ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.upload_file_outlined,color:LG.sage),
      title:const Text('Export portfolio JSON'),subtitle:const Text('Copies unencrypted JSON to clipboard'),
      trailing:const Icon(Icons.chevron_right,color:LG.muted),onTap:()=>_export(context,store)),
      const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.download_outlined,color:LG.sage),
      title:const Text('Import portfolio JSON'),subtitle:const Text('Replaces current local portfolio after confirmation'),
      trailing:const Icon(Icons.chevron_right,color:LG.muted),onTap:()=>_import(context,store)),
      const Divider(),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.science_outlined,color:LG.sage),
      title:const Text('Load demo portfolio'),subtitle:const Text('Replaces local records with sample SRS data'),
      trailing:const Icon(Icons.chevron_right,color:LG.muted),onTap:()async{
        final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Replace portfolio?'),
          content:const Text('This overwrites your local entries with demonstration data.'),actions:[
            TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
            TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Load demo'))]));
        if(yes==true)await store.loadDemo();
      }),
    ])),const SizedBox(height:22),const SectionTitle('Device state'),
    SoftCard(child:Column(children:[
      ListTile(contentPadding:EdgeInsets.zero,
        leading:const Icon(Icons.storage_outlined,color:LG.sage),
        title:const Text('Data & sync status'),
        subtitle:const Text('Counts, last-saved time, encryption and remote status'),
        trailing:const Icon(Icons.chevron_right,color:LG.muted),
        onTap:()=>push(context,DataSyncStatusScreen(store:store))),
      const Divider(),
      ListTile(contentPadding:EdgeInsets.zero,
        leading:const Icon(Icons.restart_alt,color:LG.negative),
        title:const Text('Reset portfolio',style:TextStyle(color:LG.negative,fontWeight:FontWeight.w800)),
        subtitle:const Text('Remove every local record, attachment and passphrase'),
        onTap:()=>runLocalReset(context,store)),
    ])),
    // Bank aggregation is purely an online surface; only show the entry
    // when a backend is configured, otherwise it would advertise a
    // service that cannot run.
    Builder(builder:(context){
      final remote=OnlineScope.maybeOf(context)?.sync;
      if(remote==null)return const SizedBox.shrink();
      return Column(children:[
        const SizedBox(height:22),
        const SectionTitle('Online integrations'),
        SoftCard(child:ListTile(
          contentPadding:EdgeInsets.zero,
          leading:const Icon(Icons.account_balance_outlined,color:LG.sage),
          title:const Text('Bank aggregation providers'),
          subtitle:const Text('What the server can link against today'),
          trailing:const Icon(Icons.chevron_right,color:LG.muted),
          onTap:()=>push(context,BankProvidersScreen(sync:remote)),
        )),
      ]);
    }),
    const SizedBox(height:22),const SectionTitle('About'),
    const SoftCard(child:Column(children:[InfoLabel(label:'App',value:'LonyoGang Heritage'),
      InfoLabel(label:'Prototype version',value:'0.4.0 local alpha'),
      InfoLabel(label:'Default currency',value:'UGX'),
      InfoLabel(label:'Cloud synchronization',value:'Unavailable'),
      InfoLabel(label:'Encrypted local storage',value:'User-configurable (AES-GCM)'),
      InfoLabel(label:'Subscription / payments',value:'Not connected'),
    ])),
  ]);
}
Future<void> _export(BuildContext context,PortfolioStore store)async{
  final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Unencrypted export'),
    content:const Text('Copying the portfolio to the system clipboard makes its information readable by other apps. Do not export sensitive personal data in preview mode.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
      TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Copy JSON'))]));
  if(yes!=true)return;
  await Clipboard.setData(ClipboardData(text:store.exportJson()));
  if(context.mounted)snack(context,'Portfolio JSON copied to clipboard');
}
Future<void> _import(BuildContext context,PortfolioStore store)async{
  final controller=TextEditingController();
  final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Import portfolio JSON'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Text('This overwrites your current local portfolio. Save an export first.',style:TextStyle(fontSize:12,color:LG.muted)),
      const SizedBox(height:12),TextField(controller:controller,maxLines:6,decoration:const InputDecoration(hintText:'Paste exported JSON here')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),
      TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Replace data'))]));
  if(yes==true){try{await store.importJson(controller.text);
    if(context.mounted)snack(context,'Portfolio imported');
    }catch(e){if(context.mounted)snack(context,'Import rejected: $e');}}
  controller.dispose();
}

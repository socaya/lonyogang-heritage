/// Pure Dart finance records. All monetary values are integer UGX (no floating money).
enum AssetKind { investment, property, saving, other }
enum EntryType { income, expense, contribution, withdrawal }
enum ValuationSource { ownerEstimate, statement, licensedValuation, other }

extension AssetKindLabel on AssetKind {
  String get label => switch (this) {
    AssetKind.investment => 'Investments',
    AssetKind.property => 'Properties',
    AssetKind.saving => 'Savings',
    AssetKind.other => 'Other assets',
  };
}

T enumValue<T extends Enum>(Iterable<T> values, String name, T fallback) {
  for (final item in values) {
    if (item.name == name) return item;
  }
  return fallback;
}

int _n(Object? value) => (value as num?)?.toInt() ?? 0;
String _s(Object? value) => value?.toString() ?? '';
DateTime _dt(Object? value) => DateTime.tryParse(_s(value)) ?? DateTime.now();

class WealthAsset {
  const WealthAsset({
    required this.id, required this.kind, required this.name,
    required this.valueUgx, required this.costUgx,
    required this.ownershipBps, required this.valuedAt,
    required this.valuationSource, required this.acquiredAt,
    this.institution = '', this.location = '', this.notes = '', this.archived = false,
  });
  final String id, name, institution, location, notes;
  final AssetKind kind;
  final int valueUgx, costUgx, ownershipBps;
  final DateTime valuedAt, acquiredAt;
  final ValuationSource valuationSource;
  final bool archived;

  WealthAsset copyWith({String? name, AssetKind? kind, int? valueUgx, int? costUgx,
    int? ownershipBps, DateTime? valuedAt, ValuationSource? valuationSource,
    DateTime? acquiredAt, String? institution, String? location, String? notes, bool? archived}) =>
    WealthAsset(id: id, name: name ?? this.name, kind: kind ?? this.kind,
      valueUgx: valueUgx ?? this.valueUgx, costUgx: costUgx ?? this.costUgx,
      ownershipBps: ownershipBps ?? this.ownershipBps, valuedAt: valuedAt ?? this.valuedAt,
      valuationSource: valuationSource ?? this.valuationSource, acquiredAt: acquiredAt ?? this.acquiredAt,
      institution: institution ?? this.institution, location: location ?? this.location,
      notes: notes ?? this.notes, archived: archived ?? this.archived);

  Map<String, Object?> toDb() => {
    'id': id, 'kind': kind.name, 'name': name, 'value_ugx': valueUgx,
    'cost_ugx': costUgx, 'ownership_bps': ownershipBps,
    'valued_at': valuedAt.toUtc().toIso8601String(), 'source': valuationSource.name,
    'acquired_at': acquiredAt.toUtc().toIso8601String(), 'institution': institution,
    'location': location, 'notes': notes, 'archived': archived ? 1 : 0,
  };
  factory WealthAsset.fromDb(Map<String, Object?> m) => WealthAsset(
    id: _s(m['id']), kind: enumValue(AssetKind.values, _s(m['kind']), AssetKind.other),
    name: _s(m['name']), valueUgx: _n(m['value_ugx']), costUgx: _n(m['cost_ugx']),
    ownershipBps: _n(m['ownership_bps']), valuedAt: _dt(m['valued_at']),
    valuationSource: enumValue(ValuationSource.values, _s(m['source']), ValuationSource.ownerEstimate),
    acquiredAt: _dt(m['acquired_at']), institution: _s(m['institution']),
    location: _s(m['location']), notes: _s(m['notes']), archived: _n(m['archived']) == 1,
  );
}

class WealthDebt {
  const WealthDebt({required this.id, required this.name, required this.balanceUgx,
    required this.lender, this.linkedAssetId = '', this.interestBps = 0, this.dueAt, this.notes = ''});
  final String id, name, lender, linkedAssetId, notes;
  final int balanceUgx, interestBps;
  final DateTime? dueAt;
  Map<String, Object?> toDb() => {
    'id': id, 'name': name, 'balance_ugx': balanceUgx, 'lender': lender,
    'linked_asset_id': linkedAssetId, 'interest_bps': interestBps,
    'due_at': dueAt?.toUtc().toIso8601String(), 'notes': notes,
  };
  factory WealthDebt.fromDb(Map<String, Object?> m) => WealthDebt(
    id: _s(m['id']), name: _s(m['name']), balanceUgx: _n(m['balance_ugx']),
    lender: _s(m['lender']), linkedAssetId: _s(m['linked_asset_id']),
    interestBps: _n(m['interest_bps']),
    dueAt: m['due_at'] == null ? null : DateTime.tryParse(_s(m['due_at'])),
    notes: _s(m['notes']),
  );
}

class WealthEntry {
  const WealthEntry({required this.id, required this.type, required this.amountUgx,
    required this.category, required this.occurredAt, this.assetId = '', this.notes = ''});
  final String id, category, assetId, notes;
  final EntryType type;
  final int amountUgx;
  final DateTime occurredAt;
  Map<String, Object?> toDb() => {
    'id': id, 'kind': type.name, 'amount_ugx': amountUgx,
    'category': category, 'occurred_at': occurredAt.toUtc().toIso8601String(),
    'asset_id': assetId, 'notes': notes,
  };
  factory WealthEntry.fromDb(Map<String, Object?> m) => WealthEntry(
    id: _s(m['id']), type: enumValue(EntryType.values, _s(m['kind']), EntryType.expense),
    amountUgx: _n(m['amount_ugx']), category: _s(m['category']),
    occurredAt: _dt(m['occurred_at']), assetId: _s(m['asset_id']), notes: _s(m['notes']),
  );
}

class WealthValuation {
  const WealthValuation({required this.id, required this.assetId, required this.valueUgx,
    required this.source, required this.recordedAt, this.note = ''});
  final String id, assetId, note;
  final int valueUgx;
  final ValuationSource source;
  final DateTime recordedAt;
  Map<String, Object?> toDb() => {
    'id': id, 'asset_id': assetId, 'value_ugx': valueUgx,
    'source': source.name, 'recorded_at': recordedAt.toUtc().toIso8601String(), 'note': note,
  };
  factory WealthValuation.fromDb(Map<String, Object?> m) => WealthValuation(
    id: _s(m['id']), assetId: _s(m['asset_id']), valueUgx: _n(m['value_ugx']),
    source: enumValue(ValuationSource.values, _s(m['source']), ValuationSource.ownerEstimate),
    recordedAt: _dt(m['recorded_at']), note: _s(m['note']),
  );
}

class WealthBeneficiary {
  const WealthBeneficiary({required this.id, required this.name, required this.relationship,
    required this.contact, this.notes = '', this.nominationConfirmed = false});
  final String id, name, relationship, contact, notes;
  final bool nominationConfirmed;
  Map<String, Object?> toDb() => {
    'id': id, 'name': name, 'relationship': relationship, 'contact': contact,
    'notes': notes, 'nomination_confirmed': nominationConfirmed ? 1 : 0,
  };
  factory WealthBeneficiary.fromDb(Map<String, Object?> m) => WealthBeneficiary(
    id: _s(m['id']), name: _s(m['name']), relationship: _s(m['relationship']),
    contact: _s(m['contact']), notes: _s(m['notes']),
    nominationConfirmed: _n(m['nomination_confirmed']) == 1,
  );
}

class WealthReminder {
  const WealthReminder({required this.id, required this.title, required this.dueAt,
    this.assetId = '', this.details = '', this.done = false});
  final String id, title, assetId, details;
  final DateTime dueAt;
  final bool done;
  Map<String, Object?> toDb() => {
    'id': id, 'title': title, 'due_at': dueAt.toUtc().toIso8601String(),
    'asset_id': assetId, 'details': details, 'done': done ? 1 : 0,
  };
  factory WealthReminder.fromDb(Map<String, Object?> m) => WealthReminder(
    id: _s(m['id']), title: _s(m['title']), dueAt: _dt(m['due_at']),
    assetId: _s(m['asset_id']), details: _s(m['details']), done: _n(m['done']) == 1,
  );
}

class WealthDocument {
  const WealthDocument({required this.id, required this.name, required this.mime,
    required this.assetId, required this.addedAt, required this.byteCount});
  final String id, name, mime, assetId;
  final DateTime addedAt;
  final int byteCount;
  Map<String, Object?> toDb() => {
    'id': id, 'name': name, 'mime': mime, 'asset_id': assetId,
    'added_at': addedAt.toUtc().toIso8601String(), 'byte_count': byteCount,
  };
  factory WealthDocument.fromDb(Map<String, Object?> m) => WealthDocument(
    id: _s(m['id']), name: _s(m['name']), mime: _s(m['mime']),
    assetId: _s(m['asset_id']), addedAt: _dt(m['added_at']),
    byteCount: _n(m['byte_count']),
  );
}

class WealthProfile {
  const WealthProfile({required this.name, required this.email, required this.createdAt});
  final String name, email;
  final DateTime createdAt;
}

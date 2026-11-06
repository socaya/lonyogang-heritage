import 'dart:convert';

/// Values are stored in integer UGX units: never binary floating-point currency.
/// Native-currency holdings require a separately implemented sourced FX policy.
enum AssetKind { investment, property, savings, other }
enum RecordStatus { estimated, userEntered, verified, stale }
enum EventKind { contribution, withdrawal, dividend, interest, rent, expense, fee, tax, transfer, adjustment, reversal }

typedef Json = Map<String, dynamic>;

int asInt(Object? value, [int fallback = 0]) => switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? fallback,
      _ => fallback,
    };
String asString(Object? value, [String fallback = '']) => value is String ? value : fallback;
DateTime readDate(Object? v) => DateTime.tryParse(asString(v)) ?? DateTime(2020);
String makeId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
int _idCounter = 0;

class WealthAsset {
  final String id;
  final String name;
  final AssetKind kind;
  final String category;
  final int valueUgx;
  final int ownershipBps; // 10,000 means 100 percent.
  final int costUgx;
  final String institution;
  final String location;
  final RecordStatus status;
  final DateTime valuedAt;
  final String notes;
  final bool archived;

  const WealthAsset({required this.id, required this.name, required this.kind, this.category = '', required this.valueUgx,
    this.ownershipBps = 10000, this.costUgx = 0, this.institution = '', this.location = '',
    this.status = RecordStatus.userEntered, required this.valuedAt, this.notes = '', this.archived = false});

  int get attributableUgx => (valueUgx * ownershipBps) ~/ 10000;
  Json toJson() => {'id':id,'name':name,'kind':kind.name,'category':category,'valueUgx':valueUgx,
    'ownershipBps':ownershipBps,'costUgx':costUgx,'institution':institution,'location':location,
    'status':status.name,'valuedAt':valuedAt.toIso8601String(),'notes':notes,'archived':archived};
  factory WealthAsset.fromJson(Json j) => WealthAsset(
    id:asString(j['id']),name:asString(j['name']),
    kind:AssetKind.values.firstWhere((x)=>x.name==j['kind'],orElse:()=>AssetKind.other),
    category:asString(j['category']),valueUgx:asInt(j['valueUgx']),
    ownershipBps:asInt(j['ownershipBps'],10000).clamp(0,10000).toInt(),costUgx:asInt(j['costUgx']),
    institution:asString(j['institution']),location:asString(j['location']),
    status:RecordStatus.values.firstWhere((x)=>x.name==j['status'],orElse:()=>RecordStatus.userEntered),
    valuedAt:readDate(j['valuedAt']),notes:asString(j['notes']),archived:j['archived']==true);
  WealthAsset copyWith({bool? archived}) => WealthAsset(id:id,name:name,kind:kind,category:category,valueUgx:valueUgx,
    ownershipBps:ownershipBps,costUgx:costUgx,institution:institution,location:location,status:status,
    valuedAt:valuedAt,notes:notes,archived:archived??this.archived);
}

class Liability {
  final String id;
  final String name;
  final String lender;
  final int outstandingUgx;
  final int principalUgx;
  final String? propertyId;
  final DateTime asOf;
  final DateTime? dueAt;
  final String notes;
  final bool archived;
  const Liability({required this.id,required this.name,this.lender='',required this.outstandingUgx,
    this.principalUgx=0,this.propertyId,required this.asOf,this.dueAt,this.notes='',this.archived=false});
  Json toJson()=>{'id':id,'name':name,'lender':lender,'outstandingUgx':outstandingUgx,'principalUgx':principalUgx,
    'propertyId':propertyId,'asOf':asOf.toIso8601String(),'dueAt':dueAt?.toIso8601String(),'notes':notes,'archived':archived};
  factory Liability.fromJson(Json j)=>Liability(id:asString(j['id']),name:asString(j['name']),lender:asString(j['lender']),
    outstandingUgx:asInt(j['outstandingUgx']),principalUgx:asInt(j['principalUgx']),propertyId:j['propertyId'] as String?,
    asOf:readDate(j['asOf']),dueAt:j['dueAt']==null?null:readDate(j['dueAt']),notes:asString(j['notes']),archived:j['archived']==true);
  Liability copyWith({bool? archived})=>Liability(id:id,name:name,lender:lender,outstandingUgx:outstandingUgx,
    principalUgx:principalUgx,propertyId:propertyId,asOf:asOf,dueAt:dueAt,notes:notes,archived:archived??this.archived);
}

class LedgerEvent {
  final String id;
  final String description;
  final EventKind kind;
  final int amountUgx;
  final DateTime occurredAt;
  final String? assetId;
  final String? reversalOf;
  final String notes;
  const LedgerEvent({required this.id,required this.description,required this.kind,required this.amountUgx,
    required this.occurredAt,this.assetId,this.reversalOf,this.notes=''});
  Json toJson()=>{'id':id,'description':description,'kind':kind.name,'amountUgx':amountUgx,
    'occurredAt':occurredAt.toIso8601String(),'assetId':assetId,'reversalOf':reversalOf,'notes':notes};
  factory LedgerEvent.fromJson(Json j)=>LedgerEvent(id:asString(j['id']),description:asString(j['description']),
    kind:EventKind.values.firstWhere((x)=>x.name==j['kind'],orElse:()=>EventKind.adjustment),
    amountUgx:asInt(j['amountUgx']),occurredAt:readDate(j['occurredAt']),assetId:j['assetId'] as String?,
    reversalOf:j['reversalOf'] as String?,notes:asString(j['notes']));
}

class WealthGoal {
  final String id;final String name;final int targetUgx;final int savedUgx;final DateTime? targetDate;
  const WealthGoal({required this.id,required this.name,required this.targetUgx,this.savedUgx=0,this.targetDate});
  Json toJson()=>{'id':id,'name':name,'targetUgx':targetUgx,'savedUgx':savedUgx,'targetDate':targetDate?.toIso8601String()};
  factory WealthGoal.fromJson(Json j)=>WealthGoal(id:asString(j['id']),name:asString(j['name']),targetUgx:asInt(j['targetUgx']),
    savedUgx:asInt(j['savedUgx']),targetDate:j['targetDate']==null?null:readDate(j['targetDate']));
}

class LegacyContact {
  final String id;final String name;final String relationship;final String instructions;
  const LegacyContact({required this.id,required this.name,required this.relationship,this.instructions=''});
  Json toJson()=>{'id':id,'name':name,'relationship':relationship,'instructions':instructions};
  factory LegacyContact.fromJson(Json j)=>LegacyContact(id:asString(j['id']),name:asString(j['name']),
    relationship:asString(j['relationship']),instructions:asString(j['instructions']));
}

class ReminderRecord {
  final String id;final String title;final DateTime dueAt;final bool completed;
  const ReminderRecord({required this.id,required this.title,required this.dueAt,this.completed=false});
  Json toJson()=>{'id':id,'title':title,'dueAt':dueAt.toIso8601String(),'completed':completed};
  factory ReminderRecord.fromJson(Json j)=>ReminderRecord(id:asString(j['id']),title:asString(j['title']),
    dueAt:readDate(j['dueAt']),completed:j['completed']==true);
  ReminderRecord toggle()=>ReminderRecord(id:id,title:title,dueAt:dueAt,completed:!completed);
}

class PortfolioState {
  final String ownerName;
  final bool onboardingDone;
  final List<WealthAsset> assets;
  final List<Liability> liabilities;
  final List<LedgerEvent> events;
  final List<WealthGoal> goals;
  final List<LegacyContact> contacts;
  final List<ReminderRecord> reminders;
  const PortfolioState({this.ownerName='',this.onboardingDone=false,this.assets=const [],this.liabilities=const [],
    this.events=const [],this.goals=const [],this.contacts=const [],this.reminders=const []});
  Json toJson()=>{'schemaVersion':1,'ownerName':ownerName,'onboardingDone':onboardingDone,
    'assets':assets.map((x)=>x.toJson()).toList(),'liabilities':liabilities.map((x)=>x.toJson()).toList(),
    'events':events.map((x)=>x.toJson()).toList(),'goals':goals.map((x)=>x.toJson()).toList(),
    'contacts':contacts.map((x)=>x.toJson()).toList(),'reminders':reminders.map((x)=>x.toJson()).toList()};
  factory PortfolioState.fromJson(Json j) {
    if (asInt(j['schemaVersion'])!=1) throw const FormatException('Unsupported portfolio data schema');
    List<T> read<T>(String key,T Function(Json) parse)=>(j[key] as List<dynamic>? ?? const [])
      .map((x)=>parse(Map<String,dynamic>.from(x as Map))).toList();
    return PortfolioState(ownerName:asString(j['ownerName']),onboardingDone:j['onboardingDone']==true,
      assets:read('assets',WealthAsset.fromJson),liabilities:read('liabilities',Liability.fromJson),
      events:read('events',LedgerEvent.fromJson),goals:read('goals',WealthGoal.fromJson),
      contacts:read('contacts',LegacyContact.fromJson),reminders:read('reminders',ReminderRecord.fromJson));
  }
  String encode()=>jsonEncode(toJson());
}

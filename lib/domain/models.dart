import 'dart:convert';
import 'dart:math';

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

final Random _idRng = Random.secure();
int _idCounter = _idRng.nextInt(1 << 32);
// Ids must be globally unique inside a single install so sync reconciliation
// can treat an id as a key. Microsecond resolution plus a per-process
// random-seeded counter and a random tail gives enough entropy that two
// writes in the same microsecond can't collide.
String makeId() {
  _idCounter = (_idCounter + 1) & 0xffffffff;
  final tail = _idRng.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-'
      '${_idCounter.toRadixString(16)}-$tail';
}

class WealthAsset {
  final String id;
  final String name;
  final AssetKind kind;
  final String category;
  final int valueUgx;
  final int ownershipBps; // 10,000 means 100 percent.
  final int costUgx;
  final String institution;
  final String accountNumber; // Portfolio / broker / SACCO reference.
  final String location;
  final RecordStatus status;
  final DateTime valuedAt;
  final String notes;
  final bool archived;

  const WealthAsset({required this.id, required this.name, required this.kind, this.category = '', required this.valueUgx,
    this.ownershipBps = 10000, this.costUgx = 0, this.institution = '', this.accountNumber = '',
    this.location = '',
    this.status = RecordStatus.userEntered, required this.valuedAt, this.notes = '', this.archived = false});

  int get attributableUgx => (valueUgx * ownershipBps) ~/ 10000;
  Json toJson() => {'id':id,'name':name,'kind':kind.name,'category':category,'valueUgx':valueUgx,
    'ownershipBps':ownershipBps,'costUgx':costUgx,'institution':institution,
    'accountNumber':accountNumber,'location':location,
    'status':status.name,'valuedAt':valuedAt.toIso8601String(),'notes':notes,'archived':archived};
  factory WealthAsset.fromJson(Json j) => WealthAsset(
    id:asString(j['id']),name:asString(j['name']),
    kind:AssetKind.values.firstWhere((x)=>x.name==j['kind'],orElse:()=>AssetKind.other),
    category:asString(j['category']),valueUgx:asInt(j['valueUgx']),
    ownershipBps:asInt(j['ownershipBps'],10000).clamp(0,10000).toInt(),costUgx:asInt(j['costUgx']),
    institution:asString(j['institution']),accountNumber:asString(j['accountNumber']),
    location:asString(j['location']),
    status:RecordStatus.values.firstWhere((x)=>x.name==j['status'],orElse:()=>RecordStatus.userEntered),
    valuedAt:readDate(j['valuedAt']),notes:asString(j['notes']),archived:j['archived']==true);
  WealthAsset copyWith({bool? archived,int? valueUgx,DateTime? valuedAt,RecordStatus? status,String? accountNumber,String? institution,String? category}) => WealthAsset(id:id,name:name,kind:kind,
    category:category??this.category,valueUgx:valueUgx??this.valueUgx,
    ownershipBps:ownershipBps,costUgx:costUgx,institution:institution??this.institution,
    accountNumber:accountNumber??this.accountNumber,
    location:location,status:status??this.status,
    valuedAt:valuedAt??this.valuedAt,notes:notes,archived:archived??this.archived);
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
  final String id;
  final String name;
  final String relationship;
  final String instructions;
  final String email;
  final String phone;
  const LegacyContact({
    required this.id,
    required this.name,
    required this.relationship,
    this.instructions = '',
    this.email = '',
    this.phone = '',
  });
  Json toJson() => {
        'id': id,
        'name': name,
        'relationship': relationship,
        'instructions': instructions,
        if (email.isNotEmpty) 'email': email,
        if (phone.isNotEmpty) 'phone': phone,
      };
  factory LegacyContact.fromJson(Json j) => LegacyContact(
        id: asString(j['id']),
        name: asString(j['name']),
        relationship: asString(j['relationship']),
        instructions: asString(j['instructions']),
        email: asString(j['email']),
        phone: asString(j['phone']),
      );
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
  final List<DocumentRecord> documents;
  final List<BeneficiaryRecord> beneficiaries;
  final List<ValuationRecord> valuations;
  final NotificationOptions notificationOptions;
  final List<FxRate> fxRates;
  final List<ScheduledContribution> scheduled;
  /// Target weights by asset id, stored as basis points (10,000 = 100%).
  final Map<String,int> targetWeightsBps;
  /// Dismissed alerts, keyed `source:sourceId:isoOccurrence`. The notification
  /// center suppresses an entry whose key is present until the underlying
  /// record moves to a later occurrence (e.g. reminder dueAt changes).
  final Set<String> dismissedAlertKeys;
  /// Institutions the user has entered at least once. Investment / savings
  /// forms show them as a dropdown so the second write is a tap instead
  /// of a re-type, while still accepting a new "Other..." entry.
  final Set<String> knownInstitutions;
  const PortfolioState({this.ownerName='',this.onboardingDone=false,this.assets=const [],this.liabilities=const [],
    this.events=const [],this.goals=const [],this.contacts=const [],this.reminders=const [],
    this.documents=const [],this.beneficiaries=const [],this.valuations=const [],
    this.notificationOptions=const NotificationOptions(),
    this.fxRates=const [],this.scheduled=const [],
    this.targetWeightsBps=const <String,int>{},
    this.dismissedAlertKeys=const <String>{},
    this.knownInstitutions=const <String>{}});
  Json toJson()=>{'schemaVersion':2,'ownerName':ownerName,'onboardingDone':onboardingDone,
    'assets':assets.map((x)=>x.toJson()).toList(),'liabilities':liabilities.map((x)=>x.toJson()).toList(),
    'events':events.map((x)=>x.toJson()).toList(),'goals':goals.map((x)=>x.toJson()).toList(),
    'contacts':contacts.map((x)=>x.toJson()).toList(),'reminders':reminders.map((x)=>x.toJson()).toList(),
    'documents':documents.map((x)=>x.toJson()).toList(),
    'beneficiaries':beneficiaries.map((x)=>x.toJson()).toList(),
    'valuations':valuations.map((x)=>x.toJson()).toList(),
    'notificationOptions':notificationOptions.toJson(),
    'fxRates':fxRates.map((x)=>x.toJson()).toList(),
    'scheduled':scheduled.map((x)=>x.toJson()).toList(),
    'targetWeightsBps':targetWeightsBps,
    'dismissedAlertKeys':dismissedAlertKeys.toList(),
    'knownInstitutions':knownInstitutions.toList()};
  factory PortfolioState.fromJson(Json j) {
    final v=asInt(j['schemaVersion']);
    if (v!=1 && v!=2) throw const FormatException('Unsupported portfolio data schema');
    List<T> read<T>(String key,T Function(Json) parse)=>(j[key] as List<dynamic>? ?? const [])
      .map((x)=>parse(Map<String,dynamic>.from(x as Map))).toList();
    final weightsRaw=j['targetWeightsBps'];
    final weights=<String,int>{};
    if (weightsRaw is Map) {
      weightsRaw.forEach((k,x){weights[k.toString()]=asInt(x).clamp(0,10000).toInt();});
    }
    return PortfolioState(ownerName:asString(j['ownerName']),onboardingDone:j['onboardingDone']==true,
      assets:read('assets',WealthAsset.fromJson),liabilities:read('liabilities',Liability.fromJson),
      events:read('events',LedgerEvent.fromJson),goals:read('goals',WealthGoal.fromJson),
      contacts:read('contacts',LegacyContact.fromJson),reminders:read('reminders',ReminderRecord.fromJson),
      documents:read('documents',DocumentRecord.fromJson),
      beneficiaries:read('beneficiaries',BeneficiaryRecord.fromJson),
      valuations:read('valuations',ValuationRecord.fromJson),
      fxRates:read('fxRates',FxRate.fromJson),
      scheduled:read('scheduled',ScheduledContribution.fromJson),
      targetWeightsBps:weights,
      dismissedAlertKeys:(j['dismissedAlertKeys'] as List<dynamic>? ?? const [])
          .map((e)=>e.toString()).toSet(),
      knownInstitutions:(j['knownInstitutions'] as List<dynamic>? ?? const [])
          .map((e)=>e.toString()).toSet(),
      notificationOptions:NotificationOptions.fromJson(j['notificationOptions'] is Map ? Map<String,dynamic>.from(j['notificationOptions'] as Map) : <String,dynamic>{}));
  }
  String encode()=>jsonEncode(toJson());
}

/// A manually-recorded foreign-exchange rate expressed as integer UGX
/// micro-units per unit of foreign currency. Keeping the quote in integers
/// avoids the floating-point rounding that already bit the 0.3 preview.
class FxRate {
  final String currency;
  final int ugxPerUnit;
  final DateTime asOf;
  final String source;
  const FxRate({required this.currency,required this.ugxPerUnit,
    required this.asOf,this.source=''});
  Json toJson()=>{'currency':currency,'ugxPerUnit':ugxPerUnit,
    'asOf':asOf.toIso8601String(),'source':source};
  factory FxRate.fromJson(Json j)=>FxRate(
    currency:asString(j['currency']).toUpperCase(),
    ugxPerUnit:asInt(j['ugxPerUnit']),
    asOf:readDate(j['asOf']),
    source:asString(j['source']));
}

enum ContributionFrequency { weekly, monthly, quarterly, annually }
int frequencyDays(ContributionFrequency f)=>switch(f){
  ContributionFrequency.weekly=>7,ContributionFrequency.monthly=>30,
  ContributionFrequency.quarterly=>91,ContributionFrequency.annually=>365};

/// A recurring contribution schedule. The next-fire date is a display and
/// scheduling anchor; actual posting still produces a regular LedgerEvent.
class ScheduledContribution {
  final String id;
  final String name;
  final int amountUgx;
  final String? assetId;
  final ContributionFrequency frequency;
  final DateTime nextFire;
  final DateTime? lastFired;
  final bool active;
  const ScheduledContribution({required this.id,required this.name,
    required this.amountUgx,this.assetId,required this.frequency,
    required this.nextFire,this.lastFired,this.active=true});
  Json toJson()=>{'id':id,'name':name,'amountUgx':amountUgx,'assetId':assetId,
    'frequency':frequency.name,'nextFire':nextFire.toIso8601String(),
    'lastFired':lastFired?.toIso8601String(),'active':active};
  factory ScheduledContribution.fromJson(Json j)=>ScheduledContribution(
    id:asString(j['id']),name:asString(j['name']),amountUgx:asInt(j['amountUgx']),
    assetId:j['assetId'] as String?,
    frequency:ContributionFrequency.values.firstWhere((x)=>x.name==j['frequency'],
      orElse:()=>ContributionFrequency.monthly),
    nextFire:readDate(j['nextFire']),
    lastFired:j['lastFired']==null?null:readDate(j['lastFired']),
    active:j['active']!=false);
  ScheduledContribution advance({DateTime? firedAt})=>ScheduledContribution(
    id:id,name:name,amountUgx:amountUgx,assetId:assetId,frequency:frequency,
    nextFire:(firedAt??nextFire).add(Duration(days:frequencyDays(frequency))),
    lastFired:firedAt??nextFire,active:active);
  ScheduledContribution withActive(bool value)=>ScheduledContribution(
    id:id,name:name,amountUgx:amountUgx,assetId:assetId,frequency:frequency,
    nextFire:nextFire,lastFired:lastFired,active:value);
}


/// A catalog record plus an optional encrypted file attachment stored on the
/// device. The attachment is referenced by relative path; its bytes are
/// AES-GCM encrypted at rest and decrypted on demand for preview.
class DocumentRecord {
  final String id;
  final String title;
  final String category;
  final String? linkedAssetId;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String notes;
  final bool archived;
  final AttachmentRef? attachment;
  const DocumentRecord({required this.id,required this.title,required this.category,
    this.linkedAssetId,this.issuedAt,this.expiresAt,this.notes='',this.archived=false,
    this.attachment});
  Json toJson()=>{'id':id,'title':title,'category':category,'linkedAssetId':linkedAssetId,
    'issuedAt':issuedAt?.toIso8601String(),'expiresAt':expiresAt?.toIso8601String(),
    'notes':notes,'archived':archived,
    if(attachment!=null)'attachment':attachment!.toJson()};
  factory DocumentRecord.fromJson(Json j)=>DocumentRecord(id:asString(j['id']),
    title:asString(j['title']),category:asString(j['category'],'Other'),
    linkedAssetId:j['linkedAssetId'] as String?,
    issuedAt:j['issuedAt']==null?null:readDate(j['issuedAt']),
    expiresAt:j['expiresAt']==null?null:readDate(j['expiresAt']),
    notes:asString(j['notes']),archived:j['archived']==true,
    attachment:j['attachment'] is Map
      ? AttachmentRef.fromJson(Map<String,dynamic>.from(j['attachment'] as Map))
      : null);
  DocumentRecord copyWith({bool? archived,AttachmentRef? attachment,bool clearAttachment=false})=>
    DocumentRecord(id:id,title:title,category:category,
      linkedAssetId:linkedAssetId,issuedAt:issuedAt,expiresAt:expiresAt,notes:notes,
      archived:archived??this.archived,
      attachment:clearAttachment?null:(attachment??this.attachment));
}

/// Reference to an encrypted-at-rest file in the app's private documents
/// directory. The hash lets us verify integrity before decryption. When
/// [serverId] is non-null the same ciphertext has been uploaded to the
/// online backend under that id so other devices can pull it; the server
/// treats the bytes as opaque.
class AttachmentRef {
  final String originalFilename;
  final String mimeType;
  final String relativePath;
  final int sizeBytes;
  final String sha256Hex;
  final DateTime addedAt;
  final String? serverId;
  const AttachmentRef({required this.originalFilename,required this.mimeType,
    required this.relativePath,required this.sizeBytes,required this.sha256Hex,
    required this.addedAt,this.serverId});
  Json toJson()=>{'originalFilename':originalFilename,'mimeType':mimeType,
    'relativePath':relativePath,'sizeBytes':sizeBytes,'sha256Hex':sha256Hex,
    'addedAt':addedAt.toIso8601String(),
    if(serverId!=null)'serverId':serverId};
  factory AttachmentRef.fromJson(Json j)=>AttachmentRef(
    originalFilename:asString(j['originalFilename']),
    mimeType:asString(j['mimeType'],'application/octet-stream'),
    relativePath:asString(j['relativePath']),
    sizeBytes:asInt(j['sizeBytes']),
    sha256Hex:asString(j['sha256Hex']),
    addedAt:readDate(j['addedAt']),
    serverId:j['serverId'] as String?);
  AttachmentRef withServerId(String id)=>AttachmentRef(
    originalFilename:originalFilename,mimeType:mimeType,
    relativePath:relativePath,sizeBytes:sizeBytes,sha256Hex:sha256Hex,
    addedAt:addedAt,serverId:id);
}

/// A planning note, NOT a registered beneficiary nomination or legal instrument.
class BeneficiaryRecord {
  final String id;
  final String name;
  final String relationship;
  final int intendedShareBps;
  final String notes;
  const BeneficiaryRecord({required this.id,required this.name,required this.relationship,
    this.intendedShareBps=0,this.notes=''});
  Json toJson()=>{'id':id,'name':name,'relationship':relationship,
    'intendedShareBps':intendedShareBps,'notes':notes};
  factory BeneficiaryRecord.fromJson(Json j)=>BeneficiaryRecord(id:asString(j['id']),
    name:asString(j['name']),relationship:asString(j['relationship']),
    intendedShareBps:asInt(j['intendedShareBps']).clamp(0,10000).toInt(),
    notes:asString(j['notes']));
}

class ValuationRecord {
  final String id;
  final String assetId;
  final int fullValueUgx;
  final DateTime asOf;
  final String source;
  final String notes;
  const ValuationRecord({required this.id,required this.assetId,required this.fullValueUgx,
    required this.asOf,required this.source,this.notes=''});
  Json toJson()=>{'id':id,'assetId':assetId,'fullValueUgx':fullValueUgx,
    'asOf':asOf.toIso8601String(),'source':source,'notes':notes};
  factory ValuationRecord.fromJson(Json j)=>ValuationRecord(id:asString(j['id']),
    assetId:asString(j['assetId']),fullValueUgx:asInt(j['fullValueUgx']),
    asOf:readDate(j['asOf']),source:asString(j['source']),notes:asString(j['notes']));
}

class NotificationOptions {
  final bool upcomingReminders;
  final bool expiringDocuments;
  final bool staleValuations;
  const NotificationOptions({this.upcomingReminders=true,
    this.expiringDocuments=true,this.staleValuations=true});
  Json toJson()=>{'upcomingReminders':upcomingReminders,
    'expiringDocuments':expiringDocuments,'staleValuations':staleValuations};
  factory NotificationOptions.fromJson(Json j)=>NotificationOptions(
    upcomingReminders:j['upcomingReminders']!=false,
    expiringDocuments:j['expiringDocuments']!=false,
    staleValuations:j['staleValuations']!=false);
  NotificationOptions copyWith({bool? upcomingReminders,bool? expiringDocuments,
    bool? staleValuations})=>NotificationOptions(
      upcomingReminders:upcomingReminders??this.upcomingReminders,
      expiringDocuments:expiringDocuments??this.expiringDocuments,
      staleValuations:staleValuations??this.staleValuations);
}

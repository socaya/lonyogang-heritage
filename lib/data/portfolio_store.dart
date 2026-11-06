import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';
import '../domain/finance.dart';

/// Local, offline-first demonstration repository. SharedPreferences is NOT an
/// encrypted vault. Do not record genuine sensitive financial or identity data.
class PortfolioStore extends ChangeNotifier {
  static const storageKey='lonyogang_heritage_demo_v1';
  PortfolioState _state=const PortfolioState();
  PortfolioState get state=>_state;
  WealthTotals get totals=>computeTotals(_state.assets,_state.liabilities);
  String? loadError;
  bool isDemo=false;

  Future<void> load() async {
    try {
      final prefs=await SharedPreferences.getInstance();
      final raw=prefs.getString(storageKey);
      if(raw!=null) _state=PortfolioState.fromJson(jsonDecode(raw) as Json);
    } catch (e) {
      // Preserve corrupted data in preferences so that the user can recover it.
      loadError='Saved local data could not be loaded. Nothing was deleted.';
    }
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final prefs=await SharedPreferences.getInstance();
      final ok=await prefs.setString(storageKey,_state.encode());
      if (!ok) throw StateError('Storage write rejected');
    } catch (_) {
      loadError='The last change may not be saved. Storage is unavailable.';
      notifyListeners();
    }
  }

  Future<void> setOwner(String name) async {
    _state=PortfolioState(ownerName:name.trim(),onboardingDone:true,assets:_state.assets,
      liabilities:_state.liabilities,events:_state.events,goals:_state.goals,
      contacts:_state.contacts,reminders:_state.reminders);
    await _save();
  }

  Future<void> upsertAsset(WealthAsset asset) async {
    if(asset.name.trim().isEmpty||asset.valueUgx<0||asset.ownershipBps<0||asset.ownershipBps>10000) {
      throw ArgumentError('Invalid asset name, value or ownership share');
    }
    final list=[..._state.assets];
    final i=list.indexWhere((x)=>x.id==asset.id);
    if (i<0) {list.add(asset);} else {list[i]=asset;}
    _state=_replace(assets:list);await _save();
  }
  Future<void> archiveAsset(WealthAsset asset) async => upsertAsset(asset.copyWith(archived:true));
  Future<void> upsertLiability(Liability liability) async {
    if(liability.name.trim().isEmpty||liability.outstandingUgx<0)throw ArgumentError('Invalid debt');
    final list=[..._state.liabilities];final i=list.indexWhere((x)=>x.id==liability.id);
    if(i<0){list.add(liability);}else{list[i]=liability;}
    _state=_replace(liabilities:list);await _save();
  }
  Future<void> archiveLiability(Liability debt) async=>upsertLiability(debt.copyWith(archived:true));
  Future<void> postEvent(LedgerEvent event) async {
    if(event.amountUgx<0||event.description.trim().isEmpty) throw ArgumentError('Invalid transaction');
    if(_state.events.any((x)=>x.id==event.id))return; // duplicate submission
    if(event.kind==EventKind.reversal &&
        (!_state.events.any((x)=>x.id==event.reversalOf && x.kind!=EventKind.reversal)||
          _state.events.any((x)=>x.reversalOf==event.reversalOf))) {
      throw ArgumentError('Invalid or duplicate reversal');
    }
    _state=_replace(events:[..._state.events,event]);await _save();
  }
  Future<void> reverseEvent(LedgerEvent event) async => postEvent(LedgerEvent(
    id:makeId(),description:'Reversal: ${event.description}',kind:EventKind.reversal,
    amountUgx:event.amountUgx,occurredAt:DateTime.now(),assetId:event.assetId,reversalOf:event.id));
  Future<void> addGoal(WealthGoal goal) async {
    _state=_replace(goals:[..._state.goals,goal]);await _save();
  }
  Future<void> deleteGoal(String id) async {
    _state=_replace(goals:_state.goals.where((x)=>x.id!=id).toList());await _save();
  }
  Future<void> addContact(LegacyContact contact) async {
    _state=_replace(contacts:[..._state.contacts,contact]);await _save();
  }
  Future<void> removeContact(String id) async {
    _state=_replace(contacts:_state.contacts.where((x)=>x.id!=id).toList());await _save();
  }
  Future<void> addReminder(ReminderRecord reminder) async {
    _state=_replace(reminders:[..._state.reminders,reminder]);await _save();
  }
  Future<void> toggleReminder(String id) async {
    _state=_replace(reminders:_state.reminders.map((r)=>r.id==id?r.toggle():r).toList());await _save();
  }

  /// Portable JSON export is intentionally user-initiated and clearly warns
  /// that exported content is unencrypted. Never export passwords or tokens.
  String exportJson() => const JsonEncoder.withIndent('  ').convert(_state.toJson());
  Future<void> importJson(String raw) async {
    final parsed=PortfolioState.fromJson(jsonDecode(raw) as Json);
    // Validate all amounts before replacing the active portfolio.
    if(parsed.assets.any((x)=>x.valueUgx<0||x.ownershipBps<0||x.ownershipBps>10000)||
       parsed.liabilities.any((x)=>x.outstandingUgx<0)||
       parsed.events.any((x)=>x.amountUgx<0))throw const FormatException('Negative or invalid financial amount');
    _state=parsed;await _save();
  }

  /// Explicit test fixture only; never silently generate fabricated balances.
  Future<void> loadDemo() async {
    final now=DateTime.now();
    isDemo=true;
    _state=PortfolioState(ownerName:'Demo portfolio',onboardingDone:true,assets:[
      WealthAsset(id:'investment-unit-trust',name:'Unit Trust',kind:AssetKind.investment,category:'Unit trust',valueUgx:70000000,costUgx:65000000,valuedAt:now,status:RecordStatus.estimated),
      WealthAsset(id:'investment-securities',name:'Government Securities',kind:AssetKind.investment,category:'Treasury bonds',valueUgx:35000000,valuedAt:now),
      WealthAsset(id:'savings-bank',name:'Bank and NSSF Savings',kind:AssetKind.savings,valueUgx:45000000,valuedAt:now),
      WealthAsset(id:'property-rental',name:'Rental Property',kind:AssetKind.property,location:'Uganda',valueUgx:300000000,ownershipBps:8000,valuedAt:now,status:RecordStatus.estimated),
    ],liabilities:[Liability(id:'mortgage',name:'Property Mortgage',outstandingUgx:60000000,asOf:now,propertyId:'property-rental'),
      Liability(id:'sacco-loan',name:'SACCO Loan',outstandingUgx:10000000,asOf:now)]);
    await _save();
  }

  PortfolioState _replace({List<WealthAsset>? assets,List<Liability>? liabilities,List<LedgerEvent>? events,
    List<WealthGoal>? goals,List<LegacyContact>? contacts,List<ReminderRecord>? reminders})=>PortfolioState(
      ownerName:_state.ownerName,onboardingDone:_state.onboardingDone,assets:assets??_state.assets,
      liabilities:liabilities??_state.liabilities,events:events??_state.events,goals:goals??_state.goals,
      contacts:contacts??_state.contacts,reminders:reminders??_state.reminders);
}

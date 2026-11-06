import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/domain/models.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));

  test('Document index supports metadata CRUD, expiry guard and restore',()async{
    final store=PortfolioStore();await store.load();
    final doc=DocumentRecord(id:'doc1',title:'Insurance',category:'Insurance',
      issuedAt:DateTime(2026,1,1),expiresAt:DateTime(2027,1,1));
    await store.upsertDocument(doc);
    expect(store.state.documents.single.title,'Insurance');
    await store.archiveDocument(doc);
    expect(store.state.documents.single.archived,isTrue);
    await store.restoreDocument(store.state.documents.single);
    final reloaded=PortfolioStore();await reloaded.load();
    expect(reloaded.state.documents.single.archived,isFalse);
    await expectLater(store.upsertDocument(DocumentRecord(id:'bad',
      title:'Invalid',category:'Other',issuedAt:DateTime(2027),expiresAt:DateTime(2026))),
      throwsArgumentError);
  });

  test('Beneficiary intentions are separate and never exceed 100%',()async{
    final store=PortfolioStore();await store.load();
    await store.upsertBeneficiary(const BeneficiaryRecord(id:'b1',name:'Person A',
      relationship:'Child',intendedShareBps:6000));
    await store.upsertBeneficiary(const BeneficiaryRecord(id:'b2',name:'Person B',
      relationship:'Sibling',intendedShareBps:4000));
    expect(store.state.beneficiaries.length,2);
    await expectLater(store.upsertBeneficiary(const BeneficiaryRecord(id:'b3',
      name:'Person C',relationship:'Parent',intendedShareBps:1)),throwsArgumentError);
    expect(store.state.beneficiaries.length,2);
    final reloaded=PortfolioStore();await reloaded.load();
    expect(reloaded.state.beneficiaries[0].name,'Person A');
    await store.deleteBeneficiary('b2');
    expect(store.state.beneficiaries.length,1);
  });

  test('Valuation changes update owner share and leave historical evidence',()async{
    final store=PortfolioStore();await store.load();
    final asset=WealthAsset(id:'house1',name:'Rental house',kind:AssetKind.property,
      valueUgx:200000000,ownershipBps:7500,valuedAt:DateTime(2026,11,1,10));
    await store.upsertAsset(asset);
    expect(store.totals.property,150000000);
    expect(store.state.valuations.length,1);
    // Same-day midnight value from date picker must be valid.
    await store.recordValuation('house1',220000000,DateTime(2026,11,1),
      'Independent appraisal',notes:'Demo only');
    expect(store.totals.property,165000000);
    expect(store.state.valuations.length,2);
    expect(store.state.valuations.last.source,'Independent appraisal');
    await expectLater(store.recordValuation('house1',230000000,
      DateTime(2026,10,31),'Outdated appraisal'),throwsArgumentError);
    expect(store.totals.property,165000000);
    final reloaded=PortfolioStore();await reloaded.load();
    expect(reloaded.state.valuations.length,2);
    expect(reloaded.state.assets.single.valueUgx,220000000);
  });

  test('Alert settings persist and owner name update does not erase new records',()async{
    final store=PortfolioStore();await store.load();
    await store.upsertDocument(const DocumentRecord(id:'doc',title:'Record',category:'Other'));
    await store.updateNotificationOptions(const NotificationOptions(
      upcomingReminders:false,staleValuations:false));
    await store.setOwner('Owner B');
    final fresh=PortfolioStore();await fresh.load();
    expect(fresh.state.documents.single.title,'Record');
    expect(fresh.state.notificationOptions.upcomingReminders,isFalse);
    expect(fresh.state.notificationOptions.staleValuations,isFalse);
    expect(fresh.state.notificationOptions.expiringDocuments,isTrue);
    expect(fresh.state.ownerName,'Owner B');
  });

  test('Legacy schema-1 exports without new fields remain importable',()async{
    final store=PortfolioStore();await store.load();
    await store.importJson('{"schemaVersion":1,"ownerName":"Legacy","onboardingDone":true}');
    expect(store.state.documents,isEmpty);
    expect(store.state.beneficiaries,isEmpty);
    expect(store.state.valuations,isEmpty);
    expect(store.state.notificationOptions.upcomingReminders,isTrue);
  });
}

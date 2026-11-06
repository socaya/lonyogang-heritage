import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/domain/finance.dart';
import 'package:lonyogang_heritage/domain/models.dart';

void main(){
  final date=DateTime(2026,11,1);
  test('SRS golden fixture: 390m assets and 70m debts => 320m net worth',(){
    final a=[
      WealthAsset(id:'i1',name:'Unit Trust',kind:AssetKind.investment,valueUgx:70000000,valuedAt:date),
      WealthAsset(id:'s1',name:'Bank/NSSF',kind:AssetKind.savings,valueUgx:45000000,valuedAt:date),
      WealthAsset(id:'i2',name:'Govt bonds',kind:AssetKind.investment,valueUgx:35000000,valuedAt:date),
      WealthAsset(id:'p1',name:'Rental',kind:AssetKind.property,valueUgx:300000000,ownershipBps:8000,valuedAt:date),
    ];
    final d=[Liability(id:'mortgage',name:'Mortgage',outstandingUgx:60000000,propertyId:'p1',asOf:date),
      Liability(id:'sacco',name:'SACCO',outstandingUgx:10000000,asOf:date)];
    final totals=computeTotals(a,d);
    expect(totals.grossAssets,390000000);
    expect(totals.liabilities,70000000);
    expect(totals.netWorth,320000000);
    expect(propertyEquity(a.last,d),180000000);
  });
  test('archived assets and liabilities are not included',(){
    final assets=[WealthAsset(id:'a',name:'Archived',kind:AssetKind.savings,valueUgx:100,valuedAt:date,archived:true)];
    final debts=[Liability(id:'d',name:'Archived debt',outstandingUgx:20,asOf:date,archived:true)];
    expect(computeTotals(assets,debts).netWorth,0);
  });
  test('reversal cancels original income; transfers are not deposits',(){
    final event=LedgerEvent(id:'one',description:'Dividend',kind:EventKind.dividend,amountUgx:3000,occurredAt:date);
    final reverse=LedgerEvent(id:'two',description:'Reversal',kind:EventKind.reversal,amountUgx:3000,occurredAt:date,reversalOf:'one');
    final transfer=LedgerEvent(id:'three',description:'Between own accounts',kind:EventKind.transfer,amountUgx:20000,occurredAt:date);
    expect(realizedIncome([event,reverse,transfer]),0);
    expect(externalContributions([transfer]),0);
  });
  test('round-trips all persisted portfolio records',(){
    final asset=WealthAsset(id:'x',name:'House',kind:AssetKind.property,valueUgx:10000,ownershipBps:5000,valuedAt:date);
    final p=PortfolioState(ownerName:'Test',onboardingDone:true,assets:[asset],
      contacts:[const LegacyContact(id:'c',name:'Contact',relationship:'Sibling')],
      goals:[const WealthGoal(id:'g',name:'School',targetUgx:10000)],
      reminders:[ReminderRecord(id:'r',title:'Pay rates',dueAt:date)]);
    final restored=PortfolioState.fromJson(p.toJson());
    expect(restored.ownerName,'Test');
    expect(restored.assets.single.attributableUgx,5000);
    expect(restored.contacts.single.relationship,'Sibling');
    expect(restored.reminders.single.title,'Pay rates');
  });
}

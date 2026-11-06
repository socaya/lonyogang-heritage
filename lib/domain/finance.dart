import 'models.dart';

/// Financial aggregation is intentionally simple and verifiable. It never
/// presents invented performance returns or treats an estimate as a cash gain.
class WealthTotals {
  final int investments;
  final int property;
  final int savings;
  final int other;
  final int liabilities;
  const WealthTotals({required this.investments,required this.property,required this.savings,
    required this.other,required this.liabilities});
  int get grossAssets => investments + property + savings + other;
  int get netWorth => grossAssets - liabilities;
}

WealthTotals computeTotals(Iterable<WealthAsset> allAssets, Iterable<Liability> allDebts) {
  var investments=0,property=0,savings=0,other=0;
  for (final asset in allAssets) {
    if (asset.archived) continue;
    final v=asset.attributableUgx;
    switch (asset.kind) {
      case AssetKind.investment: investments+=v;
      case AssetKind.property: property+=v;
      case AssetKind.savings: savings+=v;
      case AssetKind.other: other+=v;
    }
  }
  final debts=allDebts.where((x)=>!x.archived).fold<int>(0,(a,x)=>a+x.outstandingUgx);
  return WealthTotals(investments:investments,property:property,savings:savings,other:other,liabilities:debts);
}

/// Property equity is a *display subtotal* only. Never pass this subtotal into
/// computeTotals: linked mortgages are already included in allDebts.
int propertyEquity(WealthAsset property,Iterable<Liability> liabilities) {
  final debt=liabilities.where((x)=>!x.archived && x.propertyId==property.id)
      .fold<int>(0,(a,x)=>a+x.outstandingUgx);
  return property.attributableUgx - debt;
}

bool eventIsReversed(LedgerEvent event,Iterable<LedgerEvent> ledger)=>
    ledger.any((x)=>x.kind==EventKind.reversal && x.reversalOf==event.id);

int realizedIncome(Iterable<LedgerEvent> all) {
  final list=all.toList();
  return list.where((x)=>!eventIsReversed(x,list) && x.kind!=EventKind.reversal)
      .fold<int>(0,(sum,x)=>sum + switch(x.kind){
        EventKind.dividend || EventKind.interest || EventKind.rent=>x.amountUgx,
        EventKind.fee || EventKind.tax || EventKind.expense=>-x.amountUgx,
        _=>0,
      });
}

int externalContributions(Iterable<LedgerEvent> all) {
  final list=all.toList();
  return list.where((x)=>!eventIsReversed(x,list) && x.kind!=EventKind.reversal)
      .fold<int>(0,(sum,x)=>sum+switch(x.kind){
        EventKind.contribution=>x.amountUgx,
        EventKind.withdrawal=>-x.amountUgx,
        _=>0,
      });
}

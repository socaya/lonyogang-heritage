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

/// A single measurement point for TWR: the portfolio value and any external
/// cashflow in or out at that date. Positive flow is a contribution, negative
/// is a withdrawal.
class ValuedCashflow {
  final DateTime at;
  final int valueUgx;
  final int externalFlowUgx;
  const ValuedCashflow({required this.at,required this.valueUgx,
    this.externalFlowUgx=0});
}

/// Chain-linked time-weighted return. Each sub-period growth factor is
/// (end − flow) / start, where flow is the external cashflow recorded at the
/// end of the sub-period, following the end-of-period flow convention. The
/// factors are multiplied and the result is annualized over the series span.
///
/// Returns null if the series is too short, starts with zero, or any
/// sub-period degenerates — the preview never fabricates a return.
double? timeWeightedReturn(List<ValuedCashflow> series) {
  if (series.length < 2) return null;
  final ordered=[...series]..sort((a,b)=>a.at.compareTo(b.at));
  var chain=1.0;
  for (var i=1;i<ordered.length;i++){
    final start=ordered[i-1].valueUgx;
    final end=ordered[i].valueUgx;
    final flow=ordered[i].externalFlowUgx;
    if (start<=0) return null;
    final growth=(end-flow)/start;
    if (growth<=0 || growth.isInfinite || growth.isNaN) return null;
    chain *= growth;
  }
  final years=ordered.last.at.difference(ordered.first.at).inDays/365.25;
  if (years<=0) return chain-1;
  return _safePow(chain,1.0/years)-1;
}

double _safePow(double base,double exponent){
  if (base<=0) return double.nan;
  return _exp(exponent*_ln(base));
}

double _exp(double x) {
  // Range-reduce by halving to [-1, 1] so the series converges quickly, then
  // square the result back. Avoids pulling in dart:math::exp.
  if (x.isNaN) return double.nan;
  var halvings=0;
  while (x.abs()>1){x/=2;halvings++;}
  var term=1.0, sum=1.0;
  for (var k=1;k<80;k++){
    term*=x/k;
    sum+=term;
    if (term.abs()<1e-17) break;
  }
  for (var i=0;i<halvings;i++){sum*=sum;}
  return sum;
}

double _ln(double x) {
  if (x<=0) return double.nan;
  // ln(x) via two steps: rescale to near 1, then atanh series.
  var scale=0.0;
  while (x>1.1){x/=2;scale+=0.6931471805599453;}
  while (x<0.9){x*=2;scale-=0.6931471805599453;}
  final y=(x-1)/(x+1);
  var term=y;final y2=y*y;var sum=y;
  for (var k=1;k<80;k++){
    term*=y2;sum+=term/(2*k+1);
    if ((term/(2*k+1)).abs()<1e-17) break;
  }
  return scale+2*sum;
}

class XirrCashflow {
  final DateTime at;
  final double amount;
  const XirrCashflow(this.at,this.amount);
}

/// Internal rate of return for a dated series of cashflows. Negative values
/// represent money paid in (contributions), positive values represent money
/// returned (withdrawals, including the final valuation). Returns null when
/// the series has no sign change or Newton–Raphson fails to converge.
double? xirr(List<XirrCashflow> cashflows,{double guess=0.1,int maxIter=80,
    double tolerance=1e-7}) {
  if (cashflows.length<2) return null;
  final hasPositive=cashflows.any((c)=>c.amount>0);
  final hasNegative=cashflows.any((c)=>c.amount<0);
  if (!hasPositive||!hasNegative) return null;
  final ordered=[...cashflows]..sort((a,b)=>a.at.compareTo(b.at));
  final first=ordered.first.at;
  double rate=guess;
  for (var i=0;i<maxIter;i++){
    var npv=0.0, dnpv=0.0;
    for (final c in ordered){
      final years=c.at.difference(first).inDays/365.25;
      final factor=_safePow(1+rate,years);
      if (factor.isNaN||factor.isInfinite||factor==0) return null;
      npv+=c.amount/factor;
      dnpv+=-years*c.amount/(factor*(1+rate));
    }
    if (dnpv==0) return null;
    final next=rate-npv/dnpv;
    if ((next-rate).abs()<tolerance) return next;
    if (next.isNaN||next.isInfinite) return null;
    rate=next;
  }
  return null;
}

/// Converts an amount in [currency] to UGX using the freshest FxRate that is
/// not newer than [asOf]. Returns null when no usable rate exists so callers
/// can degrade gracefully instead of silently inventing a value.
int? convertToUgx(int foreignAmount,String currency,DateTime asOf,
    Iterable<FxRate> rates){
  if (currency.toUpperCase()=='UGX') return foreignAmount;
  final eligible=rates
    .where((r)=>r.currency==currency.toUpperCase() && !r.asOf.isAfter(asOf))
    .toList()..sort((a,b)=>b.asOf.compareTo(a.asOf));
  if (eligible.isEmpty) return null;
  return foreignAmount*eligible.first.ugxPerUnit;
}

/// A per-asset drift between recorded weight and the user's target weight.
/// drifts and targets are expressed in basis points (10000 = 100%).
class AllocationDrift {
  final String assetId;
  final String name;
  final int targetBps;
  final int actualBps;
  const AllocationDrift({required this.assetId,required this.name,
    required this.targetBps,required this.actualBps});
  int get driftBps => actualBps-targetBps;
}

List<AllocationDrift> allocationDrift(Iterable<WealthAsset> assets,
    Map<String,int> targetsBps){
  final active=assets.where((a)=>!a.archived).toList();
  final total=active.fold<int>(0,(n,a)=>n+a.attributableUgx);
  final out=<AllocationDrift>[];
  for (final a in active){
    final target=targetsBps[a.id]??0;
    final actual=total==0?0:((a.attributableUgx*10000)~/total);
    if (target==0 && actual==0) continue;
    out.add(AllocationDrift(assetId:a.id,name:a.name,
      targetBps:target,actualBps:actual));
  }
  return out;
}

/// Scheduled contributions whose next-fire date has passed. These are shown
/// as pending postings and can also be fed into local notifications.
List<ScheduledContribution> dueSchedules(Iterable<ScheduledContribution> all,
    DateTime now)=>all
  .where((s)=>s.active && !s.nextFire.isAfter(now))
  .toList()..sort((a,b)=>a.nextFire.compareTo(b.nextFire));

/// Portfolio-level return measurements. Each is null when we lack the data.
class ReturnMetrics {
  final double? twr;
  final double? xirr;
  final int sampleCount;
  const ReturnMetrics({this.twr, this.xirr, this.sampleCount = 0});
  bool get hasAny => twr != null || xirr != null;
}

/// Derives TWR and XIRR for a single asset using its stored valuations as
/// dated balance observations and its linked ledger events as cashflows.
/// Reversals and transfers are excluded. Returns null-valued metrics when
/// there are too few observations for an honest measurement.
ReturnMetrics assetReturns(WealthAsset asset, Iterable<ValuationRecord> valuations,
    Iterable<LedgerEvent> events, DateTime now) {
  final history = valuations.where((v) => v.assetId == asset.id).toList()
    ..sort((a, b) => a.asOf.compareTo(b.asOf));
  if (history.length < 2) {
    return const ReturnMetrics();
  }

  final related = events
      .where((e) => e.assetId == asset.id && e.kind != EventKind.reversal
          && !eventIsReversed(e, events))
      .toList()
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

  int flowBetween(DateTime start, DateTime end) {
    return related.where((e) => e.occurredAt.isAfter(start) && !e.occurredAt.isAfter(end))
        .fold<int>(0, (s, e) => s + switch (e.kind) {
              EventKind.contribution => e.amountUgx,
              EventKind.withdrawal => -e.amountUgx,
              _ => 0,
            });
  }

  final series = <ValuedCashflow>[];
  for (var i = 0; i < history.length; i++) {
    final flow = i == 0 ? 0 : flowBetween(history[i - 1].asOf, history[i].asOf);
    series.add(ValuedCashflow(
        at: history[i].asOf, valueUgx: history[i].fullValueUgx,
        externalFlowUgx: flow));
  }
  final twr = timeWeightedReturn(series);

  final cashflows = <XirrCashflow>[];
  for (final e in related) {
    switch (e.kind) {
      case EventKind.contribution:
        cashflows.add(XirrCashflow(e.occurredAt, -e.amountUgx.toDouble()));
      case EventKind.withdrawal:
      case EventKind.dividend:
      case EventKind.interest:
      case EventKind.rent:
        cashflows.add(XirrCashflow(e.occurredAt, e.amountUgx.toDouble()));
      case EventKind.fee:
      case EventKind.tax:
      case EventKind.expense:
        cashflows.add(XirrCashflow(e.occurredAt, -e.amountUgx.toDouble()));
      case EventKind.transfer:
      case EventKind.adjustment:
      case EventKind.reversal:
        // Transfers and bookkeeping entries are excluded from XIRR.
        break;
    }
  }
  cashflows.add(XirrCashflow(now, asset.valueUgx.toDouble()));
  final rate = xirr(cashflows);

  return ReturnMetrics(twr: twr, xirr: rate, sampleCount: history.length);
}

/// A dated net-worth observation synthesized from the available history.
/// Each snapshot uses the freshest recorded valuation for every asset not
/// yet archived at [at] and the current outstanding of every liability not
/// yet archived — liabilities carry no dated history in the current schema,
/// so historical snapshots inherit today's debt.
class WealthSnapshot {
  final DateTime at;
  final int grossAssetsUgx;
  final int liabilitiesUgx;
  const WealthSnapshot(
      {required this.at,
      required this.grossAssetsUgx,
      required this.liabilitiesUgx});
  int get netWorthUgx => grossAssetsUgx - liabilitiesUgx;
}

/// Derives a portfolio-level snapshot series from the current assets,
/// liabilities and valuation history. Returns at most [maxPoints] evenly
/// sampled points so the sparkline stays legible. Returns an empty list if
/// fewer than two distinct snapshot dates are available.
List<WealthSnapshot> wealthHistory(
  Iterable<WealthAsset> assets,
  Iterable<Liability> liabilities,
  Iterable<ValuationRecord> valuations, {
  int maxPoints = 24,
}) {
  final activeAssets = assets.where((a) => !a.archived).toList();
  final activeDebts = liabilities.where((l) => !l.archived).toList();
  if (activeAssets.isEmpty) return const [];

  final allValuations = valuations.toList()
    ..sort((a, b) => a.asOf.compareTo(b.asOf));

  // Build the set of relevant dates: every valuation asOf plus each asset's
  // own valuedAt (its latest known value). We dedupe on day resolution.
  final rawDates = <DateTime>{};
  for (final v in allValuations) {
    rawDates.add(DateTime(v.asOf.year, v.asOf.month, v.asOf.day));
  }
  for (final a in activeAssets) {
    rawDates
        .add(DateTime(a.valuedAt.year, a.valuedAt.month, a.valuedAt.day));
  }
  if (rawDates.length < 2) return const [];

  final sortedDates = rawDates.toList()..sort();
  final debtTotal = activeDebts.fold<int>(0, (s, l) => s + l.outstandingUgx);

  int valueAt(WealthAsset asset, DateTime date) {
    final history = allValuations
        .where((v) => v.assetId == asset.id && !v.asOf.isAfter(date))
        .toList();
    final lastObservedAt = history.isNotEmpty ? history.last.asOf : null;
    // Use the asset's current value when its own valuedAt is the most
    // recent observation on or before [date] — otherwise fall back to the
    // freshest valuation record.
    final useCurrent = !asset.valuedAt.isAfter(date) &&
        (lastObservedAt == null || !asset.valuedAt.isBefore(lastObservedAt));
    final int fullValue;
    if (useCurrent) {
      fullValue = asset.valueUgx;
    } else if (history.isNotEmpty) {
      fullValue = history.last.fullValueUgx;
    } else {
      fullValue = 0;
    }
    return (fullValue * asset.ownershipBps) ~/ 10000;
  }

  final rawSnapshots = sortedDates.map((d) {
    final gross =
        activeAssets.fold<int>(0, (s, a) => s + valueAt(a, d));
    return WealthSnapshot(
        at: d, grossAssetsUgx: gross, liabilitiesUgx: debtTotal);
  }).toList();

  if (rawSnapshots.length <= maxPoints) return rawSnapshots;

  // Downsample by picking evenly spaced indices while preserving first + last.
  final step = (rawSnapshots.length - 1) / (maxPoints - 1);
  return List<WealthSnapshot>.generate(
      maxPoints, (i) => rawSnapshots[(i * step).round().clamp(0, rawSnapshots.length - 1)]);
}

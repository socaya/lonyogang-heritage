import 'package:flutter/material.dart';
import '../core/design.dart';
import '../domain/models.dart';

/// Shared page grid: compact 16, standard 20, wide 24 logical pixels.
double pageGutter(double width) => width < 360 ? 16 : width < 430 ? 20 : 24;
EdgeInsets pageInsets(double width,{double top=20,double bottom=32,double maxWidth=840}) {
  final gutter=pageGutter(width);
  final horizontal=width>maxWidth? (width-maxWidth)/2+gutter:gutter;
  return EdgeInsets.fromLTRB(horizontal,top,horizontal,bottom);
}
bool stackedLayout(BuildContext context,double width) =>
    width < 300 || MediaQuery.textScalerOf(context).scale(15)>19.5;

class BrandMark extends StatelessWidget {
  final double height;
  const BrandMark({super.key,this.height=38});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'LonyoGang Heritage',
        image: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: height * 4),
          child: DecoratedBox(decoration: BoxDecoration(color:LG.isDark(context)?LG.ivory:Colors.transparent,borderRadius:BorderRadius.circular(4)),child: Image.asset(
            'assets/brand/theme1-primary.png',
            height: height,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          )),
        ),
      );
}

class PageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageHeading(this.title,{super.key,this.subtitle,this.trailing});
  @override Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.only(bottom:24),
    child:LayoutBuilder(builder:(context,c){
      final heading=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Semantics(header:true,child:Text(title,style:Theme.of(context).textTheme.headlineMedium)),
        if(subtitle!=null)...[const SizedBox(height:8),Text(subtitle!,style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:LG.adaptive(context,LG.muted)))],
      ]);
      if(trailing==null)return heading;
      if(stackedLayout(context,c.maxWidth))return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[heading,const SizedBox(height:12),trailing!]);
      return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:heading),const SizedBox(width:12),Flexible(child:trailing!)]);
    }),
  );
}

class SoftCard extends StatelessWidget {
  final Widget child;final EdgeInsets padding;final Color color;final VoidCallback? onTap;
  const SoftCard({super.key,required this.child,this.padding=const EdgeInsets.all(18),this.color=LG.white,this.onTap});
  @override Widget build(BuildContext context)=>Material(color:LG.surface(context,color),borderRadius:BorderRadius.circular(LG.r),
    child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(LG.r),
      child:Padding(padding:padding,child:child)));
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionTitle(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14, top: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                  color: LG.adaptive(context,LG.gold), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium)),
            if (action != null) Flexible(child:action!)
          ],
        ),
      );
}

class InfoLabel extends StatelessWidget {
  final String label,value;
  final Color? valueColor;
  const InfoLabel({super.key,required this.label,required this.value,this.valueColor});
  @override Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:10),
    child:LayoutBuilder(builder:(context,c){
      final name=Text(label,style:TextStyle(color:LG.adaptive(context,LG.muted),fontSize:14,height:1.3));
      final detail=Text(value,style:TextStyle(color:LG.adaptive(context,valueColor??LG.navy),fontWeight:FontWeight.w600,fontSize:14,fontFamily:LG.uiFont,fontFeatures:LG.financialFeatures),textAlign:stackedLayout(context,c.maxWidth)?TextAlign.start:TextAlign.end);
      if(stackedLayout(context,c.maxWidth))return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[name,const SizedBox(height:4),detail]);
      return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:name),const SizedBox(width:12),Expanded(child:detail)]);
    }),
  );
}

/// Pill-shaped filter chip used across the portfolio / transactions /
/// expenses surfaces. Selected state is navy + white; unselected is
/// white with a hairline border and navy text. Shared here so every
/// filter row has the same geometry.
class LGFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const LGFilterChip({super.key,required this.label,required this.selected,required this.onTap});
  @override Widget build(BuildContext context)=>Semantics(
    selected:selected,button:true,
    child:Material(color:Colors.transparent,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(8),
      child:AnimatedContainer(duration:MediaQuery.disableAnimationsOf(context)?Duration.zero:const Duration(milliseconds:160),
        constraints:const BoxConstraints(minHeight:48,minWidth:48),
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:12),
        decoration:BoxDecoration(color:LG.adaptive(context,selected?LG.goldSoft:LG.white),borderRadius:BorderRadius.circular(8),border:Border.all(color:LG.adaptive(context,selected?LG.gold:LG.line),width:1.2)),
        child:Text(label,style:TextStyle(color:LG.adaptive(context,LG.navy),fontSize:13,fontWeight:FontWeight.w600)),
      ),
    )),
  );
}

class Pill extends StatelessWidget {
  final String label;final Color color;
  const Pill(this.label,{super.key,this.color=LG.sageSoft});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
    decoration:BoxDecoration(color:LG.surface(context,color),borderRadius:BorderRadius.circular(22)),child:Text(label,
      style:TextStyle(color:LG.adaptive(context,LG.sage),fontWeight:FontWeight.w700,fontSize:11)));
}

IconData assetIcon(AssetKind kind)=>switch(kind){
  AssetKind.investment=>Icons.stacked_line_chart_rounded,
  AssetKind.property=>Icons.home_outlined,
  AssetKind.savings=>Icons.savings_outlined,
  AssetKind.other=>Icons.inventory_2_outlined,
};
String assetTitle(AssetKind kind)=>switch(kind){
  AssetKind.investment=>'Investments',AssetKind.property=>'Properties',
  AssetKind.savings=>'Savings',AssetKind.other=>'Other assets',
};

class AssetTile extends StatelessWidget {
  final WealthAsset asset;final VoidCallback onTap;
  const AssetTile({super.key,required this.asset,required this.onTap});
  bool get _isStale => DateTime.now().difference(asset.valuedAt).inDays > 365;
  String get _semanticLabel {
    final parts=<String>[
      asset.name,
      assetTitle(asset.kind),
      'Attributable value ${LG.money(asset.attributableUgx)}',
      'Valued ${LG.date(asset.valuedAt)}',
      if(asset.ownershipBps<10000)'${(asset.ownershipBps/100).toStringAsFixed(0)} percent ownership',
      if(_isStale)'Valuation is stale',
    ];
    return parts.join('. ');
  }
  bool get _hasInterest =>
      asset.interestFrequency != InterestFrequency.none &&
      asset.interestRateBps > 0;
  String get _interestLabel {
    if (!_hasInterest) return '';
    final rate = (asset.interestRateBps / 100).toStringAsFixed(2);
    final freq = switch (asset.interestFrequency) {
      InterestFrequency.daily => '/day',
      InterestFrequency.weekly => '/week',
      InterestFrequency.monthly => '/mo',
      InterestFrequency.quarterly => '/qtr',
      InterestFrequency.semiAnnual => '/half',
      InterestFrequency.annual => '/yr',
      InterestFrequency.none => '',
    };
    return '$rate%$freq';
  }

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: _semanticLabel,
        child: SoftCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(children: [
            Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: LG.adaptive(context,LG.sageSoft),
                    borderRadius: BorderRadius.circular(13)),
                child: Icon(assetIcon(asset.kind),
                    color: LG.adaptive(context,LG.sage), size: 23)),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Flexible(
                        child: Text(asset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.1))),
                    if (_isStale) ...[
                      const SizedBox(width: 6),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFBF3DD),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('Stale',
                              style: TextStyle(
                                  color: Color(0xFF8C6A1D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700))),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      '${asset.category.isNotEmpty ? asset.category : assetTitle(asset.kind)} · ${LG.date(asset.valuedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12.5, color: LG.adaptive(context,LG.muted))),
                  if (_hasInterest) ...[
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: LG.adaptive(context,LG.goldSoft),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.percent_rounded,
                            size: 10.5, color: LG.adaptive(context,LG.gold)),
                        const SizedBox(width: 4),
                        Text(_interestLabel,
                            style: TextStyle(
                                color: LG.adaptive(context,LG.navy),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                ])),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(LG.money(asset.attributableUgx, compact: true),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      letterSpacing: -.2)),
              if (asset.ownershipBps < 10000)
                Text('${(asset.ownershipBps / 100).toStringAsFixed(0)}% owned',
                    style: TextStyle(fontSize: 10.5, color: LG.adaptive(context,LG.sage))),
            ]),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: LG.adaptive(context,LG.muted)),
          ]),
        ),
      );
}

class WealthBreakdown extends StatelessWidget {
  final Map<String,int> values;
  const WealthBreakdown({super.key,required this.values});
  @override
  Widget build(BuildContext context) {
    final colors = [LG.adaptive(context,LG.gold), LG.adaptive(context,LG.sage), LG.adaptive(context,LG.navy), const Color(0xFF487A94)];
    final total = values.values.fold<int>(0, (a, b) => a + b);
    final entries = values.entries.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (total > 0 && entries.every((e) => e.value >= 0))
        Semantics(
          label: 'Asset allocation. Exact amounts and percentages below.',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(children: [
              for (var i = 0; i < entries.length; i++)
                if (entries[i].value > 0)
                  Expanded(flex: (entries[i].value / total * 10000).round().clamp(1, 10000).toInt(),
                    child: Container(height: 10, color: colors[i % colors.length])),
            ]),
          ),
        )
      else
        Text('Allocation chart unavailable', style: TextStyle(color: LG.adaptive(context,LG.muted))),
      const SizedBox(height: 16),
      for (var i = 0; i < entries.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 9, height: 9, margin: const EdgeInsets.only(top: 5), color: colors[i % colors.length]),
            const SizedBox(width: 9),
            Expanded(child: Text(entries[i].key, style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 13))),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(LG.money(entries[i].value), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              if (total > 0 && entries.every((e) => e.value >= 0))
                Text('${(entries[i].value / total * 100).toStringAsFixed(1)}%', style: TextStyle(color: LG.adaptive(context,LG.muted), fontSize: 12)),
            ])),
          ]),
        ),
    ]);
  }
}

class EmptySection extends StatelessWidget {
  final String title;final String detail;final IconData icon;final VoidCallback? onAdd;
  const EmptySection({super.key,required this.title,required this.detail,this.icon=Icons.layers_outlined,this.onAdd});
  @override Widget build(BuildContext context)=>SoftCard(child:Padding(padding:const EdgeInsets.symmetric(vertical:20),child:
    Column(children:[Icon(icon,size:34,color:LG.adaptive(context,LG.sage)),const SizedBox(height:12),Text(title,
      style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:6),Text(detail,
      textAlign:TextAlign.center,style:TextStyle(color:LG.adaptive(context,LG.muted),height:1.4)),
      if(onAdd!=null)...[const SizedBox(height:16),TextButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('Add entry'))]
    ])));
}

class FormFieldBlock extends StatelessWidget {
  final String title;
  final Widget child;
  final String? help;
  final bool required;
  const FormFieldBlock({
    super.key,
    required this.title,
    required this.child,
    this.help,
    this.required = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child:Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: LG.adaptive(context,LG.navy),
                        letterSpacing: -.1))),
                if (required) ...[
                  const SizedBox(width: 6),
                  Text('*',
                      style: TextStyle(
                          color: LG.adaptive(context,LG.gold),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            child,
            if (help != null) ...[
              const SizedBox(height: 8),
              Text(help!,
                  style: TextStyle(
                      fontSize: 13, color: LG.adaptive(context,LG.muted), height: 1.4)),
            ],
          ],
        ),
      );
}

class PrivacyBanner extends StatelessWidget {
  const PrivacyBanner({super.key});
  @override Widget build(BuildContext context)=>SoftCard(color:LG.adaptive(context,LG.sageSoft),child:Row(children:[
    Icon(Icons.shield_outlined,color:LG.adaptive(context,LG.sage),size:27),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Local alpha mode',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),SizedBox(height:3),
      Text('Optional AES-GCM encryption on this device. No cloud sync. Keep an unencrypted JSON export as your backup.',
        style:TextStyle(fontSize:11,height:1.45,color:LG.adaptive(context,LG.muted)))
    ]))]));
}

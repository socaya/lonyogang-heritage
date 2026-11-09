import 'package:flutter/material.dart';
import '../core/design.dart';
import '../domain/models.dart';

class BrandMark extends StatelessWidget {
  final double height;
  const BrandMark({super.key,this.height=38});
  @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[
    Image.asset('assets/brand/theme1-granary.png',height:height,width:height,fit:BoxFit.contain,
      errorBuilder:(_,__,___)=>Icon(Icons.home_work_outlined,color:LG.gold,size:height)),
    const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
      RichText(text:TextSpan(children:[const TextSpan(text:'LONYO',style:TextStyle(color:LG.navy)),
        const TextSpan(text:'GANG',style:TextStyle(color:LG.gold))],
        style:TextStyle(fontSize:height*.46,fontFamily:'Roboto',fontWeight:FontWeight.w900,letterSpacing:-1.1))),
      Align(alignment:Alignment.centerRight,child:Text('H E R I T A G E',
        style:TextStyle(fontSize:height*.17,color:LG.navy,fontWeight:FontWeight.w800,letterSpacing:1.1))),
    ]),
  ]);
}

class PageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageHeading(this.title, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 10),
                    Text(subtitle!,
                        style: const TextStyle(
                            color: LG.muted, fontSize: 15, height: 1.5)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!
          ],
        ),
      );
}

class SoftCard extends StatelessWidget {
  final Widget child;final EdgeInsets padding;final Color color;final VoidCallback? onTap;
  const SoftCard({super.key,required this.child,this.padding=const EdgeInsets.all(18),this.color=LG.white,this.onTap});
  @override Widget build(BuildContext context)=>Material(color:color,borderRadius:BorderRadius.circular(LG.r),
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
                  color: LG.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium)),
            if (action != null) action!
          ],
        ),
      );
}

class InfoLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const InfoLabel(
      {super.key, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: LG.muted, fontSize: 14, height: 1.3))),
            Flexible(
              child: Text(value,
                  style: TextStyle(
                      color: valueColor ?? LG.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                  textAlign: TextAlign.end),
            ),
          ],
        ),
      );
}

class Pill extends StatelessWidget {
  final String label;final Color color;
  const Pill(this.label,{super.key,this.color=LG.sageSoft});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
    decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(22)),child:Text(label,
      style:const TextStyle(color:LG.sage,fontWeight:FontWeight.w700,fontSize:11)));
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
                    color: LG.sageSoft,
                    borderRadius: BorderRadius.circular(13)),
                child: Icon(assetIcon(asset.kind),
                    color: LG.sage, size: 23)),
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
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.1))),
                    if (_isStale) ...[
                      const SizedBox(width: 6),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFBF3DD),
                              borderRadius: BorderRadius.circular(999)),
                          child: const Text('Stale',
                              style: TextStyle(
                                  color: Color(0xFF8C6A1D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800))),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      '${asset.category.isNotEmpty ? asset.category : assetTitle(asset.kind)} · ${LG.date(asset.valuedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12.5, color: LG.muted)),
                  if (_hasInterest) ...[
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: LG.goldSoft,
                          borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.percent_rounded,
                            size: 10.5, color: LG.gold),
                        const SizedBox(width: 4),
                        Text(_interestLabel,
                            style: const TextStyle(
                                color: LG.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ],
                ])),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(LG.money(asset.attributableUgx, compact: true),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      letterSpacing: -.2)),
              if (asset.ownershipBps < 10000)
                Text('${(asset.ownershipBps / 100).toStringAsFixed(0)}% owned',
                    style: const TextStyle(fontSize: 10.5, color: LG.sage)),
            ]),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: LG.muted),
          ]),
        ),
      );
}

class WealthBreakdown extends StatelessWidget {
  final Map<String,int> values;
  const WealthBreakdown({super.key,required this.values});
  @override Widget build(BuildContext context) {
    final colors=[LG.gold,LG.sage,const Color(0xFF487A94),const Color(0xFF9EAEB1)];
    final total=values.values.fold<int>(0,(a,b)=>a+b);
    return Column(children:[
      ClipRRect(borderRadius:BorderRadius.circular(8),child:Row(children:[for(var i=0;i<values.length;i++)
        Expanded(flex:total==0?1:((values.values.elementAt(i)/total*1000).round().clamp(1,1000).toInt()),
          child:Container(height:10,color:colors[i%colors.length]))])),
      const SizedBox(height:16),for(var i=0;i<values.length;i++)Padding(padding:const EdgeInsets.only(bottom:12),child:Row(children:[
        Container(width:9,height:9,decoration:BoxDecoration(color:colors[i%colors.length],borderRadius:BorderRadius.circular(4))),
        const SizedBox(width:9),Expanded(child:Text(values.keys.elementAt(i),style:const TextStyle(color:LG.muted,fontSize:13))),
        Text(LG.money(values.values.elementAt(i),compact:true),style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13))
      ]))
    ]);
  }
}

class EmptySection extends StatelessWidget {
  final String title;final String detail;final IconData icon;final VoidCallback? onAdd;
  const EmptySection({super.key,required this.title,required this.detail,this.icon=Icons.layers_outlined,this.onAdd});
  @override Widget build(BuildContext context)=>SoftCard(child:Padding(padding:const EdgeInsets.symmetric(vertical:20),child:
    Column(children:[Icon(icon,size:34,color:LG.sage),const SizedBox(height:12),Text(title,
      style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:6),Text(detail,
      textAlign:TextAlign.center,style:const TextStyle(color:LG.muted,height:1.4)),
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
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: LG.navy,
                        letterSpacing: -.1)),
                if (required) ...[
                  const SizedBox(width: 6),
                  const Text('•',
                      style: TextStyle(
                          color: LG.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            child,
            if (help != null) ...[
              const SizedBox(height: 8),
              Text(help!,
                  style: const TextStyle(
                      fontSize: 13, color: LG.muted, height: 1.4)),
            ],
          ],
        ),
      );
}

class PrivacyBanner extends StatelessWidget {
  const PrivacyBanner({super.key});
  @override Widget build(BuildContext context)=>const SoftCard(color:LG.sageSoft,child:Row(children:[
    Icon(Icons.shield_outlined,color:LG.sage,size:27),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Local alpha mode',style:TextStyle(fontWeight:FontWeight.w800,fontSize:13)),SizedBox(height:3),
      Text('Optional AES-GCM encryption on this device. No cloud sync. Keep an unencrypted JSON export as your backup.',
        style:TextStyle(fontSize:11,height:1.45,color:LG.muted))
    ]))]));
}

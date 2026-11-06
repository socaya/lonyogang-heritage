import React from 'react';
import { Image, ImageSourcePropType, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import Svg, { Path, Circle, Rect, Polyline, Line } from 'react-native-svg';
import { colors, radius, spacing } from '../theme/tokens';

const GLYPHS: Record<string, string> = {
  back: 'M15 18l-6-6 6-6', next: 'M5 12h14m-6-6 6 6-6 6', home: 'M3 10l9-7 9 7v11h-7v-7h-4v7H3z',
  portfolio: 'M3 3h7v8H3z M14 3h7v5h-7z M14 12h7v9h-7z M3 15h7v6H3z', plus: 'M12 5v14M5 12h14',
  report: 'M4 20h16 M6 16V9 M12 16V4 M18 16v-6', more: 'M5 12h.01M12 12h.01M19 12h.01',
  search: 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16z M21 21l-4.4-4.4',
  bell: 'M18 8a6 6 0 0 0-12 0c0 7-3 8-3 10h18c0-2-3-3-3-10 M10 21h4',
  eye: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7z M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
  property: 'M3 10l9-7 9 7 M5 9v12h14V9 M9 21v-7h6v7', wallet: 'M3 5h18v15H3z M3 9h18 M16 14h3',
  check: 'M5 12l4 4L19 6', close: 'M5 5l14 14 M19 5L5 19', filter: 'M3 6h18M7 12h10M10 18h4',
  shield: 'M12 2 20 6v6c0 5-4 8-8 10-4-2-8-5-8-10V6z M8 12l3 3 5-6',
  calendar: 'M4 5h16v16H4zM4 10h16M8 3v4M16 3v4', doc: 'M5 2h9l5 5v15H5z M14 2v5h5M8 12h8M8 16h8',
  lock: 'M5 10h14v11H5z M8 10V7a4 4 0 0 1 8 0v3', edit: 'M3 21l5-1 12-12-4-4L4 16z',
  logout: 'M9 3H4v18h5 M14 7l5 5-5 5 M8 12h11', chevron: 'M9 6l6 6-6 6',
};
export function Icon({ name, size = 20, color = colors.ink }: { name: string; size?: number; color?: string }) {
  return <Svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round"><Path d={GLYPHS[name] ?? GLYPHS.shield ?? ''} /></Svg>;
}
export function Brand({ compact = false }: {compact?: boolean}) {
  const image: ImageSourcePropType = require('../../assets/brand/theme1-primary.png');
  return <Image accessibilityLabel="LonyoGang Heritage" source={image} resizeMode="contain" style={{ width: compact ? 179 : 230, height: compact ? 68 : 102, alignSelf: 'flex-start' }} />;
}
export function H({ children, size = 27, muted = false, style }: { children: React.ReactNode; size?: number; muted?: boolean; style?: object }) {
  return <Text style={[{ fontSize: size, lineHeight: size * 1.22, fontWeight: '700' as const, color: muted ? colors.muted : colors.navy }, style]}>{children}</Text>;
}
export function Body({ children, muted = false, small = false, style }: { children: React.ReactNode; muted?: boolean; small?: boolean; style?: object }) {
  return <Text style={[{ fontSize: small ? 12 : 14, lineHeight: small ? 18 : 21, color: muted ? colors.muted : colors.ink }, style]}>{children}</Text>;
}
export function SectionHeading({ title, action, onAction }: {title: string; action?: string; onAction?: () => void}) {
  return <View style={styles.sectionHeading}><H size={19}>{title}</H>{action && <Pressable onPress={onAction} accessibilityRole="button"><Text style={{fontSize:12,color:colors.gold,fontWeight:'700'}}>{action}</Text></Pressable>}</View>;
}
export function Surface({ children, style, soft = false }: {children: React.ReactNode; style?: object; soft?: boolean}) {
  return <View style={[styles.surface, soft && {backgroundColor: colors.surfaceSoft}, style]}>{children}</View>;
}
export function Pill({ label, active = false, onPress }: {label: string; active?: boolean; onPress?: () => void}) {
  return <Pressable accessibilityRole="button" accessibilityState={{selected:active}} onPress={onPress} style={[styles.pill, active && styles.pillActive]}><Text style={{fontSize:12,fontWeight:'600',color:active ? colors.navy : colors.muted}}>{label}</Text></Pressable>;
}
export function Action({ label, onPress, secondary = false, disabled = false, icon = 'next' }: {label: string; onPress: () => void; secondary?: boolean; disabled?: boolean; icon?: string}) {
  return <Pressable accessibilityRole="button" accessibilityState={{disabled}} disabled={disabled} onPress={onPress} style={[styles.action, secondary && styles.actionSecondary, disabled && {opacity:0.45}]}><Text style={[styles.actionText,secondary && {color:colors.navy}]}>{label}</Text><Icon name={icon} color={secondary?colors.navy:colors.gold} size={22}/></Pressable>;
}
export function Input({label,value,onChangeText,placeholder,keyboardType='default',secureTextEntry=false, multiline=false}: {label:string;value:string;onChangeText:(value:string)=>void;placeholder?:string;keyboardType?:'default'|'numeric'|'email-address'|'phone-pad';secureTextEntry?:boolean;multiline?:boolean}) {
  return <View style={{marginBottom:18}}><Body style={{fontWeight:'700',marginBottom:8}}>{label}</Body><TextInput accessibilityLabel={label} placeholder={placeholder} placeholderTextColor="#93A0A4" value={value} onChangeText={onChangeText} keyboardType={keyboardType} secureTextEntry={secureTextEntry} multiline={multiline} style={[styles.input,multiline&&{height:92,textAlignVertical:'top'}]}/></View>;
}
export function ItemRow({title,subtitle,right,onPress,icon='portfolio',accent=colors.sage}: {title:string;subtitle?:string;right?:string;onPress?:()=>void;icon?:string;accent?:string}) {
  return <Pressable onPress={onPress} disabled={!onPress} accessibilityRole={onPress?'button':undefined} style={styles.itemRow}><View style={[styles.itemIcon,{backgroundColor: colors.surfaceSoft}]}><Icon name={icon} color={accent} size={20}/></View><View style={{flex:1,gap:3}}><Body style={{fontWeight:'700'}}>{title}</Body>{subtitle?<Body small muted>{subtitle}</Body>:null}</View>{right?<Body style={{fontWeight:'700',fontSize:13}}>{right}</Body>:null}{onPress?<Icon name="chevron" color={colors.muted} size={17}/>:null}</Pressable>;
}
export function Divider(){return <View style={{height:1,backgroundColor:colors.border}}/>}
export function Trend({ values, height=90, lineColor=colors.sageDark }: {values:number[];height?:number;lineColor?:string}){
  const w=315; const padding=7; const lowest=Math.min(...values); const range=Math.max(...values)-lowest||1;
  const pts=values.map((v,i)=>`${padding+i*(w-2*padding)/(values.length-1)},${height-padding-(v-lowest)*(height-2*padding)/range}`).join(' ');
  return <Svg width="100%" height={height} viewBox={`0 0 ${w} ${height}`} preserveAspectRatio="none"><Polyline points={pts} stroke={lineColor} strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round" fill="none" /></Svg>;
}
export function WealthDonut({ segments, size=178 }:{segments:{value:number;color:string}[];size?:number}){
  const total=segments.reduce((a,s)=>a+s.value,0)||1; let a=-90;
  const arcs=segments.filter(s=>s.value>0).map((s,i)=>{const sweep=s.value/total*359.9;const r=69; const start=a; const end=a+sweep; a=end; const rad=(deg:number)=>deg*Math.PI/180;const x1=90+r*Math.cos(rad(start)),y1=90+r*Math.sin(rad(start)),x2=90+r*Math.cos(rad(end)),y2=90+r*Math.sin(rad(end));return <Path key={i} d={`M ${x1} ${y1} A ${r} ${r} 0 ${sweep>180?1:0} 1 ${x2} ${y2}`} stroke={s.color} strokeWidth={22} fill="none"/>});
  return <Svg width={size} height={size} viewBox="0 0 180 180"><Circle cx={90} cy={90} r={69} stroke={colors.surfaceSoft} strokeWidth={22} fill="none"/>{arcs}</Svg>
}
const styles=StyleSheet.create({
  surface:{backgroundColor:colors.surface,borderRadius:radius.lg,padding:18},
  sectionHeading:{flexDirection:'row',justifyContent:'space-between',alignItems:'center',marginBottom:13},
  pill:{borderRadius:radius.pill,backgroundColor:colors.surfaceSoft,paddingHorizontal:14,paddingVertical:9,alignItems:'center'},
  pillActive:{backgroundColor:colors.goldSoft},
  action:{backgroundColor:colors.navy,borderRadius:radius.md,minHeight:56,paddingHorizontal:20,flexDirection:'row',alignItems:'center',justifyContent:'space-between',gap:12},
  actionSecondary:{backgroundColor:colors.surfaceSoft},
  actionText:{fontSize:16,fontWeight:'700',color:'#FFFFFF',flex:1,textAlign:'center'},
  input:{minHeight:52,backgroundColor:colors.surface,borderRadius:radius.md,borderColor:colors.border,borderWidth:1,paddingHorizontal:16,paddingVertical:12,fontSize:15,color:colors.navy},
  itemRow:{flexDirection:'row',gap:12,alignItems:'center',minHeight:66},
  itemIcon:{width:40,height:40,borderRadius:12,alignItems:'center',justifyContent:'center'},
});

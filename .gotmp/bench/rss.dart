import 'dart:convert';
import 'dart:io';
List<int> dizeCoz(String s){final c=<int>[];var i=0,onceki=0;while(i<s.length){var shift=0,sonuc=0;int b;do{b=s.codeUnitAt(i++)-63;sonuc|=(b&0x1f)<<shift;shift+=5;}while(b>=0x20);onceki+=(sonuc&1)!=0?~(sonuc>>1):(sonuc>>1);c.add(onceki);}return c;}
class DurakHatti{final Object hat;final int yon;final List<int> kalkislar;DurakHatti({required this.hat,required this.yon,required this.kalkislar});}
double mb(int b)=>b/1048576;
void main(List<String> a){
  final base=ProcessInfo.currentRss;
  print('  bos surec RSS      : ${mb(base).toStringAsFixed(1)} MB');
  final ham=File(a[0]).readAsStringSync();
  final hamH=File(a[1]).readAsStringSync();
  print('  +dize okundu       : +${mb(ProcessInfo.currentRss-base).toStringAsFixed(1)} MB');
  final r1=ProcessInfo.currentRss;
  final j=jsonDecode(ham) as Map<String,dynamic>;
  final sf=j['k'] as Map<String,dynamic>;
  final jh=jsonDecode(hamH) as Map<String,dynamic>;
  final ht=(jh['h']??jh['k']??jh) as Map<String,dynamic>;
  print('  +jsonDecode        : +${mb(ProcessInfo.currentRss-r1).toStringAsFixed(1)} MB  (durak=${sf.length})');
  final r2=ProcessInfo.currentRss;
  final m=<String,List<({String durakId,List<int> kalkislar})>>{};
  sf.forEach((durakId,o){(o as Map<String,dynamic>).forEach((hatId,v2){(v2 as Map<String,dynamic>).forEach((k,kod){final p=k.split(String.fromCharCode(124));if(p.length!=2)return;if(p[0]!='1')return;final dk=dizeCoz(kod as String);if(dk.isEmpty)return;(m['$hatId|${p[1]}']??=[]).add((durakId:durakId,kalkislar:dk));});});});
  print('  +hatDuraklari      : +${mb(ProcessInfo.currentRss-r2).toStringAsFixed(1)} MB  (hatYon=${m.length})');
  final r3=ProcessInfo.currentRss;
  final m2=<String,List<DurakHatti>>{};
  sf.forEach((durakId,o){final c=<DurakHatti>[];(o as Map<String,dynamic>).forEach((hatId,v2){final hat=ht[hatId];if(hat==null)return;(v2 as Map<String,dynamic>).forEach((k,kod){final p=k.split(String.fromCharCode(124));if(p.length!=2)return;if(p[0]!='1')return;final yon=int.tryParse(p[1])??0;final dk=dizeCoz(kod as String);if(dk.isEmpty)return;c.add(DurakHatti(hat:hat,yon:yon,kalkislar:dk));});});if(c.isNotEmpty)m2[durakId]=c;});
  print('  +durakHatIndeksi   : +${mb(ProcessInfo.currentRss-r3).toStringAsFixed(1)} MB  (durakIdx=${m2.length})');
  print('  TOPLAM (bostan)    : +${mb(ProcessInfo.currentRss-base).toStringAsFixed(1)} MB');
  print('  ham dize + indeks  : +${mb(ProcessInfo.currentRss-r1).toStringAsFixed(1)} MB (dize haric)');
  if(m.isEmpty||m2.isEmpty)print('x');
}

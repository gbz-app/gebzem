/// ⚠️⚠️⚠️ TURU 150 — **A -> B ROTA ARAMA (aktarmasiz).**
///
/// Kullanicinin emri: *"nereden / nereye secilsin, rotayi cizsin: durak
/// yolu ve varisa IKI RENK — durak guzergahi ve yurume mesafesi, altta da
/// step adimlar"*.
///
/// ⚠️⚠️ **GOOGLE'A ISTEK ATILMIYOR.** Hangi otobuse binilecegi, nerede
///	inilecegi ve kac dakika surdugu **kullanicinin verdigi GTFS
///	akisindan** hesaplaniyor. Fatura YOK, cevrimdisi calisir.
///
/// ⚠️⚠️ **TURU 152 — YURUME BACAKLARI ARTIK SOKAKTAN GIDIYOR.**
///	Turu 150/151'de kus ucusu duz cizgiydi ve kullanici hakli olarak
///	*"bizim yurume EVLERIN UZERINDEN gidiyor"* dedi. Artik sunucudaki
///	Routes vekilinden (`/yolbul/yaya`) gercek yol agi cizgisi aliniyor.
///	⚠️ Rota alinamazsa (ag yok / anahtar yok / cok uzak) **DUZ CIZGIYE
///	   DUSULUR** — ozellik COKMEZ, yalnizca kabalasir.
///	⚠️ DURUST SINIR: Gebze'de OSM yaya verisi fiilen yok (canli
///	   olculdu: 9.647 yolda 99 kaldirim, 40 isaretli gecit). Rota
///	   SOKAK AGINDAN gider; yaya gecidi garanti EDILMEZ. Google da
///	   WALK modunu BETA ilan edip bu uyariyi gostermeyi ZORUNLU
///	   tutuyor — metin sunucudan geliyor.
///
/// ⚠️⚠️ **AKTARMA YOK (V1).** Olculdu: 800 m yurume yaricapiyla rastgele
///	200 durak ciftinin **%41'i** aktarmasiz cozuluyor, %59'u tek aktarma
///	istiyor. Bacak modeli LISTE oldugu icin aktarma V2'de veri modeli
///	degismeden eklenebilir. Aday yoksa ekran DURUSTCE soyler, sahte rota
///	uretmez.
library;

import 'dart:math' as math;

import 'adres_servisi.dart';
import 'ulasim_veri.dart';

/// Bir rota bacaginin turu.
enum BacakTuru { yuru, bekle, otobus }

/// Rotanin tek bir bacagi.
class RotaBacagi {
  const RotaBacagi({
    required this.tur,
    required this.noktalar,
    required this.dakika,
    required this.baslik,
    required this.altBaslik,
    this.hat,
    this.metre = 0,
    this.eylem = '',
    this.yer = '',
    this.aktarmaYurumesi = false,
  });

  /// ⚠️⚠️⚠️ TURU 157 - **KOTA KAPISI.**
  ///
  ///	Aktarma yurumesi artik IKI GERCEK NOKTA tasiyor (haritada
  ///	cizilebilsin ve takipte atlanmasin diye). Ama
  ///	`_yurumeleriZenginlestir` tam da "iki noktali yurume bacagi"
  ///	olcutunu kullaniyor - yani bu bacak da Google Routes'a
  ///	gonderilirdi ve kazanan 3 aday x 3 yurume = **9 cagri**
  ///	olurdu (bugun 6). Aylik 10.000 ucretsiz kota ~1.660
  ///	aramadan ~1.100'e duserdi (turu 152 maliyet dersi).
  /// ⚠️⚠️ Aktarma yurumesi medyan **1 dk**, en fazla **2 dk** ve
  ///	aktarmalarin %36'sinda HIC YOK - duz cizgi yeterince dogru.
  /// ⚠️ Varsayilan `false`: mevcut 20+ cagri yeri DOKUNULMADAN derlenir.
  final bool aktarmaYurumesi;

  /// ⚠️⚠️ TURU 156 — **EYLEM ve YER AYRI** (kullanici emri: adim karti
  ///	Yandex duzenine gecti; orada ust satir KUCUK eylem
  ///	("Durağa kadar yürüyün"), alt satir BUYUK yer adi
  ///	("Güzeller Osb Giriş 2")).
  ///
  /// ⚠️⚠️ `baslik`/`altBaslik` **DOKUNULMADI**: iki tuketicileri daha
  ///	var (rota ozet karti ve rota detay sheet'i). Yeni ALAN eklemek
  ///	onlari BOZMAZ; `baslik`i parcalamak bozardi.
  /// ⚠️ `baslik`i METINDEN AYIRMAK (orn. " durağına yürü" ekini kesmek)
  ///    REDDEDILDI: 4. bacagin basligi "Varışa yürü" — icinde yer adi YOK,
  ///    ve durak adlarinda da o ek gecebilir.
  final String eylem;
  final String yer;

  final BacakTuru tur;

  /// Haritada cizilecek nokta dizisi (bekleme bacaginda BOS).
  final List<({double enlem, double boylam})> noktalar;

  final int dakika;
  final String baslik;
  final String altBaslik;

  /// Otobus bacaginda hattin kendisi (rozet ve renk icin).
  final Hat? hat;

  final double metre;
}

/// Bir rota adayi (yuru -> bekle -> otobus -> yuru).
class RotaAdayi {
  const RotaAdayi({
    required this.bacaklar,
    required this.varisDakika,
    required this.toplamDakika,
    required this.yurumeDakika,
    required this.hat,
    this.aktarma = 0,
  });

  /// ⚠️⚠️ TURU 157 - kac AKTARMA var (0 = aktarmasiz).
  ///	Siralama cezasi ve arayuzdeki "1 aktarma" etiketi bunu okur.
  /// ⚠️ `hat` alani ILK otobus hattidir; aktarmali rotada IKINCI hat
  ///    bacaklardan (`RotaBacagi.hat`) okunur.
  final int aktarma;

  /// ⚠️ Liste DEGISTIRILEBILIR: yurume bacaklari sonuc uretildikten SONRA
  ///    gercek yol agi cizgisiyle degistiriliyor
  ///    (bkz. `_yurumeleriZenginlestir`). `const` bir listeyle
  ///    kurulmadigi icin guvenli.
  final List<RotaBacagi> bacaklar;

  /// Gece yarisindan itibaren dakika (24'u asabilir).
  final int varisDakika;
  final int toplamDakika;
  final int yurumeDakika;
  final Hat hat;
}


/// ⚠️⚠️⚠️ TURU 157 - **AKTARMALI ROTA** (kullanici emri: *"cok uzakta bir
///	yeri isaretledigimde AKTARMA YOLLARINI gostermiyor, onu da yap"*).
///
/// ⚠️⚠️ **KULLANICI HAKLIYDI VE SAYISALLASTIRILDI.** 200 rastgele durak
///	cifti, hafta ici 12:00, 800 m yurume yaricapi:
///	  aktarmasiz motor toplam **%39,5** cozuyor
///	    0-3 km  %61  ·  6-10 km %27  ·  10-15 km %24
///	    **15 km ustu YALNIZCA %8**  <- sikayetin tam karsiligi
///	  TEK aktarma eklenince: **%98,5** (+%59).
///
/// ⚠️⚠️ **ALGORITMA OLCULEREK SECILDI** (uc secenek karsilastirildi):
///	  (a) kaba kuvvet: sorgu basina ~687.000 ic-dongu islemi -> 200 ms
///	      butcesine SIGMAZ.
///	  (b) hat-cifti kesisim tablosu: **HICBIR SEYI ELEMIYOR** - 200x200
///	      hat ciftinin %72,4'unde zaten ortak bir aktarma noktasi var,
///	      ustelik kurulumu 72 ms. (Bu secenegi bir daha arastirma.)
///	  (c) **IKI TURLU (RAPTOR benzeri)**: Dart'ta olculdu, ort **2,39 ms**
///	      / p95 5,74 / maks 9,48 ms. SECILEN BU.
///	⚠️ Olcum MASAUSTU + JIT ile yapildi; gercek cihazda AOT ile
///	   TEKRAR OLCULMELI. Sayiya degil BUYUKLUK MERTEBESINE guven.
///
/// ⚠️⚠️ **AKTARMA YARICAPI 150 m** (olculdu): 250 m ve 400 m kapsamaya
///	**HICBIR SEY EKLEMIYOR** ama komsu durak cifti sayisini 3.880'den
///	22.657'ye cikariyor. Aktarmalarin **%36'si AYNI DURAKTA**;
///	yuruyerek aktarmada sure medyan 1 dk, en fazla 2 dk.
///
/// ⚠️⚠️⚠️ **IKI AKTARMA YAPILMADI**: kazanc en fazla ~%1, maliyet katlaniyor.
/// ⚠️⚠️ Kalan ~%1,5 cozulmez; ayrica ciftlerin ~%5,5'inde 800 m icinde
///	HIC DURAK yok. O vakalarda bugunku durust *"rota bulunamadi"*
///	metni KALIR - sahte rota URETILMEZ.
const double kAktarmaYaricapM = 150;

/// ⚠️⚠️ Aktarma icin en az bekleme tamponu (dk). Otobus 1 dk gec kalirsa
///	kullanici aktarmayi kacirmasin diye ikinci hat bu kadar SONRA
///	kalkmali.
const int kAktarmaTampon = 2;

/// ⚠️⚠️ Kapidan kapiya toplam sure tavani (dk).
///	Bugunku tek kapi BACAK BASINA 180 dk; aktarmada iki otobus bacagi
///	birden ona yaklasabilir (olculen en kotu: **234 dk**). Boyle bir
///	rota gosterilmemeli.
const int kToplamSureTavani = 150;

/// ⚠️⚠️ Siralamada aktarmaya eklenen CEZA (dk).
///	Aktarma yalnizca sureye bakilarak siralansaydi, 3 dakika daha
///	erken varan aktarmali bir rota aktarmasizin ONUNE gecerdi -
///	oysa aktarma gercek bir zahmet ve KACIRMA RISKI tasir.
///	Olculdu: 8 dk ceza ile aktarmali rota aramalarin **%37**'sinde
///	yine birinci kaliyor ve kazandiginda kazanc **medyan 53 dakika**.
const int kAktarmaCezasi = 8;

/// Sefer sutunundan bir bacak icin binis/inis dakikasi bulur.
///
/// ⚠️⚠️⚠️ **BU KAPI TAM KORUMA SAGLAMAZ — DURUST OLCUM.**
///
///	Kod `kalkislar[j]`nin iki durakta da AYNI SEFERI gosterdigini
///	VARSAYIYOR. Kapi yalniz uzunluklar farkliysa cifti atar.
///
/// ⚠️⚠️ **KOK NEDEN VARLIK URETICISINDE** (`tools/ulasim_uret.js`):
///	kalkis listeleri durak basina AYRI siralaniyor ve **sefer
///	kimligi ATILIYOR**. Yani veri, "bu kalkis hangi sefere ait"
///	bilgisini TASIMIYOR; indeks eslesmesi ancak iki duragi AYNI
///	sefer kumesi geciyorsa dogru olur.
///
/// ⚠️⚠️ **DENETIMDE OLCULEN GERCEK** (eski serhteki %0,12 YANILTICIYDI —
///	o, kapinin YAKALADIGI orandir, KACIRDIGI degil):
///	  · kapi cift havuzunun **%0,12**'sini eliyor
///	  · kapidan GECENLERIN **%2,6**'sini hicbir gercek sefer saglamiyor
///	  · secilen bacaklarin **%4,4**'unde varis saati UYDURMA
///	  · hatalarin **TAMAMI** varisi **ERKEN** gosteriyor -> o rota
///	    siralamada HAKSIZ YERE ONE gecer
///	  · bacaklar COGRAFI olarak GERCEK (durak sirasi dogru); yanlis
///	    olan yalnizca SAAT.
///
/// ⚠️⚠️ **KALICI COZUM AYRI TUR**: uretici `kalkislar`i
///	`[dakika, seferIndeksi]` olarak tasimali; o zaman `kalkislar[j]`
///	iki durakta da AYNI seferi gosterir ve bu kapi GEREKSIZLESIR.
///	Varlik yeniden uretimi + yeni surum gerektirir.
/// ⚠️⚠️ YAPMA: buraya "binis ve inis ayni seferden mi" kontrolu
///	eklemeye calisma - **mevcut varlik o bilgiyi TASIMIYOR.**
/// ⚠️ Ayni varsayim `_aktarmaliAra` icinde IKI KEZ daha kullaniliyor
///    (tur 1 ve tur 2 sutun kapilari) - orasi da bu serhe baglidir.
/// ⚠️ 180 dk tavani: ayni hattin gunun BASKA seferlerinin yanlis
///    eslesmesini eler (mevcut kuraldan devir).
({int binis, int inis, int sutun})? _seferBul(
  List<int> binisSaatleri,
  List<int> inisSaatleri,
  int enErken,
) {
  if (binisSaatleri.length != inisSaatleri.length) return null;
  for (var j = 0; j < binisSaatleri.length; j++) {
    final b = binisSaatleri[j];
    final i = inisSaatleri[j];
    if (b < enErken) continue;
    if (i <= b) continue;
    if (i - b > 180) continue;
    return (binis: b, inis: i, sutun: j);
  }
  return null;
}
/// Yaya hizi (m/sn). ⚠️ TEK KAYNAK: hem sure hem "kac dakika yurudum"
/// hesabi bunu okur. 1,3 m/sn ~ 4,7 km/sa — yetiskin ortalamasi.
const double kYayaHizi = 1.3;

int _yurumeDakikasi(double metre) => (metre / kYayaHizi / 60).ceil();

/// ⚠️ Bir noktanin polyline uzerindeki EN YAKIN segment indeksi.
///
/// ⚠️⚠️ **METRIK DUZLEME GECILIR**: ham derece ile Gebze enleminde (40,8°)
///	boylam ekseni %24 yanlis olceklenir ve izdusum YANLIS segmente kayar
///	(turu 85b'de sunucu tarafinda birebir bu yasandi).
/// ⚠️ Sifira bolme kapisi ZORUNLU: GTFS sekillerinde ardisik TEKRARLI
///    nokta gercekten var; kapi olmazsa `t = NaN` olur ve **NaN her
///    karsilastirmadan sessizce duser** (turu 85b NaN dersi).
/// ⚠️⚠️⚠️ TURU 155 — **[basSegment]: ARAMAYI BURADAN BASLAT.**
///
///	Kullanici: *"bizimki DIREK USTUNDE"* (otobus cizgisi binalarin
///	uzerinden duz gidiyor).
///
/// ⚠️⚠️ **KOK NEDEN — ILMEKLI HATLAR.** Kucuk bir sehirde hatlar kendi
///	uzerine doner ve GLOBAL "en yakin segment" aramasi inis duragini
///	aynı caddenin **IKINCI GECISINE** kilitleyebilir. O zaman inis
///	indeksi binis indeksinden KUCUK cikar (`b <= a`), `_guzergahDilimi`
///	diimi uretemez ve iki durak arasi **DUZ CIZGI** dondurur.
///
///	GERCEK VERIDE OLCULDU (hafta ici, sefer-sutunu gecerlilik testiyle):
///	**361.110 gecerli durak ciftinin 14.799'u (%4,10)** bu dala
///	dusuyordu. En kotuleri: 300/yon1 **%41,2** · 480/yon0 %35,1 ·
///	440/yon1 %32,5 · 315/yon1 %30,3.
///
/// ⚠️⚠️ Kardes dosya `rota_takip.dart` bu tuzagi ZATEN kapatmis
///	(`basSegment` + arama penceresi) ve serhinde aynen soyle diyor:
///	*"Kucuk bir sehirde hatlar kendi uzerine doner; GLOBAL en yakin
///	segment aramasi kullaniciyi ILERIYE SICRATIR ya da geri atar."*
///	Ayni ders buraya UYGULANMAMISTI.
///
/// ⚠️ Burada PENCERE YOK (tum kalan cizgi taranir): `rota_takip`teki
///    40 segmentlik pencere GPS monotonlugu icindir; burada inis duragi
///    uzun bir hatta pencerenin DISINDA kalir ve sonuc DAHA KOTU olurdu.
int _enYakinSegment(
  List<({double enlem, double boylam})> yol,
  double enlem,
  double boylam, {
  int basSegment = 0,
}) {
  if (yol.length < 2) return 0;
  // ⚠️ Taban cizginin DISINA tasarsa arama yapilacak segment KALMAZ;
    // cagiran (`_guzergahDilimi`) bunu duz-cizgi dali ile karsilar.
  final bas = basSegment.clamp(0, yol.length - 2);
  final kx = 111320.0 * math.cos(yol.first.enlem * math.pi / 180);
  final px = boylam * kx;
  final py = enlem * 111320.0;
  var enIyi = bas;
  var enAz = double.infinity;
  for (var i = bas; i < yol.length - 1; i++) {
    final ax = yol[i].boylam * kx;
    final ay = yol[i].enlem * 111320.0;
    final bx = yol[i + 1].boylam * kx;
    final by = yol[i + 1].enlem * 111320.0;
    final abx = bx - ax;
    final aby = by - ay;
    final l2 = abx * abx + aby * aby;
    var t = 0.0;
    if (l2 > 0) {
      t = (((px - ax) * abx) + ((py - ay) * aby)) / l2;
      t = t.clamp(0.0, 1.0);
    }
    final qx = ax + t * abx;
    final qy = ay + t * aby;
    final dx = px - qx;
    final dy = py - qy;
    final d = dx * dx + dy * dy;
    if (d < enAz) {
      enAz = d;
      enIyi = i;
    }
  }
  return enIyi;
}

/// Bir polyline'in iki durak arasindaki dilimi.
///
/// ⚠️⚠️ TURU 155 — **INIS DURAGI BINISTEN SONRA ARANIR** (`basSegment`).
///	Onceden ikisi de GLOBAL araniyordu ve ilmekli hatlarda inis,
///	aynı caddenin ikinci gecisine kilitlenip `b <= a` uretiyordu;
///	o durumda cizgi iki durak arasi DUZ bir hat oluyor, yani
///	kullanicinin gordugu **"binalarin uzerinden gecen"** cizgi.
///	Olculdu: %4,10 -> yapisal olarak ~0.
///
/// ⚠️ Sira TERS gelirse (sekil ters yonde cizilmis) dilim BOS DONMEZ,
///    duraklar arasi duz cizgi dondurulur — ekranda "hicbir sey yok"
///    gorunmesindense kaba ama DOGRU bir cizgi daha iyidir.
/// ⚠️ **Bu duz-cizgi dali SILINMEZ**: `basSegment` ile bile
///    `yol.length < 2` ya da binis son segmentte olma hali kalir.
///    Artik ULASILMASI ZOR bir emniyet agidir.
List<({double enlem, double boylam})> _guzergahDilimi(
  List<({double enlem, double boylam})> yol,
  Durak binis,
  Durak inis,
) {
  if (yol.length < 2) {
    return [
      (enlem: binis.enlem, boylam: binis.boylam),
      (enlem: inis.enlem, boylam: inis.boylam),
    ];
  }
  final a = _enYakinSegment(yol, binis.enlem, binis.boylam);
  // ⚠️⚠️ Inis BINISTEN SONRA aranir — bkz. `_enYakinSegment` serhi.
  final b = _enYakinSegment(yol, inis.enlem, inis.boylam,
      basSegment: a + 1);
  if (b <= a) {
    return [
      (enlem: binis.enlem, boylam: binis.boylam),
      (enlem: inis.enlem, boylam: inis.boylam),
    ];
  }
  return [
    (enlem: binis.enlem, boylam: binis.boylam),
    ...yol.sublist(a + 1, math.min(b + 1, yol.length)),
    (enlem: inis.enlem, boylam: inis.boylam),
  ];
}

/// Aktarmasiz rota adaylari (en erken varis ONCE, en fazla [adet]).
///
/// ⚠️ Yaricap 800 m: olculdu, 500 m'de kapsama %28, 800 m'de %41.
///    Daha genis yaricap yurume suresini kabul edilemez yapiyor.
Future<List<RotaAdayi>> rotaAra({
  required double baslangicEnlem,
  required double baslangicBoylam,
  required double varisEnlem,
  required double varisBoylam,
  int adet = 3,
  double yaricapM = 800,
  DateTime? an,
  String varisAd = '',
}) async {
  final servis = UlasimVeri.bugunServis(an);
  final suAn = UlasimVeri.suAnDakika(an);

  final basDuraklar = await UlasimVeri.i.yakinDuraklar(
    baslangicEnlem,
    baslangicBoylam,
    adet: 12,
    yaricapM: yaricapM,
  );
  final varDuraklar = await UlasimVeri.i.yakinDuraklar(
    varisEnlem,
    varisBoylam,
    adet: 12,
    yaricapM: yaricapM,
  );
  if (basDuraklar.isEmpty || varDuraklar.isEmpty) return const [];

  // Duraklarin hat tablolarini BIR KEZ coz (ic ice dongude tekrar cozmek
  // 144 kez ayni isi yapardi).
  final basHat = <String, List<DurakHatti>>{};
  for (final d in basDuraklar) {
    basHat[d.id] = await UlasimVeri.i.duraginHatlari(d.id, servis);
  }
  final varHat = <String, List<DurakHatti>>{};
  for (final d in varDuraklar) {
    varHat[d.id] = await UlasimVeri.i.duraginHatlari(d.id, servis);
  }

  final adaylar = <RotaAdayi>[];
  for (final o in basDuraklar) {
    final oM = UlasimVeri.kabaMetre(
        baslangicEnlem, baslangicBoylam, o.enlem, o.boylam);
    final oDk = _yurumeDakikasi(oM);
    for (final d in varDuraklar) {
      if (d.id == o.id) continue;
      final dM =
          UlasimVeri.kabaMetre(varisEnlem, varisBoylam, d.enlem, d.boylam);
      final dDk = _yurumeDakikasi(dM);

      for (final oh in basHat[o.id] ?? const <DurakHatti>[]) {
        for (final dh in varHat[d.id] ?? const <DurakHatti>[]) {
          if (oh.hat.id != dh.hat.id || oh.yon != dh.yon) continue;

          // ⚠️⚠️ **GECERLILIK SIRADAN DEGIL SEFER SUTUNUNDAN.**
          //	Durak sirasi (stop_sequence) veride YOK ve zaman siralamasi
          //	dongusel hatlarda yaniltiyor (olculdu: en kotu grupta %65,8
          //	ters cift). Dogru olcut: AYNI SEFERDE binis saati inis
          //	saatinden ONCE mi?
          // ⚠️⚠️⚠️ TURU 157 - **`math.min(...)` GIZLI BIR VARSAYIMDI.**
          //	Iki duragin kalkis listelerinin INDEKS INDEKS AYNI
          //	SEFERI gosterdigini varsayiyordu. **OLCULDU: 200
          //	hat-yonun 8'i bunu SAGLAMIYOR** ve fark TAM 2 KAT -
          //	ilmekli hatta ayni durak ayni seferde IKI KEZ
          //	geciliyor. `min` ile kisa listeye hizalanmak, uzun
          //	listedeki duragin **YANLIS seferini** okumak demekti.
          //	Bugun durak ciftlerinin %0,12'si etkileniyordu;
          //	aktarmada IKI otobus bacagi oldugu icin maruziyet
          //	IKIYE KATLANIRDI.
          // ⚠️⚠️ Kapi TEK KAYNAKTAN (`_seferBul`): uzunluklar ESIT
          //	DEGILSE cift ATLANIR. Yanlis sonuc uretmektense
          //	sonuc URETMEMEK dogrudur.
          final enErken = suAn + oDk;
          final sf = _seferBul(oh.kalkislar, dh.kalkislar, enErken);
          if (sf == null) continue;
          final binis = sf.binis;
          final inis = sf.inis;

          final varis = inis + dDk;
          // ⚠️⚠️⚠️ TURU 157 - **TAVAN ARTIK AKTARMASIZ DALA DA UYGULANIR.**
          //	Onceden `kToplamSureTavani` YALNIZ `_aktarmaliAra`da
          //	vardi ve asimetri kullaniciya GORUNURDU: 151 dakikalik
          //	aktarmali rota SESSIZCE atilirken **984 dakikalik
          //	(16 saat)** aktarmasiz bir rota *"en iyi secenek"* diye
          //	BIRINCI sirada gosteriliyordu.
          // ⚠️⚠️ Yan etki ISTENEN: tavan yuzunden tekil hat sayisi duser,
          //	dolayisiyla aktarma aramasi DAHA SIK kosar.
          if (varis - suAn > kToplamSureTavani) continue;
          final yol = await UlasimVeri.i.guzergah(oh.hat.id, oh.yon);
          final dilim = _guzergahDilimi(yol, o, d);


          adaylar.add(RotaAdayi(
            hat: oh.hat,
            varisDakika: varis,
            toplamDakika: varis - suAn,
            yurumeDakika: oDk + dDk,
            bacaklar: [
              RotaBacagi(
                tur: BacakTuru.yuru,
                noktalar: [
                  (enlem: baslangicEnlem, boylam: baslangicBoylam),
                  (enlem: o.enlem, boylam: o.boylam),
                ],
                dakika: oDk,
                metre: oM,
                baslik: '${o.ad} durağına yürü',
                altBaslik: '${oM.round()} m · yaklaşık',
                eylem: 'Durağa kadar yürüyün',
                yer: o.ad,
              ),
              RotaBacagi(
                tur: BacakTuru.bekle,
                noktalar: const [],
                dakika: math.max(0, binis - (suAn + oDk)),
                baslik: '${UlasimVeri.saatMetni(binis)} kalkış',
                altBaslik: o.ad,
                hat: oh.hat,
                eylem: '${UlasimVeri.saatMetni(binis)} kalkışını bekleyin',
                yer: o.ad,
              ),
              RotaBacagi(
                tur: BacakTuru.otobus,
                noktalar: dilim,
                dakika: inis - binis,
                baslik: '${d.ad} durağında in',
                altBaslik: oh.hat.yonBaslik[oh.yon] ?? oh.hat.uzunAd,
                hat: oh.hat,
                eylem: '${oh.hat.kisaAd} ile gidin, inin:',
                yer: d.ad,
              ),
              RotaBacagi(
                tur: BacakTuru.yuru,
                noktalar: [
                  (enlem: d.enlem, boylam: d.boylam),
                  (enlem: varisEnlem, boylam: varisBoylam),
                ],
                dakika: dDk,
                metre: dM,
                baslik: 'Varışa yürü',
                altBaslik: '${dM.round()} m · yaklaşık',
                eylem: 'Varışa kadar yürüyün',
                // ⚠️ Varis adi CAGIRANDAN gelir (`rotaAra(varisAd:)`);
                //    `rotaAra` yalniz KOORDINAT aliyordu, ad ekranda vardi
                //    ama fonksiyona GECMIYORDU. Bos ise 'Varış' yazilir.
                yer: varisAd.isEmpty ? 'Varış' : varisAd,
              ),
            ],
          ));
        }
      }
    }
  }

  // ⚠️⚠️⚠️ TURU 157 - **AKTARMALI ADAYLAR AYNI LISTEYE KATILIR.**
  //
  //	AYRI BIR BOLUM YAPILMADI (olculdu): durak ciftlerinin **%61'inde
  //	aktarmasiz cozum HIC YOK**, yani "Aktarmasız" basligi cogu
  //	aramada BOMBOS kalirdi.
  // ⚠️⚠️ **ARAMA HER ZAMAN KOSULMAZ**: aktarmasiz sonuc `adet` kadar
  //	doluysa ikinci tur ATLANIR - kisa mesafelerde (0-3 km, %61
  //	basari) gereksiz is yapilmaz.
  //
  // ⚠️⚠️⚠️ **OLCUT HAM LISTE DEGIL, TEKIL HAT SAYISI.**
  //	Ilk yazimda kapi `adaylar.length < adet` idi ve `adaylar`
  //	TEKILLESTIRILMEMIS ham listedir: 12 binis x 12 inis duragi
  //	taranidigi icin **TEK BIR HAT** bile onlarca kayit uretir.
  //	Yani ekranda YALNIZ BIR rota gorunecek olsa bile
  //	`adaylar.length` 3'u rahatca astigi icin aktarma aramasi
  //	**HIC KOSMUYORDU** - kullanici tek secenekle kalirken
  //	aktarmayla cok daha hizli bir yol VARDI ve gosterilmiyordu.
  // ⚠️⚠️ Tekilleme olcutu asagidaki `zincir` ile AYNI olmak zorunda;
  //	ayrisirsa kapi yine yanlis sayar.
  final tekilHat = <String>{};
  for (final a in adaylar) {
    tekilHat.add([
      for (final b in a.bacaklar)
        if (b.tur == BacakTuru.otobus && b.hat != null) b.hat!.id,
    ].join('>'));
  }
  if (tekilHat.length < adet) {
    adaylar.addAll(await _aktarmaliAra(
      basDuraklar: basDuraklar,
      varDuraklar: varDuraklar,
      basHat: basHat,
      baslangicEnlem: baslangicEnlem,
      baslangicBoylam: baslangicBoylam,
      varisEnlem: varisEnlem,
      varisBoylam: varisBoylam,
      servis: servis,
      suAn: suAn,
      varisAd: varisAd,
    ));
  }

  // ⚠️⚠️⚠️ **SIRALAMA: VARIS + AKTARMA CEZASI.**
  //	Ciplak varis saatiyle siralansaydi, 3 dakika daha erken varan
  //	aktarmali bir rota aktarmasizin ONUNE gecerdi - oysa aktarma
  //	gercek bir zahmet ve KACIRMA RISKI tasir.
  //	Olculdu: 8 dk ceza ile aktarmali rota aramalarin %37'sinde
  //	yine birinci kaliyor ve kazandiginda kazanc medyan 53 dakika.
  int puan(RotaAdayi a) => a.varisDakika + a.aktarma * kAktarmaCezasi;
  adaylar.sort((a, b) => puan(a).compareTo(puan(b)));
  // ⚠️⚠️ **TEKILLEME ANAHTARI HAT ZINCIRI**, tek basina `hat.id` DEGIL
  //	(olculdu: tekil hat cifti medyan 26, maks 509). Tek anahtarla
  //	ilk hattin BUTUN aktarmalari SESSIZCE elenirdi.
  final gorulen = <String>{};
  final sonuc = <RotaAdayi>[];
  for (final a in adaylar) {
    final zincir = [
      for (final b in a.bacaklar)
        if (b.tur == BacakTuru.otobus && b.hat != null) b.hat!.id,
    ].join('>');
    if (!gorulen.add(zincir)) continue;
    sonuc.add(a);
    if (sonuc.length >= adet) break;
  }

  // ⚠️⚠️⚠️ **YURUME ROTALARI EN SONDA, YALNIZ KAZANAN ADAYLAR ICIN.**
  //	Ilk yazimda cagri ic ice dongunun ICINDEYDI ve SUNUCU
  //	LOGUNDA OLCULDU: **tek arama 90+ istek** uretiyordu. Her
  //	istek Google Routes'ta FATURALANABILIR bir cagri; aylik
  //	10.000 ucretsiz kota ~110 aramada biterdi.
  //	Simdi yalniz DONULECEK adaylar zenginlestiriliyor:
  //	en fazla `adet x 2` = **6 cagri**.
  // ⚠️ Tumu PARALEL: ard arda beklenseydi sonuc ekrani 6 tur gecikirdi.
  await _yurumeleriZenginlestir(
      sonuc, baslangicEnlem, baslangicBoylam, varisEnlem, varisBoylam);
  return sonuc;
}


/// ⚠️⚠️⚠️ TURU 157 - **AKTARMALI ADAYLARI URETIR (IKI TUR).**
///
///	TUR 1: baslangica yakin duraklardan kalkan her hat-yon icin
///	       SECILEN SEFER SUTUNU boyunca **hattin tum duraklarina**
///	       varis saatleri okunur (ters indeks sayesinde O(1)).
///	TUR 2: her varis noktasindan (kendisi + 150 m icindeki komsulari)
///	       kalkan hatlar taranir; ikinci sefer sutunu
///	       `inis1 + tampon + aktarma yurumesi` sonrasi olmali.
///
/// ⚠️⚠️ **AYNI HATTA AKTARMA ELENIR**: ayni hat-yonda inip tekrar binmek
///	bir aktarma DEGILDIR, tek bacaktir; tur 1 zaten o dilimi buluyor.
/// ⚠️⚠️ **TEKILLEME ANAHTARI `hat1|hat2`**, tek basina `hat.id` DEGIL
///	(olculdu: tekil hat cifti sayisi medyan 26, maks 509 - tek
///	anahtarla ilk hattin butun aktarmalari SESSIZCE elenirdi).
/// ⚠️⚠️ **AKTARMA YURUMESI ICIN GOOGLE ROUTES CAGRILMAZ**: sure medyan
///	1 dk / maks 2 dk, duz cizgi yeterince dogru. Cagrilsaydi bacak
///	sayisi 2'den 3'e cikacagi icin aylik 10.000 ucretsiz kota
///	~1.660 aramadan ~1.100'e duserdi (turu 152 maliyet dersi).
///	Bu yuzden aktarma yurumesi `noktalar: const []` ile kurulur -
///	`_yurumeleriZenginlestir` yalniz 2 noktali bacaklari isliyor,
///	yani bu bacak ONA HIC UGRAMAZ ve kota **6'da KALIR**.
///	⚠️⚠️ Ayni durakta aktarmada (vakalarin %36'si) zaten yurume YOK.
Future<List<RotaAdayi>> _aktarmaliAra({
  required List<Durak> basDuraklar,
  required List<Durak> varDuraklar,
  required Map<String, List<DurakHatti>> basHat,
  required double baslangicEnlem,
  required double baslangicBoylam,
  required double varisEnlem,
  required double varisBoylam,
  required int servis,
  required int suAn,
  required String varisAd,
}) async {
  final indeks = await UlasimVeri.i.hatDuraklari(servis);
  final durakM = await UlasimVeri.i.durakHaritasi();
  final durakHat = await UlasimVeri.i.durakHatIndeksi(servis);
  final komsu = await UlasimVeri.i.komsuDuraklar(kAktarmaYaricapM);
  // ⚠️⚠️ Guzergah cizgileri DONGUNUN ICINDE cozulmez: `guzergah()`
  //	polyline coz uyor ve ic ice donguden cagrilsaydi ayni sekil
  //	yuzlerce kez yeniden cozulurdu. Yerel onbellek.
  final yolOnbellek = <String, List<({double enlem, double boylam})>>{};
  // ⚠️ hat|yon -> o hattin VARIS ADAYI duraklari (bkz. kesit serhi).
  final kesit = <String, List<({String durakId, List<int> kalkislar})>>{};
  Future<List<({double enlem, double boylam})>> yolAl(
      String hatId, int yon) async {
    final k = '$hatId|$yon';
    return yolOnbellek[k] ??= await UlasimVeri.i.guzergah(hatId, yon);
  }
  // ⚠️⚠️⚠️ TURU 157 - **VARIS TARAFINDA TAVAN YOK** (denetimde olculdu).
  //
  //	Ilk yazimda burada da `.take(7)` vardi ve GEREKCESI KENDI
  //	ICINDE CURUKTU: serh *"`hedef` bir Set-benzeri arama tablosu
  //	oldugu icin kucultmek dogrudan ic dongu maliyetini DUSURMEZ"*
  //	diyordu - yani tavanin performans kazanci OLMADIGINI kendisi
  //	yaziyordu; geriye yalnizca ZARARI kaliyordu.
  //
  //	**OLCULDU (tavan kaldirilinca):**
  //	  birinci sira kotulesmesi  %22,8 -> **%4,0**  (5,7 kat)
  //	  bos sonuc ekrani              9 -> **1**
  //	  maliyet p99               203 ms -> **192 ms**
  //	Yani kaldirmak DAHA IYI SONUC ve DAHA UCUZ.
  // ⚠️ KALKIS tarafindaki tavan (`kAktarmaDurakTavani`) KALIR:
  //    asil maliyet orada ve orasi gercekten dogrusal DEGIL.
  final hedef = {for (final d in varDuraklar) d.id: d};
  final sonuc = <RotaAdayi>[];
  // ⚠️ Hat cifti -> O CIFTIN EN ERKEN VARAN kombinasyonu (hafif kayit).
  final enIyi = <String,
      ({
    Durak o,
    DurakHatti oh,
    int binis,
    int oDk,
    double oM,
    int enErken,
    Durak aktD,
    int inis1,
    Durak y,
    double yurM,
    int yurDk,
    int hazir,
    DurakHatti dh,
    int binis2,
    Durak d,
    int inis2,
    double dM,
    int dDk,
    int varis,
  })>{};

  // ⚠️⚠️⚠️ **AKTARMA TURUNDE DURAK SAYISI SINIRLI** (olculdu).
  //
  //	Aktarmasiz arama 12 binis x 12 inis duragi tariyor; aktarmada
  //	her binis duragi ayrica **hattin TUM duraklarina** ve onlarin
  //	komsularina aciliyor, yani maliyet dogrusal DEGIL.
  //	OLCULDU: 12 durakla en kotu arama **171 ms** (masaustu, JIT) -
  //	200 ms butcesinin sinirinda. Yavas bir telefonda ASILIRDI.
  //
  // ⚠️⚠️ EN YAKIN duraklar zaten EN IYI adaylar: `yakinDuraklar`
  //	listeyi mesafeye gore SIRALI donduruyor ve 7. duraga kadar
  //	inince yurume suresi cogu vakada rotayi ZATEN eliyor.
  // ⚠️ Aktarmasiz arama 12 durakla KALIR - orada maliyet dusuk ve
  //    kapsama daha degerli.
  const kAktarmaDurakTavani = 7;
  final basAktarma = basDuraklar.take(kAktarmaDurakTavani).toList();

  for (final o in basAktarma) {
    final oM = UlasimVeri.kabaMetre(
        baslangicEnlem, baslangicBoylam, o.enlem, o.boylam);
    final oDk = _yurumeDakikasi(oM);
    for (final oh in basHat[o.id] ?? const <DurakHatti>[]) {
      final anahtar1 = '${oh.hat.id}|${oh.yon}';
      final hat1Duraklar = indeks[anahtar1];
      if (hat1Duraklar == null) continue;
      // binis duraginin bu hattaki sutunu
      final binisSat = oh.kalkislar;
      var sutun1 = -1;
      final enErken = suAn + oDk;
      for (var j = 0; j < binisSat.length; j++) {
        if (binisSat[j] >= enErken) {
          sutun1 = j;
          break;
        }
      }
      if (sutun1 < 0) continue;
      final binis = binisSat[sutun1];

      // ── TUR 1: hattin tum duraklarina varis ──
      for (final x in hat1Duraklar) {
        if (x.durakId == o.id) continue;
        // ⚠️⚠️ SUTUN UZUNLUGU KAPISI (bkz. `_seferBul` serhi).
        if (x.kalkislar.length != binisSat.length) continue;
        final inis1 = x.kalkislar[sutun1];
        if (inis1 <= binis || inis1 - binis > 180) continue;
        final aktD = durakM[x.durakId];
        if (aktD == null) continue;

        // ── AKTARMA NOKTALARI: DURAGIN KENDISI + 150 m komsulari ──
        // ⚠️⚠️ Komsular IZGARADAN gelir. Duz tarama olsaydi her x icin
        //	2032 durak olculur, tek aramada MILYONLARCA mesafe hesabi
        //	cikar ve 200 ms butcesi KATLANARAK asilirdi.
        // ⚠️ Duragin KENDISI bastadir (aktarmalarin %36'si ayni durakta).
        final aktarmaNoktalari = <({Durak d, double m})>[
          (d: aktD, m: 0.0),
          ...?komsu[aktD.id],
        ];
        for (final k in aktarmaNoktalari) {
          final y = k.d;
          final yurM = k.m;
          final yurDk = yurM == 0 ? 0 : _yurumeDakikasi(yurM);
          final hazir = inis1 + kAktarmaTampon + yurDk;

          // ── TUR 2 ──
          for (final dh in durakHat[y.id] ?? const <DurakHatti>[]) {
            if (dh.hat.id == oh.hat.id) continue; // ayni hat aktarma DEGIL
            final anahtar2 = '${dh.hat.id}|${dh.yon}';
            final hat2Duraklar = indeks[anahtar2];
            if (hat2Duraklar == null) continue;
            // ⚠️⚠️⚠️ TURU 157 - **HEDEF KESITI ONBELLEKLI.**
            //	Ic dongu hattin TUM duraklarini tariyor ama yalnizca
            //	`hedef` tablosunda olanlar ise yariyor. Kesit hat|yon
            //	basina BIR KEZ hesaplanir.
            // ⚠️⚠️ **OLCULDU (Dart AOT, gercek GTFS):** ic dongu
            //	9.804.508 -> **69.114** islem, arama 234,5 -> **42,4 ms**;
            //	uretilen aday sayisi UC senaryoda da **BIREBIR AYNI**
            //	(310/626/106). Yani bu bir HIZLANDIRMA, davranis
            //	degisikligi DEGIL.
            final hedefliDuraklar = kesit[anahtar2] ??= [
              for (final q in hat2Duraklar)
                if (hedef.containsKey(q.durakId)) q,
            ];
            if (hedefliDuraklar.isEmpty) continue;
            var sutun2 = -1;
            for (var j = 0; j < dh.kalkislar.length; j++) {
              if (dh.kalkislar[j] >= hazir) {
                sutun2 = j;
                break;
              }
            }
            if (sutun2 < 0) continue;
            final binis2 = dh.kalkislar[sutun2];

            for (final z in hedefliDuraklar) {
              final d = hedef[z.durakId];
              if (d == null || d.id == y.id) continue;
              if (z.kalkislar.length != dh.kalkislar.length) continue;
              final inis2 = z.kalkislar[sutun2];
              if (inis2 <= binis2 || inis2 - binis2 > 180) continue;

              final dM = UlasimVeri.kabaMetre(
                  varisEnlem, varisBoylam, d.enlem, d.boylam);
              final dDk = _yurumeDakikasi(dM);
              final varis = inis2 + dDk;
              if (varis - suAn > kToplamSureTavani) continue;

              // ⚠️⚠️⚠️ TURU 157 - **HAT CIFTI BASINA EN ERKEN VARAN.**
              //
              //	Ilk yazimda `if (!gorulen.add(ck)) continue;` vardi:
              //	bir hat cifti icin **ILK RASTLANAN** kombinasyon
              //	kilitleniyor, digerleri HIC uretilmiyordu. Duraklar
              //	mesafeye gore siralandigi icin ilk bulunan EN YAKIN
              //	duraktir, **EN ERKEN VARAN degil**.
              //
              // ⚠️⚠️ **OLCULDU:** aktarma sonuclarinin **%38-43**'unde en
              //	ustteki rota, TAM AYNI iki hatti kullanan daha erken
              //	varan bir yolculuktan **6-123 dakika** daha gec
              //	variyordu. Rota GECERLIYDI, sadece gereksiz yere kotu:
              //	kullanici 8 dakikalik aktarma cezasini BOSUNA odemis
              //	oluyordu. Aktarmasiz cozumun olmadigi %61'lik dilimde
              //	bu dogrudan kullanicinin gordugu ILK sonuctur.
              // ⚠️⚠️ Anahtara **YON de girer**: ayni hattin iki yonu farkli
              //	yolculuklardir.
              // ⚠️ Pahali insa (`yolAl` + `_guzergahDilimi`) donguden CIKTI;
              //    yalniz KAZANANLAR icin bir kez kosar, yani maliyet DUSER.
              final ck =
                  '${oh.hat.id}|${oh.yon}|${dh.hat.id}|${dh.yon}';
              final mevcut = enIyi[ck];
              if (mevcut != null && mevcut.varis <= varis) continue;
              enIyi[ck] = (
                o: o,
                oh: oh,
                binis: binis,
                oDk: oDk,
                oM: oM,
                enErken: enErken,
                aktD: aktD,
                inis1: inis1,
                y: y,
                yurM: yurM,
                yurDk: yurDk,
                hazir: hazir,
                dh: dh,
                binis2: binis2,
                d: d,
                inis2: inis2,
                dM: dM,
                dDk: dDk,
                varis: varis,
              );
            }
          }
        }
      }
    }
  }
  // ⚠️⚠️ **KAZANANLARI SIMDI INSA ET.** `yolAl` hat|yon basina
  //	onbellekli oldugu icin bu dongu polyline'lari YENIDEN cozmez.
  for (final k in enIyi.values) {
    final yol1 = await yolAl(k.oh.hat.id, k.oh.yon);
    final yol2 = await yolAl(k.dh.hat.id, k.dh.yon);
    sonuc.add(RotaAdayi(
      hat: k.oh.hat,
      varisDakika: k.varis,
      toplamDakika: k.varis - suAn,
      yurumeDakika: k.oDk + k.yurDk + k.dDk,
      aktarma: 1,
      bacaklar: [
        RotaBacagi(
          tur: BacakTuru.yuru,
          noktalar: [
            (enlem: baslangicEnlem, boylam: baslangicBoylam),
            (enlem: k.o.enlem, boylam: k.o.boylam),
          ],
          dakika: k.oDk,
          metre: k.oM,
          baslik: '${k.o.ad} durağına yürü',
          altBaslik: '${k.oM.round()} m · yaklaşık',
          eylem: 'Durağa kadar yürüyün',
          yer: k.o.ad,
        ),
        RotaBacagi(
          tur: BacakTuru.bekle,
          noktalar: const [],
          dakika: math.max(0, k.binis - k.enErken),
          baslik: '${UlasimVeri.saatMetni(k.binis)} kalkış',
          altBaslik: k.o.ad,
          hat: k.oh.hat,
          eylem: '${UlasimVeri.saatMetni(k.binis)} kalkışını bekleyin',
          yer: k.o.ad,
        ),
        RotaBacagi(
          tur: BacakTuru.otobus,
          noktalar: _guzergahDilimi(yol1, k.o, k.aktD),
          dakika: k.inis1 - k.binis,
          baslik: '${k.aktD.ad} durağında in',
          altBaslik: k.oh.hat.yonBaslik[k.oh.yon] ?? k.oh.hat.uzunAd,
          hat: k.oh.hat,
          eylem: '${k.oh.hat.kisaAd} ile gidin, inin:',
          yer: k.aktD.ad,
        ),
        // ⚠️⚠️⚠️ TURU 157 - **IKI GERCEK NOKTA** (denetim bulgusu).
        //	Ilk yazimda `noktalar: const []` idi ve UC ZARARI vardi:
        //	  · `_cizgiler` `length < 2` bacaklari ATLADIGI icin 1.
        //	    otobusun bittigi yer ile 2. otobusun basladigi yer
        //	    arasinda **0-150 m CIZGISIZ BOSLUK** kaliyordu - yani
        //	    turu 157'yi baslatan *"bazen boyle KOPMALAR
        //	    yasanabiliyor"* sikayetinin YENI BIR ORNEGI. Ikinci
        //	    otobusun TURKUAZ olmasi boslugu daha da gorunur yapardi.
        //	  · `ilerlet` bos bacaklari ATLADIGI icin "Aktarma icin
        //	    yuruyun" adimi takipte HIC AKTIF OLMUYOR; kullanici
        //	    inince kart aninda ikinci otobusu gosteriyordu.
        //	  · `_adimaGit` kamerayi o adima TASIYAMIYORDU.
        // ⚠️⚠️ Kota `aktarmaYurumesi` bayragiyla korunur (o serhe bak):
        //	gercek noktalar Google Routes cagrisi URETMEZ.
        if (k.y.id != k.aktD.id)
          RotaBacagi(
            tur: BacakTuru.yuru,
            noktalar: [
              (enlem: k.aktD.enlem, boylam: k.aktD.boylam),
              (enlem: k.y.enlem, boylam: k.y.boylam),
            ],
            dakika: k.yurDk,
            metre: k.yurM,
            baslik: '${k.y.ad} durağına yürü',
            altBaslik: '${k.yurM.round()} m · aktarma',
            eylem: 'Aktarma için yürüyün',
            yer: k.y.ad,
            aktarmaYurumesi: true,
          ),
        RotaBacagi(
          tur: BacakTuru.bekle,
          dakika: math.max(0, k.binis2 - k.hazir),
          noktalar: const [],
          baslik: '${UlasimVeri.saatMetni(k.binis2)} kalkış',
          altBaslik: k.y.ad,
          hat: k.dh.hat,
          eylem: '${UlasimVeri.saatMetni(k.binis2)} kalkışını bekleyin',
          yer: k.y.ad,
        ),
        RotaBacagi(
          tur: BacakTuru.otobus,
          noktalar: _guzergahDilimi(yol2, k.y, k.d),
          dakika: k.inis2 - k.binis2,
          baslik: '${k.d.ad} durağında in',
          altBaslik: k.dh.hat.yonBaslik[k.dh.yon] ?? k.dh.hat.uzunAd,
          hat: k.dh.hat,
          eylem: '${k.dh.hat.kisaAd} ile gidin, inin:',
          yer: k.d.ad,
        ),
        RotaBacagi(
          tur: BacakTuru.yuru,
          noktalar: [
            (enlem: k.d.enlem, boylam: k.d.boylam),
            (enlem: varisEnlem, boylam: varisBoylam),
          ],
          dakika: k.dDk,
          metre: k.dM,
          baslik: 'Varışa yürü',
          altBaslik: '${k.dM.round()} m · yaklaşık',
          eylem: 'Varışa kadar yürüyün',
          yer: varisAd.isEmpty ? 'Varış' : varisAd,
        ),
      ],
    ));
  }
  return sonuc;
}
/// Kazanan adaylarin YURUME bacaklarini gercek yol agi cizgisiyle degistirir.
///
/// ⚠️ Rota alinamazsa bacak **DOKUNULMADAN** kalir (kus ucusu duz cizgi):
///    ag yoksa ya da `GOOGLE_SERVIS_KEY` tanimli degilse ozellik COKMEZ,
///    yalnizca kabalasir.
/// ⚠️ `RotaBacagi` DEGISMEZ (immutable) oldugu icin bacak YERINDE
///    degistirilemez; yeni bacak kurulup listeye YAZILIR.
Future<void> _yurumeleriZenginlestir(
  List<RotaAdayi> adaylar,
  double basEnlem,
  double basBoylam,
  double varEnlem,
  double varBoylam,
) async {
  final isler = <Future<void>>[];
  for (final a in adaylar) {
    for (var i = 0; i < a.bacaklar.length; i++) {
      final b = a.bacaklar[i];
      // ⚠️⚠️ TURU 157 - aktarma yurumesi ZENGINLESTIRILMEZ (kota).
      //	Bkz. `RotaBacagi.aktarmaYurumesi` serhi.
      if (b.tur != BacakTuru.yuru ||
          b.noktalar.length != 2 ||
          b.aktarmaYurumesi) {
        continue;
      }
      final bas = b.noktalar.first;
      final var_ = b.noktalar.last;
      final sira = i;
      isler.add(() async {
        // ⚠️⚠️⚠️ TURU 157 - **KORUMA SERHTE VARDI, GOVDEDE YOKTU.**
        //
        //	Fonksiyonun serhi *"Rota alinamazsa bacak DOKUNULMADAN
        //	kalir ... ozellik COKMEZ, yalnizca kabalasir"* diyordu
        //	ama govdede **hicbir `try` yoktu**: `AdresServisi.i` ya da
        //	`yayaRotasi` firlatirsa hata `Future.wait`e, oradan
        //	`rotaAra`ya cikiyor ve **TUM ROTA ARAMASI COKUYORDU** -
        //	kullanici yalniz kabalasmis degil, HIC sonuc gormuyordu.
        //
        // ⚠️⚠️ **OLCUMDE YAKALANDI**: turu 157 aktarma olcum testinde
        //	`AdresServisi.i` -> `Geocoding()` eklenti kanali olmadigi
        //	icin *"Null check operator used on a null value"* firlatti
        //	ve `rotaAra` komple dustu. Sahada ayni sey eklenti
        //	baslatilamadiginda ya da beklenmedik bir yanit bicimide olur.
        // ⚠️ Bu projenin en sik hata sinifi: serhin anlattigi kontrolun
        //    govdede GERCEKTEN olup olmadigini dogrula.
        List<({double enlem, double boylam})>? yol;
        try {
          yol = await AdresServisi.i.yayaRotasi(
              bas.enlem, bas.boylam, var_.enlem, var_.boylam);
        } catch (_) {
          return; // bacak DOKUNULMADAN kalir: kus ucusu duz cizgi
        }
        if (yol == null || yol.length < 2) return;
        a.bacaklar[sira] = RotaBacagi(
          tur: b.tur,
          noktalar: _uclariBagla(yol, bas, var_),
          dakika: b.dakika,
          baslik: b.baslik,
          altBaslik: b.altBaslik,
          hat: b.hat,
          metre: b.metre,
          // ⚠️⚠️ TURU 156 — YENI ALANLAR DA KOPYALANMALI. Unutulsaydi
          //	yaya rotasi ZENGINLESTIRILEN bacaklarda (yani tam da
          //	kullanicinin gordugu yurume adimlarinda) eylem/yer BOS
          //	kalir ve adim karti SESSIZCE bosalirdi.
          eylem: b.eylem,
          yer: b.yer,
          aktarmaYurumesi: b.aktarmaYurumesi,
        );
      }());
    }
  }
  await Future.wait(isler);
}

/// ⚠️⚠️⚠️ TURU 155 — **GERCEK UCLARI CIZGIYE GERI EKLER.**
///
///	Kullanici sahada gordu: *"rota cizdiginde mesela EVDEN DISARIYA
///	shape cizmiyor"* + *"Yandex'te kesikler TAM YOLUN ICINDE, yurume
///	biterken otobus duraginda bitiyor; BIZIMKI DIREK USTUNDE"*.
///
/// ⚠️⚠️ **KOK NEDEN: Google Routes uclari YOLA SNAP EDER.** Donen
///	polyline kullanicinin GERCEK koordinatindan degil, ona en yakin
///	YOL noktasindan baslar; duragin da tam ustunde bitmez. Aradaki
///	boslukta HICBIR SEY cizilmedigi icin cizgi "evden cikmiyor" ve
///	duraga "degmiyor" gorunuyordu.
///
///	Yandex ve Google Maps de ayni seyi yapar: gercek konumdan yola
///	KISA BIR BAGLAYICI cizerler. Burada da uclar cizginin basina/
///	sonuna geri konuyor.
///
/// ⚠️⚠️⚠️ TURU 157 - **ESIK 5 m -> 0,5 m** (kullanici sahada gordu:
///	*"bazen boyle KOPMALAR yasanabiliyor, bu normal mi?"*).
///
///	**OLCULDU (kullanicinin ekran goruntusunden):** yurume bacagi
///	"43 m" kalmisti ve ekranda ~913 px yer kapliyordu, yani
///	**~21 piksel/metre**. Yurume cizgisinin ucu ile durak pini
///	arasindaki bosluk ~83 px = **~4 metre**.
///
/// ⚠️⚠️ **KOK NEDEN: esigin KENDISI.** Google Routes ucu yola SNAP
///	eder; durak yolun kenarindaysa snap mesafesi 5 m'nin ALTINDA
///	kalir, kosul saglanmaz ve gercek uc EKLENMEZ. Cizgi duraga
///	4 metre uzakta biter. Sehir olceginde (z13-15) bu 1-2 piksel
///	olur ve GORUNMEZ; **navigasyon zoomunda (z19-20) 80+ piksel
///	olur ve APACIK bir kopma gibi durur**.
/// ⚠️⚠️ Yani esik SABIT METRE, gorulen bosluk ise ZOOM'A BAGLI —
///	ikisi ayni birimde olmadigi icin 5 m "kucuk" sanilmisti.
///
/// ⚠️ 0,5 m: tek amaci AYNI noktayi iki kez eklememek. Ayni koordinat
///    iki kez girse bile zarari YOK (`yapistir` sifir uzunluklu segmenti
///    `l2 > 0` kapisiyla atliyor) - yani esik guvenli tarafta KUCUK olmali.
/// ⚠️⚠️ YAPMA: esigi tekrar buyutme. "Gereksiz dugum" korkusu olculdu:
///	en fazla IKI fazladan nokta, cizim maliyeti SIFIRA yakin.
/// ⚠️ Otobus bacaginda bu GEREKMEZ: `_guzergahDilimi` binis ve inis
///    duraklarini ZATEN basa/sona koyuyor (bkz. o fonksiyon).
List<({double enlem, double boylam})> _uclariBagla(
  List<({double enlem, double boylam})> yol,
  ({double enlem, double boylam}) bas,
  ({double enlem, double boylam}) varis,
) {
  const esik = 0.5;
  final ilk = yol.first;
  final son = yol.last;
  return [
    if (UlasimVeri.kabaMetre(bas.enlem, bas.boylam, ilk.enlem, ilk.boylam) >
        esik)
      bas,
    ...yol,
    if (UlasimVeri.kabaMetre(
            varis.enlem, varis.boylam, son.enlem, son.boylam) >
        esik)
      varis,
  ];
}

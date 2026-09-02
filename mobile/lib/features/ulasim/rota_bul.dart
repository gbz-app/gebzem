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
  });

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
  });

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
          final n = math.min(oh.kalkislar.length, dh.kalkislar.length);
          int? binis;
          int? inis;
          final enErken = suAn + oDk;
          for (var j = 0; j < n; j++) {
            final b = oh.kalkislar[j];
            final i = dh.kalkislar[j];
            if (b < enErken) continue;
            if (i <= b) continue;
            // ⚠️ 180 dk tavani: ayni hattin gunun farkli seferlerinin
            //    yanlis eslesmesini eler.
            if (i - b > 180) continue;
            binis = b;
            inis = i;
            break;
          }
          if (binis == null || inis == null) continue;

          final yol = await UlasimVeri.i.guzergah(oh.hat.id, oh.yon);
          final dilim = _guzergahDilimi(yol, o, d);
          final varis = inis + dDk;


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

  // En erken varis ONCE; ayni hattin tekrarlari elenir.
  adaylar.sort((a, b) => a.varisDakika.compareTo(b.varisDakika));
  final gorulen = <String>{};
  final sonuc = <RotaAdayi>[];
  for (final a in adaylar) {
    if (!gorulen.add(a.hat.id)) continue;
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
      if (b.tur != BacakTuru.yuru || b.noktalar.length != 2) continue;
      final bas = b.noktalar.first;
      final var_ = b.noktalar.last;
      final sira = i;
      isler.add(() async {
        final yol = await AdresServisi.i.yayaRotasi(
            bas.enlem, bas.boylam, var_.enlem, var_.boylam);
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

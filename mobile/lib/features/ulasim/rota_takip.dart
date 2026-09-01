/// ⚠️⚠️⚠️ TURU 151 — **ROTA TAKIBI** (kullanici sorusu: *"telefonla
/// yurudugumde ARKAMDAN SHAPE GIDECEK MI?"* — cevap EVET, burasi onun
/// matematigi).
///
/// Kullanicinin tarifi (turu 150'de, birebir): *"basla dediginde otobus ve
/// varis HAFIF SONECEK, ilk duraga goturcez, sonra otobus, sonra durak;
/// gittikce ARKADAKI SHAPE SILINECEK. Navigasyon olmayacak, sadece KUS
/// BAKISI."*
///
/// ⚠️ **BU DOSYA SAF DART**: Flutter'a, haritaya, konum eklentisine BAGLI
///	DEGIL. Sebep: mantik ancak boyle BIRIM TESTIYLE kanitlanabilir
///	(`test/rota_takip_test.dart`). Bu projede "olculmeden dogru sayilan
///	formul" defalarca sahaya cikti.
library;

import 'dart:math' as math;

/// Bir noktanin polyline uzerindeki izdusumu.
class Izdusum {
  const Izdusum({
    required this.segment,
    required this.t,
    required this.enlem,
    required this.boylam,
    required this.uzaklikM,
  });

  /// Izdusumun dustugu segmentin BASLANGIC indeksi (`noktalar[segment]` ->
  /// `noktalar[segment + 1]`).
  final int segment;

  /// Segment icindeki oran (0 = bas, 1 = son).
  final double t;

  final double enlem;
  final double boylam;

  /// Noktanin cizgiye METRE cinsinden uzakligi.
  final double uzaklikM;
}

/// Bir noktayi cok segmentli bir polyline'a **yapistirir** (snap).
///
/// ⚠️⚠️ **METRIK DUZLEME GECILIR.** Ham derece ile calisilsaydi Gebze
///	enleminde (40,8°) boylam ekseni **%24 yanlis** olceklenir ve izdusum
///	YANLIS segmente kayardi. (Ayni hata sunucu tarafinda turu 85b'de
///	SAHAYA CIKTI: kaba kutu boylamda `cos(enlem)` uygulamiyordu.)
///
/// ⚠️⚠️ **ARAMA PENCERESI ZORUNLU** ([basSegment], [pencere]).
///	⚠️ Bu pencere ile `ilerlet` icindeki `math.max(basSeg, ...)`
///	   **BIRBIRININ YEDEGI**: ikisinden biri kaldirilinca
///	   monotonluk yine korunuyor (bozarak olculdu). Ikisi de
///	   KALIR - biri gelecekte degisirse oteki tutar.
///	Kucuk bir sehirde hatlar kendi uzerine doner; GLOBAL "en yakin
///	segment" araması, ayni caddeden ikinci kez gecen bir rotada
///	kullaniciyi **ILERIYE SICRATIR** ya da geri atar. Arama yalnizca
///	`[basSegment, basSegment + pencere)` araliginda yapilir — yani
///	ilerleme **MONOTON** olur.
///	⚠️ YAPMA: pencereyi kaldirip tum cizgiyi taramaya donme.
///
/// ⚠️⚠️ **SIFIRA BOLME KAPISI - DURUST NOT (OLCULDU):** GTFS
///	sekillerinde ARDISIK TEKRARLI nokta gercekten var (ayni
///	koordinat iki kez) ve orada `l2 = 0` olur.
///
///	Ilk yazimda buraya *"kapi olmasaydi t = NaN olur ve NaN her
///	karsilastirmadan sessizce duserdi"* yazmistim. **BOZARAK
///	DENEDIM: kapiyi kaldirinca test YESIL KALDI.** Sebebi
///	olculdu: `num.clamp` `<` degil **`compareTo`** kullanir ve
///	`double.compareTo`da NaN EN BUYUK sayilir, yani
///	`NaN.clamp(0.0, 1.0)` **1.0** doner (dart ile dogrulandi).
///	Yani NaN'i zaten `clamp` etkisizlestiriyor.
///
///	Kapi YINE DE DURUYOR: (a) niyeti belgeliyor, (b) `clamp`
///	bir gun kaldirilirsa `d = NaN` olur ve **o zaman** gercekten
///	`NaN < enAz` daima false oldugu icin segment HIC secilmez.
///	⚠️ Bunu "test ediliyor" diye YAZMA - edilmiyor, cunku
///	   `clamp` onu gormeden yutuyor.
Izdusum? yapistir(
  List<({double enlem, double boylam})> yol,
  double enlem,
  double boylam, {
  int basSegment = 0,
  int pencere = 40,
}) {
  if (yol.length < 2) return null;
  final son = math.min(yol.length - 1, basSegment + pencere);
  if (basSegment >= son) return null;

  final kx = 111320.0 * math.cos(yol.first.enlem * math.pi / 180);
  const ky = 111320.0;
  final px = boylam * kx;
  final py = enlem * ky;

  var enIyiSeg = basSegment;
  var enIyiT = 0.0;
  var enAz = double.infinity;

  for (var i = basSegment; i < son; i++) {
    final ax = yol[i].boylam * kx;
    final ay = yol[i].enlem * ky;
    final bx = yol[i + 1].boylam * kx;
    final by = yol[i + 1].enlem * ky;
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
      enIyiSeg = i;
      enIyiT = t;
    }
  }

  final a = yol[enIyiSeg];
  final b = yol[enIyiSeg + 1];
  return Izdusum(
    segment: enIyiSeg,
    t: enIyiT,
    enlem: a.enlem + (b.enlem - a.enlem) * enIyiT,
    boylam: a.boylam + (b.boylam - a.boylam) * enIyiT,
    uzaklikM: math.sqrt(enAz),
  );
}

/// Iki nokta arasi kaba mesafe (metre) — **`cos(enlem)` duzeltmeli**.
double metre(double aEn, double aBoy, double bEn, double bBoy) {
  final kx = 111320.0 * math.cos(aEn * math.pi / 180);
  final dx = (bBoy - aBoy) * kx;
  final dy = (bEn - aEn) * 111320.0;
  return math.sqrt(dx * dx + dy * dy);
}

/// Bir polyline'in [iz] noktasindan SONRAKI parcasi — yani **KALAN yol**.
///
/// ⚠️ Ilk oge izdusumun KENDISI: cizgi kullanicinin BULUNDUGU yerden
///    baslasin, bir onceki koseden degil. Aksi halde cizgi kullanicinin
///    ARKASINDA kalan kisa bir kuyruk birakirdi.
List<({double enlem, double boylam})> kalanYol(
  List<({double enlem, double boylam})> yol,
  Izdusum iz,
) {
  if (yol.length < 2) return yol;
  return [
    (enlem: iz.enlem, boylam: iz.boylam),
    ...yol.sublist(math.min(iz.segment + 1, yol.length)),
  ];
}

/// Bir polyline'in toplam uzunlugu (metre).
double yolUzunlugu(List<({double enlem, double boylam})> yol) {
  var t = 0.0;
  for (var i = 0; i < yol.length - 1; i++) {
    t += metre(yol[i].enlem, yol[i].boylam, yol[i + 1].enlem, yol[i + 1].boylam);
  }
  return t;
}

/// [iz] noktasindan yolun SONUNA kalan mesafe (metre).
double kalanMetre(
  List<({double enlem, double boylam})> yol,
  Izdusum iz,
) =>
    yolUzunlugu(kalanYol(yol, iz));

/// Kullanicinin rotadan "ciktigi" sayilacagi uzaklik.
///
/// ⚠️ 60 m: sehir ici GPS dogrulugu iyi kosulda ~5-10 m, bina aralarinda
///	20-40 m'ye cikiyor. Esik daha DAR olsaydi normal GPS gurultusunde
///	kullaniciya surekli "rotadan ciktin" denirdi.
/// ⚠️ Esik ASILDIGINDA ilerleme DURDURULUR ama rota SILINMEZ: kullanici
///	geri dondugunde kaldigi yerden devam etmeli.
const double kRotaDisiM = 60;

/// Bir bacagin "tamamlandi" sayilacagi kalan mesafe.
///
/// ⚠️ 25 m: GPS dogrulugundan BUYUK olmak zorunda, yoksa kullanici duraga
///	varmis olsa bile adim ILERLEMEZ. Daha genis olsaydi (ornegin 60 m)
///	kisa bir yurume bacagi HIC baslamadan biterdi.
const double kBacakBittiM = 25;

/// Rotanin bir anlik takip DURUMU.
///
/// ⚠️ Bu sinif **DEGISMEZ (immutable)**: her konum guncellemesinde YENISI
///    uretilir. Yerinde degistirilseydi arayuz "deger degismedi" sanip
///    yeniden cizmezdi (bu ekranda `_odak`/`_zoom` ile ayni ders).
class TakipDurumu {
  const TakipDurumu({
    required this.bacak,
    required this.segment,
    required this.kalanM,
    required this.rotaDisi,
    required this.bitti,
    this.izEnlem,
    this.izBoylam,
  });

  /// Su an hangi bacaktayiz (aday.bacaklar indeksi).
  final int bacak;

  /// O bacagin polyline'inda kacinci segmentteyiz (arama penceresi tabani).
  final int segment;

  /// Bu bacagin sonuna kalan mesafe (metre).
  final double kalanM;

  /// Kullanici cizgiden [kRotaDisiM]'den uzak mi?
  final bool rotaDisi;

  /// Tum rota tamamlandi mi?
  final bool bitti;

  final double? izEnlem;
  final double? izBoylam;

  static const TakipDurumu basla = TakipDurumu(
    bacak: 0,
    segment: 0,
    kalanM: double.infinity,
    rotaDisi: false,
    bitti: false,
  );
}

/// Yeni bir konum geldiginde takip durumunu ILERLETIR.
///
/// [bacakYollari] her bacagin polyline'i (bekleme bacaginda BOS liste).
///
/// ⚠️⚠️ **MONOTONLUK**: `segment` ASLA geri gitmez. GPS gurultusu
///	kullaniciyi bir kare geri atsa bile cizilen "kalan yol" geri
///	UZAMAZ — ekranda cizginin ileri geri oynamasi, kullanicinin
///	guvenini tumden bitirir.
///
/// ⚠️⚠️ **BOS (bekleme) BACAKLARI ATLANIR**: `BacakTuru.bekle` bacaginin
///	polyline'i YOK. Atlanmasaydi takip orada KILITLENIRDI (yapistirma
///	hep null doner, ilerleme hic olmaz).
///
/// ⚠️ Rota disindayken (`rotaDisi`) **ilerleme yazilmaz** ama durum yine
///    dondurulur: arayuz kullaniciya "rotaya don" diyebilsin.
TakipDurumu ilerlet(
  TakipDurumu onceki,
  List<List<({double enlem, double boylam})>> bacakYollari,
  double enlem,
  double boylam,
) {
  if (onceki.bitti || bacakYollari.isEmpty) return onceki;

  var bacak = onceki.bacak;
  // Bos bacaklari (bekleme) ATLA.
  while (bacak < bacakYollari.length && bacakYollari[bacak].length < 2) {
    bacak++;
  }
  if (bacak >= bacakYollari.length) {
    return const TakipDurumu(
      bacak: 0,
      segment: 0,
      kalanM: 0,
      rotaDisi: false,
      bitti: true,
    );
  }

  final yol = bacakYollari[bacak];
  final basSeg = bacak == onceki.bacak ? onceki.segment : 0;
  final iz = yapistir(yol, enlem, boylam, basSegment: basSeg);
  if (iz == null) return onceki;

  if (iz.uzaklikM > kRotaDisiM) {
    return TakipDurumu(
      bacak: bacak,
      segment: basSeg,
      kalanM: onceki.kalanM,
      rotaDisi: true,
      bitti: false,
      izEnlem: onceki.izEnlem,
      izBoylam: onceki.izBoylam,
    );
  }

  final kalan = kalanMetre(yol, iz);

  // ── BACAK BITTI MI? ──
  if (kalan <= kBacakBittiM) {
    var sonraki = bacak + 1;
    while (sonraki < bacakYollari.length &&
        bacakYollari[sonraki].length < 2) {
      sonraki++;
    }
    if (sonraki >= bacakYollari.length) {
      return TakipDurumu(
        bacak: bacak,
        segment: iz.segment,
        kalanM: 0,
        rotaDisi: false,
        bitti: true,
        izEnlem: iz.enlem,
        izBoylam: iz.boylam,
      );
    }
    return TakipDurumu(
      bacak: sonraki,
      segment: 0,
      kalanM: yolUzunlugu(bacakYollari[sonraki]),
      rotaDisi: false,
      bitti: false,
      izEnlem: iz.enlem,
      izBoylam: iz.boylam,
    );
  }

  return TakipDurumu(
    bacak: bacak,
    // ⚠️ MONOTON: segment geri GITMEZ.
    segment: math.max(basSeg, iz.segment),
    kalanM: kalan,
    rotaDisi: false,
    bitti: false,
    izEnlem: iz.enlem,
    izBoylam: iz.boylam,
  );
}

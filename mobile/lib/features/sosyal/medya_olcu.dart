/// ⚠️⚠️⚠️ TURU 82 — GONDERI MEDYASININ OLCULERI. **TEK KAYNAK.**
///
/// Kullanici **DORT KEZ** sikayet etti. Turu 82'deki tarifi:
/// *"resimler genis, SOL SAG BIRSEYLER DOLUYOR; tek resim galeri seklini
/// defalarca attim ama AYNI, degismemis"*.
///
/// ═══════════ TURU 81'IN HATASI: KUTU ORANI MEDYADAN SAPIYORDU ═══════════
///
/// Turu 81 modeli dogruydu (yukseklik -> genislik) ama **tavan davranisi
/// YANLISTI**: genislik kolona takildiginda YUKSEKLIK SABIT KALIYORDU.
///
///     4:5 fotograf, tavan 270dp, kolon 366dp
///       genislik = 270 * 0.80 = 216dp        <- kolonun YALNIZ %59'u
///       kutu     = 216 x 270                 <- SAGINDA 150dp BOSLUK
///
/// Kullanicinin gordugu "sol sag birseyler doluyor" TAM BUYDU. Ustelik
/// yukseklik tavani (%32) o kadar dusuktu ki **hemen her fotograf** dar
/// kaliyordu — yani "bazisi dar bazisi genis" etkisi de OLUSMUYORDU.
///
/// ═══════════ OLCUM (kullanicinin Threads ekran goruntusu) ═══════════
///
/// Tek fotograf: **genisligin ~%80'i · ekran yuksekliginin ~%50'si** ·
/// en-boy ~0.73. Yani Threads'te 4:5 ve daha GENIS her fotograf **kolonu
/// DOLDURUR**; yalnizca 4:5'ten DAHA DIKEY olanlar (9:16 video gibi) darlasir.
/// Turu 81'in %32 tavani bunun yarisiydi.
///
/// ═══════════ DOGRU MODEL ═══════════
///
///     w = min(kolon, tavan * enBoy)
///     h = w / enBoy                  <- ⚠️ YUKSEKLIK GENISLIKTEN TURER
///
/// Ikinci satir turu 81'de YOKTU ve butun hata oradaydi. Sonuc:
///
///     16:9  ->  w=kolon      h=kolon/1.78   GENIS ve KISA
///     1:1   ->  w=kolon      h=kolon        KARE
///     4:5   ->  w=kolon      h=kolon/0.8    KOLONU DOLDURUR  (en yaygin)
///     9:16  ->  w=tavan*.56  h=tavan        DAR ve UZUN
///
/// **Kutunun orani her zaman medyanin oranina ESIT** -> `cover` HICBIR ZAMAN
/// kirpmaz, `contain` olsaydi cikacak siyah bant da YOKTUR. Kullanicinin
/// istedigi "bazisi dar bazisi genis" etkisi de burada DOGAL olarak cikar.
///
/// ⚠️ REDDEDILEN COZUMLER (bir daha onerilmesin):
///   · Yukseklik sabit + genislik tavani -> turu 81'in hatasi (yandaki bosluk).
///   · Genislik sabit + yukseklik tavani -> turu 80'in hatasi (%41-51 kirpma).
///   · Tek bir `enBoy` sabiti -> tum medyayi ayni orana zorlar, "bazisi dar
///     bazisi genis" etkisi OLUSMAZ.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// En yaygin telefon fotografi orani (dikey 4:5). Tavan bundan turetilir.
const double _kYayginOran = 0.8;

/// Medya kutusunun YUKSEKLIK TAVANI.
///
/// ⚠️⚠️ TAVAN **KOLONDAN** TURER, ekrandan DEGIL. Sebep olculdu: ekran
///    yuzdesine baglandiginda (ilk turu 82 denemesi, %54) kucuk telefonlarda
///    tavan kolonun ihtiyacinin ALTINDA kaliyor ve **4:5 bir fotograf kolonun
///    yalnizca %82'sini** dolduruyordu — yani kullanicinin sikayet ettigi
///    YANDAKI BOSLUK kucuk cihazlarda GERI GELIYORDU:
///
///      390x844  kolon=366  tavan=456 -> 4:5 w=365  (%100)  ✓
///      375x667  kolon=351  tavan=360 -> 4:5 w=288  (%82)   ✗ BOSLUK
///      360x640  kolon=336  tavan=346 -> 4:5 w=276  (%82)   ✗ BOSLUK
///
///    `kolon / 0.8` tavani, **4:5'in kolonu tam doldurmasi** demektir; 4:5'ten
///    daha DIKEY olan (9:16 video gibi) medya darlasir — kullanicinin istedigi
///    "bazisi dar bazisi genis" etkisi TAM OLARAK budur.
///
/// ⚠️ Ikinci terim (`ekran * 0.60`) EMNIYET TAVANI: kisa ve genis ekranlarda
///    (yatay tablet, katlanabilir) `kolon/0.8` ekrani asabilirdi. Turu 80'in
///    "cok uzun" sikayeti tam bu sinifin hatasiydi.
/// ⚠️ YAPMA: tavani sabit dp yapma (turu 80: ayni gonderi 360x640'ta ekranin
///    %65'ini, 800x1280'de %107'sini kapliyordu).
/// ⚠️ YAPMA: tavani yalniz ekran yuzdesine baglama (yukaridaki tablo).
double medyaTavani(BuildContext c, double kolonGenislik) => math.min(
  kolonGenislik / _kYayginOran,
  MediaQuery.sizeOf(c).height * 0.60,
);

/// Kose yaricapi (Threads gorunumu: belirgin yuvarlak kose).
const double kMedyaYaricap = 18;

/// Kartin GENISLIK tavani (tablet/genis ekran).
///
/// ⚠️ Tavan `GonderiKarti`in KENDI kokune konur, UC cagirana ayri ayri DEGIL
///    (akis_ekrani, gonderi_detay, kaydedilenler) — ucu de unutulur ve drift eder.
const double kKolonTavani = 560;

/// Coklu galeride kutular arasi bosluk.
const double kGaleriAra = 8;

/// Coklu galeride bir ogenin kaplayabilecegi EN FAZLA kolon orani.
///
/// ⚠️ 1.0'in ALTINDA olmasi ZORUNLU: ekran goruntusundeki gibi **sonraki
///    medyanin sagdan SARKMASI** galeride birden fazla oge oldugunun TEK
///    gorsel ipucudur (nokta gostergesi YOK — turu 76b karari).
const double kGaleriOgeOrani = 0.78;

/// Medya kutusunun `BoxFit` degeri.
///
/// ⚠️⚠️ TEK MEDYADA `cover` **KIRPMAZ**: kutunun orani medyanin oranina ESIT
///    kuruluyor (bkz. [medyaKutusu]). `cover` yalnizca yuvarlama farklarindan
///    dogan yarim pikselleri doldurur — `contain` olsaydi o yarim piksel
///    SIYAH CIZGI olarak gorunurdu.
/// ⚠️ ISTISNA — COKLU GALERI: satir yuksekligi ortak oldugu icin **4:5'ten
///    GENIS ogeler kirpilir** (bkz. [galeriSatirYuksekligi]). Bu bilincli bir
///    odundur; kirpilan oge tam ekranda tam haliyle acilir.
///    ⚠️ Eski serh "cover ARTIK HICBIR ZAMAN kirpmaz" diyordu — denetim bunu
///       yakaladi: iddia TEK MEDYA icin dogru, GALERI icin YANLISTI.
///       (Bu projede tekrarlayan sinif: "serhin anlattigi kontrol govdede yok".)
const BoxFit kMedyaDolgu = BoxFit.cover;

/// Bir medyanin kutu olculeri: **orani KORUYARAK** tavana ve kolona sigdirir.
///
/// ⚠️ [enBoy] = genislik / yukseklik (`Gonderi.enBoy(i)`; olcu yoksa 4/5).
/// ⚠️ Donen kutunun orani DAIMA [enBoy]'a esittir — bu, kirpma olmamasinin
///    YAPISAL garantisidir. ⚠️ YAPMA: cagiran tarafta yuksekligi ayrica
///    sabitleme (turu 81 hatasi tam olarak buydu).
/// ⚠️ ALT SINIR 96dp: bozuk/asiri dar bir oran kutuyu goze gorunmez yapmasin.
({double w, double h}) medyaKutusu(
  double tavan,
  double enBoy,
  double kolonGenislik,
) {
  // Bozuk olcuye karsi savunma: 0/negatif/NaN oran gelirse 4:5'e dus.
  final oran = (enBoy.isFinite && enBoy > 0) ? enBoy : 0.8;
  final w = math.max(math.min(kolonGenislik, tavan * oran), 96.0);
  return (w: w, h: w / oran);
}

/// COKLU galeride TUM ogelerin PAYLASTIGI satir yuksekligi.
///
/// ⚠️⚠️⚠️ BU FONKSIYON BIR REGRESYONU KAPATIR — **`min` ILE HESAPLAMA.**
///
/// Ilk turu 82 denemesi satir yuksekligini ogelerden turetiyordu:
///     satirY = min_i( medyaKutusu(...).h )
/// Denetim bunu iki bagimsiz mercekle yakaladi ve matematigi soyle:
/// `h_i = min(tavan, ogeTavani / oran_i)` ifadesi **oran BUYUDUKCE KUCULUR**,
/// yani `min` DAIMA EN GENIS ogeye aittir. Sonuc: galeriye giren **TEK bir
/// yatay fotograf BUTUN GALERIYI COKERTIYORDU** (390x844'te olculdu):
///
///     hepsi 4:5              -> ogeler 285 x 357     dogru
///     4:5 + 4:5 + 16:9       -> 4:5 ogeler 128 x 160  (%35 olcek!)
///     9:16 + panorama 1.91   -> dikey oge  75 x 149
///
/// Yani kullanicinin DORT KEZ sikayet ettigi "gorseller kucuk, yanlarda
/// bosluk" tablosu karma galeride GERI GELIYORDU — ustelik turu 81'e gore
/// GERILEME (turu 81'in yuksekligi icerikten BAGIMSIZ sabitti).
///
/// ═══ DOGRU KURAL: yukseklik ICERIKTEN BAGIMSIZ ═══
///
/// `ogeTavani / 0.8` secildi, yani tek-medya kuralinin galeri karsiligi:
/// **4:5 bir oge KENDI genislik tavanini tam doldurur.** Kolon ve oge tavani
/// ayni katsayidan turedigi icin (`ogeTavani = kolon * 0.78`,
/// `tavan = kolon / 0.8`) bu deger dogal olarak `tavan * 0.78`e esittir.
///
///     4:5   -> w = ogeTavani        oran KORUNUR (kirpma yok)
///     9:16  -> w = ogeTavani * 0.70 oran KORUNUR, DAR (istenen etki)
///     1:1   -> genislik tavana takilir, `cover` KIRPAR
///     16:9  -> genislik tavana takilir, `cover` KIRPAR
///
/// ⚠️ 4:5'ten GENIS ogelerin kirpilmasi BILINCLI ODUN: sabit yukseklikli bir
///    satirda 16:9 ile 9:16 ayni anda kirpilmadan DURAMAZ (yukseklikleri 3.2
///    kat ayrisir). Kirpilan oge tam ekranda tam haliyle acilir.
/// ⚠️ Ikinci terim (`tavan`) kisa ekranlarda emniyet: `medyaTavani` zaten
///    ekranin %60'ini asmama garantisini tasir, satir onu asmamali.
/// ⚠️ YAPMA: yuksekligi tekrar ogelerden (min/max/ilk oge) turetme — hangisi
///    olursa olsun BIR OGE DIGERLERININ OLCEGINI BELIRLER ve cokme geri gelir.
double galeriSatirYuksekligi(double tavan, double ogeTavani) =>
    math.min(ogeTavani / _kYayginOran, tavan);

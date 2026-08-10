/// ⚠️⚠️⚠️ TURU 81 — GONDERI MEDYASININ OLCULERI. **TEK KAYNAK.**
///
/// Kullanici UC KEZ sikayet etti. Son ve NET tarifi (Threads ekran goruntusu):
/// *"tek fotograflarda BAZILARI GENISLIK DAHA AZ BAZILARI BUYUK, bunun mantigi
/// nedir, BIZIM DE BOYLE OLMASI GEREKIYOR"*.
///
/// ═══════════════ MODEL DEGISTI ═══════════════
///
/// ESKI (turu 80):  GENISLIK sabit  ->  yukseklik hesaplanir  ->  `cover` KIRPAR
/// YENI (turu 81):  YUKSEKLIK sabit ->  GENISLIK ORANDAN gelir ->  KIRPMA YOK
///
/// Threads'in yaptigi budur ve kullanicinin gordugu "bazisi dar bazisi genis"
/// etkisi tam olarak bundan dogar:
///
///     dikey  9:16  -> genislik = 320 * 0.5625 = 180dp   (DAR)
///     dikey  4:5   -> genislik = 320 * 0.80   = 256dp
///     kare   1:1   -> genislik = 320 * 1.00   = 320dp
///     yatay  16:9  -> genislik = 320 * 1.78   = 569dp -> KOLON TAVANINA kirpilir
///
/// ═══════════════ ON KOSUL: ORAN BILINMELI ═══════════════
///
/// Bu model medyanin GERCEK en-boyunu bilmeyi gerektirir.
/// `media_assets.width/height` sutunlari migration **015'ten beri VARDI** ama
/// **17 yukleme cagrisinin HICBIRI deger gecmiyordu** ve gonderi sorgulari da
/// DONDURMUYORDU — yani sutun bastan beri OLUYDU ve akis KIRPMAK ZORUNDAYDI.
/// Turu 81'de zincirin ucu birden baglandi:
///   1. `MedyaServisi.yukle()` olcuyu KENDI ICINDE alir (cagri yerleri degismedi),
///   2. `medyaTurleri` sabiti `media_boyut` ("WxH") dondurur (7 sorgu birden),
///   3. `Gonderi.enBoy(i)` orani verir, bu dosya olculeri hesaplar.
///
/// ⚠️ REDDEDILEN COZUMLER (bir daha onerilmesin):
///   · Yalniz `enBoy` sabitini degistirmek — tum medyayi AYNI orana zorlar,
///     yani kullanicinin istedigi "bazisi dar bazisi genis" ETKISI OLUSMAZ.
///   · `cover` yerine `contain` — kutu orani medya oranindan farkli oldugu
///     surece SIYAH BANT cikar; artik kutu orani medyaya ESIT oldugu icin
///     `cover` zaten kirpmiyor (bkz. `kMedyaDolgu`).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Medya kutusunun SABIT YUKSEKLIGI — modelin cekirdegi.
///
/// ⚠️ Ekran yuksekliginden turer ki kutu her cihazda AYNI EKRAN YUZDESINI
///    kaplasin (turu 80'de olculdu: sabit oran kullanildiginda ayni gonderi
///    360x640'ta ekranin %65'ini, 800x1280'de %107'sini kapliyordu).
/// ⚠️ `clamp` SINIRLARI: kucuk telefonda "minicik", tablette "devasa" olmasin.
///    Turu 80'in olculmus degerleri KORUNDU — kullanici o yuksekligi
///    ("cok uzun degil") ONAYLAMISTI; degisen yalnizca GENISLIGIN nasil
///    turetildigi.
double medyaYuksekligi(BuildContext c) =>
    (MediaQuery.sizeOf(c).height * 0.32).clamp(210.0, 340.0);

/// Kose yaricapi (Threads gorunumu: belirgin yuvarlak kose).
const double kMedyaYaricap = 18;

/// Kartin GENISLIK tavani (tablet/genis ekran).
///
/// ⚠️ Yukseklik tavani TEK BASINA tablette asiri YATAY bir kutu birakir ve
///    776dp genisliginde METIN SATIRI OKUNMAZ.
/// ⚠️ Tavan `GonderiKarti`in KENDI kokune konur, UC cagirana ayri ayri DEGIL
///    (akis_ekrani, gonderi_detay, kaydedilenler) — ucu de unutulur ve drift eder.
const double kKolonTavani = 560;

/// Coklu galeride kutular arasi bosluk.
const double kGaleriAra = 8;

/// Medya kutusunun `BoxFit` degeri.
///
/// ⚠️⚠️ `cover` KALIR ama ARTIK KIRPMAZ: kutunun orani medyanin oranina ESIT
///    kuruluyor (bkz. `medyaGenisligi`). `cover` yalnizca yuvarlama
///    farklarindan dogan yarim pikselleri doldurur — `contain` olsaydi o
///    yarim piksel SIYAH CIZGI olarak gorunurdu.
/// ⚠️ Oran SINIRA TAKILDIGINDA (cok panoramik / cok uzun medya) kirpma OLUR;
///    bu bilincli bir tavandir ve kurtarma yolu vardir (fotografta karta
///    dokun, videoda sol alttaki tam ekran dugmesi).
const BoxFit kMedyaDolgu = BoxFit.cover;

/// Bir medyanin GENISLIGI: yukseklik x oran, kolon genisligiyle sinirli.
///
/// ⚠️ [enBoy] = genislik / yukseklik (`Gonderi.enBoy(i)`; olcu yoksa 4/5).
/// ⚠️ [kolonGenislik] kartin kullanilabilir genisligi. Yatay bir medya bunu
///    asarsa TAVANA oturur — o durumda (ve yalniz o durumda) `cover` kirpar.
/// ⚠️ ALT SINIR 96dp: bozuk/asiri dar bir oran kutuyu goze gorunmez yapmasin.
double medyaGenisligi(double yukseklik, double enBoy, double kolonGenislik) =>
    math.min(math.max(yukseklik * enBoy, 96.0), kolonGenislik);

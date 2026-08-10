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

/// Medya kutusunun YUKSEKLIK TAVANI.
///
/// ⚠️ Ekran yuksekliginden turer ki kutu her cihazda AYNI EKRAN YUZDESINI
///    kaplasin (turu 80'de olculdu: sabit dp kullanildiginda ayni gonderi
///    360x640'ta ekranin %65'ini, 800x1280'de %107'sini kapliyordu).
/// ⚠️ **%54** olcumden gelir: Threads'te tek fotograf ekranin ~%50'si ve o
///    fotograflar tipik olarak 4:5. 390x844'te tavan=456 -> 4:5 bir fotograf
///    366x456 cizilir, yani kolonu DOLDURUR ve ekranin %54'unu kaplar.
///    ⚠️ YAPMA: bu degeri %32'ye (turu 81) dusurme — o zaman 4:5 bile kolonun
///    yarisinda kalir ve YANDAKI BOSLUK geri gelir.
/// ⚠️ `clamp` alt siniri kucuk telefonda "minicik", ust siniri tablette
///    "devasa" olmasini engeller.
double medyaTavani(BuildContext c) =>
    (MediaQuery.sizeOf(c).height * 0.54).clamp(300.0, 520.0);

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
/// ⚠️⚠️ `cover` KALIR ama ARTIK KIRPMAZ: kutunun orani medyanin oranina ESIT
///    kuruluyor (bkz. [medyaKutusu]). `cover` yalnizca yuvarlama farklarindan
///    dogan yarim pikselleri doldurur — `contain` olsaydi o yarim piksel
///    SIYAH CIZGI olarak gorunurdu.
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

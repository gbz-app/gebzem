/// ⚠️⚠️⚠️ TURU 80 — GONDERI MEDYASININ OLCULERI. **TEK KAYNAK.**
///
/// Kullanici: *"gönderilerin video resimler çok uzun yüksekliği, sana attığım
/// bunun gibi olmalı, radüslü olması gerekiyor"* (Threads ekran goruntusu).
///
/// ═══════════════ KOK NEDEN ═══════════════
///
/// Yukseklik SADECE GENISLIKTEN turetiliyordu:
///
///     yukseklik = ogeGenislik / enBoy        // enBoy = 4/5
///
/// Ekran en-boylari cihazdan cihaza degistigi icin (360x640 = 0.563,
/// 390x844 = 0.462, tablet 800x1280 = 0.625) SABIT bir en-boy her cihazda
/// **FARKLI EKRAN YUZDESI** uretir. Olculen:
///
///     tek foto   390x844  -> 457px = ekranin %54.2
///     tek foto   360x640  -> 420px = %65.6
///     tek foto   800x1280 -> 970px = %75.8
///     tek reels  800x1280 -> 1379px = **%107.8** (ekrandan UZUN!)
///
/// Kullanicinin gonderdigi Threads ekraninda kutular ekranin **~%28-31**'i.
///
/// ═══════════════ SECILEN COZUM: YUKSEKLIK TAVANI ═══════════════
///
///     yukseklik = min(ogeGenislik / enBoy, medyaTavani(context))
///
/// Tavan EKRAN YUKSEKLIGINDEN turedigi icin ekran yuzdesi **cihazdan bagimsiz**
/// sabitlenir. `min` sayesinde dar ekranlarda kutu zaten tavanin altinda kalir
/// ve formul KENDILIGINDEN devre disi kalir (davranis degismez).
///
/// OLCULEN SONUC (tek medya): 360x640 -> 210px %32.8 · 390x844 -> 270px %32.0
/// · 414x896 -> 287px %32.0 · 430x932 -> 298px %32.0 · 800x1280 -> 340px %26.6.
/// Tumu %26.6-%32.8 bandinda.
///
/// ⚠️ REDDEDILEN COZUMLER (bir daha onerilmesin):
///   · YALNIZ `enBoy` degistirmek — yukseklik hala GENISLIGE bagli kalir,
///     yani cihazlar arasi savrulma SURER. %30 icin gereken 1.47 degeri
///     ustelik YATAY bir kutu demek ve dikey fotograflari sert kirpar.
///   · `viewportFraction` degistirmek — YALNIZ coklu medyayi etkiler, TEK
///     medyayi (en kotu vaka) HIC degistirmez. Ayrica controller'i
///     `MediaQuery`ye bagimli kilar ve turu 76b'nin "controller initState'te
///     kurulur" kuralini riske atar.
///   · Threads'in GERCEK modeli (sabit yukseklik + medyanin gercek en-boyuna
///     gore DEGISKEN genislik) — dogru model ama BU SURUMDE UYGULANAMAZ:
///     (a) `PageView` sayfalari TANIM GEREGI esit genisliktedir, degisken
///     genislik PageView'i terk etmeyi gerektirir ki turu 76b bunu ACIKCA
///     yasakladi; (b) medyanin gercek en-boyu ISTEMCIDE YOK
///     (`media_assets.width/height` sutunlari VAR ama 18 yukleme cagrisinin
///     HICBIRI deger gecmiyor — olu sutun).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Gonderi medyasinin YUKSEKLIK TAVANI.
///
/// ⚠️ `clamp` SINIRLARI ZORUNLU:
///   · ALT 210 — 360x640'ta 640*0.32 = 205px cikiyor; bunsuz kucuk telefonda
///     kutu "minicik" gorunurdu.
///   · UST 340 — tablette 1280*0.32 = 410px cikardi; 340 tavani kutuyu
///     %26.6'da tutar.
/// Kullanicinin "tablette devasa olmamali, kucuk telefonda minicik olmamali"
/// sartinin SAYISAL karsiligi tam olarak bu iki sinirdir.
double medyaTavani(BuildContext c) =>
    (MediaQuery.sizeOf(c).height * 0.32).clamp(210.0, 340.0);

/// Nominal en-boy (genislik/yukseklik). Telefonla cekilen fotograflarin cogu
/// dikey oldugu icin 4:5.
///
/// ⚠️⚠️ REELS DALI SILINDI (`tur == 'reels' ? 9/16 : 4/5`). Tavan zaten ikisini
///    de ayni degere indirdigi icin dalin AYIRT EDICI islevi kalmadi; duran bir
///    dal ileride drift kaynagi olur. Akista reels artik ayni kutuda `cover`
///    ile merkezden kirpilmis gorunur — REELS SEKMESI ETKILENMEZ (orasi kendi
///    tam ekran oynaticisini kullaniyor).
///
/// ⚠️⚠️⚠️ TURU 80b — DURUST NOT (denetim): BU SABIT **BUGUN HICBIR CIHAZDA
///    BAGLAYICI DEGIL.** `medyaYuksekligi` bir `math.min`dir ve tavan pratikte
///    HER ZAMAN kazanir: `ogeGenislik/0.8 < tavan` olabilmesi icin oge
///    genisliginin ~216dp'nin ALTINA inmesi gerekir; en dar telefonda (320dp)
///    bile tek medya ~296dp, coklu galeride (viewportFraction 0.78) ~231dp.
///    Yani sabit, `min`in ALT SINIRI olarak yalnizca TEORIK bir emniyet agidir.
///
///    ⚠️ SONUCU (bilincli kabul edilen bedel): kutunun GERCEK en-boyu tavandan
///    turer ve ~1.06-1.65 arasinda degisir; icerik `cover` cizildigi icin
///    · 4:5 dikey fotograf ~%41-51 · 9:16 video ~%58-66 KIRPILIR.
///    Bu, kullanicinin *"cok uzun"* sikayetinin kacinilmaz karsi tarafidir:
///    kutuyu ekranin %32'sinde tutup dikey icerigi TAM gostermek ayni anda
///    MUMKUN DEGIL (Threads bunu DEGISKEN GENISLIKLE cozer — bkz. yukarida
///    "REDDEDILEN COZUMLER", PageView ile uygulanamaz).
///    ⚠️ Kirpmanin KURTARMA YOLU zorunludur ve VARDIR: fotografta karta dokun
///       (`TamEkranGorsel`), videoda sol alttaki tam ekran dugmesi
///       (`TamEkranVideo`) — ikisi de `contain`. Turu 80b'ye kadar VIDEODA
///       BU YOL YOKTU, yani videonun yalniz orta seridi gorulebiliyordu.
///    ⚠️ YAPMA: kurtarma yollarindan birini kaldirma; `cover`i `contain`e
///       cevirme (yatay kutuda dikey icerik kus kadar kalir + siyah bant).
const double kMedyaEnBoy = 4 / 5;

/// Kose yaricapi.
///
/// ⚠️ 16 -> 18: yaricap kutu boyutuna GORELI algilanir; kutu 457px'den 270px'e
///    inince ayni 16px daha "keskin" gorunur. 20+ ise kucuk kutularda "hap"
///    gorunumune kayar.
const double kMedyaYaricap = 18;

/// Kartin GENISLIK tavani (tablet/genis ekran).
///
/// ⚠️ Yukseklik tavani TEK BASINA tablette 536x340'lik (en-boy 1.58) asiri
///    YATAY bir kutu birakir ve 776dp genisliginde METIN SATIRI OKUNMAZ.
/// ⚠️ Tavan `GonderiKarti`in KENDI kokune konur, UC cagirana (akis_ekrani,
///    gonderi_detay, kaydedilenler_sayfasi) ayri ayri DEGIL — ucu de unutulur
///    ve drift eder.
const double kKolonTavani = 560;

/// Yukseklik hesabinin TEK ifadesi. ⚠️ Cagiranlar bunu KENDILERI hesaplamaz.
double medyaYuksekligi(BuildContext c, double ogeGenislik) =>
    math.min(ogeGenislik / kMedyaEnBoy, medyaTavani(c));

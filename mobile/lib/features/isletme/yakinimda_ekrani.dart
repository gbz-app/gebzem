/// ⚠️⚠️⚠️ TURU 85 — "YAKINIMDA": USTTE HARITA, ALTTA KARTLAR.
///
/// Kullanici emri: *"menuye tikladigimizda acilan pencereye yakinimda
/// eklemeliyiz; ustte harita altta kartlar olacak — isletmeler, eczane vs;
/// harita uber tarzi grimsi beyaz olsun"*.
///
/// ═══════════ HARITA HAKKINDA DURUST DURUM (TURU 85b'de GUNCELLENDI) ═══════
///
/// ⚠️⚠️ **BU SERH ESKIDEN "SDK KURULU DEGIL" DIYORDU — ARTIK KURULU.**
///	Turu 85'te `google_maps_flutter` eklendi, Maps SDK'lari (Android +
///	iOS) `gebzem-app` projesinde ACILDI ve Maps'e KISITLI bir anahtar
///	uretildi. Denetim bu bayat serhi bulguladi: metin hala *"YAPMA:
///	`google_maps_flutter` ekleme"* hukmu tasiyordu, yani gelecekte biri
///	SDK'yi KALDIRMAYA calisabilirdi.
///
/// BUGUNKU DURUM:
///   · SDK KURULU ve KULLANILIYOR (`GoogleMap` asagida).
///   · ANAHTAR **REPODA DEGIL**: derleme aninda enjekte edilir (Android
///     `manifestPlaceholders`, iOS PlistBuddy -> Info.plist). Repo PUBLIC
///     oldugu icin anahtarin izlenen hicbir dosyada bulunmamasi ZORUNLU.
///   · `haritaAnahtariVar` (`--dart-define=HARITA`) derlemede anahtar
///     verilip verilmedigini soyler; verilmediyse ALTTAKI yer tutucu cizilir.
///   · Stil YEREL JSON ("uber tarzi grimsi beyaz"); CLAUDE.md `cloudMapId`
///     kullanimini yasakliyor (ucretli) — yerel stil UCRETSIZDIR.
///
/// ⚠️ YAPMA: `haritaAnahtariVar` kapisini kaldirip haritayi kosulsuz cizme.
///    Anahtarsiz derlemede harita Android'de "For development purposes only"
///    filigranli GRI kutu, iOS'ta BOS ekran olur — ozellik BOZUK gorunur.
/// ⚠️ YAPMA: anahtari koda/pubspec'e/Info.plist'e SABIT yazma (repo PUBLIC).
library;

import 'dart:async';
// Platform: kesik cizgi birimi Android'de PIKSEL, iOS'ta METRE.
import 'dart:io' show Platform;
// ⚠️ TURU 138 — `kAiKartYuzey`: cip ikonunun arkasindaki daire, MENUDEKI
//    kategori kartiyla AYNI yuzeyi kullanir (kullanici emri; kopya renk YOK).
import '../../core/theme.dart' show morLogo, kAiKartYuzey, kAiZemin;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart'
    show EagerGestureRecognizer, OneSequenceGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';



// ⚠️ TURU 88 — YenileSarmali ARTIK KULLANILMIYOR: ekran dikey kaydirilmiyor
//    (harita %70 + yatay kart seridi), asagi-cek jesti YOK. Yenileme
//    AppBar dugmesine tasindi.
// ⚠️ TURU 89 — harita rengi tercihi (Ayarlar > Harita).
import '../../core/tercihler.dart';
import '../medya/konum_servisi.dart';
import '../medya/pusula_servisi.dart';
import '../sosyal/profil_basligi.dart' show kOnayliRengi;
import '../sosyal/hizmet_menusu.dart' show KalinIkon;
 import '../sosyal/profil_sayfasi.dart';
// ⚠️ TURU 141 — SnackBar'lar acik %70/%95 popuplarin USTUNDE cizilmeli;
//    ekranin messenger'i onlarin ARKASINDA kalir (bkz. `_mesaj`).
import '../../router.dart' show rootMessengerKey;
// ⚠️ TURU 115 — kart/olcu sabitleri kategori ekraniyla ORTAK.
import 'isletme_kart.dart' show kYanBosluk, kYaricap, kYuzeyGri, kVurgu;
// ⚠️⚠️ TURU 140 — kategori popupu ANASAYFA MENUSUYLE **AYNI OLCULERI**
//    kullanir (kullanici emri). Sabitler KOPYALANMAZ, kaynagindan import
//    edilir; biri degisince ikisi birlikte doner.
import 'isletme_listesi.dart' show kKesifKutu, kIzgaraAralik;
import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_servisi.dart' show medyaServisiProvider;
import '../ulasim/adres_servisi.dart';
import '../ulasim/rota_bul.dart';
import '../ulasim/rota_sayfalari.dart';
import '../ulasim/rota_takip.dart' as takip;
import '../ulasim/ulasim_sayfalari.dart' as ulasim;
import '../ulasim/ulasim_veri.dart';
import 'harita_daire_pin.dart';
import 'isletme_servisi.dart';
// ⚠️ TURU 140 — telefon numarasi LISTEDE gelmiyor; dokununca
//    `GET /users/{id}/isletme` ile cozuluyor (bkz. `_ara`).

/// Uber tarzi acik-gri harita paleti.
///
/// ⚠️ Renkler Google'in "silver" stiliyle ayni aileden secildi: zemin kirli
///    beyaz, yollar beyaz, su acik gri-mavi. Gercek harita geldiginde AYNI
///    palet JSON stil olarak verilecek — yer tutucu ile harita arasinda
///    gorsel SICRAMA olmasin.
/// ⚠️⚠️ HARITA ANAHTARI DERLEMEYE GOMULUDUR — istemci onu OKUYAMAZ (Android'de
///    manifest meta-data, iOS'ta Info.plist; ikisi de native tarafta).
///
///    Bu bayrak `--dart-define=HARITA=1` ile gelir ve CI'da anahtar VARSA
///    gecilir. Boylece: anahtar yoksa harita HIC KURULMAZ ve kullanici bozuk
///    gri kutu yerine DURUST bir yer tutucu gorur.
/// ⚠️ YAPMA: varsayilani `true` yapma — yerel `flutter run` (secret'siz)
///    anahtarsiz calisir ve harita bozuk gorunurdu.
/// ⚠️⚠️⚠️ TURU 87 — **BU BAYRAK ÜÇ SÜRÜM BOYUNCA HEP `false` KALDI.**
///
///	Eski hali `bool.fromEnvironment('HARITA')` idi ve CI `--dart-define=
///	**HARITA=1**` geciyordu. Dart'in `bool.fromEnvironment` sozlesmesi:
///	deger **YALNIZCA** `"true"` ise true, `"false"` ise false, **BASKA HER
///	SEYDE `defaultValue` (false)**. Yani `"1"` -> **FALSE**.
///
///	SONUC: `if (haritaAnahtariVar && ...)` kapisi HIC ACILMADI; uygulama
///	GERCEK Google haritasini **hicbir surumde cizmedi**, hep elle boyanmis
///	yer tutucuyu (`_SehirCizer`) gosterdi. Kullanici uc kez soyledi:
///	*"bu nasil bir harita?"* / *"normal google haritasi degil ki bu"* /
///	*"yine sacma sapan bir harita var, neden google haritasini
///	kullanmiyorsun"*. HER SEFERINDE HAKLIYDI.
///
///	⚠️ **HATA NEDEN GORUNMEDI:** anahtarin APK manifestine ve iOS
///	   `Info.plist`ine enjekte edildigini DOGRULADIM ve "harita hazir"
///	   sandim. Ama enjeksiyon ile `HARITA` bayragi **AYRI IKI SEY**;
///	   biri dogruyken oteki sessizce yanlisti. Derleme temiz, uygulama
///	   saglam, hata YALNIZCA EKRANDA.
///
/// FIX (iki katmanli — biri bozulursa oteki tutar):
///   1. Bayrak artik **DIZEDEN** turetiliyor ve `true`/`1`/`yes` kabul ediyor.
///   2. CI `--dart-define=HARITA=true` geciyor (dogru sozlesme).
/// ⚠️ Muhafiz: `test/harita_stili_test.dart` CI dosyalarindaki degeri
///    KODDAKI kabul kumesiyle karsilastirir; ikisi ayrisirsa test KIRMIZI.
/// ⚠️ YAPMA: bunu tekrar ciplak `bool.fromEnvironment`a dondurme.
/// ⚠️ YAPMA: varsayilani `true` yapma — yerel `flutter run` (secret'siz)
///    anahtarsiz calisir ve harita bozuk gorunurdu.
/// ⚠️⚠️ TURU 137 — PANELDEKI ISLETME SERIDI (bkz. `_panelSeridi`).
///
/// ⚠️ **TAVAN ZORUNLU**: `/yakinimda` en fazla 60 kayit doner; sinir
///    olmasaydi 60 kart yan yana kurulur ve her biri bir kapak gorseli
///    COZERDI (turu 91 performans dersi).
/// ⚠️ Serit bir VITRIN: daha fazlasini isteyen kullanici kategori ekranina
///    gider (harita ikonu oradan da acilir).
const int kPanelSeritTavan = 12;

/// Serit kartinin genisligi.
///
/// ⚠️ Sabit: yatay seritte kartlar ekran genisligine gore degisirse komsu
///    kartin "sarkma" miktari cihazdan cihaza kayar ve serit hizasiz durur.
const double kPanelKartEn = 372;

/// Panelin ALT ic dolgusu — **TEK KAYNAK** (`_panelGovde` ve `_panelBoy`).
///
/// ⚠️⚠️ TURU 144 — iki yerde ayri ayri yaziliyken formulden DUSTU ve panel
///	govdeden 12 dp kisa hesaplandi (olculdu). Sabit hale getirildi ki
///	ayrisma bir daha mumkun olmasin.
const double kPanelAltDolgu = 12;

/// Kisayol kartinin (Eczane · Durak · Benzinlik · Taksi) ikon kutusu.
///
/// ⚠️ TURU 145 — kullanici *"anasayfadaki kategori gibi KARTLI IKON"* dedi.
///    Turu 143'te olculen %40 buyutme burada KUTU olcusu olarak yasiyor.
const double kKisayolKutu = 52;

/// ⚠️⚠️ TURU 140 — **MENU KARESI** (kullanici emri: *"yemekte isletmenin
/// orada menuler gorunsun, KARE resim alanlari kategori radus mantiginda"*).
///
/// ⚠️ Radus buradan turetilir (`kYaricap(kMenuKare)`) — kategori dairesi ve
///    kart dugmeleriyle AYNI dil.
/// ⚠️ 56 dp: dort kare + 3x6 aralik = 242 dp, kartin 328 dp'lik icerik
///    genisligine RAHAT siger; buyugu kart boyunu gereksiz uzatirdi.
const double kMenuKare = 56;

/// Arama sayfasindaki kategori kartinin kutu olcusu.
///
/// ⚠️ TURU 142 — kullanici emri: *"kategorilerde kartlar %20 kucult"*.
///    Anasayfa menusundeki `kKesifKutu` (78) referans alinip %20
///    kucultuldu. Menuye DOKUNULMADI — orasi baska bir ekran.
const double kAramaKutu = 62;

/// ⚠️⚠️ TURU 139 — HARITA USTU DUGMELERI (geri · konumuma dön · + · −).
///
/// ⚠️ Olculer kullanici emriyle **%15 buyutuldu** (48 -> 55, 44 -> 51).
///    Ikisi de `kYaricap` ile yuvarlanir (kategori kartlariyla ayni dil).
/// ⚠️ Zemin opakligi 0.45 -> **0.62** (kullanici: *"arkasi cok gorunuyor"*).
///    Daha da koyulastirmak dugmeyi haritadan KOPARIR; 0.62 harita hala
///    seciliyorken metnin/ikonun okunmasini garanti eder.
const double kHaritaDugmeOlcu = 55;
const double kHaritaZoomOlcu = 51;
const double kHaritaDugmeAlfa = 0.62;

/// Yuzen filtre cipinin zemin opakligi.
///
/// ⚠️ TURU 141 — 0.62 -> **0.82** (kullanici emri: *"filtrelerdeki arka plan
///    hala saydam, biraz daha kapat"*).
/// ⚠️ Ust bardaki dugmelerden (`kHaritaDugmeAlfa`) AYRI tutulur: o dugmeler
///    haritanin uzerinde TEK BASINA duran ikonlar, bu serit ise METIN tasir
///    ve okunabilirlik esigi daha yuksek.
const double kYuzenCipAlfa = 0.82;

/// ⚠️⚠️ TURU 140 — **GOOGLE LOGOSU PANELIN ARKASINA DUSSUN** diye harita
/// dolgusundan DUSULEN pay (kullanici emri: *"Google Maps yazisi gorunuyor,
/// onu kartin altina al"*).
///
/// ⚠️ Deger logo yuksekligi + kenar marjidir; `EdgeInsets.zero` YERINE bu
///    kullanilir cunku dolgunun TAMAMINI silmek turu 132'de yazili kamera
///    merkezleme hatalarini geri getirir.
/// ⚠️ Android ile iOS logo olculeri birebir ayni DEGIL — GERCEK CIHAZDA
///    dogrulanmali.
const double kLogoPay = 30;

/// Cipler arasi bosluk (seridin `separatorBuilder`inda TEK KAYNAK).
///
/// ⚠️ TURU 140 — 8 -> 14 (kullanici emri: *"kategorilerin arasini biraz ac"*).
/// ⚠️ Cipin KENDI `Padding`inde DEGIL burada: orada olsaydi son ogeye de
///    uygulanir ve sagdaki nefesle CIFT SAYILIRDI.
const double kCipAra = 14;

/// Cip seridinin SAG dolgusu.
///
/// ⚠️ TURU 140 — kullanici *"sagda divin disina cikiyor"* dedi: cipler
///    ekranin tam kenarinda yaridan kesiliyordu. Sol dolgudan (16) BUYUK
///    olmak zorunda — sol kenar sabit, sag kenara ise kaydirdikca icerik
///    dayanir.
const double kSeritSagNefes = 28;

/// ⚠️⚠️ TURU 155 — iOS kesik deseninin yeniden hesaplanma esigi (zoom).
///
/// Desen iOS'ta **METRE** cinsindendir (paket kaynagindan dogrulandi:
/// `FGMPolylineController.m` -> `GMSStyleSpans(..., kGMSLengthRhumb)`),
/// yani ekranda sabit gorunmesi icin zoom degistikce yeniden hesaplanmak
/// ZORUNDA. Android'de birim PIKSEL (`Convert.java` -> `new Dash(length)`)
/// ve orada hicbir sey yapmak GEREKMEZ.
///
/// 0.15 zoom = ~%11 olcek hatasi — gozle secilemez. Onceki deger **0.4**
/// (%32) idi ve kullanici farki SAHADA GORDU.
/// ⚠️ Daha da kucultme: her 0.05'te yeniden cizim, sikistirma boyunca
///    ~20 `setState` demek ve kazanci gorunmez.
const double kZoomEsigi = 0.15;

/// ⚠️⚠️⚠️ TURU 156 — **ROTA CIZGISI OLCULERI VE RENKLERI.**
///
/// Kullanici emirleri (Yandex Navigator referansi):
///	*"otobus shape YESIL olsun, hafif kapali ve hafif SIYAH BORDER
///	olsun, yolu TAM KAVRASIN TASMASIN"* +
///	*"yurume shape ARKASINDA RENK var, BORDERLAR var"*.
///
/// ⚠️⚠️ `Polyline.width` **`int`** ve birimi IKI PLATFORMDA DA dp:
///	Android `PolylineController.setWidth(width * density)` (dp->px),
///	iOS `polyline.strokeWidth = width` (GMSPolyline zaten NOKTA
///	cinsinden calisir). Yani buradaki sayilar dp'dir.
///
/// ⚠️ Otobus 9 -> **7**: kullanici *"yolu tam kavrasin TASMASIN"*
///    dedi. Kilifla birlikte toplam 7+2*1 = **9 dp**, yani eski ciplak
///    cizgiyle AYNI dis olcu — ama artik icinde cerceve var.
///	⚠️⚠️ Yol genisligi zoom ile DEGISIR, `Polyline.width` ise
///	SABIT. "Tam kavramak" hicbir sabit degerde her zoom'da
///	saglanamaz; 7 dp sehir zoom'unda (16-18) yola en yakin olcu.
/// ⚠️⚠️ TURU 156 — **KESIKLER SIKLASTIRILDI** (kullanici: *"bu
///	kesikler arasi HALEN COK BOSLUKLU"*).
///
/// Eski deger 18/10 idi. Referans gorselde (Yandex) dolu parca ile
/// bosluk neredeyse ESIT, bosluk biraz daha KISA.
/// ⚠️ Altta DUZ kilif oldugu icin bosluklar harita zeminini degil
///    koyu kilifi gosterir; bu yuzden bosluk kucuk olabilir, cizgi yine
///    de "kesik" okunur.
const double kKesikDolu = 9;
const double kKesikBos = 5;

const int kYurumeEn = 5;
const int kOtobusEn = 7;

/// Kilifin HER IKI YANDAN tastigi miktar (dp).
///
/// ⚠️ 1 dp bilincli: kullanici *"HAFIF siyah border"* dedi. 2 dp
///    denendiginde cizgi kalinlasip yolu asiyordu.
const int kKilifPay = 1;

/// Kilif rengi — harita zemininden (`#232a44`) belirgin KOYU.
///
/// ⚠️ Saf siyah DEGIL: koyu lacivert zeminde saf siyah bir cerceve
///    "delik" gibi durur; zeminle ayni aileden koyu bir ton daha temiz.
const Color kCizgiKilif = Color(0xFF0E1120);

/// Otobus bacaginin rengi — **YESIL** (kullanici emri).
///
/// ⚠️ *"hafif kapali"* = doygun degil, MAT yesil. Parlak yesil
///    (`#3BD35F`) koyu haritada goz aliyordu.
const Color kOtobusRengi = Color(0xFF2FA85C);

const _haritaBayragi = String.fromEnvironment('HARITA');
const haritaAnahtariVar =
    _haritaBayragi == 'true' || _haritaBayragi == '1' || _haritaBayragi == 'yes';

/// ⚠️⚠️ **UBER TARZI GRIMSI-BEYAZ** harita stili (kullanici emri).
///
/// Google'in "silver" ailesinden: zemin kirli beyaz, yollar beyaz, POI ve
/// ilgisiz etiketler KAPALI (kalabalik yapiyor), su acik gri-mavi.
/// ⚠️ `cloudMapId` KULLANILMADI (CLAUDE.md yasagi — ucretli). Yerel JSON
///    stil UCRETSIZDIR ve ayni gorunumu verir.
/// ⚠️ Renkler yer tutucu paletiyle (`_zemin`/`_yol`/`_su`) AYNI aileden:
///    anahtar eklendiginde gorsel SICRAMA olmasin.
/// ⚠️⚠️⚠️ TURU 86 — **ÖZEL STİL KALDIRILDI, NORMAL GOOGLE HARİTASI KULLANILIYOR.**
///
/// Kullanıcı (11 Ağu): *"bu nasıl bir harita? normal google haritası değil ki bu"*.
/// **HAKLIYDI.** Turu 85'te "uber tarzı grimsi beyaz" isteğini bir stil JSON'una
/// çevirirken haritanın TANIMLAYICI her unsurunu kapatmıştım:
///
///	· `poi` -> **visibility: off**     (hiçbir işletme/mekân görünmüyor)
///	· `road … labels` -> **off**       (SOKAK ADI YOK)
///	· `labels.icon` -> **off**         (simgeler yok)
///	· `transit` -> **off**             (metro/otobüs yok)
///	· `administrative geometry` -> off (ilçe sınırları yok)
///
/// Geriye beyaz çizgili GRİ BİR KÂĞIT kalıyordu — kullanıcı nerede olduğunu
/// anlayamıyor, bir yeri tanıyamıyordu. "Grimsi beyaz" bir RENK TERCİHİYDİ;
/// haritayı OKUNAMAZ hale getirme yetkisi değildi.
///
/// ⚠️ **DERS: bir görsel tercihi uygularken ürünün TEMEL İŞLEVİNİ elinden
///    alma.** Harita bir dekor değil; sokak adı ve mekân etiketleri onun
///    VAROLUŞ SEBEBİDİR.
/// ⚠️ YAPMA: buraya `poi`/`road labels`/`transit` kapatan bir stil geri koyma.
///    Renk tonu istenirse YALNIZCA `geometry` renkleri değiştirilir, hiçbir
///    `visibility: off` eklenmez.
/// ⚠️ `cloudMapId` YASAK (CLAUDE.md — ücretli).
/// ⚠️⚠️ TURU 88 — TEK BIR SEY GIZLENIR: **GOOGLE'IN KENDI ISLETME ETIKETLERI.**
///
/// Kullanici emri: *"haritadaki isletmeler gorunmeyecek"* — yani Google'in
/// varsayilan POI balonlari (restoran/market/kafe adlari ve simgeleri). Sebep:
/// haritada BIZIM pinlerimiz var ve Google'in yuzlerce POI etiketi onlari
/// gorunmez kiliyor, kullanici hangisinin uygulamadaki isletme oldugunu
/// ayirt edemiyordu.
///
/// ⚠️⚠️ **YALNIZCA `poi.business` KAPATILIR.** Turu 85'te "grimsi beyaz"
///    istegi uygulanirken `poi` (HEPSI) + `road labels` + `transit` +
///    `labels.icon` + `administrative` kapatilmis ve harita OKUNAMAZ bir gri
///    kagida donmustu (kullanici: *"bu nasil bir harita?"*).
///    Burada SOKAK ADLARI, park/hastane/okul, toplu tasima ve tum zemin
///    **AYNEN DURUYOR** — kapanan tek sey TICARI POI etiketleri.
/// ⚠️ YAPMA: bu listeye `road`, `transit`, `administrative`, `labels.icon`
///    ya da alt tur belirtmeden `poi` ekleme. Muhafiz
///    (`test/harita_stili_test.dart`) bunlari REDDEDER.
// ignore: unused_element
const _haritaStili = '''
[
 {"featureType":"poi.business","stylers":[{"visibility":"off"}]}
]
''';

/// ⚠️⚠️⚠️ TURU 89 — "UBER TARZI GRI-BEYAZ" (kullanici emri, arastirildi).
///
/// Google'in RESMI **"Silver"** ornek stili temel alindi (Uber'in acik
/// haritasinin gorunumu bu aileden: dusuk doygunluk, kirli beyaz zemin,
/// beyaz yollar, gri-mavi su).
///
/// ⚠️⚠️ RESMI SILVER **OLDUGU GIBI KULLANILAMAZ**: icinde
///	`{"elementType":"labels.icon","stylers":[{"visibility":"off"}]}`
///	satiri VARDIR ve bu, turu 85'te haritayi okunamaz kilan hatanin TA
///	KENDISIDIR. O satir **CIKARILDI**. (Muhafiz da bunu dogruluyor: resmi
///	Silver yapistirilip test KIRMIZIYA dusuruldu.)
///
/// SONUC: yalnizca **RENK** degisiyor — sokak adlari, park/hastane/okul,
/// toplu tasima ve idari sinirlar AYNEN duruyor.
/// ⚠️ `poi.business` kurali turu 88'den TASINDI (kullanici: "haritadaki
///    isletmeler gorunmeyecek") — her stilde TEKRARLANMALI.
const _haritaGri = '''
[
 {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
 {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
 {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
 {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
 {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
 {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
 {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},
 {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
 {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
 {"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
 {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},
 {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
 {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
 {"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},
 {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
 {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},
 {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
 {"featureType":"poi.business","stylers":[{"visibility":"off"}]}
]
''';

/// ⚠️⚠️ TURU 89 — GECE STILI (kullanici emri: *"gece ve uberin gri beyaz"*).
///
/// Google'in RESMI **"Night"** ornek stili. Bu stil `visibility` kurali
/// ICERMEZ — yani hicbir katmani gizlemez, yalnizca renk degistirir; oldugu
/// gibi kullanilabilir. Sonuna yalnizca turu 88'in `poi.business` kurali
/// eklendi.
/// ⚠️ Koyu temada haritanin PARLAK BEYAZ kalmasi ekranin %70'ini temadan
///    KOPARIYORDU; "Sistem" secenegi bunu kapatir.
const _haritaGece = '''
[
 {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
 {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
 {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
 {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
 {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
 {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},
 {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},
 {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
 {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
 {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},
 {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},
 {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},
 {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},
 {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},
 {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
 {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},
 {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},
 {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]},
 {"featureType":"poi.business","stylers":[{"visibility":"off"}]}
]
''';

/// Ayardaki tercihi (+ tema parlakligini) somut bir stile cevirir.
///
/// ⚠️ `'sistem'` seceneginin varligi ZORUNLU: koyu temaya gecen kullanicinin
///    haritasi da kararmali, aksi halde ekranin %70'i uygulamadan KOPUK
///    parlak beyaz bir dikdortgen olarak kalir.
/// ⚠️⚠️⚠️ TURU 139 — **"NAVIGATOR" HARITA STILI** (kullanici emri: *"harita
///	rengini sana verdigim resimdeki renk gibi yap, sana verdigim resimdeki
///	renk mantigini uygula haritada, harita renkler baska renkler degil"* —
///	referans: Yandex Navigator koyu temasi, ekran goruntusu verildi).
///
///	Resimden okunan renk mantigi:
///	  · zemin       koyu LACIVERT-GRI (mavi-mor egilimli, siyah DEGIL)
///	  · park/yesil  belirgin KOYU YESIL (zeminden ayrisir)
///	  · yollar      MAVI-GRI seritler; ana yollar bir tik ACIK
///	  · su          zeminden daha KOYU mavi
///	  · etiketler   acik gri-beyaz, koyu konturlu (okunur)
///
/// ⚠️⚠️ **`visibility: off` YALNIZ `poi.business` ICIN** — turu 85'te
///	"grimsi beyaz" istegi uygulanirken poi/road labels/transit kapatilmis
///	ve harita OKUNAMAZ bir kagida donmustu (kullanici: *"bu nasil bir
///	harita?"*). Muhafiz (`test/harita_stili_test.dart`) baska bir
///	`visibility: off` gorurse KIRMIZI duser.
/// ⚠️ Yani burada YALNIZCA **RENK** degisiyor: sokak adlari, parklar,
///    hastane/okul, toplu tasima ve idari sinirlar AYNEN duruyor.
/// ⚠️ `poi.business` kurali HER stilde TEKRARLANMALI (turu 88).
/// ⚠️⚠️ **HER RENK `#RRGGBB` OLMAK ZORUNDA**: Google stil ayristiricisi
///	gecersiz bir hex gorunce O KURALI SESSIZCE ATAR — harita "biraz
///	yanlis" gorunur ve sebebi hicbir yerde yazmaz. (Ilk yazimda
///	`#2e3category` ve 8 haneli `#44528097` kalmisti; ikisi de duzeltildi.)
///
/// ⚠️⚠️⚠️ TURU 155 — **`landscape.natural` YESILDI, TUM ZEMINI
///	BOYUYORDU** (kullanici sahada gordu: *"yaklastikca haritada boyle
///	yesilimsi bir renk oluyor"* — ekran goruntusu gonderdi).
///
///	⚠️⚠️ KOK NEDEN: Google stil semasinda `landscape.natural`
///	YALNIZ parklari degil, **YAPILASMAMIS HER ZEMINI** kapsar
///	(`landscape.natural.landcover` + `landscape.natural.terrain`).
///	Sehir olceginde ustunu `landscape.man_made` karolari ortuyordu ve
///	hata GORUNMUYORDU; **yakinlastikca** man_made karolari seyrelince
///	altindaki YESIL ortaya cikiyor ve ekran komple yesile donuyordu.
///
///	FIX: `landscape.natural` ZEMIN RENGINE cekildi ve
///	`landscape.man_made` ACIKCA tanimlandi (varsayilana birakilirsa
///	Google kendi rengini kullanir ve stil "biraz yanlis" gorunur).
///	Yesil ARTIK YALNIZ `poi.park`ta — Yandex referansindaki gibi.
/// ⚠️ YAPMA: `landscape` ya da `landscape.natural` altina yesil
///    (`#26402f` gibi) bir renk geri koyma. Yesil YALNIZ `poi.park`.
const _haritaNavigator = '''
[
 {"elementType":"geometry","stylers":[{"color":"#232a44"}]},
 {"elementType":"labels.text.fill","stylers":[{"color":"#c7cee0"}]},
 {"elementType":"labels.text.stroke","stylers":[{"color":"#1b2036"}]},
 {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#2e3555"}]},
 {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9aa4c4"}]},
 {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d3d9e8"}]},
 {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#7f89aa"}]},
 {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#2a3150"}]},
 {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#a7b0cc"}]},
 {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#26402f"}]},
 {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#8fbf9c"}]},
 {"featureType":"poi.medical","elementType":"geometry","stylers":[{"color":"#33304e"}]},
 {"featureType":"poi.school","elementType":"geometry","stylers":[{"color":"#2c3352"}]},
 {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#232a44"}]},
 {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#232a44"}]},
 {"featureType":"landscape.natural.landcover","elementType":"geometry","stylers":[{"color":"#232a44"}]},
 {"featureType":"landscape.natural.terrain","elementType":"geometry","stylers":[{"color":"#232a44"}]},
 {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#262e4b"}]},
 {"featureType":"road","elementType":"geometry","stylers":[{"color":"#3e4c77"}]},
 {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#2b3355"}]},
 {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#b9c2dc"}]},
 {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#4a5a8c"}]},
 {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#313a63"}]},
 {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#d6dcec"}]},
 {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#445280"}]},
 {"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#37436b"}]},
 {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3960"}]},
 {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#a7b0cc"}]},
 {"featureType":"water","elementType":"geometry","stylers":[{"color":"#1a2340"}]},
 {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#6f7ba0"}]},
 {"featureType":"poi.business","stylers":[{"visibility":"off"}]}
]
''';

String haritaStiliSec(String tercih, Brightness parlaklik) => switch (tercih) {
  'gri' => _haritaGri,
  'gece' => _haritaGece,
  // ⚠️⚠️⚠️ TURU 139 — VARSAYILAN artik **NAVIGATOR** stili (kullanici
  //	emri: harita renkleri verdigi Yandex Navigator ekran goruntusundeki
  //	gibi olacak). Acik/koyu TEMADAN BAGIMSIZ: kullanici tek bir harita
  //	gorunumu istedi, temaya gore renk degistirmesini DEGIL.
  // ⚠️ Ayardaki 'gri' ve 'gece' secenekleri DURUYOR — kullanici isterse
  //    eski gorunume donebilir (Ayarlar > Harita).
  // ⚠️ `_haritaStili` (yalniz `poi.business` kapali, Google varsayilani)
  //    ARTIK HICBIR DALDAN CAGRILMIYOR ama SILINMEDI: "sade Google
  //    haritasi" bir daha istenirse tek satirla geri gelir.
  _ => _haritaNavigator,
};

const _zemin = Color(0xFFF2F3F5);
const _yol = Color(0xFFFFFFFF);
const _yolCizgi = Color(0xFFE4E6EA);
const _su = Color(0xFFDDE6EC);
const _yesil = Color(0xFFE8EDE6);

class YakinimdaEkrani extends ConsumerStatefulWidget {
  const YakinimdaEkrani({
    super.key,
    this.kategori = '',
    this.durakla = false,
  });

  /// ⚠️⚠️⚠️ TURU 150 - **DURAK MODUYLA ACILIR** (kullanici emri:
  ///	*"girişte ilk ekranda DURAK dedigimde alt kisimda bana EN
  ///	YAKIN DURAKLAR ayni yemek kartlari gibi gorunmeli"*).
  /// ⚠️ Ayri bir ekran YAZILMADI: durak modu bu ekranin bir KIPI;
  ///    harita, konum, stil ve pin uretimi zaten burada.
  final bool durakla;

  /// ⚠️⚠️ TURU 92 — ACILIS KATEGORISI (kullanici emri: *"slider sag uste
  ///    HARITA ekle, ona tikladiginda haritadan gorunsun"*).
  ///
  ///    Kategori listesindeki harita ikonundan gelindiginde AYNI kategoriyle
  ///    acilir; kullanici serit ustunden degistirebilir.
  /// ⚠️ IKINCI BIR HARITA EKRANI YAZILMADI: bu ekranda harita stili muhafizi,
  ///    jest cakismasi cozumu (`EagerGestureRecognizer`), kamera takibi ve
  ///    adresten pin cozumleme ZATEN var (turu 85-88). Kopyasi KACINILMAZ
  ///    olarak drift ederdi.
  final String kategori;

  @override
  ConsumerState<YakinimdaEkrani> createState() => _YakinimdaEkraniState();
}

class _YakinimdaEkraniState extends ConsumerState<YakinimdaEkrani> {
  ({double enlem, double boylam})? _konum;
  List<IsletmeOzet> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  late String _kategori = widget.kategori;

  // ⚠️ TURU 137 — `_arama` (denetleyici) ve `_q` (arama metni) SILINDI:
  //    mekan arama kutusu kullanici emriyle kaldirildi (bkz. `_altPanel`).

  /// Kategoriye ozel suzgecler. ⚠️ **YALNIZ SUNUCUDAN GELEN ALANLAR**:
  ///	`puan`, `min_tutar_kurus`, `kampanyalar`, `km`, `dogrulandi`.
  ///	Kullanici *"akaryakita fiyat araliklari"* dedi; akaryakit FIYATI bu
  ///	projede HICBIR YERDE YOK (ne tablo ne uc) — uydurmak yerine gercekten
  ///	sahip oldugumuz olcutler sunuluyor ve sinir alt sayfada YAZILI.
  bool _fPuan = false;      // 4+ puan
  bool _fKampanya = false;  // kampanyasi olan
  bool _fOnayli = false;    // onayli isletme
  double _fKm = 0;          // 0 = sinirsiz (sunucu yaricapi neyse o)

  /// ⚠️⚠️⚠️ TURU 141 — **GORUNUM DALI** (`_kategori`den AYRI).
  ///
  ///	Cogu zaman `_kategori` ile AYNIDIR. Ayristigi TEK yer, sunucuda
  ///	KARSILIGI OLMAYAN kisayollardir: bugun **'akaryakit'**.
  ///	  `_dal = 'akaryakit'`  ->  `_kategori = 'oto'`
  ///
  /// ⚠️⚠️ **SUNUCUYA BILINMEYEN KATEGORI GONDERILEMEZ**: `/yakinimda`
  ///	handler'i `Kategoriler` haritasinda olmayan anahtara **400
  ///	"geçersiz kategori"** doner (backend `yakinimda.go:103`). Bu yuzden
  ///	ekranin GOSTERDIGI dal ile sunucuya GIDEN kategori ayri tutulur.
  /// ⚠️ 'akaryakit' -> 'oto' eslemesi ICAT DEGIL: menudeki hizli erisim
  ///    (`hizmet_menusu.dart`) ayni esleme ve ayni `LucideIcons.fuel`
  ///    ikonunu IKI ayri yerde zaten kullaniyor (turu 124/128).
  /// ⚠️ Cip seridi, alt satir varyanti ve ornek kayitlar `_dal`a bakar;
  ///    yalnizca AG ISTEGI `_kategori`ye bakar.
  /// ⚠️⚠️ **BASLANGICTA `widget.kategori` ILE DOLDURULUR.** Menuden bir
  ///	kategoriyle gelindiginde (`YakinimdaEkrani(kategori: 'hizmet')`)
  ///	`_kategori` doluyor ama `_dal` bos kalsaydi cip seridi hicbir cipi
  ///	SECILI gostermez, isletme seridi CIZILMEZ ve vitrin varyanti
  ///	SECILMEZDI — yani ekran kategoriyle acildiginda OLU gorunurdu.
  ///	(Menude 'Taksi'/'Akaryakit' gibi DORT giris bu yoldan geliyor.)
  late String _dal = widget.kategori;

  /// ⚠️⚠️⚠️ TURU 141 — **ARAMA METNI** (kullanici emri: *"kategori yemek vs
  ///	ALTINA arama yeri yap"* + kategori popupunda *"en ustte arama"*).
  ///
  /// ⚠️⚠️ **SUZGEC ISTEMCIDE** — sunucuda karsiligi YOK: `/yakinimda`
  ///	handler'i yalniz `lat`/`lng`/`km`/`kategori` okuyor, `q`
  ///	parametresi ALMIYOR (backend `yakinimda.go:68-105`) ve gonderilse
  ///	SESSIZCE yok sayilirdi.
  /// ⚠️ Istemcide suzmek BURADA DURUST: liste TEK ISTEKTE geliyor
  ///    (`yakinLimit = 60`, sayfalama YOK), yani suzulen kume kullanicinin
  ///    gordugu kumenin TAMAMIDIR (turu 122'deki ilan siralamasiyla ayni
  ///    gerekce).
  /// ⚠️ Panel ile popup AYNI metni paylasir: iki ayri arama tutulsaydi
  ///    kullanici popupta arayip kapattiginda seritte BASKA bir liste
  ///    gorurdu.
  /// ⚠️ Dal degisince SIFIRLANIR (bkz. `_dalSec`).
  String _q = '';

  /// Son secilen dallar (en yeni ONCE) — arama sayfasindaki "Geçmiş".
  ///
  /// ⚠️ **OTURUM OMURLU**: diske yazilmiyor, uygulama kapaninca gider.
  ///    Kalici olmasi istenirse `core/tercihler.dart` (SharedPreferences)
  ///    kullanilir; bu tur HIZLI ARAYUZ turu oldugu icin ertelendi.
  final List<String> _gecmis = [];

  /// Kategori basina son alinan liste — **GECIS YUMUSATICI**.
  ///
  /// ⚠️⚠️⚠️ TURU 144 — kullanici emri: *"haritada kategori secerken cok sert
  ///	geciyor, bunu duzelt"*. Onceden her cip dokunusu `_yukle`yi
  ///	baslatiyor, `_yukleniyor` true olunca serit AGACTAN KALKIYOR, panel
  ///	kisaliyor, ag yaniti gelince tekrar UZUYORDU — ekran her secimde
  ///	ZIPLIYORDU. Artik daha once gorulen bir kategoriye donuldugunde liste
  ///	ANINDA cizilir ve tazeleme ARKA PLANDA yapilir.
  /// ⚠️ Anahtar `_kategori` (sunucuya giden deger) + `_km`: yaricap
  ///    degisince eski sonuc GECERSIZDIR.
  /// ⚠️ Onbellek OTURUM OMURLU ve KUCUK (en fazla kategori sayisi kadar
  ///    kayit x 60 ozet). Diske yazilmaz — bayat veri gostermek istemiyoruz,
  ///    yalnizca AYNI OTURUMDAKI gecisi yumusatiyoruz.
  final Map<String, List<IsletmeOzet>> _onbellek = {};

  /// ⚠️⚠️⚠️ TURU 149 — **HARITADA GERCEK DURAK PINLERI.**
  ///
  /// Bos ise durak katmani cizilmez. "Durak" kisayoluna dokununca
  /// kullanicinin cevresindeki GERCEK duraklarla dolar (GTFS verisi).
  /// ⚠️ Yaricap ve adet SINIRLI (`yakinDuraklar`): bolgede 2032 durak var
  ///    ve hepsini haritaya koymak hem pin uretimini hem cizimi bogardi
  ///    (turu 91'de olculen sinif).
  List<Durak> _duraklar = const [];

  /// Haritada cizilen GERCEK guzergah (hat + yon secilince dolar).
  ({List<({double enlem, double boylam})> noktalar, Color renk})? _hatCizgi;

  /// Cizilen guzergahin ust barda gosterilecek adi ("563 · MERKEZ - SANAYI").
  String _hatEtiketi = '';

  /// ⚠️⚠️⚠️ TURU 149 — **"KONUMUMA DON" NESIL SAYACI.**
  ///
  /// Denetimde OLCULDU: dugme yalnizca `_yukle(konumuTazele: true)`
  /// cagiriyordu; kamerayi tasiyan tek yer ise `didUpdateWidget` icinde
  /// `merkez`in BIT-BAZINDA degismesiydi. GPS ayni fix'i dondurdugunde
  /// (kullanici yerinde duruyorsa NORMAL) **hicbir sey olmuyordu** —
  /// kullanicinin *"navigator tikladigimda ortalansin"* sikayeti tam buydu.
  /// ⚠️ Sayac deseni bu ekranda ZATEN var (`_odak`, `_zoom`): "deger
  ///    degismedi" diye sessizce yok sayilan istekleri onler.
  int _merkezNesli = 0;

  /// ⚠️⚠️⚠️ TURU 150 — **DURAK MODU** (kullanici emri: *"ben durak
  ///	dedigimde ekranda duraklardan BASKA SEYLER GORUNMEMELI"*).
  ///
  /// Acikken:
  ///   · panelde YALNIZ [Nereden]/[Nereye] + yatay DURAK KARTLARI,
  ///   · haritada YALNIZ durak pinleri (isletme pinleri CIZILMEZ),
  ///   · cip seridi · arama · kisayollar · isletme seridi GIZLI.
  bool _durakModu = false;

  /// Durak basina hat listesi (kart uzerinde "563 · 4 dk" icin).
  /// ⚠️ Onbelleklenir: 30 kart icin her cizimde yeniden cozmek 1,7 MB'lik
  ///    tabloyu kart basina taramak demekti.
  final Map<String, List<DurakHatti>> _durakHat = {};

  /// Haritada secili durak (pinden ya da karttan).
  Durak? _seciliDurak;

  RotaNoktasi? _rotaBas;
  RotaNoktasi? _rotaVaris;
  RotaAdayi? _rota;

  /// ⚠️⚠️⚠️ TURU 151 — **ROTA TAKIBI** (kullanici emri: *"rota
  ///	baslatma yok; basla dediginde otobus ve varis HAFIF
  ///	SONECEK ve ekranda STEP EKRANI olacak"*).
  ///
  /// `null` ise takip KAPALI (rota yalnizca cizili duruyor).
  takip.TakipDurumu? _takip;
  StreamSubscription<
      ({
        double enlem,
        double boylam,
        double dogrulukM,
        double? yon,
      })>? _konumAkisi;

  /// ⚠️⚠️⚠️ TURU 155 — **PUSULA AKISI** (kullanici: *"telefonu
  ///	oynattikca yonu gostersin"*).
  ///
  /// ⚠️ YALNIZ takip acikken dinlenir: pusulayi ekran boyunca acik
  ///    tutmak sebepsiz pil harcar.
  StreamSubscription<double>? _pusulaAkisi;

  /// Konum isaretinin GOSTERECEGI yon (derece, 0 = kuzey).
  ///
  /// ⚠️⚠️ Kaynak SIRASI: (1) pusula — cihaz duruyorken de calisir,
  ///	(2) GPS gidis yonu — YALNIZ hareket halinde gecerli.
  ///	Ikisi de yoksa **`null`** kalir ve yon oku CIZILMEZ:
  ///	yanlis bir yon gostermek hic gostermemekten KOTUDUR.
  double? _yon;

  /// Konum dogrulugu (metre) — beyaz halkanin yaricapi.
  double? _dogrulukM;

  /// Kamera kullaniciyi TAKIP EDIYOR MU?
  ///
  /// ⚠️⚠️ Mapbox/Google deseni (arastirmada dogrulandi): kullanici
  ///	haritaya DOKUNDUGU an takip birakilir ("to avoid running
  ///	competing animations") ve **merkeze don** dugmesi gorunur.
  ///	Aksi halde kullanici haritayi kaydirmaya calisirken kamera
  ///	onu surekli geri ceker ve harita KULLANILAMAZ olur.
  bool _takipKamera = true;

  /// ⚠️⚠️⚠️ TURU 154 - **ADIM KARTLARI SAYFA DENETLEYICISI.**
  ///
  ///	Kullanici emri: *"steplere tikladigimda hangi stepleri SOL
  ///	SAG yapinca harita o NOKTALARA gidiyor"*.
  ///
  /// ⚠️⚠️ `initState`te DEGIL alan basinda kurulur ve `dispose`ta
  ///	BIRAKILIR. Takip her basladiginda yeniden kurulsaydi,
  ///	kapanis anindaki `dispose` HALA BAGLI bir `PageView`in
  ///	denetleyicisini birakirdi (turu 96i sinifi: "route cikis
  ///	animasyonu surerken dispose edilmis denetleyici").
  final PageController _adimSayfa = PageController();

  /// Kullanicinin BAKTIGI adim - takip edilen bacaktan FARKLI olabilir.
  int _adimGorunen = 0;

  /// ⚠️⚠️ Sayfa PROGRAMATIK degistiriliyor (kullanici kaydirmadi).
  ///
  ///	`PageView.onPageChanged` kullanici kaydirmasi ile programatik
  ///	gecisi **AYIRT ETMEZ**. Bayrak olmasaydi takip bir sonraki
  ///	bacaga gectiginde kamera kullanicidan KOPAR ve "Merkeze don"
  ///	dugmesi kendiliginden belirirdi.
  bool _adimProgramatik = false;

  /// Ard arda gelen konum akisi hatasi sayisi (saglikli veride sifirlanir).
  int _akisHatasi = 0;

  /// Haritadan nokta secme kipi (`true` ise dokunus noktayi secer).
  bool _noktaSec = false;
  bool _noktaBaslangicIcin = false;

  /// ⚠️⚠️⚠️ TURU 154 — **HARITA NOKTA SECICI** (kullanici emri:
  ///	*"harita nokta secerken ekranda bir PIN olsun, biraktigi
  ///	yerin ustune ONAY ISARETI olsun, BURASININ ADRESI
  ///	YAZSIN"*).
  ///
  /// ⚠️⚠️ **SABIT MERKEZ PIN** deseni (Uber/Google "set location on
  ///	map"): pin ekranin ORTASINDA DURUR, kullanici HARITAYI
  ///	kaydirir. Dokunulan yere pin BIRAKMAK yerine bu secildi —
  ///	parmak dokundugu noktayi KAPATIR ve kullanici tam nereye
  ///	bastigini goremez.
  ///
  /// Haritanin son duran merkezi (adres bunun icin cozulur).
  ({double enlem, double boylam})? _noktaMerkez;

  /// Merkezin cozulmus adresi; `null` ise heniz cozulmedi.
  String? _noktaAdres;

  /// ⚠️ Adres cozumu ucusta mi — kartta "Adres alınıyor…" yazar.
  ///    Bos birakmak kullaniciya "adres YOK" gibi gorunurdu.
  bool _noktaAdresYukleniyor = false;

  /// Ucustaki adres cozumunun nesli (bayat yanit kapisi).
  int _noktaNesli = 0;

  /// Durak kartlari seridi - pine dokununca secili karta kaydirmak icin.
  /// ⚠️ `dispose`ta birakilir; birakilmazsa her mod acilisinda bir
  ///    denetleyici SIZARDI.
  final ScrollController _durakSerit = ScrollController();

  /// Kamerayi bir DIKDORTGENE sigdirma istegi (rota bulununca).
  /// ⚠️ Nesil sayaci: ayni rota tekrar secilirse deger degismez ve kamera
  ///    TASINMAZDI (bu ekranda `_odak`/`_zoom` ile ayni ders).
  ({double guney, double kuzey, double bati, double dogu, int nesil})? _sigdir;

  /// Haritaya verilecek **GERCEK** guzergah cizgisi (`null` = cizme).
  ///
  /// ⚠️⚠️ TURU 149 — noktalar GTFS `shapes.txt`ten geliyor, yani hattin
  ///	RESMI cizimidir ve **gercekten sokaklari takip eder**. Turu 148'deki
  ///	konumdan turetilmis ORNEK cizgi KALDIRILDI.
  ({List<LatLng> noktalar, Color renk})? get _guzergahCizgisi {
    final c = _hatCizgi;
    if (c == null || c.noktalar.isEmpty) return null;
    return (
      noktalar: [
        for (final nk in c.noktalar) LatLng(nk.enlem, nk.boylam),
      ],
      renk: c.renk,
    );
  }

  String get _onbellekAnahtari => '$_kategori|$_km';

  /// ⚠️⚠️⚠️ **LISTE NESLI — POPUPUN KENDINI YENILEMESI ICIN.**
  ///
  ///	`_dalCipi` once dali secer (`_yukle` BASLAR ama BEKLENMEZ), hemen
  ///	ardindan %70 popupu acar. Popup `showModalBottomSheet` ile AYRI bir
  ///	route'ta dogar; ekranin `setState`i o agaci YENIDEN CIZMEZ. Yani
  ///	yanit geldiginde popup **ONCEKI dalin isletmelerini** gostermeye
  ///	devam ederdi ve kendini HIC onarmazdi (denetimde SEVK ENGELI).
  ///
  /// ⚠️⚠️ `ValueNotifier` + `ValueListenableBuilder` KULLANILIR, popupun
  ///	`setState`ini bir alanda saklamak DEGIL: sheet kapanirken saklanan
  ///	geri cagirim OLU bir `State`e `setState` cagirabilir.
  ///	`ValueListenableBuilder` dispose'ta KENDISI aboneligi birakir.
  /// ⚠️ Deger `_yukle`nin HER sonucunda artar (basari VE hata dali).
  final ValueNotifier<int> _listeNesli = ValueNotifier<int>(0);

  /// Dal -> sunucu kategorisi.
  ///
  /// ⚠️ Bilinmeyen dal SUNUCUYA GONDERILMEZ (400 doner). 'akaryakit'
  ///    disindaki her dal zaten gecerli bir kategori anahtaridir.
  static String _dalKategori(String dal) =>
      dal == 'akaryakit' ? 'oto' : dal;

  /// ⚠️⚠️ TURU 137 — KAMERANIN ODAKLANACAGI NOKTA (serit kartindaki harita
  ///	dugmesi doldurur, bkz. `_haritadaGoster`).
  ///
  /// ⚠️ `_konum`DAN AYRI TUTULUR: `_konum` KULLANICININ yeri ve her
  ///	yenilemede yeniden yazilir; ikisi tek alanda tutulsaydi asagi-cek
  ///	kullaniciyi bakmak istedigi isletmeden KOPARIRDI.
  /// ⚠️ Kamera yalnizca DEGER DEGISTIGINDE tasinir (bkz. `didUpdateWidget`);
  ///    her `build`te `animateCamera` cagirmak haritayi surekli sarsardi.
  ({double enlem, double boylam, int nesil})? _odak;

  /// ⚠️⚠️ TURU 138 — YAKINLASTIRMA ISTEGI SAYACI (+ / − dugmeleri).
  ///
  ///	Deger bir ZOOM SEVIYESI DEGIL, "kac adim yakinlas/uzaklas" farkidir;
  ///	`_HaritaAlani` degisimi gorup `CameraUpdate.zoomIn/zoomOut` uygular.
  /// ⚠️⚠️ **SAYAC OLMAK ZORUNDA**: bayrakla yapilsaydi ayni yone IKINCI
  ///	dokunus "deger degismedi" sayilir ve SESSIZCE YOK SAYILIRDI —
  ///	kullanici iki kez basip bir kez yakinlasan bir harita gorurdu.
  /// ⚠️ `ValueNotifier` DEGIL duz alan: yeniden cizim maliyeti onemsiz.
  ///    (Eski gerekce "bu ekranda `dispose` YOK" idi; turu 141'de
  ///    `_listeNesli` icin `dispose` EKLENDI, ama bu alan icin notifier
  ///    yine de gereksiz.)
  ///    Yeniden cizim maliyeti onemsiz (harita platform gorunumu yeniden
  ///    KURULMAZ, yalnizca `didUpdateWidget` kosar).
  int _zoom = 0;

  /// ⚠️⚠️⚠️ TURU 139 — **KENDI KONUM PININDEKI PROFIL FOTOGRAFI** (kullanici
  ///	emri: *"bizim kendi navigasyonumuz yerine de resmimiz olsun, mevcut
  ///	profildeki resmi koy"*).
  ///
  ///	Burada tutulan sey IMZALI MEDYA ADRESIDIR: `avatar_media_id` tek
  ///	basina indirilemez, `/media/{id}/url` ile cozulmesi gerekir.
  /// ⚠️ Cozulemezse (`null`) pin ESKI haline duser (mor daire + navigasyon
  ///    ikonu) — kullanici konumunu HER DURUMDA gorur.
  String? _avatarAdres;

  /// ⚠️ Onbellek anahtari icin KARARLI kimlik: `ui.Image` her cozumde yeni
  ///    nesnedir, adres ise ayni fotograf icin (imza suresi boyunca) sabit.
  String _avatarAnahtar = '';

  // ⚠️ TURU 137 — `_kucult` (Turkce kucultme) SILINDI: tek kullanicisi
  //    kaldirilan metin suzgeciydi. Yeniden gerekirse `talep_ekranlari.dart`
  //    ve `hizmet_menusu.dart` ayni yardimciyi tasiyor.

  /// Haritada ve listede GOSTERILEN kume.
  ///
  /// ⚠️⚠️ SUZGEC ISTEMCIDE: `/isletmeler/yakinimda` ucu `q`/puan/kampanya
  ///	parametresi ALMIYOR ve liste en fazla 60 kayit. Sunucuya parametre
  ///	eklemek ayri bir tur isi; 60 kayitta istemci suzgeci FARK EDILMEZ.
  /// ⚠️ Harita ve liste AYNI kumeyi gosterir — ayrisirsa kullanici
  ///    haritada gordugu pini listede bulamaz.
  /// ⚠️⚠️⚠️ TURU 136/137 — **HARITADAKI ORNEK ISLETMELER** (kullanici emri:
  ///	*"haritada mockup isletmeler koyup tikladigimda kart seklinde"* +
  ///	*"mesela OTELE tikladigimda mockup veriler olacak ama sirket
  ///	kartlari DIREKT gelecek, en yakindaki ilk basta"*).
  ///
  ///	Canli veritabaninda koordinati OLAN isletme sayisi bir elin
  ///	parmaklarini gecmiyor; harita bu yuzden BOS gorunuyor ve tasarim
  ///	degerlendirilemiyordu. Bu kayitlar YALNIZCA tasarimi gostermek icin.
  ///
  /// ⚠️⚠️ **YAYIN ONCESI `false` YAPILACAK.** Acikken haritada GERCEK
  ///	OLMAYAN isletmeler gorunur. (Kardesi `kYakinOnizleme`,
  ///	`hizmet_menusu.dart`.)
  /// ⚠️ Kimlikler **`demo-` onekli**: karta dokunmak profil ACMAZ, durustce
  ///    "ornek kayit" der (turu 113'te demo gonderi kimlikleri de oneklendi).
  /// ⚠️ Konum KULLANICININ KONUMUNA GORE turetilir: sabit Gebze koordinati
  ///    yazilsaydi baska sehirdeki bir kullanici pinleri HIC goremezdi.
  static const kHaritaOnizleme = true;

  /// ⚠️⚠️ TURU 137 — ornekler artik **HER KATEGORI ICIN** uretiliyor.
  ///	Onceden bes sabit kayit vardi (yemek/market/kuafor/eczane/oto) ve
  ///	"Otel"e dokunan kullanici BOS harita goruyordu — yani yeni cipler
  ///	tanim geregi bos donerdi.
  /// ⚠️ Adlar UYDURMA ama TURU BELLI: kullanici hangi kategoriye baktigini
  ///    kartlardan anlayabilmeli.
  /// ⚠️⚠️⚠️ TURU 140 — **YEMEK ORNEKLERI GERCEK MARKALAR** (kullanici emri:
  ///	*"Yemek ornek olarak McDonald's, Burger King, Domino's Pizza, Popeyes
  ///	olsun, ben logolari klasore koyacagim"*).
  ///
  /// ⚠️⚠️ **MARKA HAKKI — DURUST NOT:** bunlar tescilli markalardir ve
  ///	logolari uygulama paketine gomuluyor. Ekranda "Örnek" etiketi ve
  ///	profil dokunusunda *"gerçek işletme değil"* uyarisi DURUYOR, ama
  ///	bu varliklar **YAYIN ONCESI** (`kHaritaOnizleme = false` ile
  ///	BIRLIKTE) paketten CIKARILMALI — aksi halde magazaya tescilli marka
  ///	gorselleri iceren bir ikili gider.
  /// ⚠️ `_ornekOfset` DORT satir; bes marka yazilirsa besincisi SESSIZCE
  ///    DUSER (`i < _ornekOfset.length` kapisi). Marka eklenecekse ofset
  ///    tablosuna da satir ekle.
  static const _ornekAdlar = <String, List<String>>{
    'yemek': ['McDonald\'s', 'Burger King', 'Domino\'s Pizza', 'Popeyes'],
    'kafe': ['Marina Kahve', 'Köşe Cafe', 'Gebze Roastery', 'Kitap & Kahve'],
    'market': ['Bahar Market', 'Yıldız Bakkal', 'Şen Market', 'Mahalle Marketi'],
    'giyim': ['Moda Butik', 'Trend Giyim', 'Deniz Tekstil', 'Stil Mağaza'],
    'kuafor': ['Marmara Kuaför', 'Salon Ece', 'Berber Kadir', 'Saç Atölyesi'],
    'guzellik': ['Cilt & Bakım', 'Güzellik Studyo', 'Estetik Merkez', 'Spa Gebze'],
    'diyetisyen': ['Dyt. Elif Kaya', 'Sağlıklı Yaşam', 'Beslenme Ofisi', 'Diyet Kliniği'],
    'oto': ['Teknik Oto Servis', 'Usta Oto', 'Lastikçi Murat', 'Oto Yıkama 7/24'],
    'saglik': ['Özel Poliklinik', 'Diş Hekimi Ayça', 'Fizik Tedavi Merkezi', 'Laboratuvar'],
    'eczane': ['Yıldız Eczanesi', 'Merkez Eczanesi', 'Hayat Eczanesi', 'Şifa Eczanesi'],
    'otel': ['Marmara Otel', 'Gebze Palas', 'Liman Butik Otel', 'Konak Konukevi'],
    'egitim': ['Bilgi Kurs Merkezi', 'Dil Akademi', 'Etüt Merkezi', 'Müzik Okulu'],
    'emlak': ['Gebze Emlak', 'Anahtar Gayrimenkul', 'Merkez Emlak', 'Konut Ofisi'],
    'spor': ['Form Spor Salonu', 'Pilates Studyo', 'Halı Saha Gebze', 'Boks Kulübü'],
    'teknoloji': ['Teknik Servis', 'Bilgisayar Dünyası', 'Telefon Tamir', 'Kamera Sistem'],
    'eglence': ['Bowling Merkezi', 'Oyun Salonu', 'Sinema Kulüp', 'Kaçış Odası'],
    'hizmet': ['Temizlik Ekibi', 'Nakliyat Gebze', 'Tesisatçı Ali', 'Boya Badana'],
    // ⚠️ TURU 141 — 'akaryakit' bir DAL'dir, sunucu kategorisi DEGIL
    //    (bkz. `_dalKategori`). Ornekler o dalda uretilir.
    'akaryakit': ['Shell Gebze', 'Opet Merkez', 'BP Sahil', 'Petrol Ofisi'],
  };

  /// ⚠️⚠️⚠️ TURU 139 — **ORNEK URUN ADLARI** (kullanici emri: *"alttaki
  ///	isletmelerin altina URUNLER koy"*).
  ///
  /// ⚠️⚠️ **YALNIZ `demo-` KAYITLAR ICIN.** Gercek isletmede urun ADI
  ///	sunucudan GELMIYOR (`/yakinimda` yaniti yalniz `urunSayisi` ve
  ///	`minFiyatKurus` tasir) ve kart basina `/users/{id}/urunler`
  ///	cagirmak seritte 12 EK ISTEK olurdu (turu 17'de kapatilan N+1).
  ///	Gercek kayitta sunucunun VERDIGI bilgi cizilir — bkz. `_urunSeridi`.
  /// ⚠️ YAPMA: bu listeyi gercek kayitlara da uygulama; ekranda "Örnek"
  ///    yazmayan bir kartta uydurma urun adi YANLIS BILGIDIR.
  static const _ornekUrunler = <String, List<String>>{
    // ⚠️ TURU 140 — marka adlariyla uyumlu hale getirildi.
    'yemek': ['Menü', 'Burger', 'Patates'],
    'kafe': ['Filtre kahve', 'Cheesecake', 'Sıcak çikolata'],
    'market': ['Ekmek', 'Süt', 'Yumurta'],
    'giyim': ['Gömlek', 'Kot pantolon', 'Mont'],
    'kuafor': ['Saç kesimi', 'Sakal', 'Fön'],
    'guzellik': ['Cilt bakımı', 'Manikür', 'Ağda'],
    'diyetisyen': ['Beslenme planı', 'Ölçüm', 'Kontrol'],
    'oto': ['Yağ değişimi', 'Balans ayar', 'Lastik'],
    'saglik': ['Muayene', 'Kontrol', 'Tahlil'],
    'eczane': ['Reçete', 'Vitamin', 'Dermokozmetik'],
    'otel': ['Tek kişilik', 'Çift kişilik', 'Kahvaltı dahil'],
    'egitim': ['Birebir ders', 'Grup dersi', 'Deneme sınavı'],
    'emlak': ['Satılık daire', 'Kiralık daire', 'Arsa'],
    'spor': ['Aylık üyelik', 'Pilates', 'Kişisel antrenör'],
    'teknoloji': ['Ekran değişimi', 'Batarya', 'Format'],
    'eglence': ['Tek oyun', 'Grup bileti', 'Öğrenci'],
    'hizmet': ['Ev temizliği', 'Nakliyat', 'Tesisat'],
  };

  /// ⚠️⚠️⚠️ TURU 140 — **ORNEK ISLETME LOGOLARI** (kullanici klasore koydu).
  ///
  /// Anahtar = `_ornekAdlar`daki ad; deger = paketlenmis varlik yolu.
  /// ⚠️⚠️ **POPEYES YOK** — kullanici klasore koymadi. Sahte bir logo
  ///	URETILMEDI; o kayit kategori ikonuna duser (bkz. `_ornekLogo`
  ///	cagri yeri). Dosya gelince buraya BIR SATIR eklenir ve pubspec'e
  ///	de eklenmesi gerekir.
  /// ⚠️ Bu yol `avatarMediaId`/`kapakMediaId` UZERINDEN KURULAMAZDI:
  ///    `MedyaGorsel` yalnizca SUNUCU medyasi kabul eder ve `demo-` onekli
  ///    bir kimlik gorunce hic istek atmadan BOS kutu cizer.
  static const _ornekLogo = <String, String>{
    'McDonald\'s': 'assets/marka/mcdonalds.jpg',
    'Burger King': 'assets/marka/burgerking.png',
    'Domino\'s Pizza': 'assets/marka/dominos.png',
  };

  /// ⚠️⚠️⚠️ TURU 142 — **HARITA PININDE MARKA RENGI** (kullanici emri:
  ///	*"haritada mesela yemek dedigimde IKONLAR DEGIL LOGOLAR gorunmeli,
  ///	ONLARIN RENGINE YAKIN"*).
  ///
  /// Anahtar = `_ornekLogo` ile AYNI ad; deger = markanin kurumsal rengine
  /// yakin bir ton. Pinin IC dolgusu bu renktir; logonun SAYDAM
  /// bolgelerinden bu renk gorunur ve logo cozulemezse pin yine markanin
  /// renginde kalir.
  /// ⚠️ Halka **BEYAZ KALIR** (`daireIsaret` sozlesmesi): harita zemini her
  ///    renkte olabilir; renkli halka acik zeminde kaybolurdu (turu 138).
  /// ⚠️ Renkler YAKLASIKTIR, kurumsal kilavuzdan alinmadi — zaten YALNIZ
  ///    `demo-` kayitlarda cizilir.
  static const _markaRenk = <String, Color>{
    'McDonald\'s': Color(0xFFDA291C),
    'Burger King': Color(0xFFD62300),
    'Domino\'s Pizza': Color(0xFF006491),
  };

  /// ⚠️⚠️⚠️ TURU 141 — **ORNEK VITRIN KALEMLERI** (kullanici emri: *"yemekte
  ///	menu resminin SAGINA ISMI, ALTINA FIYATI yazsin, kafede boyle"* +
  ///	*"benzin istasyonuna tikladiginda ... AKARYAKIT ISTASYONU FIYATLARI
  ///	(benzin, motorin ucretleri) gorunsun"* + *"odalar tikladiginda ODALAR
  ///	gozukecek"* + *"hizmetleri sana birakiyorum"*).
  ///
  /// Anahtar = **DAL** (`_dal`), deger = o dalda kartin altinda cizilecek
  /// kalemler. `gorsel` null ise yalniz ad + fiyat cizilir (yakit · oda ·
  /// hizmet); dolu ise solda kare gorsel de cizilir (yemek · kafe).
  ///
  /// ⚠️⚠️⚠️ **HEPSI ORNEKTIR VE YALNIZ `demo-` KAYITLARDA CIZILIR.**
  ///	Bu projede urun ADI/FIYATI/GORSELI `/yakinimda` yanitinda YOK
  ///	(yalnizca `urunSayisi` + `minFiyatKurus`), ve kart basina
  ///	`GET /users/{id}/urunler` cagirmak seritte **12 EK ISTEK** olurdu
  ///	(turu 17'de kapatilan N+1). Gercek kayitta eskisi gibi sunucunun
  ///	VERDIGI bilgi ("N ürün" · "en uygun X TL") cizilir.
  /// ⚠️⚠️ **AKARYAKIT FIYATI HICBIR YERDE YOK** (turu 96t'de yazili durust
  ///	sinir; backend'de ne tablo, ne uc, ne dis servis). Buradaki degerler
  ///	ORNEKTIR ve kart ekranda **"Örnek"** diye isaretlidir.
  ///	⚠️ YAPMA: bu sayilari "guncel fiyat" gibi sunma, gercek kayda tasima.
  /// ⚠️ Fiyat **DIZE** olarak yazilir, kurus DEGIL: bunlar hesaplanan bir
  ///    para degeri degil, gosterimlik ornek metinlerdir. Kurusa cevirmek
  ///    "bu sayi bir yerden geliyor" izlenimi verirdi.
  // ⚠️⚠️⚠️ TURU 143 — **`gorsel` ALANI TAMAMEN KALKTI** (kullanici emri:
  //	*"altindaki menulerde RESIMLERI KALDIR"*). Kalemler artik yalniz
  //	ad + fiyat tasiyor ve `kAiKartYuzey` zeminli bir KUTU icinde cizilir
  //	(kullanici: *"menuleri telefon ve harita gibi bir KATEGORI RADUS
  //	mantiginda bir KARENIN ICINE al"*).
  // ⚠️ Dort McDonald's menu fotografi (`menu_*.png`, ~170 KB) artik hicbir
  //    yerden okunmuyor -> `pubspec.yaml`tan da CIKARILDI (turu 116b'de
  //    olculen "olu varlik pakete giriyor" dersi). Dosyalar diskte ve
  //    git'te DURUYOR; geri istenirse birer satir.
  /// ⚠️⚠️⚠️ TURU 147 — **HIZMET DALLARINDA FIYAT YOK** (kullanici emri:
  ///	*"hizmetler FIYATLA KOTU DURUR, onlar icin farkli bir seyler
  ///	yapalim"*).
  ///
  /// Anahtar = DAL, deger = o daldaki HIZMET ADLARI. Kartin alt satirinda
  /// fiyat yerine bu adlar kutu icinde cizilir (`_hizmetSeridi`).
  /// ⚠️⚠️ **FIYAT BILEREK YOK**: bir doktorun/temizlikcinin ucreti ise
  ///	gore degisir; sabit bir rakam yazmak kullaniciya YANLIS BILGI
  ///	olurdu. Yemek/kafe/akaryakit/otel'de fiyat ANLAMLI oldugu icin
  ///	orada DURUYOR (bkz. `_ornekVitrin`).
  /// ⚠️ Bu adlar da ORNEKTIR ve YALNIZ `demo-` kayitlarda cizilir; gercek
  ///    kayitta sunucunun verdigi bilgi gosterilir (`_urunSeridi`).
  static const _ornekHizmet = <String, List<String>>{
    'hizmet': ['Ev Temizliği', 'Nakliyat', 'Tesisat', 'Boya & Badana'],
    'saglik': ['Muayene', 'Kontrol', 'Tahlil', 'Görüntüleme'],
    'diyetisyen': ['Beslenme Danışmanlığı', 'Ölçüm', 'Takip Programı'],
    'kuafor': ['Saç Kesim', 'Boya', 'Fön', 'Bakım'],
    'guzellik': ['Cilt Bakımı', 'Manikür', 'Ağda', 'Masaj'],
    'oto': ['Periyodik Bakım', 'Yağ Değişimi', 'Lastik', 'Kaporta'],
    'egitim': ['Birebir Ders', 'Grup Dersi', 'Deneme Sınavı'],
    'spor': ['Üyelik', 'Kişisel Antrenör', 'Grup Dersi'],
    'teknoloji': ['Ekran Değişimi', 'Batarya', 'Yazılım', 'Veri Kurtarma'],
    'emlak': ['Satılık', 'Kiralık', 'Değerleme', 'Danışmanlık'],
  };

  /// ⚠️⚠️ TURU 150 - **YAPAY ZEKA YORUM ALANI** (kullanici emri: *"tum
  ///	isletmelerde alttaki temizlik nakliyat MENU GOSTERIMI yerine YAPAY
  ///	ZEKA YORUM ALANI koy; hepsine oylesine bir yapay zeka yorumu yaz,
  ///	MOCKUP gibi dusun"*).
  ///
  /// Anahtar = DAL, deger = o dala ait ornek yorumlar. Kart basina
  /// kaydirilarak secilir (turu 141 dersi: imza [IsletmeOzet] almadan
  /// yazilsaydi bir daldaki DORT kart da AYNI yorumu gosterirdi).
  ///
  /// ⚠️⚠️ **BUNLAR GERCEK BIR MODELIN CIKTISI DEGIL** - kullanicinin
  ///	ACIKCA istedigi gibi MOCKUP. Bu yuzden kart uzerinde "Gebzem AI"
  ///	etiketiyle cizilir ve yayin oncesi `kHaritaOnizleme = false` ile
  ///	ornek kayitlarla BIRLIKTE paketten cikar.
  /// ⚠️⚠️ **YALNIZ `demo-` KAYITLARDA**: gercek bir isletmenin altina
  ///	uydurma bir "yapay zeka yorumu" yazmak kullaniciya YANLIS BILGI
  ///	olurdu (turu 139un *"gercek kayda uydurma urun adi yazma"*
  ///	kuraliyla ayni sinif).
  /// ⚠️ `_bosYorum` YEDEGI: tablosu olmayan bir dal eklenirse kart BOS
  ///    kalmaz; yukseklik zaten `_altSatirBoy` ile SABIT.
  static const _bosYorum = <String>[
    'Yakındaki kullanıcıların değerlendirmelerine göre işini düzgün yapan, iletişimi iyi bir yer.',
    'Kısa sürede dönüş yapıyor; fiyat ve hizmet dengesi bölgedeki benzerlerine göre makul.',
  ];

  static const _aiYorum = <String, List<String>>{
    'hizmet': [
      'Randevusuna sadık, işi bitince ortalığı toplayarak çıkıyor. Nakliyatta paketleme ekstra ücretli.',
      'Ev temizliğinde detaycı; tesisat işlerinde aynı gün dönüş yapabiliyor.',
      'Fiyatı yerinde görüp söylüyor, sonradan ek ücret çıkarmıyor.',
      'Yorumlarda en çok titiz ve dakik kelimeleri geçiyor.',
    ],
    'saglik': [
      'Muayenede acele etmiyor, tahlil sonuçlarını sade bir dille anlatıyor.',
      'Randevu saatine genelde sadık; yoğun saat öğleden sonra.',
      'Kontrol randevularını kendisi hatırlatıyor.',
    ],
    'diyetisyen': [
      'Programı kişiye göre kuruyor, katı listeler yerine alışkanlık değiştirmeye odaklanıyor.',
      'Haftalık takip mesajları düzenli; ölçüm kaydını uygulamadan paylaşıyor.',
    ],
    'kuafor': [
      'Kesimde ne istediğini dinliyor; boyada renk çıkışı yorumlarda olumlu.',
      'Hafta sonu yoğun, randevusuz gidince beklemek gerekebiliyor.',
      'Bakım sonrası ürün önerisinde ısrarcı değil.',
    ],
    'guzellik': [
      'Cilt bakımında ürünleri cilde göre seçiyor; işlem öncesi test yapıyor.',
      'Hijyen konusunda yorumlar oldukça olumlu.',
    ],
    'oto': [
      'Değişen parçayı gösteriyor, faturayı ayrıntılı kesiyor.',
      'Periyodik bakımda aynı gün teslim; kaporta işlerinde süre uzayabiliyor.',
      'Yağ değişimi için randevu almadan gidilebiliyor.',
    ],
    'egitim': [
      'Birebir derslerde seviye tespitiyle başlıyor; deneme sınavı sonuçlarını tek tek konuşuyor.',
      'Grup dersleri kalabalık değil, soru sormak rahat.',
    ],
    'spor': [
      'Aletler bakımlı; yoğun saat 18.00-21.00 arası.',
      'Kişisel antrenör desteğini üyelik dışında da alabiliyorsun.',
    ],
    'teknoloji': [
      'Ekran değişimini aynı gün yapıyor, çıkan parçayı veriyor.',
      'Veri kurtarmada önce ücretsiz inceleme yapıp sonuç ihtimalini söylüyor.',
    ],
    'emlak': [
      'İlandaki fotoğraflar yerinde çıkıyor; gezdirmede acele ettirmiyor.',
      'Bölgedeki metrekare fiyatlarını karşılaştırmalı anlatıyor.',
    ],
    'market': [
      'Raflar düzenli, son kullanma tarihine dikkat ediliyor.',
      'Akşam geç saatte de açık; kart geçiyor.',
    ],
    'eczane': [
      'Nöbet günlerinde de ulaşılabiliyor; muadil ilaç konusunda bilgilendiriyor.',
      'Reçetesiz ürünlerde yönlendirme yerine doktora danışmayı öneriyor.',
    ],
    'giyim': [
      'Beden değişimi sorunsuz; kampanya dönemlerinde stok hızlı tükeniyor.',
      'Deneme kabinleri geniş, personel üzerine gelmiyor.',
    ],
    'eglence': [
      'Hafta içi daha sakin; grup rezervasyonunda indirim uygulanıyor.',
      'Ses düzeni iyi, oturma alanı rahat.',
    ],
    'ulasim': [
      'Yoğun saatlerde bekleme kısa; araçlar temiz.',
      'Gece saatlerinde de çağrı alıyor.',
    ],
  };

  static const _ornekVitrin = <String, List<({String ad, String fiyat})>>{
    // ⚠️ TURU 146 — kullanici *"2 satirli menu ismi yaz, birde UZUN yaz,
    //    3 nokta nerede bitiriyor gorelim"* dedi: ikinci kalem IKI SATIR,
    //    ucuncusu kasitli olarak UZUN (ellipsis'i gostersin).
    'yemek': [
      (ad: 'Big Mac', fiyat: '229 ₺'),
      (ad: 'McChicken Menü', fiyat: '199 ₺'),
      (
        ad: 'Acılı Cheeseburger Menü Patates ve İçecek',
        fiyat: '259 ₺'
      ),
      (ad: 'Patates', fiyat: '79 ₺'),
    ],
    'kafe': [
      (ad: 'Filtre Kahve', fiyat: '95 ₺'),
      (ad: 'Cheesecake', fiyat: '145 ₺'),
      (ad: 'Sıcak Çikolata', fiyat: '110 ₺'),
    ],
    // ⚠️ Yakit kalemleri GORSELSIZ: pompa fotografi yok ve olsaydi da
    //    fiyattan dikkat calardi. Referans (Yandex/Google) da yalnizca
    //    ad + fiyat gosterir.
    'akaryakit': [
      (ad: 'Benzin', fiyat: '44,15 ₺/lt'),
      (ad: 'Motorin', fiyat: '45,80 ₺/lt'),
      (ad: 'LPG', fiyat: '22,40 ₺/lt'),
    ],
    'otel': [
      (ad: 'Tek Kişilik', fiyat: '1.250 ₺/gece'),
      (ad: 'Çift Kişilik', fiyat: '1.850 ₺/gece'),
      (ad: 'Aile Odası', fiyat: '2.400 ₺/gece'),
    ],
    // ⚠️ HIZMET dali kullaniciya birakilmisti (*"hizmetleri sana
    //    birakiyorum, mantigi tam oturtursun"*): yakit/oda ile AYNI dil —
    //    ad + fiyat, gorsel YOK. Hizmetin gorseli olmaz; olan sey bir
    //    ISCILIK ucretidir.
    // ⚠️ TURU 147 — `hizmet` dali BURADAN CIKTI: fiyat gosterimi
    //    hizmetlerde kotu duruyordu (kullanici emri) -> `_ornekHizmet`.
    //    Kayit SILINMEDI, adi degistirildi ki fiyat bicimi bir daha
    //    gerekirse ornek olarak dursun (`_menuluSerit` onu OKUMAZ).
    'hizmet_fiyatli_eski': [
      (ad: 'Ev Temizliği', fiyat: '900 ₺'),
      (ad: 'Nakliyat', fiyat: '2.500 ₺'),
      (ad: 'Tesisat', fiyat: '650 ₺'),
    ],
  };

  /// ⚠️ Kaydirma (derece) ve mesafe TABLOSU: dorduncu kart en uzakta.
  ///    Boylamda `cos(enlem)` uygulanmaz — bunlar OLCUM DEGIL yer tutucu.
  // ⚠️ TURU 149 — turu 148'in ORNEK hat/guzergah tablosu SILINDI:
  //	kullanici GERCEK GTFS verisini verdi (bkz. `features/ulasim/`).
  //	Uydurma veri, gercegi varken tutulmaz.
  static const _ornekOfset = <({double dEn, double dBoy, double km})>[
    (dEn: 0.0022, dBoy: 0.0016, km: 0.25),
    (dEn: -0.0018, dBoy: 0.0027, km: 0.42),
    (dEn: 0.0035, dBoy: -0.0029, km: 0.68),
    (dEn: -0.0051, dBoy: 0.0044, km: 1.1),
  ];

  List<IsletmeOzet> _ornekIsletmeler(({double enlem, double boylam}) k) {
    // ⚠️⚠️ **YALNIZ SECILI KATEGORININ ORNEKLERI.** "Tümü"de hepsini
    //	uretmek 17 x 4 = 68 sahte kart demekti; harita pinlerle dolar ve
    //	gercek kayitlar kaybolurdu.
    // ⚠️ TURU 141 — anahtar `_kategori` DEGIL `_dal`: 'akaryakit' dalinda
    //    sunucu kategorisi 'oto'dur ama ornekler akaryakit istasyonlaridir.
    final adlar = _ornekAdlar[_dal];
    if (adlar == null) return const [];
    final cikti = <IsletmeOzet>[];
    for (var i = 0; i < adlar.length && i < _ornekOfset.length; i++) {
      final o = _ornekOfset[i];
      final e = IsletmeOzet(
        id: 'demo-harita-$_dal-$i',
        ad: adlar[i],
        kullaniciAdi: '',
        avatarUrl: '',
        avatarMediaId: null,
        kategori: _kategori,
        il: 'Kocaeli',
        ilce: 'Gebze',
        adres: 'Gebze, Kocaeli',
        // ⚠️ Ilk kayit "onayli": rozetin nasil durdugu da gorunsun.
        dogrulandi: i == 0,
        puan: i == 3 ? null : 4.8 - i * 0.3,
        puanSayisi: i == 3 ? 0 : 120 - i * 30,
        kampanyalar: i == 0 ? const ['%20 indirim'] : const [],
      );
      // ⚠️ Bu uc alan KURUCUDA yok (sunucu yanitindan sonra yazilir).
      e.enlem = k.enlem + o.dEn;
      e.boylam = k.boylam + o.dBoy;
      e.km = o.km;
      cikti.add(e);
    }
    return cikti;
  }

  List<IsletmeOzet> get _gorunen {
    // ⚠️⚠️ TURU 136 — ORNEK KAYITLAR **SUZGECLERIN ONUNE** eklenir, sonra
    //	AYNI suzgecten gecer. Suzgecten MUAF tutulsalardi "4+ puan" ya da
    //	"kampanyali" secildiginde gercek kayitlar elenir, ornekler ekranda
    //	KALIRDI — suzgec bozuk sanilirdi (turu 121d'de demo ilanlarda
    //	birebir bu yasandi: 985.000 TL'lik ornek daire "1.000 TL alti"
    //	suzgecinde listede kaliyordu).
    // ⚠️ Konum YOKSA ornek de YOK: koordinatlari kullanicinin konumundan
    //    turetiliyor.
    final k = _konum;
    final kaynak = (kHaritaOnizleme && k != null)
        ? [..._liste, ..._ornekIsletmeler(k)]
        : _liste;
    // ⚠️ TURU 141 — metin suzgeci GERI GELDI (kullanici emri). Turkce
    //    duyarsiz: `toLowerCase()` "İ" harfini birlesik noktaya cevirir ve
    //    "İSTANBUL" -> "istanbul"u BULAMAZ.
    final q = _KategoriPopupState._sadelestir(_q.trim());
    return kaynak.where((i) {
      if (q.isNotEmpty &&
          !_KategoriPopupState._sadelestir(i.ad).contains(q)) {
        return false;
      }
      if (_fPuan && (i.puan ?? 0) < 4) return false;
      if (_fKampanya && i.kampanyalar.isEmpty) return false;
      if (_fOnayli && !i.dogrulandi) return false;
      if (_fKm > 0 && i.km > _fKm) return false;
      return true;
    }).toList();
  }

  bool get _suzgecVar =>
      _fPuan || _fKampanya || _fOnayli || _fKm > 0;
  /// ⚠️⚠️ TURU 88 — MESAFE **SABIT 10 km**, secici KALDIRILDI (kullanici emri:
  ///    *"10km icinde vs kaldir"*). Slider + "N km icinde" satiri ekrandan
  ///    cikti; yaricap yine sunucuya GONDERILIYOR (uc onu ZORUNLU beklemiyor
  ///    ama varsayilani da 10, yani sozlesme degismedi).
  /// ⚠️ Alan : secici kalkinca degisen tek yazici da gitti.
///    Secici geri istenirse  yapilip slider baglanir.
  /// ⚠️ YAPMA: sunucuya `km` gondermeyi birakma — uc tavani 50 km ile
  ///    sinirliyor ve gondermezsek varsayilan yine 10 olur, ama acik
  ///    gondermek niyeti belgeliyor.
  static const double _km = 10;

  @override
  void dispose() {
    // ⚠️ TURU 141 — `_listeNesli` bir `ValueNotifier`; birakilmazsa
    //    dinleyicileri sizar.
    _listeNesli.dispose();
    _durakSerit.dispose();
    // ⚠️ TURU 154 - adim kartlarinin sayfa denetleyicisi.
    _adimSayfa.dispose();
    // ⚠️ TURU 151 — konum akisi birakilmazsa GPS ekran kapandiktan
    //    sonra da acik kalir.
    _konumAkisi?.cancel();
    // ⚠️ TURU 155 — ayni sey pusula icin de gecerli.
    _pusulaAkisi?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _yukle();
    // ⚠️⚠️ TURU 150 - menuden "Durak" ile gelindiyse ekran DOGRUDAN
    //	durak modunda acilir.
    // ⚠️ `addPostFrameCallback` ZORUNLU DEGIL ama `_durakAc` konum
    //    yoksa `_mesaj` (SnackBar) gosteriyor; `initState` govdesinde
    //    `ScaffoldMessenger.of` cagirmak agac henuz kurulmadigi icin
    //    patlardi (turu 96i sinifi).
    if (widget.durakla) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_durakAc());
      });
    }
    // ⚠️ TURU 139 — kendi konum pinindeki profil fotografi (kullanici emri).
    unawaited(_avatariCoz());
  }

  /// ⚠️⚠️⚠️ TURU 85b — BAYAT-YANIT KAPISI (denetim bulgusu).
  ///
  ///	Serhim *"yeniden girme kapisi"* diyordu ama GOVDEDE KAPI YOKTU —
  ///	yalnizca `mounted` kontrolu vardi (CLAUDE.md'nin defalarca yazdigi
  ///	"yorumun anlattigi kontrol govdede yok" sinifi, bu kez yeni kodda).
  ///	`_yukle` DORT yerden cagriliyor (acilis · asagi-cek · kategori
  ///	degisimi · mesafe degisimi) ve kullanici hizli hizli kategori
  ///	degistirdiginde istekler PARALEL ucuyor. Yanitlar GELIS SIRASINA gore
  ///	`setState` ettigi icin YAVAS gelen ESKI sorgu, HIZLI gelen YENISININ
  ///	uzerine yaziyordu: ekranda "Eczane" secili gorunurken liste
  ///	OTELLERI gosteriyordu.
  ///
  /// FIX: her cagri bir NESIL alir; yalnizca EN SON nesil ekrana yazabilir.
  /// ⚠️ Sayac `await`lerden ONCE artirilir ve YEREL bir kopya yakalanir.
  /// ⚠️ YAPMA: bunu tek bir `bool _mesgul` bayragiyla degistirme — o, ikinci
  ///    istegi TAMAMEN reddeder ve kullanicinin son secimi UYGULANMAZDI.
  int _nesil = 0;

  /// Profil fotografinin IMZALI adresini cozer (kendi konum pini icin).
  ///
  /// ⚠️ Servis TUM await'lerden ONCE yakalanir: kullanici geri basarsa
  ///    `ref.read` `StateError` firlatir ve `catch` onu yutar (turu 77b).
  /// ⚠️ Hata SESSIZ: fotograf cozulemezse pin ikonlu haline duser; bu bir
  ///    ARIZA DEGIL, yalnizca sussuz bir yedek.
  Future<void> _avatariCoz() async {
    // ⚠⚠ `.future` KULLANILIR, `valueOrNull` DEGIL: `initState`te profil
    //    HENUZ YUKLENMEMIS olur ve `valueOrNull` null doner -> fotograf HIC
    //    cizilmezdi (bu projede "olu ozellik" sinifinin en sik kokü).
    final istek = ref.read(myProfileProvider.future);
    final svc = ref.read(medyaServisiProvider);
    try {
      final profil = await istek;
      final mid = (profil['avatar_media_id'] ?? '').toString();
      if (!mounted || mid.isEmpty) return;
      final d = await svc.adres(mid);
      // ⚠️ Pin 26 dp — KUCUK RESIM yeter. `thumb_url` yoksa tam
      //    boyuta duseriz (`MedyaGorsel` ile AYNI sira).
      final u = (d['thumb_url'] ?? d['url'] ?? '').toString();
      if (!mounted || u.isEmpty) return;
      setState(() {
        _avatarAdres = u;
        _avatarAnahtar = mid;
      });
    } catch (_) {
      // sessiz — yedek pin zaten cizilir
    }
  }

  Future<void> _yukle({bool konumuTazele = false}) async {
    if (!mounted) return;
    final nesil = ++_nesil;
    // ⚠️⚠️ TURU 144 — **ONBELLEK VARSA SPINNER GOSTERILMEZ.** Liste aninda
    //	cizilir, istek yine de atilir ve yanit gelince sessizce guncellenir.
    //	Boylece ayni kategoriler arasinda gidip gelmek ZIPLAMA URETMEZ.
    // ⚠️ `konumuTazele` (asagi-cek) onbellegi ATLAR: kullanici acikca
    //    "yenile" diyor, ona bayat veri gostermek yanlis olurdu.
    final hazir = konumuTazele ? null : _onbellek[_onbellekAnahtari];
    setState(() {
      _yukleniyor = hazir == null;
      _hata = null;
      if (hazir != null) _liste = hazir;
    });
    if (hazir != null) _listeNesli.value++;
    try {
      // ⚠️ Servis await'ten ONCE yakalanir (turu 78b dersi: disposed State'te
      //    `ref.read` StateError firlatir ve is SESSIZCE iptal olur).
      final svc = ref.read(isletmeServisiProvider);
      // ⚠️⚠️ TURU 85b — ASAGI-CEK **GPS'I DE TAZELER** (denetim bulgusu).
      //    Eskiden `_konum` bir kez alinip SUREKLI onbellekten okunuyordu;
      //    kullanici baska bir semte gidip asagi cekse bile liste ESKI
      //    konuma gore geliyordu. Ustelik haritadaki mavi nokta cihazin
      //    GERCEK konumunu ciziyordu -> pin ile liste BIRBIRINI TUTMUYORDU.
      final k = (konumuTazele ? null : _konum) ?? await KonumServisi.konumAl();
      if (!mounted || nesil != _nesil) return;
      // ⚠️⚠️⚠️ TURU 144 — **KONUM DEGISTIYSE ONBELLEK COPE.** Denetim
      //	bulgusu: kullanici baska bir sehre gidip asagi cektiginde YALNIZ
      //	o anki kategori tazeleniyordu; baska bir cipe dokununca onbellek
      //	ISABET ediyor ve ESKI SEHRIN isletmeleri **eski mesafeleriyle**
      //	("250 m") ANINDA ciziliyordu.
      // ⚠️ Esik ~200 m: GPS gurultusu her tazelemede onbellegi bosaltmasin.
      //    (0,002 derece ~ 222 m enlemde.)
      final eski = _konum;
      if (k != null &&
          eski != null &&
          ((k.enlem - eski.enlem).abs() > 0.002 ||
              (k.boylam - eski.boylam).abs() > 0.002)) {
        _onbellek.clear();
      }
      if (k == null) {
        setState(() {
          _yukleniyor = false;
          // ⚠️ TURU 85c — LISTE BURADA DA BOSALTILIR (denetim bulgusu).
          //    Kardes `catch` dalinda duzeltme yapilmisti ama BU dal
          //    atlanmisti: konum izni kaldirilip asagi cekildiginde ekran
          //    "Konumun alınamadı" derken harita BAYAT pinleri ve
          //    "N işletme yakınında" rozetini cizmeye devam ediyordu.
          //    ("Ayni kuralin iki kopyasi drift eder" — bu kez KENDI
          //     duzeltmemin kardes dalinda.)
          _liste = const [];
          _hata = 'Konumun alınamadı. Yakındakileri görebilmek için '
              'konum iznine ihtiyacımız var.';
        });
        // ⚠️ KONUM-YOK DALINDA DA artar (bkz. hata dali serhi).
        _listeNesli.value++;
        return;
      }
      final l = await svc.yakinimda(
        enlem: k.enlem,
        boylam: k.boylam,
        km: _km,
        kategori: _kategori,
      );
      if (!mounted || nesil != _nesil) return;
      _onbellek[_onbellekAnahtari] = l;
      setState(() {
        _konum = k;
        _liste = l;
        _yukleniyor = false;
      });
      // ⚠️ Acik %70 popup KENDINI yeniler (bkz. `_listeNesli` serhi).
      _listeNesli.value++;
    } catch (e) {
      if (!mounted || nesil != _nesil) return;
      setState(() {
        _yukleniyor = false;
        // ⚠️ Hata halinde liste BOSALTILIR: aksi halde harita ve kartlar
        //    BAYAT sonuclari cizmeye devam ediyordu ("N işletme yakınında"
        //    rozeti + pinler), yani kullanici hata seridini gorurken ALTTA
        //    guncel saniyordu (denetim bulgusu).
        _liste = const [];
        _hata = 'Yakındaki işletmeler alınamadı';
      });
      // ⚠️ HATA DALINDA DA artar: yoksa acik popup bayat listede kalirdi.
      _listeNesli.value++;
    }
  }

  /// ⚠️⚠️⚠️ TURU 88 — DUZEN YENIDEN KURULDU (kullanici emri).
  ///
  ///	*"harita %70 yukseklikte olacak · isletmeler sol sag scroll olacak ·
  ///	 10km icinde vs kaldir"*.
  ///
  /// ⚠️ Ekran artik **DIKEY KAYDIRILMIYOR**: harita ekranin %70'i, altta
  ///    YATAY kart seridi. Onceki hal bir `ListView` idi ve harita sabit
  ///    220px'ti. Dikey kaydirma KALKTIGI icin asagi-cek-yenile de anlamsiz
  ///    kaldi -> yenileme AppBar dugmesine tasindi (kaybolmadi).
  /// ⚠️ Yukseklikler `LayoutBuilder`dan turer, `MediaQuery`den DEGIL: AppBar
  ///    ve sistem cubuklari dusuldukten SONRAKI gercek alan budur; ekran
  ///    yuksekliginin %70'i alinsaydi kart seridi tasardi.
  @override
  /// ⚠️⚠️⚠️ TURU 115 — **YANDEX NAVIGATOR DUZENI** (kullanici iki ekran
  ///	goruntusu verdi: *"yakinimdayi bu sekilde yap, BIREBIR AYNI
  ///	istiyorum"*).
  ///
  /// Eski duzen: AppBar + ust %70 harita + altta yatay kart seridi. Yeni:
  ///  · harita **TAM EKRAN** (zemin),
  ///  · sol ustte geri, sag ustte "konumuma don" YUZEN dugmeler,
  ///  · altta `DraggableScrollableSheet`: arama kutusu + kategori cipleri;
  ///    yukari cekilince **Kategoriler / Geçmiş** sekmeleri ve 4 sutunlu
  ///    kategori izgarasi.
  ///
  /// ⚠️⚠️ `DraggableScrollableSheet` **`Stack`in SON cocugu**: Flutter hit
  ///	testini TERS sirada yapar; sayfa haritanin ALTINDA kalsaydi
  ///	surukleme jestini HARITA yerdi ve sayfa acilmazdi.
  /// ⚠️ Harita jestleri ACIK kalir (turu 86 karari) — sayfa yalnizca kendi
  ///    alaninda kaydirma alir, ustteki harita serbest.
  @override
  Widget build(BuildContext context) {
    // ⚠️ Cip seridi de KOSULLU (bkz. `_yuzenCipler` serhi): ikisi de yigina
    //    yalnizca GERCEK bir `Positioned` olarak girer.
    final hatSerit = _hatSeridi();
    return Scaffold(
      // ⚠️⚠️⚠️ TURU 143 — **KLAVYE HARITAYI OYNATIYORDU** (kullanici emri:
      //	*"aramaya tikladigimda arkada haritada oynuyor, bunu duzelt
      //	oynamasin"*). Denetimde OLCULDU: arama sayfasi bir `PopupRoute`
      //	(opaque=false, maintainState=true), yani ALTTAKI bu Scaffold
      //	KLAVYE ACIKKEN DE YERLESIME GIRIYOR. Varsayilan
      //	`resizeToAvoidBottomInset: true` govdeyi klavye kadar (~300 dp)
      //	KISALTIYOR; harita `Positioned.fill` oldugu icin gorunur bolgenin
      //	merkezi ~150 dp yukari kayiyor ve sayfa kapaninca GERI ZIPLIYOR.
      // ⚠️ **GUVENLI (denetimde dogrulandi):** bu route'ta odaklanabilir
      //    HICBIR girdi yok — `_panelArama` turu 142'den beri bir `InkWell`
      //    DUGMESI. Dosyadaki UC `TextField`in ucu de AYRI sheet
      //    route'larinda yasiyor ve klavyeyi kendileri karsiliyor.
      // ⚠️ YAPMA: bu bayragi kaldirma; `_panelBoy`daki `viewPaddingOf` da
      //    KALSIN — o IKINCI ve bagimsiz (~34 dp) yolu kapatiyor.
      resizeToAvoidBottomInset: false,
      // ⚠️ AppBar YOK: harita durum cubugunun ALTINA girer (Yandex boyle).
      //    Dugmeler `MediaQuery.paddingOf(context).top` ile guvenli alana
      //    konumlanir.
      body: Stack(
        children: [
          Positioned.fill(
            child: _HaritaAlani(
                merkez: _konum,
                // ⚠️⚠️ TURU 150 — DURAK MODUNDA isletme pinleri CIZILMEZ
                //	(kullanici emri: *"durak dedigimde ekranda duraklardan
                //	BASKA SEYLER GORUNMEMELI"*).
                isletmeler: _durakModu ? const [] : _gorunen,
                // ⚠️⚠️ TURU 150 - DURAK MODUNDA isletme listesi
                //	CIZILMIYOR; carki gostermek kullaniciya duraklarin
                //	yuklendigini SANDIRIRDI (emulatorde goruldu).
                yukleniyor: _durakModu ? false : _yukleniyor,
                // ⚠️ TEK KAYNAK: panel yuksekligi neyse harita da onu
                //    bilir; sabit bir sayi yazilsaydi ikisi AYRISIRDI.
                altDolgu: _panelBoy(context),
                // ⚠️ TURU 149 — secili GERCEK guzergah (yoksa null).
                guzergah: _guzergahCizgisi,
                // ⚠️⚠️ TURU 150 — ROTA BACAKLARI: yurume KESIK gri,
                //	otobus KALIN hat renginde (kullanici emri: *"durak
                //	guzergahi ve yurume mesafesi IKI RENK"*).
                rota: _rota?.bacaklar,
                sigdir: _sigdir,
                // ⚠️⚠️ TURU 154 — dokunus artik SECMEZ, kamerayi o
                //	noktaya TASIR; secimi ONAY dugmesi yapar.
                //	Boylece kullanici neyi sectigini ONCE gorur.
                noktaSec: _noktaSec
                    ? (en, boy) => setState(() {
                          _odak = (
                            enlem: en,
                            boylam: boy,
                            nesil: (_odak?.nesil ?? 0) + 1,
                          );
                        })
                    : null,
                merkezPin: _noktaSec,
                // ⚠️ TURU 155 — konum isaretinin yonu ve dogrulugu.
                yon: _yon,
                dogrulukM: _dogrulukM,
                kameraDurdu: _noktaSec ? _noktaMerkezDegisti : null,
                takipBacak: _takip?.bacak,
                takipEnlem: _takip?.izEnlem,
                takipBoylam: _takip?.izBoylam,
                // ⚠️ Yalniz TAKIP ACIKKEN baglanir: durak modunda
                //    harita kaydirmak zaten kamerayi etkilemiyor.
                eldeKaydirdi: _takip == null
                    ? null
                    : () {
                        if (_takipKamera) {
                          setState(() => _takipKamera = false);
                        }
                      },
                duraklar: _duraklar,
                // ⚠️⚠️ TURU 150 - DURAK MODUNDA pin dokunusu ESKI SHEET
                //	ACMAZ: panelde zaten kartlar var ve ustune bir sheet
                //	acmak kullanicinin "duraklardan baska sey gorunmesin"
                //	emriyle celisirdi. Bunun yerine karti SECER, serit o
                //	karta KAYAR ve kamera durak uzerine oturur.
                durakSec: (d) => _durakModu
                    ? _duragiSec(d, detay: true)
                    : unawaited(_durakDetay(d)),
                merkezNesli: _merkezNesli,
                // ⚠️⚠️ TURU 89 — STIL AYARDAN GELIR (kullanici emri).
                //    Stil CALISMA ANINDA degistirilebilir: eklenti
                //    `map_configuration.dart` stili DIFF'liyor ve
                //    `didUpdateWidget -> _updateOptions` ile push ediyor,
                //    yani harita YENIDEN KURULMAZ (`key` degistirmek GEREKMEZ).
                // ⚠️ YAPMA: `GoogleMapController.setMapStyle` kullanma —
                //    eklentide `@Deprecated('Use GoogleMap.style instead.')`.
                stil: haritaStiliSec(
                  ref.watch(haritaStiliProvider),
                  Theme.of(context).brightness,
                ),
                odak: _odak,
                kategori: _kategori,
                zoom: _zoom,
                avatarAdres: _avatarAdres,
                avatarAnahtar: _avatarAnahtar,
            ),
          ),
          _ustDugmeler(),
          // ⚠️ TURU 138 — +/- dugmeleri ust barin ALTINDA (kullanici emri).
          _zoomDugmeleri(),
          // ⚠️ SIRA: cipler alt sayfanin ALTINDA cizilir ki sayfa yukari
          //    cekilince ciplerin USTUNU ortsun (Yandex/Google deseni).
          _altPanel(),
          // ⚠️⚠️⚠️ TURU 150 — **YUZEN SUZGEC SERIDI KALDIRILDI**
          //	(kullanici emri: *"ilk ekrandaki 5 km icinde vs ANA KARTIN
          //	USTUNDEKI yeri de KALDIR"*).
          // ⚠️ Kod SILINMEDI (`_yuzenCipler`/`_filtreSatiri`/`_yuzenCip`
          //    `// ignore: unused_element` ile duruyor): bu dosyada ayni
          //    sinif silme BES kez komsu uyeyi de goturdu (turu 127/138/140/141).
          //    Geri istenirse tek satir yeter.
          // ⚠️ Suzgeclerin KENDISI OLU DEGIL: `isletmeFiltreAc` ekrani
          //    (`_fKm`/`_fPuan`/`_fKampanya`/`_fOnayli`) DURUYOR.
          // ⚠️⚠️ TURU 149 — cizili hat seridi. `Stack`e **null olarak
          //	girmez**: bu ekranin diger cocuklari `Positioned` ve
          //	0x0 non-positioned bir cocuk yigini 0x0'a dusurup EKRANIN
          //	TAMAMINI siler (turu 136'da emulatorde OLCULDU).
          if (hatSerit != null) hatSerit,
        ],
      ),
    );
  }

  double _panelBoy(BuildContext context) {
    // ⚠️⚠️ TURU 150 — DURAK MODUNDA panel govdesi bambaska; formul de
    //	AYRI. Ortak formule dal eklemek ikisini de okunmaz yapardi.
    //	Sira: 10 + [baslik 32] + 8 + [nereden/nereye] + 12
    //	      + [kart ya da ozet] + kPanelAltDolgu + alt.
    // ⚠️⚠️ TURU 151 - nereden/nereye dugmesi artik UC SATIR (adres
    //	eklendi) ve yuksekligi `_rotaDugmeBoy` TEK KAYNAGINDAN gelir.
    // ⚠️⚠️ Baslik satirinin yuksekligi SABIT 32: icindeki IconButton'a
    //    `BoxConstraints.tightFor(height: 32)` verildigi ve metin
    //    `Row` icinde dikeyde ORTALANDIGI icin yazi olcegi buyuse de
    //    satir BUYUMEZ (olculdu). Metin buyuyup satiri iterse formul
    //    govdeden ayrisir ve harita dolgusu kayardi.
    if (_noktaSec) {
      // ⚠️ Sira: 10 + baslik(32) + 8 + adres(2 satir) + 12
      //    + dugme(48) + kPanelAltDolgu + guvenli alan.
      final o0 = MediaQuery.textScalerOf(context);
      return (10 +
                  32 +
                  8 +
                  o0.scale(14) * 1.3 * 2 +
                  12 +
                  48 +
                  kPanelAltDolgu +
                  MediaQuery.viewPaddingOf(context).bottom)
              .ceilToDouble() +
          1;
    }
    if (_durakModu) {
      final alt0 = MediaQuery.viewPaddingOf(context).bottom;
      final govde = _takip != null
          ? _adimKartBoy(context)
          : _rota != null
              ? _rotaOzetBoy(context)
              : _durakKartBoy(context);
      // ⚠️⚠️ TURU 154 - **TAKIP ACIKKEN "Nereden/Nereye" CIZILMEZ**
      //	(bkz. `_durakPaneli`). Yururken adres degistirmek
      //	istenmez ve o iki dugme haritadan ~74 dp calardi.
      // ⚠️ Deger `_durakPaneli` govdesindeki kosulla AYNI
      //    ifadeden gelmek zorunda; ayrisirsa panel ile haritanin alt
      //    dolgusu kayar (bu ekranda UC KEZ yasandi).
      final ust = _takip != null ? 0.0 : _rotaDugmeBoy(context) + 12;
      return 10 + 32 + 8 + ust + govde + kPanelAltDolgu + alt0;
    }
    final o = MediaQuery.textScalerOf(context);
    // ⚠️⚠️⚠️ TURU 143 — **`viewPadding`, `padding` DEGIL** (kullanici emri:
    //	*"aramaya tikladigimda arkada HARITA OYNUYOR, duzelt"*).
    //	Flutter'da `padding = viewPadding - viewInsets`; arama sayfasinda
    //	KLAVYE acilinca `padding.bottom` **SIFIRA duser**, `_panelBoy`
    //	jest cubugu kadar kisalir, `GoogleMap.padding` degisir ve harita
    //	KAMERAYI KAYDIRIR. `viewPadding` klavyeden ETKILENMEZ.
    // ⚠️ YAPMA: burayi tekrar `paddingOf` yapma.
    final alt = MediaQuery.viewPaddingOf(context).bottom;
    // ⚠️⚠️⚠️ TURU 137 — HESAP GUNCELLENDI:
    //	· arama kutusu (48+10) **CIKTI** (kullanici emri),
    //	· kategori seciliyken ISLETME SERIDI (+12) **GIRDI**,
    //	· serit varken ULASIM KARTLARI cizilmiyor (bkz. `_altPanel`).
    //	Duzen: 12 (ust dolgu) + cip(40) + 12 [+ serit + 12] + ayrac(1)
    //	       + 12 + [ulasim] + 12 (alt dolgu) + guvenli alan
    // ⚠️ **BU HESAP GOVDEYLE BIREBIR OLMAK ZORUNDA**: harita dolgusu,
    //    yuzen cip seridi ve secili-isletme karti hep buradan konumlaniyor.
    //    Ayrisirsa kartlar panelin ALTINDA kalir (turu 132'de yasandi).
    // ⚠️⚠️ TURU 144 — kosuldan `_dal.isNotEmpty` **VE** `!_yukleniyor`
    //	CIKARILDI:
    //	· `_dal` kosulu, kullanicinin *"hicbir sey aktif olmadiginda hep
    //	  yakindakiler gorunecek"* emriyle gecersiz kaldi;
    //	· `_yukleniyor` ise GERI KONDU (denetim bulgusu): onbellek
    //	  ISKALADIGINDA `_liste` temizlenmedigi icin serit ve harita
    //	  pinleri **ONCEKI KATEGORIYI** cizmeye devam ediyordu — cip
    //	  "Kafe" seciliyken ekranda market kayitlari duruyordu.
    //	  ⚠️ Bu, kullanicinin sikayet ettigi ziplamayi GERI GETIRMEZ:
    //	     `_yukleniyor` artik YALNIZCA onbellek iskaladiginda true
    //	     (bkz. `_yukle`), yani daha once gorulen bir kategoriye
    //	     donuste serit HIC kaybolmaz.
    final seritVar = !_yukleniyor && _gorunen.isNotEmpty;
    final serit = seritVar ? _seritBoy(context) : 0.0;
    // ⚠️⚠️ TURU 143 — kisayol kartlari artik IKONSUZ ve %40 BUYUK; formul
    //	`_kisayolBoy` **TEK KAYNAGINA** devredildi (elle kopyalanan bir
    //	ikinci formul, kart degisince SESSIZCE geride kalirdi).
    // ⚠️⚠️ **PAY YOK**: `_ulasimKartlari` yalniz YATAY dolgu veriyor
    //	(`EdgeInsets.symmetric(horizontal: kYanBosluk)`) ve kartin govdesi
    //	`SizedBox(height: boy)`; `Expanded` dikeyde GEVSEK kisit verdigi
    //	icin `Row`un gercek yuksekligi TAM OLARAK `_kisayolBoy`.
    //	⚠️ Turu 143'un ilk yaziminda buraya `+ 8` konmustu — o, IKONLU
    //	   surumdeki `vertical: 4` dolgusunun kalintisiydi ve formulu
    //	   govdeden 8 dp UZUN yapiyordu (denetim yakaladi).
    final ulasim = _kisayolBoy(context);
    // ⚠️⚠️ **HATA SATIRI DA SAYILIR** (emulatorde goruldu): konum
    //	alinamayinca panele iki satirlik bir uyari + "Tekrar dene"
    //	dugmesi giriyor ve panel UZUYOR. Hesaba katilmazsa ustte yuzen
    //	filtre seridi panelin ALTINDA kalir (kayboldu sanilir).
    // ⚠️ 48 dp: iki satirlik metin ile TextButton`un buyugu.
    // ⚠️⚠️ **OLCULDU:** gercek yukseklik 48 dp @olcek 1.0/1.15/1.3 ve
    //	74 dp @2.0. Eski formul 41,1 veriyordu — cunku yalniz METNI
    //	olcuyordu; satirdaki `TextButton` ("Tekrar dene") Material'in
    //	48 dp'lik dokunma tabanini dayatiyor.
    // ⚠️⚠️ TURU 143 — **+6 dp**: hata blogunun ALTINDAKI
    //	`SizedBox(height: 6)` (govdede DURUYOR) formulde YOKTU; olculdu,
    //	gercek yukseklik 54,0 dp @olcek 1.0-1.3 ve 80,0 @2.0 iken formul
    //	48,0 / 51,6 / 76,2 veriyordu. Eksik olan pay tam da o 6 dp'ydi.
    final hataBoy =
        _hata == null ? 0.0 : math.max(48.0, o.scale(13) * 1.35 * 2 + 6) + 6;
    // ⚠️⚠️ TURU 141 — **ARAMA ALANI HESABA GIRDI** (`_aramaBoy + 12`).
    //	Govdede `_hizliCipler` -> 12 -> `_panelArama` -> 12 sirasi var;
    //	terim TAM O YERE konur. Yazilmasaydi `_panelBoy` govdeyle AYRISIR
    //	ve (a) haritanin alt dolgusu, (b) yuzen filtre seridinin konumu
    //	IKISI DE kayardi (`altDolgu` ve `_panelBoy + 10`).
    // ⚠️⚠️ TURU 143 — cip seridi (40 + 12) terimi **GERI GELDI** (kullanici
    //	emri). Govdedeki sira: 10 -> cip(40) -> 12 -> arama -> 12 -> ...
    //	Bu hesap govdeyle BIREBIR olmak ZORUNDA (bkz. ustteki serh).
    // ⚠️ Govdedeki sira (TURU 145): 10 -> [hata] -> arama -> 12 -> cip(40)
    //    -> 12 -> [ayrac(1) + 12] -> [serit + 12] -> ulasim -> 12 + alt.
    // ⚠️⚠️ Ayrac SERITLE BIRLIKTE girer/cikar (govdede de oyle) — ayri ayri
    //	yazilsalardi serit yokken formul 13 dp FAZLA verirdi.
    // ⚠️ Serit varken ALTINA 12 dp bosluk girer (kisayollardan ayirmak icin).
    final ayrac = seritVar ? 13.0 : 0.0;
    final seritAlt = seritVar ? 12.0 : 0.0;
    // ⚠️⚠️⚠️ TURU 144 — **ALT DOLGU (`kPanelAltDolgu`) FORMULE GERI KONDU.**
    //	Ilk yazimda dusmustu ve denetim OLCTU: gercek 600 / formul 588
    //	(seritli), gercek 215 / formul 203 (seritsiz) — HER DURUMDA 12 dp.
    //	Sonucu: yuzen filtre seridi `_panelBoy + 10` ile konumlandigi icin
    //	panelin 10 dp USTUNDE degil, yuvarlak ust kenarinin **2 dp ICINDE**
    //	duruyordu; ayrica `GoogleMap.padding` 12 dp eksik gidiyordu.
    // ⚠️ Govdedeki `Padding(fromLTRB(0, 10, 0, kPanelAltDolgu + alt))` ile
    //    **AYNI SABITTEN** besleniyor — ayrisma yapisal olarak imkansiz.
    return 10 +
        _aramaBoy(context) +
        12 +
        40 +
        12 +
        ayrac +
        serit +
        seritAlt +
        ulasim +
        hataBoy +
        kPanelAltDolgu +
        alt;
  }

  /// ⚠️⚠️⚠️ TURU 138 — **PANEL ZEMINI SIYAH** (kullanici emri: *"alttaki
  ///	alanin arka planin rengini siyah yapalim"*).
  ///
  /// ⚠️⚠️ **ZEMIN DEGISINCE ON PLAN DA DEGISMEK ZORUNDA.** Panelin icinde
  ///	tema renginden beslenen ON DOKUZ ayri metin/ikon var (cipler, serit
  ///	kartlari, ulasim kartlari, hata satiri, "Tekrar dene"). Yalnizca
  ///	zemini siyaha boyasaydik acik temada SIYAH ZEMINDE SIYAH YAZI
  ///	cikardi — turu 115b'de sohbet balonlarinda birebir bu yasandi
  ///	(**1,23:1** olculmustu).
  ///	Bu yuzden panel `Theme(brightness: dark)` ile sariliyor; `onSurface`
  ///	KENDILIGINDEN beyaza doner ve alt bilesenler tek tek boyanmaz.
  /// ⚠️⚠️ **`Builder` ZORUNLU** (turu 136'da OLCULEN tuzak): `Theme.of`
  ///	yalniz ATA elemanlari gezer. `Theme` bu metodun DONDURDUGU agacta,
  ///	yani `_altPanel`in aldigi `context` onun USTUNDE kalir. Alt cizerlere
  ///	(`_hizliCipler` · `_panelSeridi` · `_ulasimKartlari`) o context
  ///	gecirilseydi hepsi UYGULAMANIN temasini cozer ve siyah zeminde
  ///	okunmazdi.
  /// ⚠️ `Material` sarmali: `DefaultTextStyle`i o saglar; `Theme` tek basina
  ///    renk BELIRTMEYEN `Text`leri beyaza cevirmez (turu 129 dersi).
  /// ⚠️ Zemin `Colors.black` DEGIL `kAiZemin`: menu/GebzemAI ile AYNI siyah
  ///    (tek kaynak) — iki ekran arasinda ton farki olmasin.
  /// ⚠️⚠️⚠️ TURU 149 — **CIZILI HAT SERIDI.**
  ///
  /// Haritada bir guzergah ciziliyken ust barda hattin adini ve kapatma
  /// dugmesini gosterir.
  /// ⚠️ Kapatma yolu ZORUNLU: cizgi kalici olsaydi kullanici onu haritadan
  ///    kaldiramaz ve ekran "bozuk" gorunurdu (bu projede olu arayuz yasak).
  Widget? _hatSeridi() {
    if (_hatCizgi == null || _hatEtiketi.isEmpty) return null;
    final renk = _hatCizgi!.renk;
    return Positioned(
      left: kYanBosluk,
      right: kYanBosluk,
      top: MediaQuery.paddingOf(context).top + 8 + kHaritaDugmeOlcu + 10,
      child: Material(
        color: Colors.black.withValues(alpha: kHaritaDugmeAlfa),
        borderRadius: BorderRadius.circular(kYaricap(40)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() {
            _hatCizgi = null;
            _hatEtiketi = '';
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: renk,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _hatEtiketi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(LucideIcons.x, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _altPanel() {
    // ⚠️ TURU 143 — `_panelBoy` ile AYNI KAYNAK olmak ZORUNDA (bkz. oradaki
    //    serh): ikisi ayrisirsa panel ile harita dolgusu birbirini tutmaz.
    final alt = MediaQuery.viewPaddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Theme(
        data: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: morLogo,
            brightness: Brightness.dark,
          ).copyWith(surface: kAiZemin),
          scaffoldBackgroundColor: kAiZemin,
          textTheme: ThemeData.dark(useMaterial3: true)
              .textTheme
              .apply(fontFamily: 'Google Sans'),
          // ⚠️ Uygulamanin "dokunma dairesi YOK" karari (turu 7 kullanici
          //    emri) `ThemeData.dark()` ile SIFIRLANIYOR; acikca geri konur.
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Builder(
          builder: (context) => _panelGovde(context, alt),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 150 — **DURAK MODU PANELI** (kullanici emri).
  ///
  /// Duzen: [Nereden] / [Nereye] satiri -> yatay DURAK KARTLARI.
  /// Rota bulunduysa kartlarin yerini ROTA OZETI alir (kullanici emri:
  /// *"rota bulununca alttaki durak kartlari gidecek"*).
  Widget _durakPaneli(BuildContext context, double alt) {
    final tema = Theme.of(context);
    final k = _konum;
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kAiZemin,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [
            BoxShadow(blurRadius: 18, color: Color(0x33000000)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, kPanelAltDolgu + alt),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── BASLIK + CIKIS ──
              // ⚠️⚠️ Cikis yolu ZORUNLU: durak modu cip seridini, aramayi ve
              //    kisayollari GIZLIYOR; X olmasaydi kullanici moddan
              //    cikamaz ve ekran kilitlenmis gibi gorunurdu.
              Padding(
                padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, 6, 8),
                child: Row(
                  children: [
                    Text(
                      _takip != null
                          ? 'Yol tarifi'
                          : _rota != null
                              ? 'Rota'
                              : 'Yakındaki duraklar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tema.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    // ⚠️ TURU 154 - takip surerken "Duraklar" CIZILMEZ:
                    //    yol ortasinda rotayi dusuren bir dugme, en
                    //    kotu anda basilabilecek dugmedir.
                    if (_rota != null && _takip == null)
                      TextButton(
                        onPressed: () => setState(() {
                          _rota = null;
                          _seciliDurak =
                              _duraklar.isEmpty ? null : _duraklar.first;
                        }),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Duraklar',
                            style: TextStyle(fontSize: 13)),
                      ),
                    IconButton(
                      onPressed: _durakKapat,
                      iconSize: 20,
                      constraints:
                          const BoxConstraints.tightFor(width: 40, height: 32),
                      padding: EdgeInsets.zero,
                      icon: Icon(LucideIcons.x,
                          color: tema.colorScheme.onSurface
                              .withValues(alpha: 0.75)),
                      tooltip: 'Durakları kapat',
                    ),
                  ],
                ),
              ),
              // ── NEREDEN / NEREYE ──
              // ⚠️⚠️ TURU 154 - **TAKIP ACIKKEN CIZILMEZ.** Yururken
              //	adres degistirmek istenmez; ustelik referans
              //	ekranda (Google Maps navigasyon) da yoktur ve o
              //	iki dugme haritadan ~74 dp calardi.
              // ⚠️ `_panelBoy` AYNI kosulu okur; ayrisirsa panel ile
              //    haritanin alt dolgusu kayar.
              if (_takip == null) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: kYanBosluk),
                  child: Row(
                    children: [
                      Expanded(
                        child: _rotaDugmesi(
                          context,
                          LucideIcons.circleDot,
                          const Color(0xFF2BB673),
                          'Nereden',
                          _rotaBas?.ad ?? 'Konumum',
                          _rotaBas?.altAd ?? '',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _rotaDugmesi(
                          context,
                          LucideIcons.mapPin,
                          const Color(0xFFFF5E5E),
                          'Nereye',
                          _rotaVaris?.ad ?? 'Seç',
                          _rotaVaris?.altAd ?? '',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // ── ROTA OZETI **YA DA** DURAK KARTLARI ──
              // ⚠️⚠️ TURU 151 — takip acikken panel **ADIM KARTINA**
              //	doner (kullanici emri: *"ekranda STEP EKRANI
              //	olacak"*). Referans desen (arastirmada dogrulandi,
              //	Citymapper/Google): **TEK adim** gosterilir ve o
              //	adimin EYLEMI yazilir, bacagin adi degil.
              if (_takip != null && _rota != null)
                _adimKarti(context, _rota!, _takip!)
              else if (_rota != null)
                _rotaOzeti(context, _rota!)
              else
                SizedBox(
                  height: _durakKartBoy(context),
                  child: _duraklar.isEmpty
                      ? Center(
                          child: Text(
                            'Yakınında durak bulunamadı.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: tema.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: _durakSerit,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: kYanBosluk),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _duraklar.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (_, i) => _durakKarti(
                            context,
                            _duraklar[i],
                            k,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// [Nereden]/[Nereye] dugmesinin yuksekligi - **TEK KAYNAK**.
  ///
  /// ⚠️⚠️ `_panelBoy` de bunu okur. Ayri yazilsalardi biri
  ///	degisince oteki geride kalir ve haritanin alt dolgusu
  ///	kayardi (bu ekranda ayni sinif turu 143/144/150'de UC KEZ
  ///	yasandi).
  /// ⚠️ Icerik: etiket(10.5x1.2) + ad(13.5x1.25) + adres(10.5x1.2)
  ///    + dikey dolgu 2x6. Adres bos olsa DA ayni deger dondurulur:
  ///    ters geocoding sonradan geldiginde kutu ZIPLAMASIN.
  /// ⚠️ **+1 dp PAY**: `fontSize * height` carpimi gercek satir
  ///    yuksekligini TAM vermez, Flutter YUKARI yuvarlar.
  double _rotaDugmeBoy(BuildContext c) {
    final o = MediaQuery.textScalerOf(c);
    return (o.scale(10.5) * 1.2 * 2 + o.scale(13.5) * 1.25 + 12)
            .ceilToDouble() +
        1;
  }

  /// ⚠️⚠️⚠️ TURU 154 — **NOKTA SECME ONAY KARTI** (kullanici emri:
  ///	*"biraktigi yerin ustune ONAY ISARETI olsun, BURASININ
  ///	ADRESI YAZSIN"*).
  ///
  /// ⚠️ Adres UC HALDE de bir sey yazar: cozulurken "Adres
  ///    alınıyor…", cozulunce adres, cozulemezse koordinat. Bos
  ///    birakmak kullaniciya "burasi gecersiz" gibi gorunurdu.
  Widget _noktaSecKarti(BuildContext c, double alt) {
    final tema = Theme.of(c);
    final m = _noktaMerkez;
    final metin = _noktaAdresYukleniyor
        ? 'Adres alınıyor…'
        : (_noktaAdres ??
            (m == null
                ? 'Haritayı kaydır'
                : '${m.enlem.toStringAsFixed(5)}, ${m.boylam.toStringAsFixed(5)}'));
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kAiZemin,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [BoxShadow(blurRadius: 18, color: Color(0x33000000))],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, kPanelAltDolgu + alt),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── BASLIK + IPTAL ──
              Padding(
                padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, 6, 8),
                child: Row(
                  children: [
                    SizedBox(
                      height: 32,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _noktaBaslangicIcin
                              ? 'Başlangıcı seç'
                              : 'Varışı seç',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tema.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _noktaSecIptal,
                      iconSize: 20,
                      constraints:
                          const BoxConstraints.tightFor(width: 40, height: 32),
                      padding: EdgeInsets.zero,
                      icon: Icon(LucideIcons.x,
                          color: tema.colorScheme.onSurface
                              .withValues(alpha: 0.75)),
                      tooltip: 'Vazgeç',
                    ),
                  ],
                ),
              ),
              // ── ADRES ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: kYanBosluk),
                child: SizedBox(
                  width: double.infinity,
                  // ⚠️ SABIT IKI SATIR: adres gelince kart
                  //    ZIPLAMASIN (`_panelBoy` de bu olcuyu okuyor).
                  height: MediaQuery.textScalerOf(c).scale(14) * 1.3 * 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 8),
                        child: Icon(LucideIcons.mapPin,
                            size: 16, color: kVurgu(c)),
                      ),
                      Expanded(
                        child: Text(
                          metin,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── ONAY ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: kYanBosluk),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    // ⚠️ Merkez bilinmiyorsa PASIF: basildiginda
                    //    sessizce hicbir sey yapan dugme bu projede
                    //    "olu arayuz" sayilir.
                    onPressed: m == null
                        ? null
                        : () => _noktaSecildi(m.enlem, m.boylam),
                    icon: const Icon(LucideIcons.check, size: 18),
                    label: const Text('Burayı seç',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kYaricap(48)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rota ozet kartinin yuksekligi — **TEK KAYNAK** (`_panelBoy` de okur).
  ///
  /// Icerik: baslik satiri (17*1.1) + 8 + dort bacak satiri (15 dp) + 2x12.
  double _rotaOzetBoy(BuildContext c) {
    final o = MediaQuery.textScalerOf(c);
    // ⚠️ Ust satirin yuksekligi artik **BAŞLA dugmesiyle** (30 dp)
    //    metnin BUYUGU: dugme sabit, metin olcekle buyuyor.
    final ust = math.max(30.0, o.scale(17) * 1.1);
    return (ust + 8 + 4 * 15 + 24).ceilToDouble() + 1;
  }

  /// Takip acikken cizilen **ADIM KARTI**nin yuksekligi — TEK KAYNAK.
  ///
  /// ⚠️⚠️ TURU 156 - formul govdeyle TERIM TERIM yeniden yurundu
  ///	(baslik TEK satirdan IKI satira cikti):
  ///	  ust1 (17x1.15)  <- "8 dk · 630 m kaldı"
  ///	  + 2
  ///	  + ust2 (12x1.25) <- "Tüm rota: 31 dk · 09:05"
  ///	  + 8
  ///	  + ilerleme cubugu (20)
  ///	  + 10
  ///	  + adim sayfasi (15x1.25 x2 satir + 2 + 12x1.2)
  ///	  + 8
  ///	  + dugme (34)
  ///	  + 2x12 dolgu
  ///
  /// ⚠️ Ust satirda `math.max(20, ...)`: dugme/rozet gibi SABIT
  ///    ogeler kucuk olcekte metnin altina dusmesin.
  /// ⚠️ Sondaki **+1 pay**: `TextPainter` satir kutusunu YUKARI
  ///    yuvarlar, `fontSize * height` carpimi TAM vermez (turu
  ///    121/123/137 ayni ders).
  /// ⚠️⚠️ `_panelBoy` bu degeri OKUR; ayrisirsa haritanin alt dolgusu
  ///	ve yuzen serit KAYAR (bu ekranda UC KEZ yasandi).
  double _adimKartBoy(BuildContext c) {
    final o = MediaQuery.textScalerOf(c);
    final ust1 = math.max(20.0, o.scale(17) * 1.15);
    final ust2 = o.scale(12) * 1.25;
    final adim = o.scale(15) * 1.25 * 2 + 2 + o.scale(12) * 1.2;
    return (ust1 + 2 + ust2 + 8 + 20 + 10 + adim + 8 + 34 + 24)
            .ceilToDouble() +
        1;
  }

  /// Durak kartinin yuksekligi — **TEK KAYNAK** (`_panelBoy` de okur).
  ///
  /// Icerik: ad (2 satir) + 6 + uc hat satiri (her biri 22 dp) + 2x12 dolgu.
  double _durakKartBoy(BuildContext c) {
    final o = MediaQuery.textScalerOf(c);
    return (o.scale(14) * 1.25 * 2 + 6 + 3 * _hatSatirBoy(c) + 24)
            .ceilToDouble() +
        1;
  }

  /// Kartaki TEK bir hat satirinin yuksekligi - **TEK KAYNAK**.
  ///
  /// ⚠️⚠️⚠️ EMULATORDE GORULDU (yazi olcegi 2.0): satirlar SABIT 22 dp
  ///	idi ve metin olcekle buyuyunce **UST ALT KIRPILIYORDU**
  ///	("OSB - KENT..." satirinin harfleri kesiliyordu).
  /// ⚠️⚠️ Deger `_durakKartBoy` ile AYNI kaynaktan gelmek ZORUNDA:
  ///	ayri yazilsalardi biri degisince oteki geride kalir ve kart
  ///	ya tasar ya altta bos band birakirdi (turu 139 dersi).
  /// ⚠️ Taban 19 dp: hat rozetinin SABIT boyu (`hatRozeti(boy: 19)`)
  ///    - metin kucukken satir rozetten kisa olamaz.
  double _hatSatirBoy(BuildContext c) => math.max(
        22.0,
        MediaQuery.textScalerOf(c).scale(12.5) * 1.25 + 6,
      );

  /// Panelin [Nereden] / [Nereye] dugmesi.
  ///
  /// ⚠️⚠️ TURU 151 - **UC SATIR** (kullanici emri: *"ben sectigim
  ///	yerin ADRESI DE gorunmeli neredende ve nereyede"*):
  ///	etiket / ad / adres. Adres BOSSA ucuncu satir CIZILMEZ ama
  ///	kutu YINE AYNI BOYDA kalir - yoksa adres gelince
  ///	(ters geocoding saniyeler sonra donuyor) panel ZIPLARDI.
  Widget _rotaDugmesi(
    BuildContext c,
    IconData ikon,
    Color renk,
    String etiket,
    String deger,
    String alt,
  ) {
    final scheme = Theme.of(c).colorScheme;
    return Material(
      color: kYuzeyGri(c),
      borderRadius: BorderRadius.circular(kYaricap(52)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(_rotaPlanla()),
        child: SizedBox(
          height: _rotaDugmeBoy(c),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(ikon, size: 16, color: renk),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        etiket,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.2,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        deger,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (alt.isNotEmpty)
                        Text(
                          alt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.2,
                            color:
                                scheme.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️ Yatay durak karti — kullanici emri: *"en yakin duraklar AYNI
  ///	YEMEK KARTLARI GIBI gorunmeli, o duraktan gecenler yaklasanlar"*.
  ///	Kartta **UC HAT UST USTE**: rozet + hedef + "N dk".
  Widget _durakKarti(
    BuildContext c,
    Durak d,
    ({double enlem, double boylam})? konum,
  ) {
    final scheme = Theme.of(c).colorScheme;
    final secili = _seciliDurak?.id == d.id;
    final an = UlasimVeri.suAnDakika();
    final hatlar = [...?_durakHat[d.id]];
    hatlar.sort((a, b) {
      final ax = a.sonrakiler(an, adet: 1);
      final bx = b.sonrakiler(an, adet: 1);
      return (ax.isEmpty ? 1 << 30 : ax.first)
          .compareTo(bx.isEmpty ? 1 << 30 : bx.first);
    });
    final ilkUc = hatlar.take(3).toList();
    final m = konum == null
        ? null
        : UlasimVeri.kabaMetre(konum.enlem, konum.boylam, d.enlem, d.boylam);

    // ⚠️⚠️⚠️ EMULATORDE GORULDU: `kPanelKartEn` (372) 360 dp ekranda
    //	EKRANIN DISINA tasiyor ve kartin SAG UCUNDAKI **"N dk"**
    //	kirpiliyordu - yani kartin EN ONEMLI bilgisi gorunmuyordu.
    // ⚠️⚠️ Tavan ekrandan TURETILIR; sabit bir sayi yazilsaydi genis
    //	ekranda kart gereksiz dar, dar ekranda yine tasar olurdu.
    //	44 dp pay BILINCLI: sonraki kart KENARDAN GORUNUR ve
    //	kullanici seridin kaydigini anlar.
    final en = math.min(
      kPanelKartEn,
      MediaQuery.sizeOf(c).width - kYanBosluk - 44,
    );
    return SizedBox(
      width: en,
      child: Material(
        color: kYuzeyGri(c),
        borderRadius: BorderRadius.circular(kYaricap(96)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _duragiSec(d, detay: true),
          child: Container(
            // ⚠️⚠️⚠️ EMULATORDE OLCULDU: *"BOTTOM OVERFLOWED BY 2.2
            //	PIXELS"*. Sebep `decoration`di: `Container` kenarligi
            //	DOLGUNUN DISINA koyar ve cocugun kisitindan
            //	2 x 1.6 = **3.2 dp** DUSER. `_durakKartBoy` bunu
            //	gormedigi icin kart tasiyordu.
            // ⚠️⚠️ `foregroundDecoration` YERLESIMI DEGISTIRMEZ: cerceve
            //	cocugun USTUNE cizilir. Ayrica secili/secili-degil
            //	kartlar artik AYNI yukseklikte (yoksa serit her
            //	secimde 3.2 dp ZIPLARDI).
            foregroundDecoration: secili
                ? BoxDecoration(
                    border: Border.all(color: kVurgu(c), width: 1.6),
                    borderRadius: BorderRadius.circular(kYaricap(96)),
                  )
                : null,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: MediaQuery.textScalerOf(c).scale(14) * 1.25 * 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 6),
                        child: Icon(LucideIcons.busFront,
                            size: 15, color: Color(0xFF3AA9FF)),
                      ),
                      Expanded(
                        child: Text(
                          d.ad,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (m != null) const SizedBox(width: 8),
                      if (m != null)
                        Text(
                          m < 950
                              ? '${m.round()} m'
                              : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // ⚠️ UC HAT UST USTE (kullanici emri). Hicbiri yoksa
                //    DURUSTCE soylenir, bos satir birakilmaz.
                if (ilkUc.isEmpty)
                  SizedBox(
                    height: 3 * _hatSatirBoy(c),
                    child: Text(
                      _durakHat.containsKey(d.id)
                          ? 'Bugün sefer yok'
                          : 'Saatler yükleniyor…',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < 3; i++)
                    SizedBox(
                      height: _hatSatirBoy(c),
                      child: i < ilkUc.length
                          ? _hatSatiri(c, ilkUc[i], an)
                          : null,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hatSatiri(BuildContext c, DurakHatti dh, int an) {
    final scheme = Theme.of(c).colorScheme;
    final sonraki = dh.sonrakiler(an, adet: 1);
    final kalan = sonraki.isEmpty ? null : sonraki.first - an;
    return Row(
      children: [
        ulasim.hatRozeti(dh.hat, boy: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            dh.hat.yonBaslik[dh.yon] ?? dh.hat.uzunAd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        const SizedBox(width: 6),
        if (kalan != null)
          Text(
            kalan <= 60
                ? '$kalan dk'
                : UlasimVeri.saatMetni(sonraki.first),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: kalan <= 10 ? const Color(0xFF2BB673) : scheme.onSurface,
            ),
          ),
      ],
    );
  }

  /// ⚠️⚠️⚠️ TURU 154 - **ADIM (STEP) EKRANI, YENIDEN KURULDU.**
  ///
  ///	Kullanici emri: *"sana rota baslat ve step gorsellerini de
  ///	attim, ALAKASI YOK, arayuzu daha MODERN hale getir diyorum
  ///	yapmiyorsun"* + *"steplere tikladigimda hangi stepleri SOL
  ///	SAG yapinca harita o NOKTALARA gidiyor"*.
  ///
  /// Duzen (kullanicinin verdigi Google Maps ekran goruntusu):
  ///	1. **kalan sure** (ekranin en buyuk sayisi) + varis saati
  ///	2. **BACAK BACAK ilerleme cubugu** + sonda hat rozeti
  ///	3. **KAYDIRILABILIR adim karti** (sol/sag -> harita o bacaga)
  ///	4. Bitir - (takip birakilmissa) Merkeze don
  ///
  /// ⚠️⚠️ **TEK ADIM GOSTERILIR** (Citymapper: *"show you the step that
  ///	is most relevant"*); kart bacagin ADINI degil **EYLEMINI**
  ///	yazar. Tum liste "Bitir"e basinca ozet olarak zaten geri gelir.
  ///
  /// ⚠️⚠️ Takip acikken panelde **"Nereden/Nereye" CIZILMEZ** (bkz.
  ///	`_durakPaneli`): yururken adres degistirmek istenmez ve o iki
  ///	dugme haritadan ~74 dp calardi.
  ///
  /// ⚠️ Yukseklik `_adimKartBoy` TEK KAYNAGINDAN; `_panelBoy` de onu
  ///    okur. Ayrisirsa haritanin alt dolgusu ile yuzen serit KAYAR
  ///    (bu ekranda UC KEZ yasandi).
  Widget _adimKarti(BuildContext c, RotaAdayi a, takip.TakipDurumu d) {
    final scheme = Theme.of(c).colorScheme;
    final aktif = d.bacak.clamp(0, a.bacaklar.length - 1);
    final kalanDk = _kalanDakika(a, d);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
      child: SizedBox(
        height: _adimKartBoy(c),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kYuzeyGri(c),
            borderRadius: BorderRadius.circular(kYaricap(160)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              // ⚠️ TURU 156 — **`stretch`**: ust iki metin `textAlign`
              //    ile ortalanabilsin diye TAM GENISLIK almalari gerekiyor.
              //    `start` olsaydi metinler kendi genisliklerine buzulur ve
              //    `textAlign: center` HICBIR SEY YAPMAZDI.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: [
                // == 1) BU ADIMIN KALANI (ORTALI) + TUM ROTA ==
                //
                // ⚠️⚠️⚠️ TURU 156 — **REFERANS DUZEN** (kullanici: *"step
                //	adimini BOYLE yapmaliyiz"*, Yandex ekran goruntusu).
                //	Referansta ust satir ORTALI ve **BU BACAGIN** kalani
                //	("8 dk. · 630 m"), hemen altinda soluk ve ortali
                //	**TUM ROTA** ("Tüm rota: 31 dk. · 09:05").
                //
                // ⚠️⚠️ Onceki hal SOLA dayali TEK satirdi ve yalniz TUM
                //	ROTANIN kalanini yaziyordu; kullanici *"su anda kac
                //	metrem kaldi"* sorusunun cevabini GOREMIYORDU.
                //	Iki bilgi AYRI satirlarda: buyuk sayi SIMDIKI adim,
                //	kucuk satir yolculugun tamami.
                // ⚠️ Mesafe `ulasim.mesafeMetni` TEK KAYNAGINDAN (950 m
                //    ustu km). Ham metre yazmak "15240 m" uretiyordu.
                Text(
                  // ⚠️ Rota disindayken sure/mesafe YAZILMAZ: degerler
                  //    DONMUS olur ve kullanici onlari gecerli sanardi.
                  d.rotaDisi
                      ? 'Rotadan uzaktasın'
                      : !d.kalanM.isFinite
                          ? '$kalanDk dk kaldı'
                          : '${_bacakDakika(a, d)} dk · '
                              '${ulasim.mesafeMetni(d.kalanM)} kaldı',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: d.rotaDisi
                        ? const Color(0xFFFFC531)
                        : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tüm rota: $kalanDk dk · '
                  '${UlasimVeri.saatMetni(a.varisDakika)}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.60),
                  ),
                ),
                const SizedBox(height: 8),
                // == 2) BACAK BACAK ILERLEME CUBUGU ==
                _ilerlemeCubugu(c, a, d, aktif),
                const SizedBox(height: 10),
                // == 3) KAYDIRILABILIR ADIM KARTI ==
                // ⚠️⚠️ Harita senkronu kaydirma BITINCE (`onPageChanged`)
                //	yapilir; her karede tasinsaydi kamera parmakla
                //	YARISIR ve harita titrerdi.
                Expanded(
                  child: PageView.builder(
                    controller: _adimSayfa,
                    itemCount: a.bacaklar.length,
                    onPageChanged: (i) => _adimaGit(a, i),
                    itemBuilder: (_, i) => _adimIcerik(c, a, d, i, aktif),
                  ),
                ),
                const SizedBox(height: 8),
                // == 4) DUGMELER ==
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _takipDurdur,
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kYaricap(34)),
                            ),
                          ),
                          child: const Text('Bitir',
                              maxLines: 1, style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ⚠️⚠️ **MERKEZE DON** yalniz takip BIRAKILMISKEN
                      //	cizilir (Mapbox deseni: `FOLLOWING`de dugme
                      //	GONE). Hep gorunse, zaten takip edilen kamera
                      //	icin anlamsiz bir dugme olurdu.
                      // ⚠️ `Flexible` + `FittedBox`: yazi olcegi 2.0'da
                      //    "Merkeze dön" + ikon 360 dp'lik ekranda
                      //    tasardi (turu 143 kisayol karti dersi).
                      if (!_takipKamera)
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                final k = _konum;
                                setState(() {
                                  _takipKamera = true;
                                  if (k != null) {
                                    _odak = (
                                      enlem: k.enlem,
                                      boylam: k.boylam,
                                      nesil: (_odak?.nesil ?? 0) + 1,
                                    );
                                  }
                                });
                                // ⚠️ Kart da takip edilen adima geri
                                //    doner: kamera kullanicida, kart
                                //    baska adimda kalsaydi ikisi
                                //    CELISIRDI.
                                _adimSayfasinaGec(aktif);
                              },
                              icon: const Icon(LucideIcons.locateFixed,
                                  size: 15),
                              label: const Text('Merkeze dön',
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 154 - **BACAK BACAK ILERLEME CUBUGU.**
  ///
  ///	Gecilen bacaklar DOLU, icinde bulunulan KISMEN dolu, sonrakiler
  ///	SOLUK; sonda hattin rozeti. Dilimler bacak SURELERIYLE
  ///	orantili (`flex`): esit bolunseydi 2 dakikalik yurume ile
  ///	20 dakikalik otobus ayni genislikte gorunur ve cubuk YANLIS
  ///	bir ilerleme hissi verirdi.
  ///
  /// ⚠️⚠️ `Stack` + `FractionallySizedBox` KULLANILMADI: oran 0 iken
  ///	genislik 0 olur ve `RenderStack` boyutunu YALNIZ positioned
  ///	OLMAYAN cocuklarindan hesapladigi icin cubuk **0x0**'a
  ///	duserdi (turu 136'da ekranin tamamini silen hata).
  Widget _ilerlemeCubugu(
    BuildContext c,
    RotaAdayi a,
    takip.TakipDurumu d,
    int aktif,
  ) {
    final scheme = Theme.of(c).colorScheme;
    final bos = scheme.onSurface.withValues(alpha: 0.16);
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          for (var i = 0; i < a.bacaklar.length; i++) ...[
            Expanded(
              // ⚠️ En az 1: suresi 0 olan bir bacak (aninda kalkis)
              //    cubuktan TAMAMEN kaybolmasin.
              flex: math.max(1, a.bacaklar[i].dakika),
              child: _dilim(
                bos: bos,
                dolu: i == aktif
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.65),
                oran: i < aktif
                    ? 1.0
                    : i > aktif
                        ? 0.0
                        : _bacakOrani(a.bacaklar[i], d),
                // ⚠️⚠️ Kullanicinin BAKTIGI dilim KALIN cizilir.
                //	Kart kaydirilinca cubuk ile kart AYNI adimi
                //	gosterdigini soylemeli; yoksa kullanici 4.
                //	adima bakarken cubukta hicbir sey degismez ve
                //	nerede oldugunu KAYBEDERDI.
                kalinlik: i == _adimGorunen ? 8 : 6,
              ),
            ),
            if (i < a.bacaklar.length - 1) const SizedBox(width: 3),
          ],
          const SizedBox(width: 8),
          ulasim.hatRozeti(a.hat, boy: 20),
        ],
      ),
    );
  }

  /// Ilerleme cubugunun TEK dilimi.
  ///
  /// ⚠️⚠️⚠️ **`LinearProgressIndicator` KULLANILMADI**: Material 3'un
  ///	yeni surumu cubugun ucuna bir "stop indicator" noktasi ve
  ///	dolu/bos arasina bir bosluk koyuyor; dort minik dilimde bu
  ///	suslemeler cubugu OKUNAMAZ yapardi.
  ///
  /// ⚠️⚠️⚠️ **`Stack`/`FractionallySizedBox` DE KULLANILMADI**: oran 0
  ///	iken cocuk 0 genislige duser ve `RenderStack` boyutunu
  ///	YALNIZ positioned OLMAYAN cocuklarindan hesapladigi icin
  ///	dilim **0x0**'a coker (turu 136'da EKRANIN TAMAMINI
  ///	silen hata). Iki `Expanded` ile bu YAPISAL OLARAK imkansiz.
  ///
  /// ⚠️⚠️ `CrossAxisAlignment.stretch` ZORUNLU: `ColoredBox` cocuksuzdur
  ///	ve gevsek kisitta `constraints.smallest` alir, yani
  ///	yuksekligi **0** olur ve cubuk HIC gorunmezdi.
  /// ⚠️ `flex` tam sayi olmak zorunda; 1000'lik olcek 0,1% cozunurluk
  ///    verir ve `if` kapilari sayesinde flex ASLA 0 olmaz.
  Widget _dilim({
    required Color bos,
    required Color dolu,
    required double oran,
    required double kalinlik,
  }) {
    final p = (oran.clamp(0.0, 1.0) * 1000).round();
    return SizedBox(
      height: kalinlik,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kalinlik / 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p > 0) Expanded(flex: p, child: ColoredBox(color: dolu)),
            if (p < 1000)
              Expanded(flex: 1000 - p, child: ColoredBox(color: bos)),
          ],
        ),
      ),
    );
  }

  /// Bir bacagin tamamlanma orani (0..1).
  ///
  /// ⚠️ Toplam yol bilinmiyorsa **0** doner: UYDURMA bir oran cizmek
  ///    kullaniciya YANLIS ilerleme gosterirdi.
  /// ⚠️ `toplam > 0` ve `kalanM` sonlu oldugu icin bolme NaN uretemez;
  ///    `clamp` NaN'i **1.0**'a cevirdigi icin (olculdu: `compareTo`
  ///    ile karsilastirir, NaN en buyuk sayilir) bu kapi ZORUNLU.
  double _bacakOrani(RotaBacagi b, takip.TakipDurumu d) {
    final toplam = takip.yolUzunlugu(b.noktalar);
    if (toplam <= 0 || !d.kalanM.isFinite) return 0;
    return (1 - d.kalanM / toplam).clamp(0.0, 1.0);
  }

  /// ⚠️⚠️ TURU 156 — **ICINDE BULUNULAN BACAGIN** kalan dakikasi.
  ///
  ///	Referansta buyuk sayi TUM ROTA degil **SIMDIKI ADIM** icindir
  ///	("8 dk. · 630 m" = duraga kadar yurume).
  /// ⚠️ Yurume bacaginda mesafeden turetilir (yaya hizi TEK KAYNAK);
  ///    otobus/bekleme bacaginda mesafe anlamsiz oldugu icin bacagin
  ///    KENDI suresinin kalani (oranla) kullanilir.
  int _bacakDakika(RotaAdayi a, takip.TakipDurumu d) {
    final b = a.bacaklar[d.bacak.clamp(0, a.bacaklar.length - 1)];
    if (b.tur == BacakTuru.yuru && d.kalanM.isFinite) {
      return math.max(1, (d.kalanM / kYayaHizi / 60).ceil());
    }
    return math.max(1, (b.dakika * (1 - _bacakOrani(b, d))).ceil());
  }

  /// Rotanin TAMAMINDAN kalan dakika.
  ///
  /// ⚠️⚠️ Icinde bulunulan bacagin KALANI + sonraki bacaklarin TAMAMI.
  ///	Yalniz aktif bacagin suresi yazilsaydi kullanici "3 dk" gorup
  ///	25 dakika sonra varirdi - ozelligin en yaniltici hali.
  int _kalanDakika(RotaAdayi a, takip.TakipDurumu d) {
    final i = d.bacak.clamp(0, a.bacaklar.length - 1);
    final b = a.bacaklar[i];
    final oran = _bacakOrani(b, d);
    var dk = (b.dakika * (1 - oran)).ceil();
    for (var j = i + 1; j < a.bacaklar.length; j++) {
      dk += a.bacaklar[j].dakika;
    }
    // ⚠️ "0 dk kaldı" yazmak yerine en az 1: kullanici hala
    //    yuruyorsa sifir gormek "vardim mi?" sorusunu dogururdu.
    return math.max(1, dk);
  }

  /// Kaydirilabilir adim kartinin TEK sayfasi.
  ///
  /// ⚠️ Aktif OLMAYAN adim SOLUK cizilir ve sagda "i/N" sayaci durur:
  ///    kullanici kaydirdiginda hangi adimda oldugunu KAYBETMESIN.
  Widget _adimIcerik(
    BuildContext c,
    RotaAdayi a,
    takip.TakipDurumu d,
    int sira,
    int aktif,
  ) {
    final scheme = Theme.of(c).colorScheme;
    final b = a.bacaklar[sira];
    final bu = sira == aktif;
    final otobus = b.tur == BacakTuru.otobus;
    final renk = otobus ? ulasim.hatRengi(a.hat) : kYurumeRengi;
    // ⚠️⚠️ Kalan mesafe YALNIZ AKTIF bacakta yazilir: `kalanM` diger
    //	bacaklara AIT DEGILDIR ve orada yazilsaydi duz bir YALAN
    //	olurdu.
    // ⚠️⚠️ TURU 155 — mesafe `ulasim.mesafeMetni` ile bicimlenir.
    //	Kullanicinin ekran goruntusunde **"15240 m kaldı"** yaziyordu;
    //	15 kilometreyi metre cinsinden yazmak okunmaz. Bicimleyici
    //	ZATEN vardi, yalnizca `private` oldugu icin kullanilamiyordu.
    // ⚠️ EMULATORDE GORULDU (turu 151): "143 m kaldı · 143 m ·
    //    yaklaşık" - mesafe IKI KEZ yaziliyordu. Yurume bacaginin
    //    `altBaslik`i ZATEN mesafe tasiyor.
    final alt = !bu || !d.kalanM.isFinite
        ? '${b.dakika} dk · ${b.altBaslik}'
        : d.rotaDisi
            ? 'Rotadan uzaktasın — çizgiye dön'
            : b.tur == BacakTuru.yuru
                ? '${ulasim.mesafeMetni(d.kalanM)} kaldı · yaklaşık'
                : '${ulasim.mesafeMetni(d.kalanM)} kaldı · ${b.altBaslik}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, right: 10),
          child: Icon(
            switch (b.tur) {
              BacakTuru.yuru => LucideIcons.footprints,
              BacakTuru.bekle => LucideIcons.clock,
              BacakTuru.otobus => LucideIcons.busFront,
            },
            size: 20,
            color: bu ? renk : renk.withValues(alpha: 0.45),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                b.baslik,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color:
                      scheme.onSurface.withValues(alpha: bu ? 1 : 0.55),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                alt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: bu && d.rotaDisi
                      ? const Color(0xFFFFC531)
                      : scheme.onSurface
                          .withValues(alpha: bu ? 0.7 : 0.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${sira + 1}/${a.bacaklar.length}',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  /// Rota bulununca kartlarin yerini alan OZET.
  Widget _rotaOzeti(BuildContext c, RotaAdayi a) {
    final scheme = Theme.of(c).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
      child: Material(
        color: kYuzeyGri(c),
        borderRadius: BorderRadius.circular(kYaricap(96)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_rotaAra()),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${UlasimVeri.saatMetni(a.varisDakika)}\'de varış',
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${a.toplamDakika} dk',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const Spacer(),
                    ulasim.hatRozeti(a.hat, boy: 24),
                    const SizedBox(width: 8),
                    // ⚠️⚠️⚠️ TURU 151 — **BAŞLA** (kullanici emri:
                    //	*"rota BASLATMA yok"*). Basilinca konum
                    //	akisi acilir, gecilen yol cizgiden SILINIR
                    //	ve diger bacaklar SOLAR.
                    SizedBox(
                      height: 30,
                      child: FilledButton(
                        onPressed: _takipBaslat,
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kYaricap(30)),
                          ),
                        ),
                        child: const Text(
                          'Başla',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final b in a.bacaklar.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Icon(
                          switch (b.tur) {
                            BacakTuru.yuru => LucideIcons.footprints,
                            BacakTuru.bekle => LucideIcons.clock,
                            BacakTuru.otobus => LucideIcons.busFront,
                          },
                          size: 13,
                          color: b.tur == BacakTuru.otobus
                              ? ulasim.hatRengi(a.hat)
                              : kYurumeRengi,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            b.baslik,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        Text(
                          '${b.dakika} dk',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Panelin govdesi — **koyu temanin ALTINDAKI** context ile cizilir.
  Widget _panelGovde(BuildContext context, double alt) {
    // ⚠️⚠️ TURU 150 — DURAK MODUNDA panel TAMAMEN farklidir (kullanici
    //	emri: *"durak dedigimde ekranda duraklardan baska seyler
    //	gorunmemeli"*).
    // ⚠️⚠️ TURU 154 — nokta secme kipinde panel YERINE onay karti.
    //	Ayni anda hem durak kartlari hem secim karti gostermek
    //	kullaniciya "hangisi simdi aktif" sorusunu sordururdu.
    if (_noktaSec) return _noktaSecKarti(context, alt);
    if (_durakModu) return _durakPaneli(context, alt);
    final tema = Theme.of(context);
    // ⚠️⚠️ TURU 137 — serit BIR KEZ kurulur: hem cizilecek mi karari hem
    //	ulasim kartlarinin gorunurlugu hem panel yuksekligi ona bagli.
    //	Uc yerde ayri ayri hesaplansaydi biri degisince oteki geride kalir
    //	ve panel ile icerik AYRISIRDI.
    final serit = _panelSeridi(context);
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kAiZemin,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: const [
            BoxShadow(blurRadius: 18, color: Color(0x33000000)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, kPanelAltDolgu + alt),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ⚠️⚠️ TURU 124/132 — **HATA SATIRI PANELDE KALMAK ZORUNDA.**
              //	Konum reddedilirse harita BOS kalir ve kullanici sebebini
              //	baska hicbir yerde GOREMEZ. Turu 124'te alt liste
              //	kaldirilinca bu satir da gitmisti ve ayni hata yasanmisti.
              // ⚠️ YAPMA: bu blogu kaldirma.
              if (_hata != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _hata!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: tema.colorScheme.onSurface.withValues(
                              alpha: 0.62,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _yukle(konumuTazele: true),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              // ⚠️⚠️⚠️ TURU 137 — **MEKAN ARAMA KUTUSU KALDIRILDI** (kullanici
              //	emri: *"mekan aramayi kaldir"*). Kutu, `AramaPaneli`
              //	sayfasi, `_arama` denetleyicisi ve `_q` suzgeci de SILINDI —
              //	panelde duran ama hicbir seye baglanmayan bir kutu birakmak
              //	OLU ARAYUZ olurdu.
              // ⚠️ Aramaya ihtiyac dogarsa ust bardaki geri/konum dugmelerinin
              //    yanina eklenir; panele GERI KOYMA (panel yuksekligi zaten
              //    kategori kartlariyla doldu).
              // ── ARAMA (kategori sayfasinin girisi de BURADA) ──
              // ⚠️⚠️⚠️ TURU 144 — **ARAMA ARTIK CIPLERIN USTUNDE** (kullanici
              //	emri: *"arama kategorilerin uzerinde olsun"*).
              _panelArama(context),
              const SizedBox(height: 12),
              // ── KATEGORİLER ──
              // ⚠️⚠️⚠️ TURU 143 — **ŞERİT GERİ GELDİ** (kullanici emri:
              //	*"aramanin altindaki kategorileri KALDIRMISSIN, ben o
              //	KATEGORI KELIMESINI kaldir dedim, GERI GETIR onlari"*).
              //	Turu 142 kullanicinin *"kategorileri kaldir"* sozunu
              //	seridin TAMAMI diye okumustu; kastedilen yalnizca seridin
              //	basindaki **"Kategori" DUGMESIYDI**. Serit geri kondu,
              //	dugme CIKARILDI (girisi arama dugmesinde DURUYOR).
              _hizliCipler(context),
              const SizedBox(height: 12),
              // ── INCE AYRAC ──
              // ⚠️ Kullanici emri (turu 141): *"onun altinda hafif ince
              //    cizgi"*.
              // ⚠️⚠️ TURU 144 — **YALNIZ SERIT VARSA**: ayrac iki bolumu
              //	AYIRMAK icin var. Serit yokken (konum yok / sonuc yok)
              //	panelin dibinde ayracin ALTINDA bos bir siyah band
              //	kaliyordu (emulatorde goruldu).
              // ⚠️ `_panelBoy`daki karsiligi da AYNI kosula bagli.
              if (serit != null) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: tema.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 12),
              ],
              // ── ISLETME KARTLARI ──
              // ⚠️⚠️⚠️ TURU 144 — serit artik **KATEGORI SECILI OLMASA DA**
              //	cizilir (kullanici emri: *"hicbir sey aktif olmadiginda
              //	HEP YAKINDAKILER gorunecek"*). Turu 137'nin *"Tümü'de
              //	17 kategorinin karisimi anlamsiz"* gerekcesi kullanicinin
              //	yeni karariyla GECERSIZ kaldi.
              // ⚠️⚠️⚠️ TURU 141 — **KISAYOL KARTLARI ARTIK HER ZAMAN
              //	CIZILIR** (kullanici emri: *"harita sayfasinda ISLETME
              //	KARTININ ALTINDA, cizginin altina 4 tane kart koy"* —
              //	yani serit ile BIRLIKTE).
              //	⚠️ Turu 137 bunu bilerek yapmiyordu: ikisi birden
              //	   360x640'ta paneli ~330 dp'ye cikariyor ve haritaya
              //	   ~240 dp kaliyordu. Karar KULLANICININ; bedeli 360 dp
              //	   genislikte OLCULDU ve devir notuna yazildi.
              //	⚠️ YAPMA: bu karari "duzeltme" diye geri alma — kullanici
              //	   dort karti ACIKCA seridin altinda istedi.
              // ⚠️⚠️⚠️ TURU 144 — serit artik **KATEGORI SECILI OLMASA DA**
              //	cizilir (kullanici emri: *"hicbir sey aktif olmadiginda
              //	HEP YAKINDAKILER gorunecek"*). Turu 137'nin *"Tümü'de
              //	17 kategorinin karisimi anlamsiz"* gerekcesi kullanicinin
              //	yeni karariyla GECERSIZ kaldi.
              if (serit != null) ...[
                serit,
                const SizedBox(height: 12),
              ],
              // ── KISAYOLLAR (Eczane · Durak · Benzinlik · Taksi) ──
              // ⚠️⚠️⚠️ TURU 145 — **ALTA GERI TASINDI** (kullanici emri:
              //	*"gittin YUKARI almissin, bunu ALTA AL"*). Turu 144'te
              //	yukari alinmisti; kullanicinin o turdaki sozu yalnizca
              //	GORUNUMU (raduslu renkli zemin) kastediyormus.
              _ulasimKartlari(context),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 141 — **CIPE DOKUNUS: DAL SEC + %70 LISTE POPUPU AC**
  ///	(kullanici emri: *"ornegin kafeye tikladiginda popup acilsin, kafeler
  ///	isletme kartlari ALTA DOGRU siralansin, bu popupun ustunde FILTRELEME
  ///	olsun, bu isletme karti popup %70 olacak, EN USTTE ARAMA"*).
  ///
  /// ⚠️ **TOGGLE KORUNDU**: secili cipe tekrar dokunmak dali BIRAKIR ve
  ///    popup ACILMAZ. "Tümü" cipi olmadigi icin birakmanin TEK yolu budur
  ///    (turu 138'de yazili).
  /// ⚠️ Popup, dal secildikten SONRA acilir: liste sunucudan gelirken
  ///    acilsaydi kullanici bos bir popup gorurdu.
  /// Kisayol karti: dali sec **ve** listeyi ac.
  ///
  /// ⚠️ Dogrudan `_dalSec` cagrilsaydi, zaten secili bir dalda kart
  ///    SESSIZCE hicbir sey yapmazdi (`if (_dal == dal) return;`) —
  ///    kullanici "dokundum, olmadi" derdi (denetim bulgusu).
  void _kisayol(String dal) {
    _dalSec(dal);
    unawaited(_listePopupAc());
  }

  void _dalCipi(String g) {
    // ⚠️⚠️ TURU 144 — **"Yakınımda" CIPI TOGGLE DEGILDIR**: bos dal zaten
    //	seciliyken ona tekrar dokunmak `_dalSec('')` -> yine bos demek
    //	olurdu ve popup ACILIRDI. Bos dalda dokunus yalnizca listeyi acar.
    if (g.isEmpty) {
      if (_dal.isNotEmpty) _dalSec('');
      unawaited(_listePopupAc());
      return;
    }
    if (_dal == g) {
      _dalSec('');
      return;
    }
    _dalSec(g);
    unawaited(_listePopupAc());
  }

  /// ⚠️⚠️⚠️ TURU 141 — **%70 ISLETME LISTESI POPUPU.**
  ///
  /// Duzen (kullanicinin sirasi): en ustte **arama** -> **filtreler** ->
  /// altta **dikey isletme kartlari**.
  ///
  /// ⚠️⚠️ **EKRANIN `setState`i BU SHEET'I YENIDEN CIZMEZ.**
  ///	`showModalBottomSheet` AYRI bir route ve AYRI bir eleman agacidir;
  ///	filtre/arama geri cagirimlari ekranin `setState`ini cagirdigi icin
  ///	sheet'in KENDI `setState`i de cagrilmak ZORUNDA. Aksi halde kullanici
  ///	filtreye dokunur, HARITA guncellenir ama POPUP bayat kalir — bu
  ///	projede "olu arayuz" sinifinin en sik koku.
  ///	Cozum: `StatefulBuilder` + `_popupTazele` geri cagirimi.
  /// ⚠️ `isScrollControlled` ZORUNLU: varsayilan tavan ekranin 9/16'si
  ///    (0.5625) ve %70 istegi KIRPILIRDI (turu 90b/115c).
  /// ⚠️ Zemin kardesleriyle (panel · kategori popupu · filtre ekrani) AYNI
  ///    siyah + zorla koyu tema + `Builder` + `Material` (turu 129/136/140).
  Future<void> _listePopupAc() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: kAiZemin,
      // ⚠️⚠️ TURU 142 — kullanici emri: *"isletme listesi cikarken arkadaki
      //	HARITA GORUNMESI gerekiyor, siyahlasiyor"*. Varsayilan perde
      //	%54 siyahtir; %18'e cekildi.
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (c) => FractionallySizedBox(
        heightFactor: 0.70,
        child: Theme(
          data: _koyuTema(),
          child: Material(
            type: MaterialType.transparency,
            child: Builder(
              builder: (tc) => SafeArea(
                top: false,
                // ⚠️⚠️⚠️ **`ValueListenableBuilder` SEVK ENGELINI KAPATIR.**
                //	`_dalCipi` dali secip `_yukle`yi BASLATIR ama BEKLEMEZ;
                //	popup bir sonraki karede acilir ve o an `_liste` HALA
                //	ONCEKI dalin kayitlaridir. Ekranin `setState`i AYRI bir
                //	route olan bu agaci YENIDEN CIZMEZ — popup onceki dalin
                //	isletmelerini gosterip kendini HIC onarmazdi.
                //	`_listeNesli` `_yukle`nin HER sonucunda artar ve burasi
                //	yeniden cizilir.
                // ⚠️ `StatefulBuilder` de KALIR: filtre/arama degisimini
                //    ANINDA yansitan odur (nesil yalniz AG yanitinda artar).
                child: ValueListenableBuilder<int>(
                  valueListenable: _listeNesli,
                  builder: (_, _, _) => StatefulBuilder(
                  builder: (_, popupTazele) {
                    // ⚠️⚠️ Her iki agac da yenilenir: EKRAN (harita + serit)
                    //	ve POPUP. Yalniz biri cagrilsaydi oteki bayat kalirdi.
                    void tazele(VoidCallback f) {
                      setState(f);
                      popupTazele(() {});
                    }

                    // ⚠️ `_gorunen` bir GETTER ve her okumada 60 kaydi
                    //    bastan suzer; kart basina okunsaydi dikey listede
                    //    O(n²) olurdu (turu 141 kesif bulgusu). BIR KEZ.
                    final liste = _gorunen;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _popupArama(tc, tazele),
                        const SizedBox(height: 10),
                        _popupFiltreler(tc, tazele),
                        const SizedBox(height: 6),
                        Expanded(
                          child: liste.isEmpty
                              ? _popupBos(tc)
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                      kYanBosluk, 6, kYanBosluk, 16),
                                  itemCount: liste.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  // ⚠️ `builder`: dikeyde 60 kayit olabilir
                                  //    ve `children:` hepsini BIR ANDA
                                  //    kurardi (turu 91 dersi).
                                  // ⚠️⚠️ `haritaKapat`: popup ACIKKEN
                                  //	"Haritada göster"e dokunmak kamerayi
                                  //	tasiyordu ama sheet KAPANMADIGI icin
                                  //	kullanici hicbir sey GORMUYORDU
                                  //	(denetim bulgusu). Artik once sheet
                                  //	kapanir.
                                  itemBuilder: (_, i) => _panelKarti(
                                    tc,
                                    liste[i],
                                    esnek: true,
                                    haritaKapat: true,
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Popupun EN USTUNDEKI arama alani.
  ///
  /// ⚠️⚠️ Kullanici *"inputun icinde ornegin cafe yazsin"* dedi; bu
  ///	**IPUCU (hint)** olarak uygulandi, DEGER olarak DEGIL. Deger yazilsaydi
  ///	suzgec isletme adlarinda "Kafe" arar ve liste ANINDA BOSALIRDI —
  ///	kullanici kategoriye girer girmez bos bir ekran gorurdu.
  Widget _popupArama(BuildContext c, void Function(VoidCallback) tazele) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(kYanBosluk, 4, kYanBosluk, 0),
        child: _aramaKutusu(c, tazele),
      );

  /// Popuptaki filtre cipleri.
  ///
  /// ⚠️⚠️ `_yuzenCip` KULLANILAMAZ: onun dolgusu **harita ustu** icin
  ///	secilmis siyah bir haptir (`kYuzenCipAlfa`) ve siyah popup zemininde
  ///	KAYBOLURDU. Burada panel cipiyle ayni dil kullanilir.
  Widget _popupFiltreler(BuildContext c, void Function(VoidCallback) tazele) {
    final ticari = _dal.isEmpty ||
        const {'yemek', 'kafe', 'market'}.contains(_dal);
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
        children: [
          _popupCip(c, '2 km içinde', _fKm == 2,
              () => tazele(() => _fKm = _fKm == 2 ? 0 : 2)),
          _popupCip(c, '5 km içinde', _fKm == 5,
              () => tazele(() => _fKm = _fKm == 5 ? 0 : 5)),
          _popupCip(c, '4+ puan', _fPuan, () => tazele(() => _fPuan = !_fPuan)),
          if (ticari)
            _popupCip(c, 'Kampanyalı', _fKampanya,
                () => tazele(() => _fKampanya = !_fKampanya)),
          _popupCip(c, 'Onaylı', _fOnayli,
              () => tazele(() => _fOnayli = !_fOnayli)),
          if (_suzgecVar)
            _popupCip(c, 'Temizle', false, () {
              tazele(() {
                _fPuan = false;
                _fKampanya = false;
                _fOnayli = false;
                _fKm = 0;
              });
            }),
        ],
      ),
    );
  }

  /// Popuptaki tek filtre cipi — **CHECKBOX'LI** (kullanici emri).
  Widget _popupCip(
      BuildContext c, String etiket, bool secili, VoidCallback bas) {
    final vurgu = kVurgu(c);
    final notr = Theme.of(c).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Material(
          color: kAiKartYuzey(c),
          borderRadius: BorderRadius.circular(kYaricap(34)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: bas,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: SizedBox(
                height: 34,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      // ⚠️ `kYaricap` DEGIL: clamp tabani 8 ve bu boyutta
                      //    kutuyu DAIREYE cevirip radio gibi gosterir.
                      decoration: BoxDecoration(
                        color: secili ? vurgu : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: secili ? vurgu : notr.withValues(alpha: 0.45),
                          width: 1.4,
                        ),
                      ),
                      child: secili
                          ? Icon(LucideIcons.check,
                              size: 11,
                              color: Theme.of(c).colorScheme.surface)
                          : null,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      etiket,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: secili ? vurgu : notr,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Popup bos oldugunda — SEBEBINI soyler.
  ///
  /// ⚠️ Bos bir liste "bozuk" gorunur; sebep yazilmazsa kullanici neden bos
  ///    oldugunu bilemez (turu 121d dersi).
  Widget _popupBos(BuildContext c) {
    final scheme = Theme.of(c).colorScheme;
    // ⚠️⚠️ **YUKLEME VE HATA AYRI SOYLENIR** (denetim bulgusu): eski hal
    //	ag hatasini da "kayıtlı işletme yok" diye gosteriyordu ve kullanici
    //	sorunun kendisinde mi yoksa baglantida mi oldugunu ANLAYAMIYORDU.
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    final metin = _hata != null
        ? _hata!
        : _q.trim().isNotEmpty
            ? '"${_q.trim()}" ile eşleşen işletme yok.'
            : _suzgecVar
                ? 'Seçtiğin filtrelere uyan işletme yok.'
                : 'Bu kategoride yakınında kayıtlı işletme yok.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          metin,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }

  /// Panelde ve popupta ORTAK arama kutusu.
  ///
  /// ⚠️ Ipucu SECILI DALDAN turer (kullanici emri: *"ornegin cafe
  ///    tikladiysam ... inputun icinde cafe yazsin"*).
  /// ⚠️⚠️ Kullanici *"inputun ICINDE yazsin"* dedi; bu **IPUCU (hint)**
  ///	olarak uygulandi, DEGER olarak DEGIL. Deger yazilsaydi suzgec
  ///	isletme adlarinda "Kafe" arar ve liste ANINDA BOSALIRDI.
  /// ⚠️ Denetleyici `_AramaAlani`nin KENDI `State`inde yasar ve orada
  ///    dispose edilir (bkz. o sinifin serhi).
  Widget _aramaKutusu(BuildContext c, void Function(VoidCallback) tazele) {
    final ipucu = _dal.isEmpty
        ? 'İşletme ara'
        : '${isletmeKategorileri[_dalKategori(_dal)] ?? 'İşletme'} ara';
    return _AramaAlani(
      deger: _q,
      ipucu: ipucu,
      degisti: (v) => tazele(() => _q = v),
    );
  }

  /// Panelde cip seridinin ALTINDAKI arama alani (kullanici emri:
  /// *"kategori yemek vs ALTINA arama yeri yap"*).
  ///
  /// ⚠️ TURU 137 arama kutusunu bu panelden CIKARMIS ve *"panele GERI KOYMA"*
  ///    diye serh birakmisti; kullanicinin turu 141 emri o karari GECERSIZ
  ///    kilar. Serh gerekcesiyle GUNCELLENDI, silinmedi.
  /// ⚠️⚠️ TURU 142 — panelde artik DUZENLENEBILIR bir kutu DEGIL, **arama
  ///	SAYFASINI acan bir DUGME** (kullanici emri: *"arama butonuna
  ///	tikladiginda kategoriler popup acilsin"*).
  /// ⚠️ Klavye panelde ACILMAZ; yazma islemi tam ekran benzeri %95 arama
  ///    sayfasinda yapilir — panel 4 kisayol + serit ile zaten dolu.
  Widget _panelArama(BuildContext c) {
    final scheme = Theme.of(c).colorScheme;
    final metin = _q.trim().isNotEmpty
        ? _q.trim()
        : _dal.isEmpty
            ? 'İşletme ara'
            : isletmeKategorileri[_dalKategori(_dal)] ?? 'İşletme ara';
    final dolu = _q.trim().isNotEmpty || _dal.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
      child: Material(
        color: kAiKartYuzey(c),
        borderRadius: BorderRadius.circular(kYaricap(44)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_kategoriPopupAc()),
          // ⚠️⚠️ TURU 143 — yukseklik **`_aramaBoy` ILE AYNI KAYNAKTAN**.
          //	Turu 142'de bu kutu bir `TextField`ken formul ona gore
          //	olculmustu; dugmeye cevrilince govde (dikey dolgu 11x2 + Row)
          //	formulden ~4 dp KISA kaldi ve yuzen filtre seridi panelden
          //	10 degil ~14 dp yukarida duruyordu (kullanici 10 istedi).
          //	Artik ayrisma YAPISAL OLARAK imkansiz.
          child: SizedBox(
            height: _aramaBoy(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.search, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      metin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: dolu ? FontWeight.w700 : FontWeight.w400,
                        color: scheme.onSurface
                            .withValues(alpha: dolu ? 1 : 0.55),
                      ),
                    ),
                  ),
                  // ⚠️⚠️ TURU 145 — **X KALDIRILDI** (kullanici emri:
                  //	*"oradaki aramada x kaldir"*).
                  // ⚠️ KURTARMA YOLU KAYBOLMADI: kategoriyi/aramayi
                  //    birakmanin yolu cip seridinin basindaki
                  //    **"Yakınımda"** cipidir (turu 144). Bu dugme zaten
                  //    ARAMA SAYFASINI aciyor; orada da metin temizlenir.
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Panel arama alaninin kapladigi yukseklik.
  ///
  /// ⚠️⚠️ **SABIT 48 YAZILAMAZ**: `isDense` + 11 dp dikey dolgu ile kutu
  ///	yuksekligi YAZI OLCEGINDEN turer. Sabit yazilsaydi olcek 1.3/2.0'da
  ///	`_panelBoy` govdeyle AYRISIR ve yuzen filtre seridi panelin ALTINDA
  ///	kalirdi (bu ekranda olculmus sinif).
  /// ⚠️⚠️ **OLCULDU (gecici widget testi, 360 dp, Google Sans):** eski
  ///	formul (`scale(14)*1.2 + 24`) 41 dp veriyordu; GERCEK kutu bos iken
  ///	**43**, temizle (X) dugmesi cikinca **48** dp idi. Yani panel HER
  ///	OLCEKTE ve ozellikle ILK HARFTE govdeden KISA kaliyordu ve yuzen
  ///	filtre seridi panelin UZERINE biniyordu.
  /// ⚠️ Iki katmanli duzeltme: (a) `_AramaAlani`da `suffixIconConstraints`
  ///    ACIKCA verildi — verilmezse `InputDecorator` 48 dp'lik
  ///    `kMinInteractiveDimension` dayatir ve kutu ilk harfte UZAR;
  ///    (b) formul olculen degere hizalandi + **2 dp pay**.
  /// ⚠️ Pay YUKARI dogru: panel iceriginden 2 dp UZUN olursa kucuk bir
  ///    bosluk kalir (zararsiz); KISA olursa serit panelin altinda kalir.
  double _aramaBoy(BuildContext c) =>
      (MediaQuery.textScalerOf(c).scale(14) * 1.35 + 24).ceilToDouble() + 2;

  /// ⚠️⚠️⚠️ TURU 141 — **DORT KISAYOL KARTI** (kullanici emri: *"harita
  ///	sayfasinda isletme kartinin altinda CIZGININ ALTINA 4 tane kart koy:
  ///	Nobetci Eczane · Durak · Benzin Istasyonu · Taksi"*).
  ///
  /// ⚠️⚠️ **DURUST SINIRLAR (turu 89/96t'de yazili, DEGISMEDI):**
  ///	· **NOBET VERISI YOK** — kart eczaneleri MESAFEYE gore listeler.
  ///	  ⚠️ TURU 143'te etiket "Nöbetçi Eczane" -> **"Eczane"** oldu
  ///	  (kullanici emri); kart artik "nobetci" IDDIA ETMEDIGI icin
  ///	  gorunen metin de DURUSTLESTI.
  ///	· **DURAK verisi YOK** (belediye/POI kaynagi gerektirir) — kart
  ///	  durustce soyler, sahte durak listesi CIZMEZ.
  ///	· **AKARYAKIT FIYATI YOK** — kart (etiketi turu 143'te "Benzin
  ///	  İstasyonu" -> **"Benzinlik"**) `oto` kategorisini acar; fiyatlar
  ///	  yalniz ORNEK kayitlarda ve "Örnek" etiketiyle cizilir.
  ///	· **TAKSI** kayitli `hizmet` isletmelerini gosterir.
  /// ⚠️ Onceki dort kart (Otobüs · Tren · Taksi · Uber) kullanici emriyle
  ///    DEGISTI; Uber girisi menude/`_uberAc` ile DURUYOR mu diye bakildi —
  ///    `_uberAc` baska cagri yeri kalmadigi icin SILINDI.
  /// Kisayol kartinin yuksekligi — **TEK KAYNAK** (`_panelBoy` de okur).
  ///
  /// ⚠️⚠️ Ayri ayri hesaplansaydi biri degisince oteki geride kalir ve
  ///	panelin alti ya TASAR ya bos bir serit birakirdi (bu ekranda ayni
  ///	sinif turu 139'da yasandi).
  /// ⚠️⚠️⚠️ TURU 145 — **KARTLI IKON GERI** (kullanici emri: *"eczane vs
  ///	durak bunlarin uzerinde ANASAYFADAKI KATEGORI GIBI KARTLI IKON
  ///	olacak"*): raduslu kutu + ICINDE ikon + ALTINDA etiket.
  ///	Turu 143 ikonu, turu 144 zemini kaldirmisti; ikisi de GERI GELDI.
  /// ⚠️ Yukseklik = kutu (`kKisayolKutu`) + 5 + TEK SATIR etiket.
  ///    Etiket `FittedBox(scaleDown)` ile tek satirda kalir (turu 143:
  ///    "Benzinlik" kelime ORTASINDAN boluniyordu).
  double _kisayolBoy(BuildContext c) {
    final o = MediaQuery.textScalerOf(c);
    return (kKisayolKutu + 5 + o.scale(13.5) * 1.2).ceilToDouble() + 1;
  }

  Widget _ulasimKartlari(BuildContext c) {
    final boy = _kisayolBoy(c);
    // ⚠️⚠️⚠️ TURU 145 — **KUTU + IKON + ALTINDA ETIKET** (kullanici emri:
    //	*"anasayfadaki KATEGORI GIBI KARTLI IKON olacak"*). Kutu raduslu
    //	(`kYaricap`, kategori diliyle AYNI) ve zemini markanin renginin
    //	%14'u; ikon TAM renkte. Etiket kutunun ALTINDA, beyaz.
    // ⚠️ Renkler `kAiZemin` (sabit siyah) uzerinde okunuyor: bu satir
    //    YALNIZ panelde ciziliyor ve panel zorla koyu tema kuruyor.
    //    ⚠️ Satir acik zeminli bir ekrana tasinirsa renkler yeniden
    //       olculmeli (turu 115b dersi).
    Widget kart(IconData ikon, String ad, Color renk, VoidCallback bas) =>
        Expanded(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(kYaricap(kKisayolKutu)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: bas,
              child: SizedBox(
                height: boy,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: kKisayolKutu,
                      height: kKisayolKutu,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: renk.withValues(alpha: 0.14),
                        borderRadius:
                            BorderRadius.circular(kYaricap(kKisayolKutu)),
                      ),
                      child: Icon(ikon, size: 24, color: renk),
                    ),
                    const SizedBox(height: 5),
                    // ⚠️⚠️⚠️ TURU 143 — **KELIME ORTASINDAN BOLUNMEYI ENGELLER**
                    //	(gercek fontla olculdu): 360 dp'de karta 76 dp,
                    //	metne 64 dp kaliyor; "Benzinlik" olcek 1.3'te
                    //	74,9 dp istiyor ve Flutter tek bir kelime satira
                    //	sigmayinca onu **ORTADAN BOLUYOR** — ekranda
                    //	*"Benzinli / k"* cikiyordu.
                    // ⚠️ `maxLines: 1` + `softWrap: false` + `scaleDown`:
                    //    kelime BOLUNMEZ, yalniz GEREKTIGINDE kuculur.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          ad,
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
      child: Row(
        children: [
          // ⚠️⚠️ TURU 143 — etiketler KISALDI (kullanici emri): "Nöbetçi
          //	Eczane" -> **Eczane**, "Benzin İstasyonu" -> **Benzinlik**.
          //	⚠️ DURUST SINIR DEGISMEDI: nobet verisi HALA YOK; kisa ad
          //	   ustelik daha DURUST, cunku artik "nobetci" IDDIA ETMIYOR.
          kart(LucideIcons.pill, 'Eczane', const Color(0xFF2BB673),
              () => _kisayol('eczane')),
          const SizedBox(width: 8),
          kart(
            LucideIcons.busFront,
            'Durak',
            const Color(0xFF3AA9FF),
            // ⚠️⚠️⚠️ TURU 149 — artik **GERCEK GTFS VERISI** (kullanici
            //	KentKart Kocaeli akisini verdi). Turu 144'teki ornek
            //	hatlar KALDIRILDI.
            () => unawaited(_durakAc()),
          ),
          const SizedBox(width: 8),
          // ⚠️ `LucideIcons.fuel` — menudeki hizli erisimle AYNI ikon
          //    (turu 128); iki yerde farkli ikon olmasin.
          kart(LucideIcons.fuel, 'Benzinlik', const Color(0xFFFFC531),
              () => _kisayol('akaryakit')),
          const SizedBox(width: 8),
          // ⚠️⚠️⚠️ TURU 149 — artik **GERCEK TAKSI DURAKLARI** (Kocaeli
          //	Buyuksehir acik verisi, 53 durak). Turu 141'de bu kisayol
          //	`hizmet` kategorisini aciyordu (temizlik/nakliyat da oradaydi);
          //	o DURUST OLMAYAN esleme bitti.
          kart(LucideIcons.carTaxiFront, 'Taksi', const Color(0xFFFF7A3C),
              () => unawaited(_taksiAc())),
        ],
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 144 — **DURAK SAYFASI** (kullanici emri: *"birde durak ekle
  ///	dostum, otobus hatti vs saat sana birakiyorum"*).
  ///
  /// ⚠️⚠️ **GERCEK DURAK VERISI YOK VE UYDURULMADI.** Bu projede ne bir
  ///	tablo, ne bir uc, ne de bir belediye/POI kaynagi var (turu 89/96t'de
  ///	yazili durust sinir, DEGISMEDI). Sayfa bu yuzden:
  ///	  · hat adlarini **jenerik** tutar ("Merkez – Sanayi"), GERCEK bir
  ///	    Gebze hat numarasi YAZMAZ — yanlis numara, numarasizdan KOTUDUR;
  ///	  · her satirda ve baslikta **"Örnek"** ibaresi tasir;
  ///	  · en ustte gercek verinin bagli OLMADIGINI acikca soyler.
  /// ⚠️ Sureler SABIT (5/12/24 dk): saatten turetilseydi ekranda "canli"
  ///    gorunur ve kullanici GERCEK saniridi.
  /// ⚠️ YAPMA: buraya gercek gorunumlu hat numarasi/saat yazma; veri
  ///    baglanmadan "Örnek" ibaresini kaldirma.
  /// ⚠️⚠️⚠️ TURU 149 — **DURAK AKISI (GERCEK VERI).**
  ///
  /// Kisayol -> yakindaki duraklar listesi -> durak detayi (gecen hatlar +
  /// GERCEK kalkis saatleri) -> hat secilince haritada GERCEK guzergah.
  /// ⚠️ Konum YOKSA hicbir sey yapilmaz ve sebep SOYLENIR: duraklar
  ///    kullanicinin cevresinden secildigi icin konum olmadan liste
  ///    anlamsiz olurdu.
  /// **DURAK MODUNA GIRER** (kullanici emri).
  ///
  /// ⚠️ Konum YOKSA girilmez ve sebep SOYLENIR: duraklar kullanicinin
  ///    cevresinden secildigi icin konumsuz mod anlamsiz olurdu.
  Future<void> _durakAc() async {
    // ⚠️⚠️ TURU 154 - **ACIK TAKIP ONCE BIRAKILIR.** Bu metot
    //	`_rota`yi null yapiyor; takip acik kalsaydi `_takip != null`
    //	ama `_rota == null` olur, panel durak kartlarini cizerken
    //	`_panelBoy` ADIM KARTI yuksekligini dondururdu (haritanin
    //	alt dolgusu ve yuzen serit KAYARDI). Ustelik GPS akisi
    //	sahipsiz surerdi.
    if (_takip != null) _takipDurdur();
    final k = _konum;
    if (k == null) {
      _mesaj('Yakındaki durakları görebilmek için konum izni gerekiyor.');
      return;
    }
    final yakin = await UlasimVeri.i.yakinDuraklar(k.enlem, k.boylam,
        adet: 25, yaricapM: 2000);
    if (!mounted) return;
    setState(() {
      _durakModu = true;
      _duraklar = yakin;
      _seciliDurak = yakin.isEmpty ? null : yakin.first;
      _rotaBas = RotaNoktasi(
        ad: 'Konumum',
        enlem: k.enlem,
        boylam: k.boylam,
      );
      _rota = null;
      _hatCizgi = null;
      _hatEtiketi = '';
    });
    unawaited(_durakHatlariniYukle(yakin));
    // ⚠️⚠️ TURU 151 - "Konumum" satirinda da ADRES yazsin (kullanici
    //	emri: *"sectigim yerin adresi de gorunmeli NEREDENDE ve
    //	nereyede"*). Ad "Konumum" KALIR, adres alt satira gecer.
    unawaited(_adresiYaz(k.enlem, k.boylam, true, koruAd: 'Konumum'));
  }

  /// Kartlarda gosterilecek hat/saat bilgisini ONDEN cozer.
  ///
  /// ⚠️ Tek tek `setState` cagrilmaz: 25 durak icin 25 yeniden cizim
  ///    demekti. Hepsi cozulup TEK seferde yazilir.
  Future<void> _durakHatlariniYukle(List<Durak> liste) async {
    final servis = UlasimVeri.bugunServis();
    final yeni = <String, List<DurakHatti>>{};
    for (final d in liste) {
      if (_durakHat.containsKey(d.id)) continue;
      yeni[d.id] = await UlasimVeri.i.duraginHatlari(d.id, servis);
    }
    if (!mounted || yeni.isEmpty) return;
    setState(() => _durakHat.addAll(yeni));
  }

  /// Bir duragi secer - **TEK KAYNAK** (hem pin hem kart bunu cagirir).
  ///
  /// ⚠️ Kamera nesil sayacli tasinir: ayni durak tekrar secilirse
  ///    koordinat degismez ve kamera TASINMAZDI (turu 138/140 dersi).
  /// ⚠️ Serit secili karta KAYDIRILIR; yoksa pine dokunan kullanici
  ///    kartin ekran disinda kaldigini goremezdi.
  /// ⚠️ [detay] verilirse durak bilgi paneli DE acilir. Pin ve
  ///    kart dokunusu bunu `true` gecer (kullanici emri); rota
  ///    akisindan gelen secimler `false` birakir - orada panel
  ///    kullanicinin ONUNU KESERDI.
  void _duragiSec(Durak d, {bool detay = false}) {
    final i = _duraklar.indexWhere((x) => x.id == d.id);
    setState(() {
      _seciliDurak = d;
      _odak = (
        enlem: d.enlem,
        boylam: d.boylam,
        nesil: (_odak?.nesil ?? 0) + 1,
      );
    });
    if (i >= 0 && _durakSerit.hasClients && mounted) {
      // ⚠️ Adim kartin GERCEK genisligi (bkz. `_durakKarti`); sabit
      //    `kPanelKartEn` yazilsaydi dar ekranda serit YANLIS karta
      //    kayardi.
      final en = math.min(
        kPanelKartEn,
        MediaQuery.sizeOf(context).width - kYanBosluk - 44,
      );
      unawaited(_durakSerit.animateTo(
        (i * (en + 10))
            .clamp(0.0, _durakSerit.position.maxScrollExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ));
    }
    // ⚠️ Adres ARKA PLANDA cozulur ki panel bir dahaki acilista
    //    onbellekten ANINDA gostersin (bkz. `_durakDetay`).
    unawaited(AdresServisi.i.coz(d.enlem, d.boylam));
    if (detay) unawaited(_durakDetay(d));
  }

  /// Rota takibini **BASLATIR** (kullanicinin "Başla" dugmesi).
  ///
  /// ⚠️⚠️ **IZIN BURADA ISTENMEZ**: durak moduna girebilmek icin
  ///	konum ZATEN alinmis olmak zorunda (`_durakAc` konumsuz
  ///	moda girmiyor). Ikinci bir izin istegi kullaniciya
  ///	sebepsiz gorunurdu.
  /// ⚠️ Akis ZATEN aciksa yeniden acilmaz — cift abonelik iki kat
  ///    olay ve iki kat pil demektir.
  void _takipBaslat() {
    if (_rota == null || _konumAkisi != null) return;
    setState(() {
      _takip = takip.TakipDurumu.basla;
      _takipKamera = true;
      _adimGorunen = 0;
      _adimProgramatik = false;
    });
    // ⚠️⚠️ TURU 154 - `PageView` bu karede HENUZ AGACTA YOK
    //	(`_takip` yeni yazildi), yani `hasClients` false.
    //	Sifirlama bir sonraki kareye BIRAKILIR; yoksa onceki
    //	takip oturumundan kalan sayfa acilir ve kullanici yola
    //	3. adimdan basliyormus gibi gorunurdu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _takip != null) _adimSayfasinaGec(0, ani: true);
    });
    _pusulayiBagla();
    _akisiBagla();
  }

  /// ⚠️⚠️⚠️ TURU 153 — **GECICI HATADA TAKIP BIRAKILMAZ.**
  ///
  ///	Onceki hal ilk hatada takibi KAPATIYOR ve ekrana
  ///	*"Konum akışı kesildi"* yaziyordu (kullanici sahada gordu).
  ///	Oysa GPS akisi tunelde/bina icinde GECICI olarak hata
  ///	verebilir; kullanici yurumeye devam ederken takibin
  ///	kendini kapatmasi ozelligi KULLANILAMAZ yapiyordu.
  ///
  /// ⚠️ **IZIN HATASI AYRI**: `KonumIzniYok` KALICI bir durumdur —
  ///    orada tekrar denemek anlamsiz, kullaniciya SEBEBI soylenir.
  /// ⚠️ Tekrar sayisi SINIRLI (3): sonsuz denemek pili bitirirdi.
  void _akisiBagla() {
    _konumAkisi = KonumServisi.konumAkisi().listen(
      (k) {
        _akisHatasi = 0; // saglikli veri geldi -> sayac sifirlanir
        // ⚠️ TURU 155 — GPS gidis yonu YALNIZ pusula yokken kullanilir
        //    (bkz. `_yon` serhi). Pusula bir kez deger verdiyse ona
        //    dokunulmaz, yoksa yurumeye baslayinca ok ZIPLARDI.
        _dogrulukM = k.dogrulukM;
        if (_pusulaVerdi == false && k.yon != null) _yon = k.yon;
        _konumGeldi((enlem: k.enlem, boylam: k.boylam));
      },
      onError: (Object e) {
        if (!mounted || _takip == null) return;
        if (e is KonumIzniYok) {
          _mesaj('Takip için konum izni gerekiyor.');
          _takipDurdur();
          return;
        }
        _akisHatasi++;
        if (_akisHatasi > 3) {
          _mesaj('Konum sinyali alınamıyor. Takip durduruldu.');
          _takipDurdur();
          return;
        }
        // ⚠️ Aboneligi KAPATIP yeniden ac: hatali bir akis kendini
        //    onarmaz, yeni bir dinleyici gerekir.
        _konumAkisi?.cancel();
        _konumAkisi = null;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _takip != null && _konumAkisi == null) {
            _akisiBagla();
          }
        });
      },
    );
  }

  /// Pusula bir kez GERCEK deger verdi mi?
  ///
  /// ⚠️⚠️ Kaynak secimini bu bayrak yapar: pusula calisiyorsa GPS gidis
  ///	yonu YOK SAYILIR. Ikisi karisik kullanilsaydi ok, kullanici
  ///	yurumeye basladiginda iki farkli kaynak arasinda ZIPLARDI.
  bool _pusulaVerdi = false;

  /// ⚠️ Pusula akisini baglar. Kanal/sensor yoksa akis hicbir sey
  ///    yaymaz (fail-soft) ve yon GPS gidis yonune duser; o da yoksa
  ///    yon oku HIC cizilmez.
  void _pusulayiBagla() {
    _pusulaAkisi?.cancel();
    _pusulaAkisi = PusulaServisi.i.akis().listen(
      (d) {
        if (!mounted) return;
        setState(() {
          _pusulaVerdi = true;
          _yon = d;
        });
      },
      // ⚠️ Hata SESSIZ: pusula bir KOLAYLIK, takip onsuz da calisir.
      onError: (Object _) {},
    );
  }

  /// Takibi durdurur (kullanici "Bitir" ya da rota degisimi).
  ///
  /// ⚠️⚠️ **AKIS IPTALI ZORUNLU**: birakilmazsa GPS acik kalir,
  ///	pil akar ve ekran kapandiktan sonra bile olay gelmeye
  ///	devam eder (`setState` OLU bir `State`e dokunur).
  void _takipDurdur() {
    _konumAkisi?.cancel();
    _konumAkisi = null;
    // ⚠️ TURU 155 — pusula da birakilir; yoksa sensor takip bittikten
    //    sonra da acik kalir ve pil yakar.
    _pusulaAkisi?.cancel();
    _pusulaAkisi = null;
    _pusulaVerdi = false;
    if (!mounted) return;
    setState(() {
      _takip = null;
      _takipKamera = true;
      // ⚠️ Bayrak takili kalirsa bir SONRAKI takipte kullanicinin
      //    kaydirmasi "programatik" sanilir ve kamera TASINMAZDI.
      _adimProgramatik = false;
    });
  }

  /// ⚠️⚠️⚠️ TURU 154 - **ADIM SAYFASINI PROGRAMATIK DEGISTIRIR.**
  ///
  ///	Takip bir sonraki bacaga gecince kart da otomatik ilerler
  ///	(Google Maps deseni). `_adimProgramatik` bayragi bu gecisi
  ///	kullanicinin KENDI kaydirmasindan ayirir - bkz. alan serhi.
  void _adimSayfasinaGec(int i, {bool ani = false}) {
    _adimGorunen = i;
    if (!_adimSayfa.hasClients) return;
    _adimProgramatik = true;
    final Future<void> is0;
    if (ani) {
      _adimSayfa.jumpToPage(i);
      is0 = Future<void>.value();
    } else {
      is0 = _adimSayfa.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    // ⚠️ Bayrak animasyon BITENE kadar acik kalir: `onPageChanged`
    //    animasyonun ortasinda (sayfa yarisi gecilince) tetiklenir.
    unawaited(is0.whenComplete(() {
      if (mounted) _adimProgramatik = false;
    }));
  }

  /// ⚠️⚠️⚠️ Kullanici adim kartlarini SOL/SAG kaydirdi.
  ///
  ///	Kullanici emri: *"steplere tikladigimda hangi stepleri sol
  ///	sag yapinca harita o NOKTALARA gidiyor"*. Kamera o bacagin
  ///	TAMAMINI ekrana sigdirir; egim/donme YOK - kullanici turu
  ///	150'de acikca **kus bakisi** istedi.
  ///
  /// ⚠️⚠️ **TAKIP KAMERASI BIRAKILIR**: birakilmasaydi bir sonraki GPS
  ///	olayi kamerayi ANINDA kullanicinin uzerine geri ceker ve
  ///	kaydirma HICBIR ISE YARAMAZDI. Geri donus yolu kapanmiyor:
  ///	"Merkeze dön" dugmesi tam bu anda beliriyor.
  void _adimaGit(RotaAdayi a, int i) {
    setState(() => _adimGorunen = i);
    if (_adimProgramatik) return;
    if (i < 0 || i >= a.bacaklar.length) return;
    final b = a.bacaklar[i];
    // ⚠️ Bekleme bacaginin polyline'i YOK; kamera tasinamaz,
    //    sessizce bulundugu yerde kalir.
    if (b.noktalar.isEmpty) return;
    setState(() => _takipKamera = false);
    _noktalaraSigdir(b.noktalar);
  }

  /// Akistan yeni konum geldi.
  void _konumGeldi(({double enlem, double boylam}) k) {
    final r = _rota;
    final d = _takip;
    if (!mounted || r == null || d == null) return;
    final yeni = takip.ilerlet(
      d,
      [for (final b in r.bacaklar) b.noktalar],
      k.enlem,
      k.boylam,
    );
    setState(() {
      _takip = yeni;
      _konum = k;
    });
    // ⚠️ Kamera YALNIZ takip acikken tasinir; kullanici haritayi
    //    elle kaydirdiysa `_takipKamera` false olur ve kamera RAHAT
    //    birakilir (bkz. `_takipKamera` serhi).
    if (_takipKamera) {
      setState(() {
        _odak = (
          enlem: k.enlem,
          boylam: k.boylam,
          nesil: (_odak?.nesil ?? 0) + 1,
        );
      });
    }
    // ⚠️⚠️ TURU 154 - bacak degistiyse ADIM KARTI da ilerler.
    //	Kullanici baska bir adima bakiyor olsa bile geri cekilir:
    //	yururken ekranda YANLIS adimin durmasi, ozelligin en
    //	tehlikeli hali olurdu.
    if (yeni.bacak != d.bacak) _adimSayfasinaGec(yeni.bacak);
    if (yeni.bitti) {
      _mesaj('Vardın.');
      _takipDurdur();
    }
  }

  /// Durak modundan cikar.
  void _durakKapat() {
    // ⚠️ Takip acik kalirsa GPS akisi durak modundan CIKTIKTAN
    //    sonra da surer.
    _konumAkisi?.cancel();
    _konumAkisi = null;
    _pusulaAkisi?.cancel();
    _pusulaAkisi = null;
    _pusulaVerdi = false;
    setState(() {
      _takip = null;
      _durakModu = false;
      _duraklar = const [];
      _seciliDurak = null;
      _rota = null;
      _rotaVaris = null;
      _noktaSec = false;
      _hatCizgi = null;
      _hatEtiketi = '';
    });
  }

  /// Rota planlama sayfasini acar.
  Future<void> _rotaPlanla() async {
    // ⚠️⚠️⚠️ EMULATORDE GORULDU: burada `if (_konum == null) return;`
    //	vardi ve **"Nereye" dugmesi SESSIZCE HICBIR SEY YAPMIYORDU**.
    //	Gercek cihazda da ayni: konum iznini REDDEDEN kullanici
    //	dugmeye basar, hicbir sey olmaz, sebebini de ogrenemezdi.
    // ⚠️⚠️ Konum ZORUNLU DEGIL: baslangic haritadan ya da durak
    //	aramasindan da secilebiliyor. Konum yalnizca "Konumum"
    //	kisayolunu VARSAYILAN yapmak icin kullanilir.
    final k = _konum;
    if (k != null) {
      _rotaBas ??= RotaNoktasi(ad: 'Konumum', enlem: k.enlem, boylam: k.boylam);
    }
    if (!mounted) return;
    await rotaPlanlaAc(
      context,
      baslangic: _rotaBas,
      varis: _rotaVaris,
      rotaBul: (b, v) {
        setState(() {
          _rotaBas = b;
          _rotaVaris = v;
        });
        unawaited(_rotaAra());
      },
      haritadanSec: (baslangicIcin) {
        // ⚠️ Baslangic merkezi: varsa mevcut secim, yoksa kullanici
        //    konumu. Haritanin nereye bakacagini bilmek, kullaniciyi
        //    once dogru semte goturur.
        final m = (baslangicIcin ? _rotaBas : _rotaVaris) ??
            (_konum == null
                ? null
                : RotaNoktasi(ad: '', enlem: _konum!.enlem, boylam: _konum!.boylam));
        setState(() {
          _noktaSec = true;
          _noktaBaslangicIcin = baslangicIcin;
          _noktaMerkez =
              m == null ? null : (enlem: m.enlem, boylam: m.boylam);
          _noktaAdres = null;
          _noktaAdresYukleniyor = m != null;
        });
        if (m != null) _noktaMerkezDegisti(m.enlem, m.boylam);
      },
    );
  }

  /// Nokta secme kipinde harita DURDUGUNDA cagrilir.
  ///
  /// ⚠️⚠️ **HER KAREDE DEGIL, KAMERA DURUNCA**: ters geocoding bir AG
  ///	istegi; her karede cagrilsaydi kaydirma sirasinda onlarca
  ///	istek ucar ve cihaz geocoder'i bogulurdu ("Service not
  ///	Available" ile SESSIZCE bos donerdi).
  /// ⚠️ Bayat yanit kapisi: kullanici haritayi kaydirmaya devam
  ///    ederse ESKI adres YENI merkezin uzerine yazilmamali.
  void _noktaMerkezDegisti(double enlem, double boylam) {
    if (!_noktaSec) return;
    final nesil = ++_noktaNesli;
    setState(() {
      _noktaMerkez = (enlem: enlem, boylam: boylam);
      _noktaAdres = null;
      _noktaAdresYukleniyor = true;
    });
    unawaited(() async {
      final m = await AdresServisi.i.coz(enlem, boylam);
      if (!mounted || nesil != _noktaNesli) return;
      setState(() {
        _noktaAdres = m;
        _noktaAdresYukleniyor = false;
      });
    }());
  }

  /// Nokta secme kipini KAPATIR (onaysiz).
  void _noktaSecIptal() {
    setState(() {
      _noktaSec = false;
      _noktaMerkez = null;
      _noktaAdres = null;
      _noktaAdresYukleniyor = false;
    });
    // ⚠️ Planlama sayfasi geri acilir; yoksa kullanici yarim
    //    kalmis bir akista ORTADA kalirdi.
    unawaited(_rotaPlanla());
  }

  /// Haritadan nokta secildi.
  /// ⚠️⚠️⚠️ TURU 151 - haritadan secilen noktanin **ADRESI COZULUR**
  ///	(kullanici emri: *"ben sectigim yerin ADRESI DE gorunmeli
  ///	neredende ve nereyede"*).
  ///
  /// ⚠️⚠️ **PLANLAMA SAYFASI BEKLETILMEZ:** ters geocoding bir AG
  ///	istegi ve saniyeler surebiliyor. Sayfa ANINDA gecici
  ///	etiketle acilir; adres gelince `setState` ile YERINE yazilir.
  ///	Beklenseydi kullanici bos ekrana bakardi.
  /// ⚠️ Adres cozulemezse gecici etiket KALIR - bos birakmak,
  ///    kaba bir etiketten kotudur.
  /// ⚠️ Artik haritaya DOKUNUNCA degil, **ONAY dugmesiyle** cagrilir.
  ///    Dokunus yalnizca kamerayi o noktaya tasir (bkz. `noktaSec`).
  void _noktaSecildi(double enlem, double boylam) {
    if (!_noktaSec) return;
    final baslangicIcin = _noktaBaslangicIcin;
    final nk = RotaNoktasi(
      ad: baslangicIcin ? 'Seçilen başlangıç' : 'Seçilen varış',
      enlem: enlem,
      boylam: boylam,
    );
    setState(() {
      _noktaSec = false;
      if (baslangicIcin) {
        _rotaBas = nk;
      } else {
        _rotaVaris = nk;
      }
    });
    unawaited(_adresiYaz(enlem, boylam, baslangicIcin));
    unawaited(_rotaPlanla());
  }

  /// Bir noktanin adresini cozup ilgili uca yazar.
  ///
  /// ⚠️⚠️ **KIMLIK KAPISI ZORUNLU:** cozum donene kadar kullanici
  ///	BASKA bir nokta secmis olabilir; koordinat karsilastirmasi
  ///	olmadan ESKI adres YENI noktanin uzerine yazilirdi (bu
  ///	projede "bayat yanit" sinifi turu 85b/93b/150'de yasandi).
  /// ⚠️ [koruAd] verilirse birincil satir DEGISMEZ ve cozulen adres
  ///    ALT SATIRA yazilir. "Konumum" icin sart: kullanicinin kendi
  ///    konumunu bir cadde adiyla degistirmek, "nereden yola cikiyorum"
  ///    bilgisini SILERDI.
  Future<void> _adresiYaz(
    double enlem,
    double boylam,
    bool baslangicIcin, {
    String? koruAd,
  }) async {
    final metin = await AdresServisi.i.coz(enlem, boylam);
    if (!mounted || metin == null || metin.isEmpty) return;
    final hedef = baslangicIcin ? _rotaBas : _rotaVaris;
    if (hedef == null ||
        hedef.enlem != enlem ||
        hedef.boylam != boylam) {
      return;
    }
    // ⚠️ Adres IKI PARCA: ilk virgulden oncesi cadde/no (birincil
    //    satir), sonrasi mahalle/ilce (ikincil satir).
    final v = metin.indexOf(', ');
    final ad = koruAd ?? (v < 0 ? metin : metin.substring(0, v));
    final alt = koruAd != null ? metin : (v < 0 ? '' : metin.substring(v + 2));
    setState(() {
      final yeni = RotaNoktasi(
        ad: ad,
        altAd: alt,
        enlem: enlem,
        boylam: boylam,
      );
      if (baslangicIcin) {
        _rotaBas = yeni;
      } else {
        _rotaVaris = yeni;
      }
    });
  }

  /// Rotayi arar ve sonucu gosterir.
  ///
  /// ⚠️ Hesap tamamen KENDI GTFS verimizle yapilir; Google'a istek YOK.
  Future<void> _rotaAra() async {
    final b = _rotaBas;
    final v = _rotaVaris;
    // ⚠️ Iki uc da SECILMEDEN arama yapilmaz; kullanici zaten
    //    planlama sayfasinda ikisini de gorur (dugme orada PASIF).
    if (b == null || v == null) return;
    // ⚠️ TURU 154 - rota DEGISIYOR; eski rotanin takibi surerse
    //    yeni bacaklarla eski `_takip.bacak` indeksi uyusmaz.
    if (_takip != null) _takipDurdur();
    setState(() => _rota = null);
    final adaylar = await rotaAra(
      baslangicEnlem: b.enlem,
      baslangicBoylam: b.boylam,
      varisEnlem: v.enlem,
      varisBoylam: v.boylam,
    );
    if (!mounted) return;
    await rotaSonucAc(
      context,
      adaylar: adaylar,
      rotaSec: (a) {
        // ⚠️ Yeni rota secildiginde eski takip GECERSIZ: bacak
        //    indeksleri baska bir rotaya aitti.
        _konumAkisi?.cancel();
        _konumAkisi = null;
        setState(() {
          _takip = null;
          _rota = a;
          // ⚠️⚠️ Kullanici emri: *"rota bulununca alttaki durak kartlari
          //	GIDECEK"*. Kartlar rota ozetine yerini birakir.
          _seciliDurak = null;
        });
        _rotayaSigdir(a);
      },
      yenidenSec: () => unawaited(_rotaPlanla()),
    );
  }

  /// ⚠️ Kullanici emri: *"sistem UZAKLASACAK, shape cizecek"*. Rotanin
  ///    tamami ekrana sigacak sekilde kamera geri cekilir.
  void _rotayaSigdir(RotaAdayi a) =>
      _noktalaraSigdir([for (final b in a.bacaklar) ...b.noktalar]);

  /// Verilen nokta dizisini ekrana sigdirir - **TEK KAYNAK**.
  ///
  /// ⚠️ Hem rotanin tamami (`_rotayaSigdir`) hem TEK BIR BACAK
  ///    (`_adimaGit`) bunu cagirir. Iki ayri kopya yazilsaydi biri
  ///    degisince oteki geride kalirdi (bu projede ayni sinif DORT kez
  ///    komsu uyeyi de goturdu).
  void _noktalaraSigdir(List<({double enlem, double boylam})> yol) {
    double? gEn, kEn, bBoy, dBoy;
    for (final nk in yol) {
      gEn = gEn == null ? nk.enlem : math.min(gEn, nk.enlem);
      kEn = kEn == null ? nk.enlem : math.max(kEn, nk.enlem);
      bBoy = bBoy == null ? nk.boylam : math.min(bBoy, nk.boylam);
      dBoy = dBoy == null ? nk.boylam : math.max(dBoy, nk.boylam);
    }
    if (gEn == null || kEn == null || bBoy == null || dBoy == null) return;
    // ⚠️ Yerel degiskenlere ALINIR: kayit alanlari `double?` cikarsanirsa
    //    tip uyusmaz (Dart null-yukseltmeyi kayit icinde yapmaz).
    final g = gEn, k2 = kEn, b2 = bBoy, d2 = dBoy;
    setState(() {
      _sigdir = (
        guney: g,
        kuzey: k2,
        bati: b2,
        dogu: d2,
        nesil: (_sigdir?.nesil ?? 0) + 1,
      );
    });
  }

  /// ⚠️⚠️⚠️ TURU 151 - **DURAK BILGI PANELI** (kullanici emri:
  ///	*"duraga tikladigimda hatlar, gecen otobusler, durak
  ///	hakkinda bilgi GORUNMUYOR, sadece alttaki karttan
  ///	geliyor"*).
  ///
  /// ⚠️⚠️ **PANEL ZATEN YAZILMISTI, ULASILAMIYORDU** - bu projenin
  ///	en sik hata sinifi ("bir uc/servis eklenir, onu CAGIRAN
  ///	yol yazilmaz"; turu 93b/113/80b'de ayni sey yasandi).
  ///	Turu 150'de pin dokunusu KARTI seciyordu, detayi ACMIYORDU.
  ///
  /// ⚠️ Kart 3 hat gosterir (yer yok); panel **TUM hatlari** ve
  ///    her hattin **sonraki UC kalkisini** gosterir.
  /// ⚠️ Adres ONBELLEKTEN gelirse aninda yazilir; gelmezse panel
  ///    adres SATIRI OLMADAN acilir. Ters geocoding icin sheet'i
  ///    BEKLETMEK, saniyelerce bos ekran demekti.
  Future<void> _durakDetay(Durak d) async {
    if (!mounted) return;
    final k = _konum;
    final m = k == null
        ? null
        : UlasimVeri.kabaMetre(k.enlem, k.boylam, d.enlem, d.boylam);
    await ulasim.durakDetayAc(
      context,
      d,
      mesafeM: m,
      adres: AdresServisi.i.onbellektenCoz(d.enlem, d.boylam),
      guzergahSec: (hat, yon) => unawaited(_guzergahCiz(hat, yon)),
    );
  }

  /// Secilen hattin GERCEK guzergahini haritaya cizer.
  ///
  /// ⚠️ Guzergah GTFS `shapes.txt`ten geliyor, yani **gercekten
  ///    sokaklari takip eder** — duraklar arasi duz cizgi DEGIL.
  Future<void> _guzergahCiz(Hat hat, int yon) async {
    final nk = await UlasimVeri.i.guzergah(hat.id, yon);
    if (!mounted) return;
    if (nk.isEmpty) {
      _mesaj('Bu hattın güzergah çizimi veride yok.');
      return;
    }
    setState(() {
      _hatCizgi = (noktalar: nk, renk: ulasim.hatRengi(hat));
      _hatEtiketi = '${hat.kisaAd} · ${hat.yonBaslik[yon] ?? hat.uzunAd}';
    });
  }

  Future<void> _taksiAc() async {
    final k = _konum;
    if (k == null) {
      _mesaj('Yakındaki taksi duraklarını görebilmek için konum izni gerekiyor.');
      return;
    }
    if (!mounted) return;
    await ulasim.taksiListesiAc(
      context,
      enlem: k.enlem,
      boylam: k.boylam,
      haritadaGoster: (t) {
        setState(() {
          _odak = (
            enlem: t.enlem,
            boylam: t.boylam,
            nesil: (_odak?.nesil ?? 0) + 1,
          );
        });
      },
    );
  }

  /// Panel · popup · filtre ekrani ORTAK koyu temasi (TEK KAYNAK).
  ///
  /// ⚠️ `ThemeData.dark()` uygulamanin **"dokunma dairesi YOK"** kararini
  ///    (turu 7 kullanici emri) SIFIRLAR; acikca geri konur.
  ThemeData _koyuTema() => ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: morLogo,
          brightness: Brightness.dark,
        ).copyWith(surface: kAiZemin),
        scaffoldBackgroundColor: kAiZemin,
        textTheme: ThemeData.dark(useMaterial3: true)
            .textTheme
            .apply(fontFamily: 'Google Sans'),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      );

  /// ⚠️⚠️⚠️ TURU 137 — **PANELDEKI YATAY ISLETME SERIDI** (kullanici emri:
  ///	*"otele tikladigimda ... sirket kartlari DIREKT gelecek, EN
  ///	YAKINDAKI ILK BASTA olacak ve hepsi SOL SAG SCROLL seklinde
  ///	olacak, yuksekligi biraz arttir, PROFIL ve HARITA ikonu koy"*).
  ///
  /// ⚠️ **YALNIZ KATEGORI SECILIYKEN** cizilir. "Tümü"de 17 kategorinin
  ///    karisimi bir serit hem anlamsiz olurdu hem paneli iki katina
  ///    cikarirdi (bkz. `_panelBoy`).
  /// ⚠️ **EN YAKIN ONCE**: `km` artan siralanir. Sunucu `/yakinimda` zaten
  ///    mesafeye gore doner ama ornek kayitlar araya karisiyor; sirayi
  ///    BURADA garanti etmek iki kaynagi da hizalar.
  ///    ⚠️ `km == 0` (mesafe BILINMIYOR) DAIMA SONA: aksi halde mesafesi
  ///       olmayan bir kayit "en yakin" gibi basa gecerdi (turu 122'de ilan
  ///       fiyatinda birebir ayni tuzak).
  /// ⚠️ Liste bossa ya da yukleme surerken serit HIC cizilmez (bos gri
  ///    kutular "yukleniyor" gibi okunurdu).
  Widget? _panelSeridi(BuildContext c) {
    if (_yukleniyor) return null;
    // ⚠️⚠️⚠️ TURU 144 — kosul `_panelBoy`daki `seritVar` ile **BIREBIR**
    //	olmak ZORUNDA; ayrisirsa panel yuksekligi ile icerigi tutmaz ve
    //	yuzen filtre seridi kayar (bu ekranda turu 132'de yasandi).
    //	· `_dal.isEmpty` CIKTI: kullanici *"hicbir sey aktif olmadiginda
    //	  hep yakindakiler gorunecek"* dedi.
    //	· `_yukleniyor` KALDI ama artik YALNIZCA onbellek iskaladiginda
    //	  true; onbellek isabetinde serit HIC kaybolmaz (bkz. `_yukle`).
    //	  ⚠️ Kapi ZORUNLU: kaldirildiginda yeni kategori yuklenirken ekran
    //	     ONCEKI kategorinin kayitlarini cizmeye devam ediyordu.
    final l = [..._gorunen]
      ..sort((a, b) {
        final ak = a.km <= 0 ? double.infinity : a.km;
        final bk = b.km <= 0 ? double.infinity : b.km;
        return ak.compareTo(bk);
      });
    if (l.isEmpty) return null;
    final ogeler = l.take(kPanelSeritTavan).toList();
    // ⚠️ Serit ARTIK KOLONUN SON OGESI (turu 144 sirasi): altinda 12 dp'lik
    //    ayrac YOK, panelin kendi alt dolgusu var.
    return SizedBox(
      height: _seritBoy(c),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
        physics: const BouncingScrollPhysics(),
        itemCount: ogeler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _panelKarti(c, ogeler[i]),
      ),
    );
  }

  /// Serit yuksekligi — **YAZI OLCEGINDEN TURETILIR**.
  ///
  /// ⚠️ Sabit dp yazilsaydi olcek 1.3/2.0'da ad + meta + alt satir tasar
  ///    ve sari-siyah serit cikardi (bu ekranda olculmus sinif).
  /// ⚠️ `_panelBoy` de BU FONKSIYONU cagirir: panel yuksekligi ile seridin
  ///    gercek boyu ayrisirsa kartlar panelin ALTINDA kalir.
  ///
  /// ⚠️⚠️ TURU 140 — alt satir artik IKI TURLU olabiliyor (bkz. `_altSatir`):
  ///	MENU KARELERI (`kMenuKare`) ya da URUN CIPLERI. Yukseklik ikisinden
  ///	HANGISININ cizilecegini `_menuluSerit`ten sorar.
  /// ⚠️⚠️ **ALT SATIR YUKSEKLIGI TEK KAYNAK** (`_altSatirBoy`): turu 139'da
  ///	bu formul IKI YERDE ayri ayri yaziliydi (`_seritBoy` ve `_urunSeridi`)
  ///	ve yalniz birini degistirmek ya tasma ya altta bos serit uretirdi.
  double _seritBoy(BuildContext c) {
    // ⚠️⚠️⚠️ TURU 145 — **AD ARTIK IKI SATIR** (kullanici emri: *"isletme
    //	kartlarini yukselt dedim, mesela yemekte 2 SATIRLI ISIM yap; 2
    //	satirli olsun, OLMASA BILE YUKSEKLIK DEGISMESIN"*).
    //	Ad alani SABIT iki satir yuksekligindedir (`_kartAdBoy`), yani
    //	tek satirlik adli bir kart da AYNI boyda durur — serit kayittan
    //	kayita ZIPLAMAZ.
    // ⚠️ Sol daire 46 dp; iki satirlik ad + meta ondan uzun olabilir.
    //    Ikisinin BUYUGU alinir — `Row` zaten en uzun cocugu kadar olur.
    final ust = _kartUstBoy(c);
    final ham = 12 + ust + 10 + _altSatirBoy(c) + 12;
    // ⚠️⚠️ **+1 dp PAY ZORUNLU** — emulatorde OLCULDU: paysiz hesapta
    //	*"RenderFlex overflowed by 0.800 pixels"* cikti. Flutter satir
    //	kutusunu yukari yuvarlar; `fontSize * height` carpimi gercek
    //	yuksekligi TAM vermez.
    // ⚠️ YAPMA: payi kaldirma.
    return ham.ceilToDouble() + 1;
  }

  /// Kart basligindaki ADIN alani — **SABIT IKI SATIR** (TEK KAYNAK).
  ///
  /// ⚠️⚠️ TURU 145 — kullanici emri: *"2 satirli olsun, OLMASA BILE
  ///	YUKSEKLIK DEGISMESIN"*. Deger hem `_seritBoy` hem kart govdesi
  ///	tarafindan okunur; ayri ayri yazilsalardi biri degisince oteki
  ///	geride kalir ve kart ya tasar ya bos bir band birakirdi.
  double _kartAdBoy(BuildContext c) =>
      MediaQuery.textScalerOf(c).scale(15) * 1.25 * 2;

  /// Kartin UST SATIRININ (logo · ad+meta · dugmeler) yuksekligi —
  /// **TEK KAYNAK** (`_seritBoy` ve kart govdesi ayni degeri okur).
  ///
  /// ⚠️ TURU 146 — ad + meta artik BIR GRUP olarak bu yukseklikte dikey
  ///    ortalanir; boylece tek satirlik adda ad ile meta ARASINDA bosluk
  ///    kalmaz ama kart boyu kayittan kayita DEGISMEZ.
  /// ⚠️ Sol daire 46 dp; grup ondan uzun olabilir, BUYUGU alinir.
  /// ⚠️⚠️⚠️ EMULATORDE OLCULDU: *"BOTTOM OVERFLOWED BY 1.5 PIXELS"*.
  ///	Kardesi `_seritBoy` **+1 dp pay** tasiyordu, bu formul PAYSIZDI:
  ///	ici `mainAxisSize.max` bir `Column` ve `fontSize * height` carpimi
  ///	gercek satir yuksekligini TAM vermez (Flutter YUKARI yuvarlar).
  ///	Ayni sinifin turu 121/123/137/141de olculmus tekrari.
  /// ⚠️ Pay **2 dp**: iki metin satiri + meta = UC yuvarlama noktasi.
  double _kartUstBoy(BuildContext c) => math.max(
        46.0,
        (_kartAdBoy(c) + 2 + MediaQuery.textScalerOf(c).scale(12) * 1.25)
                .ceilToDouble() +
            2,
      );

  /// Kartin ALT SATIRININ yuksekligi — **TEK KAYNAK**.
  ///
  /// ⚠️ `_seritBoy` ve `_altSatir` IKISI DE bunu okur; ayri ayri
  ///    hesaplansalardi biri degisince oteki geride kalir ve kart ya tasar
  ///    ya altta bos bir serit birakirdi (turu 139'da bu drift vardi).
  /// ⚠️⚠️ TURU 143 — vitrin ogesi artik **ad + fiyat** (gorsel KALKTI) ve
  ///	bir KUTU icinde cizilir. Yukseklik `kMenuKare` ile iki metin
  ///	satirindan BUYUK olani; yalniz metne bakilsaydi kutular olcek 1.0'da
  ///	cok basik dururdu, yalniz `kMenuKare`e bakilsaydi olcek 2.0'da
  ///	metin TASARDI.
  double _altSatirBoy(BuildContext c) {
    final o = MediaQuery.textScalerOf(c);
    // ⚠️⚠️⚠️ TURU 144 — **DAL AYRIMI KALKTI** (kullanici emri: *"alttaki
    //	isletme kartlari mesela YEMEKTE YUKSEK ama HIZMETLERDE alcak;
    //	yemekteki gibi HEPSI ESIT olsun"*). Onceden vitrinli dallarda
    //	(yemek · kafe · akaryakit · otel · hizmet) alt satir `kMenuKare`
    //	kadar, digerlerinde ~25 dp idi ve kartlar kategoriye gore
    //	BOY DEGISTIRIYORDU.
    // ⚠️ Urun cipleri (vitrini olmayan dallar) artik bu yuksekligin
    //    ICINDE DIKEY ORTALANIR (bkz. `_urunSeridi`) — gerilmezler.
    // ad(13) + 2 + fiyat(13) — ikisi de `height: 1.2` — **artı kutunun
    // dikey ic dolgusu (2 × 6)**; dolgu sayilmazsa kutu metni KIRPARDI.
    // ⚠️ TURU 146 — ad artik IKI SATIR: carpan 2.
    final metin = o.scale(13) * 1.2 * 2 + 2 + o.scale(13) * 1.2 + 12;
    // ⚠️ TURU 144 — ayni deger TUM dallarda dondurulur.
    // ⚠️⚠️ TURU 145 — taban `kMenuKare + 12`: kutunun ICINDE artik bos bir
    //	RESIM KARTI (`kMenuKare`) var ve dikey dolgu 2x6 onun DISINDA.
    //	Yalniz `kMenuKare`e bakilsaydi kutu resim kartini KIRPARDI.
    // ⚠️ **+1 dp PAY**: olcek 1.875'in uzerinde metin dali BAGLAYICI olur
    //    (2.0'da 59,6 > 56) ve paysiz hesap RenderFlex tasmasi uretirdi.
    return math.max(kMenuKare + 12, metin.ceilToDouble() + 1);
  }

  /// Bu DALDA vitrin kalemi TANIMLI MI (yemek · kafe · akaryakit · otel ·
  /// hizmet)?
  ///
  /// ⚠️ Serit TEK dal gosterir, yani karar serit genelinde AYNI olur ve
  ///    kart yukseklikleri tutarli kalir.
  /// ⚠️ TURU 147 — alt satirda KUTU cizilen dallar: fiyatli vitrin
  ///    (`_ornekVitrin`) **ya da** fiyatsiz hizmet (`_ornekHizmet`).
  ///    Ikisi de ayni yukseklikte cizilir; kartlar dallar arasi ESIT kalir.
  /// ⚠️⚠️⚠️ TURU 150 - **HER DALDA `true`**: alt satirda ya VITRIN
  ///	(fiyatli) ya da **YAPAY ZEKA YORUMU** cizilir; ikisi de
  ///	`_altSatirBoy` yuksekliginde oldugu icin kartlar dallar arasi
  ///	ESIT kalir (turu 144 karari).
  /// ⚠️ `_bosYorum` yedegi oldugu icin tablosu olmayan dal da kart cizer.
  bool get _menuluSerit => true;

  /// Bu seritte VITRIN ogeleri cizilecek MI (serit genelinde tek karar).
  ///
  /// ⚠️ Vitrin kalemleri YALNIZ ornek kayitlarda var (gercek isletmenin
  ///    urun adi/fiyati/gorseli `/yakinimda` yanitinda YOK).
  /// ⚠️⚠️ **`_gorunen` OKUNMAZ** (denetim bulgusu): o bir GETTER ve her
  ///	okumada 60 kaydi bastan suzup DORT YENI `IsletmeOzet` uretiyor.
  ///	Kart basina cagrildigi icin dikey listede O(n²) oluyordu.
  ///	Olcut ESDEGER ve O(1): ornek kayit TAM OLARAK bu uc kosul saglaninca
  ///	uretilir (bkz. `_ornekIsletmeler` ve `_gorunen`).
  bool get _menuluKume =>
      _menuluSerit && kHaritaOnizleme && _konum != null;

  /// ⚠️ TURU 144 — YUKSEKLIK ARTIK IKI DALDA DA AYNI (`_altSatirBoy`); bu
  ///    kosul yalnizca ICERIGIN hangisi olacagini secer.
  Widget _altSatir(BuildContext c, IsletmeOzet o, bool ornek) {
    if (!_menuluKume || !ornek) return _urunSeridi(c, o);
    // ⚠️⚠️ TURU 150 - fiyat ANLAMLI olan dallarda vitrin KALIR
    //	(yemek - kafe - akaryakit - otel; kullanici turu 143te bunu
    //	ACIKCA istemisti). Digerlerinde `_hizmetSeridi`nin yerini
    //	**YAPAY ZEKA YORUMU** aldi (kullanici emri).
    if (_ornekVitrin.containsKey(_dal)) return _vitrinSeridi(c, o);
    return _aiYorumSeridi(c, o);
  }

  /// ⚠️⚠️⚠️ TURU 147 — **HIZMET KARTLARI (FIYATSIZ)**.
  ///
  /// Yemek/kafe kartindaki [gorsel kutusu + ad + fiyat] duzeni hizmetlerde
  /// KOTU duruyordu (kullanici emri). Burada kutunun ICINDE yalnizca
  /// HIZMET ADI var; kutu olcusu ve radusu vitrinle AYNI, boylece kartlar
  /// dallar arasi ESIT kalir (turu 144 karari).
  /// ⚠️ Kalemler kayittan kayita KAYDIRILIR (turu 141 dersi): imza
  ///    `IsletmeOzet` almadan yazilsaydi bir daldaki dort ornek kart da
  ///    AYNI hizmetleri gosterirdi.
  /// ⚠️⚠️⚠️ TURU 150 - **YAPAY ZEKA YORUM ALANI** (kullanici emri).
  ///
  /// Tek kutu: solda kivilcim ikonu, saginda "Gebzem AI" etiketi +
  /// yorum metni (en fazla IKI satir, tasarsa ellipsis).
  ///
  /// ⚠️⚠️ **YUKSEKLIK `_altSatirBoy` ILE AYNI OLMAK ZORUNDA**: kart boyu
  ///	bu degerden turetiliyor (`_seritBoy`). Ayrisirsa kartlar ya tasar
  ///	ya altta bos serit birakir (turu 139da bu drift yasandi).
  /// ⚠️ **TASMAYA KAPALI (hesaplandi):** metin dali
  ///    `scale(12.5)*1.25*2 + 12` = `scale(13)*2.4 + 12`; `_altSatirBoy`
  ///    metin dali ise `scale(13)*3.6 + 14`. Yani HER yazi olceginde
  ///    kutunun icerigi tabandan KUCUK kalir.
  /// ⚠️ Kutu `ListView` DEGIL: tek oge var ve ic ice yatay kaydirma
  ///    kartin alt yarisindaki suruklemeyi yerdi (turu 140 dersi).
  Widget _aiYorumSeridi(BuildContext c, IsletmeOzet o) {
    final tum = _aiYorum[_dal] ?? _bosYorum;
    // ⚠️ Kart basina KAYDIRILIR: ayni daldaki dort ornek kart ayni
    //    yorumu gostermesin (turu 141 dersi).
    final i0 = int.tryParse(o.id.split('-').last) ?? 0;
    final yorum = tum[i0 % tum.length];
    final tema = Theme.of(c);
    return SizedBox(
      height: _altSatirBoy(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kAiKartYuzey(c),
            borderRadius: BorderRadius.circular(kYaricap(_altSatirBoy(c))),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ⚠️ Kivilcim marka renginde: kutunun "yapay zeka"
                //    oldugunu tek bakista anlatan tek isaret.
                Icon(LucideIcons.sparkles, size: 15, color: kVurgu(c)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: 'Gebzem AI  ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: kVurgu(c),
                        ),
                      ),
                      TextSpan(text: yorum),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color:
                          tema.colorScheme.onSurface.withValues(alpha: 0.88),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _hizmetSeridi(BuildContext c, IsletmeOzet o) {
    final tum = _ornekHizmet[_dal] ?? const <String>[];
    if (tum.isEmpty) return SizedBox(height: _altSatirBoy(c));
    final i0 = int.tryParse(o.id.split('-').last) ?? 0;
    final kalemler = [
      for (var i = 0; i < tum.length; i++) tum[(i0 + i) % tum.length],
    ];
    return SizedBox(
      height: _altSatirBoy(c),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: kalemler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => DecoratedBox(
          decoration: BoxDecoration(
            color: kAiKartYuzey(c),
            borderRadius: BorderRadius.circular(kYaricap(_altSatirBoy(c))),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: ConstrainedBox(
                // ⚠️ Tavan: uzun bir hizmet adi ("Beslenme Danışmanlığı")
                //    kartin tamamini kaplamasin; iki satira sarar.
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  kalemler[i],
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 141 — **VITRIN SERIDI: GORSEL + AD + FIYAT** (kullanici
  ///	emri: *"yemekte menu resminin SAGINA ISMI, ALTINA FIYATI yazsin,
  ///	kafede boyle"* + *"benzin istasyonuna tikladiginda ... AKARYAKIT
  ///	FIYATLARI gorunsun"* + *"odalar tikladiginda odalar gozukecek"*).
  ///
  /// ⚠️⚠️ TURU 143 — **GORSEL YOK**: her kalem `kAiKartYuzey` zeminli bir
  ///	kutu icinde [ad / fiyat] gosterir (kullanici emri).
  ///
  /// ⚠️⚠️ **`Row` + `Expanded` — IC ICE YATAY KAYDIRMA YOK.** Ogeler bir
  ///	`ListView` olsaydi kartin ALT YARISINDAKI yatay surukleme ICTEKI
  ///	listeye gider ve DIS isletme seridi kaymazdi (turu 140'ta olculdu).
  ///	`Expanded` ile ogeler kalan genisligi PAYLASIR; tasma YAPISAL OLARAK
  ///	imkansiz.
  /// ⚠️ Radus `kYaricap(...)` — kategori dairesi ve kart dugmeleriyle AYNI
  ///    dil (sabit sayi YAZILMADI).
  Widget _vitrinSeridi(BuildContext c, IsletmeOzet o) {
    final tum = _ornekVitrin[_dal] ?? const [];
    if (tum.isEmpty) return SizedBox(height: _altSatirBoy(c));
    // ⚠️⚠️ **KALEMLER KAYITTAN KAYITA KAYDIRILIR** (denetim bulgusu):
    //	imza `IsletmeOzet` almadan yazilmisti ve bir daldaki DORT ornek
    //	kart da AYNI kalemleri gosteriyordu — Burger King kartinin altinda
    //	"Big Mac Menü" yaziyordu.
    // ⚠️ Kaydirma kayit kimliginin SON parcasindan (`demo-harita-<dal>-<i>`)
    //    turer; sunucu kaydinda bu dal zaten calismaz.
    final i0 = int.tryParse(o.id.split('-').last) ?? 0;
    final kalemler = [
      for (var i = 0; i < tum.length; i++) tum[(i0 + i) % tum.length],
    ];
    final scheme = Theme.of(c).colorScheme;

    // ⚠️⚠️⚠️ TURU 143 — her kalem artik **KUTU ICINDE** (kullanici emri:
    //	*"menuleri TELEFON VE HARITA GIBI bir KATEGORI RADUS mantiginda bir
    //	KARENIN ICINE al"*). Zemin `kAiKartYuzey` ve radus `kYaricap` —
    //	kartin sag dugmeleri (`_kartDugmesi`), sol kategori dairesi ve
    //	menudeki kategori kartlariyla AYNI dil; sabit sayi YAZILMADI.
    Widget oge(({String ad, String fiyat}) k) => DecoratedBox(
          decoration: BoxDecoration(
            color: kAiKartYuzey(c),
            borderRadius: BorderRadius.circular(kYaricap(_altSatirBoy(c))),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
              // ⚠️⚠️⚠️ TURU 145 — **BOS RESIM KARTI** (kullanici emri:
              //	*"buradaki menulerin soluna KART ekle dedim, RESIM KARTI
              //	ama RESIM EKLEME"*).
              // ⚠️⚠️ Gercekten BOS: bu projede urun GORSELI `/yakinimda`
              //	yanitinda YOK ve turu 141'de elimizdeki dort McDonald's
              //	fotografi yanlis kalemlere dusuyordu ("Filtre Kahve"nin
              //	yaninda PATATES). **Yanlis gorsel, gorselsizden KOTUDUR.**
              //	Kutu, veri baglandiginda gorselin girecegi YERI tutuyor.
              Container(
                width: kMenuKare,
                height: kMenuKare,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(kYaricap(kMenuKare)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚠️ TURU 146 — ad **IKI SATIR** (kullanici emri). Kutunun
                //    yuksekligi `_altSatirBoy` ile SABIT oldugu icin iki
                //    satirlik ad da tek satirlik ad da AYNI kutuda durur.
                Text(
                  k.ad,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  k.fiyat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface.withValues(alpha: 0.92),
                  ),
                ),
              ],
                ),
              ),
              ],
            ),
          ),
        );

    // ⚠️ TURU 142 — ogeler YATAY KAYDIRILIR (kullanici emri).
    // ⚠️ Bedeli BILINIYOR: ic ice yatay kaydirma, kartin ALT yarisindaki
    //    suruklemeyi ICTEKI listeye verir ve dis serit o bolgeden kaymaz
    //    (turu 140'ta olculmustu). Kullanici kaydirmayi ACIKCA istedi.
    // ⚠️⚠️ TURU 143 — gorsel kalktigi icin oge **TEK GENISLIKTE** (128) ve
    //	aralik **14 -> 8** (kullanici: *"menuleri YAKLASTIR dedim,
    //	aralarindaki boslugu AZALT"*).
    // ⚠️ TURU 145 — soldaki bos resim karti (56) + 8 + metin + 2x6 dolgu.
    const ogeEn = 190.0;
    return SizedBox(
      height: _altSatirBoy(c),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // ⚠️ TURU 144 — dolgu kolondan BURAYA tasindi (bkz. `_panelKarti`):
        //    serit artik kartin GERCEK kenarina kadar kayiyor.
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: kalemler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SizedBox(width: ogeEn, child: oge(kalemler[i])),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 139/140 — **SERITTEKI ISLETME KARTI**.
  ///
  ///	turu 139 (kullanici tarifi): solda kategori dairesi · saginda ad ·
  ///	altinda yildiz/mesafe · sagda profil + harita ikonlari · altinda
  ///	urunler.
  ///	turu 140 (kullanici emri: *"kartlari genislet, isletme kartlarinda
  ///	HARITANIN SOLUNA TELEFON IKONU koy, yemekte isletmenin orada
  ///	MENULER gorunsun"*): kart genisledi ve alt satirda MENU KALEMLERI.
  ///	⚠️ GUNCEL DURUM: `kPanelKartEn` **372** (turu 144'te 348'den cikti)
  ///	   ve sagda **IKI** dugme var — profil dugmesi turu 142'de kaldirildi
  ///	   (profil KART GOVDESINDEN aciliyor).
  ///
  /// ⚠️⚠️ **GENISLIK BUTCESI (turu 144'te guncellendi):** ust satirin
  ///	dolgusu 2x10; SABIT ogeler 46 (logo) + 10 + 8 + 2x36 + 6 = 142 dp.
  ///	Kart 300'de kalsaydi ada+metaya 96 dp kalirdi ve "Domino's Pizza"
  ///	bile ellipsis'e girerdi; 348'de 144 dp kaliyor (turu 139'daki
  ///	138 dp'nin biraz USTU).
  /// ⚠️⚠️ **KAPAK GORSELI YOK**: kullanicinin tarif ettigi duzende yer
  ///	almiyor ve ornek kayitlarin cogunun kapagi bos oldugu icin serit
  ///	bos gri kutularla doluyordu (turu 139 karari).
  /// ⚠️ **KART GOVDESINE DOKUNMAK HARITAYA ODAKLANIR** (kullanici emri).
  ///    Profil SAGDAKI dugmeden acilir — iki eylem AYRI.
  /// ⚠️ [esnek] TURU 141 — DIKEY listede kart SABIT 348 dp olamaz: 360 dp
  ///    ekranda saga 4 dp kalir ve kart kirpik durur. Popup listesinde
  ///    `esnek: true` verilir ve kart ebeveynin genisligini alir.
  /// ⚠️ [haritaKapat] TURU 141 — popup icinde "Haritada göster" once
  ///    SHEET'I KAPATIR; yoksa kamera tasinir ama kullanici goremez.
  Widget _panelKarti(
    BuildContext c,
    IsletmeOzet o, {
    bool esnek = false,
    bool haritaKapat = false,
  }) {
    final scheme = Theme.of(c).colorScheme;
    final ornek = o.id.startsWith('demo-');
    final meta = [
      if (o.puan != null) '${o.puan!.toStringAsFixed(1).replaceAll('.', ',')} ★',
      if (o.mesafeMetni.isNotEmpty) o.mesafeMetni,
      if (ornek) 'Örnek',
    ].join(' · ');
    return SizedBox(
      width: esnek ? null : kPanelKartEn,
      child: Material(
        color: kYuzeyGri(c),
        borderRadius: BorderRadius.circular(kYaricap(96)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // ⚠️⚠️ TURU 141 — kart govdesi **PROFILI ACAR** (kullanici emri:
          //	*"alttaki isletme kartina tikladiginda popup acilsin,
          //	isletmenin %95 profil hesabi"* ve *"bu isletme kartlarinda
          //	isletme kartina tikladiginda ISLETME PROFILI acilacak"*).
          //	Turu 139/140'ta govde haritaya gidiyordu; karar TERSINE
          //	cevrildi.
          // ⚠️ Harita odagi ULASILAMAZ KALMADI: kartin SAGINDAKI harita
          //    dugmesi hala `_haritadaGoster` cagiriyor.
          onTap: () => _isletmeAc(o),
          // ⚠️⚠️⚠️ TURU 144 — **YATAY DOLGU KOLONDAN CIKARILDI** (kullanici:
          //	*"isletme kartindaki menu scroll SAGDA DIVINE TAKILIYOR,
          //	takilmasin"*). Dolgu kolonun uzerindeyken alt serit kartin
          //	IC kenarinda bitiyordu; ogeler oraya dayanip **duvara carpmis
          //	gibi** duruyordu. Artik dolgu UST SATIRDA ve seridin KENDI
          //	`padding`inde — serit kartin GERCEK kenarina kadar kayiyor.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                  children: [
                    _kartLogosu(c, o),
                    const SizedBox(width: 10),
                    Expanded(
                      // ⚠️⚠️⚠️ TURU 146 — **AD + META TEK GRUP, DIKEY
                      //	ORTALI** (kullanici: *"McDonald's ve altinda 4.8
                      //	arasinda BOSLUK olmus, onu duzelt"*).
                      //	Turu 145'te ad alani SABIT iki satirdi ve TEK
                      //	SATIRLIK adda altta bos bir satir kaliyor, meta
                      //	ondan SONRA basliyordu. Artik sabit yukseklik
                      //	GRUBUN kendisinde; grup ortalandigi icin ad ile
                      //	meta arasinda bosluk KALMIYOR, kart boyu ise
                      //	DEGISMIYOR (`_seritBoy` ile ayni kaynak).
                      child: SizedBox(
                        height: _kartUstBoy(c),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(
                                  o.ad,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (o.dogrulandi)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4, top: 3),
                                  child: Icon(LucideIcons.badgeCheck,
                                      size: 13, color: kOnayliRengi),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: scheme.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ── SAGDA UC EYLEM ──
                    // ⚠️ TURU 140 — telefon HARITANIN SOLUNA (kullanici emri);
                    //    sira: telefon · profil · harita.
                    // ⚠️⚠️ TURU 146 — **YORUM DUGMESI** (kullanici emri:
                    //	*"telefonun soluna yorum ikonu koy"*).
                    // ⚠️ DURUST SINIR: bu ekranda yorum YAZMA/OKUMA yolu
                    //	YOK; `/isletmeler/yakinimda` yorum dondurmuyor.
                    //	Dugme isletmenin PROFILINI acar — yorumlar orada.
                    //	⚠️ YAPMA: buraya sahte bir yorum sayisi yazma.
                    _kartDugmesi(
                      c,
                      LucideIcons.messageCircle,
                      'Yorumlar',
                      () => _isletmeAc(o),
                    ),
                    const SizedBox(width: 6),
                    _kartDugmesi(c, LucideIcons.phone, 'Ara', () => _ara(o)),
                    const SizedBox(width: 6),

                    _kartDugmesi(
                      c,
                      LucideIcons.map,
                      'Haritada göster',
                      () {
                        if (haritaKapat) Navigator.of(c).maybePop();
                        _haritadaGoster(o);
                      },
                    ),
                  ],
                  ),
                ),
                const SizedBox(height: 10),
                _altSatir(c, o, ornek),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kartin sol dairesi — **KATEGORI IKONU**.
  ///
  /// ⚠️⚠️⚠️ TURU 143 — **MARKA LOGOSU KARTTAN KALDIRILDI** (kullanici emri:
  ///	*"isletme kartlarindaki logoyu kaldir"*). Turu 140'ta eklenmisti.
  ///	`_ornekLogo` tablosu SILINMEDI: haritadaki **marka logolu pinler**
  ///	(`_markaPinUret`) hala onu okuyor — kullanici logolari HARITADA
  ///	acikca istedi (turu 142).
  /// ⚠️ YAPMA: `_ornekLogo`yu "artik kullanilmiyor" diye silme.
  Widget _kartLogosu(BuildContext c, IsletmeOzet o) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // ⚠️ TEK KAYNAK: cip ikonlariyla ve menudeki kategori kartiyla
        //    AYNI yuzey.
        color: kAiKartYuzey(c),
        borderRadius: BorderRadius.circular(kYaricap(46)),
      ),
      child: Icon(_kategoriIkonu(o.kategori), size: 22, color: kVurgu(c)),
    );
  }

  /// Kartin altindaki **urun seridi**.
  ///
  /// ⚠️⚠️ **DURUST SINIR — GERCEK KAYITTA URUN ADI YOK.** `/yakinimda`
  ///	yaniti (`IsletmeOzet`) urun ADI dondurmuyor; yalnizca `urunSayisi`
  ///	ve `minFiyatKurus` var. Her kart icin `/users/{id}/urunler` cagirmak
  ///	seritte 12 EK ISTEK demek olurdu (turu 17'de kapatilan N+1 sinifi).
  ///	Bu yuzden:
  ///	  · **ORNEK** kayitta (`demo-`) ornek urun adlari cizilir — kayit
  ///	    zaten ekranda "Örnek" diye isaretli,
  ///	  · **GERCEK** kayitta sunucunun VERDIGI bilgi cizilir
  ///	    ("N ürün" · "en uygun X TL"),
  ///	  · ikisi de yoksa **ilce** (her kayitta dolu olan tek serbest alan).
  /// ⚠️ YAPMA: gercek kayda uydurma urun adi yazma.
  Widget _urunSeridi(BuildContext c, IsletmeOzet o) {
    final ornek = o.id.startsWith('demo-');
    final etiketler = <String>[
      if (ornek) ...(_ornekUrunler[o.kategori] ?? const <String>[]),
      if (!ornek) ...[
        if (o.urunSayisi > 0) '${o.urunSayisi} ürün',
        if (o.minFiyatKurus != null && o.minFiyatKurus! > 0)
          'en uygun ${(o.minFiyatKurus! / 100).round()} TL',
      ],
    ];
    if (etiketler.isEmpty && o.ilce.isNotEmpty) etiketler.add(o.ilce);
    if (etiketler.isEmpty) {
      etiketler.add(isletmeKategorileri[o.kategori] ?? 'İşletme');
    }
    final scheme = Theme.of(c).colorScheme;
    return SizedBox(
      // ⚠️ TURU 140 — TEK KAYNAK (`_seritBoy` de bunu okur).
      height: _altSatirBoy(c),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // ⚠️ TURU 144 — dolgu kolondan BURAYA tasindi (bkz. `_panelKarti`).
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: etiketler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        // ⚠️⚠️ TURU 144 — `Center` ZORUNLU: `_altSatirBoy` artik TUM
        //	dallarda ayni (yuksek) degeri donduruyor ve `ListView` cocuguna
        //	DIKEYDE TIGHT kisit verir — sarmalsiz cipler 56+ dp'ye GERILIR
        //	(turu 96/121d'de olculen ayni tuzak).
        itemBuilder: (_, i) => Center(
          child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(kYaricap(28)),
          ),
          // ⚠️⚠️⚠️ TURU 144 — **ICTEKI `Center` KALDIRILDI** (denetim
          //	olctu: cip 56 dp'ye GERILIYORDU). Distaki `Center` `ListView`in
          //	TIGHT kisitini LOOSE'a cevirir; ama `Center` loose-bounded
          //	kisitta **EN BUYUGU** alir, yani icteki `Center` yuksekligi
          //	yine 56'ya cikariyordu. Dikey olcu artik DOLGUDAN gelir.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              etiketler[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.82),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }

  /// Karttaki eylem dugmesi — **radüslü daire, YALNIZ IKON** (kullanici
  /// emri: *"sagda profil ve harita ikon, arka daire kategori mantigi
  /// daire radüslü"*).
  ///
  /// ⚠️ Dokunma hedefi 36 dp — Material 48'in altinda; kabul edilebilir
  ///    cunku HARITA eylemi kartin TAMAMINDAN da yapilabiliyor ve isletme
  ///    sayfasi baska yollardan da aciliyor.
  /// ⚠️ Zemin `kAiKartYuzey`: kategori dairesiyle AYNI kaynak; ayri renk
  ///    yazilsaydi ayni kartta iki farkli "daire dili" olurdu.
  Widget _kartDugmesi(
      BuildContext c, IconData ikon, String etiket, VoidCallback bas) {
    return SizedBox(
      height: 36,
      width: 36,
      child: Material(
        color: kAiKartYuzey(c),
        borderRadius: BorderRadius.circular(kYaricap(36)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: bas,
          child: Tooltip(
            message: etiket,
            child: Center(child: Icon(ikon, size: 17, color: kVurgu(c))),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 140 — **TELEFONLA ARAMA** (kullanici emri: *"isletme
  ///	kartlarinda haritanin soluna TELEFON IKONU koy"*).
  ///
  /// ⚠️⚠️ **NUMARA LISTEDE YOK — DOKUNUNCA CEKILIR.** `IsletmeOzet`te
  ///	`telefon` alani HIC YOK ve `/isletmeler/yakinimda` SELECT'i
  ///	`i.telefon` sutununu SECMIYOR (sunucu kaynagindan dogrulandi).
  ///	Numarayi kart basina onceden cekmek seritte **12 EK ISTEK** demekti
  ///	(turu 17'de kapatilan N+1). Bu yuzden numara YALNIZ dokunuldugunda
  ///	`GET /users/{id}/isletme` ile cozulur — o uc `telefon` donduruyor ve
  ///	HERHANGI bir kullanici kimligini kabul ediyor.
  /// ⏳ **BEKLEYEN (sunucu isi, ARAYUZ TURU oldugu icin YAPILMADI):**
  ///	`/yakinimda` yanitina `telefon` eklenirse bu ek istek kalkar
  ///	(SELECT + Scan + yanit haritasi UCU BIRLIKTE — `sutun_test.go`
  ///	hizayi olcuyor).
  ///
  /// ⚠️ ORNEK kayitta ARAMA YAPILMAZ: uydurma bir numarayi cevirmek
  ///    kullaniciyi yanlis birine baglardi.
  /// ⚠️ Servis await'ten ONCE yakalanir: kullanici geri basarsa `ref.read`
  ///    `StateError` firlatir ve `catch` onu sessizce yutar (turu 77b).
  /// ⚠️ Numara yoksa DURUSTCE soylenir — sessiz kalan bir dugme "bozuk"
  ///    gorunur.
  /// ⚠️ Yeniden-girme kapisi: yavas agda `detay` 1-2 sn surer ve dugme o
  ///    sure boyunca ETKIN kalir; cift dokunus IKI istek + IKI cevirici
  ///    acilisi uretirdi. Bayrak `finally`de temizlenir, yoksa tek hata
  ///    telefon dugmesini SUREKLI olu birakirdi.
  bool _araMesgul = false;

  Future<void> _ara(IsletmeOzet o) async {
    if (_araMesgul) return;
    if (o.id.startsWith('demo-')) {
      _mesaj('Bu bir örnek kayıt — arama yapılmaz.');
      return;
    }
    _araMesgul = true;
    final svc = ref.read(isletmeServisiProvider);
    try {
      final d = await svc.detay(o.id);
      if (!mounted) return;
      final t = (d?.telefon ?? '').trim();
      if (t.isEmpty) {
        _mesaj('${o.ad} telefon numarası eklememiş.');
        return;
      }
      // ⚠️ Bosluk/parantez/tire TEMIZLENIR: `tel:` semasi bunlari kabul
      //    edebilir ama bazi cevirici uygulamalar takiliyor.
      final sade = t.replaceAll(RegExp(r'[^0-9+]'), '');
      final adres = Uri.parse('tel:$sade');
      final oldu =
          await launchUrl(adres, mode: LaunchMode.externalApplication);
      if (!oldu && mounted) _mesaj('Arama uygulaması açılamadı.');
    } catch (_) {
      if (mounted) _mesaj('Numara alınamadı, tekrar deneyin.');
    } finally {
      _araMesgul = false;
    }
  }

  /// Kisa bilgi satiri (TEK KAYNAK).
  ///
  /// ⚠️⚠️ **KOK MESSENGER KULLANILIR** (denetim bulgusu): `ScaffoldMessenger
  ///	.of(context)` EKRANIN messenger'ini bulur ve SnackBar sayfanin
  ///	`Scaffold`inda, yani acik olan %70/%95 popupun **ARKASINDA** cizilir
  ///	— kullanici hicbir sey gormezdi. `rootMessengerKey` uygulamanin
  ///	kok messenger'idir ve sheet'lerin USTUNDE cizer (turu 90b'de
  ///	`olustur_menusu` icin ayni karar verilmisti).
  void _mesaj(String m) => rootMessengerKey.currentState
      ?.showSnackBar(SnackBar(content: Text(m)));

  /// Profili acar — ORNEK kayitta durustce soyler.
  ///
  /// ⚠️ TEK KAYNAK: serit karti, kart govdesi ve harita pin karti AYNI yolu
  ///    kullanir; ayri ayri yazilsaydi biri ornek kapisini unuturdu.
  void _isletmeAc(IsletmeOzet o) {
    if (o.id.startsWith('demo-')) {
      // ⚠️ Kok messenger: popup acikken ekranin messenger'i SnackBar'i
      //    popupun ARKASINDA cizerdi (bkz. `_mesaj` serhi).
      _mesaj('Bu bir örnek kayıt — gerçek işletme değil.');
      return;
    }
    // ⚠️⚠️⚠️ TURU 141 — **PROFIL ARTIK %95 POPUP** (kullanici emri:
    //	*"alttaki isletme kartina tikladiginda popup acilsin, isletmenin
    //	%95 PROFIL HESABI"*). Onceden tam sayfa `MaterialPageRoute` idi.
    //
    // ⚠️⚠️ **`sekmeModu: true` ZORUNLU**: sheet route'un ALTINDA sayfa
    //	oldugu icin `Navigator.canPop` true doner ve `AppBar`
    //	OTOMATIK GERI OKU cizer — popup "sayfa" gibi gorunurdu. Bayragin
    //	baska yan etkisi YOK: ikinci kullanimi `sekmeModu && _benimMi`
    //	ayar carki ve isletme profilinde `_benimMi` DAIMA false.
    // ⚠️⚠️ **`MediaQuery.removePadding(removeTop: true)` ZORUNLU**:
    //	`AppBar` `primary: true` oldugu icin `padding.top`u uygular ve
    //	sheet'in tepesi durum cubugunda OLMADIGI icin ~44-59 dp OLU
    //	BOSLUK birakirdi.
    //	⚠️ `removeBottom` EKLEME — profil govdesi alt dolguyu
    //	   `paddingOf(context).bottom`tan aliyor ve %95 sheet ekranin
    //	   DIBINE yapisik oldugu icin o deger DOGRU.
    // ⚠️⚠️ **`enableDrag: false`**: profil govdesindeki asagi-cek
    //	yenileme (`YenileSarmali`) ile sheet'in dikey surukleme jesti AYNI
    //	arenada yarisir; liste tepedeyken parmak asagi cekilince sheet
    //	KAPANIR ve yenileme HIC tetiklenmezdi.
    // ⚠️ `ScaffoldMessenger` sarmali: sheet icindeki `Scaffold` messenger
    //    YARATMAZ; profil govdesinin SnackBar'lari ("Bağlantı kopyalandı"
    //    · "Sohbet açılamadı") ekranin DIBINDE, popupun ARKASINDA cizilir
    //    ve GORUNMEZDI.
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: true,
      backgroundColor: kAiZemin,
      builder: (c) => FractionallySizedBox(
        heightFactor: 0.95,
        child: MediaQuery.removePadding(
          context: c,
          removeTop: true,
          child: ScaffoldMessenger(
            child: ProfilSayfasi(userId: o.id, sekmeModu: true),
          ),
        ),
      ),
    ));
  }

  /// Haritada o isletmeye odaklanir — **KAMERAYI TASIR** (kullanici emri:
  /// *"alttaki isletme kartina dokununca navigator ona gitsin"*).
  ///
  /// ⚠️⚠️ TURU 140 — **KART ARTIK ACILMAZ** (kullanici emri: *"alttaki
  ///	isletme kartlarina tikladiginda popup cikariyor, onlari kaldir,
  ///	gereksiz; filtrenin uzerinde popup cikiyor onu kaldir"*). Eskiden
  ///	burada `_secilen` de yaziliyordu; o alan ve `_secilenKart` metodu
  ///	komple SILINDI.
  /// ⚠️ Koordinati OLMAYAN kayitta kamera TASINMAZ (0,0 Gine Korfezi'dir —
  ///    turu 85b dersi). O durumda bu cagri SESSIZ kalir; kullaniciya yanlis
  ///    bir yere ucan bir harita gostermekten iyidir.
  void _haritadaGoster(IsletmeOzet o) {
    if (o.enlem == 0 && o.boylam == 0) return;
    // ⚠️⚠️ **NESIL SAYACI ZORUNLU** (turu 138'deki `_zoom` deseni): odak
    //	yalniz koordinattan olussaydi, kullanici haritayi elle kaydirip
    //	AYNI karta tekrar dokundugunda deger DEGISMEZ ve
    //	`didUpdateWidget` kamerayi TASIMAZDI — "bir kere calisti, sonra
    //	calismiyor" izlenimi.
    setState(() => _odak = (
          enlem: o.enlem,
          boylam: o.boylam,
          nesil: (_odak?.nesil ?? 0) + 1,
        ));
  }

  /// ⚠️⚠️⚠️ TURU 139 — **CIP SERIDI: SOLDA "KATEGORI" DUGMESI**
  ///	(kullanici emri: *"filtre yerine KATEGORI koy, tikladiginda popup
  ///	acilsin %95 kategoriler olsun · filtreleri yine getir alttaki ana
  ///	kartin ustune 10 px yukarda eskisi gibi"*).
  ///
  ///	· en solda **Kategori** dugmesi -> %95 kategori popupu
  ///	· suzgecler haritanin uzerindeki YUZEN SERITTE (`_filtreSatiri`)
  ///	· sonra kategoriler (`isletmeKategorileri` TEK KAYNAGINDAN)
  /// ⚠️ Turu 138'in "Filtre" dugmesi ve %50'lik paneli SILINDI — girisi
  ///    devredildigi icin ulasilamaz kalirdi.
  ///
  /// ⚠️⚠️ **KATEGORIYI BIRAKMA YOLU KAYBOLMADI:** secili cipe TEKRAR
  ///	dokunmak kategoriyi temizler (toggle). "Tümü" cipi kalktigi icin bu
  ///	TEK yol; kaldirilirsa kullanici bir kategoriye girdikten sonra
  ///	haritanin tamamina BIR DAHA DONEMEZ.
  /// ⚠️ Filtre dugmesinde aktif suzgec varsa **NOKTA** cizilir — kullanici
  ///    listenin neden kisaldigini gorebilmeli (turu 96d dersi).
  /// ⚠️⚠️ TURU 140 — **SAG KENARDA NEFES + AYRIK ARALIK** (kullanici emri:
  ///	*"kategoriler sol sag scrollda SAGDA DIVIN DISINA CIKIYOR onu duzelt,
  ///	yemek cafe vb kategorilerin ARASINI BIRAZ AC"*).
  ///
  ///	· Aralik cipin KENDI `Padding`inden CIKARILDI ve `separatorBuilder`a
  ///	  tasindi: 8 -> **`kCipAra` (14)**. Cipte kalsaydi son ogeye de
  ///	  uygulanip sagdaki nefesle CIFT SAYILIRDI.
  ///	· Serit `ListView.separated` oldu ve sag dolgu **`kSeritSagNefes`
  ///	  (28)**: cipler ekranin tam kenarinda YARIDAN kesilmiyor, panelin
  ///	  icinde bitiyor gibi duruyor.
  /// ⚠️ Sag nefes SOL dolgudan BUYUK olmak zorunda: sol kenar sabit
  ///    (kaydirilmaz), sag kenar ise kaydirdikca icerik oraya dayanir.
  /// ⚠️ `kYanBosluk` sabitine DOKUNULMADI — `isletme_kart.dart`tan import
  ///    ediliyor ve degistirilseydi Isletme listesi/kartlari da kayardi.
  /// ⚠️⚠️ TURU 143 — **ŞERİT PANELE GERİ KONDU**; turu 142'de cagri yeri
  ///	kaldirilmisti (o gun kullanicinin *"kategorileri kaldir"* sozu yanlis
  ///	okunmustu). ⚠️ Seridin BASINDAKI **"Kategori" dugmesi ARTIK YOK**:
  ///	kullanicinin gercekten kaldirilmasini istedigi sey OYDU. Kategori
  ///	sayfasinin girisi `_panelArama` dugmesinde DURUYOR.
  Widget _hizliCipler(BuildContext c) {
    final ogeler = <Widget>[
      // ⚠️⚠️⚠️ TURU 144 — **SERIDIN BASINDA "Yakınımda"** (kullanici emri:
      //	*"kategorilerin basina Yakinimda olacak; hicbir sey aktif
      //	olmadiginda hep yakindakiler gorunecek"*).
      //	Bos anahtar = kategori suzgeci YOK; sunucu tum kategorileri
      //	mesafeye gore dondurur. Kategoriyi BIRAKMANIN da en acik yolu
      //	budur (eskiden yalniz "secili cipe tekrar dokun" vardi).
      _cip(
        c,
        'Yakınımda',
        _dal.isEmpty,
        () => _dalCipi(''),
        // ⚠️ TURU 145 — kullanici emri: *"yakinimdaki ikon NAVIGATOR ikonu
        //    olsun"*. Ust bardaki "konumuma dön" dugmesiyle AYNI dil.
        ikon: LucideIcons.navigation,
      ),
      for (final g in _haritaKategorileri)
        _cip(
          c,
          isletmeKategorileri[g]!,
          _dal == g,
          // ⚠️ TOGGLE: secili cipe tekrar dokunmak kategoriyi BIRAKIR.
          () => _dalCipi(g),
          ikon: _kategoriIkonu(g),
        ),
    ];
    return SizedBox(
      height: 40,
      child: ShaderMask(
        // ⚠️ `dstIn`: gradyanin ALFASI cocuga uygulanir, rengi DEGIL.
        blendMode: BlendMode.dstIn,
        shaderCallback: (kutu) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          // ⚠️ Solma yalnizca SON %8'de: daha genisi okunabilir cipleri de
          //    silikleştirirdi.
          stops: [0.0, 0.92, 1.0],
          colors: [Colors.white, Colors.white, Colors.transparent],
        ).createShader(kutu),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(
            left: kYanBosluk,
            right: kSeritSagNefes,
          ),
          itemCount: ogeler.length,
          separatorBuilder: (_, _) => const SizedBox(width: kCipAra),
          itemBuilder: (_, i) => ogeler[i],
        ),
      ),
    );
  }

  /// Haritada cip/kart olarak cizilecek kategoriler.
  ///
  /// ⚠️ TEK KAYNAK: hem cip seridi hem %95 kategori popupu bunu okur —
  ///    iki liste yazilsaydi biri guncellenip oteki geride kalirdi.
  ///
  /// ⚠️ `isletmeKategorileri`nin SIRASI korunur (sunucudaki `Kategoriler`
  ///    haritasinin ikizi); yalnizca `diger` elenir — "Diğer" diye bir
  ///    kategoriye dokunmak kullaniciya hicbir sey anlatmaz.
  static final List<String> _haritaKategorileri =
      isletmeKategorileri.keys.where((k) => k != 'diger').toList();

  /// ⚠️⚠️⚠️ TURU 139 — Serit basindaki dugme artik **"Kategori"** (kullanici
  ///	emri: *"filtre yerine KATEGORI koy, tikladiginda popup acilsin %95
  ///	kategoriler olsun"*).
  ///
  /// ⚠️ Suzgecler BURADAN CIKTI ve haritanin uzerindeki YUZEN SERIDE geri
  ///    dondu (bkz. `_filtreSatiri` / `_yuzenCipler`) — yine kullanici emri.
  ///    Turu 138'in %50'lik filtre paneli bu yuzden SILINDI: ulasilamayan
  ///    bir panel birakmak OLU KOD olurdu.
  /// ⚠️ Kategori ciplerinden AYRI cizilir: o bir SECIM, bu bir EYLEM.
  ///    Ayni gorunumde olsaydi kullanici "Kategori" diye bir kategori sanardi.
  /// ⚠️ TURU 143 — cagri yeri KALKTI (kullanici *"Kategori kelimesini
  ///    kaldir"* dedi). Govde SILINMEDI: bu projede uye silmek DORT kez
  ///    komsu uyeyi de goturdu (turu 127/138/140/141).
  // ignore: unused_element
  Widget _kategoriDugmesi(BuildContext c) {
    final vurgu = kVurgu(c);
    final notr = Theme.of(c).colorScheme.onSurface;
    final secili = _dal.isNotEmpty;
    // ⚠️ TURU 140 — kendi sag `Padding`i KALKTI; aralik artik seridin
    //    `separatorBuilder`inda TEK KAYNAK.
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _kategoriPopupAc,
        child: Center(
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kAiKartYuzey(c),
              borderRadius: BorderRadius.circular(kYaricap(34)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.layoutGrid,
                    size: 15, color: secili ? vurgu : notr),
                const SizedBox(width: 6),
                Text(
                  'Kategori',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: secili ? vurgu : notr,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 139/140 — **KATEGORI POPUPU: EKRANIN %95'I** (kullanici emri).
  ///
  ///	Icerik: kategori KARTLARI. ⚠️⚠️ TURU 140'ta **ANASAYFA MENUSUYLE
  ///	BIREBIR** hizalandi (kullanici emri: *"haritada kategorilere
  ///	tikladigimda YUKSEKLIKLERI ANASAYFADAKI KATEGORILERIN YUKSEKLIKLERI
  ///	ILE AYNI DEGIL ve IKONLARI KALDIR, oradaki gibi yap"*):
  ///	  · kutu **`kKesifKutu` (78 dp)** — onceden 64 idi
  ///	  · kutu ile yazi arasi **5** — onceden 6
  ///	  · etiket alani **`scale(14) * 1.15 * 2`** — onceden `scale(12)*1.2*2`
  ///	  · kutunun ICI **BOS** — ikon KALDIRILDI
  /// ⚠️ Olculer `hizmet_menusu.dart`taki `_kart` ile AYNI SABITLERDEN
  ///    (`kKesifKutu`, `kAiKartYuzey`, `kYaricap`) turetilir; kopyalanmaz.
  ///
  /// ⚠️⚠️ TURU 140 — **ARAMA ALANI** (kullanici emri: *"kategoriye
  ///	tikladiginda orada ARAMA ALANI olacak"*). Kategori adinda gecen
  ///	metne gore suzer; sonuc yoksa DURUSTCE soyler.
  /// ⚠️ Suzgec `StatefulBuilder` ile YEREL tutulur: ekranin `State`ine
  ///    yazilsaydi popup kapandiktan sonra da yasardi ve bir dahaki
  ///    acilista kullanici BOS bir izgara gorurdu.
  /// ⚠️ Denetleyici `_KategoriPopup` icinde yasar ve orada `dispose` edilir
  ///    — `showModalBottomSheet` future'i **pop ANINDA** cozulur, route'un
  ///    CIKIS ANIMASYONU surerken alt agac hala ciziliyordur ve disaridan
  ///    dispose edilen bir denetleyici *"used after being disposed"* ile
  ///    EKRANIN TAMAMINI kirmizi boyar (turu 96i, sahada yasandi).
  ///
  /// ⚠️ `isScrollControlled` + `FractionallySizedBox(heightFactor: 0.95)`:
  ///    `showModalBottomSheet` varsayilan tavani ekranin **9/16**'sidir ve
  ///    izgara KIRPILIRDI (turu 90b/115c'de iki ayri sheet'te yasandi).
  /// ⚠️ `SafeArea(top: false)`: alt jest cubugu kartlari kesmesin
  ///    (`useSafeArea` bunu COZMEZ — SDK'da o bayrak `bottom: false`
  ///    uretir; turu 121d'de olculdu).
  /// ⚠️⚠️ Secim `pop(anahtar)` ile DONER, panel icinde `setState` YAPILMAZ:
  ///	sheet'in kendi agaci ekranin `State`i degildir ve `_kategoriSec`
  ///	sunucu istegi de tetikler — sheet kapanmadan liste degisirse
  ///	kullanici arkada ne oldugunu goremez.
  Future<void> _kategoriPopupAc() async {
    final secim = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: kAiZemin,
      builder: (c) => FractionallySizedBox(
        heightFactor: 0.95,
        child: Theme(
          data: _koyuTema(),
          // ⚠️⚠️ `Material` sarmali ZORUNLU: `Theme` tek basina renk
          //	BELIRTMEYEN `Text`leri beyaza cevirmez — sarmalsiz haliyle
          //	siyah sayfada kategori adlari SILIK GRI cikiyordu (turu 129).
          child: Material(
            type: MaterialType.transparency,
            // ⚠️⚠️ `Builder` ZORUNLU: `_popupKarti` EKRANIN metodu ve
            //	kendisine verilen context'i kullaniyor; `Theme`in ALTINDAN
            //	gelmezse kartlar UYGULAMANIN temasini cozer (turu 136/138).
            child: Builder(
              builder: (tc) => SafeArea(
                top: false,
                // ⚠️ Klavye acilinca alt kismi kirpilmasin.
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(c).bottom),
                  child: _AramaSayfasi(
                    baslangic: _q,
                    gecmis: _gecmis,
                    kartYapici: (_, anahtar, ad) => _popupKarti(
                      tc,
                      anahtar,
                      ad,
                      sec: () => Navigator.of(c).pop(('dal', anahtar)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || secim == null) return;
    // ⚠️ Iki sonuc tipi: kategori KARTI ('dal') ya da serbest METIN.
    if (secim.$1 == 'dal') {
      _dalSec(secim.$2);
      unawaited(_listePopupAc());
    } else {
      _metinAra(secim.$2);
      unawaited(_listePopupAc());
    }
  }

  /// Popuptaki tek kategori karti — **ANASAYFA MENUSUYLE AYNI DIL**.
  ///
  /// ⚠️⚠️ **KUTUNUN ICI BOS** (kullanici emri: *"ikonlari kaldir"*).
  ///    Anasayfadaki `_kart` da boyle: duz `kAiKartYuzey` yuzey + altinda
  ///    ad. ⚠️ YAPMA: buraya ikon/harf/gradyan geri koyma — kullanici
  ///    kategori ekraninda kutu icine konan HER SEYI uc kez kaldirtti
  ///    (`hizmet_menusu.dart` serhinde yazili).
  /// ⚠️ Secili kategori KENARLIKLA isaretlenir; ikon olmadigi icin baska
  ///    bir sinyal kalmadi ve kenarlik ZORUNLU.
  Widget _popupKarti(BuildContext c, String anahtar, String ad,
      {VoidCallback? sec}) {
    final secili = _dal == anahtar;
    final vurgu = kVurgu(c);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: sec,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚠️⚠️ TURU 143 — kutu artik **KARE** (kullanici emri: *"acilan
          //	sayfada kategori kartlarinin GENISLIGINI AZALT"*). Onceden
          //	yalniz YUKSEKLIK veriliyordu ve kutu izgara hucresinin TAM
          //	genisligine (~78 dp) yayiliyordu; artik `kAramaKutu` (62)
          //	kadar genis ve ORTALI.
          // ⚠️ Etiket kutunun DISINDA ve hucrenin tam genisligini kullanir —
          //    "Otel & Konaklama" gibi uzun adlar kirpilmasin.
          Center(
            child: SizedBox(
              width: kAramaKutu,
              height: kAramaKutu,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kAiKartYuzey(c),
                  borderRadius: BorderRadius.circular(kYaricap(kAramaKutu)),
                  border: secili ? Border.all(color: vurgu, width: 1.6) : null,
                ),
              ),
            ),
          ),
          // ⚠️ 5 dp — anasayfadaki `_kart` ile AYNI.
          const SizedBox(height: 5),
          SizedBox(
            // ⚠️ Etiket alani SABIT IKI SATIR (anasayfayla ayni formul):
            //    icerige gore degisseydi "Otel & Konaklama" gibi iki satira
            //    saran adlar o hucreyi uzatir ve izgaranin alt siniri
            //    DALGALANIRDI (turu 96k'da olculdu).
            height: MediaQuery.textScalerOf(c).scale(13) * 1.15 * 2,
            child: Center(
              child: Text(
                ad,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: secili ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 139 — **YUZEN SUZGEC SERIDI GERI GELDI** (kullanici emri:
  ///	*"filtreleri yine getir, alttaki ana kartin ustune 10 px yukarda
  ///	ESKISI GIBI"*). Turu 138'de kaldirilmisti.
  ///
  /// ⚠️⚠️ **DURUST SINIR:** kullanici turu 132'de *"akaryakita fiyat
  ///	araliklari"* demisti; akaryakit FIYATI bu projede HICBIR YERDE YOK
  ///	(ne tablo, ne uc, ne isletme alani). Uydurma bir aralik cizmek
  ///	YANLIS BILGI olurdu. Yerine sunucunun GERCEKTEN dondurdugu olcutler:
  ///	mesafe · puan · kampanya · onayli.
  /// ⚠️ Yemek/kafe/market disinda "Kampanyalı" cogu zaman bos donecegi icin
  ///    CIZILMEZ — hicbir sey suzmeyen bir dugme "bozuk" hissi verir.
  // ignore: unused_element
  Widget _filtreSatiri() {
    final ticari = _dal.isEmpty ||
        const {'yemek', 'kafe', 'market'}.contains(_dal);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
        children: [
          _yuzenCip('2 km içinde', _fKm == 2, LucideIcons.footprints, () {
            setState(() => _fKm = _fKm == 2 ? 0 : 2);
          }),
          _yuzenCip('5 km içinde', _fKm == 5, LucideIcons.bike, () {
            setState(() => _fKm = _fKm == 5 ? 0 : 5);
          }),
          _yuzenCip('4+ puan', _fPuan, LucideIcons.star,
              () => setState(() => _fPuan = !_fPuan)),
          if (ticari)
            _yuzenCip('Kampanyalı', _fKampanya, LucideIcons.tag,
                () => setState(() => _fKampanya = !_fKampanya)),
          _yuzenCip('Onaylı', _fOnayli, LucideIcons.badgeCheck,
              () => setState(() => _fOnayli = !_fOnayli)),
          if (_suzgecVar)
            _yuzenCip('Temizle', false, LucideIcons.x, () {
              setState(() {
                _fPuan = false;
                _fKampanya = false;
                _fOnayli = false;
                _fKm = 0;
              });
            }),
        ],
      ),
    );
  }

  /// Yuzen seritteki tek cip.
  ///
  /// ⚠️⚠️ **PANELDEKI `_cip` KULLANILAMAZ**: o cipin ZEMINI YOK (yalniz ikon
  ///	dairesi + yazi) cunku SIYAH panelin uzerinde duruyor. Buradaki serit
  ///	HARITANIN uzerinde yuzuyor ve harita her renkte olabilir — zeminsiz
  ///	bir yazi okunmazdi. Bu yuzden cipin KENDI koyu hapi var.
  /// ⚠️ Zemin, ust bardaki dugmelerle AYNI sabittir (`kHaritaDugmeAlfa`):
  ///    ayni ekranda iki farkli "harita ustu yuzey" olmasin.
  /// ⚠️ Secili hal VURGU rengiyle dolar — koyu hapta kalinlik tek basina
  ///    yeterince belli olmuyordu (turu 138'de olculdu).
  // ignore: unused_element
  Widget _yuzenCip(
      String etiket, bool secili, IconData ikon, VoidCallback bas) {
    final vurgu = kVurgu(context);
    // ⚠️⚠️⚠️ **ON PLAN DOLGUDAN TURETILIR — SABIT BEYAZ YAZMA.**
    //	`kVurgu` KOYU temada `Colors.white` dondurur. Secili cipin zemini
    //	`vurgu` ile doldugunda yazi/ikon sabit beyaz kalsaydi **beyaz
    //	uzerine beyaz (1,00:1)** cizilir ve cip TAMAMEN OKUNMAZ olurdu
    //	(turu 139'dan kalma, uygulama koyu temadayken).
    // ⚠️⚠️ TURU 141 — zemin **%62 -> %82** (kullanici emri: *"filtrelerdeki
    //	arka plan hala saydam, biraz daha kapat"*). Ust bardaki dugmelerden
    //	AYRISTI: o dugmeler haritanin uzerinde TEK BASINA durur, bu serit ise
    //	metin tasiyor ve harita her renkte olabilir.
    final dolgu =
        secili ? vurgu : Colors.black.withValues(alpha: kYuzenCipAlfa);
    final ustRenk =
        ThemeData.estimateBrightnessForColor(dolgu) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Material(
          color: dolgu,
          borderRadius: BorderRadius.circular(kYaricap(34)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: bas,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 34,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ⚠️⚠️ TURU 141 — **CHECKBOX** (kullanici emri: *"check
                    //	box kutularini koymamissin onlari da koy"*).
                    //	Filtre ekranindakiyle (`isletme_filtre.dart`) AYNI
                    //	dil: 16 dp kare, 5 dp radus, secilince dolar + tik.
                    // ⚠️ `kYaricap` KULLANILMAZ — clamp tabani 8 ve bu
                    //    boyutta kutuyu DAIREYE cevirip radio gibi gosterir
                    //    (turu 140'ta olculdu).
                    Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: secili ? ustRenk : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: ustRenk.withValues(alpha: secili ? 1 : 0.55),
                          width: 1.4,
                        ),
                      ),
                      child: secili
                          // ⚠️ TURU 145 — tik **1 TIK KALIN** (kullanici
                          //    emri). Lucide bir FONT'tur, `strokeWidth`
                          //    YOKTUR; kalinlik ayni renkte dort golgeyle
                          //    simule edilir (`KalinIkon`, turu 93).
                          ? KalinIkon(
                              ikon: LucideIcons.check, boy: 11, renk: dolgu)
                          : null,
                    ),
                    const SizedBox(width: 7),
                    Icon(ikon, size: 15, color: ustRenk),
                    const SizedBox(width: 6),
                    Text(
                      etiket,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ustRenk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ **`Widget?` DONER; ESKIDEN `SizedBox.shrink()` IDI VE KATEGORISIZ
  ///	ACILISTA EKRANIN TAMAMINI BEYAZ BIRAKIYORDU** (turu 136'da olculdu).
  ///
  ///	Yigindaki (`build` -> `Stack`) diger cocuklarin HEPSI `Positioned`.
  ///	`RenderStack` boyutunu YALNIZCA positioned OLMAYAN cocuklarindan
  ///	hesaplar; buradan donen 0x0 cocuk TEK non-positioned cocuk oluyor ve
  ///	yigin **0x0**'a dusuyordu — harita, dugmeler, panel HICBIRI
  ///	cizilmiyordu.
  /// ⚠️ YAPMA: bu metodu tekrar `SizedBox.shrink()` dondurur hale getirme;
  ///    cagri yerindeki `if (... != null)` kapisini da kaldirma.
  // ignore: unused_element
  Widget? _yuzenCipler() {
    if (_dal.isEmpty) return null;
    return Positioned(
      left: 0,
      right: 0,
      // ⚠️ Kullanici emri: **panelin 10 px ustunde**.
      bottom: _panelBoy(context) + 10,
      child: _filtreSatiri(),
    );
  }

  /// ⚠️ Dal degisince suzgecler KALIR ama liste SUNUCUDAN yeniden cekilir
  ///    (kategori sunucu tarafinda suzuluyor).
  /// ⚠️⚠️ Arama metni (`_q`) SIFIRLANIR: "Kafe" icin yazilmis bir arama
  ///	"Otel"e gecince listeyi SEBEPSIZ bosaltirdi ve kullanici kutuyu
  ///	gormeden once neden bos oldugunu anlayamazdi (turu 93b'de kategori
  ///	+ metin birlesiminde birebir bu yasandi).
  /// ⚠️ Ayni dal ikinci kez secilirse SESSIZCE doner — cagiranlar bunu
  ///    bilerek kullanir (`_dalCipi` toggle yapar, kisayol karti popupu
  ///    acar).
  /// Serbest metinle arama — **KATEGORI SUZGECINI BIRAKIR**.
  ///
  /// ⚠️⚠️⚠️ TURU 144 — kullanici emri: *"bir sey aradigimda aramanin altta
  ///	ornegin MARKET AKTIF KALIYOR, bu da olmasin"*. Kullanici metinle
  ///	arama yaptiginda kategori suzgeci ACIK kalirsa sonuc kumesi
  ///	SESSIZCE daralir: "kuafor" yazan ama Market cipi acik kalan kullanici
  ///	BOS liste gorur ve sebebini anlamaz.
  /// ⚠️ `_dalSec('')` KULLANILAMAZ: o metot `_q`yu SIFIRLIYOR (kategori
  ///    secmek aramayi birakmali) — burada TAM TERSI gerekiyor.
  void _metinAra(String q) {
    final dalDegisti = _dal.isNotEmpty;
    setState(() {
      _q = q;
      _dal = '';
      _kategori = '';
    });
    // ⚠️ Kategori BIRAKILDIYSA sunucudan tum kategoriler yeniden istenir;
    //    yoksa gereksiz bir istek atmayiz (suzgec ZATEN istemcide).
    if (dalDegisti) _yukle();
  }

  void _dalSec(String dal) {
    if (_dal == dal) return;
    setState(() {
      _dal = dal;
      _kategori = _dalKategori(dal);
      _q = '';
      // ⚠️ Gecmis: en yeni ONCE, tekrarsiz, en fazla 8 kayit.
      if (dal.isNotEmpty) {
        _gecmis.remove(dal);
        _gecmis.insert(0, dal);
        if (_gecmis.length > 8) _gecmis.removeLast();
      }
    });
    _yukle();
  }

  static IconData _kategoriIkonu(String k) => switch (k) {
        'yemek' => LucideIcons.utensils,
        'kafe' => LucideIcons.coffee,
        // ⚠️ TURU 145 — kullanici emri: *"market ve bakkal SHOPPING-BAG
        //    bu ikonu yap"*. (Turu 144'te `store` yapilmisti; `store`
        //    zaten `_` yedegi oldugu icin ayrim da netlesti.)
        'market' => LucideIcons.shoppingBag,
        'eczane' => LucideIcons.pill,
        'oto' => LucideIcons.car,
        'saglik' => LucideIcons.stethoscope,
        'kuafor' => LucideIcons.scissors,
        'guzellik' => LucideIcons.sparkles,
        'otel' => LucideIcons.bedDouble,
        'egitim' => LucideIcons.graduationCap,
        // ⚠️ TURU 139 — YEDI KATEGORI notr store ikonuna dusuyordu ve
        //    kartlarin sol dairesi ARTIK BU IKONA dayaniyor (kapak gorseli
        //    kalkti): ayni ekranda yedi ayni daire, kategoriyi ayirt
        //    edilemez yapiyordu (popupta OLCULDU).
        'giyim' => LucideIcons.shirt,
        'diyetisyen' => LucideIcons.salad,
        'emlak' => LucideIcons.house,
        'spor' => LucideIcons.dumbbell,
        'teknoloji' => LucideIcons.smartphone,
        'eglence' => LucideIcons.gamepad2,
        'hizmet' => LucideIcons.wrench,
        _ => LucideIcons.store,
      };


  /// ⚠️⚠️⚠️ TURU 139 — **HARITA USTU DUGMELERI TEK KAYNAKTAN** (kullanici
  ///	emri: *"geri navigator + - bunlarin raduslerini KATEGORI RADUS
  ///	MANTIGINI yap, bunlari %15 BUYUT, bu ikonlari 1 TIK KALINLASTIR"* +
  ///	*"bu siyahi biraz daha KAPA, transparanini biraz daha kapa, arkasi
  ///	cok gorunuyor"*).
  ///
  ///	· sekil: `CircleBorder` **DEGIL** `kYaricap` (kategori kartlariyla
  ///	  ayni yuvarlatilmis kare dili — referans Yandex Navigator'da da
  ///	  dugmeler squircle)
  ///	· olcu: 48 -> **55** (%15), zoom 44 -> **51** (%15)
  ///	· ikon: `KalinIkon` (ayni renkte ±0.4 px dort golge; Lucide bir FONT
  ///	  oldugu icin `strokeWidth` YOKTUR — turu 93 teknigi)
  ///	· zemin: siyah **%45 -> %62** (kullanici: "arkasi cok gorunuyor")
  ///
  /// ⚠️ Dort dugme de BU yardimciyi kullanir; ayri ayri yazilsaydi biri
  ///    degisince oteki geride kalirdi (bu ekranda ayni sinif iki kez oldu).
  Widget _haritaDugmesi(
    IconData ikon,
    String ipucu,
    VoidCallback bas, {
    double olcu = kHaritaDugmeOlcu,
    double aci = 0,
  }) =>
      Material(
        color: Colors.black.withValues(alpha: kHaritaDugmeAlfa),
        borderRadius: BorderRadius.circular(kYaricap(olcu)),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: bas,
          child: SizedBox(
            width: olcu,
            height: olcu,
            child: Tooltip(
              message: ipucu,
              child: Center(
                child: aci == 0
                    ? KalinIkon(ikon: ikon, boy: 21, renk: Colors.white)
                    : Transform.rotate(
                        angle: aci,
                        child: KalinIkon(
                            ikon: ikon, boy: 21, renk: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      );

  Widget _ustDugmeler() {
    final ust = MediaQuery.paddingOf(context).top + 8;
    return Positioned(
      top: ust,
      left: kYanBosluk,
      right: kYanBosluk,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _haritaDugmesi(
              LucideIcons.arrowLeft, 'Geri', () => Navigator.of(context).pop()),
          _haritaDugmesi(
            // ⚠️⚠️ TURU 141 — **DOLU NAVIGATOR** (kullanici emri: *"en sag
            //	ustte navigator icin DOLDUR bunlari"*).
            //	Lucide bir CIZGI ikon setidir ve dolu varyanti YOKTUR;
            //	turu 98'de "dolu kalp" icin de ayni yola gidildi. Bu, ikon
            //	dilinden BILINCLI ve TEK bir sapma — geri · + · − Lucide kalir.
            // ⚠️ TURU 132'de `locateFixed` -> `navigation` yapilmisti;
            //    ikon AYNI, yalnizca dolu varyantina gecildi.
            Icons.navigation,
            'Konumuma dön',
            // ⚠️ TURU 142 — kullanici emri: *"navigasyon ikonu sag 45 derece
            //    olsun"*. Ikonun kendisi degil CIZIMI dondurulur.
            aci: math.pi / 4,
            // ⚠️⚠️⚠️ TURU 149 — dugme artik **KAMERAYI DA TASIYOR.**
            //	· `_merkezNesli` artar -> `didUpdateWidget` kamerayi
            //	  koordinat AYNI OLSA BILE konuma ortalar (bkz. alan serhi),
            //	· konum tazeleme YAN IS olarak kosar; kullanici agin
            //	  donmesini BEKLEMEZ — kamera ANINDA gider.
            // ⚠️ `_yukleniyor ? () {} : ...` KAPISI KALDIRILDI: dugme tam da
            //    kullanicinin sabirsizlandigi anda OLU oluyordu.
            () {
              setState(() => _merkezNesli++);
              if (!_yukleniyor) unawaited(_yukle(konumuTazele: true));
            },
          ),
        ],
      ),
    );
  }

  /// ⚠️⚠️ TURU 138/139 — **HARITA YAKINLASTIRMA DUGMELERI** (kullanici emri:
  ///	*"yukarida navigatorun altina + ve - butonlar koy harita icin"*).
  ///
  /// ⚠️ Google'in kendi zoom dugmeleri (`zoomControlsEnabled`) KULLANILMADI:
  ///    onlar SAG ALTTA cizilir ve orasi alt panelin altinda kalir.
  /// ⚠️ Kamerayi `_HaritaAlani` tasir — controller orada. Ekran yalnizca
  ///    "yakinlas/uzaklas" ISTEGINI iletir (`_zoom` sayaci).
  Widget _zoomDugmeleri() {
    // ⚠️ Ust bar: guvenli alan + 8 + dugme boyu -> altinda 10 nefes.
    final ust = MediaQuery.paddingOf(context).top + 8 + kHaritaDugmeOlcu + 10;
    return Positioned(
      top: ust,
      right: kYanBosluk,
      child: Column(
        children: [
          _haritaDugmesi(LucideIcons.plus, 'Yakınlaştır',
              () => setState(() => _zoom++),
              olcu: kHaritaZoomOlcu),
          const SizedBox(height: 8),
          _haritaDugmesi(LucideIcons.minus, 'Uzaklaştır',
              () => setState(() => _zoom--),
              olcu: kHaritaZoomOlcu),
        ],
      ),
    );
  }

  /// ⚠️ TURU 145 — [secili] artik **CIZIME ETKI ETMIYOR** (kullanici
  ///    *"aktifligi kaldir"* dedi). Parametre KALDIRILMADI: uc cagri yeri
  ///    var ve bu projede imza degistirmek komsu uyeleri goturen silme
  ///    islemleriyle ayni riski tasiyor. Aktiflik geri istenirse tek yer.
  // ignore: avoid_unused_constructor_parameters
  Widget _cip(
    BuildContext c,
    String etiket,
    // ignore: avoid_unused_parameters
    bool secili,
    VoidCallback onTap, {
    IconData? ikon,
  }) {
    final notr = Theme.of(c).colorScheme.onSurface;
    // ⚠️⚠️⚠️ TURU 145 — **AKTIFLIK GORUNUMU KALDIRILDI** (kullanici emri:
    //	*"yemek cafe onlarin ikon arka plani ISLETME KARTI ARKA PLAN
    //	RENGINDE olsun, tikladigimda BEYAZ OLMASIN, AKTIFLIGI KALDIR"*).
    //	Turu 140'ta secili cipin ikon kutusu BEYAZA donuyordu.
    // ⚠️⚠️ Kutu zemini artik **`kYuzeyGri`** — panel seridindeki ISLETME
    //	KARTIYLA AYNI kaynak (`_panelKarti` -> `Material(color: kYuzeyGri)`).
    //	Sabit renk YAZILMADI ki kart zemini degisince cip de dossun.
    // ⚠️ Secili kategori HALA GORUNUR: arama dugmesi kategorinin ADINI
    //    yaziyor ve secili degilken "Yakınımda" cipi one cikiyor. Yani
    //    aktiflik bilgisi KAYBOLMADI, yalnizca cipten cikti.
    final kutuZemin = kYuzeyGri(c);
    final ikonRenk = notr;
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ikon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // ⚠️ TEK KAYNAK: menudeki kategori kartiyla AYNI yuzey.
                      color: kutuZemin,
                      borderRadius: BorderRadius.circular(kYaricap(32)),
                    ),
                    child: Icon(ikon, size: 16, color: ikonRenk),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  etiket,
                  style: TextStyle(
                    // ⚠️ 13 -> 14 (kullanici emri: "yazilari 1px buyut").
                    fontSize: 14,
                    // ⚠️⚠️ TURU 140 — **KALINLIK ARTIK SABIT (w700).**
                    //	Onceden secili w800 / pasif w600 idi; kalinlik
                    //	degisimi metnin GENISLIGINI degistirir ve serit
                    //	her secimde KAYAR (turu 121d'de ayni sinif
                    //	olculmustu).
                    // ⚠️ TURU 145 — secili/pasif AYRIMI YOK (kullanici
                    //    emri: *"aktifligi kaldir"*).
                    fontWeight: FontWeight.w700,
                    color: notr,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ⚠️⚠️ TURU 138 -> 139 — yuzen suzgec seridi turu 138'de KALDIRILMIS,
  //	turu 139'da kullanici emriyle **GERI GETIRILMISTI** (bkz.
  //	`_filtreSatiri` / `_yuzenCipler`).
  //	Turu 138'in %50'lik filtre paneli (`_filtrePaneliAc`) ise SILINDI:
  //	girisi "Kategori" dugmesine devredildigi icin ULASILAMAZ kalirdi ve
  //	bu projede olu arayuz birakmak yasak.
}

/// ⚠️⚠️ HARITA ALANI — su an **YER TUTUCU** (bkz. dosya basindaki serh).
///
/// Gercek konumu ve isletmeleri DOGRU GORECELI KONUMDA cizer: merkez
/// kullanici, cevresinde isletme igneleri. Karo (tile) katmani yoktur.
///
/// ⚠️ Gercek haritaya gecerken SADECE bu sinifin `build`i degisir; ekranin
///    geri kalani ve cagri yeri AYNEN kalir.
/// ⚠️⚠️⚠️ TURU 85c — **`StatelessWidget` DEGIL `StatefulWidget`** (denetim).
///
///	`GoogleMap`in `initialCameraPosition`i adindan da anlasilacagi gibi
///	YALNIZCA ILK KURULUMDA uygulanir; sonraki `build`lerde YOK SAYILIR.
///	Ustelik `scrollGesturesEnabled: false` (harita bir listenin icinde
///	oldugu icin ZORUNLU) ve `myLocationButtonEnabled: false` -> kullanicinin
///	kamerayi elle tasima yolu da YOK.
///	SONUC: asagi-cek GPS'i tazeleyip listeyi guncelliyor ama **harita ilk
///	konuma CIVILI kaliyordu**; kullanici baska bir semte gidip yenilediginde
///	kartlar yeni sehri, harita ESKI sehri gosteriyordu ve duzeltmenin
///	HICBIR YOLU yoktu (uygulamayi oldurmek disinda).
///	FIX: `onMapCreated` ile controller saklanir, `merkez` degistiginde
///	`animateCamera` ile takip edilir.
/// ⚠️ YAPMA: `onMapCreated`i kaldirma ya da bu sinifi tekrar `Stateless`
///    yapma; `initialCameraPosition` TEK BASINA yeterli DEGILDIR.
/// Merkez pininin ucundaki kucuk nokta.
///
/// ⚠️ Ayri widget: `const` olabilmesi icin. Ic ice `Container` ile
///    yazilsaydi her karede yeniden kurulurdu.
class _MerkezNoktasi extends StatelessWidget {
  const _MerkezNoktasi();

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFF5E5E),
        ),
      );
}

class _HaritaAlani extends StatefulWidget {
  const _HaritaAlani({
    required this.stil,
    required this.merkez,
    required this.isletmeler,
    required this.yukleniyor,
    required this.altDolgu,
    this.odak,
    this.kategori = '',
    this.zoom = 0,
    this.avatarAdres,
    this.avatarAnahtar = '',
    this.guzergah,
    this.duraklar = const [],
    this.durakSec,
    this.merkezNesli = 0,
    this.rota,
    this.sigdir,
    this.noktaSec,
    this.takipBacak,
    this.takipEnlem,
    this.takipBoylam,
    this.eldeKaydirdi,
    this.merkezPin = false,
    this.kameraDurdu,
    this.yon,
    this.dogrulukM,
  });

  /// ⚠️⚠️⚠️ TURU 155 — konum isaretinin YONU (derece, 0 = kuzey).
  ///
  ///	Kullanici emri: *"Konum yandextedki gibi daire yon oku olsun,
  ///	telefonu oynattikca yonu gostersin"*.
  /// ⚠️ `null` ise yon konisi CIZILMEZ — yanlis yon gostermek hic
  ///    gostermemekten KOTUDUR.
  final double? yon;

  /// ⚠️⚠️⚠️ Konum dogrulugu (metre) — cevredeki hafif beyaz halka.
  ///
  ///	Kullanici emri: *"cevresinde hafif beyaz daire var bunun gibi
  ///	olsun"*. Bu SUS DEGIL: halka buyudukce kullanici konumun
  ///	belirsiz oldugunu anlar (Google/Yandex/Apple ayni dili kullanir).
  final double? dogrulukM;

  /// ⚠️⚠️ TURU 154 — ekranin ORTASINDA sabit bir secim pini cizilir.
  ///	`Marker` DEGIL bir `Stack` katmani: marker haritayla
  ///	BIRLIKTE kayar, oysa secici pinin EKRANDA SABIT kalmasi
  ///	gerekiyor (kullanici haritayi pinin ALTINDAN kaydiriyor).
  final bool merkezPin;

  /// Kamera DURDUGUNDA merkezi bildirir (adres cozumu icin).
  final void Function(double enlem, double boylam)? kameraDurdu;

  /// ⚠️⚠️⚠️ TURU 151 — **TAKIP EDILEN BACAK** (yoksa null).
  ///
  /// Dolu oldugunda cizim degisir (kullanici emri: *"yurume ya da artik
  /// neyse orasi NET, digerleri HAFIF rengi SOLACAK ve gittikce ARKADAKI
  /// SHAPE SILINECEK"*):
  ///   · gecilen bacaklar     -> **HIC CIZILMEZ**
  ///   · icinde bulunulan bacak -> gecilen kismi KESILMIS, TAM OPAK
  ///   · sonraki bacaklar     -> **SOLUK** renk
  ///
  /// ⚠️⚠️ **`Polyline`DA `opacity` ALANI YOK** (paket kaynagindan
  ///	dogrulandi: `color · width · patterns · points · caps ·
  ///	`jointType · visible · zIndex`). Solma bu yuzden ALFA
  ///	animasyonu degil **AYRI RENK** ile yapilir — Mapbox da ayni
  ///	seyi yapiyor (`inActiveRouteLegsColor`).
  final int? takipBacak;
  final double? takipEnlem;
  final double? takipBoylam;

  /// Kullanici haritayi ELLE kaydirdiginda cagrilir (kamera takibi birakilir).
  final VoidCallback? eldeKaydirdi;

  /// ⚠️⚠️ TURU 150 — cizilecek ROTA BACAKLARI (yoksa null).
  ///
  /// Yurume bacagi **KESIK ve notr gri**, otobus bacagi **KALIN ve hattin
  /// renginde** cizilir — kullanicinin istedigi "iki renk".
  /// ⚠️⚠️ **PLATFORM TUZAGI (arastirmada olculdu):** `PatternItem.dash(n)`
  ///	Android'de **PIKSEL**, iOS'ta **METRE** birimindedir
  ///	(Convert.java new Dash(length) vs FGMPolylineController.m
  ///	kGMSLengthRhumb). Sabit bir sayi yazilsaydi iOS ta kesikler
  ///	18 METRE olur ve sehir olceginde cizgi DUZ gorunurdu — yani
  ///	yurume/otobus ayrimi SESSIZCE kaybolurdu.
  ///	Bu yuzden iOS'ta desen zoom'dan turetilen metre karsiligiyla verilir.
  final List<RotaBacagi>? rota;

  /// Kamerayi bir dikdortgene sigdirma istegi (nesil sayacli).
  final ({double guney, double kuzey, double bati, double dogu, int nesil})?
      sigdir;

  /// Nokta secme kipi acikken haritaya dokunulunca cagrilir.
  final void Function(double enlem, double boylam)? noktaSec;

  /// ⚠️⚠️ TURU 149 — "konumuma dön" istegi SAYACI.
  ///
  /// Deger her artisinda kamera `merkez`e ortalanir — koordinat DEGISMESE
  /// BILE. Bayrak olsaydi ayni yone ikinci dokunus "deger degismedi" diye
  /// SESSIZCE yok sayilirdi (turu 138'de `_zoom` icin olculen ders).
  final int merkezNesli;

  /// ⚠️⚠️ TURU 149 — **GERCEK OTOBUS DURAKLARI** (GTFS). Bos ise katman
  ///	cizilmez. Adet SINIRLI geliyor (`yakinDuraklar`): bolgede 2032
  ///	durak var ve hepsini pinlemek cizimi bogardi (turu 91 dersi).
  final List<Durak> duraklar;

  /// Durak pinine dokununca cagrilir (durak detayini acar).
  final void Function(Durak)? durakSec;

  /// ⚠️⚠️⚠️ TURU 148 — **ORNEK OTOBUS GUZERGAHI** (kullanici emri).
  ///
  /// `null` ise hicbir cizgi cizilmez. Nokta listesi EKRANIN kendisinden
  /// degil, kullanicinin KONUMUNDAN turetilir (bkz. `_ornekHatlar`).
  /// ⚠️ **GERCEK SOKAK HIZASI DEGILDIR** — projede yol tarifi (routing)
  ///    kaynagi yok. Kullaniciya bu durak sayfasinda ACIKCA soyleniyor.
  final ({List<LatLng> noktalar, Color renk})? guzergah;

  /// ⚠️⚠️⚠️ TURU 132 — **HARITANIN ALT DOLGUSU** (denetim buldu).
  ///
  ///	Alt panel artik SABIT ve haritanin USTUNE oturuyor. `GoogleMap`e
  ///	`padding` verilmezse harita kendini TAM EKRAN sanir:
  ///	· konum isareti ekranin ORTASINA konur ama orasi panelin
  ///	  hemen ustudur — kullanici kendi cevresini goremez,
  ///	· "Konumuma dön" her basista kullaniciyi yine panelin DIBINE
  ///	  yerlestirir,
  ///	· 360x640`ta panelin ortettigi bant ~4-5 km`ye denk gelir ve
  ///	  guneydeki isletmeler HIC gorunmez.
  ///
  /// ⚠️ `padding` yalnizca KAMERA hesabini kaydirir; harita yine tam
  ///    ekran cizilir (panelin arkasindan gorunmeye devam eder).
  final double altDolgu;

  // ⚠️ TURU 115 — `yukseklik` alani SILINDI: harita artik DAIMA tam ekran
  //    (Yandex duzeni). Opsiyonel birakmak "kullanilmayan parametre"
  //    uyarisi uretiyordu.

  /// Ayardan gelen harita stili JSON (bkz. haritaStiliSec).
  final String stil;
  final ({double enlem, double boylam})? merkez;
  final List<IsletmeOzet> isletmeler;

  /// Konum/liste hala geliyorsa true — ilk acilista NE cizilecegini belirler.
  final bool yukleniyor;

  /// ⚠️ TURU 137 — kameranin odaklanacagi nokta (serit kartindaki HARITA
  ///    dugmesi doldurur). `null` ise kamera KULLANICININ konumunu izler.
  final ({double enlem, double boylam, int nesil})? odak;

  /// ⚠️ TURU 138 — PIN IKONU bundan turer (bkz. `_pinUret`). Bos ise notr
  ///    magaza ikonu cizilir.
  final String kategori;

  /// ⚠️ TURU 138 — yakinlastirma istegi SAYACI (bkz. ekrandaki `_zoom`).
  ///    Degeri degistiginde `didUpdateWidget` kamerayi bir adim tasir.
  final int zoom;

  /// ⚠️ TURU 139 — kendi konum pinine cizilecek profil fotografinin IMZALI
  ///    adresi. `null` ise pin navigasyon ikonuna duser.
  final String? avatarAdres;

  /// Onbellek anahtari (fotograf degisince pin yeniden uretilsin).
  final String avatarAnahtar;

  @override
  State<_HaritaAlani> createState() => _HaritaAlaniState();
}

class _HaritaAlaniState extends State<_HaritaAlani> {
  GoogleMapController? _harita;

  /// ⚠️ TURU 115 — daire pin (bkz. `harita_pin.dart`).
  BitmapDescriptor? _pin;

  /// ⚠️ TURU 142 — marka adi -> logolu pin. Bos kalirsa kayit normal pine
  ///    duser (`_pin`), yani ozellik FAIL-SAFE'tir.
  final Map<String, BitmapDescriptor> _markaPin = {};

  /// ⚠️ TURU 149 — otobus duragi pini (TEK bitmap, tum duraklar paylasir).
  ///    Durak basina ayri bitmap uretmek 40 PNG kodlamasi demekti.
  BitmapDescriptor? _durakPin;

  /// ⚠️⚠️⚠️ TURU 155 — **VARIS NOKTASI PINI** (kullanici: *"varis
  ///	noktasinda DURAK GORUNMUYOR"*).
  ///
  /// ⚠️⚠️ KOK NEDEN: haritada cizilen duraklar `widget.duraklar`,
  ///	yani **KULLANICININ CEVRESINDEKI** duraklar. Inilecek durak
  ///	genelde kilometrelerce uzakta oldugu icin o listede DEGIL —
  ///	rota cizilse bile varis ucunda hicbir isaret yoktu.
  /// Kirmizi: Yandex referansinda varis noktasi kirmizi pin.
  BitmapDescriptor? _varisPin;

  /// TURU 155 — yon konisi (donen AYRI marker).
  BitmapDescriptor? _yonPin;

  /// ⚠️ TURU 124 — KENDI konum isaretimiz (Google`in mavi noktasi yerine).
  BitmapDescriptor? _benPin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠️ `MediaQuery` BURADA okunur, `initState`te DEGIL: orada
    //    `devicePixelRatio` henuz erisilebilir degil.
    unawaited(_pinUret());
    // ⚠️ Marka pinleri kategoriden BAGIMSIZ: bir kez uretilir, sonra
    //    onbellekten okunur.
    unawaited(_markaPinUret());
  }

  /// ⚠️⚠️⚠️ TURU 138 — PIN ARTIK **IKONLU VE DAHA ACIK** (kullanici emri:
  ///	*"renkler daha acik modern olsun ve icine icon koy"*).
  ///
  /// ⚠️ Isletme pininin ikonu **SECILI KATEGORIDEN** gelir. Kayit basina
  ///    ikon uretilseydi her kategori icin ayri bitmap (ve ayri PNG
  ///    kodlamasi) gerekirdi; `/yakinimda?kategori=X` zaten TEK kategori
  ///    donduruyor, yani kayit basina ikon PRATIKTE ayni cikardi.
  ///    "Tümü"de karisik kume gelir -> notr magaza ikonu.
  /// ⚠️⚠️ **KATEGORI DEGISINCE YENIDEN URETILIR** (`didUpdateWidget`):
  ///	yoksa Otel'e gecen kullanici hala catal-bicak pini gorurdu.
  /// ⚠️ Ic renk marka morunun **ACIK** varyanti: `Color.lerp(morLogo, beyaz,
  ///    0.22)`. Sabit hex YAZILMADI — marka moru degisirse pin de doner.
  /// ⚠️ Kendi konum isaretim KOYU marka moru ve **farkli ikon** (navigation):
  ///    ikisi ayni renk+ikon olsaydi kullanici kendini bir isletme sanardi.
  /// Profil fotografini `ui.Image` olarak cozer (pin icine cizilecek).
  ///
  /// ⚠️⚠️ **`ResizeImage` ZORUNLU**: avatar 1600x1600 olabilir ve pin en
  ///	fazla ~26 dp. Ham cozum kare basina degil ama TEK SEFERDE ~10 MB
  ///	gecici RAM demektir (turu 91 `memCacheWidth` dersi).
  /// ⚠️ `NetworkImage` Flutter'in gorsel onbellegini kullanir; ayni adres
  ///    ikinci kez cozulmez.
  /// ⚠️ Zaman asimi VAR: yavas agda `_pinUret` suresiz asili kalirsa pin
  ///    HIC cizilmez ve harita isaretsiz kalirdi.
  /// ⚠️ Hata SESSIZ — cagiran null'i yedek dal olarak ele alir.
  Future<ui.Image?> _avatarGorseli(double oran) async {
    final adres = widget.avatarAdres;
    if (adres == null || adres.isEmpty) return null;
    return _saglayiciyiCoz(
        ResizeImage(NetworkImage(adres), width: (26 * oran).ceil()));
  }

  /// ⚠️⚠️⚠️ TURU 142 — **MARKA LOGOLU ISLETME PINLERI** (kullanici emri).
  ///
  /// Yalniz `_ornekLogo`da karsiligi olan ORNEK kayitlar icin uretilir;
  /// digerleri eskisi gibi kategori ikonlu `_pin`e duser.
  /// ⚠️ Uretim `daireIsaret` icinde ONBELLEKLIDIR (anahtar varlik yolunu
  ///    icerir) — kategori degisip geri donulunce PNG kodlamasi TEKRARLANMAZ.
  /// ⚠️ Bir logo cozulemezse o marka SESSIZCE atlanir ve kaydi normal pinle
  ///    cizilir; harita isaretsiz KALMAZ.
  Future<void> _markaPinUret() async {
    final oran = MediaQuery.devicePixelRatioOf(context);
    final yeni = <String, BitmapDescriptor>{};
    for (final g in _YakinimdaEkraniState._ornekLogo.entries) {
      final foto = await _saglayiciyiCoz(
          ResizeImage(AssetImage(g.value), width: (26 * oran).ceil()));
      if (foto == null) continue;
      yeni[g.key] = await daireIsaret(
        ic: _YakinimdaEkraniState._markaRenk[g.key] ?? morLogo,
        kenar: Colors.white,
        pikselOrani: oran,
        foto: foto,
        fotoAnahtar: g.value,
      );
    }
    if (!mounted || yeni.isEmpty) return;
    setState(() => _markaPin
      ..clear()
      ..addAll(yeni));
  }

  Future<ui.Image?> _saglayiciyiCoz(ImageProvider saglayici) async {
    try {
      final akis = saglayici.resolve(ImageConfiguration.empty);
      final tamam = Completer<ui.Image>();
      late ImageStreamListener dinleyici;
      dinleyici = ImageStreamListener(
        (bilgi, _) {
          akis.removeListener(dinleyici);
          if (!tamam.isCompleted) tamam.complete(bilgi.image);
        },
        onError: (hata, iz) {
          akis.removeListener(dinleyici);
          if (!tamam.isCompleted) tamam.completeError(hata);
        },
      );
      akis.addListener(dinleyici);
      return await tamam.future.timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  /// Haritaya cizilecek TUM cizgiler (rota bacaklari ya da secili hat).
  ///
  /// ⚠️ Bos KUME dondurulur, `null` DEGIL: eklenti `polylines` icin null
  ///    kabul etmiyor.
  Set<Polyline> _cizgiler() {
    final r = widget.rota;
    if (r != null && r.isNotEmpty) {
      final c = <Polyline>{};
      final aktif = widget.takipBacak;
      for (var i = 0; i < r.length; i++) {
        final b = r[i];
        if (b.noktalar.length < 2) continue;

        // ── GECILEN BACAK: HIC CIZILMEZ ──
        // ⚠️ Mapbox'in "vanishing route line" deseni: arkada kalan
        //    kisim varsayilan olarak SAYDAM. Kullanicinin emri de bu:
        //    *"gittikce arkadaki shape SILINECEK"*.
        if (aktif != null && i < aktif) continue;

        var noktalar = b.noktalar;
        // ── ICINDE BULUNULAN BACAK: gecilen kismi KES ──
        if (aktif != null &&
            i == aktif &&
            widget.takipEnlem != null &&
            widget.takipBoylam != null) {
          final iz = takip.yapistir(
            b.noktalar,
            widget.takipEnlem!,
            widget.takipBoylam!,
          );
          if (iz != null) noktalar = takip.kalanYol(b.noktalar, iz);
        }
        if (noktalar.length < 2) continue;

        final otobus = b.tur == BacakTuru.otobus;
        // ⚠️⚠️⚠️ TURU 156 — **OTOBUS CIZGISI ARTIK YESIL** (kullanici
        //	emri: *"otobus shape YESIL olsun, HAFIF KAPALI ve hafif
        //	SIYAH BORDER olsun, yolu TAM KAVRASIN TASMASIN"*).
        // ⚠️⚠️ Onceden hattin KENDI rengi (`ulasim.hatRengi`)
        //	kullaniliyordu (turu 150). Gebze GTFS renklerinin cogu
        //	birbirine yakin CAMGOBEGI tonlari; koyu lacivert zeminde
        //	hangi bacagin otobus oldugu ayirt edilemiyordu.
        // ⚠️ Hat kimligi KAYBOLMADI: rozet (`hatRozeti`) hala hattin
        //    KENDI rengini kullaniyor — kullanici hangi hat oldugunu
        //    oradan gorur.
        final tamRenk = otobus ? kOtobusRengi : kYurumeRengi;
        // ── SONRAKI BACAKLAR: SOLUK ──
        // ⚠️ Alfa yerine ZEMINE KARISTIRMA: saydam bir cizgi
        //    altindaki harita etiketlerini gosterip okunmaz olur;
        //    zemine karistirilmis opak renk temiz durur.
        final soluk = aktif != null && i > aktif;
        final cizgi = [
          for (final nk in noktalar) LatLng(nk.enlem, nk.boylam),
        ];
        final renk = soluk
            ? (Color.lerp(tamRenk, kAiZemin, 0.55) ?? tamRenk)
            : tamRenk;

        // ══ KILIF (casing) — ALTTA, DAHA GENIS, KOYU ══
        //
        // ⚠️⚠️⚠️ Kullanici: *"yurume adim shape ARKASINDA RENK var,
        //	BORDERLAR var"*. `google_maps_flutter`in `Polyline`
        //	sinifinda **`strokeColor` YOKTUR** (paket kaynagindan
        //	dogrulandi: yalniz `color`, `width`, `patterns`).
        //	Cerceve ancak IKI POLYLINE ile yapilir: altta genis+koyu,
        //	ustte dar+renkli.
        //
        // ⚠️⚠️ **KILIF DUZ, USTTEKI KESIK.** Boylece kesiklerin ARASI
        //	koyu bant olarak gorunur — referans gorselde cizgi
        //	"koyu bir bant uzerinde akiyor" gibi duruyor. Kilif da
        //	kesik olsaydi aralar HARITA ZEMINI kalir ve "arkasinda
        //	renk var" tarifi KARSILANMAZDI.
        //
        // ⚠️⚠️ **zIndex SIRASI KRITIK**: TUM kiliflar TUM cizgilerin
        //	ALTINDA olmali. Bacaklar durakta birlestigi icin, bir
        //	bacagin kilifi otekinin CIZGISINI ortebilirdi.
        //	  kilif yurume 1 · kilif otobus 2 · cizgi yurume 3 ·
        //	  cizgi otobus 4
        c.add(Polyline(
          polylineId: PolylineId('rota-kilif-$i'),
          points: cizgi,
          // ⚠️ Kilif da SOLUKLASIR; yoksa gecilmemis bacaklarin
          //    kilifi one cikar ve hiyerarsi TERS donerdi.
          color: soluk
              ? (Color.lerp(kCizgiKilif, kAiZemin, 0.45) ?? kCizgiKilif)
              : kCizgiKilif,
          width: otobus ? kOtobusEn + 2 * kKilifPay : kYurumeEn + 2 * kKilifPay,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          geodesic: false,
          zIndex: otobus ? 2 : 1,
        ));
        c.add(Polyline(
          polylineId: PolylineId('rota-$i'),
          points: cizgi,
          color: renk,
          width: otobus ? kOtobusEn : kYurumeEn,
          patterns: otobus ? const [] : _kesikDesen(),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          geodesic: false,
          zIndex: otobus ? 4 : 3,
        ));
      }
      return c;
    }
    final g = widget.guzergah;
    if (g == null) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('guzergah'),
        points: g.noktalar,
        color: g.renk,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        geodesic: false,
      ),
    };
  }

  /// Yurume cizgisinin KESIK deseni.
  ///
  /// ⚠️⚠️ **BIRIM PLATFORMA GORE DEGISIR** (arastirmada kaynaktan
  ///	dogrulandi): Android `dash` degerini PIKSEL, iOS METRE sayar.
  ///	iOS'ta sabit 18 verilseydi kesikler 18 METRE olur ve sehir
  ///	olceginde cizgi DUZ gorunurdu.
  /// ⚠️ iOS'ta metre karsiligi mevcut zoom'dan turetilir; `_sonZoom`
  ///    kamera durunca guncellenir.
  List<PatternItem> _kesikDesen() {
    if (!Platform.isIOS) {
      // ⚠️⚠️⚠️ TURU 155 — **ANDROID'DE DESENE DENSITY UYGULANMIYOR.**
      //	Eklenti kaynagindan DOGRULANDI (`PolylineController.java`):
      //	  · `setWidth(width * density)`   <- density UYGULANIYOR
      //	  · `setPattern(pattern)`         <- density YOK
      //	Yani 3x yogunluklu bir telefonda cizgi 5 dp -> 15 px dogru
      //	cizilirken kesik 18 **FIZIKSEL PIKSEL** = **6 dp** oluyordu:
      //	cizgiye gore UC KAT kisa, uzaktan neredeyse DUZ gorunuyor.
      //	Kullanicinin "Yandex'teki gibi olsun" dedigi seyin bir
      //	parcasi da buydu.
      // ⚠️ Carpan `width` ile AYNI olcuye (dp) hizalar; boylece kesik
      //    her yogunlukta cizgi kalinligiyla ayni oranda kalir.
      final o = MediaQuery.devicePixelRatioOf(context);
      return [PatternItem.dash(kKesikDolu * o), PatternItem.gap(kKesikBos * o)];
    }
    // metre/piksel = 156543.03392 * cos(enlem) / 2^zoom
    final en = widget.merkez?.enlem ?? 40.8;
    final mpp =
        156543.03392 * math.cos(en * math.pi / 180) / math.pow(2, _sonZoom);
    return [
      PatternItem.dash(kKesikDolu * mpp),
      PatternItem.gap(kKesikBos * mpp),
    ];
  }

  /// Parmagin basma noktasi — **ELLE KAYDIRMA** algilamak icin.
  ///
  /// ⚠️  ise ya parmak ekranda degil ya da bu temas ZATEN surukleme
  ///    sayildi (ikinci kez bildirilmesin).
  Offset? _basimNoktasi;

  /// Kameranin son bilinen merkezi (nokta secici icin).
  ///
  /// ⚠️ `onCameraMove` her karede tetiklenir ve burada YALNIZ alan
  ///    yazilir — `setState` CAGRILMAZ. Cagrilsaydi harita kaydirilirken
  ///    saniyede 60 yeniden cizim olurdu.
  LatLng? _sonMerkez;

  /// Son bilinen zoom (iOS kesik deseni icin).
  double _sonZoom = 13.5;

  /// Rotanin iki ucundaki isaretler: BINIS duragi, INIS duragi, VARIS.
  ///
  /// ⚠️ Rota yokken BOS kume doner — `markers` bir `Set` oldugu icin
  ///    bos yayma (`...`) tamamen zararsizdir.
  /// ⚠️ zIndex 3: cevredeki durak pinlerinin (1) ve kendi konumumuzun
  ///    (2) USTUNDE. Rotanin uclari en onemli iki noktadir.
  /// ⚠️⚠️ Binis duragi cogu zaman `widget.duraklar` icinde de vardir;
  ///	ayni koordinatta iki marker cizilir ama `markerId` FARKLI
  ///	oldugu icin Set catismasi OLMAZ ve ustteki (zIndex 3) gorunur.
  Iterable<Marker> _rotaUcIsaretleri() sync* {
    final r = widget.rota;
    if (r == null) return;
    for (final b in r) {
      if (b.tur != BacakTuru.otobus || b.noktalar.length < 2) continue;
      final binis = b.noktalar.first;
      final inis = b.noktalar.last;
      yield Marker(
        markerId: const MarkerId('rota-binis'),
        position: LatLng(binis.enlem, binis.boylam),
        icon: _durakPin ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        zIndex: 3,
      );
      yield Marker(
        markerId: const MarkerId('rota-inis'),
        position: LatLng(inis.enlem, inis.boylam),
        icon: _durakPin ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        zIndex: 3,
      );
      break;
    }
    // ⚠️ VARIS: son bacagin SON noktasi. Ayri bir `varis` parametresi
    //    tasimak ikinci bir kaynak olurdu; rota zaten oraya bitiyor.
    final son = r.isEmpty ? null : r.last.noktalar;
    if (son != null && son.isNotEmpty && _varisPin != null) {
      yield Marker(
        markerId: const MarkerId('rota-varis'),
        position: LatLng(son.last.enlem, son.last.boylam),
        icon: _varisPin!,
        anchor: const Offset(0.5, 0.5),
        zIndex: 4,
      );
    }
  }

  Future<void> _pinUret() async {
    final oran = MediaQuery.devicePixelRatioOf(context);
    final d = await daireIsaret(
      // ⚠️ Kenar ACIK: harita zemini her renkte olabilir (yol beyaz, park
      //    yesil, su mavi); acik halka pini her zeminde ayirir.
      ic: Color.lerp(morLogo, Colors.white, 0.22)!,
      kenar: Colors.white,
      pikselOrani: oran,
      ikon: _YakinimdaEkraniState._kategoriIkonu(widget.kategori),
    );
    // ⚠️ TURU 124 — KENDI konum isaretimiz. Google`in MAVI noktasi
    //    kapatildi; bu MOR (marka rengi) ve isletme pinleriyle ayni
    //    bilesenden uretilir (tek kaynak).
    // ⚠️⚠️⚠️ TURU 139 — KENDI PINDE **PROFIL FOTOGRAFI** (kullanici emri:
    //	*"bizim kendi navigasyonumuz yerine de resmimiz olsun, mevcut
    //	profildeki resmi koy"*).
    // ⚠️ Fotograf cozulemezse (adres yok / ag hatasi / zaman asimi)
    //    `foto` null kalir ve pin ESKI haline (mor daire + navigasyon
    //    ikonu) duser. Kullanici konumunu HER DURUMDA gorur.
    final foto = await _avatarGorseli(oran);
    if (!mounted) return;
    final b = await daireIsaret(
      ic: morLogo,
      kenar: Colors.white,
      pikselOrani: oran,
      ikon: LucideIcons.navigation,
      foto: foto,
      fotoAnahtar: foto == null ? '' : widget.avatarAnahtar,
    );
    // ⚠️ TURU 149 — otobus duragi pini: mavi ic + beyaz halka + otobus
    //    ikonu. Isletme pininden RENK ve IKONLA ayrilir; ayni renkte
    //    olsaydi kullanici duragi isletme sanardi (turu 138 dersi).
    final dp = await daireIsaret(
      ic: const Color(0xFF3AA9FF),
      kenar: Colors.white,
      pikselOrani: oran,
      ikon: LucideIcons.busFront,
    );
    // ⚠️ TURU 155 — varis noktasi pini (kirmizi + konum ikonu).
    final vp = await daireIsaret(
      ic: const Color(0xFFFF4D4D),
      kenar: Colors.white,
      pikselOrani: oran,
      ikon: LucideIcons.mapPin,
    );
    // ⚠️ TURU 155 — yon konisi puck ile AYNI marka renginde.
    final yp = await yonKonisi(renk: morLogo, pikselOrani: oran);
    if (!mounted) return;
    setState(() {
      _pin = d;
      _benPin = b;
      _durakPin = dp;
      _varisPin = vp;
      _yonPin = yp;
    });
  }

  ({double enlem, double boylam})? get merkez => widget.merkez;
  List<IsletmeOzet> get isletmeler => widget.isletmeler;
  @override
  void didUpdateWidget(covariant _HaritaAlani eski) {
    super.didUpdateWidget(eski);
    // ⚠️⚠️ TURU 138 — KATEGORI DEGISINCE PIN YENIDEN URETILIR: yoksa Otel'e
    //	gecen kullanici hala catal-bicak pini gorurdu. Uretim ONBELLEKLI
    //	(`daireIsaret`), yani ayni kategoriye donuste PNG kodlamasi TEKRAR
    //	YAPILMAZ.
    if (eski.kategori != widget.kategori ||
        eski.avatarAnahtar != widget.avatarAnahtar) {
      unawaited(_pinUret());
    }
    // ⚠️⚠️ TURU 138 — +/- DUGMELERI. Sayac degistiyse kamera BIR ADIM tasinir
    //	ve **`return` edilir**: ayni karede odak/merkez de degismis olabilir,
    //	iki `animateCamera` ust uste cagrilirsa ikincisi birincisini KESER.
    if (eski.zoom != widget.zoom) {
      _harita?.animateCamera(
        widget.zoom > eski.zoom ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
      );
      return;
    }
    // ⚠️ Kamera YALNIZ merkez GERCEKTEN degistiginde tasinir; her `build`te
    //    `animateCamera` cagirmak haritayi surekli sarsardi.
    // ⚠️ TURU 137 — ODAK MERKEZDEN ONCE: kullanici bir isletmeye
    //    odaklandiysa kamera ORAYA gider; ayni karede konum da
    //    degistiyse (asagi-cek) odak KAZANIR, yoksa kullanici bakmak
    //    istedigi yerden koparilirdi.
    final od = widget.odak;
    final eod = eski.odak;
    // ⚠️⚠️ TURU 140 — olcut artik **NESIL**: koordinat karsilastirmasi
    //	kullanici AYNI karta ikinci kez dokundugunda deger degismedigi
    //	icin kamerayi TASIMIYORDU (haritayi elle kaydirdiktan sonra geri
    //	donus yolu YOKTU). Sayac her dokunusta artar.
    if (od != null && (eod == null || eod.nesil != od.nesil)) {
      _harita?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(od.enlem, od.boylam), 16),
      );
      return;
    }
    final y = widget.merkez;
    final e = eski.merkez;
    // ⚠️⚠️⚠️ TURU 149 — **"KONUMUMA DON" DALI.** Sayac arttiysa koordinat
    //	AYNI OLSA BILE kamera tasinir.
    // ⚠️ `newLatLngZoom` kullanilir, `newLatLng` DEGIL: ikincisi mevcut
    //	zoom'u KORUR ve kullanici z=8'e uzaklastiysa "konumuma dondum ama
    //	hicbir sey gormuyorum" olur.
    // ⚠️ `return` ZORUNLU: ayni karede `merkez` de degismis olabilir ve
    //	iki `animateCamera` ust uste cagrilirsa ikincisi birincisini KESER
    //	(turu 138'de olculdu).
    // ⚠️⚠️ TURU 150 — ROTAYA SIGDIR (kullanici emri: *"sistem
    //	uzaklasacak, shape cizecek"*). Nesil sayacli: ayni rota tekrar
    //	secilirse deger degismez ve kamera TASINMAZDI.
    // ⚠️ `return` ZORUNLU: ayni karede baska bir kamera istegi de olabilir
    //	ve iki `animateCamera` ust uste cagrilirsa ikincisi birincisini
    //	KESER (turu 138'de olculdu).
    final sg = widget.sigdir;
    final esg = eski.sigdir;
    if (sg != null && (esg == null || esg.nesil != sg.nesil)) {
      _harita?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(sg.guney, sg.bati),
            northeast: LatLng(sg.kuzey, sg.dogu),
          ),
          // ⚠️ Dolgu: rota panelin ARKASINA dusmesin.
          60,
        ),
      );
      return;
    }
    if (widget.merkezNesli != eski.merkezNesli && y != null) {
      _harita?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(y.enlem, y.boylam), 16),
      );
      return;
    }
    if (y != null && (e == null || e.enlem != y.enlem || e.boylam != y.boylam)) {
      _harita?.animateCamera(
        CameraUpdate.newLatLng(LatLng(y.enlem, y.boylam)),
      );
    }
  }

  @override
  void dispose() {
    // ⚠️ `GoogleMapController.dispose()` platform gorunumunu de yikar; burada
    //    YALNIZ referans birakilir (gorunumu Flutter'in kendisi soker).
    _harita = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ⚠️⚠️ GERCEK HARITA — yalniz ANAHTAR VARSA.
            //
            //    Anahtar yoksa Google SDK'si Android'de "For development
            //    purposes only" filigranli GRI KUTU, iOS'ta BOS ekran cizer
            //    (iOS'ta `provideAPIKey` bos anahtarla cagrilirsa ASSERT ATIP
            //    COKER — bu yuzden `AppDelegate` de bos kontrolu yapiyor).
            //    O yuzden anahtarsiz derlemede ALTTAKI yer tutucu kalir:
            //    konumlar DOGRU gorunur, yalnizca karo katmani olmaz.
            // ⚠️ YAPMA: bu kapiyi kaldirip haritayi kosulsuz cizme.
            if (haritaAnahtariVar && merkez != null)
              // ⚠️⚠️⚠️ TURU 151 — **ELLE KAYDIRMA ALGILAMA**
              //	(kamera takibini birakmak icin).
              //
              // ⚠️⚠️ **`onCameraMoveStarted` KULLANILAMAZ**: o bir
              //	ciplak `VoidCallback` ve **JEST ile BIZIM**
              //	`animateCamera` cagrimizi AYIRT ETMEZ
              //	(`CameraMoveStartedReason` bu eklentide YOK).
              //	Kullanilsaydi kameranin kullaniciyi takip icin
              //	yaptigi ILK hareket takibi kendisi birakirdi —
              //	yani ozellik ilk karede kendini kapatirdi.
              //
              // ⚠️ `Listener` jestleri YUTMAZ (`HitTestBehavior`
              //    degistirilmiyor); haritanin kendi jest tanicilari
              //    calismaya devam eder.
              // ⚠️ **10 px ESIGI**: parmak temasindaki kucuk
              //    titremeler ve dokunuslar takibi birakmasin; ancak
              //    gercek bir SURUKLEME sayilsin.
              Listener(
                onPointerDown: (e) => _basimNoktasi = e.position,
                onPointerMove: (e) {
                  final b = _basimNoktasi;
                  if (b == null) return;
                  if ((e.position - b).distance > 10) {
                    _basimNoktasi = null;
                    widget.eldeKaydirdi?.call();
                  }
                },
                onPointerUp: (_) => _basimNoktasi = null,
                onPointerCancel: (_) => _basimNoktasi = null,
                child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(merkez!.enlem, merkez!.boylam),
                  zoom: 13.5,
                ),
                // ⚠️⚠️⚠️ TURU 140 — **GOOGLE LOGOSU PANELIN ALTINA**
                //	(kullanici emri: *"Google Maps yazisi gorunuyor, onu
                //	KARTIN ALTINA al — kaldirmak yasak ama kartin altina
                //	al"*).
                //
                //	`padding` hem KAMERAYI hem TUM HARITA UI'INI (Google
                //	logosu, pusula, konum dugmesi) "gorunur bolgenin" icine
                //	tasir. `altDolgu` = panel boyu oldugu icin logo tam
                //	panelin UST KENARINA oturuyor ve haritanin ortasinda
                //	duruyordu.
                // ⚠️⚠️ **`EdgeInsets.zero` YAPILMADI** — o, turu 132'de
                //	dosya serhine yazili UC hatayi birden geri getirirdi:
                //	kendi konum pini panelin dibine konur, "Konumuma dön"
                //	her basista kullaniciyi panelin altina atar ve
                //	360x640'ta panelin ortettigi ~4-5 km'lik bantta
                //	guneydeki isletmeler HIC gorunmez.
                //	Bunun yerine dolgu YALNIZ logo yuksekligi kadar
                //	KISALTILIR: logo panelin ust kenarinin `kLogoPay` dp
                //	ALTINA, yani panelin ARKASINA duser; kamera
                //	merkezlemesinin ~%85'i KORUNUR.
                // ⚠️ Platformlar arasi logo yuksekligi/marji BIREBIR AYNI
                //    DEGIL — deger GERCEK CIHAZDA dogrulanmali (emulatorde
                //    Google Maps karolari cizilmiyor, Play Services 400).
                padding: EdgeInsets.only(
                  bottom: math.max(0, widget.altDolgu - kLogoPay),
                ),
                // ⚠️ Controller SAKLANIR: konum degisince kamerayi tasiyan
                //    TEK yol budur (bkz. sinif serhi).
                onMapCreated: (c) => _harita = c,
                // ⚠️ NORMAL GOOGLE HARITASI (bkz. `_haritaStili` serhi).
                style: widget.stil,
                // ⚠️⚠️ TURU 124 — **GOOGLE`IN MAVI KONUM NOKTASI KAPATILDI**
                //	(kullanici emri: *"konum mavi değil bizim kullandığımız
                //	mor olsun"*).
                //
                //	O nokta PLATFORM tarafindan cizilir ve rengi
                //	DEGISTIRILEMEZ; tek yol kapatip KENDI isaretimizi
                //	koymaktir (asagidaki `konum-ben` marker`i, `_benPin`
                //	ile MOR).
                myLocationEnabled: false,
                // ⚠️ Google`in kendi konum dugmesi de MAVI ve sag altta
                //    duruyordu; bizim "konumuma dön" dugmemiz ZATEN ust
                //    barda (`_ustDugmeler`). Iki dugme = iki farkli dil.
                myLocationButtonEnabled: false,
                // ⚠️⚠️⚠️ TURU 86 — HARITA JESTLERI **ACILDI** (kullanici emri).
                //
                //	Turu 85'te bunlarin hepsi `false` idi ve gerekce olarak
                //	*"harita bir LISTE ICINDE, dikey jesti alirsa kullanici
                //	sayfayi kaydiramaz"* yazilmisti. Sonuc: kullanici haritaya
                //	dokunuyor, parmagini suruyor ve **HICBIR SEY OLMUYORDU** —
                //	harita canli degil, EKRAN GORUNTUSU gibi duruyordu.
                //	Etiketlerin de kapali olmasiyla birlesince ortaya
                //	"harita olmayan bir harita" cikmisti.
                //
                //	Kaydirma catismasi `EagerGestureRecognizer` ile cozulur:
                //	dokunus HARITANIN UZERINDE baslarsa jesti HARITA alir,
                //	kartlarin uzerinde baslarsa LISTE alir. Iki yuzey ayri.
                // ⚠️ YAPMA: jestleri tekrar `false` yapma; catismayi
                //    recognizer YERINE jestleri kapatarak "cozme".
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                // ⚠️⚠️ TURU 148 — ORNEK GUZERGAH CIZGISI. Bos kume verilir
                //	(null DEGIL): eklenti `polylines` icin null kabul
                //	etmiyor ve bos kume "cizgi yok" demektir.
                // ⚠️ `geodesic: false`: noktalar zaten sik; buyuk daire
                //    yayina cevirmek kisa parcalarda gorunur bir egrilik
                //    uretmez ama hesabi bosuna agirlastirir.
                polylines: _cizgiler(),
                // ⚠️⚠️⚠️ TURU 155 — **DOGRULUK HALKASI** (kullanici emri:
                //	*"cevresinde hafif beyaz daire var bunun gibi olsun"*).
                //
                // ⚠️⚠️ `Circle.radius` **METRE** cinsindendir; yani halka
                //	zoom degistikce dogru olceklenir ve GERCEK belirsizligi
                //	gosterir. Sabit piksel bir daire cizmek yalnizca SUS
                //	olurdu.
                // ⚠️ 10 m taban: mukemmel GPS'te bile halka gorunsun,
                //    yoksa isaret "cirilciplak" durur. 120 m tavan: kapali
                //    alanda dogruluk 500 m'ye cikabiliyor ve o kadar buyuk
                //    bir daire haritanin tamamini kaplar.
                circles: {
                  if (merkez != null && widget.dogrulukM != null)
                    Circle(
                      circleId: const CircleId('konum-dogruluk'),
                      center: LatLng(merkez!.enlem, merkez!.boylam),
                      radius: widget.dogrulukM!.clamp(10.0, 120.0),
                      fillColor: Colors.white.withValues(alpha: 0.10),
                      strokeColor: Colors.white.withValues(alpha: 0.28),
                      strokeWidth: 1,
                      zIndex: 0,
                    ),
                },
                // ⚠️ TURU 150 — nokta secme kipinde haritaya dokunmak
                //    baslangic/varis noktasini secer.
                onTap: widget.noktaSec == null
                    ? null
                    : (p) => widget.noktaSec!(p.latitude, p.longitude),
                // ⚠️⚠️⚠️ TURU 155 — **KESIK DESEN ZOOM SIRASINDA DA
                //	GUNCELLENIR** (kullanici: *"Yandexte kesik cizgiler
                //	yaklassam da uzaklassam da AYNI; bizimkinin de boyle
                //	olmasi gerekiyor"*).
                //
                //	⚠️⚠️ KOK NEDEN: desen YALNIZ `onCameraIdle`de ve
                //	yalniz **0.4 zoom** farkinda guncelleniyordu. 0.4 zoom
                //	= **%32 olcek hatasi**; ustelik parmak ekrandayken HIC
                //	guncellenmedigi icin kesikler yakinlastirirken UZUYOR,
                //	parmak kalkinca ANIDEN yerine oturuyordu.
                //
                // ⚠️⚠️ `onCameraMove` zoom'u BEDAVA verir (`p.zoom`);
                //	`onCameraIdle`daki `getZoomLevel()` ise ASENKRON bir
                //	platform cagrisidir. Esik **0.15** (%11 hata) ve yalniz
                //	iOS: tam bir sikistirmada ~6-7 yeniden cizim demek —
                //	60 fps yeniden cizimin yaninda onemsiz.
                // ⚠️ Android'de dash PIKSEL oldugu icin zaten zoom'dan
                //    bagimsizdir; orada `setState` yapmak BOSA yeniden cizimdir.
                onCameraMove: (p) {
                  _sonMerkez = p.target;
                  if (!Platform.isIOS) return;
                  if ((p.zoom - _sonZoom).abs() > kZoomEsigi) {
                    setState(() => _sonZoom = p.zoom);
                  }
                },
                onCameraIdle: () async {
                  // ⚠️ Merkez YALNIZ kamera durunca bildirilir
                  //    (ters geocoding bir AG istegi).
                  final mk = _sonMerkez;
                  if (mk != null) {
                    widget.kameraDurdu?.call(mk.latitude, mk.longitude);
                  }
                  // ⚠️ iOS kesik deseni zoom'a bagli. `onCameraMove`
                  //    zaten izliyor; bu **EMNIYET AGI**: programatik
                  //    kamera hareketlerinde (`animateCamera`) `onCameraMove`
                  //    her zaman tetiklenmeyebilir.
                  final z = await _harita?.getZoomLevel();
                  if (!mounted || z == null) return;
                  if ((z - _sonZoom).abs() > kZoomEsigi) {
                    setState(() => _sonZoom = z);
                  }
                },
                markers: {
                  // ⚠️⚠️ TURU 124 — KENDI KONUMUMUZ (mor). Google`in mavi
                  //	noktasi kapatildigi icin bu marker olmazsa kullanici
                  //	haritada NEREDE oldugunu goremezdi.
                  // ⚠️ Isaret hazir degilse (uretim asenkron) marker HIC
                  //    cizilmez: varsayilan KIRMIZI damla, "benim konumum"
                  //    icin yanlis bir dil olurdu.
                  // ⚠️⚠️⚠️ TURU 155 — **YON KONISI AYRI BIR MARKER.**
                  //	Yon `Marker.rotation` ile veriliyor ve rotation
                  //	MARKERIN TAMAMINI dondurur. Koni puck ile ayni
                  //	bitmap'te olsaydi kullanici donunce **PROFIL
                  //	FOTOGRAFI DA TERS DONERDI**. Alta donen koni,
                  //	uste sabit fotograf.
                  // ⚠️ `flat: true`: marker haritaya YATIK cizilir, harita
                  //    dondurulurse koni de doner (ekrana sabit kalmaz).
                  if (merkez != null && _yonPin != null && widget.yon != null)
                    Marker(
                      markerId: const MarkerId('konum-yon'),
                      position: LatLng(merkez!.enlem, merkez!.boylam),
                      icon: _yonPin!,
                      anchor: const Offset(0.5, 0.5),
                      rotation: widget.yon!,
                      flat: true,
                      zIndex: 1,
                    ),
                  if (merkez != null && _benPin != null)
                    Marker(
                      markerId: const MarkerId('konum-ben'),
                      position: LatLng(merkez!.enlem, merkez!.boylam),
                      icon: _benPin!,
                      anchor: const Offset(0.5, 0.5),
                      // ⚠️ Isletme pinlerinin ALTINDA kalmasin diye degil,
                      //    USTUNDE olsun diye yuksek zIndex.
                      zIndex: 2,
                    ),
                  // ⚠️⚠️ TURU 149 — **GERCEK OTOBUS DURAKLARI.** Isletme
                  //	pinlerinden ONCE cizilir ki isletme pinleri ustte
                  //	kalsin (kullanicinin asil aradigi onlar).
                  for (final d in widget.duraklar)
                    Marker(
                      markerId: MarkerId('durak-${d.id}'),
                      position: LatLng(d.enlem, d.boylam),
                      icon: _durakPin ?? BitmapDescriptor.defaultMarker,
                      anchor: const Offset(0.5, 0.5),
                      zIndex: 1,
                      onTap: () => widget.durakSec?.call(d),
                    ),
                  // ⚠️⚠️⚠️ TURU 155 — **ROTANIN IKI UCU DA ISARETLENIR.**
                  //	Kullanici: *"varis noktasinda DURAK GORUNMUYOR"*.
                  //	`widget.duraklar` YALNIZ kullanicinin cevresindeki
                  //	duraklardir; INILECEK durak kilometrelerce uzakta
                  //	oldugu icin o listede DEGIL ve haritada hicbir isaret
                  //	yoktu.
                  //	⚠️⚠️ Duraklar ROTADAN turetilir: otobus bacaginin
                  //	ILK noktasi BINIS, SON noktasi INIS duragidir
                  //	(`_guzergahDilimi` ikisini basa/sona ACIKCA koyar).
                  //	Ayri bir parametre tasimak iki kaynak yaratir ve
                  //	kacinilmaz olarak DRIFT ederdi.
                  ..._rotaUcIsaretleri(),
                  for (final i in isletmeler)
                    if (i.enlem != 0 || i.boylam != 0)
                      Marker(
                        markerId: MarkerId(i.id),
                        position: LatLng(i.enlem, i.boylam),
                        // ⚠️⚠️ TURU 115 — **DAIRE PIN** (kullanici emri:
                        //    *"pinler daire seklinde, border acik renk"*).
                        //    `_pin` null iken varsayilan damla cizilir:
                        //    uretim asenkron ve ilk karede hazir olmayabilir.
                        // ⚠️⚠️ TURU 142 — ORNEK kayitta ve markanin logosu
                        //	varsa **LOGOLU PIN** (kullanici emri: *"ikonlar
                        //	degil logolar gorunmeli, onlarin rengine
                        //	yakin"*). Gercek kayitta ASLA: marka adini
                        //	tasiyan gercek bir isletmeye logo basmak
                        //	kullaniciya YANLIS BILGI olurdu.
                        icon: (i.id.startsWith('demo-')
                                ? _markaPin[i.ad]
                                : null) ??
                            _pin ??
                            BitmapDescriptor.defaultMarker,
                        // ⚠️ Daire ORTASINDAN capalanir; damla ucundan
                        //    capalaniyordu ve daire konumun ~12 dp ustunde
                        //    duruyordu.
                        anchor: const Offset(0.5, 0.5),
                        // ⚠️⚠️ TURU 140 — pin dokunusu artik **KAMERAYI
                        //	ODAKLAR**, kart ACMAZ (kullanici emri: *"alttaki
                        //	isletme kartlarina tikladiginda popup cikariyor,
                        //	onlari kaldir"*).
                        // ⚠️ `onTap`i komple silmek pini SALT GORSEL yapardi
                        //    ve kullaniciya "bozuk" gorunurdu: `InfoWindow`
                        //    turu 136'da zaten kaldirilmisti, geriye tek
                        //    eylem buydu.
                        // ⚠️ Kamera DOGRUDAN buradan tasinir — ekrana geri
                        //    cagirim GEREKMEZ (`_harita` bu State'te).
                        // ⚠️ **GEZINME HALA ONAYLI EYLEM:** pin dokunusu
                        //    profile GITMEZ (turu 85b gerekcesi KORUNDU).
                        onTap: () => _harita?.animateCamera(
                          CameraUpdate.newLatLng(LatLng(i.enlem, i.boylam)),
                        ),
                      ),
                },
                ),
              )
            // ⚠️⚠️⚠️ TURU 88 — CIZIM HARITASI **ANAHTAR VARKEN HIC CIZILMEZ.**
            //
            //	Kullanici: *"harita ilkten gelirken o eski cizim harita
            //	geliyor gidiyor, onu kaldir"*. Sebep: kapi
            //	`haritaAnahtariVar && merkez != null` idi; acilista `merkez`
            //	HENUZ NULL oldugu icin (GPS ~1-2 sn suruyor) `else` dali
            //	kosuyor ve elle boyanmis sahte sehir ciziliyordu. Konum
            //	gelince gercek haritaya geciyor -> **GORUNUR BIR SICRAMA**.
            //
            //	Artik iki kapi AYRILDI:
            //	  · anahtar VAR + konum YOK  -> notr zemin + spinner
            //	  · anahtar YOK              -> durust yer tutucu (cizim)
            //	Yani cizim harita YALNIZCA anahtarsiz derlemede gorunur;
            //	yayindaki surumde ASLA cizilmez.
            // ⚠️ YAPMA: iki kapiyi tekrar tek `else`de birlestirme.
            else if (haritaAnahtariVar)
              ColoredBox(
                color: _zemin,
                child: Center(
                  child: widget.yukleniyor
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(
                          LucideIcons.mapPinOff,
                          size: 26,
                          color: Colors.grey,
                        ),
                ),
              )
            else ...[
              const ColoredBox(color: _zemin),
              CustomPaint(painter: _SehirCizer()),
              if (merkez != null)
                CustomPaint(
                  painter: _IgneCizer(merkez: merkez!, isletmeler: isletmeler),
                ),
            ],
            // Durust bilgi seridi.
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isletmeler.isEmpty
                      ? 'Konumun'
                      : '${isletmeler.length} işletme yakınında',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF3C3C43),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // ⚠️⚠️⚠️ TURU 154 — **SABIT MERKEZ PINI** (kullanici emri:
            //	*"harita nokta secerken ekranda bir PIN olsun"*).
            //
            // ⚠️⚠️ **`Marker` DEGIL `Stack` katmani**: marker haritayla
            //	BIRLIKTE kayar, oysa secici pin EKRANDA SABIT durup
            //	haritanin ALTINDAN kaymasi gerekiyor.
            // ⚠️ `IgnorePointer` ZORUNLU: pin dokunuslari YUTARSA harita
            //    tam ortasindan kaydirilamaz.
            // ⚠️ Pin ucu MERKEZE oturur: ikon 44 dp ve golgesiyle birlikte
            //    `Alignment.center`da cizilseydi UCU degil ORTASI merkeze
            //    gelir, kullanici 22 dp yanlis nokta secerdi.
            if (widget.merkezPin)
              const IgnorePointer(
                child: Center(
                  child: Padding(
                    // Pinin UCU merkeze gelsin diye govde yukari kaydirilir.
                    padding: EdgeInsets.only(bottom: 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.mapPin,
                            size: 44, color: Color(0xFFFF5E5E)),
                        // Golge yerine kucuk bir nokta: kullanici tam
                        // hangi noktanin secildigini gorur.
                        SizedBox(height: 2),
                        _MerkezNoktasi(),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Uber tarzi acik-gri sehir dokusu (yol agi + park + su).
///
/// ⚠️ Rastgelelik YOK: `Random` kullanilsaydi her cizimde farkli bir sehir
///    olusur ve kaydirmada TITRERDI. Desen deterministik bir formulden gelir.
class _SehirCizer extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final su = Paint()..color = _su;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.72, 0)
        ..quadraticBezierTo(
          size.width * 0.86, size.height * 0.45,
          size.width * 0.78, size.height,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      su,
    );
    final park = Paint()..color = _yesil;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.06, size.height * 0.58,
            size.width * 0.22, size.height * 0.28),
        const Radius.circular(10),
      ),
      park,
    );

    final yol = Paint()
      ..color = _yol
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cizgi = Paint()
      ..color = _yolCizgi
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Yatay + dikey yol agi (kalinliklar degisken -> ana/ara yol hissi).
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      yol.strokeWidth = i.isEven ? 9 : 5;
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.8, y), yol);
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.8, y), cizgi);
    }
    for (var i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      if (x > size.width * 0.75) break;
      yol.strokeWidth = i == 2 ? 10 : 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), yol);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cizgi);
    }
  }

  @override
  bool shouldRepaint(_SehirCizer oldDelegate) => false;
}

/// Kullanici + isletme igneleri. Konumlar GERCEK koordinatlardan turer.
class _IgneCizer extends CustomPainter {
  _IgneCizer({required this.merkez, required this.isletmeler})
    : _adet = isletmeler.length;

  final ({double enlem, double boylam}) merkez;
  final List<IsletmeOzet> isletmeler;

  /// ⚠️ Uzunluk KURULUM ANINDA yakalanir — `shouldRepaint` icinde AYNI liste
  ///    nesnesinin uzunlugunu kendisiyle karsilastirmak DAIMA false doner
  ///    (turu 81b'de canli ses dalgasi tam bu yuzden hic cizilmemisti).
  final int _adet;

  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(size.width / 2, size.height / 2);

    // En uzak isletme kenara denk gelsin diye olcek.
    var enUzak = 0.5;
    for (final i in isletmeler) {
      if (i.km > enUzak) enUzak = i.km;
    }
    final olcek = (math.min(size.width, size.height) / 2 - 26) / enUzak;

    final igne = Paint()..color = const Color(0xFF6C2BD9);
    for (final i in isletmeler) {
      if (i.enlem == 0 && i.boylam == 0) continue;
      // Kuzey yukari: enlem farki -Y, boylam farki +X (boylam cos ile daralir).
      final dy = (i.enlem - merkez.enlem) * 111.0;
      final dx = (i.boylam - merkez.boylam) *
          111.0 * math.cos(merkez.enlem * math.pi / 180);
      final p = o + Offset(dx * olcek, -dy * olcek);
      if (p.dx < 6 || p.dx > size.width - 6 ||
          p.dy < 6 || p.dy > size.height - 6) {
        continue;
      }
      canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, igne);
    }

    // Kullanici: mavi nokta + halka (harita uygulamalarinin ortak dili).
    canvas.drawCircle(o, 13, Paint()..color = const Color(0x333AA9FF));
    canvas.drawCircle(o, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(o, 5, Paint()..color = const Color(0xFF3AA9FF));
  }

  @override
  bool shouldRepaint(_IgneCizer eski) =>
      eski._adet != _adet ||
      eski.merkez.enlem != merkez.enlem ||
      eski.merkez.boylam != merkez.boylam;
}

/// ⚠️⚠️⚠️ TURU 140 — **KATEGORI POPUPU: ARAMA ALANI + IZGARA** (kullanici
///	emri: *"kategoriye tikladiginda orada ARAMA ALANI olacak"*).
///
/// ⚠️⚠️ **AYRI BIR `StatefulWidget` OLMAK ZORUNDA** — `StatefulBuilder` ile
///	yapilamaz: bir `TextEditingController` gerekiyor ve o denetleyicinin
///	`dispose`i, sheet'in KENDI agacinda olmali. `showModalBottomSheet`
///	future'i **pop ANINDA** cozulur; route'un CIKIS ANIMASYONU (~150-250 ms)
///	surerken alt agac CIZILMEYE DEVAM EDER ve disaridan dispose edilmis bir
///	denetleyiciye dokunan `EditableText` *"A TextEditingController was used
///	after being disposed"* atar -> `build` istisnasi -> `ErrorWidget`
///	**EKRANIN TAMAMINI KIRMIZI** boyar. Bu, turu 96i'de kullanicinin SAHADA
///	yakaladigi hatadir (`core/denetleyici_sahibi.dart` de tam bunun icin
///	yazildi).
/// ⚠️ YAPMA: denetleyiciyi disarida kurup buraya parametre olarak gecme.
class _KategoriPopup extends StatefulWidget {
  const _KategoriPopup({required this.kartYapici});

  /// Karti EKRAN cizer (secili kategoriyi ve `pop` yolunu o biliyor).
  final Widget Function(BuildContext c, String anahtar, String ad) kartYapici;

  @override
  State<_KategoriPopup> createState() => _KategoriPopupState();
}

class _KategoriPopupState extends State<_KategoriPopup> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  /// Arama metnine gore suzulmus kategori anahtarlari.
  ///
  /// ⚠️ Karsilastirma **`toLowerCase()` ILE DEGIL** `contains` + kucultme
  ///    yapilarak degil, dogrudan Turkce duyarsiz bir esleme ile yapilir:
  ///    Dart'in `toLowerCase()`i "İ" harfini birlesik noktali bir kodpoint'e
  ///    cevirir ve "İSTANBUL" aramasi "istanbul"u BULAMAZ (turu 91'de
  ///    sunucu tarafinda birebir bu yasandi).
  List<String> get _suzulmus {
    final q = _sadelestir(_q.text.trim());
    if (q.isEmpty) return _YakinimdaEkraniState._haritaKategorileri;
    return _YakinimdaEkraniState._haritaKategorileri
        .where((k) => _sadelestir(isletmeKategorileri[k]!).contains(q))
        .toList();
  }

  /// Turkce harfleri ASCII'ye indirger ve kucultur (arama icin).
  static String _sadelestir(String s) {
    const eslesme = {
      'ı': 'i', 'İ': 'i', 'I': 'i', 'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g',
      'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o', 'ç': 'c', 'Ç': 'c',
    };
    final b = StringBuffer();
    for (final h in s.split('')) {
      b.write(eslesme[h] ?? h.toLowerCase());
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final liste = _suzulmus;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 10),
          child: Text(
            'Kategoriler',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        // ── ARAMA ALANI ──
        // ⚠️ `suffixIcon`a GENISLIK ACIKCA verilir: verilmezse Flutter ona
        //    KALAN GENISLIGIN TAMAMINI ayirir ve metne yer kalmaz — yazi
        //    GORUNMEZ olur (turu 96o'da olculdu).
        Padding(
          padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 12),
          child: TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Kategori ara',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 42, minHeight: 42),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : SizedBox(
                      width: 44,
                      child: IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        tooltip: 'Temizle',
                        onPressed: () => setState(_q.clear),
                      ),
                    ),
              filled: true,
              fillColor: kYuzeyGri(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kYaricap(46)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: liste.isEmpty
              // ⚠️ BOS SONUC DURUSTCE SOYLENIR: bos bir izgara "bozuk"
              //    gorunur ve kullanici sebebini bilemez.
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '"${_q.text.trim()}" ile eşleşen kategori yok.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                )
              : GridView.count(
                  padding:
                      const EdgeInsets.fromLTRB(kYanBosluk, 4, kYanBosluk, 16),
                  crossAxisCount: 4,
                  crossAxisSpacing: kIzgaraAralik,
                  mainAxisSpacing: kIzgaraAralik,
                  // ⚠️ Oran DEGIL sabit hucre boyu — ANASAYFA ILE AYNI
                  //    FORMUL (`hizmet_menusu.dart`: kutu + 5 + iki satir).
                  //    Oranla verilseydi yazi olcegi 1.3'te TASARDI.
                  mainAxisExtent: kKesifKutu +
                      5 +
                      MediaQuery.textScalerOf(context).scale(14) * 1.15 * 2,
                  children: [
                    // ⚠️ "Tümü" YALNIZ arama BOSKEN cizilir: bir arama
                    //    sonucunda "Tümü" gostermek yaniltici olurdu.
                    if (_q.text.trim().isEmpty)
                      widget.kartYapici(context, '', 'Tümü'),
                    for (final g in liste)
                      widget.kartYapici(context, g, isletmeKategorileri[g]!),
                  ],
                ),
        ),
      ],
    );
  }
}

/// ⚠️⚠️⚠️ TURU 141 — **ARAMA ALANI AYRI BIR `StatefulWidget`**.
///
/// Ilk yazimda kutu, `build` icinde `TextEditingController(text: _q)` ile
/// kuruluyordu. Bu UC ayri hata uretir:
///   1. **Her karede YENI denetleyici** — eskisi HIC dispose edilmez
///      (sizinti) ve `EditableText` her cizimde yeni nesneye baglanir.
///   2. **IME bilesimi (composing) SIFIRLANIR** — Turkce klavyede harf
///      birlesimi ve kelime onerisi bozulur.
///   3. Kutuyu `key`le yenilemek (metin bos<->dolu) ILK HARFTE elemani
///      yeniden kurar ve **KLAVYE KAPANIR**.
///
/// Cozum: denetleyici bu widget'in KENDI `State`inde yasar ve orada
/// `dispose` edilir. Panel ve popup AYRI birer ornek kullanir, yani iki
/// canli `TextField` AYNI denetleyiciyi paylasmaz (secim cakismasi olmaz).
///
/// ⚠️ `didUpdateWidget` DISARIDAN gelen degeri yazar ama **yalniz farkliysa**:
///    kosulsuz yazmak kullanici yazarken imleci her karede SONA atardi.
class _AramaAlani extends StatefulWidget {
  const _AramaAlani({
    required this.deger,
    required this.ipucu,
    required this.degisti,
  });

  final String deger;
  final String ipucu;
  final ValueChanged<String> degisti;

  @override
  State<_AramaAlani> createState() => _AramaAlaniState();
}

class _AramaAlaniState extends State<_AramaAlani> {
  late final TextEditingController _c =
      TextEditingController(text: widget.deger);

  @override
  void didUpdateWidget(covariant _AramaAlani eski) {
    super.didUpdateWidget(eski);
    // ⚠️ Yalniz DISARIDAN degistiyse (or. dal secimi `_q`yu sifirladi).
    if (widget.deger != _c.text) {
      _c.text = widget.deger;
      _c.selection = TextSelection.collapsed(offset: widget.deger.length);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        onChanged: widget.degisti,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.ipucu,
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          // ⚠️ `minHeight` 40 -> 36: 40 verilince kutunun IC yuksekligi
          //    `isDense` + 11 dp dolgudan BUYUK olur ve `_aramaBoy` hesabi
          //    govdeyle AYRISIR (panel yuksekligi 4 dp kayardi).
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 36),
          // ⚠️⚠️ **ZORUNLU — verilmezse kutu ILK HARFTE 43 -> 48 dp SICRAR.**
          //	`InputDecorator` kap yuksekligini
          //	`max(fixIconHeight, contentPadding + inputHeight)` ile bulur ve
          //	`suffixIconConstraints` yoksa `kMinInteractiveDimension`
          //	(48 dp) dayatir. `_panelBoy` o sicramayi goremedigi icin yuzen
          //	filtre seridi 7 dp kayiyordu (olculdu).
          // ⚠️ Bedeli: X'in dokunma hedefi 36 dp. BILINCLI — temizlemenin
          //    ikinci yolu (metni secip silmek) duruyor ve alternatif,
          //    panelin her harfte ziplamasi, daha kotu.
          suffixIconConstraints:
              const BoxConstraints(minWidth: 42, minHeight: 36),
          suffixIcon: _c.text.isEmpty
              ? null
              : SizedBox(
                  width: 42,
                  child: IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    tooltip: 'Temizle',
                    onPressed: () {
                      _c.clear();
                      widget.degisti('');
                    },
                  ),
                ),
          filled: true,
          fillColor: kAiKartYuzey(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kYaricap(44)),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

/// ⚠️⚠️⚠️ TURU 142 — **ARAMA SAYFASI** (kullanici emri: *"kategori arama
///	yerine NORMAL ARAMA olacak, altinda KATEGORILER ve GECMIS yazacak"* +
///	*"kategorilerde kartlar %20 kucult"*).
///
/// Duzen: ustte normal arama kutusu -> **Geçmiş** (varsa) -> **Kategoriler**.
/// ⚠️ Denetleyici bu widget'in KENDI `State`inde yasar ve orada dispose
///    edilir (turu 96i: sheet kapanirken disaridan dispose edilen bir
///    denetleyici EKRANI KIRMIZI boyar).
class _AramaSayfasi extends StatefulWidget {
  const _AramaSayfasi({
    required this.baslangic,
    required this.gecmis,
    required this.kartYapici,
  });

  final String baslangic;

  /// Son secilen dallar (en yeni ONCE). ⚠️ OTURUM OMURLU — diske
  /// yazilmiyor; uygulama kapaninca gider (durust sinir).
  final List<String> gecmis;

  /// Karti EKRAN cizer (secili dali ve `pop` yolunu o biliyor).
  final Widget Function(BuildContext c, String anahtar, String ad) kartYapici;

  @override
  State<_AramaSayfasi> createState() => _AramaSayfasiState();
}

class _AramaSayfasiState extends State<_AramaSayfasi> {
  late final TextEditingController _c =
      TextEditingController(text: widget.baslangic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Arama metnine gore suzulmus kategori anahtarlari.
  ///
  /// ⚠️ Turkce duyarsiz: `toLowerCase()` "İ" harfini birlesik noktaya
  ///    cevirir ve "İSTANBUL" -> "istanbul"u BULAMAZ.
  List<String> get _suzulmus {
    final q = _KategoriPopupState._sadelestir(_c.text.trim());
    if (q.isEmpty) return _YakinimdaEkraniState._haritaKategorileri;
    return _YakinimdaEkraniState._haritaKategorileri
        .where((k) => _KategoriPopupState._sadelestir(isletmeKategorileri[k]!)
            .contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final liste = _suzulmus;
    final scheme = Theme.of(context).colorScheme;
    final q = _c.text.trim();
    // ⚠️ Arama yazilirken "Geçmiş" GIZLENIR: kullanicinin o an aradigi sey
    //    ile ilgisiz bir liste gostermek kafa karistirir.
    final gecmis = q.isEmpty
        ? widget.gecmis
            .where(_YakinimdaEkraniState._haritaKategorileri.contains)
            .toList()
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── NORMAL ARAMA ──
        Padding(
          padding: const EdgeInsets.fromLTRB(kYanBosluk, 4, kYanBosluk, 14),
          child: TextField(
            controller: _c,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => Navigator.of(context).pop(('metin', v)),
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              // ⚠️ TURU 146 — kullanici emri: *"ilk actigimizda orada
              //    'İşletme ara' gibi yazi olsun inputta"*.
              hintText: 'İşletme ara',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 42, minHeight: 38),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 38),
              suffixIcon: _c.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      tooltip: 'Temizle',
                      onPressed: () => setState(_c.clear),
                    ),
              filled: true,
              fillColor: kAiKartYuzey(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kYaricap(46)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (gecmis.isNotEmpty) ...[
                _baslik(context, 'GEÇMİŞ'),
                _izgara(context, gecmis),
                const SizedBox(height: 18),
              ],
              _baslik(context, 'KATEGORİLER'),
              if (liste.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '"$q" ile eşleşen kategori yok.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                )
              else
                _izgara(context, [if (q.isEmpty) '', ...liste]),
            ],
          ),
        ),
      ],
    );
  }

  /// ⚠️⚠️ Başlık ÇAĞRI YERİNDE büyük yazılır; `toUpperCase()` KULLANILMAZ:
  ///    Dart 'i' harfini 'I'ya çevirir ve ekranda "KATEGORILER" görünürdü
  ///    (Türkçede doğrusu "KATEGORİLER" — emülatörde görüldü).
  Widget _baslik(BuildContext c, String metin) => Padding(
        padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 10),
        child: Text(
          metin,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );

  /// ⚠️ `shrinkWrap` + `NeverScrollable`: izgara DIS `ListView`in icinde
  ///    yasiyor; kendi kaydirmasi olsaydi iki kaydirma cakisirdi.
  Widget _izgara(BuildContext c, List<String> anahtarlar) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 0),
        crossAxisCount: 4,
        crossAxisSpacing: kIzgaraAralik,
        mainAxisSpacing: kIzgaraAralik,
        // ⚠️ TURU 142 — kart **%20 KUCUK** (kullanici emri):
        //    `kKesifKutu` (78) -> `kAramaKutu` (62).
        mainAxisExtent: kAramaKutu +
            5 +
            MediaQuery.textScalerOf(c).scale(13) * 1.15 * 2,
        children: [
          for (final a in anahtarlar)
            widget.kartYapici(
                c, a, a.isEmpty ? 'Tümü' : isletmeKategorileri[a]!),
        ],
      );
}

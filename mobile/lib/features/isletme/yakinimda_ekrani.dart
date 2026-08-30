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
import '../sosyal/profil_basligi.dart' show kOnayliRengi;
import '../sosyal/hizmet_menusu.dart' show KalinIkon;
 import '../sosyal/profil_sayfasi.dart';
// ⚠️ TURU 115 — kart/olcu sabitleri kategori ekraniyla ORTAK.
import 'isletme_kart.dart' show kYanBosluk, kYaricap, kYuzeyGri, kVurgu;
// ⚠️⚠️ TURU 140 — kategori popupu ANASAYFA MENUSUYLE **AYNI OLCULERI**
//    kullanir (kullanici emri). Sabitler KOPYALANMAZ, kaynagindan import
//    edilir; biri degisince ikisi birlikte doner.
import 'isletme_listesi.dart' show kKesifKutu, kIzgaraAralik;
import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_servisi.dart' show medyaServisiProvider;
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
const double kPanelKartEn = 348;

/// ⚠️⚠️ TURU 140 — **MENU KARESI** (kullanici emri: *"yemekte isletmenin
/// orada menuler gorunsun, KARE resim alanlari kategori radus mantiginda"*).
///
/// ⚠️ Radus buradan turetilir (`kYaricap(kMenuKare)`) — kategori dairesi ve
///    kart dugmeleriyle AYNI dil.
/// ⚠️ 56 dp: dort kare + 3x6 aralik = 242 dp, kartin 328 dp'lik icerik
///    genisligine RAHAT siger; buyugu kart boyunu gereksiz uzatirdi.
const double kMenuKare = 56;

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
 {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#26402f"}]},
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
  const YakinimdaEkrani({super.key, this.kategori = ''});

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
  /// ⚠️ `ValueNotifier` DEGIL duz alan: notifier `dispose` gerektirir ve bu
  ///    ekranda `dispose` YOK; sizinti riskini bir sayi icin almiyoruz.
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

  /// ⚠️⚠️⚠️ TURU 140 — **MENU GORSELLERI** (kullanici emri: *"yemekte
  ///	isletmenin orada MENULER gorunsun, KARE resim alanlari kategori
  ///	radus mantiginda"* + *"oradaki menuleri DIGER ISLETMELERDE de menu
  ///	resmi olarak koyabilirsin"*).
  ///
  /// ⚠️⚠️ **YALNIZ `demo-` KAYITLARDA.** Gercek isletmenin menu gorseli
  ///	istemcide YOK: `/yakinimda` yaniti urun ADI ya da GORSELI tasimaz
  ///	(yalnizca `urunSayisi` + `minFiyatKurus`), ve kart basina
  ///	`GET /users/{id}/urunler` cagirmak seritte **12 EK ISTEK** +
  ///	her gorsel icin ayrica `/media/{id}/url` demek olurdu (turu 17'de
  ///	kapatilan N+1). Gercek kayitta eskisi gibi METIN cipleri cizilir.
  /// ⏳ **BEKLEYEN (sunucu isi):** `/yakinimda` yanitina isletme basina
  ///	3-4 urun ozeti (ad + fiyat + media_id) eklenirse gercek isletmeler
  ///	de menu gorseli gosterebilir. Bu bir ARAYUZ turu oldugu icin uca
  ///	DOKUNULMADI.
  static const _ornekMenu = <String>[
    'assets/marka/menu_bigmac.png',
    'assets/marka/menu_tavuk.png',
    'assets/marka/menu_cheeseburger.png',
    'assets/marka/menu_patates.png',
  ];

  /// ⚠️ Kaydirma (derece) ve mesafe TABLOSU: dorduncu kart en uzakta.
  ///    Boylamda `cos(enlem)` uygulanmaz — bunlar OLCUM DEGIL yer tutucu.
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
    final adlar = _ornekAdlar[_kategori];
    if (adlar == null) return const [];
    final cikti = <IsletmeOzet>[];
    for (var i = 0; i < adlar.length && i < _ornekOfset.length; i++) {
      final o = _ornekOfset[i];
      final e = IsletmeOzet(
        id: 'demo-harita-$_kategori-$i',
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
    return kaynak.where((i) {
      // ⚠️ TURU 137 — metin suzgeci KALKTI (arama kutusu kaldirildi).
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
  void initState() {
    super.initState();
    _yukle();
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
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
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
        return;
      }
      final l = await svc.yakinimda(
        enlem: k.enlem,
        boylam: k.boylam,
        km: _km,
        kategori: _kategori,
      );
      if (!mounted || nesil != _nesil) return;
      setState(() {
        _konum = k;
        _liste = l;
        _yukleniyor = false;
      });
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
    final cipler = _yuzenCipler();
    return Scaffold(
      // ⚠️ AppBar YOK: harita durum cubugunun ALTINA girer (Yandex boyle).
      //    Dugmeler `MediaQuery.paddingOf(context).top` ile guvenli alana
      //    konumlanir.
      body: Stack(
        children: [
          Positioned.fill(
            child: _HaritaAlani(
                merkez: _konum,
                isletmeler: _gorunen,
                yukleniyor: _yukleniyor,
                // ⚠️ TEK KAYNAK: panel yuksekligi neyse harita da onu
                //    bilir; sabit bir sayi yazilsaydi ikisi AYRISIRDI.
                altDolgu: _panelBoy(context),
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
          // ⚠️ TURU 139 — yuzen suzgec seridi panelin 10 px USTUNDE
          //    (kullanici emri). Panelden SONRA cizilir ki panel yukari
          //    genislediginde serit onun ustunde kalsin.
          if (cipler != null) cipler,
        ],
      ),
    );
  }

  double _panelBoy(BuildContext context) {
    final o = MediaQuery.textScalerOf(context);
    final alt = MediaQuery.paddingOf(context).bottom;
    // ⚠️⚠️⚠️ TURU 137 — HESAP GUNCELLENDI:
    //	· arama kutusu (48+10) **CIKTI** (kullanici emri),
    //	· kategori seciliyken ISLETME SERIDI (+12) **GIRDI**,
    //	· serit varken ULASIM KARTLARI cizilmiyor (bkz. `_altPanel`).
    //	Duzen: 12 (ust dolgu) + cip(40) + 12 [+ serit + 12] + ayrac(1)
    //	       + 12 + [ulasim] + 12 (alt dolgu) + guvenli alan
    // ⚠️ **BU HESAP GOVDEYLE BIREBIR OLMAK ZORUNDA**: harita dolgusu,
    //    yuzen cip seridi ve secili-isletme karti hep buradan konumlaniyor.
    //    Ayrisirsa kartlar panelin ALTINDA kalir (turu 132'de yasandi).
    final seritVar = !_kategori.isEmpty && !_yukleniyor && _gorunen.isNotEmpty;
    final serit = seritVar ? _seritBoy(context) + 12 : 0.0;
    final ulasim = seritVar ? 0.0 : o.scale(11.5) * 1.2 + 34 + 12;
    // ⚠️⚠️ **HATA SATIRI DA SAYILIR** (emulatorde goruldu): konum
    //	alinamayinca panele iki satirlik bir uyari + "Tekrar dene"
    //	dugmesi giriyor ve panel UZUYOR. Hesaba katilmazsa ustte yuzen
    //	filtre seridi panelin ALTINDA kalir (kayboldu sanilir).
    // ⚠️ 48 dp: iki satirlik metin ile TextButton`un buyugu.
    final hataBoy = _hata == null ? 0.0 : o.scale(13) * 1.35 * 2 + 6;
    return 12 + 40 + 12 + serit + 1 + 12 + ulasim + 12 + hataBoy + alt;
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
  Widget _altPanel() {
    final alt = MediaQuery.paddingOf(context).bottom;
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

  /// Panelin govdesi — **koyu temanin ALTINDAKI** context ile cizilir.
  Widget _panelGovde(BuildContext context, double alt) {
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
          padding: EdgeInsets.fromLTRB(0, 12, 0, 12 + alt),
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
              // ── KATEGORILER ──
              _hizliCipler(context),
              const SizedBox(height: 12),
              // ── ISLETME KARTLARI (kategori seciliyken) ──
              // ⚠️⚠️⚠️ TURU 137 — kullanici emri: *"otele tikladigimda ...
              //	sirket kartlari DIREKT gelecek"*. Serit `_panelSeridi`de
              //	kuruluyor; `null` ise (Tümü / yukleniyor / bos) BURAYA
              //	HICBIR SEY girmez ve panel de o kadar kisalir.
              if (serit != null) ...[
                serit,
                const SizedBox(height: 12),
              ],
              // ── INCE AYRAC ──
              // ⚠️ Kullanici emri: *"onun altinda hafif ince cizgi"*.
              Divider(
                height: 1,
                thickness: 1,
                color: tema.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 12),
              // ── ULASIM ──
              // ⚠️⚠️ TURU 137 — **SERIT VARKEN ULASIM KARTLARI CIZILMEZ.**
              //	Ikisi birden 360x640'ta paneli ~330 dp'ye cikariyor ve
              //	geriye haritaya ~240 dp kaliyordu; kullanici "yakinimda"
              //	ekraninda HARITAYI goremez olurdu. Kategori secilince
              //	ekranin konusu O KATEGORIDIR; ulasim kisayollari
              //	"Tümü"de (ve kategori birakilinca) geri gelir.
              // ⚠️ YAPMA: ikisini ayni anda cizmeye donme — once 360 dp'de OLC.
              if (serit == null) _ulasimKartlari(context),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ **ULASIM KARTLARI** (kullanici emri: *"otobus tren taksi uber
  ///	kartlari olsun"*).
  ///
  /// ⚠️⚠️ **DURUST SINIR — TOPLU TASIMA VERISI YOK.** Projede otobus hatti,
  ///	sefer saati ya da tren tarifesi HICBIR YERDE tutulmuyor (resmi
  ///	kaynak + ayri entegrasyon ister; CLAUDE.md turu 96t`de bilerek
  ///	kapsam disi birakildi).
  ///	· Otobüs / Tren -> veri YOK; karta dokununca DURUSTCE soylenir.
  ///	· Taksi -> kayitli `hizmet` isletmelerini haritada gosterir
  ///	  (arama kisayolu; turu 124 deseni).
  ///	· Uber  -> cihazdaki UYGULAMAYI/siteyi acar (bizim verimiz degil).
  /// ⚠️ YAPMA: bu kartlara gomulu/sahte sefer listesi yazma.
  Widget _ulasimKartlari(BuildContext c) {
    final onRenk = Theme.of(c).colorScheme.onSurface;
    Widget kart(IconData ikon, String ad, Color renk, VoidCallback bas) =>
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: bas,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(ikon, size: 17, color: renk),
                ),
                const SizedBox(height: 5),
                Text(
                  ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: onRenk.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        );
    void veriYok(String ne) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$ne sefer bilgisi henüz bağlı değil')),
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
      child: Row(
        children: [
          kart(
            LucideIcons.busFront,
            'Otobüs',
            const Color(0xFF3AA9FF),
            () => veriYok('Otobüs'),
          ),
          kart(
            LucideIcons.trainFront,
            'Tren',
            const Color(0xFF8B3FFF),
            () => veriYok('Tren'),
          ),
          // ⚠️ Taksi GERCEK bir sey yapar: kayitli `hizmet` isletmelerini
          //    haritada gosterir (turu 124 deseni).
          kart(
            LucideIcons.carTaxiFront,
            'Taksi',
            const Color(0xFFFFC531),
            () => _kategoriSec('hizmet'),
          ),
          kart(
            LucideIcons.car,
            'Uber',
            const Color(0xFF2BB673),
            _uberAc,
          ),
        ],
      ),
    );
  }

  /// ⚠️ Uber BIZIM verimiz degil: cihazdaki uygulama varsa o, yoksa site.
  /// ⚠️ `mode` ONEMLI: `externalApplication` uygulamayi tercih eder;
  ///    varsayilan mod iOS`ta uygulama ici tarayicida acardi.
  /// ⚠️ Acilamazsa SESSIZ KALINMAZ — kullaniciya soylenir.
  Future<void> _uberAc() async {
    final adres = Uri.parse('https://m.uber.com/');
    var oldu = false;
    try {
      oldu = await launchUrl(adres, mode: LaunchMode.externalApplication);
    } catch (_) {
      oldu = false;
    }
    if (!oldu && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Uber açılamadı')),
        );
    }
  }
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
    if (_kategori.isEmpty || _yukleniyor) return null;
    final l = [..._gorunen]
      ..sort((a, b) {
        final ak = a.km <= 0 ? double.infinity : a.km;
        final bk = b.km <= 0 ? double.infinity : b.km;
        return ak.compareTo(bk);
      });
    if (l.isEmpty) return null;
    final ogeler = l.take(kPanelSeritTavan).toList();
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
    final o = MediaQuery.textScalerOf(c);
    // ⚠️ Sol daire 46 dp; ad(15)+2+meta(12) daha uzun olabilir (olcek 2.0).
    //    Ikisinin BUYUGU alinir — `Row` zaten en uzun cocugu kadar olur.
    final ust = math.max(46.0, o.scale(15) * 1.25 + 2 + o.scale(12) * 1.25);
    final ham = 12 + ust + 10 + _altSatirBoy(c) + 12;
    // ⚠️⚠️ **+1 dp PAY ZORUNLU** — emulatorde OLCULDU: paysiz hesapta
    //	*"RenderFlex overflowed by 0.800 pixels"* cikti. Flutter satir
    //	kutusunu yukari yuvarlar; `fontSize * height` carpimi gercek
    //	yuksekligi TAM vermez.
    // ⚠️ YAPMA: payi kaldirma.
    return ham.ceilToDouble() + 1;
  }

  /// Kartin ALT SATIRININ yuksekligi — **TEK KAYNAK**.
  ///
  /// ⚠️ `_seritBoy` ve `_altSatir` IKISI DE bunu okur; ayri ayri
  ///    hesaplansalardi biri degisince oteki geride kalir ve kart ya tasar
  ///    ya altta bos bir serit birakirdi (turu 139'da bu drift vardi).
  /// ⚠️⚠️ **KOSUL `_altSatir` ILE BIREBIR AYNI OLMAK ZORUNDA.** Onceden
  ///	burasi yalniz `_menuluSerit`e, `_altSatir` ise
  ///	`_menuluSerit && ornek`e bakiyordu: YEMEK kategorisinde GERCEK bir
  ///	isletme geldiginde 56 dp ayrilip 25 dp cizilir ve kartin altinda
  ///	~31 dp BOSLUK kalirdi.
  /// ⚠️ Karar SERIT GENELINDE verilir (`_menuluKume`): serit TEK yukseklik
  ///    tasir, kart basina karar verilseydi ayni seritte iki farkli kart
  ///    boyu olurdu.
  double _altSatirBoy(BuildContext c) => _menuluKume
      ? kMenuKare
      : MediaQuery.textScalerOf(c).scale(11) * 1.2 + 12;

  /// Bu seritte menu kareleri cizilecek MI (serit genelinde tek karar).
  ///
  /// ⚠️ Menu gorselleri YALNIZ ornek kayitlarda var (gercek isletmenin urun
  ///    gorseli `/yakinimda` yanitinda YOK — bkz. `_ornekMenu` serhi).
  bool get _menuluKume =>
      _menuluSerit && _gorunen.any((o) => o.id.startsWith('demo-'));

  /// Bu seritte MENU KARELERI mi cizilecek?
  ///
  /// ⚠️ Serit TEK kategori gosterir, yani karar serit genelinde AYNI olur
  ///    ve kart yukseklikleri tutarli kalir.
  /// ⚠️ Kullanici emri: *"simdilik YEMEK icin yapalim"*.
  bool get _menuluSerit => _kategori == 'yemek';

  /// ⚠️⚠️⚠️ TURU 139/140 — **SERITTEKI ISLETME KARTI**.
  ///
  ///	turu 139 (kullanici tarifi): solda kategori dairesi · saginda ad ·
  ///	altinda yildiz/mesafe · sagda profil + harita ikonlari · altinda
  ///	urunler.
  ///	turu 140 (kullanici emri: *"kartlari genislet, isletme kartlarinda
  ///	HARITANIN SOLUNA TELEFON IKONU koy, yemekte isletmenin orada
  ///	MENULER gorunsun"*): kart **300 -> `kPanelKartEn` (348)**, sagda
  ///	UC dugme (telefon · profil · harita) ve alt satirda MENU KARELERI.
  ///
  /// ⚠️⚠️ **GENISLIK BUTCESI OLCULDU:** icerik = kart - 20 dolgu. Ust
  ///	satirdaki SABIT ogeler: 46 (logo) + 10 + 8 + 3x36 + 2x6 = 184 dp.
  ///	Kart 300'de kalsaydi ada+metaya 96 dp kalirdi ve "Domino's Pizza"
  ///	bile ellipsis'e girerdi; 348'de 144 dp kaliyor (turu 139'daki
  ///	138 dp'nin biraz USTU).
  /// ⚠️⚠️ **KAPAK GORSELI YOK**: kullanicinin tarif ettigi duzende yer
  ///	almiyor ve ornek kayitlarin cogunun kapagi bos oldugu icin serit
  ///	bos gri kutularla doluyordu (turu 139 karari).
  /// ⚠️ **KART GOVDESINE DOKUNMAK HARITAYA ODAKLANIR** (kullanici emri).
  ///    Profil SAGDAKI dugmeden acilir — iki eylem AYRI.
  Widget _panelKarti(BuildContext c, IsletmeOzet o) {
    final scheme = Theme.of(c).colorScheme;
    final ornek = o.id.startsWith('demo-');
    final meta = [
      if (o.puan != null) '${o.puan!.toStringAsFixed(1).replaceAll('.', ',')} ★',
      if (o.mesafeMetni.isNotEmpty) o.mesafeMetni,
      if (ornek) 'Örnek',
    ].join(' · ');
    return SizedBox(
      width: kPanelKartEn,
      child: Material(
        color: kYuzeyGri(c),
        borderRadius: BorderRadius.circular(kYaricap(96)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // ⚠️ Kullanici emri: kart govdesi HARITAYA gider.
          onTap: () => _haritadaGoster(o),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _kartLogosu(c, o, ornek),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  o.ad,
                                  maxLines: 1,
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
                                  padding: EdgeInsets.only(left: 4),
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
                    const SizedBox(width: 8),
                    // ── SAGDA UC EYLEM ──
                    // ⚠️ TURU 140 — telefon HARITANIN SOLUNA (kullanici emri);
                    //    sira: telefon · profil · harita.
                    _kartDugmesi(c, LucideIcons.phone, 'Ara', () => _ara(o)),
                    const SizedBox(width: 6),
                    _kartDugmesi(
                      c,
                      LucideIcons.circleUser,
                      'Profil',
                      () => _isletmeAc(o),
                    ),
                    const SizedBox(width: 6),
                    _kartDugmesi(
                      c,
                      LucideIcons.map,
                      'Haritada göster',
                      () => _haritadaGoster(o),
                    ),
                  ],
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

  /// Kartin sol dairesi — ORNEK kayitta **MARKA LOGOSU**, digerlerinde
  /// kategori ikonu.
  ///
  /// ⚠️ Logo `BoxFit.cover` ile daireye kirpilir: McDonald's/Domino's
  ///    gorselleri kare ve KENARINA KADAR renkli, `contain` ile konsaydi
  ///    yanlarda bos bant kalirdi.
  /// ⚠️ Burger King logosu SAYDAM zeminlidir (olculdu: en dusuk alfa 0);
  ///    `kAiKartYuzey` zemini onun arkasindan gorunur ve dogru durur.
  /// ⚠️⚠️ **POPEYES LOGOSU YOK** (kullanici klasore koymadi) — o kayit
  ///	sessizce kategori ikonuna duser. Sahte logo URETILMEDI.
  Widget _kartLogosu(BuildContext c, IsletmeOzet o, bool ornek) {
    final yol = ornek ? _ornekLogo[o.ad] : null;
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
      child: yol == null
          ? Icon(_kategoriIkonu(o.kategori), size: 22, color: kVurgu(c))
          : Image.asset(
              yol,
              // ⚠️⚠️ `contain`: logolar KARE DEGIL — burgerking 500x545
              //	(1:1,09). `cover` onu ustten/alttan KIRPARDI. Kare olan
              //	ikisi (mcdonalds 720x720, dominos 512x512) `contain` ile
              //	de daireyi TAM doldurur; BK'nin saydam zemini arkasindan
              //	`kAiKartYuzey` gorunur.
              fit: BoxFit.contain,
              width: 46,
              height: 46,
              // ⚠️ Ham cozunurluk 720x720 = ~2,1 MB RAM; 46 dp'lik kutu
              //    icin gereksiz (turu 91 `memCacheWidth` dersi).
              cacheWidth: (46 * MediaQuery.devicePixelRatioOf(c)).round(),
            ),
    );
  }

  /// Kartin ALT SATIRI: menu kareleri (yemek) ya da urun cipleri.
  /// ⚠️ Kosul `_altSatirBoy` ile BIREBIR: `_menuluKume` serit genelinde
  ///    karar verir, `ornek` ise o KAYITTA gorsel olup olmadigini soyler.
  ///    Menusuz bir kayit menulu seritte urun ciplerini cizer ve fazla yer
  ///    KALIR — ama kart boyu SABIT kaldigi icin serit hizali durur.
  Widget _altSatir(BuildContext c, IsletmeOzet o, bool ornek) =>
      _menuluKume && ornek ? _menuKareleri(c) : _urunSeridi(c, o);

  /// ⚠️⚠️⚠️ TURU 140 — **MENU KARELERI** (kullanici emri: *"yemekte
  ///	isletmenin orada menuler gorunsun, KARE resim alanlari KATEGORI
  ///	RADUS MANTIGINDA"*).
  ///
  /// ⚠️ Radus `kYaricap(kMenuKare)` — kategori dairesi ve dugmelerle AYNI
  ///    dil (sabit bir sayi YAZILMADI).
  /// ⚠️ Yatay kaydirilir: dort kare + aralik, 348 dp'lik kartin icerik
  ///    genisligine (328) sigar ama yazi olcegi buyudugunde kart daralmaz,
  ///    kareler sabit kalir — tasma yerine KAYDIRMA olur.
  /// ⚠️ Gorseller PAKETLENMIS varlik (`_ornekMenu`); ag istegi YOK.
  Widget _menuKareleri(BuildContext c) => SizedBox(
        height: kMenuKare,
        // ⚠️⚠️ `ListView` DEGIL `Row`: ic ice yatay kaydirma, kartin alt
        //	yarisindaki suruklemeyi ICTEKI listeye verir ve DIS isletme
        //	seridi kaymaz. Dort kare (242 dp) kartin 328 dp'lik icerigine
        //	yapisal olarak siger, yani kaydirmaya GEREK YOK.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _ornekMenu.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(kYaricap(kMenuKare)),
                child: Image.asset(
                  _ornekMenu[i],
                  width: kMenuKare,
                  height: kMenuKare,
                  fit: BoxFit.cover,
                  // ⚠️ Cozunurluk EKRAN YOGUNLUGUNDAN turetilir: ham 200 px'lik
                  //    gorseli 56 dp'lik kutu icin tam cozmek gereksiz RAM
                  //    demekti (turu 91 dersi).
                  cacheWidth:
                      (kMenuKare * MediaQuery.devicePixelRatioOf(c)).round(),
                ),
              ),
            ],
          ],
        ),
      );

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
        padding: EdgeInsets.zero,
        itemCount: etiketler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(kYaricap(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
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

  /// Kisa bilgi satiri (tek kaynak).
  void _mesaj(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  /// Profili acar — ORNEK kayitta durustce soyler.
  ///
  /// ⚠️ TEK KAYNAK: serit karti, kart govdesi ve harita pin karti AYNI yolu
  ///    kullanir; ayri ayri yazilsaydi biri ornek kapisini unuturdu.
  void _isletmeAc(IsletmeOzet o) {
    if (o.id.startsWith('demo-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu bir örnek kayıt — gerçek işletme değil.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfilSayfasi(userId: o.id)),
    );
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
  Widget _hizliCipler(BuildContext c) {
    final ogeler = <Widget>[
      _kategoriDugmesi(c),
      for (final g in _haritaKategorileri)
        _cip(
          c,
          isletmeKategorileri[g]!,
          _kategori == g,
          // ⚠️ TOGGLE: secili cipe tekrar dokunmak kategoriyi BIRAKIR.
          () => _kategoriSec(_kategori == g ? '' : g),
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
  Widget _kategoriDugmesi(BuildContext c) {
    final vurgu = kVurgu(c);
    final notr = Theme.of(c).colorScheme.onSurface;
    final secili = _kategori.isNotEmpty;
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
    final secim = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // ⚠️ Zemin kardesleriyle (panel · filtre ekrani) AYNI siyah.
      backgroundColor: kAiZemin,
      builder: (c) => FractionallySizedBox(
        heightFactor: 0.95,
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
            //    emri) `ThemeData.dark()` ile SIFIRLANIYORDU; acikca geri
            //    konur.
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          // ⚠️⚠️ `Builder` ZORUNLU: `_popupKarti` EKRANIN metodu ve
          //	kendisine verilen context'i kullaniyor; `Theme`in ALTINDAN
          //	gelmezse kartlar UYGULAMANIN temasini cozer (turu 136/138).
          // ⚠️⚠️ **`Material` SARMALI ZORUNLU** (turu 129 dersi, burada da
          //	OLCULDU): `Theme` tek basina renk BELIRTMEYEN `Text`leri
          //	beyaza cevirmez — `DefaultTextStyle`i `Material` saglar ve
          //	sheet'in kendi `Material`i bu `Theme`in USTUNDE kaliyor.
          //	Sarmalsiz haliyle siyah popupta kategori adlari SILIK GRI
          //	cikiyordu (emulatorde goruldu).
          child: Material(
            type: MaterialType.transparency,
            child: Builder(
              builder: (tc) => SafeArea(
                top: false,
              // ⚠️ Secili isareti `_popupKarti` icinde `_kategori` ile
              //    veriliyor; popupa AYRICA gecirmek olu parametre olurdu.
                child: _KategoriPopup(
                  kartYapici: (_, anahtar, ad) =>
                      _popupKarti(tc, anahtar, ad),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || secim == null) return;
    _kategoriSec(secim);
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
  Widget _popupKarti(BuildContext c, String anahtar, String ad) {
    final secili = _kategori == anahtar;
    final vurgu = kVurgu(c);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(c).pop(anahtar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            // ⚠️ TEK KAYNAK: anasayfa menusunun kutu olcusu.
            height: kKesifKutu,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kAiKartYuzey(c),
                borderRadius: BorderRadius.circular(kYaricap(kKesifKutu)),
                border: secili ? Border.all(color: vurgu, width: 1.6) : null,
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
            height: MediaQuery.textScalerOf(c).scale(14) * 1.15 * 2,
            child: Center(
              child: Text(
                ad,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
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
  Widget _filtreSatiri() {
    final ticari = _kategori.isEmpty ||
        const {'yemek', 'kafe', 'market'}.contains(_kategori);
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
  Widget _yuzenCip(
      String etiket, bool secili, IconData ikon, VoidCallback bas) {
    final vurgu = kVurgu(context);
    // ⚠️⚠️⚠️ **ON PLAN DOLGUDAN TURETILIR — SABIT BEYAZ YAZMA.**
    //	`kVurgu` KOYU temada `Colors.white` dondurur. Secili cipin zemini
    //	`vurgu` ile doldugunda yazi/ikon sabit beyaz kalsaydi **beyaz
    //	uzerine beyaz (1,00:1)** cizilir ve cip TAMAMEN OKUNMAZ olurdu
    //	(turu 139'dan kalma, uygulama koyu temadayken).
    final dolgu =
        secili ? vurgu : Colors.black.withValues(alpha: kHaritaDugmeAlfa);
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
  Widget? _yuzenCipler() {
    if (_kategori.isEmpty) return null;
    return Positioned(
      left: 0,
      right: 0,
      // ⚠️ Kullanici emri: **panelin 10 px ustunde**.
      bottom: _panelBoy(context) + 10,
      child: _filtreSatiri(),
    );
  }

  /// ⚠️ Kategori degisince suzgecler KALIR ama liste SUNUCUDAN yeniden
  ///    cekilir (kategori sunucu tarafinda suzuluyor).
  void _kategoriSec(String k) {
    if (_kategori == k) return;
    setState(() => _kategori = k);
    _yukle();
  }

  static IconData _kategoriIkonu(String k) => switch (k) {
        'yemek' => LucideIcons.utensils,
        'kafe' => LucideIcons.coffee,
        'market' => LucideIcons.shoppingCart,
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
                child: KalinIkon(ikon: ikon, boy: 21, renk: Colors.white),
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
            // ⚠️ TURU 132 — `locateFixed` -> `navigation` (kullanici emri).
            LucideIcons.navigation,
            'Konumuma dön',
            // ⚠️ Konum TAZELENIR (`konumuTazele: true`): kullanici baska
            //    semte gecmis olabilir ve eski koordinatla ayni listeyi
            //    gormek "calismiyor" izlenimi verir.
            _yukleniyor ? () {} : () => _yukle(konumuTazele: true),
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

  Widget _cip(
    BuildContext c,
    String etiket,
    bool secili,
    VoidCallback onTap, {
    IconData? ikon,
  }) {
    final vurgu = kVurgu(c);
    final notr = Theme.of(c).colorScheme.onSurface;
    // ⚠️⚠️⚠️ TURU 140 — **AKTIF CIPTE IKON KUTUSU BEYAZ, IKON KUTU RENGI**
    //	(kullanici emri: *"aktif olanda ikon arkasi BEYAZ, ikon arka kare
    //	daire rengi olsun"*).
    //
    // ⚠️⚠️ Ikona `kAiKartYuzey(c)` VERILEMEZ: o deger **%12 alfali** bir
    //	renktir ve beyaz zeminde neredeyse GORUNMEZ olur. Kutunun rengini
    //	besleyen TAM OPAK kaynak `colorScheme.primary` — ikon onu alir.
    //	(`kAiKartYuzey` zaten `primary.withValues(alpha: .12)`.)
    // ⚠️ Panel ZORLA koyu tema kullandigi icin buradaki `primary` acik bir
    //    lavantadir; beyaz uzerinde okunur.
    final kutuZemin = secili ? Colors.white : kAiKartYuzey(c);
    // ⚠️⚠️ **OLCULDU: ciplak `primary` BEYAZDA 1,70:1 ile GORUNMUYORDU.**
    //	Panel zorla koyu tema kuruyor ve oradaki `primary` M3 tone-80,
    //	yani ACIK bir lavanta. Kullanicinin "ikon arka kare daire rengi
    //	olsun" dedigi renk, kutunun EKRANDA CIZILEN hali: `kAiKartYuzey`
    //	(primary %12) `kAiZemin` uzerine BIRLESMIS koyu mor-gri.
    // ⚠️ YAPMA: buraya ciplak `colorScheme.primary` geri koyma.
    final ikonRenk = secili
        ? Color.alphaBlend(kAiKartYuzey(c), kAiZemin)
        : notr;
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
                    //	olculmustu). Aktif ayrimi artik IKON KUTUSUNUN
                    //	BEYAZ olmasiyla tasiniyor — daha guclu bir sinyal.
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
  });

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

  /// ⚠️ TURU 124 — KENDI konum isaretimiz (Google`in mavi noktasi yerine).
  BitmapDescriptor? _benPin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠️ `MediaQuery` BURADA okunur, `initState`te DEGIL: orada
    //    `devicePixelRatio` henuz erisilebilir degil.
    unawaited(_pinUret());
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
    final hedef = (26 * oran).ceil();
    try {
      final saglayici = ResizeImage(NetworkImage(adres), width: hedef);
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
    if (!mounted) return;
    setState(() {
      _pin = d;
      _benPin = b;
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
              GoogleMap(
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
                markers: {
                  // ⚠️⚠️ TURU 124 — KENDI KONUMUMUZ (mor). Google`in mavi
                  //	noktasi kapatildigi icin bu marker olmazsa kullanici
                  //	haritada NEREDE oldugunu goremezdi.
                  // ⚠️ Isaret hazir degilse (uretim asenkron) marker HIC
                  //    cizilmez: varsayilan KIRMIZI damla, "benim konumum"
                  //    icin yanlis bir dil olurdu.
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
                  for (final i in isletmeler)
                    if (i.enlem != 0 || i.boylam != 0)
                      Marker(
                        markerId: MarkerId(i.id),
                        position: LatLng(i.enlem, i.boylam),
                        // ⚠️⚠️ TURU 115 — **DAIRE PIN** (kullanici emri:
                        //    *"pinler daire seklinde, border acik renk"*).
                        //    `_pin` null iken varsayilan damla cizilir:
                        //    uretim asenkron ve ilk karede hazir olmayabilir.
                        icon: _pin ?? BitmapDescriptor.defaultMarker,
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

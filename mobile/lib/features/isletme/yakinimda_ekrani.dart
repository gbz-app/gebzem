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
    'hizmet': [
      (ad: 'Ev Temizliği', fiyat: '900 ₺'),
      (ad: 'Nakliyat', fiyat: '2.500 ₺'),
      (ad: 'Tesisat', fiyat: '650 ₺'),
    ],
  };

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
    super.dispose();
  }

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
    final cipler = _yuzenCipler();
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
            // ⚠️⚠️ TURU 144 — kullanici emri: *"birde DURAK ekle dostum,
            //	otobus hatti vs saat SANA BIRAKIYORUM"*. Acilan sayfa
            //	ORNEK hatlari gosterir ve bunu ACIKCA soyler.
            () => unawaited(_durakPopupAc()),
          ),
          const SizedBox(width: 8),
          // ⚠️ `LucideIcons.fuel` — menudeki hizli erisimle AYNI ikon
          //    (turu 128); iki yerde farkli ikon olmasin.
          kart(LucideIcons.fuel, 'Benzinlik', const Color(0xFFFFC531),
              () => _kisayol('akaryakit')),
          const SizedBox(width: 8),
          kart(LucideIcons.carTaxiFront, 'Taksi', const Color(0xFFFF7A3C),
              () => _kisayol('hizmet')),
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
  Future<void> _durakPopupAc() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: kAiZemin,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (c) => FractionallySizedBox(
        heightFactor: 0.70,
        child: Theme(
          data: _koyuTema(),
          child: Material(
            type: MaterialType.transparency,
            child: Builder(
              builder: (tc) {
                final scheme = Theme.of(tc).colorScheme;
                const hatlar = [
                  (ad: 'Merkez – Sanayi', yon: 'Merkez yönü', dk: '5 dk'),
                  (ad: 'İstasyon – Çayırova', yon: 'İstasyon yönü', dk: '12 dk'),
                  (ad: 'Merkez – Üniversite', yon: 'Üniversite yönü', dk: '24 dk'),
                ];
                return SafeArea(
                  top: false,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        kYanBosluk, 0, kYanBosluk, 16),
                    children: [
                      const Text(
                        'Durak',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ⚠️ DURUST SINIR EN USTTE: kullanici asagi inmeden
                      //    bunun ornek oldugunu gormeli.
                      Text(
                        'Durak ve sefer verisi henüz bağlı değil. Aşağıdakiler '
                        'yalnızca örnektir.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: scheme.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final h in hatlar)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: kAiKartYuzey(tc),
                              borderRadius: BorderRadius.circular(kYaricap(64)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          h.ad,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.25,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${h.yon} · Örnek',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.25,
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.62),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    h.dk,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
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
  double _kartUstBoy(BuildContext c) => math.max(
        46.0,
        _kartAdBoy(c) + 2 + MediaQuery.textScalerOf(c).scale(12) * 1.25,
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
  bool get _menuluSerit => _ornekVitrin.containsKey(_dal);

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
  Widget _altSatir(BuildContext c, IsletmeOzet o, bool ornek) =>
      _menuluKume && ornek ? _vitrinSeridi(c, o) : _urunSeridi(c, o);

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

  /// ⚠️ TURU 142 — marka adi -> logolu pin. Bos kalirsa kayit normal pine
  ///    duser (`_pin`), yani ozellik FAIL-SAFE'tir.
  final Map<String, BitmapDescriptor> _markaPin = {};

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

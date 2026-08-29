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
import '../../core/theme.dart' show morLogo;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart'
    show EagerGestureRecognizer, OneSequenceGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'yakinimda_arama.dart';

// ⚠️ TURU 88 — YenileSarmali ARTIK KULLANILMIYOR: ekran dikey kaydirilmiyor
//    (harita %70 + yatay kart seridi), asagi-cek jesti YOK. Yenileme
//    AppBar dugmesine tasindi.
// ⚠️ TURU 89 — harita rengi tercihi (Ayarlar > Harita).
import '../../core/tercihler.dart';
import '../medya/konum_servisi.dart';
// ⚠️ TURU 136 — haritada secili isletme kartinin kapak gorseli ve onay
//    rozeti; ikisi de kategori ekraniyla AYNI bilesenler (kopya YOK).
import '../medya/medya_gorsel.dart' show MedyaGorsel;
import '../sosyal/profil_basligi.dart' show kOnayliRengi;
import '../sosyal/profil_sayfasi.dart';
// ⚠️ TURU 115 — kart/olcu sabitleri kategori ekraniyla ORTAK.
import 'isletme_kart.dart' show kYanBosluk, kYaricap, kYuzeyGri, kVurgu;
import 'harita_daire_pin.dart';
import 'isletme_servisi.dart';

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
String haritaStiliSec(String tercih, Brightness parlaklik) => switch (tercih) {
  'gri' => _haritaGri,
  'gece' => _haritaGece,
  // 'sistem' (ve bilinmeyen her deger) -> temaya uy.
  _ => parlaklik == Brightness.dark ? _haritaGece : _haritaStili,
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

  /// ⚠️⚠️ TURU 115 — ALT SAYFA DURUMU (Yandex duzeni).
  final _arama = TextEditingController();
  String _q = '';

  /// Kategoriye ozel suzgecler. ⚠️ **YALNIZ SUNUCUDAN GELEN ALANLAR**:
  ///	`puan`, `min_tutar_kurus`, `kampanyalar`, `km`, `dogrulandi`.
  ///	Kullanici *"akaryakita fiyat araliklari"* dedi; akaryakit FIYATI bu
  ///	projede HICBIR YERDE YOK (ne tablo ne uc) — uydurmak yerine gercekten
  ///	sahip oldugumuz olcutler sunuluyor ve sinir alt sayfada YAZILI.
  bool _fPuan = false;      // 4+ puan
  bool _fKampanya = false;  // kampanyasi olan
  bool _fOnayli = false;    // onayli isletme
  double _fKm = 0;          // 0 = sinirsiz (sunucu yaricapi neyse o)

  /// ⚠️⚠️ TURU 136 — HARITADA SECILI ISLETME (pine dokununca kart acilir).
  /// ⚠️ Liste degisince (kategori/suzgec/yenileme) SIFIRLANIR: aksi halde
  ///    artik haritada OLMAYAN bir isletmenin karti ekranda asili kalirdi.
  IsletmeOzet? _secilen;

  /// ⚠️ TURKCE KUCULTME ELLE (Dart'in `toLowerCase()`i 'İ'yi bozar —
  ///    turu 114'te talep ekraninda ayni tuzak).
  static String _kucult(String x) =>
      x.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  /// Haritada ve listede GOSTERILEN kume.
  ///
  /// ⚠️⚠️ SUZGEC ISTEMCIDE: `/isletmeler/yakinimda` ucu `q`/puan/kampanya
  ///	parametresi ALMIYOR ve liste en fazla 60 kayit. Sunucuya parametre
  ///	eklemek ayri bir tur isi; 60 kayitta istemci suzgeci FARK EDILMEZ.
  /// ⚠️ Harita ve liste AYNI kumeyi gosterir — ayrisirsa kullanici
  ///    haritada gordugu pini listede bulamaz.
  /// ⚠️⚠️⚠️ TURU 136 — **HARITADAKI ORNEK ISLETMELER** (kullanici emri:
  ///	*"haritada mockup isletmeler koyup tikladigimda kart seklinde"*).
  ///
  ///	Canli veritabaninda koordinati OLAN isletme sayisi bir elin
  ///	parmaklarini gecmiyor; harita bu yuzden BOS gorunuyor ve tasarim
  ///	degerlendirilemiyordu. Bu kayitlar YALNIZCA tasarimi gostermek icin.
  ///
  /// ⚠️⚠️ **YAYIN ONCESI `false` YAPILACAK.** Acikken haritada GERCEK
  ///	OLMAYAN isletmeler gorunur. (Kardesi `kYakinOnizleme`,
  ///	`hizmet_menusu.dart`.)
  /// ⚠️ Kimlikler **`demo-` onekli**: karta dokunmak profil ACMAZ, durustce
  ///    "ornek kayit" der. Onek olmasaydi `ProfilSayfasi` 404 ile acilir ve
  ///    kullanici uygulamayi bozuk sanardi (turu 113'te demo gonderi
  ///    kimlikleri tam bu yuzden oneklendi).
  /// ⚠️ Konum KULLANICININ KONUMUNA GORE turetilir: sabit Gebze koordinati
  ///    yazilsaydi baska sehirdeki bir kullanici pinleri HIC goremezdi.
  static const kHaritaOnizleme = true;

  /// ⚠️ Derece cinsinden kaydirma: ~0.0009 derece enlem ≈ 100 m.
  ///    Boylamda `cos(enlem)` uygulanmaz — bu kayitlar OLCUM DEGIL, YER
  ///    TUTUCU; birkac on metrelik sapmanin gorsel bir karsiligi yok.
  List<IsletmeOzet> _ornekIsletmeler(({double enlem, double boylam}) k) {
    IsletmeOzet yap({
      required String no,
      required String ad,
      required String kategori,
      required String adres,
      required double dEnlem,
      required double dBoylam,
      required double km,
      double? puan,
      int puanSayisi = 0,
      bool onayli = false,
      List<String> kampanyalar = const [],
    }) {
      final o = IsletmeOzet(
        id: 'demo-harita-$no',
        ad: ad,
        kullaniciAdi: '',
        avatarUrl: '',
        avatarMediaId: null,
        kategori: kategori,
        il: 'Kocaeli',
        ilce: 'Gebze',
        adres: adres,
        dogrulandi: onayli,
        puan: puan,
        puanSayisi: puanSayisi,
        kampanyalar: kampanyalar,
      );
      // ⚠️ Bu ucu KURUCUDA yok (sunucu yanitindan sonra yazilir) — burada da
      //    ayni sirayi izliyoruz.
      o.enlem = k.enlem + dEnlem;
      o.boylam = k.boylam + dBoylam;
      o.km = km;
      return o;
    }

    return [
      yap(
        no: '1',
        ad: 'Köşe Fırın',
        kategori: 'yemek',
        adres: 'Hacı Halil Mah.',
        dEnlem: 0.0022,
        dBoylam: 0.0016,
        km: 0.25,
        puan: 4.6,
        puanSayisi: 128,
        onayli: true,
        kampanyalar: const ['%20 indirim'],
      ),
      yap(
        no: '2',
        ad: 'Bahar Market',
        kategori: 'market',
        adres: 'Mustafapaşa Mah.',
        dEnlem: -0.0018,
        dBoylam: 0.0027,
        km: 0.32,
        puan: 4.8,
        puanSayisi: 64,
      ),
      yap(
        no: '3',
        ad: 'Marmara Kuaför',
        kategori: 'kuafor',
        adres: 'İstasyon Cad.',
        dEnlem: 0.0035,
        dBoylam: -0.0029,
        km: 0.48,
        puan: 4.3,
        puanSayisi: 41,
      ),
      yap(
        no: '4',
        ad: 'Yıldız Eczanesi',
        kategori: 'eczane',
        adres: 'Osman Yılmaz Mah.',
        dEnlem: -0.0051,
        dBoylam: -0.0014,
        km: 0.7,
        onayli: true,
      ),
      yap(
        no: '5',
        ad: 'Teknik Oto Servis',
        kategori: 'oto',
        adres: 'Sanayi Mah.',
        dEnlem: 0.0074,
        dBoylam: 0.0061,
        km: 1.1,
        puan: 4.1,
        puanSayisi: 23,
      ),
    ];
  }


  List<IsletmeOzet> get _gorunen {
    final q = _kucult(_q);
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
      if (q.isNotEmpty &&
          !_kucult(i.ad).contains(q) &&
          !_kucult(i.kategori).contains(q) &&
          !_kucult(i.adres).contains(q)) {
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
      _q.isNotEmpty || _fPuan || _fKampanya || _fOnayli || _fKm > 0;
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

  Future<void> _yukle({bool konumuTazele = false}) async {
    if (!mounted) return;
    final nesil = ++_nesil;
    setState(() {
      _yukleniyor = true;
      _hata = null;
      // ⚠️⚠️ TURU 136 — SECIM SIFIRLANIR. Yeni kume gelince eski isletme
      //	haritada olmayabilir (kategori degisti, suzgec elendi, hata
      //	dalinda liste BOSALDI) ve karti ekranda ASILI kalirdi: kullanici
      //	haritada pinini goremedigi bir kaydin kartina bakiyor olurdu.
      _secilen = null;
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
    // ⚠️ TURU 136 — kart BIR KEZ kurulur; `null` ise yigina HIC eklenmez
    //    (bkz. `_secilenKart` serhindeki 0x0 yigin tuzagi).
    // ⚠️ Cip seridi de kosullu (bkz. `_yuzenCipler` serhi): ikisi de yigina
    //    YALNIZCA gercek bir `Positioned` olarak girer.
    final cipler = _yuzenCipler();
    final kart = _secilenKart();
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
                acildi: (i) => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: i.id)),
                ),
                // ⚠️ TURU 136 — pine dokunus KART acar (bkz. `_secilenKart`).
                secildi: (i) => setState(() => _secilen = i),
                secimKapandi: () {
                  if (_secilen != null) setState(() => _secilen = null);
                },
            ),
          ),
          _ustDugmeler(),
          // ⚠️ SIRA: cipler alt sayfanin ALTINDA cizilir ki sayfa yukari
          //    cekilince ciplerin USTUNU ortsun (Yandex/Google deseni).
          if (cipler != null) cipler,
          _altPanel(),
          // ⚠️ SIRA: kart EN SONDA — `Stack` son cocugu EN USTE cizer ve
          //    hit-test'i TERS sirada yapar. Panelin ALTINDA kalsaydi hem
          //    gorunmez hem tiklanamaz olurdu.
          // ⚠️⚠️ **KOSULLU EKLENIR (`?? kart`) — bkz. `_secilenKart` serhi:**
          //	secim yokken buraya 0x0 bir NON-POSITIONED cocuk konmasi
          //	yigini 0x0'a dusuruyor ve EKRANIN TAMAMI beyaz kaliyordu
          //	(emulatorde olculdu). Yigina yalnizca GERCEK bir `Positioned`
          //	girer.
          if (kart != null) kart,
        ],
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 132 — **ALT PANEL YENIDEN KURULDU** (kullanici emri).
  ///
  ///	*"tumu yemek bunlar mekan ve adres aramanin altinda olacak, onun
  ///	altinda hafif ince cizgi otobus tren taksi uber kartlari olsun,
  ///	alttaki seyi yukari kaldirip cekme olmayacak"*
  ///
  ///	DUZEN (yukaridan asagi):
  ///	  · arama kutusu  -> dokununca POPUP acar (liste sayfada DEGIL)
  ///	  · kategori cipleri (Tümü · Yemek · Oto ...) — sol/sag kaydirma
  ///	  · ince ayrac cizgisi
  ///	  · ulasim kartlari (Otobüs · Tren · Taksi · Uber)
  ///
  /// ⚠️⚠️ **`DraggableScrollableSheet` KALDIRILDI** (kullanici: *"yukari
  ///	kaldirip cekme olmayacak"*). Panel artik SABIT yukseklikte ve
  ///	ekranin dibine oturur.
  ///	⚠️ Bunun bedeli: panel icine UZUN bir liste konamaz — zaten
  ///	  konmuyor, arama sonuclari POPUP`ta gosteriliyor.
  ///
  /// ⚠️ Yukseklik SABIT dp DEGIL, yazi olceginden TURETILIR: olcek
  ///    1.3/2.0`da sabit bir sayi icerigi KIRPARDI.
  /// ⚠️ Alt guvenli alan (`MediaQuery.paddingOf.bottom`) EKLENIR: jest
  ///    cubugu olan cihazlarda ulasim kartlari cubugun ALTINDA kalirdi.
  /// ⚠️⚠️⚠️ TURU 136 — **HARITADA SECILI ISLETME KARTI** (kullanici emri:
  ///	*"haritada mockup isletmeler koyup TIKLADIGIMDA KART SEKLINDE"*).
  ///
  ///	Pine dokunulunca haritanin ustune, alt panelin HEMEN USTUNE cizilir.
  ///	Icerik: kapak/avatar + ad + onay rozeti + puan · mesafe + adres.
  ///
  /// ⚠️ Konum SABIT DEGIL: `_panelBoy(context)` uzerinden hesaplanir — panel
  ///    yazi olcegine gore uzuyor ve sabit bir sayi yazilsaydi kart panelin
  ///    ALTINDA kalirdi (turu 132'de yuzen cip seridinde birebir bu yasandi).
  /// ⚠️ Yukseklik SABIT DEGIL: icerikten gelir, iki metin de tek satir +
  ///    ellipsis. Yazi olcegi 2.0'da kart uzar, TASMAZ.
  /// ⚠️ ORNEK KAYITTA PROFIL ACILMAZ: `demo-` onekli kimligin arkasinda
  ///    sunucuda satir YOK; `ProfilSayfasi` 404 gosterir ve kullanici
  ///    uygulamayi bozuk sanardi. Durustce soyleniyor.
  /// ⚠️⚠️⚠️ **`Widget?` DONER — `SizedBox.shrink()` DEGIL. EMULATORDE
  ///	OLCULDU: ekranin TAMAMI BEYAZ kaliyordu.**
  ///
  ///	Ilk yazimda kart `Stack`in cocugu olarak KOSULSUZ ekleniyor, secim
  ///	yokken `SizedBox.shrink()` donuyordu. Yigindaki DIGER cocuklarin
  ///	HEPSI `Positioned`; `RenderStack` boyutunu **YALNIZCA
  ///	POSITIONED OLMAYAN** cocuklarindan hesaplar. Tek non-positioned
  ///	cocuk 0x0 olunca yigin **0x0**'a dustu ve harita, dugmeler, cipler,
  ///	panel — hepsi CIZILMEDI.
  ///	⚠️ Hata SESSIZDI: `flutter analyze` temiz, `flutter test` 52/52,
  ///	   logcat'te TEK BIR istisna yok. Yalnizca ekrana bakinca gorunur;
  ///	   bisect ile (karti yigindan cikarip yeniden derleyerek) bulundu.
  ///
  /// ⚠️ YAPMA: bu metodu tekrar `Widget` dondurup bos dalda
  ///    `SizedBox.shrink()` verme. Cagri yerindeki `if (kart != null)`
  ///    kapisi da KALMALI.
  Widget? _secilenKart() {
    final o = _secilen;
    if (o == null) return null;
    // ⚠️⚠️ **YAPISAL KAPI:** kart YALNIZ haritada PINI OLAN bir kayit icin
    //	cizilir. Suzgecler (`4+ puan`, `kampanyali`, arama) yeniden
    //	YUKLEME YAPMADAN kumeyi daraltiyor; o dallara tek tek "secimi
    //	sifirla" yazmak yerine olcut BURADA, tek yerde. Aksi halde
    //	kullanici pini kaybolmus bir isletmenin kartina bakardi.
    // ⚠️ YAPMA: bu kontrolu kaldirip yalniz `_yukle` icindeki sifirlamaya
    //    guvenme — suzgecler `_yukle` CAGIRMIYOR.
    if (!_gorunen.any((i) => i.id == o.id)) return null;
    final scheme = Theme.of(context).colorScheme;
    final gorselID = (o.kapakMediaId != null && o.kapakMediaId!.isNotEmpty)
        ? o.kapakMediaId!
        : (o.avatarMediaId ?? '');
    final ornek = o.id.startsWith('demo-');
    final alt = [
      if (o.puan != null) '${o.puan!.toStringAsFixed(1).replaceAll('.', ',')} ★',
      if (o.mesafeMetni.isNotEmpty) o.mesafeMetni,
      if (o.adres.isNotEmpty) o.adres,
    ].join(' · ');
    return Positioned(
      left: kYanBosluk,
      right: kYanBosluk,
      // ⚠️ Panelin ustunde 12 dp nefes.
      bottom: _panelBoy(context) + _cipSeridiBoy() + 12,
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(kYaricap(96)),
        clipBehavior: Clip.antiAlias,
        // ⚠️ Golge: kart HARITANIN ustunde duruyor; golgesiz birakilirsa
        //    acik zeminli haritada kenari kaybolur.
        elevation: 6,
        child: InkWell(
          onTap: () {
            if (ornek) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu bir örnek kayıt — gerçek işletme değil.'),
                ),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(kYaricap(64)),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: gorselID.isEmpty
                        ? ColoredBox(color: kYuzeyGri(context))
                        : MedyaGorsel(
                            mediaId: gorselID,
                            fit: BoxFit.cover,
                            width: 64,
                          ),
                  ),
                ),
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
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (o.dogrulandi)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(LucideIcons.badgeCheck,
                                  size: 14, color: kOnayliRengi),
                            ),
                        ],
                      ),
                      if (alt.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          alt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.25,
                            color: scheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                      if (ornek) ...[
                        const SizedBox(height: 3),
                        // ⚠️ **DURUST SINIR KARTIN ICINDE**: kullanici karta
                        //    DOKUNMADAN bunun ornek oldugunu gormeli
                        //    (turu 131 dersi: ibare detay ekraninin dibindeydi).
                        Text(
                          'Örnek kayıt',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // ⚠️ Kapatma: haritanin bos yerine dokunmak da kapatir
                //    (`onTap`), bu gorunur ve KESIN olan yol.
                IconButton(
                  onPressed: () => setState(() => _secilen = null),
                  icon: const Icon(LucideIcons.x, size: 18),
                  tooltip: 'Kapat',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  double _panelBoy(BuildContext context) {
    final o = MediaQuery.textScalerOf(context);
    final alt = MediaQuery.paddingOf(context).bottom;
    // arama(48) + 10 + cip(40) + 12 + ayrac(1) + 12 + ulasim + 12
    final ulasim = o.scale(11.5) * 1.2 + 34 + 14;
    // ⚠️⚠️ **HATA SATIRI DA SAYILIR** (emulatorde goruldu): konum
    //	alinamayinca panele iki satirlik bir uyari + "Tekrar dene"
    //	dugmesi giriyor ve panel UZUYOR. Hesaba katilmazsa ustte yuzen
    //	filtre seridi panelin ALTINDA kalir (kayboldu sanilir).
    // ⚠️ 48 dp: iki satirlik metin ile TextButton`un buyugu.
    final hataBoy = _hata == null ? 0.0 : o.scale(13) * 1.35 * 2 + 6;
    return 48 + 10 + 40 + 12 + 1 + 12 + ulasim + 12 + hataBoy + alt;
  }

  Widget _altPanel() {
    final tema = Theme.of(context);
    final alt = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tema.scaffoldBackgroundColor,
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
              // ── ARAMA (dokununca POPUP) ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kYanBosluk,
                ),
                child: _aramaKutusu(),
              ),
              const SizedBox(height: 10),
              // ── KATEGORILER ──
              _hizliCipler(),
              const SizedBox(height: 12),
              // ── INCE AYRAC ──
              // ⚠️ Kullanici emri: *"onun altinda hafif ince cizgi"*.
              Divider(
                height: 1,
                thickness: 1,
                color: tema.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 12),
              // ── ULASIM ──
              _ulasimKartlari(),
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
  /// ⚠️⚠️⚠️ TURU 132 — **ARAMA PANELI** (kullanici emri: *"mekan ve adres
  ///	araya tikladiginda popup acilacak, orada kartlar olacak"*).
  ///
  ///	Panelde: gercek arama alani + sonuc KARTLARI (isletme adi, mesafe,
  ///	kategori). Sonuc secilince harita O ISLETMEYE odaklanir.
  ///
  /// ⚠️⚠️ `isScrollControlled` + `SingleChildScrollView` yerine BURADA
  ///	**`DraggableScrollableSheet`** kullanildi: sonuc listesi UZUN
  ///	olabilir ve sabit tavanli bir panel onu kirpardi.
  /// ⚠️ `viewInsets.bottom` EKLENIR: klavye acilinca liste onun ALTINDA
  ///    kalmasin (`useSafeArea` klavyeyi OLCMEZ).
  /// ⚠️ Panel kapaninda arama metni KORUNUR — kullanici ne aradigini
  ///    haritada da gorur.
  Future<void> _aramaPaneliAc() async {
    // ⚠️ Odak: kutu `readOnly`, klavye panelde acilir.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => AramaPaneli(
        baslangic: _q,
        liste: _liste,
        onSec: (i) {
          Navigator.of(c).pop();
          // ⚠️ Ayni yol harita ignesiyle AYNI (`acildi`): iki ayri
          //    acma yolu kacinilmaz olarak drift ederdi.
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfilSayfasi(userId: i.id),
            ),
          );
        },
        onDegis: (v) => setState(() => _q = v.trim()),
      ),
    );
    // ⚠️ Panel kapaninca kutu metni guncellenir (panel kendi denetleyicisini
    //    kullanir; iki denetleyici tutmak DRIFT uretirdi).
    if (mounted) _arama.text = _q;
  }

  Widget _ulasimKartlari() {
    final onRenk = Theme.of(context).colorScheme.onSurface;
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
  /// ⚠️ `suffixIcon`e KALAN GENISLIGIN TAMAMI verilir (turu 96o tuzagi):
  ///    genislik ACIKCA verilmezse X inputun ORTASINDA cikar ve metne yer
  ///    kalmaz.
  /// ⚠️⚠️⚠️ TURU 132 — **ARAMA KUTUSU ARTIK POPUP ACIYOR** (kullanici
  ///	emri: *"mekan ve adres araya tikladiginda popup acilacak, orada
  ///	kartlar olacak"*).
  ///
  /// ⚠️⚠️ Kutu `readOnly` + `AbsorbPointer` DEGIL, `onTap` ile: alan
  ///	odaklanmadan panel acilir, klavye ALT PANELDE acilmaz (panel
  ///	sabit yukseklikte ve klavye onu EZERDI).
  /// ⚠️ Metin yine gorunur (secilen arama kutuda kalir) — kullanici ne
  ///    aradigini panel kapandiktan sonra da GORUR.
  Widget _aramaKutusu() => SizedBox(
    height: 48,
    child: TextField(
      controller: _arama,
      readOnly: true,
      onTap: _aramaPaneliAc,
      textInputAction: TextInputAction.search,
      onChanged: (v) => setState(() => _q = v.trim()),
      decoration: InputDecoration(
        hintText: 'Mekân ve adres ara',
        prefixIcon: const Icon(LucideIcons.search, size: 19),
        suffixIcon: _q.isEmpty
            ? null
            : SizedBox(
                width: 44,
                child: IconButton(
                  tooltip: 'Temizle',
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () {
                    _arama.clear();
                    setState(() => _q = '');
                  },
                ),
              ),
        filled: true,
        fillColor: kYuzeyGri(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kYaricap(48)),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );

  /// Yandex'teki gibi tek satir hizli kategori cipleri.
  ///
  /// ⚠️ Anahtarlar `isletmeKategorileri` TEK KAYNAGINDAN gelir (istemci
  ///    sabiti sunucudaki `Kategoriler` haritasinin ikizi). Elle yazilsaydi
  ///    sunucuya yeni kategori eklendiginde burasi geride kalirdi.
  Widget _hizliCipler() {
    const hizli = ['yemek', 'oto', 'eczane', 'market', 'kafe', 'saglik'];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
        children: [
          // ⚠️ TURU 125 — kategori ciplerine de IKON (kullanici emri).
          //    Ikon KATEGORIYE gore; haritada tanidik simgeler.
          _cip('Tümü', _kategori.isEmpty, () => _kategoriSec(''),
              ikon: LucideIcons.layoutGrid),
          for (final k in hizli)
            if (isletmeKategorileri[k] != null)
              _cip(
                isletmeKategorileri[k]!,
                _kategori == k,
                () => _kategoriSec(k),
                ikon: _kategoriIkonu(k),
              ),
        ],
      ),
    );
  }

  /// ⚠️⚠️ KATEGORIYE OZEL FILTRELER (kullanici emri: *"yemege tikladiginda o
  ///	kategorinin filtrelemeleri orada olsun"*).
  ///
  /// ⚠️⚠️ **DURUST SINIR:** kullanici *"akaryakita fiyat araliklari"* dedi;
  ///	akaryakit FIYATI bu projede HICBIR YERDE YOK (ne tablo, ne uc, ne
  ///	isletme alani). Uydurma bir aralik cizmek kullaniciya YANLIS BILGI
  ///	olurdu. Bunun yerine sunucunun GERCEKTEN dondurdugu olcutler:
  ///	mesafe · puan · kampanya · onayli.
  /// ⚠️ Yemek/kafe/market disindaki kategorilerde "min. tutar" ve
  ///    "kampanya" cogu zaman bos oldugu icin cip CIZILMEZ — kullaniciya
  ///    hicbir sey suzmeyen bir dugme gostermek "bozuk" hissi verir.
  Widget _filtreSatiri() {
    final ticari = _kategori.isEmpty ||
        const {'yemek', 'kafe', 'market'}.contains(_kategori);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
        children: [
          // ⚠️ TURU 125 — her cipte IKON (kullanici emri).
          _cip('2 km içinde', _fKm == 2, () {
            setState(() => _fKm = _fKm == 2 ? 0 : 2);
          }, ikon: LucideIcons.footprints),
          _cip('5 km içinde', _fKm == 5, () {
            setState(() => _fKm = _fKm == 5 ? 0 : 5);
          }, ikon: LucideIcons.bike),
          _cip('4+ puan', _fPuan, () => setState(() => _fPuan = !_fPuan),
              ikon: LucideIcons.star),
          if (ticari)
            _cip(
              'Kampanyalı',
              _fKampanya,
              () => setState(() => _fKampanya = !_fKampanya),
              ikon: LucideIcons.tag,
            ),
          _cip('Onaylı', _fOnayli, () => setState(() => _fOnayli = !_fOnayli),
              ikon: LucideIcons.badgeCheck),
          if (_suzgecVar)
            _cip('Temizle', false, ikon: LucideIcons.x, () {
              _arama.clear();
              setState(() {
                _q = '';
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

  /// ⚠️ Kategori degisince suzgecler KALIR ama liste SUNUCUDAN yeniden
  ///    cekilir (kategori sunucu tarafinda suzuluyor).
  void _kategoriSec(String k) {
    if (_kategori == k) return;
    setState(() => _kategori = k);
    _yukle();
  }
  /// Haritanin uzerinde yuzen iki dugme (geri · konumuma don).
  ///
  /// ⚠️⚠️ TURU 124 — **SIYAH HAFIF SAYDAM DAIRE, GOLGE YOK** (kullanici
  ///	emri: *"geri ve konum arkasındaki dairede siyah hafif saydam olacak,
  ///	gölge olmasın"*).
  ///
  /// ⚠️ Zemin TEMADAN DEGIL SABIT: altta harita var ve harita her renkte
  ///	olabilir; `colorScheme.surface` acik temada BEYAZ daire cizip acik
  ///	zeminli haritada KAYBOLUYORDU.
  /// ⚠️ Ikon BEYAZ olmak ZORUNDA: siyah daire uzerinde tema rengi (acik
  ///    temada siyah) okunmazdi.
  /// ⚠️ `elevation: 0` — golge kaldirildi.
  Widget _ustDugmeler() {
    final ust = MediaQuery.paddingOf(context).top + 8;
    Widget d(IconData ikon, String ipucu, VoidCallback bas) => Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      elevation: 0,
      child: IconButton(
        tooltip: ipucu,
        icon: Icon(ikon, size: 20, color: Colors.white),
        onPressed: bas,
      ),
    );
    return Positioned(
      top: ust,
      left: kYanBosluk,
      right: kYanBosluk,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          d(LucideIcons.arrowLeft, 'Geri', () => Navigator.of(context).pop()),
          d(
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

  // ⚠️⚠️ TURU 115 — `_altSerit` ve `_kategoriSeridi` SILINDI: eski duzenin
  //    (ust %70 harita + altta YATAY kart seridi) parcalariydi. Yandex
  //    duzeninde liste DIKEY ve alt sayfanin icinde; cipler de
  //    `_hizliCipler`/`_filtreSatiri`na tasindi.
  // ⚠️ Yalniz cagri kaldirilsaydi ikisi de OLU KOD olarak kalir ve
  //    sifir-uyari tabanini bozardi.

  /// ⚠️⚠️ TURU 125 — **`ChoiceChip` KALDIRILDI** (kullanici emri:
  ///	*"tıkladığında patlama oynama olmasın"* + *"filtreleme ve
  ///	kategorilere ikon ekle"*).
  ///
  ///	Material `ChoiceChip` secilince SOLUNA BIR TIK KOYAR; cip o anda
  ///	~24 dp genisler ve SAGINDAKI TUM cipler kayar — kullanicinin
  ///	"patlama/oynama" dedigi sey buydu. Ayrica secim animasyonu
  ///	olcek degistirir.
  /// ⚠️ Yeni cip **SABIT OLCULU**: yaziyi w600, kenarligi 1.4 dp SABIT
  ///    tutar; secili halde YALNIZ RENK degisir, GENISLIK DEGISMEZ.
  /// ⚠️ Kategori ekranindaki `KabukCip` ile AYNI dil (32 dp, 13 px yazi,
  ///    kalinlastirilmis ikon).
  Widget _cip(
    String etiket,
    bool secili,
    VoidCallback onTap, {
    IconData? ikon,
  }) {
    final vurgu = kVurgu(context);
    final notr = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              // ⚠️ Zemin OPAK: cipler HARITANIN UZERINDE yuzuyor.
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(kYaricap(32)),
              border: Border.fromBorderSide(
                BorderSide(
                  color: secili ? vurgu : notr.withValues(alpha: 0.16),
                  width: 1.4,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ikon != null) ...[
                  Icon(ikon, size: 14, color: secili ? vurgu : notr),
                  const SizedBox(width: 6),
                ],
                Text(
                  etiket,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

  /// ⚠️⚠️ TURU 125 — **YUZEN FILTRE KATMANI** (kullanici emri:
  ///	*"filtrelemeler kartın ÜZERİNDE olacak, kartın İÇİNDE değil,
  ///	10px üzerinde"*).
  ///
  /// ⚠️ Alt sayfanin kapali yuksekligi `initialChildSize` (0.28) ile
  ///	hesaplanir; cipler onun **10 dp USTUNDE** durur.
  /// ⚠️ `IgnorePointer` YOK: ciplere dokunulabilmeli. Ama katman yalniz
  ///    kendi yuksekligini kaplar, geri kalan harita DOKUNULABILIR kalir.
  /// Kategori ikonu — haritadaki cipler icin.
  ///
  /// ⚠️ Bilinmeyen kategori notr bir ikona duser: eksik anahtar yuzunden
  ///    cip HIC cizilmemesindense notr simge dogrudur.
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
        _ => LucideIcons.store,
      };

  /// ⚠️⚠️⚠️ TURU 132 — **FILTRE SERIDI PANELIN 10 dp USTUNDE YUZER**
  ///	(kullanici emri: *"yemek dedigimde o alttaki kartin 10 px
  ///	ustunde sol sag scroll filtreleme olacak — alttaki buyuk alanin
  ///	ICINDE DEGIL, 10 px yukari"*).
  ///
  /// ⚠️⚠️ Kategori CIPLERI buradan CIKARILDI: onlar artik panelin
  ///	ICINDE, aramanin altinda (ayni kullanici emri). Burada YALNIZ
  ///	suzgecler var.
  /// ⚠️ Yukseklik `_panelBoy` ile AYNI KAYNAKTAN gelir; panel yuksekligi
  ///    degisirse serit kendiliginde onunla birlikte kayar. Sabit bir
  ///    sayi yazilsaydi ikisi AYRISIR ve serit panelin altinda kalirdi.
  /// ⚠️⚠️ **KATEGORI SECILI DEGILKEN CIZILMEZ**: "Tümü"de suzgec sunmak
  ///	haritanin ustunu bosuna kaplardi ve kullanici emri de
  ///	*"yemek dedigimde"* diyor.
  /// ⚠️⚠️⚠️ TURU 136 — **`Widget?` DONER; ESKIDEN `SizedBox.shrink()` IDI VE
  ///	KATEGORISIZ ACILISTA EKRANIN TAMAMINI BEYAZ BIRAKIYORDU.**
  ///
  ///	Yigindaki (`build` -> `Stack`) diger cocuklarin HEPSI `Positioned`.
  ///	`RenderStack` boyutunu YALNIZCA positioned OLMAYAN cocuklarindan
  ///	hesaplar; `_kategori` bos oldugunda buradan donen 0x0 cocuk TEK
  ///	non-positioned cocuk oluyor ve yigin **0x0**'a dusuyordu — harita,
  ///	dugmeler, panel HICBIRI cizilmiyordu.
  ///
  /// ⚠️⚠️ **BU YOL GERCEKTEN ULASILABILIR:** menudeki "Yakınımda" karti
  ///	`const YakinimdaEkrani()` ile, yani **kategorisiz** aciyor
  ///	(`hizmet_menusu.dart`). Yani hata turu 136'dan ONCE de vardi ve
  ///	kullanicinin kendi menu girisini vuruyordu.
  /// ⚠️ Emulatorde olculdu: kosullu hale getirilince ekran geri geliyor.
  /// ⚠️ YAPMA: bu metodu tekrar `SizedBox.shrink()` dondurur hale getirme;
  ///    cagri yerindeki `if (... != null)` kapisini da kaldirma.
  Widget? _yuzenCipler() {
    if (_kategori.isEmpty) return null;
    return Positioned(
      left: 0,
      right: 0,
      bottom: _panelBoy(context) + 10,
      child: _filtreSatiri(),
    );
  }

  /// Yuzen cip seridinin kapladigi yukseklik (kart onun USTUNE konumlanir).
  ///
  /// ⚠️ Serit `_filtreSatiri()` -> yuksekligi 40 dp'lik cipler + 10 dp
  ///    aciklik. Kategori yoksa serit CIZILMEZ, yer de kaplamaz.
  double _cipSeridiBoy() => _kategori.isEmpty ? 0 : 40 + 10;
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
    this.acildi,
    this.secildi,
    this.secimKapandi,
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

  /// Harita balonuna dokununca cagrilir (bkz. `onInfoWindowTap` serhi).
  /// ⚠️ Gezinmeyi EKRAN yapar, bu bilesen DEGIL: `_HaritaAlani` saf gorunum
  ///    kalsin ki anahtarsiz yer tutucu daliyla ayni sozlesmeyi paylassin.
  final void Function(IsletmeOzet)? acildi;

  /// ⚠️⚠️ TURU 136 — **PINE DOKUNUNCA KART** (kullanici emri: *"haritada
  ///	mockup isletmeler koyup tikladigimda KART seklinde"*).
  ///
  ///	Turu 85b'de pinin dokunusu yalnizca BALONU (`InfoWindow`) aciyordu;
  ///	balon ad + mesafeden fazlasini gosteremez (Google Maps balonu bizim
  ///	widget'imiz DEGIL) ve kullanici kapak/puan/kampanya goremiyordu.
  ///	Artik pine dokunus EKRANA haber verir, ekran da haritanin ustune
  ///	GERCEK bir kart cizer.
  /// ⚠️ Secim durumu EKRANDA tutulur, burada DEGIL: kart panelin ustunde,
  ///    yani bu bilesenin DISINDA ciziliyor.
  final void Function(IsletmeOzet)? secildi;

  /// Haritanin bos bir yerine dokunulunca (secimi kapatmak icin).
  final VoidCallback? secimKapandi;

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

  Future<void> _pinUret() async {
    final tema = Theme.of(context).colorScheme;
    final oran = MediaQuery.devicePixelRatioOf(context);
    final d = await daireIsaret(
      ic: tema.primary,
      // ⚠️ Kenar ACIK: harita zemini her renkte olabilir (yol beyaz, park
      //    yesil, su mavi); acik halka pini her zeminde ayirir.
      kenar: Colors.white,
      pikselOrani: oran,
    );
    // ⚠️ TURU 124 — KENDI konum isaretimiz. Google`in MAVI noktasi
    //    kapatildi; bu MOR (marka rengi) ve isletme pinleriyle ayni
    //    bilesenden uretilir (tek kaynak).
    final b = await daireIsaret(
      ic: morLogo,
      kenar: Colors.white,
      pikselOrani: oran,
    );
    if (!mounted) return;
    setState(() {
      _pin = d;
      _benPin = b;
    });
  }

  ({double enlem, double boylam})? get merkez => widget.merkez;
  List<IsletmeOzet> get isletmeler => widget.isletmeler;
  void Function(IsletmeOzet)? get acildi => widget.acildi;
  // ⚠️ TURU 136 — kardesleriyle AYNI desen (pine dokunus -> ekranda kart).
  void Function(IsletmeOzet)? get secildi => widget.secildi;

  @override
  void didUpdateWidget(covariant _HaritaAlani eski) {
    super.didUpdateWidget(eski);
    // ⚠️ Kamera YALNIZ merkez GERCEKTEN degistiginde tasinir; her `build`te
    //    `animateCamera` cagirmak haritayi surekli sarsardi.
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
                // ⚠️ Alt panelin ortettigi bant (bkz. `altDolgu` serhi).
                padding: EdgeInsets.only(bottom: widget.altDolgu),
                // ⚠️ Controller SAKLANIR: konum degisince kamerayi tasiyan
                //    TEK yol budur (bkz. sinif serhi).
                onMapCreated: (c) => _harita = c,
                // ⚠️ TURU 136 — haritanin BOS bir yerine dokunmak acik karti
                //    kapatir (Google/Yandex deseni). Kart kendi ✕ dugmesini
                //    de tasiyor; bu ikinci ve daha dogal yol.
                onTap: (_) => widget.secimKapandi?.call(),
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
                        // ⚠️⚠️⚠️ TURU 136 — **PINE DOKUNUS ARTIK KART ACAR.**
                        //
                        //	Turu 85b'de bu dokunus yalnizca `InfoWindow`
                        //	aciyordu (ad + mesafe) ve balona basinca profile
                        //	gidiliyordu. Balon Google Maps'in kendi cizimi;
                        //	kapak gorseli, puan, kampanya rozeti GOSTEREMEZ.
                        //	Kullanici (turu 136) acikca KART istedi.
                        // ⚠️ `InfoWindow` KALDIRILDI: kart ayni bilgiyi
                        //    fazlasiyla veriyor; ikisi birlikte cizilseydi
                        //    pinin ustunde balon, altta kart olurdu.
                        // ⚠️ **GEZINME HALA ONAYLI EYLEM:** pin dokunusu
                        //    yalnizca karti ACAR; profile gitmek icin KARTA
                        //    dokunmak gerekir. Kaydirirken yanlislikla pine
                        //    degen kullanici ekran degistirmis olmaz
                        //    (turu 85b'nin gerekcesi KORUNDU).
                        onTap: () => secildi?.call(i),
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

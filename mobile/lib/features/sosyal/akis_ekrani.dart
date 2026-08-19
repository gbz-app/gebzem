import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../home/home_screen.dart' show myProfileProvider;
// ⚠️ TURU 98e — ust cubuk ikonlari alt menuyle AYNI olcude (TEK KAYNAK).
import '../home/alt_menu.dart' show kAltMenuIkonBoy;
// ⚠️ TURU 98m — sayfa kenar payi TEK KAYNAK (kategori ekraniyla ayni).
import '../isletme/isletme_kart.dart' show kYanBosluk;
// ⚠️ TURU 114 — "Mahalle" bolmesi konum ZORUNLU (sunucu koordinatsiz istegi
//    400 ile reddeder). Konum tek kaynaktan alinir.
import '../medya/konum_servisi.dart' show KonumServisi;
import 'demo_veri.dart';
import 'bildirim_sayaci.dart';
import 'bildirimler_sayfasi.dart';
import 'gonderi_karti.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';
import 'story_seridi.dart';
import 'olustur_menusu.dart';

/// ⚠️⚠️ TURU 75 — ANA SAYFA AKISI (Instagram/Facebook duzeni).
///
/// ⚠️ SAYFALAMA IMLECLI (cursor): son gonderinin `created_at`i `before` olarak
///    gonderilir. `offset` KULLANILMAZ — yeni gonderi gelince satirlar kayar ve
///    ayni gonderi iki kez gorunur.
///
/// ⚠️ SOGUK BASLANGIC: kimseyi takip etmeyen kullaniciya BOS EKRAN gosterilmez;
///    sunucu "kesfet" (herkese acik yeni gonderiler) doner ve ustte serit cikar.
///    Bos akis yeni kullanicinin urunu terk etme sebebidir.
class AkisEkrani extends ConsumerStatefulWidget {
  const AkisEkrani({super.key});

  @override
  ConsumerState<AkisEkrani> createState() => _AkisEkraniState();
}

class _AkisEkraniState extends ConsumerState<AkisEkrani>
    with AutomaticKeepAliveClientMixin {
  final _kaydirma = ScrollController();

  /// ⚠️ TURU 80 — AKTIF bolmenin listesi. Alan DEGIL GETTER: iki bolme ayri
  ///    liste tutuyor ve tum mevcut kod `_liste` uzerinden calisiyordu.
  List<Gonderi> get _liste => _listeler[_bolme];
  bool _ilkYukleme = true;
  bool _yukleniyor = false;
  String? _hata;

  /// ⚠️⚠️ TURU 80b — `_dahaVar` ve `_kesfet` **BOLME BASINA** (denetim).
  ///
  ///	Ikisi de tek bir `bool` idi ve bolmeler arasinda TASINIYORDU:
  ///	· `_kesfet` (soguk baslangic seridi) "Takip Ettiklerin"de true olunca
  ///	  Keşfet'e gecince de cizilmeye devam ediyordu — Keşfet'te
  ///	  *"takip edecek kimse bulamadik"* seridi YANILTICI.
  ///	· `_dahaVar` bolme degisiminde kosulsuz diriliyor, tukenmis sayfalama
  ///	  yeniden tetikleniyordu (bos istek + gereksiz spinner).
  ///
  /// ⚠️ YAPMA: bunlari tekrar tek `bool`a indirgeme; bolmeye ozgu HER durum
  ///    listeye tasinmali (liste ve kaydirma konumu zaten oyle).
  // ⚠️ TURU 114 — diziler UC elemanli (0 Arkadaş · 1 Keşfet · 2 Mahalle).
  final List<bool> _dahaVarlar = [true, true, true];
  final List<bool> _kesfetler = [false, false, false];

  bool get _dahaVar => _dahaVarlar[_bolme];
  bool get _kesfet => _kesfetler[_bolme];

  /// ⚠️⚠️⚠️ TURU 80 — BOLME ARTIK "Takip Ettiklerin | Keşfet" (kullanici emri:
  /// *"anasayfadaki akış ve kanallar butonunu kaldır, onun yerine hikaye
  /// dairesinin altına Takip Ettiklerin / Keşfet olacak"*).
  ///
  /// 0 = Takip Ettiklerin (`/feed`) · 1 = Keşfet (`/kesfet`)
  ///
  /// ⚠️⚠️ KANALLAR NEREYE GITTI: eski secici KANALLARIN **TEK GIRIS
  ///    NOKTASIYDI**. Kaldirip yerine bir sey koymamak kanal ozelligini
  ///    TAMAMEN ULASILAMAZ birakirdi (bu projede ALTI kez yasanan "olu
  ///    ozellik" sinifi). Kanallar sol ust hamburger menuye TASINDI
  ///    (`hizmet_menusu.dart` -> `KanallarSayfasi`).
  ///    ⚠️ YAPMA: buraya kanal bolmesini geri ekleme; iki giris DRIFT eder.
  /// ⚠️⚠️⚠️ TURU 114 — **SECICI GERI GELDI, UCUNCU BOLME "MAHALLE"**
  ///	(kullanici emri: *"anasayfada ustte Arkadas Keşfet Mahalle
  ///	kaldirmissin dikkat et"*). Turu 113 seciciyi kaldirmisti; kullanici
  ///	geri istedi ve ucuncu ogeye YENI BIR ANLAM verdi.
  ///
  /// 0 = Arkadaş (`/feed`) · 1 = Keşfet (`/kesfet`) · 2 = Mahalle (`/mahalle`)
  ///
  /// ⚠️⚠️ ESKI HALDE ucuncu oge ("Canlı Yayın") bir AKIS BOLMESI DEGIL, alt
  ///	menuye giden bir KISAYOLDU ve o yuzden diziler IKI elemanliydi.
  ///	Mahalle GERCEK bir bolme oldugu icin `_listeler`, `_dahaVarlar`,
  ///	`_kesfetler`, `_bolmeYuklendi`, `_bolmeKaydirma` **UC elemana**
  ///	cikarildi. ⚠️ YAPMA: dorduncu bolme eklerken bu bes diziyi unutma.
  int _bolme = 0;

  /// ⚠️⚠️ HER BOLMENIN **KENDI LISTESI** var — bolme degisince liste SWAP
  ///    edilir, yeniden ag istegi ATILMAZ ve kaydirma konumu korunur.
  ///
  /// ⚠️ NEDEN `IndexedStack` DEGIL (bu isin EN KRITIK karari): `IndexedStack`
  ///    secili OLMAYAN cocuklari da agacta CANLI + LAYOUT EDILMIS tutar. Akista
  ///    OTOMATIK OYNAYAN VIDEO var ve otomatik oynatma dort kapiya bagli
  ///    (`_gorunurOran>=0.6` · `_sayfa==sira` · `aktifSekme==0` ·
  ///    `ModalRoute.isCurrent`) — bunlarin HICBIRI "hangi BOLME acik" sorusunu
  ///    bilmez. Iki bolme birden canli olsaydi GORUNMEYEN bolmedeki video da
  ///    oynar, mobil veri harcar ve iOS'ta ses oturumunu tutardi (turu 64/65/73
  ///    aramalari tam bu yuzden sagirlasti).
  /// ⚠️ YAPMA: iki bolmeyi `IndexedStack`e koyma.
  final List<List<Gonderi>> _listeler = [<Gonderi>[], <Gonderi>[], <Gonderi>[]];
  final List<bool> _bolmeYuklendi = [false, false, false];
  final List<double> _bolmeKaydirma = [0, 0, 0];

  /// ⚠️⚠️ TURU 114 — MAHALLE bolmesinin konumu. BIR KEZ alinir ve bolme
  ///	acik kaldigi surece yeniden sorulmaz (her sayfalamada GPS uyandirmak
  ///	pil yakar). Asagi-cek konumu TAZELER.
  ({double enlem, double boylam})? _mahalleKonum;

  /// ⚠️ TURU 76b — hikaye seridine erisim: akis YENILENINCE serit de
  ///    yenilenmeli (yeni hikaye paylasan biri aninda gorunsun).
  final _storyKey = GlobalKey<StorySeridiDurumu>();

  /// ⚠️ IndexedStack icinde oldugumuz icin sekme degisince state KORUNUR; ama
  ///    `AutomaticKeepAlive` olmadan ListView kaydirma konumu kaybolabiliyor.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _kaydirma.addListener(_kaydirmaDinle);
    _yenile();
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  void _kaydirmaDinle() {
    if (!_kaydirma.hasClients) return;
    final kalan =
        _kaydirma.position.maxScrollExtent - _kaydirma.position.pixels;
    // 800px kala sonrakini getir — kullanici "yukleniyor" gormeden akmali.
    if (kalan < 800) _dahaGetir();
  }

  Future<void> _yenile() async {
    if (_yukleniyor) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    // ⚠️ Bolme kimligi await'ten ONCE ve **try'in DISINDA** yakalanir:
    //    disinda olmasi ZORUNLU, cunku `catch` dali da bu kimlige bakiyor
    //    (hatanin YANLIS bolmede cizilmemesi icin — turu 80b denetimi).
    final bolme = _bolme;
    try {
      // ⚠️ Serit de tazelenir — asagi cekince yalniz gonderiler yenilenseydi
      //    yeni hikayeler gorunmezdi.
      unawaited(_storyKey.currentState?.yukle() ?? Future.value());
      // ⚠️⚠️⚠️ TURU 98 — **TASARIM DEMOSU** (bkz. `demo_veri.dart`).
      //	`kDemoAkis` false iken bu dal calismaz ve akis normal isler.
      //	Sunucudan HICBIR SEY SILINMEDI; yalniz ekranda demo icerik
      //	cizilir (gri yer tutucu medya + her icerik turunden bir ornek).
      if (kDemoAkis) {
        if (!mounted) return;
        setState(() {
          // ⚠️⚠️⚠️ TURU 114 — **MAHALLE DEMODA DA KENDINI ANLATIR** (denetim
          //	bulgusu). Demo dali bolme dagitiminin USTUNDE oldugu icin
          //	Mahalle sekmesi de AYNI sekiz demo gonderiyi gosteriyordu:
          //	konum HIC istenmiyor, bolme digerlerinden AYIRT EDILEMIYOR ve
          //	ozellik pratikte **hic gorunmuyordu**.
          //
          // ⚠️ Cozum SAHTE VERI EKLEMEK DEGIL: mahallenin tanimi "konumlu
          //    gonderiler" oldugu icin demo listesi de o olcute gore
          //    SUZULUYOR. Boylece bolmenin ne yaptigi ekranda GORUNUYOR ve
          //    hicbir uydurma sayi/kart cizilmiyor.
          final demo = demoGonderiler();
          _listeler[bolme]
            ..clear()
            ..addAll(
              bolme == 2
                  ? demo.where((g) => g.enlem != 0 || g.boylam != 0)
                  : demo,
            );
          _bolmeYuklendi[bolme] = true;
          // ⚠️⚠️ TURU 114 — **DEMODA SAYFALAMA YOK** (`_dahaGetir` ilk satirda
          //	`kDemoAkis` ile doner). `_dahaVarlar` baslangicta `true` oldugu
          //	icin listenin SONUNA "daha yukleniyor" gostergesi ciziliyor ve
          //	SONSUZA KADAR DONUYORDU. Mahalle bolmesinde tek gonderi oldugu
          //	icin gosterge EKRANDA gorunur hale geldi ve emulatorde yakalandi.
          //	Arkadaş/Keşfet'te de vardi, yalnizca sekiz kartin altinda
          //	kaldigi icin fark edilmemisti.
          _dahaVarlar[bolme] = false;
          _yukleniyor = false;
          _ilkYukleme = false;
        });
        return;
      }
      // ⚠️ Servis await'ten ONCE yakalanir (turu 78b dersi: disposed State'te
      //    `ref.read` StateError firlatir ve is SESSIZCE iptal olur).
      final svc = ref.read(sosyalServisiProvider);
      final List<Gonderi> gelen;
      if (bolme == 2) {
        // ⚠️⚠️⚠️ TURU 114 — MAHALLE: **KONUM ZORUNLU.**
        //
        //	Sunucu koordinatsiz istegi 400 ile reddeder ("konum gerekli") —
        //	koordinatsiz bir "mahalle" tanimsizdir. Izin verilmemisse
        //	kullaniciya JENERIK "Akış yüklenemedi" YAZILMAZ; sebep ACIKCA
        //	soylenir, yoksa kullanici hatayi ag sorunu sanar ve izin
        //	ekranina HIC gitmez.
        // ⚠️ Konum BIR KEZ alinir; asagi-cek onu tazeler (`_elleYenile`).
        final k = _mahalleKonum ?? await KonumServisi.konumAl();
        if (!mounted) return;
        if (k == null) {
          setState(() {
            _yukleniyor = false;
            _ilkYukleme = false;
            // ⚠️⚠️⚠️ TURU 114 (denetim) — **`_bolmeYuklendi` ISARETLENIR.**
            //
            //	`_bolmeYukle` IKI TURLU bir dongudur ve durma olcutu YALNIZ
            //	`_bolmeYuklendi[hedef]`tir. Isaretlenmezse konum reddedilen
            //	kullanicida `_yenile` IKINCI KEZ kosuyor ve
            //	`KonumServisi.konumAl()` **IKINCI BIR IZIN DIYALOGU** ile
            //	arka arkaya soruyordu (Android ikinciyi sessizce dusurur —
            //	turu 89'da tam bu yuzden READ_PHONE_STATE 36 tur alinamadi).
            // ⚠️ Kullanici yine deneyebilir: asagi-cek `_mahalleKonum`u
            //    sifirlar ve `_yenile`yi dogrudan cagirir.
            _bolmeYuklendi[2] = true;
            if (bolme == _bolme) {
              // ⚠️ Liste de TEMIZLENIR: hata govdesinin kapisi
              //    `_hata != null && _liste.isEmpty`. Bayat bir liste
              //    kalsaydi hata mesaji HIC cizilmez ve kullanici izni
              //    reddettigini ogrenemezdi.
              _listeler[2].clear();
              _hata = 'Mahalle akışı için konum izni gerekiyor';
            }
          });
          return;
        }
        _mahalleKonum = k;
        gelen = await svc.mahalleAkisi(enlem: k.enlem, boylam: k.boylam);
      } else if (bolme == 1) {
        gelen = await svc.kesfetAkisi();
      } else {
        final s = await svc.akis();
        gelen = s.gonderiler;
        // ⚠️ `s.kesfet` (soguk baslangic bayragi) BILEREK KULLANILMIYOR —
        //    gerekce `_kesfetler[bolme] = false` satirinin ustunde yazili.
      }
      // ⚠️⚠️⚠️ TURU 80b — SEVK ENGELI DUZELTMESI (denetim bulgusu).
      //    Eskiden burada `if (!mounted || bolme != _bolme) return;` vardi ve
      //    ERKEN DONUS `_yukleniyor = false` satirini ATLIYORDU. `_yukleniyor`
      //    BOLMEYE OZGU DEGIL, PAYLASILAN bir bayrak: kullanici yukleme
      //    surerken bolme degistirdiginde bayrak SONSUZA KADAR true kaliyor ve
      //    `_yenile` ile `_dahaGetir`in ILK SATIRI (`if (_yukleniyor) return;`)
      //    her cagriyi reddediyordu -> **AKIS KALICI OLARAK KILITLENIYORDU**
      //    (asagi-cek calismaz, sayfalama durur; uygulama yeniden baslatilana
      //    kadar duzelmez).
      // ⚠️ Bayrak ARTIK HER DURUMDA temizlenir; yalnizca LISTEYE YAZMA islemi
      //    bolme kapisiyla korunur.
      if (!mounted) return;
      if (bolme != _bolme) {
        // ⚠️ `_ilkYukleme` DE temizlenir: aksi halde uygulama acilisindaki ilk
        //    yukleme sirasinda bolme degistirilirse bayrak true kalir ve
        //    `_govde`nin ILK dali ekrani KALICI (kaydirilamaz) spinner'a
        //    kilitler. Bugun ulasilmasi zor bir yol ama bedeli agir.
        setState(() {
          _yukleniyor = false;
          _ilkYukleme = false;
        });
        return;
      }
      setState(() {
        _listeler[bolme]
          ..clear()
          ..addAll(gelen);
        _bolmeYuklendi[bolme] = true;
        // ⚠️ Soguk baslangic seridi YALNIZ "Takip Ettiklerin" bolmesinde
        //    anlamli: Keşfet zaten kesfet icerigidir, orada "takip edecek kimse
        //    bulamadik" seridi cizmek YANILTICI olurdu.
        // ⚠️⚠️ TURU 82b — SOGUK BASLANGIC SERIDI KAPATILDI (kullanici emri:
        //    *"kesfet kimseyi takip etmiyorsun vb yaziyi kaldir, gereksiz"*).
        //    Sunucu HALA kesfet icerigi donuyor (`soguk` bayragi), yani yeni
        //    kullanici BOS EKRAN gormuyor — yalnizca ACIKLAMA SERIDI cizilmiyor.
        // ⚠️ YAPMA: sunucudaki soguk-baslangic dalini kaldirma; kaldirilirsa
        //    kimseyi takip etmeyen kullanicinin akisi GERCEKTEN bosalir.
        // ⚠️ `_kesfetler` daima false. Serit geri istenirse yukaridaki dalda
        //    `s.kesfet` okunup buraya `bolme == 0 && soguk` yazilir.
        _kesfetler[bolme] = false;
        _dahaVarlar[bolme] = gelen.isNotEmpty;
        _ilkYukleme = false;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      // ⚠️⚠️ TURU 80b — HATA DA **BOLMEYE OZGU** (denetim).
      //    Basari yolunda bolme kapisi vardi ama catch dalinda YOKTU: bir
      //    bolmenin ag hatasi, kullanici o sirada digerine gectiyse **DIGER
      //    bolmenin ekraninda** "Akış yüklenemedi" cizdiriyordu — dolu ve
      //    saglikli bir listenin uzerine yanlis hata. `_hata` paylasilan
      //    oldugu icin kapiyi ELLE koymak zorundayiz.
      setState(() {
        _ilkYukleme = false;
        _yukleniyor = false;
        if (bolme == _bolme) _hata = 'Akış yüklenemedi';
      });
    }
  }

  /// Kullanicinin ELLE tetikledigi yenileme (asagi-cek + "Tekrar dene").
  ///
  /// ⚠️⚠️ TURU 80b — DOGRUDAN `_yenile` CAGIRMAZ (denetim bulgusu).
  ///    `_yenile`nin ilk satiri `if (_yukleniyor) return;`. Kurtarma yoluna
  ///    en cok ihtiyac duyulan an, tam da ucusta bir istek OLDUGU andir
  ///    (`_bolmeYukle` pes etmis, bolme bos kalmis). O anda asagi-cek
  ///    SESSIZCE no-op olurdu: gosterge doner, hicbir sey olmaz, kullanici
  ///    "uygulama bozuk" der. Once ucustaki istegin bitmesini bekliyoruz.
  /// ⚠️ Sinirli bekleme (3sn): sonsuz asili kalmaz.
  Future<void> _elleYenile() async {
    for (var i = 0; i < 20 && _yukleniyor; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
    }
    if (!mounted) return;
    // ⚠️⚠️ TURU 114 — asagi-cek MAHALLE'de **KONUMU DA TAZELER.** Konum
    //	`_yenile` icinde bir kez alinip saklaniyor (her sayfalamada GPS
    //	uyandirmak pil yakar); kullanici baska bir semte gidip asagi
    //	cektiginde ESKI koordinatla ayni listeyi gorurdu. Ayrica konum izni
    //	SONRADAN verilmisse tekrar denemenin TEK yolu budur.
    if (_bolme == 2) _mahalleKonum = null;
    await _yenile();
  }

  Future<void> _dahaGetir() async {
    // ⚠️⚠️ TURU 98i — DEMODA SAYFALAMA YOK.
    //	Demo listesi `_yenile` icinde kuruluyordu ama `_dahaGetir` sunucudan
    //	cekmeye devam ediyordu: kullanici asagi kaydirinca demo kartlarin
    //	ALTINA GERCEK gonderiler ekleniyordu (emulatorde gorundu).
    if (kDemoAkis) return;
    if (_yukleniyor || !_dahaVar || _liste.isEmpty) return;
    setState(() => _yukleniyor = true);
    try {
      // ⚠️ Servis ve bolme kimligi await'ten ONCE (bkz. `_yenile` serhi).
      final svc = ref.read(sosyalServisiProvider);
      final bolme = _bolme;
      final imlec = _liste.last.createdAt;
      // ⚠️ Mahalle sayfalamasi KONUM ZATEN ALINMISKEN yapilir; `_mahalleKonum`
      //    null ise (ilk yukleme basarisiz) sayfalama denenmez.
      final k = _mahalleKonum;
      if (bolme == 2 && k == null) {
        setState(() => _yukleniyor = false);
        return;
      }
      final gelen = switch (bolme) {
        2 => await svc.mahalleAkisi(
          enlem: k!.enlem,
          boylam: k.boylam,
          before: imlec,
        ),
        1 => await svc.kesfetAkisi(before: imlec),
        _ => (await svc.akis(before: imlec)).gonderiler,
      };
      // ⚠️ AYNI SIZINTI (bkz. `_yenile` serhi): erken donus `_yukleniyor`u
      //    temizlemezse akis KALICI kilitlenir.
      if (!mounted) return;
      if (bolme != _bolme) {
        setState(() => _yukleniyor = false);
        return;
      }
      setState(() {
        // ⚠️ TEKRAR SUZGECI: imlec sinirinda ayni saniyede olusmus gonderiler
        //    hem onceki hem yeni sayfada gelebilir. Id'ye gore eliyoruz —
        //    yoksa listede CIFT KART cizilir (ve `Key` cakismasi patlatir).
        final hedef = _listeler[bolme];
        final mevcut = hedef.map((g) => g.id).toSet();
        hedef.addAll(gelen.where((g) => !mevcut.contains(g.id)));
        _dahaVarlar[bolme] = gelen.isNotEmpty;
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
    }
  }

  /// ⚠️⚠️⚠️ TURU 80 — "Takip Ettiklerin | Keşfet" SECICISI.
  ///
  /// Kullanici emri: *"hikaye dairesinin ALTINA Takip Ettiklerin / Keşfet"*.
  ///
  /// ⚠️ AKISLA BIRLIKTE KAYAR (sabitlenmedi). Sabit (pinned) bir baslik
  ///    `gorunurluk.dart` gozcusuyle catisirdi: gozcu viewport'un TAMAMINI
  ///    olcuyor, yani baslik ARKASINDA kalan kismi da "gorunur" sayardi ve
  ///    otomatik video oynatmanin `>=0.6` kapisi olcusunu SASIRIRDI. Hikaye
  ///    seridi de ayni gerekceyle akisla kayiyor (turu 76b karari).
  /// ⚠️ Bolme degisiminde LISTE SWAP edilir, ag istegi ATILMAZ (bolme daha once
  ///    yuklendiyse). Kaydirma konumu bolme basina saklanir.
  /// ⚠️⚠️⚠️ TURU 81 — DUGME DEGIL **SOL HIZALI KALIN YAZI** (kullanici emri:
  /// *"Takip ettiklerim ve Keşfet BUTON DEGIL, YAZI SOLDA olacak, YAZI KALIN,
  /// aktif/pasif belli olsun"*).
  ///
  /// Threads deseni: cerceve/dolgu YOK, iki metin yan yana; secili olan
  /// PARLAK ve KALIN, digeri SOLUK ve normal agirlikta.
  ///
  /// ⚠️ `SegmentedButton` KALDIRILDI ama onun verdigi IKI SEY ELLE geri kondu:
  ///   · **Dokunma alani**: ciplak `Text` ~17dp yuksekliktedir; `Padding` ile
  ///     44dp'ye cikarildi (Material 48 / Apple 44 — turu 78b dersi, orada
  ///     17x17dp bir dugme fiilen ULASILAMAZDI).
  ///   · **Erisilebilirlik**: `Semantics(button + selected)` — ekran okuyucu
  ///     hangi sekmenin secili oldugunu soylemeye devam etmeli.
  /// ⚠️ YAPMA: bu ikisini kaldirma; gorunumu sadelestirmek islevsellik
  ///    kaybetmek DEMEK DEGIL.
  ///
  /// ⚠️ Secici AKISLA BIRLIKTE KAYAN bir liste ogesidir (sabitlenmez) —
  ///    gerekcesi `_bolmeSecici` cagrisinin yanindaki serhte.
  /// ⚠️⚠️ TURU 82 — YATAY KAYDIRMA SARMALI **ZORUNLU**.
  ///
  /// Yazi 15 -> 17px buyutuldu (kullanici emri). AMPIRIK OLCUM (`flutter test`,
  /// 360dp ekran, kullanilabilir genislik 344dp):
  ///
  ///     olcek 1.0   15px=189  17px=209    ikisi de sigar
  ///     olcek 1.3   15px=234  17px=260    ikisi de sigar
  ///     olcek 1.5   15px=264  17px=294    ikisi de sigar
  ///     olcek 2.0   15px=339  17px=379    <- 15px SIGIYOR, 17px **TASIYOR**
  ///
  /// Yani +2px, erisilebilirlik icin yazi olcegini 2.0 yapan kullanicida
  /// sari-siyah RenderFlex seridi cikariyordu. `Flexible`+ellipsis secilmedi:
  /// "Takip Ettiklerin" -> "Takip Ettik…" olurdu ve kullanicinin ACIKCA
  /// istedigi etiket okunamaz hale gelirdi. Kaydirma metni BOZMAZ.
  /// ⚠️ YAPMA: bu sarmali kaldirma; yaziyi kucultup "cozuldu" sayma.
  /// ⚠️⚠️ TURU 98e — SECICI **ORTALANIR** (kullanici emri: *"Arkadaslar,
  ///	Kesfet ve Canli Yayin header ortasinda olacak"*).
  ///
  /// ⚠️ Ortalama `Center` ILE DEGIL, kaydirma alaninin KENDI hizasiyla
  ///	yapilir: `Center` sarmali kaydirma alanini icerigin genisligine
  ///	daraltir ve ASIRI YAZI OLCEGINDE kaydirmayi OLDURURDU
  ///	(yukaridaki olcum tablosu: olcek 2.0da icerik 379dp, alan 344dp).
  ///	**`ConstrainedBox(minWidth: alanGenisligi)` + `MainAxisAlignment.center`**
  ///	ikisini birden verir: icerik sigiyorsa satir alan genisligine uzar ve
  ///	ORTALANIR, sigmiyorsa dogal genisligine cikar ve KAYDIRILIR.
  ///
  /// ⚠️⚠️ ILK DENEME `Align(center)` IDI ve **HICBIR SEY YAPMADI** (ekranda
  ///	olculdu): `SingleChildScrollView` cocuguna kaydirma ekseninde
  ///	**SINIRSIZ** genislik verir; sinirsiz kisitta `Align` hizalayacak
  ///	fazla alan BULAMAZ. Ortalamak icin alt sinir (`minWidth`) SART.
  /// ⚠️ YAPMA: `Center`/`Align` ile "cozdum" sayma; `LayoutBuilder`i kaldirma.
  /// ⚠️ TURU 98g — SERIT ILE ILK GONDERI ARASINDA NEFES (kullanici:
  ///    *"profili cok yaklastirmissin story alanina"*). Secici AppBara
  ///    tasininca aradaki bosluk da gitmisti.
  Widget _serit() => Padding(
    // ⚠️ Serit kendi 4 dp dikey dolgusunu tasir; 4 + 5 = **9 dp**.
    // ⚠️ GORUNEN bosluk 9 dp: serit kendi 4 dp dikey dolgusunu VE izlenmis
    //    halkanin 2 dp kenarligi icin 4 dp pay tasir (toplam 8); ustune 1.
    // ⚠️⚠️ OLCUT: seridin EN ALT GORUNEN ogesi daire DEGIL, canli/oda
    //	ROZETI (daireden ~4 dp asagi tasar). Boslugu daireye gore ayarlamak
    //	gozle 5 dp gosteriyordu; rozet olcut alininca 9 dp olur.
    padding: const EdgeInsets.only(bottom: 16),
    child: StorySeridi(key: _storyKey),
  );

  /// ⚠️⚠️⚠️ TURU 114 — **AKIS BOLME SECICISI: Arkadaş · Keşfet · Mahalle.**
  ///
  ///	Turu 113'te kullanicinin *"secici olmasin"* emriyle KALDIRILMISTI;
  ///	kullanici bu turda GERI istedi ve ucuncu ogeye YENI BIR AD verdi:
  ///	*"anasayfada ustte Arkadas Keşfet Mahalle kaldirmissin dikkat et"*.
  ///
  /// ⚠️⚠️ UCUNCU OGE ARTIK **GERCEK BIR BOLME** (eskiden "Canlı Yayın" idi ve
  ///	yalnizca alt menudeki Canli sekmesine giden bir KISAYOLDU). Bu yuzden
  ///	`_bolmeLinki` yardimcisi GERI GETIRILMEDI — uc oge de ayni
  ///	`_bolmeYazisi` govdesinden ciziliyor.
  ///
  /// ⚠️ **APPBAR ORTASINDA** duruyor, listenin ICINDE degil (turu 98f karari):
  ///	`gorunurluk.dart` gozcusu viewport'un TAMAMINI olcuyor; secici listenin
  ///	icinde olsaydi baslik arkasinda kalan kismi da "gorunur" sayilir ve
  ///	otomatik video oynatmanin `>=0.6` kapisi olcusunu SASIRIRDI.
  Widget _bolmeSecici() => LayoutBuilder(
    // ⚠️⚠️ ORTALAMA `Align` ILE OLMAZ (turu 98f'de olculdu):
    //	`SingleChildScrollView` cocuguna kaydirma ekseninde SINIRSIZ genislik
    //	verir. Dogrusu `ConstrainedBox(minWidth: alan)` +
    //	`MainAxisAlignment.center`.
    builder: (context, kisit) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // ⚠️ Normal olcekte icerik siyor; kullanici bu sarmali HIC fark etmez.
      //    Asiri yazi olceginde TASMA yerine KAYDIRMA olur.
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: kisit.maxWidth),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _bolmeYazisi(0, 'Arkadaş'),
            _bolmeYazisi(1, 'Keşfet'),
            // ⚠️ MAHALLE = konuma gore gonderiler (`GET /mahalle`). Yeni tablo
            //    ACILMADI: `posts.enlem/boylam` migration 044'ten beri var.
            _bolmeYazisi(2, 'Mahalle'),
          ],
        ),
      ),
    ),
  );

  /// Bir akis bolmesi (secilebilir).
  Widget _bolmeYazisi(int deger, String metin) =>
      _bolmeOgesi(metin, _bolme == deger, () => _bolmeDegistir(deger));

  /// Secicinin TEK govdesi.
  ///
  /// ⚠️⚠️ **SECILI HAL BOYUT DEGISTIRMEZ** (kullanici emri: *"gecislerde
  ///	buyume kuculme patlama olmasin"*). Kutu genisligini DAIMA w800 olan
  ///	GORUNMEZ bir kopya belirler; ustteki gercek yazi onun icinde cizilir.
  ///	Kalinlik da SABIT (w700) — turu 97c'de kullanici IKINCI kez *"gecis
  ///	yaparken oynuyor"* dedi ve ayrim yalniz RENGE dusuruldu.
  /// ⚠️ YAPMA: kalinligi tekrar secime bagli yapma.
  Widget _bolmeOgesi(String metin, bool secili, VoidCallback onTap) {
    final renk = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: secili,
      label: metin,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // ⚠️ Dikey 12 + yazi ~17 + 12 = ~41 dp; yatay 10 ile birlikte
          //    dokunma hedefi rahatca 44 dp'yi asar.
          // ⚠️ TURU 114 (denetim) — yatay dolgu 10 -> 8: 360 dp'de baslik
          //    alani 256 dp ve uc oge sinirda kaliyordu. Sarmal zaten
          //    kaydiriyor (tasma imkansiz) ama 12 dp kazanmak ucunun de
          //    NORMAL olcekte tam gorunmesini saglar.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Stack(
            // ⚠️ `centerLeft` ZORUNLU: ortalama kullanilsaydi secili olmayan
            //    (daha soluk) yazi gorunmez kutunun ICINDE saga kayardi.
            alignment: Alignment.centerLeft,
            children: [
              Opacity(
                opacity: 0,
                child: Text(
                  metin,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                metin,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: secili ? renk : renk.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bolmeDegistir(int yeni) {
    if (yeni == _bolme) return;
    // ⚠️ Mevcut bolmenin kaydirma konumu SAKLANIR — geri donunce kullanici
    //    kaldigi yerde olsun (liste zaten bellekte).
    if (_kaydirma.hasClients) _bolmeKaydirma[_bolme] = _kaydirma.offset;
    setState(() {
      _bolme = yeni;
      _hata = null;
    });
    // ⚠️ DAHA ONCE YUKLENDIYSE AG ISTEGI ATMA.
    if (!_bolmeYuklendi[yeni]) {
      // ⚠️⚠️ TURU 80b — YUTULAN YENILEME (denetim: YUKSEK).
      //
      //	`_yenile()`nin ILK SATIRI `if (_yukleniyor) return;`. Onceki bolmenin
      //	istegi HALA UCARKEN bolme degistirilirse bu cagri SESSIZCE dusuyordu;
      //	`_bolmeYuklendi[yeni]` false kaldigi icin de bir daha DENEYEN HICBIR
      //	YOL yoktu. Sonuc: bolme KALICI BOS.
      unawaited(_bolmeYukle(yeni));
      return;
    }
    // ⚠️ Kaydirma geri yuklemesi bir sonraki KAREDE yapilir: liste bu karede
    //    henuz yeniden olculmedi, `jumpTo` `maxScrollExtent`i asardi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_kaydirma.hasClients) return;
      final hedef = _bolmeKaydirma[yeni].clamp(
        0.0,
        _kaydirma.position.maxScrollExtent,
      );
      _kaydirma.jumpTo(hedef);
    });
  }

  /// Bir bolmeyi yukler; ucusta baska bir istek varsa BITMESINI bekler.
  ///
  /// ⚠️ Sinirli deneme: **IKI TUR x 10 x 150 ms = en fazla ~3 sn**. Sonsuz
  ///    dongu YOK; tukenirse asagi-cek yolu ACIK kalir.
  /// ⚠️ Her turda `mounted` + bolme kimligi dogrulanir.
  Future<void> _bolmeYukle(int hedef) async {
    for (var tur = 0; tur < 2; tur++) {
      for (var i = 0; i < 10 && _yukleniyor; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!mounted || _bolme != hedef) return;
      }
      if (!mounted || _bolme != hedef || _bolmeYuklendi[hedef]) return;
      await _yenile();
      if (!mounted || _bolme != hedef || _bolmeYuklendi[hedef]) return;
    }
  }

  void _profileGit(String userId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: userId)));
  }

  /// ⚠️⚠️ TURU 90b — MENU SONUCU **OKUNUR**.
  ///
  /// Turu 90'in menusu ekrani `nav.push(...)` ile aciyor ve DONEN ID'yi
  /// ATIYORDU. `GonderiOlustur` `pop(postId)` ile id dondurur; akis onu
  /// kullanarak kendini tazeler. Okunmayinca kullanici paylasip geri
  /// donuyor ve **gonderisini akista GORMUYORDU** (profildeki
  /// `gonderi_sayisi` da bayat kaliyordu). Eski yol bunu DOGRU yapiyordu —
  /// menu onu ulasilamaz kilinca davranis GERILEDI.
  Future<void> _olusturMenusu() =>
      olusturMenusuAc(context, sonrasinda: _paylasimSonrasi);

  void _paylasimSonrasi(String? id) {
    if (id == null || !mounted) return;
    unawaited(_yenile());
    ref.invalidate(myProfileProvider);
  }

  // ⚠️ TURU 90b — `_olustur()` **SILINDI**: FAB artik olusturma menusunu
  //    aciyor ve menu ekrani kendisi push edip sonucu `_paylasimSonrasi`ya
  //    veriyor. Govde ayni ise iki yoldan yapilsaydi (biri menuden, biri
  //    dogrudan) "ayni kuralin iki kopyasi drift eder" sinifi acilirdi:
  //    tazeleme mantigi birinde guncellenip digerinde unutulurdu.

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final benimId = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();

    return Scaffold(
      appBar: AppBar(
        // ⚠️⚠️ TURU 76b — SOL UST HAMBURGER (kullanici emri: "anasayfada sol
        //    ustte menu ikonu olsun, 2 satir cizgi").  KULLANILDI:
        //    Akis kok route oldugu icin AppBar oraya geri oku KOYMAZ, cakisma YOK.
        // ⚠️⚠️⚠️ TURU 96z — SOL USTTE **HAMBURGER YERINE "+" (squarePlus)**
        //	ve islevi **SAG ALTTAKI FABIN ISLEVI** (kullanici emri: *"sol
        //	ustteki hamburgeri kaldir, yerine + icon square-plus ekle"* +
        //	*"sag alttaki + sol ustteki + yerine gececek islev olarak"*).
        //
        // ⚠️⚠️ MENUYE GIRIS KAYBOLMADI: hamburgerin actigi hizmet menusu
        //    artik ALT MENUDEKI LOGOYA baglidir (turu 96n).
        // ⚠️ FAB **KALDIRILDI** (asagida): ayni islevin iki dugmesi
        //    olsaydi kullanici hangisinin ne yaptigini bilemezdi ve turu
        //    90bdeki "iki FAB ust uste" hatasinin kardesi dogardi.
        // ⚠️⚠️ TURU 98m — SOL KENAR HIZASI (kullanici: *"hizalamada sorun
        //	var, + cok solda, gorsel ile begen ikonu ayni hizada degil"*).
        //	Ikon KUTUNUN ORTASINA cizilir; glyph sol kenari `kYanBosluk`ta
        //	olsun diye kutu = 2*16 + ikon.
        // ⚠️ OLCULDU: `squarePlus` glyphi 26 lik kutusunun icinde ~2.3 dp
        //    iceride basliyor; kutu 58 iken sol kenar 18.3 cikiyordu.
        leadingWidth: kYanBosluk * 2 + kAltMenuIkonBoy - 5,
        leading: IconButton(
          // ⚠️⚠️ TURU 98e — IKON BOYU **ALT MENUYLE AYNI** (kullanici emri:
          //	*"sol ustteki + ve bildirim ikonlari alt menudeki ikonlar
          //	ile ayni buyuklukte olacak"*). Sabit `alt_menu.dart`tan
          //	IMPORT edilir — iki cubuk arasinda drift YAPISAL OLARAK
          //	imkansiz olsun diye (bu projede "ayni olcu iki yerde"
          //	sinifi defalarca sahaya cikti).
          iconSize: kAltMenuIkonBoy,
          icon: const Icon(LucideIcons.squarePlus),
          tooltip: "Oluştur",
          onPressed: _olusturMenusu,
        ),
        // ⚠️⚠️ TURU 80 — BURADAKI "Akış | Kanallar" SECICISI **KALDIRILDI**
        //    (kullanici emri). Yerine gelen "Takip Ettiklerin | Keşfet"
        //    secicisi HIKAYE SERIDININ ALTINDA (bkz. `_bolmeSecici`).
        //    Kanallar sol ust hamburger menuye TASINDI — o secici kanallarin
        //    TEK GIRISIYDI, yerine bir sey konmasaydi ozellik OLURDU.
        // ⚠️⚠️ TURU 82 — "Gebzem" BASLIGI KALDIRILDI (kullanici emri:
        //    *"anasayfada gebzem yazisini kaldir"*). Onceki serh basligi
        //    "hamburger havada kalmasin" diye savunuyordu; sag tarafta
        //    BILDIRIM dugmesi (tek `actions` ogesi) VAR, yani cubugun iki ucu
        //    da dolu.
        //    ⚠️ Bu serh once "bildirim + arama dugmeleri" (COGUL) diyordu;
        //       denetim govdede TEK dugme oldugunu gosterdi. Arama ALT MENUDE
        //       kendi sekmesinde (turu 76), AppBar'da DEGIL.
        // ⚠️ YAPMA: baslik geri ekleme.
        // ⚠️⚠️ TURU 83 — YAZI YERINE **LOGO, TAM ORTADA** (kullanici emri:
        //    *"logo bu, header ortada olacak, olcuyu ona gore ayarla"*).
        //
        // ⚠️ `centerTitle: true` BURADA ACIKCA veriliyor: `theme.dart`taki
        //    `appBarTheme` genelinde `centerTitle: false` (baslik SOLDA) —
        //    tema degeri EZILMEZSE logo sola yapisir.
        // ⚠️ OLCU: AppBar govdesi 56dp. Logo **32dp** — ustte/altta 12'ser dp
        //    nefes birakir, hamburger (sol) ve bildirim (sag) dugmeleriyle
        //    cakismaz. Daha buyugu (40+) cubugu doldurup sikisik gosteriyordu.
        // ⚠️ `ClipRRect` 8dp: logo KARE bir ikon; koseleri yumusatilmadan
        //    cubukta sert duruyor.
        // ⚠️ `errorBuilder` ZORUNLU: logo dosyasi degistirilirken bozuk/eksik
        //    kalirsa AppBar KIRMIZI HATA KUTUSU cizerdi.
        // ⚠️ LOGOYU DEGISTIRMEK ICIN YALNIZ `assets/icon/logo.png` degisir —
        //    bu koda DOKUNMAYA GEREK YOK.
        centerTitle: true,
        // ⚠️⚠️⚠️ TURU 98f — SECICI **APPBAR ORTASINA** TASINDI (kullanici
        //	emri: *"Arkadaslar · Kesfet · Canli Yayin bunlari header
        //	ortasina, + ile bildirim arasina yapacaktin"*).
        //
        //	Onceden hikaye seridinin ALTINDA, listenin i==1 ogesiydi (turu
        //	80 karari) ve akisla birlikte KAYIYORDU; artik ust cubukta
        //	SABIT duruyor. Liste indisleri de buna gore 1 azaltildi.
        // ⚠️ centerTitle: true ZORUNLU (tema geneli false).
        // ⚠️ Secici hala yatay KAYDIRILABILIR: asiri yazi olceginde dar
        //    alana sigmazsa kayar, TASMAZ.
        // ⚠️ TURU 98f — `titleSpacing: 0`: varsayilan 16+16 dp bosluk
        //    "Canlı Yayın"in son harfini KIRPIYORDU (ekranda olculdu).
        // ⚠️ TURU 98f — `titleSpacing: 0`: varsayilan 16+16 dp bosluk en
        //    sagdaki etiketin son harfini KIRPIYORDU (ekranda olculdu).
        titleSpacing: 0,
        title: _bolmeSecici(),
        // ⚠️⚠️ TURU 96z — **ORTADAKI LOGO KALDIRILDI** (kullanici emri:
        //	*"ortadaki logoyu kaldir"*). Logo artik ALT MENUNUN ortasinda
        //	duruyor ve menuyu aciyor; AppBarda ikinci bir kopyasi
        //	gereksiz tekrardi.
        // ⚠️ `centerTitle` bilerek DURUYOR: ileride bir baslik konursa
        //    ortalanmis gelsin (tema geneli `centerTitle: false`).
        actions: [
          // ⚠️⚠️ TURU 76 — BURADAKI "Reels" DUGMESI KALDIRILDI. Reels artik ALT
          //    MENUDE kendi sekmesi. Ikisini birden birakmak, kullanicinin ayni
          //    ekrani IKI FARKLI yoldan (biri route PUSH'u, digeri sekme)
          //    acabilmesi demekti; push edilen kopya sekme degistirilince
          //    ustte KALIR ve iki oynatici ayni anda yasayabilirdi.
          //    ⚠️ YAPMA: bu dugmeyi geri ekleme.
          // TURU 76: okunmamis rozeti. Sayac WS 'bildirim.yeni' olayinda yerel
          // olarak artar, sayfaya girilince sifirlanir.
          // ⚠️ TURU 98m — sag kenar hizasi: IconButton kutusu 48, ikon 26,
          //    yani glyph sagdan 11 dp iceride; 5 dp daha eklenince 16 olur.
          Padding(
            // ⚠️ OLCULDU: 5 dp ile sag kenar 18.3 cikiyordu -> 3.
            padding: const EdgeInsets.only(right: 3),
            child: BildirimRozeti(
              child: IconButton(
                // ⚠️ TURU 98e — alt menuyle AYNI olcu (yukaridaki serh).
                iconSize: kAltMenuIkonBoy,
                // ⚠️ TURU 96z — ikon **bildirim (bell)** (kullanici emri:
                //    *"en sagdaki ise push icon olacak"*). Onceki
                //    `trendingUp` bildirimle ilgisi olmayan bir grafik
                //    okuydu; dugmenin ISLEVI zaten bildirimlerdi.
                icon: const Icon(LucideIcons.bell),
                tooltip: 'Bildirimler',
                onPressed: () async {
                  ref.read(bildirimSayaciProvider.notifier).sifirla();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BildirimlerSayfasi(),
                    ),
                  );
                  // Sayfada 'okundu' isaretlendi; sunucuyla hizala.
                  if (context.mounted) {
                    unawaited(
                      ref.read(bildirimSayaciProvider.notifier).tazele(),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
      // ⚠️ TURU 80 — FAB ARTIK HER IKI BOLMEDE de var: eski "Kanallar" bolmesi
      //    kendi "Kanal aç" FAB'ini tasidigi icin gizleniyordu; "Keşfet"in
      //    boyle bir dugmesi YOK ve orada gonderi paylasamamak icin sebep yok.
      // ⚠️⚠️ TURU 96z — **FAB KALDIRILDI**: islevi sol ustteki "+"
      //    (squarePlus) dugmesine tasindi (kullanici emri).
      // ⚠️⚠️ TURU 80 — `IndexedStack` **KALDIRILDI** (bkz. `_listeler` serhi).
      //    Iki bolme artik TEK govdeyi paylasiyor; ayrim VERIDE (`_listeler`),
      //    widget agacinda DEGIL. Boylece gorunmeyen bolmenin videosu
      //    yasamiyor ve akista otomatik oynatmanin dort kapisi bozulmuyor.
      body: YenileSarmali(onRefresh: _elleYenile, child: _govde(benimId)),
    );
  }

  Widget _govde(String benimId) {
    if (_ilkYukleme) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null && _liste.isEmpty) {
      return ListView(
        // ⚠️⚠️ TURU 77b — AlwaysScrollableScrollPhysics ZORUNLU (denetim bulgusu).
        //    Icerik ekrani DOLDURMAYINCA Android varsayilani
        //    (ClampingScrollPhysics) kullanici kaydirmasini KABUL ETMEZ ->
        //    sarmalayici RefreshIndicator TETIKLENMEZ. Ustelik AkisEkrani
        //    IndexedStack icinde CANLI kaldigi icin sekme degistirip donmek de
        //    yeniden yuklemiyordu: YENI kullanici uygulamayi OLDURMEDEN akisini
        //    TAZELEYEMIYORDU (bos akis = tam da yeni kullanicinin durumu).
        //    ⚠️ YAPMA: bos/hata dallarindan bu satiri kaldirma.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _serit(),
          const SizedBox(height: 120),
          Center(child: Text(_hata!)),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: _elleYenile,
              child: const Text('Tekrar dene'),
            ),
          ),
        ],
      );
    }
    // ⚠️⚠️ TURU 80b — HENUZ YUKLENMEMIS BOLME "BOS" DEGILDIR (denetim).
    //
    //	`_ilkYukleme` yalnizca UYGULAMA acilisindaki ILK yuklemeyi temsil
    //	eder. Kullanici Keşfet'e ILK kez gectiginde o bayrak coktan false
    //	oldugu icin, istek daha ucarken **"Henüz gönderi yok"** cizilyordu —
    //	yani icerik VARKEN kullaniciya "hicbir sey yok" deniyordu ve cogu
    //	kullanici o noktada sekmeyi terk ederdi.
    // ⚠️ YAPMA: bu dali `_ilkYukleme` ile birlestirme (o bayrak bolmeye
    //    ozgu DEGIL ve olamaz — bkz. `_dahaVarlar`/`_kesfetler` serhi).
    if (_liste.isEmpty && !_bolmeYuklendi[_bolme]) {
      // ⚠️⚠️ KAYDIRILABILIR OLMAK ZORUNDA (turu 77b dersi, kendi eklememde
      //    tekrarladim): duz bir `Center` KAYDIRILAMAZ, dolayisiyla sarmalayici
      //    `RefreshIndicator` TETIKLENMEZ. `_bolmeYukle` 1.5sn'de pes ederse
      //    (ucustaki istek uzarsa) bolme yuklenmemis kalir, `_hata` da null
      //    oldugu icin hata dali cizilmez ve kullanici **kurtarma yolu olmayan
      //    kalici bir spinner** gorurdu. Asagi-cek artik HER ZAMAN mumkun.
      // ⚠️ YAPMA: bu dali tekrar ciplak `Center`a cevirme.
      // ⚠️⚠️ SERIT + BOLME SECICISI **BURADA DA CIZILIR** (turu 80b denetimi).
      //    Ilk yazimda yalniz spinner vardi; Keşfet yuklenirken secici
      //    EKRANDAN KAYBOLUYORDU ve kullanicinin "Takip Ettiklerin"e GERI
      //    DONME YOLU KALMIYORDU (yavas agda saniyelerce). Dosyadaki diger
      //    tum bos/hata dallari ikisini de ciziyor — bu dal ONLARDAN SAPMISTI.
      // ⚠️ YAPMA: bu dali yalniz spinner'a indirgeme.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _serit(),
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_liste.isEmpty) {
      return ListView(
        // ⚠️⚠️ TURU 77b — AlwaysScrollableScrollPhysics ZORUNLU (denetim bulgusu).
        //    Icerik ekrani DOLDURMAYINCA Android varsayilani
        //    (ClampingScrollPhysics) kullanici kaydirmasini KABUL ETMEZ ->
        //    sarmalayici RefreshIndicator TETIKLENMEZ. Ustelik AkisEkrani
        //    IndexedStack icinde CANLI kaldigi icin sekme degistirip donmek de
        //    yeniden yuklemiyordu: YENI kullanici uygulamayi OLDURMEDEN akisini
        //    TAZELEYEMIYORDU (bos akis = tam da yeni kullanicinin durumu).
        //    ⚠️ YAPMA: bos/hata dallarindan bu satiri kaldirma.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _serit(),
          const SizedBox(height: 100),
          const Icon(LucideIcons.images, size: 54, color: Colors.grey),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            // ⚠️⚠️ TURU 114 — METIN **UC DALLI** (denetim bulgusu). Iki dalliyken
            //	Mahalle bos donunce kullaniciya *"birilerini takip et"*
            //	deniyordu; oysa mahalle akisinda takip iliskisi HIC sorulmaz.
            //	YANLIS TAVSIYE, bos ekrandan daha kotudur: kullanici sorunu
            //	cozmek icin ise yaramayacak bir sey yapardi.
            child: Text(
              switch (_bolme) {
                2 =>
                  'Çevrende konum paylaşan gönderi yok.\n'
                      'Yakınındaki gönderiler burada görünür.',
                1 => 'Keşfedilecek gönderi bulunamadı.\nBiraz sonra tekrar bak.',
                _ =>
                  'Henüz gönderi yok.\n'
                      'İlk paylaşımı sen yap ya da birilerini takip et.',
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _kaydirma,
      // ⚠️⚠️ TURU 90b — **OLCULDU**: FAB (56dp, dipten 16dp) merkezi ile son
      //    gonderinin KAYDET dugmesi arasindaki uzaklik 16.8dp, dugmenin
      //    dokunma yaricapi ise 28dp -> kaydet, FAB dairesinin TAM ICINDE
      //    kaliyor ve dokunusu FAB aliyordu.
      //    ⚠️ Son ogedeki `SizedBox`i buyutmek YETMEZ: `_dahaVar` true iken
      //       o dal HIC cizilmez.
      padding: const EdgeInsets.only(bottom: 80),
      // ⚠️ ILK OGE HER ZAMAN HIKAYE SERIDI (kullanici emri: 'anasayfada
      //    storyler'). Serit akisla BIRLIKTE kayar (Instagram deseni) —
      //    sabit birakmak 106px'i kalici olarak yer.
      // ⚠️ TURU 80: +1 hikaye seridi / **+1 BOLME SECICI** / +1 kesfet seridi /
      //    +1 alt yukleme gostergesi. Secici eklendiginde bu sayac da
      //    guncellendi — atlanmis olsaydi listenin SON KARTI cizilmezdi.
      // ⚠️ TURU 98f — secici ARTIK APPBARDA; listeden CIKTI, bu yuzden
      //    sayac +2 yerine **+1** (yalniz hikaye seridi) ve indis kaymasi da
      //    1 azaldi. Atlanirsa listenin SON KARTI cizilmezdi.
      itemCount: _liste.length + 1 + (_kesfet ? 1 : 0) + 1,
      itemBuilder: (_, i) {
        // ⚠️ TURU 80: 0 = hikaye seridi, 1 = BOLME SECICI (kullanici emri:
        //    "hikaye dairesinin ALTINA"). Ikisi de akisla BIRLIKTE kayar.
        if (i == 0) return _serit();
        var idx = i - 1;
        if (_kesfet) {
          if (idx == 0) return _kesfetSeridi();
          idx = idx - 1;
        }
        if (idx >= _liste.length) {
          // ⚠️ TURU 82b — "Hepsi bu kadar" yazisi KALDIRILDI (kullanici emri).
          //    Liste bittiginde artik HICBIR SEY cizilmez; yalnizca DAHA VARSA
          //    yukleme gostergesi kalir.
          // ⚠️ `SizedBox.shrink()` donulur, oge SILINMEZ: `itemCount` bu son
          //    ogeyi sayiyor (+1) ve burada `null`/kisa liste dondurmek son
          //    KARTIN cizilmemesine yol acardi (turu 80 dersi).
          if (!_dahaVar) return const SizedBox(height: 8);
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final g = _liste[idx];
        return GonderiKarti(
          // ⚠️ ANAHTAR ZORUNLU: anahtarsiz, liste yenilenince Flutter kart
          //    state'ini (begeni animasyonu, sayfa indeksi) YANLIS karta tasir.
          key: ValueKey(g.id),
          gonderi: g,
          benimId: benimId,
          profileGit: _profileGit,
          // ⚠️⚠️ TURU 80b — SILME **HER IKI BOLMEDEN** (denetim).
          //    Ayni gonderi hem "Takip Ettiklerin"de hem Keşfet'te bulunabilir
          //    (takip ettigin biri kesfete de dusebilir). Yalniz aktif
          //    bolmeden silinseydi kullanici diger sekmeye gecince SILDIGI
          //    gonderiyi TEKRAR gorurdu — ve oradan tekrar silmeye calisinca
          //    sunucu 404 doner, yani "silinmedi" izlenimi kalicilasirdi.
          onSilindi: () => setState(() {
            for (final l in _listeler) {
              l.removeWhere((x) => x.id == g.id);
            }
          }),
        );
      },
    );
  }

  Widget _kesfetSeridi() => Container(
    width: double.infinity,
    color: const Color(0x228B5CF6),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: const Row(
      children: [
        Icon(LucideIcons.compass, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Keşfet — kimseyi takip etmiyorsun. Beğendiğin kişileri takip et, akışın kişiselleşsin.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

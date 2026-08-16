import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../home/home_screen.dart' show myProfileProvider, aktifSekme;
import 'bildirim_sayaci.dart';
import 'bildirimler_sayfasi.dart';
import 'gonderi_karti.dart';
import 'hizmet_menusu.dart';
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
  final List<bool> _dahaVarlar = [true, true];
  final List<bool> _kesfetler = [false, false];

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
  final List<List<Gonderi>> _listeler = [<Gonderi>[], <Gonderi>[]];
  final List<bool> _bolmeYuklendi = [false, false];
  final List<double> _bolmeKaydirma = [0, 0];

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
      // ⚠️ Servis await'ten ONCE yakalanir (turu 78b dersi: disposed State'te
      //    `ref.read` StateError firlatir ve is SESSIZCE iptal olur).
      final svc = ref.read(sosyalServisiProvider);
      final List<Gonderi> gelen;
      if (bolme == 1) {
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
    await _yenile();
  }

  Future<void> _dahaGetir() async {
    if (_yukleniyor || !_dahaVar || _liste.isEmpty) return;
    setState(() => _yukleniyor = true);
    try {
      // ⚠️ Servis ve bolme kimligi await'ten ONCE (bkz. `_yenile` serhi).
      final svc = ref.read(sosyalServisiProvider);
      final bolme = _bolme;
      final imlec = _liste.last.createdAt;
      final gelen = bolme == 1
          ? await svc.kesfetAkisi(before: imlec)
          : (await svc.akis(before: imlec)).gonderiler;
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
  Widget _bolmeSecici() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // ⚠️ Kaydirma cubugu YOK ve normal olcekte icerik zaten sigiyor, yani
      //    kullanici bu sarmali HIC fark etmez; yalniz asiri olcekte devreye girer.
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          // ⚠️ TURU 97 — 'Takip Ettiklerin' -> **'Arkadaşlar'** (kullanici emri).
          _bolmeYazisi(0, 'Arkadaşlar'),
          _bolmeYazisi(1, 'Keşfet'),
          // ⚠️⚠️ 'Canlı Yayın' bir AKIS BOLMESI DEGIL, alt menudeki CANLI
          //	sekmesine giden bir KISAYOLDUR (kullanici emri: *"kesfetin
          //	sagina Canli Yayin olsun"*).
          //
          // ⚠️⚠️ UCUNCU BOLME OLARAK EKLENMEDI ve sebebi kullanicinin
          //	kendi uyarisidir (*"yer degistirince patlamasin"*):
          //	`_bolmeYuklendi` ve `_bolmeKaydirma` **IKI ELEMANLI** sabit
          //	dizilerdir; `_bolme = 2` yazmak bu dizilerde RANGE ERROR
          //	verirdi. Yayin listesi ZATEN `LiveTab`ta yasiyor — ikinci bir
          //	kopya yazmak yerine oraya goturuluyor.
          // ⚠️ YAPMA: buraya `_bolmeYazisi(2, ...)` yazma; once iki diziyi
          //    ve `_bolmeYukle` dallarini uc elemana cikarman gerekir.
          _bolmeLinki('Canlı Yayın', () => aktifSekme.value = 4),
        ],
      ),
    ),
  );

  /// Baska bir SEKMEYE goturen secici ogesi (secili hali YOKTUR).
  Widget _bolmeLinki(String metin, VoidCallback git) => Semantics(
        button: true,
        label: metin,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: git,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text(
              metin,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.45,
                    ),
              ),
            ),
          ),
        ),
      );

  Widget _bolmeYazisi(int deger, String metin) {
    final secili = _bolme == deger;
    return Semantics(
      button: true,
      selected: secili,
      label: metin,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _bolmeDegistir(deger),
        child: Padding(
          // ⚠️ Dikey 12 + yazi ~17 + 12 = ~41dp; yatay 10 ile birlikte
          //    dokunma hedefi rahatca 44dp'yi asar.
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          // ⚠️⚠️⚠️ TURU 82b — YERLESIM OYNAMASI KAPATILDI (kullanici emri:
          //    *"Takip ettiklerin ve Kesfet'e tikladiginda OYNAMA oluyor,
          //    buyume kuculme olmasin"*).
          //
          //    KOK NEDEN: `fontWeight` w500 <-> w800 arasinda degisiyordu ve
          //    KALIN METIN DAHA GENISTIR. Secim degisince iki etiketin de
          //    genisligi degisiyor, `Row` yeniden olculuyor ve YAZILAR YANA
          //    KAYIYORDU (tiklamada "ziplama" hissi).
          //
          //    COZUM: her etiket bir `Stack` icinde cizilir; altta GORUNMEZ
          //    (`Opacity(0)`) ama DAIMA **w800** olan bir kopya durur ve kutu
          //    genisligini O belirler. Ustteki gercek yazi bu sabit kutunun
          //    icinde ortalanir -> kalinlik degisse de **genislik DEGISMEZ**.
          // ⚠️ YAPMA: kalinlik farkini kaldirip yalniz renge dusurme —
          //    kullanici "yazi KALIN" istedi ve tek isaret renk korlugunde
          //    ayirt edilemez (turu 80 karari).
          // ⚠️ YAPMA: `AnimatedDefaultTextStyle` ile yumusatmaya calisma;
          //    genislik yine degisir, oynama SURER.
          child: Stack(
            // ⚠️⚠️ `centerLeft` ZORUNLU, `center` DEGIL. Kutu genisligini
            //    gorunmez w800 kopya belirliyor; ortalama kullanilsaydi
            //    SECILI OLMAYAN (daha dar w500) yazi kutunun ICINDE saga
            //    kayar ve kullanicinin turu 80'de acikca istedigi
            //    *"yazi SOLDA olacak"* kurali bozulurdu.
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
                  // ⚠️ TURU 82 — kullanici emri: +2px (15 -> 17).
                  fontSize: 17,
                  // ⚠️ Aktif/pasif AYRIMI IKI ISARETLE: kalinlik VE renk.
                  fontWeight: secili ? FontWeight.w800 : FontWeight.w500,
                  color: secili
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.45),
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
    // ⚠️ DAHA ONCE YUKLENMEDIYSE getir; yuklendiyse AG ISTEGI ATMA.
    if (!_bolmeYuklendi[yeni]) {
      // ⚠️⚠️ TURU 80b — YUTULAN YENILEME (denetim: YUKSEK).
      //
      //	`_yenile()`nin ILK SATIRI `if (_yukleniyor) return;`. Onceki
      //	bolmenin istegi HALA UCARKEN bolme degistirilirse bu cagri
      //	SESSIZCE dusuyordu; `_bolmeYuklendi[yeni]` false kaldigi icin
      //	de bir daha DENEYEN HICBIR YOL yoktu (`_kaydirmaDinle` bos
      //	listede tetiklenmez, asagi-cek ise ancak kullanici bunu
      //	kendiliginden denerse). Sonuc: Keşfet sekmesi KALICI BOS.
      // ⚠️ Ucustaki istek bittiginde bayrak temizlenir; o ana kadar
      //    bekleyip TEKRAR deniyoruz (yeniden giris kilidi `_yenile`de).
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
  /// ⚠️ Sinirli deneme: **IKI TUR x 10 x 150ms = en fazla ~3sn** bekleme
  ///    (artı her turda bir `_yenile` denemesi). Sonsuz dongu YOK.
  /// ⚠️ Tukenirse KURTARMA YOLLARI ACIK KALIR — ikisi de govdede GERCEKTEN var:
  ///    (1) yukleme dali KAYDIRILABILIR cizilir, yani asagi-cek mumkun;
  ///    (2) asagi-cek `_elleYenile`ye baglidir, o da ucustaki istegin
  ///        bitmesini BEKLER (dogrudan `_yenile` olsaydi `_yukleniyor`
  ///        kapisinda sessizce yutulurdu — tam da gerektigi anda).
  /// ⚠️ Her turda `mounted` + bolme kimligi dogrulanir: kullanici geri
  ///    donduyse ISTEK ATILMAZ.
  Future<void> _bolmeYukle(int hedef) async {
    // ⚠️ IKI TUR: ilk turda ucustaki istegin bitmesini bekler ve dener; istek
    //    o pencereden UZUN surerse `_yenile` yine yutulur (`_yukleniyor`
    //    kapisi), bu yuzden IKINCI bir tur daha var. Sinirli (sonsuz dongu
    //    YOK) — tukenirse kullanicinin asagi-cek yolu ACIKTIR (yukleme dali
    //    kaydirilabilir cizilir).
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
        leadingWidth: 46,
        leading: IconButton(
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
          BildirimRozeti(
            child: IconButton(
              // ⚠️ TURU 96z — ikon **bildirim (bell)** (kullanici emri:
              //    *"en sagdaki ise push icon olacak"*). Onceki
              //    `trendingUp` bildirimle ilgisi olmayan bir grafik
              //    okuydu; dugmenin ISLEVI zaten bildirimlerdi.
              icon: const Icon(LucideIcons.bell),
              tooltip: 'Bildirimler',
              onPressed: () async {
                ref.read(bildirimSayaciProvider.notifier).sifirla();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BildirimlerSayfasi()),
                );
                // Sayfada 'okundu' isaretlendi; sunucuyla hizala.
                if (context.mounted) {
                  unawaited(ref.read(bildirimSayaciProvider.notifier).tazele());
                }
              },
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
          StorySeridi(key: _storyKey),
          _bolmeSecici(),
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
          StorySeridi(key: _storyKey),
          _bolmeSecici(),
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
          StorySeridi(key: _storyKey),
          _bolmeSecici(),
          const SizedBox(height: 100),
          const Icon(LucideIcons.images, size: 54, color: Colors.grey),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _bolme == 1
                  ? 'Keşfedilecek gönderi bulunamadı.\nBiraz sonra tekrar bak.'
                  : 'Henüz gönderi yok.\nİlk paylaşımı sen yap ya da birilerini takip et.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
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
      itemCount: _liste.length + 2 + (_kesfet ? 1 : 0) + 1,
      itemBuilder: (_, i) {
        // ⚠️ TURU 80: 0 = hikaye seridi, 1 = BOLME SECICI (kullanici emri:
        //    "hikaye dairesinin ALTINA"). Ikisi de akisla BIRLIKTE kayar.
        if (i == 0) return StorySeridi(key: _storyKey);
        if (i == 1) return _bolmeSecici();
        var idx = i - 2;
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

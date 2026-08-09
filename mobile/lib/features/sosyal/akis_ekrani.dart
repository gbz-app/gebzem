import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_screen.dart' show myProfileProvider;
import 'bildirim_sayaci.dart';
import 'bildirimler_sayfasi.dart';
import 'gonderi_karti.dart';
import 'hizmet_menusu.dart';
import 'gonderi_olustur.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';
import 'story_seridi.dart';

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
    try {
      // ⚠️ Serit de tazelenir — asagi cekince yalniz gonderiler yenilenseydi
      //    yeni hikayeler gorunmezdi.
      unawaited(_storyKey.currentState?.yukle() ?? Future.value());
      // ⚠️ Servis await'ten ONCE yakalanir (turu 78b dersi: disposed State'te
      //    `ref.read` StateError firlatir ve is SESSIZCE iptal olur).
      final svc = ref.read(sosyalServisiProvider);
      // ⚠️ Bolme kimligi await'ten ONCE yakalanir: kullanici yuklenirken
      //    bolme degistirirse gelen sonuc YANLIS listeye yazilmamali.
      final bolme = _bolme;
      final List<Gonderi> gelen;
      var soguk = false;
      if (bolme == 1) {
        gelen = await svc.kesfetAkisi();
      } else {
        final s = await svc.akis();
        gelen = s.gonderiler;
        soguk = s.kesfet;
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
        setState(() => _yukleniyor = false);
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
        _kesfetler[bolme] = bolme == 0 && soguk;
        _dahaVarlar[bolme] = gelen.isNotEmpty;
        _ilkYukleme = false;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ilkYukleme = false;
        _yukleniyor = false;
        _hata = 'Akış yüklenemedi';
      });
    }
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
  Widget _bolmeSecici() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
    child: SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Takip Ettiklerin')),
        ButtonSegment(value: 1, label: Text('Keşfet')),
      ],
      selected: {_bolme},
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
      ),
      onSelectionChanged: (v) => _bolmeDegistir(v.first),
    ),
  );

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
  /// ⚠️ Sinirli deneme (10 x 150ms = 1.5sn): sonsuz dongu YOK. Bu sure icinde
  ///    bitmezse kullanici asagi cekerek yenileyebilir (`_bolmeYuklendi` false
  ///    kaldigi icin bir sonraki bolme gecisi de tekrar dener).
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

  Future<void> _olustur({bool reels = false}) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => GonderiOlustur(reels: reels)),
    );
    // Paylasildiysa akisi bastan getir — kendi gonderini EN USTTE gormelisin.
    if (id != null && mounted) {
      unawaited(_yenile());
      // Profil sayaci (`gonderi_sayisi`) degisti.
      ref.invalidate(myProfileProvider);
    }
  }

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
        leadingWidth: 46,
        leading: const HamburgerDugmesi(),
        // ⚠️⚠️ TURU 80 — BURADAKI "Akış | Kanallar" SECICISI **KALDIRILDI**
        //    (kullanici emri). Yerine gelen "Takip Ettiklerin | Keşfet"
        //    secicisi HIKAYE SERIDININ ALTINDA (bkz. `_bolmeSecici`).
        //    Kanallar sol ust hamburger menuye TASINDI — o secici kanallarin
        //    TEK GIRISIYDI, yerine bir sey konmasaydi ozellik OLURDU.
        // ⚠️ Baslik "Gebzem": AppBar bomboş kalsaydi hamburger dugmesi havada
        //    duran tek oge olurdu.
        title: const Text(
          'Gebzem',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
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
      floatingActionButton: FloatingActionButton(
        // TURU 76: HERO ETIKETI ZORUNLU. Ucun de varsayilan etiketi paylasmasi
        // debug/profile derlemede route gecisinde KIRMIZI EKRAN uretiyordu;
        // release'te assert silindigi icin sessizce SON hero yaziliyor ve
        // ucus YANLIS dugmeyi tasiyordu.
        heroTag: 'fabGonderiOlustur',
        onPressed: _olustur,
        child: const Icon(LucideIcons.plus),
      ),
      // ⚠️⚠️ TURU 80 — `IndexedStack` **KALDIRILDI** (bkz. `_listeler` serhi).
      //    Iki bolme artik TEK govdeyi paylasiyor; ayrim VERIDE (`_listeler`),
      //    widget agacinda DEGIL. Boylece gorunmeyen bolmenin videosu
      //    yasamiyor ve akista otomatik oynatmanin dort kapisi bozulmuyor.
      body: RefreshIndicator(onRefresh: _yenile, child: _govde(benimId)),
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
              onPressed: _yenile,
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: _dahaVar
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Hepsi bu kadar',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
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

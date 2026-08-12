import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_basligi.dart' show kOnayliRengi;
import '../sosyal/profil_sayfasi.dart';
import 'isletme_servisi.dart';
import 'kategori_slider.dart';
import 'yakinimda_ekrani.dart';

/// ⚠️⚠️ TURU 77 — ISLETME REHBERI.
///
/// ⚠️⚠️ BU EKRAN, HAMBURGER MENUDEKI KARTLARIN GITTIGI YERDIR.
///    Turu 76b'de Yemek / Restoran / Alisveris kartlari HICBIR YERE gitmiyordu
///    ("yakında" diyordu) — bu projede tekrar eden "olu dogmus ozellik"
///    sinifiydi. Artik gercek bir listeye baglaniyor.
///
/// ⚠️⚠️ TURU 93 — YAN BOSLUK **TEK KAYNAK** (kullanici emri: *"hepsi bir
///    container icinde sol sag bosluk icinde"*). Header, slider, arama
///    kutusu, 60x60 kartlar, filtre satiri ve isletme kartlari AYNI hizada
///    durur.
/// ⚠️ YAPMA: bu ekranda elle 12/14/16 gibi yatay dolgu yazma — bir tanesi
///    guncellenip otekiler unutuldugunda hizalama SESSIZCE bozulur.
const double kYanBosluk = 16;

/// [kategori] bos ise TUM isletmeler; doluysa o kategori.
class IsletmeListesiEkrani extends ConsumerStatefulWidget {
  const IsletmeListesiEkrani({super.key, this.kategori = '', this.baslik = ''});

  final String kategori;
  final String baslik;

  @override
  ConsumerState<IsletmeListesiEkrani> createState() =>
      _IsletmeListesiEkraniState();
}

class _IsletmeListesiEkraniState extends ConsumerState<IsletmeListesiEkrani> {
  final _arama = TextEditingController();
  Timer? _gecikme;

  /// Bayat yanit kapisi — yanitlar SIRASIZ donebilir (kesfet ekraniyla ayni desen).
  int _istekNo = 0;

  /// ⚠️⚠️⚠️ **SLIDER HIC CIZILMIYORDU — AYRI SAYAC ZORUNLU.**
  ///
  ///	`_kesfiYukle` ile `_yukle` AYNI `_istekNo` sayacini paylasiyordu ve
  ///	ikisi de `initState`te ARDISIK cagriliyor:
  ///	   `_kesfiYukle()` -> jeton 1 · `_yukle()` -> jeton 2
  ///	Kesif yaniti donunce `1 != 2` cikip **SESSIZCE ATILIYORDU**. Yani
  ///	slider ve 60x60 serit **HICBIR ZAMAN** cizilmiyordu.
  /// ⚠️ YAPMA: bu iki sayaci tekrar birlestirme. Farkli iki istegin bayatlik
  ///    kapisi AYRI olmak ZORUNDA.
  int _kesifNo = 0;

  List<IsletmeOzet>? _liste;
  String? _hata;
  late String _kategori = widget.kategori;

  /// ⚠️⚠️ TURU 78 — HIZLI KARTLAR ("Şehrimde" / "Onaylı").
  ///
  /// Kullanici emri: "altta kucuk kartlar mesela yemekte yakinimda favoriler
  /// vs diye kartlar olsun".
  ///
  /// ⚠️⚠️ "YAKINIMDA" YERINE "ŞEHRİMDE" — bu bilincli ve DURUST bir karar:
  ///    GPS icin `AndroidManifest.xml`de `ACCESS_*_LOCATION`, `Info.plist`te
  ///    `NSLocation*` anahtarlari YOK. Podfile olmadigi icin
  ///    `permission_handler`in TUM izin isleyicileri derleniyor ve anahtar
  ///    eksikken konum istenirse **iOS uygulamayi ANINDA SONLANDIRIR**.
  ///    Ayrica sistemde tek bir gercek koordinat da yok (bkz. FAZ 0 koordinat
  ///    ezme duzeltmesi). Il/ilce ile ayni isi BUGUN goruyoruz; GPS ayri tur.
  ///    ⚠️ YAPMA: izin anahtarlarini eklemeden konum paketi cagirma.
  String _hizli = '';

  /// Kullanicinin kendi ilcesi — "Şehrimde" kartinin kaynagi.
  /// ⚠️ Bos ise kart CIZILMEZ (olu kart birakmiyoruz).
  String _benimIlce = '';

  /// ⚠️⚠️ TURU 92 — KESIF VERISI **SUNUCUDAN** (alt kategoriler + slaytlar).
  ///    Istemciye sabit yazmak turu 77'nin "Dart'a kategori sabiti YAZMA"
  ///    kuralinin ihlali olurdu ve yeni bir alt kategori eklemek MAGAZA
  ///    ONAYI gerektirirdi.
  /// ⚠️ TEK ISTEK: alt kategoriler ve slayt metinleri AYNI uctan gelir —
  ///    ekran acilisinda iki istek atmak turu 91'de olculen "acilistaki
  ///    es zamanli istek" maliyetini artirirdi.
  List<({String ad, String ara})> _altKategoriler = const [];
  List<({String baslik, String alt})> _slaytlar = const [];

  /// Secili alt kategori (arama metni). Bos = hicbiri.
  String _altSecili = '';

  @override
  void initState() {
    super.initState();
    _ilceyiOgren();
    _kesfiYukle();
    _yukle();
  }

  /// Kullanicinin ilcesini KENDI isletme kaydindan ogrenir.
  ///
  /// ⚠️ Bu YALNIZ isletme hesaplarinda dolu olur. Kisisel hesapta ilce bilgisi
  ///    HICBIR YERDE tutulmuyor — o yuzden "Şehrimde" karti onlarda CIZILMEZ.
  ///    Sahte bir varsayilan ("Gebze") koymak YANLIS olurdu: kullanici baska
  ///    ilcedeyse liste yanlis gelir ve sebebini anlamaz.
  Future<void> _ilceyiOgren() async {
    // ⚠️⚠️ TURU 78b — SAGLAYICI HENUZ COZULMEMISSE **BEKLENIR** (denetim).
    //    `myProfileProvider` bir `FutureProvider`dir; `initState`ten cagrilan
    //    bu metot `valueOrNull`u okuyup null bulunca SESSIZCE cikiyordu ve
    //    TEKRAR DENEYEN HICBIR SEY YOKTU -> ekran soguk acildiginda "Şehrimde"
    //    karti KALICI OLARAK cizilmiyordu (ozellik rastgele "yok" gorunuyordu).
    var id = (ref.read(myProfileProvider).valueOrNull?['id'] ?? '').toString();
    if (id.isEmpty) {
      try {
        final p = await ref.read(myProfileProvider.future);
        id = (p['id'] ?? '').toString();
      } catch (_) {
        return; // profil alinamadi: kart cizilmez (durust davranis)
      }
    }
    if (!mounted || id.isEmpty) return;
    try {
      final i = await ref.read(isletmeServisiProvider).detay(id);
      if (mounted && i != null && i.ilce.isNotEmpty) {
        setState(() => _benimIlce = i.ilce);
      }
    } catch (_) {
      // ⚠️ SESSIZ: ilce ogrenilemezse yalnizca "Şehrimde" karti cizilmez.
    }
  }

  /// Alt kategorileri ve slayt metinlerini sunucudan alir.
  ///
  /// ⚠️ HATA SESSIZ: kesif verisi gelmezse slider VARSAYILAN metinlerle
  ///    (sunucu zaten oyle donuyor) ve alt kategori seridi CIZILMEDEN
  ///    calisir. Ekranin ASIL isi (isletme listesi) bundan BAGIMSIZ.
  Future<void> _kesfiYukle() async {
    // ⚠️⚠️ TURU 93b — BAYAT YANIT KAPISI (denetim: kardes metotta VARDI,
    //	BURADA YOKTU).
    //
    //	Kullanici filtre sheet'inde ChoiceChip'ler yan yana oldugu icin
    //	hizlica "Yemek" -> "Kuaför" secebiliyor. Iki `kesif` istegi PARALEL
    //	ucar; Yemek'in yaniti GEC gelirse Kuaför'un uzerine YAZAR. Ekranda
    //	"Kuaför" cipi SECILI gorunur ama alt kategori kartlari
    //	**Döner/Kebap/Pide** olur. Kullanici "Döner"e basar ->
    //	`kategori=kuafor` + `q=döner` -> **KALICI BOS LISTE**, sebebi
    //	ekranda hicbir yerde yazmaz.
    // ⚠️⚠️ **AYRI SAYAC** (`_kesifNo`): `_yukle` ile paylasilirsa ikisi de
    //    `initState`te ardisik cagrildigi icin kesif yaniti DAIMA bayat
    //    sayilir ve slider HIC CIZILMEZ (bkz. `_kesifNo` serhi).
    final jeton = ++_kesifNo;
    try {
      final d = await ref.read(isletmeServisiProvider).kesif(_kategori);
      if (!mounted || jeton != _kesifNo) return;
      setState(() {
        _altKategoriler = d.altKategoriler;
        _slaytlar = d.slaytlar;
      });
    } catch (_) {
      // ⚠️ SESSIZ: slider ve serit cizilmez, ekranin ASIL isi (liste)
      //    bundan bagimsiz calisir. Kurtarma yolu asagi-cek (`_tazele`).
    }
  }

  /// ⚠️⚠️ TURU 93b — KATEGORI DEGISTIRMENIN **TEK KAPISI** (denetim).
  ///
  /// Onceden kategori UC ayri yerde yaziliyordu ve `_altSecili` sifirlamasi
  /// YALNIZ BIRINDE vardi:
  ///   · kategori cipi secimi          -> `_altSecili = ''`  ✓
  ///   · "Tümü" cipi                   -> **YOK**
  ///   · `InputChip.onDeleted` (✕)     -> **YOK**
  ///
  /// Sonuc: "Yemek → Döner" seciliyken "Tümü"ye basan kullanicida
  /// `_altSecili='döner'` KALIYORDU. Yeni kategoride o kart LISTEDE
  /// OLMADIGI icin secili gorunmuyor bile — yani **GORUNMEZ bir suzgec**
  /// takili kaliyor ve kullanici neden az sonuc gordugunu EKRANDA HICBIR
  /// YERDE goremiyordu.
  ///
  /// ⚠️ Duzeltmenin dogru yeri "ucuncu dala da o satiri ekle" DEGIL, tek
  ///    kapiya indirmektir: dordunc bir dal eklendiginde ayni hata
  ///    tekrarlanmasin.
  /// ⚠️ YAPMA: `_kategori`ye bu metodun DISINDA atama yapma.
  void _kategoriSec(String k) {
    setState(() {
      _kategori = k;
      _altSecili = '';
    });
    _gecikme?.cancel();
    _kesfiYukle();
    _yukle();
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final jeton = ++_istekNo;
    try {
      final l = await ref
          .read(isletmeServisiProvider)
          .liste(
            kategori: _kategori,
            // ⚠️ ALT KATEGORI **ARAMA METNINE** cevrilir (ayri sutun YOK —
            //    gerekce sunucudaki `altkategori.go` serhinde). Kullanici
            //    hem kart secip hem yazi yazabilir; ikisi BIRLESTIRILIR.
            q: [_altSecili, _arama.text.trim()]
                .where((x) => x.isNotEmpty)
                .join(' '),
            // ⚠️ Hizli kart suzgecleri SUNUCUYA gider. Istemcide suzmek YANLIS
            //    olurdu: sunucu `LIMIT 60` donuyor, istemci 3'e dusurseydi
            //    kullanici "sadece 3 isletme var" sanirdi.
            ilce: _hizli == 'sehrimde' ? _benimIlce : '',
            yalnizOnayli: _hizli == 'onayli',
          );
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (_) {
      if (!mounted || jeton != _istekNo) return;
      setState(() => _hata = 'İşletmeler alınamadı');
    }
  }

  void _aramaDegisti(String _) {
    _gecikme?.cancel();
    // ⚠️ 320ms gecikme — her tusa basista istek atmak sunucuyu bosuna yorar.
    _gecikme = Timer(const Duration(milliseconds: 320), _yukle);
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      // ⚠️⚠️⚠️ TURU 92 — **APPBAR KALDIRILDI** (kullanici emri: *"'Yemek'
      //    yazisi gerek yok, sadece GERI IKONU"*). Baslik slider'in
      //    kendisinde degil, HIC YOK; geri ve harita ikonlari slider'in
      //    USTUNDE yuzuyor.
      // ⚠️ `extendBodyBehindAppBar` GEREKMEZ cunku AppBar YOK; slider
      //    dogrudan ekranin tepesinden baslar ve durum cubugunun altina
      //    girer — ikonlar `MediaQuery.paddingOf(context).top` ile
      //    guvenli alana konumlanir.
      // ⚠️⚠️ TURU 93 — HER SEY **TEK YATAY DOLGUDA** (kullanici emri:
      //    *"hepsi bir container icinde sol sag bosluk icinde"*).
      //    `kYanBosluk` TEK KAYNAK: header, slider, arama, kartlar ve
      //    filtreler AYNI hizada durur. Ayri ayri sayilar yazilsaydi biri
      //    guncellenip otekiler unutulurdu.
      // ⚠️⚠️⚠️ TURU 93b — GOVDE **KAYDIRILABILIR** OLDU (denetimde yakalanan
      //    IKINCI SEVK ENGELI).
      //
      //	Onceki hal bir `Column` + `Expanded(liste)` idi. `Expanded`in
      //	USTUNDEKI SABIT bloklar olculdu:
      //
      //	   header 48 + bosluk 10 + slider 350 + arama ~58
      //	   + 60x60 serit 92 + filtre satiri 56  =  **614 px**
      //
      //	· 360x800 (en yaygin modern Android, kullanilabilir ~776):
      //	  listeye **162px** kaliyor. Bir kart ~250px (16:9 kapak + ad +
      //	  meta) -> kapagin bir kismi gorunuyor, **AD VE META HIC
      //	  GORUNMUYOR**.
      //	· 360x640 + 3 tus navigasyon (~568): `Expanded` NEGATIF alan alir
      //	  -> **RenderFlex overflowed** sari-siyah serit.
      //	· 414x896 (test cihazi): 238px — yine tek kart bile tam sigmiyor.
      //
      //	Yani "kategori ekrani bastan tasarlandi" denen ekranda kullanici
      //	KAYDIRMADAN TEK BIR ISLETME ADI GOREMIYORDU.
      //
      // ⚠️ FIX: slider + arama + 60x60 serit + filtre satiri artik LISTENIN
      //    KENDISININ parcasi (`CustomScrollView` slaytlari). Yemeksepeti/
      //    Getir de boyle yapar: ust blok yukari kayip gider, liste ekranin
      //    TAMAMINI kullanir.
      // ⚠️ Slider yuksekligi (350) **DEGISTIRILMEDI** — kullanicinin verdigi
      //    olcu. Sorun yuksekligin kendisi degil, SABIT bir dikey butceyi
      //    listeden CALMASIYDI.
      // ⚠️ `AlwaysScrollableScrollPhysics` ZORUNLU: icerik ekrandan kisa
      //    oldugunda (bos liste / hata) asagi-cek-yenile CALISMAZ (turu 83b
      //    dersi — dort kardes ekranda ayni sinif duzeltilmisti).
      // ⚠️ YAPMA: bunu tekrar `Column` + `Expanded`e cevirme.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ⚠️ Header SABIT kalir: geri dugmesi HER ZAMAN erisilebilir
            //    olmali (kaydirinca kaybolan bir geri tusu tuzaktir).
            _header(),
            Expanded(
              child: YenileSarmali(
                // ⚠️ TURU 93b — YENILEME **IKISINI DE** tazeler. Eskiden
                //    yalniz `_yukle` cagriliyordu; kesif istegi hata verirse
                //    350px BOS GRI KUTU kaliyor ve kullanicinin onu
                //    duzeltecek HICBIR yolu olmuyordu.
                onRefresh: _tazele,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ⚠️ Kullanici emri: header'in ALTINDA **10px** bosluk.
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),

                    // ⚠️⚠️ SLAYT YOKSA SLIDER HIC CIZILMEZ. Eski serh
                    //    "veri gelmezse VARSAYILAN metinler gosterilir"
                    //    diyordu ama bu YALNIZ istek BASARILI olursa dogru
                    //    (varsayilani SUNUCU donduruyor). Istek PATLARSA
                    //    `_slaytlar` bos kalir ve `PageView` 0 ogeyle
                    //    cizilir -> ekranin tepesinde **350px hicbir sey
                    //    icermeyen gri dikdortgen**.
                    if (_slaytlar.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: kYanBosluk),
                          child: KategoriSlider(slaytlar: _slaytlar),
                        ),
                      ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            kYanBosluk, 12, kYanBosluk, 0),
                        child: _aramaKutusu(),
                      ),
                    ),

                    // ---- ALT KATEGORI KARTLARI (60x60) — kullanici emri
                    SliverToBoxAdapter(child: _altKategoriSeridi()),
                    // ---- FILTRE SATIRI: solda "Filtrele", saginda sik kullanilanlar
                    SliverToBoxAdapter(child: _filtreSatiri()),

                    if (_hata != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Text(_hata!,
                                  style: const TextStyle(color: Colors.grey)),
                              TextButton(
                                // ⚠️ IKISI BIRDEN: kesif verisi de bu
                                //    hatadan etkilenmis olabilir.
                                onPressed: _tazele,
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (l == null)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (l.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Text(
                            'Bu kategoride henüz işletme yok.\n'
                            'İlk işletme sen ol: Profil → İşletme hesabı.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      // ⚠️ TURU 93 — AYIRICI CIZGI KALDIRILDI: kartlar artik
                      //    kendi golgeleriyle ayriliyor (Yemeksepeti/Getir
                      //    deseni). Cizgi + kart ARADA cift ayirici olurdu.
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            kYanBosluk, 6, kYanBosluk, 24),
                        sliver: SliverList.builder(
                          itemCount: l.length,
                          itemBuilder: (_, i) => _kart(l[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kesif verisi + liste birlikte tazelenir.
  ///
  /// ⚠️ Asagi-cek YALNIZ `_yukle` cagirsaydi, kesif istegi patlamis bir
  ///    ekranda slider ve 60x60 serit KALICI olarak bos kalirdi ve
  ///    kullanicinin ekrani kapatmaktan baska yolu olmazdi.
  Future<void> _tazele() async {
    await Future.wait([_kesfiYukle(), _yukle()]);
  }

  /// ⚠️⚠️ TURU 93 — HEADER: geri (arrow-left) + harita, DAIRE YOK.
  ///
  /// Kullanici emri: *"header'da geri ikonu ARROW-LEFT olsun, sagdaki harita
  /// kalsin, bunlarin ARKASINDAKI DAIRE KALDIR; bunlar bir HEADER olacak"*.
  ///
  /// ⚠️ Daire (opak beyaz zemin) kalkinca ikonlar SAYFA ZEMINI uzerinde
  ///    duruyor — renk TEMADAN alinir; sabit siyah yazilsaydi koyu temada
  ///    GORUNMEZ olurdu.
  /// ⚠️ `IconButton` 48dp dokunma alanini KORUR (gorsel olarak yalniz ikon
  ///    gorunse de); ciplak `Icon` + `GestureDetector` hedefi 24dp'ye
  ///    dusururdu (Material 48 / Apple 44 kurali).
  Widget _header() => Padding(
        // ⚠️ `IconButton`in kendi 8dp ic dolgusu var; yan bosluk ondan
        //    dusulur ki ikonlar slider/arama ile AYNI hizada dursun.
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk - 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Geri',
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            // ⚠️⚠️ TURU 93b — `baslik` **OLU PARAMETREYDI** (denetim).
            //
            //	Alan tanimliydi, `hizmet_menusu.dart` ALTI cagri yerinde
            //	deger geciyordu ("Oteller", "Kafe & Restoran"...) ama govde
            //	onu HIC OKUMUYORDU: turu 92'de AppBar kaldirilinca tek
            //	tuketicisi yok olmus, parametre ve cagri yerleri kalmisti.
            //	Sonuc: "Oteller" kartina basan kullanici, acilan ekranda
            //	hangi kategoride oldugunu HICBIR YERDE goremiyordu (tek
            //	gosterge filtre satirindaki cip, o da yatay serit icinde
            //	kismen kirpilabiliyor).
            // ⚠️ Kullanicinin *"Yemek yazisi gerek yok"* emri **KOCAMAN BIR
            //    APPBAR BASLIGINA** yonelikti; burada iki ikon arasinda
            //    kalan kucuk, ikincil bir etiket var — o emrin ihlali degil,
            //    yon bilgisi.
            // ⚠️ `Expanded` + ellipsis: uzun ad ("Kafe & Restoran") yazi
            //    olcegi 2.0'da bile ikonlari EZMEZ.
            if (widget.baslik.isNotEmpty)
              Expanded(
                child: Text(
                  widget.baslik,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Haritada gör',
              icon: const Icon(LucideIcons.map, size: 22),
              // ⚠️ IKINCI HARITA EKRANI YAZILMADI: `YakinimdaEkrani` kategori
              //    parametresi aldi. O ekranda harita stili muhafizi, jest
              //    cakismasi cozumu ve kamera takibi ZATEN var (turu 85-88).
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => YakinimdaEkrani(kategori: _kategori),
                ),
              ),
            ),
          ],
        ),
      );

  /// ⚠️⚠️ TURU 93 — ARAMA KUTUSU (kullanici emri).
  ///
  /// · Odaklaninca kenarlik **TAM SIYAHIN BIR TIK ACIGI** (`0xFF1A1A1A`).
  ///   Varsayilan Material odak rengi TEMA VURGUSU idi; kullanici notr
  ///   istedi.
  /// · Arama ikonu **BIR TIK KALIN**: `size` 19 -> 21 **+ golge hilesi**.
  ///   ⚠️⚠️ `strokeWidth` YOKTUR: `lucide_icons_flutter` ikonlari bir FONT
  ///      olarak sunar (glif), SVG olarak degil — cizgi kalinligi
  ///      ayarlanamaz. Yalniz `size` buyutmek ikonu BUYUTUR ama oransal
  ///      olarak AYNI incelikte birakir.
  ///   ⚠️ Cozum: ayni renkte, ±0.4px kaydirilmis DORT golge. Glif kendi
  ///      uzerine hafifce yayilir ve cizgi KALINLASIR. Bu, font tabanli
  ///      ikonlarda kalinlik simule etmenin standart yolu.
  ///   ⚠️ YAPMA: `Icon`a `strokeWidth` eklemeye calisma — DERLENMEZ.
  /// · Ikon ile yazi arasi **BIR TIK AZ**: `prefixIconConstraints` ile kutu
  ///   daraltilir. Varsayilan `prefixIcon` 48dp'lik bir kutuya oturur ve
  ///   metin ondan SONRA baslar.
  /// ⚠️ Koyu temada siyah kenarlik GORUNMEZ olurdu — tema parlakligina gore
  ///    secilir.
  Widget _aramaKutusu() {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final odak = koyu ? const Color(0xFFE8E8EA) : const Color(0xFF1A1A1A);
    final bos = (koyu ? Colors.white : Colors.black).withValues(alpha: 0.14);
    final ikonRenk = koyu ? Colors.white70 : Colors.black87;
    return TextField(
      controller: _arama,
      onChanged: _aramaDegisti,
      decoration: InputDecoration(
        hintText: 'İşletme ara',
        prefixIcon: Icon(
          LucideIcons.search,
          size: 21,
          color: ikonRenk,
          shadows: [
            for (final d in const [
              Offset(0.4, 0),
              Offset(-0.4, 0),
              Offset(0, 0.4),
              Offset(0, -0.4),
            ])
              Shadow(color: ikonRenk, offset: d),
          ],
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 38, minHeight: 38),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: bos),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: odak, width: 1.6),
        ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 92 — ALT KATEGORI KARTLARI (kullanici emri: *"aramanin
  ///    altinda soyle kartlar olacak, UFAK kartlar 60x60 RADIUSLU, iste
  ///    doner kebap gibi"*).
  ///
  /// ⚠️ Kart 60x60 KARE + altinda ad. Ad kutunun ICINE yazilsaydi "Lahmacun"
  ///    gibi uzun kelimeler 60px'e SIGMAZDI; disarida iki satira sarabilir.
  /// ⚠️ Liste BOSSA serit HIC CIZILMEZ — her kategoride alt kategori yok
  ///    (bos yatay bosluk birakmiyoruz).
  /// ⚠️ Secili kart TEK: ikinci karta basmak oncekini kapatir. Coklu secim
  ///    "döner kebap" gibi ikisini birden iceren bir arama uretir ve
  ///    neredeyse DAIMA BOS sonuc doner.
  Widget _altKategoriSeridi() {
    if (_altKategoriler.isEmpty) return const SizedBox.shrink();
    // ⚠️⚠️ TURU 93b — YUKSEKLIK **YAZI OLCEGINDEN TURETILIR** (denetim).
    //
    //	Sabit 92px idi. Icerik: 60 (kutu) + 5 (bosluk) + iki satir metin
    //	(11 x 1.15 x 2 = 25.3) = **90.3** -> pay yalnizca **1.7px**.
    //	Android "Yazi tipi boyutu" ayarinin ILK KADEMESI (1.15) bile
    //	2.1px tasirir ve "Lahmacun / Ev Yemeği / Kahvaltı" gibi IKI SATIRA
    //	SARAN adlarda sari-siyah **RenderFlex** seridi cikar.
    // ⚠️ Iki satir bir KENAR DURUM DEGIL, tasarimin NORMAL dali (serh
    //    zaten "disarida iki satira sarabilir" diyor) — yani tasma nadir
    //    degil, YAYGIN olurdu.
    // ⚠️ `textScaler` ile turetmek `MediaQuery`ye baglamak DEMEK DEGILDIR:
    //    olculen sey EKRAN BOYUTU degil KULLANICININ YAZI TERCIHI.
    final olcek = MediaQuery.textScalerOf(context);
    final serit = 60 + 5 + olcek.scale(11) * 1.15 * 2 + 12 + 2;
    return SizedBox(
      height: serit,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // ⚠️ TURU 93b — `12` idi; `kYanBosluk` TEK KAYNAK (dosya basindaki
        //    serhin ACIKCA yasakladigi sey elle yazilmisti: 60x60 kartlar
        //    slider ve arama kutusundan **4px solda** duruyordu).
        // ⚠️ Sag dolgu da `kYanBosluk`: yatay serit kaydirildiginda son
        //    kartin kenara YAPISMAMASI icin.
        padding: const EdgeInsets.fromLTRB(kYanBosluk, 12, kYanBosluk, 0),
        itemCount: _altKategoriler.length,
        itemBuilder: (_, i) {
          final a = _altKategoriler[i];
          final secili = _altSecili == a.ara;
          final renk = Theme.of(context).colorScheme.primary;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              // ⚠️ `opaque`: kutu ile yazi ARASINDAKI bosluga dokunmak da
              //    secer; aksi halde kullanici "bastim olmadi" der.
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _altSecili = secili ? '' : a.ara);
                // ⚠️ TURU 93b — BEKLEYEN ARAMA ZAMANLAYICISI IPTAL EDILIR:
                //    kullanici yazip hemen karta basarsa 320ms'lik timer
                //    ikinci bir istek daha atardi (jeton kapisi yanlis
                //    veriyi engelliyor ama istek bosuna gidiyordu).
                _gecikme?.cancel();
                _yukle();
              },
              child: SizedBox(
                width: 64,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        // ⚠️⚠️ TURU 93b — ALFA KALDIRILDI + KENARLIK EKLENDI
                        //	(denetim: kontrast **~1.06** olculdu).
                        //
                        //	`surfaceContainerHighest` (~#E3E1E6) %50 alfa ile
                        //	acik tema zemini `#F2F2F5` uzerine binince
                        //	**~#EBEAEE** cikiyordu — zeminden 7-8 birim fark.
                        //	Kullanici kartlarin ICINDEKI HARFLERI kaldirttigi
                        //	icin (turu 93) kutunun TEK isi "burada bir kart
                        //	var" demek; gorunmez bir kart o isi YAPMAZ.
                        //	⚠️ Ustelik cevresindeki slider zemini `#E7E7EA`
                        //	   idi: "kart" kendi arka planindan DAHA ACIK
                        //	   kaliyor, gorsel hiyerarsi TERS donuyordu.
                        // ⚠️ Kenarlik filtre cipleriyle AYNI dili konusur
                        //    (`_notrKenar`) — yeni bir sabit renk eklemez.
                        color: secili
                            ? renk.withValues(alpha: 0.16)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        border: Border.all(
                          color: secili ? renk : _notrKenar,
                          width: secili ? 1.6 : 1,
                        ),
                      ),
                      // ⚠️⚠️ TURU 93 — KUTUNUN ICI **BOS** (kullanici emri:
                      //    *"kart icinde yazi olmasin, kartlarin icindeki
                      //    HARFLERI KALDIR"*). Kutu artik salt renkli bir
                      //    yuzey; ad ALTINDA yaziyor.
                      // ⚠️ YAPMA: buraya harf ya da ikon geri koyma.
                    ),
                    const SizedBox(height: 5),
                    Text(
                      a.ad,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                        color: secili ? renk : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// ⚠️⚠️ TURU 92 — FILTRE SATIRI (kullanici emri: *"altinda FILTRELEME
  ///    BUTONU, saginda da genel olarak kullanilan filtrelemeler"*).
  ///
  /// SOLDA sabit "Filtrele" dugmesi (tum secenekleri alttan sheet'te acar),
  /// SAGINDA yatay kayan SIK KULLANILANLAR.
  /// ⚠️ Solraki dugme KAYMAZ (`Row` + `Expanded`): kullanici filtreyi
  ///    ararken seridi kaydirmak zorunda kalmamali.
  Widget _filtreSatiri() {
    // ⚠️ TURU 93b — `_altSecili` DE SAYILIR (denetim). Rozetin kendi
    //    gerekcesi "kullanici neden az sonuc gordugunu anlayabilmeli"
    //    diyor; alt kategori EN DARALTICI suzgec oldugu halde sayilmiyordu
    //    -> "Filtre (1)" yazarken FIILEN IKI suzgec aktifti.
    final aktifSayi = (_hizli.isEmpty ? 0 : 1) +
        (_kategori.isEmpty ? 0 : 1) +
        (_altSecili.isEmpty ? 0 : 1);
    return Padding(
      // ⚠️ TURU 93b — `12` idi -> `kYanBosluk` (dosya basindaki "elle yatay
      //    dolgu YAZMA" serhinin ikinci ihlali; "Filtrele" dugmesi arama
      //    kutusundan 4px solda duruyordu).
      // ⚠️ Sag 0 KALIR: sagdaki serit YATAY KAYIYOR, sag dolgu son cipi
      //    kirpiyormus gibi gosterirdi.
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 10, 0, 6),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _filtreSheet,
            icon: const Icon(LucideIcons.slidersHorizontal, size: 16),
            // ⚠️ AKTIF SAYI ROZETI: kullanici neden az sonuc gordugunu
            //    anlayabilmeli. Rozetsiz bir filtre, "hic isletme yok"
            //    yanilgisinin en sik sebebidir.
            label: Text(aktifSayi == 0 ? 'Filtrele' : 'Filtre ($aktifSayi)'),
            // ⚠️⚠️ TURU 93 — **ARAMA KUTUSUYLA AYNI DIL** (kullanici emri:
            //    *"filtre vs butonlarda YESIL RENK OLMAYACAK, arama inputu
            //    mantigi olacak"*). Material'in varsayilan secili hali TEMA
            //    VURGU RENGINI kullaniyordu; hepsi notr siyah/beyaz dile
            //    cevrildi ve renk TEK KAYNAKTAN geliyor (`_notrKenar`).
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: _notrYazi,
              side: BorderSide(color: _notrKenar),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              // ⚠️ TURU 93b — 36 -> 48 (denetim). `FilterChip` varsayilan
              //    `materialTapTargetSize: padded` ile **48dp**lik dokunma
              //    alani ister; ebeveyn 36'ya kesince hedef Material 48 /
              //    Apple 44 kuralinin ALTINA dusuyordu.
              // ⚠️ Eklenen 12px artik bir sorun degil: govde turu 93b'de
              //    KAYDIRILABILIR oldu, yani sabit dikey butce yok.
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_benimIlce.isNotEmpty)
                    _hizliCip('sehrimde', _benimIlce, LucideIcons.mapPin),
                  _hizliCip('onayli', 'Onaylı', LucideIcons.badgeCheck),
                  // ⚠️ Kategori CIPLERI buraya TASINDI: eskiden ayri bir
                  //    44px'lik serit vardi ve ekranin ustunde ARKA ARKAYA
                  //    UC yatay serit (hizli kartlar + arama + kategoriler)
                  //    olusuyordu. Tek satirda birlesince liste 80px daha
                  //    erken basliyor.
                  if (_kategori.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(isletmeKategoriAdi(_kategori)),
                        // ⚠️ TURU 93b — TEK KAPI (`_altSecili` de sifirlanir).
                        onDeleted: () => _kategoriSec(''),
                      ),
                    ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Notr renkler — arama kutusuyla AYNI dil (kullanici emri: yesil YOK).
  ///
  /// ⚠️ TEK KAYNAK: filtre dugmesi, hizli cipler ve secili kategori cipi
  ///    ayni iki degeri kullanir. Elle yazilsaydi biri guncellenip otekiler
  ///    unutulur ve ekranda IKI FARKLI vurgu rengi olusurdu.
  Color get _notrKenar =>
      (Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black)
          .withValues(alpha: 0.16);

  Color get _notrYazi => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A1A);

  Widget _hizliCip(String anahtar, String ad, IconData ikon) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          avatar: Icon(ikon, size: 15, color: _notrYazi),
          label: Text(ad),
          selected: _hizli == anahtar,
          // ⚠️ Secili hal TEMA RENGI DEGIL, notr dolgu (kullanici emri).
          showCheckmark: false,
          selectedColor: _notrYazi.withValues(alpha: 0.10),
          side: BorderSide(color: _notrKenar),
          labelStyle: TextStyle(color: _notrYazi),
          onSelected: (secili) {
            // ⚠️ TEK SECIM: ikinci karta basmak oncekini KAPATIR. Coklu
            //    secim ("Şehrimde + Onaylı") bos sonuclar uretip kullaniciyi
            //    "hic isletme yok" sanisina dusururdu.
            setState(() => _hizli = secili ? anahtar : '');
            _yukle();
          },
        ),
      );

  /// Tum filtreler — alttan sheet.
  ///
  /// ⚠️ Kategori degisince `_kesfiYukle` DE cagrilir: alt kategoriler ve
  ///    slayt metinleri KATEGORIYE OZELDIR (kullanici: "her kategori
  ///    FARKLI"). Cagrilmasaydi "Yemek"in doner/kebap kartlari "Kuaför"
  ///    kategorisinde de gorunurdu.
  Future<void> _filtreSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: StatefulBuilder(
          builder: (c, yenile) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Kategori',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // ⚠️⚠️ TURU 93b — UC DAL DA `_kategoriSec` KAPISINDAN
                      //    gecer. Onceden "Tümü" ve ✕ dallari `_altSecili`yi
                      //    SIFIRLAMIYORDU: "Yemek → Döner" seciliyken
                      //    "Tümü"ye basan kullanicida GORUNMEZ bir "döner"
                      //    suzgeci takili kaliyordu.
                      ChoiceChip(
                        label: const Text('Tümü'),
                        selected: _kategori.isEmpty,
                        onSelected: (_) {
                          yenile(() {});
                          _kategoriSec('');
                        },
                      ),
                      for (final e in isletmeKategorileri.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: _kategori == e.key,
                          onSelected: (_) {
                            yenile(() {});
                            _kategoriSec(e.key);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Uygula'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ⚠️ TURU 92 — `_cip` ve `_hizliKartlar` SILINDI: kategori secimi
  //    "Filtrele" sheet'ine, hizli suzgecler ise filtre satirina tasindi.
  //    Olu birakmak, ileride birinin onlari geri baglayip IKI AYRI
  //    kategori secicisi olusturmasina yol acardi (turu 90b'de
  //    `OlusturFab` tam bu sebeple silinmisti).

  /// ⚠️⚠️⚠️ TURU 93 — ISLETME KARTI (kullanici emri: *"firmalar Getir Yemek /
  /// Yemeksepeti kartlari gibi olsun"*, ekran goruntusu referansiyla).
  ///
  /// YAPI: ustte GENIS GORSEL (16:9, yuvarlak kose) · altinda AD + onayli
  /// rozeti · altinda META satiri (kategori · ilce/il).
  ///
  /// ⚠️⚠️ **PUAN, TESLIMAT SURESI VE MINIMUM TUTAR YOK — VE UYDURULMADI.**
  ///    Referans ekranda "25-35 dk · Min. 260 TL · 3,9 (500+)" var; bu
  ///    projede o verilerin HICBIRI YOK (ne degerlendirme tablosu, ne
  ///    teslimat modeli, ne siparis). Sahte deger basmak kullaniciya
  ///    YANLIS BILGI gostermek olurdu; bos yildiz/sure cizmek de "bozuk"
  ///    izlenimi verirdi. Kart, BUGUN GERCEK OLAN alanlarla dolduruldu.
  ///    ⚠️ YAPMA: yer tutucu puan/sure/mesafe ekleme.
  ///
  /// ⚠️ GORSEL SIRASI: kapak -> avatar -> gradyan yer tutucu. Kapak yoksa
  ///    avatar 46px icin uretilmis bir gorseldir ve 150px kutuda BULANIK
  ///    cikar; yine de bos gri kutudan iyidir. Ikisi de yoksa KIRIK GORSEL
  ///    CIZILMEZ, kategori renginde bir gradyan cizilir.
  Widget _kart(IsletmeOzet o) {
    final gorselID = (o.kapakMediaId != null && o.kapakMediaId!.isNotEmpty)
        ? o.kapakMediaId!
        : (o.avatarMediaId ?? '');
    // ⚠️⚠️ TURU 93b — KAPAK GENISLIGI ACIKCA VERILIR (denetim; turu 91
    //	performans dersinin tekrari — kullanici "uygulama bir tik kasiyor"
    //	demisti).
    //
    //	`MedyaGorsel`e `width` verilmezse varsayilan 1080 kabul edilir ve
    //	`dpr=3` cihazda `1080*3=3240` -> **2048'e** kirpilir; yani kartin
    //	gercek ihtiyaci ~984px iken gorsel iki katindan fazla cozunurlukte
    //	belleğe aciliyordu (~9 MB gecici RAM x 10 kart).
    final kartGenislik =
        MediaQuery.sizeOf(context).width - kYanBosluk * 2;
    return Padding(
      // ⚠️ KARTLAR ARASI BOSLUK **AD-GORSEL BOSLUGUNUN 3.5 KATI** olmali.
      //    18 iken (gorsel-ad araligi 9) oran 1:2 kaliyordu ve goz hangi
      //    ismin hangi gorsele ait oldugunu AYIRAMIYORDU — emulatorde
      //    bakinca ilk fark edilen sey buydu.
      padding: const EdgeInsets.only(bottom: 32),
      child: InkWell(
        // ⚠️ TURU 93b — `GestureDetector` -> `InkWell`: kardes ekran
        //    (`yakinimda_ekrani`) AYNI kart icin `InkWell` kullaniyordu;
        //    ayni veriye iki farkli dokunma dili konusuluyordu.
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KAPAK ──
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: gorselID.isEmpty
                    ? _kapakYerTutucu(o)
                    : MedyaGorsel(
                        mediaId: gorselID,
                        fit: BoxFit.cover,
                        width: kartGenislik,
                      ),
              ),
            ),
            const SizedBox(height: 9),
            // ── AD + ONAYLI ──
            Row(
              children: [
                Flexible(
                  child: Text(
                    o.ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // ⚠️⚠️ TURU 78 — ROZET RENGI/BOYUTU TEK KAYNAKTAN
                //    (`kOnayliRengi`). Bu rozet iki ekranda ELLE cizilmisti
                //    ve ZATEN DRIFT ETMISTI.
                if (o.dogrulandi)
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Icon(LucideIcons.badgeCheck,
                        size: 16, color: kOnayliRengi),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            // ── BILGI SATIRI (kullanici emri: referans ekrandaki gibi) ──
            //
            // ⚠️⚠️ **PUAN / TESLIMAT SURESI / MIN. TUTAR UYDURULMADI.**
            //	Referans ekranda "25-35 dk · Min. 260 TL · ★ 3,9 (500+)" var
            //	ama bu projede o verilerin HICBIRI YOK (ne degerlendirme
            //	tablosu, ne teslimat modeli, ne siparis). Sahte deger basmak
            //	kullaniciya YANLIS BILGI gostermek olurdu.
            //	Yerine BUGUN GERCEK OLAN uc sey ciziliyor:
            //	  · **Acik / Kapali** (+ bugunun kapanis saati)
            //	  · **En uygun fiyat** (katalogdaki en dusuk urun)
            //	  · kategori · ilce, il
            // ⚠️ YAPMA: buraya yer tutucu puan/sure/mesafe ekleme.
            _bilgiSatiri(o),
          ],
        ),
      ),
    );
  }

  /// Kapak da avatar da yoksa: kategori renginde gradyan + isletme adinin
  /// bas harfi.
  ///
  /// ⚠️ Renk ADDAN turetilir (kategoriden DEGIL): ayni kategorideki tum
  ///    kartlar ayni renk olsaydi liste tekduze bir blok gibi gorunurdu.
  /// Kartin bilgi satiri: **Açık/Kapalı · En uygun XX ₺ · Kategori · İlçe**.
  ///
  /// ⚠️ Hicbir deger UYDURULMAZ; hepsi sunucudan gelen GERCEK alanlardan
  ///    turetilir. Veri yoksa o parca CIZILMEZ (bos yildiz/sure gostermek
  ///    "bozuk" izlenimi verirdi).
  Widget _bilgiSatiri(IsletmeOzet o) {
    final soluk = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.color
        ?.withValues(alpha: 0.6);

    final acik = _acikMi(o.calisma);
    final kapanis = _bugunKapanis(o.calisma);

    final parcalar = <Widget>[];

    // ── AÇIK / KAPALI ──
    // ⚠️ `null` = calisma saati TANIMSIZ -> hicbir sey yazilmaz. "Kapalı"
    //    yazmak, saatini girmemis isletmeyi HAKSIZ yere kapali gosterirdi.
    if (acik != null) {
      parcalar.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: acik ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            acik
                ? (kapanis.isEmpty ? 'Açık' : 'Açık · $kapanis\'a kadar')
                : 'Kapalı',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: acik ? const Color(0xFF16A34A) : soluk,
            ),
          ),
        ],
      ));
    }

    // ── EN UYGUN FİYAT ──
    final f = o.minFiyatKurus;
    if (f != null && f > 0) {
      parcalar.add(Text(
        'En uygun ${(f / 100).round()} ₺',
        style: TextStyle(fontSize: 13, color: soluk),
      ));
    }

    // ── KATEGORİ · İLÇE ──
    final yer = [
      isletmeKategoriAdi(o.kategori),
      if (o.ilce.isNotEmpty || o.il.isNotEmpty)
        [o.ilce, o.il].where((s) => s.isNotEmpty).join(', '),
    ].where((s) => s.isNotEmpty).join(' · ');
    if (yer.isNotEmpty) {
      parcalar.add(Text(yer, style: TextStyle(fontSize: 13, color: soluk)));
    }

    // ⚠️ `Wrap`: dar ekranda (360dp) uc parca tek satira sigmazsa alta
    //    sarar — `Row` olsaydi RenderFlex TASARDI.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 2,
      children: [
        for (var i = 0; i < parcalar.length; i++) ...[
          if (i > 0)
            Text('·', style: TextStyle(fontSize: 13, color: soluk)),
          parcalar[i],
        ],
      ],
    );
  }

  /// Bugün için işletme açık mı? `null` = çalışma saati tanımsız.
  ///
  /// ⚠️ Sunucu `calisma`yi `[{gun:1..7, acilis:"09:00", kapanis:"20:00",
  ///    kapali:bool}]` olarak tutuyor; `gun` **1=Pazartesi**, Dart'in
  ///    `DateTime.weekday` degeriyle BIREBIR ayni.
  /// ⚠️ GECE YARISINI ASAN mesai (22:00-02:00) destekleniyor: kapanis
  ///    acilistan kucukse aralik ertesi gune tasar.
  bool? _acikMi(List<dynamic> calisma) {
    final bugun = _bugunKaydi(calisma);
    if (bugun == null) return null;
    if (bugun['kapali'] == true) return false;
    final a = _dk(bugun['acilis']);
    final k = _dk(bugun['kapanis']);
    if (a == null || k == null) return null;
    final now = DateTime.now();
    final s = now.hour * 60 + now.minute;
    return k > a ? (s >= a && s < k) : (s >= a || s < k);
  }

  String _bugunKapanis(List<dynamic> calisma) {
    final b = _bugunKaydi(calisma);
    if (b == null || b['kapali'] == true) return '';
    return (b['kapanis'] ?? '').toString();
  }

  Map<String, dynamic>? _bugunKaydi(List<dynamic> calisma) {
    for (final g in calisma) {
      if (g is Map && (g['gun'] as num?)?.toInt() == DateTime.now().weekday) {
        return g.cast<String, dynamic>();
      }
    }
    return null;
  }

  /// "09:00" -> 540. Bozuk deger `null`.
  int? _dk(dynamic s) {
    final p = (s ?? '').toString().split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// ⚠️⚠️ KAPAK YOKSA **HAFIF GRI** (kullanici emri: *"kapaklardaki renkli
  ///    desenleri kaldir, onun yerine hafif gri slider gibi yap"*).
  ///
  ///	Onceden ADDAN turetilen RENKLI bir gradyan ciziliyordu. Listede alt
  ///	alta duran kirmizi/mor/yesil bloklar dikkati icerikten CALIYOR ve
  ///	referans ekrandaki sakin gorunumden UZAKLASTIRIYORDU.
  /// ⚠️ Ton **slider ile AYNI** (`0xFFE7E7EA` / koyu `0xFF2A2A2E`): ekranda
  ///    iki farkli gri olmasin.
  /// ⚠️ Bas harf KALDI ama artik SOLUK: kartin bos degil "gorseli yok"
  ///    oldugunu gosterir; tamamen bos bir kutu "yukleniyor" gibi durur.
  Widget _kapakYerTutucu(IsletmeOzet o) {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: koyu ? const Color(0xFF2A2A2E) : const Color(0xFFE7E7EA),
      child: Center(
        child: Text(
          o.ad.isEmpty ? '?' : o.ad.characters.first.toUpperCase(),
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: (koyu ? Colors.white : Colors.black).withValues(alpha: 0.18),
          ),
        ),
      ),
    );
  }

}

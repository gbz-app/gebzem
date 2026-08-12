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
    try {
      final d = await ref.read(isletmeServisiProvider).kesif(_kategori);
      if (!mounted) return;
      setState(() {
        _altKategoriler = d.altKategoriler;
        _slaytlar = d.slaytlar;
      });
    } catch (_) {
      // sessiz — bkz. serh
    }
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            // ⚠️ Kullanici emri: header'in ALTINDA **10px** bosluk.
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
              child: KategoriSlider(slaytlar: _slaytlar),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(kYanBosluk, 12, kYanBosluk, 0),
              child: _aramaKutusu(),
            ),
            // ---- ALT KATEGORI KARTLARI (60x60) — kullanici emri
            _altKategoriSeridi(),
            // ---- FILTRE SATIRI: solda "Filtrele", saginda sik kullanilanlar
            _filtreSatiri(),
            Expanded(
            child: _hata != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _hata!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: _yukle,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  )
                : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                ? const Center(
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
                : YenileSarmali(
                    onRefresh: _yukle,
                    // ⚠️ TURU 93 — AYIRICI CIZGI KALDIRILDI: kartlar artik
                    //    kendi golgeleriyle ayriliyor (Yemeksepeti/Getir
                    //    deseni). Cizgi + kart ARADA cift ayirici olurdu.
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          kYanBosluk, 6, kYanBosluk, 24),
                      itemCount: l.length,
                      itemBuilder: (_, i) => _kart(l[i]),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
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
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
                        color: secili
                            ? renk.withValues(alpha: 0.16)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        border: Border.all(
                          color: secili ? renk : Colors.transparent,
                          width: 1.6,
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
    final aktifSayi = (_hizli.isEmpty ? 0 : 1) + (_kategori.isEmpty ? 0 : 1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 0, 6),
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
              height: 36,
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
                        onDeleted: () {
                          setState(() => _kategori = '');
                          _kesfiYukle();
                          _yukle();
                        },
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
                      ChoiceChip(
                        label: const Text('Tümü'),
                        selected: _kategori.isEmpty,
                        onSelected: (_) {
                          yenile(() {});
                          setState(() => _kategori = '');
                          _kesfiYukle();
                          _yukle();
                        },
                      ),
                      for (final e in isletmeKategorileri.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: _kategori == e.key,
                          onSelected: (_) {
                            yenile(() {});
                            setState(() {
                              _kategori = e.key;
                              // ⚠️ Alt kategori SIFIRLANIR: "döner" secili
                              //    kalip kategori "Kuaför"e gecerse sonuc
                              //    DAIMA BOS olurdu ve kullanici sebebini
                              //    goremezdi (secili kart artik cizilmiyor).
                              _altSecili = '';
                            });
                            _kesfiYukle();
                            _yukle();
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        // ⚠️ `opaque`: gorsel ile yazi ARASINDAKI bosluga dokunmak da karti
        //    acar; aksi halde kullanici "bastim acilmadi" der.
        behavior: HitTestBehavior.opaque,
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
                    : MedyaGorsel(mediaId: gorselID, fit: BoxFit.cover),
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
            // ── META ──
            Text(
              [
                isletmeKategoriAdi(o.kategori),
                if (o.ilce.isNotEmpty || o.il.isNotEmpty)
                  [o.ilce, o.il].where((s) => s.isNotEmpty).join(', '),
              ].where((s) => s.isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.6),
              ),
            ),
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
  Widget _kapakYerTutucu(IsletmeOzet o) {
    final tohum = o.ad.isEmpty ? 0 : o.ad.codeUnitAt(0);
    final renkler = [
      [const Color(0xFF3AA9FF), const Color(0xFF6C2BD9)],
      [const Color(0xFF2BB673), const Color(0xFF0E7A52)],
      [const Color(0xFFFF7A45), const Color(0xFFFF3B5C)],
      [const Color(0xFF8B3FFF), const Color(0xFF5A1EBE)],
      [const Color(0xFF0EA5A5), const Color(0xFF0B5F63)],
    ][tohum % 5];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: renkler,
        ),
      ),
      child: Center(
        child: Text(
          o.ad.isEmpty ? '?' : o.ad.characters.first.toUpperCase(),
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

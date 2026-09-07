import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/denetleyici_sahibi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'urun_detay.dart';
import 'urun_servisi.dart';
import '../../core/theme.dart';

/// ⚠️⚠️ TURU 77 — ISLETME KATALOGU / MENUSU.
///
/// Kullanici emri: "isletmeler urunlerini yukleyebilecek ya da ChatGPT
/// yardimiyla AI gorsel, AI menu, AI ile tek tek fotograftan problemleri ...".
///
/// ⚠️ AI DUGMELERI YALNIZ SUNUCUDA ACIKSA CIZILIR (`aiDurumProvider`).
///    Kapaliyken cizilseydi kullanici basar ve 503 alirdi.
class UrunKatalogEkrani extends ConsumerStatefulWidget {
  const UrunKatalogEkrani({
    super.key,
    required this.isletmeId,
    required this.isletmeAd,
    this.benimMi = false,
    this.modul = Modul.varsayilan,
  });

  final String isletmeId;
  final String isletmeAd;
  final bool benimMi;

  /// TURU 89 — kategoriye ozel katalog modulu (Odalar/Hizmetler/Menü).
  /// ⚠️ Cagiran vermezse varsayilan 'Ürünler' kullanilir; ekran HICBIR
  ///    durumda kategoriden TAHMIN yurutmez.
  final Modul modul;

  @override
  ConsumerState<UrunKatalogEkrani> createState() => _UrunKatalogEkraniState();
}

/// ⚠️⚠️ TURU 178 — MENU KALEMININ GORSELI (kullanici emri: *"menulerde
///	RESIM ALANLARI olsun"*).
///
/// Tohum verisindeki urunlerin `media_ids` alani BOS (gorsel yuklenmedi),
/// yani gercek bir gorsel YOK. Bilinen marka kalemleri icin pakete konmus
/// ornek fotograf gosterilir; digerlerinde **yer tutucu** cizilir.
/// ⚠️ Uydurma gorsel BASILMAZ: eslesmeyen kalem notr bir ikon kutusu alir.
/// ⚠️ Bu tablo **ornek/tanitim** icindir; yayin oncesi `assets/marka`
///	varliklariyla BIRLIKTE kaldirilacak (turu 140 marka notu).
const Map<String, String> kOrnekMenuGorsel = {
  'big mac': 'assets/marka/menu_bigmac.png',
  'cheeseburger': 'assets/marka/menu_cheeseburger.png',
  'mcchicken': 'assets/marka/menu_tavuk.png',
  'tavuk burger': 'assets/marka/menu_tavuk.png',
  'patates': 'assets/marka/menu_patates.png',
  'mcnuggets': 'assets/marka/menu_tavuk.png',
  'chicken burger': 'assets/marka/menu_tavuk.png',
  'double cheeseburger': 'assets/marka/menu_cheeseburger.png',
  'mcroyal': 'assets/marka/menu_bigmac.png',
};

// ignore: unused_element
String? _ornekGorsel(String ad) {
  // ⚠️ Turkce kucultme ELLE: `toLowerCase()` 'I' harfini 'i' yapar ama
  //    'İ'yi BIRLESIK NOKTAYA cevirir ve eslesme kacar (turu 140 dersi).
  final a = ad.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  for (final e in kOrnekMenuGorsel.entries) {
    if (a.contains(e.key)) return e.value;
  }
  return null;
}

class _UrunKatalogEkraniState extends ConsumerState<UrunKatalogEkrani> {
  List<Urun>? _liste;
  String? _hata;

  /// ⚠️ Suzgec ISTEMCIDE: katalog TEK ISTEKTE geliyor, yani suzulen kume
  //	kullanicinin gordugu kumenin TAMAMI (turu 141 gerekcesi).
  String _q = '';

  // ⚠️⚠️ TURU 179 — **BOLUM SEKMELERI** (kullanici: *"ustte menu
  //	cizgileri, aynen profildeki fotograf tarzi; burger vs
  //	tikladigimda oraya girsin"*).
  //
  // ⚠️ Anahtarlar **HER `build`de YENIDEN URETILMEZ**: `GlobalKey` bir
  //	KIMLIKTIR ve her cizimde yenisi uretilseydi
  //	`ensureVisible` bir onceki karenin OLU anahtarina bakar,
  //	dokunus HICBIR SEY YAPMAZDI.
  final _kaydirma = ScrollController();
  final Map<String, GlobalKey> _bolumAnahtar = {};
  String _aktifBolum = '';

  /// ⚠️ TURU 180 — dokunulan sekme SERITTE ORTALANIR (kullanici:
  //	*"tikladigimda hangi menuye tikladiysam ORTALANSIN"*).
  //	Bunun icin sekmenin KENDI anahtari gerekiyor: `ensureVisible`
  //	yalniz bir `BuildContext` ile calisir.
  final Map<String, GlobalKey> _sekmeAnahtar = {};

  /// ⚠️⚠️ TURU 180 — **ASAGI INERKEN HEADER GIZLENIR** (kullanici emri).
  //	Bayrak `_kaydirma` dinleyicisinden gelir; esik 60 dp: daha
  //	kucuk bir esikte header her kucuk kaydirmada YANIP SONERDI.
  bool _headerGizli = false;

  /// ⚠️⚠️ TURU 180g — **KAYDIRMA TAKIBI (scroll-spy)** (kullanici: *"menude
  ///	asagi inerken butonlar DEGISMIYOR, yukari cikarken
  ///	degismiyor"*). Serit artik ekranin USTUNDEKI bolumu
  ///	secili gosterir.
  /// ⚠️ Olcum icin listenin EKRANDAKI ust kenari gerekiyor; bunu
  ///	`ScrollController`den okuyamayiz (o yalniz ofset verir).
  final GlobalKey _listeAnahtar = GlobalKey();

  /// ⚠️⚠️ Dokunusla secim SIRASINDA spy KAPALI: `ensureVisible` animasyonu
  ///	kaydirma olayi uretir ve spy ARA bolumleri secili gosterip
  ///	seridi titretirdi (dokunulan sekme secili kalmali).
  bool _elleSecim = false;

  GlobalKey _sekmeAnahtari(String bolum) =>
      _sekmeAnahtar.putIfAbsent(bolum, GlobalKey.new);

  GlobalKey _anahtar(String bolum) =>
      _bolumAnahtar.putIfAbsent(bolum, GlobalKey.new);

  /// ⚠️ `alignment: 0` bolumu ekranin USTUNE getirir; varsayilan (0.5)
  //	ortalar ve kullanici "tikladim, ustte degil" derdi.
  /// ⚠️⚠️⚠️ TURU 180g — **ASAGIDAYKEN DOKUNUS CALISMIYORDU** (kullanici:
  ///	*"asagida iken butonlara tikladiginda AKTIF OLMUYOR"*).
  ///
  ///	Kok neden: liste TEMBEL (`ListView` cocuklarini yalniz
  ///	goruntu + onbellek seridinde KURAR). Uzaktaki bir bolumun
  ///	`GlobalKey.currentContext`i **null**dur ve eski kod tam
  ///	orada `return` ediyordu — dokunus HICBIR SEY yapmiyordu.
  ///
  ///	Yeni akis: hedef kurulana kadar o yone **atlaya atlaya**
  ///	yaklasilir, kurulunca `ensureVisible` ile tam ustune
  ///	oturtulur.
  /// ⚠️ Adim 600 dp: daha kucugu cok tur dondurur, daha buyugu hedefi
  ///	ASAR ve ters yone salinim yapar.
  /// ⚠️ Tavan 14 tur: sonsuz donguye karsi (liste sonuna dayanirsa
  ///	`jumpTo` ayni degeri dondurur ve dongu ZATEN kirilir).
  Future<void> _bolumeGit(String bolum) async {
    final adlar = _bolumler.keys.toList();
    final hedef = adlar.indexOf(bolum);
    final onceki = adlar.indexOf(_aktifBolum);
    setState(() {
      _aktifBolum = bolum;
      _elleSecim = true;
    });
    // ⚠️ TURU 180 — dokunulan sekme SERITTE ORTALANIR (`alignment: 0.5`).
    final sk = _sekmeAnahtari(bolum).currentContext;
    if (sk != null) {
      unawaited(Scrollable.ensureVisible(
        sk,
        alignment: 0.5,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ));
    }
    try {
      final yon = (hedef >= 0 && onceki >= 0 && hedef < onceki) ? -1 : 1;
      for (var tur = 0; tur < 14; tur++) {
        if (!mounted) return;
        final k = _anahtar(bolum).currentContext;
        // ⚠️ `k.mounted`: `k` BASKA bir widget'in context'i ve onceki turun
        //    `await`inden sonra sokulmus olabilir. State'in `mounted`i bunu
        //    GORMEZ (analyzer da uyariyor).
        if (k != null && k.mounted) {
          // ⚠️ `alignment: 0` bolumu ekranin USTUNE getirir; varsayilan
          //    (0.5) ortalar ve kullanici "tikladim, ustte degil" derdi.
          await Scrollable.ensureVisible(
            k,
            alignment: 0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          return;
        }
        if (!_kaydirma.hasClients) return;
        final simdi = _kaydirma.offset;
        final yeni = (simdi + yon * 600)
            .clamp(0.0, _kaydirma.position.maxScrollExtent);
        if (yeni == simdi) return;
        _kaydirma.jumpTo(yeni);
        // ⚠️ Bir KARE beklenir: `jumpTo` sonrasi cocuklar ancak yerlesim
        //    gecisinde kurulur; beklemeden `currentContext` yine null olur.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
    } finally {
      if (mounted) setState(() => _elleSecim = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _yukle();
    _kaydirma.addListener(_kaydirmaDegisti);
  }

  /// ⚠️ `setState` YALNIZ bayrak degisince: kosulsuz cagrilsaydi her
  //	kaydirma karesinde TUM liste yeniden cizilirdi (turu 169
  //	"dakika degisince setState" dersinin ayni sinifi).
  void _kaydirmaDegisti() {
    final gizle = _kaydirma.hasClients && _kaydirma.offset > 60;
    final yeniBolum = _elleSecim ? _aktifBolum : _ustdekiBolum();
    if (gizle == _headerGizli && yeniBolum == _aktifBolum) return;
    setState(() {
      _headerGizli = gizle;
      _aktifBolum = yeniBolum;
    });
    // ⚠️ Serit, secili sekme GORUS ALANI DISINDA kaldiysa ona kayar.
    //    Kosulsuz `ensureVisible` her kaydirma karesinde bir animasyon
    //    baslatir ve serit TITRERDI.
    final sk = _sekmeAnahtari(yeniBolum).currentContext;
    if (sk != null) {
      unawaited(Scrollable.ensureVisible(
        sk,
        alignment: 0.5,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ));
    }
  }

  /// Ekranin USTUNDEKI bolumun adi (kaydirma takibi).
  ///
  /// ⚠️ YALNIZ KURULMUS bolumler olculebilir (liste tembel). Hicbiri
  ///	esigi gecmediyse mevcut secim KORUNUR — bos dize donmek
  ///	seridi ilk sekmeye ZIPLATIRDI.
  /// ⚠️ Esik 12 dp: baslik listenin ust kenarina TAM oturmadan bir
  ///	onceki bolum secili kalsin (goz de oyle okur).
  String _ustdekiBolum() {
    final lk = _listeAnahtar.currentContext?.findRenderObject();
    if (lk is! RenderBox || !lk.hasSize) return _aktifBolum;
    final ustY = lk.localToGlobal(Offset.zero).dy + 12;
    var secili = _aktifBolum;
    double? enYakin;
    for (final ad in _bolumler.keys) {
      final c = _bolumAnahtar[ad]?.currentContext;
      final b = c?.findRenderObject();
      if (b is! RenderBox || !b.hasSize) continue;
      final y = b.localToGlobal(Offset.zero).dy;
      if (y > ustY) continue;
      if (enYakin == null || y > enYakin) {
        enYakin = y;
        secili = ad;
      }
    }
    // ⚠️ Liste TEPEDEYSE daima ILK bolum: yukari cikarken secim eski
    //    bolumde takili kaliyordu (kullanici: "yukari cikarken degismiyor").
    if (_kaydirma.hasClients && _kaydirma.offset <= 4 && _bolumler.isNotEmpty) {
      return _bolumler.keys.first;
    }
    return secili;
  }

  @override
  void dispose() {
    _kaydirma
      ..removeListener(_kaydirmaDegisti)
      ..dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(urunServisiProvider).liste(widget.isletmeId);
      if (mounted) {
        setState(() {
          _liste = l;
          _hata = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hata = 'Ürünler alınamadı');
    }
  }

  /// Bolume gore grupla (menu gorunumu).
  Map<String, List<Urun>> get _bolumler {
    final q = _q.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    final m = <String, List<Urun>>{};
    for (final u in _liste ?? const <Urun>[]) {
      // ⚠️⚠️ TURU 178 — KALDIRILMIS kalem MUSTERIYE CIZILMEZ.
      //	Sunucu silmeyi "soft delete" yapiyor (`durum=kaldirildi`) ve
      //	listede DONDURMEYE devam ediyor. Sahibi gormeli (geri
      //	alabilir) ama musteri icin bunlar menude YOK hukmundedir —
      //	aksi halde silinen her kalem menuyu kirletirdi (tohum
      //	kaydinda olculdu: 18 yayinda, 24 kaldirilmis).
      if (!widget.benimMi && u.durum == 'kaldirildi') continue;
      if (q.isNotEmpty) {
        final metin = '${u.ad} ${u.aciklama} ${u.bolum}'
            .replaceAll('İ', 'i')
            .replaceAll('I', 'ı')
            .toLowerCase();
        if (!metin.contains(q)) continue;
      }
      m.putIfAbsent(u.bolum.isEmpty ? 'Diğer' : u.bolum, () => []).add(u);
    }
    return m;
  }

  // ⚠️⚠️ **STATE METOTLARI `Theme`I GORMEZ** (turu 135c/138): `build`in
  //	DONDURDUGU agaca konan `Theme`, State'in KENDI `context`inin
  //	ALTINDA kalir. Metotlar rengi buradan okur.
  ColorScheme get _ks => kKoyuTema.colorScheme;

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    final l = _liste;
    // ⚠️ TURU 178 — menu ekrani da SIYAH: cagiran iki yuzey (yemek
    //    kategorisi ve isletme profili) siyah; beyaz bir ara sayfa
    //    gecisi KOPUK gorunuyordu (emulatorde bakildi).
    return koyuSayfa(Scaffold(
      // ⚠️⚠️ TURU 178 — **HEADER YEMEK EKRANIYLA AYNI** (kullanici emri:
      //	*"menuye tikladiginda ust menu yemekteki gibi ust header
      //	olsun"*): 44 dp · ortada baslik · solda `arrowLeft`.
      // ⚠️ `AppBar` KULLANILMIYOR: Material'in kendi `BackButton`u
      //	PLATFORMA gore degisir ve baslik SOLA yaslidir.
      // ⚠️⚠️ TURU 180 — **ASAGI INERKEN HEADER GIZLENIR** (kullanici emri:
      //	*"alta inerken header gorunmeyecek"*).
      // ⚠️ `AnimatedSize` ile YUKSEKLIK 0'a iner: widget agactan
      //	CIKARILSAYDI `PreferredSize` null olamaz ve `Scaffold`
      //	yeniden yerlesirken icerik ZIPLARDI.
      // ⚠️ `SafeArea` KATMANIN DISINDA kalir: centik dolgusu daima
      //	uygulanmali, yoksa header gizlenince arama kutusu durum
      //	cubugunun ALTINA girer.
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_headerGizli ? 0 : 44),
        // ⚠️⚠️⚠️ TURU 180g — **`ClipRect` ZORUNLU** (kullanici: *"asagi
        //	inerken SOLDAKI GERI TUSU KAYBOLMUYOR"*).
        //
        //	`Scaffold` appBar'a `preferredSize` kadar yer verir ama
        //	cocugu KIRPMAZ. Yukseklik 0'a inince `SafeArea` +
        //	44 dp'lik `Stack` kutunun DISINA TASIP CIZILMEYE
        //	devam ediyordu: baslik gidiyor gibi gorunuyor ama geri
        //	oku EKRANDA KALIYORDU.
        // ⚠️ `AnimatedSize`in kendi `clipBehavior`i YETMEZ: o yalniz
        //	KENDI animasyonlu kutusunu kirpar, `SafeArea`nin
        //	dolgusunu degil.
        child: ClipRect(
        child: SafeArea(
          bottom: false,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            // ⚠️ `clipBehavior` ZORUNLU: yukseklik 0'a inerken icerik
            //    (geri oku + baslik) TASIYOR ve arama kutusunun uzerine
            //    biniyordu (emulatorde goruldu).
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
            height: _headerGizli ? 0 : 44,
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Text(
                      widget.isletmeAd.isEmpty
                          ? widget.modul.ad
                          : widget.isletmeAd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(LucideIcons.arrowLeft, size: 24),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
          // ⚠️ AI MENU dugmesi: YALNIZ sahibine ve YALNIZ AI aciksa.
          if (widget.benimMi && (ai?.acik ?? false))
            IconButton(
              // ⚠️ TURU 78: artik IKI yol var (fotograf + yazili tarif), bu
              //    yuzden ipucu da genellestirildi. Eski metin kullaniciyi
              //    "yalnizca fotograf" sanisina dusururdu.
              tooltip: 'Yapay zekâ ile menü',
              icon: const Icon(LucideIcons.sparkles),
              onPressed: _aiMenu,
            ),
                  ]),
                ),
              ],
            ),
            ),
          ),
        ),
        ),
      ),
      floatingActionButton: widget.benimMi
          ? FloatingActionButton.extended(
              heroTag: 'fabUrunEkle',
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => UrunDuzenleEkrani(modul: widget.modul),
                  ),
                );
                if (ok == true) _yukle();
              },
              icon: const Icon(LucideIcons.plus),
              // TURU 89 - 'Oda ekle' / 'Hizmet ekle' / 'Ürün ekle'.
              label: Text('${widget.modul.tekil} ekle'),
            )
          : null,
      body: _hata != null
          ? Center(
              child: Text(_hata!, style: const TextStyle(color: Colors.grey)),
            )
          : l == null
          ? const Center(child: CircularProgressIndicator())
          : l.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                  widget.benimMi
                      ? 'Henüz ürün eklemedin.\nSağ alttan ilk ürününü ekle.'
                      : 'Bu işletme henüz ürün eklememiş.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          // ⚠️⚠️ TURU 179 — arama ve bolum seridi **KAYDIRMA DISINDA**
          //	(kullanici: *"asagi inerken arama butonu ustte
          //	kalsin"*). Liste icinde birakilsaydi yukari kayip
          //	kaybolurlardi.
          // ⚠️ `SliverPersistentHeader` KULLANILMADI: `YenileSarmali`
          //	(asagi-cek) bir `RefreshIndicator` ve onun cocugu
          //	kaydirilabilir OLMAK ZORUNDA. Sabit basliklari
          //	listenin DISINA almak hem daha basit hem de
          //	asagi-cek jestini bozmuyor.
          : Column(
              children: [
                _arama(),
                _bolumSeridi(),
                Expanded(
                  child: YenileSarmali(
                    onRefresh: _yukle,
                    child: ListView(
                      // ⚠️ Kaydirma takibi listenin EKRANDAKI ust kenarini
                      //    olcuyor (bkz. `_ustdekiBolum`).
                      key: _listeAnahtar,
                      controller: _kaydirma,
                      padding: const EdgeInsets.only(top: 4, bottom: 90),
                      children: [
                        if (_bolumler.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Text(
                                'Eşleşen bir şey yok.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        for (final b in _bolumler.entries) ...[
                          Padding(
                            key: _anahtar(b.key),
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: Text(
                              b.key,
                              // ⚠️ TURU 178 — punto 11 -> 15 ve BUYUK HARF
                              //	YOK: `toUpperCase()` Dart'ta 'i' -> 'I'
                              //	yapar; 'İçecek' -> 'IÇECEK' cikardi
                              //	(turu 142 dersi).
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _ks.onSurface.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                          for (final u in b.value) _satir(u),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ));
  }

  /// ⚠️ TURU 178 — arama kutusu **yemek ekraniyla ayni dilde**: cerceve YOK,
  //	hafif dolgu, 24 radus, soldan 16 dp iceride 21 px ikon.
  // ⚠️ Dolgu ZORUNLU: cercevesiz VE dolgusuz bir alan dokunulabilir
  //	gorunmez (turu 174 dersi).
  Widget _arama() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: TextField(
          onChanged: (v) => setState(() => _q = v.trim()),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '${widget.modul.ad} içinde ara',
            filled: true,
            fillColor: _ks.onSurface.withValues(alpha: 0.07),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16, right: 10),
              child: Icon(LucideIcons.search, size: 21),
            ),
            prefixIconConstraints: const BoxConstraints(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  /// ⚠️⚠️ TURU 179 — **BOLUM SEKMELERI** (kullanici: *"ustte menu
  //	cizgileri, aynen profildeki fotograf tarzi; burger vs
  //	tikladigimda oraya girsin"*).
  //
  // ⚠️ Tek bolum varsa serit CIZILMEZ: tek sekmelik bir gezinme
  //	cubugu hicbir sey secmez, yalniz yer kaplar.
  // ⚠️ Serit ARAMA SONUCUNA gore daralir (`_bolumler` suzulmus kume):
  //	aksi halde arama sonucunda gorunmeyen bir bolume
  //	goturen olu bir sekme kalirdi.
  Widget _bolumSeridi() {
    final adlar = _bolumler.keys.toList();
    if (adlar.length < 2) return const SizedBox.shrink();
    // ⚠️ TURU 180 — arama ile serit arasinda bosluk YOKTU (kullanici emri).
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: adlar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final ad = adlar[i];
          // ⚠️ Ilk bolum, kullanici hicbir seye dokunmadiysa SECILI
          //    gorunur: bos bir seritte hangi bolumde oldugu
          //    anlasilmazdi.
          final secili =
              _aktifBolum.isEmpty ? i == 0 : _aktifBolum == ad;
          return GestureDetector(
            onTap: () => _bolumeGit(ad),
            child: Container(
              key: _sekmeAnahtari(ad),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: secili
                    ? _ks.primary
                    : _ks.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ad,
                style: TextStyle(
                  fontSize: 14,
                  // ⚠️ Kalinlik SABIT: secimle degisseydi metnin
                  //    genisligi degisir ve serit her dokunusta
                  //    KAYARDI (turu 140 dersi).
                  fontWeight: FontWeight.w700,
                  color: secili
                      ? _ks.onPrimary
                      : _ks.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 178 — **MENU KALEMI YENIDEN KURULDU** (kullanici emri:
  //	*"menulerde resim alanlari olsun, aciklama kismi olsun, biraz
  //	daha yazi tipleri buyuk olsun"*).
  //
  //	Eski hal bir `ListTile` idi: gorsel 56 dp ve YALNIZ medya
  //	varsa, ad varsayilan punto (14), aciklama silik, fiyat 14.
  //	Kalemler birbirinden ayirt edilemiyordu.
  // ⚠️ Gorsel **DAIMA cizilir**: kaynak yoksa notr yer tutucu gelir.
  //	Kosullu cizilseydi kimi satir 92 dp kimi 56 dp olur ve liste
  //	ZIPLARDI.
  // ⚠️ Satir yuksekligi ICERIKTEN gelir (sabit `height` YOK): yazi olcegi
  //	buyudugunde aciklama sarar, kart uzar, TASMAZ.
  Widget _satir(Urun u) {
    final scheme = _ks;
    final tukendi = u.durum == 'tukendi';
    // ⚠️⚠️ TURU 179 — **HER KALEM KENDI KARTINDA** (kullanici:
    //	*"menulerinde ARKA PLAN RENGI olsun; cheeseburger'in
    //	ismi, aciklamasi, fiyati, resim alani BIR ALANIN ICINDE
    //	olsun"*). Onceden kalemler cizgisiz akiyordu ve nerede
    //	bittigi belirsizdi.
    // ⚠️ `Material` + `InkWell` sirasi: `InkWell`in dalgasi `Material`in
    //	USTUNDE cizilir; ters kurulsaydi dalga kartin dis
    //	kosesine TASARDI.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
      // ⚠️⚠️ TURU 179 — **MUSTERI DOKUNUSU ARTIK DETAY SAYFASINI ACAR**
      //	(kullanici: *"urun detay sayfasi da olacakti; POPUP DEGIL,
      //	direk icine girsin"*). Onceden `benimMi` degilse `onTap`
      //	**null** idi: kalem tiklanabilir gorunmuyordu ve detay
      //	gormenin HICBIR yolu yoktu.
      // ⚠️ Sahipte DUZENLEME ekrani KALIR: detay salt okuma, duzenleme
      //	ayri bir yetki — ikisini tek ekranda birlestirmek musteriye
      //	gorunen bir yuzeyde yazma yollari acardi.
      onTap: widget.benimMi
          ? () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      UrunDuzenleEkrani(urun: u, modul: widget.modul),
                ),
              );
              if (ok == true) _yukle();
            }
          : () => urunDetayAc(
              context,
              urun: u,
              isletmeAd: widget.isletmeAd,
              modul: widget.modul,
            ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.ad,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: tukendi
                          ? scheme.onSurface.withValues(alpha: 0.45)
                          : null,
                    ),
                  ),
                  if (u.aciklama.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      u.aciklama,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: scheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        u.fiyatMetni,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (tukendi) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Tükendi',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                      ] else if (u.durum == 'kaldirildi') ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Kaldırıldı',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _kalemGorseli(u, scheme),
          ],
        ),
      ),
        ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 179 — **ORNEK MARKA FOTOGRAFI ARTIK CIZILMIYOR** (kullanici:
  //	*"menulerde resim yerine BOS kalsin, resim KATI olsun
  //	simdilik"*). Alan DURUYOR — gorsel yuklendiginde ayni
  //	kutuya oturur ve kart yuksekligi DEGISMEZ.
  //
  // ⚠️ GERCEK medya HALA cizilir: isletme kendi fotografini yuklediyse
  //	onu gizlemek bir ozelligi OLDURMEK olurdu. Kaldirilan yalniz
  //	`assets/marka` ORNEK fotograflaridir.
  // ⚠️ `_ornekGorsel` / `kOrnekMenuGorsel` SILINMEDI: karar tek satirla
  //	geri alinabilsin (bu dosyada uye silmek komsu uyeyi goturdu).
  /// ⚠️ `cacheWidth` ZORUNLU: 92 dp'lik kutu icin ham cozunurlukte cozmek
  //	kare basina megabaytlarca gecici RAM demek (turu 91 dersi).
  Widget _kalemGorseli(Urun u, ColorScheme scheme) {
    const boy = 92.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: boy,
        height: boy,
        child: u.mediaIds.isNotEmpty
            ? Stack(
                children: [
                  Positioned.fill(
                    child: MedyaGorsel(
                      mediaId: u.mediaIds.first,
                      kucuk: true,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // ⚠️⚠️ TURU 180o — COKLU FOTOGRAF ROZETI.
                  //    Listede yalniz KAPAK cizilir; rozet olmadan musteri
                  //    urunun baska fotograflari oldugunu BILEMEZ ve detaya
                  //    girip galeriyi kaydirmayi hic denemez.
                  if (u.mediaIds.length > 1)
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.images,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${u.mediaIds.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : _yerTutucu(scheme),
      ),
    );
  }

  /// ⚠️ Alfa 0.07 -> **0.11**: kart zemini de 0.06 ve ikisi ayni tonda
  //	olsaydi resim alani kartin icinde GORUNMEZ olurdu.
  /// ⚠️ TURU 180g — **IKON KALDIRILDI** (kullanici: *"resim olmayanlarda
  //	IKON OLMASIN"*). Alan yine CIZILIR: kosullu olsaydi kimi satir
  //	92 kimi 56 dp olur ve liste ZIPLARDI (turu 178 dersi).
  Widget _yerTutucu(ColorScheme scheme) => ColoredBox(
        color: scheme.onSurface.withValues(alpha: 0.11),
        child: const SizedBox.expand(),
      );

  /// ⚠️⚠️ AI MENU — **IKI YOL**: menu FOTOGRAFINDAN oku ya da YAZILI TARIFTEN
  ///    olustur.
  ///
  /// ⚠️⚠️ TURU 78 — YAZILI TARIF YOLU EKLENDI. Sunucu (`POST /ai/menu`)
  ///    `metin` alanini BASINDAN BERI kabul ediyordu, ama istemci YALNIZCA
  ///    fotograf gonderiyordu: yani "menuyu AI ile OLUSTUR" yetenegi sunucuda
  ///    VAR, uygulamada ULASILAMAZ durumdaydi. Bu, projede BES kez tekrarlayan
  ///    "sunucuda var, ekranda yok" sinifiydi.
  ///    Kullanici emri acikca "menulerini yapay zeka ile OLUSTURABILMELI" idi;
  ///    fotograftan OKUMAK farkli bir istir.
  ///    ⚠️ YAPMA: bu secim sheet'ini kaldirip yalniz fotografa donme.
  ///
  /// ⚠️ Sonuc DOGRUDAN KAYDEDILMEZ — kullaniciya ONERI listesi gosterilir, o
  ///    onaylar. Otomatik kaydetmek yanlis okunan/uydurulan bir fiyati
  ///    sessizce menuye yazardi.
  Future<void> _aiMenu() async {
    final yol = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Menü fotoğrafından oku'),
              subtitle: const Text('Basılı menünün fotoğrafını seç'),
              onTap: () => Navigator.pop(c, 'foto'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.penLine),
              title: const Text('Anlatarak oluştur'),
              subtitle: const Text(
                'Örnek: Adana usulü kebapçı, 15 çeşit, ortalama 250 TL',
              ),
              onTap: () => Navigator.pop(c, 'metin'),
            ),
          ],
        ),
      ),
    );
    if (yol == null || !mounted) return;
    if (yol == 'metin') {
      await _aiMenuMetinden();
      return;
    }

    if (!MedyaKapisi.izinVer(ref)) return;
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;

    // ⚠️⚠️ TURU 78b — SERVISLER **AWAIT'LERDEN ONCE** yakalanir.
    //    Buradaki pencere projedeki EN GENIS pencere: AI cagrisi **60 saniyeye
    //    kadar** surebiliyor. Kullanici bekleme diyalogunu geri tusuyla kapatip
    //    bir kez daha geri basarsa ekran dispose olur; `ref.read` `StateError`
    //    firlatir, catch yutar ve KOTA ZATEN HARCANMIS oldugu halde kullanici
    //    HICBIR SONUC GORMEZ (kota rezervasyonu cagridan ONCE yapiliyor).
    //    ⚠️ YAPMA: bu satirlari await'lerin ALTINA tasima.
    final medyaSvc = ref.read(medyaServisiProvider);
    final aiSvc = ref.read(aiServisiProvider);

    final bekleme = _beklemeAc('Menü okunuyor...');
    try {
      final hazir = await MedyaServisi.gorseliHazirla(File(x.path));
      if (hazir == null) throw Exception('Görsel hazırlanamadı');
      final mediaId = await medyaSvc.yukle(
        dosya: hazir,
        kind: 'image',
        mime: 'image/jpeg',
      );
      final sonuc = await aiSvc.menu(mediaId: mediaId);
      if (!mounted) return;
      bekleme.kapat(context);
      // ⚠️ TURU 77b — KOTA SAYACI TAZELENIR. `aiDurumProvider` SUREC OMURLU ve
      //    hicbir yerde invalidate EDILMIYORDU: dugme etiketindeki "(20)" 20
      //    cagridan sonra bile "(20)" der, kullanici sonra 429 alirdi.
      ref.invalidate(aiDurumProvider);
      await _oneriGoster(sonuc);
    } catch (e) {
      if (mounted) bekleme.kapat(context);
      // ⚠️ KOK MESSENGER: cagri onlarca saniye surer, ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  /// ⚠️ TURU 78 — YAZILI TARIFTEN MENU OLUSTURMA.
  ///
  /// ⚠️ Model UYDURUR: fotograftan okumada "yanlis okuma" riski varken burada
  ///    "hic olmayan urun" riski var. Bu yuzden onay adimi DAHA DA onemli ve
  ///    diyalogda kullaniciya ACIKCA soyleniyor.
  /// ⚠️ FIYAT: kullanici ortalama fiyat yazabilir ama model 2026 Gebze
  ///    fiyatlarini BILMEZ. Onerilen fiyatlar TASLAKTIR — kullanici onay
  ///    ekraninda gorur ve isterse duzenler.
  Future<void> _aiMenuMetinden() async {
    final ctrl = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => DenetleyiciSahibi(
        denetleyiciler: [ctrl],
        child: AlertDialog(
        // ⚠️⚠️ TURU 78b — `scrollable: true` ZORUNLU (denetim bulgusu).
        //    `AlertDialog`in scrollable OLMAYAN dalinda icerik
        //    `Flexible(child: content)` icine konur ve klavye acilinca kalan
        //    yukseklik cok kucuk olur: 6 satirlik metin kutusu + uyari metni
        //    KIRPILIR, kullanici ne yazdigini goremez. Ozellikle kucuk
        //    ekranlarda (360x640) "Oluştur" dugmesi bile erisilemez olur.
        //    ⚠️ YAPMA: `scrollable`i kaldirma.
        scrollable: true,
        title: const Text('Menüyü anlatarak oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              // ⚠️ Sunucu 2000 karaktere kirpiyor; istemcide de AYNI tavan
              //    gosterilsin ki kullanici sessizce kesilen metin yazmasin.
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText:
                    'İşletmeni ve menünü anlat.\n'
                    'Örnek: Adana usulü kebapçı, 15 çeşit, '
                    'ortalama 250 TL, çorba ve tatlı da var.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Yapay zekâ bir TASLAK üretir. Ürünleri ve fiyatları '
              'onaylamadan menüne eklenmez.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Oluştur'),
          ),
        ],
        ),
      ),
    );
    // ⚠️ Metin SENKRON okunur (route hala cikis animasyonunda = denetleyici
    //    CANLI); birakmayi DenetleyiciSahibi yapar.
    final tarif = ctrl.text.trim();
    if (onay != true || tarif.isEmpty || !mounted) return;

    // ⚠️⚠️ TURU 78b — SERVIS **AWAIT'TEN ONCE** yakalanir (fotograf yolundaki
    //    ile AYNI gerekce: AI cagrisi 60 saniyeye kadar surer).
    final aiSvc = ref.read(aiServisiProvider);

    final bekleme = _beklemeAc('Menü oluşturuluyor...');
    try {
      final sonuc = await aiSvc.menu(metin: tarif);
      if (!mounted) return;
      bekleme.kapat(context);
      ref.invalidate(aiDurumProvider); // kota sayaci tazelenir
      await _oneriGoster(sonuc);
    } catch (e) {
      if (mounted) bekleme.kapat(context);
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  /// ⚠️⚠️⚠️ TURU 78b — BEKLEME DIYALOGU **GERI TUSUNA KAPALI** + kapanisini
  /// KENDI izler (denetim: SEVK ENGELI).
  ///
  /// ESKI KOD: `var diyalogAcik = true;` + `barrierDismissible: false`.
  /// **`barrierDismissible` YALNIZ PERDEYE DOKUNMAYI engeller — ANDROID GERI
  /// TUSU diyalog route'unu YINE DE POP EDER.** Kullanici "Menü oluşturuluyor..."
  /// beklerken (AI cagrisi ONLARCA saniye surer) sabirsizlanip geri basarsa:
  ///   · diyalog kapanir, `diyalogAcik` bayragi HALA `true` (yalanci),
  ///   · cagri donunce basari dali KOSULSUZ `Navigator.pop()` cagirir,
  ///   · en ustteki route artik **KATALOG EKRANIDIR** -> kullanicinin urun
  ///     listesi ekrani KAPANIR, ustelik oneri diyalogu bir daha acilamaz.
  ///
  /// FIX IKI KATMANLI:
  ///   1. `PopScope(canPop: false)` — geri tusu diyalogu KAPATAMAZ, yani
  ///      "en ustteki route diyalogdur" varsayimi GARANTI olur.
  ///   2. `whenComplete` — diyalog HERHANGI bir yolla kapanirsa bayrak
  ///      GERCEKLE senkron kalir (savunma katmani).
  /// ⚠️ YAPMA: `PopScope`u kaldirma; bayragi elle yonetmeye geri donme.
  _BeklemeKapisi _beklemeAc(String mesaj) {
    final kapi = _BeklemeKapisi();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(mesaj)),
            ],
          ),
        ),
      ),
    ).whenComplete(() => kapi.acik = false);
    return kapi;
  }

  Future<void> _oneriGoster(String ham) async {
    // ⚠️ Model bazen bozuk JSON dondurebilir — PATLAMAK YERINE ham metni
    //    gosteriyoruz. Kullanici en azindan sonucu gorur.
    List<Map<String, dynamic>> urunler = [];
    try {
      final j = jsonDecode(ham);
      if (j is Map && j['urunler'] is List) {
        urunler = (j['urunler'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }
    } catch (_) {}

    if (!mounted) return;
    if (urunler.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Menü okunamadı'),
          content: SingleChildScrollView(child: Text(ham)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    final secili = List<bool>.filled(urunler.length, true);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, yenile) => AlertDialog(
          title: Text('${urunler.length} ürün bulundu'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: urunler.length,
              itemBuilder: (_, i) {
                final u = urunler[i];
                // ⚠️⚠️ TURU 77b — TIP KORUMASI ZORUNLU (denetim bulgusu).
                //    JSON *ayristirmasi* korunmustu ama ALAN TIPLERI
                //    korunmamisti. Dil modelleri talimata ragmen sik sik
                //    `"fiyat_kurus": "1250"` (METIN) donduruyor; ciplak
                //    `as num?` cast'i `itemBuilder` ICINDE `TypeError` atar ve
                //    oneri diyalogu KIRMIZI HATA KUTUSUNA doner -> kullanici
                //    HICBIR urunu ekleyemez. (Ayni cast bir alt satirda
                //    `catch(_)` ile korunuyordu = ASIMETRI.)
                //    ⚠️ YAPMA: ciplak cast'e geri donme.
                //
                // ⚠️⚠️ TURU 78b — AYRISTIRMA ARTIK **TEK KAYNAK** (`_kurusOku`).
                //    Turu 77b bu korumayi YALNIZ BURAYA (gosterim yoluna)
                //    koymustu; KAYDETME yolu ciplak `as num?` ile kalmisti.
                //    Sonuc sinsiydi: model fiyati METIN dondurdugunde diyalog
                //    urunleri DOGRU fiyatlariyla listeliyor, kullanici hepsini
                //    isaretleyip "Menüye ekle" diyor ve **"0 ürün eklendi"**
                //    goruyordu — hicbir ipucu olmadan.
                //    ⚠️ YAPMA: iki yolda ayri ayristirma yazma (drift eder).
                final kurus = _kurusOku(u['fiyat_kurus']);
                return CheckboxListTile(
                  dense: true,
                  value: secili[i],
                  onChanged: (v) => yenile(() => secili[i] = v ?? false),
                  title: Text((u['ad'] ?? '').toString()),
                  subtitle: Text(
                    [
                      if ((u['bolum'] ?? '').toString().isNotEmpty)
                        u['bolum'].toString(),
                      if (kurus > 0) kurusMetni(kurus),
                    ].join(' · '),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Menüye ekle'),
            ),
          ],
        ),
      ),
    );
    if (onay != true || !mounted) return;

    // ⚠️ Servis await'lerden ONCE (bkz. `_kaydet` serhi): dongu onlarca urun
    //    icin onlarca istek atar ve arada ekran dispose olabilir.
    final urunSvc = ref.read(urunServisiProvider);
    var eklenen = 0;
    var basarisiz = 0;
    for (var i = 0; i < urunler.length; i++) {
      if (!secili[i]) continue;
      try {
        await urunSvc.ekle({
          'ad': (urunler[i]['ad'] ?? '').toString(),
          'aciklama': (urunler[i]['aciklama'] ?? '').toString(),
          'bolum': (urunler[i]['bolum'] ?? '').toString(),
          // ⚠️ TEK KAYNAK (yukaridaki gosterim yoluyla AYNI ayristirma).
          'fiyat_kurus': _kurusOku(urunler[i]['fiyat_kurus']),
          'media_ids': <String>[],
        });
        eklenen++;
      } catch (_) {
        // ⚠️ SESSIZ YUTMA YOK: eskiden `catch (_) {}` idi ve bir sorun oldugunda
        //    kullanici yalnizca "0 ürün eklendi" goruyordu — sebebi anlamasinin
        //    HICBIR yolu yoktu.
        basarisiz++;
      }
    }
    if (!mounted) return;
    await _yukle();
    // ⚠️ KOK MESSENGER: dongu uzun surer, ekran degismis olabilir.
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          basarisiz == 0
              ? '$eklenen ürün eklendi'
              : '$eklenen ürün eklendi, $basarisiz tanesi eklenemedi',
        ),
      ),
    );
  }

  /// AI'nin dondurdugu fiyati kurusa cevirir — **TEK KAYNAK**.
  ///
  /// ⚠️⚠️ Dil modelleri talimata ragmen sik sik `"fiyat_kurus": "1250"` (METIN)
  ///    donduruyor. Ciplak `as num?` cast'i bu durumda `TypeError` atar.
  ///    Turu 77b bu korumayi gosterim yoluna koydu, KAYDETME yoluna koymadi ve
  ///    turu 78b denetimi bunu SEVK ENGELI olarak yakaladi ("0 ürün eklendi").
  /// ⚠️ YAPMA: cagiran yerlere ayri ayristirma yazma.
  static int _kurusOku(dynamic ham) {
    if (ham is num) return ham.toInt();
    return int.tryParse(ham?.toString() ?? '') ?? 0;
  }
}

/// Urun ekle / duzenle (+ AI aciklama).
class UrunDuzenleEkrani extends ConsumerStatefulWidget {
  const UrunDuzenleEkrani({super.key, this.urun, this.modul = Modul.varsayilan});

  /// TURU 89 — kategoriye ozel alan tanimlari ve etiketler.
  final Modul modul;
  final Urun? urun;

  @override
  ConsumerState<UrunDuzenleEkrani> createState() => _UrunDuzenleEkraniState();
}

class _UrunDuzenleEkraniState extends ConsumerState<UrunDuzenleEkrani> {
  late final _ad = TextEditingController(text: widget.urun?.ad ?? '');
  late final _aciklama = TextEditingController(
    text: widget.urun?.aciklama ?? '',
  );
  late final _bolum = TextEditingController(text: widget.urun?.bolum ?? '');
  late final _fiyat = TextEditingController(
    text: widget.urun == null || widget.urun!.fiyatKurus == 0
        ? ''
        : (widget.urun!.fiyatKurus / 100).toStringAsFixed(2),
  );

  /// ⚠️⚠️ TURU 89 — MODULE OZEL ALANLARIN DEGERLERI (kapasite, yatak, süre...).
  ///
  /// Alan TANIMLARI sunucudan gelir (`widget.modul.alanlar`); burada yalnizca
  /// GIRILEN DEGERLER tutulur ve `ozellikler` JSONB'sine yazilir.
  /// ⚠️ Duzenlemede mevcut degerlerle DOLDURULUR — aksi halde kullanici
  ///    baska bir alani degistirip kaydettiginde girdigi kapasite/süre
  ///    SESSIZCE SILINIRDI.
  late final Map<String, String> _ozellikler = {
    ...?widget.urun?.ozellikler,
  };

  /// ⚠️⚠️⚠️ TURU 180o — **COKLU FOTOGRAF** (kullanici: *"otel odasinda
  ///    galeri vs bu galeriler aciliyor mu, her sey var mi"*).
  ///
  /// Onceden burada `File? _gorsel` vardi: bir otel odasina ya da hizmete
  /// **TEK** fotograf eklenebiliyordu ve detay sayfasi da yalniz onu
  /// ciziyordu. Sutun (`isletme_urunleri.media_ids UUID[]`, migration 031)
  /// ve sunucu ZATEN dizi tasiyordu — eksik olan ARAYUZDU.
  /// ⚠️ Backend'e DOKUNULMADI (kullanici: *"backendi sonra yap arayuzu
  ///    hizli cikart"*).
  final List<File> _gorseller = [];

  /// ⚠️ AI aciklama yolu tek gorsel ister; ilk fotograf temsilcidir.
  File? get _gorsel => _gorseller.isEmpty ? null : _gorseller.first;

  /// ⚠️ Tavan: cok fotograf = cok yukleme + cok R2 nesnesi. 6 kare,
  ///    onizleme seridinde kaydirmadan sigan sayidir.
  static const int _enFazlaFoto = 6;

  bool _kaydediliyor = false;
  bool _aiCalisiyor = false;

  /// ⚠️ TURU 79 — gorsel uretimi surerken dugmeyi KILITLER. Cift dokunus IKI
  ///    kotayi birden yakar ve uretim GERI ALINAMAZ (para harcanir).
  bool _gorselUretiliyor = false;

  /// ⚠️ TURU 79 — kullanicinin ONAYLADIGI AI gorselinin id'si.
  ///    `_gorsel` (elle secilen dosya) ile AYNI ANDA dolu olamaz — onay
  ///    adiminda oteki dusurulur, yoksa `_kaydet` hangisini gonderecegini
  ///    bilemez ve biri SESSIZCE kaybolurdu.
  String? _uretilenMediaId;

  /// yayinda | tukendi  (⚠️ 'kaldirildi' arayuzden AYARLANMAZ — o "Kaldır"
  /// dugmesinin isi; iki yol ayni durumu yazsaydi kullanici hangisinin ne
  /// yaptigini bilemezdi.)
  late String _durum = widget.urun?.durum == 'tukendi' ? 'tukendi' : 'yayinda';

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    _bolum.dispose();
    _fiyat.dispose();
    super.dispose();
  }

  Future<void> _gorselSec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    final kalan = _enFazlaFoto - _gorseller.length;
    if (kalan <= 0) return;
    // ⚠️⚠️ `MedyaSecici.coklu` TEK KAYNAK: `pickMultiImage(limit: 1)`
    //    **ArgumentError FIRLATIR** ve o hata burada sessizce yutulurdu
    //    (turu 90b dersi). Yardimci, tavan 1 iken sinirsiz acip donusu
    //    kirpar.
    final secim = await MedyaSecici.coklu(kalan);
    if (secim.isEmpty || !mounted) return;
    setState(() {
      _gorseller.addAll(secim.map((x) => File(x.path)));
      // ⚠️⚠️ TURU 79 — SIMETRI ZORUNLU: onay adimi elle secilen dosyayi
      //    dusuruyor, burasi da AI gorselini DUSURMELI. Ikisi ayni anda dolu
      //    kalsaydi `_kaydet` AI'i tercih eder ve kullanicinin YENI SECTIGI
      //    fotograf SESSIZCE kaybolurdu ("sectim ama eskisi kaldi").
      _uretilenMediaId = null;
    });
  }

  /// ⚠️⚠️⚠️ TURU 79 — YAPAY ZEKA ILE URUN GORSELI URETIR.
  ///
  /// Kullanici emri: *"yapay zeka ile görsel oluşturma nerede"* / *"hepsi olsun"*.
  ///
  /// ⚠️ SONUC **ONAY ADIMINDAN GECER**: uretilen gorsel dogrudan urune
  ///
  ///	baglanmaz, kullaniciya buyuk gosterilir ve "Kullan / Vazgeç" sorulur.
  ///	Model yanlis/alakasiz bir sey cizebilir; menu onerisindeki ILKENIN AYNISI.
  ///
  /// ⚠️ URETIM PARA HARCAR ve GERI ALINAMAZ: dugme cagri boyunca KILITLENIR
  ///
  ///	(`_gorselUretiliyor`), yoksa cift dokunus IKI kotayi birden yakar.
  ///
  /// ⚠️ Servis await'lerden ONCE yakalanir (bkz. `_kaydet` serhi): uretim
  ///
  ///	120 saniyeye kadar surebiliyor ve o pencerede ekran dispose olabilir.
  Future<void> _aiGorsel() async {
    if (_gorselUretiliyor) return;
    final ad = _ad.text.trim();
    final tarif = await _gorselTarifiSor(ad);
    if (tarif == null || !mounted) return;
    // ⚠️ TURU 79b — BOS TARIF **SESSIZCE GECILMEZ** (denetim bulgusu).
    //    Eskiden bos metinle "Oluştur"a basmak hicbir sey yapmiyordu ve
    //    kullanici dugmenin bozuk oldugunu saniyordu.
    if (tarif.isEmpty) {
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Ne çizilmesini istediğini yaz')),
      );
      return;
    }

    final aiSvc = ref.read(aiServisiProvider);
    setState(() => _gorselUretiliyor = true);
    try {
      final mediaId = await aiSvc.gorsel(metin: tarif);
      if (!mounted) return;
      if (mediaId.isEmpty) {
        rootMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Görsel oluşturulamadı')),
        );
        return;
      }
      await _uretilenGorseliOnayla(mediaId, aiSvc);
    } catch (e) {
      // ⚠️ KOK MESSENGER: uretim uzun surer, ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      // ⚠️⚠️ TURU 79b — KOTA SAYACI **`finally` ICINDE** TAZELENIR (denetim).
      //    Eskiden yalniz BASARI dalindaydi; zaman asimi ya da 502 sonrasi
      //    etiketteki hak sayisi BAYAT kaliyordu. Ustelik basarisiz istek de
      //    (faturalanmis olabilecegi icin) kotadan DUSUYOR — yani sayacin
      //    guncellenmesi gereken en onemli an tam da HATA aniydi.
      if (mounted) {
        setState(() => _gorselUretiliyor = false);
        ref.invalidate(aiDurumProvider);
      }
    }
  }

  /// Ne cizilecegini sorar. ⚠️ Urun adi VARSA hazir gelir — kullanicinin
  ///    coguna dokunmadan onaylamasi icin.
  Future<String?> _gorselTarifiSor(String ad) async {
    final ctrl = TextEditingController(text: ad);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => DenetleyiciSahibi(
        denetleyiciler: [ctrl],
        child: AlertDialog(
        // ⚠️ `scrollable`: klavye acilinca icerik kirpilmasin (turu 78b dersi).
        scrollable: true,
        title: const Text('Yapay zekâ ile görsel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText:
                    'Ne çizilsin?\n'
                    'Örnek: tabakta Adana kebap, yanında bulgur pilavı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Görsel yapay zekâ tarafından ÜRETİLİR; gerçek bir fotoğraf '
              'değildir. Beğenmezsen kullanmak zorunda değilsin.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Oluştur'),
          ),
        ],
        ),
      ),
    );
    // ⚠️ Metin SENKRON okunur; birakmayi DenetleyiciSahibi yapar.
    final metin = ctrl.text.trim();
    return onay == true ? metin : null;
  }

  /// Uretilen gorseli BUYUK gosterir ve onay ister.
  ///
  /// ⚠️ Onaylanirsa `_uretilenMediaId` doldurulur; `_kaydet` bunu `media_ids`e
  ///    koyar.
  /// ⚠️⚠️ TURU 79b — REDDEDILIRSE **SUNUCUDAN SILINIR** (denetim bulgusu).
  ///    Eskiden hicbir sey yapilmiyordu: medya R2'de 'aktif' kaliyor, hicbir
  ///    yere baglanmiyor ve kullanicinin AYLIK DEPOLAMA KOTASINDAN kalici
  ///    olarak dusuyordu. Birkac denemeden sonra kota, kullanicinin HIC
  ///    GORMEDIGI dosyalarla dolar ve temizleyecek bir yol da YOKTU.
  ///    ⚠️ AI hakki iade EDILMEZ (uretim gercekten para harcadi) — yalnizca
  ///       depolama geri verilir. Aksi halde "begenene kadar sinirsiz deneme"
  ///       olurdu.
  Future<void> _uretilenGorseliOnayla(String mediaId, AiServisi aiSvc) async {
    final kullan = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Görsel hazır'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: MedyaGorsel(mediaId: mediaId, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            // ⚠️ TURU 79b — KARAR ANINDA BILGI (denetim bulgusu). Uyari ilk
            //    diyalogda vardi ama ONAY aninda yoktu; kullanicinin "bu gercek
            //    bir fotograf mi" sorusunu sorabilecegi TEK an burasi.
            const Text(
              'Bu görsel yapay zekâ ile üretildi; gerçek bir fotoğraf değildir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kullan'),
          ),
        ],
      ),
    );
    if (kullan != true) {
      // ⚠️ TURU 79b: reddedilen gorsel SUNUCUDAN SILINIR (depolama kotasi iade).
      //    `mounted` KONTROLU YOK ve `unawaited` DEGIL: kullanici ekrandan
      //    cikmis olsa bile temizlik TAMAMLANMALI. Servis await'ten ONCE
      //    yakalandigi icin `ref` erisimi guvenli.
      await aiSvc.gorselVazgec(mediaId);
      return;
    }
    if (!mounted) return;
    setState(() {
      _uretilenMediaId = mediaId;
      // ⚠️ Elle secilmis dosya varsa DUSURULUR: iki kaynak birden olursa
      //    `_kaydet` hangisini yollayacagini bilemez ve sessizce biri kaybolur.
      _gorseller.clear();
    });
  }

  /// ⚠️ AI ACIKLAMA — urunun fotografindan/adindan satis metni yazar.
  ///    Sonuc alana YAZILIR ama kullanici duzenleyebilir.
  Future<void> _aiAciklama() async {
    setState(() => _aiCalisiyor = true);
    // ⚠️ Servisler await'lerden ONCE (bkz. `_kaydet` serhi) — AI cagrisi uzun.
    final medyaSvc = ref.read(medyaServisiProvider);
    final aiSvc = ref.read(aiServisiProvider);
    try {
      var mediaId = '';
      if (_gorsel != null) {
        final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
        if (hazir != null) {
          mediaId = await medyaSvc.yukle(
            dosya: hazir,
            kind: 'image',
            mime: 'image/jpeg',
          );
        }
      }
      final metin = await aiSvc.urunMetni(
        mediaId: mediaId,
        metin: _ad.text.trim(),
      );
      if (!mounted) return;
      setState(() => _aciklama.text = metin);
      ref.invalidate(aiDurumProvider); // kota sayaci tazelenir (turu 77b)
    } catch (e) {
      // ⚠️ KOK MESSENGER: AI cagrisi uzun surer, ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _aiCalisiyor = false);
    }
  }

  Future<void> _kaydet() async {
    if (_ad.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ürün adı gerekli')));
      return;
    }
    setState(() => _kaydediliyor = true);
    // ⚠️⚠️ TURU 78b — SERVISLER **TUM AWAIT'LERDEN ONCE** (ayrinti icin
    //    `ilan_ekranlari.dart` `_kaydet` serhi). Kullanici fotograf yuklenirken
    //    geri basarsa `ref.read` `StateError` firlatir, catch yutar ve urun
    //    OLUSMAZ; medya yetim kalir.
    //    ⚠️ YAPMA: bu iki satiri await'lerin ALTINA tasima.
    final medyaSvc = ref.read(medyaServisiProvider);
    final urunSvc = ref.read(urunServisiProvider);
    try {
      final tl = double.tryParse(_fiyat.text.trim().replaceAll(',', '.')) ?? 0;
      final govde = <String, dynamic>{
        'ad': _ad.text.trim(),
        'aciklama': _aciklama.text.trim(),
        'bolum': _bolum.text.trim(),
        'fiyat_kurus': (tl * 100).round(),
        // TURU 89 - kategoriye ozel modul turu ve alanlari.
        // Sunucu `tur`u beyaz listeden gecirir; gecersizse 'urun'a duser.
        'tur': widget.modul.tur,
        'ozellikler': _ozellikler,
      };
      // ⚠️⚠️ TURU 77b — "TUKENDI" OLU OZELLIKTI (denetim bulgusu).
      //    Sunucu `durum` PATCH'ini beyaz listeyle KABUL EDIYORDU ve katalog
      //    "Tükendi" rozetini CIZIYORDU, ama istemci `durum` alanini
      //    **HICBIR YERDE GONDERMIYORDU** -> rozet sahada ASLA gorunmez,
      //    isletme urununu tukendi isaretleyemezdi. Bu, projede BES kez
      //    tekrarlayan "sutun eklendi, yazan yol yok" sinifinin yenisi.
      //    ⚠️ Yalniz DUZENLEMEDE gonderilir (yeni urun zaten 'yayinda' dogar).
      if (widget.urun != null) govde['durum'] = _durum;
      if (widget.urun == null) {
        final idler = <String>[];
        // ⚠️⚠️ TURU 79 — AI GORSELI ZATEN SUNUCUDA: yeniden YUKLENMEZ, id
        //    dogrudan baglanir. (Uretim yolunda baytlar OpenAI'dan SUNUCUYA
        //    gelip R2'ye orada yazildi; istemcide dosya HIC YOK.)
        if (_uretilenMediaId != null) {
          idler.add(_uretilenMediaId!);
        } else {
          // ⚠️⚠️ TURU 180o — **SIRA KORUNUR**: yuklemeler `Future.wait`
          //    ile paralel yapilsaydi donus sirasi AG HIZINA gore degisir ve
          //    kullanicinin sectigi ilk fotograf katalogda kapak olmayabilirdi
          //    (katalog + detay ikisi de `mediaIds.first`i kapak sayar).
          for (final dosya in _gorseller) {
            final hazir = await MedyaServisi.gorseliHazirla(dosya);
            if (hazir == null) throw Exception('Görsel hazırlanamadı');
            idler.add(
              await medyaSvc.yukle(
                dosya: hazir,
                kind: 'image',
                mime: 'image/jpeg',
              ),
            );
          }
        }
        govde['media_ids'] = idler;
        await urunSvc.ekle(govde);
      } else {
        // ⚠️ DUZENLEMEDE MEDYA DEGISMEZ (gonderi duzenlemesiyle ayni kural):
        //    medya degisecekse urun silinip yenisi eklenir.
        await urunSvc.guncelle(widget.urun!.id, govde);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      // ⚠️ KOK MESSENGER: kullanici kaydetme surerken ekrandan cikmis olabilir.
      if (mounted) setState(() => _kaydediliyor = false);
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ürün kaldırılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    // ⚠️ TURU 77b — try/catch YOKTU: ag hatasi/404 durumunda Future reddedilir
    //    (`onPressed` sonucu dusurur), ekran ACIK kalir ve HICBIR MESAJ
    //    CIKMAZDI — kullanici urunu sildigini sanardi.
    try {
      await ref.read(urunServisiProvider).sil(widget.urun!.id);
    } catch (_) {
      if (!mounted) return;
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Ürün kaldırılamadı')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.urun == null ? 'Ürün ekle' : 'Ürünü düzenle'),
        actions: [
          if (widget.urun != null)
            IconButton(icon: const Icon(LucideIcons.trash2), onPressed: _sil),
          // ⚠️⚠️ TURU 79b — URETIM SURERKEN **KAYDET KILITLI** (denetim bulgusu).
          //    Eskiden yalniz `_kaydediliyor`a bakiyordu: kullanici gorsel
          //    "Çiziliyor..." iken Kaydet'e basabiliyordu. Sonuc: urun
          //    FOTOGRAFSIZ kaydedilir, ekran kapanir, saniyeler sonra biten
          //    (ve PARASI ODENMIS) gorsel HICBIR YERE baglanmadan yetim kalir.
          //    ⚠️ `_aiCalisiyor` (AI aciklama) da ayni gerekceyle eklendi:
          //       yazilan metin alana ulasmadan ekran kapaniyordu.
          TextButton(
            onPressed: (_kaydediliyor || _gorselUretiliyor || _aiCalisiyor)
                ? null
                : _kaydet,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.urun == null)
            GestureDetector(
              onTap: _gorselSec,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  // ⚠️ TURU 79 — UC DURUM: (a) AI gorseli onaylandi -> SUNUCUDAN
                  //    ciz, (b) elle dosya secildi -> dosyadan ciz, (c) hicbiri.
                  //    (a) ve (b) AYNI ANDA olamaz (onay adiminda oteki dusuyor).
                  child: _uretilenMediaId != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: MedyaGorsel(
                            mediaId: _uretilenMediaId!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _gorsel == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.imagePlus, size: 28),
                              SizedBox(height: 6),
                              Text('Fotoğraf ekle'),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_gorsel!, fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
          // ⚠️⚠️ TURU 180o — SECILEN FOTOGRAFLARIN SERIDI.
          //    Ustteki 16:9 kutu KAPAGI (ilk fotograf) gosterir; serit
          //    digerlerini gorunur kilar ve TEK TEK kaldirma yolunu acar.
          // ⚠️ Serit YALNIZ dosya secilmisken cizilir: AI gorseli tek
          //    parcadir ve onun icin serit anlamsiz olurdu.
          if (widget.urun == null && _gorseller.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _gorseller.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, k) {
                  if (k == _gorseller.length) {
                    // ⚠️ Tavana ulasilinca ekleme karesi CIZILMEZ: dokunusa
                    //    cevap vermeyen bir kutu "bozuk" gorunurdu.
                    if (_gorseller.length >= _enFazlaFoto) {
                      return const SizedBox.shrink();
                    }
                    return GestureDetector(
                      onTap: _gorselSec,
                      child: Container(
                        width: 74,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.plus, size: 22),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _gorseller[k],
                          width: 74,
                          height: 74,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        // ⚠️⚠️ Dokunma kutusu 30 dp: turu 78b'de olculdu —
                        //    17x17'lik kaldirma dugmesi Material'in 48 dp
                        //    tabaninin cok altindaydi ve basilamiyordu.
                        child: GestureDetector(
                          onTap: () => setState(() => _gorseller.removeAt(k)),
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(3),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${_gorseller.length}/$_enFazlaFoto fotoğraf · ilki kapak olur',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
          // ---- ⚠️⚠️ TURU 79 — YAPAY ZEKA ILE GORSEL OLUSTUR
          //
          // Kullanici emri: "yapay zeka ile gorsel oluşturma nerede?" —
          // turu 77/78'de yalniz METIN uclari baglanmisti.
          //
          // ⚠️ YALNIZ YENI URUNDE ve YALNIZ `ai.gorsel` bayragi TRUE iken
          //    cizilir. `ai.acik` YETMEZ: anahtar var ama medya (R2) kapaliysa
          //    sunucu 503 doner ve dugme "var gorunup calismayan" olurdu.
          // ⚠️ Duzenlemede GIZLI: sunucu PATCH'te medyaya DOKUNMUYOR (mevcut
          //    davranis), yani uretilen gorsel kaydedilemezdi.
          if (widget.urun == null && (ai?.gorsel ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                // ⚠️⚠️ TURU 79b — HAK BITINCE DUGME **PASIF** ve SEBEP YAZILI
                //    (denetim bulgusu). Eskiden hak 0 olunca sayac etiketten
                //    TAMAMEN kayboluyor, dugme ise ETKIN kaliyordu: kullanici
                //    saglikli durumdan ayirt edemiyor, basiyor ve 429 aliyordu.
                //    Ayrica sayi artik KOSULSUZ yaziliyor — "(0)" gormek,
                //    hicbir sey gormemekten cok daha bilgilendirici.
                child: TextButton.icon(
                  onPressed:
                      (_gorselUretiliyor || (ai?.gorselKalan ?? 0) <= 0)
                      ? null
                      : _aiGorsel,
                  icon: _gorselUretiliyor
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.wandSparkles, size: 17),
                  label: Text(
                    _gorselUretiliyor
                        ? 'Çiziliyor...'
                        : (ai?.gorselKalan ?? 0) <= 0
                        ? 'Günlük görsel hakkın doldu'
                        : 'Yapay zekâ ile görsel oluştur (${ai!.gorselKalan})',
                  ),
                ),
              ),
            ),
          // ⚠️⚠️ TURU 77b — MEVCUT FOTOGRAF DUZENLEMEDE GORUNMUYORDU.
          //    Gorsel blogu tamamen `widget.urun == null` kapisi altindaydi;
          //    sahibi urununu acinca fotografini ne goruyor ne de oldugunu
          //    biliyordu -> "fotografim silindi" algisi. Sunucu PATCH'te
          //    medyaya DOKUNMUYOR (davranis dogru), eksik olan ILETISIMDI.
          if (widget.urun != null && widget.urun!.mediaIds.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: MedyaGorsel(
                  mediaId: widget.urun!.mediaIds.first,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Fotoğraf düzenlemede değiştirilemez. Değiştirmek için ürünü '
                'kaldırıp yeniden ekle.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
          // ⚠️ "Tükendi" anahtari — bkz. `_durum` ve `_kaydet` serhleri.
          if (widget.urun != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tükendi'),
              subtitle: const Text('Menüde "Tükendi" olarak görünür'),
              value: _durum == 'tukendi',
              onChanged: (v) =>
                  setState(() => _durum = v ? 'tukendi' : 'yayinda'),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _ad,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Ürün adı',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            controller: _aciklama,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              border: OutlineInputBorder(),
            ),
          ),
          // ⚠️ AI dugmesi YALNIZ sunucuda AI aciksa cizilir.
          if (ai?.acik ?? false)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _aiCalisiyor ? null : _aiAciklama,
                icon: _aiCalisiyor
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.sparkles, size: 17),
                label: Text(
                  _aiCalisiyor
                      ? 'Yazılıyor...'
                      : 'Yapay zekâ ile açıklama yaz'
                            '${ai != null && ai.kalan > 0 ? " (${ai.kalan})" : ""}',
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _bolum,
            maxLength: 60,
            decoration: InputDecoration(
              // TURU 89 - etiket KATEGORIYE gore (otelciye 'Ana Yemekler'
              //    ornegi gosterilmesi kullanicinin sikayetiydi).
              labelText: widget.modul.bolumEtiketi,
              border: const OutlineInputBorder(),
            ),
          ),
          // ⚠️⚠️⚠️ TURU 89 — KATEGORIYE OZEL ALANLAR (kullanici emri).
          //
          //	Otel -> kapasite / yatak / kahvaltı, doktor -> süre.
          //	Alan TANIMLARI **SUNUCUDAN** gelir; burada yalnizca ciziliyor.
          //	Boylece yeni bir alan eklemek ISTEMCI GUNCELLEMESI GEREKTIRMEZ
          //	(`ilan` tarafiyla ayni desen).
          //
          // ⚠️ `ValueKey` ZORUNLU: modul degisirse (kategori degistirildiginde)
          //    Flutter alan elemanlarini YENIDEN KULLANIR ve
          //    `FormField.didUpdateWidget` `initialValue` degisimini YOK
          //    SAYAR -> "Metrekare" kutusunda "Ford" kalir (turu 77b/78b
          //    HAYALET VERI hatasi).
          for (final a in widget.modul.alanlar) ...[
            if (a.tip == 'secim')
              Padding(
                key: ValueKey('sec:${widget.modul.tur}:${a.anahtar}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: _ozellikler[a.anahtar]?.isNotEmpty == true
                      ? _ozellikler[a.anahtar]
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: a.ad,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in a.secenekler)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => setState(() {
                    if (v == null) {
                      _ozellikler.remove(a.anahtar);
                    } else {
                      _ozellikler[a.anahtar] = v;
                    }
                  }),
                ),
              )
            else
              Padding(
                key: ValueKey('txt:${widget.modul.tur}:${a.anahtar}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  initialValue: _ozellikler[a.anahtar] ?? '',
                  keyboardType: a.tip == 'sayi'
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: a.birim.isEmpty ? a.ad : '${a.ad} (${a.birim})',
                    border: const OutlineInputBorder(),
                  ),
                  // ⚠️ `onChanged` — odak kaybi `onSubmitted` TETIKLEMEZ ve
                  //    kullanicinin yazdigi deger SESSIZCE ATILIRDI
                  //    (turu 85c'de elle koordinat girisinde tam bu yasandi).
                  onChanged: (v) {
                    final t = v.trim();
                    if (t.isEmpty) {
                      _ozellikler.remove(a.anahtar);
                    } else {
                      _ozellikler[a.anahtar] = t;
                    }
                  },
                ),
              ),
          ],
          TextField(
            controller: _fiyat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fiyat (TL)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_kaydediliyor)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// ⚠️ AI DANISMA — "fotograftan problemleri anlat" (kullanici emri).
///    Hamburger menuden acilir; isletme hesabi GEREKTIRMEZ.
class AiDanismaEkrani extends ConsumerStatefulWidget {
  const AiDanismaEkrani({super.key});

  @override
  ConsumerState<AiDanismaEkrani> createState() => _AiDanismaEkraniState();
}

class _AiDanismaEkraniState extends ConsumerState<AiDanismaEkrani> {
  final _not = TextEditingController();
  File? _gorsel;
  String _sonuc = '';
  bool _calisiyor = false;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _sec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.camera);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    // ⚠️⚠️ TURU 78b — GALERI YEDEGI DE AYNI KORUMAYI KULLANIR (denetim: bu
    //    cagri `pickerAcik` bayragini SET ETMIYOR ve `try/catch`SIZDI, yani
    //    ayni dosyadaki diger iki secicisiyle ASIMETRIKTI).
    //    `pickerAcik` bayragi, secici acikken gelen aramanin medya kapilarini
    //    dogru degerlendirmesi icin var; burada set edilmeyince kamera iptal
    //    edilip galeriye dusuldugunde bayrak YANLIS kaliyordu.
    if (x == null) {
      try {
        MedyaKapisi.pickerAcik = true;
        x = await ImagePicker().pickImage(source: ImageSource.gallery);
      } catch (_) {
        // secici acilamadi — asagidaki null kapisi devrali
      } finally {
        MedyaKapisi.pickerAcik = false;
      }
    }
    if (x == null || !mounted) return;
    setState(() => _gorsel = File(x!.path));
  }

  Future<void> _sor() async {
    if (_gorsel == null) return;
    setState(() {
      _calisiyor = true;
      _sonuc = '';
    });
    // ⚠️ Servisler await'lerden ONCE (bkz. `_kaydet` serhi) — AI cagrisi uzun.
    final medyaSvc = ref.read(medyaServisiProvider);
    final aiSvc = ref.read(aiServisiProvider);
    try {
      final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
      if (hazir == null) throw Exception('Görsel hazırlanamadı');
      final mediaId = await medyaSvc.yukle(
        dosya: hazir,
        kind: 'image',
        mime: 'image/jpeg',
      );
      final s = await aiSvc.danisma(
        mediaId: mediaId,
        metin: _not.text.trim(),
      );
      if (!mounted) return;
      setState(() => _sonuc = s);
      ref.invalidate(aiDurumProvider); // kota sayaci tazelenir (turu 77b)
    } catch (e) {
      // ⚠️ KOK MESSENGER: AI cagrisi uzun surer, ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Yapay zekâ danışman')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ⚠️ AI kapaliyken DURUST mesaj — dugme cizip 503 aldirmiyoruz.
          if (!(ai?.acik ?? false))
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Yapay zekâ şu anda kullanılamıyor.\n'
                  'Bu özellik yakında açılacak.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            const Text(
              'Bir fotoğraf çek, ne yapman gerektiğini anlatalım.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _sec,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _gorsel == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.camera, size: 30),
                              SizedBox(height: 6),
                              Text('Fotoğraf çek / seç'),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_gorsel!, fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _not,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Eklemek istediğin bilgi (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_gorsel == null || _calisiyor) ? null : _sor,
              icon: _calisiyor
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.sparkles, size: 18),
              label: Text(_calisiyor ? 'İnceleniyor...' : 'Sor'),
            ),
            if (_sonuc.isNotEmpty) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_sonuc, style: const TextStyle(fontSize: 15)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Yapay zekâ yanılabilir. Önemli konularda uzmana danış.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// Bekleme diyalogunun canliligini tutan kucuk kapi (bkz. `_beklemeAc` serhi).
///
/// ⚠️ Ayri bir SINIF olmasinin sebebi: `bool`u closure'da tutmak, kapatma
///    sorumlulugunu cagirana birakir ve turu 77b/78b'de tam bu yuzden iki ayri
///    yerde birbirinden bagimsiz (ve biri YANLIS) bayrak yonetimi olusmustu.
class _BeklemeKapisi {
  bool acik = true;

  /// Diyalog HALA aciksa kapatir. Kapali ise HICBIR SEY YAPMAZ.
  ///
  /// ⚠️ Bu kontrol olmadan `Navigator.pop()` EN USTTEKI route'u kapatir ve
  ///    diyalog zaten kapanmissa **CAGIRAN EKRANI** kapatir.
  void kapat(BuildContext context) {
    if (!acik) return;
    acik = false;
    Navigator.of(context).pop();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

// ⚠️ TURU 97 — 'bizim gri' TEK KAYNAK (kart yuzeyiyle ayni renk).
import '../isletme/isletme_kart.dart' show kYuzeyGri;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../router.dart' show rootMessengerKey;
import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'story_editor.dart';
import 'story_izleyici.dart';
import 'story_servisi.dart';

/// ⚠️⚠️ TURU 76b — ANASAYFADAKI HIKAYE SERIDI (kullanici emri: "story olayini
/// getirmemiz gerekiyor, anasayfada storyler").
///
/// ⚠️ SERIT HER ZAMAN CIZILIR (hikaye yoksa bile): en soldaki "Hikâyen" halkasi
///    kullanicinin ozelligin VARLIGINI ogrenmesinin TEK yolu. Bos gecmek, bu
///    projede defalarca yasanan "ozellik var ama kimse bulamiyor" hatasidir.
/// ⚠️ Halka RENKLI = izlenmemis, GRI = hepsi izlendi (Instagram).
/// ⚠️ YAPMA: seridi akisin icine `ListView` ogesi olarak koyma — akis
///    kaydirilinca serit de kaybolur; Instagram'da da kaybolur ama BIZDE akis
///    kendi `ListView`i oldugu icin serit ONUN ILK OGESI olmali (oyle yapildi).
class StorySeridi extends ConsumerStatefulWidget {
  const StorySeridi({super.key});

  @override
  ConsumerState<StorySeridi> createState() => StorySeridiDurumu();
}

/// ⚠️⚠️ `AutomaticKeepAliveClientMixin` ZORUNLU (turu 77b denetim bulgusu).
///
/// Serit, akis `ListView`inin `i == 0` OGESIDIR. `ListView`in
/// `addAutomaticKeepAlives: true` varsayilani TEK BASINA YETMEZ — cocugun
/// KeepAlive bildirimi GONDERMESI gerekir. Bildirmeyince serit 106px ve
/// varsayilan `cacheExtent` 250px oldugu icin kullanici akisi ~356px
/// kaydirdiginda State **DISPOSE OLUYORDU**:
///   · suren hikaye yuklemesi yarida kesiliyordu (bkz. `_paylas` serhi),
///   · yukleme ilerleme halkasi kayboluyordu,
///   · geri kaydirinca serit sifirdan yeniden yukleniyordu (gereksiz istek).
/// ⚠️ YAPMA: `wantKeepAlive`i false yapma veya `super.build(context)` cagrisini
///    silme (mixin bunu SART kosar).
class StorySeridiDurumu extends ConsumerState<StorySeridi>
    with AutomaticKeepAliveClientMixin {
  List<StoryKullanici>? _liste;
  bool _yukleniyor = false;
  double? _ilerleme;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    yukle();
  }

  Future<void> yukle() async {
    try {
      final l = await ref.read(storyServisiProvider).serit();
      if (mounted) setState(() => _liste = l);
    } catch (_) {
      // ⚠️ Sessiz: hikaye seridi akisi BLOKLAMAZ. Hata durumunda yalniz
      //    "Hikâyen" halkasi cizilir (asagidaki `_benimHalka`).
      if (mounted) setState(() => _liste = const []);
    }
  }

  /// ⚠️⚠️ KOK `scaffoldMessengerKey` KULLANILIR, `ScaffoldMessenger.of(context)`
  ///    DEGIL (turu 77b denetim bulgusu).
  ///
  /// **NEDEN:** serit bir `ListView` OGESIDIR ve `AutomaticKeepAliveClientMixin`
  /// kullanmaz -> kullanici akisi ~356px kaydirinca State **dispose olur**.
  /// Yukleme surerken bu olursa `context` olur ve hata mesaji HIC gorunmezdi —
  /// tam da "paylastim sandim ama gitmemis" sikayeti. Kok messenger widget'in
  /// omrunden BAGIMSIZDIR, mesaj her halukarda gorunur.
  /// ⚠️ YAPMA: buray... `ScaffoldMessenger.of(context)`e dondurme.
  void _uyar(String m) {
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(m)),
    );
  }

  /// Hikaye paylas: medya sec -> **EDITOR** -> yukle -> POST /stories.
  ///
  /// ⚠️⚠️ TURU 77 — ARAYA EDITOR GIRDI (kullanici emri: "storyde AA gibi, renk
  ///    gibi, yazi tipi gibi ne varsa olacak"). Editor IPTAL edilirse hicbir sey
  ///    YUKLENMEZ — once editor, sonra yukleme. Tersi yapilsaydi kullanici
  ///    vazgectiginde bosuna 100 MB yuklenmis olurdu.
  /// ⚠️ FOTOGRAF: EXIF (KONUM) TEMIZLIGI ZORUNLU — sunucu GPS bulursa 422 doner.
  /// ⚠️ VIDEO: HAM gider (gonderi/kanal tarafiyla ayni davranis).
  /// ⚠️ Metin goruntuye PISIRILMEZ, meta veri gider (bkz. migration 027).
  /// ⚠️ Hata YUTULMAZ: "paylastim sandim ama gitmemis" bu projenin tekrarlayan
  ///    sikayeti.
  Future<void> _paylas({required bool video}) async {
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez');
      return;
    }
    // ⚠️⚠️ SEVK ENGELIYDI (turu 77b denetim bulgusu) — SERVISLER **TUM
    //    AWAIT'LERDEN ONCE** YAKALANIR.
    //
    // ZINCIR: serit bir `ListView` OGESIDIR (akis_ekrani i==0) ve
    // `AutomaticKeepAliveClientMixin` KULLANMAZ -> serit 106px, varsayilan
    // `cacheExtent` 250px, yani kullanici akisi ~356px kaydirinca State
    // **DISPOSE OLUR**. Disposed `ConsumerState`te `ref.read` `StateError`
    // firlatir; asagidaki `catch (e)` onu yakalar, `if (!mounted) return;`
    // ile de **HICBIR MESAJ GOSTERILMEZ**.
    // SONUC: medya R2'ye yuklenir, `POST /stories` **HIC ATILMAZ**, medya
    // `status='aktif'` takili kalir (yetim), kullanici ne hikayeyi ne hatayi
    // gorur. 100 MB videoda bu pencere ONLARCA SANIYEDIR.
    // Bu, dosyanin kendi serhinin ("paylastim sandim ama gitmemis") tam olarak
    // engellemeye calistigi senaryonun kendisiydi.
    // 📌 CLAUDE.md turu 67 dersinin birebir tekrari: `_notifier`/`_ctrl`
    //    orada da `initState`te yakalanmisti.
    // ⚠️ YAPMA: bu iki satiri await'lerin ALTINA tasima.
    final medyaSvc = ref.read(medyaServisiProvider);
    final storySvc = ref.read(storyServisiProvider);

    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = video
          ? await ImagePicker().pickVideo(source: ImageSource.gallery)
          : await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;

    var dosya = File(x.path);
    if (video) {
      final bayt = await dosya.length();
      if (!mounted) return;
      final tavan = kTavanlar['video'] ?? (100 << 20);
      if (bayt > tavan) {
        _uyar('Video çok büyük (en fazla ${(tavan / (1 << 20)).round()} MB)');
        return;
      }
    }

    // ---- EDITOR (yazi/renk/boyut). Iptal edilirse YUKLEME YOK.
    final cikti = await Navigator.of(context).push<StoryCikti>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StoryEditor(dosya: dosya, video: video),
      ),
    );
    if (cikti == null || !mounted) return;

    setState(() {
      _yukleniyor = true;
      _ilerleme = 0;
    });
    try {
      if (!video) {
        final hazir = await MedyaServisi.gorseliHazirla(dosya);
        if (hazir == null) throw Exception('Fotoğraf hazırlanamadı');
        dosya = hazir;
      }
      final mediaId = await medyaSvc.yukle(
        dosya: dosya,
        kind: video ? 'video' : 'image',
        mime: video ? 'video/mp4' : 'image/jpeg',
        fileName: x.name,
        ilerleme: (p) {
          if (mounted) setState(() => _ilerleme = p);
        },
      );
      await storySvc.paylas(
        mediaId: mediaId,
        kind: video ? 'video' : 'image',
        katmanlar: cikti.katmanlar,
      );
      // ⚠️ Buradan sonrasi SADECE ARAYUZ tazelemesi. Serit kaydirilip dispose
      //    olsa bile hikaye SUNUCUDA OLUSMUSTUR ve mesaj kok messenger'dan
      //    gorunur (bkz. `_uyar` serhi).
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _ilerleme = null;
        });
        await yukle();
      }
      _uyar('Hikâyen paylaşıldı');
    } catch (e) {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _ilerleme = null;
        });
      }
      final d = e is DioException ? e.response?.data : null;
      _uyar(
        (d is Map && d['error'] is String)
            ? d['error'] as String
            : 'Hikâye paylaşılamadı',
      );
    }
  }

  /// ⚠️ TURU 77 — SADECE METIN hikayesi (Instagram deseni): medya YOK, gradyan
  ///    zemin + yazi. Medya yuklemesi HIC yapilmaz -> aninda paylasilir.
  Future<void> _metinHikayesi() async {
    final cikti = await Navigator.of(context).push<StoryCikti>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const StoryEditor(metinHikayesi: true),
      ),
    );
    if (cikti == null || !mounted) return;
    setState(() => _yukleniyor = true);
    try {
      await ref
          .read(storyServisiProvider)
          .paylas(
            mediaId: '',
            kind: 'metin',
            katmanlar: cikti.katmanlar,
            arkaPlan: cikti.arkaPlan,
          );
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      await yukle();
      if (mounted) _uyar('Hikâyen paylaşıldı');
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      final d = e is DioException ? e.response?.data : null;
      _uyar(
        (d is Map && d['error'] is String)
            ? d['error'] as String
            : 'Hikâye paylaşılamadı',
      );
    }
  }

  Future<void> _paylasSecenek() async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Fotoğraf'),
              onTap: () => Navigator.pop(c, 'foto'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.video),
              title: const Text('Video'),
              onTap: () => Navigator.pop(c, 'video'),
            ),
            // ⚠️ TURU 77: medyasiz metin hikayesi — Instagram'daki "Oluştur".
            ListTile(
              leading: const Icon(LucideIcons.type),
              title: const Text('Yazı'),
              subtitle: const Text('Renkli zemin üzerine yaz'),
              onTap: () => Navigator.pop(c, 'metin'),
            ),
          ],
        ),
      ),
    );
    if (secim == null || !mounted) return;
    if (secim == 'metin') {
      await _metinHikayesi();
    } else {
      await _paylas(video: secim == 'video');
    }
  }

  Future<void> _ac(StoryKullanici k) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryIzleyici(
          kullanici: k,
          // ⚠️⚠️ TURU 82 — GERI CAGIRIM YALNIZCA MODELI GUNCELLER, `setState`
          //    CAGIRMAZ. Sebep YAPISAL: bu geri cagirim artik iki yerden gelir
          //    — (a) `_sonraki()` liste bitince, (b) izleyicinin `dispose()`i
          //    (geri tusu / X / asagi kaydirma ile cikis). (b) yolunda cocuk
          //    route AGACTAN SOKULURKEN, yani cerceve BUILD FAZINDA olabilir;
          //    orada BASKA bir State'in `setState`ini tetiklemek Flutter'da
          //    *"setState() or markNeedsBuild() called during build"*
          //    ASSERTION'ini firlatir.
          // ⚠️ Cizim ZATEN garanti: asagidaki `await` donunce var olan
          //    `if (mounted) setState(() {});` seridi yeniden cizer.
          // ⚠️ YAPMA: buraya `setState` geri koyma.
          onIzlendi: () => k.hepsiIzlendi = true,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ⚠️ AutomaticKeepAliveClientMixin SART kosar.
    final l = _liste;
    final benimProfil = ref.watch(myProfileProvider).valueOrNull;
    final benim = l?.where((e) => e.benim).firstOrNull;
    final digerleri = (l ?? const <StoryKullanici>[])
        .where((e) => !e.benim)
        .toList();

    return SizedBox(
      // ⚠️ TURU 82 — 106 -> 116. Olcum: cember 69 + bosluk 5 + etiket satiri +
      //    ListView dikey dolgusu 16. Etiket 11px'te ~14dp, ama YAZI OLCEGI
      //    1.3'te ~18dp -> gereken 108 > 106 ve `Column` sari-siyah TASMA
      //    SERIDI ciziyordu (turun konusu "serit duzgun gorunsun" oldugu icin
      //    onceden beri var olan bu hata da kapatildi). 116, olcek ~1.6'ya
      //    kadar pay birakir.
      // ⚠️ YAPMA: 106'ya geri dusurme.
      // ⚠️⚠️ TURU 97 — etiket satiri kaldirilinca serit kisaldi: 116 -> **90**.
      //	⚠️ ILK DENEME **78** IDI ve emulatorde *"BOTTOM OVERFLOWED BY 11
      //	PIXELS"* verdi: halka 60 + cember kenarligi/dolgusu (~9) + kose '+'
      //	rozetinin tastigi (~2) + seridin dikey dolgusu hesaba katilmamisti.
      //	OLCULEN gereksinim 89 dp; 90 yazildi (1 dp pay).
      // ⚠️ YAPMA: bu sayiyi 'daha derli toplu dursun' diye tahminle dusurme;
      //    tasma sessiz DEGIL ama yalniz debug derlemede gorunur.
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        // ⚠️ TURU 82 — yatay 10 -> 12: serit ve gonderi kartlari AYNI dikey
        //    cizgiden baslasin. Kart icerigi 12dp dolguyla basliyor (medya,
        //    metin, etkilesim cubugu); serit 10'da kaldigi surece hikaye
        //    halkalari kartlardan 2dp SOLDA duruyor ve goz bunu hizasizlik
        //    olarak okuyor.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _benimHalka(benim, benimProfil),
          for (final k in digerleri) _halka(k),
        ],
      ),
    );
  }

  /// En soldaki "Hikâyen" halkasi.
  /// ⚠️ Kendi hikayem VARSA: dokun -> IZLE, kose "+" -> yeni ekle.
  ///    YOKSA: dokun -> paylas.
  Widget _benimHalka(StoryKullanici? benim, Map<String, dynamic>? profil) {
    final ad = (profil?['name'] ?? '').toString();
    return _kutu(
      etiket: 'Hikâyen',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: _yukleniyor
                ? null
                : (benim != null ? () => _ac(benim) : _paylasSecenek),
            child: _cember(
              halka: benim != null && !benim.hepsiIzlendi,
              gri: benim != null && benim.hepsiIzlendi,
              // ⚠️⚠️⚠️ TURU 97 — FOTOGRAF YOKSA **HARF DEGIL DUZ GRI DAIRE**
              //	(kullanici emri: *"A yazmasin, bos olsun, gri bizim gri
              //	renk olsun"*). Alt menudeki profil dairesiyle AYNI dil.
              // ⚠️ Etiket de kaldirildigi icin (asagida) harf tek basina
              //    zaten hicbir sey anlatmiyordu.
              child: _benimAvatar(ad, profil),
            ),
          ),
          if (_yukleniyor)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      value: _ilerleme,
                    ),
                  ),
                ),
              ),
            )
          else
            // ⚠️⚠️⚠️ TURU 97c — '+' ROZETI **DAIRENIN KENARINA** oturur
            //	(kullanici: *"+ daire storynin disina kalmis"*).
            //
            //	OLCU (hesaplandi): `_cember` iki ic ice `Container`dir —
            //	dis dolgu 2.5 + ic dolgu 2 = **4.5 dp**; yani `Stack` kutusu
            //	60 + 9 = **69 dp**, gorunen daire ise ortadaki **60 dp**.
            //	Eski deger (-2) rozetin MERKEZINI kutunun disina, daire
            //	merkezinden **38 dp** uzaga koyuyordu — daire yaricapi 30,
            //	yani rozet daireden **8 dp KOPUKTU**.
            //	Dairenin 45 derecelik kenar noktasi merkezden 30 dp uzakta:
            //	  kenar = 34.5 + 30*0.707 = 55.7  ->  rozet (19 dp) sol/ust
            //	  kosesi 46.2  ->  sag/alt bosluk = 69 - 46.2 - 19 = **3.8**
            // ⚠️ YAPMA: negatif degere dondurme; rozet daireden kopar.
            Positioned(
              right: 4,
              bottom: 4,
              child: GestureDetector(
                onTap: _paylasSecenek,
                child: Container(
                  decoration: BoxDecoration(
                    // ⚠️ TURU 97 — kullanici emri: **SIYAH** (yesil vurgu
                    //    degil). Alt menunun siyahiyla ayni dil.
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(
                    LucideIcons.plus,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _halka(StoryKullanici k) => _kutu(
    etiket: k.ad.isEmpty ? '@${k.kullaniciAdi}' : k.ad,
    child: GestureDetector(
      onTap: () => _ac(k),
      child: _cember(
        halka: !k.hepsiIzlendi,
        gri: k.hepsiIzlendi,
        child: Avatar(ad: k.ad, mediaId: k.avatarMediaId, cap: 60),
      ),
    ),
  );

  /// Fotograf varsa avatar, yoksa **duz gri daire** (turu 97).
  Widget _benimAvatar(String ad, Map<String, dynamic>? profil) {
    final mediaId = profil?['avatar_media_id'] as String?;
    final url = (profil?['avatar_url'] ?? '').toString();
    final fotografVar = (mediaId != null && mediaId.isNotEmpty) || url.isNotEmpty;
    if (!fotografVar) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kYuzeyGri(context),
        ),
      );
    }
    return Avatar(ad: ad, mediaId: mediaId, avatarUrl: url, cap: 60);
  }

  Widget _kutu({required String etiket, required Widget child}) => SizedBox(
    // ⚠️ TURU 82 — kullanici: *"storyler arasinda bosluk cok az"*.
    //    Halka capi 60 + 2.5 + 2 dolgu = ~69dp; 74 genislikte aradaki bosluk
    //    yalnizca ~5dp kaliyordu. 84 -> ~15dp (Instagram'la ayni his).
    // ⚠️ YAPMA: 74'e geri dusurme.
    width: 84,
    // ⚠️⚠️⚠️ TURU 97 — **HIKAYE ETIKETLERI KALDIRILDI** (kullanici emri:
    //	*"hikayen yazmasin, bir sey yazmasin"*). Halkanin altinda artik hicbir
    //	yazi yok; serit yalniz dairelerden olusuyor.
    //
    // ⚠️ `etiket` parametresi **DURUYOR** ve `Semantics`e verilir: gorunur
    //    yazisi olmayan bir daire ekran okuyucuda "resim" diye okunur ve
    //    TalkBack kullanicisi kimin hikayesi oldugunu ANLAYAMAZ (alt menude
    //    de ayni karar verildi — turu 96m).
    // ⚠️ YAPMA: `etiket`i "kullanilmiyor" diye silme.
    // ⚠️⚠️ `Column(mainAxisSize.min)` ZORUNLU — etiket kalksa bile.
    //	Ilk denemede cocuk DOGRUDAN verilmisti ve serit ozeti soyle bozuldu:
    //	`SizedBox`in yuksekligi YOK, yani cocuk seridin TAM YUKSEKLIGINE
    //	yayiliyor; halkanin kose '+' rozeti `Positioned(bottom: -2)` ile
    //	konumlandigi icin rozet DAIRENIN degil SERIDIN dibine dusuyordu
    //	(ekranda daireden kopuk duruyordu).
    // ⚠️ YAPMA: bu Column'u kaldirip cocugu dogrudan verme.
    child: Semantics(
      label: etiket,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [child],
      ),
    ),
  );

  /// Halka: RENKLI (izlenmemis) / GRI (izlenmis) / YOK (hikaye yok).
  Widget _cember({
    required bool halka,
    required bool gri,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(2.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: halka
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B3FFF), Color(0xFFFF3B5C), Color(0xFFFFB03A)],
            )
          : null,
      border: halka
          ? null
          : Border.all(
              color: gri
                  ? Colors.grey.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
    ),
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: child,
    ),
  );
}

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

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
import 'demo_veri.dart';
// ⚠️ Sayi bicimleme TEK KAYNAK (akis kartiyla ayni dil: '12,3 bin').
import 'gonderi_karti.dart' show sayiBicimle;
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
      if (!mounted) return;
      // ⚠️⚠️⚠️ TURU 113 (denetim, YUKSEK) — **GERCEK HIKAYE DEMONUN ALTINDA
      //	KAYBOLUYORDU.**
      //
      //	Onceden `kDemoAkis` dali fonksiyonun BASINDA kisa devre yapiyor ve
      //	seridi TAMAMEN demo veriyle eziyordu. `_paylas()` sunucuya yazip
      //	`await yukle()` cagirdigi icin kullanici *"Hikâyen paylaşıldı"*
      //	mesajini goruyor, ama serit HIC degismiyordu; kendi halkasina
      //	dokununca da *"tasarim demosu"* uyarisi cikiyordu. Bu, dosyanin
      //	kendi serhinin onlemeye calistigi *"paylastim sandim, gitmemis"*
      //	senaryosunun ta kendisiydi.
      //
      // ⚠️ COZUM: demo acikken de SUNUCU CEVABI once alinir; **kullanicinin
      //    KENDI gercek hikayesi varsa o KORUNUR**, demo kullanicilari
      //    yalnizca ARKASINA eklenir.
      // ⚠️ YAPMA: demo dalini tekrar fonksiyonun basina alma.
      if (kDemoAkis) {
        final benim = l.where((k) => k.benim).toList();
        final demo = demoStoryler().where((k) => !k.benim || benim.isEmpty);
        setState(() => _liste = [...benim, ...demo]);
        return;
      }
      setState(() => _liste = l);
    } catch (_) {
      // ⚠️ Sessiz: hikaye seridi akisi BLOKLAMAZ. Hata durumunda yalniz
      //    "Hikâyen" halkasi cizilir (asagidaki `_benimHalka`).
      // ⚠️ Demo acikken ag hatasinda da demo serit cizilir (tasarim
      //    incelemesi ag olmadan da yapilabilsin).
      if (mounted) {
        setState(() => _liste = kDemoAkis ? demoStoryler() : const []);
      }
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
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));
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
    // ⚠️ TURU 98c — demo hikayesi sunucuda YOK; izleyici bos acilirdi.
    if (demoKimlik(k.userId)) {
      _uyar('Bu bir tasarım demosu — gerçek içerik değil');
      return;
    }
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
      // ⚠️⚠️⚠️ TURU 97d — YUKSEKLIK **TURETILIR, ELLE YAZILMAZ**.
      //
      //	Gecmis: 116 (etiketliyken) -> 78 (etiket kalkti; **emulatorde
      //	'BOTTOM OVERFLOWED BY 11 PIXELS' verdi**) -> 90. Her seferinde
      //	sayi TAHMIN edildigi icin bir kez tasti. Artik formul:
      //	  halka capi
      //	  + ic dolgu 2x2   = 4
      //	  + dis dolgu 2x2.5 = 5
      //	  + **KENARLIK 2x2 = 4**  <- ILK FORMULDE UNUTULDU
      //	  + seridin dikey dolgusu (2 x `kDikey`)
      //
      // ⚠️⚠️ Kenarlik (`Border.all(width: 2)`) kutuyu BUYUTUR; ilk formul
      //	onu saymadigi icin emulatorde *"RenderFlex overflowed by 2.0
      //	pixels"* verdi. **Olcup duzeltildi** — tahminle degil.
      // ⚠️ Kullanici *"ust ve alttan boslugu biraz azalt"* dedi: dikey
      //    dolgu 8 -> **4**. Halka 10 dp buyudu ama serit yalnizca 1 dp
      //    uzadi (90 -> 91).
      height: kHalkaCap + 13 + kDikey * 2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        // ⚠️ TURU 82 — yatay 10 -> 12: serit ve gonderi kartlari AYNI dikey
        //    cizgiden baslasin. Kart icerigi 12dp dolguyla basliyor (medya,
        //    metin, etkilesim cubugu); serit 10'da kaldigi surece hikaye
        //    halkalari kartlardan 2dp SOLDA duruyor ve goz bunu hizasizlik
        //    olarak okuyor.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: kDikey),
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
      // ⚠️⚠️⚠️ TURU 98g — HALKASIZ TILE **HALKA PAYINI AYIRMAZ** (olculdu).
      //	Kutu herkes icin `cap + 9(halka) + 9(aralik)` idi; bu dairede halka
      //	CIZILMEDIGI icin o 9 dp bos kaliyor ve komsusuyla arasi **13 dp**
      //	olcultuyordu (kardeslerinde 9). Halka yoksa pay da ayrilmaz.
      // ⚠️ TURU 113 — genislik override'i KALDIRILDI: paylasma dairesi
      //    artik halkali oldugu icin kutusu da kardesleriyle AYNI
      //    (`kHalkaCap + 9 + kAralik`). Dar birakilsaydi ilk daire ile
      //    ikincisi arasindaki bosluk 9 dp EKSIK kalirdi.
      etiket: 'Hikâyen',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: _yukleniyor
                ? null
                : (benim != null ? () => _ac(benim) : _paylasSecenek),
            // ⚠️⚠️⚠️ TURU 98f — HALKASIZ HALDE **CEMBER SARMALI YOK**
            //	(kullanici: *"story ekleme dairesi digerleriyle AYNI
            //	buyuklukte olsun"*).
            //	 4.5 dp dolgu ekler; halka CIZILMEDIGINDE o dolgu
            //	SAYDAM kalir ve gorunen daire kardeslerinden **9 dp KUCUK**
            //	cikardi. Hikayesi olmayan kullanici daireyi dolgu kadar
            //	BUYUK cizer; ikisinin DIS capi artik esit.
            // ⚠️ YAPMA: halkasiz dali tekrar  icine alma.
            // ⚠️⚠️ TURU 98g — HALKASIZ DALDA DA `_cember` KULLANILIR:
            //	boylece GRI DISK her yerde `kHalkaCap`, DIS KUTU her yerde
            //	`kHalkaCap + 9` olur. 98fde disk 79ye cikarilmisti; o zaman
            //	bu daire kardeslerinin DISKINDEN buyuk gorunuyordu.
            // ⚠️⚠️⚠️ TURU 113 — **PAYLASMA DAIRESI ARTIK HALKALI** (kullanici
            //	emri: *"story paylasma dairesi, story paylasilan daire ve
            //	border buyuklugunde olsun ... border siyah mor gradient
            //	olacak"*).
            //
            // ⚠️ Eski halde `halka: false` idi ve kenarlik `transparent`
            //    ciziliyordu: 4.5 dp'lik dolgu SAYDAM kaldigi icin gorunen
            //    daire kardeslerinden **9 dp kucuk** duruyordu. Artik halka
            //    GERCEKTEN cizilir, dis cap kardesleriyle BIREBIR ayni.
            // ⚠️ Hikaye paylasildiktan sonra (`benim != null`) gorunum
            //    DEGISMEZ — kullanici *"paylasildiginda su anki gibi olsun"*
            //    dedi; o dal AYNEN duruyor.
            child: benim == null
                ? _cember(
                    halka: true,
                    gri: false,
                    gradyan: const [Color(0xFF14101C), Color(0xFF8B3FFF)],
                    child: _benimAvatar(ad, profil, kHalkaCap),
                  )
                : _cember(
                    halka: !benim.hepsiIzlendi,
                    gri: benim.hepsiIzlendi,
                    // ⚠️⚠️⚠️ TURU 97 — FOTOGRAF YOKSA **HARF DEGIL DUZ GRI DAIRE**
                    //	(kullanici emri: *"A yazmasin, bos olsun, gri bizim gri
                    //	renk olsun"*). Alt menudeki profil dairesiyle AYNI dil.
                    // ⚠️ Etiket de kaldirildigi icin (asagida) harf tek basina
                    //    zaten hicbir sey anlatmiyordu.
                    child: _benimAvatar(ad, profil, kHalkaCap),
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

  /// ⚠️⚠️ TURU 97d — HALKA CAPI **60 -> 70** (kullanici emri: *"story daire
  ///	10px daha buyut"*). TEK SABIT: uc cizim yeri de bunu okur (kendi
  ///	halkam · baskasinin halkasi · fotografsiz gri daire). Uc yere ayri
  ///	sayi yazilsaydi biri guncellenip otekiler geride kalirdi.
  /// ⚠️ TURU 98e — 70 -> **74** (kullanici: *"story paylasma dairesini
  ///    4px daha buyut, digerleri de AYNI buyuklukte olsun"*). Tek sabit
  ///    oldugu icin kendi halkam · baskasinin halkasi · kapsuldeki iki
  ///    daire HEPSI birlikte buyur.
  static const double kHalkaCap = 65;

  /// Seridin ust/alt boslugu (kullanici emri: *"biraz daha azalt"*): 8 -> 4.
  static const double kDikey = 4;

  /// Halkalar arasi bosluk — TEK SABIT (normal daire + kapsul ayni deger).
  static const double kAralik = 9;

  /// ⚠️⚠️⚠️ TURU 98b — HALKA **YAYIN DURUMUNU** GOSTERIR (kullanici emri:
  ///	*"canli yayin KIRMIZI, sesli oda MOR olsun, ikon koy"*).
  ///
  /// ⚠️ Renk TEK BASINA yetmez (renk korlugu): durum ayrica **IKONLU BIR
  ///    ROZETLE** yazilir — canli icin `radio`, oda icin `mic`.
  Widget _halka(StoryKullanici k) {
    final yayin = demoYayin(k.userId);
    final durum = yayin?.durum;
    final renk = durum == 'canli'
        ? const Color(0xFFFF3B30)
        : durum == 'oda'
        ? const Color(0xFF8B3FFF)
        : null;
    // ⚠️⚠️⚠️ TURU 98k — YAYIN/ODA OGESI **TEK PROFIL** (kullanici emri:
    //	*"tekli yapalim, kim actiysa canli yayini/odayi onun resmi olsun,
    //	ikinciyi kaldir"*).
    //
    // ⚠️ 98c-98j arasinda burada IKI avatarlik bir KAPSUL vardi (Threads
    //    referansi). Kullanici sahada gorup reddetti: oge artik kardes
    //    hikaye daireleriyle AYNI daire, farki YALNIZ halka rengi ve
    //    ustundeki iki rozet.
    // ⚠️ YAPMA: kapsul/ikinci avatar geri getirme.
    return _kutu(
      etiket: k.ad.isEmpty ? '@${k.kullaniciAdi}' : k.ad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => _ac(k),
            child: _cember(
              halka: durum == null && !k.hepsiIzlendi,
              gri: durum == null && k.hepsiIzlendi,
              duzRenk: renk,
              child: _seritAvatar(k.ad, k.avatarMediaId, kHalkaCap),
            ),
          ),
          // ⚠️ IZLEYICI SAYISI (sag ust) — yalniz canli/odada.
          if (yayin != null && renk != null)
            Positioned(
              // ⚠️ TURU 98k — rozet dairenin TAM USTUNDE ORTALI (kullanici:
              //    *"sayilar tam orada olsun, hafif sagda duruyor"*).
              //    `right: 6` kutunun sagina yaslıyordu; kutu daireden 9 dp
              //    genis oldugu icin rozet saga kaciyordu.
              left: 0,
              right: 0,
              top: -4,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: renk,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    sayiBicimle(yayin.izleyici),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          if (durum != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: -6,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: renk,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        durum == 'canli' ? LucideIcons.radio : LucideIcons.mic,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        durum == 'canli' ? 'CANLI' : 'ODA',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
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
  }

  /// ⚠️⚠️⚠️ TURU 98d — SERITTE **HARF YOK** (kullanici emri: *"harf
  ///	olmayacak"*, ayrica turu 97'de kendi halkam icin de ayni sey
  ///	istenmisti: *"A yazmasin, bos gri daire olsun"*).
  ///
  ///	`Avatar` fotograf yokken bas harfli renkli bir daire cizer; serit
  ///	yazisiz bir dil kullandigi icin (etiketler turu 97'de kaldirildi) harf
  ///	tek basina hicbir sey anlatmiyor, ustelik kendi halkamla DIGERLERI
  ///	arasinda gorunum farki yaratiyordu.
  /// ⚠️ TEK KAYNAK: hem halka hem kapsul hem kendi halkam bunu kullanir.
  /// ⚠️ YAPMA: cagri yerlerine tekrar ciplak `Avatar` koyma.
  Widget _seritAvatar(String ad, String? mediaId, double cap) {
    final fotografVar = mediaId != null && mediaId.isNotEmpty;
    if (!fotografVar) {
      return Container(
        width: cap,
        height: cap,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kYuzeyGri(context),
        ),
      );
    }
    return Avatar(ad: ad, mediaId: mediaId, cap: cap);
  }

  /// Fotograf varsa avatar, yoksa **duz gri daire** (turu 97).
  Widget _benimAvatar(String ad, Map<String, dynamic>? profil, double cap) {
    final mediaId = profil?['avatar_media_id'] as String?;
    final url = (profil?['avatar_url'] ?? '').toString();
    final fotografVar =
        (mediaId != null && mediaId.isNotEmpty) || url.isNotEmpty;
    if (!fotografVar) {
      return Container(
        width: cap,
        height: cap,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kYuzeyGri(context),
        ),
      );
    }
    return Avatar(ad: ad, mediaId: mediaId, avatarUrl: url, cap: cap);
  }

  /// [genislik] verilmezse DAIRE olcusu kullanilir; kapsul (canli/oda) ogesi
  /// daha genis oldugu icin kendi olcusunu gecirir.
  Widget _kutu({
    required String etiket,
    required Widget child,
    double? genislik,
  }) => SizedBox(
    // ⚠️⚠️ TURU 97d — GENISLIK DE **TURETILIR**: halka capi + cember dolgusu
    //	(9) + halkalar arasi bosluk (**15**, turu 82'de kullanicinin istedigi
    //	'Instagram hissi'). Halka 60 -> 70 buyuyunce bu sayi elle
    //	guncellenmeseydi kutu 84'te kalir ve halkalar birbirine YAPISIRDI
    //	(70 + 9 = 79, geriye 5 dp kalirdi — tam da turu 82'de sikayet edilen
    //	durum).
    // ⚠️ YAPMA: buraya sabit sayi yazma.
    // ⚠️ TURU 98e — halkalar arasi bosluk **15 -> 11** (kullanici: *"aralarindaki
    //    boslugu bir tik azalt"*). Daire 4 dp buyudugu icin toplam kutu
    //    genisligi degismez, yalniz nefes payi kisilir.
    width: genislik ?? (kHalkaCap + 9 + kAralik),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
    ),
  );

  /// Halka: RENKLI (izlenmemis) / GRI (izlenmis) / YOK (hikaye yok).
  /// [duzRenk] verilirse halka GRADYAN degil O RENKTE cizilir (canli/oda).
  /// ⚠️ [gradyan] verilmezse HIKAYE halkasi (mor-kirmizi-turuncu) cizilir.
  ///    Paylasma dairesi kendi SIYAH-MOR gradyanini gecer (kullanici emri).
  Widget _cember({
    required bool halka,
    required bool gri,
    required Widget child,
    Color? duzRenk,
    List<Color>? gradyan,
  }) => Container(
    padding: const EdgeInsets.all(2.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: duzRenk,
      gradient: halka
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // ⚠️ TURU 117 — renkler `core/theme.dart` icindeki
              //    `kHikayeHalkaGradient` sabitinden gelir (TEK KAYNAK);
              //    alt menudeki logo halkasi da AYNI sabiti okur.
              colors: gradyan ?? kHikayeHalkaGradient,
            )
          : null,
      border: (halka || duzRenk != null)
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

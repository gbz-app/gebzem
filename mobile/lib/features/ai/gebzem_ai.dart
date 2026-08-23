library;

import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart' show morLogo;
import '../home/home_screen.dart' show myProfileProvider;
import '../../router.dart' show rootMessengerKey;
import '../isletme/isletme_kart.dart' show kYanBosluk, kYaricap;
import '../isletme/urun_servisi.dart';
import '../medya/medya_kapisi.dart';
import '../medya/ses_notu_kaydedici.dart';
import '../medya/medya_servisi.dart';

/// ⚠️⚠️⚠️ TURU 127 — **DONEN ORNEK SORULAR** (kullanici emri: *"hangi
///	konuda yardimci olabilirim 30 px altina Gebze'nin en iyi kebapcisi ya
///	da hava durumu gibi Gebze ile ilgili 10 tane baslik olsun, boyle
///	yazilsin ekrana sonra silinip yenisi yazilsin, tikladiginda onu
///	arasin, en basinda trending-up ikonu olsun"*).
///
/// ⚠️⚠️ **BUNLAR "TREND" DEGIL, ORNEK SORULARDIR.** Sunucuda ne arama
///	sayaci ne populerlik verisi VAR; `trendingUp` ikonu yalnizca GORSEL
///	bir isarettir ve ekranda "trend", "populer", "en cok aranan" gibi bir
///	IDDIA YAZILMAZ. Yazsaydik uydurma veri olurdu.
///
/// ⚠️ Metinler KISA tutuldu (<= ~30 karakter): daktilo efekti sirasinda
///    satir buyudugu icin uzun bir baslik 360 dp genislikte tasardi.
/// ⚠️ Hepsi GEBZE'ye ozel ve uygulamanin GERCEK alanlarindan (isletme,
///    etkinlik, hizmet) — AI bunlari yanitlayabilir.
const _kOneriler = <String>[
  'Gebze\'nin en iyi kebapçısı',
  'Bugün hava nasıl olacak?',
  'Akşam nereye gidebilirim?',
  'Yakınımdaki nöbetçi eczane',
  'Hafta sonu ne yapılır?',
  'Çocukla gidilecek yerler',
  'İyi bir kuaför önerir misin?',
  'Gebze\'de kahvaltı nerede?',
  'Bu hafta hangi etkinlik var?',
  'Ev taşımak için nakliyeci',
];

/// ⚠️⚠️⚠️ TURU 111 — **GEBZEMAI SOHBET EKRANI** (kullanici emri: *"gebzemai
///	daha profesyonel, Claude/Gemini gibi bir arayuz istiyorum"*).
///
/// ═══════════ ESKI HAL ═══════════
///
/// `AiDanismaEkrani` bir **tek atislik formdu**: fotograf sec -> not yaz ->
/// "Sor" -> altta duz metin. Ikinci soru sorulamiyordu, onceki cevap
/// EKRANDAN SILINIYORDU (`_sonuc = ''`) ve fotograf **ZORUNLUYDU** (sunucu
/// `400 "fotoğraf gerekli"` donduruyordu) — yani yazi yazip gondermek
/// YAPISAL OLARAK imkansizdi.
///
/// ═══════════ YENI ═══════════
///
///   · mesaj listesi — kullanici SAGDA baloncukta, yanit SOLDA tam genislikte
///     (Claude deseni: uzun metni baloncuga hapsetmek okunurlugu dusurur),
///   · altta cok satirli yazac + fotograf ekleme + gonder dugmesi,
///   · bos ekranda **oneri cipleri**,
///   · her yanitin altinda **kopyala**,
///   · **Yeni sohbet** (AppBar).
///
/// ⚠️⚠️ **DURUST SINIRLAR — ekranda da yazili:**
///   · **Akan (streaming) yanit YOK**: sunucu OpenAI cagrisini tek parca
///     bekleyip donduruyor. "Yaziyor" animasyonu bir BEKLEME gostergesidir,
///     harf harf akan bir metin degildir.
///   · **Sohbet SAKLANMAZ**: sunucuda tablo yok. Ekrandan cikinca konusma
///     biter. "Sohbetlerim" gibi bir liste vaat EDILMIYOR.
///   · **Durdurma YOK**: istek atildiktan sonra iptal etmek kotayi geri
///     getirmez (rezervasyon atomik) — olmayan bir kurtarma dugmesi
///     cizmiyoruz.
///
/// ⚠️ AI kapaliyken (`/ai/durum`) ekran yazaci CIZMEZ — dugmeye basip 503
///    almak bu projede kayitli "olu ozellik" sinifi.
/// ⚠️⚠️ TURU 127 — GebzemAI zemin gradyani (kullanici emri + verdigi
///	ekran goruntusu).
///
///	⚠️ **MOR YALNIZ ALTTA.** Ilk yazimda orta durak %55`teydi ve mor
///	ekranin YARISINDAN itibaren basliyordu; referansta ust bolge
///	neredeyse TAMAMEN siyah, renk yalnizca alt ucta acilir.
///	Duraklar %0 / **%68** / %100 ve orta durak da KOYU.
const Color _kAiZeminUst = Color(0xFF050308);
// ⚠️ TURU 127 — `_kAiZeminOrta`/`_kAiZeminAlt` SILINDI: duz gradyanin
//    ara duraklariydi, radyal parlamalara gecince karsiliklari kalmadi.

/// ⚠️ Alt parlamalarin renkleri. Ikisi FARKLI ton: tek renk iki kez
///    kullanilsaydi ust uste binen bolge yalnizca KOYULASIR, RENK
///    KARISMAZDI — kullanicinin istedigi "renkler karissin" buydu.
const Color _kAiParlakMor = Color(0xFF7B3FE4);
const Color _kAiKoyuMor = Color(0xFF3B1E7A);

class GebzemAiEkrani extends ConsumerStatefulWidget {
  const GebzemAiEkrani({super.key});

  @override
  ConsumerState<GebzemAiEkrani> createState() => _GebzemAiEkraniState();
}

/// Tek mesaj. `benim` false ise yanit.
class _Mesaj {
  const _Mesaj({required this.benim, required this.metin, this.gorsel});
  final bool benim;
  final String metin;
  final File? gorsel;
}

class _GebzemAiEkraniState extends ConsumerState<GebzemAiEkrani>
    with TickerProviderStateMixin {
  /// ⚠️ TURU 127 — HEM "yaziyor" cubuklarini HEM alt gradyanin hafif
  ///    dalgasini besler. TEK denetleyici: iki ayri ticker acmak bu
  ///    ekranda gereksiz.
  late final AnimationController _dalga = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  final _yazac = TextEditingController();
  final _kaydirma = ScrollController();

  /// ⚠️ TURU 117 — giris kutusunun kenarligi ODAKTA marka rengine doner;
  ///    bunun icin odak durumunu IZLEMEK gerekiyor.
  /// ⚠️ Dinleyici ZORUNLU: `hasFocus` degistiginde Flutter kendiliginden
  ///    yeniden CIZMEZ — `setState` biz cagirmaliyiz.
  /// ⚠️ `dispose`ta hem dinleyici kaldirilir hem node birakilir (sizinti).
  final _odak = FocusNode();
  final _mesajlar = <_Mesaj>[];
  File? _eklenen;

  /// ⚠️⚠️⚠️ TURU 127 — **GORSEL ARTIK SECILIR SECILMEZ HAZIRLANIR**
  ///	(kullanici emri: *"resim eklenirken loading olsun ortada, resim
  ///	eklenmeden hafif karanlik olsun, eklendiginde normal rengine
  ///	donsun"*).
  ///
  ///	Onceden `gorseliHazirla` (EXIF/GPS temizligi + sikistirma)
  ///	**GONDER ANINDA** kosuyordu: kullanici onizlemeyi hazir sanip
  ///	gonderiyor, sonra saniyelerce bekliyordu. Artik is ONDE yapilir
  ///	ve ekranda GORUNUR.
  ///
  /// ⚠️ Sunucu EXIF`te GPS bulursa **422** doner — temizlik atlanabilir
  ///    bir adim DEGIL.
  /// ⚠️ Hazirlik BASARISIZ olursa gorsel DUSURULUR ve kullaniciya
  ///    soylenir; sessizce hazirlanmamis dosya gondermek 422 uretirdi.
  File? _eklenenHazir;
  bool _gorselHazirlaniyor = false;
  bool _calisiyor = false;

  @override
  void initState() {
    super.initState();
    _odak.addListener(_odakDegisti);
  }

  void _odakDegisti() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _dalga.dispose();
    _odak.removeListener(_odakDegisti);
    _odak.dispose();
    _yazac.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  /// ⚠️ Yeni mesaj eklendiginde listenin DIBINE kaydirilir. Kare sonrasina
  ///    ertelenir: `setState` aninda yeni satirin yuksekligi HENUZ BILINMEZ.
  void _dibeKaydir() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_kaydirma.hasClients) return;
      _kaydirma.animateTo(
        _kaydirma.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _gorselSec() async {
    // ⚠️ `MedyaKapisi` kapisi: aktif arama/oda/yayin varken kamera acilmaz.
    if (!MedyaKapisi.izinVer(ref)) return;
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
      // secici acilamadi — asagidaki null kapisi devralir
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;
    final dosya = File(x.path);
    setState(() {
      _eklenen = dosya;
      _eklenenHazir = null;
      _gorselHazirlaniyor = true;
    });
    File? hazir;
    try {
      hazir = await MedyaServisi.gorseliHazirla(dosya);
    } catch (_) {
      hazir = null;
    }
    // ⚠️ Canlilik kapisi: hazirlik surerken ekrandan cikilmis olabilir.
    if (!mounted) return;
    // ⚠️⚠️ **KIMLIK KAPISI:** kullanici bu arada gorseli SILMIS ya da
    //	BASKA bir gorsel secmis olabilir. `_eklenen` degistiyse bu
    //	sonuc BAYATTIR — yazilirsa ekrandaki gorselle GONDERILEN dosya
    //	ayrisirdi.
    if (_eklenen != dosya) return;
    if (hazir == null) {
      setState(() {
        _eklenen = null;
        _gorselHazirlaniyor = false;
      });
      rootMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Görsel hazırlanamadı.')),
        );
      return;
    }
    setState(() {
      _eklenenHazir = hazir;
      _gorselHazirlaniyor = false;
    });
  }

  Future<void> _gonder() async {
    final metin = _yazac.text.trim();
    if (_calisiyor || (metin.isEmpty && _eklenen == null)) return;

    // ⚠️⚠️ Servisler TUM await'lerden ONCE yakalanir: AI cagrisi uzun surer,
    //	kullanici bu arada ekrandan cikabilir ve `ref.read` `StateError`
    //	firlatirdi (turu 67/77b dersi).
    final medyaSvc = ref.read(medyaServisiProvider);
    final aiSvc = ref.read(aiServisiProvider);

    final gorsel = _eklenen;
    // ⚠️ Yukleme icin HAZIRLANMIS dosya kullanilir; `gorsel` yalniz
    //    ekranda gosterilen ORIJINALDIR (balonda o cizilir).
    final gorselHazir = _eklenenHazir;
    // ⚠️ Gecmis GONDERILEN MESAJDAN ONCEKI hali olmali: yeni mesaj `metin`
    //    alaniyla ayrica gidiyor, gecmise de eklenirse IKI KEZ gonderilirdi.
    final gecmis = [
      for (final m in _mesajlar)
        if (m.metin.isNotEmpty)
          (rol: m.benim ? 'user' : 'assistant', metin: m.metin),
    ];

    setState(() {
      _mesajlar.add(_Mesaj(benim: true, metin: metin, gorsel: gorsel));
      _yazac.clear();
      _eklenen = null;
      _eklenenHazir = null;
      _calisiyor = true;
    });
    _dibeKaydir();

    try {
      var mediaId = '';
      if (gorselHazir != null) {
        // ⚠️ Hazirlik (EXIF temizligi) ARTIK BURADA DEGIL — secim
        //    aninda yapildi ve ekranda gosterildi.
        mediaId = await medyaSvc.yukle(
          dosya: gorselHazir,
          kind: 'image',
          mime: 'image/jpeg',
        );
      }
      final s = await aiSvc.danisma(
        mediaId: mediaId,
        metin: metin,
        gecmis: gecmis,
      );
      if (!mounted) return;
      setState(() => _mesajlar.add(_Mesaj(benim: false, metin: s)));
      // kota sayaci tazelenir (turu 77b)
      ref.invalidate(aiDurumProvider);
    } catch (e) {
      // ⚠️ KOK MESSENGER: cagri uzun surer, ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _calisiyor = false);
      _dibeKaydir();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    final acik = ai?.acik ?? false;
    final scheme = Theme.of(context).colorScheme;

    // ⚠️⚠️⚠️ TURU 127 — **EKRAN KOYU MOR** (kullanici emri: Gemini
    //	arayuzunun birebir benzeri + *"arkadaki renk morumsu olacak"*).
    //
    // ⚠️⚠️ EKRAN TEMADAN BAGIMSIZ KOYU: uygulama teması ACIK ve bu
    //	ekranin yazi/ikon renkleri `scheme.onSurface`ten geliyordu —
    //	zemin koyulasinca hepsi SIYAH kalir ve **hicbiri okunmazdi**
    //	(turu 115b`de sohbet balonlarinda birebir bu yasandi: 1,23:1).
    //	Bu yuzden ekran `ThemeData.dark` ile SARILIYOR; boylece
    //	`scheme.onSurface` beyaz doner ve alt bilesenler (balonlar,
    //	giris kutusu, yaziyor gostergesi) TEK TEK boyanmak zorunda
    //	kalmaz.
    // ⚠️ YAPMA: sarmali kaldirip renkleri cagri yerlerine yazma.
    // ⚠️⚠️ TURU 127 — **SISTEM GERI JESTI DE ONAY ISTER.** `PopScope`
    //	olmasaydi ekrandaki ok nazik davranir, jest sohbeti SESSIZCE
    //	goturuurdu (turu 126`da kayit akisinda birebir bu yasandi).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bittiMi, _) async {
        if (bittiMi) return;
        if (!await _cikisOnayi()) return;
        if (mounted && context.mounted) Navigator.of(context).pop();
      },
      child: Theme(
        // ⚠️⚠️⚠️ TURU 127 — **YAZI TIPI KAYBOLMUSTU** (kullanici sordu:
        //	*"yazi tipi bizim uygulamanin yazi tipi Google Sans degil mi,
        //	degisik geldi"*). HAKLIYDI: ekran `ThemeData.dark()` ile
        //	sariliyordu ve o tema **SIFIRDAN kuruluyor** — uygulamanin
        //	`fontFamily: Google Sans` ayari TASINMIYOR, sistem fontuna
        //	(Roboto) dusuyordu.
        //	⚠️ `copyWith` ile SARMALIN KENDISINE eklendi.
        //	⚠️ YAPMA: `fontFamily`yi cagri yerlerine tek tek yazma —
        //	   `theme.dart` serhi "kod genelinde BASKA yerde yazili degil"
        //	   diyor ve bu tek kaynagi bozardi.
        data: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: morLogo,
            brightness: Brightness.dark,
          ).copyWith(surface: _kAiZeminUst),
          scaffoldBackgroundColor: Colors.transparent,
          textTheme: ThemeData.dark(useMaterial3: true).textTheme.apply(
            fontFamily: 'Google Sans',
          ),
          primaryTextTheme: ThemeData.dark(useMaterial3: true)
              .primaryTextTheme
              .apply(fontFamily: 'Google Sans'),
        ),
        // ⚠️⚠️⚠️ TURU 127 — **DUZ GRADYAN DEGIL, YUMUSAK MOR PARLAMALAR.**
        //
        //	Kullanici emri: *"yukaridan asagi degil, boyle dalgali; renkler
        //	karissin; siyah-mor birlesmeleri cok sert, daha yumusak olsun;
        //	dalgalansin"*.
        //
        //	ONCEKI HAL: tek `LinearGradient`, uc durak. Duraklar arasi gecis
        //	YATAY BIR BANT uretiyordu — ekranin belli bir yuksekliginde
        //	cizgi gibi bir sinir goruluyordu ("cok sert" denen sey buydu).
        //
        //	YENI: siyah taban + UZERINE IKI **RadialGradient** parlama.
        //	Radyal sonum dogasi geregi kenari OLMAYAN bir gecistir; iki
        //	parlama ust uste binince renkler KARISIR ve sinir kalmaz.
        // ⚠️ Iki parlama **AYRI FAZDA** hareket eder (biri `_dalga`, oteki
        //    `1 - _dalga`): ayni fazda olsalardi tek bir sisen leke gibi
        //    durur, "dalga" hissi olusmazdi.
        // ⚠️ Merkezler ekranin ALT KENARININ ALTINDA (y > 1): parlamanin
        //    yalniz UST YAYI gorunur — dalga tepesi dili budur.
        // ⚠️ Genlik kucuk (x ekseninde ±0.18): kullanici "cok hafif" dedi.
        // ⚠️⚠️ `cocuk` PARAMETRESI ZORUNLU: agac `builder` govdesinde
        //	kurulsaydi Scaffold ve TUM ekran HER KAREDE yeniden insa
        //	edilirdi (turu 120 ANR dersi: 500 ms/kare).
        child: AnimatedBuilder(
          animation: _dalga,
          builder: (_, cocuk) {
            final t = _dalga.value;
            return DecoratedBox(
              decoration: const BoxDecoration(color: _kAiZeminUst),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.55 + t * 0.18, 1.25),
                    radius: 1.15,
                    colors: [
                      _kAiParlakMor.withValues(alpha: 0.55),
                      _kAiParlakMor.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                    // ⚠️ Ara durak (0.45) sonumu YAVASLATIR; iki duraklı
                    //    radyalde gecis hala fark ediliyordu.
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.6 - t * 0.18, 1.1),
                      radius: 0.95,
                      colors: [
                        _kAiKoyuMor.withValues(alpha: 0.6),
                        _kAiKoyuMor.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: cocuk,
                ),
              ),
            );
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: Colors.white,
              // ⚠️⚠️ TURU 117 — GERI TUSU **GONDER IKONUNUN AYNASI** (kullanici
              //	emri: *"geri tusu oradaki gonder gibi olacak sola dogru"*).
              //	Gonder dugmesi `LucideIcons.arrowUp`; geri onun 90 derece
              //	sola cevrilmisi = `arrowLeft`. Boylece ekranin iki ucundaki
              //	iki ok AYNI cizim dilinde olur.
              // ⚠️ Varsayilan `BackButton` KULLANILMIYOR: o platforma gore
              //    degisir (Android ok, iOS chevron) ve "gonder gibi" olmaz.
              // ⚠️ `Navigator.maybePop`: bu ekran kok route ise patlamasin.
              leading: IconButton(
                tooltip: 'Geri',
                icon: const Icon(LucideIcons.arrowLeft),
                // ⚠️ TURU 127 — ok da sistem geri jesti de AYNI kapidan
                //    gecer (`_cikisOnayi`); asimetri olsaydi biri onay
                //    sorar oteki sohbeti SESSIZCE goturuurdu.
                onPressed: () async {
                  if (!await _cikisOnayi()) return;
                  if (mounted && context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
              // ⚠️⚠️ TURU 117 — BASLIK **ORTADA**, bir tik KALIN, 2 px KUCUK
              //	(kullanici emri: *"gebzemai ortada bir tik kalin ve 2px yazi
              //	tipi kucuk"*).
              //	Tema `appBarTheme` genelinde `centerTitle: false` — burada
              //	ACIKCA eziliyor, yoksa baslik sola yapisir.
              //	Olcu: `titleLarge` 22 px -> **20 px**, agirlik w600 -> **w700**.
              centerTitle: true,
              title: const Text(
                'GebzemAI',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              actions: [
                // ⚠️⚠️ TURU 127 — dugme artik **HER ZAMAN CIZILIYOR**
                //	(kullanici: *"en saga yeni sohbet iconu kaldirmissin"*).
                //	Kosul `_mesajlar.isNotEmpty` idi: bos sohbette dugme HIC
                //	cizilmiyordu ve kullanici onu KALDIRILMIS saniyordu.
                // ⚠️ Bos sohbette **PASIF** (soluk): temizlenecek bir sey yok.
                //    Gorunur ama etkisiz olmasi, hic olmamasindan durust —
                //    dugmenin nerede oldugu ogrenilebiliyor.
                if (acik)
                  IconButton(
                    tooltip: 'Yeni sohbet',
                    // ⚠️ TURU 127 — `squarePen` -> **`penLine`** (kullanici:
                    //    *"daha basit bir icon"*). `plus` DENENDI ve
                    //    BIRAKILDI: giris alanindaki fotograf `+` ile BIREBIR
                    //    ayni cizimdi, iki farkli is ayni ikonla anlatiliyordu.
                    // ⚠️ TURU 127 — kullanici emri: `messageCirclePlus`.
                    icon: const Icon(LucideIcons.messageCirclePlus),
                    onPressed: (_calisiyor || _mesajlar.isEmpty)
                        ? null
                        : _yeniSohbetSor,
                  ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: !acik
                      ? _kapali()
                      : _mesajlar.isEmpty
                      ? _karsilama(ai)
                      : ListView.builder(
                          controller: _kaydirma,
                          // ⚠️ TURU 127 — ust bosluk 12 -> **17** (kullanici:
                          //    header ile mesajlarin arasi 5 px artsin).
                          padding: const EdgeInsets.fromLTRB(
                            kYanBosluk,
                            17,
                            kYanBosluk,
                            12,
                          ),
                          itemCount: _mesajlar.length + (_calisiyor ? 1 : 0),
                          itemBuilder: (_, i) => i < _mesajlar.length
                              ? _balon(_mesajlar[i], scheme)
                              : _yaziyor(scheme),
                        ),
                ),
                if (acik) _yazacAlani(scheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// AI kapaliyken: yazac CIZILMEZ.
  Widget _kapali() => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Text(
        'Yapay zekâ şu anda kullanılamıyor.',
        textAlign: TextAlign.center,
        // ⚠️ TURU 114 (denetim) — `Colors.grey` (#9E9E9E) acik tema zemininde
        //    (#F2F2F5) **2.40:1**; 14 px normal metin icin esik 4.5:1.
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    ),
  );

  /// Bos ekran: selamlama + oneri cipleri.
  ///
  /// ⚠️ Oneriler SABIT ve GENEL: kullanicinin verisine gore "kisisellestirilmis"
  ///    oneri uretecek bir uc YOK, uydurma bir kisisellik iddia etmiyoruz.
  Widget _karsilama(AiDurum? ai) {
    // ⚠️⚠️ TURU 127 — **ONERI KARTLARI KALDIRILDI** (kullanici emri:
    //	*"bir sey sor ya da fotograf ekle altindaki Gebze hafta sonu ne
    //	yapilabilir gibi seyleri kaldir"*).
    // ⚠️ Kartlar SABIT metinlerdi; kullanicinin verisine gore oneri
    //    ureten bir uc YOK ve olmadigi icin dordu de herkeste AYNIYDI.
    //    Kaldirilmalariyla ekran "ne yazacagimi ben sectim" hissi
    //    yerine BOS BIR SORU ALANI birakiyor — istenen buydu.
    // ⚠️⚠️⚠️ TURU 117 — KARSILAMA EKRANI YENIDEN KURULDU (kullanici emri:
    //	*"karsilama ekrani daha profesyonel olsun daha modern hale getir ...
    //	kalan hak vb altta daha guzel anlasilir sekilde olsun"*).
    //
    // ESKI HALI: ciplak bir ikon, iki satir yazi, dort tane ayni gorunen
    // cerceveli kutu ve en altta iki soluk gri satir (kalan hak + uyari).
    // Kalan hak, oneri kartlariyla AYNI dilde bir gri yaziydi — yani en
    // onemli bilgi en SILIK ogeydi.
    //
    // YENI DUZEN:
    //  · ustte MARKA ROZETI (gradyanli daire + ikon) — logo diliyle ayni
    //  · baslik + tek satir aciklama
    //  · oneriler: her biri KENDI IKONUYLA, dokunulabilir oldugu belli
    //  · en altta **KALAN HAK KARTI**: sayi buyuk, yaninda ilerleme cubugu
    //
    // ⚠️⚠️ `Expanded`/`Spacer` KULLANILMADI: govde bir `ListView` ve dikey
    //	kisiti SINIRSIZ; esnek cocuk koymak "BoxConstraints forces an
    //	infinite height" verir (turu 115b'de olustur menusunde birebir bu
    //	yasandi, ekran BOMBOS acildi). Yerlesim SABIT bosluklarla kurulur.
    // ⚠️⚠️ TURU 127 — **GEMINI DUZENI** (kullanici emri, ekran goruntusu
    //	verdi): ekranin ORTASINDA parlak yildiz + iki satir buyuk soru.
    //	Ustte rozet, altta kart YOK — bos ekranin tamami TEK bir davet.
    // ⚠️ `Center` + `Column(min)`: govde `Expanded` icinde, dikey kisit
    //    SINIRLI — `ListView` gerekmiyor ve kaydirma cubugu cikmiyor.
    // ⚠️⚠️ TURU 127 — **ISIMLE SELAMLAMA** (kullanici emri: *"isim
    //	kullan, ornegin Yavuz sana hangi konuda yardimci olabilirim"*).
    // ⚠️ Ad SUNUCUDAN gelir (`myProfileProvider`), UYDURULMAZ. Profil
    //    henuz gelmediyse ya da ad bossa isimsiz surum cizilir —
    //    "Merhaba null" gibi bir sey EKRANA CIKAMAZ.
    // ⚠️ Yalniz ILK KELIME kullanilir: "Ahmet Yılmaz, sana hangi konuda"
    //    iki satiri asar ve samimi degil resmi durur.
    final tamAd = (ref.watch(myProfileProvider).valueOrNull?['name'] ?? '')
        .toString()
        .trim();
    final ad = tamAd.isEmpty ? '' : tamAd.split(RegExp(r'\s+')).first;
    // ⚠️⚠️ TURU 127 — **ISIM CUMLENIN GERISINDEN BIR TIK KALIN**
    //	(kullanici emri: *"oradaki ... ismi 1 tik daha kalinlastir"*).
    //	Isim w700, cumlenin geri kalani w600.
    // ⚠️ Kalinlik `Text.rich` ile PARCA BAZINDA veriliyor; tum cumleyi
    //    w700 yapmak istegin TERSI olurdu (isim one cikmaz, hepsi kalin
    //    olur). ⚠️ `letterSpacing` KULLANILMADI (kullanici yasagi).
    const govdeStil = TextStyle(
      fontSize: 27,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    // ⚠️ TURU 127 — **IKON KALDIRILDI** (kullanici emri). Ekranin
    //    ortasinda yalnizca soru duruyor.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text.rich(
          TextSpan(
            style: govdeStil,
            children: ad.isEmpty
                ? const [TextSpan(text: 'Sana hangi konuda yardımcı olabilirim?')]
                : [
                    TextSpan(
                      text: ad,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(
                      text: ', sana hangi konuda yardımcı olabilirim?',
                    ),
                  ],
          ),
              textAlign: TextAlign.center,
            ),
          ),
          // ⚠️ 30 px: kullanici emri (*"hangi konuda yardimci olabilirim
          //    30 px altina"*).
          const SizedBox(height: 30),
          _OneriDongusu(
            oneriler: _kOneriler,
            onSec: _oneriSecildi,
          ),
        ],
      ),
    );
  }

  /// ⚠️⚠️ Oneri secilince soru KUTUYA yazilir ve ANINDA gonderilir.
  ///    Yalniz kutuya yazip birakmak, kullanicinin bir de gonder`e
  ///    basmasini gerektirirdi — dokunusun ANLAMI "bunu sor"du.
  /// ⚠️ `_calisiyor` kapisi: yanit beklenirken ikinci soru gonderilemez
  ///    (`_gonder` zaten reddeder, ama burada da erken donup kutuyu
  ///    bosuna doldurmayalim).
  void _oneriSecildi(String soru) {
    if (_calisiyor) return;
    _yazac.text = soru;
    _gonder();
  }

  /// ⚠️⚠️ TURU 127 — **KOPYALAMA IKONU** (kullanici emri: *"benim
  ///	gonderdigimde ve cevapta kopyalama ikonu yok, onu ekle"*).
  ///
  ///	Onceki turda "Kopyala" YAZILI dugmesi kaldirilmisti; islev
  ///	`SelectableText` uzerinde duruyordu ama **KESFEDILEBILIR
  ///	DEGILDI** — uzun basmayi denemeyen kullanici icin ozellik YOK
  ///	hukmundeydi. Artik yazisiz, kucuk bir ikon.
  ///
  /// ⚠️ TEK KAYNAK: iki cagri yeri de bunu kullanir. Iki ayri kopya
  ///    kacinilmaz olarak drift ederdi (bu projede alti kez yasandi).
  Widget _kopyaDugmesi(String metin) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        tooltip: 'Kopyala',
        padding: EdgeInsets.zero,
        // ⚠️ `IconButton` varsayilani 48 dp kare bir kutu dayatir; bu
        //    kadar kucuk bir ikonun ustunde o kutu balonu SISIRIYORDU.
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        icon: Icon(
          LucideIcons.copy,
          size: 15,
          color: Colors.white.withValues(alpha: 0.45),
        ),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: metin));
          rootMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Kopyalandı')));
        },
      ),
    );
  }

  /// ⚠️ Kullanici mesaji BALONCUKTA (sagda), yanit TAM GENISLIKTE (solda).
  ///    Uzun bir yaniti dar bir baloncuga hapsetmek satir uzunlugunu kirar;
  ///    Claude/Gemini de yaniti tam genislikte cizer.
  Widget _balon(_Mesaj m, ColorScheme scheme) {
    if (m.benim) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(kYaricap(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.gorsel != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      m.gorsel!,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (m.metin.isNotEmpty) const SizedBox(height: 8),
                ],
                if (m.metin.isNotEmpty)
                  // ⚠️ TURU 127 — **`SelectableText`** (kullanici emri:
                  //    *"bizim attigimiz mesajlarda kopyalayabilmesi
                  //    gerekiyor"*). Duz `Text` uzun basmayi HIC almiyordu.
                  SelectableText(m.metin, style: const TextStyle(fontSize: 17)),
                // ⚠️ Ikon balonun ICINDE, saga dayali: disarida olsaydi
                //    baloncugun hizasini bozardi.
                if (m.metin.isNotEmpty) _kopyaDugmesi(m.metin),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️⚠️ TURU 127 — **IKON + "GebzemAI" ETIKETI KALDIRILDI**
          //	(kullanici emri). Ilk adimda yalniz "yaziyor" gostergesinden
          //	kaldirilmisti; YANIT BALONUNDAKI kopya ATLANMISTI ve
          //	kullanici cevap gelince onu goruyordu.
          // ⚠️ Kimin yazdigi KONUMDAN belli: kullanici mesaji SAGDA
          //    baloncukta, yanit SOLDA tam genislikte.
          SelectableText(
            m.metin,
            // ⚠️ TURU 127 — 15 -> 17 (kullanici emri).
            style: const TextStyle(fontSize: 17, height: 1.42),
          ),
          // ⚠️ Yanitta ikon SOLA dayali (yanit da sola dayali).
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _kopyaDugmesi(m.metin),
          ),
        ],
      ),
    );
  }

  /// ⚠️ Bu bir BEKLEME gostergesidir, akan metin DEGIL (sunucu tek parca
  ///    donduruyor). Yaniltmamak icin yaninda "yazıyor" yazar.
  /// ⚠️⚠️⚠️ TURU 127 — **ONAY PANELI: TEK KAYNAK, KULLANICININ VERDIGI
  ///	TASARIM.** (Kullanici bir ekran goruntusu yolladi.)
  ///
  ///	Duzen: **baslik SOLDA + sag ustte X** · ince AYRAC · aciklama ·
  ///	altta **YAN YANA iki hap dugme** (sol gri "Vazgeç", sag beyaz
  ///	dolgulu eylem).
  ///
  /// ⚠️⚠️ **IKI PANEL DE BURADAN CIZILIR.** Onceki surumde "Yeni sohbet"
  ///	ve "Sohbetten cik" panelleri AYRI AYRI yazilmisti (~90 satir
  ///	KOPYA); biri degisince oteki geride kalirdi. Bu projede o sinif
  ///	alti kez yasandi.
  ///
  /// ⚠️ Eylem dugmesi **BEYAZ**, mor DEGIL: panel zemini koyu mor
  ///    tonlarinda ve mor dolgulu dugme zeminden ayrilmiyordu
  ///    (kullanicinin verdigi tasarimda da beyaz).
  /// ⚠️⚠️ `isScrollControlled: true` + `SingleChildScrollView` IKISI DE
  ///	ZORUNLU (turu 115c dersi): ilki yalnizca YUKSEKLIK TAVANINI
  ///	kaldirir, icerigi KAYDIRILABILIR YAPMAZ. Yazi olcegi 2.0`da
  ///	panel tasar ve dugmeler EKRAN DISINDA kalirdi.
  /// ⚠️ `useSafeArea: true` YETMEZ — SDK`da o bayrak
  ///    `SafeArea(bottom: false)` uretir; alt guvenli alan ELLE eklendi.
  /// ⚠️ X ve "Vazgeç" AYNI sonucu doner (`false`); ikisi de kullanicinin
  ///    "hayir" demesinin mesru yollari.
  Future<bool> _onayPaneli({
    required String baslik,
    required String aciklama,
    required String eylem,
  }) async {
    final onay = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15121F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── BASLIK + X ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        baslik,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      // ⚠️ Kapatma X`i "hayir" demektir -> `false`.
                      onPressed: () => Navigator.of(c).pop(false),
                      icon: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // ── AYRAC ──
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              // ── ACIKLAMA ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                child: Text(
                  aciklama,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ),
              // ── DUGMELER (YAN YANA) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Row(
                  children: [
                    // ⚠️ `Expanded` ZORUNLU: dugme metinleri farkli
                    //    uzunlukta ve sabit genislik verilseydi uzun
                    //    eylem adi ("Yeni sohbet başlat") tasardi.
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(c).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(
                            alpha: 0.10,
                          ),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Vazgeç',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(c).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          // ⚠️ Beyaz zeminde SIYAH yazi (21:1) — beyaz
                          //    ustune beyaz okunmazdi.
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          eylem,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return onay == true;
  }

  /// ⚠️ Onay GERCEKTEN gerekli: sohbet **HICBIR YERDE SAKLANMIYOR**
  ///    (sunucuda tablo yok). Temizlenen konusma GERI GETIRILEMEZ —
  ///    geri alinamayan bir eylem onaysiz calismamali.
  /// ⚠️ Metin ne olacagini ACIKCA soyler; "Emin misin?" gibi bos bir
  ///    soru kullaniciya NE KAYBEDECEGINI anlatmaz.
  Future<void> _yeniSohbetSor() async {
    final onay = await _onayPaneli(
      baslik: 'Yeni sohbet',
      aciklama: 'Bu konuşma silinecek. Sohbetler kaydedilmediği için '
          'geri getirilemez.',
      eylem: 'Başlat',
    );
    // ⚠️ `mounted` kapisi ZORUNLU: panel acikken ekran sokulmus olabilir.
    if (!onay || !mounted) return;
    setState(() {
      _mesajlar.clear();
      _eklenen = null;
      _eklenenHazir = null;
    });
  }

  /// ⚠️⚠️⚠️ TURU 127 — **GERI TUSU: SOHBET ACIKSA ONAY ISTER**
  ///	(kullanici emri: *"sohbet aktifse geri dedigimizde de alert ver,
  ///	sohbet kapanacagina dair"*).
  ///
  /// ⚠️ Sebep GERCEK: sohbet hicbir yerde saklanmiyor, ekrandan cikinca
  ///    KAYBOLUYOR. Yanlislikla basilan bir geri, konusmanin tamamini
  ///    goturur.
  /// ⚠️ Bos sohbette SORULMAZ: kaybedilecek bir sey yok ve her cikista
  ///    onay istemek gereksiz surtunmedir.
  Future<bool> _cikisOnayi() async {
    if (_mesajlar.isEmpty) return true;
    return _onayPaneli(
      baslik: 'Sohbetten çık',
      aciklama: 'Bu konuşma kapanacak ve kaydedilmediği için geri '
          'getirilemez.',
      eylem: 'Çık',
    );
  }

  /// ⚠️⚠️⚠️ TURU 127 — **SES KAYDI SOHBETTEKI ARAYUZLE AYNI** (kullanici
  ///	emri: *"sosyalde ses kaydina basladigimiz gibi arayuz yapsana"*).
  ///
  ///	Alttan cikan panel KALDIRILDI. Artik mikrofona dokununca giris
  ///	kutusunun **YERINE** mor kayit seridi geciyor:
  ///	`[cop] ~~~canli dalga~~~ 0:07 [gonder]` — sohbetteki ses notuyla
  ///	BIREBIR ayni bilesen (`SesNotuKaydedici`).
  ///
  /// ⚠️⚠️ **TASARIM KOPYALANMADI, BILESEN YENIDEN KULLANILDI.** Ikinci
  ///	bir kopya kacinilmaz olarak DRIFT ederdi (bu projede alti kez
  ///	yasandi); ustelik canli dalga cizeri ve genlik olcumu orada
  ///	ZATEN dogrulanmis durumda.
  ///
  /// ⚠️⚠️ **DURUST SINIR:** kayit GERCEKTEN aliniyor ama
  ///	**GONDERILEMIYOR** — sunucuda sesi metne ceviren uc YOK
  ///	(`/ai/danisma` yalniz metin + gorsel alir). Gonder`e basilinca
  ///	dosya SILINIR ve durustce "sesli soru henuz gonderilemiyor"
  ///	denir. **BEKLEYEN IS: `/ai/ses` ucu + STT.**
  /// ⚠️ YAPMA: kaydi `/ai/danisma`ya gorsel gibi gondermeye calisma —
  ///    uc `kind` beyaz listesinde ses YOK, 400 doner.
  ///
  /// ⚠️⚠️ `GlobalKey` ZORUNLU: kaydedici kayit basladiginda AGACTA
  ///	BASKA BIR KONUMA gecer (giris kutusunun icinden, kutunun
  ///	YERINE). Anahtar olmasaydi element yeniden kullanilamaz, State
  ///	SIFIRLANIR ve kayit ANINDA olurdu.
  final _sesAnahtar = GlobalKey();

  /// Kayit surerken giris kutusu CIZILMEZ.
  bool _sesKayitta = false;

  /// ⚠️ Kayit HER DURUMDA silinir: gonderilecek yer YOK, dosyayi diskte
  ///    birakmak sessiz bir sizinti olurdu.
  void _sesKaydiGeldi(File dosya, int sureMs, String dalga) {
    try {
      if (dosya.existsSync()) dosya.deleteSync();
    } catch (_) {}
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Sesli soru henüz gönderilemiyor. Kayıt cihazından silindi.',
          ),
        ),
      );
  }

  /// ⚠️⚠️ TURU 127 — **YUKLENIYOR: UC DAIRE** (kullanici emri: *"o
  ///	balonda cizgiler degil daireler olsun, 3 tane"*).
  ///
  ///	Once iki kayan CUBUK denendi; kullanici daire istedi. Klasik
  ///	"yaziyor" dili zaten budur ve her sohbet uygulamasinda ayni.
  ///
  /// ⚠️ Ikon ve "GebzemAI" etiketi YOK: yanit zaten SOLDA hizali,
  ///    kimin yazdigi konumdan belli.
  /// ⚠️ Uc daire **FAZ KAYDIRMALI** yanar (0 · 1/3 · 2/3): ayni anda
  ///    yanip sonselerdi tek bir nabiz gibi durur, "siraya giren
  ///    harfler" hissi olusmazdi.
  Widget _yaziyor(ColorScheme scheme) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedBuilder(
          animation: _dalga,
          builder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                  child: _nokta(i),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  /// Tek daire. `sira` fazi kaydirir.
  ///
  /// ⚠️ `_dalga` `reverse: true` ile 0..1..0 gidip geliyor; faz kaymasi
  ///    icin degeri `sira/3` kadar oteliyoruz ve `% 1.0` ile sariyoruz.
  /// ⚠️ Opaklik tabani 0.28: sifira inseydi daire KAYBOLUR ve satir
  ///    "eksik" gorunurdu.
  Widget _nokta(int sira) {
    final t = (_dalga.value + sira / 3) % 1.0;
    // ⚠️ Ucgen dalga: 0 -> 1 -> 0 (tek yonlu artis "atlama" yapardi).
    final p = t < 0.5 ? t * 2 : (1 - t) * 2;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.28 + p * 0.52),
      ),
    );
  }

  Widget _yazacAlani(ColorScheme scheme) => SafeArea(
    top: false,
    child: Padding(
      // ⚠️ TURU 127 — alt bosluk 8 -> **13** (kullanici: *"tus takimi
      //    ile arasindaki boslugu 5 px arttir"*). Klavye acikken kutu
      //    tuslara yapisik duruyordu.
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 6, kYanBosluk, 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⚠️⚠️ TURU 127 — onizleme kutunun **DISINDAN ICINE** tasindi
          //	(kullanici emri: *"resim eklendiginde inputun EN USTUNE
          //	eklenecek, yazi altindan devam edecek"*). Bkz.
          //	`_eklenenOnizleme`.
          // ⚠️⚠️⚠️ TURU 117 — GIRIS ALANI YENIDEN KURULDU (kullanici emri:
          //	*"alttaki gorsel iconu daha guzel icon yap, BUNLAR INPUTUN
          //	ICINDE OLSUN, gonderde ikisi de inputun icinde ALTINDA
          //	olacak, YAZI YUKARIDA, input borderi guzellestir"*).
          //
          // ESKI HALI: [atac] [input] [gonder] — UC AYRI kutu yan yana,
          // uc farkli yukseklik. Ikonlar inputun DISINDAYDI.
          //
          // YENI: **TEK BIR KUTU**. Icinde ustte yazi alani, ALTINDA
          // eylem satiri (solda gorsel ekle, sagda gonder).
          //
          // ⚠️⚠️ NEDEN `prefixIcon`/`suffixIcon` DEGIL: ikisi de metinle
          //	AYNI SATIRDA durur ve cok satirli girdide DIKEY ORTALANIR —
          //	yani 5 satirlik soruda ikonlar ortada asili kalirdi.
          //	Kullanici ACIKCA "yazi YUKARIDA, ikonlar ALTINDA" dedi.
          // ⚠️ Kutu `Column(mainAxisSize.min)`: girdi buyudukce kutu da
          //    buyur, ikonlar HEP en altta kalir.
          // ⚠️ Odak: kutuya dokunmak yazi alanini odaklar (`GestureDetector`
          //    + `requestFocus`) — yoksa kullanici kutunun bos yerine
          //    dokununca hicbir sey olmuyordu.
          // ⚠️⚠️ TURU 127 — **DURUST SINIR SATIRI GIRISIN 10 px USTUNDE**
          //	(kullanici emri). Onceden karsilama ekraninin ICINDEYDI ve
          //	sohbet basladiginda EKRANDAN KAYBOLUYORDU — oysa "sohbet
          //	kaydedilmez" bilgisi tam da KONUSURKEN gerekli.
          // ⚠️ Ikon 1 tik kalin (dort golgeyle simule) ve yazi 12 -> 14
          //    (kullanici emri).
          // ⚠️ Kayit surerken uyari CIZILMEZ: serit zaten tum satiri
          //    kapliyor ve iki satir birden alt alta sikisirdi.
          if (!_sesKayitta)
            // ⚠️ TURU 127 — uyari **SOLA hizali**, **5 px daha yukarida**
            //    (10 -> 15) ve yazi 1 tik buyuk (kullanici emri).
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // ⚠️ TURU 127 — **KALINLASTIRMA KALDIRILDI** (kullanici:
                  //    *"icondaki kalinligi dusur"*). Dort golgeli simulasyon
                  //    koyu zeminde ikonu SISMIS gosteriyordu.
                  Icon(
                    LucideIcons.info,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 6),
                  // ⚠️⚠️ TURU 127 — metin **TEK SATIRA** indirildi (kullanici:
                  //	*"yazi tek satirda olsun, alt satira gecmesin, daha
                  //	profesyonel"*). Eski metin 360 dp`de IKI SATIRA sariyordu.
                  // ⚠️ Bilgi KAYBOLMADI: "kaydedilmiyor" zaten "ekrandan
                  //    cikinca gider" demek — ikinci cumle onu TEKRARLIYORDU.
                  // ⚠️ `maxLines: 1` + `ellipsis`: cok buyuk yazi olceginde
                  //    sarmak yerine kirpilir, satir YUKSEKLIGI SABIT kalir.
                  Flexible(
                    child: Text(
                      'Bu sohbet kaydedilmiyor.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ⚠️⚠️ TURU 127 — kayit surerken giris kutusu yerine **SERIT**
          //	(sohbetteki desen). Kaydedici AYNI `GlobalKey` ile burada
          //	da cizilir; anahtar olmasaydi State SIFIRLANIR ve kayit
          //	ANINDA olurdu.
          if (_sesKayitta)
            SesNotuKaydedici(
              key: _sesAnahtar,
              // ⚠️ TURU 127 — GebzemAI ekraninda KOYU serit (kullanici emri).
              koyu: true,
              onKayit: _sesKaydiGeldi,
              onDurum: (k) => setState(() => _sesKayitta = k),
            )
          else
            _girisKutusu(scheme),
        ],
      ),
    ),
  );

  /// ⚠️⚠️⚠️ TURU 127 — **EKLENEN GORSEL GIRIS KUTUSUNUN ICINDE, EN USTTE**
  ///	(kullanici emri: *"resim eklendiginde inputun en ustune
  ///	eklenecek, yazi altindan devam edecek ... resim eklenirken
  ///	loading olsun ortada, resim eklenmeden hafif karanlik olsun,
  ///	eklendiginde normal rengine donsun, saginda beyaz daire icinde
  ///	x olsun"*).
  ///
  ///	Onceden onizleme kutunun **DISINDA**, ustunde ayri bir satirda
  ///	duruyordu; gorsel ile yazinin AYNI mesaja ait oldugu belli
  ///	degildi.
  ///
  /// ⚠️ **KARANLIK ORTU + LOADING** yalniz `_gorselHazirlaniyor` iken:
  ///    hazirlik (EXIF/GPS temizligi + sikistirma) buyuk fotograflarda
  ///    saniyeler surer ve o sure boyunca ekranda HICBIR IZ YOKTU.
  /// ⚠️ Ortu `Positioned.fill` + AYNI yaricapla kirpilir; kirpilmasaydi
  ///    yuvarlak kosenin disinda kare bir golge kalirdi.
  /// ⚠️ X **beyaz daire icinde SIYAH** (kullanici emri): gorsel her renkte
  ///    olabilir, ciplak beyaz bir X acik bir fotografta KAYBOLURDU.
  /// ⚠️ Dokunma alani 30 dp: turu 78b`de 17 dp olcusu "dokunulamiyor"
  ///    diye duzeltilmisti.
  Widget _eklenenOnizleme() {
    const kose = 14.0;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
        child: SizedBox(
          width: 78,
          height: 78,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(kose),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_eklenen!, fit: BoxFit.cover),
                    // ── HAZIRLANIRKEN: KARARTMA + ORTADA LOADING ──
                    if (_gorselHazirlaniyor) ...[
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                      const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // ── SIL (SAG UST) ──
              Positioned(
                right: -9,
                top: -9,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _eklenen = null;
                    _eklenenHazir = null;
                    // ⚠️ Bayrak da DUSURULUR: hazirlik ucusta olabilir ve
                    //    kimlik kapisi sonucu atacak; bayrak asili kalirsa
                    //    gonder dugmesi KALICI KILITLENIRDI.
                    _gorselHazirlaniyor = false;
                  }),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.x,
                        size: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tek parca giris kutusu: ustte yazi, altta eylem satiri.
  ///
  /// ⚠️ Kenarlik ODAKTA marka rengine doner (`_odak`): kullanici emri
  ///    *"input borderi guzellestir"*. Sabit gri bir cerceve, yaziyor
  ///    olup olmadigini HIC belli etmiyordu.
  /// ⚠️⚠️⚠️ TURU 127 — **IKI SATIRLI, KENARLIKSIZ GIRIS (GEMINI DUZENI).**
  ///
  ///	Kullanici emri: *"border kullanmissin ama onda border yok; input
  ///	2 satir, yani yukarida yazi alani, altta + ve gonder; gonder ikonu
  ///	BEYAZ, arkada daire YOK; solunda mikrofon var; GebzemAI`a sorun
  ///	yazsin"*.
  ///
  /// ⚠️ **KENARLIK YOK** — kutu koyu zeminden yalnizca DOLGUSUYLA ayrilir
  ///    (beyazin %7`si). Odakta dolgu bir tik acilir; kenarlik EKLENMEZ,
  ///    cunku eklenip cikarilmasi kutunun ic olcusunu degistirir ve yazi
  ///    1 px ZIPLAR.
  /// ⚠️⚠️ Ikonlar `prefixIcon`/`suffixIcon` DEGIL, AYRI BIR SATIRDA
  ///	(turu 117 dersi): o alanlar metinle ayni satirda durur ve cok
  ///	satirli girdide DIKEY ORTALANIR — 5 satirlik soruda ikonlar
  ///	ortada asili kalirdi.
  Widget _girisKutusu(ColorScheme scheme) {
    final odakli = _odak.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: odakli ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── EKLENEN GORSEL (EN USTTE, KUTUNUN ICINDE) ──
          if (_eklenen != null) _eklenenOnizleme(),
          // ── YAZI ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _odak.requestFocus(),
            child: Padding(
              // ⚠️ Gorsel varken ust dolgu KUCULUR: onizleme zaten 14 dp
              //    ustten bosluk birakiyor, ikisi ust uste 28 dp yapardi.
              padding: EdgeInsets.fromLTRB(18, _eklenen != null ? 4 : 14, 18, 2),
              child: TextField(
                controller: _yazac,
                focusNode: _odak,
                minLines: 1,
                maxLines: 5,
                // ⚠️⚠️ TURU 127 — **CUMLE BASI BUYUK HARF** (kullanici:
                //	*"mesaja baslarken kucuk harfle basliyor, Gemini gibi
                //	uygulamalarda buyuk"*). Sebep BIZDEYDI: Flutter`in
                //	varsayilani `TextCapitalization.none` — klavyeye "cumle
                //	basi buyut" ipucu HIC gonderilmiyordu.
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                onChanged: (_) => setState(() {}),
                // ⚠️ TURU 127 — 16 -> 18 (kullanici emri).
                style: const TextStyle(fontSize: 18, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'GebzemAI’a sorun',
                  hintStyle: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  isDense: true,
                  // ⚠️ Kutu kendi zeminini ciziyor; `TextField` KENDI
                  //    cercevesini cizmez, yoksa CIFT cerceve olurdu.
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          // ── EYLEM SATIRI (ALTTA) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              children: [
                // ⚠️ `+` — islev fotograf secmek; `tooltip` bunu soyler.
                IconButton(
                  tooltip: 'Fotoğraf ekle',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: Icon(
                    LucideIcons.plus,
                    // ⚠️ TURU 127 — 23 -> 24 (kullanici emri).
                    size: 24,
                    color: _calisiyor
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                  onPressed: _calisiyor ? null : _gorselSec,
                ),
                const Spacer(),
                // ⚠️⚠️ TURU 127 — mikrofon artik `SesNotuKaydedici`nin
                //	KENDI dugmesi. Kayit baslayinca ayni bilesen mor
                //	SERIDE donusur ve giris kutusunun YERINE gecer
                //	(bkz. `_sesKaydiGeldi` serhi).
                SizedBox(
                  width: 44,
                  height: 44,
                  child: SesNotuKaydedici(
                    key: _sesAnahtar,
                    // ⚠️ TURU 127 — GebzemAI ekraninda KOYU serit (kullanici emri).
                    koyu: true,
                    onKayit: _sesKaydiGeldi,
                    onDurum: (k) => setState(() => _sesKayitta = k),
                  ),
                ),
                // ⚠️ Gonder bos girdide PASIF: bos istek kota yakardi.
                _gonderDugmesi(scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Karsilama ekranindaki **kalan hak** karti.
  ///
  /// ⚠️ Sayilar SUNUCUDAN (`ai.kalan` / `ai.kota`); kart yalniz `ai`
  ///    doluyken cizilir — yer tutucu sayi UYDURULMAZ.
  /// ⚠️ Ilerleme cubugu ORAN gosterir; kota 0 olursa sifira bolme olmasin
  ///    diye `kota > 0` kapisi var.
  // ⚠️ TURU 127 — kart artik CIZILMIYOR (kullanici emri) ama govdesi
  //    DURUYOR: kota gorunurlugu geri istenirse tek satirla geri gelir.
  // ignore: unused_element
  Widget _kalanHakKarti(AiDurum ai, ColorScheme scheme) {
    final oran = ai.kota > 0 ? (ai.kalan / ai.kota).clamp(0.0, 1.0) : 0.0;
    // ⚠️ Hak BITTIGINDE renk uyarici olur: kullanici neden yanit
    //    alamadigini kartin RENGINDEN anlar.
    final bitti = ai.kalan <= 0;
    final vurgu = bitti ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: vurgu.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vurgu.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(LucideIcons.zap, size: 16, color: vurgu),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  bitti ? 'Bugünlük hakkın doldu' : 'Bugün kalan hakkın',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              // ⚠️ Sayi BUYUK ve KALIN: eskiden %45 saydam 12,5 px gri bir
              //    satirdi, yani ekrandaki en onemli sayi en SILIK ogeydi.
              Text(
                '${ai.kalan}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: vurgu,
                ),
              ),
              Text(
                ' / ${ai.kota}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 5,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(vurgu),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            bitti ? 'Yarın sıfırlanır.' : 'Her gün sıfırlanır.',
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gonderDugmesi(ColorScheme scheme) {
    final hazir =
        !_calisiyor &&
        // ⚠️⚠️ Gorsel HAZIRLANIRKEN gonderilemez: hazir dosya henuz YOK
        //	ve gonderilseydi gorsel SESSIZCE dusurulur, kullanici
        //	ekledigi fotografin gittigini sanirdi.
        !_gorselHazirlaniyor &&
        (_yazac.text.trim().isNotEmpty || _eklenen != null);
    return Semantics(
      button: true,
      label: 'Gönder',
      // ⚠️⚠️ TURU 127 — **ARKADA DAIRE YOK, IKON BEYAZ** (kullanici emri).
      //	Onceden dolu mor bir daireydi; referans arayuzde gonder ciplak
      //	bir ikon. Dokunma alani 44 dp KALIYOR (Material tavani) —
      //	daire gitti, HEDEF GITMEDI.
      // ⚠️ Pasif hal SOLUK BEYAZ: renk degil OPAKLIK degisir, boylece
      //    ikonun yeri/olcusu sabit kalir.
      child: InkWell(
        onTap: hazir ? _gonder : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            LucideIcons.arrowUp,
            // ⚠️ TURU 127 — 22 -> 24: mikrofona gore KUCUK kaliyordu.
            size: 24,
            // ⚠️ TURU 127 — pasif opaklik 0.3 -> **0.55** (kullanici:
            //    *"gonder oku beyaz degil"*). Bos girdide dugme PASIF
            //    oldugu icin soluk ciziliyordu ve ok gri gorunuyordu.
            //    Ayrim KORUNUYOR (aktif 1.0) ama ok artik BEYAZ okunuyor.
            color: Colors.white.withValues(alpha: hazir ? 1.0 : 0.55),
          ),
        ),
      ),
    );
  }
}

/// ⚠️⚠️⚠️ TURU 127 — **DAKTILO DONGUSU** (yaz -> bekle -> sil -> sonraki).
///
/// ⚠️⚠️ **`Timer.periodic` DEGIL, ZINCIRLI `Timer`:** her adimin suresi
///	FARKLI (yazma 45 ms, silme 22 ms, dolu bekleme 1500 ms, bos
///	bekleme 320 ms). Tek bir periyotla bunlari uretmek icin sayac
///	tutmak gerekirdi ve hiz her fazda ayni kalirdi — silme yazmayla
///	ayni hizda olunca efekt "geri sariyor" gibi durur.
///
/// ⚠️ Silme yazmadan HIZLI: gercek daktilo hissi boyledir; esit hizda
///    dongu iki kat uzun surer ve kullanici sikilir.
///
/// ⚠️⚠️ **`substring` KARAKTER DEGIL KOD BIRIMI SAYAR.** Turkce harfler
///	(`ç`, `ı`, `ğ`) BMP icinde ve tek kod birimi — bu listede sorun
///	YOK. Ama listeye emoji ya da BMP disi bir isaret eklenirse
///	`substring` VEKIL CIFTI ORTASINDAN keser ve ekranda bozuk karakter
///	cikar. ⚠️ YAPMA: bu listeye emoji ekleme (zaten arayuzde emoji
///	yasak).
///
/// ⚠️ `dispose`ta zamanlayici IPTAL edilir; edilmezse ekran kapandiktan
///    sonra `setState` cagrilir ve konsola hata duser.
/// ⚠️ Metin BOSKEN bile satir yuksekligi SABIT (`SizedBox(height:)`):
///    aksi halde her dongu basinda karsilama yazisi ASAGI YUKARI ZIPLARDI.
class _OneriDongusu extends StatefulWidget {
  const _OneriDongusu({required this.oneriler, required this.onSec});

  final List<String> oneriler;
  final void Function(String) onSec;

  @override
  State<_OneriDongusu> createState() => _OneriDongusuState();
}

class _OneriDongusuState extends State<_OneriDongusu> {
  static const _yazmaHizi = Duration(milliseconds: 45);
  static const _silmeHizi = Duration(milliseconds: 22);
  static const _doluBekleme = Duration(milliseconds: 1500);
  static const _bosBekleme = Duration(milliseconds: 320);

  Timer? _zaman;
  int _sira = 0;
  int _harf = 0;
  bool _siliyor = false;

  @override
  void initState() {
    super.initState();
    _adim();
  }

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  String get _tam => widget.oneriler[_sira];
  String get _gorunen => _tam.substring(0, _harf);

  void _adim() {
    Duration sonraki;
    if (_siliyor) {
      if (_harf > 0) {
        _harf--;
        sonraki = _silmeHizi;
      } else {
        _siliyor = false;
        _sira = (_sira + 1) % widget.oneriler.length;
        sonraki = _bosBekleme;
      }
    } else {
      if (_harf < _tam.length) {
        _harf++;
        sonraki = _harf < _tam.length ? _yazmaHizi : _doluBekleme;
      } else {
        _siliyor = true;
        sonraki = _silmeHizi;
      }
    }
    if (mounted) setState(() {});
    _zaman = Timer(sonraki, _adim);
  }

  @override
  Widget build(BuildContext context) {
    final beyaz = Colors.white;
    return Semantics(
      button: true,
      // ⚠️ Ekran okuyucuya YAZILMAKTA OLAN yarim metin degil, TAM soru
      //    okunur; yarim metin duyulunca anlamsiz olurdu.
      label: 'Örnek soru: ${_tam}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // ⚠️ TAM metin gonderilir, ekrandaki YARIM metin degil.
        onTap: () => widget.onSec(_tam),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: SizedBox(
            // ⚠️ Sabit yukseklik: metin bosalinca satir cokmesin.
            height: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.trendingUp,
                  size: 17,
                  color: beyaz.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 8),
                // ⚠️ `Flexible` ZORUNLU: daktilo metni buyurken satir
                //    dar ekranda tasardi.
                Flexible(
                  child: Text(
                    _gorunen,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: beyaz.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                // ⚠️ Imlec: daktilo hissini tamamlar. Yanip SONMEZ —
                //    sonen bir imlec ikinci bir zamanlayici ister ve
                //    hicbir sey kazandirmaz.
                Container(
                  width: 1.5,
                  height: 16,
                  margin: const EdgeInsets.only(left: 2),
                  color: beyaz.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

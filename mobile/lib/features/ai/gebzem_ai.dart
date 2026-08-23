library;

import 'dart:io';

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
import '../medya/medya_servisi.dart';

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
    setState(() => _eklenen = File(x!.path));
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
      _calisiyor = true;
    });
    _dibeKaydir();

    try {
      var mediaId = '';
      if (gorsel != null) {
        final hazir = await MedyaServisi.gorseliHazirla(gorsel);
        if (hazir == null) throw Exception('Görsel hazırlanamadı');
        mediaId = await medyaSvc.yukle(
          dosya: hazir,
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
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: morLogo,
          brightness: Brightness.dark,
        ).copyWith(surface: _kAiZeminUst),
        scaffoldBackgroundColor: Colors.transparent,
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
              onPressed: () => Navigator.of(context).maybePop(),
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
                        padding: const EdgeInsets.fromLTRB(
                          kYanBosluk,
                          12,
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
    final selam = ad.isEmpty
        ? 'Sana hangi konuda yardımcı olabilirim?'
        : '$ad, sana hangi konuda yardımcı olabilirim?';

    // ⚠️ TURU 127 — **IKON KALDIRILDI** (kullanici emri). Ekranin
    //    ortasinda yalnizca soru duruyor.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          selam,
          textAlign: TextAlign.center,
          // ⚠️ TURU 127 — w400 -> **w500** (kullanici: *"ekrandaki yaziyi
          //    1 tik kalinlastir"*). w600 fazla resmi durdu.
          style: const TextStyle(
            fontSize: 27,
            height: 1.3,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
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
                  Text(m.metin, style: const TextStyle(fontSize: 15)),
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
            style: const TextStyle(fontSize: 15, height: 1.42),
          ),
          const SizedBox(height: 4),
          // ⚠️ KOPYALA: uzun yanitlari elle secmek zor; tek dokunusla panoya.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: m.metin));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Kopyalandı')));
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(LucideIcons.copy, size: 14),
              label: const Text('Kopyala', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️ Bu bir BEKLEME gostergesidir, akan metin DEGIL (sunucu tek parca
  ///    donduruyor). Yaniltmamak icin yaninda "yazıyor" yazar.
  /// ⚠️⚠️ TURU 127 — **YENI SOHBET ONAY ISTER** (kullanici emri:
  ///	*"alert versin, yeni sohbetin acilacagi ve eskisinin gidecegine
  ///	dair"*).
  ///
  /// ⚠️ Onay GERCEKTEN gerekli: sohbet **HICBIR YERDE SAKLANMIYOR**
  ///    (sunucuda tablo yok). Temizlenen konusma GERI GETIRILEMEZ —
  ///    geri alinamayan bir eylem onaysiz calismamali.
  /// ⚠️ Metin ne olacagini ACIKCA soyler; "Emin misin?" gibi bos bir
  ///    soru kullaniciya NE KAYBEDECEGINI anlatmaz.
  Future<void> _yeniSohbetSor() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni sohbet'),
        content: const Text(
          'Yeni bir sohbet başlayacak ve bu konuşma silinecek. '
          'Sohbetler kaydedilmediği için geri getirilemez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Yeni sohbet'),
          ),
        ],
      ),
    );
    // ⚠️ `mounted` kapisi ZORUNLU: diyalog acikken ekran sokulmus olabilir.
    if (onay != true || !mounted) return;
    setState(() {
      _mesajlar.clear();
      _eklenen = null;
    });
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
          // ---- EKLENEN FOTOGRAF ONIZLEMESI
          if (_eklenen != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _eklenen!,
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // ⚠️ Kaldirma dugmesi 28 dp: turu 78b'de 17 dp olcusu
                    //    "dokunulamiyor" diye duzeltilmisti.
                    Positioned(
                      right: -8,
                      top: -8,
                      child: IconButton(
                        iconSize: 16,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(LucideIcons.circleX),
                        onPressed: () => setState(() => _eklenen = null),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          _girisKutusu(scheme),
        ],
      ),
    ),
  );

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
          // ── YAZI (USTTE) ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _odak.requestFocus(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 2),
              child: TextField(
                controller: _yazac,
                focusNode: _odak,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 16, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'GebzemAI’a sorun',
                  hintStyle: TextStyle(
                    fontSize: 16,
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
                    size: 23,
                    color: _calisiyor
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                  onPressed: _calisiyor ? null : _gorselSec,
                ),
                const Spacer(),
                // ⚠️⚠️ **MIKROFON: SESLI SORU HENUZ YOK.** Ikon kullanici
                //	emriyle cizildi ama sesten metne ceviren bir yol
                //	(ne istemcide ne sunucuda) YOK. Bu yuzden dokunus
                //	DURUSTCE "yakinda" der — sessizce hicbir sey yapan
                //	bir dugme "bozuk" diye okunur.
                // ⚠️ YAPMA: bu bildirimi kaldirip dugmeyi ISLEVSIZ birakma.
                IconButton(
                  tooltip: 'Sesli soru',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: Icon(
                    LucideIcons.mic,
                    size: 21,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  onPressed: () => rootMessengerKey.currentState
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Sesli soru yakında eklenecek.'),
                      ),
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
        !_calisiyor && (_yazac.text.trim().isNotEmpty || _eklenen != null);
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
            size: 22,
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

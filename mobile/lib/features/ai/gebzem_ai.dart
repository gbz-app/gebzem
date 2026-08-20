library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
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

class _GebzemAiEkraniState extends ConsumerState<GebzemAiEkrani> {
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

    return Scaffold(
      appBar: AppBar(
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
          if (acik && _mesajlar.isNotEmpty)
            IconButton(
              tooltip: 'Yeni sohbet',
              icon: const Icon(LucideIcons.squarePen),
              onPressed: _calisiyor
                  ? null
                  : () => setState(() {
                      _mesajlar.clear();
                      _eklenen = null;
                    }),
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
          color: Theme.of(context).colorScheme.onSurface.withValues(
            alpha: 0.75,
          ),
        ),
      ),
    ),
  );

  /// Bos ekran: selamlama + oneri cipleri.
  ///
  /// ⚠️ Oneriler SABIT ve GENEL: kullanicinin verisine gore "kisisellestirilmis"
  ///    oneri uretecek bir uc YOK, uydurma bir kisisellik iddia etmiyoruz.
  Widget _karsilama(AiDurum? ai) {
    final scheme = Theme.of(context).colorScheme;
    // ⚠️ TURU 117 — her oneri kendi IKONUNU tasir. Kayit (record) tipi:
    //    ayri bir sinif acmak bu dort satir icin agir olurdu.
    const oneriler = <(String, IconData)>[
      ('Gebze’de hafta sonu ne yapılır?', LucideIcons.mapPin),
      ('Bu fotoğraftaki arıza ne olabilir?', LucideIcons.wrench),
      ('Kısa bir ilan metni yaz', LucideIcons.penLine),
      ('Ev taşırken nelere dikkat etmeliyim?', LucideIcons.truck),
    ];
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 28, kYanBosluk, 20),
      children: [
        // ── MARKA ROZETI ──
        // ⚠️ Gradyan `kHikayeHalkaGradient` DEGIL marka moru: bu bir
        //    HIKAYE halkasi degil, urun rozeti.
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.65),
                ],
              ),
            ),
            child: Icon(
              LucideIcons.sparkles,
              size: 30,
              color: scheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Merhaba, ben GebzemAI',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Bir şey sor ya da fotoğraf ekle.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 26),
        // ── ONERILER ──
        // ⚠️ Her onerinin KENDI IKONU var: dort ayni cerceve "liste" gibi
        //    duruyordu, ikon onlari DOKUNULABILIR birer eylem yapiyor.
        // ⚠️ Sagdaki ok da ayni isi yapar (bu bir yazi degil, bir dugme).
        for (var i = 0; i < oneriler.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  _yazac.text = oneriler[i].$1;
                  _gonder();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          oneriler[i].$2,
                          size: 17,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          oneriler[i].$1,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.arrowUpRight,
                        size: 16,
                        color: scheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        // ── KALAN HAK KARTI ──
        // ⚠️⚠️ Kullanici emri: *"kalan hak vb altta daha guzel anlasilir
        //	sekilde olsun"*. Eskiden %45 saydam 12,5 px gri bir satirdi —
        //	yani ekrandaki EN ONEMLI sayi EN SILIK ogeydi.
        // ⚠️ Sayi UYDURULMAZ: `ai.kalan`/`ai.kota` sunucudan gelir; `ai`
        //    null ise kart HIC cizilmez (yer tutucu sayi YAZILMAZ).
        if (ai != null) _kalanHakKarti(ai, scheme),
        const SizedBox(height: 12),
        // ⚠️ DURUST SINIR EKRANDA YAZILI (bkz. sinif serhi).
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.info,
              size: 13,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Sohbet kaydedilmez; ekrandan çıkınca konuşma biter.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ],
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
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'GebzemAI',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kopyalandı')),
                );
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
  Widget _yaziyor(ColorScheme scheme) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          'GebzemAI yazıyor…',
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    ),
  );

  Widget _yazacAlani(ColorScheme scheme) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 6, kYanBosluk, 8),
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
  Widget _girisKutusu(ColorScheme scheme) {
    final odakli = _odak.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: odakli
              ? scheme.primary.withValues(alpha: 0.85)
              : scheme.onSurface.withValues(alpha: 0.12),
          // ⚠️ Kalinlik ODAKTA da 1.5 KALIR: 1 -> 2 gecisi kutunun ic
          //    olcusunu degistirir ve yazi 1 px ZIPLAR.
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── YAZI (USTTE) ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _odak.requestFocus(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _yazac,
                focusNode: _odak,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Bir şey sor…',
                  isDense: true,
                  // ⚠️ Kenarliklar KUTUNUN kendisinde; `TextField` KENDI
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
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                // ⚠️ TURU 117 — ikon `imagePlus` -> **`imageUp`**
                //    (kullanici: *"daha guzel icon yap"*). `imageUp`
                //    "gorsel YUKLE" anlamini tasir; `imagePlus` daha cok
                //    "galeriye ekle" gibi okunuyordu.
                IconButton(
                  tooltip: 'Fotoğraf ekle',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: Icon(
                    LucideIcons.imageUp,
                    size: 21,
                    color: _calisiyor
                        ? scheme.onSurface.withValues(alpha: 0.3)
                        : scheme.onSurface.withValues(alpha: 0.7),
                  ),
                  onPressed: _calisiyor ? null : _gorselSec,
                ),
                const Spacer(),
                // ⚠️ Gonder dugmesi bos girdide PASIF: bos istek kota yakardi.
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
            bitti
                ? 'Yarın sıfırlanır.'
                : 'Her gün sıfırlanır.',
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
      child: InkWell(
        onTap: hazir ? _gonder : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hazir
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.12),
          ),
          child: Icon(
            LucideIcons.arrowUp,
            size: 20,
            color: hazir ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

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
  final _mesajlar = <_Mesaj>[];
  File? _eklenen;
  bool _calisiyor = false;

  @override
  void dispose() {
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
        title: const Text('GebzemAI'),
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
  Widget _kapali() => const Center(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Text(
        'Yapay zekâ şu anda kullanılamıyor.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      ),
    ),
  );

  /// Bos ekran: selamlama + oneri cipleri.
  ///
  /// ⚠️ Oneriler SABIT ve GENEL: kullanicinin verisine gore "kisisellestirilmis"
  ///    oneri uretecek bir uc YOK, uydurma bir kisisellik iddia etmiyoruz.
  Widget _karsilama(AiDurum? ai) {
    final scheme = Theme.of(context).colorScheme;
    const oneriler = [
      'Gebze’de hafta sonu ne yapılır?',
      'Bu fotoğraftaki arıza ne olabilir?',
      'Kısa bir ilan metni yaz',
      'Ev taşırken nelere dikkat etmeliyim?',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 40, kYanBosluk, 20),
      children: [
        Icon(LucideIcons.sparkles, size: 34, color: scheme.primary),
        const SizedBox(height: 14),
        const Text(
          'Merhaba, ben GebzemAI',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Bir şey sor ya da fotoğraf ekle.',
          style: TextStyle(
            fontSize: 15,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 22),
        for (final o in oneriler)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                _yazac.text = o;
                _gonder();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(o, style: const TextStyle(fontSize: 14.5)),
              ),
            ),
          ),
        if (ai != null) ...[
          const SizedBox(height: 10),
          Text(
            'Bugün kalan hakkın: ${ai.kalan}/${ai.kota}',
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          // ⚠️ DURUST SINIR EKRANDA YAZILI (bkz. sinif serhi).
          'Sohbet kaydedilmez; ekrandan çıkınca konuşma biter.',
          style: TextStyle(
            fontSize: 12.5,
            color: scheme.onSurface.withValues(alpha: 0.45),
          ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Fotoğraf ekle',
                icon: const Icon(LucideIcons.imagePlus),
                onPressed: _calisiyor ? null : _gorselSec,
              ),
              Expanded(
                child: TextField(
                  controller: _yazac,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Bir şey sor…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ⚠️ Gonder dugmesi bos girdide PASIF: bos istek kota yakardi.
              _gonderDugmesi(scheme),
            ],
          ),
        ],
      ),
    ),
  );

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

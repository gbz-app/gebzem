import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

class StorySeridiDurumu extends ConsumerState<StorySeridi> {
  List<StoryKullanici>? _liste;
  bool _yukleniyor = false;
  double? _ilerleme;

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

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
      final mediaId = await ref
          .read(medyaServisiProvider)
          .yukle(
            dosya: dosya,
            kind: video ? 'video' : 'image',
            mime: video ? 'video/mp4' : 'image/jpeg',
            fileName: x.name,
            ilerleme: (p) {
              if (mounted) setState(() => _ilerleme = p);
            },
          );
      await ref
          .read(storyServisiProvider)
          .paylas(
            mediaId: mediaId,
            kind: video ? 'video' : 'image',
            katmanlar: cikti.katmanlar,
          );
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _ilerleme = null;
      });
      await yukle();
      if (mounted) _uyar('Hikâyen paylaşıldı');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _ilerleme = null;
      });
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
          // ⚠️ Halkayi ANINDA griye cevir — sunucuyu tekrar sormaya gerek yok
          //    (izlendi zaten atesle-unut olarak gonderildi).
          onIzlendi: () {
            if (mounted) setState(() => k.hepsiIzlendi = true);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    final benimProfil = ref.watch(myProfileProvider).valueOrNull;
    final benim = l?.where((e) => e.benim).firstOrNull;
    final digerleri = (l ?? const <StoryKullanici>[])
        .where((e) => !e.benim)
        .toList();

    return SizedBox(
      height: 106,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              child: Avatar(
                ad: ad,
                mediaId: profil?['avatar_media_id'] as String?,
                avatarUrl: (profil?['avatar_url'] ?? '').toString(),
                cap: 60,
              ),
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
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: _paylasSecenek,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
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

  Widget _kutu({required String etiket, required Widget child}) => SizedBox(
    width: 74,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 5),
        Text(
          etiket,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
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

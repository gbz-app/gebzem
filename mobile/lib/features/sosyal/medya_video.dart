import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:video_player/video_player.dart';

import '../medya/medya_kapisi.dart';
import '../medya/medya_gorsel.dart';
import '../medya/medya_servisi.dart';
import '../medya/ses_notu_kontrol.dart';

/// ⚠️⚠️ TURU 75 — GONDERI/REELS VIDEO OYNATICI.
///
/// ⚠️⚠️⚠️ iOS SES OTURUMU — BU DOSYANIN VAROLUS SEBEBI:
///   `video_player` iOS'ta varsayilan olarak `AVAudioSession` kategorisini
///   `.playback` yapar. O kategori **DIGER SESI KESER** — yani bir gonderi
///   videosu, SUREN LiveKit aramasinin/odanin sesini OLDURUR. Bu projede ayni
///   sinif hata (process-global ses oturumu) turu 64/65/73'te defalarca yasandi.
///
///   UC KATMANLI SAVUNMA:
///   (1) `VideoPlayerOptions(mixWithOthers: true)` — oturumu ELE GECIRMEZ.
///   (2) `MedyaKapisi.donanimSerbest` false ise ses ZORLA kapatilir (mixWithOthers
///       "karistir" demek; kullanici arama sesiyle reel sesini AYNI ANDA duymasin).
///   (3) `SesNotuKontrol` defterine kaydolur — arama/oda/yayin BASLARKEN
///       `sustur()` cagriliyor (5 giris noktasinda `await` ile) ve oynatma DURUR.
///
/// ⚠️ YAPMA: `mixWithOthers: true`yi kaldirma.
/// ⚠️ YAPMA: `SesNotuKontrol.kaydol/birak` cagrilarini kaldirma.
/// ⚠️ YAPMA: bu widget'i `SesSahipligi`ne kaydetme — o defter
///    `setAudioEnabled(false)` kararini suruyor; video oynatici WebRTC ses birimi
///    DEGILDIR ve oraya yazilirsa `aramaCanli` YALAN soyler (bkz. ses_notu_kontrol).
class MedyaVideo extends ConsumerStatefulWidget {
  const MedyaVideo({
    super.key,
    required this.mediaId,
    this.kapakMediaId,
    this.otoOynat = false,
    this.dongu = true,
    this.sesli = false,
    this.dolgu = BoxFit.contain,
    this.kontrolGoster = true,
  });

  final String mediaId;

  /// Kucuk resim — video hazir olana kadar gosterilir (siyah kare yerine).
  final String? kapakMediaId;

  /// Gorunur olunca kendiliginden oynasin mi (akista SESSIZ, reels'te SESLI).
  final bool otoOynat;
  final bool dongu;

  /// Baslangicta sesli mi. ⚠️ Akista DAIMA `false` — kaydirirken aniden ses
  ///    patlamasi (Instagram/Facebook davranisi da sessiz otomatik oynatma).
  final bool sesli;
  final BoxFit dolgu;
  final bool kontrolGoster;

  @override
  ConsumerState<MedyaVideo> createState() => _MedyaVideoState();
}

class _MedyaVideoState extends ConsumerState<MedyaVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _c;
  bool _hazir = false;
  bool _hata = false;
  bool _sesli = false;
  bool _kullaniciDurdurdu = false;

  /// ⚠️ Kurulum ASENKRON (imzali adres + `initialize()`); bu arada widget dispose
  ///    olabilir ya da `mediaId` degisebilir. Her await sonrasi bu jeton kontrol
  ///    edilir — bu projede "bayat async" hatalarinin TEK caresi (turu 19 dersi).
  int _nesil = 0;

  @override
  void initState() {
    super.initState();
    _sesli = widget.sesli;
    WidgetsBinding.instance.addObserver(this);
    _kur();
  }

  @override
  void didUpdateWidget(covariant MedyaVideo eski) {
    super.didUpdateWidget(eski);
    if (eski.mediaId != widget.mediaId) {
      _birak();
      _kur();
    } else if (eski.otoOynat != widget.otoOynat) {
      // PageView'de sayfa degisti: gorunur olan oynar, olmayan DURUR.
      if (widget.otoOynat) {
        _kullaniciDurdurdu = false;
        _oynat();
      } else {
        _c?.pause();
        _c?.seekTo(Duration.zero);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    // ⚠️ Arka planda video oynatmak YOK: pil + veri harcar, ustelik iOS'ta
    //    ses oturumunu arka planda tutmaya calisir. `inactive` DE dahil degil —
    //    o durumdan (bildirim merkezi/app switcher) donuste devam etmeli.
    if (durum == AppLifecycleState.paused ||
        durum == AppLifecycleState.detached) {
      _c?.pause();
    } else if (durum == AppLifecycleState.resumed &&
        widget.otoOynat &&
        !_kullaniciDurdurdu) {
      _oynat();
    }
  }

  Future<void> _kur() async {
    final nesil = ++_nesil;
    setState(() {
      _hazir = false;
      _hata = false;
    });
    try {
      final bilgi = await ref.read(medyaServisiProvider).adres(widget.mediaId);
      if (!mounted || nesil != _nesil) return;
      final url = (bilgi['url'] ?? '').toString();
      if (url.isEmpty) throw Exception('adres bos');

      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        // ⚠️⚠️ ZORUNLU — bkz. dosya basligi. Kaldirilirsa suren aramanin sesi olur.
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await c.initialize();
      if (!mounted || nesil != _nesil) {
        unawaited(c.dispose());
        return;
      }
      await c.setLooping(widget.dongu);
      _c = c;
      setState(() => _hazir = true);
      if (widget.otoOynat) _oynat();
    } catch (e) {
      if (!mounted || nesil != _nesil) return;
      setState(() => _hata = true);
      unawaited(Sentry.captureMessage('gonderi video acilamadi: $e'));
    }
  }

  /// ⚠️ SES KARARI TEK YERDE: arama/oda/yayin/GSM canliysa ses KAPALI.
  ///    Her oynatmadan once YENIDEN degerlendirilir (kullanici video acikken
  ///    arama kabul edebilir).
  bool get _sesVerilebilir =>
      _sesli && MedyaKapisi.donanimSerbest(ref) && !MedyaKapisi.pickerAcik;

  Future<void> _oynat() async {
    final c = _c;
    if (c == null || !mounted) return;
    await c.setVolume(_sesVerilebilir ? 1.0 : 0.0);
    // ⚠️ Ses CIKARACAKSAK defterine kaydol: arama baslarken `sustur()` bizi durdurur.
    //    Sessiz oynatma ses oturumuna DOKUNMAZ — defteri gereksiz mesgul etme.
    if (_sesVerilebilir) {
      SesNotuKontrol.kaydol(this, () async {
        await _c?.pause();
        if (mounted) setState(() => _sesli = false);
      });
    } else {
      SesNotuKontrol.birak(this);
    }
    await c.play();
    if (mounted) setState(() {});
  }

  Future<void> _sesiCevir() async {
    if (!_sesli && !MedyaKapisi.donanimSerbest(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Görüşme sürüyor — video sesi açılamaz'),
      ));
      return;
    }
    setState(() => _sesli = !_sesli);
    await _c?.setVolume(_sesVerilebilir ? 1.0 : 0.0);
    if (_sesVerilebilir) {
      SesNotuKontrol.kaydol(this, () async {
        await _c?.pause();
        if (mounted) setState(() => _sesli = false);
      });
    } else {
      SesNotuKontrol.birak(this);
    }
  }

  void _duraklatCevir() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      _kullaniciDurdurdu = true;
      c.pause();
    } else {
      _kullaniciDurdurdu = false;
      _oynat();
    }
    setState(() {});
  }

  void _birak() {
    _nesil++; // ucan kurulumu gecersiz kil
    SesNotuKontrol.birak(this);
    final c = _c;
    _c = null;
    _hazir = false;
    unawaited(c?.dispose());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _birak();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return GestureDetector(
      onTap: widget.kontrolGoster ? _duraklatCevir : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Kapak: video hazir DEGILKEN gorunur. Siyah kare yerine gercek kare —
          // kaydirirken "bos delik" hissi olmasin.
          if (!_hazir && widget.kapakMediaId != null)
            MedyaGorsel(mediaId: widget.kapakMediaId!, kucuk: true, fit: widget.dolgu),
          if (_hazir && c != null)
            FittedBox(
              fit: widget.dolgu,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          if (!_hazir && !_hata)
            const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_hata)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.circleAlert, color: Colors.white70),
                  SizedBox(height: 6),
                  Text('Video açılamadı',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          if (_hazir && c != null && !c.value.isPlaying && widget.kontrolGoster)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0x66000000), shape: BoxShape.circle),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(LucideIcons.play, color: Colors.white, size: 28),
                ),
              ),
            ),
          if (_hazir && widget.kontrolGoster)
            Positioned(
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: _sesiCevir,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                      color: Color(0x66000000), shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      _sesVerilebilir
                          ? LucideIcons.volume2
                          : LucideIcons.volumeOff,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          if (_hazir && c != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: widget.kontrolGoster,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF8B5CF6),
                  bufferedColor: Color(0x33FFFFFF),
                  backgroundColor: Color(0x22FFFFFF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

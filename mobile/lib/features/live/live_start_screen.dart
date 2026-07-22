import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api.dart';
import '../calls/call_media_options.dart';
import '../calls/call_provider.dart';
import 'live_broadcast_screen.dart';
import 'live_provider.dart';

/// Yayin baslatma: kamera ONIZLEME (Room'suz, CallRoomLock DISI — ses birimine dokunmaz)
/// + baslik + "Yayina basla". Baslarken onizleme track'i tamamen birakilir; yayin odasi
/// SIFIR track'le kilit icinde kurulur (plan karari).
class LiveStartScreen extends ConsumerStatefulWidget {
  const LiveStartScreen({super.key});

  @override
  ConsumerState<LiveStartScreen> createState() => _LiveStartScreenState();
}

class _LiveStartScreenState extends ConsumerState<LiveStartScreen> {
  final _baslik = TextEditingController();
  lk.LocalVideoTrack? _onizleme;
  bool _basliyor = false;
  int? _geriSayim; // 3-2-1 geri sayim (test turu 9): null iken gizli
  String? _hata;
  // Muhafiz kimligi: onizleme fiziksel kamerayi tutar — bu ekrandayken gelen arama kabul
  // edilirse iki capture oturumu cakisir (dogrulama bulgusu). ekranAcildi ile aramalar
  // otomatik "mesgul" olur (CallKit kabulu answer-null -> bitir+reddet yoluna duser).
  static const _muhafizId = 'yayin-onizleme';
  // KOK FIX (dogrulama hukmu, KESIN): dispose() icinde ref.read KULLANILAMAZ —
  // flutter_riverpod 2.6.1 _assertNotDisposed KOSULSUZ StateError firlatiyor; ekranKapandi
  // HIC calismiyor, 'yayin-onizleme' muhafizi KALICI sizip tum arama/oda/yayin girislerini
  // "Once aramayi/odayi bitirin"e kilitliyor + gelen aramalari otomatik reddettiriyordu
  // (kullanicinin "oturum kapatilmadi, restart duzeltiyor" sorunu). Servis initState'te
  // YAKALANIR (call_screen deseni), dispose ondan kullanir.
  late final CallService _svc;

  @override
  void initState() {
    super.initState();
    _svc = ref.read(callServiceProvider.notifier);
    _svc.ekranAcildi(_muhafizId);
    _onizlemeBaslat();
  }

  Future<void> _onizlemeBaslat() async {
    final izinler = await [Permission.camera, Permission.microphone].request();
    if (izinler[Permission.camera] != PermissionStatus.granted ||
        izinler[Permission.microphone] != PermissionStatus.granted) {
      setState(() => _hata = 'Yayın için kamera ve mikrofon izni gerekli');
      return;
    }
    try {
      final t = await lk.LocalVideoTrack.createCameraTrack(kCameraCaptureOptions);
      if (!mounted) {
        await t.stop();
        await t.dispose();
        return;
      }
      setState(() => _onizleme = t);
    } catch (e) {
      if (mounted) setState(() => _hata = 'Kamera açılamadı');
    }
  }

  Future<void> _onizlemeBirak() async {
    final t = _onizleme;
    _onizleme = null;
    try {
      await t?.stop();
      await t?.dispose();
    } catch (_) {}
  }

  Future<void> _basla() async {
    if (_basliyor) return;
    final svc = _svc;
    // Kendi muhafiz kaydimiz haric baska arama/oda var mi
    if (svc.baskaIsleMesgul(_muhafizId)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Önce aramayı/odayı bitirin')));
      return;
    }
    setState(() => _basliyor = true);
    // GERI SAYIM (test turu 9): yayin SUNUCUDA acilmadan ONCE ortada 3-2-1 say. Yayin REST'i
    // (baslat) henuz cagirilmadigi icin izleyici erken katilamaz, hayalet 'live' riski yok;
    // kamera onizlemesi zaten canli akiyor. Sunucu-tarafi degismez (yalniz gorsel gecikme).
    for (var i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _geriSayim = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _geriSayim = null);
    // Geri sayim sirasinda arama gelip kabul edilmis olabilir -> yayina girme (muhafiz tekrari)
    if (svc.baskaIsleMesgul(_muhafizId)) {
      setState(() => _basliyor = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aramadasınız — yayın başlatılmadı')));
      return;
    }
    String? acilanYayin;
    try {
      final info = await ref
          .read(liveApiProvider)
          .baslat(_baslik.text.trim().isEmpty ? 'Canlı yayın' : _baslik.text.trim());
      final id = info['stream_id'] as String;
      acilanYayin = id;
      // MUHAFIZ TEKRARI + mounted (dogrulama bulgusu): REST surerken ekran kapandiysa veya
      // arama kabul edildiyse sunucudaki yayini GERI KAPAT — hayalet 'live' yayin +
      // pushReplacement'in kabul edilen CallScreen'i sokmesi onlenir.
      if (!mounted || svc.baskaIsleMesgul(_muhafizId)) {
        unawaited(ref.read(liveApiProvider).bitir(id));
        if (mounted) {
          setState(() => _basliyor = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aramadasınız — yayın başlatılmadı')));
        }
        return;
      }
      // SAHIPLIK DEVRI (P1 kok fix, hukum A1): onizleme track'i BIRAKILMAZ — yayin ekranina
      // devredilip publishVideoTrack ile AYNEN yayinlanir. Eski yol (birak -> yeniden ac)
      // Android'de kamera kapanis/acilis YARISI yuzunden ILK yayinda videoyu olduruyordu
      // (flutter_webrtc waitForCameraOpen ERROR'da da donuyor -> sessiz OLU track; kanit:
      // stream_0fd65863'te video hic publish edilmedi). Muhafiz/mounted dallarinda devir
      // YAPILMAZ (oralarda dispose -> _onizlemeBirak normal salar).
      final devir = _onizleme;
      _onizleme = null; // dispose artik dokunmaz (setState YOK — ekran zaten degisiyor)
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        settings: RouteSettings(name: 'yayin-$id'),
        builder: (_) => LiveBroadcastScreen(
          streamId: id,
          lkRoom: info['room'] as String,
          url: info['url'] as String,
          token: info['token'] as String,
          baslik: info['title'] as String? ?? '',
          onizlemeTrack: devir,
        ),
      ));
    } catch (e) {
      if (acilanYayin != null) {
        unawaited(ref.read(liveApiProvider).bitir(acilanYayin));
      }
      if (mounted) {
        setState(() => _basliyor = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  void dispose() {
    _svc.ekranKapandi(_muhafizId); // ref DEGIL cache — ref burada StateError firlatiyordu
    _baslik.dispose();
    _onizlemeBirak();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: Stack(children: [
        Positioned.fill(
          child: _onizleme != null
              ? IgnorePointer(
                  child: lk.VideoTrackRenderer(_onizleme!,
                      key: ValueKey('onizleme-${_onizleme!.sid}'),
                      fit: lk.VideoViewFit.cover))
              : Center(
                  child: _hata != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_hata!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 16)))
                      : const CircularProgressIndicator()),
        ),
        // GERI SAYIM overlay (test turu 11: TAM ORTADA, DAIRE/BORDER YOK — temiz buyuk rakam).
        // Positioned.fill + Center -> ekranin tam ortasi. Daire kaldirildi (kullanici: "beyaz
        // border vs olamayacak"); yalniz mor parilti golgesi + pop animasyonu.
        if (_geriSayim != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_geriSayim),
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (_, olcek, child) => Transform.scale(
                      scale: olcek,
                      child: Opacity(opacity: olcek.clamp(0.0, 1.0), child: child)),
                  child: Text('$_geriSayim',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 140,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: Color(0xFF8B3FFF), blurRadius: 32),
                          ])),
                ),
              ),
            ),
          ),
        SafeArea(
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white),
                // REST surerken/geri sayimda cikis kapali (yarim kalan yayin olusmasin)
                onPressed: _basliyor ? null : () => Navigator.of(context).pop(),
              ),
              const Text('Canlı yayın',
                  style: TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ]),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(children: [
                TextField(
                  controller: _baslik,
                  maxLength: 80,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Yayın başlığı (isteğe bağlı)',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: (_onizleme == null || _basliyor) ? null : _basla,
                    icon: _basliyor
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.radioTower),
                    label: const Text('Yayına başla',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/api.dart';
import '../invites/davet_sec_sheet.dart';
import '../calls/call_media_options.dart';
import '../calls/call_provider.dart';
import '../calls/call_room_lock.dart';
import 'live_info_sheets.dart';
import 'live_provider.dart';
import 'live_widgets.dart';

/// YAYINCI ekrani: kendi kamerasi tam ekran + izleyici sayaci + chat/hediye seridi.
/// Medya yolu 1:1 aramayla AYNI kanitlanmis desen (CallRoomLock + iOS ses sirasi + relay +
/// 720p VP8 simulcast profili). Sinyaller SendData'dan gelir (dinleme salt-okunur; yayinci
/// data YAYINLAYAMAZ — chat'i de REST'ten atar).
class LiveBroadcastScreen extends ConsumerStatefulWidget {
  const LiveBroadcastScreen({
    super.key,
    required this.streamId,
    required this.lkRoom,
    required this.url,
    required this.token,
    required this.baslik,
    this.onizlemeTrack,
  });

  final String streamId;
  final String lkRoom;
  final String url;
  final String token;
  final String baslik;
  // P1 fix (hukum A1/A2): baslatma ekranindan DEVRALINAN canli kamera track'i —
  // kamera kapat/ac yarisina girmeden publishVideoTrack ile aynen yayinlanir.
  final lk.LocalVideoTrack? onizlemeTrack;

  @override
  ConsumerState<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends ConsumerState<LiveBroadcastScreen>
    with WidgetsBindingObserver {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  Timer? _nabiz;
  final _kalpKey = GlobalKey<KalpKatmaniState>();
  final List<ChatMesaj> _mesajlar = [];
  // Sayac-anahtarli hediye animasyonlari (dogrulama bulgusu: indexOf/ozdes-string key'leri
  // ayni emoji iki kez gelince cakisiyordu / silinince animasyonlar bastan basliyordu)
  final List<MapEntry<int, String>> _hediyeler = [];
  int _hediyeSayac = 0;
  int _izleyici = 0;
  int _jeton = 0; // bu yayinda toplanan jeton (gift sinyallerinden; yayin 0'la baslar)
  final Set<String> _istekIds = {}; // bekleyen katil istekleri (rozet; Bolum 6 I4)
  String _konukId = ''; // aktif konuk (guest.joined/left sinyalinden)
  String _konukAdi = '';
  bool _micOn = true;
  bool _onKamera = true; // ayna kurali: on=aynali, arka=aynasiz ("kamera ters" fix'i)
  bool _connecting = true;
  lk.LocalVideoTrack? _devralinan; // onizlemeden devralinan track (P1)
  bool _videoYayinda = false; // devralinan publish edildi mi (salivermede kullanilir)
  bool _ayrildi = false;
  bool _kapandi = false;
  String? _hata;

  late final CallService _svc;
  final _chatCtrl = TextEditingController();
  static const _audioCh = MethodChannel('gebzem/audio');

  @override
  void initState() {
    super.initState();
    _svc = ref.read(callServiceProvider.notifier);
    _svc.ekranAcildi('yayin_${widget.streamId}'); // arama muhafizi
    _devralinan = widget.onizlemeTrack; // P1: onizlemeden devralinan kamera
    WidgetsBinding.instance.addObserver(this);
    _baglan(); // nabiz timer'i BAGLANTI BASARILI olunca baslar (dogrulama bulgusu:
    // connect patlarsa nabiz sunucuda hayalet 'live' yayini ayakta tutuyordu)
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_ayrildi) {
      _sesiAc(true); // kesinti toparlama (GSM/Siri)
      ref.read(liveApiProvider).nabiz(widget.streamId).catchError((_) {});
    }
  }

  Future<void> _baglan() async {
    try {
      await CallRoomLock.calistir(_odayaBaglan);
      if (mounted) {
        setState(() => _connecting = false);
        _nabiz = Timer.periodic(const Duration(seconds: 15),
            (_) => ref.read(liveApiProvider).nabiz(widget.streamId).catchError((_) {}));
        _videoSagligiKur(); // A3 guvenlik agi: kare akmiyorsa TEK restartTrack
      }
    } catch (e) {
      await Sentry.captureException(e, stackTrace: StackTrace.current);
      // Baglanti kurulamadi: yayini sunucuda da kapat (hayalet 'live' kalmasin)
      try {
        await ref.read(liveApiProvider).bitir(widget.streamId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _hata = 'Yayına bağlanılamadı.\nTekrar deneyin.';
          _connecting = false;
        });
      }
    }
  }

  Future<void> _odayaBaglan() async {
    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: kCameraCaptureOptions, // 720p (1:1 profili aynen)
        defaultVideoPublishOptions: kVideoPublishOptions, // VP8+simulcast+balanced
        defaultAudioCaptureOptions: kAudioCaptureOptions,
        defaultAudioPublishOptions: kAudioPublishOptions,
      ),
    );
    _room = room;
    try {
      _listener = room.createListener();
      _listener!
        ..on<lk.DataReceivedEvent>(_veriGeldi)
        ..on<lk.LocalTrackPublishedEvent>((_) {
          if (mounted) setState(() {});
        })
        // KONUK track'leri (Bolum 6 I4): bu listener'lar olmadan konuk PiP render'i
        // HIC tetiklenmez (yayincida ilk kez uzak video var).
        ..on<lk.TrackSubscribedEvent>((e) {
          if (!mounted) return;
          setState(() {});
          if (e.track is lk.VideoTrack) {
            // Ilk-kare texture tekmesi (viewer/call_screen deseni)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) setState(() {});
            });
          }
        })
        ..on<lk.TrackUnsubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.RoomDisconnectedEvent>((_) {
          // admin end / DeleteRoom / KALICI ag kopmasi -> cik. Sunucuya bitir GONDER
          // (idempotent; kalici istemci kopmasi sunucuda zombi live/paused birakmasin —
          // dogrulama bulgusu; gecici kopmalar zaten SDK resume'uyla buraya dusmez).
          if (mounted) _cik(sunucuyaBildir: true);
        });
      await room.connect(
        widget.url,
        widget.token,
        connectOptions: const lk.ConnectOptions(
          autoSubscribe: true,
          rtcConfiguration:
              lk.RTCConfiguration(iceTransportPolicy: lk.RTCIceTransportPolicy.relay),
        ),
      );
      if (!mounted || _ayrildi) {
        await _kapatOda();
        return;
      }
      // iOS ses sirasi: mic -> kamera -> hoparlor -> ses birimi EN SON (v7/v8 dersi)
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (_devralinan != null) {
        // P1: devralinan CANLI track'i AYNEN yayinla — kamera kapat/ac yarisi HIC olusmaz.
        try {
          await room.localParticipant
              ?.publishVideoTrack(_devralinan!, publishOptions: kVideoPublishOptions);
          _videoYayinda = true;
        } catch (e) {
          Sentry.addBreadcrumb(Breadcrumb(
              category: 'yayin.video',
              message: 'devralinan track publish HATASI: $e — setCameraEnabled geri dususu'));
          await room.localParticipant?.setCameraEnabled(true); // geri dusus (eski yol)
        }
      } else {
        await room.localParticipant?.setCameraEnabled(true);
      }
      await room.setSpeakerOn(true);
      await _sesiAc(true);
    } catch (e) {
      await _kapatOda();
      rethrow;
    }
  }

  void _veriGeldi(lk.DataReceivedEvent e) {
    final v = yayinVerisiCoz(e.data);
    if (v == null || !mounted) return;
    switch (v['t']) {
      case 'viewers':
        setState(() => _izleyici = (v['n'] as num?)?.toInt() ?? _izleyici);
      case 'chat':
        setState(() {
          _mesajlar.add(ChatMesaj(
              kimden: v['from'] as String? ?? '', metin: v['text'] as String? ?? ''));
          if (_mesajlar.length > 40) _mesajlar.removeAt(0);
        });
      case 'gift':
        setState(() {
          _jeton += (v['coins'] as num?)?.toInt() ?? 0;
          _mesajlar.add(ChatMesaj(
              kimden: v['from_name'] as String? ?? '',
              metin: '${v['emoji']} hediye gönderdi (+${v['coins']} jeton)',
              vurgulu: true));
          if (_mesajlar.length > 40) _mesajlar.removeAt(0);
          _hediyeler.add(MapEntry(_hediyeSayac++, v['emoji'] as String? ?? '🎁'));
        });
      case 'hearts':
        _kalpKey.currentState?.patlat((v['n'] as num?)?.toInt() ?? 1);
      // ---- KONUK sinyalleri (Bolum 6 I4) ----
      case 'guest.request':
        setState(() => _istekIds.add(v['user_id'] as String? ?? ''));
      case 'guest.request.cancel':
        setState(() => _istekIds.remove(v['user_id'] as String? ?? ''));
      case 'guest.joined':
        setState(() {
          _konukId = v['user_id'] as String? ?? '';
          _konukAdi = v['name'] as String? ?? '';
          _istekIds.remove(_konukId);
        });
      case 'guest.left':
        if ((v['user_id'] as String?) == _konukId) {
          setState(() {
            _konukId = '';
            _konukAdi = '';
          });
        }
      case 'stream.ended':
        _cik(sunucuyaBildir: false); // admin bitirdi
    }
  }

  /// Konugun uzak videosu — TRACK-BAZLI (dusurulen konugun track'siz participant'i gorunmez)
  lk.VideoTrack? get _konukVideo {
    for (final p in _room?.remoteParticipants.values ?? const <lk.RemoteParticipant>[]) {
      for (final pub in p.videoTrackPublications) {
        if (pub.subscribed && pub.track != null) return pub.track as lk.VideoTrack;
      }
    }
    return null;
  }

  /// Istek sheet'i; kapaninca rozeti REST'ten tazele (sheet icinde kabul/red olmus olabilir)
  Future<void> _istekSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => IstekSheet(streamId: widget.streamId),
    );
    if (!mounted) return;
    try {
      final r = await ref.read(liveApiProvider).istekler(widget.streamId);
      if (mounted) {
        setState(() {
          _istekIds
            ..clear()
            ..addAll(r.map((u) => u['user_id'] as String? ?? ''));
        });
      }
    } catch (_) {}
  }

  /// Aktif konugun user_id'si. TARAMA #7: guest.joined sinyali kacmis olabilir
  /// (arka plan/reconnect) — PiP track-bazli gorunmeye devam eder ama _konukId bos
  /// kalirdi ve x butonu SESSIZCE hicbir sey yapmazdi. Yedek: publish eden tek uzak
  /// katilimcinin LiveKit identity'si (token identity = user_id).
  String _konukIdBul() {
    if (_konukId.isNotEmpty) return _konukId;
    for (final p in _room?.remoteParticipants.values ?? const <lk.RemoteParticipant>[]) {
      for (final pub in p.videoTrackPublications) {
        if (pub.subscribed && pub.track != null) return p.identity;
      }
    }
    return '';
  }

  /// Konugu yayindan cikar (PiP'teki x) — onayli
  Future<void> _konukCikarOnayli() async {
    final ad = _konukAdi.isNotEmpty ? _konukAdi : 'Konuk';
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$ad yayından alınsın mı?'),
        content: const Text('İzleyici olarak yayında kalır.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Al')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    final hedef = _konukIdBul();
    if (hedef.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Konuk bilgisi alınamadı — İzleyiciler listesinden deneyin')));
      return;
    }
    try {
      await ref.read(liveApiProvider).konukCikar(widget.streamId, hedef);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  // A3 GUVENLIK AGI: baglantidan 4sn ve 8sn sonra kendi video sender'imdan kare cikiyor mu
  // kontrol et (framesSent). Cikmiyorsa Sentry'e isaretle + TEK KEZ restartTrack (ayni
  // cozunurluk — CLAUDE.md restartTrack tuzagi kapsam disi; dongusel retry YOK).
  bool _videoKurtarmaDenendi = false;
  void _videoSagligiKur() {
    for (final sn in const [4, 8]) {
      Timer(Duration(seconds: sn), () async {
        if (!mounted || _ayrildi) return;
        final t = _kameram;
        if (t is! lk.LocalVideoTrack) return;
        try {
          final stats = await t.getSenderStats();
          num kare = 0;
          for (final s in stats) {
            kare += s.framesSent ?? 0;
          }
          if (kare > 0) return; // saglikli
          Sentry.captureMessage('yayin-video-olu: ${sn}sn, framesSent=0');
          if (!_videoKurtarmaDenendi) {
            _videoKurtarmaDenendi = true;
            await t.restartTrack();
            Sentry.addBreadcrumb(
                Breadcrumb(category: 'yayin.video', message: 'restartTrack kurtarmasi denendi'));
          }
        } catch (_) {}
      });
    }
  }

  Future<void> _sesiAc(bool ac) async {
    if (!Platform.isIOS) return;
    try {
      await _audioCh.invokeMethod('setAudioEnabled', ac);
    } catch (_) {}
  }

  Future<void> _kapatOda() async {
    if (_kapandi) return;
    _kapandi = true;
    await _sesiAc(false);
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;
    if (room == null && listener == null) return;
    try {
      await room?.disconnect().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await listener?.dispose().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await room?.dispose().timeout(const Duration(seconds: 3));
    } catch (_) {}
    // P1 TEK-NOKTA SALIVERME: devralinan track publish EDILEMEDIYSE kamerayi burada birak
    // (publish edildiyse stopLocalTrackOnUnpublish=true — room.dispose zaten kapatir).
    final dev = _devralinan;
    _devralinan = null;
    if (dev != null && !_videoYayinda) {
      try {
        await dev.stop();
        await dev.dispose();
      } catch (_) {}
    }
  }

  Future<void> _cik({required bool sunucuyaBildir}) async {
    if (_ayrildi) return;
    _ayrildi = true;
    _svc.ekranKapandi('yayin_${widget.streamId}');
    unawaited(CallRoomLock.calistir(_kapatOda));
    if (sunucuyaBildir) {
      try {
        await ref.read(liveApiProvider).bitir(widget.streamId);
      } catch (_) {}
    }
    if (mounted) {
      final nav = Navigator.of(context);
      nav.popUntil((r) => r.settings.name == 'yayin-${widget.streamId}' || r.isFirst);
      if (nav.canPop()) nav.pop();
    }
  }

  Future<void> _bitirOnayli() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yayını bitir?'),
        content: Text('$_izleyici izleyici yayından çıkarılacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Bitir')),
        ],
      ),
    );
    if (onay == true) _cik(sunucuyaBildir: true);
  }

  /// Yayina davet (Bolum 5 I3): sheet -> secilen id'ler -> REST
  Future<void> _davetEt() async {
    final secilenler = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const DavetSecSheet(),
    );
    if (secilenler == null || secilenler.isEmpty || !mounted) return;
    try {
      final n = await ref.read(liveApiProvider).davet(widget.streamId, secilenler);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Davet gönderildi ($n kişi)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _chatGonder() async {
    final t = _chatCtrl.text.trim();
    if (t.isEmpty) return;
    _chatCtrl.clear();
    try {
      await ref.read(liveApiProvider).chat(widget.streamId, t);
    } catch (e) {
      // Sessiz yutma (dogrulama bulgusu): kullanici mesajin gittigini sanmasin
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  void dispose() {
    _svc.ekranKapandi('yayin_${widget.streamId}');
    WidgetsBinding.instance.removeObserver(this);
    _nabiz?.cancel();
    _chatCtrl.dispose();
    unawaited(CallRoomLock.calistir(_kapatOda));
    super.dispose();
  }

  lk.VideoTrack? get _kameram =>
      _room?.localParticipant?.videoTrackPublications.firstOrNull?.track ??
      _devralinan; // publish tamamlanana kadar onizleme akisi gorunmeye devam eder (P1)

  @override
  Widget build(BuildContext context) {
    final video = _kameram;
    final konukVideo = _konukVideo;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _bitirOnayli();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: Stack(children: [
          Positioned.fill(
            child: video != null
                ? IgnorePointer(
                    child: lk.VideoTrackRenderer(video,
                        // KEY mediaStreamTrack.id: publish oncesi sid NULL (devralinan track
                        // gorunurken key cakismasin — hukum A2 duzeltmesi)
                        key: ValueKey('yayin-${video.mediaStreamTrack.id}'),
                        fit: lk.VideoViewFit.cover,
                        // auto modu bayat facingMode'la ARKA kamerada da AYNALIYORDU
                        // ("kamera ters"). On=aynali, arka=aynasiz; izleyici etkilenmez.
                        mirrorMode: _onKamera
                            ? lk.VideoViewMirrorMode.mirror
                            : lk.VideoViewMirrorMode.off))
                : Center(
                    child: _hata != null
                        ? Text(_hata!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70))
                        : const CircularProgressIndicator()),
          ),
          // KONUK PiP (Bolum 6 I4): konugun videosu + sag-ust x (yayindan al)
          if (konukVideo != null)
            Positioned(
              top: 76,
              right: 12,
              width: 108,
              height: 150,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black45, blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    // IgnorePointer: renderer'a dokunus = CameraUtils NPE riski (proje
                    // kurali); x butonu Stack'te ustte, calismaya devam eder.
                    child: IgnorePointer(
                      child: lk.VideoTrackRenderer(
                        konukVideo,
                        key: ValueKey('konuk-${konukVideo.mediaStreamTrack.id}'),
                        fit: lk.VideoViewFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: _konukCikarOnayli,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child:
                          const Icon(LucideIcons.x, size: 14, color: Colors.white),
                    ),
                  ),
                ),
                if (_konukAdi.isNotEmpty)
                  Positioned(
                    left: 6,
                    bottom: 4,
                    right: 6,
                    child: Text(_konukAdi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                  ),
              ]),
            ),
          KalpKatmani(key: _kalpKey),
          for (final h in _hediyeler)
            HediyePatlamasi(
                key: ValueKey('h-${h.key}'),
                emoji: h.value,
                bitti: () =>
                    setState(() => _hediyeler.removeWhere((x) => x.key == h.key))),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                    child: const Text('CANLI',
                        style: TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    // 👁 -> kimler izliyor + Canliya al/At (Bolum 6 I4)
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => IzleyicilerSheet(
                          streamId: widget.streamId, yayinciyim: true),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                      child: Text('👁 $_izleyici',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    // 🪙 -> hediye gonderenler (kirilimli leaderboard)
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          HediyeLeaderboardSheet(streamId: widget.streamId),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                      child: Text('🪙 $_jeton',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  const Spacer(),
                  // Katil istekleri (rozetli el) — Bolum 6 I4
                  IconButton(
                    onPressed: _istekSheet,
                    icon: Badge(
                      isLabelVisible: _istekIds.isNotEmpty,
                      label: Text('${_istekIds.length}'),
                      child: const Icon(LucideIcons.hand, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.userPlus, color: Colors.white),
                    onPressed: _davetEt, // yayina davet (Bolum 5 I3)
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.switchCamera, color: Colors.white),
                    onPressed: () async {
                      final t = _kameram;
                      if (t == null) return;
                      try {
                        // switchCamera GERCEK yonu doner (true=on) -> ayna moduna islenir
                        final onMu = await rtc.Helper.switchCamera(t.mediaStreamTrack);
                        if (mounted) setState(() => _onKamera = onMu);
                      } catch (_) {}
                    },
                  ),
                  IconButton(
                    icon: Icon(_micOn ? LucideIcons.mic : LucideIcons.micOff,
                        color: _micOn ? Colors.white : Colors.redAccent),
                    onPressed: () async {
                      final on = !_micOn;
                      await _room?.localParticipant?.setMicrophoneEnabled(on);
                      setState(() => _micOn = on);
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.power, color: Colors.redAccent),
                    onPressed: _bitirOnayli,
                  ),
                ]),
              ),
              if (_connecting)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Bağlanıyor...',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Klavye acikken serit kucultulur (RenderFlex tasmasi bulgusu)
                  ChatSeridi(
                      mesajlar: _mesajlar,
                      yukseklik:
                          MediaQuery.of(context).viewInsets.bottom > 0 ? 90 : 180),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Mesaj yaz...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black38,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _chatGonder(),
                      ),
                    ),
                    IconButton(
                        onPressed: _chatGonder,
                        icon: const Icon(LucideIcons.sendHorizontal, color: Colors.white)),
                  ]),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

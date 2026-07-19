import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/api.dart';
import '../invites/davet_sec_sheet.dart';
import '../calls/call_provider.dart';
import '../calls/call_room_lock.dart';
import 'live_gift_sheet.dart';
import 'live_provider.dart';
import 'live_widgets.dart';

/// IZLEYICI ekrani: yayincinin videosu tam ekran + chat + kalp + hediye.
/// Mikrofon IZNI HIC ISTENMEZ (token'da publish kapali). Sinyaller SendData'dan.
class LiveViewerScreen extends ConsumerStatefulWidget {
  const LiveViewerScreen({
    super.key,
    required this.streamId,
    required this.lkRoom,
    required this.url,
    required this.token,
    required this.baslik,
    required this.yayinciId,
    required this.yayinciAd,
    required this.durum,
    this.ilkIzleyici = 0,
  });

  final String streamId;
  final String lkRoom;
  final String url;
  final String token;
  final String baslik;
  final String yayinciId;
  final String yayinciAd;
  final String durum;
  final int ilkIzleyici; // watch cevabindaki sayi (SendData 15sn'ye kadar gecikebilir)

  @override
  ConsumerState<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends ConsumerState<LiveViewerScreen>
    with WidgetsBindingObserver {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  Timer? _nabiz;
  final _kalpKey = GlobalKey<KalpKatmaniState>();
  final List<ChatMesaj> _mesajlar = [];
  final List<MapEntry<int, String>> _hediyeler = []; // sayac-anahtarli (key cakismasi bulgusu)
  int _hediyeSayac = 0;
  late int _izleyici = widget.ilkIzleyici; // watch cevabindan (15sn '0' gorunme bulgusu)
  bool _durakladi = false;
  bool _connecting = true;
  bool _ayrildi = false;
  bool _kapandi = false;
  bool _bittiGosterildi = false; // stream.ended + RoomDisconnected cift dialog muhafizi
  DateTime _sonKalp = DateTime.fromMillisecondsSinceEpoch(0);
  String? _hata;

  late final CallService _svc;
  final _chatCtrl = TextEditingController();
  static const _audioCh = MethodChannel('gebzem/audio');

  @override
  void initState() {
    super.initState();
    _svc = ref.read(callServiceProvider.notifier);
    _svc.ekranAcildi('yayin_${widget.streamId}');
    WidgetsBinding.instance.addObserver(this);
    _durakladi = widget.durum == 'paused';
    _nabiz = Timer.periodic(const Duration(seconds: 15),
        (_) => ref.read(liveApiProvider).nabiz(widget.streamId).catchError((_) {}));
    _baglan();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_ayrildi) {
      _sesiAc(true); // kesinti toparlama
      ref.read(liveApiProvider).nabiz(widget.streamId).catchError((_) {});
    }
  }

  Future<void> _baglan() async {
    try {
      await CallRoomLock.calistir(_odayaBaglan);
      if (mounted) setState(() => _connecting = false);
    } catch (e) {
      await Sentry.captureException(e, stackTrace: StackTrace.current);
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
      roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;
    try {
      _listener = room.createListener();
      _listener!
        ..on<lk.DataReceivedEvent>(_veriGeldi)
        ..on<lk.TrackSubscribedEvent>((e) {
          if (!mounted) return;
          setState(() {});
          if (e.track is lk.VideoTrack) {
            // Ilk-kare texture tekmesi (call_screen deseni)
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
          // yayin bitti / kick / kalici kopma
          if (mounted) _yayinBitti();
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
      // Izleyicide mic YOK; hoparlor + ses birimi EN SON (iOS sirasi)
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
          _mesajlar.add(ChatMesaj(
              kimden: v['from_name'] as String? ?? '',
              metin: '${v['emoji']} hediye gönderdi',
              vurgulu: true));
          if (_mesajlar.length > 40) _mesajlar.removeAt(0);
          _hediyeler.add(MapEntry(_hediyeSayac++, v['emoji'] as String? ?? '🎁'));
        });
      case 'hearts':
        _kalpKey.currentState?.patlat((v['n'] as num?)?.toInt() ?? 1);
      case 'stream.paused':
        setState(() => _durakladi = true);
      case 'stream.resumed':
        setState(() => _durakladi = false);
      case 'stream.ended':
        _yayinBitti();
    }
  }

  void _yayinBitti() {
    if (!mounted || _ayrildi || _bittiGosterildi) return;
    _bittiGosterildi = true; // stream.ended + DeleteRoom-RoomDisconnected cifti tek dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Yayın sona erdi'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Tamam')),
        ],
      ),
    ).then((_) => _cik());
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
  }

  Future<void> _cik() async {
    if (_ayrildi) return;
    _ayrildi = true;
    _svc.ekranKapandi('yayin_${widget.streamId}');
    unawaited(CallRoomLock.calistir(_kapatOda));
    try {
      await ref.read(liveApiProvider).ayril(widget.streamId);
    } catch (_) {}
    if (mounted) {
      final nav = Navigator.of(context);
      nav.popUntil((r) => r.settings.name == 'yayin-${widget.streamId}' || r.isFirst);
      if (nav.canPop()) nav.pop();
    }
  }

  Future<void> _kalpGonder() async {
    // istemci throttle 500ms; kendi kalbin ANINDA gorunur (digerlerine sunucu toplar)
    final simdi = DateTime.now();
    if (simdi.difference(_sonKalp).inMilliseconds < 500) return;
    _sonKalp = simdi;
    _kalpKey.currentState?.patlat(1);
    try {
      await ref.read(liveApiProvider).kalp(widget.streamId);
    } catch (_) {}
  }

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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  void _hediyeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => LiveGiftSheet(streamId: widget.streamId),
    );
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

  lk.VideoTrack? get _video {
    for (final p in _room?.remoteParticipants.values ?? const <lk.RemoteParticipant>[]) {
      for (final pub in p.videoTrackPublications) {
        if (pub.subscribed && pub.track != null) return pub.track as lk.VideoTrack;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cik();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: Stack(children: [
          Positioned.fill(
            child: video != null
                ? IgnorePointer(
                    child: lk.VideoTrackRenderer(video,
                        key: ValueKey('izle-${video.sid}'), fit: lk.VideoViewFit.cover))
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1A0B2E), Color(0xFF0B141A)],
                      ),
                    ),
                    child: Center(
                      child: _hata != null
                          ? Text(_hata!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70))
                          : _connecting
                              ? const CircularProgressIndicator()
                              : const Text('Görüntü bekleniyor...',
                                  style: TextStyle(color: Colors.white70)),
                    ),
                  ),
          ),
          if (_durakladi)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.wifiOff, color: Colors.white70, size: 48),
                  SizedBox(height: 12),
                  Text('Yayıncının bağlantısı koptu\nBekleniyor...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ]),
              ),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF6C2BD9),
                    child: Text(
                        widget.yayinciAd.isNotEmpty
                            ? widget.yayinciAd[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.yayinciAd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                      Text('👁 $_izleyici',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.userPlus, color: Colors.white70, size: 20),
                    onPressed: _davetEt, // izleyici de davet edebilir (Bolum 5)
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.flag, color: Colors.white54, size: 20),
                    onPressed: () async {
                      final mesajci = ScaffoldMessenger.of(context); // await oncesi yakala
                      try {
                        await ref.read(liveApiProvider).rapor(widget.streamId, 'uygunsuz');
                        mesajci.showSnackBar(const SnackBar(
                            content: Text('Rapor alındı — teşekkürler')));
                      } catch (_) {}
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                    onPressed: _cik,
                  ),
                ]),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                    IconButton(
                        onPressed: _hediyeSheet,
                        icon: const Icon(LucideIcons.gift, color: Colors.amberAccent)),
                    IconButton(
                        onPressed: _kalpGonder,
                        icon: const Icon(LucideIcons.heart, color: Color(0xFFB79CFF))),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'call_provider.dart';

/// Aktif arama ekrani — LiveKit odasina baglanir, sesi/goruntuyu tasir.
/// Zayif baglantida kalite otomatik duser; kopunca otomatik yeniden baglanir
/// (LiveKit SDK'nin kendi mekanizmasi).
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.callId,
    required this.url,
    required this.token,
    required this.video,
    required this.peerName,
    this.outgoing = true,
  });

  final String callId;
  final String url;
  final String token;
  final bool video;
  final String peerName;
  final bool outgoing; // giden arama mi (karsi taraf henuz kabul etmedi)

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  StreamSubscription? _endedSub;
  StreamSubscription? _answeredSub;
  Timer? _durationTimer;
  Timer? _ringTimeout;

  bool _connecting = true;
  bool _peerJoined = false;
  bool _micOn = true;
  bool _camOn = false;
  bool _speakerOn = true;
  bool _frontCamera = true;
  String? _error;
  Duration _duration = Duration.zero;
  ConnectionQuality _quality = ConnectionQuality.unknown;

  @override
  void initState() {
    super.initState();
    _camOn = widget.video;
    _connect();

    // Karsi taraf kapatirsa ekrani kapat
    _endedSub = ref.read(callServiceProvider.notifier).onCallEnded.listen((id) {
      if (id == widget.callId && mounted) _leave(notifyServer: false);
    });
  }

  Future<void> _connect() async {
    try {
      // Izinler: mikrofon her zaman, kamera goruntulu aramada
      final perms = <Permission>[Permission.microphone];
      if (widget.video) perms.add(Permission.camera);
      final statuses = await perms.request();
      if (statuses[Permission.microphone] != PermissionStatus.granted) {
        setState(() {
          _error = 'Arama icin mikrofon izni gerekli';
          _connecting = false;
        });
        return;
      }

      final room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: true, // zayif baglantida kaliteyi otomatik dusur
          dynacast: true, // kullanilmayan akislari durdur (pil/veri tasarrufu)
          defaultAudioPublishOptions: const AudioPublishOptions(
            dtx: true, // sessizken veri gonderme
          ),
          defaultVideoPublishOptions: const VideoPublishOptions(
            simulcast: true, // farkli kalitelerde gonder
          ),
        ),
      );

      _listener = room.createListener();
      _listener!
        ..on<ParticipantConnectedEvent>((_) {
          if (mounted) {
            _ringTimeout?.cancel();
            setState(() => _peerJoined = true);
            _startTimer();
          }
        })
        ..on<ParticipantDisconnectedEvent>((_) {
          if (mounted) _leave(notifyServer: true); // karsi taraf ayrildi
        })
        ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
          if (mounted && e.participant is LocalParticipant) {
            setState(() => _quality = e.connectionQuality);
          }
        })
        ..on<TrackSubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnsubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted) _leave(notifyServer: false);
        });

      await room.connect(
        widget.url,
        widget.token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
          // Kisitli aglarda (mobil operator) medya TURN uzerinden gecer
          rtcConfiguration: RTCConfiguration(
            iceTransportPolicy: RTCIceTransportPolicy.all,
          ),
        ),
      );
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (widget.video) {
        await room.localParticipant?.setCameraEnabled(true);
      }
      await room.setSpeakerOn(widget.video); // goruntuluda hoparlor acik baslar

      if (!mounted) return;
      setState(() {
        _room = room;
        _connecting = false;
        _speakerOn = widget.video;
        _peerJoined = room.remoteParticipants.isNotEmpty;
      });
      if (_peerJoined) {
        _startTimer();
      } else if (widget.outgoing) {
        // Karsi taraf 45 saniyede acmazsa aramayi kapat (cevapsiz)
        _ringTimeout = Timer(const Duration(seconds: 45), () {
          if (mounted && !_peerJoined) _leave(notifyServer: true);
        });
      }
    } catch (e) {
      // Hata Sentry'e duser; kullaniciya net mesaj gosterilir
      await Sentry.captureException(e, stackTrace: StackTrace.current);
      if (mounted) {
        final msg = e.toString().toLowerCase();
        setState(() {
          _error = msg.contains('timeout') || msg.contains('ice') || msg.contains('dtls')
              ? 'Baglanti kurulamadi.\nInternet baglantinizi kontrol edin.'
              : 'Arama baslatilamadi.\nTekrar deneyin.';
          _connecting = false;
        });
      }
    }
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  Future<void> _leave({required bool notifyServer}) async {
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    await _room?.disconnect();
    await _listener?.dispose();
    _room = null;
    if (notifyServer) {
      await ref.read(callServiceProvider.notifier).end(widget.callId);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleMic() async {
    final on = !_micOn;
    await _room?.localParticipant?.setMicrophoneEnabled(on);
    setState(() => _micOn = on);
  }

  Future<void> _toggleCam() async {
    final on = !_camOn;
    await _room?.localParticipant?.setCameraEnabled(on);
    setState(() => _camOn = on);
  }

  Future<void> _toggleSpeaker() async {
    final on = !_speakerOn;
    await _room?.setSpeakerOn(on);
    setState(() => _speakerOn = on);
  }

  Future<void> _flipCamera() async {
    final track =
        _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
    if (track == null) return;
    final pos = _frontCamera ? CameraPosition.back : CameraPosition.front;
    await track.setCameraPosition(pos);
    setState(() => _frontCamera = !_frontCamera);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    _endedSub?.cancel();
    _answeredSub?.cancel();
    _listener?.dispose();
    _room?.disconnect();
    super.dispose();
  }

  String get _statusText {
    if (_error != null) return _error!;
    if (_connecting) return 'Baglaniliyor...';
    if (!_peerJoined) return widget.outgoing ? 'Caliyor...' : 'Bekleniyor...';
    final m = _duration.inMinutes.toString().padLeft(2, '0');
    final s = (_duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Karsi tarafin video akisi (varsa)
  VideoTrack? get _remoteVideo {
    final p = _room?.remoteParticipants.values.firstOrNull;
    final pub = p?.videoTrackPublications.firstOrNull;
    if (pub?.subscribed == true && pub?.track != null) {
      return pub!.track as VideoTrack;
    }
    return null;
  }

  VideoTrack? get _localVideo =>
      _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;

  @override
  Widget build(BuildContext context) {
    final remote = _remoteVideo;
    final local = _localVideo;
    final showVideo = widget.video && (remote != null || local != null);

    return PopScope(
      canPop: false, // geri tusuyla kacamaz — aramayi bitirmeli
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: Stack(
          children: [
            // Karsi tarafin goruntusu (tam ekran)
            if (remote != null)
              Positioned.fill(child: VideoTrackRenderer(remote))
            else
              _buildAudioBackground(),

            // Kendi goruntun (kucuk pencere)
            if (showVideo && local != null && _camOn)
              Positioned(
                top: 60,
                right: 16,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: VideoTrackRenderer(local),
                ),
              ),

            // Ust bilgi: isim + sure/durum + baglanti kalitesi
            Positioned(
              top: 48,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(widget.peerName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_peerJoined) _qualityDot(),
                      if (_peerJoined) const SizedBox(width: 6),
                      Text(_statusText,
                          style: TextStyle(color: Colors.white70, fontSize: 15)),
                    ],
                  ),
                ],
              ),
            ),

            // Alt kontroller
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ctrlButton(
                    icon: _micOn ? LucideIcons.mic : LucideIcons.micOff,
                    active: !_micOn,
                    onTap: _toggleMic,
                  ),
                  const SizedBox(width: 16),
                  if (widget.video) ...[
                    _ctrlButton(
                      icon: _camOn ? LucideIcons.video : LucideIcons.videoOff,
                      active: !_camOn,
                      onTap: _toggleCam,
                    ),
                    const SizedBox(width: 16),
                    _ctrlButton(
                      icon: LucideIcons.switchCamera,
                      onTap: _flipCamera,
                    ),
                    const SizedBox(width: 16),
                  ],
                  _ctrlButton(
                    icon: _speakerOn ? LucideIcons.volume2 : LucideIcons.volumeX,
                    active: _speakerOn,
                    onTap: _toggleSpeaker,
                  ),
                  const SizedBox(width: 16),
                  // Kapat
                  GestureDetector(
                    onTap: () => _leave(notifyServer: true),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                          color: Color(0xFFE53935), shape: BoxShape.circle),
                      child: const Icon(LucideIcons.phoneOff,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF075E54), Color(0xFF0B141A)],
        ),
      ),
      child: Center(
        child: CircleAvatar(
          radius: 64,
          backgroundColor: Colors.white24,
          child: Text(
            widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 48, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _qualityDot() {
    final color = switch (_quality) {
      ConnectionQuality.excellent => Colors.greenAccent,
      ConnectionQuality.good => Colors.amberAccent,
      ConnectionQuality.poor => Colors.redAccent,
      _ => Colors.white38,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _ctrlButton({
    required IconData icon,
    bool active = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? Colors.black87 : Colors.white, size: 24),
      ),
    );
  }
}

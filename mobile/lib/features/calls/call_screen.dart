import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../router.dart';
import 'active_call_controller.dart';
import 'add_participant_sheet.dart';

/// AKTIF ARAMA EKRANI — SAF GORUNUM (Faz-C C2). TUM mantik (Room, timer'lar, sure
/// senkronu, ses birimi, muhafizlar) ActiveCallController'da yasar; bu ekran yalniz
/// render eder + kontrol cagrilari yapar. EKRAN DISPOSE'U ARAMAYI BITIRMEZ (minimize
/// sayilir); aramayi yalniz kirmizi tus / peer-hangup (controller.leave) bitirir.
/// GORSEL YAPI PIKSELI PIKSELINE korunmustur (hukum C2c — gorsel fark YASAK).
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.bilgi});

  final AramaBilgisi bilgi;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  late final ActiveCallController _c; // cache — dispose'ta ref.read YASAK (F1 tuzagi)
  bool _benimEkranim = true; // initState'te callId eslesti mi (bayat ekran guvenligi)
  bool _kapaniyor = false; // bitis pop'u tek sefer

  // ---- EKRANDA KALAN SAF GORSEL STATE (hukum C2b / K5) ----
  bool _sorunBildirildi = false;
  bool _sheetAcik = false; // kisi-ekleme sheet'i (K7: bitiste once sheet-pop)
  Offset? _selfPos; // yalniz pan surerken ham konum
  bool _selfSagda = true, _selfAltta = false; // kalici kose hafizasi (A5)
  static const double _selfW = 140, _selfH = 200, _selfMargin = 16;
  bool _selfBuyuk = false; // self-view swap
  bool _uiGizli = false; // A7 dokun-gizle

  @override
  void initState() {
    super.initState();
    _c = ref.read(activeCallProvider);
    _benimEkranim = _c.arama?.callId == widget.bilgi.callId;
    if (_benimEkranim) {
      _c.ekranGorunur = true;
      _c.minimized = false;
      _c.addListener(_ctrlDegisti);
      _c.pipDurumTazele(); // FAZ-6: ekran acildi — PiP izni guncel duruma gore kurulsun
    } else {
      // Uyusmazlik (restore yarisi vb.): bu ekran bayat — kendini kapat, controller'a dokunma
      _kapaniyor = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }
  }

  /// Controller "arama bitti" dedi (arama==null) -> K7 sirasi: ONCE sheet, SONRA ekran pop.
  void _ctrlDegisti() {
    if (!mounted || _kapaniyor) return;
    if (_c.arama == null) {
      _kapaniyor = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Navigator.of(context);
        if (_sheetAcik && nav.canPop()) nav.pop();
        if (nav.canPop()) nav.pop();
      });
    }
  }

  @override
  void dispose() {
    if (_benimEkranim) {
      _c.removeListener(_ctrlDegisti);
      if (_kapaniyor) {
        _c.ekranGorunur = false; // normal bitis: arama zaten null
      } else {
        // Beklenmedik pop: arama SURUYOR -> guvenli minimize (bitirme YOK)
        _c.ekranBeklenmedikKapandi();
      }
    }
    super.dispose();
  }

  // ---- kontrol sarmalayicilari (gorsel state resetleri ekranda) ----

  Future<void> _toggleCam() async {
    await _c.toggleCam();
    // Kamera KAPANINCA swap + gizleme sifirla (kapali -> varsayilan gorunum; A7)
    if (mounted && !_c.camOn) {
      setState(() {
        _selfBuyuk = false;
        _uiGizli = false;
      });
    }
  }

  Future<void> _sorunBildir() async {
    setState(() => _sorunBildirildi = true);
    await _c.sorunBildir();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sorun kaydedildi — teşekkürler'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  Future<void> _geriAra() async {
    final ok = await _c.geriAra();
    if (ok && mounted) {
      // yeni arama: gorsel durumu sifirla (controller zaten sifirladi)
      setState(() {
        _sorunBildirildi = false;
        _selfBuyuk = false;
        _uiGizli = false;
      });
    }
  }

  /// MINIMIZE (C4): yalniz BAGLI aramada. Bitis DEGIL — muhafizlar dolu, timer'lar akar,
  /// CallKit aktif kalir; ekran pop olur, yesil bant gorunur.
  void _minimize() {
    if (!_c.minimizeEdilebilir) return;
    _c.minimize();
    Navigator.of(context).pop();
  }

  // KISI EKLEME (Faz-B B6): sheet ac; secim -> controller.kisiEkle (REST + iyimser grup).
  void _kisiEkle() {
    if (!_c.baglandi || _c.cevapsiz) return;
    _sheetAcik = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddParticipantSheet(
        onEkle: (userId, name) async {
          await _c.kisiEkle(userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$name aramaya davet edildi')));
          }
        },
      ),
    ).whenComplete(() => _sheetAcik = false);
  }

  /// MESAJ IKONU (C5): minimize + (1:1 giden aramada) dogru sohbeti ac.
  /// peerId yoksa (gelen 1:1/grup) yalniz minimize — backend'e alan EKLENMEZ (1:1 dokunmama).
  Future<void> _mesajaDon() async {
    if (!_c.minimizeEdilebilir) return;
    final b = _c.arama;
    final peerId = b?.peerId;
    final ad = b?.peerName ?? '';
    final api = ref.read(apiProvider); // pop'tan ONCE yakala (sonrasi ref KULLANILAMAZ)
    _c.minimize();
    Navigator.of(context).pop();
    if (peerId == null) return;
    try {
      final res = await api.post('/chats/direct', data: {'user_id': peerId});
      final chatId = ((res.data as Map)['chat_id'])?.toString() ?? '';
      if (chatId.isEmpty) return;
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        GoRouter.of(ctx)
            .push('/chat/$chatId', extra: {'title': ad, 'peer_id': peerId});
      }
    } catch (e) {
      rootMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  // ---- video getter'lari (controller.room uzerinden; render kurallari AYNEN) ----

  VideoTrack? get _remoteVideo {
    final p = _c.room?.remoteParticipants.values.firstOrNull;
    final pub = p?.videoTrackPublications.firstOrNull;
    // FAZ-6 donma fix'inin ekran yarisi: karsi taraf kamerayi MUTE ettiyse (arka plana
    // indi) donuk son kare degil avatar goster (grup tile'lari zaten boyle yapiyordu).
    if (pub?.subscribed == true && pub?.muted == false && pub?.track != null) {
      return pub!.track as VideoTrack;
    }
    return null;
  }

  VideoTrack? get _localVideo =>
      _c.room?.localParticipant?.videoTrackPublications.firstOrNull?.track;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(activeCallProvider);
    // Bitis aninda (arama==null, pop bekleniyor) son kare widget.bilgi ile cizilir
    final b = c.arama ?? widget.bilgi;
    // FAZ-6: sistem PiP penceresi — SADE gorunum (tek video, kontrol/self-view yok)
    if (c.pipModunda) return _pipGorunum(c, b);
    final remote = _remoteVideo;
    final local = _localVideo;
    // MID-CALL: sesli aramada kamera acilinca (yerel VEYA karsi) video moduna gecer.
    final showVideo = remote != null || local != null;

    // SWAP (WhatsApp): self-view'e dokununca kendi goruntum buyuk, karsininki kucuk.
    final bothVideo = remote != null && local != null && c.camOn;
    final swap = _selfBuyuk && bothVideo;
    final VideoTrack? bigTrack = swap ? local : remote;
    final VideoTrack? smallTrack =
        swap ? remote : (local != null && c.camOn ? local : null);
    final bool smallIsLocal = !swap;

    return PopScope(
      canPop: false,
      // C4: geri tusu BAGLI aramada minimize eder (WhatsApp); ring/cevapsiz fazinda
      // ESKISI gibi bloklu (bilincli daraltma — Plan 2 karar 2).
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _c.minimizeEdilebilir) {
          _c.minimize();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: Stack(
          children: [
            // GRUP: coklu-katilimci izgara. 1:1: video/ses arka plani AYNEN.
            if (c.isGroup)
              _buildGroupGrid(b)
            else if (bigTrack != null)
              Positioned.fill(
                // A7: buyuk videoya dokun -> kontroller gizle/goster. opaque + IgnorePointer
                // AYRICA CameraUtils NPE'sini kapatir (renderer'a dokunus gitmemeli).
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _uiToggle,
                  child: IgnorePointer(
                    // KEY track kimligine bagli: taze renderer, bayat/siyah texture kalmaz
                    child: VideoTrackRenderer(bigTrack,
                        key: ValueKey('big-${bigTrack.sid}'),
                        fit: VideoViewFit.cover,
                        mirrorMode: swap ? c.yerelAyna : VideoViewMirrorMode.auto),
                  ),
                ),
              )
            else
              _buildAudioBackground(b),

            // Kucuk pencere (self-view): dokun->SWAP, surukle->koseye yapisir.
            // GRUPTA acilmaz (yerel goruntu kendi tile'inda).
            if (!c.isGroup && showVideo && smallTrack != null)
              _buildSelfView(context, smallTrack,
                  canSwap: bothVideo, isLocal: smallIsLocal),

            // Ust bilgi: isim + sure/durum + kalite (A7: gizlenebilir)
            Positioned(
              top: 48,
              left: 0,
              right: 0,
              child: _gizlenebilir(Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Text(
                        c.isGroup
                            ? (b.chatTitle.isEmpty ? 'Grup araması' : b.chatTitle)
                            : b.peerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (c.peerJoined) _qualityDot(),
                      if (c.peerJoined) const SizedBox(width: 6),
                      Text(c.durumMetni,
                          style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ],
                  ),
                  // TESHIS: kullanici "ses gelmiyor" isaretler -> sunucuya SORUN-BILDIRIMI
                  if (c.peerJoined && !c.cevapsiz)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: _sorunBildir,
                        icon: const Icon(Icons.volume_off,
                            color: Colors.orangeAccent, size: 18),
                        label: Text(_sorunBildirildi ? 'Bildirildi ✓' : 'Ses gelmiyor',
                            style: const TextStyle(
                                color: Colors.orangeAccent, fontSize: 13)),
                      ),
                    ),
                ],
              )),
            ),

            // A6 UST BAR (WhatsApp yerlesimi): sol kucultme oku, sag kisi-ekle + mesaj.
            // Kapi (hukum K2): baglandi && !cevapsiz && error==null.
            if (c.baglandi && !c.cevapsiz && c.error == null)
              Positioned(
                top: 44,
                left: 8,
                right: 8,
                child: _gizlenebilir(Row(children: [
                  _barBtn(LucideIcons.chevronDown, _minimize),
                  const Spacer(),
                  _barBtn(LucideIcons.userPlus, _kisiEkle),
                  const SizedBox(width: 8),
                  _barBtn(LucideIcons.messageSquare, _mesajaDon),
                ])),
              ),

            // Alt kontroller (cevapsizda: Geri Ara / Kapat) — A7: gizlenebilir
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: _gizlenebilir(
                  c.cevapsiz ? _buildCevapsizKontroller(b) : _buildAramaKontroller(c)),
            ),
          ],
        ),
      ),
    );
  }

  /// FAZ-6: PiP penceresi icerigi — yalniz en anlamli TEK video (grup dahil), yoksa
  /// avatar. Kontroller/self-view/ust bar CIZILMEZ; _uiGizli kullanilmaz.
  Widget _pipGorunum(ActiveCallController c, AramaBilgisi b) {
    VideoTrack? video;
    bool yerelMi = false;
    if (c.isGroup) {
      final katilimcilar = <Participant>[
        ...c.room?.remoteParticipants.values ?? const <RemoteParticipant>[],
        if (c.room?.localParticipant != null) c.room!.localParticipant!,
      ];
      for (final p in katilimcilar) {
        final v = _katilimciVideosu(p);
        if (v != null) {
          video = v;
          yerelMi = p is LocalParticipant;
          break;
        }
      }
    } else {
      video = _remoteVideo;
      if (video == null && c.camOn) {
        video = _localVideo;
        yerelMi = true;
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: video != null
          ? IgnorePointer(
              child: VideoTrackRenderer(video,
                  key: ValueKey('pip-${video.sid}'),
                  fit: VideoViewFit.cover,
                  mirrorMode: yerelMi ? c.yerelAyna : VideoViewMirrorMode.auto),
            )
          : _buildAudioBackground(b),
    );
  }

  // ---- A6/A7 yardimcilari ----

  bool get _gizliEfektif {
    final videoModu = _c.isGroup
        ? _grupVideoVarMi()
        : (_remoteVideo != null || _localVideo != null);
    return _uiGizli && videoModu && !_c.cevapsiz && _c.error == null && !_c.connecting;
  }

  Widget _gizlenebilir(Widget child) {
    final gizli = _gizliEfektif;
    return IgnorePointer(
      ignoring: gizli,
      child: AnimatedOpacity(
        opacity: gizli ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: child,
      ),
    );
  }

  void _uiToggle() {
    if (_c.cevapsiz || _c.error != null) return;
    setState(() => _uiGizli = !_uiGizli);
  }

  Widget _barBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration:
            const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  /// Suruklenebilir + dokun-ile-swap self-view. (opaque + IgnorePointer deseni:
  /// deferToChild tuzagi + CameraUtils NPE korumasi — degistirme.)
  Offset _selfKonum(Size sz, double w, double h) {
    if (_selfPos != null) return _selfPos!;
    final x = _selfSagda ? sz.width - w - _selfMargin : _selfMargin;
    final y = _selfAltta ? sz.height - h - 140.0 : 130.0;
    return Offset(x, y);
  }

  Widget _buildSelfView(BuildContext c2, VideoTrack track,
      {required bool canSwap, required bool isLocal}) {
    final sz = MediaQuery.of(c2).size;
    final w = _uiGizli ? 100.0 : _selfW;
    final h = _uiGizli ? 143.0 : _selfH;
    final pos = _selfKonum(sz, w, h);
    return AnimatedPositioned(
      duration:
          _selfPos != null ? Duration.zero : const Duration(milliseconds: 180),
      left: pos.dx,
      top: pos.dy,
      width: w,
      height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canSwap ? () => setState(() => _selfBuyuk = !_selfBuyuk) : null,
        onPanUpdate: (d) {
          final cur = _selfPos ?? pos;
          final nx = (cur.dx + d.delta.dx).clamp(_selfMargin, sz.width - w - _selfMargin);
          final ny = (cur.dy + d.delta.dy).clamp(60.0, sz.height - h - 140.0);
          setState(() => _selfPos = Offset(nx, ny));
        },
        onPanEnd: (_) {
          final cur = _selfPos ?? pos;
          setState(() {
            _selfSagda = (cur.dx + w / 2) >= sz.width / 2;
            _selfAltta = (cur.dy + h / 2) >= sz.height / 2;
            _selfPos = null;
          });
        },
        // A4: cover + radius 14 + cerceve/golge (WhatsApp gorunumu)
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: IgnorePointer(
              child: VideoTrackRenderer(track,
                  key: ValueKey('small-${isLocal ? 'local' : 'remote'}-${track.sid}'),
                  fit: VideoViewFit.cover,
                  mirrorMode: isLocal ? _c.yerelAyna : VideoViewMirrorMode.auto),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAramaKontroller(ActiveCallController c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ctrlButton(
          icon: c.micOn ? LucideIcons.mic : LucideIcons.micOff,
          active: !c.micOn,
          onTap: c.toggleMic,
        ),
        const SizedBox(width: 16),
        // MID-CALL: kamera butonu her zaman gorunur (grup dahil)
        _ctrlButton(
          icon: c.camOn ? LucideIcons.video : LucideIcons.videoOff,
          active: !c.camOn,
          onTap: _toggleCam,
        ),
        const SizedBox(width: 16),
        if (c.camOn) ...[
          _ctrlButton(
            icon: LucideIcons.switchCamera,
            onTap: c.flipCamera,
          ),
          const SizedBox(width: 16),
        ],
        _ctrlButton(
          icon: c.speakerOn ? LucideIcons.volume2 : LucideIcons.volumeX,
          active: c.speakerOn,
          onTap: c.toggleSpeaker,
        ),
        const SizedBox(width: 16),
        // Kapat — aramayi YALNIZ bu bitirir (tek kapi: controller.leave)
        GestureDetector(
          onTap: () => c.leave(notifyServer: true),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: Color(0xFFE53935), shape: BoxShape.circle),
            child: const Icon(LucideIcons.phoneOff, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  /// Cevapsiz/reddedilen: Geri Ara (peerId varsa) + Kapat.
  Widget _buildCevapsizKontroller(AramaBilgisi b) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (b.peerId != null) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _geriAra,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: Color(0xFF25D366), shape: BoxShape.circle),
                  child: Icon(b.video ? LucideIcons.video : LucideIcons.phone,
                      color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Geri Ara', style: TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(width: 40),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _c.leave(notifyServer: false),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                    color: Color(0xFFE53935), shape: BoxShape.circle),
                child: const Icon(LucideIcons.phoneOff, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Kapat', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioBackground(AramaBilgisi b) {
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
            b.peerName.isNotEmpty ? b.peerName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 48, color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// Katilimcinin CANLI video track'i (yerel: kamera acikken; uzak: abone + mute degil)
  VideoTrack? _katilimciVideosu(Participant p) {
    if (p is LocalParticipant) {
      if (!_c.camOn) return null;
      return p.videoTrackPublications.firstOrNull?.track;
    }
    for (final pub in p.videoTrackPublications) {
      if (pub.subscribed && !pub.muted && pub.track != null) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  bool _grupVideoVarMi() {
    final lp = _c.room?.localParticipant;
    if (lp != null && _katilimciVideosu(lp) != null) return true;
    for (final p in _c.room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      if (_katilimciVideosu(p) != null) return true;
    }
    return false;
  }

  /// GRUP: video varsa izgara, yoksa ESKI sesli avatar izgarasi BIREBIR.
  Widget _buildGroupGrid(AramaBilgisi b) {
    final katilimcilar = <Participant>[];
    final lp = _c.room?.localParticipant;
    if (lp != null) katilimcilar.add(lp);
    katilimcilar.addAll(_c.room?.remoteParticipants.values ?? const []);
    if (katilimcilar.any((p) => _katilimciVideosu(p) != null)) {
      return _grupVideoIzgara(katilimcilar);
    }
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF075E54), Color(0xFF0B141A)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 140, 20, 150),
        child: SingleChildScrollView(
          child: Center(
            child: Wrap(
              spacing: 22,
              runSpacing: 22,
              alignment: WrapAlignment.center,
              children: [for (final p in katilimcilar) _grupAvatar(p)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _grupAvatar(Participant p) {
    final yerel = p is LocalParticipant;
    final ad = p.name.isNotEmpty ? p.name : (yerel ? 'Sen' : 'Katılımcı');
    final harf = ad.isNotEmpty ? ad[0].toUpperCase() : '?';
    final konusuyor = p.isSpeaking;
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF128C7E), Color(0xFF25D366)]),
              border: konusuyor
                  ? Border.all(color: const Color(0xFF25D366), width: 4)
                  : Border.all(color: Colors.white24, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(harf,
                style: const TextStyle(
                    color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Text(yerel ? 'Sen' : ad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  /// GORUNTULU GRUP IZGARASI (kurallar AYNEN: kaydirma esigi, padding, DPR fixed(1.0))
  Widget _grupVideoIzgara(List<Participant> katilimcilar) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _uiToggle,
        child: Container(
        color: const Color(0xFF0B141A),
        padding: const EdgeInsets.fromLTRB(8, 108, 8, 132),
        child: LayoutBuilder(builder: (context, box) {
          final n = katilimcilar.length;
          final cols = n <= 2 ? 1 : 2;
          final rows = (n + cols - 1) ~/ cols;
          final gorunurSatir = rows > 4 ? 4 : rows;
          const bosluk = 6.0;
          final w = (box.maxWidth - (cols - 1) * bosluk) / cols;
          final h = (box.maxHeight - (gorunurSatir - 1) * bosluk) / gorunurSatir;
          return GridView.count(
            crossAxisCount: cols,
            mainAxisSpacing: bosluk,
            crossAxisSpacing: bosluk,
            childAspectRatio: w / h,
            padding: EdgeInsets.zero,
            physics: rows > 4
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            children: [for (final p in katilimcilar) _grupVideoTile(p)],
          );
        }),
        ),
      ),
    );
  }

  Widget _grupVideoTile(Participant p) {
    final yerel = p is LocalParticipant;
    final ad = yerel ? 'Sen' : (p.name.isNotEmpty ? p.name : 'Katılımcı');
    final video = _katilimciVideosu(p);
    final konusuyor = p.isSpeaking;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: konusuyor ? const Color(0xFF25D366) : Colors.white12,
          width: konusuyor ? 3 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video != null)
              IgnorePointer(
                child: VideoTrackRenderer(video,
                    key: ValueKey('tile-${video.sid}'),
                    fit: VideoViewFit.cover,
                    mirrorMode: yerel ? _c.yerelAyna : VideoViewMirrorMode.auto,
                    adaptiveStreamPixelDensity:
                        const AdaptiveStreamPixelDensity.fixed(1.0)),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF075E54), Color(0xFF0B141A)],
                  ),
                ),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white24,
                  child: Text(ad[0].toUpperCase(),
                      style: const TextStyle(fontSize: 26, color: Colors.white)),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qualityDot() {
    final color = switch (_c.quality) {
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

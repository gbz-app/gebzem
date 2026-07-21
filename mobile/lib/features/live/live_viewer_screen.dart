import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/api.dart';
import '../calls/call_media_options.dart';
import '../calls/call_provider.dart';
import '../calls/call_room_lock.dart';
import '../home/home_screen.dart' show myProfileProvider;
import '../invites/davet_sec_sheet.dart';
import 'live_gift_sheet.dart';
import 'live_info_sheets.dart';
import 'live_provider.dart';
import 'live_widgets.dart';

/// IZLEYICI ekrani: yayincinin videosu tam ekran + chat + kalp + hediye.
/// Mikrofon IZNI izleyicilikte HIC ISTENMEZ (token'da publish kapali); yalniz KONUK
/// olurken istenir (Bolum 6 I3). Sinyaller SendData'dan.
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
    this.tip = 'video',
    this.ilkKonukId = '',
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
  final String tip; // 'video' | 'audio' — katil istegi yalniz video yayinda
  // GEC KATILAN IZLEYICI (test turu 8): konuk zaten canlidayken yayina girenler guest.joined
  // sinyalini HIC almamisti -> split gorunmuyordu. Watch artik guest_id donduruyor.
  final String ilkKonukId;

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

  // KONUK DURUMU (Bolum 6 I3). Rol kaynagi SUNUCU (guest.* sinyalleri); istemci yalniz yansitir.
  String _benimId = '';
  // guest.joined -> konuk id; guest.left -> temizle (split sinyal-gate). Baslangic degeri
  // watch cevabindan (gec katilan izleyici konugu gorsun — test turu 8).
  late String _aktifKonuk = widget.ilkKonukId;
  bool _konukum = false; // guest.accepted geldi + medya acildi
  bool _istekGitti = false; // bekleyen katil istegim var
  bool _konukMicOn = true;
  bool _onKamera = true; // ayna kurali (on=aynali)

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
    // Kendi kimligim: guest.left {user_id} sinyalinde "ben miyim" ayrimi icin
    ref.read(myProfileProvider.future).then((p) {
      _benimId = p['id'] as String? ?? '';
    }).catchError((_) {});
    _nabiz = Timer.periodic(const Duration(seconds: 15),
        (_) => ref.read(liveApiProvider).nabiz(widget.streamId).catchError((_) {}));
    _baglan();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_ayrildi) {
      _sesiAc(true); // kesinti toparlama
      if (_konukum) {
        // Konuk mikrofonu kesinti sonrasi kendiliginden geri gelmez (oda ekrani dersi)
        _room?.localParticipant?.setMicrophoneEnabled(_konukMicOn);
      }
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
      // GRUP medya profilleri BASTAN (Bolum 6 karari): SDK publish varsayilanlari
      // RoomOptions'tan gelir — konuk olununca 540p/700kbps profiliyle yayinlanir.
      // Izleyicilikte hicbir etkisi yok (publish kapali).
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: kGroupCameraCaptureOptions,
        defaultVideoPublishOptions: kGroupVideoPublishOptions,
        defaultAudioCaptureOptions: kAudioCaptureOptions,
        defaultAudioPublishOptions: kAudioPublishOptions,
      ),
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
        // KONUK ATILMA BUG'I (test turu 4): konuk cikarilinca track MUTE/UNPUBLISH olur
        // (unsubscribe hemen gelmez) — bu event'ler dinlenmezse split KALKMAZ, siyah kalir.
        ..on<lk.TrackMutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackUnmutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackUnpublishedEvent>((_) {
          if (mounted) setState(() {});
        })
        // KONUK SERT-KAPATMA/AG-OLUMU (test turu 7 kok fix): uzak konuk app-kill/airplane ->
        // guest.left gelmez, split ~60sn takili kalirdi. identity==_aktifKonuk ise temizle.
        // _konukum (BEN konuk) yolu bundan etkilenmez (kendi participant'im disconnect olmaz).
        ..on<lk.ParticipantDisconnectedEvent>((e) {
          if (!mounted) return;
          if (e.participant.identity == _aktifKonuk) {
            setState(() => _aktifKonuk = '');
          } else {
            setState(() {});
          }
        })
        ..on<lk.RoomReconnectedEvent>((_) {
          // FULL reconnect grant'i TOKEN'dan yukler (izleyici=publish kapali) — konuksam
          // sunucudan izni idempotent geri iste (D4).
          // TARAMA #5: 403 = konuklugum sunucuda dusmus (sweep beni offline'ken almis) ->
          // bayat 'konugum' durumunda TAKILI KALMA: durustce izleyicilige don.
          if (mounted && _konukum) {
            ref.read(liveApiProvider).konukYenile(widget.streamId).catchError((e) {
              if (!mounted || !_konukum) return;
              final st = e is DioException ? e.response?.statusCode : null;
              if (st == 403) {
                _konuktanCik(sunucuyaBildir: false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Konukluktan çıkarıldın — izlemeye devam ediyorsun')));
              }
            });
          }
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
      // ---- KONUK sinyalleri (Bolum 6): accepted/declined YALNIZ bana gelir (SendDataTo) ----
      case 'guest.accepted':
        _konukOl();
      case 'guest.declined':
        setState(() => _istekGitti = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yayıncı isteğini şimdilik kabul etmedi')));
      case 'guest.joined':
        // SINYAL-BAZLI konuk (test turu 5): aktif konuk id'sini yakala -> split panel buna
        // bagli (atilinca ANINDA kalksin). Ben degilsem uzak konuk panelini gosterir.
        setState(() => _aktifKonuk = v['user_id'] as String? ?? '');
      case 'guest.left':
        // TARAMA #6: ben-mi ayrimi LiveKit identity ile (token identity = user_id;
        // SENKRON ve her zaman dolu) — _benimId asenkron/profil-hatasi durumunda bos
        // kalabiliyordu ve demote KACIYORDU. _benimId yalniz yedek.
        final gidenId = v['user_id'] as String?;
        final benim = _room?.localParticipant?.identity ?? _benimId;
        if (gidenId != null && gidenId == benim && _konukum) {
          // TEST TURU 8 KOK FIX: giden konuk BENIM. guest.joined sirasinda _aktifKonuk
          // KENDI id'me kurulmustu; burada temizlenmeyince split "Görüntü bekleniyor"da
          // SONSUZA takiliyordu (kendi id'm remoteParticipants'ta hic eslesmez).
          setState(() {
            if (_aktifKonuk == gidenId) _aktifKonuk = '';
          });
          _konuktanCik(sunucuyaBildir: false); // yayinci cikardi / sweep
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Yayıncı seni izleyiciliğe aldı')));
        } else {
          // Uzak konuk atildi -> aktif konuk id'sini temizle (split ANINDA kalksin, siyah kalmasin)
          setState(() {
            if (gidenId == null || gidenId == _aktifKonuk) _aktifKonuk = '';
          });
        }
      case 'stream.ended':
        _yayinBitti();
    }
  }

  // ---- KONUK AKISI (Bolum 6 I3) ----

  /// Katil istegi gonder/geri cek (yalniz video yayinda gorunur).
  Future<void> _istekToggle() async {
    final mesajci = ScaffoldMessenger.of(context);
    final yeni = !_istekGitti;
    try {
      await ref.read(liveApiProvider).katilIstek(widget.streamId, cancel: !yeni);
      if (!mounted) return;
      setState(() => _istekGitti = yeni);
      mesajci.showSnackBar(SnackBar(
          content: Text(yeni
              ? 'Katılma isteği gönderildi — yayıncı kabul ederse canlıya geçersin'
              : 'İstek geri çekildi')));
    } catch (e) {
      if (mounted) mesajci.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  /// guest.accepted geldi: izinler -> mic -> kamera -> ses birimi EN SON (iOS sirasi).
  /// Izin reddi/medya hatasi = sunucuya konukAyril DURUSTLUGU (slot bosalsin, tek konuk kilidi
  /// takili kalmasin). Medya acilisinda 1 sn arayla TEK retry.
  Future<void> _konukOl() async {
    if (_konukum || _ayrildi) return;
    final mesajci = ScaffoldMessenger.of(context);
    setState(() => _istekGitti = false);
    final mikIzin = await Permission.microphone.request();
    final kamIzin = await Permission.camera.request();
    if (!mounted || _ayrildi) return;
    if (mikIzin != PermissionStatus.granted || kamIzin != PermissionStatus.granted) {
      unawaited(ref.read(liveApiProvider).konukAyril(widget.streamId));
      mesajci.showSnackBar(const SnackBar(
          content: Text('Kamera ve mikrofon izni olmadan canlıya katılamazsın')));
      return;
    }
    Future<void> ac() async {
      await _room?.localParticipant?.setMicrophoneEnabled(true);
      await _room?.localParticipant?.setCameraEnabled(true);
    }

    try {
      try {
        await ac();
      } catch (_) {
        await Future.delayed(const Duration(seconds: 1)); // tek retry (izin sonrasi yaris)
        await ac();
      }
      await _sesiAc(true); // iOS ses birimi EN SON (v7/v8 dersi)
      if (!mounted || _ayrildi) return;
      setState(() {
        _konukum = true;
        _konukMicOn = true;
        _onKamera = true;
      });
      mesajci.showSnackBar(
          const SnackBar(content: Text('Canlıdasın! 🎥 Ayrılmak için ✕ Ayrıl')));
    } catch (e) {
      await Sentry.captureException(e, stackTrace: StackTrace.current);
      // Medya acilamadi: kismi acilani kapat + sunucuya birak
      try {
        await _room?.localParticipant?.setCameraEnabled(false);
        await _room?.localParticipant?.setMicrophoneEnabled(false);
      } catch (_) {}
      unawaited(ref.read(liveApiProvider).konukAyril(widget.streamId));
      if (mounted) {
        mesajci.showSnackBar(
            const SnackBar(content: Text('Kamera açılamadı — canlıya katılınamadı')));
      }
    }
  }

  /// Konuk kontrol pill'i: mic / kamera cevir / ayril (split panel sag-ust; fallback konum
  /// kamera acilamadiginda). Icerik eski PiP-alti pill'in BIREBIR tasinmis hali.
  Widget _konukPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(_konukMicOn ? LucideIcons.mic : LucideIcons.micOff,
              size: 18, color: _konukMicOn ? Colors.white : Colors.redAccent),
          onPressed: () async {
            final on = !_konukMicOn;
            await _room?.localParticipant?.setMicrophoneEnabled(on);
            if (mounted) setState(() => _konukMicOn = on);
          },
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(LucideIcons.switchCamera, size: 18, color: Colors.white),
          onPressed: () async {
            final t = _konukVideo;
            if (t == null) return;
            try {
              final onMu = await rtc.Helper.switchCamera(t.mediaStreamTrack);
              if (mounted) setState(() => _onKamera = onMu);
            } catch (_) {}
          },
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Canlıdan ayrıl',
          icon: const Icon(LucideIcons.x, size: 18, color: Colors.redAccent),
          onPressed: () => _konuktanCik(sunucuyaBildir: true),
        ),
      ]),
    );
  }

  /// Konukluktan izleyicilige don. _sesiAc(false) CAGRILMAZ — dinlemeye devam (plan karari).
  Future<void> _konuktanCik({required bool sunucuyaBildir}) async {
    if (!_konukum) return;
    final benim = _room?.localParticipant?.identity ?? _benimId;
    setState(() {
      _konukum = false;
      // TEST TURU 8: kendi id'me isaret eden bayat _aktifKonuk'u da temizle — yoksa
      // konukVar true kalir, alt panel "Görüntü bekleniyor"da takilir (kok neden).
      if (_aktifKonuk.isNotEmpty && _aktifKonuk == benim) _aktifKonuk = '';
    });
    try {
      await _room?.localParticipant?.setCameraEnabled(false);
      await _room?.localParticipant?.setMicrophoneEnabled(false);
    } catch (_) {}
    if (sunucuyaBildir) {
      try {
        await ref.read(liveApiProvider).konukAyril(widget.streamId);
      } catch (_) {}
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
    // Bekleyen istegimi geri cek (yayincinin listesinde hayalet kalmasin). Konuklugu ayrica
    // bildirmeye gerek yok: /leave sunucuda konukDusur'u zaten cagirir (B7).
    if (_istekGitti) {
      unawaited(
          ref.read(liveApiProvider).katilIstek(widget.streamId, cancel: true).catchError((_) {}));
    }
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

  /// Tam ekran video = YALNIZ YAYINCININ track'i (identity filtresi KRITIK — Bolum 6:
  /// konuk yayina baslayinca tam ekrani KAPMASIN, PiP'te kalsin).
  lk.VideoTrack? get _video {
    for (final p in _room?.remoteParticipants.values ?? const <lk.RemoteParticipant>[]) {
      if (p.identity != widget.yayinciId) continue; // yayinci-identity filtresi KORUNUR
      for (final pub in p.videoTrackPublications) {
        // !muted (test turu 4): yayinci kamerayi kapatirsa "Goruntu bekleniyor"e dusmeli
        if (pub.subscribed && !pub.muted && pub.track != null) {
          return pub.track as lk.VideoTrack;
        }
      }
    }
    return null;
  }

  /// PiP'teki konuk videosu — TRACK-BAZLI render (dusurulen konugun track'siz participant'i
  /// kalsa bile gorunmez). Konuk BENSEM kendi kameram (lokal, aynali).
  lk.VideoTrack? get _konukVideo {
    if (_konukum) {
      final t = _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
      return t is lk.VideoTrack ? t : null;
    }
    // UZAK konuk: SINYAL-BAZLI (test turu 5) — yalniz _aktifKonuk identity'si (guest.left ->
    // temizlenir -> split ANINDA kalkar). !muted -> konuk kamera kapatirsa "Görüntü bekleniyor".
    if (_aktifKonuk.isEmpty) return null;
    for (final p in _room?.remoteParticipants.values ?? const <lk.RemoteParticipant>[]) {
      if (p.identity != _aktifKonuk) continue;
      for (final pub in p.videoTrackPublications) {
        if (pub.subscribed && !pub.muted && pub.track != null) {
          return pub.track as lk.VideoTrack;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final konukVideo = _konukVideo;
    // SINYAL-BAZLI split (test turu 5): konuk BEN (_konukum) ya da aktif uzak konuk (_aktifKonuk)
    // varsa split; atilinca sinyal temizlenir -> ANINDA tam ekrana doner (siyah kalmaz).
    // TEST TURU 8 KIMLIK KAPISI: _aktifKonuk KENDI id'imse ve konuk DEGILSEM (atilma/ayrilma
    // sonrasi bayat sinyal) split ASLA cizilmez — "Görüntü bekleniyor" takilmasi yapisal olarak
    // imkansizlasir (sinyal sirasi ne olursa olsun).
    final benim = _room?.localParticipant?.identity ?? _benimId;
    final konukVar =
        _konukum || (_aktifKonuk.isNotEmpty && _aktifKonuk != benim);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cik();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: Stack(children: [
          Positioned.fill(
            // SINYAL-BAZLI split (test turu 5): konuk sinyali varsa GRUP GIBI dikey SPLIT
            // (ust: yayinci, alt: konuk); konuk atilinca sinyal temizlenir -> ANINDA tam ekran.
            child: konukVar
                ? yayinSplitAlani(
                    ust: SplitVideoPaneli(
                        track: video,
                        etiket: widget.yayinciAd,
                        bosMetin: 'Yayıncı bekleniyor...'),
                    alt: SplitVideoPaneli(
                      track: konukVideo,
                      mirrorMode: _konukum
                          ? (_onKamera
                              ? lk.VideoViewMirrorMode.mirror
                              : lk.VideoViewMirrorMode.off)
                          : lk.VideoViewMirrorMode.auto,
                      etiket: _konukum ? 'Sen' : '',
                      bosMetin: 'Görüntü bekleniyor...',
                      ustKatman: _konukum
                          ? Positioned(top: 6, right: 6, child: _konukPill())
                          : null,
                    ),
                  )
                : video != null
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
          // NOT (test turu 5): konuk pill'i artik split alt panelinin ustKatman'inda HER ZAMAN
          // gorunur (_konukum iken; kamera acilmasa da bosMetin+pill). Ayri fallback KALDIRILDI
          // (cift pill olurdu — split artik konukVar ile daima ciziliyor).
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
                      GestureDetector(
                        // 👁 -> kimler izliyor (Bolum 6; izleyicide salt-okunur liste)
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => IzleyicilerSheet(
                              streamId: widget.streamId, yayinciyim: false),
                        ),
                        child: Text('👁 $_izleyici',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ),
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
                    // KATIL ISTEGI (Bolum 6): yalniz video yayininda ve konuk degilken
                    if (!_konukum && widget.tip == 'video')
                      IconButton(
                          tooltip: _istekGitti
                              ? 'İsteği geri çek'
                              : 'Canlıya katılma isteği gönder',
                          onPressed: _istekToggle,
                          icon: Icon(LucideIcons.hand,
                              color: _istekGitti
                                  ? Colors.amberAccent
                                  : Colors.white70)),
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

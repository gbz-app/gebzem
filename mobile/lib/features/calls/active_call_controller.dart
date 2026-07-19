import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/api.dart';
import '../../router.dart';
import 'call_media_options.dart';
import 'call_provider.dart';
import 'call_room_lock.dart';
import 'call_screen.dart';
import 'call_sounds.dart';
import 'callkit_service.dart';

/// ARAMA META BILGISI — CallScreen'in eski constructor parametrelerinin birebir kopyasi.
class AramaBilgisi {
  const AramaBilgisi({
    required this.callId,
    required this.url,
    required this.token,
    required this.video,
    required this.peerName,
    this.peerId,
    this.outgoing = true,
    this.isGroup = false,
    this.chatTitle = '',
    this.elapsedMs,
  });

  final String callId;
  final String url;
  final String token;
  final bool video;
  final String peerName;
  final String? peerId; // "Geri Ara" + mesaj ikonu icin (giden 1:1'de dolu)
  final bool outgoing;
  final bool isGroup; // BASLANGIC degeri — canli deger controller._isGroup (yukseltme)
  final String chatTitle;
  final int? elapsedMs; // SURE SENKRONU baslangic referansi (answer cevabi ~0)
}

/// AKTIF ARAMA CONTROLLER'I (parite-hukum C1 / Plan 2): Room + listener + TUM timer'lar +
/// sure Stopwatch'i + ses birimi/nesli + muhafiz cagrilari BURADA yasar — CallScreen SAF
/// GORUNUM. Uygulama boyu YASAR (autoDispose YOK); "ekran dispose'u aramayi BITIRMEZ"
/// (minimize sayilir). Aramayi yalniz `leave` TEK KAPISI bitirir.
///
/// KOPYALAMA YASAKLARI (hukum — REGRESYON YAPMA):
/// - iOS SES SIRASI: mic -> kamera -> setSpeakerOn(false) -> _sesiAc(true) EN SON (v7/v8)
/// - SURE SENKRONU: referans YALNIZ s=='active' iken; created_at'e DUSURME; push sure TASIMAZ;
///   grup HARIC yerel sayac; monotonik Stopwatch (_sureBaz + _sureSayaci.elapsed)
/// - ParticipantDisconnected GRUP dalinda otomatik leave YOK (oda bitisi backend'den)
/// - relay ICE; grup 540p profili; durumMetni kapi sirasi
/// - Teardown "ENQUEUE ANINDA YAKALA" (KARAR 4): kuyruga koyarken room/listener/nesil
///   SENKRON yakalanir — tek controller'da alanlar yeni aramada resetlenir, bekleyen eski
///   teardown yeni Room'u OLDURMESIN.
class ActiveCallController extends ChangeNotifier with WidgetsBindingObserver {
  ActiveCallController(this._ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;
  CallService get _svc => _ref.read(callServiceProvider.notifier);

  // ---- ARAMA DURUMU (null = arama yok) ----
  AramaBilgisi? arama;
  bool minimized = false;
  bool ekranGorunur = false; // CallScreen kendini kaydeder (cift-push korumasi)

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  StreamSubscription? _endedSub;
  StreamSubscription? _answeredSub;
  StreamSubscription? _partSub;
  Timer? _durationTimer;
  Timer? _ringTimeout;
  Timer? _statusPoll;
  Timer? _statsTimer;
  Timer? _mediaYedek;

  int _sonRecvPaket = 0;
  double _sonEnergy = 0;
  int _sonSentPaket = 0;
  double _sonMikEnerji = 0;
  int _oluMikSayaci = 0;
  bool _sesKurtarmaDenendi = false;

  bool _isGroup = false; // canli deger (call.upgraded / Status is_group ile guncellenir)
  int? _sesNesli; // CallSounds nesli
  bool _connecting = true;
  bool _kapandi = false;
  bool _baglandi = false;
  bool _ayrildi = false;
  bool _peerJoined = false;
  bool _mediaBasladi = false;
  bool _micOn = true;
  bool _camOn = false;
  bool _speakerOn = false;
  bool _frontCamera = true;
  String? _error;
  Duration _duration = Duration.zero;
  final Stopwatch _sureSayaci = Stopwatch();
  Duration _sureBaz = Duration.zero;
  bool _sureReferansVar = false;
  ConnectionQuality _quality = ConnectionQuality.unknown;
  bool _cevapsiz = false;
  String _cevapsizNeden = 'Cevap yok';

  // ---- SAF GORUNUM icin okunan alanlar ----
  Room? get room => _room;
  bool get isGroup => _isGroup;
  bool get connecting => _connecting;
  bool get baglandi => _baglandi;
  bool get peerJoined => _peerJoined;
  bool get mediaBasladi => _mediaBasladi;
  bool get micOn => _micOn;
  bool get camOn => _camOn;
  bool get speakerOn => _speakerOn;
  bool get frontCamera => _frontCamera;
  String? get error => _error;
  Duration get duration => _duration;
  ConnectionQuality get quality => _quality;
  bool get cevapsiz => _cevapsiz;
  String get cevapsizNeden => _cevapsizNeden;

  /// Minimize kapisi (hukum K2 ile ayni): yalniz BAGLI ve saglikli aramada.
  bool get minimizeEdilebilir =>
      arama != null && _baglandi && !_cevapsiz && _error == null;

  String get durumMetni {
    // KAPI SIRASI AYNEN (_statusText — yargic YAPMA listesi: degistirme)
    if (_cevapsiz) return _cevapsizNeden;
    if (_error != null) return _error!;
    if (_connecting) return 'Baglaniliyor...';
    if (!_peerJoined) return (arama?.outgoing ?? true) ? 'Caliyor...' : 'Bekleniyor...';
    if (!_mediaBasladi) return 'Bağlanıyor...';
    final m = _duration.inMinutes.toString().padLeft(2, '0');
    final s = (_duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Yerel goruntu ayna kurali: ON aynali, ARKA aynasiz (kamera-ters fix'i). Uzak HEP auto.
  VideoViewMirrorMode get yerelAyna =>
      _frontCamera ? VideoViewMirrorMode.mirror : VideoViewMirrorMode.off;

  // ---- YASAM DONGUSU ----

  /// Yeni aramayi baslat (eski initState govdesi). Cagiran ONCE REST'i (start/answer)
  /// tamamlamis olmali — b.url/token hazir gelir. Ekrani ACMAZ (ekraniAc ayri).
  Future<void> baslat(AramaBilgisi b) async {
    // Tum tek-seferlik bayraklar RESET (teardown'i etkilemez — KARAR 4: bekleyen
    // teardown'lar enqueue aninda yakalanmis nesnelerle calisir).
    _iptalAbonelikler();
    arama = b;
    minimized = false;
    _isGroup = b.isGroup;
    _connecting = true;
    _kapandi = false;
    _baglandi = false;
    _ayrildi = false;
    _peerJoined = false;
    _mediaBasladi = false;
    _micOn = true;
    _camOn = b.video;
    _speakerOn = false;
    _frontCamera = true;
    _error = null;
    _duration = Duration.zero;
    _sureBaz = Duration.zero;
    _sureReferansVar = false;
    _sureSayaci
      ..stop()
      ..reset();
    _quality = ConnectionQuality.unknown;
    _cevapsiz = false;
    _cevapsizNeden = 'Cevap yok';
    _sonRecvPaket = 0;
    _sonEnergy = 0;
    _sonSentPaket = 0;
    _sonMikEnerji = 0;
    _oluMikSayaci = 0;
    _sesKurtarmaDenendi = false;
    _sesNesli = null;

    final id = b.callId;
    // SURE SENKRONU: ARANAN tarafta answer() cevabindaki gecen-sure (~0); grupta kullanilmaz.
    _sureReferansiAl(b.elapsedMs);
    // MESGUL MUHAFIZI: calar fazi dahil isaretle; yalniz leave birakir.
    _svc.ekranAcildi(id);

    // KISI EKLEME: yukseltme sinyali (WS call.upgraded) — grup moduna gecis.
    _partSub = _svc.onParticipant.listen((ev) {
      if (arama?.callId != id || _ayrildi) return;
      if (ev['event'] == 'call.upgraded' && !_isGroup) {
        _isGroup = true;
        notifyListeners();
        rootMessengerKey.currentState?.showSnackBar(SnackBar(
            content: Text('${ev['added_name'] ?? 'Bir kisi'} aramaya kisi ekledi')));
      } else if (_isGroup) {
        notifyListeners(); // izgara tazelensin (joined/left)
      }
    });

    // Karsi taraf kapatti / arama bitti.
    _endedSub = _svc.onCallEnded.listen((eid) async {
      if (eid != id || arama?.callId != id || _ayrildi) return;
      if (_baglandi) {
        leave(notifyServer: false);
        return;
      }
      String s = '';
      try {
        s = (await _svc.callStatus(id))['status'] as String? ?? '';
      } catch (_) {}
      if (arama?.callId != id || _ayrildi || _baglandi) return;
      if (s == 'ended') {
        leave(notifyServer: false);
      } else {
        _cevapsizGoster(s == 'rejected'
            ? 'Arama reddedildi'
            : s == 'busy'
                ? 'Mesgul'
                : 'Cevap yok');
      }
    });

    if (b.outgoing) {
      // GIDEN ARAMA: karsi taraf acana kadar odaya BAGLANMA.
      _answeredSub = _svc.onCallAnswered.listen((ev) {
        if (ev['call_id'] != id || arama?.callId != id || _ayrildi) return;
        _sureReferansiAl((ev['elapsed_ms'] as num?)?.toInt());
        if (!_baglandi) {
          CallSounds.durdur(_sesNesli);
          _connect();
        }
      });
      // GRUP HOST'U DOGRUDAN BAGLANIR (grup-host mic fix'i wf_32afbd46 — kaldirma!):
      // backend grubu ANINDA 'active' yapar; calmaTonu+poll yolu iOS mic'i sessiz kilitliyordu.
      if (_svc.kabulEdilenler.contains(id) || _isGroup) {
        _connect();
        return;
      }
      CallSounds.calmaTonu().then((n) => _sesNesli = n);
      _ringTimeout = Timer(const Duration(seconds: 45), () async {
        if (arama?.callId != id || _baglandi || _ayrildi) return;
        String s = '';
        try {
          s = (await _svc.callStatus(id))['status'] as String? ?? '';
        } catch (_) {}
        if (arama?.callId != id || _baglandi || _ayrildi) return;
        if (s == 'active') {
          CallSounds.durdur(_sesNesli);
          _connect();
        } else {
          _cevapsizGoster('Cevap yok', sunucuyaBildir: true);
        }
      });
      _statusPoll = Timer.periodic(const Duration(seconds: 2), (_) => _durumKontrol());
      _connecting = false; // "Caliyor..." goster
      notifyListeners();
    } else {
      _connect();
    }
  }

  /// Sunucudaki arama durumunu bir kez sorup uzlastir (ring 2sn / aktif 3sn / resume).
  Future<void> _durumKontrol() async {
    final id = arama?.callId;
    if (id == null || _ayrildi || _cevapsiz) return;
    String s;
    try {
      final st = await _svc.callStatus(id);
      s = st['status'] as String? ?? '';
      // SURE SENKRONU KURTARMA: YALNIZ 'active' iken referans (zil fazinda KILITLEME —
      // sayac sisme blocker'inin kok fix'i; created_at'e dusurme YOK).
      if (s == 'active') _sureReferansiAl((st['elapsed_ms'] as num?)?.toInt());
      // KISI EKLEME KURTARMASI: WS call.upgraded kaybolduysa poll'dan yakala.
      if (st['is_group'] == true && !_isGroup) {
        _isGroup = true;
        notifyListeners();
      }
    } catch (_) {
      return;
    }
    if (arama?.callId != id || _ayrildi || _cevapsiz) return;
    if (s == 'active') {
      if (!_baglandi) {
        CallSounds.durdur(_sesNesli);
        _connect();
      }
      return;
    }
    if (s == 'ended') {
      leave(notifyServer: false);
      return;
    }
    if (s == 'rejected' || s == 'missed' || s == 'busy') {
      if (_baglandi) {
        leave(notifyServer: false);
      } else {
        _cevapsizGoster(s == 'rejected'
            ? 'Arama reddedildi'
            : s == 'busy'
                ? 'Mesgul'
                : 'Cevap yok');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && arama != null && !_ayrildi && !_cevapsiz) {
      _durumKontrol();
      // KESINTI TOPARLAMA: iOS CallKit didActivate kesinti sonrasi guvenilir gelmez ->
      // resume yedek tetikleyici (ses birimi + mic son durumu).
      if (_baglandi) _kesintidenTopla();
    }
  }

  Future<void> _kesintidenTopla() async {
    _sesLog('kesintiden topla (resume)');
    await _sesiAc(true);
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(_micOn);
    } catch (_) {}
  }

  /// Cevapsiz/reddedilen: ekran KAPANMADAN "Cevap yok" durumuna gec (Geri Ara/Kapat).
  Future<void> _cevapsizGoster(String neden, {bool sunucuyaBildir = false}) async {
    if (_baglandi || _ayrildi || _cevapsiz) return;
    final id = arama?.callId ?? '';
    // MESGUL MUHAFIZINI BIRAK (v13): cevapsiz ekran artik aktif arama degil.
    _svc.ekranKapandi(id);
    await CallSounds.durdur(_sesNesli);
    _ringTimeout?.cancel();
    _statusPoll?.cancel();
    if (sunucuyaBildir) {
      try {
        await _svc.end(id);
      } catch (_) {}
    }
    _svc.gecmisiYenile();
    _cevapsiz = true;
    _cevapsizNeden = neden;
    notifyListeners();
  }

  /// "Geri Ara" — cevapsiz ekrandan ayni kisiyi tekrar ara. Yeni aramayi BASLATIR;
  /// ekran acik kalir ve controller'in yeni durumunu render eder (pushReplacement gereksiz).
  Future<bool> geriAra() async {
    final b = arama;
    final pid = b?.peerId;
    if (b == null || pid == null) return false;
    // Cevapsiz ekran "aramada" sayilmasin — yoksa start() "Zaten bir aramadasiniz" der.
    _svc.ekranKapandi(b.callId);
    try {
      final info = await _svc.start(pid, video: b.video);
      await baslat(AramaBilgisi(
        callId: info['call_id'] as String,
        url: info['url'] as String,
        token: info['token'] as String,
        video: b.video,
        peerName: b.peerName,
        peerId: pid,
        outgoing: true,
      ));
      return true;
    } catch (e) {
      rootMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      return false;
    }
  }

  Future<void> _connect() async {
    if (_baglandi) return;
    _baglandi = true;
    _statusPoll?.cancel();
    final b = arama;
    if (b == null) return;
    final id = b.callId;
    try {
      final perms = <Permission>[Permission.microphone];
      if (b.video) perms.add(Permission.camera);
      final statuses = await perms.request();
      if (statuses[Permission.microphone] != PermissionStatus.granted) {
        if (arama?.callId != id) return;
        _error = 'Arama icin mikrofon izni gerekli';
        _connecting = false;
        notifyListeners();
        return;
      }
      _connecting = true;
      notifyListeners();

      await CallRoomLock.calistir(_odayaBaglan);
      // TEK BITIR-KAPISI: canli konusma basladi (CallKit yanlis-zamanli olaylari oldurmesin).
      _svc.aktifKonusmaBasladi(id);
      _aktifPollBaslat();
      _statsBaslat();
    } catch (e) {
      // TARAMA #3: STALE cagri (baska arama devralmis) paylasilan _sesNesli'yi okuyup
      // YENI aramanin calma tonunu susturmasin — ses yalniz hala benim aramamsa durur.
      if (arama?.callId == id) await CallSounds.durdur(_sesNesli);
      // BAGLANAMADIK: muhafizi birak + aramayi sunucuda dusur (0ba750d7 hukmu).
      _svc.ekranKapandi(id);
      unawaited(_svc.end(id));
      await Sentry.captureException(e, stackTrace: StackTrace.current);
      if (arama?.callId == id) {
        final msg = e.toString().toLowerCase();
        _error = msg.contains('timeout') || msg.contains('ice') || msg.contains('dtls')
            ? 'Baglanti kurulamadi.\nInternet baglantinizi kontrol edin.'
            : 'Arama baslatilamadi.\nTekrar deneyin.';
        _connecting = false;
        notifyListeners();
      }
    }
  }

  /// Odaya baglanma — CallRoomLock sirasinda (onceki aramanin kapanisi BITMIS olur).
  Future<void> _odayaBaglan() async {
    final b = arama;
    if (b == null) return;
    // TARAMA #2: TUM listener callback'leri ve stale kontrolleri BU cagrinin callId'sini
    // yakalar — eski odanin gecikmis eventi (RoomDisconnected vb.) YENI aramayi olduremez.
    final id = b.callId;
    final room = Room(
      roomOptions: RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        // GRUP: 540p/700kbps profili; 1:1: 720p (call_media_options — degistirme)
        defaultCameraCaptureOptions:
            _isGroup ? kGroupCameraCaptureOptions : kCameraCaptureOptions,
        defaultVideoPublishOptions:
            _isGroup ? kGroupVideoPublishOptions : kVideoPublishOptions,
        defaultAudioCaptureOptions: kAudioCaptureOptions,
        defaultAudioPublishOptions: kAudioPublishOptions,
      ),
    );
    // Odayi HEMEN alana ata (baglanirken cikis -> teardown bulabilsin; sizinti olmasin)
    _room = room;

    final listener = room.createListener();
    _listener = listener;
    try {
      listener
        ..on<ParticipantConnectedEvent>((_) {
          if (arama?.callId != id) return;
          _ringTimeout?.cancel();
          _peerJoined = true;
          notifyListeners();
          _mediaGuvenlikAgi(); // sure GERCEK ses gelince baslar; 8sn yedek
        })
        ..on<ParticipantDisconnectedEvent>((_) {
          if (arama?.callId != id) return;
          if (_isGroup) {
            // GRUP: biri ayrilinca arama SURER — otomatik leave YOK (backend yonetir).
            notifyListeners();
            return;
          }
          leave(notifyServer: true); // 1:1: karsi taraf ayrildi
        })
        ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
          if (arama?.callId == id && e.participant is LocalParticipant) {
            _quality = e.connectionQuality;
            notifyListeners();
          }
        })
        ..on<TrackSubscribedEvent>((e) {
          if (arama?.callId != id) return;
          notifyListeners();
          if (e.track is VideoTrack) {
            // Ilk-kare texture tekmesi
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (arama?.callId == id) notifyListeners();
            });
            Future.delayed(const Duration(milliseconds: 400), () {
              if (arama?.callId == id) notifyListeners();
            });
          }
          if (e.track is AudioTrack) {
            _sesLog('remote AUDIO track subscribe oldu (ses akisi basladi)');
            _mediaBaslat();
          }
        })
        ..on<TrackUnsubscribedEvent>((_) {
          if (arama?.callId == id) notifyListeners();
        })
        ..on<TrackMutedEvent>((_) {
          if (arama?.callId == id) notifyListeners();
        })
        ..on<TrackUnmutedEvent>((_) {
          if (arama?.callId == id) notifyListeners();
        })
        ..on<ActiveSpeakersChangedEvent>((_) {
          if (arama?.callId == id && _isGroup) notifyListeners();
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (arama?.callId == id) leave(notifyServer: false);
        });

      await room.connect(
        b.url,
        b.token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
          // MEDYA HER ZAMAN TURN RELAY (TR operator CGNAT karari — degistirme)
          rtcConfiguration: RTCConfiguration(
            iceTransportPolicy: RTCIceTransportPolicy.relay,
          ),
        ),
      );
      // iOS SES SIRASI (KRITIK v7/v8 — AYNEN): mic -> kamera -> speaker(false) -> _sesiAc EN SON
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (b.video) {
        await room.localParticipant?.setCameraEnabled(true);
      }
      await room.setSpeakerOn(false); // varsayilan kulaklik (earpiece)
      await _sesiAc(true); // SES BIRIMI EN SON
      _sesLog('ses kuruldu: video=${b.video}');

      // Bu arada ayrildiysak odayi birak (sizinti olmasin).
      // TARAMA #1 (kritik): _kapatOdayiKuyrugaKoy CAGRILMAZ — o metot controller'in
      // GUNCEL (belki yeni aramanin) bayrak/timer'larini degistirir; stale cagri yalniz
      // KENDI yerel nesnelerini temizler.
      if (_ayrildi || arama?.callId != id) {
        _staleTemizle(room, listener);
        return;
      }
      _ringTimeout?.cancel();
      _connecting = false;
      _speakerOn = false;
      _peerJoined = room.remoteParticipants.isNotEmpty;
      notifyListeners();
      if (_remoteAudioHazir()) {
        _mediaBaslat();
      } else if (_peerJoined) {
        _mediaGuvenlikAgi();
      }
    } catch (e) {
      // TARAMA #1: yalniz HALA benim aramamsa tam teardown (bayraklar/timer'lar dahil);
      // stale isem (yeni arama devralmis) yalniz yerel nesneleri temizle.
      if (!_ayrildi && arama?.callId == id) {
        _kapatOdayiKuyrugaKoy();
      } else {
        _staleTemizle(room, listener);
      }
      rethrow;
    }
  }

  /// STALE _odayaBaglan temizligi (TARAMA #1): controller alan/bayrak/timer'larina
  /// DOKUNMADAN yalniz bu cagrinin yakaladigi room/listener'i kilit sirasinda kapatir.
  /// Alanlar ancak HALA bu cagriya aitse null'lanir (yeni arama devraldiysa ellenmez).
  void _staleTemizle(Room room, EventsListener<RoomEvent> listener) {
    final nesil = _benimSesNeslim;
    if (identical(_room, room)) _room = null;
    if (identical(_listener, listener)) _listener = null;
    unawaited(CallRoomLock.calistir(() => _odaTemizle(room, listener, nesil)));
  }

  void _aktifPollBaslat() {
    _statusPoll?.cancel();
    _statusPoll = Timer.periodic(const Duration(seconds: 3), (_) => _durumKontrol());
  }

  /// SES NOKTA-ATISI olcumu (2sn) — recv/enerji + GONDEREN sent/mikE + OLU-MIK oto-kurtarma.
  void _statsBaslat() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final b = arama;
      if (b == null || !_baglandi) return;
      try {
        int recv = -1;
        double energy = 0;
        final rp = _room?.remoteParticipants.values.firstOrNull;
        final track = rp?.audioTrackPublications.firstOrNull?.track;
        if (track is RemoteAudioTrack) {
          final s = await track.getReceiverStats();
          recv = (s?.packetsReceived ?? 0).toInt();
          energy = (s?.totalAudioEnergy ?? 0).toDouble();
        }
        final delta = recv < 0 ? 0 : recv - _sonRecvPaket;
        if (recv >= 0) _sonRecvPaket = recv;
        final enerjiDelta = energy - _sonEnergy;
        _sonEnergy = energy;

        int sent = -1;
        double mikEnerji = 0;
        final lt = _room?.localParticipant?.audioTrackPublications.firstOrNull?.track;
        if (lt is LocalAudioTrack) {
          final ss = await lt.getSenderStats();
          sent = (ss?.packetsSent ?? -1).toInt();
          mikEnerji = (ss?.audioSourceStats?.totalAudioEnergy ?? 0).toDouble();
        }
        final sentDelta = sent < 0 ? 0 : sent - _sonSentPaket;
        if (sent >= 0) _sonSentPaket = sent;
        final mikDelta = mikEnerji - _sonMikEnerji;
        _sonMikEnerji = mikEnerji;

        // OTOMATIK SES KURTARMA: mic ACIK + paket AKIYOR + capture 3 olcumdur SIFIR
        if (_micOn && sentDelta > 60 && mikDelta <= 0.0000001) {
          _oluMikSayaci++;
          if (_oluMikSayaci >= 3 && !_sesKurtarmaDenendi) {
            _sesKurtarmaDenendi = true;
            _sesLog('OLU MIKROFON tespit (sent akiyor, capture=0) -> ses birimi yeniden kuruluyor');
            try {
              await _sesiAc(false);
              await _room?.localParticipant?.setMicrophoneEnabled(false);
              await _room?.localParticipant?.setMicrophoneEnabled(true);
              await _sesiAc(true);
              _sesLog('ses birimi yeniden kuruldu (kurtarma)');
            } catch (e) {
              _sesLog('ses kurtarma HATA: $e');
            }
          }
        } else {
          _oluMikSayaci = 0;
        }

        final ios = await _sesDurumOku();
        _svc.audioStat(b.callId, {
          'recv': recv,
          'delta': delta,
          'enerji': (enerjiDelta * 1000).toStringAsFixed(1),
          'sent': sent,
          'sdelta': sentDelta,
          'mik': (mikDelta * 1000).toStringAsFixed(1),
          'mic': _micOn,
          'outgoing': b.outgoing,
          'video': b.video,
          'speaker': _speakerOn,
          'peer': _peerJoined,
          if (ios != null) 'ios': ios,
        });
      } catch (_) {}
    });
  }

  /// SURE SENKRONU referansi: bir kez kilitlenir (1:1); grupta/null/negatifte yok sayilir.
  void _sureReferansiAl(int? elapsedMs) {
    if (_isGroup || _sureReferansVar) return;
    if (elapsedMs == null || elapsedMs < 0) return;
    _sureReferansVar = true;
    _sureBaz = Duration(milliseconds: elapsedMs);
    _sureSayaci
      ..reset()
      ..start();
    if (_mediaBasladi) {
      _duration = _sureBaz + _sureSayaci.elapsed;
      notifyListeners();
    }
  }

  void _startTimer() {
    if (!_sureSayaci.isRunning) _sureSayaci.start();
    _durationTimer?.cancel();
    _tick();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (arama == null) return;
    _duration = _sureBaz + _sureSayaci.elapsed;
    notifyListeners(); // banner da ayni tik ile tazelenir
  }

  void _mediaBaslat() {
    if (_mediaBasladi || _ayrildi) return;
    _mediaBasladi = true;
    _mediaYedek?.cancel();
    _ringTimeout?.cancel();
    _peerJoined = true;
    notifyListeners();
    _startTimer();
  }

  void _mediaGuvenlikAgi() {
    if (_mediaBasladi) return;
    _mediaYedek?.cancel();
    _mediaYedek = Timer(const Duration(seconds: 8), () {
      // Peer HALA odadaysa basla (F5: hayalet sayac onlemi)
      if (arama != null && !_mediaBasladi && (_room?.remoteParticipants.isNotEmpty ?? false)) {
        _mediaBaslat();
      }
    });
  }

  bool _remoteAudioHazir() {
    for (final p in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      for (final pub in p.audioTrackPublications) {
        if (pub.subscribed && pub.track != null) return true;
      }
    }
    return false;
  }

  static const _audioCh = MethodChannel('gebzem/audio');

  Future<Map<String, dynamic>?> _sesDurumOku() async {
    if (!Platform.isIOS) return null;
    try {
      final r = await _audioCh.invokeMethod('getAudioState');
      return (r as Map?)?.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }

  /// Kullanici "ses gelmiyor" isaretledi — o anki tum durumu sunucuya yaz.
  Future<void> sorunBildir() async {
    final b = arama;
    if (b == null) return;
    final ios = await _sesDurumOku();
    _svc.audioStat(b.callId, {
      'sorun': true,
      'sure': _duration.inSeconds,
      'recv': _sonRecvPaket,
      'outgoing': b.outgoing,
      'video': b.video,
      'speaker': _speakerOn,
      'peer': _peerJoined,
      if (ios != null) 'ios': ios,
    });
  }

  // Ses birimi NESIL JETONU: en son "true" ile sahiplenen disinda kimse kapatamaz
  // (sirali-gecis tuzagi). Teardown closure'i nesli enqueue ANINDA yakalar.
  static int _sesNesilSayaci = 0;
  int _benimSesNeslim = 0;
  Future<void> _sesiAc(bool ac) async {
    if (!Platform.isIOS) return;
    if (ac) {
      _benimSesNeslim = ++_sesNesilSayaci;
    } else if (_benimSesNeslim != _sesNesilSayaci) {
      _sesLog('_sesiAc(false) ATLANDI — ses birimi daha yeni aramaya ait');
      return;
    }
    _sesLog('_sesiAc($ac)');
    try {
      await _audioCh.invokeMethod('setAudioEnabled', ac);
    } catch (e) {
      _sesLog('_sesiAc HATA: $e');
    }
  }

  void _sesLog(String m) {
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(category: 'call.audio', message: m, level: SentryLevel.info),
      );
    } catch (_) {}
  }

  /// TEARDOWN — KARAR 4 "enqueue aninda yakala": kuyruga koyarken room/listener/nesil
  /// SENKRON yakalanir; alanlar hemen null'lanir. Bekleyen closure YENI aramanin
  /// Room'una dokunamaz. Sira semantigi eski _leave enqueue'suyla birebir.
  void _kapatOdayiKuyrugaKoy() {
    if (_kapandi) return;
    _kapandi = true;
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    _statusPoll?.cancel();
    _statsTimer?.cancel();
    _mediaYedek?.cancel();
    final room = _room;
    final listener = _listener;
    final nesil = _benimSesNeslim;
    _room = null;
    _listener = null;
    unawaited(CallRoomLock.calistir(() => _odaTemizle(room, listener, nesil)));
  }

  static Future<void> _odaTemizle(
      Room? room, EventsListener<RoomEvent>? listener, int nesil) async {
    // iOS ses birimi: yalniz hala sahibiysek kapat (nesil jetonu — yeni aramanin sesini kesme)
    if (Platform.isIOS && nesil == _sesNesilSayaci) {
      try {
        await _audioCh.invokeMethod('setAudioEnabled', false);
      } catch (_) {}
    }
    if (room == null && listener == null) return;
    // timeout SART: hang ederse CallRoomLock zinciri kilitlenir (art arda arama bug'i)
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

  void _iptalAbonelikler() {
    _endedSub?.cancel();
    _answeredSub?.cancel();
    _partSub?.cancel();
    _endedSub = null;
    _answeredSub = null;
    _partSub = null;
  }

  /// ARAMADAN CIK — TEK KAPI. Ekran dispose'u aramayi BITIRMEZ; yalniz bu metot bitirir.
  /// Sira: kilit -> CallKit bitir -> teardown enqueue (ANINDA yakala) -> sesler ->
  /// muhafizlari birak -> arama=null (ekran listener'i pop'unu yapar) -> end REST.
  Future<void> leave({required bool notifyServer}) async {
    if (_ayrildi || arama == null) return;
    _ayrildi = true;
    final id = arama!.callId;

    // CallKit KAPAT (kilit ekrani kabulunde aktif sistem aramasi vardir; idempotent)
    unawaited(CallKitService.bitir(id));
    // SERI ARAMA YARISI: teardown'i AYRILMA ANINDA kilit sirasina koy
    _kapatOdayiKuyrugaKoy();
    await CallSounds.durdur(_sesNesli);
    _iptalAbonelikler();

    // Muhafizlari birak (eski dispose'un iki birakmasi TEK KAPIDA)
    _svc.aktifKonusmaBitti(id);
    _svc.ekranKapandi(id);

    // Ekrana "bitti" bildir: arama=null -> CallScreen listener'i (sheet-pop -> ekran-pop; K7)
    arama = null;
    minimized = false;
    notifyListeners();

    try {
      if (notifyServer) await _svc.end(id);
    } catch (_) {
      // arama zaten bitmis olabilir
    }
    _svc.gecmisiYenile();
  }

  // ---- KONTROLLER (saf gorunumden cagrilir) ----

  Future<void> toggleMic() async {
    final on = !_micOn;
    await _room?.localParticipant?.setMicrophoneEnabled(on);
    _micOn = on;
    notifyListeners();
  }

  /// Kamera ac/kapat. Donus: acildiktan sonra gorunum swap'i sifirlanmali mi (ekran karar verir).
  Future<void> toggleCam() async {
    final on = !_camOn;
    // KAPASITE — WhatsApp standardi: grup 32 kisi
    if (on && _isGroup) {
      final katilimci = 1 + (_room?.remoteParticipants.length ?? 0);
      if (katilimci > 32) {
        rootMessengerKey.currentState?.showSnackBar(const SnackBar(
            content: Text('Grup araması en fazla 32 kişi — kamera açılamıyor')));
        return;
      }
    }
    if (on) {
      // Sesli aramada kamera izni ISTENMEDI -> mid-call acarken iste
      final st = await Permission.camera.request();
      if (st != PermissionStatus.granted) {
        rootMessengerKey.currentState
            ?.showSnackBar(const SnackBar(content: Text('Kamera izni gerekli')));
        return;
      }
    }
    await _room?.localParticipant?.setCameraEnabled(on);
    _camOn = on;
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    final on = !_speakerOn;
    await _room?.setSpeakerOn(on);
    _speakerOn = on;
    notifyListeners();
  }

  Future<void> flipCamera() async {
    final track = _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
    if (track == null) return;
    try {
      // switchCamera GERCEK yonu doner (true=on) — ayna moduna islenir
      final onMu = await rtc.Helper.switchCamera(track.mediaStreamTrack);
      _frontCamera = onMu;
      notifyListeners();
    } catch (e) {
      await Sentry.captureException(e, stackTrace: StackTrace.current);
    }
  }

  /// Kisi ekleme (Faz-B): REST + iyimser grup moduna gecis.
  Future<void> kisiEkle(String userId) async {
    final id = arama?.callId;
    if (id == null) return;
    await _svc.addToCall(id, userId);
    if (!_isGroup) {
      _isGroup = true;
      notifyListeners();
    }
  }

  // ---- MINIMIZE / RESTORE (C4) ----

  void minimize() {
    if (!minimizeEdilebilir) return;
    minimized = true;
    notifyListeners();
  }

  void restore() {
    if (arama == null) return;
    minimized = false;
    notifyListeners();
    ekraniAc();
  }

  /// Arama ekranini ac (tek kapi). Zaten gorunurse no-op (cift-push korumasi).
  void ekraniAc() {
    if (ekranGorunur) return;
    final b = arama;
    if (b == null) return;
    rootNavigatorKey.currentState?.push(MaterialPageRoute(
      settings: const RouteSettings(name: 'arama'),
      builder: (_) => CallScreen(bilgi: b),
    ));
  }

  /// Ekran beklenmedik sekilde pop oldu (dispose) — arama suruyor: guvenli minimize.
  /// notifyListeners POST-FRAME: dispose sirasinda senkron notify agac kilitlenmesin.
  void ekranBeklenmedikKapandi() {
    ekranGorunur = false;
    if (arama != null && !minimized) {
      minimized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }
}

final activeCallProvider = ChangeNotifierProvider<ActiveCallController>(
    (ref) => ActiveCallController(ref));

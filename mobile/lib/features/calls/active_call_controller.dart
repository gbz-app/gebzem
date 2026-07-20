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
import 'pip_service.dart';

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
    // FAZ-6: Android sistem PiP durum dinleyicisi (PiP'e girince ekran sade gorunum cizer)
    PipService.dinle((v) {
      pipModunda = v;
      notifyListeners();
    });
    // iOS SISTEM PiP (test turu 7): cihaz destegini bir kez sor (iOS<15/desteksiz -> false ->
    // hicbir sey yapilmaz, kamera-mute avatar yedegi kalir).
    PipService.iosPipHazirMi().then((v) => _iosPipHazir = v);
  }

  final Ref _ref;
  CallService get _svc => _ref.read(callServiceProvider.notifier);

  // ---- ARAMA DURUMU (null = arama yok) ----
  AramaBilgisi? arama;
  bool minimized = false;
  bool ekranGorunur = false; // CallScreen kendini kaydeder (cift-push korumasi)

  // FAZ-6 ANDROID PiP: sistem yuzen penceresi (uygulama-DISI kuculme; WhatsApp paritesi).
  // PiP MINIMIZE DEGILDIR — CallScreen route'ta kalir, leave tek-kapi bozulmaz.
  bool pipModunda = false;
  bool _pipIzinliSon = false;
  bool _kameraOtoKapandi = false; // arka planda kamerayi BIZ kapattik (donus'te geri ac)
  // iOS SISTEM PiP (test turu 7): native AVPictureInPicture. Android'den FARKLI — Flutter
  // ekrani PiP icerigi DEGIL; uzak video native AVSampleBufferDisplayLayer'da. Sadece kurulum/
  // birakma yonetilir; auto-enter iOS'ta OS tarafinda. Kamera-mute yedegi iOS'ta da KALIR
  // (kendi giden kameramizi bg'de kapatir — PiP bize UZAK videoyu gosterir, ikisi bagimsiz).
  bool _iosPipHazir = false;
  String _iosPipKurulanId = ''; // native'e kurulan uzak track id (degisince yeniden kur)

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
  // FAZ-7 guvenlik agi 2: paket AKIYOR ama decode enerjisi hep 0 = OLU PLAYOUT adayi (iOS)
  int _oluCikisSayaci = 0;
  String? _sonKurtarma; // tetiklenen kurtarma imzasi — bir sonraki audioStat'a eklenir
  // SORUN-6 SES KANIT BEKCISI: sayac yalniz GERCEK paket akisi kanitiyla baslar
  // (TrackSubscribed sinyal-duzeyi olay — olu birimde paket olmadan da tetikleniyordu)
  Timer? _kanitTimer;
  int _kanitRecvToplam = -1;
  bool _kanitOkunabildi = false; // getReceiverStats en az bir kez basarili okundu mu
  // FAZ-1A HIZ: taze aramada Room sifirdan kurulur -> packetsReceived kumulatifi 0'dan
  // baslar; ILK okumada >0 = paketler BU baglantida gercekten akti (delta beklemek bilgi
  // eklemez, ~1-2sn kaybettirir). Bayrak YALNIZ baslat()'ta true olur — re-arm/resume
  // yollari eski delta-sartli davranista kalir (SORUN-6 korunur).
  bool _kanitIlkDeneme = false;
  // TEST TURU 4: iOS'ta packetsReceived (RTP jitter buffer'a VARIS) sayaci ACAR ama
  // AVAudioSession PLAYOUT henuz baslamamis olabilir -> "sayiyor ama ses yok". iOS'ta
  // fast-path totalAudioEnergy (decode/playout kaniti) delta'sina baglanir; Android'de
  // paket-varisi yeterli (mevcut hizli davranis). Bu alanlar iOS enerji-kapisinin state'i.
  double _kanitEnerjiBaz = -1;
  int _kanitSessizTick = 0; // paket akiyor ama enerji 0 (sessiz) — 4 tick sonra dururst fallback
  // FAZ-0 GECICI OLCUM (uretim oncesi ses-teshisle birlikte kaldirilacak): kabul aninden
  // sese kadar asama sureleri (ms) — fix oncesi/sonrasi karsilastirma icin sunucuya raporlanir.
  Stopwatch? _kurulumSaat;
  Map<String, int>? _kurulumAsama;

  bool _isGroup = false; // canli deger (call.upgraded / Status is_group ile guncellenir)
  int? _sesNesli; // CallSounds nesli
  bool _connecting = true;
  bool _kapandi = false;
  bool _baglandi = false;
  bool _ayrildi = false;
  bool _peerJoined = false;
  bool _mediaBasladi = false;
  // SENKRON SAYAC (test turu 6): room.connect TAMAMLANDI mi. 1:1 sayaci YEREL SES yerine
  // "baglanti kuruldu + peer odada + sunucu-aktif" anina baglanir (WhatsApp modeli) -> iki
  // taraf ayni elapsed_ms referansindan SENKRON sayar. Grup HARIC (referanssiz -> eski yol).
  bool _odaBagli = false;
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

  // ---- FAZ-6 PiP yardimcilari ----

  bool _uzakVideoVar() {
    for (final p in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      for (final pub in p.videoTrackPublications) {
        if (pub.subscribed && !pub.muted && pub.track != null) return true;
      }
    }
    return false;
  }

  /// PiP'e girilmesi istenen durum: Android + bagli/saglikli arama + EKRAN ACIK
  /// (minimize'da bant var, PiP ana sayfayi minik gosterirdi) + gorunecek video var.
  bool get _pipIstenir =>
      Platform.isAndroid &&
      minimizeEdilebilir &&
      ekranGorunur &&
      !minimized &&
      (_camOn || _uzakVideoVar());

  void _pipGuncelle() {
    final istenen = _pipIstenir;
    if (istenen == _pipIzinliSon) return; // kanala yalniz DEGISIMDE git
    _pipIzinliSon = istenen;
    PipService.pipIzinli(istenen);
  }

  /// iOS PiP: uzak video track'inin webrtc id'si (1:1 — ilk uygun uzak video).
  String? _uzakVideoTrackId() {
    for (final p in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      for (final pub in p.videoTrackPublications) {
        if (pub.subscribed && !pub.muted && pub.track != null) {
          return (pub.track as VideoTrack).mediaStreamTrack.id;
        }
      }
    }
    return null;
  }

  /// iOS SISTEM PiP guncelle (test turu 7): 1:1 GORUNTULU + bagli + ekran acik + uzak video
  /// varsa native PiP controller'i kur (auto-enter); degilse birak. Track degisince yeniden kur.
  /// Fire-and-forget; guard sayesinde cogu cagri no-op (yalniz trackId degisiminde native).
  Future<void> _iosPipGuncelle() async {
    if (!Platform.isIOS || !_iosPipHazir) return;
    final b = arama;
    final uygun = b != null &&
        b.video &&
        !_isGroup &&
        _baglandi &&
        !_cevapsiz &&
        _error == null &&
        ekranGorunur;
    final trackId = uygun ? _uzakVideoTrackId() : null;
    if (trackId != null) {
      if (trackId != _iosPipKurulanId) {
        final ok = await PipService.iosPipKur(trackId);
        _iosPipKurulanId = ok ? trackId : '';
      }
    } else if (_iosPipKurulanId.isNotEmpty) {
      _iosPipKurulanId = '';
      await PipService.iosPipBirak();
    }
  }

  /// Ekran acilis/kapanisinda PiP iznini tazele (CallScreen initState cagirir).
  void pipDurumTazele() {
    _pipGuncelle();
    unawaited(_iosPipGuncelle());
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _pipGuncelle(); // her durum degisiminde PiP izni senkron kalir (yalniz delta'da kanal)
    unawaited(_iosPipGuncelle()); // iOS PiP kurulum/birakma (yalniz trackId delta'sinda native)
  }

  String get durumMetni {
    // KAPI SIRASI AYNEN (_statusText — yargic YAPMA listesi: degistirme)
    if (_cevapsiz) return _cevapsizNeden;
    if (_error != null) return _error!;
    if (_connecting) return 'Baglaniliyor...';
    if (!_peerJoined) {
      // SORUN-6 adim 4: grupta 'Caliyor' yaniltici (kimse aranmiyor, katilim bekleniyor)
      if (_isGroup) return 'Katılım bekleniyor...';
      return (arama?.outgoing ?? true) ? 'Caliyor...' : 'Bekleniyor...';
    }
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
    pipModunda = false; // FAZ-6 (yargic): eski aramadan bayrak sarkmasin
    _kameraOtoKapandi = false;
    _iosPipKurulanId = ''; // iOS PiP (test turu 7): eski aramadan kurulum sarkmasin
    _isGroup = b.isGroup;
    _connecting = true;
    _kapandi = false;
    _baglandi = false;
    _ayrildi = false;
    _peerJoined = false;
    _mediaBasladi = false;
    _odaBagli = false; // senkron sayac (test turu 6)
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
    _oluCikisSayaci = 0;
    _sonKurtarma = null;
    _kanitTimer?.cancel();
    _kanitRecvToplam = -1;
    _kanitOkunabildi = false;
    _kanitIlkDeneme = true; // FAZ-1A: fast-path yalniz taze aramanin ilk bekcisinde
    _kanitEnerjiBaz = -1;
    _kanitSessizTick = 0;
    _kurulumSaat = Stopwatch()..start(); // FAZ-0 GECICI olcum
    _kurulumAsama = {};
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
    // FAZ-6 KAMERA-MUTE YEDEGI (PiP'siz/PiP reddeden cihazlar): GERCEK arka plana
    // inince (PiP'te DEGILKEN) kamerayi biz kapatiriz -> karsi taraf DONUK KARE degil
    // "kamera kapali" avatar gorur. Android arka planda kamerayi zaten fiziksel keser;
    // mute sinyali karsi tarafa durumu DURUSTCE anlatir. Donuste geri acilir.
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.hidden) &&
        arama != null && _baglandi && !_ayrildi && !pipModunda && _camOn) {
      _kameraOtoKapandi = true;
      _camOn = false;
      _room?.localParticipant?.setCameraEnabled(false);
      notifyListeners();
      return;
    }
    if (state == AppLifecycleState.resumed && arama != null && !_ayrildi && !_cevapsiz) {
      // Kamera restore _kesintidenTopla'dan ONCE (iOS ses sirasi: _sesiAc EN SON kalmali)
      if (_kameraOtoKapandi && _baglandi) {
        _kameraOtoKapandi = false;
        _camOn = true;
        _room?.localParticipant?.setCameraEnabled(true);
        notifyListeners();
      }
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

      _kurulumAsama?['izin'] = _kurulumSaat?.elapsedMilliseconds ?? 0; // FAZ-0
      await CallRoomLock.calistir(_odayaBaglan);
      _kurulumAsama?['oda'] = _kurulumSaat?.elapsedMilliseconds ?? 0; // FAZ-0
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
          // SENKRON SAYAC (test turu 6): peer connect-SONRASI katildi + baglanti kuruldu +
          // sunucu-aktif -> sayaci senkron ac (WhatsApp modeli). Referans yoksa/grupsa 8sn yedek.
          if (!_isGroup && _sureReferansVar && _odaBagli) {
            _mediaBaslat();
          } else {
            _mediaGuvenlikAgi(); // sure GERCEK ses gelince baslar; 8sn yedek
          }
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
            // SORUN-6: subscribe SINYAL-duzeyi olay — olu birimde paket olmadan da gelir.
            // Sayaci dogrudan baslatma; PAKET KANITI bekle (00:00 sayip ses yok bulgusu).
            _sesLog('remote AUDIO track subscribe oldu — paket kaniti bekleniyor');
            _sesKanitBekle();
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

      const secenekler = ConnectOptions(
        autoSubscribe: true,
        // MEDYA HER ZAMAN TURN RELAY (TR operator CGNAT karari — degistirme)
        rtcConfiguration: RTCConfiguration(
          iceTransportPolicy: RTCIceTransportPolicy.relay,
        ),
      );
      try {
        await room.connect(b.url, b.token, connectOptions: secenekler);
      } catch (e) {
        // FAZ-3A SINYAL FALLBACK: dogrudan adres (rtcd.*:7443) kisitli aglarda (otel/
        // kurumsal) bloklanabilir -> CF'li eski adrese TEK retry. url rtcd degilse
        // kod PASIF (rethrow). Sunucu LIVEKIT_URL flip'i ancak bu build sahadayken yapilir.
        if (b.url.contains('rtcd.')) {
          _sesLog('sinyal fallback: dogrudan adres basarisiz, rtc deneniyor ($e)');
          await room.connect('wss://rtc.gebzem.app', b.token,
              connectOptions: secenekler);
        } else {
          rethrow;
        }
      }
      _kurulumAsama?['connect'] = _kurulumSaat?.elapsedMilliseconds ?? 0; // FAZ-0
      // iOS SES SIRASI (KRITIK v7/v8 — AYNEN): mic -> kamera -> speaker(false) -> _sesiAc EN SON
      await room.localParticipant?.setMicrophoneEnabled(true);
      _kurulumAsama?['mic'] = _kurulumSaat?.elapsedMilliseconds ?? 0; // FAZ-0
      if (b.video) {
        await room.localParticipant?.setCameraEnabled(true);
        _kurulumAsama?['cam'] = _kurulumSaat?.elapsedMilliseconds ?? 0; // FAZ-0
      }
      await room.setSpeakerOn(false); // varsayilan kulaklik (earpiece)
      await _sesiAc(true); // SES BIRIMI EN SON
      _kurulumAsama?['sesiAc'] = _kurulumSaat?.elapsedMilliseconds ?? 0; // FAZ-0
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
      _odaBagli = true; // room.connect TAMAMLANDI
      notifyListeners();
      // SENKRON SAYAC (test turu 6): 1:1'de baglanti kuruldu + PEER ODADA + sunucu-aktif
      // (elapsed_ms referansi) -> sayaci HEMEN ac (YEREL ses playout'unu BEKLEME). Iki taraf
      // ayni referanstan sayar -> asimetri WS gecikmesi kadar (<0.5sn). Peer henuz odada
      // degilse ParticipantConnected tetikler; referans yoksa/grupsa eski enerji/8sn yolu.
      if (!_isGroup && _sureReferansVar && _peerJoined) {
        _mediaBaslat();
      } else if (_remoteAudioHazir()) {
        _sesKanitBekle(); // SORUN-6: resume/reconnect'te de kanitla basla
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
        // FAZ-7: recv/enerji TUM remote audio track'lerden TOPLANIR (grup uyumu —
        // firstOrNull yalniz ilk katilimciyi olcuyordu). Hic track yoksa recv=-1 kalir.
        int recv = -1;
        double energy = 0;
        for (final rp in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
          for (final pub in rp.audioTrackPublications) {
            final track = pub.track;
            if (track is RemoteAudioTrack) {
              try {
                final s = await track.getReceiverStats();
                if (s != null) {
                  if (recv < 0) recv = 0;
                  recv += (s.packetsReceived ?? 0).toInt();
                  energy += (s.totalAudioEnergy ?? 0).toDouble();
                }
              } catch (_) {}
            }
          }
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

        // OTOMATIK SES KURTARMA (FAZ-7 genisletildi — 19 Tem kaniti eski imzayi kacirdi):
        // Imza A 'sentAkiyor': paket AKIYOR + capture 0 (eski imza).
        // Imza B 'sent0': track VAR ama HIC paket cikmiyor + karsi yon AKIYOR = birim
        // tamamen olu (sent=0 modu — mevcut kurtarma bunu KACIRIYORDU). Paylasimli
        // 3-tick esigi ilk saniyelerin mesru 0'ini eler; kurtarma arama basina TEK sefer.
        final sentAkiyorImza = sentDelta > 60 && mikDelta <= 0.0000001;
        final sent0Imza =
            sent >= 0 && sentDelta <= 0 && mikDelta <= 0.0000001 && delta > 60;
        if (_micOn && _peerJoined && (sentAkiyorImza || sent0Imza)) {
          _oluMikSayaci++;
          if (_oluMikSayaci >= 3 && !_sesKurtarmaDenendi) {
            await _birimYenidenKur(sentAkiyorImza ? 'sentAkiyor' : 'sent0');
          }
        } else {
          _oluMikSayaci = 0;
        }
        // FAZ-7 guvenlik agi 2 (OLU PLAYOUT — iOS): paket AKIYOR ama decode enerjisi
        // 5 olcumdur (10sn) tam 0 = birim ses CALMIYOR (19 Tem: recv akti, enerji 0.0).
        // Donanim-mute kulaklik yanlis-pozitifi: 10sn + tek-seferlik = kabul edilebilir.
        if (Platform.isIOS && delta > 60 && enerjiDelta <= 0.0000001) {
          _oluCikisSayaci++;
          if (_oluCikisSayaci >= 5 && !_sesKurtarmaDenendi) {
            await _birimYenidenKur('cikisOlu');
          }
        } else {
          _oluCikisSayaci = 0;
        }

        final ios = await _sesDurumOku();
        final kurtarma = _sonKurtarma;
        _sonKurtarma = null; // tek satirda raporla
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
          if (kurtarma != null) 'kurtarma': kurtarma,
          if (ios != null) 'ios': ios,
        });
      } catch (_) {}
    });
  }

  /// FAZ-7 ortak kurtarma govdesi: ses birimini v7 sirasi korunarak BIR KEZ yeniden kur
  /// (_sesiAc(false) -> mic off -> mic on -> _sesiAc(true) EN SON). Imza adi sunucuya
  /// 'kurtarma' alaniyla raporlanir (admin panelde turuncu KURTARMA satiri).
  Future<void> _birimYenidenKur(String imza) async {
    if (_sesKurtarmaDenendi) return;
    _sesKurtarmaDenendi = true;
    _sonKurtarma = imza;
    _sesLog('OLU BIRIM tespit ($imza) -> ses birimi yeniden kuruluyor');
    try {
      await _sesiAc(false);
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      await _room?.localParticipant?.setMicrophoneEnabled(true);
      await _sesiAc(true);
      _sesLog('ses birimi yeniden kuruldu ($imza)');
    } catch (e) {
      _sesLog('ses kurtarma HATA: $e');
    }
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
    } else if (_odaBagli && _peerJoined) {
      // SENKRON SAYAC (test turu 6): referans BAGLANTI + PEER'den SONRA geldi (WS gecikmesi)
      // -> sayaci simdi senkron ac. (Grupta bu metot zaten erken-return ile buraya gelmez.)
      _mediaBaslat();
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
    // FAZ-0 GECICI: kabul->ses asama raporu (tek seferlik; admin log: KURULUM-MS)
    final asamalar = _kurulumAsama;
    final id = arama?.callId;
    if (asamalar != null && id != null) {
      asamalar['ses'] = _kurulumSaat?.elapsedMilliseconds ?? 0;
      _sesLog('kurulum_ms: $asamalar');
      _svc.audioStat(id, {'kurulum_ms': asamalar});
      _kurulumAsama = null;
    }
  }

  void _mediaGuvenlikAgi() {
    if (_mediaBasladi) return;
    _mediaYedek?.cancel();
    _mediaYedek = Timer(const Duration(seconds: 8), () {
      // Peer HALA odadaysa (F5: hayalet sayac onlemi):
      // SORUN-6 yeni anlam — stats OKUNAMIYORSA (bozuk/eski cihaz) eski davranis: sayaci
      // ac. Stats OKUNUYOR ama paket 0 ise sayac ACILMAZ ('Baglaniyor' kalir — durust);
      // kurtarma aglari birimi 6-10sn'de kurar, ses gelince kanit bekcisi acar.
      if (arama == null || _mediaBasladi) return;
      if (_room?.remoteParticipants.isNotEmpty ?? false) {
        if (!_kanitOkunabildi) {
          _mediaBaslat();
        } else {
          _sesKanitBekle(); // bekci suruyor; yedegi de yeniden kur
          _mediaGuvenlikAgi();
        }
      }
    });
  }

  /// SORUN-6 SES KANIT BEKCISI: 1sn'de bir TUM remote audio publication'larin
  /// packetsReceived TOPLAMINI okur; toplam ARTARSA (gercek ses akisi) veya publication
  /// MUTED ise (karsi taraf bilincli sessiz — 'Baglaniyor'da asili kalma olmasin)
  /// _mediaBaslat. Sinyal-duzeyi TrackSubscribed tek basina sayac ACAMAZ.
  void _sesKanitBekle() {
    if (_mediaBasladi) return;
    // FAZ-1A dedupe: ilk denemede TrackSubscribed + connect-sonrasi cifte cagri baseline'i
    // sifirlayip fast-path'i yakmasin (sonraki re-arm'lar eski resetleme davranisiyla).
    if (_kanitIlkDeneme && (_kanitTimer?.isActive ?? false)) return;
    _kanitTimer?.cancel();
    _kanitRecvToplam = -1;
    _kanitEnerjiBaz = -1;
    _kanitSessizTick = 0;
    final id = arama?.callId;
    _kanitTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      if (arama?.callId != id || _ayrildi || _mediaBasladi) {
        _kanitTimer?.cancel();
        return;
      }
      var muteVar = false;
      var toplam = 0;
      var enerjiToplam = 0.0;
      var trackVar = false;
      for (final p in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
        for (final pub in p.audioTrackPublications) {
          if (pub.muted) muteVar = true;
          final t = pub.track;
          if (t is RemoteAudioTrack) {
            trackVar = true;
            try {
              final s = await t.getReceiverStats();
              if (s != null) {
                _kanitOkunabildi = true;
                toplam += (s.packetsReceived ?? 0).toInt();
                // totalAudioEnergy = decode/playout yolu (RRT varisindan DAHA GUCLU kanit)
                enerjiToplam += (s.totalAudioEnergy ?? 0).toDouble();
              }
            } catch (_) {}
          }
        }
      }
      if (arama?.callId != id || _ayrildi || _mediaBasladi) return;
      if (muteVar) {
        _kanitTimer?.cancel();
        _sesLog('ses kaniti: karsi taraf muted — sayac aciliyor');
        _mediaBaslat();
        return;
      }
      if (!trackVar) return;

      // iOS: sayac GERCEK PLAYOUT ile acilir (packetsReceived degil totalAudioEnergy) —
      // "sayiyor ama ses yok" bulgusunun kok fix'i. Android: paket-varisi yeterli (hizli).
      if (Platform.isIOS) {
        // KILITLI SAYAC KOK FIX (test turu 5): "taze enerji>0 -> hemen" fast-path'i
        // KALDIRILDI. KANIT: CallKit didActivateAudioSession sesi ERKEN isitir ->
        // totalAudioEnergy (kumulatif) kapinin ILK 400ms tick'inden ONCE tirmanir ->
        // sayac gercek ISITILEBILIR playout'tan once 00:01 aciliyordu (yalniz KILITLI/CallKit
        // yolunda; uygulama-ici yolda _sesiAc EN SONDA -> ilk okuma enerji~0 -> zaten delta
        // bekliyordu). Artik TUM iOS yollarinda enerji-DELTA (canli artis) beklenir; baseline
        // her tick yazildigi icin delta 2. tick'te dogru olusur (+~400ms, kabul).
        final playoutBasladi = _kanitEnerjiBaz >= 0 && enerjiToplam > _kanitEnerjiBaz;
        if (playoutBasladi) {
          _kanitTimer?.cancel();
          _sesLog('ses kaniti (iOS): playout enerjisi dogrulandi — sayac aciliyor');
          _mediaBaslat();
          return;
        }
        // SESSIZ-AKIS DURUSTLUGU: paket akiyor ama enerji 0 (karsi taraf gercekten sessiz
        // ya da iOS unit gec) -> 4 tick (~1.6s) sonra 'Baglaniyor'da asili birakma, ac.
        if (toplam > (_kanitRecvToplam < 0 ? -1 : _kanitRecvToplam)) {
          _kanitSessizTick++;
          if (_kanitSessizTick >= 4) {
            _kanitTimer?.cancel();
            _sesLog('ses kaniti (iOS): sessiz-akis fallback (~1.6s) — sayac aciliyor');
            _mediaBaslat();
            return;
          }
        }
        _kanitRecvToplam = toplam;
        _kanitEnerjiBaz = enerjiToplam;
        _kanitIlkDeneme = false;
        return;
      }

      // ANDROID (mevcut hizli davranis AYNEN): paket-varisi = kanit
      if (_kanitIlkDeneme && _kanitRecvToplam < 0 && toplam > 0) {
        _kanitIlkDeneme = false;
        _kanitTimer?.cancel();
        _sesLog('ses kaniti: kumulatif>0 (ilk deneme) — hemen baslatiliyor');
        _mediaBaslat();
        return;
      }
      if (_kanitRecvToplam >= 0 && toplam > _kanitRecvToplam) {
        _kanitTimer?.cancel();
        _sesLog('ses kaniti: paket akisi dogrulandi (+${toplam - _kanitRecvToplam})');
        _mediaBaslat();
        return;
      }
      _kanitRecvToplam = toplam;
      _kanitIlkDeneme = false; // baseline yazildi — bundan sonra yalniz delta kaniti
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
    _kanitTimer?.cancel(); // SORUN-6 bekcisi de dursun
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

    // iOS PiP (test turu 7): arama bitti -> native controller'i birak (kaynak sizmasin)
    if (_iosPipKurulanId.isNotEmpty) {
      _iosPipKurulanId = '';
      unawaited(PipService.iosPipBirak());
    }
    // Ekrana "bitti" bildir: arama=null -> CallScreen listener'i (sheet-pop -> ekran-pop; K7)
    arama = null;
    minimized = false;
    pipModunda = false; // FAZ-6: arama bitti — PiP izni notifyListeners'la geri cekilir
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
    _kameraOtoKapandi = false; // FAZ-6: kullanici elle dokundu — oto-restore devre disi
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

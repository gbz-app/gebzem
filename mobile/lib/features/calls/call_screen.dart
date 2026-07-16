import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/api.dart';
import 'call_media_options.dart';
import 'call_provider.dart';
import 'call_room_lock.dart';
import 'call_sounds.dart';
import 'callkit_service.dart';

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
    this.peerId,
    this.outgoing = true,
  });

  final String callId;
  final String url;
  final String token;
  final bool video;
  final String peerName;
  final String? peerId; // "Geri Ara" icin (giden aramada dolu; gelen aramada gereksiz)
  final bool outgoing; // giden arama mi (karsi taraf henuz kabul etmedi)

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> with WidgetsBindingObserver {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  StreamSubscription? _endedSub;
  StreamSubscription? _answeredSub;
  Timer? _durationTimer;
  Timer? _ringTimeout;
  Timer? _statusPoll; // arayan: WS kaybolursa durum kurtarma pollu
  Timer? _statsTimer; // ses NOKTA-ATISI olcumu (getStats -> Sentry)
  int _sonRecvPaket = 0;

  /// Arama servisi initState'te yakalanir. `ref`, widget yok edildikten sonra
  /// KULLANILAMAZ (StateError firlatir) — servis ise uygulama boyunca yasar.
  late final CallService _svc;

  int? _sesNesli; // CallSounds nesli — durdururken verilir ki art arda aramada ESKI ekranin
  // gec dispose durdur'u YENI aramanin sesini (dit/zil) kesmesin.
  bool _connecting = true;
  bool _kapandi = false; // oda bir kez kapatildi mi (cift kapatmayi onler)
  bool _baglandi = false; // odaya baglanma baslatildi mi (cift baglanmayi onler)
  bool _ayrildi = false; // _leave bir kez calisti mi (cift pop = siyah ekran)
  bool _peerJoined = false;
  bool _micOn = true;
  bool _camOn = false;
  bool _speakerOn = true;
  bool _frontCamera = true;
  String? _error;
  Duration _duration = Duration.zero;
  ConnectionQuality _quality = ConnectionQuality.unknown;

  // Cevapsiz/reddedilen arama: arayan tarafta ekran otomatik kapanmaz, "Cevap yok" +
  // Geri Ara/Kapat gosterilir.
  bool _cevapsiz = false;
  String _cevapsizNeden = 'Cevap yok';

  // Suruklenebilir self-view (kendi kamera onizlemesi)
  Offset? _selfPos;
  static const double _selfW = 110, _selfH = 160, _selfMargin = 16;

  @override
  void initState() {
    super.initState();
    _camOn = widget.video;
    WidgetsBinding.instance.addObserver(this); // resume'da durum uzlastirma icin

    _svc = ref.read(callServiceProvider.notifier);
    final svc = _svc;

    // Karsi taraf kapatirsa / arama biterse: bagliysak dogrudan cik; ring fazindaysak
    // nedeni (red/mesgul/cevapsiz) sunucudan ogrenip cevapsiz UI goster (WS nedeni tasimaz).
    _endedSub = svc.onCallEnded.listen((id) async {
      if (id != widget.callId || !mounted || _ayrildi) return;
      if (_baglandi) {
        _leave(notifyServer: false);
        return;
      }
      String s = '';
      try {
        s = (await _svc.callStatus(id))['status'] as String? ?? '';
      } catch (_) {}
      if (!mounted || _ayrildi || _baglandi) return;
      if (s == 'ended') {
        _leave(notifyServer: false); // arayan baska cihazdan iptal etmis olabilir
      } else {
        _cevapsizGoster(s == 'rejected'
            ? 'Arama reddedildi'
            : s == 'busy'
                ? 'Mesgul'
                : 'Cevap yok');
      }
    });

    if (widget.outgoing) {
      // GIDEN ARAMA: karsi taraf ACANA KADAR LiveKit odasina BAGLANMA (iOS'ta mikrofon
      // acilinca LiveKit calma tonunu susturur). Cevaptan sonra odaya girilir.
      _answeredSub = svc.onCallAnswered.listen((id) {
        if (id == widget.callId && mounted && !_baglandi) {
          CallSounds.durdur(_sesNesli);
          _connect();
        }
      });
      // Cok hizli kabul edildiyse olay biz dinlemeye baslamadan gelmis olabilir
      if (svc.kabulEdilenler.contains(widget.callId)) {
        _connect();
        return;
      }
      CallSounds.calmaTonu().then((n) => _sesNesli = n); // nesli sakla (durdururken verilecek)
      // 45 sn cevap yoksa: ONCE sunucuyu sor. 'active' ise (arayan arka plandaydi, poll
      // ertelendi) BAGLAN — yoksa sunucuda CANLI olan aramayi End'e cekip karsi tarafin
      // aramasini dusururduk. Hala 'ringing' ise "Cevap yok" (ekrani KAPATMA).
      _ringTimeout = Timer(const Duration(seconds: 45), () async {
        if (!mounted || _baglandi || _ayrildi) return;
        String s = '';
        try {
          s = (await _svc.callStatus(widget.callId))['status'] as String? ?? '';
        } catch (_) {}
        if (!mounted || _baglandi || _ayrildi) return;
        if (s == 'active') {
          CallSounds.durdur(_sesNesli);
          _connect();
        } else {
          _cevapsizGoster('Cevap yok', sunucuyaBildir: true);
        }
      });
      // KURTARMA AGI: WS call.answered/ended kaybolabilir; 2sn'de bir sunucu durumunu sor.
      _statusPoll = Timer.periodic(const Duration(seconds: 2), (_) => _durumKontrol());
      setState(() => _connecting = false); // "Caliyor..." goster
    } else {
      // GELEN ARAMAYI KABUL ETTIK: hemen odaya gir
      _connect();
    }
  }

  /// Sunucudaki arama durumunu bir kez sorup uzlastir. Ring poll (2sn), aktif poll (3sn)
  /// ve on plana donuste (resume) cagrilir — Doze'da ertelenen timer'a bagimli kalmadan
  /// durumu hemen senkronlar (arayanin "Caliyor"da takili kalmasinin KOK cozumu).
  Future<void> _durumKontrol() async {
    if (!mounted || _ayrildi || _cevapsiz) return;
    String s;
    try {
      s = (await _svc.callStatus(widget.callId))['status'] as String? ?? '';
    } catch (_) {
      return;
    }
    if (!mounted || _ayrildi || _cevapsiz) return;
    if (s == 'active') {
      if (!_baglandi) {
        CallSounds.durdur(_sesNesli);
        _connect(); // ring fazi: karsi taraf kabul etti -> bagla
      }
      return;
    }
    if (s == 'ended') {
      _leave(notifyServer: false);
      return;
    }
    if (s == 'rejected' || s == 'missed' || s == 'busy') {
      if (_baglandi) {
        _leave(notifyServer: false);
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
    if (state == AppLifecycleState.resumed && mounted && !_ayrildi && !_cevapsiz) {
      // On plana donunce Doze'da ertelenen poll'u BEKLEME; durumu HEMEN uzlastir.
      _durumKontrol();
    }
  }

  /// Cevapsiz/reddedilen arama: ekrani KAPATMADAN "Cevap yok/reddedildi/mesgul" durumuna
  /// gec (Geri Ara / Kapat gosterilir). Otomatik pop YOK.
  Future<void> _cevapsizGoster(String neden, {bool sunucuyaBildir = false}) async {
    if (_baglandi || _ayrildi || _cevapsiz) return;
    await CallSounds.durdur(_sesNesli);
    _ringTimeout?.cancel();
    _statusPoll?.cancel();
    if (sunucuyaBildir) {
      try {
        await _svc.end(widget.callId);
      } catch (_) {}
    }
    _svc.gecmisiYenile();
    if (mounted) {
      setState(() {
        _cevapsiz = true;
        _cevapsizNeden = neden;
      });
    }
  }

  /// "Geri Ara" — cevapsiz ekrandan ayni kisiyi tekrar ara (peerId sart).
  Future<void> _geriAra() async {
    final pid = widget.peerId;
    if (pid == null) return;
    try {
      final info = await _svc.start(pid, video: widget.video);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: info['call_id'] as String,
          url: info['url'] as String,
          token: info['token'] as String,
          video: widget.video,
          peerName: widget.peerName,
          peerId: pid,
          outgoing: true,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _connect() async {
    if (_baglandi) return;
    _baglandi = true;
    _statusPoll?.cancel(); // baglaniyoruz, kurtarma pollu gereksiz
    try {
      // Izinler: mikrofon her zaman, kamera goruntulu aramada
      final perms = <Permission>[Permission.microphone];
      if (widget.video) perms.add(Permission.camera);
      final statuses = await perms.request();
      if (statuses[Permission.microphone] != PermissionStatus.granted) {
        if (!mounted) return;
        setState(() {
          _error = 'Arama icin mikrofon izni gerekli';
          _connecting = false;
        });
        return;
      }
      if (mounted) setState(() => _connecting = true);

      await CallRoomLock.calistir(() => _odayaBaglan());
      // TEK BITIR-KAPISI: canli konusma basladi. Artik CallKit'in yanlis zamanli
      // decline/ended/timeout olayi (ikinci UI yuzeyi / 45sn CallKit auto-expire) bu aramayi
      // OLDURMEMELI (main.dart onRed aktifKonusmalar'i kontrol eder). Gercek bitirme yalniz
      // kirmizi tus veya peer-hangup (RoomDisconnected/ParticipantDisconnected) ile olur.
      _svc.aktifKonusmaBasladi(widget.callId);
      // Baglandik: aktif aramada da durum yokla. Karsi taraf kapatinca "call.ended" WS
      // olayi (o taraf arka plandayken / yari-acik sokette) kaybolabilir; bu poll en fazla
      // 3sn'de ekrani kapatir -> "kapatinca karsi tarafta arama devam ediyor" bug'i biter.
      _aktifPollBaslat();
      _statsBaslat(); // ses nokta-atisi olcumu (Sentry)
    } catch (e) {
      // Hata Sentry'e duser; kullaniciya net mesaj gosterilir
      await CallSounds.durdur(_sesNesli);
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

  /// Odaya baglanma — CallRoomLock sirasinda calisir, yani onceki aramanin
  /// kapanisi BITMIS olur (ses oturumu yarisini onler).
  Future<void> _odayaBaglan() async {
    final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true, // zayif baglantida/kucuk pencerede kaliteyi otomatik dusur
          dynacast: true, // kullanilmayan ust katmanlari durdur (pil/veri/CPU tasarrufu)
          // UYARLANABILIR 1080p: ag iyiyse 1080p'ye kadar; kotulesince otomatik duser
          // (bkz. call_media_options.dart — degradationPreference: balanced)
          defaultCameraCaptureOptions: kCameraCaptureOptions,
          defaultVideoPublishOptions: kVideoPublishOptions,
          defaultAudioCaptureOptions: kAudioCaptureOptions,
          defaultAudioPublishOptions: kAudioPublishOptions,
        ),
      );
    // Odayi HEMEN alana ata: baglanma sirasinda ekran kapanirsa (erken cikis / hata)
    // _kapatOda() bu odayi bulup kapatabilsin. Yoksa oda sizar, mikrofon yayinda kalir
    // ve global ses sayaci takili kalir -> sonraki aramanin sesi olur.
    _room = room;

    try {
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
        ..on<TrackSubscribedEvent>((e) {
          if (mounted) setState(() {});
          // ILK-ARAMA SES DUZELTMESI (Apple forum 64544 + kanonik CallKit+WebRTC): iOS soguk
          // baslangicta ILK CallKit aramasinda didActivateAudioSession GELMEYIP _sesiAc erken/bos
          // oturuma kuruldugunda karsinin sesi (downlink) render EDILMIYORDU -> "ilk arama sessiz,
          // ikinci ses var". Cozum: remote AUDIO track SUBSCRIBE olunca (ses artik gercekten var)
          // iOS cikis ses birimini YENIDEN aktive et -> birim remote track ile dogru kurulur,
          // ilk aramada da ses gelir. useManualAudio'da bu, playout'u remote-track'e baglar.
          if (e.track is AudioTrack) {
            _sesLog('remote AUDIO subscribe -> _sesiAc(true) yeniden (ilk-arama ses fix)');
            _sesiAc(true);
          }
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
          // MEDYAYI HER ZAMAN TURN RELAY UZERINDEN gecir (iceTransportPolicy.relay).
          // NEDEN: mobil operator aglarinda (Turkiye CGNAT/simetrik NAT) dogrudan UDP
          // adaylari (srflx) bir an "basarili" gorunup sonra susuyor -> WebRTC relay'e
          // GEC dusuyor/hic dusmuyor -> "dtls timeout", ses gitmiyor / "Baglaniyor"da
          // takiliyor. .all modu bu tuzaga dusuyordu. TURN kendi sunucumuzda (turn.gebzem.app
          // TLS 443, LiveKit ile ayni makine) -> relay overhead'i minimal, WiFi'de de sorunsuz.
          // LiveKit zaten SFU (medya her durumda client<->server); relay yalniz ICE transport'unu
          // garantili yola (TLS 443) sabitler. Kisitli WiFi (otel/kurumsal) de bununla calisir.
          rtcConfiguration: RTCConfiguration(
            iceTransportPolicy: RTCIceTransportPolicy.relay,
          ),
        ),
      );
      // iOS SES SIRASI (KRITIK - v7 regresyon duzeltmesi): ses birimini (_sesiAc) EN SON ac.
      // useManualAudio=true'da isAudioEnabled=true, WebRTC ses birimini o ANKI AVAudioSession
      // kategorisi/rotasi/mic-track durumunu KILITLEYEREK baslatir. Once session playAndRecord'a
      // alinip mic track + rota HAZIR olmali, ses birimi EN SON acilmali (kanonik CallKit+WebRTC
      // deseni; flutter-webrtc #1996/#1691). v7'de _sesiAc ILK cagrilinca SESLI aramada capture
      // BOS kalip mic SESSIZ gidiyordu (goruntuluyu setSpeakerOn(true) hoparlor restart'i
      // kurtariyordu, sesli earpiece restart vermedigi icin bozuk kaliyordu). Android'de no-op.
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (widget.video) {
        await room.localParticipant?.setCameraEnabled(true);
      }
      await room.setSpeakerOn(widget.video); // rota (goruntuluda hoparlor, seslide kulaklik)
      await _sesiAc(true); // SES BIRIMI EN SON — mic+rota hazir, capture temiz kurulur
      _sesLog('ses kuruldu: video=${widget.video}');

      // Ekran bu arada kapandiysa odayi burada birak (sizinti olmasin)
      if (!mounted) {
        await _kapatOda();
        return;
      }
      _ringTimeout?.cancel();
      setState(() {
        _connecting = false;
        _speakerOn = widget.video;
        _peerJoined = room.remoteParticipants.isNotEmpty;
      });
      if (_peerJoined) _startTimer();
    } catch (e) {
      await _kapatOda(); // yarim kalan odayi TEMIZLE
      rethrow; // ust katman Sentry'e bildirir ve mesaj gosterir
    }
  }

  /// Aktif aramada (HER IKI tarafta) durum yoklama. Caliyor fazindaki _statusPoll'un
  /// devami: baglandiktan sonra sunucuya 3sn'de bir "bu arama hala gecerli mi" diye sorar;
  /// karsi taraf kapattiginda (WS olayi kacsa bile) ekrani kapatir.
  void _aktifPollBaslat() {
    _statusPoll?.cancel();
    _statusPoll = Timer.periodic(const Duration(seconds: 3), (_) => _durumKontrol());
  }

  /// SES NOKTA-ATISI olcumu -> Sentry event (kullanici istegi: "daha derin izleme araci").
  /// 5sn'de bir karsinin ses paketleri (downlink) artiyor mu olcup gebzem-mobile Sentry'e yazar.
  /// Gercek cihazda "ilk aramada ses yok" KESIN teshis: recvDelta=0 -> karsinin sesi HIC gelmiyor
  /// (ag/subscribe); recvDelta>0 ama kullanici DUYMUYOR -> ses ALINIYOR ama CALINMIYOR (iOS cikis
  /// birimi/route). Boylece bir daha karanlikta tahmin yurutmeyiz.
  void _statsBaslat() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || !_baglandi) return;
      try {
        final rp = _room?.remoteParticipants.values.firstOrNull;
        final track = rp?.audioTrackPublications.firstOrNull?.track;
        if (track is! RemoteAudioTrack) {
          _sesLog('stats: remote audio track yok');
          return;
        }
        final s = await track.getReceiverStats();
        final recv = (s?.packetsReceived ?? 0).toInt();
        final delta = recv - _sonRecvPaket;
        _sonRecvPaket = recv;
        Sentry.captureMessage(
          'call.audio.stats video=${widget.video} speaker=$_speakerOn recvPaket=$recv delta=$delta',
          level: SentryLevel.info,
        );
      } catch (e) {
        _sesLog('stats HATA: $e');
      }
    });
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  /// Odayi TAM olarak kapat.
  /// KRITIK: disconnect() yetmez — Room.dispose() cagrilmazsa WebRTC motoru,
  /// dinleyiciler ve ses oturumu (AVAudioSession / Android AudioManager) sizar;
  /// 2-3. aramada ses gitmez ve goruntu bozulur. Sira: disconnect -> listener -> room.
  /// iOS foreground ses kanalini ac/kapat (AppDelegate 'gebzem/audio').
  /// Android'de ve hata durumunda sessizce gecer.
  static const _audioCh = MethodChannel('gebzem/audio');
  Future<void> _sesiAc(bool ac) async {
    if (!Platform.isIOS) return;
    _sesLog('_sesiAc($ac)');
    try {
      await _audioCh.invokeMethod('setAudioEnabled', ac);
    } catch (e) {
      _sesLog('_sesiAc HATA: $e');
    }
  }

  /// Ses akisi teshis logu -> Sentry breadcrumb (gebzem-mobile). Gercek cihazda "sesli aramada
  /// ses neden gitmiyor" kesin gorulur: hangi adim ne zaman, hangi sirada. Davranis degistirmez.
  void _sesLog(String m) {
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(category: 'call.audio', message: m, level: SentryLevel.info),
      );
    } catch (_) {}
  }

  Future<void> _kapatOda() async {
    if (_kapandi) return;
    _kapandi = true;
    await _sesiAc(false); // iOS foreground ses kanalini kapat
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    _statusPoll?.cancel();
    _statsTimer?.cancel();
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;
    if (room == null && listener == null) return;
    // timeout SART: disconnect/dispose HANG ederse CallRoomLock zinciri sonsuza
    // kilitlenir -> sonraki arama "Baglaniyor"da asili kalir (art arda arama bug'i).
    try {
      await room?.disconnect().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      // dispose() Future dondurur; hang ederse (nadir) global sira kilitlenmesin diye timeout
      await listener?.dispose().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await room?.dispose().timeout(const Duration(seconds: 3)); // motoru+ses oturumunu birak
    } catch (_) {}
  }

  /// Aramadan cik. TEK SEFER calisir.
  ///
  /// SIYAH EKRAN HATASI (Android, Sentry: "Cannot use ref after the widget was disposed"):
  /// Eskiden once odayi kapatiyor (await), SONRA `ref` kullaniyor ve EN SON pop ediyorduk.
  /// Kapanis sirasinda widget yok edilirse `ref` firlatiyordu ve `Navigator.pop()` satirina
  /// HIC GELINMIYORDU -> arama ekrani kapanmiyor, siyah kaliyordu.
  /// Simdi: (1) tek seferlik kilit, (2) ekrani HEMEN kapat, (3) `ref` yerine initState'te
  /// yakalanan servis kullan (widget olse de yasar), (4) oda temizligi dispose()'ta
  /// kilit sirasinda yapilir.
  Future<void> _leave({required bool notifyServer}) async {
    if (_ayrildi) return;
    _ayrildi = true;

    // CallKit (iOS) KAPAT — KOK NEDEN: Arama arka planda/kilit ekraninda CallKit ile
    // kabul edildiyse iOS tarafinda AKTIF bir sistem aramasi vardir. Yerel kapatmada
    // (kirmizi tus / RoomDisconnected) SADECE sunucuya "end" gidiyor, CallKit'e HIC
    // haber verilmiyordu -> iOS'un native arama arayuzu ekranda kaliyor, sureyi saymaya
    // devam ediyor ("1:23") ve sistem arama seridi dokunuslari yutuyor ("tiklayinca
    // gitmiyor"). Peer kapatinca aramaBitti() zaten bitir()'i cagiriyor; yerel kapatma
    // bu yolu ATLIYORDU. bitir() idempotent: CallKit ile gosterilmemis aramada
    // activeCalls bos -> no-op, hayalet cevapsiz bildirim URETMEZ.
    unawaited(CallKitService.bitir(widget.callId));

    // SERI (art arda) ARAMA YARISI: oda/ses/kamera teardown'ini AYRILMA ANINDA kilit
    // sirasina koy. dispose() pop animasyonuyla ~300ms gecikir; o boslukta bir sonraki
    // aramanin _odayaBaglan'i kilide ONCE girip, eski odanin Room.dispose'u (global
    // AVAudioSession + _sesiAc(false) + fiziksel kamera) YENI aramanin sesini/goruntusunu
    // altindan cekiyordu -> "art arda ikisinden birinde patliyor". _kapatOda idempotent
    // (_kapandi guard) + timeout'lu; dispose'daki enqueue safety-net olarak KALIR.
    unawaited(CallRoomLock.calistir(_kapatOda));

    await CallSounds.durdur(_sesNesli);

    // Ekrani hemen kapat — arkasindaki oda temizligi dispose()'ta suruyor
    if (mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    }

    try {
      if (notifyServer) await _svc.end(widget.callId);
    } catch (_) {
      // arama zaten bitmis olabilir
    }
    _svc.gecmisiYenile(); // arama gecmisi hemen guncellensin
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
    // Helper.switchCamera native on/arka gecisi yapar (restartTrack'siz).
    // livekit'in setCameraPosition'i restartTrack yapiyordu -> Android'de
    // kamera degismiyordu ("sadece on calisiyor").
    try {
      await rtc.Helper.switchCamera(track.mediaStreamTrack);
      if (mounted) setState(() => _frontCamera = !_frontCamera);
    } catch (e) {
      await Sentry.captureException(e, stackTrace: StackTrace.current);
    }
  }

  @override
  void dispose() {
    _svc.aktifKonusmaBitti(widget.callId); // tek bitir-kapisi muhafizini birak
    WidgetsBinding.instance.removeObserver(this);
    _statusPoll?.cancel();
    _statsTimer?.cancel();
    _endedSub?.cancel();
    _answeredSub?.cancel();
    CallSounds.durdur(_sesNesli);
    // await edilemez (dispose senkron) — ama kilit sirasina konur, boylece
    // BIR SONRAKI aramanin connect'i bu kapanis bitmeden baslamaz.
    unawaited(CallRoomLock.calistir(_kapatOda));
    super.dispose();
  }

  String get _statusText {
    if (_cevapsiz) return _cevapsizNeden;
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
            // Karsi tarafin goruntusu (tam ekran, ekrani doldur)
            if (remote != null)
              Positioned.fill(
                child: VideoTrackRenderer(remote, fit: VideoViewFit.cover),
              )
            else
              _buildAudioBackground(),

            // Kendi goruntun (kucuk pencere).
            // IgnorePointer SART: VideoTrackRenderer yerel kamerayi GestureDetector'a
            // sariyor; kucuk pencereye kazara dokunmak setFocusPoint/setExposurePoint ->
            // flutter_webrtc CameraUtils'te NullPointerException -> uygulama COKUYOR.
            // Kendi onizlemende odak/zoom zaten gereksiz, dokunmayi tamamen kesiyoruz.
            if (showVideo && local != null && _camOn) _buildSelfView(context, local),

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

            // Alt kontroller (cevapsiz durumda: Geri Ara / Kapat)
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: _cevapsiz ? _buildCevapsizKontroller() : _buildAramaKontroller(),
            ),
          ],
        ),
      ),
    );
  }

  /// Suruklenebilir self-view. IgnorePointer YALNIZ renderer'i sarar (dokunus renderer'a
  /// ulasirsa flutter_webrtc CameraUtils NPE ile coker); GestureDetector onun DISINDA.
  /// Tek dokunus -> on/arka kamera; surukle -> en yakin koseye yapisir.
  Widget _buildSelfView(BuildContext c, VideoTrack local) {
    final sz = MediaQuery.of(c).size;
    final varsayilan = Offset(sz.width - _selfW - _selfMargin, 60);
    final pos = _selfPos ?? varsayilan;
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: _selfW,
      height: _selfH,
      child: GestureDetector(
        onTap: _flipCamera,
        onPanUpdate: (d) {
          final cur = _selfPos ?? varsayilan;
          final nx =
              (cur.dx + d.delta.dx).clamp(_selfMargin, sz.width - _selfW - _selfMargin);
          final ny = (cur.dy + d.delta.dy).clamp(60.0, sz.height - _selfH - 140.0);
          setState(() => _selfPos = Offset(nx, ny));
        },
        onPanEnd: (_) {
          final cur = _selfPos ?? varsayilan;
          final sol = (cur.dx + _selfW / 2) < sz.width / 2;
          final ust = (cur.dy + _selfH / 2) < sz.height / 2;
          setState(() => _selfPos = Offset(
                sol ? _selfMargin : sz.width - _selfW - _selfMargin,
                ust ? 60.0 : sz.height - _selfH - 140.0,
              ));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IgnorePointer(child: VideoTrackRenderer(local)),
        ),
      ),
    );
  }

  Widget _buildAramaKontroller() {
    return Row(
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
            child: const Icon(LucideIcons.phoneOff, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  /// Cevapsiz/reddedilen: Geri Ara (peerId varsa) + Kapat. Otomatik kapanma yok.
  Widget _buildCevapsizKontroller() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.peerId != null) ...[
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
                  child: Icon(widget.video ? LucideIcons.video : LucideIcons.phone,
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
              onTap: () => _leave(notifyServer: false),
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

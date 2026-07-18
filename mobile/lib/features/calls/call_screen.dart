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
    this.isGroup = false,
    this.chatTitle = '',
    this.elapsedMs,
  });

  final String callId;
  final String url;
  final String token;
  final bool video;
  final String peerName;
  final String? peerId; // "Geri Ara" icin (giden aramada dolu; gelen aramada gereksiz)
  final bool outgoing; // giden arama mi (karsi taraf henuz kabul etmedi)
  final bool isGroup; // GRUP aramasi mi (coklu katilimci -> avatar izgara + biri ayrilinca arama surer)
  final String chatTitle; // grup basligi (ust bilgide "peerName" yerine)
  final int? elapsedMs; // SURE SENKRONU: kabulden bu yana GECEN SURE (ms, backend). 1:1 ARANAN
  // tarafta answer() cevabindan ~0 gelir; ARAYAN sonradan WS/Status'tan alir. Grupta kullanilmaz.

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
  Timer? _statsTimer; // ses NOKTA-ATISI olcumu (getStats -> sunucu canli log)
  int _sonRecvPaket = 0;
  double _sonEnergy = 0; // ses ENERJISI: paket geliyor ama enerji 0 ise karsi taraf SESSIZ
  bool _sorunBildirildi = false; // kullanici "ses gelmiyor" isaretledi mi

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
  bool _mediaBasladi = false; // GERCEK ses akmaya basladi mi -> sure buna gore baslar (WhatsApp gibi)
  Timer? _mediaYedek; // ses ~8sn'de gelmezse sureyi yine de basla (takili "Baglaniyor" kalma)
  bool _micOn = true;
  bool _camOn = false;
  bool _speakerOn = false; // VARSAYILAN KAPALI (earpiece) — kullanici isterse hoparloru acar (WhatsApp gibi)
  bool _frontCamera = true;
  String? _error;
  Duration _duration = Duration.zero;
  // SURE SENKRONU: MONOTONIK sayac (duvar-saati kaymasindan ETKILENMEZ). Referans (backend'in
  // "gecen sure"si) alininca _sureBaz'a yazilir + sayac SIFIRLANIP baslar -> sure = _sureBaz +
  // sayac. Iki cihaz ayni server referansindan saydigi icin SENKRON. Referans yoksa (grup /
  // hic gelmedi) baz=0, sayac medya aninda baslar (00:00'dan; eski yerel davranis).
  final Stopwatch _sureSayaci = Stopwatch();
  Duration _sureBaz = Duration.zero;
  bool _sureReferansVar = false; // server referansi bir kez kilitlenir (calma-fazi sahte deger girmesin)
  ConnectionQuality _quality = ConnectionQuality.unknown;

  // Cevapsiz/reddedilen arama: arayan tarafta ekran otomatik kapanmaz, "Cevap yok" +
  // Geri Ara/Kapat gosterilir.
  bool _cevapsiz = false;
  String _cevapsizNeden = 'Cevap yok';

  // Suruklenebilir self-view (kendi kamera onizlemesi)
  Offset? _selfPos;
  static const double _selfW = 140, _selfH = 200, _selfMargin = 16; // WhatsApp gibi (biraz buyutuldu)
  bool _selfBuyuk = false; // self-view'e dokununca SWAP: true iken KENDI goruntum tam ekran, karsininki kucuk

  @override
  void initState() {
    super.initState();
    _camOn = widget.video;
    // SURE SENKRONU: ARANAN tarafta answer() cevabindaki gecen-sure (~0). ARAYAN'da null baslar;
    // WS/Status'tan gelince alinir (asagida). Grupta kullanilmaz (yerel sayac).
    _sureReferansiAl(widget.elapsedMs);
    WidgetsBinding.instance.addObserver(this); // resume'da durum uzlastirma icin

    _svc = ref.read(callServiceProvider.notifier);
    final svc = _svc;
    // MESGUL MUHAFIZI: bu ekran (calar/aktif) acildi -> 2. arama baslatma/kabul engellensin.
    // connect'i BEKLEMEDEN, calar fazi dahil isaretlenir; dispose'ta birakilir.
    _svc.ekranAcildi(widget.callId);

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
      _answeredSub = svc.onCallAnswered.listen((ev) {
        if (ev['call_id'] != widget.callId || !mounted) return;
        // SURE SENKRONU: ARAYAN gecen-sure referansini WS call.answered'dan alir (push'ta null gelir).
        _sureReferansiAl((ev['elapsed_ms'] as num?)?.toInt());
        if (!_baglandi) {
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
      final st = await _svc.callStatus(widget.callId);
      s = st['status'] as String? ?? '';
      // SURE SENKRONU KURTARMA: WS call.answered kaybolsa da ARAYAN gercek gecen-sureyi buradan
      // alir (1:1). YALNIZ 'active' iken (backend cevaplanmayinca elapsed_ms=-1 doner zaten,
      // ama cift guvence: zil fazinda referans KILITLEME -> sayac sisme blocker'inin kok fix'i).
      if (s == 'active') _sureReferansiAl((st['elapsed_ms'] as num?)?.toInt());
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
      // KESINTI TOPARLAMA (GSM/WhatsApp aramasi Gebzem'i boldukten sonra one donunce):
      // iOS CallKit didActivate KESINTI SONRASI GUVENILIR GELMEZ (Apple forum 749202) ->
      // uygulamaya geri donmeyi (resume) YEDEK tetikleyici yap. Bagli aramada ses birimini
      // yeniden aktive et + mikrofonu kullanicinin SON durumuna getir (mute'unu zorla acma).
      // GetStream/Twilio'nun kanitlanmis deseni; en kotu senaryo birkac saniyelik gecikme.
      if (_baglandi) _kesintidenTopla();
    }
  }

  /// Baska bir arama (GSM/WhatsApp) Gebzem'i boldukten sonra one donunce sesi toparla.
  /// DUSUK RISK: mevcut arama akisina dokunmaz, sadece ses birimini + mic durumunu tazeler.
  Future<void> _kesintidenTopla() async {
    _sesLog('kesintiden topla (resume)');
    await _sesiAc(true); // iOS ses birimini yeniden aktive et (Android'de no-op)
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(_micOn); // kullanicinin son mic durumu
    } catch (_) {}
  }

  /// Cevapsiz/reddedilen arama: ekrani KAPATMADAN "Cevap yok/reddedildi/mesgul" durumuna
  /// gec (Geri Ara / Kapat gosterilir). Otomatik pop YOK.
  Future<void> _cevapsizGoster(String neden, {bool sunucuyaBildir = false}) async {
    if (_baglandi || _ayrildi || _cevapsiz) return;
    // MESGUL MUHAFIZINI BIRAK: cevapsiz/reddedilen ekran ARTIK aktif arama degil (sadece
    // Geri Ara/Kapat sonucu). Ekran POP olmadigindan dispose de calismaz -> ekranKapandi'yi
    // BURADA cagirmazsak "aramadaMi" sonsuza true kalir; o ekrana bakan kullanici gelen
    // aramalari KACIRIR ("kabul ettim acilmadi") + yeni arama baslatamaz (v13 dogrulama bulgusu).
    _svc.ekranKapandi(widget.callId);
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
    // Bu ekran CEVAPSIZ durumda (arama bitti); "aramada" sayilmasin, yoksa kendi ekranimiz
    // yuzunden start() "Zaten bir aramadasınız" der. pushReplacement zaten bu ekrani kapatacak.
    _svc.ekranKapandi(widget.callId);
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
        roomOptions: RoomOptions(
          adaptiveStream: true, // zayif baglantida/kucuk pencerede kaliteyi otomatik dusur
          dynacast: true, // kullanilmayan ust katmanlari durdur (pil/veri/CPU tasarrufu)
          // GRUP: dusuk video profili (540p/700kbps — N yayin + N*(N-1) abonelik cx33'u
          // yormasin). 1:1: uyarlanabilir 720p profili AYNEN (call_media_options.dart).
          defaultCameraCaptureOptions:
              widget.isGroup ? kGroupCameraCaptureOptions : kCameraCaptureOptions,
          defaultVideoPublishOptions:
              widget.isGroup ? kGroupVideoPublishOptions : kVideoPublishOptions,
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
            setState(() => _peerJoined = true); // grupta setState izgarayi da tazeler
            // Sure BURADA baslamaz -> gercek ses gelince (_mediaBaslat). Peer odada ama medya
            // henuz yokken ekranda "Baglaniyor" yazar (WhatsApp gibi). Yedek: 8sn'de ses gelmezse basla.
            _mediaGuvenlikAgi();
          }
        })
        ..on<ParticipantDisconnectedEvent>((_) {
          if (!mounted) return;
          if (widget.isGroup) {
            // GRUP: biri ayrilinca arama SURER. Otomatik _leave YAPMA — 'remoteParticipants.isEmpty'
            // "herkes ayrildi" ile "henuz kimse katilmadi"yi karistirir (host tek A bagli, A cikar,
            // B hala caliyor -> yanlislikla oda kapanirdi). Oda bitisini BACKEND yonetir: son katilimci
            // ayrilinca (joined=0) call.ended WS -> aramaBitti -> _leave. Kullanici kirmizi tusla cikar.
            setState(() {}); // yalniz izgarayi guncelle
            return;
          }
          _leave(notifyServer: true); // 1:1: karsi taraf ayrildi -> arama biter (AYNEN)
        })
        ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
          if (mounted && e.participant is LocalParticipant) {
            setState(() => _quality = e.connectionQuality);
          }
        })
        ..on<TrackSubscribedEvent>((e) {
          if (mounted) setState(() {});
          if (e.track is VideoTrack) {
            // Ilk-kare texture yarisi: tek setState texture'i tazelemeyebilir ("ses var goruntu yok").
            // Post-frame + kisa gecikmeli tekme ile renderer ilk kareler gelince yeniden sorgulanir.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) setState(() {});
            });
          }
          // Teshis logu: remote audio track ne zaman subscribe oldu (ses akisi zaman cizelgesi).
          // NOT: burada _sesiAc(true) COZUM DEGIL — isAudioEnabled setter idempotent (ayni true=no-op),
          // ses birimini yeniden baslatmaz + mic-oncesi yarisi bozabilir (dogrulama wf_889c1267).
          // ILK-ARAMA sessizligi icin dogru cozum native AVAudioSession re-aktivasyonu; once getStats
          // ile gercek cihazda OLC (ses aliniyor mu/caliniyor mu), sonra native fix.
          if (e.track is AudioTrack) {
            _sesLog('remote AUDIO track subscribe oldu (ses akisi basladi)');
            _mediaBaslat(); // GERCEK ses geldi -> sure 00:00'dan simdi baslar
          }
        })
        ..on<TrackUnsubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        // Karsi taraf kamerayi kapatinca/acinca (mute/unmute) UI tazelensin — grupta tile
        // video<->avatar gecisi, 1:1'de zararsiz rebuild.
        ..on<TrackMutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnmutedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<ActiveSpeakersChangedEvent>((_) {
          if (mounted && widget.isGroup) setState(() {}); // grup: konusan yesil halkasini tazele
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
      await room.setSpeakerOn(false); // VARSAYILAN KULAKLIK (earpiece) — sesli+goruntulude kapali basla,
      // kullanici hoparloru elle acar. Cagri SILINMEDI (sira korunur); _sesiAc EN SON kaldi -> mic bozulmaz.
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
        _speakerOn = false; // varsayilan kapali (earpiece)
        _peerJoined = room.remoteParticipants.isNotEmpty;
      });
      // Resume/reconnect: ses zaten akiyorsa sureyi hemen basla; peer var ama ses yoksa yedek.
      if (_remoteAudioHazir()) {
        _mediaBaslat();
      } else if (_peerJoined) {
        _mediaGuvenlikAgi();
      }
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
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || !_baglandi) return;
      try {
        int recv = -1; // -1 = remote audio track YOK
        double energy = 0;
        final rp = _room?.remoteParticipants.values.firstOrNull;
        final track = rp?.audioTrackPublications.firstOrNull?.track;
        if (track is RemoteAudioTrack) {
          final s = await track.getReceiverStats();
          recv = (s?.packetsReceived ?? 0).toInt();
          // totalAudioEnergy: gelen sesin TOPLAM enerjisi (birikimli). Delta'si 0 ise
          // paket geliyor ama ici SESSIZLIK -> karsi tarafin mikrofonu kapali/bozuk.
          energy = (s?.totalAudioEnergy ?? 0).toDouble();
        }
        final delta = recv < 0 ? 0 : recv - _sonRecvPaket;
        if (recv >= 0) _sonRecvPaket = recv;
        final enerjiDelta = energy - _sonEnergy;
        _sonEnergy = energy;
        // iOS cikis durumu: paket+enerji VAR ama audioEnabled=false/route yanlissa
        // ses geliyor ama iPhone CALMIYOR (kesin iOS cikis sorunu).
        final ios = await _sesDurumOku();
        // CANLI + KALICI: her 2sn ses metrigini SUNUCUYA yolla -> api log (zaman damgali).
        // YANILTMAZ: recv=-1 track yok | delta=0 paket gelmiyor | enerji~0 karsi SESSIZ |
        // paket+enerji var ama iOS cikis kapali -> ses geliyor iPhone calmiyor.
        _svc.audioStat(widget.callId, {
          'recv': recv,
          'delta': delta,
          'enerji': (enerjiDelta * 1000).toStringAsFixed(1), // ses seviyesi (0 = sessizlik)
          'outgoing': widget.outgoing,
          'video': widget.video,
          'speaker': _speakerOn,
          'peer': _peerJoined,
          if (ios != null) 'ios': ios,
        });
      } catch (_) {}
    });
  }

  /// SURE SENKRONU referansini AL: backend'in "gecen sure"si (ms). Bir kez kilitlenir (1:1);
  /// grupta / null / negatif (cevaplanmadi) yok sayilir. Referans alininca MONOTONIK sayac
  /// sifirlanip baslar -> sure = _sureBaz(server) + sayac. Iki cihaz ayni server referansindan
  /// saydigi icin SENKRON; duvar-saati kaymasi ETKILEMEZ (Stopwatch monotonik). Gec gelirse
  /// (WS kaybi -> Status) sayac SNAP eder.
  void _sureReferansiAl(int? elapsedMs) {
    if (widget.isGroup || _sureReferansVar) return;
    if (elapsedMs == null || elapsedMs < 0) return;
    _sureReferansVar = true;
    _sureBaz = Duration(milliseconds: elapsedMs);
    _sureSayaci
      ..reset()
      ..start();
    if (mounted && _mediaBasladi) setState(() => _duration = _sureBaz + _sureSayaci.elapsed);
  }

  void _startTimer() {
    // Referans yoksa (grup/fallback) sayaci SIMDI (medya aninda) baslat -> 00:00'dan; referans
    // varsa zaten kabul aninda basladi (dogru gecen-sure). Cift start no-op (Stopwatch guvenli).
    if (!_sureSayaci.isRunning) _sureSayaci.start();
    _durationTimer?.cancel();
    _tick();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _duration = _sureBaz + _sureSayaci.elapsed);
  }

  /// GERCEK ses akisi basladi -> sureyi SIMDI baslat (WhatsApp gibi). Peer odaya katilmis
  /// olsa da ses gelene kadar "Baglaniyor" gosterilir; ilk remote audio track gelince buraya.
  /// Idempotent: bir kez calisir.
  void _mediaBaslat() {
    if (_mediaBasladi || _ayrildi) return;
    _mediaBasladi = true;
    _mediaYedek?.cancel();
    _ringTimeout?.cancel();
    if (mounted) setState(() => _peerJoined = true);
    _startTimer();
  }

  /// Peer odada ama ses ~8sn'de gelmezse takili "Baglaniyor" kalmasin -> sureyi yine de basla.
  void _mediaGuvenlikAgi() {
    if (_mediaBasladi) return;
    _mediaYedek?.cancel();
    _mediaYedek = Timer(const Duration(seconds: 8), () {
      if (mounted && !_mediaBasladi) _mediaBaslat();
    });
  }

  /// Odada karsi tarafin abone olunmus (canli) bir AUDIO track'i var mi (resume/reconnect icin).
  bool _remoteAudioHazir() {
    for (final p in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      for (final pub in p.audioTrackPublications) {
        if (pub.subscribed && pub.track != null) return true;
      }
    }
    return false;
  }

  /// Odayi TAM olarak kapat.
  /// KRITIK: disconnect() yetmez — Room.dispose() cagrilmazsa WebRTC motoru,
  /// dinleyiciler ve ses oturumu (AVAudioSession / Android AudioManager) sizar;
  /// 2-3. aramada ses gitmez ve goruntu bozulur. Sira: disconnect -> listener -> room.
  /// iOS foreground ses kanalini ac/kapat (AppDelegate 'gebzem/audio').
  /// Android'de ve hata durumunda sessizce gecer.
  static const _audioCh = MethodChannel('gebzem/audio');
  /// TESHIS: iPhone'un ses cikis durumunu native'den oku (getAudioState).
  /// {audioEnabled, active, category, route}. Android'de/hata durumunda null.
  Future<Map<String, dynamic>?> _sesDurumOku() async {
    if (!Platform.isIOS) return null;
    try {
      final r = await _audioCh.invokeMethod('getAudioState');
      return (r as Map?)?.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }

  /// Kullanici "ses gelmiyor" dedigi ANI sunucuya isaretler + o anki tum durumu
  /// (paket/enerji/iOS cikis) ekler. Ben sonradan bu aramanin logunda tam veriyi bulurum.
  Future<void> _sorunBildir() async {
    setState(() => _sorunBildirildi = true);
    final ios = await _sesDurumOku();
    _svc.audioStat(widget.callId, {
      'sorun': true,
      'sure': _duration.inSeconds,
      'recv': _sonRecvPaket,
      'outgoing': widget.outgoing,
      'video': widget.video,
      'speaker': _speakerOn,
      'peer': _peerJoined,
      if (ios != null) 'ios': ios,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sorun kaydedildi — teşekkürler'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  // Ses birimi NESIL JETONU (CallSounds'un kanitlanmis deseni): sirali gecis (bir aramayi
  // bitirip HEMEN yeni arama baslatma) sirasinda eski ekranin gec _sesiAc(false)'i, yeni
  // aramanin _sesiAc(true)'undan SONRA dusup yeni sesi KOSULSUZ kapatiyordu (CLAUDE.md tuzagi).
  // Cozum: ses birimini en son "true" ile sahiplenen ekran disinda kimse kapatamaz.
  static int _sesNesilSayaci = 0;
  int _benimSesNeslim = 0;
  Future<void> _sesiAc(bool ac) async {
    if (!Platform.isIOS) return;
    if (ac) {
      _benimSesNeslim = ++_sesNesilSayaci; // ses birimini SAHIPLEN
    } else if (_benimSesNeslim != _sesNesilSayaci) {
      // daha yeni bir arama ses birimini sahiplendi -> onun sesini KAPATMA
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
    // KAPASITE MUHAFIZI (dogrulama bulgusu): video<=8 siniri yalniz BASLATMADA uygulaniyordu;
    // 9-32 kisilik SESLI grupta mid-call kamera acmak siniri deliyordu (cx33 CPU/bant duvari).
    // Grupta oda 8'den kalabaliksa kamera ACMAYI engelle (kapatma her zaman serbest).
    if (on && widget.isGroup) {
      final katilimci = 1 + (_room?.remoteParticipants.length ?? 0);
      if (katilimci > 8) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Görüntülü grup en fazla 8 kişi — kamera açılamıyor')));
        }
        return;
      }
    }
    if (on) {
      // Sesli aramada baslarken kamera izni ISTENMEDI -> mid-call kamera acarken iste.
      final st = await Permission.camera.request();
      if (st != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kamera izni gerekli')));
        }
        return;
      }
    }
    await _room?.localParticipant?.setCameraEnabled(on);
    // Kamera KAPANINCA swap'i sifirla: yoksa tekrar acilinca (bothVideo yeniden true) gorunum
    // kendiliginden self-buyuk'e ziplar (kullanici istemeden). Kapali -> varsayilan (remote buyuk).
    if (mounted) {
      setState(() {
        _camOn = on;
        if (!on) _selfBuyuk = false;
      });
    }
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
    _svc.ekranKapandi(widget.callId); // mesgul muhafizini birak -> yeni arama serbest
    WidgetsBinding.instance.removeObserver(this);
    _statusPoll?.cancel();
    _statsTimer?.cancel();
    _mediaYedek?.cancel();
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
    // Peer odada ama GERCEK ses henuz akmadi -> "Baglaniyor" (WhatsApp gibi; sure fiili sesle baslar).
    if (!_mediaBasladi) return 'Bağlanıyor...';
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
    // MID-CALL: widget.video kilidini kaldir -> sesli aramada kamera acilinca (local track) VEYA karsi
    // kamera acinca (remote track) ekran video moduna gecer (WhatsApp gibi). Goruntulu aramada davranis AYNI.
    final showVideo = remote != null || local != null;

    // SWAP (WhatsApp): self-view'e dokununca kendi goruntum tam ekrana, karsininki kucuk pencereye gecer.
    // Sadece HER IKI goruntu de varken mumkun; degilse eski davranisa (remote buyuk / local kucuk) duser.
    final bothVideo = remote != null && local != null && _camOn;
    final swap = _selfBuyuk && bothVideo;
    // Tam ekran (buyuk) track ve kucuk (self-view) track — swap durumuna gore rol degisir.
    final VideoTrack? bigTrack = swap ? local : remote;
    final VideoTrack? smallTrack =
        swap ? remote : (local != null && _camOn ? local : null);
    final bool smallIsLocal = !swap; // kucuk pencere KENDI kameram mi (mirror/crash notu icin)

    return PopScope(
      canPop: false, // geri tusuyla kacamaz — aramayi bitirmeli
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: Stack(
          children: [
            // GRUP: coklu-katilimci avatar izgarasi (sesli). 1:1: mevcut video/ses arka plani AYNEN.
            if (widget.isGroup)
              _buildGroupGrid()
            else if (bigTrack != null)
              Positioned.fill(
                // KEY track kimligine bagli: track her (yeniden) subscribe olunca (veya swap ile rol
                // degisince) TAZE renderer baglanir -> bayat/siyah texture kalmaz (ilk-kare yarisi fix).
                child: VideoTrackRenderer(bigTrack,
                    key: ValueKey('big-${bigTrack.sid}'), fit: VideoViewFit.cover),
              )
            else
              _buildAudioBackground(),

            // Kucuk pencere (self-view). Dokun -> SWAP (buyuk/kucuk yer degistir), surukle -> koseye yapisir.
            // IgnorePointer SART: VideoTrackRenderer kamerayi GestureDetector'a sariyor; kucuk pencereye
            // kazara dokunmak setFocusPoint/setExposurePoint -> flutter_webrtc CameraUtils'te
            // NullPointerException -> uygulama COKUYOR. Renderer'i tamamen dokunmaya kapatiyoruz; dokunusu
            // DIStaki GestureDetector (opaque) yakalar.
            // GRUPTA self-view overlay ACILMAZ: yerel goruntu kendi izgara tile'inda.
            // (Overlay acilirsa grup gridinin ustune biner — grup-video fazi karari.)
            if (!widget.isGroup && showVideo && smallTrack != null)
              _buildSelfView(context, smallTrack,
                  canSwap: bothVideo, isLocal: smallIsLocal),

            // Ust bilgi: isim + sure/durum + baglanti kalitesi
            Positioned(
              top: 48,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                      widget.isGroup
                          ? (widget.chatTitle.isEmpty ? 'Grup araması' : widget.chatTitle)
                          : widget.peerName,
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
                  // TESHIS: sorun anini kullanici ISARETLER -> sunucuya "SORUN-BILDIRIMI"
                  // duser. Ben yaninda olmasam da o aramayi tam bulurum.
                  if (_peerJoined && !_cevapsiz)
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

  /// Suruklenebilir + dokun-ile-swap self-view (kucuk pencere).
  ///
  /// SURUKLEME KOK-COZUMU: GestureDetector'in child'i IgnorePointer'la sarili renderer.
  /// GestureDetector'in VARSAYILAN davranisi HitTestBehavior.deferToChild — yani kendisi
  /// ancak child'i hit-test'i GECERSE pointer olayi alir. IgnorePointer TUM alt-agaci
  /// hit-test DISI biraktigi icin child asla "hit" olmuyor -> GestureDetector hic pointer
  /// olayi ALMIYORDU (ne onTap ne onPan tetikleniyordu). COZUM: behavior: HitTestBehavior.opaque
  /// -> GestureDetector kendi alanini KOSULSUZ hit-test'e sokar, dokunusu kendi yakalar;
  /// IgnorePointer yine renderer'i (CameraUtils NPE) korur.  (flutter/flutter deferToChild;
  /// flutter-webrtc #1007 PlatformView dokunus yutmasi.)
  ///
  /// Dokun -> SWAP (buyuk/kucuk yer degistir, WhatsApp). Kamera cevirme kontrol cubugundaki
  /// ayri butonda. Surukle -> en yakin koseye yapisir.
  Widget _buildSelfView(BuildContext c, VideoTrack track,
      {required bool canSwap, required bool isLocal}) {
    final sz = MediaQuery.of(c).size;
    // Varsayilan konum: sag-ust ama ust bilgi/butonun ALTINDA (buyutulen self-view cakismasin).
    final varsayilan = Offset(sz.width - _selfW - _selfMargin, 130);
    final pos = _selfPos ?? varsayilan;
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: _selfW,
      height: _selfH,
      child: GestureDetector(
        // KRITIK: opaque olmadan (deferToChild) IgnorePointer child'i yuzunden hic dokunus gelmez.
        behavior: HitTestBehavior.opaque,
        onTap: canSwap ? () => setState(() => _selfBuyuk = !_selfBuyuk) : null,
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
          borderRadius: BorderRadius.circular(24), // WhatsApp gibi belirgin yuvarlak kose
          child: IgnorePointer(
            // KEY rol+kimlige bagli -> swap'ta (local<->remote) taze renderer, bayat texture kalmaz.
            child: VideoTrackRenderer(track,
                key: ValueKey('small-${isLocal ? 'local' : 'remote'}-${track.sid}')),
          ),
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
        // MID-CALL: kamera butonu HER ZAMAN gorunur (sesli aramada "kameraya gec" -> video moduna).
        // GRUP DAHIL (grup goruntulu fazi): yerel kamera kendi tile'inda, digerleri autoSubscribe
        // ile gorur; sesli grupta acilinca izgara video moduna gecer.
        _ctrlButton(
          icon: _camOn ? LucideIcons.video : LucideIcons.videoOff,
          active: !_camOn,
          onTap: _toggleCam,
        ),
        const SizedBox(width: 16),
        // On/arka kamera degistir — yalniz kamera acikken anlamli
        if (_camOn) ...[
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

  /// Katilimcinin CANLI video track'i. Yerel: kamera acikken; uzak: abone olunmus + mute degil.
  /// null = video yok (avatar gosterilir).
  VideoTrack? _katilimciVideosu(Participant p) {
    if (p is LocalParticipant) {
      if (!_camOn) return null;
      return p.videoTrackPublications.firstOrNull?.track;
    }
    for (final pub in p.videoTrackPublications) {
      if (pub.subscribed && !pub.muted && pub.track != null) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  /// GRUP: herhangi bir katilimcida canli video varsa VIDEO IZGARASI; hic yoksa ESKI sesli
  /// avatar izgarasi BIREBIR korunur (sesli grup regresyonsuz — kullanici test etti).
  Widget _buildGroupGrid() {
    final katilimcilar = <Participant>[];
    final lp = _room?.localParticipant;
    if (lp != null) katilimcilar.add(lp);
    katilimcilar.addAll(_room?.remoteParticipants.values ?? const []);
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
        // Kaydirilabilir -> kalabalik grupta tasma (RenderFlex overflow) olmaz.
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

  /// GORUNTULU GRUP IZGARASI: 2 kisi tek sutun, 3+ iki sutun. Kapasite siniri 8 (backend)
  /// -> 2x4 kaydirmasiz sigar. Video olan katilimci video tile, olmayan avatar tile (karisik).
  Widget _grupVideoIzgara(List<Participant> katilimcilar) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0B141A),
        // Ust bilgi (isim/sure/teshis butonu) + alt kontrol bari ile cakismayan alan
        padding: const EdgeInsets.fromLTRB(8, 108, 8, 132),
        child: LayoutBuilder(builder: (context, box) {
          final n = katilimcilar.length;
          final cols = n <= 2 ? 1 : 2;
          final rows = (n + cols - 1) ~/ cols;
          // SAVUNMA (dogrulama bulgusu): kamera acildiktan SONRA odaya 9+ kisi gelebilir
          // (sesli grup 32'ye kadar) -> tile'lar mikro boyuta dusmesin; 4 satirdan
          // fazlasi KAYDIRILARAK gorunur. n<=8'de eski davranis (tam sigar, kaydirmasiz).
          final gorunurSatir = rows > 4 ? 4 : rows;
          const bosluk = 6.0;
          final w = (box.maxWidth - (cols - 1) * bosluk) / cols;
          final h = (box.maxHeight - (gorunurSatir - 1) * bosluk) / gorunurSatir;
          return GridView.count(
            crossAxisCount: cols,
            mainAxisSpacing: bosluk,
            crossAxisSpacing: bosluk,
            childAspectRatio: w / h,
            // padding SART (dogrulama bulgusu): verilmezse Flutter, MediaQuery safe-area
            // padding'ini (centik/status bar + jest cubugu) ORTULU ekler -> icerik viewport'u
            // asar, kaydirma kapaliyken ALT SIRA KIRPILIR. Ust/alt bosluk zaten Container'da.
            padding: EdgeInsets.zero,
            physics: rows > 4
                ? const ClampingScrollPhysics() // 9+ kisi: kaydirilabilir
                : const NeverScrollableScrollPhysics(), // <=8: tam sigar
            children: [for (final p in katilimcilar) _grupVideoTile(p)],
          );
        }),
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
              // KEY track kimligine bagli (ilk-kare/bayat-texture fix — 1:1 ile ayni desen).
              // IgnorePointer SART: renderer'a dokunus giderse flutter_webrtc CameraUtils
              // NullPointerException ile COKUYOR (self-view'daki ayni koruma).
              IgnorePointer(
                child: VideoTrackRenderer(video,
                    key: ValueKey('tile-${video.sid}'),
                    fit: VideoViewFit.cover,
                    // MANTIKSAL piksel bildir (DPR carpani yok): kucuk tile'da adaptiveStream
                    // 270p alt katmani secer -> 8 kisilik gridde telefon 7x540p decode etmez
                    // (isinma/kare dususu onlemi; dogrulama bulgusu). 2 kisilik buyuk tile'da
                    // yine 540p secilir (mantiksal boyut da buyuk).
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

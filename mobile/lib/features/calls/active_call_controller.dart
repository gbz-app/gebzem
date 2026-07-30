import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:battery_plus/battery_plus.dart';
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

/// BEKLEMEYE ALINMIS ARAMA (test turu 18 — call waiting): oda BAGLI kalir, yalniz medya
/// durur (mic/kamera kapali + uzak track'ler `disable()` ile sunucudan kesilir). Sunucuda
/// arama 'active' kalir; diger gorusme bitince kaldigi yerden devam eder.
class ParkEdilenArama {
  ParkEdilenArama({
    required this.bilgi,
    required this.room,
    required this.listener,
    required this.gecen,
    required this.micOn,
    required this.camOn,
    required this.isGroup,
  });
  final AramaBilgisi bilgi;
  final Room room;
  final EventsListener<RoomEvent> listener;
  final Duration gecen; // park anindaki konusma suresi (devam edince buradan sayar)
  final bool micOn;
  final bool camOn;
  final bool isGroup;
}

/// Kucuk pencere (PiP / yuzen pencere) izgarasindaki TEK katilimci (test turu 17).
class MiniKatilimci {
  const MiniKatilimci(this.track, this.ad, {this.mirror = false});
  final VideoTrack? track; // null -> harf avatari
  final String ad;
  final bool mirror; // yalniz kendi on kameram aynalanir
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
      // PiP'e girerken bekleyen kamera-mute'u iptal et (KOK-4): PiP'te kamera ACIK kalir,
      // karsi taraf beni gormeye devam eder.
      if (v) _pipKameraGecikme?.cancel();
      if (v) unawaited(PipService.micDurum(_micOn)); // dugme ikonu dogru baslasin
      notifyListeners();
    }, onEylem: (eylem) {
      // TEST TURU 14: PiP penceresindeki WhatsApp tarzi dugmeler
      if (arama == null || _ayrildi) return;
      if (eylem == 'mic') {
        unawaited(toggleMic());
      } else if (eylem == 'kapat') {
        unawaited(leave(notifyServer: true));
      }
    });
    // iOS SISTEM PiP (test turu 7): cihaz destegini bir kez sor (iOS<15/desteksiz -> false ->
    // hicbir sey yapilmaz, kamera-mute avatar yedegi kalir).
    PipService.iosPipHazirMi().then((v) => _iosPipHazir = v);
    // iOS PiP DURUM geri bildirimi (test turu 9): native GebzemPip delegate PiP basladi/durdu/
    // basarisiz haber verir. Basladi/durdu -> pipModunda (kamera-mute yedegi PiP'te atlanir).
    // Basarisiz (kullanici Ayarlar'dan PiP kapatmis olabilir) -> kamerayi kapat (donuk kare
    // yerine avatar). Android'de zaten PipService.dinle var; iOS bu ayri kanaldan gelir.
    PipService.iosDinle(onDurum: (aktif) {
      pipModunda = aktif;
      // TEST TURU 29: Android dalinda (satir ~103) olan ama iOS'ta EKSIK olan adim —
      // PiP GERCEKTEN basladiysa bekleyen 900ms'lik kamera-mute zamanlayicisini IPTAL et.
      // Yoksa PiP acikken kamera yine de kapaniyor ve karsi taraf beni goremiyordu.
      if (aktif) _pipKameraGecikme?.cancel();
      notifyListeners();
    }, onBasarisiz: _iosPipBasarisiz, onKameraKesinti: _iosKameraKesinti,
        onPipOlcum: (olcum) {
          // TEST TURU 39: olcum ARKA PLANDA uretilir; Sentry gonderimi orada kaybolabiliyor.
          // Sakla, ON PLANA DONUNCE gonder.
          _bekleyenOlcum = olcum;
        }, onKareDurdu: _iosPipKareDurdu);
    // TEST TURU 20 — GSM ARAMA BEKLETME (Android; iOS'ta bunu CallKit yapar):
    // normal telefon aramasi baslayinca Gebzem aramasi BEKLEMEYE alinir (medya durur,
    // arama SUNUCUDA OLMEZ), telefon gorusmesi bitince kaldigi yerden DEVAM eder.
    PipService.gsmAramada.addListener(() {
      final b = arama;
      if (b == null || _ayrildi || !_baglandi) return;
      unawaited(beklemeyeAl(b.callId, PipService.gsmAramada.value));
    });
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
  Map<String, dynamic>? _bekleyenOlcum; // turu 39: on plana donunce Sentry'e yazilir
  AppLifecycleState? _sonYasamDurumu; // turu 46: yon kontrolu (arka plana mi gidiyoruz)
  DateTime? _arkaPlanaGidisAni; // turu 48: PiP baslatma tekrar penceresi (1200ms)
  Timer? _kesintiMuteGecikme; // turu 43: kurtarma sansi icin gecikmeli durust mute
  bool _iosPipMesgul = false; // turu 39: _iosPipGuncelle yeniden-girme kilidi
  String _iosPipYerelId = ''; // turu 28: PiP alt gorunumundeki kendi kamera track id'm

  /// iOS kucuk penceresinde BOLUNME acik mi. **SU AN ACIK (true) — turu 41-42'den beri.**
  ///
  /// TARIHCE (yorumlar 30 Tem'e kadar YANLIS "kapali" diyordu, denetimde yakalandi):
  /// · turu 24: ilk UST/ALT bolunme (`pipAddStacked`), kurulum kimligi BIRLESIK "uzak|yerel".
  /// · turu 26: GERI ALINDI — kamera mute olunca yerel id bosalip kimlik degisiyor ->
  ///   `kur()` -> `birak()` -> `stopPictureInPicture()` -> pencere HIC acilmiyordu.
  /// · turu 27-31: DOGRU yontemle geri geldi — UIStackView + `yerelAyarla`, kimlik YALNIZ
  ///   uzak track (bu yuzden kamera mute'u artik pencereyi kapatmaz).
  /// · turu 34: gecici olarak false yapildi (arka plan kamerasi kanitlanmamisti).
  /// · turu 43-44: arka plan kamerasi deployment target 16.0 ile KANITLANDI.
  /// · turu 41-42: bolunme = WhatsApp tarzi SAG-ALT KOSE KUTUSU olarak ACIK (true).
  ///
  /// ⚠️ YAPMA: bunu false yapma — kose kutusu (kendi goruntum) TAMAMEN kaybolur.
  /// ⚠️ YAPMA: kurulum kimligine yerel track id'sini KARISTIRMA (turu 24/26 dersi:
  ///   pencere hic acilmaz).
  static const bool pipBolunme = true;
  // iOS COKLU-GOREV KAMERA (test turu 9): isMultitaskingCameraAccessEnabled acildiysa true.
  // Acikken arka planda kamera CAPTURE'a devam eder -> PiP karsi tarafa CANLI gonderir
  // (kullanici sikayeti: "alta alinca karsi taraf beni goremiyor"). iOS18+ entitlementsiz;
  // desteksiz cihazda false kalir -> mevcut kamera-mute avatar yedegine duser.
  bool _iosArkaPlanKamera = false;
  bool _iosCokluGorevDeniyor = false; // cift native cagriyi engelle (test turu 10)

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
  Timer? _pipKameraGecikme; // PiP'e girerken kamera-mute'u geciktirir (test turu 14 KOK-4)

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

  /// UYGULAMA-ICI YUZEN VIDEO (test turu 10): minimize edilmis aramada bantta gosterilecek
  /// UZAK video (grup: aktif konusan; 1:1: karsi taraf). !muted -> karsi kamera kapaliysa
  /// null (bant avatar gosterir). Yerel kamerayi GOSTERMEZ (karsiyi gormek istersin).
  VideoTrack? get bantVideo {
    if (_isGroup) {
      for (final p in _room?.activeSpeakers ?? const <Participant>[]) {
        if (p is! RemoteParticipant) continue;
        final t = _bantIlkVideo(p);
        if (t != null) return t;
      }
    }
    for (final p in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      final t = _bantIlkVideo(p);
      if (t != null) return t;
    }
    return null;
  }

  /// KUCUK PENCERE KATILIMCILARI (test turu 17): sistem PiP'i ve uygulama-ici yuzen pencere
  /// artik IZGARA cizer. Sira: once UZAKLAR (grupta AKTIF KONUSAN basta), en sonda BEN.
  /// Video yoksa harf avatari cizilir (sesli katilimci / kamera kapali).
  List<MiniKatilimci> get miniKatilimcilar {
    final out = <MiniKatilimci>[];
    final r = _room;
    if (r == null) return out;
    final uzaklar = <RemoteParticipant>[];
    if (_isGroup) {
      for (final p in r.activeSpeakers) {
        if (p is RemoteParticipant && !uzaklar.contains(p)) uzaklar.add(p);
      }
    }
    for (final p in r.remoteParticipants.values) {
      if (!uzaklar.contains(p)) uzaklar.add(p);
    }
    for (final p in uzaklar) {
      final ad = p.name.isNotEmpty ? p.name : (arama?.peerName ?? '?');
      out.add(MiniKatilimci(_bantIlkVideo(p), ad));
    }
    if (r.localParticipant != null) {
      out.add(MiniKatilimci(yerelVideo, 'Sen', mirror: _frontCamera));
    }
    return out;
  }

  // ---- ANINDA KAMERA (test turu 22): baglanti beklenmeden kendi goruntum ----
  LocalVideoTrack? _onizlemeTrack;
  Future<void>? _onizlemeIsi; // turu 32: onizleme acma isi (yayin oncesi BEKLENIR)
  bool _onizlemeYayinda = false;
  // TEST TURU 50 (KOK NEDEN — "birebirde bazen goruntum gelmiyor"): `Future.timeout`
  // altta calisan isi IPTAL ETMEZ. Onizleme sureyi asarsa yedek yol `setCameraEnabled`
  // ikinci bir kamera acar; iOS'ta flutter_webrtc'nin TEK paylasilan `videoCapturer`
  // property'si (FlutterRTCMediaStream.m) uzerine yazildigi icin iki acilis birbirinin
  // capture oturumunu CALAR -> video track HIC yayinlanmaz, hata SESSIZCE yutulur.
  // Bu bayrak: sure asildi, gec biten onizleme track'i ATILSIN (controller'a girmesin).
  bool _onizlemeIptal = false;

  /// Ekranda gosterilecek KENDI goruntum: yayinlanan track varsa o, yoksa onizleme.
  VideoTrack? get kendiGoruntum {
    final t = _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
    if (t is VideoTrack) return t;
    return _onizlemeTrack;
  }

  /// Odaya baglanmadan kamerayi ac (izin varsa). Hata/izin yoksa sessizce vazgecilir —
  /// baglanti sonrasi normal setCameraEnabled yolu devreye girer.
  Future<void> _onizlemeAc() async {
    try {
      // KOK NEDEN (test turu 25 — "kameram tam ekran gelmiyor"): GIDEN aramada kamera izni
      // bu ana kadar HIC istenmemis olabiliyordu; sadece "verilmis mi" diye bakinca
      // onizleme hic acilmiyordu. Artik IZIN ISTENIR (WhatsApp da arama baslarken sorar).
      if (!await Permission.camera.isGranted) {
        final st = await Permission.camera.request();
        if (st != PermissionStatus.granted) return;
      }
      if (_onizlemeTrack != null || _ayrildi) return;
      final t = await LocalVideoTrack.createCameraTrack(
          _isGroup ? kGroupCameraCaptureOptions : kCameraCaptureOptions);
      // TEST TURU 50: gec kaldiysak (yedek yol devreye girdi) bu track'i ATIYORUZ —
      // aksi halde iOS'ta iki capture oturumu ayni `videoCapturer`i paylasip
      // birbirini oldururdu (kok neden). ⚠️ YAPMA: bu kapiyi kaldirma.
      if (_ayrildi || arama == null || _onizlemeIptal) {
        await t.stop();
        await t.dispose();
        return;
      }
      _onizlemeTrack = t;
      notifyListeners();
    } catch (_) {}
  }

  /// Onizleme track'ini SALIVER (publish edilmediyse kamerayi kapat).
  Future<void> _onizlemeBirak() async {
    final t = _onizlemeTrack;
    _onizlemeTrack = null;
    if (t == null || _onizlemeYayinda) return;
    try {
      await t.stop();
      await t.dispose();
    } catch (_) {}
  }

  /// TEST TURU 50 — VIDEO YAYIN DOGRULAMASI. Goruntulu aramada baglanti kurulduktan
  /// 1.5sn sonra yayinlanmis bir video track YOKSA kamerayi TEK SEFER yeniden acar.
  /// Sunucu logu kanitladi: aramalarin ~%14'unde (hepsi iOS) video track odaya HIC
  /// ulasmiyordu ve kimse fark etmiyordu. Sonuc Sentry'e olcum olarak yazilir.
  /// ⚠️ YAPMA: tekrar sayisini artirma (ac/kapa savasi) veya sureyi kisaltma
  /// (yavas cihazda normal yayin HENUZ bitmemis olabilir -> gereksiz ikinci kamera).
  Timer? _videoDogrulamaTimer;
  void _videoYayinDogrula(String id) {
    _videoDogrulamaTimer?.cancel();
    _videoDogrulamaTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (_ayrildi || arama?.callId != id || !_camOn) return;
      final lp = _room?.localParticipant;
      if (lp == null) return;
      final varMi = lp.videoTrackPublications.isNotEmpty;
      if (varMi) return;
      unawaited(Sentry.captureMessage('video yayin yok — kamera tekrar deneniyor'));
      _sesLog('video track yayinlanmamis, tekrar deneniyor');
      try {
        await _onizlemeBirak(); // ortada asili capture kalmasin
        if (_ayrildi || arama?.callId != id || !_camOn) return;
        await lp.setCameraEnabled(true);
        _sesLog('video tekrar denemesi: ${lp.videoTrackPublications.isNotEmpty}');
      } catch (e) {
        _camOn = false;
        unawaited(Sentry.captureMessage('video tekrar denemesi BASARISIZ: $e'));
        bildirimGoster('Kamera açılamadı');
      }
      notifyListeners();
    });
  }

  /// Kendi kamera track'im (PiP'te uzak video yoksa yedek — kara ekran yerine kendi goruntum).
  VideoTrack? get yerelVideo {
    if (!_camOn) return null;
    final t = _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
    return t is VideoTrack ? t : null;
  }

  VideoTrack? _bantIlkVideo(RemoteParticipant p) {
    for (final pub in p.videoTrackPublications) {
      if (pub.subscribed && !pub.muted && pub.track != null) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  /// GORUNTULU ARAMA MI (canli): baslangic tipi video VEYA taraflardan biri kamerayi acmis.
  /// TEST TURU 14 KOK-1: eski kapi yalniz `_camOn || _uzakVideoVar()` bakiyordu — arka plana
  /// inince kamera OTOMATIK mute edildigi icin (_camOn=false) ve karsi taraf da alta alininca
  /// uzak video mute oldugu icin 1:1'de PiP izni KAPANIYORDU ("toplu aramada geliyor, normal
  /// aramada gelmiyor" semptomunun kok nedeni). Grupta 3+ kisiden biri hep acik oldugu icin
  /// sorun gorunmuyordu. Artik aramanin TIPI belirleyici (WhatsApp davranisi).
  bool get goruntuluMu => (arama?.video ?? false) || _camOn || _uzakVideoVar();

  /// PiP'e girilmesi istenen durum: Android + bagli/saglikli GORUNTULU arama.
  /// TEST TURU 14: `ekranGorunur && !minimized` sarti KALDIRILDI — aramayi kucultup
  /// uygulamada gezinen kullanici HOME'a inince hicbir sey gormuyordu (uygulama-ici yuzen
  /// pencere arka planda gorunmez). PiP icerigi artik AktifAramaBanner'da (MaterialApp.builder)
  /// tam ekran ciziliyor -> hangi sayfada olursak olalim PiP penceresinde KARSI TARAF gorunur.
  bool get _pipIstenir => Platform.isAndroid && minimizeEdilebilir && goruntuluMu;

  void _pipGuncelle() {
    final istenen = _pipIstenir;
    if (istenen == _pipIzinliSon) return; // kanala yalniz DEGISIMDE git
    _pipIzinliSon = istenen;
    PipService.pipIzinli(istenen);
  }

  /// iOS PiP: uzak video track'inin webrtc id'si.
  /// TEST TURU 8: muted DAHIL — karsi taraf kamerayi gecici kapatinca (arka plan kamera-mute
  /// yedegi) PiP SOKULMESIN. Sokup arka planda yeniden kurmak ise yaramaz (auto-enter yalniz
  /// on plandan gecliste tetiklenir) -> pencere "gidiyor, geri gelmiyor"du. Mute'ta pencere
  /// son karede kalir, unmute'ta akis kendiliginden devam eder.
  /// TEST TURU 9 GRUP: grupta AKTIF KONUSANIN videosunu tercih et (baskin konusan PiP'te
  /// gorunur; konusan degisince ActiveSpeakersChangedEvent -> notifyListeners -> PiP otomatik
  /// takip eder). 1:1'de tek uzak katilimci — sira onemsiz.
  String? _uzakVideoTrackId() {
    if (_isGroup) {
      // activeSpeakers audioLevel'a gore azalan sirali (livekit 2.8.1) — first = baskin konusan.
      for (final p in _room?.activeSpeakers ?? const <Participant>[]) {
        if (p is! RemoteParticipant) continue; // yerel kamera PiP'e girmez
        final t = _ilkVideoTrackId(p);
        if (t != null) return t;
      }
    }
    // 1:1 (ve grupta konusan videosuz): ilk uygun uzak video
    for (final p in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      final t = _ilkVideoTrackId(p);
      if (t != null) return t;
    }
    return null;
  }

  /// TEST TURU 28: KENDI kamera track id'm (iOS PiP alt gorunumu). Yayinlanan track yoksa
  /// onizleme track'i kullanilir (arama baglanmadan once de bolunmus pencere calissin).
  String? _yerelVideoTrackId() {
    // TEST TURU 30: MUTE olsa da dondurulur — arka plana gecerken kamera oto-mute oluyor
    // ve kutu tam o anda kayboluyordu (bolunme bozuluyordu). Track nesnesi durdukca kutu kalir.
    for (final p
        in _room?.localParticipant?.videoTrackPublications ?? const []) {
      final t = p.track;
      if (t != null) return t.mediaStreamTrack.id;
    }
    return _onizlemeTrack?.mediaStreamTrack.id;
  }

  String? _ilkVideoTrackId(RemoteParticipant p) {
    for (final pub in p.videoTrackPublications) {
      if (pub.subscribed && pub.track != null) {
        return (pub.track as VideoTrack).mediaStreamTrack.id;
      }
    }
    return null;
  }

  /// iOS SISTEM PiP guncelle (test turu 7): GORUNTULU + bagli + ekran acik + uzak video
  /// varsa native PiP controller'i kur (auto-enter); degilse birak. Track degisince yeniden kur.
  /// Fire-and-forget; guard sayesinde cogu cagri no-op (yalniz trackId degisiminde native).
  /// TEST TURU 9: `!_isGroup` kapisi KALDIRILDI — grupta da PiP (aktif konusanin videosu).
  Future<void> _iosPipGuncelle() async {
    if (!Platform.isIOS || !_iosPipHazir) return;
    // TEST TURU 39 — YENIDEN-GIRME KILIDI: bu metot HER notifyListeners mikro-goreviyle ve
    // sure sayaciyla saniyede bir cagriliyor; icinde `await` var ve `_iosPipKurulanId`
    // ancak await'ten SONRA yaziliyordu. Iki es zamanli akis ayni anda `iosPipKur`
    // cagirabiliyor, ikincisi native `birak()` -> `stopPictureInPicture()` tetikleyip
    // PENCEREYI KAPATIYORDU (turu 24-29'daki "pencere gidiyor" sikayetlerinin yapisal koku).
    // Kilit yuzunden bir tazeleme atlanirsa 1sn sonraki tetikleme telafi eder.
    // ⚠️ YAPMA: kilidi kaldirma.
    if (_iosPipMesgul) return;
    _iosPipMesgul = true;
    try {
      await _iosPipGuncelleGovde();
    } finally {
      _iosPipMesgul = false;
    }
  }

  Future<void> _iosPipGuncelleGovde() async {
    final b = arama;
    // TEST TURU 14: `b.video` yerine CANLI goruntulu kapisi — sesli baslayip kamera acilan
    // aramada da iOS PiP kurulur (eskiden hic kurulmuyordu).
    // TEST TURU 29 — KULLANICININ EN COK TEKRAR EDEN SIKAYETI ("iPhone'da alta alinca
    // kucuk ekran GELMIYOR"): sart `ekranGorunur` iceriyordu. Aramayi UYGULAMA ICINDE
    // kucultunce (geri tusu / mesaj ikonu) CallScreen pop olur -> ekranGorunur=false ->
    // her saniye tetiklenen bu metot `iosPipBirak()` cagirip kurulumu YIKIYORDU; sonra
    // HOME'a basinca native controller NIL oldugu icin pencere HIC acilmiyordu.
    // Android'de bu sart turu 14'te zaten kaldirilmisti — iOS dali geride kalmis.
    // ⚠️ YAPMA: buraya tekrar `ekranGorunur` koyma (kucultulmus aramada PiP olur).
    final uygun = b != null &&
        goruntuluMu &&
        _baglandi &&
        !_cevapsiz &&
        _error == null;
    // PiP KURULUMU ONCE (test turu 10 regresyon fix): auto-enter'in "possible" olabilmesi icin
    // controller ILK gelen kareyle kurulmali; asagidaki agir capture-reconfig'i beklemesin.
    // ================= TEST TURU 40 — TURU 36 GERI ALINDI (KOK DUZELTME) =================
    // Kullanici: "daha once CALISIYORDU, sonra boyle oldu, anlamiyorum."
    // GIT KANITI: `yerelId ?? uzakId` (kucuk pencerede KENDI kameram) YALNIZ 0bb2660 (turu 36)
    // ile girdi; oncesinde `uzakId ?? yerelId` (KARSI TARAF) idi ve CALISIYORDU — kullanici
    // turu 32'de "karsinin goruntusu var, guzelce cizmis" demisti. "Donuyor" sikayetleri
    // turu 36'dan SONRA basladi.
    //
    // FIZIKSEL SEBEP: iPhone uygulama arka plana gecince KENDI kamerani DURDURUR (Apple).
    // Karsi tarafin videosu ise AGDAN gelir, arka planda AKMAYA DEVAM EDER. Yani kucuk
    // pencerede kendi kamerani gostermek = arka planda gosterilecek goruntu OLMAMASI =
    // son karede donma. WhatsApp/Instagram da kucuk pencerede KARSI TARAFI gosterir; sebep
    // tam olarak budur.
    //
    // Bu yuzden kaynak sirasi KARSI TARAF -> (yoksa) kendi kameram olarak GERI ALINDI.
    // ⚠️ YAPMA: sirayi tekrar yerele cevirme — iPhone'da arka planda kendi kameran DURUR ve
    // pencere DONAR. (Kullanici isterse bile once bu fiziksel sinir anlatilmali.)
    final uzakId = uygun ? _uzakVideoTrackId() : null;
    // `_yerelVideoTrackId` MUTE track'i de dondurur — bu KASITLI: arka plana gecince kamera
    // oto-mute oluyor; id degismedigi surece pencere kimligi SABIT kalir.
    final yerelId = uygun ? _yerelVideoTrackId() : null;
    // KIMLIK CALKANTISI KORUMASI (turu 24 dersi): kurulmus kimlik HALA gecerli bir track'e
    // isaret ediyorsa DEGISTIRME. Aksi halde kaynak her degistiginde `kur()` -> `birak()` ->
    // stopPictureInPicture calisir ve PENCERE KAPANIR.
    final aday = uzakId ?? yerelId; // turu 40: KARSI TARAF once (calisan davranis)
    final trackId = (_iosPipKurulanId.isNotEmpty &&
            (_iosPipKurulanId == yerelId || _iosPipKurulanId == uzakId))
        ? _iosPipKurulanId
        : aday;
    if (trackId != null) {
      // TEST TURU 24 (kullanici: "iPhone kucuk pencerede UST-ALT olmali"): kendi kameram
      // da PiP'e verilir -> uzak USTTE, ben ALTTA.
      // TEST TURU 26 GERI ALMA (kullanici hakli): iOS PiP'i IKIYE BOLMEK (uzak+yerel)
      // pencereyi BOZDU. Sebep: kurulum kimligi "uzak|yerel" idi; arka planda kamera
      // mute olunca yerel id BOSALIYOR -> kimlik degisiyor -> PiP kurulumu YIKILIP
      // yeniden kuruluyordu (birak() stopPictureInPicture cagirir) -> pencere HIC acilmadi.
      // Artik iOS PiP YALNIZ UZAK VIDEO (calisan eski davranis); kimlik SADECE uzak track.
      if (trackId != _iosPipKurulanId) {
        // turu 39: native tarafa hangi kaynak oldugunu bildir (kare gozcusu raporlar)
        final ok = await PipService.iosPipKur(trackId,
            kaynak: trackId == uzakId ? 'uzak' : 'yerel');
        _iosPipKurulanId = ok ? trackId : '';
        _iosPipYerelId = ''; // yeni kurulumda alt gorunum sifirlanir
      }
      // TEST TURU 44 — "IKI KUTUDA DA BENI GOSTERIYOR" (kullanici testi).
      // KOK NEDEN: PiP, karsi tarafin videosu HENUZ abone olunmadan kurulabiliyor; o an
      // `uzakId` null oldugu icin `aday` YEREL'e dusuyor ve turu 36'daki kimlik-calkanti
      // korumasi onu SONSUZA KADAR kilitliyordu -> buyuk kutu da ben, kose kutusu da ben.
      // COZUM: uzak video sonradan gelirse pencereyi KAPATMADAN sicak gecis
      // (`kaynakDegistir` yalniz sink tasir; `stopPictureInPicture` CAGRILMAZ).
      // ⚠️ YAPMA: bunu `iosPipKur` ile yapma — pencere kapanir (turu 24/26 dersi).
      if (_iosPipKurulanId.isNotEmpty &&
          uzakId != null &&
          uzakId.isNotEmpty &&
          _iosPipKurulanId != uzakId) {
        final gecti = await PipService.iosPipKaynak(uzakId, 'uzak');
        if (gecti) {
          _iosPipKurulanId = uzakId;
          _sesLog('ios pip kaynak yerel -> uzak (sicak gecis)');
        }
      }
      // KOSE KUTUSU (turu 41-42, WhatsApp gorunumu): karsi taraf TAM pencere, BEN sag-altta
      // kucuk kutu. `pipBolunme` ACIK (true) — asagidaki eski "KAPATILDI" yorumu 30 Tem
      // denetiminde YANLIS bulundu ve kaldirildi (kod turu 42'den beri bolunmeyi ciziyor).
      // Native `yerelAyarla` YALNIZ `callVC.view` uzerine alt gorunum ekler; `pipController`a
      // DOKUNMAZ -> bu yol pencereyi KAPATMAZ (turu 27-31 tasarimi).
      // ⚠️ YAPMA: kose kutusunu `iosPipKur` ile kurmaya calisma (pencere kapanir — turu 24/26).
      if (pipBolunme && _iosPipKurulanId.isNotEmpty) {
        final yid = (uzakId != null ? yerelId : null) ?? '';
        if (yid != _iosPipYerelId) {
          _iosPipYerelId = yid;
          // Kamera kare uretmezse kutuda donmus kare yerine bu yazi gorunur.
          final sonuc =
              await PipService.iosPipYerel(yid.isEmpty ? null : yid, harf: 'Sen');
          if (yid.isNotEmpty && sonuc != 'eklendi' && sonuc != 'ayni') {
            _iosPipYerelId = ''; // basarisiz -> sonraki tazelemede TEKRAR denensin
            unawaited(Sentry.captureMessage('ios pip alt gorunum sonuc=$sonuc'));
          }
        }
      } else if (_iosPipYerelId.isNotEmpty) {
        // Bolunme kapatildi ama onceden eklenmis alt kutu varsa KALDIR (tek videoya don).
        _iosPipYerelId = '';
        await PipService.iosPipYerel(null);
      }
    } else if (_iosPipKurulanId.isNotEmpty) {
      _iosPipKurulanId = '';
      _iosPipYerelId = '';
      await PipService.iosPipBirak();
    }
    // COKLU-GOREV KAMERA (test turu 9->10): PiP kurulumundan SONRA + BLOKLAMAYAN (fire-and-forget).
    // Eskiden iosPipKur'dan ONCE await ediliyordu -> agir beginConfiguration/commitConfiguration
    // PiP kurulumunu geciktirip auto-enter'i kaciriyordu (test turu 9 regresyonu). Artik kurulumu
    // bloklamaz; yerel kamera acikken BIR KEZ dener (native idempotent; desteksizse false).
    if (uygun && _camOn && !_iosArkaPlanKamera && !_iosCokluGorevDeniyor) {
      unawaited(iosArkaPlanKamerayiTazele());
    }
  }

  /// TEST TURU 31 — ARKA PLANDA KAMERA BAYRAGINI TAZELE (kullanici tespiti: "WhatsApp'ta
  /// alta alinca kamera DURMUYOR; yalniz KILIT veya uygulamayi OLDURUNCE 'Kamera
  /// duraklatildi' diyor").
  ///
  /// KOK NEDEN: `isMultitaskingCameraAccessEnabled` AVCaptureSession NESNESINE yazilir.
  /// livekit varsayilani `stopCameraCaptureOnMute = true` oldugundan kamerayi her
  /// kapat/ac (ve arka plandan donuste oto-unmute) YENI bir capture session yaratir ->
  /// bayrak SIFIRLANIR. Bizim `_iosArkaPlanKamera` ise true takili kaliyordu: ne bayrak
  /// yeniden yaziliyor ne de durustce mute ediliyordu -> karsi taraf DONMUS KARE goruyordu.
  /// Cozum: bayragi kamera her (yeniden) acildiginda ve arka plana GECMEDEN HEMEN ONCE
  /// yeniden uygula, sonucu her seferinde guncelle.
  /// ⚠️ YAPMA: bu tazelemeyi tek seferlik (yalniz baglantida) yapma.
  Future<void> iosArkaPlanKamerayiTazele() async {
    if (!Platform.isIOS || _iosCokluGorevDeniyor) return;
    _iosCokluGorevDeniyor = true;
    try {
      final ok = await PipService.iosCokluGorevKamera();
      _iosArkaPlanKamera = ok;
    } catch (_) {
      _iosArkaPlanKamera = false;
    } finally {
      _iosCokluGorevDeniyor = false;
    }
  }

  /// TEST TURU 37 — iOS KAMERA KESINTISI (OS'un KENDI bildirimi, bayrak tahmini DEGIL).
  ///
  /// Arka planda capture GERCEKTEN durdurulduysa iOS `AVCaptureSessionWasInterrupted`
  /// gonderir. Bugune kadar bunu dinlemiyorduk; `isMultitaskingCameraAccessEnabled` geri
  /// okumada `true` dondugu icin (Apple yazmayi kabul ediyor ama gec yazildiginda FIILEN
  /// etkisiz) kamerayi canli saniyor, durustce mute ETMIYORDUK -> karsi taraf DONMUS KARE
  /// goruyordu. Artik gercek olaya tepki veriyoruz.
  /// ⚠️ YAPMA: burada kamerayi kapatmayi atlama (donmus kare geri gelir).
  /// TEST TURU 39 — PENCEREYE KARE AKMIYOR (native gozcu 1.5sn boyunca yeni kare gormedi).
  ///
  /// Kullanici UC turdur "alta alinca donuyor" diyor. Olcum (Sentry): "3sn kare=0" —
  /// yani kendi kameramin karesi arka planda AKMIYOR. Buna karsilik KARSI TARAFIN videosu
  /// akmaya devam ediyor (32. turda kullanici "karsinin goruntusu var, benimki yok" demisti).
  ///
  /// Cozum: pencereyi KAPATMADAN karsi tarafin videosuna gec (`iosPipKaynak` yalniz sink
  /// tasir; `stopPictureInPicture` cagrilmaz -> pencere kapanmaz). Karsi taraf yoksa
  /// (sesli arama) pencere zaten "Kamera duraklatildi" etiketini gosterir.
  /// Ayrica kamerayi DURUSTCE kapat: bu artik TAHMIN degil OLCUM — karsi taraf donmus kare
  /// yerine bulanik "Kamera duraklatildi" gorur.
  /// ⚠️ YAPMA: burada `iosPipKur`/`iosPipBirak` cagirma (pencere kapanir — turu 24 dersi).
  void _iosPipKareDurdu(String kaynak) {
    if (!Platform.isIOS || arama == null || _ayrildi) return;
    if (kaynak != 'yerel') return; // uzak video da durduysa yapacak bir sey yok
    final uzak = _uzakVideoTrackId();
    if (uzak != null && uzak.isNotEmpty) {
      unawaited(PipService.iosPipKaynak(uzak, 'uzak').then((ok) {
        if (ok) _iosPipKurulanId = uzak; // kimlik kapisi yeni kaynagi korusun
      }));
    }
    // Kamera GERCEKTEN kare uretmiyor -> durustce kapat (olcume dayali, tahmin degil).
    if (_camOn && _baglandi) {
      _kameraOtoKapandi = true; // on plana donunce geri acilir
      _camOn = false;
      _room?.localParticipant?.setCameraEnabled(false);
      notifyListeners();
    }
  }

  void _iosKameraKesinti(bool kesintiVar) {
    if (!Platform.isIOS || arama == null || _ayrildi) return;
    if (!kesintiVar) return;
    _iosArkaPlanKamera = false; // bayrak yalan soyluyordu — gercek OS olayina guven
    // TEST TURU 43 — KAMERAYI HEMEN OLDURME. Apple: *"If you don't explicitly call the
    // stopRunning() method, your startRunning() request is preserved."* livekit mute
    // (`stopCameraCaptureOnMute = true`) capture'i DURDURUR ve kurtarma sansini yok eder.
    // Native taraf ~0.7sn icinde `startRunning()` ile kurtarmayi deniyor; ona sans veriyoruz.
    // Kurtarma olmazsa 1.5sn sonra DURUSTCE mute (karsi taraf bulanik yazi gorur).
    // ⚠️ YAPMA: bu gecikmeyi kaldirip aninda mute'a donme.
    _kesintiMuteGecikme?.cancel();
    _kesintiMuteGecikme = Timer(const Duration(milliseconds: 1500), () {
      if (arama == null || _ayrildi || !_camOn || !_baglandi) return;
      if (PipService.kurtarmaSonucu == true) {
        _sesLog('kamera kesintiden KURTARILDI — mute atlandi');
        return;
      }
      _kameraOtoKapandi = true; // on plana donunce geri acilsin
      _camOn = false;
      _room?.localParticipant?.setCameraEnabled(false);
      // turu 48: YALNIZ kose kutusu bosalir — buyuk kutuda karsi taraf akmaya devam ediyor
      unawaited(PipService.iosPipKareBosalt(yalnizYerel: true));
      notifyListeners();
    });
  }

  /// iOS PiP baslatilamadi (native delegate failedToStart): kullanici Ayarlar'dan PiP'i
  /// kapatmis olabilir -> arka planda kamera CAPTURE'i OS'ca durur, karsi taraf DONUK KARE
  /// gorur. Kamerayi kapat -> avatar yedegi (donuk kareden iyi). Donuste resume geri acar.
  void _iosPipBasarisiz() {
    if (Platform.isIOS && arama != null && _baglandi && !_ayrildi && _camOn && !pipModunda) {
      _kameraOtoKapandi = true;
      _camOn = false;
      _room?.localParticipant?.setCameraEnabled(false);
      notifyListeners();
    }
  }

  /// Ekran acilis/kapanisinda PiP iznini tazele (CallScreen initState cagirir).
  void pipDurumTazele() {
    _pipGuncelle();
    unawaited(_iosPipGuncelle());
  }

  // TEST TURU 27 — AKICILIK (kullanici: "acilirken patlıyor, yavas"): baglanma aninda
  // 5-10 olay (katilimci, track, kalite, ses kaniti, sure) PES PESE geliyor ve her biri
  // AYRI yeniden cizim tetikliyordu. Artik ayni mikro-gorevde gelen bildirimler TEK
  // karede birlestirilir (6 olay = 1 cizim). Davranis aynidir, yalniz cizim sayisi duser.
  bool _hazirlik = false; // turu 30: ekran acildi ama baslat henuz gelmedi
  bool _bildirimBekliyor = false;

  @override
  void notifyListeners() {
    if (_bildirimBekliyor) return;
    _bildirimBekliyor = true;
    scheduleMicrotask(() {
      _bildirimBekliyor = false;
      super.notifyListeners();
      _pipGuncelle(); // PiP izni senkron kalir (yalniz delta'da kanal)
      unawaited(_iosPipGuncelle()); // iOS PiP kurulum/birakma (yalniz trackId delta'sinda)
    });
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
  /// [micAcik]/[kameraAcik]: GRUP DAVET EKRANINDA (test turu 21) kullanici onceden secmis
  /// olabilir (WhatsApp gibi kamera/mikrofon kapali katilma). Verilmezse eski davranis.
  Future<void> baslat(AramaBilgisi b,
      {bool? micAcik, bool? kameraAcik, LocalVideoTrack? hazirKamera}) async {
    // Tum tek-seferlik bayraklar RESET (teardown'i etkilemez — KARAR 4: bekleyen
    // teardown'lar enqueue aninda yakalanmis nesnelerle calisir).
    _iptalAbonelikler();
    _hazirlik = false; // turu 30: gorunum hazirligi bitti, gercek arama basliyor
    arama = b;
    minimized = false;
    // TEST TURU 18: beklet bayraklari YENI aramaya SARKMASIN (parkEdilen KASTEN korunur —
    // ikinci aramayi kabul ederken birincisi park edilmis olabilir).
    beklemede = false;
    karsiBeklemede = false;
    // TEST TURU 32 — ZOMBI KAMERA SIZINTISI: burada alan sadece null'laniyordu; yayinlanmamis
    // onizleme track'i (ornek: "Geri Ara" yolu, cevapsiz sonrasi) NATIVE kamerayi acik
    // birakiyordu -> sonraki aramada kamera mesgul olabiliyordu. Once SAL, sonra sifirla.
    // (`_onizlemeBirak` yayinlanmis track'e DOKUNMAZ; hazirKamera devri asagida yapilir.)
    unawaited(_onizlemeBirak());
    _onizlemeTrack = null;
    _onizlemeYayinda = false;
    _onizlemeIsi = null;
    _onizlemeIptal = false; // turu 50: eski aramanin iptal bayragi SARKMASIN
    _videoDogrulamaTimer?.cancel();
    bildirim = '';
    _bildirimTimer?.cancel();
    karsiPil = -1;
    _benimPil = -1;
    karsiKalite = ConnectionQuality.unknown;
    yenidenBaglaniyor = false;
    pipModunda = false; // FAZ-6 (yargic): eski aramadan bayrak sarkmasin
    _kameraOtoKapandi = false;
    _iosPipKurulanId = ''; // iOS PiP (test turu 7): eski aramadan kurulum sarkmasin
    _iosPipYerelId = '';
    _iosArkaPlanKamera = false; // iOS coklu-gorev kamera (test turu 9): eski aramadan sarkmasin
    _iosCokluGorevDeniyor = false;
    _isGroup = b.isGroup;
    _connecting = true;
    _kapandi = false;
    _baglandi = false;
    _ayrildi = false;
    _peerJoined = false;
    _mediaBasladi = false;
    _odaBagli = false; // senkron sayac (test turu 6)
    _micOn = micAcik ?? true;
    _camOn = kameraAcik ?? b.video;
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
    // TEST TURU 22 (kullanici: "goruntulu arama atinca kameram DIREK gelmiyor"): kamerayi
    // odaya BAGLANMADAN ONCE ac ve ekranda goster; baglanti kurulunca AYNI track publish
    // edilir (canli yayin P1 deseni) — ikinci kez kamera acilmaz, yaris olmaz.
    // TEST TURU 28: gelen-arama ekraninda ZATEN acilmis kamera varsa DEVRAL (kapat-ac
    // yok -> siyah sicrama yok). Yoksa eskisi gibi kendimiz aciyoruz.
    if (_camOn && hazirKamera != null) {
      _onizlemeTrack = hazirKamera;
      notifyListeners();
    } else if (_camOn) {
      _onizlemeIsi = _onizlemeAc();
    } else if (hazirKamera != null) {
      unawaited(hazirKamera.stop().then((_) => hazirKamera.dispose()));
    }
    // TEST TURU 20: GSM arama dinleyicisini AC (arama boyunca). Izin yoksa no-op.
    unawaited(PipService.gsmDinle(true));
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
    // TEST TURU 9: iOS coklu-gorev kamera ACIKSA arka planda kamerayi KAPATMA — kamera CAPTURE'a
    // devam eder, PiP karsi tarafa CANLI gonderir ("alta alinca karsi beni goremiyor" fix'i).
    // PiP baslatilamazsa native pipBasarisiz -> _iosPipBasarisiz zaten kamerayi kapatir.
    // TEST TURU 20 (kullanici: "iPhone'da alta alinca kucuk pencere gelmiyor"): uygulama
    // arka plana GECERKEN PiP'i ELLE baslat — otomatik giris telefon Ayarina/Dusuk Guc
    // Modu'na bagliydi, elle baslatma bagimsiz calisir. 'inactive' iOS'ta gecis anidir
    // (uygulama HALA on planda sayilir; Apple startPictureInPicture'a burada izin verir).
    // TEST TURU 46 — TEK TETIK + YON KONTROLU (kullanici: "alta alirken zorlaniyorum").
    // ESKIDEN: `inactive || paused || hidden` UCU DE ayni native `baslat()`e iniyordu.
    // Flutter iOS'ta tek bir alta almada UCUNU birden gonderir (hidden, paused'dan once
    // SENTEZLENIR) -> tek harekette 3 method channel + 3 startPictureInPicture istegi;
    // ustune SceneDelegate (kaldirildi) ve iOS'un kendi auto-enter'i. Sistemin kuculme
    // animasyonuyla yarisan bu istekler surtunme uretiyordu.
    // AYRICA DONUS yolu da `paused -> hidden -> inactive -> resumed` seklindedir; eski
    // kosul ON PLANA DONERKEN de baslatma istiyor, hemen ardindan `resumed` dalindaki
    // kosulsuz `iosPipDurdur()` onu kapatiyordu = ikinci bir ac-kapa yankisi.
    // ARTIK: yalniz `inactive` VE yalniz `resumed`dan geliyorsak (gercekten arka plana
    // gidiyorsak). Native tarafta ayrica tek-istek kilidi var (`baslatIstendi`).
    // TEST TURU 48 — TEK TETIK YETMIYOR, "TEKRAR DENEME" PENCERESI EKLENDI.
    // OLCUM: turu 44'te (uc tetik vardi) `oturum=true`; turu 46'da tek tetige indirince
    // `oturum=false` — yani kamera arka planda oluyor. Sebep zamanlama: native `baslat()`
    // `isPictureInPicturePossible == false` iken ERKEN DONER (ilk kare daha enqueue
    // edilmemis olabilir) ve tur 46'da BASKA TETIK KALMADIGI icin PiP ancak iOS'un kendi
    // (gec) auto-enter'iyle acilabiliyor; Apple kamerayi YALNIZ PiP AKTIFKEN surdurdugu
    // icin arada kamera kesiliyor.
    // Turu 46'daki takilma duzeltmesi ASIL OLARAK native tek-istek kilidiydi (`cagri` 5->1,
    // `msMax=0`) — o kilit DURUYOR, dolayisiyla tekrar deneme ARTIK BEDAVA: ilk istek
    // tutmussa sonrakiler gercek bir `startPictureInPicture()` cagirmaz.
    // Tekrarlar YALNIZ arka plana gidis anindan sonraki 1200ms icinde yapilir -> ON PLANA
    // DONUS yolundaki (`paused -> hidden -> inactive -> resumed`) olaylar tetiklemez.
    // ⚠️ YAPMA: tekrar penceresini zaman siniri olmadan acma (donuste PiP yankisi olur);
    // native tek-istek kilidini kaldirma (takilma geri gelir).
    final onceki = _sonYasamDurumu ?? AppLifecycleState.resumed;
    _sonYasamDurumu = state;
    final arkaPlanaGidiyor =
        state == AppLifecycleState.inactive && onceki == AppLifecycleState.resumed;
    if (arkaPlanaGidiyor) _arkaPlanaGidisAni = DateTime.now();
    if (state == AppLifecycleState.resumed) _arkaPlanaGidisAni = null;
    final gidis = _arkaPlanaGidisAni;
    final tekrarPenceresi = gidis != null &&
        DateTime.now().difference(gidis) < const Duration(milliseconds: 1200) &&
        (state == AppLifecycleState.hidden || state == AppLifecycleState.paused);
    if (Platform.isIOS &&
        (arkaPlanaGidiyor || tekrarPenceresi) &&
        arama != null &&
        _baglandi &&
        !_ayrildi &&
        !pipModunda &&
        _iosPipKurulanId.isNotEmpty) {
      unawaited(PipService.iosPipBaslat());
    }
    // TEST TURU 47 — TAZELEME GERI GELDI (turu 45'te kaldirmistim, YANLIS KARARDI).
    // OLCUM: turu 44 (tazeleme VAR) -> `oturum=true`; turu 45 (tazeleme YOK) ->
    // `oturum=false` ve kullanicinin kose kutusu yine dondu. Yani bu adim YUK TASIYORDU.
    // Turu 45'teki takilmanin sebebi tazelemenin KENDISI degil, ANA IS PARCACIGINDA
    // yapilmasiydi; native taraf artik yazmayi ARKA PLAN KUYRUGUNDA yapiyor -> arayuz
    // bloklanmaz (bu surumde `cagri=1 msMax=0` olcumu takilmanin cozuldugunu gosteriyor).
    // ⚠️ YAPMA: bu cagriyi tekrar kaldirma (arka planda kamera oluyor, kose kutusu donuyor).
    if (Platform.isIOS &&
        state == AppLifecycleState.inactive &&
        arama != null &&
        _baglandi &&
        !_ayrildi &&
        _camOn) {
      unawaited(iosArkaPlanKamerayiTazele());
    }
    // TEST TURU 35 — "KARSI TARAFTA GORUNTUM GIDIYOR" icin TEK SATIRLIK GUVENLI ADIM:
    // 'inactive' aninda `iosArkaPlanKamerayiTazele()` baslatiliyor ve sonucu ASENKRON
    // yaziliyor; 'paused' milisaniyeler sonra gelip BAYAT `_iosArkaPlanKamera` degerini
    // okuyabiliyor. Bayat deger true ise durust kamera-mute HIC calismaz; tazeleme sonucu
    // false cikarsa karsi taraf DONMUS KARE gorur. Sonuc belli degilken (tazeleme ucarken)
    // kamerayi CANLI SAYMIYORUZ -> en kotu ihtimalle bulanik "Kamera duraklatildi" gorunur,
    // donmus kare degil. ⚠️ YAPMA: 900ms'lik erteleme dalini kaldirma (orada bayrak
    // tazelenmis haliyle yeniden okunur, destekli cihazda kayip yok).
    final iosKameraCanli =
        Platform.isIOS && _iosArkaPlanKamera && !_iosCokluGorevDeniyor;
    // TEST TURU 14 KOK-4: Android'de PiP'e girerken lifecycle 'paused' native pipDegisti(true)'dan
    // ONCE gelebiliyor -> pipModunda henuz false -> kamerayi kapatiyorduk ve PiP penceresinde
    // karsi taraf beni GOREMIYORDU. PiP izni verilmisse (goruntulu + bagli) kamerayi kapatmayi
    // 900ms ERTELE; PiP gercekten basladiysa (pipModunda) hic kapatma.
    // TEST TURU 24 (kullanici: "iPhone'da alta alinca karsi taraftan GORUNTUM GIDIYOR"):
    // iOS'ta da kamera-mute ERTELENIR — PiP baslamadan mute edersek karsi taraf beni
    // kaybediyordu. PiP basladiysa (pipModunda) veya coklu-gorev kamera aciksa HIC mute
    // edilmez (iOS16+ isMultitaskingCameraAccessEnabled ile capture arka planda surer).
    final pipBekleniyor = (Platform.isAndroid && _pipIzinliSon) ||
        (Platform.isIOS && _iosPipKurulanId.isNotEmpty);
    // ================= TEST TURU 38 — DONMANIN GERCEK SEBEBI =================
    // KANIT (Sentry, 26 Tem 22:03): "ios coklu-gorev kamera destek=true" 70 kayit VAR ama
    // "ios kamera kesinti sebep=..." kaydi HIC YOK. Yani iOS kamerayi KESMIYOR — kamerayi
    // durduran BIZIM KENDI mute yolumuz. livekit `stopCameraCaptureOnMute=true` oldugu icin
    // mute CAPTURE'I DURDURUR; bu "nazik" durdurma OS kesinti bildirimi URETMEZ, o yuzden
    // ne biz haberdar oluyorduk ne de "Kamera duraklatildi" etiketi cikiyordu -> kucuk
    // pencere SON KAREDE DONUYORDU (kullanici: "halen donuyor").
    //
    // Ustelik turu 36'dan beri kucuk pencere KENDI kamerami gosteriyor: kendi kamerami
    // kapatip kendi goruntumu beklemek MANTIKSAL CELISKI.
    //
    // KURAL: iOS'ta PiP KURULUYSA kamerayi ASLA kendiliğinden kapatma. Kamera gercekten
    // durdurulursa bunu artik OS SOYLUYOR (AVCaptureSessionWasInterrupted ->
    // `_iosKameraKesinti`) ve orada DURUSTCE mute ediyoruz. Yani yedek kayboldu degil,
    // TAHMIN yerine GERCEK OLAYA baglandi.
    // ⚠️ YAPMA: bu kapiyi kaldirip iOS'ta zamanlayiciyla mute etmeye donme.
    final iosPipKendiKameram = Platform.isIOS && _iosPipKurulanId.isNotEmpty;
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.hidden) &&
        arama != null &&
        _baglandi &&
        !_ayrildi &&
        !pipModunda &&
        !iosKameraCanli &&
        !iosPipKendiKameram &&
        _camOn) {
      if (pipBekleniyor) {
        _pipKameraGecikme?.cancel();
    _kesintiMuteGecikme?.cancel();
        _pipKameraGecikme = Timer(const Duration(milliseconds: 900), () {
          if (arama == null || _ayrildi || !_camOn) return;
          // PiP BASLADIYSA: Android'de kamera capture SURER; iOS'ta yalniz coklu-gorev
          // kamera destegi varsa surer. Destek yoksa OS capture'i zaten durdurur ->
          // DURUSTCE mute et ki karsi taraf donmus kare degil bulanik "Beklemede" gorsun.
          if (pipModunda && (Platform.isAndroid || _iosArkaPlanKamera)) return;
          _kameraOtoKapandi = true;
          _camOn = false;
          _room?.localParticipant?.setCameraEnabled(false);
          unawaited(PipService.iosPipKareBosalt()); // turu 38: donmus kare gosterme
          notifyListeners();
        });
        return;
      }
      _kameraOtoKapandi = true;
      _camOn = false;
      _room?.localParticipant?.setCameraEnabled(false);
      notifyListeners();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _pipKameraGecikme?.cancel();
      // TEST TURU 25 -> 29: uygulama ON PLANDA -> iOS PiP penceresi ASILI KALMASIN.
      // KOSULSUZ cagriliyor: `pipModunda` bayragi native didStart callback'iyle gelir ve
      // bu callback PiP ACILIS ANIMASYONUNDAN SONRA dustugu icin 'inactive -> resumed'
      // arasinda HENUZ FALSE olabiliyor; eski `if (pipModunda)` kapisi bu yarista
      // durdurmayi tamamen atliyordu (kullanici: "PiP kucuk ekranin uzerinde cikiyor").
      // ⚠️ YAPMA: buraya tekrar pipModunda sarti koyma.
      if (Platform.isIOS) {
        if (pipModunda) pipModunda = false;
        unawaited(PipService.iosPipDurdur());
        // TEST TURU 39: arka planda uretilen olcum burada gonderilir (arka planda Sentry
        // teslimi garantili degil — bugune kadarki olcumun zayif noktasi buydu).
        final ki = PipService.kesintiBilgi;
        if (ki != null) {
          PipService.kesintiBilgi = null;
          unawaited(Sentry.captureMessage(
              'ios kesinti sebep=${ki['sebep']} durum=${ki['durum']} pip=${ki['pip']} '
              'sinif=${ki['sinif']} calisiyor=${ki['calisiyor']} acik=${ki['acik']} '
              'kurtarma=${PipService.kurtarmaSonucu}'));
        }
        final o = _bekleyenOlcum;
        if (o != null) {
          _bekleyenOlcum = null;
          // turu 48: KOSE kutusu (yerel) ayri sayilir + 1sn/3sn ayrimi + uygulama durumu
          unawaited(Sentry.captureMessage(
              'ios pip olcum on=${o['on']} arka1=${o['arka1']} arka3=${o['arka']} '
              'yerelOn=${o['yerelOn']} yerel1=${o['yerel1']} yerel3=${o['yerel3']} '
              'kaynak=${o['kaynak']} oturum=${o['oturum']} coklu=${o['coklu']} '
              'cagri=${o['cagri']} msMax=${o['msMax']} '
              'durum=${o['durum']} pipAktif=${o['pipAktif']}'));
        }
        notifyListeners();
      }
    }
    if (state == AppLifecycleState.resumed && arama != null && !_ayrildi && !_cevapsiz) {
      // Kamera restore _kesintidenTopla'dan ONCE (iOS ses sirasi: _sesiAc EN SON kalmali)
      if (_kameraOtoKapandi && _baglandi) {
        _kameraOtoKapandi = false;
        _camOn = true;
        _room?.localParticipant?.setCameraEnabled(true);
        // TEST TURU 31: yeniden acilan kamera = YENI capture session -> coklu-gorev
        // bayragini tazele (yoksa ikinci kez alta alinca karsi taraf donmus kare gorur).
        if (Platform.isIOS) unawaited(iosArkaPlanKamerayiTazele());
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
      // TEST TURU 32 — ANDROID ONDEPLAN SERVISI (kullanici: "alta alinca/kilitleyince 5-10sn
      // sonra gorusme bitiyor"). Android 14+ arka plandaki sureci 10sn sonra DONDURUR; servis
      // olmadan WebRTC durur ve LiveKit katilimciyi duser. BURADA baslatilir cunku (a) mikrofon
      // izni artik KESIN verilmis, (b) ekran GORUNUR (while-in-use izinli ondeplan servisi
      // ancak gorunur aktiviteyle baslatilabilir). Basarisiz olursa sessizce vazgecilir.
      // ⚠️ YAPMA: servisi izin alinmadan / arka plandayken baslatmayi deneme.
      unawaited(PipService.aramaServisi(true, video: goruntuluMu));
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
        // TEST TURU 28 — GORUNTU 2-3sn GEC GELIYOR (kullanici: "instagram'da ANINDA").
        // KOK NEDEN: adaptiveStream, karsi tarafin videosunu renderer GORUNUR oldugunu
        // BILDIRENE kadar duraklatir; dynacast ise abone yokken yayin katmanini kapatir.
        // 1:1 aramada ikisi de bir tur ekstra sinyal turu = ilk karede ~1-2sn gecikme,
        // kazanci ise sifira yakin (zaten tek abone, tek katman). Bu yuzden 1:1'de
        // KAPALI, GRUPTA acik (8 kisilik izgarada gercekten bant kazandirir).
        // ⚠️ YAPMA: grupta kapatma (8 video x tam katman = cx33 SFU + telefon isinir).
        adaptiveStream: _isGroup,
        dynacast: _isGroup,
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
        ..on<ParticipantConnectedEvent>((e) {
          if (arama?.callId != id) return;
          if (_isGroup && e.participant.name.isNotEmpty) {
            bildirimGoster('${e.participant.name} katıldı.');
          }
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
        ..on<ParticipantDisconnectedEvent>((e) {
          if (arama?.callId != id) return;
          if (_isGroup && e.participant.name.isNotEmpty) {
            bildirimGoster('${e.participant.name} ayrıldı.');
          }
          if (_isGroup) {
            // GRUP: biri ayrilinca arama SURER — otomatik leave YOK (backend yonetir).
            notifyListeners();
            return;
          }
          leave(notifyServer: true); // 1:1: karsi taraf ayrildi
        })
        ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
          if (arama?.callId != id) return;
          if (e.participant is LocalParticipant) {
            _quality = e.connectionQuality;
          } else {
            // TEST TURU 21: KARSI TARAFIN kalitesi -> "X bağlantısı zayıf" uyarisi
            karsiKalite = e.connectionQuality;
          }
          notifyListeners();
        })
        // TEST TURU 21: karsi tarafin PIL seviyesi (veri kanali {"t":"batt","v":n})
        ..on<DataReceivedEvent>((e) {
          if (arama?.callId != id) return;
          try {
            final m = jsonDecode(utf8.decode(e.data));
            if (m is Map && m['t'] == 'batt') {
              final v = (m['v'] as num?)?.toInt() ?? -1;
              if (v != karsiPil) {
                karsiPil = v;
                notifyListeners();
              }
            }
          } catch (_) {}
        })
        ..on<RoomReconnectingEvent>((_) {
          if (arama?.callId != id) return;
          yenidenBaglaniyor = true;
          notifyListeners();
        })
        ..on<RoomReconnectedEvent>((_) {
          if (arama?.callId != id) return;
          yenidenBaglaniyor = false;
          notifyListeners();
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
        // TEST TURU 24: "X sessize alındı / sesi açtı / kamerasını kapattı" bildirimi
        ..on<TrackMutedEvent>((e) {
          if (arama?.callId != id) return;
          if (e.participant is RemoteParticipant) {
            final ad = e.participant.name.isNotEmpty
                ? e.participant.name
                : (arama?.peerName ?? 'Katılımcı');
            bildirimGoster(e.publication.kind == TrackType.AUDIO
                ? '$ad sessize alındı.'
                : '$ad kamerasını kapattı.');
          }
          notifyListeners();
        })
        ..on<TrackUnmutedEvent>((e) {
          if (arama?.callId != id) return;
          if (e.participant is RemoteParticipant) {
            final ad = e.participant.name.isNotEmpty
                ? e.participant.name
                : (arama?.peerName ?? 'Katılımcı');
            bildirimGoster(e.publication.kind == TrackType.AUDIO
                ? '$ad sesini açtı.'
                : '$ad kamerasını açtı.');
          }
          notifyListeners();
        })
        ..on<ActiveSpeakersChangedEvent>((_) {
          if (arama?.callId == id && _isGroup) notifyListeners();
        })
        ..on<RoomDisconnectedEvent>((e) {
          // TEST TURU 32 — OLCUM (davranis AYNI): aramanin neden koptugunu KAYDA GECIR.
          // Sebep ayrimi kritik: SIGNAL_CLOSE/CONNECTION_TIMEOUT = ag/askiya alma (uygulama
          // donduruldu), ROOM_DELETED/PARTICIPANT_REMOVED = SUNUCU kapatti (webhook),
          // DUPLICATE_IDENTITY = ikinci baglanti. Kullanicinin "alta alinca 5-10sn sonra
          // bitiyor" sikayetinin hangi dala dustugunu ancak bu ayrim soyler.
          if (arama?.callId == id) {
            _sesLog('oda koptu: ${e.reason}');
            unawaited(Sentry.captureMessage('oda koptu reason=${e.reason}'));
            leave(notifyServer: false);
          }
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
      await room.localParticipant?.setMicrophoneEnabled(_micOn);
      _kurulumAsama?['mic'] = _kurulumSaat?.elapsedMilliseconds ?? 0; // FAZ-0
      // TEST TURU 32 (kullanici: "bazen ARANAN kiside kendi kamerasi acilmadi"):
      // ONIZLEME ile YAYIN arasinda SENKRON yoktu — `_onizlemeAc()` unawaited baslatiliyor,
      // buradaki okuma SENKRON oldugu icin onizleme henuz hazir degilse `setCameraEnabled(true)`
      // IKINCI bir kamera track'i aciyordu. iOS'ta flutter_webrtc'nin TEK `videoCapturer`
      // property'si uzerine yazildigi icin (FlutterRTCMediaStream.m) coklu-gorev kamera
      // bayragi YANLIS oturuma yaziliyor ve arka planda goruntu donuyordu.
      // Cozum: onizleme isini KISA SURE bekle (en fazla 700ms), sonra karar ver.
      // ⚠️ YAPMA: bu await'i kaldirma (yarisi geri getirir) veya suresiz bekletme.
      // TEST TURU 50 — KOK NEDEN KANITI (LiveKit sunucu logu, 96 saat, 64 arama):
      // 9 aramada TEK TARAFLI video; patlayan taraf 9/9 iOS, 7/9 ARANAN (ikinci katilan),
      // Android'de 0 vaka. Aranan tarafta `_onizlemeAc()` ancak `baslat()` icinde, yani
      // answer REST'inden SONRA basliyor -> 700ms'lik pencereyi eski/yavas cihazda
      // (kayitlarin 8'i iPhone XS Max) kaciriyordu. Sure asilinca `Future.timeout`
      // alttaki isi IPTAL ETMEDIGI icin `setCameraEnabled` IKINCI kamerayi aciyor ve iki
      // capture oturumu iOS'un TEK `videoCapturer`ini paylasip birbirini olduruyordu;
      // sonucta video track HIC yayinlanmiyor, hata `_sesLog` ile (yalniz breadcrumb)
      // sessizce yutuluyordu — 20+ test turu boyunca gorunmemesinin sebebi bu.
      // FIX: pencere 2500ms + sure asiminda gec biten onizleme ATILIR (_onizlemeIptal)
      // + asagida YAYIN DOGRULAMASI (track yoksa tek sefer tekrar dener).
      // ⚠️ YAPMA: bu await'i kaldirma, suresiz bekletme veya `_onizlemeIptal`i atlama.
      if (_camOn) {
        try {
          await _onizlemeIsi?.timeout(const Duration(milliseconds: 2500));
        } catch (_) {
          _onizlemeIptal = true; // gec biten onizleme track'i controller'a GIRMESIN
        }
      }
      if (_camOn) {
        // TEST TURU 22: onizlemede acilan kamerayi AYNEN yayinla (ikinci kez acma yarisi yok)
        final onizleme = _onizlemeTrack;
        // TEST TURU 32: kamera hatasi ARAMAYI OLDURMESIN. Eskiden `setCameraEnabled(true)`
        // try'siz idi; istisna `_connect` catch'ine dusup `_svc.end(id)` ile aramayi
        // SUNUCUDA bitiriyordu (kamera baska uygulamada mesgulse arama hic kurulamiyordu).
        try {
          if (onizleme != null) {
            try {
              await room.localParticipant?.publishVideoTrack(onizleme,
                  publishOptions:
                      _isGroup ? kGroupVideoPublishOptions : kVideoPublishOptions);
              _onizlemeYayinda = true;
            } catch (_) {
              // Yedek yola dusmeden ONCE onizlemeyi sal (iki capture oturumu kalmasin)
              await _onizlemeBirak();
              await room.localParticipant?.setCameraEnabled(true);
            }
          } else {
            await room.localParticipant?.setCameraEnabled(true);
          }
        } catch (e) {
          _camOn = false;
          _sesLog('kamera acilamadi: $e');
          // TEST TURU 50: `_sesLog` yalniz BREADCRUMB yazar — breadcrumb ancak baska bir
          // olay/crash olursa Sentry'e gider. Bu yuzden kamera hatasi bugune kadar
          // GORUNMEDI. Artik olay olarak yazilir (olcum, tahmin degil).
          unawaited(Sentry.captureMessage('kamera acilamadi: $e'));
          bildirimGoster('Kamera açılamadı');
        }
        _kurulumAsama?['cam'] = _kurulumSaat?.elapsedMilliseconds ?? 0; // FAZ-0
        // TEST TURU 50 — YAYIN DOGRULAMASI (yapisal emniyet): yukaridaki yollardan
        // hangisi calisirsa calissin, 1.5sn sonra HALA yayinlanmis video track YOKSA
        // kamera bir kez daha acilir. Bu, kok neden disinda kalan tum sessiz
        // basarisizliklari (capture calinmasi, gec izin, mesgul kamera) da kapatir.
        // ⚠️ YAPMA: bu dogrulamayi kaldirma veya birden fazla kez tekrarlatma
        // (dongu = kamera ac/kapa savasi).
        _videoYayinDogrula(id);
      } else if (_onizlemeTrack != null) {
        // Baglanirken kamera kapandi (yasam dongusu oto-mute) -> onizlemeyi sal, sizinti olmasin
        await _onizlemeBirak();
      }
      // TEST TURU 14: GORUNTULU aramada varsayilan HOPARLOR (WhatsApp davranisi — telefonu
      // kulaga dayamadan konusulur); SESLI aramada eskisi gibi kulaklik (earpiece).
      // iOS SES SIRASI KORUNUR: mic -> kamera -> hoparlor -> _sesiAc EN SON.
      final hoparlor = b.video;
      await room.setSpeakerOn(hoparlor);
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
      // TEST TURU 26: iOS'ta ARKA PLAN KAMERASINI EN BASTA ac (Apple: arka plana gecmeden
      // ONCE acik olmali). Sonucu Sentry'e yaz — cihazin destegi boylece KESIN bilinir
      // ("alta alinca karsi taraf beni goremiyor" sikayetinin cevabi burada).
      if (Platform.isIOS && _camOn) {
        PipService.iosCokluGorevKamera().then((ok) {
          _iosArkaPlanKamera = ok;
          _sesLog('ios coklu-gorev kamera destegi: $ok');
          unawaited(Sentry.captureMessage(
              'ios coklu-gorev kamera (arka planda kamera) destek=$ok'));
        });
      }
      _pilTakibiBaslat(); // TEST TURU 21: pil seviyemi karsi tarafa bildir (uyari icin)
      _speakerOn = hoparlor; // goruntuluyse hoparlor acik (buton durumu gercekle uyumlu)
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
    _videoDogrulamaTimer?.cancel(); // turu 50: arama bitince dogrulama tetiklenmesin
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    _statusPoll?.cancel();
    _statsTimer?.cancel();
    _mediaYedek?.cancel();
    _pipKameraGecikme?.cancel();
    _pilTimer?.cancel();
    _bildirimTimer?.cancel();
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
      await room?.disconnect().timeout(const Duration(milliseconds: 1200));
    } catch (_) {}
    try {
      await listener?.dispose().timeout(const Duration(milliseconds: 1200));
    } catch (_) {}
    try {
      await room?.dispose().timeout(const Duration(milliseconds: 1200));
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
    unawaited(_onizlemeBirak()); // test turu 22: yayinlanmadiysa kamerayi kapat
    // GSM dinleyicisini kapat (park edilmis arama varsa devamEt tekrar acar)
    // TEST TURU 32: ondeplan servisi de AYNI kapida durur — park edilen arama SURDUGU icin
    // beklemedeyken servis KAPANMAZ (yoksa beklemedeki arama arka planda dondurulurdu).
    if (parkEdilen == null) {
      unawaited(PipService.gsmDinle(false));
      unawaited(PipService.aramaServisi(false));
    }
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
    // TEST TURU 14: PiP penceresindeyken arama bittiyse pencereyi KAPAT (yoksa yuzen
    // pencerede uygulamanin ana ekrani asili kalir; WhatsApp pencereyi kapatir).
    if (pipModunda) unawaited(PipService.pipKapat());
    // Ekrana "bitti" bildir: arama=null -> CallScreen listener'i (sheet-pop -> ekran-pop; K7)
    arama = null;
    minimized = false;
    beklemede = false;
    pipModunda = false; // FAZ-6: arama bitti — PiP izni notifyListeners'la geri cekilir
    notifyListeners();

    // TEST TURU 18 — ARAMA BEKLETME: beklemede bir arama varsa aktif arama bitince
    // OTOMATIK ona geri don (telefon davranisi). Ekran pop'u once tamamlansin diye
    // kisa gecikme (devamEt yeni CallScreen push eder; cift-push korumasi ekranGorunur'de).
    if (parkEdilen != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (arama == null && parkEdilen != null) unawaited(devamEt());
      });
    }

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
    unawaited(PipService.micDurum(on)); // PiP dugmesinin ikonu/etiketi senkron kalsin
    notifyListeners();
  }

  /// Kamera ac/kapat. Donus: acildiktan sonra gorunum swap'i sifirlanmali mi (ekran karar verir).
  Future<void> toggleCam() async {
    _kameraOtoKapandi = false; // FAZ-6: kullanici elle dokundu — oto-restore devre disi
    final on = !_camOn;
    // KAPASITE (kullanici karari 30 Tem): grup aramasi 8 kisi — backend
    // `maxGrupKatilimci` ile AYNI sayi olmali. ⚠️ YAPMA: iki tarafi ayirma.
    if (on && _isGroup) {
      final katilimci = 1 + (_room?.remoteParticipants.length ?? 0);
      if (katilimci > 8) {
        rootMessengerKey.currentState?.showSnackBar(const SnackBar(
            content: Text('Grup araması en fazla 8 kişi — kamera açılamıyor')));
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
    // TEST TURU 31: kamera YENIDEN acilinca livekit YENI capture session yaratir ve
    // `isMultitaskingCameraAccessEnabled` sifirlanir -> bayragi hemen tazele, yoksa
    // sonraki arka plana gecişte karsi taraf DONMUS KARE gorur.
    if (Platform.isIOS) {
      if (on) {
        unawaited(iosArkaPlanKamerayiTazele());
      } else {
        _iosArkaPlanKamera = false;
      }
    }
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

  // ---- ARAMA BEKLETME / CALL WAITING (test turu 18) ----

  /// Beklemeye alinmis (parked) arama — varsa ekranda "Beklemede: X" seridi gorunur.
  ParkEdilenArama? parkEdilen;
  StreamSubscription? _parkEndedSub; // parked aramanin karsisi kapatirsa haber ver
  /// AKTIF arama CallKit/GSM tarafindan beklemeye alindi mi (iOS CXSetHeldCallAction).
  bool beklemede = false;

  /// Medyayi durdur/geri ac. Oda ve katilimcilik AYNEN kalir (LiveKit `disable()` sunucuya
  /// "bu track'i bana gonderme" der; `enable()` geri acar) — arama SUNUCUDA OLMEZ.
  Future<void> _medyaBeklet(Room room, bool beklet,
      {bool micHedef = true, bool camHedef = false}) async {
    try {
      await room.localParticipant?.setMicrophoneEnabled(beklet ? false : micHedef);
    } catch (_) {}
    try {
      await room.localParticipant?.setCameraEnabled(beklet ? false : camHedef);
    } catch (_) {}
    for (final p in room.remoteParticipants.values) {
      for (final pub in p.trackPublications.values) {
        try {
          if (beklet) {
            await pub.disable();
          } else {
            await pub.enable();
          }
        } catch (_) {}
      }
    }
  }

  /// AKTIF aramayi PARK ET (ikinci aramayi kabul etmeden once). Oda kapanmaz.
  Future<void> parkEt() async {
    final b = arama;
    final room = _room;
    final listener = _listener;
    if (b == null || room == null || listener == null || parkEdilen != null) return;
    await _medyaBeklet(room, true);
    parkEdilen = ParkEdilenArama(
      bilgi: b,
      room: room,
      listener: listener,
      gecen: _duration,
      micOn: _micOn,
      camOn: _camOn,
      isGroup: _isGroup,
    );
    // Alanlari BOSALT: baslat(yeni) bu odayi ne kapatir ne de karistirir (teardown
    // "enqueue aninda yakala" kurali geregi yalniz _room/_listener uzerinden calisiyor).
    _room = null;
    _listener = null;
    _durationTimer?.cancel();
    _statsTimer?.cancel();
    _kanitTimer?.cancel();
    _mediaYedek?.cancel();
    _statusPoll?.cancel();
    // Park edilen aramanin karsisi kapatirsa (WS call.ended) parki DUSUR
    final parkId = b.callId;
    _parkEndedSub?.cancel();
    _parkEndedSub = _svc.onCallEnded.listen((eid) {
      if (eid != parkId || parkEdilen?.bilgi.callId != parkId) return;
      parkiDusur(bildir: false);
      rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('${b.peerName} beklemedeki aramayı sonlandırdı')));
    });
    unawaited(_svc.hold(parkId, true)); // karsi tarafta "Beklemede" yazsin
    notifyListeners();
  }

  /// Beklemedeki aramayi KAPAT (kullanici bitirdi / karsi taraf kapatti).
  Future<void> parkiDusur({bool bildir = true}) async {
    final p = parkEdilen;
    if (p == null) return;
    parkEdilen = null;
    _parkEndedSub?.cancel();
    _parkEndedSub = null;
    _svc.aktifKonusmaBitti(p.bilgi.callId);
    _svc.ekranKapandi(p.bilgi.callId);
    unawaited(CallKitService.bitir(p.bilgi.callId));
    // TEST TURU 32: park dusunce ve baska aktif arama YOKSA ondeplan servisi de kapansin
    // (bildirim asili kalmasin).
    if (arama == null) unawaited(PipService.aramaServisi(false));
    final room = p.room;
    final listener = p.listener;
    unawaited(CallRoomLock.calistir(() => _odaTemizle(room, listener, -1)));
    if (bildir) {
      try {
        await _svc.end(p.bilgi.callId);
      } catch (_) {}
    }
    notifyListeners();
  }

  /// BEKLEMEDEKI aramaya GERI DON (aktif arama bittikten sonra otomatik ya da elle).
  Future<void> devamEt() async {
    final p = parkEdilen;
    if (p == null || arama != null) return; // once aktif arama bitmis olmali
    parkEdilen = null;
    _parkEndedSub?.cancel();
    _parkEndedSub = null;
    arama = p.bilgi;
    _room = p.room;
    _listener = p.listener;
    _isGroup = p.isGroup;
    _micOn = p.micOn;
    _camOn = p.camOn;
    _baglandi = true;
    _connecting = false;
    _peerJoined = true;
    _mediaBasladi = true;
    _odaBagli = true;
    _ayrildi = false;
    _kapandi = false;
    _cevapsiz = false;
    _error = null;
    minimized = false;
    beklemede = false;
    _sureBaz = p.gecen; // kaldigi yerden
    _sureSayaci
      ..stop()
      ..reset();
    _svc.ekranAcildi(p.bilgi.callId); // mesgul muhafizi geri
    await _medyaBeklet(p.room, false, micHedef: p.micOn, camHedef: p.camOn);
    await _sesiAc(true); // iOS: ses birimi EN SON (hold->resume ses kaybi tuzagi)
    unawaited(_svc.hold(p.bilgi.callId, false));
    _startTimer();
    notifyListeners();
    ekraniAc();
  }

  // ---- ANLIK BILDIRIM SERIDI (test turu 24 — WhatsApp: "X sessize alındı.") ----

  /// Ekranda 5 saniye gorunen anlik bildirim ('' = yok). Yeni bildirim gelirse ESKISININ
  /// YERINE gecer (kuyruk yok — WhatsApp davranisi).
  String bildirim = '';
  Timer? _bildirimTimer;

  void bildirimGoster(String metin) {
    if (metin.isEmpty || arama == null) return;
    bildirim = metin;
    notifyListeners();
    _bildirimTimer?.cancel();
    _bildirimTimer = Timer(const Duration(seconds: 5), () {
      if (bildirim.isEmpty) return;
      bildirim = '';
      notifyListeners();
    });
  }

  // ---- UYARILAR: PIL / BAGLANTI (test turu 21 — WhatsApp deneyimi) ----

  /// Karsi tarafin pil yuzdesi (LiveKit veri kanalindan gelir; -1 = bilinmiyor).
  int karsiPil = -1;
  int _benimPil = -1;
  Timer? _pilTimer;
  final Battery _pilOkuyucu = Battery();
  /// Karsi tarafin baglanti kalitesi (LiveKit) — zayifsa uyari gosterilir.
  ConnectionQuality karsiKalite = ConnectionQuality.unknown;
  bool yenidenBaglaniyor = false;

  /// Ekranda gosterilecek TEK uyari metni (oncelik: yeniden baglanma > baglanti > pil).
  /// Bos string = uyari yok.
  String get uyariMetni {
    if (yenidenBaglaniyor) return 'Yeniden bağlanılıyor…';
    if (karsiKalite == ConnectionQuality.lost) {
      return '${_karsiAd()} bağlantısı koptu';
    }
    if (_quality == ConnectionQuality.poor) return 'İnternet bağlantın zayıf';
    if (karsiKalite == ConnectionQuality.poor) {
      return '${_karsiAd()} bağlantısı zayıf';
    }
    if (karsiPil >= 0 && karsiPil <= 15) {
      return '${_karsiAd()} pil seviyesi düşük';
    }
    if (_benimPil > 0 && _benimPil <= 15) return 'Pil seviyen düşük';
    return '';
  }

  String _karsiAd() {
    final b = arama;
    if (b == null) return 'Karşı taraf';
    if (_isGroup) {
      final p = _room?.remoteParticipants.values.firstOrNull;
      return (p?.name.isNotEmpty ?? false) ? p!.name : 'Katılımcı';
    }
    return b.peerName.isEmpty ? 'Karşı taraf' : b.peerName;
  }

  /// Pil seviyemi periyodik oku ve KARSI TARAFA gonder (LiveKit veri kanali; arama
  /// token'inda canPublishData=true). WhatsApp'taki "X pil seviyesi dusuk" uyarisi icin.
  void _pilTakibiBaslat() {
    _pilTimer?.cancel();
    Future<void> oku() async {
      try {
        final seviye = await _pilOkuyucu.batteryLevel;
        if (arama == null || _ayrildi) return;
        final degisti = seviye != _benimPil;
        _benimPil = seviye;
        if (degisti) notifyListeners();
        final r = _room;
        if (r?.localParticipant == null) return;
        final veri = utf8.encode(jsonEncode({'t': 'batt', 'v': seviye}));
        await r!.localParticipant!.publishData(veri, reliable: true);
      } catch (_) {}
    }

    unawaited(oku());
    _pilTimer = Timer.periodic(const Duration(minutes: 1), (_) => oku());
  }

  /// Karsi taraf BENI beklemeye aldi (WS call.held) — yalniz bilgi (ekranda "Beklemede").
  bool karsiBeklemede = false;
  void karsiTarafBekletti(bool on) {
    if (karsiBeklemede == on) return;
    karsiBeklemede = on;
    notifyListeners();
  }

  /// iOS CallKit BEKLET olayi (CXSetHeldCallAction): GSM aramasi geldi ya da kullanici
  /// "Beklet ve Kabul" dedi. [callId] hangi arama icin geldigini soyler:
  ///  - AKTIF arama ise -> medyayi durdur/geri ac (arama BITMEZ, oda acik kalir).
  ///  - PARK EDILMIS arama ise -> zaten bekliyor; unhold gelirse ve aktif arama yoksa DEVAM ET.
  Future<void> beklemeyeAl(String callId, bool aktif) async {
    final p = parkEdilen;
    if (p != null && p.bilgi.callId == callId) {
      if (!aktif && arama == null) await devamEt();
      return;
    }
    final room = _room;
    if (arama == null || arama!.callId != callId || room == null) return;
    if (beklemede == aktif) return;
    beklemede = aktif;
    await _medyaBeklet(room, aktif, micHedef: _micOn, camHedef: _camOn);
    if (!aktif) await _sesiAc(true); // geri donuste ses birimini tazele (Apple tuzagi)
    unawaited(_svc.hold(callId, aktif));
    notifyListeners();
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
  /// TEST TURU 30 — "KABUL EDINCE ONCE UYGULAMA GORUNUYOR, SONRA ARAMA EKRANI GELIYOR"
  /// (kullanici: "karsi taraf goruntuyu actiginda ilk once uygulamaya gidip tekrar
  /// goruntulu konusmaya geliyor").
  ///
  /// KOK NEDEN: CallKit'ten kabul edilince uygulama ON PLANA gelir ve o anda ekranda
  /// SON KALDIGI SAYFA (sohbet listesi) durur; arama ekrani ancak `answer` REST'i +
  /// izin istegi + Navigator beklemesi bittikten SONRA push edilir -> arada 0.5-1.5sn
  /// "uygulamaya girip geri donme" hissi.
  ///
  /// COZUM: CallKit kabulunde bilinen bilgilerle (callId/video/ad) ekran ANINDA acilir,
  /// "Baglaniliyor..." gosterir; gercek `baslat()` hemen ardindan gelip her seyi kurar.
  /// Bu YALNIZ GORUNUM hazirligidir: oda, medya, muhafiz, sure YOK.
  /// ⚠️ YAPMA: burada `_svc.ekranAcildi` / oda kurulumu yapma (baslat'in isi).
  void hazirlaVeAc(AramaBilgisi gecici) {
    if (arama != null) return; // aktif/park edilmis arama var — dokunma
    _hazirlik = true;
    arama = gecici;
    _isGroup = gecici.isGroup;
    _camOn = gecici.video;
    _micOn = true;
    _connecting = true;
    _baglandi = false;
    _cevapsiz = false;
    _error = null;
    minimized = false;
    notifyListeners();
    ekraniAc();
  }

  /// Hazirlik iptali (answer basarisiz/null): ekran kendini pop eder (arama=null).
  void hazirligiBirak() {
    if (!_hazirlik) return;
    _hazirlik = false;
    arama = null;
    _connecting = false;
    notifyListeners();
  }

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

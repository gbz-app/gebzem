import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/ws.dart';
import 'callkit_service.dart';

/// Gelen arama bilgisi (WebSocket "call.incoming" olayindan)
class IncomingCall {
  IncomingCall({
    required this.callId,
    required this.callerName,
    required this.callerAvatar,
    required this.video,
    this.isGroup = false,
    this.chatTitle = '',
    this.participantCount = 0,
  });

  final String callId;
  final String callerName;
  final String callerAvatar;
  final bool video;
  final bool isGroup; // GRUP aramasi mi (coklu katilimci)
  final String chatTitle; // grup basligi
  final int participantCount; // grup katilimci sayisi (host dahil)

  factory IncomingCall.fromJson(Map<String, dynamic> j) => IncomingCall(
        callId: j['call_id'] as String,
        callerName: j['caller_name'] as String? ?? 'Bilinmeyen',
        callerAvatar: j['caller_avatar'] as String? ?? '',
        // WS payload 'type', push davet 'call_type' -> ikisini de kabul et
        video: ((j['type'] ?? j['call_type']) as String? ?? 'audio') == 'video',
        isGroup: j['is_group'] == true || j['is_group'] == 'true',
        chatTitle: j['chat_title'] as String? ?? '',
        participantCount: (j['participant_count'] as num?)?.toInt() ?? 0,
      );
}

/// Arama servisi: davetleri dinler, arama baslatir/kabul eder/bitirir
class CallService extends StateNotifier<IncomingCall?> {
  CallService(this._ref) : super(null) {
    _sub = _ref.read(wsProvider).events.listen(_onEvent);
  }

  final Ref _ref;
  StreamSubscription? _sub;

  /// Arama bittiginde/reddedildiginde tetiklenir (ekran kapatmak icin)
  final _endedController = StreamController<String>.broadcast();
  Stream<String> get onCallEnded => _endedController.stream;

  /// Karsi taraf kabul edince tetiklenir. Yayin: {call_id, elapsed_ms}.
  /// elapsed_ms = kabulden bu yana GECEN SURE (backend); istemci monotonik Stopwatch ile sayar.
  /// Push yedeginde null (zamanlama guvenilmez) -> istemci referansi WS/Status'tan alir.
  final _answeredController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onCallAnswered => _answeredController.stream;

  /// GRUP: bir katilimci katildi/ayrildi -> CallScreen izgarayi gunceller.
  /// {event: 'call.participant.joined'|'call.participant.left', call_id, user_id, name?}
  final _participantController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onParticipant => _participantController.stream;

  /// Kabul edilmis aramalar. Arama ekrani olayi dinlemeye baslamadan ONCE
  /// "kabul edildi" gelirse kaybolmasin diye tutuluyor.
  final Set<String> kabulEdilenler = {};

  /// Odaya baglanmis (CANLI konusma) aramalar = TEK BITIR-KAPISI muhafizi.
  /// CallScreen odaya baglaninca eklenir, ayrilinca cikarilir. CallKit'in yanlis zamanli
  /// decline/ended/timeout olayi (ikinci UI yuzeyi ya da 45sn CallKit auto-expire) CANLI
  /// aramayi OLDURMESIN diye main.dart onRed bunu kontrol eder. Canli aramayi yalniz kirmizi
  /// tus (CallScreen) veya gercek peer-hangup (RoomDisconnected/ParticipantDisconnected) bitirir.
  final Set<String> aktifKonusmalar = {};
  void aktifKonusmaBasladi(String id) {
    if (id.isNotEmpty) aktifKonusmalar.add(id);
  }

  void aktifKonusmaBitti(String id) => aktifKonusmalar.remove(id);

  /// EKRANDAKI aramalar = "zaten bir aramadasin" (mesgul) muhafizi.
  /// CallScreen initState'te — CALAR fazi dahil, connect'i BEKLEMEDEN — eklenir, dispose'ta
  /// cikarilir; boylece hem "caliyor" hem "aktif konusma" fazlarini kapsar. (aktifKonusmalar
  /// yalniz odaya BAGLANINCA dolan bitir-kapisi muhafizi; calar fazini kacirir -> AYRI set sart.)
  /// Amac: bir arama ekrani acikken 2. arama baslatmayi/kabul etmeyi ENGELLE. Yoksa iki
  /// CallScreen + iki LiveKit Room tek native ses birimini cekistirir ve ikinci aramada
  /// goruntu/ses kurulamaz (kullanicinin "ustte arama altta goruntu, goruntu gelmedi" sorunu).
  final Set<String> ekrandakiAramalar = {};
  bool get aramadaMi => ekrandakiAramalar.isNotEmpty;
  void ekranAcildi(String id) {
    if (id.isNotEmpty) ekrandakiAramalar.add(id);
  }

  void ekranKapandi(String id) => ekrandakiAramalar.remove(id);

  void _onEvent(Map<String, dynamic> ev) {
    final payload = ev['payload'];
    if (payload is! Map) return;
    final p = payload.cast<String, dynamic>();

    switch (ev['type']) {
      case 'call.incoming':
        // iOS: gelen arama HER ZAMAN VoIP push -> CallKit ile gelir (backend her zaman push atar).
        // WS overlay'i de acarsak on planda CIFT gosterim + ses cakismasi olur (Oturum 7).
        // iOS'ta WS call.incoming yok sayilir; arama yalniz CallKit'ten. Android'de on planda
        // WS overlay kullanilir (arka planda FCM data -> CallKit).
        if (Platform.isIOS) return;
        final id = p['call_id'] as String? ?? '';
        // Ayni arama CallKit (kilit ekrani) uzerinden zaten gosterildiyse
        // uygulama ici ekrani ACMA — yoksa cift arama ekrani cikar.
        if (CallKitService.islenenler.contains(id)) return;
        // MESGUL: zaten bir aramadayken uzerine gelen-arama overlay'i BINMESIN
        // ("ustte arama altta goruntu"nun ikinci uretim yolu). Arayana backend 'mesgul' doner.
        if (aramadaMi) return;
        state = IncomingCall.fromJson(p);
      case 'call.answered':
        final id = p['call_id'] as String? ?? '';
        kabulEdilenler.add(id);
        _answeredController.add({'call_id': id, 'elapsed_ms': p['elapsed_ms']});
      case 'call.ended':
        final id = p['call_id'] as String? ?? '';
        aramaBitti(id);
      case 'call.participant.joined':
      case 'call.participant.left':
        // GRUP: izgarayi guncelle (CallScreen dinler). 1:1 aramada bu olaylar HIC gelmez.
        _participantController.add({'event': ev['type'] as String? ?? '', ...p});
    }
  }

  /// Arama bitti/iptal edildi. WS "call.ended" VEYA push ("call.cancel"/"call.ended")
  /// ile cagrilir. Hem gelen arama ekranini/CallKit'i hem de AKTIF CallScreen'i kapatir.
  /// Idempotent: state=null noop, CallKit.bitir aktif yoksa noop, _endedController'i
  /// dinleyen _leave tek-seferlik kilitli. Push yedegi de bu tek kapiyi kullanir.
  void aramaBitti(String id) {
    if (id.isEmpty) return;
    if (state?.callId == id) state = null;
    CallKitService.bitir(id);
    _endedController.add(id);
  }

  /// Arayan: "aramam cevaplandi mi / bitti mi" (WS call.answered kaybolursa kurtarma)
  Future<Map<String, dynamic>> callStatus(String callId) async {
    final res = await _ref.read(apiProvider).get('/calls/$callId/status');
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Uygulama acilinca / on plana donunce: beni su an arayan var mi?
  /// (Arka plandayken WebSocket kopuk oldugu icin "call.incoming" olayi kacmis olabilir —
  /// kullanici bildirime dokunup acinca aramayi yine de gormeli.)
  Future<void> checkActive() async {
    if (state != null) return; // zaten gelen arama ekrani acik
    try {
      final res = await _ref.read(apiProvider).get('/calls/active');
      final data = (res.data as Map).cast<String, dynamic>();
      if (data['call_id'] is String) {
        // iOS'ta gelen arama HER ZAMAN CallKit (VoIP push) ile gelir; uygulama-ici overlay
        // HIC acilmaz. islenenler sinyali iOS'ta native PushKit yolunda dolmadigi (Dart
        // CallKitService.goster cagrilmaz) icin guvenilmezdi -> "CallKit calarken overlay de
        // acilir" cift-UI'sine yol aciyordu. iOS = %100 CallKit, uygulama-ici gelen arama yok.
        if (Platform.isIOS) return;
        // ANDROID cift-UI muhafizi: bu arama CallKit (FCM->arka plan) ile zaten tam ekran
        // gosterildiyse uygulama-ici overlay ACMA -> yoksa CallKit'in UZERINE popup biner.
        // call.incoming yolunda bu muhafiz vardi (satir 69) ama checkActive'de EKSIKTI ->
        // arka plandan one gelince overlay + CallKit CIFT geliyordu (kullanicinin bildirdigi puruz).
        final id = data['call_id'] as String;
        if (CallKitService.islenenler.contains(id)) return;
        if (aramadaMi) return; // MESGUL: aktif aramada gelen-arama overlay'i acma
        state = IncomingCall.fromJson(data);
      }
    } catch (_) {
      // sessiz gec — arama yoksa sorun degil
    }
  }

  /// Arama baslat — LiveKit baglanti bilgilerini doner
  Future<Map<String, dynamic>> start(String calleeId, {required bool video}) async {
    // MESGUL MUHAFIZI: zaten bir arama ekranindayken (calar/aktif) 2. aramayi BASLATMA.
    // Sunucuya POST atmadan ONCE durdur ki ikinci arama hic acilmasin (iki Room cakismasi).
    if (aramadaMi) {
      throw StateError('Zaten bir aramadasınız');
    }
    final res = await _ref.read(apiProvider).post('/calls', data: {
      'callee_id': calleeId,
      'video': video,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  /// GRUP aramasi baslat — secilen kisilerle (anlik grup). LiveKit baglanti bilgilerini doner.
  /// start() ile AYNI mesgul muhafizi (zaten aramada -> engelle) + aramadaMi guard.
  Future<Map<String, dynamic>> startGroup(List<String> memberIds, {required bool video}) async {
    if (aramadaMi) {
      throw StateError('Zaten bir aramadasınız');
    }
    final res = await _ref.read(apiProvider).post('/calls', data: {
      'member_ids': memberIds,
      'video': video,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  // Ayni arama iki yoldan (uygulama ici overlay + CallKit) kabul/bitir edilebilir.
  // callId bazli kilit -> cift answer (409) ve 5-6 kez end REST'ini onler.
  final Set<String> _cevaplanan = {};
  final Set<String> _bitenler = {};

  /// Gelen aramayi kabul et.
  /// DIKKAT: state'i SIFIRLAMIYORUZ (once ekran acilir, sonra dismiss).
  /// null DONERSE: bu arama zaten baska yoldan cevaplandi -> cagiran ekran ACMASIN.
  Future<Map<String, dynamic>?> answer(String callId) async {
    // MESGUL: BASKA bir arama ekrani (calar/aktif) acikken gelen aramayi KABUL ETME.
    // Bu aramanin kendi ekrani answer'dan SONRA acilir, o yuzden ekrandakiAramalar'da
    // BU callId disinda bir id varsa mesgulüz -> ekran acma (cagiran null'da acmaz).
    if (ekrandakiAramalar.any((x) => x != callId)) return null;
    if (!_cevaplanan.add(callId)) return null; // ikinci kabul -> 409 olmadan engelle
    try {
      final res = await _ref.read(apiProvider).post('/calls/$callId/answer');
      return (res.data as Map).cast<String, dynamic>();
    } catch (e) {
      _cevaplanan.remove(callId); // basarisizsa (401 vs) tekrar denenebilsin
      rethrow;
    }
  }

  /// Aramayi bitir / reddet.
  /// KRITIK: guard'i (_bitenler) await ONCESI degil, POST BASARILI olunca isaretle.
  /// Eski kod await'ten once isaretliyor + hatayi yutuyordu -> ilk POST ag hatasiyla
  /// patlarsa callId kalici "bitti" damgalaniyor, bir daha GONDERILMIYOR -> arama sunucuda
  /// 'active' takili kaliyor, o kisi cok uzun sure "mesgul" gorunuyor (2. arama gitmiyor).
  /// Simdi: basarili olana kadar 3 kez dene, YALNIZ basarida isaretle. Sunucu End idempotent
  /// (zaten bitmisse rowsAffected=0 sessiz basari) oldugu icin cift-end zararsiz.
  Future<void> end(String callId) async {
    state = null;
    if (_bitenler.contains(callId)) return; // zaten basariyla bitirildi
    for (var deneme = 0; deneme < 3; deneme++) {
      try {
        await _ref.read(apiProvider).post('/calls/$callId/end');
        _bitenler.add(callId); // yalniz BASARIDA damgala
        return;
      } catch (_) {
        if (deneme < 2) await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Push (on plan onMessage) ile "kabul edildi" geldiginde — WS call.answered yedegi.
  void aramaKabulPush(String id) {
    if (id.isEmpty) return;
    kabulEdilenler.add(id);
    // PUSH zamanlamasi guvenilmez -> sure referansi TASIMA (null); WS/Status referansi verir.
    _answeredController.add({'call_id': id, 'elapsed_ms': null});
  }

  void dismiss() => state = null;

  /// Arama gecmisini tazele. Arama ekrani kapanirken cagrilir — ekranin kendi
  /// `ref`'i o an yok edilmis olabilir, bu yuzden servisin kendi Ref'ini kullaniyoruz.
  void gecmisiYenile() => _ref.invalidate(callHistoryProvider);

  /// CANLI ESZAMANLI ses takibi: arama sirasinda 2sn'de bir ses metrigini sunucuya yollar ki
  /// api log'unda ANLIK izlenebilsin (docker logs -f api | grep AUDIO). Fire-and-forget.
  Future<void> audioStat(String callId, Map<String, dynamic> data) async {
    try {
      await _ref.read(apiProvider).post('/calls/$callId/audio-stat', data: data);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _endedController.close();
    _answeredController.close();
    _participantController.close();
    super.dispose();
  }
}

final callServiceProvider =
    StateNotifierProvider<CallService, IncomingCall?>(CallService.new);

/// Arama gecmisi
final callHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiProvider).get('/calls');
  return (res.data as List).cast<Map<String, dynamic>>();
});

/// Basit JSON yardimcisi (WS payload'lari icin)
Map<String, dynamic> decodePayload(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
  return {};
}

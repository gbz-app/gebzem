import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/ws.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'active_call_controller.dart';
import 'callkit_service.dart';
import 'pip_service.dart'; // turu 64: iOS hucresel arama gozcusu defteri

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
    this.waiting = false,
  });

  final String callId;
  final String callerName;
  final String callerAvatar;
  final bool video;
  final bool isGroup; // GRUP aramasi mi (coklu katilimci)
  final String chatTitle; // grup basligi
  final int participantCount; // grup katilimci sayisi (host dahil)
  // TEST TURU 18 (arama bekletme): alici ZATEN baska bir gorusmede -> ekranda
  // "Beklet ve Kabul / Bitir ve Kabul / Reddet" secenekleri gosterilir.
  final bool waiting;

  factory IncomingCall.fromJson(Map<String, dynamic> j) => IncomingCall(
        callId: j['call_id'] as String,
        callerName: j['caller_name'] as String? ?? 'Bilinmeyen',
        callerAvatar: j['caller_avatar'] as String? ?? '',
        // WS payload 'type', push davet 'call_type' -> ikisini de kabul et
        video: ((j['type'] ?? j['call_type']) as String? ?? 'audio') == 'video',
        isGroup: j['is_group'] == true || j['is_group'] == 'true',
        chatTitle: j['chat_title'] as String? ?? '',
        participantCount: (j['participant_count'] as num?)?.toInt() ?? 0,
        waiting: j['waiting'] == true || j['waiting'] == 'true',
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

  /// Muhafiz bir ODA/CANLI YAYIN ekranina mi ait (arama DEGIL)?
  /// ⚠️ `startsWith('yayin')` BILEREK GENIS: `yayin_<id>` (yayinci/izleyici) VE
  ///     `yayin-onizleme` (live_start_screen) — ikisi de ses cakismasi uretir.
  static bool _odaVeyaYayinMuhafizi(String x) =>
      x.startsWith('oda_') || x.startsWith('yayin');

  /// ⚠️⚠️ TURU 72b (denetim bulgusu) — bu muhafizin ekrani DURAKLATILABILIR mi?
  /// Turu 72 duraklatma kodu YALNIZ `room_screen` (`oda_<id>`),
  /// `live_broadcast_screen` ve `live_viewer_screen` (`yayin_<id>`) icinde var.
  /// ⚠️⚠️ `live_start_screen`in muhafizi **`yayin-onizleme`**dir ve o ekranda
  ///     duraklatma KODU YOKTUR; ustelik fiziksel kamerayi TUTAR — arama kabul
  ///     edilirse IKI capture oturumu cakisir (o ekranin kendi serhi, satir 33).
  ///     Bu yuzden onek ALT CIZGILI olmak ZORUNDA: `startsWith('yayin')` onu da
  ///     kapsardi ve muafiyet FAIL-OPEN olurdu.
  /// ⚠️ YAPMA: bunu `startsWith('yayin')`e genisletme.
  /// ⚠️ YENI bir duraklatilabilir ekran eklersen muhafiz onekini `oda_`/`yayin_`
  ///     yap; duraklatilamayan ekranlara BASKA bir onek ver.
  static bool _duraklatilabilirMuhafiz(String x) =>
      x.startsWith('oda_') || x.startsWith('yayin_');

  /// Su an ACIK olan muhafiz bir ARAMA mi (oda/canli yayin ekrani DEGIL)? Arama bekletme
  /// (test turu 18) yalniz arama-arama durumunda calisir: oda/yayin ekranlarinda ikinci
  /// aramayi gostermek ses cakismasi yaratir (bilincli eski davranis korunur).
  bool get aktifAramaVar => ekrandakiAramalar
      .any((x) => !x.startsWith('oda_') && !x.startsWith('yayin'));
  void ekranAcildi(String id) {
    if (id.isNotEmpty) ekrandakiAramalar.add(id);
  }

  void ekranKapandi(String id) => ekrandakiAramalar.remove(id);

  /// Bu callId DISINDA acik bir arama/oda ekrani var mi. CallKit kabul yolunda
  /// answer()==null'un IKI anlamini ayirir: "zaten kabul edildi" (ayni id acik) ile
  /// "mesgul — odada/baska aramada" (baska id acik). Ikincisinde CallKit UI'si
  /// kapatilip arama reddedilmeli (hayalet CallKit + oda sesi olumu bulgusu).
  bool baskaIsleMesgul(String callId) => ekrandakiAramalar.any((x) => x != callId);

  /// ⚠️ TEST TURU 56 — MESGULLUK KONTROLU **TEK KAYNAK** (bayat muhafiz self-heal).
  ///
  /// `ekrandakiAramalar` kumesine 5 ekrandan giriliyor, 9 yerden birakiliyor; bir birakma
  /// yolu kacarsa id ASILI kalir ve kullanici SUNUCU TERTEMIZ OLSA BILE ne arama yapabilir
  /// ne kabul edebilir ne odaya/yayina girebilir. Bu metot muhafiza koru korune guvenmez,
  /// GERCEKLIGE sorar:
  ///   · GERCEK aktif arama VAR (hazirlik modu HARIC) -> MESGUL
  ///   · `oda_` / `yayin` onekli kayit VAR -> MESGUL (ses cakismasi korumasi ORADA)
  ///   · aksi halde kayit BAYATTIR -> temizlenir, Sentry'e olcum yazilir, MESGUL DEGIL
  ///
  /// [haric]: bu id'yi yok say (kabul yolunda kendi aramamiz mesgul saymaz).
  /// [etiket]: olcumde hangi yoldan geldigi gorunsun (start/answer/oda/yayin).
  ///
  /// ⚠️ YAPMA: bu mantigi cagiran yerlere KOPYALAMA (drift eder — denetim bulgusu:
  /// rooms_tab/live_tab ham `aramadaMi`ye bakiyordu ve self-heal'den YARARLANMIYORDU).
  /// ⚠️ YAPMA: `oda_`/`yayin` kapisini kaldirma.
  /// ⚠️⚠️ TURU 72 — [odaYayinMuaf]: oda/yayin DURAKLATILABILDIGI icin artik arama
  /// KABUL EDILEBILIR. Muaf iken YALNIZ `oda_`/`yayin` dali atlanir; `gercekArama`
  /// dali AYNEN kalir (iki arama ayni anda olmaz).
  /// ⚠️ VARSAYILAN `false` — FAIL-CLOSED. Yalniz duraklatmayi GERCEKTEN yapabilecek
  ///     cagirma noktalari `true` gecer.
  /// ⚠️ YAPMA: muaf yolda bayat-muhafiz self-heal'ini calistirma — oda id'si GERCEK,
  ///     kumeden silersek muhafiz duser ve ikinci oda acilabilir.
  bool mesgulMu(
      {String? haric, String etiket = '', bool odaYayinMuaf = false}) {
    final ilgili =
        ekrandakiAramalar.where((x) => haric == null || x != haric).toList();
    if (ilgili.isEmpty) return false;
    final ctrl = _ref.read(activeCallProvider);
    final gercekArama = ctrl.arama != null && !ctrl.hazirlikModunda;
    if (gercekArama) return true; // iki arama AYNI ANDA olmaz (degismedi)

    // ⚠️⚠️ TURU 72b (denetim bulgusu) — BAYAT ARAMA MUHAFIZLARI ARTIK ODA/YAYIN
    // MUHAFIZIYLA BIRLIKTE DE TEMIZLENIR. Eski kodda self-heal `if (gercekArama ||
    // odaVeyaYayin) return true;` satirinin ALTINDAYDI: kumede bir `oda_` kaydi
    // varsa BAYAT arama id'sine HIC ULASILMIYOR ve muhafiz KALICI olarak asili
    // kaliyordu (kullanici odadayken bir daha arama alamaz/yapamaz).
    // ⚠️ Gercek arama VARSA yukarida donduk — buraya dusuyorsak arama id'li her
    //     kayit tanim geregi BAYATTIR.
    final bayat = ilgili.where((x) => !_odaVeyaYayinMuhafizi(x)).toList();
    if (bayat.isNotEmpty) {
      ekrandakiAramalar.removeAll(bayat);
      unawaited(Sentry.captureMessage(
          'bayat mesgul muhafizi temizlendi ($etiket): $bayat'));
    }

    final kalan = ilgili.where(_odaVeyaYayinMuhafizi).toList();
    if (kalan.isEmpty) return false;
    // ⚠️⚠️ TURU 73 — MUAFIYET ARTIK iOS'TA DA GECERLI (kullanici emri).
    //     Turu 72'de `Platform.isAndroid` sarti vardi cunku duraklatma yalniz
    //     Android'de calisiyordu; iOS'ta muaf birakmak "arama kabul edildi ama
    //     oda susmadi" = ses cakismasi demekti. Artik uc ekran da iOS'ta
    //     duraklatiyor (SesSahipligi + iosSesBirimiAc).
    // ⚠️⚠️ `every` — `any` DEGIL (denetim bulgusu): kumede duraklatilamayan TEK bir
    //     ekran (ornegin `yayin-onizleme`) varsa muafiyet VERILMEZ. FAIL-CLOSED.
    if (odaYayinMuaf && kalan.every(_duraklatilabilirMuhafiz)) {
      return false; // hepsi DURAKLATILABILIR -> mesgul SAYMA
    }
    return true;
  }

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
        final gelen = IncomingCall.fromJson(p);
        // MESGUL: zaten bir aramadayken uzerine gelen-arama overlay'i BINMESIN
        // ("ustte arama altta goruntu"nun ikinci uretim yolu). Arayana backend 'mesgul' doner.
        // TEST TURU 18 ISTISNASI — ARAMA BEKLETME: sunucu `waiting:true` dediyse (alici
        // SUREN bir aramada) overlay YINE gosterilir; 3 secenekli katman cikar
        // (Beklet ve Kabul / Bitir ve Kabul / Reddet). Oda/canli yayin ekranlarinda
        // (guard onekleri 'oda_' / 'yayin') eski davranis: gosterme.
        // ⚠️⚠️ TURU 72 — ODA/YAYIN ARTIK ISTISNA: o ekranlar DURAKLATILABILDIGI icin
        // gelen arama katmani GOSTERILIR (Android'de telefon artik CALAR).
        // ⚠️⚠️ TURU 72b (denetim bulgusu) — KARAR `mesgulMu`YA DEVREDILDI.
        //     Burada AYRI bir kopya vardi ve `every` kullaniyordu; `mesgulMu` ise
        //     `any`. Kumede bayat bir arama id'si varken IKISI FARKLI cevap
        //     veriyordu: ON PLANDA telefon CALMIYOR (bu kapi), ama ayni arama
        //     KILIT EKRANINDAN (CallKit -> answer -> mesgulMu) KABUL EDILIYORDU.
        //     Tek kaynak = drift YOK; ustelik `mesgulMu`nun bayat-muhafiz
        //     self-heal'i artik bu yolda da calisiyor.
        // ⚠️ YAPMA: bu kurali tekrar buraya KOPYALAMA.
        if (mesgulMu(haric: id, etiket: 'incoming', odaYayinMuaf: true) &&
            !(gelen.waiting && aktifAramaVar)) {
          return;
        }
        state = gelen;
      case 'call.answered':
        final id = p['call_id'] as String? ?? '';
        kabulEdilenler.add(id);
        _answeredController.add({'call_id': id, 'elapsed_ms': p['elapsed_ms']});
      case 'call.ended':
        final id = p['call_id'] as String? ?? '';
        aramaBitti(id);
      case 'call.held':
        // TEST TURU 18: karsi taraf beni beklemeye aldi/geri aldi
        _heldController.add({
          'call_id': p['call_id'] as String? ?? '',
          'on': p['on'] == true,
        });
      case 'call.participant.joined':
      case 'call.participant.left':
        // GRUP: izgarayi guncelle (CallScreen dinler). 1:1 aramada bu olaylar HIC gelmez.
        _participantController.add({'event': ev['type'] as String? ?? '', ...p});
      case 'call.upgraded':
        // KISI EKLEME (Faz-B): 1:1 arama gruba yukseltildi — CallScreen ayni kanaldan
        // dinleyip _isGroup moduna gecer (yeni controller ACMA — hukum B4).
        _participantController.add({'event': 'call.upgraded', ...p});
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
    davetSifirla(id); // turu 54: ayni aramaya TEKRAR davet edilebilsin
    _endedController.add(id);
  }

  /// ⚠️ TEST TURU 54 — TEKRAR DAVET EDILEBILME (kullanici: "goruntulu aramadan CIKAN
  /// kisiyi TEKRAR EKLEDIGIMDE karsi taraf SUREKLI ARIYOR, TAKILI KALIYOR").
  ///
  /// SUNUCU KANITI: grup aramasi `7bc32718`e 4 kez `/add` gitti (hepsi 200) ama o arama
  /// icin TEK BIR `/answer` istegi YOK. Backend `Add` 'left' -> 'ringing' upsert'unu
  /// DOGRU yapiyor; sorun ISTEMCIDE.
  ///
  /// KOK: arama-id bazli UC KUME surec omru boyunca HIC temizlenmiyordu:
  ///  · `_cevaplanan` -> ayni callId ile IKINCI kabul REST'e HIC GITMEDEN null doner
  ///    (ASIL KOK: kisi bir kez katilip ciktiysa, ayni aramaya tekrar davet edilince
  ///     "Katil" dese bile sunucuya ulasmaz; CallKit ekrani kapanmaz, zil susmaz)
  ///  · `_bitenler` -> ikinci ayrilis/red sunucuya HIC bildirilmez
  ///  · `CallKitService.islenenler` -> Android'de uygulama-ici gelen-arama katmani
  ///    bir daha HIC acilmaz (cift-UI kapisi yanlis tetiklenir)
  ///
  /// Bu metot bir arama EPISODU bitince o damgalari duser; kapilarin KENDISI durur
  /// (ayni ZIL episodunda cift kabul/cift bitirme korumasi gereklidir).
  /// ⚠️ YAPMA: kapilari tamamen kaldirma; bu sifirlamayi arama SURERKEN cagirma.
  void davetSifirla(String id) {
    if (id.isEmpty) return;
    _cevaplanan.remove(id);
    _bitenler.remove(id);
    kabulEdilenler.remove(id);
    CallKitService.islenenler.remove(id);
    CallKitService.gidenler.remove(id); // turu 57
    // TURU 64: hucresel arama gozcusunun defterinden de dus (iOS). Episod bitti;
    // defterde kalirsa gozcu ilerideki GERCEK bir hucresel aramayi kacirmaz ama
    // defter sisyerek buyur — ayrica ayni id yeniden kullanilirsa yaniltir.
    unawaited(PipService.gebzemAramaSil(id));
    _sonHoldKarari.remove(id); // turu 64: kardes defterlerle tutarli — episod bitti
  }

  /// ARAMA BEKLETME (test turu 18): bu arama beklemeye alindi/geri alindi -> karsi tarafa
  /// bilgi (ekraninda "Beklemede" yazar). Sunucu arama satirina DOKUNMAZ.
  /// Karsi tarafa "aramayi beklemeye aldim/geri aldim" bilgisini gonderir.
  ///
  /// ⚠️ TURU 60: hata eskiden TAMAMEN YUTULUYORDU (`catch (_) {}`) ve TEK deneme
  /// yapiliyordu. GSM aramasi kabul edilirken telefon hucresel/wifi gecisi yasar,
  /// istek TAM O ANDA duserse karsi taraf bekletmeyi HIC ogrenmezdi ve bunu
  /// gorecek TEK BIR olcum de yoktu. Artik 3 deneme (artan aralik) + gorunur olcum.
  /// ⚠️ YAPMA: tek denemeye/sessiz yutmaya geri donme.
  /// ⚠️ NOT: `unhold` (on=false) kaybolursa karsi taraf SONSUZA KADAR "beklemede"
  /// kalir — bu yuzden tekrar denemesi ozellikle kritiktir.
  /// ⚠️⚠️ TURU 64 — SON-KARAR KAPISI (yarisi kapatir).
  /// 3 kor tekrar, hold(true) ve hold(false) arasinda YARIS uretiyordu: yavas kalan
  /// bir `on=true` denemesi, sonradan gonderilen `on=false`i EZIP karsi tarafi
  /// SONSUZA KADAR "Beklemede" rozetiyle birakabiliyordu (sahada 20:56:05 ve 20:56:06'da
  /// AYNI bekletme icin IKI `on=true` olayi gorulmesi bu tekrarlarin izidir).
  /// Cozum: her callId icin SON karar saklanir; karar degistiyse bekleyen denemeler
  /// SESSIZCE birakilir.
  /// ⚠️ YAPMA: 3 denemeyi kaldirma (turu 60 — kaybolan unhold rozeti kalici birakir).
  /// ⚠️ YAPMA: kapiyi GLOBAL yapma — park edilen arama (`hold(parkId,true)`) ile aktif
  ///     arama (`hold(aktifId,false)`) birbirini iptal eder. Anahtar callId OLMALI.
  static final Map<String, bool> _sonHoldKarari = {};

  Future<void> hold(String callId, bool on) async {
    if (callId.isEmpty) return;
    _sonHoldKarari[callId] = on;
    Object? sonHata;
    for (var i = 0; i < 3; i++) {
      if (_sonHoldKarari[callId] != on) return; // daha yeni bir karar var — birak
      try {
        await _ref.read(apiProvider).post('/calls/$callId/hold', data: {'on': on});
        // ⚠️ TURU 64 denetimi: POST UCARKEN karar degismis olabilir (hizli
        // hold->unhold). Sunucuda son yazan biz kalmayalim diye GUNCEL karari
        // yeniden gonder — yoksa karsi tarafta rozet TERS kalir.
        // ⚠️ YAPMA: bu telafiyi kaldirma; sonsuz dongu riski yok (yeni cagri
        //     `_sonHoldKarari`i ayni degere yazar, kosul bir daha tutmaz).
        final guncel = _sonHoldKarari[callId];
        if (guncel != null && guncel != on) unawaited(hold(callId, guncel));
        return;
      } catch (e) {
        sonHata = e;
        if (i < 2) await Future.delayed(Duration(milliseconds: 400 * (i + 1)));
      }
    }
    if (_sonHoldKarari[callId] != on) return;
    unawaited(Sentry.captureMessage(
        'hold POST BASARISIZ (3 deneme) on=$on: $sonHata'));
  }

  /// Karsi taraf beni beklemeye aldi mi (WS call.held) — CallScreen "Beklemede" yazar.
  final _heldController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onHeld => _heldController.stream;

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
    //
    // TEST TURU 53 — BAYAT MUHAFIZ KENDI KENDINI ONARIR (kullanici: "gorusmeden cikip
    // hemen tekrar aramak istedigimde BAZEN alamiyorum").
    // Muhafiz `ekrandakiAramalar` kumesine 5 ekrandan giriliyor ve 9 ayri yerden
    // birakiliyor (arama, oda, yayin baslatma, yayinci, izleyici). Bir birakma yolu
    // kacarsa (istisna, erken donus, ekran oldurulmesi) id kumede ASILI kalir ve bu
    // satir "Zaten bir aramadasınız" firlatir — sunucu tertemiz olsa bile.
    // (Ayni sinif: turu 15'te yayin bitisi modal dialoga bagliydi, `yayin_<id>` asili
    // kaliyordu.) SUNUCU tarafi zaten dogrulandi: DB'de asili 'active'/'ringing' YOK.
    //
    // Artik: muhafizda kayit VAR ama GERCEK aktif arama YOK ve oda/yayin ekrani da
    // yoksa -> kayit BAYATTIR, temizlenir ve arama devam eder. Olcum Sentry'e yazilir.
    // ⚠️ YAPMA: bu kapiyi kosulsuz temizlemeye cevirme (oda/yayin muhafizi GERCEK olabilir
    // — ses cakismasi korumasi orada duruyor).
    // TURU 56: mantik `mesgulMu()` TEK KAYNAGINA tasindi (drift olmasin).
    if (mesgulMu(etiket: 'start')) {
      throw StateError('Zaten bir aramadasınız');
    }
    final res = await _ref.read(apiProvider).post('/calls', data: {
      'callee_id': calleeId,
      'video': video,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  /// AKTIF aramaya kisi ekle (1:1 -> grup yukseltme; Faz-B). Cagiran zaten aramada
  /// oldugundan mesgul muhafizi UYGULANMAZ.
  Future<void> addToCall(String callId, String userId) async {
    await _ref.read(apiProvider).post('/calls/$callId/add', data: {'user_id': userId});
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
  /// [zorla]: ARAMA BEKLETME yolu (test turu 18) — kullanici "Beklet ve Kabul" / "Bitir ve
  /// Kabul" dedi; mevcut arama bilincli olarak park edildi/bitirildi, mesgul kapisi ATLANIR.
  Future<Map<String, dynamic>?> answer(String callId, {bool zorla = false}) async {
    // MESGUL: BASKA bir arama ekrani (calar/aktif) acikken gelen aramayi KABUL ETME.
    // Bu aramanin kendi ekrani answer'dan SONRA acilir, o yuzden ekrandakiAramalar'da
    // BU callId disinda bir id varsa mesgulüz -> ekran acma (cagiran null'da acmaz).
    //
    // ⚠️ TEST TURU 54 — SUNUCU KANITI (1 Agu): kullanici "goruntulu aramadan CIKAN kisiyi
    // TEKRAR EKLEDIGIMDE karsi taraf SUREKLI ARIYOR, TAKILI KALIYOR" dedi.
    // Sunucu logu: `7bc32718` grup aramasina 4 kez `/add` gitti (hepsi 200) ama o arama
    // icin TEK BIR `/answer` istegi YOK. Yani davet ulasiyor, telefon caliyor, ama kabul
    // SUNUCUYA HIC VARMIYOR.
    // KOK: gruptan AYRILAN kisinin `ekrandakiAramalar` kumesinde ESKI arama id'si ASILI
    // kaliyor; asagidaki kapi `x != callId` gorup SESSIZCE `null` donuyor -> cagiran
    // "zaten cevaplanmis" sanip ekran acmiyor, CallKit caliyor kaliyor.
    // Bu, 31 Tem'de `start()` icin duzelttigim BAYAT MUHAFIZIN IKINCI YUZU — orayi
    // onarmis ama BURAYI atlamistim.
    // FIX: kapi artik GERCEKLIGE soruyor (start() ile AYNI mantik): gercek aktif arama
    // VEYA `oda_`/`yayin` muhafizi varsa engelle; yoksa kayit BAYATTIR -> temizle + olcum.
    // ⚠️ YAPMA: bu kapiyi kosulsuz kaldirma (oda/yayin muhafizi GERCEK olabilir — ses
    // cakismasi korumasi orada duruyor) ya da `start()` ile farkli mantiga ayirma.
    // TURU 56: mantik `mesgulMu()` TEK KAYNAGINA tasindi (drift olmasin).
    // ⚠️ TURU 72: `odaYayinMuaf: true` — odada/yayinda iken arama KABUL EDILEBILIR;
    //     ilgili ekran kendini duraklatir ("Bekliyor" + devam dugmesi).
    //     `start` (:362) ve `rooms_tab`/`live_tab` cagrilari MUAF DEGIL — oradan
    //     yeni bir oturum ACMAK hala yasak.
    if (!zorla &&
        mesgulMu(haric: callId, etiket: 'answer', odaYayinMuaf: true)) {
      return null;
    }
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

  /// TEST TURU 35 — GRUP DAVET ("Katil") EKRANINI CALLKIT KABULUNDEN SONRA GOSTER.
  ///
  /// KOK NEDEN: grup davet ekrani (kendi kamera onizlemesi + kamera/mik on-ayari +
  /// "Yok say / Katil") YALNIZ "Android + uygulama ON PLANDA + WS call.incoming" yolunda
  /// cizilebiliyordu. iOS'ta WS call.incoming KOSULSUZ atlanir (satir ~126, CIFT-UI tuzagi
  /// icin dogru bir karar) ve Android kilitli/arka planda FCM -> CallKit yolundan gelir.
  /// Her iki durumda kabul dogrudan aramayi aciyordu -> kullanici: "KATIL ekranini
  /// kaldirmissin". Artik CallKit kabulunde GRUP ise arama HENUZ cevaplanmaz; bu metotla
  /// davet ekrani acilir ve "Katil"a basilinca normal `_accept` akisi calisir.
  /// ⚠️ YAPMA: bunu 1:1 aramada cagirma (kullanici CallKit'te zaten kabul etti, ikinci
  /// onay istemek yanlis olur); WS `call.incoming` iOS kapisini gevsetme (cift UI).
  void grupDavetiGoster(IncomingCall davet) {
    if (state?.callId == davet.callId) return;
    // TURU 54: YENI bir davet episodu basliyor — eski damgalar (bir onceki katilimdan
    // kalan `_cevaplanan`/`islenenler`) "Katil" dokunusunu sessizce yutmasin.
    davetSifirla(davet.callId);
    state = davet;
  }

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

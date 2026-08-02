import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../router.dart';
import 'active_call_controller.dart';
import 'beklemede_katmani.dart';

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
  bool _kapanisAnim = false; // yumusak kapanis (test turu 18: "donarak kapaniyor" fix'i)

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
      // ⚠️ TURU 59: SAHIPLIK JETONU. Bu ekran artik "gecerli ekran"; daha eski bir
      // CallScreen'in gecikmis `dispose`u (ters gecis 160ms + kuyruk) buradan sonra
      // calisirsa jeton uyusmayacagi icin controller durumuna DOKUNAMAZ.
      _c.ekranSahibi = this;
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
  /// TEST TURU 18 (kullanici: "arama kapanirken DONARAK kapaniyor"): once 220ms'lik hafif
  /// SOLMA + hafif kuculme animasyonu, sonra pop. Oda teardown'i zaten arka planda kuyrukta;
  /// bu kisa animasyon donmus son kareyi ortup yumusak bir kapanis hissi verir.
  void _ctrlDegisti() {
    if (!mounted || _kapaniyor) return;
    if (_c.arama == null) {
      _kapaniyor = true;
      // TURU 58: `ekranGorunur` mandalini POP KARARI aninda dusur. Eskiden yalniz
      // `dispose`ta dusuyordu; arada `ekraniAc()` cagrilirsa bayat `true` degeri
      // yuzunden SESSIZCE erken donuyor ve ekran BIR DAHA acilmiyordu.
      // ⚠️ YAPMA: bu satiri kaldirma (dispose'taki yazim zaten idempotent).
      _c.ekranGorunur = false;
      setState(() => _kapanisAnim = true);
      Future.delayed(const Duration(milliseconds: 240), () {
        if (!mounted) return;
        // ⚠️ TURU 58: 240ms icinde arama DIRILMIS olabilir (park -> `devamEt` 500ms
        // zamanlayicisi, ya da yeni bir arama devralmis olabilir). Eskiden bu kontrol
        // YOKTU ve YASAYAN aramanin ekrani pop ediliyordu.
        // ⚠️ TURU 59 EKI: dirilme YALNIZ hala SAHIP isek gecerli. Jeton baskasindaysa
        // ARADA YENI BIR ARAMA DEVRALMIS demektir; bu ekran BAYAT ve normal pop
        // akisina dusmeli. Eskiden burada kalir, ustelik `ekranGorunur=true` yazip
        // canli ekranin durumunu bozar, AYNI track'e IKINCI renderer baglanirdi.
        // ⚠️ YAPMA: bu kontrolu kaldirma veya jeton sartini dusurme.
        if (_c.arama != null && identical(_c.ekranSahibi, this)) {
          _kapaniyor = false;
          _c.ekranGorunur = true; // ekran duruyor — mandali geri al
          if (mounted) setState(() => _kapanisAnim = false);
          return;
        }
        final nav = Navigator.of(context);
        if (_sheetAcik && nav.canPop()) nav.pop();
        if (nav.canPop()) nav.pop();
      });
    }
  }

  /// Kapanis animasyonu sarmalayicisi (arama/oda/yayin ekranlari ortak deseni).
  Widget _kapanisSarmal(Widget child) => AnimatedScale(
        scale: _kapanisAnim ? 0.94 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _kapanisAnim ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: child,
        ),
      );

  @override
  void dispose() {
    if (_benimEkranim) {
      _c.removeListener(_ctrlDegisti);
      // ⚠️ TURU 59 — BAYAT DISPOSE KAPISI. `dispose` pop kararindan ~400ms SONRA
      // (ters gecis 160ms + kuyruk) calisir; o aralikta YENI bir arama devralip kendi
      // ekranini acmis olabilir. Jeton bizde degilse controller durumuna DOKUNMA —
      // aksi halde CANLI ekranin ustune `minimized` + yesil bant biniyordu.
      // ⚠️ YAPMA: bu kapiyi kaldirma veya callId karsilastirmasina cevirme
      // (`geriAra()` yolunda callId ayni ekran yasarken degisir).
      if (!identical(_c.ekranSahibi, this)) {
        super.dispose();
        return;
      }
      _c.ekranSahibi = null;
      // ⚠️⚠️ TEST TURU 58 — KOK NEDEN ("GSM sonrasi arama devam ediyor ama EKRAN GIDIYOR").
      // Karar eskiden `_kapaniyor` BAYRAGINA bakiyordu. O bayrak "arama bitti, kapaniyoruz"
      // demek; ama bayrak true olup arama HALA YASIYORSA (240ms'lik gecikmeli pop ile
      // `devamEt`/yeniden dirilme YARISI) su hale duserdik:
      //   `ekranGorunur = false` yazilir, `minimized` TRUE YAPILMAZ
      //   -> `AktifAramaBanner` (`c.minimized` sartina bagli) yesil seridi de CIZMEZ
      //   -> NE EKRAN NE BANT kalir; arama sunucuda ve medyada YASAR ama DONUS YOLU YOK.
      // Kullanicinin tarif ettigi tam olarak budur.
      // FIX: karari BAYRAGA degil GERCEGE (`arama`) bagla — hangi yoldan pop olursa olsun
      // arama yasiyorsa MUTLAKA minimize + bant.
      // ⚠️ YAPMA: bu karari tekrar `_kapaniyor`a baglama.
      if (_c.arama == null) {
        _c.ekranGorunur = false; // gercekten bitti
      } else {
        // Arama SURUYOR -> guvenli minimize (bitirme YOK, bant cizilir)
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

  // TURU 56: `_kisiEkle()` KALDIRILDI — grup aramasi kapatildi (kullanici karari 2 Agu).
  // Geri acilacaksa: `AddParticipantSheet` + `controller.kisiEkle` DURUYOR; bu metot
  // `_sheetAcik = true` + `.whenComplete(() => _sheetAcik = false)` deseniyle yeniden
  // yazilmali (turu 27-31: `_sheetAcik` isaretlenmezse yanlis pop -> kullanici bos
  // ekranda kalir ve SONRAKI arama ekrani hic acilmaz).
  // ⚠️ `_sheetAcik` alani KALIYOR — ••• menusu ve diger sheet'ler kullaniyor.

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

  /// TEST TURU 29 — karsi tarafin videosu MUTE OLSA DA dondurulur; kutu agacta KALIR,
  /// uzerine bulanik "Beklemede" ortusu binir (`_uzakBeklemede`).
  /// KOK NEDEN: eskiden mute olunca bu getter null donuyordu -> karsi tarafin kutusu
  /// AGACTAN SILINIYOR, buyuk goruntu BANA zipliyor ve karsi taraf donunce renderer
  /// SIFIRDAN kuruluyordu (= siyah patlama). ⚠️ YAPMA: buraya tekrar `muted == false` koyma.
  VideoTrack? get _remoteVideo {
    final p = _c.room?.remoteParticipants.values.firstOrNull;
    final pub = p?.videoTrackPublications.firstOrNull;
    if (pub?.subscribed == true && pub?.track != null) {
      return pub!.track as VideoTrack;
    }
    return null;
  }

  /// Karsi tarafin videosu su an MUTE mi (arka plan/beklemede) — ortu icin.
  bool get _uzakBeklemede {
    final p = _c.room?.remoteParticipants.values.firstOrNull;
    final pub = p?.videoTrackPublications.firstOrNull;
    return pub?.subscribed == true && pub?.muted == true && pub?.track != null;
  }

  /// 1:1'de karsi tarafin MUTE (arka plan/beklemede) video track'i — son kare bulaniklastirilir.
  VideoTrack? get _uzakBeklemedeVideo {
    final p = _c.room?.remoteParticipants.values.firstOrNull;
    if (p == null) return null;
    return _beklemedekiVideo(p);
  }

  // TEST TURU 22: baglanti beklenmeden kendi goruntum (onizleme track'i dahil)
  VideoTrack? get _localVideo => _c.kendiGoruntum ??
      _c.room?.localParticipant?.videoTrackPublications.firstOrNull?.track;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(activeCallProvider);
    // Bitis aninda (arama==null, pop bekleniyor) son kare widget.bilgi ile cizilir
    final b = c.arama ?? widget.bilgi;
    // FAZ-6 -> TEST TURU 14: sistem PiP penceresinin ICERIGI artik AktifAramaBanner'da
    // (MaterialApp.builder) TAM EKRAN ciziliyor — boylece arama kucultulup baska sayfaya
    // gecildiginde de PiP penceresinde KARSI TARAF gorunur (eskiden ana ekran goruntusu
    // dusuyordu). Burada BOS cizeriz: ayni track'e IKINCI bir renderer baglanmasin
    // (kucuk PiP penceresinde cift texture = bosuna GPU/pil).
    // TEST TURU 24 (kullanici: "PiP'ten donunce ekrani cok yavas ciziyor"): ONCEDEN bos
    // Scaffold donuyorduk -> PiP'ten cikinca TUM agac (video renderer'lar dahil) SIFIRDAN
    // kuruluyordu = yavas cizim. Artik agac AYNEN korunur, yalniz BOYANMAZ (Offstage) ->
    // donus ANINDA olur (renderer'lar canli kalir, texture yeniden kurulmaz).
    // YALNIZ ANDROID: iOS PiP icerigi native cizilir; iPhone'da Offstage yapmak
    // uygulamayi GORUNMEZ birakiyordu (kullanici: "ekran gidiyor").
    final pipte = c.pipModunda && Platform.isAndroid;
    final remote = _remoteVideo;
    final local = _localVideo;
    // MID-CALL: sesli aramada kamera acilinca (yerel VEYA karsi) video moduna gecer.
    final showVideo = remote != null || (local != null && c.camOn);

    // ===== TEST TURU 28 — INSTAGRAM/WHATSAPP GECISI (kullanici: "2 saniye sonra iki
    // ekranda PATLAMA oldu"): eskiden karsi taraf baglaninca KENDI video widget'im
    // agacta YER DEGISTIRIYORDU (tam ekran dali -> kucuk pencere dali). Flutter'da
    // widget'in agacta yeri degisince element YENIDEN kurulur -> texture sifirdan
    // olusur -> SIYAH PATLAMA + 1-2sn bos kare.
    // COZUM: iki video da HEP AYNI YERDE (keyed AnimatedPositioned) durur; yalniz
    // DIKDORTGENLERI animasyonla degisir (tam ekran <-> kose). Renderer HIC yeniden
    // kurulmaz -> patlama YOK, gecis 260ms akici. Stack sirasi anahtarli oldugundan
    // kucuk olan uste alinirken de element korunur.
    // ⚠️ YAPMA: video renderer'i kosullu dallarda (if/else) farkli konumlarda cizme.
    final bool bothVideo = remote != null && local != null && c.camOn;
    final bool swap = _selfBuyuk && bothVideo;
    // Karsi taraf HENUZ acmadiysa kendi kameram TAM EKRAN (WhatsApp); acinca kuculur.
    final bool uzakBuyuk = remote != null && !swap;
    final bool yerelBuyuk = local != null && c.camOn && (remote == null || swap);
    final Widget? uzakKutu = remote == null
        ? null
        : _videoKutu(context, const ValueKey('kutu-uzak'), remote,
            buyuk: uzakBuyuk,
            yerel: false,
            swapEdilebilir: bothVideo,
            beklemede: _uzakBeklemede);
    final Widget? yerelKutu = (local == null || !c.camOn)
        ? null
        : _videoKutu(context, const ValueKey('kutu-yerel'), local,
            buyuk: yerelBuyuk, yerel: true, swapEdilebilir: bothVideo);
    // Buyuk ONCE, kucuk SONRA (kucuk pencere ustte kalsin).
    final videoKutulari = <Widget>[
      if (uzakKutu != null && uzakBuyuk) uzakKutu,
      if (yerelKutu != null && yerelBuyuk) yerelKutu,
      if (uzakKutu != null && !uzakBuyuk) uzakKutu,
      if (yerelKutu != null && !yerelBuyuk) yerelKutu,
    ];

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
      child: Offstage(
          offstage: pipte, // PiP'te agac canli kalir ama boyanmaz (hizli donus)
          child: _kapanisSarmal(Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: Stack(
          children: [
            // TEST TURU 27 (kullanici: "siyah patlama oluyor, sonra devam ediyor"):
            // Video katmaninin ALTINDA HER ZAMAN zemin (avatar/degrade) durur -> yeni video
            // yuzeyi ilk karesini uretene kadar SIYAH gorunmez. Uste video 160ms CAPRAZ
            // GECISLE biner (Instagram/WhatsApp hissi); kimlik mediaStreamTrack.id (sabit).
            if (!c.isGroup) Positioned.fill(child: _buildAudioBackground(b)),
            // GRUP: coklu-katilimci izgara. 1:1: video kutulari (yukaridaki animasyon
            // aciklamasina bak — konumlari animasyonla degisir, YENIDEN KURULMAZ).
            if (c.isGroup)
              _buildGroupGrid(b)
            // TEST TURU 21 (1:1): karsi taraf uygulamayi kapatti/arka plana aldi -> videosu
            // MUTE; son kareyi BULANIK gosterip "Beklemede" yaz (WhatsApp gorunumu).
            else if (!showVideo && _uzakBeklemedeVideo != null)
              Positioned.fill(
                child: BeklemedeKatmani(
                    track: _uzakBeklemedeVideo, harf: b.peerName),
              ),
            if (!c.isGroup) ...videoKutulari,

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
                      // TEST TURU 21 (WhatsApp): PIL / BAGLANTI uyarisi — "X pil seviyesi
                      // düşük", "İnternet bağlantın zayıf", "Yeniden bağlanılıyor…".
                      if (c.uyariMetni.isNotEmpty && !c.beklemede)
                        Padding(
                          // TEST TURU 23: uzun uyari metni tasiyordu -> yatay pay + tek satir
                          padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                  c.uyariMetni.contains('pil')
                                      ? LucideIcons.batteryLow
                                      : LucideIcons.wifiOff,
                                  size: 14,
                                  color: Colors.amberAccent),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(c.uyariMetni,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.amberAccent, fontSize: 12)),
                              ),
                            ]),
                          ),
                        ),
                      // ARAMA BEKLETME (test turu 18): bu arama beklemede mi
                      if (c.beklemede || c.karsiBeklemede)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: const Color(0xAAEF6C00),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                                c.beklemede
                                    ? '⏸ Beklemede'
                                    : '⏸ Karşı taraf sizi beklemeye aldı',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ),
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
                  // TURU 56: "Kisi ekle" KALDIRILDI — grup aramasi kapatildi
                  // (kullanici karari 2 Agu). ⚠️ YAPMA: geri eklerken `_kisiEkle`nin
                  // `_sheetAcik` + `whenComplete` desenini bozma (turu 27-31 dersi).
                  _barBtn(LucideIcons.messageSquare, _mesajaDon),
                ])),
              ),

            // ANLIK BILDIRIM SERIDI (test turu 24 — WhatsApp: "Mikail sessize alındı."):
            // ustte koyu hap; 5 saniye sonra kaybolur, yeni bildirim gelirse yerine gecer.
            if (c.bildirim.isNotEmpty)
              Positioned(
                top: 118,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xE6202C33),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(c.bildirim,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15)),
                      ),
                    ),
                  ),
                ),
              ),

            // ARAMA BEKLEMEDE PANELI (test turu 20 — WhatsApp duzeni): GSM aramasi geldi
            // ya da arama beklemeye alindi. Alt kontrollerin YERINE gecer: "Aramayi bitir"
            // (kirmizi) / "Devam et" (yesil). Arama SUNUCUDA yasar, yalniz medya durur.
            if (c.beklemede)
              Positioned(
                left: 12,
                right: 12,
                bottom: 40,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17232B),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Arama beklemede.',
                        style: TextStyle(color: Colors.white, fontSize: 17)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0x33E53935),
                          foregroundColor: const Color(0xFFE57373),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                        ),
                        onPressed: () => _c.leave(notifyServer: true),
                        icon: const Icon(LucideIcons.phoneOff, size: 18),
                        label: const Text('Aramayı bitir',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                        ),
                        onPressed: () =>
                            _c.beklemeyeAl(_c.arama?.callId ?? '', false),
                        child: const Text('Devam et',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
              ),

            // Alt kontroller (cevapsizda: Geri Ara / Kapat) — A7: gizlenebilir
            if (!c.beklemede)
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: _gizlenebilir(
                  c.cevapsiz ? _buildCevapsizKontroller(b) : _buildAramaKontroller(c)),
            ),
          ],
        ),
      ))),
    );
  }

  // NOT (test turu 14): eski _pipGorunum KALDIRILDI — PiP icerigi AktifAramaBanner'da
  // (MaterialApp.builder) tam ekran cizilir; boylece PiP hangi sayfadayken acilirsa acilsin
  // ayni goruntu gelir ve ayni track'e iki renderer baglanmaz.

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

  /// TEST TURU 28 — TEK VIDEO KUTUSU (hem tam ekran hem kucuk pencere AYNI widget).
  /// [buyuk] degisince YALNIZ dikdortgen animasyonla degisir; renderer element'i
  /// korunur (anahtarli AnimatedPositioned) -> siyah patlama / yeniden cizim YOK.
  /// Kucukken: dokun->SWAP, surukle->koseye yapisir. Buyukken: dokun->kontrolleri gizle.
  /// ⚠️ Iki durumun widget AGACI AYNI SEKILDE kurulmali (ayni tip sirasi) — farkli
  /// kurarsan Flutter element'i yeniden yaratir ve patlama geri gelir.
  Widget _videoKutu(BuildContext c2, Key anahtar, VideoTrack track,
      {required bool buyuk,
      required bool yerel,
      required bool swapEdilebilir,
      bool beklemede = false}) {
    final sz = MediaQuery.of(c2).size;
    final w = buyuk ? sz.width : (_uiGizli ? 100.0 : _selfW);
    final h = buyuk ? sz.height : (_uiGizli ? 143.0 : _selfH);
    final pos = buyuk ? Offset.zero : _selfKonum(sz, w, h);
    // Surukleme sirasinda animasyon OLMAZ (parmakla birebir hareket).
    final surukleniyor = !buyuk && _selfPos != null;
    return AnimatedPositioned(
      key: anahtar,
      duration:
          surukleniyor ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: pos.dx,
      top: pos.dy,
      width: w,
      height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: buyuk
            ? _uiToggle
            : (swapEdilebilir
                ? () => setState(() => _selfBuyuk = !_selfBuyuk)
                : null),
        onPanUpdate: buyuk
            ? null
            : (d) {
                final cur = _selfPos ?? pos;
                final nx = (cur.dx + d.delta.dx)
                    .clamp(_selfMargin, sz.width - w - _selfMargin);
                final ny =
                    (cur.dy + d.delta.dy).clamp(60.0, sz.height - h - 140.0);
                setState(() => _selfPos = Offset(nx, ny));
              },
        onPanEnd: buyuk
            ? null
            : (_) {
                final cur = _selfPos ?? pos;
                setState(() {
                  _selfSagda = (cur.dx + w / 2) >= sz.width / 2;
                  _selfAltta = (cur.dy + h / 2) >= sz.height / 2;
                  _selfPos = null;
                });
              },
        // Ilk beliriste 180ms yumusak acilis (kutu agaca yeni eklendiginde BIR KEZ).
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          builder: (_, o, child) => Opacity(opacity: o, child: child),
          // Kose yuvarlamasi da gecisle: tam ekranda 0, kucukte 14.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: buyuk ? 0.0 : 14.0, end: buyuk ? 0.0 : 14.0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (_, r, child) => ClipRRect(
                borderRadius: BorderRadius.circular(r), child: child),
            // TEST TURU 24: cerceve/golge YOK — yalniz videonun kendisi.
            child: Stack(fit: StackFit.expand, children: [
              IgnorePointer(
                child: VideoTrackRenderer(track,
                    // TEST TURU 53 — ANAHTAR ARTIK TRACK KIMLIGINE DEGIL, KUTUNUN ROLUNE
                    // BAGLI. Eskiden `mediaStreamTrack.id` kullaniliyordu; on plana
                    // donuste `setCameraEnabled(true)` livekit'te `restartTrack()`
                    // calistirip YENI bir mediaStreamTrack uretiyor -> anahtar degisiyor
                    // -> renderer YIKILIP yeniden kuruluyor (texture sifirdan). Kullanici
                    // "donunce cizmeye calisiyor, guzel gorunmuyor" derken bunu goruyordu.
                    // Rol sabit oldugu icin renderer AYAKTA kalir, yalniz track degisir.
                    // ⚠️ YAPMA: anahtara tekrar track kimligi (id/sid) koyma.
                    key: yerel
                        ? const ValueKey('vid-yerel')
                        : const ValueKey('vid-uzak'),
                    fit: VideoViewFit.cover,
                    mirrorMode:
                        yerel ? _c.yerelAyna : VideoViewMirrorMode.auto),
              ),
              // TEST TURU 29: karsi taraf arka planda -> renderer DEGISMEZ, uzerine
              // bulanik "Beklemede" ortusu biner (widget degistirmek patlama uretiyordu).
              // TEST TURU 31 (kullanici: WhatsApp'ta KILIT/uygulama kapatmada "Kamera
              // duraklatildi" yaziyor, ses devam ediyor): video mute -> ayni yazi.
              // Karsi taraf aramayi BEKLETTIYSE (hold) yazi "Beklemede" kalir.
              if (beklemede)
                Positioned.fill(
                  child: BeklemedeOrtusu(
                      etiket: _c.karsiBeklemede ? 'Beklemede' : 'Kamera duraklatıldı'),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  /// ALT KONTROL CUBUGU — TEST TURU 25 (kullanici ekran goruntusu, WhatsApp duzeni):
  /// TEK koyu hap icinde 5 dugme: [•••] [kamera] [hoparlor] [mikrofon] [KIRMIZI kapat].
  /// Acik durumlar BEYAZ daire + koyu ikon; kapali/pasif koyu daire + beyaz ikon.
  Widget _buildAramaKontroller(ActiveCallController c) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xE61E282E),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // ••• : ek secenekler (kamera cevir / kisi ekle)
          _hapBtn(
            icon: LucideIcons.ellipsis,
            beyaz: false,
            onTap: _ekSecenekler,
          ),
          const SizedBox(width: 10),
          _hapBtn(
            icon: c.camOn ? LucideIcons.video : LucideIcons.videoOff,
            beyaz: c.camOn,
            onTap: _toggleCam,
          ),
          const SizedBox(width: 10),
          _hapBtn(
            icon: c.speakerOn ? LucideIcons.volume2 : LucideIcons.volumeX,
            beyaz: c.speakerOn,
            onTap: c.toggleSpeaker,
          ),
          const SizedBox(width: 10),
          // TEST TURU 29: mikrofon ACIK durumu gorsel olarak ayirt EDILMIYORDU
          // (`beyaz:false` sabitti, `kirmiziIkon` ise iki dalda da beyaz veriyordu =
          // olu parametre). Artik kamera/hoparlor ile AYNI kural: acik = BEYAZ daire.
          _hapBtn(
            icon: c.micOn ? LucideIcons.mic : LucideIcons.micOff,
            beyaz: c.micOn,
            onTap: c.toggleMic,
          ),
          const SizedBox(width: 10),
          // Kapat — aramayi YALNIZ bu bitirir (tek kapi: controller.leave)
          _hapBtn(
            icon: LucideIcons.phoneOff,
            beyaz: false,
            arka: const Color(0xFFE53935),
            onTap: () => c.leave(notifyServer: true),
          ),
        ]),
      ),
    );
  }

  Widget _hapBtn({
    required IconData icon,
    required bool beyaz,
    required VoidCallback onTap,
    Color? arka,
    bool kirmiziIkon = false,
  }) {
    final zemin = arka ?? (beyaz ? Colors.white : const Color(0xFF3A464E));
    final renk = arka != null
        ? Colors.white
        : (beyaz
            ? const Color(0xFF0B141A)
            : (kirmiziIkon ? const Color(0xFFE53935) : Colors.white));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(color: zemin, shape: BoxShape.circle),
        child: Icon(icon, color: renk, size: 25),
      ),
    );
  }

  /// ••• menusu: kamera cevir + kisi ekle (alt cubuk sade kalsin diye buraya alindi)
  void _ekSecenekler() {
    // TEST TURU 29 — EKRAN KILITLENMESI FIX'I: bu sayfa ACIKKEN karsi taraf kapatirsa
    // `_ctrlDegisti` iki pop yapar; `_sheetAcik` isaretlenmezse TEK pop calisip yalniz
    // SAYFAYI kapatiyor, arama ekrani opacity 0 halde EKRANDA KALIYORDU (geri tusu de
    // bloklu -> uygulamayi oldurmek gerekiyordu; dahasi ekranGorunur true kaldigi icin
    // SONRAKI arama ekrani da hic acilmiyordu). ⚠️ Yeni sheet/dialog eklerken AYNI
    // bayragi set et.
    _sheetAcik = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E282E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_c.camOn)
            ListTile(
              leading: const Icon(LucideIcons.switchCamera, color: Colors.white),
              title: const Text('Kamerayı çevir',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _c.flipCamera();
              },
            ),
          // TURU 56: "Kisi ekle" maddesi KALDIRILDI — grup aramasi kapatildi.
          ListTile(
            leading: const Icon(Icons.volume_off, color: Colors.orangeAccent),
            title: Text(_sorunBildirildi ? 'Bildirildi ✓' : 'Ses gelmiyor',
                style: const TextStyle(color: Colors.orangeAccent)),
            onTap: () {
              Navigator.of(context).pop();
              _sorunBildir();
            },
          ),
        ]),
      ),
    ).whenComplete(() => _sheetAcik = false);
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
      // TEST TURU 22: yayin baslamadan da kendi goruntum (onizleme track'i) gorunsun
      return p.videoTrackPublications.firstOrNull?.track ?? _c.kendiGoruntum;
    }
    // TEST TURU 29: MUTE track de dondurulur (tile agacta KALSIN) — bulanik "Beklemede"
    // ortusu `_katilimciBeklemede` ile ustune binir. ⚠️ YAPMA: `!pub.muted` sartini geri
    // koyma (tile silinip geri gelince renderer sifirdan kurulur = siyah patlama).
    for (final pub in p.videoTrackPublications) {
      if (pub.subscribed && pub.track != null) return pub.track as VideoTrack;
    }
    return null;
  }

  /// Grup tile'i su an "Beklemede" mi (uzak katilimcinin videosu MUTE).
  bool _katilimciBeklemede(Participant p) {
    if (p is LocalParticipant) return false;
    for (final pub in p.videoTrackPublications) {
      if (pub.subscribed && pub.muted && pub.track != null) return true;
    }
    return false;
  }

  /// TEST TURU 21 (WhatsApp deneyimi): karsi taraf uygulamayi arka plana aldi/kapatti ya da
  /// aramayi beklemeye aldi -> video track'i MUTE, ama SON KARE elimizde. Bu durumda avatar
  /// yerine son kareyi BULANIK gosterip "Beklemede" yaziyoruz. Track hic yoksa null.
  VideoTrack? _beklemedekiVideo(Participant p) {
    if (p is LocalParticipant) return null;
    for (final pub in p.videoTrackPublications) {
      if (pub.subscribed && pub.muted && pub.track != null) {
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
    // TEST TURU 22 (kullanici: "sesli grupta kisiler daire seklinde HEPSI gorunmuyor"):
    // eski kod videosuz grupta serbest bir Wrap ciziyordu (tasma/kaybolma). Artik SESLI de
    // GORUNTULU de AYNI IZGARA kullanilir — herkes esit kutuda, avatar + ad ile.
    return _grupVideoIzgara(katilimcilar);
  }

  // NOT (test turu 22): _grupAvatar KALDIRILDI — sesli grup da artik ayni izgarayi kullaniyor.
  /// GORUNTULU GRUP IZGARASI (kurallar AYNEN: kaydirma esigi, padding, DPR fixed(1.0))
  Widget _grupVideoIzgara(List<Participant> katilimcilar) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _uiToggle,
        child: Container(
        color: const Color(0xFF0B141A),
        // TEST TURU 53 (kullanici: "gridler arasinda siyahlik olmasin"): ust/alt 108/132px
        // BOS koyu serit KALDIRILDI — izgara tum ekrani doldurur, kontroller USTUNE biner
        // (WhatsApp gorunumu).
        // ⚠️ DENETIM UYARISI VE NEDEN GECERSIZ: dogrulayici "sesli grup da AYNI izgarayi
        // kullaniyor (turu 22); padding sifirlanirsa 5-6 kisilik sesli grupta alt satirin
        // ortalanmis avatar+adi kontrol cubugunun ALTINA girer" dedi. O hesap 5-6 kisiye
        // gore; grup kapasitesi 31 Tem'de **4 kisiye** indirildi (`maxGrupKatilimci`),
        // yani en fazla 2 SATIR olusur ve alt satirin merkezi ekranin ortasinda kalir —
        // kontrol cubugunun cok uzerinde. Risk kalkti.
        // ⚠️ YAPMA: grup kapasitesi tekrar 4'un UZERINE cikarilirsa bu padding'i geri
        // getir (yoksa alt satirdaki adlar kontrollerin altinda kaybolur).
        padding: EdgeInsets.zero,
        child: LayoutBuilder(builder: (context, box) {
          final n = katilimcilar.length;
          final cols = n <= 2 ? 1 : 2;
          final rows = (n + cols - 1) ~/ cols;
          final gorunurSatir = rows > 4 ? 4 : rows;
          const bosluk = 0.0; // turu 53: kutular arasi SIYAH CIZGI olmasin
          final tamW = box.maxWidth;
          final tileW = (tamW - (cols - 1) * bosluk) / cols;
          // TEST TURU 50 ("toplu goruntulu gorusmede ALTTA PATLIYOR"): satir yukseklikleri
          // `box.maxHeight`e TAM oturuyordu; ondalik yuvarlama toplami bir kil payi
          // asinca Flutter alt kenarda sari-siyah "RenderFlex overflowed" seridi cizer.
          // Ayrica kucuk ekranda ust/alt padding (108+132) yuksekligi eritip tileH'i
          // NEGATIFE dusurebiliyordu. Cozum: yarim piksel pay + taban sinir.
          // ⚠️ YAPMA: bu payi kaldirma veya tileH'i sinirsiz birakma.
          final tileH = math.max(
              1.0,
              (box.maxHeight - (gorunurSatir - 1) * bosluk) / gorunurSatir - 0.5);
          // TEST TURU 16 (kullanici): SON SATIRDA TEK kisi kalirsa YARIM genislikte solda
          // durmasin -> TAM GENISLIK (yatik). 3 kisi: ustte 2 yan yana, altta 1 genis.
          // GridView.count sabit sutunlu oldugu icin elle satir/sutun kuruluyor; 4 satirdan
          // fazlasi kaydirilir (eski davranis korundu).
          final icerik = Column(children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: bosluk),
              () {
                final ilk = r * cols;
                final son = math.min(ilk + cols, n);
                final tekBasina = (son - ilk) == 1 && cols > 1;
                return SizedBox(
                  height: tileH,
                  child: Row(children: [
                    for (var i = ilk; i < son; i++) ...[
                      if (i > ilk) const SizedBox(width: bosluk),
                      SizedBox(
                          width: tekBasina ? tamW : tileW,
                          child: _grupVideoTile(katilimcilar[i])),
                    ],
                  ]),
                );
              }(),
            ],
          ]);
          return rows > 4 ? SingleChildScrollView(child: icerik) : icerik;
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
    // TEST TURU 24 (kullanici: "gruba katilinca iki ekranda da takiliyor"): yeni tile
    // BIRDEN belirmesin — 180ms'lik cok hafif bir belirme (jank hissini gizler).
    return TweenAnimationBuilder<double>(
      key: ValueKey('tile-anim-${p.identity}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (_, deger, child) => Opacity(opacity: deger, child: child),
      child: _grupVideoTileIc(p, yerel, ad, video, konusuyor),
    );
  }

  Widget _grupVideoTileIc(Participant p, bool yerel, String ad, VideoTrack? video,
      bool konusuyor) {
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
            if (video != null) ...[
              IgnorePointer(
                child: VideoTrackRenderer(video,
                    // TEST TURU 29 — GRUPTA SIYAH PATLAMA KOKU: anahtar `video.sid` idi;
                    // livekit'te `Track.sid` YAYINLANANA KADAR NULL, yayinda atanir ->
                    // anahtar 'tile-null' -> 'tile-TR_xxx' degisiyor -> renderer YENIDEN
                    // kuruluyor -> aramanin 1-2. saniyesinde kendi kutunda SIYAH SICRAMA.
                    // mediaStreamTrack.id yayin oncesi/sonrasi AYNI kalir.
                    // ⚠️ YAPMA: tile anahtarina tekrar sid koyma.
                    // TEST TURU 53: `mediaStreamTrack.id` de yeterli DEGILMIS — kamera
                    // yeniden acilinca (restartTrack) o da degisiyor ve renderer yikiliyor.
                    // `p.identity` katilimcinin KIMLIGI; yayin oncesi/sonrasi VE kamera
                    // yeniden baslatmasindan SONRA da DEGISMEZ.
                    // ⚠️ YAPMA: buraya tekrar track kimligi koyma.
                    key: ValueKey('tile-${p.identity}'),
                    fit: VideoViewFit.cover,
                    mirrorMode: yerel ? _c.yerelAyna : VideoViewMirrorMode.auto,
                    adaptiveStreamPixelDensity:
                        const AdaptiveStreamPixelDensity.fixed(1.0)),
              ),
              // TEST TURU 21+29: kamerasi MUTE olan (arka planda/beklemede) katilimcinin
              // SON KARESI BULANIK + "Beklemede" (WhatsApp). Renderer DEGISMEZ, ortu biner.
              if (_katilimciBeklemede(p))
                const Positioned.fill(
                    child: BeklemedeOrtusu(etiket: 'Kamera duraklatıldı')),
            ] else
              // TEST TURU 22 (kullanici ekran goruntusu): kamerasi kapali katilimci —
              // ORTADA daire avatar + ALTINDA adi (FaceTime/WhatsApp duzeni).
              Container(
                color: const Color(0xFF1C1C1E),
                alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: yerel
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFF7A4A3A),
                    child: Text(ad[0].toUpperCase(),
                        style: const TextStyle(fontSize: 30, color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  Text(ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: yerel
                              ? const Color(0xFF7EE2C8)
                              : const Color(0xFFF2B8A6))),
                ]),
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

  // NOT (test turu 25): _ctrlButton KALDIRILDI — alt kontroller artik tek hap icinde (_hapBtn).
}

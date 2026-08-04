import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api.dart';
import '../../router.dart';
import 'active_call_controller.dart';
import 'call_media_options.dart';
import 'call_provider.dart';
import 'call_sounds.dart';
import 'callkit_service.dart';

/// Gelen arama ekrani — uygulama acikken her ekranin uzerinde belirir.
/// (Kilit ekraninda calma/CallKit sonraki asamada eklenecek.)
class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(callServiceProvider);

    return Stack(
      children: [
        child,
        if (incoming != null)
          Positioned.fill(
            child: _IncomingCallSheet(call: incoming),
          ),
      ],
    );
  }
}

class _IncomingCallSheet extends ConsumerStatefulWidget {
  const _IncomingCallSheet({required this.call});

  final IncomingCall call;

  @override
  ConsumerState<_IncomingCallSheet> createState() => _IncomingCallSheetState();
}

class _IncomingCallSheetState extends ConsumerState<_IncomingCallSheet> {
  bool _busy = false;
  int? _zilNesli; // CallSounds zil nesli — durdururken verilir (art arda ezme koruması)
  Timer? _timeout; // gelen arama sonsuza calmasin (arayan iptali WS'te kaybolabilir)
  Timer? _poll;
  // TEST TURU 21 — GRUP DAVET EKRANI (WhatsApp): kendi kamera onizlemem + kamera/mikrofon
  // ON-AYARI. Kullanici "Katil" demeden once kamerasini/mikrofonunu kapatabilir; secim
  // aramaya TASINIR (controller.baslat(micAcik:, kameraAcik:)).
  lk.LocalVideoTrack? _onizleme;
  bool _kameraSecimi = true;
  bool _mikSecimi = true;
  bool get _grupDavet => widget.call.isGroup;

  @override
  void initState() {
    super.initState();
    // TEST TURU 26 (kullanici: "aradigim kiside de kamera DIREK acilmali"): GORUNTULU
    // gelen aramada (1:1 dahil) kendi kameramiz ekranda ANINDA gorunur — kabul edilince
    // ayni akis devam eder. Grup daveti zaten boyleydi.
    if (widget.call.video) _onizlemeAc();
    // Zil + titresim. LiveKit odasina henuz baglanmadigimiz icin zil serbestce calar.
    CallSounds.gelenArama().then((n) => _zilNesli = n); // nesli sakla (durdururken verilecek)
    final notifier = ref.read(callServiceProvider.notifier);
    // Arayan iptal edince call.ended WS'i duserse (buffer/half-open) telefon SONSUZA
    // calmasin: (1) ~48sn'de kendiliginden kapan, (2) 3sn'de bir sunucu durumunu sor.
    _timeout = Timer(const Duration(seconds: 48), () {
      if (mounted) notifier.dismiss();
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final s =
            (await notifier.callStatus(widget.call.callId))['status'] as String? ?? '';
        // GRUP: host konustugu icin status 'active' doner; bu davetliyi KAPATMASIN -> yalniz arama
        // BITINCE kapat (48sn timeout + WS call.ended emniyeti duruyor). 1:1: eskisi gibi ringing disi kapat.
        final kapat = widget.call.isGroup ? (s == 'ended' || s == 'missed') : (s != 'ringing');
        if (kapat && mounted) notifier.dismiss();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _poll?.cancel();
    CallSounds.durdur(_zilNesli); // ekran her kapandiginda zil MUTLAKA sussun
    _onizlemeKapat(); // grup davet onizlemesi (test turu 21)
    super.dispose();
  }

  /// GRUP DAVET ONIZLEMESI (test turu 21): kamera izni VARSA kendi goruntumu goster.
  /// Izin yoksa/hata olursa sessizce avatar gorunumune duseriz (davet ekrani bozulmaz).
  Future<void> _onizlemeAc() async {
    try {
      // TEST TURU 32 — PARITE: controller'in ayni isi yapan metodu izni ISTIYOR
      // (active_call_controller `_onizlemeAc`, turu 25 fix'i), burasi yalniz "verilmis mi"
      // diye bakiyordu. Sonuc: ILK goruntulu aramada aranan kisi calarken kendini gormuyor,
      // kabulde devredilecek track OLMUYOR ve kamera IKINCI kez aciliyordu (turu 32 yarisi).
      // Reddedilirse sessizce avatara duseriz. WhatsApp da bu ekranda izin ister.
      if (!await Permission.camera.isGranted) {
        final st = await Permission.camera.request();
        if (st != PermissionStatus.granted || !mounted) return;
      }
      final t = await lk.LocalVideoTrack.createCameraTrack(kCameraCaptureOptions);
      if (!mounted) {
        await t.stop();
        await t.dispose();
        return;
      }
      setState(() => _onizleme = t);
    } catch (_) {}
  }

  Future<void> _onizlemeKapat() async {
    final t = _onizleme;
    _onizleme = null;
    try {
      await t?.stop();
      await t?.dispose();
    } catch (_) {}
  }

  /// ARAMA BEKLETME (test turu 18): bu arama BEN BASKA GORUSMEDEYKEN geldi.
  /// [beklet]=true -> mevcut aramayi beklemeye al (sunucuda olmez, medya durur);
  /// false -> mevcut aramayi BITIR. Ikisinde de yeni arama kabul edilir (zorla).
  Future<void> _bekletVeyaBitirKabul({required bool beklet}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ctrl = ref.read(activeCallProvider);
    try {
      // ⚠️⚠️ TURU 66 — BEKLETME KAPALI: `beklet` istegi gelse bile mevcut arama
      // BITIRILIR (bkz. `ActiveCallController.bekletmeAcik`). Bekletmeden cikista ses
      // geri gelmiyordu (turu 65 "!pri" kaniti), bu yuzden ozellik kapatildi.
      // ⚠️ YAPMA: `bekletmeAcik` kontrolunu kaldirip dogrudan `parkEt()` cagirma.
      if (beklet && ActiveCallController.bekletmeAcik) {
        await ctrl.parkEt();
      } else {
        await ctrl.leave(notifyServer: true);
        // TURU 66: kullanici ne oldugunu GORSUN (main.dart CallKit yolundaki
        // bildirimin karsiligi). ⚠️ Bu widget Navigator DISINDA olabilir ->
        // `ScaffoldMessenger.of(context)` KULLANMA, kok anahtari kullan.
        rootMessengerKey.currentState?.showSnackBar(const SnackBar(
            content: Text('Önceki arama sonlandırıldı'),
            duration: Duration(seconds: 2)));
      }
    } catch (_) {}
    await _accept(zorla: true);
  }

  Future<void> _accept({bool zorla = false}) async {
    if (_busy && !zorla) return;
    if (mounted) setState(() => _busy = true);
    // FAZ-1B HIZ: zil durdurmayi BEKLEME (nesil jetonu + dispose'taki durdur yarisi zaten
    // koruyor) + izinleri answer REST'iyle PARALEL iste (verilmisse anlik doner; _connect'in
    // kendi request'i artik cache'ten cikar).
    unawaited(CallSounds.durdur(_zilNesli));
    final izinF = [
      Permission.microphone,
      if (widget.call.video) Permission.camera,
    ].request();

    // Bu widget Navigator'in DISINDA yasar (MaterialApp.builder), bu yuzden
    // Navigator.of(context) kullanilamaz — kok Navigator anahtarini kullaniyoruz.
    final notifier = ref.read(callServiceProvider.notifier);
    try {
      final info = await notifier.answer(widget.call.callId, zorla: zorla);
      if (info == null) {
        // Arama zaten baska yoldan (CallKit) kabul edildi -> ekrani acma
        unawaited(izinF.catchError((_) => <Permission, PermissionStatus>{}));
        notifier.dismiss();
        return;
      }
      // Android es-zamanli ikinci request firlatir -> baslat'in _connect izni oncesi bitmis olsun
      await izinF;
      // TEST TURU 28 (kullanici: "kabul edince 2sn sonra PATLAMA"): gelen-arama ekranindaki
      // ONIZLEME KAMERASINI KAPATIP arama ekraninda YENIDEN ACIYORDUK -> kamera kapan/ac
      // ~0.5-1sn siyah + gorsel sicrama. Artik track OLDUGU GIBI DEVREDILIR (canli yayin
      // P1 devir deseni) — kamera hic kapanmaz, gorunt kesintisiz. ⚠️ YAPMA: burada
      // _onizlemeKapat cagirip controller'da yeniden acma.
      final bool kameraDevam = widget.call.video && _kameraSecimi;
      final devirKamera = kameraDevam ? _onizleme : null;
      if (devirKamera != null) {
        _onizleme = null; // dispose kapatmasin — sahiplik controller'a gecti
      } else {
        await _onizlemeKapat();
      }

      // FAZ-C: mantik controller'da; ekran saf gorunum (rootNavigatorKey ile acilir)
      final ctrl = ref.read(activeCallProvider);
      unawaited(ctrl.baslat(AramaBilgisi(
        callId: widget.call.callId,
        url: info['url'] as String,
        token: info['token'] as String,
        video: widget.call.video,
        peerName: widget.call.callerName,
        outgoing: false,
        isGroup: widget.call.isGroup,
        chatTitle: widget.call.chatTitle,
        elapsedMs: (info['elapsed_ms'] as num?)?.toInt(), // sure senkronu: gecen-sure baslangici
      ),
          micAcik: _mikSecimi,
          kameraAcik: kameraDevam,
          hazirKamera: devirKamera));
      ctrl.ekraniAc();
      notifier.dismiss(); // arama ekrani acildiktan SONRA gelen arama ekranini kaldir
    } catch (e) {
      rootMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      notifier.dismiss();
      await notifier.end(widget.call.callId); // arayan sonsuza kadar beklemesin
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    await CallSounds.durdur(_zilNesli);
    // TEST TURU 36: bu ekran artik CallKit KABULUNDEN SONRA da acilabiliyor (grup daveti,
    // turu 35). O durumda sistemde AKTIF bir CallKit aramasi vardir; "Yok say" derken onu
    // da kapatmazsak iPhone'da HAYALET arama asili kalir (ve kapanisinda ses birimi baska
    // aramayi bozar). Idempotent — WS yolunda no-op.
    unawaited(CallKitService.bitir(widget.call.callId));
    await _onizlemeKapat(); // kamera acik kalmasin
    await ref.read(callServiceProvider.notifier).end(widget.call.callId);
  }

  /// GRUP DAVET EKRANI (test turu 21 — WhatsApp duzeni): arkada KENDI kamera onizlemem,
  /// ortada kamera/mikrofon ON-AYAR dugmeleri, altta kart: "X ve N kisi daha" + Yok say/Katil.
  Widget _grupDavetGorunumu(IncomingCall call) {
    final onizleme = _onizleme;
    final baslik = call.chatTitle.isNotEmpty ? call.chatTitle : call.callerName;
    final altBaslik = call.participantCount > 2
        ? '${call.callerName} ve ${call.participantCount - 1} kişi daha'
        : call.callerName;
    return Material(
      color: const Color(0xFF0B141A),
      child: Stack(fit: StackFit.expand, children: [
        // Arka plan: kendi kameram (kapaliysa koyu zemin)
        if (onizleme != null && _kameraSecimi)
          IgnorePointer(
            child: lk.VideoTrackRenderer(onizleme,
                key: ValueKey('davet-${onizleme.sid}'),
                fit: lk.VideoViewFit.cover,
                mirrorMode: lk.VideoViewMirrorMode.mirror),
          )
        else
          Container(color: const Color(0xFF0B141A)),
        SafeArea(
          child: Column(children: [
            const SizedBox(height: 28),
            Text(baslik,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 8)])),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(call.video ? LucideIcons.video : LucideIcons.phone,
                  size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Text('Grup araması',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 15)),
            ]),
            const Spacer(),
            // KAMERA / MIKROFON ON-AYARI (WhatsApp: katilmadan once kapatabilirsin)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (call.video)
                _onAyarBtn(
                  acik: _kameraSecimi,
                  acikIkon: LucideIcons.video,
                  kapaliIkon: LucideIcons.videoOff,
                  onTap: () => setState(() => _kameraSecimi = !_kameraSecimi),
                ),
              if (call.video) const SizedBox(width: 18),
              _onAyarBtn(
                acik: _mikSecimi,
                acikIkon: LucideIcons.mic,
                kapaliIkon: LucideIcons.micOff,
                onTap: () => setState(() => _mikSecimi = !_mikSecimi),
              ),
            ]),
            const SizedBox(height: 22),
            // ALT KART: kim davet etti + Yok say / Katil
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xF21F2C34),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                        color: Color(0xFF25D366), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(altBaslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF6C2BD9),
                    backgroundImage: call.callerAvatar.isNotEmpty
                        ? NetworkImage(call.callerAvatar)
                        : null,
                    child: call.callerAvatar.isEmpty
                        ? Text(
                            call.callerName.isNotEmpty
                                ? call.callerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14))
                        : null,
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2A3942),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: _busy ? null : _reject,
                      child: const Text('Yok say',
                          style: TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: _busy ? null : () => _accept(),
                      child: const Text('Katıl',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _onAyarBtn({
    required bool acik,
    required IconData acikIkon,
    required IconData kapaliIkon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: acik ? Colors.white : const Color(0xFF2A3942),
          shape: BoxShape.circle,
        ),
        child: Icon(acik ? acikIkon : kapaliIkon,
            color: acik ? const Color(0xFF0B141A) : Colors.white, size: 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    // GRUP DAVETI (test turu 21): WhatsApp tarzi onizlemeli ekran. 1:1 arama ekrani AYNEN kalir.
    if (_grupDavet && !call.waiting) return _grupDavetGorunumu(call);
    final onizleme = _onizleme;
    return Material(
      color: const Color(0xFF0B141A),
      child: Stack(fit: StackFit.expand, children: [
        // TEST TURU 26: GORUNTULU gelen aramada arka planda KENDI kameram (WhatsApp gibi)
        if (onizleme != null && call.video)
          IgnorePointer(
            child: lk.VideoTrackRenderer(onizleme,
                key: ValueKey('gelen-${onizleme.sid}'),
                fit: lk.VideoViewFit.cover,
                mirrorMode: lk.VideoViewMirrorMode.mirror),
          ),
        if (onizleme != null && call.video)
          Container(color: Colors.black.withValues(alpha: 0.35)),
        SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white24,
              backgroundImage:
                  call.callerAvatar.isNotEmpty ? NetworkImage(call.callerAvatar) : null,
              child: call.callerAvatar.isEmpty
                  ? Text(
                      call.callerName.isNotEmpty ? call.callerName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 44, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            // GRUP: baslik grup adi, alt satir "Grup sesli/goruntulu aramasi · baslatan"
            Text(call.isGroup && call.chatTitle.isNotEmpty ? call.chatTitle : call.callerName,
                style: const TextStyle(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
                call.isGroup
                    ? (call.video
                        ? 'Grup görüntülü araması · ${call.callerName}'
                        : 'Grup sesli araması · ${call.callerName}')
                    : (call.video ? 'Görüntülü arama' : 'Sesli arama'),
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const Spacer(flex: 3),
            // ARAMA BEKLETME (test turu 18): bu arama BEN BASKA GORUSMEDEYKEN geldiyse
            // (sunucu `waiting:true`) telefonun kendi ekrani gibi UC secenek gosterilir.
            if (call.waiting)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _bigButton(
                      color: const Color(0xFFE53935),
                      icon: LucideIcons.phoneOff,
                      label: 'Reddet',
                      onTap: _reject,
                      kucuk: true,
                    ),
                    _bigButton(
                      color: const Color(0xFFEF6C00),
                      icon: LucideIcons.phoneOff,
                      label: 'Bitir ve\nkabul et',
                      onTap: () => _bekletVeyaBitirKabul(beklet: false),
                      kucuk: true,
                    ),
                    // ⚠️⚠️ TURU 66 — "Beklet ve kabul et" YALNIZ bekletme ACIKKEN cizilir.
                    // Denetim bulgusu: bayrak kapatilinca bu dugme EKRANDA KALIYOR ama
                    // gorevi degisiyordu — basan kullanici "bekletiyorum" sanarken
                    // gorusme BITIYORDU. Bu Android'in BIRINCIL ikinci-arama arayuzu.
                    // ⚠️ YAPMA: bayrak kapaliyken bu dugmeyi gosterme.
                    if (ActiveCallController.bekletmeAcik)
                      _bigButton(
                        color: const Color(0xFF25D366),
                        icon: LucideIcons.pause,
                        label: 'Beklet ve\nkabul et',
                        onTap: () => _bekletVeyaBitirKabul(beklet: true),
                        kucuk: true,
                      ),
                  ],
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _bigButton(
                    color: const Color(0xFFE53935),
                    icon: LucideIcons.phoneOff,
                    label: 'Reddet',
                    onTap: _reject,
                  ),
                  _bigButton(
                    color: const Color(0xFF25D366),
                    icon: call.video ? LucideIcons.video : LucideIcons.phone,
                    label: 'Kabul et',
                    onTap: _accept,
                  ),
                ],
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
      ]),
    );
  }

  Widget _bigButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool kucuk = false, // 3 secenek yan yana sigsin (arama bekletme)
  }) {
    final cap = kucuk ? 60.0 : 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _busy ? null : onTap,
          child: Container(
            width: cap,
            height: cap,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: kucuk ? 26 : 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: kucuk ? 12 : 14)),
      ],
    );
  }
}

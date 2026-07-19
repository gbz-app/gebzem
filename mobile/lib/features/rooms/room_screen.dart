import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/api.dart';
import '../../core/ws.dart';
import '../calls/call_media_options.dart';
import '../calls/call_provider.dart';
import '../calls/call_room_lock.dart';
import '../home/home_screen.dart' show myProfileProvider;
import 'room_provider.dart';

/// SPACES ODA EKRANI — host + konusmacilar + dinleyiciler + el kaldirma.
/// In-app (CallKit/zil YOK). Rol kaynagi SUNUCU (DB): terfi/dusurme WS 'room.role.changed'
/// ile gelir; LiveKit izni sunucu UpdateParticipant ile CANLIYA itilir (token yenilenmez).
/// SES YASAM DONGUSU call_screen'in kanitlanmis desenleridir (CallRoomLock + iOS ses sirasi
/// + timeout'lu teardown) — o dosyaya DOKUNULMADAN kopyalandi.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({
    super.key,
    required this.roomId,
    required this.lkRoom,
    required this.url,
    required this.token,
    required this.rol,
    required this.baslik,
    required this.hostId,
  });

  final String roomId;
  final String lkRoom; // "oda_<id>"
  final String url;
  final String token;
  final String rol; // host | speaker | listener (giris ani; WS ile degisebilir)
  final String baslik;
  final String hostId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> with WidgetsBindingObserver {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  StreamSubscription? _wsSub;
  Timer? _rosterTimer;
  String _benimId = ''; // kendi user_id (WS rol olayi icin; LiveKit identity'e GUVENME —
  // baglanti tamamlanmadan null kalir ve erken gelen room.role.changed kacar)

  late String _rol = widget.rol;
  bool _connecting = true;
  bool _micOn = false;
  bool _elKalkik = false;
  bool _ayrildi = false; // tek-seferlik cikis kilidi (cift pop = siyah ekran)
  bool _kapandi = false; // oda bir kez kapatildi mi
  String? _hata;

  // Roster (kaynak: sunucu detayi + WS olaylari; LiveKit listesi yalniz isSpeaking icin)
  List<Map<String, dynamic>> _konusmacilar = [];
  List<Map<String, dynamic>> _eller = []; // yalniz host gorur
  int _dinleyici = 0;

  late final CallService _svc;

  static const _audioCh = MethodChannel('gebzem/audio');

  @override
  void initState() {
    super.initState();
    _svc = ref.read(callServiceProvider.notifier);
    // MESGUL MUHAFIZI: odadayken 1:1 arama baslatilamaz/kabul edilemez (mevcut public
    // kume — arama koduna dokunmadan entegre). Cikista birakilir.
    _svc.ekranAcildi('oda_${widget.roomId}');
    WidgetsBinding.instance.addObserver(this); // kesinti toparlama (resume)
    // Kendi kimligim: WS rol olaylari LiveKit baglantisindan ONCE gelebilir.
    ref.read(myProfileProvider.future).then((p) {
      _benimId = p['id'] as String? ?? '';
    }).catchError((_) {});
    _wsSub = ref.read(wsProvider).events.listen(_wsOlay);
    _rosterTimer = Timer.periodic(const Duration(seconds: 10), (_) => _detayYenile());
    _baglan();
    _detayYenile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // KESINTI TOPARLAMA (call_screen _kesintidenTopla dengi — dogrulama bulgusu):
    // GSM/Siri/alarm kesintisi sonrasi iOS ses birimi kendiliginden geri gelmez.
    if (state == AppLifecycleState.resumed && mounted && !_ayrildi) {
      _sesiAc(true);
      if (_rol != 'listener') {
        _room?.localParticipant?.setMicrophoneEnabled(_micOn);
      }
      _detayYenile();
    }
  }

  Future<void> _baglan() async {
    try {
      // Dinleyicide mikrofon IZNI HIC ISTENMEZ; konusmaci/host icin sart.
      if (_rol != 'listener') {
        final st = await Permission.microphone.request();
        if (st != PermissionStatus.granted) {
          setState(() {
            _hata = 'Konusmak icin mikrofon izni gerekli';
            _connecting = false;
          });
          return;
        }
      }
      await CallRoomLock.calistir(_odayaBaglan);
      if (!mounted) return;
      setState(() => _connecting = false);
    } catch (e) {
      await Sentry.captureException(e, stackTrace: StackTrace.current);
      if (mounted) {
        setState(() {
          _hata = 'Odaya baglanilamadi.\nTekrar deneyin.';
          _connecting = false;
        });
      }
    }
  }

  Future<void> _odayaBaglan() async {
    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: kAudioCaptureOptions,
        defaultAudioPublishOptions: kAudioPublishOptions,
      ),
    );
    _room = room; // HEMEN ata: baglanirken cikilirsa _kapatOda bulabilsin (sizinti olmasin)

    try {
      _listener = room.createListener();
      _listener!
        ..on<lk.ActiveSpeakersChangedEvent>((_) {
          if (mounted) setState(() {}); // konusan halkasi
        })
        ..on<lk.ParticipantConnectedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.ParticipantDisconnectedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<lk.TrackMutedEvent>((e) {
          // Buton durumunu senkronla. SNACKBAR YOK: bu olay KENDI mute'umda da tetiklenir
          // (dogrulama bulgusu) — "host susturdu" bildirimi WS room.participant.muted'dan gelir.
          if (mounted && e.participant is lk.LocalParticipant) {
            setState(() => _micOn = false);
          }
        })
        ..on<lk.RoomDisconnectedEvent>((_) {
          // DeleteRoom / at / kalici ag kopmasi -> ekrandan cik. Sunucuya AYRIL gonder
          // (dogrulama bulgusu: bildirmezsek DB'de 'joined' kalir, sweep host kopmasini
          // goremez, host 'zaten acik odaniz var' kilidine girer). Ayril idempotent —
          // oda coktan bittiyse zararsiz 200.
          if (mounted) _cik(sunucuyaBildir: true);
        });

      await room.connect(
        widget.url,
        widget.token,
        connectOptions: const lk.ConnectOptions(
          autoSubscribe: true,
          // TR operator NAT'i: medya HER ZAMAN TURN relay (1:1 aramayla ayni karar)
          rtcConfiguration: lk.RTCConfiguration(
            iceTransportPolicy: lk.RTCIceTransportPolicy.relay,
          ),
        ),
      );
      // Ekran baglanirken kapandiysa odayi birak (mic acilip yayina sizmasin — dogrulama bulgusu)
      if (!mounted || _ayrildi) {
        await _kapatOda();
        return;
      }
      // iOS SES SIRASI (v7/v8 dersi — AYNEN): mic/rota HAZIR olmadan ses birimi acilmaz.
      // Sira: (konusmaciysa) mic -> hoparlor -> _sesiAc(true) EN SON.
      if (_rol != 'listener') {
        await room.localParticipant?.setMicrophoneEnabled(true);
        _micOn = true;
      }
      await room.setSpeakerOn(true); // ODA VARSAYILANI HOPARLOR (dinleme senaryosu; 1:1'in tersi)
      await _sesiAc(true);
    } catch (e) {
      await _kapatOda(); // yarim kalan odayi temizle
      rethrow;
    }
  }

  /// iOS foreground ses birimi (AppDelegate 'gebzem/audio'). Android'de no-op.
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
    // timeout SART: hang, CallRoomLock zincirini kilitler (sonraki arama/oda baglanamaz)
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

  // ---- WS olaylari (rol kaynagi sunucu) ----
  void _wsOlay(Map<String, dynamic> ev) {
    final p = (ev['payload'] is Map)
        ? (ev['payload'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    if (p['room_id'] != widget.roomId) return;
    // Kimlik: profile'dan (erken/kesin); LiveKit identity yalniz yedek (baglanmadan null).
    final benimId =
        _benimId.isNotEmpty ? _benimId : (_room?.localParticipant?.identity ?? '');

    switch (ev['type']) {
      case 'room.role.changed':
        final uid = p['user_id'] as String?;
        final yeniRol = p['role'] as String? ?? 'listener';
        if (uid != null && uid == benimId) {
          _rolDegisti(yeniRol);
        }
        _detayYenile();
      case 'room.hand.raised':
        // yalniz host'a gelir
        final uid = p['user_id'] as String? ?? '';
        setState(() {
          _eller.removeWhere((e) => e['user_id'] == uid);
          if (p['raised'] == true) {
            _eller.add({
              'user_id': uid,
              'name': p['name'] ?? '',
              'avatar': p['avatar'] ?? '',
            });
          }
        });
      case 'room.participant.joined':
      case 'room.participant.left':
        final n = (p['listener_count'] as num?)?.toInt();
        if (n != null) setState(() => _dinleyici = n);
        _detayYenile();
      case 'room.participant.muted':
        // Host susturmasi bildirimi YALNIZ buradan (host aksiyonunda gelir; TrackMuted
        // kendi mute'unda da tetiklendigi icin oradan gosterilmez — dogrulama bulgusu).
        if (p['user_id'] == benimId && mounted) {
          setState(() => _micOn = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Host seni susturdu — konuşmak için mikrofonu tekrar aç')));
        }
        _detayYenile();
      case 'room.removed':
        _atildim();
      case 'room.ended':
        if (mounted && !_ayrildi) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Oda sona erdi')));
          _cik(sunucuyaBildir: false);
        }
    }
  }

  /// Terfi/dusurme BANA geldi: mikrofonu role gore ac/kapa. LiveKit izni sunucudan
  /// zaten itildi (ParticipantPermissionsUpdated) — token yenileme GEREKMEZ.
  Future<void> _rolDegisti(String yeniRol) async {
    final eski = _rol;
    setState(() => _rol = yeniRol);
    if (eski == 'listener' && yeniRol == 'speaker') {
      final st = await Permission.microphone.request();
      if (st != PermissionStatus.granted) {
        // DURUST DAVRAN (dogrulama bulgusu): sunucu beni konusmaci SAYIYOR; "dinleyici
        // olarak devam" deme. Rol konusmaci kalir, mic kapali — butona basinca izin
        // yeniden istenir. UI konusmaci moduna gecer (mic kapali gorunur).
        if (mounted) {
          setState(() {
            _micOn = false;
            _elKalkik = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Konuşmacı yapıldın ama mikrofon izni yok — mikrofon butonuna basıp izin ver')));
        }
        return;
      }
      try {
        await _room?.localParticipant?.setMicrophoneEnabled(true);
        if (mounted) {
          setState(() {
            _micOn = true;
            _elKalkik = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🎙️ Artık konuşmacısın!')));
        }
      } catch (e) {
        Sentry.captureException(e, stackTrace: StackTrace.current);
        // LiveKit izni henuz ulasmamis olabilir (nadir yaris) — kullaniciya soyle
        if (mounted) {
          setState(() => _micOn = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Mikrofon açılamadı — mikrofon butonuyla tekrar dene')));
        }
      }
    } else if (yeniRol == 'listener') {
      try {
        await _room?.localParticipant?.setMicrophoneEnabled(false);
      } catch (_) {}
      if (mounted) {
        setState(() => _micOn = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dinleyiciye alındın')));
      }
    }
  }

  void _atildim() {
    if (!mounted || _ayrildi) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Odadan çıkarıldın'),
        content: const Text('Oda sahibi seni odadan çıkardı.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(), child: const Text('Tamam')),
        ],
      ),
    ).then((_) => _cik(sunucuyaBildir: false));
  }

  Future<void> _detayYenile() async {
    if (!mounted || _ayrildi) return;
    try {
      final d = await ref.read(roomsApiProvider).detay(widget.roomId);
      if (!mounted || _ayrildi) return;
      if (d['status'] == 'ended') {
        _cik(sunucuyaBildir: false);
        return;
      }
      setState(() {
        _konusmacilar =
            (d['speakers'] as List? ?? const []).cast<Map<String, dynamic>>();
        _dinleyici = (d['listener_count'] as num?)?.toInt() ?? 0;
        if (_rol == 'host') {
          _eller = (d['hands'] as List? ?? const []).cast<Map<String, dynamic>>();
        }
      });
    } catch (_) {
      // gecici ag hatasi — bir sonraki tur duzeltir
    }
  }

  // ---- kullanici eylemleri ----
  Future<void> _cik({required bool sunucuyaBildir}) async {
    if (_ayrildi) return;
    _ayrildi = true;
    _svc.ekranKapandi('oda_${widget.roomId}'); // arama muhafizini birak
    // Teardown'i AYRILMA ANINDA kilit sirasina koy (dispose ~300ms gec kalir; seri
    // gecis yarisi — call_screen v3 dersi). dispose'daki enqueue safety-net kalir.
    unawaited(CallRoomLock.calistir(_kapatOda));
    if (sunucuyaBildir) {
      try {
        await ref.read(roomsApiProvider).ayril(widget.roomId);
      } catch (_) {}
    }
    if (mounted) {
      // BLOCKER DUZELTMESI (dogrulama): duz pop() EN USTTEKI rotayi kapatir — sheet/dialog
      // acikken RoomScreen ekranda kalir ve _ayrildi kilidi kullaniciyi OLU ekrana hapseder.
      // Once oda rotasina KADAR pop (ustteki tum modaller kapanir), sonra odayi kapat.
      final nav = Navigator.of(context);
      nav.popUntil((r) => r.settings.name == 'oda-${widget.roomId}' || r.isFirst);
      if (nav.canPop()) nav.pop();
    }
  }

  Future<void> _odayiBitir() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Odayı bitir?'),
        content: const Text('Oda herkes için kapanır.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Bitir')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await ref.read(roomsApiProvider).bitir(widget.roomId);
    } catch (_) {}
    _cik(sunucuyaBildir: false); // end zaten herkesi (beni de) kapatir
  }

  Future<void> _micDegistir() async {
    final on = !_micOn;
    if (on) {
      // Izin reddedilmis konusmaci butondan tekrar deneyebilsin (terfi-izin bulgusu)
      final st = await Permission.microphone.request();
      if (st != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mikrofon izni gerekli')));
        }
        return;
      }
    }
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(on);
      setState(() => _micOn = on);
    } catch (e) {
      Sentry.captureException(e, stackTrace: StackTrace.current);
    }
  }

  Future<void> _elDegistir() async {
    final yeni = !_elKalkik;
    try {
      await ref.read(roomsApiProvider).elKaldir(widget.roomId, yeni);
      setState(() => _elKalkik = yeni);
      if (yeni && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El kaldırdın — host onaylarsa konuşabilirsin')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  // ---- host katilimci sheet'i ----
  void _katilimcilarSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (c2, scroll) => StatefulBuilder(builder: (c3, refresh) {
          Future<void> aksiyon(Future<void> Function() f) async {
            try {
              await f();
              await _detayYenile();
              refresh(() {});
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
              }
            }
          }

          final api = ref.read(roomsApiProvider);
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Katılımcılar', style: Theme.of(c3).textTheme.titleLarge),
              if (_eller.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('✋ El kaldıranlar',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                for (final e in _eller)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                        child: Text((e['name'] as String? ?? '?').isNotEmpty
                            ? (e['name'] as String)[0].toUpperCase()
                            : '?')),
                    title: Text(e['name'] as String? ?? ''),
                    trailing: FilledButton(
                      onPressed: () =>
                          aksiyon(() => api.konusmaciYap(widget.roomId, e['user_id'] as String)),
                      child: const Text('Konuşmacı yap'),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              const Text('🎙️ Konuşmacılar',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              for (final k in _konusmacilar)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      child: Text((k['name'] as String? ?? '?').isNotEmpty
                          ? (k['name'] as String)[0].toUpperCase()
                          : '?')),
                  title: Text(k['name'] as String? ?? ''),
                  subtitle: Text(k['role'] == 'host' ? 'Oda sahibi' : 'Konuşmacı'),
                  trailing: k['role'] == 'host'
                      ? null
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Sustur',
                            icon: const Icon(LucideIcons.micOff),
                            onPressed: () =>
                                aksiyon(() => api.sustur(widget.roomId, k['user_id'] as String)),
                          ),
                          IconButton(
                            tooltip: 'Dinleyiciye indir',
                            icon: const Icon(LucideIcons.arrowDown),
                            onPressed: () => aksiyon(
                                () => api.dinleyiciYap(widget.roomId, k['user_id'] as String)),
                          ),
                          IconButton(
                            tooltip: 'Odadan at',
                            icon: const Icon(LucideIcons.userX, color: Colors.redAccent),
                            onPressed: () =>
                                aksiyon(() => api.at(widget.roomId, k['user_id'] as String)),
                          ),
                        ]),
                ),
              const SizedBox(height: 8),
              Text('🎧 $_dinleyici dinleyici',
                  style: TextStyle(color: Theme.of(c3).colorScheme.outline)),
            ],
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _svc.ekranKapandi('oda_${widget.roomId}');
    WidgetsBinding.instance.removeObserver(this);
    _wsSub?.cancel();
    _rosterTimer?.cancel();
    unawaited(CallRoomLock.calistir(_kapatOda)); // safety-net (idempotent)
    super.dispose();
  }

  // ---- UI ----
  bool _konusuyorMu(String userId) {
    final r = _room;
    if (r == null) return false;
    if (r.localParticipant?.identity == userId) {
      return r.localParticipant?.isSpeaking ?? false;
    }
    for (final p in r.remoteParticipants.values) {
      if (p.identity == userId) return p.isSpeaking;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cik(sunucuyaBildir: true); // geri tusu = odadan ayril
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        body: Stack(children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A0B2E), Color(0xFF0B141A)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(children: [
              // Ust bilgi
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.baslik,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          _connecting
                              ? 'Bağlanıyor...'
                              : (_hata ?? '🎧 $_dinleyici dinleyici'),
                          style: const TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  if (_rol == 'host' && _eller.isNotEmpty)
                    Badge(
                      label: Text('${_eller.length}'),
                      child: IconButton(
                        icon: const Icon(LucideIcons.hand, color: Colors.amber),
                        onPressed: _katilimcilarSheet,
                      ),
                    ),
                ]),
              ),
              // Konusmaci izgarasi
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Wrap(
                    spacing: 22,
                    runSpacing: 22,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final k in _konusmacilar)
                        _konusmaciAvatar(k, _konusuyorMu(k['user_id'] as String? ?? '')),
                    ],
                  ),
                ),
              ),
              // Alt kontrol bari (role gore)
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_rol == 'listener') ...[
                      _ctrl(
                        icon: LucideIcons.hand,
                        active: _elKalkik,
                        // ETIKET FIX (kullanici bulgusu): eski metin "El indirildi" idi —
                        // kullanici eli ANINDA indi sandi. Kalkikken eylem: "Eli indir".
                        label: _elKalkik ? 'Eli indir' : 'El kaldır',
                        onTap: _elDegistir,
                      ),
                      const SizedBox(width: 20),
                    ] else ...[
                      _ctrl(
                        icon: _micOn ? LucideIcons.mic : LucideIcons.micOff,
                        active: !_micOn,
                        label: _micOn ? 'Mikrofon' : 'Kapalı',
                        onTap: _micDegistir,
                      ),
                      const SizedBox(width: 20),
                    ],
                    if (_rol == 'host') ...[
                      _ctrl(
                        icon: LucideIcons.users,
                        label: 'Katılımcılar',
                        onTap: _katilimcilarSheet,
                      ),
                      const SizedBox(width: 20),
                    ],
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(
                        onTap: _rol == 'host'
                            ? _odayiBitir
                            : () => _cik(sunucuyaBildir: true),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                              color: Color(0xFFE53935), shape: BoxShape.circle),
                          child: Icon(
                              _rol == 'host' ? LucideIcons.power : LucideIcons.logOut,
                              color: Colors.white,
                              size: 26),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_rol == 'host' ? 'Bitir' : 'Ayrıl',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _konusmaciAvatar(Map<String, dynamic> k, bool konusuyor) {
    final ad = k['name'] as String? ?? '';
    final host = k['role'] == 'host';
    return SizedBox(
      width: 96,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C2BD9), Color(0xFF8B3FFF)]),
              border: konusuyor
                  ? Border.all(color: const Color(0xFF25D366), width: 4)
                  : Border.all(color: Colors.white24, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
          ),
          if (host)
            const Positioned(
              top: -6,
              right: -2,
              child: Text('👑', style: TextStyle(fontSize: 20)),
            ),
        ]),
        const SizedBox(height: 8),
        Text(ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]),
    );
  }

  Widget _ctrl({
    required IconData icon,
    required String label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
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
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}

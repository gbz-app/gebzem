import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/ws.dart';
import '../../router.dart';
import '../calls/active_call_controller.dart';
import '../calls/call_provider.dart';
import '../live/live_provider.dart';
import '../live/live_viewer_screen.dart';
import '../rooms/room_provider.dart';
import '../rooms/room_screen.dart';

/// DAVET SERVISI (Bolum 5 I1): stream.invite / room.invite olaylarini dinler, ust banner
/// gosterir, dokununca katilma akisini yurutur. call_provider'a / ws.dart'a /
/// IncomingCallOverlay'e DOKUNMAZ (ayri hafif servis; ayni broadcast stream'i bagimsiz dinler).
class DavetServisi {
  DavetServisi(this._ref) {
    _sub = _ref.read(wsProvider).events.listen(_onEvent);
  }

  final Ref _ref;
  StreamSubscription? _sub;
  Timer? _gizleme;

  void _onEvent(Map<String, dynamic> ev) {
    final tip = ev['type'];
    if (tip != 'stream.invite' && tip != 'room.invite') return;
    final p = (ev['payload'] is Map)
        ? (ev['payload'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    _bannerGoster(
      tip == 'stream.invite' ? 'yayin' : 'oda',
      (tip == 'stream.invite' ? p['stream_id'] : p['room_id']) as String? ?? '',
      p['title'] as String? ?? '',
      p['from_name'] as String? ?? 'Biri',
    );
  }

  /// FCM push'tan (on planda onMessage) gelen davet — ayni banner.
  void pushtanGoster(Map<String, dynamic> data) {
    final tip = data['type'] == 'stream.invite' ? 'yayin' : 'oda';
    final id = (data['type'] == 'stream.invite' ? data['stream_id'] : data['room_id'])
            as String? ??
        '';
    _bannerGoster(tip, id, data['title'] as String? ?? '',
        data['from_name'] as String? ?? 'Biri');
  }

  void _bannerGoster(String tip, String id, String baslik, String kimden) {
    if (id.isEmpty) return;
    final m = rootMessengerKey.currentState;
    if (m == null) return;
    m.hideCurrentMaterialBanner(); // yeni davet eskisini ezer
    _gizleme?.cancel();
    m.showMaterialBanner(MaterialBanner(
      content: Text(tip == 'yayin'
          ? '$kimden seni canlı yayına davet etti${baslik.isNotEmpty ? ': $baslik' : ''}'
          : '$kimden seni sesli odaya davet etti${baslik.isNotEmpty ? ': $baslik' : ''}'),
      leading: Icon(tip == 'yayin' ? Icons.live_tv : Icons.headphones,
          color: const Color(0xFF6C2BD9)),
      actions: [
        TextButton(
          onPressed: () {
            m.hideCurrentMaterialBanner();
            davetiAc(tip: tip, id: id, baslik: baslik);
          },
          child: Text(tip == 'yayin' ? 'İzle' : 'Katıl',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: m.hideCurrentMaterialBanner,
          child: const Text('Kapat'),
        ),
      ],
    ));
    _gizleme = Timer(const Duration(seconds: 15), () {
      rootMessengerKey.currentState?.hideCurrentMaterialBanner();
    });
  }

  bool _aciliyor = false; // TARAMA #8: re-entrancy kilidi (cift dokunus / banner+tepsi)

  /// Davete dokununca katilma akisi (banner + push yonlendirme ORTAK yolu).
  /// Muhafizlar: re-entrancy + aramadaMi + REST-sonrasi tekrar (Spaces dersi) + zaten-iceride.
  Future<void> davetiAc({required String tip, required String id, String baslik = ''}) async {
    if (_aciliyor) return; // TARAMA #8: ikinci dokunus REST penceresinde cift katilim yapardi
    _aciliyor = true;
    try {
      await _davetiAcGovde(tip: tip, id: id, baslik: baslik);
    } finally {
      _aciliyor = false;
    }
  }

  Future<void> _davetiAcGovde(
      {required String tip, required String id, String baslik = ''}) async {
    final svc = _ref.read(callServiceProvider.notifier);
    void mesaj(String t) =>
        rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(t)));

    final ekranId = tip == 'yayin' ? 'yayin_$id' : 'oda_$id';
    if (svc.ekrandakiAramalar.contains(ekranId)) return; // zaten icerideyim
    if (svc.aramadaMi) {
      // C5: minimize edilmis arama varsa "Aramaya don" kisayolu
      final ctrl = _ref.read(activeCallProvider);
      rootMessengerKey.currentState?.showSnackBar(SnackBar(
        content: const Text('Önce aramayı/odayı bitirin'),
        action: ctrl.arama != null
            ? SnackBarAction(label: 'Aramaya dön', onPressed: ctrl.restore)
            : null,
      ));
      return;
    }
    // TARAMA #9: REST-sonrasi kontrol KENDI ekranId'mi HARIC tutar — manuel yoldan ayni
    // odaya/yayina coktan girdiysem 'ayril' GONDERMEK sunucu kaydimi bozar (sessiz cik);
    // rollback yalniz BASKA bir arama/oda araya girdiyse.
    try {
      if (tip == 'yayin') {
        final info = await _ref.read(liveApiProvider).izle(id);
        if (svc.ekrandakiAramalar.contains(ekranId)) return; // manuel yol kazandi
        if (svc.ekrandakiAramalar.any((x) => x != ekranId)) {
          unawaited(_ref.read(liveApiProvider).ayril(id));
          mesaj('Aramadasınız — yayına girilmedi');
          return;
        }
        rootNavigatorKey.currentState?.push(MaterialPageRoute(
          settings: RouteSettings(name: 'yayin-$id'),
          builder: (_) => LiveViewerScreen(
            streamId: id,
            lkRoom: info['room'] as String,
            url: info['url'] as String,
            token: info['token'] as String,
            baslik: info['title'] as String? ?? baslik,
            yayinciId: info['broadcaster_id'] as String? ?? '',
            yayinciAd: info['broadcaster_name'] as String? ?? '',
            durum: info['status'] as String? ?? 'live',
            ilkIzleyici: (info['viewer_count'] as num?)?.toInt() ?? 0,
            tip: info['type'] as String? ?? 'video',
            ilkKonukId: info['guest_id'] as String? ?? '',
          ),
        ));
      } else {
        final info = await _ref.read(roomsApiProvider).katil(id);
        if (svc.ekrandakiAramalar.contains(ekranId)) return; // manuel yol kazandi
        if (svc.ekrandakiAramalar.any((x) => x != ekranId)) {
          unawaited(_ref.read(roomsApiProvider).ayril(id));
          mesaj('Aramadasınız — odaya katılınmadı');
          return;
        }
        rootNavigatorKey.currentState?.push(MaterialPageRoute(
          settings: RouteSettings(name: 'oda-$id'),
          builder: (_) => RoomScreen(
            roomId: id,
            lkRoom: info['room'] as String,
            url: info['url'] as String,
            token: info['token'] as String,
            rol: info['role'] as String? ?? 'listener',
            baslik: info['title'] as String? ?? baslik,
            hostId: info['host_id'] as String? ?? '',
          ),
        ));
      }
    } catch (e) {
      mesaj(apiErrorMessage(e));
    }
  }

  void dispose() {
    _sub?.cancel();
    _gizleme?.cancel();
  }
}

final davetServisiProvider = Provider<DavetServisi>((ref) {
  final s = DavetServisi(ref);
  ref.onDispose(s.dispose);
  return s;
});

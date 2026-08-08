import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/ws.dart';

/// ⚠️⚠️ TURU 76 — OKUNMAMIS BILDIRIM SAYACI (rozet).
///
/// ⚠️ NEDEN VAR: bildirim rozeti/sayaci uygulamada HIC YOKTU. Zil ikonu duz bir
///    `IconButton`di; bildirim gelse bile kullanici GORSEL OLARAK hicbir sey
///    gormuyordu ve ancak zile tesadufen basarsa fark ediyordu. Sosyal bildirim
///    (begeni/yorum/takip) zaten WS/push GONDERMIYORDU (bkz. internal/bildirim) —
///    ikisi birlesince ozellik pratikte GORUNMEZDI.
///
/// ⚠️ UC KAYNAKTAN BESLENIR:
///   (1) acilista + WS her (yeniden) baglandiginda REST (`/notifications/count`),
///   (2) WS `bildirim.yeni` olayinda YEREL +1 (anlik; ag gidis-donusu YOK),
///   (3) Bildirimler sayfasi acilinca `sifirla()`.
///
/// ⚠️ YAPMA: her WS olayinda REST cagirma — akis/sohbet olaylari da bu akistan
///    geciyor; sayac icin ag istegi patlamasi olusur.
class BildirimSayaci extends StateNotifier<int> {
  BildirimSayaci(this._ref) : super(0) {
    final ws = _ref.read(wsProvider);
    _sub = ws.events.listen(_olay);
    // ⚠️ Yakalama: uygulama arka plandayken gelen bildirimler WS'te KAYBOLUR
    //    (Redis pub/sub saklamaz); her baglantida sayac sunucudan tazelenir.
    ws.yenidenBaglandiDinle(tazele);
    tazele();
  }

  final Ref _ref;
  StreamSubscription? _sub;

  Future<void> tazele() async {
    try {
      final r = await _ref.read(apiProvider).get('/notifications/count');
      final n = (r.data is Map) ? (r.data['okunmamis'] as num?)?.toInt() : null;
      if (n != null && mounted) state = n;
    } catch (_) {
      // Sessiz: rozet kritik degil, bir sonraki baglantida tazelenir.
    }
  }

  void _olay(Map<String, dynamic> ev) {
    if (ev['type'] == 'bildirim.yeni' && mounted) state = state + 1;
  }

  /// Bildirimler sayfasi acildi — rozet sifirlanir.
  /// ⚠️ Sunucudaki `okundu` isaretlemesi AYRI (`bildirimleriOkudum`); burasi
  ///    yalnizca yerel rozeti dusurur ki kullanici aninda geri bildirim alsin.
  void sifirla() {
    if (mounted) state = 0;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ref.read(wsProvider).yenidenBaglandiBirak(tazele);
    super.dispose();
  }
}

final bildirimSayaciProvider =
    StateNotifierProvider<BildirimSayaci, int>(BildirimSayaci.new);

/// Zil ikonunu rozetle saran yardimci.
/// ⚠️ 99'dan sonra "99+" — dar AppBar'da tasmayi engeller.
class BildirimRozeti extends ConsumerWidget {
  const BildirimRozeti({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adet = ref.watch(bildirimSayaciProvider);
    if (adet <= 0) return child;
    return Badge(
      label: Text(adet > 99 ? '99+' : '$adet'),
      backgroundColor: const Color(0xFFFF3B5C),
      child: child,
    );
  }
}

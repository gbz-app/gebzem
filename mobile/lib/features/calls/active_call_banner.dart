import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'active_call_controller.dart';
import 'mini_izgara.dart';

/// AKTIF ARAMA — minimize edilmis aramada TUM sayfalarin ustunde gorunur.
/// TEST TURU 10: SESLI aramada eski yesil bant; GORUNTULU aramada SURUKLENEBILIR YUZEN
/// VIDEO penceresi (WhatsApp mini oynatici): karsi tarafin videosu + dokun-don + mic/kapat
/// butonlari. Uygulama-ici gezinmede karsi taraf gorunur, cökme yok (uzak track guard'li;
/// arama bitince arama==null -> render durur). Sistem PiP'e (iOS Dusuk Guc Modu/ayar) BAGIMLI
/// DEGIL — %100 Flutter kontrolunde.
/// MaterialApp.builder icinde yasar => Navigator DISINDA: Navigator.of(context) YASAK
/// (restore/leave controller ustunden; rootNavigatorKey).
class AktifAramaBanner extends ConsumerStatefulWidget {
  const AktifAramaBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AktifAramaBanner> createState() => _AktifAramaBannerState();
}

class _AktifAramaBannerState extends ConsumerState<AktifAramaBanner> {
  // Yuzen pencere konumu (null = ilk cizimde sag-uste yerlesir). Surukleyince guncellenir.
  Offset? _pos;
  // TEST TURU 14: kullanici "kucuk ekran biraz buyuk olmali" dedi -> 116x168 yerine
  // 152x232 (9:16'ya yakin, kontrol seridi ile birlikte rahat okunur).
  static const double _w = 152;
  static const double _h = 232;

  /// BEKLEMEDEKI ARAMA SERIDI (test turu 18): aktif arama surerken park edilmis arama
  /// varsa en ustte turuncu serit — dokun: aktif aramayi bitirip beklemedekine DON;
  /// ✕: beklemedeki aramayi bitir.
  Widget _parkSeridi(ActiveCallController c) {
    final p = c.parkEdilen!;
    final ad = p.isGroup
        ? (p.bilgi.chatTitle.isEmpty ? 'Grup araması' : p.bilgi.chatTitle)
        : p.bilgi.peerName;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: const Color(0xFFEF6C00),
        child: SafeArea(
          bottom: false,
          child: InkWell(
            onTap: () async {
              // Aktif arama varsa once onu bitir; leave() beklemedekine OTOMATIK doner.
              if (c.arama != null) {
                await c.leave(notifyServer: true);
              } else {
                await c.devamEt();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(children: [
                const Icon(LucideIcons.pause, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Beklemede: $ad  ·  dokun ve geç',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => c.parkiDusur(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Icon(LucideIcons.x, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(activeCallProvider);
    final b = c.arama;
    // BEKLEMEDEKI ARAMA (test turu 18): aktif arama ekrani acikken de, uygulamada
    // gezerken de en ustte gorunur. PiP/yuzen pencere mantigi ETKILENMEZ.
    final park = c.parkEdilen != null ? _parkSeridi(c) : null;
    // YAPISAL GARANTI (test turu 23 — kullanici ekran goruntusu: ARAMA EKRANI ACIKKEN
    // yuzen pencere de ciziliyordu, ikisi ust uste bindi): arama ekrani GORUNURKEN yuzen
    // pencere ASLA cizilmez. 'minimized' bayragi bayat kalsa bile (restore/PiP yarisi)
    // pencere cikamaz.
    final yuzenGorunur = b != null && c.minimized && !c.ekranGorunur;
    if (park != null && !yuzenGorunur) {
      // Aktif arama ekrani acik (veya arama yok) -> yalniz park seridini bindir
      return Stack(children: [widget.child, park]);
    }
    // ANDROID SISTEM PiP (test turu 14): PiP penceresi HANGI sayfada olursak olalim karsi
    // tarafin videosunu TAM EKRAN gostersin (eskiden yalniz CallScreen ustundeyken calisiyordu;
    // arama kucultulup uygulamada gezerken HOME'a inince PiP'te ana ekran gorunuyordu).
    // widget.child agacta KALIR (Navigator state'i korunur), uzerine opak katman cizilir.
    // KRITIK (test turu 25 — kullanici: 'iPhone'da arama KAPANMIYOR, ekran gidiyor'):
    // iOS'ta sistem PiP penceresinin icerigini NATIVE katman cizer (GebzemPip). Flutter'da
    // AYRICA tam ekran PiP katmani cizmek iPhone'da uygulamanin USTUNU kapatiyor ve
    // DOKUNUSLARI YUTUYORDU -> kirmizi tusa basilamiyor, geri donunce kontroller yok.
    // Bu katman ARTIK YALNIZ ANDROID'de (orada PiP penceresi Flutter agacini gosterir).
    if (b != null && c.pipModunda && Platform.isAndroid) {
      return Stack(children: [
        widget.child,
        Positioned.fill(child: IgnorePointer(child: _pipTamEkran(c, b))),
      ]);
    }
    if (!yuzenGorunur) return widget.child;

    final ad = c.isGroup
        ? (b.chatTitle.isEmpty ? 'Grup araması' : b.chatTitle)
        : b.peerName;

    // SESLI arama -> eski yesil bant (video yok). GORUNTULU -> yuzen video penceresi.
    // TEST TURU 14 KOK-5: `b.video` (baslangic tipi) yerine CANLI goruntulu kapisi —
    // sesli baslayip kamera acilan aramada da yuzen video gorunur (eskiden yesil bantta
    // kaliyordu). c.goruntuluMu = arama tipi video VEYA taraflardan biri kamerayi acmis.
    if (!c.goruntuluMu) {
      return Stack(children: [widget.child, _sesliBant(c, ad)]);
    }
    return Stack(children: [widget.child, _yuzenVideo(c, ad)]);
  }

  /// SISTEM PiP ICERIGI (Android): TEST TURU 17 -> artik IZGARA (2 kisi sol/sag, 3 kisi
  /// ustte 2 + altta 1, 4 kisi ceyrek). 1:1'de karsi taraf + ben. Kontrol/self-view YOK —
  /// PiP penceresinde sistem dugmeleri (mic/kapat) var.
  Widget _pipTamEkran(ActiveCallController c, AramaBilgisi b) {
    final ad = c.isGroup
        ? (b.chatTitle.isEmpty ? 'Grup araması' : b.chatTitle)
        : b.peerName;
    final katilimcilar = c.miniKatilimcilar;
    return Container(
      color: const Color(0xFF0B141A),
      child: katilimcilar.isEmpty
          ? _bantAvatar(ad)
          : miniIzgara([
              for (final k in katilimcilar)
                MiniKutu(track: k.track, harf: k.ad, mirror: k.mirror),
            ]),
    );
  }

  // ---- SESLI ARAMA: ust yesil bant (eski davranis) ----
  Widget _sesliBant(ActiveCallController c, String ad) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: const Color(0xFF25D366),
        child: SafeArea(
          bottom: false,
          child: InkWell(
            onTap: c.restore,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                const Icon(LucideIcons.phone, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.white24,
                  child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const Text('Aramaya dönmek için dokun',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                Text(c.durumMetni,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ---- GORUNTULU ARAMA: suruklenebilir yuzen video penceresi ----
  Widget _yuzenVideo(ActiveCallController c, String ad) {
    final ekran = MediaQuery.of(context).size;
    final guvenli = MediaQuery.of(context).padding;
    // Ilk konum: sag-ust (durum cubugu + bir miktar bosluk altinda)
    var pos = _pos ?? Offset(ekran.width - _w - 12, guvenli.top + 12);
    // STABILITE (test turu 14): ekran donunce / klavye acilinca / kucuk ekranda pencere
    // disari tasabiliyordu — her cizimde ekran icine SIKISTIR.
    final enFazlaX = (ekran.width - _w - 4).clamp(4.0, double.infinity);
    final enFazlaY =
        (ekran.height - _h - guvenli.bottom - 4).clamp(guvenli.top + 4, double.infinity);
    pos = Offset(pos.dx.clamp(4.0, enFazlaX), pos.dy.clamp(guvenli.top + 4, enFazlaY));
    final katilimcilar = c.miniKatilimcilar; // izgara (test turu 17)

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        // Surukle: pencereyi tasi (ekran icinde tut)
        onPanUpdate: (d) {
          final ny = (pos.dy + d.delta.dy)
              .clamp(guvenli.top + 4, ekran.height - _h - guvenli.bottom - 4);
          final nx = (pos.dx + d.delta.dx).clamp(4.0, ekran.width - _w - 4);
          setState(() => _pos = Offset(nx.toDouble(), ny.toDouble()));
        },
        // Videoya dokun -> aramaya don
        onTap: c.restore,
        // TEST TURU 24: golge/siyah zemin KALDIRILDI — sade, kose yuvarlamali video.
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: _w,
              height: _h,
              child: Stack(fit: StackFit.expand, children: [
                // TEST TURU 17: tek video yerine IZGARA (2 sol/sag, 3 ustte2+altta1, 4 ceyrek).
                // Katilimci yoksa (henuz baglanmadi) eski avatar gorunumu.
                if (katilimcilar.isNotEmpty)
                  miniIzgara([
                    for (final k in katilimcilar)
                      MiniKutu(track: k.track, harf: k.ad, mirror: k.mirror),
                  ])
                else
                  _bantAvatar(ad),
                // Ust: isim + CANLI sure (okunur olsun diye koyu serit)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Row(children: [
                      Expanded(
                        child: Text(ad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                      Text(c.durumMetni,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ]),
                  ),
                ),
                // Alt: kontrol butonlari (mic / hoparlor / kapat) — WhatsApp mini kontrol.
                // TEST TURU 14: buton alani buyudu (36px) + HOPARLOR eklendi ("sesi azalt/ac").
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _miniBtn(
                        c.micOn ? LucideIcons.mic : LucideIcons.micOff,
                        c.micOn ? Colors.white : Colors.redAccent,
                        c.toggleMic,
                      ),
                      _miniBtn(
                        c.speakerOn ? LucideIcons.volume2 : LucideIcons.volumeX,
                        c.speakerOn ? Colors.white : Colors.white70,
                        c.toggleSpeaker,
                      ),
                      _miniBtn(LucideIcons.phoneOff, Colors.white,
                          () => c.leave(notifyServer: true),
                          arka: Colors.redAccent),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, Color renk, VoidCallback onTap, {Color? arka}) {
    return GestureDetector(
      // Dokunma alani buton kadar (36px): kucuk hedefte kacirma olmasin. behavior opaque ->
      // dokunus ALTTAKI "aramaya don" jestine SIZMAZ (yanlislikla ekran acilmasin).
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: arka ?? Colors.white24),
        child: Icon(icon, color: renk, size: 19),
      ),
    );
  }

  Widget _bantAvatar(String ad) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0B2E), Color(0xFF0B141A)],
        ),
      ),
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF6C2BD9),
        child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontSize: 22)),
      ),
    );
  }
}

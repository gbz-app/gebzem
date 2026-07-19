import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'active_call_controller.dart';

/// AKTIF ARAMA BANTI (Faz-C C3) — minimize edilmis aramada TUM sayfalarin ustunde
/// yesil WhatsApp banti: avatar harfi + isim/grup adi + CANLI sure + "dokun: don".
/// MaterialApp.builder icinde yasar => Navigator'in DISINDA: burada Navigator.of(context)
/// YASAK — restore() rootNavigatorKey ile acar. Video onizleme YOK (v1 karari: renderer'i
/// kalici overlay'e koymak texture/CameraUtils riski).
class AktifAramaBanner extends ConsumerWidget {
  const AktifAramaBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(activeCallProvider);
    final b = c.arama;
    if (b == null || !c.minimized) return child;

    final ad = c.isGroup
        ? (b.chatTitle.isEmpty ? 'Grup araması' : b.chatTitle)
        : b.peerName;
    return Stack(
      children: [
        child,
        Positioned(
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
                    Icon(b.video ? LucideIcons.video : LucideIcons.phone,
                        color: Colors.white, size: 18),
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
                    // CANLI sure — controller'in saniye tick'i notifyListeners ile tazeler
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
        ),
      ],
    );
  }
}

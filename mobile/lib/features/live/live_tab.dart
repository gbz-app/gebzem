import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../../core/api.dart';
import '../../core/ws.dart';
import '../calls/active_call_controller.dart';
import '../calls/call_provider.dart';
import '../medya/medya_gorsel.dart';
import 'live_provider.dart';
import 'live_start_screen.dart';
import 'live_viewer_screen.dart';

/// CANLI sekmesi — yayin kesfet listesi (TikTok/Insta deseni; davet yok)
class LiveTab extends ConsumerStatefulWidget {
  const LiveTab({super.key});

  @override
  ConsumerState<LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends ConsumerState<LiveTab> {
  Timer? _yenile;
  StreamSubscription? _wsSub;
  bool _isleniyor = false;

  @override
  void initState() {
    super.initState();
    ref.invalidate(liveStreamsProvider); // aciliste taze
    // ANLIK (test turu 5): yayin baslat/bitir -> backend broadcast -> listeyi HEMEN tazele.
    // (home IndexedStack ile bu State kalici -> WS dinleyici surekli aktif, olay kacmaz.)
    _wsSub = ref.read(wsProvider).events.listen((ev) {
      if (mounted && ev['type'] == 'stream.list.changed') {
        ref.invalidate(liveStreamsProvider);
      }
    });
    _yenile = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(liveStreamsProvider); // yedek (WS kopmasi)
    });
  }

  @override
  void dispose() {
    _yenile?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  bool _aramaVarMi() {
    // TURU 56: self-heal'li TEK KAYNAK (bayat muhafiz kaydi temizlenir)
    if (ref.read(callServiceProvider.notifier).mesgulMu(etiket: 'yayin')) {
      // C5: minimize edilmis ARAMA varsa "Aramaya don" kisayolu (oda/yayinda arama null -> aksiyon yok)
      final ctrl = ref.read(activeCallProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Önce aramayı/odayı bitirin'),
        action: ctrl.arama != null
            ? SnackBarAction(label: 'Aramaya dön', onPressed: ctrl.restore)
            : null,
      ));
      return true;
    }
    return false;
  }

  Future<void> _izle(Map<String, dynamic> y) async {
    if (_isleniyor || _aramaVarMi()) return;
    setState(() => _isleniyor = true);
    try {
      final id = y['id'] as String;
      final info = await ref.read(liveApiProvider).izle(id);
      if (!mounted) return;
      if (ref.read(callServiceProvider.notifier).mesgulMu(etiket: 'yayin')) {
        // REST surerken arama kabul edildi (Spaces'teki muhafiz-tekrari dersi)
        unawaited(ref.read(liveApiProvider).ayril(id));
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aramadasınız — yayına girilmedi')));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        settings: RouteSettings(name: 'yayin-$id'),
        builder: (_) => LiveViewerScreen(
          streamId: id,
          lkRoom: info['room'] as String,
          url: info['url'] as String,
          token: info['token'] as String,
          baslik: info['title'] as String? ?? '',
          yayinciId: info['broadcaster_id'] as String? ?? '',
          yayinciAd: info['broadcaster_name'] as String? ?? '',
          durum: info['status'] as String? ?? 'live',
          ilkIzleyici: (info['viewer_count'] as num?)?.toInt() ?? 0,
          tip: info['type'] as String? ?? 'video',
          ilkKonukIds: (info['guest_ids'] as List?)?.cast<String>() ?? const [],
          ilkKonukAdlari: konukAdlariCoz(info['guest_list']),
        ),
      ));
      ref.invalidate(liveStreamsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yayinlar = ref.watch(liveStreamsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: YenileSarmali(
        onRefresh: () async => ref.invalidate(liveStreamsProvider),
        child: yayinlar.when(
          // Sik WS-invalidate'te spinner-flash olmasin (liste sabit kalir, arkada tazelenir)
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(children: const [
            SizedBox(height: 160),
            Center(child: Text('Yayınlar yüklenemedi — aşağı çekip yenileyin')),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 140),
                  Icon(LucideIcons.radioTower, size: 64, color: scheme.outline),
                  const SizedBox(height: 16),
                  Center(
                      child: Text('Şu an canlı yayın yok\nİlk yayını sen başlat!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.outline, fontSize: 16))),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final y = list[i];
                    final durakli = y['status'] == 'paused';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () => _izle(y),
                        // ⚠️ TURU 76: sunucu artik `broadcaster_avatar_media_id`
                        //    donuyor; eskiden yalniz harf ciziliyordu cunku
                        //    `avatar_url` sunucuda HIC yazilmiyor.
                        leading: Avatar(
                          ad: (y['broadcaster_name'] as String?) ?? '',
                          mediaId: y['broadcaster_avatar_media_id'] as String?,
                          cap: 48,
                        ),
                        title: Text(y['title'] as String? ?? '',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: durakli ? Colors.orange : Colors.redAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(durakli ? 'DURAKLADI' : 'CANLI',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(children: [
                                Flexible(
                                  child: Text('${y['broadcaster_name']}',
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 6),
                                const Icon(LucideIcons.eye, size: 13),
                                const SizedBox(width: 3),
                                Text('${y['viewer_count'] ?? 0}'),
                              ]),
                            ),
                          ]),
                        ),
                        trailing: const Icon(LucideIcons.chevronRight),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'yayinBaslat',
        onPressed: () {
          if (_aramaVarMi()) return;
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LiveStartScreen()));
        },
        icon: const Icon(LucideIcons.radioTower),
        label: const Text('Yayın başlat'),
      ),
    );
  }
}

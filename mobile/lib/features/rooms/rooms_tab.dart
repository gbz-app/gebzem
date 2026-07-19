import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/ws.dart';
import '../calls/active_call_controller.dart';
import '../calls/call_provider.dart';
import 'room_provider.dart';
import 'room_screen.dart';

/// ODALAR sekmesi — Spaces kesfet listesi (davet/zil YOK; kesif modeli).
class RoomsTab extends ConsumerStatefulWidget {
  const RoomsTab({super.key});

  @override
  ConsumerState<RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends ConsumerState<RoomsTab> {
  Timer? _yenile;
  StreamSubscription? _wsSub;
  bool _isleniyor = false; // cift dokunma muhafizi (ac/katil)

  @override
  void initState() {
    super.initState();
    ref.invalidate(roomsProvider); // aciliste taze
    // ANLIK (test turu 5): oda ac/bitir -> backend broadcast -> listeyi HEMEN tazele.
    _wsSub = ref.read(wsProvider).events.listen((ev) {
      if (mounted && ev['type'] == 'room.list.changed') {
        ref.invalidate(roomsProvider);
      }
    });
    _yenile = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(roomsProvider); // yedek (WS kopmasi)
    });
  }

  @override
  void dispose() {
    _yenile?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  /// MUHAFIZ: aramadayken odaya girilmez (iki LiveKit Room tek native ses birimini
  /// cekistirir — call_provider mesgul muhafiziyla ayni kural).
  bool _aramaVarMi() {
    if (ref.read(callServiceProvider.notifier).aramadaMi) {
      // C5: minimize edilmis arama varsa "Aramaya don" kisayolu
      final ctrl = ref.read(activeCallProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Önce aramayı bitirin'),
        action: ctrl.arama != null
            ? SnackBarAction(label: 'Aramaya dön', onPressed: ctrl.restore)
            : null,
      ));
      return true;
    }
    return false;
  }

  Future<void> _odaAc() async {
    if (_isleniyor || _aramaVarMi()) return;
    final ctrl = TextEditingController();
    final baslik = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sesli oda aç', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: 'Oda başlığı (ör. Akşam sohbeti)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (v) => Navigator.of(c).pop(v.trim()),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(LucideIcons.audioLines),
              label: const Text('Odayı aç'),
              onPressed: () => Navigator.of(c).pop(ctrl.text.trim()),
            ),
          ],
        ),
      ),
    );
    if (baslik == null || baslik.isEmpty || !mounted) return;

    setState(() => _isleniyor = true);
    try {
      final info = await ref.read(roomsApiProvider).olustur(baslik);
      if (!mounted) return;
      final roomId = info['room_id'] as String;
      // MUHAFIZ TEKRARI (dogrulama bulgusu): REST surerken gelen arama KABUL edilmis
      // olabilir — iki canli LiveKit Room acilmasin. Odayi geri kapat, ekrani ACMA.
      if (ref.read(callServiceProvider.notifier).aramadaMi) {
        unawaited(ref.read(roomsApiProvider).bitir(roomId));
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aramadasınız — oda açılmadı')));
        return;
      }
      // ONCE ekrani ac, SONRA state isleri (Riverpod+overlay tuzagi — CLAUDE.md)
      await Navigator.of(context).push(MaterialPageRoute(
        settings: RouteSettings(name: 'oda-$roomId'), // _cik popUntil hedefi (kilit bulgusu)
        builder: (_) => RoomScreen(
          roomId: roomId,
          lkRoom: info['room'] as String,
          url: info['url'] as String,
          token: info['token'] as String,
          rol: 'host',
          baslik: info['title'] as String? ?? baslik,
          hostId: info['host_id'] as String? ?? '',
        ),
      ));
      ref.invalidate(roomsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  Future<void> _katil(Map<String, dynamic> oda) async {
    if (_isleniyor || _aramaVarMi()) return;
    setState(() => _isleniyor = true);
    try {
      final id = oda['id'] as String;
      final info = await ref.read(roomsApiProvider).katil(id);
      if (!mounted) return;
      // MUHAFIZ TEKRARI (dogrulama bulgusu): join REST'i surerken arama kabul edilmis
      // olabilir. Sunucudaki 'joined' kaydini geri al, ekrani ACMA.
      if (ref.read(callServiceProvider.notifier).aramadaMi) {
        unawaited(ref.read(roomsApiProvider).ayril(id));
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aramadasınız — odaya katılınmadı')));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        settings: RouteSettings(name: 'oda-$id'), // _cik popUntil hedefi (kilit bulgusu)
        builder: (_) => RoomScreen(
          roomId: id,
          lkRoom: info['room'] as String,
          url: info['url'] as String,
          token: info['token'] as String,
          rol: info['role'] as String? ?? 'listener',
          baslik: info['title'] as String? ?? '',
          hostId: info['host_id'] as String? ?? '',
        ),
      ));
      ref.invalidate(roomsProvider);
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
    final odalar = ref.watch(roomsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(roomsProvider),
        child: odalar.when(
          skipLoadingOnReload: true, // WS-invalidate'te spinner-flash olmasin
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(children: const [
            SizedBox(height: 160),
            Center(child: Text('Odalar yüklenemedi — aşağı çekip yenileyin')),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 140),
                  Icon(LucideIcons.audioLines, size: 64, color: scheme.outline),
                  const SizedBox(height: 16),
                  Center(
                      child: Text('Şu an açık oda yok\nİlk odayı sen aç!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.outline, fontSize: 16))),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final o = list[i];
                    final konusmaci = (o['speaker_count'] as num?)?.toInt() ?? 0;
                    final dinleyici = (o['listener_count'] as num?)?.toInt() ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () => _katil(o),
                        leading: CircleAvatar(
                          radius: 24,
                          child: Text(
                              (o['host_name'] as String? ?? '?').isNotEmpty
                                  ? (o['host_name'] as String)[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(o['title'] as String? ?? '',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                  color: Colors.redAccent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${o['host_name']} · $konusmaci konuşmacı · $dinleyici dinleyici',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
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
        heroTag: 'odaAc',
        onPressed: _isleniyor ? null : _odaAc,
        icon: _isleniyor
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(LucideIcons.plus),
        label: const Text('Oda aç'),
      ),
    );
  }
}

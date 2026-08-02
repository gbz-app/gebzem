import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'active_call_controller.dart';
import 'call_provider.dart';

/// Aramalar sekmesi: gecmis + tekrar arama
class CallsTab extends ConsumerWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(callHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.phone, size: 56, color: scheme.outline),
                  const SizedBox(height: 12),
                  Text('Henüz arama yok.\nSohbetten arama başlatabilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.outline)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(callHistoryProvider),
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) => _CallTile(call: list[i]),
            ),
          );
        },
      ),
      // ⚠️ TEST TURU 56 — GRUP ARAMASI KALDIRILDI (kullanici karari 2 Agu):
      // "Tek arama, tek goruntulu arama, sesli oda ve yayin. Grup arama ve grup goruntulu
      //  arama OLMAYACAK. Temiz kod istiyorum, karmasa istemiyorum."
      // GEREKCE: son turlarda kovaladigimiz hatalarin cogu GRUP kaynakliydi (tekrar davet
      // takilmasi, grup aramasinin hic kapanmamasi, izgaranin konusmaci degisiminde
      // yikilmasi, is_group bayraginin CallKit yukunde dusmesi...). 1:1 ise stabil.
      // YONTEM: giris noktalari KAPATILDI, grup KODU SILINMEDI — 37 grup dali `baslat`,
      // `leave`, `parkEt`, `devamEt` gibi 1:1'in de kullandigi yollara orulmus durumda;
      // sokmek calisan yollari kirma riski tasiyor. Bu yol sahadaki hata yuzeyini AYNI
      // oranda sifirlar ve geri acmak tek dosya degisikligi kadardir.
      // ⚠️ SESLI ODA (features/rooms) ve CANLI YAYIN (features/live) DOKUNULMADI —
      // onlar coklu katilimci ve AYNI makineyi (LiveKit, mini_izgara, PiP) paylasiyor.
      // ⚠️ YAPMA: `mini_izgara.dart`i silme (oda/yayin kullaniyor).
      floatingActionButton: FloatingActionButton(
        heroTag: 'birebirAra',
        onPressed: () => context.push('/search'),
        child: const Icon(LucideIcons.phone),
      ),
    );
  }
}

class _CallTile extends ConsumerWidget {
  const _CallTile({required this.call});

  final Map<String, dynamic> call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final outgoing = call['outgoing'] as bool? ?? false;
    final status = call['status'] as String? ?? '';
    final video = (call['type'] as String? ?? 'audio') == 'video';
    final duration = call['duration'] as int? ?? 0;
    // Kirmizi gosterilecek durumlar: bana gelip cevaplanmayanlar
    final kacirilmis = !outgoing && (status == 'missed' || status == 'rejected');
    final name = call['peer_name'] as String? ?? '';
    final avatar = call['peer_avatar'] as String? ?? '';
    final at = DateTime.tryParse(call['created_at'] as String? ?? '')?.toLocal();

    // Ok ikonu: giden yukari-sag, gelen asagi-sol; cevaplanmadiysa kirmizi
    final cevaplandi = status == 'ended' && duration > 0;
    final icon = outgoing ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft;
    final iconColor = cevaplandi
        ? (outgoing ? Colors.green : Colors.green)
        : (kacirilmis ? scheme.error : scheme.outline);

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.isEmpty ? const Icon(LucideIcons.user) : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kacirilmis ? scheme.error : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(video ? LucideIcons.video : LucideIcons.phone,
              size: 14, color: scheme.outline),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _altSatir(status, outgoing, duration, at),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: scheme.outline),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(video ? LucideIcons.video : LucideIcons.phone, color: scheme.primary),
        onPressed: () => _callAgain(context, ref, video: video),
      ),
    );
  }

  /// "Cevapsiz · bugun 14:32" / "Giden arama · 3 dk 12 sn · dun 09:10"
  String _altSatir(String status, bool outgoing, int duration, DateTime? at) {
    final parcalar = <String>[_durum(status, outgoing, duration)];
    if (duration > 0) parcalar.add(_sure(duration));
    if (at != null) parcalar.add(_zaman(at));
    return parcalar.join(' · ');
  }

  String _durum(String status, bool outgoing, int duration) => switch (status) {
        'missed' => outgoing ? 'Cevap vermedi' : 'Cevapsız arama',
        'rejected' => outgoing ? 'Reddedildi' : 'Reddettin',
        'busy' => outgoing ? 'Meşguldü' : 'Meşguldün',
        'ended' when duration > 0 => outgoing ? 'Giden arama' : 'Gelen arama',
        'ended' => outgoing ? 'Cevap vermedi' : 'Cevapsız arama',
        'active' => 'Sürüyor',
        'ringing' => 'Çalıyor',
        _ => status,
      };

  String _sure(int saniye) {
    if (saniye < 60) return '$saniye sn';
    final dk = saniye ~/ 60;
    final sn = saniye % 60;
    if (dk < 60) return sn == 0 ? '$dk dk' : '$dk dk $sn sn';
    final sa = dk ~/ 60;
    return '$sa sa ${dk % 60} dk';
  }

  String _zaman(DateTime at) {
    final simdi = DateTime.now();
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final gun = DateTime(at.year, at.month, at.day);
    final fark = bugun.difference(gun).inDays;
    final saat = DateFormat('HH:mm').format(at);
    if (fark == 0) return 'bugün $saat';
    if (fark == 1) return 'dün $saat';
    if (fark < 7) return '${DateFormat('EEEE', 'tr').format(at)} $saat';
    return DateFormat('d MMM HH:mm', 'tr').format(at);
  }

  Future<void> _callAgain(BuildContext context, WidgetRef ref,
      {required bool video}) async {
    try {
      final info = await ref
          .read(callServiceProvider.notifier)
          .start(call['peer_id'] as String, video: video);
      if (!context.mounted) return;
      // FAZ-C: mantik controller'da baslar, ekran saf gorunum olarak acilir
      final ctrl = ref.read(activeCallProvider);
      await ctrl.baslat(AramaBilgisi(
        callId: info['call_id'] as String,
        url: info['url'] as String,
        token: info['token'] as String,
        video: video,
        peerName: call['peer_name'] as String? ?? '',
        peerId: call['peer_id'] as String,
      ));
      ctrl.ekraniAc();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

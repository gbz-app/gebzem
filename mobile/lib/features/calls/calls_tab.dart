import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'call_provider.dart';
import 'call_screen.dart';

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
                  Text('Henuz arama yok.\nSohbetten arama baslatabilirsin.',
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
      floatingActionButton: FloatingActionButton(
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
    final missed = status == 'missed' || status == 'rejected';
    final name = call['peer_name'] as String? ?? '';
    final avatar = call['peer_avatar'] as String? ?? '';
    final at = DateTime.tryParse(call['created_at'] as String? ?? '')?.toLocal();

    final icon = outgoing ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft;
    final color = missed ? scheme.error : (outgoing ? scheme.outline : Colors.green);

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.isEmpty ? const Icon(LucideIcons.user) : null,
      ),
      title: Text(name,
          style: TextStyle(color: missed ? scheme.error : null, fontWeight: FontWeight.w500)),
      subtitle: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _label(status, outgoing),
            style: TextStyle(fontSize: 13, color: scheme.outline),
          ),
          if (at != null) ...[
            Text('  ·  ', style: TextStyle(color: scheme.outline)),
            Text(DateFormat('d MMM HH:mm', 'tr').format(at),
                style: TextStyle(fontSize: 13, color: scheme.outline)),
          ],
        ],
      ),
      trailing: IconButton(
        icon: Icon(video ? LucideIcons.video : LucideIcons.phone, color: scheme.primary),
        onPressed: () => _callAgain(context, ref, video: video),
      ),
    );
  }

  String _label(String status, bool outgoing) => switch (status) {
        'missed' => 'Cevapsiz',
        'rejected' => outgoing ? 'Reddedildi' : 'Reddettin',
        'ended' => outgoing ? 'Giden arama' : 'Gelen arama',
        _ => status,
      };

  Future<void> _callAgain(BuildContext context, WidgetRef ref,
      {required bool video}) async {
    try {
      final info = await ref
          .read(callServiceProvider.notifier)
          .start(call['peer_id'] as String, video: video);
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: info['call_id'] as String,
          url: info['url'] as String,
          token: info['token'] as String,
          video: video,
          peerName: call['peer_name'] as String? ?? '',
        ),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'chats_provider.dart';
import 'models.dart';

/// WhatsApp tarzi sohbet listesi
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider);

    return Scaffold(
      body: chats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorRetry(
          message: apiErrorMessage(e),
          onRetry: () => ref.read(chatsProvider.notifier).load(),
        ),
        data: (list) {
          final visible = list.where((c) => !c.archived).toList();
          if (visible.isEmpty) {
            return const Center(
              child: Text('Henuz sohbet yok.\nSag alttan yeni sohbet baslat!',
                  textAlign: TextAlign.center),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(chatsProvider.notifier).load(),
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) => _ChatTile(chat: visible[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Yeni sohbet: isim/@kullaniciadi ile kisi ara (telefon numarasi gerekmez)
        onPressed: () => context.push('/search'),
        child: const Icon(LucideIcons.squarePen),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat});

  final Chat chat;

  String _timeLabel(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return DateFormat.Hm().format(local);
    }
    if (now.difference(local).inDays < 7) {
      return DateFormat.E('tr').format(local);
    }
    return DateFormat('dd.MM.yy').format(local);
  }

  String _preview() {
    switch (chat.lastType) {
      case 'image':
        return '📷 Fotograf';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎤 Sesli mesaj';
      case 'location':
        return '📍 Konum';
      default:
        return chat.lastMessage;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        radius: 26,
        backgroundImage: chat.avatarUrl.isNotEmpty ? NetworkImage(chat.avatarUrl) : null,
        child: chat.avatarUrl.isEmpty
            ? Icon(chat.type == 'group' ? LucideIcons.users : LucideIcons.user)
            : null,
      ),
      title: Row(
        children: [
          if (chat.pinned)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(LucideIcons.pin, size: 14, color: scheme.outline),
            ),
          Expanded(
            child: Text(
              chat.title.isNotEmpty ? chat.title : 'Sohbet',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: chat.unread > 0 ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ],
      ),
      subtitle: Text(
        _preview(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontWeight: chat.unread > 0 ? FontWeight.w600 : FontWeight.normal),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_timeLabel(chat.lastAt),
              style: TextStyle(
                  fontSize: 12,
                  color: chat.unread > 0 ? scheme.primary : scheme.outline)),
          const SizedBox(height: 4),
          if (chat.unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration:
                  BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(12)),
              child: Text('${chat.unread}',
                  style: TextStyle(fontSize: 12, color: scheme.onPrimary)),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
      onTap: () => context.push('/chat/${chat.id}', extra: {
        'title': chat.title.isNotEmpty ? chat.title : 'Sohbet',
        'peer_id': chat.peerId,
      }),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

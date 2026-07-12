import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/ws.dart';
import '../auth/auth_provider.dart';
import '../calls/call_provider.dart';
import '../calls/call_screen.dart';
import 'chats_provider.dart';
import 'models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.peerId,
  });

  final String chatId;
  final String title;
  final String? peerId; // 1:1 sohbette karsi tarafin id'si (arama icin)

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _typingThrottle;
  Timer? _typingUiTimer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // "yaziyor..." etiketini 3 sn sonra dusurmek icin periyodik kontrol
    _typingUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _typingThrottle?.cancel();
    _typingUiTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String _) {
    // her tusta degil, 2 sn'de bir "yaziyor" olayi gonder
    if (_typingThrottle?.isActive ?? false) return;
    _typingThrottle = Timer(const Duration(seconds: 2), () {});
    ref.read(wsProvider).sendTyping(widget.chatId);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagesProvider(widget.chatId).notifier).send(text);
      _input.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  /// Sesli/goruntulu arama baslat
  Future<void> _startCall({required bool video}) async {
    final peerId = widget.peerId;
    if (peerId == null) return;
    try {
      final info =
          await ref.read(callServiceProvider.notifier).start(peerId, video: video);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: info['call_id'] as String,
          url: info['url'] as String,
          token: info['token'] as String,
          video: video,
          peerName: widget.title,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.chatId));
    final notifier = ref.read(messagesProvider(widget.chatId).notifier);
    final myId = ref.watch(myUserIdProvider).valueOrNull;

    // yeni mesaj gelince asagi kay
    ref.listen(messagesProvider(widget.chatId), (prev, next) {
      final prevLen = prev?.valueOrNull?.length ?? 0;
      final nextLen = next.valueOrNull?.length ?? 0;
      if (nextLen > prevLen) _scrollToBottom();
    });

    final typing = notifier.typingAt != null &&
        DateTime.now().difference(notifier.typingAt!).inSeconds < 3;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 17)),
            if (typing)
              Text('yaziyor...',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.video),
            onPressed: widget.peerId == null ? null : () => _startCall(video: true),
          ),
          IconButton(
            icon: const Icon(LucideIcons.phone),
            onPressed: widget.peerId == null ? null : () => _startCall(video: false),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(apiErrorMessage(e))),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('Ilk mesaji sen gonder 👋'));
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final msg = list[i];
                    final mine = msg.senderId == myId;
                    final showDate = i == 0 ||
                        !_sameDay(list[i - 1].createdAt, msg.createdAt);
                    return Column(
                      children: [
                        if (showDate) _DateChip(date: msg.createdAt),
                        _Bubble(message: msg, mine: mine),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _send(),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yazin',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        // Faz 2: atas (medya) butonu buraya
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _sending ? null : _send,
                    child: const Icon(LucideIcons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final now = DateTime.now();
    String label;
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      label = 'Bugun';
    } else if (now.difference(local).inDays == 1) {
      label = 'Dun';
    } else {
      label = DateFormat('d MMMM yyyy', 'tr').format(local);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat.Hm().format(message.createdAt.toLocal());

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? scheme.bubbleMine : scheme.bubbleOther,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(mine ? 12 : 2),
            bottomRight: Radius.circular(mine ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 2,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.deletedForAll)
              Text('🚫 Bu mesaj silindi',
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: scheme.outline))
            else
              Text(message.content, style: const TextStyle(fontSize: 15.5)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time,
                    style: TextStyle(fontSize: 11, color: scheme.outline)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.checkCheck,
                    size: 15,
                    color: message.read ? scheme.tickRead : scheme.outline,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

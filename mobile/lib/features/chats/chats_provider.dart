import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/ws.dart';
import 'models.dart';

/// Sohbet listesi: REST'ten ceker, WebSocket olaylariyla canli guncellenir
class ChatsNotifier extends StateNotifier<AsyncValue<List<Chat>>> {
  ChatsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
    _sub = _ref.read(wsProvider).events.listen(_onEvent);
  }

  final Ref _ref;
  StreamSubscription? _sub;

  Future<void> load() async {
    try {
      final res = await _ref.read(apiProvider).get('/chats');
      final list =
          (res.data as List).map((e) => Chat.fromJson(e as Map<String, dynamic>)).toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _onEvent(Map<String, dynamic> ev) {
    // yeni mesaj geldiginde listeyi tazele (son mesaj + okunmamis sayaci icin)
    if (ev['type'] == 'message.new' || ev['type'] == 'receipt.read') {
      load();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final chatsProvider =
    StateNotifierProvider<ChatsNotifier, AsyncValue<List<Chat>>>(ChatsNotifier.new);

/// Tek sohbetin mesajlari: gecmis + canli akis
class MessagesNotifier extends StateNotifier<AsyncValue<List<Message>>> {
  MessagesNotifier(this._ref, this.chatId) : super(const AsyncValue.loading()) {
    load();
    _sub = _ref.read(wsProvider).events.listen(_onEvent);
  }

  final Ref _ref;
  final String chatId;
  StreamSubscription? _sub;

  /// "yaziyor..." gostergesi icin son olay zamani
  DateTime? typingAt;

  Future<void> load() async {
    try {
      final res = await _ref.read(apiProvider).get('/chats/$chatId/messages');
      final list = (res.data as List)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList(); // API yeni->eski verir; ekranda eski->yeni tutariz
      state = AsyncValue.data(list);
      // sohbet acildi — okundu isaretle
      _ref.read(apiProvider).post('/chats/$chatId/read').ignore();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> send(String content, {String type = 'text'}) async {
    await _ref
        .read(apiProvider)
        .post('/chats/$chatId/messages', data: {'type': type, 'content': content});
    // kendi mesajimiz sunucuya yazildi — listeyi tazele (WS yayini alicilara gider)
    await load();
  }

  void _onEvent(Map<String, dynamic> ev) {
    if (ev['chat_id'] != chatId) return;
    switch (ev['type']) {
      case 'message.new':
        final payload = ev['payload'];
        if (payload is Map<String, dynamic>) {
          final msg = Message.fromJson(payload);
          final current = List<Message>.from(state.valueOrNull ?? []);
          if (!current.any((m) => m.id == msg.id)) {
            current.add(msg);
            state = AsyncValue.data(current);
          }
          // acik sohbette gelen mesaji hemen okundu isaretle
          _ref.read(apiProvider).post('/chats/$chatId/read').ignore();
        }
      case 'receipt.read':
        // karsi taraf okudu — benim mesajlarim mavi tik olsun
        final current = List<Message>.from(state.valueOrNull ?? []);
        for (final m in current) {
          m.read = true;
        }
        state = AsyncValue.data(current);
      case 'typing':
        typingAt = DateTime.now();
        // dinleyicileri uyandirmak icin state'i kopyala
        state = AsyncValue.data(List<Message>.from(state.valueOrNull ?? []));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final messagesProvider = StateNotifierProvider.family
    .autoDispose<MessagesNotifier, AsyncValue<List<Message>>, String>(
        (ref, chatId) => MessagesNotifier(ref, chatId));

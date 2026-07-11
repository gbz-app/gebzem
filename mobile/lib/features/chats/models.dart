/// Sohbet listesi satiri
class Chat {
  Chat({
    required this.id,
    required this.type,
    required this.title,
    required this.avatarUrl,
    required this.pinned,
    required this.archived,
    required this.lastMessage,
    required this.lastType,
    required this.lastAt,
    required this.unread,
  });

  final String id;
  final String type; // direct, group, channel
  final String title;
  final String avatarUrl;
  final bool pinned;
  final bool archived;
  final String lastMessage;
  final String lastType;
  final DateTime? lastAt;
  final int unread;

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'direct',
        title: j['title'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String? ?? '',
        pinned: j['pinned'] as bool? ?? false,
        archived: j['archived'] as bool? ?? false,
        lastMessage: j['last_message'] as String? ?? '',
        lastType: j['last_type'] as String? ?? '',
        lastAt: j['last_at'] != null ? DateTime.tryParse(j['last_at'] as String) : null,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
      );

  Chat copyWith({String? lastMessage, String? lastType, DateTime? lastAt, int? unread}) => Chat(
        id: id,
        type: type,
        title: title,
        avatarUrl: avatarUrl,
        pinned: pinned,
        archived: archived,
        lastMessage: lastMessage ?? this.lastMessage,
        lastType: lastType ?? this.lastType,
        lastAt: lastAt ?? this.lastAt,
        unread: unread ?? this.unread,
      );
}

/// Tek mesaj
class Message {
  Message({
    required this.id,
    required this.senderId,
    required this.type,
    required this.content,
    required this.mediaUrl,
    required this.replyToId,
    required this.deletedForAll,
    required this.createdAt,
    this.read = false,
  });

  final int id;
  final String senderId;
  final String type; // text, image, video, audio, location, system
  final String content;
  final String mediaUrl;
  final int? replyToId;
  final bool deletedForAll;
  final DateTime createdAt;
  bool read; // benim mesajim karsi tarafca okundu mu (mavi tik)

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: (j['id'] as num).toInt(),
        senderId: j['sender_id'] as String,
        type: j['type'] as String? ?? 'text',
        content: j['content'] as String? ?? '',
        mediaUrl: j['media_url'] as String? ?? '',
        replyToId: (j['reply_to_id'] as num?)?.toInt(),
        deletedForAll: j['deleted_for_all'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

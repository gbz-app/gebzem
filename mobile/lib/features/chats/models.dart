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
    required this.lastSenderId,
    required this.lastAt,
    required this.unread,
    this.peerId,
  });

  final String id;
  final String type; // direct, group, channel
  final String title;
  final String avatarUrl;
  final bool pinned;
  final bool archived;
  final String lastMessage;
  final String lastType;
  /// TURU 59: son mesajin GONDERENI. Sohbet listesi arama kaydi onizlemesinde YON
  /// gerekiyor — "Cevapsiz sesli arama" yalniz ARANAN icin dogru; arayana "Sesli
  /// arama" yazilmali (WhatsApp deseni). Eski sunucu bu alani dondurmezse bos gelir
  /// ve onizleme YONSUZ metne duser (guvenli varsayilan).
  final String lastSenderId;
  final DateTime? lastAt;
  final int unread;
  final String? peerId; // 1:1 sohbette karsi tarafin id'si (arama icin)

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'direct',
        title: j['title'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String? ?? '',
        pinned: j['pinned'] as bool? ?? false,
        archived: j['archived'] as bool? ?? false,
        lastMessage: j['last_message'] as String? ?? '',
        lastType: j['last_type'] as String? ?? '',
        lastSenderId: j['last_sender_id'] as String? ?? '',
        lastAt: j['last_at'] != null ? DateTime.tryParse(j['last_at'] as String) : null,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        peerId: j['peer_id'] as String?,
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
    this.mediaId,
    this.durationMs = 0,
    this.waveform = '',
    this.width = 0,
    this.height = 0,
    this.fileName = '',
    this.bytes = 0,
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
  /// TURU 74: R2 medya kaydinin kimligi. ⚠️ URL DEGIL id — adres her
  /// goruntulemede /media/{id}/url ile ALINIR (imza 600sn omurlu).
  final String? mediaId;
  /// TURU 74: medya ustverisi — sunucudan mesajla BIRLIKTE gelir (N+1 istek yok).
  final int durationMs;
  final String waveform;
  final int width;
  final int height;
  final String fileName;
  final int bytes;
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
        mediaId: j['media_id'] as String?,
        durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
        waveform: j['waveform'] as String? ?? '',
        width: (j['width'] as num?)?.toInt() ?? 0,
        height: (j['height'] as num?)?.toInt() ?? 0,
        fileName: j['file_name'] as String? ?? '',
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        replyToId: (j['reply_to_id'] as num?)?.toInt(),
        deletedForAll: j['deleted_for_all'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  /// TURU 74 — "herkesten silindi" hali. Sunucu da AYNISINI yapar (satiri silmez,
  /// icerigi bosaltir) — yerel kopya sunucuyla TUTARLI kalsin diye ayni sekilde.
  /// ⚠️ `read` KORUNUR: silme okundu bilgisini degistirmez.
  Message silindiKopyasi() => Message(
        id: id,
        senderId: senderId,
        type: type,
        content: '',
        mediaUrl: '',
        mediaId: null, // silinen mesajda medya da GIZLENIR
        replyToId: replyToId,
        deletedForAll: true,
        createdAt: createdAt,
        read: read,
      );
}

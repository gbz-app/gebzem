import 'anket.dart';

/// Sohbet listesi satiri
class Chat {
  Chat({
    required this.id,
    required this.type,
    required this.title,
    required this.avatarUrl,
    this.avatarMediaId,
    required this.pinned,
    required this.archived,
    this.sessiz = false,
    required this.lastMessage,
    required this.lastType,
    required this.lastSenderId,
    required this.lastAt,
    required this.unread,
    this.peerId,
    this.ilanBaslik = '',
  });

  final String id;
  final String type; // direct, group, channel
  final String title;
  final String avatarUrl;

  /// ⚠️ TURU 76: `avatar_url` sunucuda HIC YAZILMIYOR (kalici bos string) —
  ///    sohbet listesi bu yuzden DAIMA harf ciziyordu. Fotograf ancak bu
  ///    alanla gorunur (R2'de, imzali adresle).
  final String? avatarMediaId;
  final bool pinned;
  final bool archived;

  /// TURU 76: sessize alinmis mi (muted_until). 001'den beri OLU SUTUNDU.
  final bool sessiz;
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

  /// TURU 78 — ILAN SOHBETI ise ilan basligi (yoksa bos).
  /// ⚠️⚠️ Bu alan OLMASAYDI ozellik YARIM kalirdi: sohbet ilana bagli olur
  ///    ama satici listede HANGI ILAN oldugunu goremezdi ve her seferinde
  ///    sormak zorunda kalirdi — cozulmek istenen sorunun ta kendisi.
  final String ilanBaslik;

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'direct',
        title: j['title'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String? ?? '',
        avatarMediaId: j['avatar_media_id'] as String?,
        pinned: j['pinned'] as bool? ?? false,
        archived: j['archived'] as bool? ?? false,
        sessiz: j['muted'] as bool? ?? false,
        lastMessage: j['last_message'] as String? ?? '',
        lastType: j['last_type'] as String? ?? '',
        lastSenderId: j['last_sender_id'] as String? ?? '',
        lastAt: j['last_at'] != null ? DateTime.tryParse(j['last_at'] as String) : null,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        peerId: j['peer_id'] as String?,
        ilanBaslik: j['ilan_baslik'] as String? ?? '',
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
    this.senderName = '',
    this.senderAvatarMediaId,
    required this.replyToId,
    required this.deletedForAll,
    required this.createdAt,
    this.read = false,
    this.anket,
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
  /// TURU 76 — GRUP icin: gonderen adi/avatari. 1:1'de cizilmez.
  final String senderName;
  final String? senderAvatarMediaId;
  final int? replyToId;
  final bool deletedForAll;
  final DateTime createdAt;
  bool read; // benim mesajim karsi tarafca okundu mu (mavi tik)

  /// ⚠️⚠️ TURU 81 — ANKET. YALNIZ `type == 'poll'` mesajlarda dolu olur.
  ///
  /// Sunucu anketin TAM ANLIK GORUNTUSUNU (secenekler + sayimlar + benim
  /// oylarim) mesaj govdesinin `poll` alaninda donduruyor; istemci balonu
  /// cizmek icin AYRI bir istek ATMAZ. Aksi halde 20 mesajlik bir sohbette
  /// 20 ek istek olurdu.
  final Anket? anket;

  /// Anketi DEGISTIRILMIS bir kopya doner.
  ///
  /// ⚠️ `anket` alani `final`; WS olayi geldiginde yerinde yamalamak yerine
  ///    KOPYA uretiliyor. Alani `final` olmaktan cikarmak, listeyi tutan
  ///    baska bir yerin ayni nesneyi paylasmasi durumunda sessiz yan etki
  ///    uretirdi.
  Message anketle(Anket yeni) => Message(
    id: id,
    senderId: senderId,
    type: type,
    content: content,
    mediaUrl: mediaUrl,
    mediaId: mediaId,
    durationMs: durationMs,
    waveform: waveform,
    width: width,
    height: height,
    fileName: fileName,
    bytes: bytes,
    senderName: senderName,
    senderAvatarMediaId: senderAvatarMediaId,
    replyToId: replyToId,
    deletedForAll: deletedForAll,
    createdAt: createdAt,
    read: read,
    anket: yeni,
  );

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
        senderName: j['sender_name'] as String? ?? '',
        senderAvatarMediaId: j['sender_avatar_media_id'] as String?,
        anket: j['poll'] is Map
            ? Anket.fromJson((j['poll'] as Map).cast<String, dynamic>())
            : null,
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
        senderName: senderName,
        senderAvatarMediaId: senderAvatarMediaId,
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

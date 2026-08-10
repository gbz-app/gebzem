import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/ws.dart';
import '../auth/auth_provider.dart';
import 'anket.dart';
import 'models.dart';

/// Sohbet listesi: REST'ten ceker, WebSocket olaylariyla canli guncellenir
class ChatsNotifier extends StateNotifier<AsyncValue<List<Chat>>> {
  ChatsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
    final ws = _ref.read(wsProvider);
    _sub = ws.events.listen(_onEvent);
    // ⚠️⚠️ TURU 76 — YAKALAMA (catch-up). WS her (yeniden) baglandiginda liste
    //    bastan cekilir. Bu, IKI ayri bosluğu birden kapatir:
    //    (1) uygulama arka planda WS'i KASTEN kapatiyor (turu 33: kilit
    //        ekraninda arama calsin diye ZORUNLU) -> o sirada gelen mesajlar
    //        Redis pub/sub'ta SAKLANMIYOR ve ekranda HIC gorunmuyordu,
    //    (2) mobil agda kopma sonrasi ayni durum.
    // ⚠️ YAPMA: bu kancayi kaldirip yalniz `main.dart` resumed dalina guvenme —
    //    o dal ag kopmasini KAPSAMAZ.
    ws.yenidenBaglandiDinle(load);
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
    final ws = _ref.read(wsProvider);
    _sub = ws.events.listen(_onEvent);
    // ⚠️ TURU 76 — YAKALAMA: acik sohbette de gerekli. Kullanici sohbet
    //    ekranindayken uygulamayi arka plana alir, karsi taraf 3 mesaj gonderir,
    //    geri doner: ChatScreen mount kaldigi icin bu notifier YASAR ve `load()`
    //    bir daha CALISMAZDI -> o 3 mesaj ekranda HIC gorunmuyordu.
    // ⚠️ Bu notifier autoDispose family — kanca dispose'ta MUTLAKA birakilir.
    _yakalama = load;
    ws.yenidenBaglandiDinle(_yakalama!);
  }

  final Ref _ref;
  final String chatId;
  StreamSubscription? _sub;
  void Function()? _yakalama;

  /// ⚠️ TURU 76: `receipt.read` olayini dogru islemek icin kendi kimligim.
  ///    `myUserIdProvider` ASENKRON; gelmediyse `null` kalir ve o durumda ESKI
  ///    (gevsek) davranisa duseriz — mavi tik yanlis cizilebilir ama mesajlar
  ///    KAYBOLMAZ. Guvenli varsayilan.
  String? get _benimId => _ref.read(myUserIdProvider).valueOrNull;

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

  Future<void> send(
    String content, {
    String type = 'text',
    String? mediaId,
    String? clientRef,
  }) async {
    await _ref.read(apiProvider).post('/chats/$chatId/messages', data: {
      'type': type,
      'content': content,
      // ⚠️ TURU 74: URL DEGIL id. Sunucu sahipligi ve dogrulanmisligi kontrol eder.
      if (mediaId != null) 'media_id': mediaId,
      // ⚠️ Idempotency: ag zaman asimindan sonra tekrar denenirse sunucu IKINCI
      //     MESAJ ACMAZ (kismi UNIQUE index). Medya gonderiminde bu SART — yukleme
      //     dakikalar surebiliyor ve kullanici "gitmedi" sanip tekrar basiyor.
      if (clientRef != null) 'client_ref': clientRef,
    });
    // kendi mesajimiz sunucuya yazildi — listeyi tazele (WS yayini alicilara gider)
    await load();
  }

  /// TURU 74 — mesaji HERKESTEN sil (yalniz kendi mesajim).
  /// ⚠️ Sunucu satiri FIZIKSEL SILMEZ, icerigi bosaltip `deleted_for_all=true` yazar;
  ///     balon "Bu mesaj silindi" cizer (`_Bubble` bunu ZATEN destekliyor).
  /// ⚠️ IYIMSER guncelleme YOK: sunucu 403 donebilir (baskasinin mesaji / baska sohbet).
  ///     Once sunucuya sorulur, sonra yerel liste guncellenir.
  Future<void> mesajiSil(int messageId) async {
    await _ref.read(apiProvider).delete('/chats/$chatId/messages/$messageId');
    _silindiIsaretle(messageId);
  }

  void _silindiIsaretle(int messageId) {
    final current = List<Message>.from(state.valueOrNull ?? []);
    final i = current.indexWhere((m) => m.id == messageId);
    if (i < 0) return;
    current[i] = current[i].silindiKopyasi();
    state = AsyncValue.data(current);
  }

  void _onEvent(Map<String, dynamic> ev) {
    if (ev['chat_id'] != chatId) return;
    switch (ev['type']) {
      // TURU 74: karsi taraf (veya kendi ikinci cihazimiz) mesaji sildi.
      case 'message.deleted':
        final p = ev['payload'];
        if (p is Map<String, dynamic>) {
          final id = (p['id'] as num?)?.toInt();
          if (id != null) _silindiIsaretle(id);
        }
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
      // ⚠️⚠️⚠️ TURU 81 — ANKET OLAYLARI (denetim bulgusu: SEVK ENGELIYDI).
      //
      //	Sunucu `poll.vote` ve `poll.closed` olaylarini YAYINLIYORDU ama
      //	istemcide onlari DINLEYEN HICBIR YER YOKTU. Sonuc: biri oy
      //	verdiginde ya da anketi bitirdiginde DIGERLERININ ekraninda
      //	HICBIR SEY DEGISMIYORDU — anket "canli" gorunmesine ragmen fiilen
      //	statik bir resimdi ve kullanici sohbetten cikip girmeden sonucu
      //	goremiyordu. ("Sunucu uretiyor ama tuketen yok" = olu ozellik.)
      //
      // ⚠️ Govde `anketOku` ile AYNI sekildedir; balon `vote_seq` ile
      //    eskimis olayi zaten eliyor (WS bu projede KAYBOLABILIR/GECIKEBILIR).
      // ⚠️ `mine` alani yayinda ANLAMSIZDIR (ortak govde) — balon kendi
      //    secimini YEREL durumundan bilir, bu yuzden burada yalnizca
      //    SAYIMLAR ve KAPALI bilgisi guncellenir.
      case 'poll.vote':
      case 'poll.closed':
        final p = ev['payload'];
        if (p is Map<String, dynamic>) {
          final yeni = Anket.fromJson(p);
          final current = List<Message>.from(state.valueOrNull ?? []);
          var degisti = false;
          for (var i = 0; i < current.length; i++) {
            final m = current[i];
            if (m.anket?.id != yeni.id) continue;
            // ⚠️ ESKIMIS OLAY ELENIR: `vote_seq` kucuk/esitse yok say.
            //    Aksi halde gecikmis bir olay, kullanicinin AZ ONCE verdigi
            //    oyu geri alirdi.
            if (yeni.seq <= (m.anket?.seq ?? 0)) break;
            current[i] = m.anketle(yeni);
            degisti = true;
            break;
          }
          if (degisti) state = AsyncValue.data(current);
        }
      case 'receipt.read':
        // ⚠️⚠️ TURU 76 — OKUYANIN KIM OLDUGU KONTROL EDILIYOR.
        //    Eskiden olay KOSULSUZ isleniyor ve listedeki TUM mesajlar
        //    (kendiminki olsun olmasin) `read = true` yapiliyordu.
        //    1:1'de tesadufen dogruydu (tek karsi taraf var). GRUP acildigi AN
        //    YALAN olurdu: 5 kisilik grupta SADECE BIRI okudugunda diger 4
        //    kisinin ekraninda butun mesajlar mavi tike donerdi —
        //    "herkes okudu" yalani.
        // ⚠️ KENDI okuma olayimi da yok sayiyorum: kendi mesajlarimi mavi
        //    yapmaz, gereksiz yeniden cizim uretirdi.
        final okuyan = (ev['payload'] as Map?)?['user_id'] as String?;
        if (okuyan != null && okuyan == _benimId) break;
        final current = List<Message>.from(state.valueOrNull ?? []);
        for (final m in current) {
          // ⚠️ Yalniz BENIM mesajlarim mavi tik alir — karsi tarafin mesajina
          //    "okundu" yazmak anlamsizdi.
          if (_benimId == null || m.senderId == _benimId) m.read = true;
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
    // ⚠️ ZORUNLU: kanca birakilmazsa dispose edilmis notifier'in load()'i
    //    cagrilir -> "Cannot use ref after ... disposed" (turu 67 sinifi).
    if (_yakalama != null) _ref.read(wsProvider).yenidenBaglandiBirak(_yakalama!);
    super.dispose();
  }
}

final messagesProvider = StateNotifierProvider.family
    .autoDispose<MessagesNotifier, AsyncValue<List<Message>>, String>(
        (ref, chatId) => MessagesNotifier(ref, chatId));

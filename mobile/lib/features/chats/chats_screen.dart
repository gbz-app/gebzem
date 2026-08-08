import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../auth/auth_provider.dart';
import '../medya/medya_gorsel.dart';
import 'arama_kaydi.dart';
import 'chats_provider.dart';
import 'grup_olustur.dart';
import 'models.dart';

/// WhatsApp tarzi sohbet listesi. "Gebzem" basliginin altinda ARAMA INPUT'u (yerel filtre);
/// FAB = mor-gradient + (yeni sohbet).
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

/// Sohbet listesi filtresi.
/// ⚠️ Arsiv AYRI bir gorunumdur: digerlerinde arsivlenmisler GIZLIDIR.
enum _Filtre { tumu, okunmamis, gruplar, arsiv }

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _aramaCtrl = TextEditingController();
  String _arama = '';
  _Filtre _filtre = _Filtre.tumu;

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  /// + dugmesi: yeni sohbet mi, yeni grup mu.
  Future<void> _yeniSecenek(BuildContext context) async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.messageCirclePlus),
              title: const Text('Yeni sohbet'),
              subtitle: const Text('Bir kişiyle mesajlaş'),
              onTap: () => Navigator.pop(c, 'sohbet'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.users),
              title: const Text('Yeni grup'),
              subtitle: const Text('Birden fazla kişiyle mesajlaş'),
              onTap: () => Navigator.pop(c, 'grup'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || secim == null) return;
    if (secim == 'sohbet') {
      context.push('/search');
      return;
    }
    final chatId = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const GrupOlusturEkrani()));
    if (chatId != null && context.mounted) {
      context.push('/chat/$chatId', extra: {'title': 'Grup'});
    }
  }

  /// Cip etiketi. Okunmamis ve arsiv icin SAYI da gosterilir — kullanici
  /// filtreye dokunmadan kac tane oldugunu gorsun.
  String _filtreAdi(_Filtre f, List<Chat>? liste) {
    final l = liste ?? const <Chat>[];
    switch (f) {
      case _Filtre.tumu:
        return 'Tümü';
      case _Filtre.okunmamis:
        final n = l.where((c) => !c.archived && c.unread > 0).length;
        return n > 0 ? 'Okunmamış ($n)' : 'Okunmamış';
      case _Filtre.gruplar:
        return 'Gruplar';
      case _Filtre.arsiv:
        final n = l.where((c) => c.archived).length;
        return n > 0 ? 'Arşiv ($n)' : 'Arşiv';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatsProvider);

    return Scaffold(
      body: Column(children: [
        // ARAMA INPUT'u (Gebzem altinda — kullanici istegi): sohbet basligina gore filtreler
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: TextField(
            controller: _aramaCtrl,
            onChanged: (v) => setState(() => _arama = v.trim().toLowerCase()),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Sohbet ara',
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              suffixIcon: _arama.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () {
                        _aramaCtrl.clear();
                        setState(() => _arama = '');
                      },
                    ),
              filled: true,
              fillColor: const Color(0xFF232326),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // FILTRE CIPLERI — arama kutusunun ALTINDA (WhatsApp deseni).
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in _Filtre.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_filtreAdi(f, chats.valueOrNull)),
                    selected: _filtre == f,
                    onSelected: (_) => setState(() => _filtre = f),
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: chats.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorRetry(
              message: apiErrorMessage(e),
              onRetry: () => ref.read(chatsProvider.notifier).load(),
            ),
            data: (list) {
              // ⚠️⚠️ TURU 76 — FILTRE (kullanici emri: "tümü / okunmamış vs").
              //    TAMAMEN ISTEMCI TARAFINDA: sunucu zaten `unread`, `type` ve
              //    `archived` donduruyor, yani YENI UC GEREKMEZ. Liste kullanicinin
              //    TUM sohbetleri oldugu icin sayfalama da gerekmiyor.
              // ⚠️ Arsiv AYRI bir filtre: digerlerinde arsivlenmisler GIZLI kalir,
              //    yoksa "arsivle" hicbir ise yaramaz.
              var visible = switch (_filtre) {
                _Filtre.okunmamis =>
                  list.where((c) => !c.archived && c.unread > 0).toList(),
                _Filtre.gruplar =>
                  list.where((c) => !c.archived && c.type == 'group').toList(),
                _Filtre.arsiv => list.where((c) => c.archived).toList(),
                _ => list.where((c) => !c.archived).toList(),
              };
              if (_arama.isNotEmpty) {
                visible = visible
                    .where((c) => c.title.toLowerCase().contains(_arama))
                    .toList();
              }
              // SIK GORUSULEN kisiler (test turu 7): arama YOKKEN, arama input'unun altinda
              // en son gorusulen 1:1 kisiler yatay profil seridi (WhatsApp/Telegram deseni).
              // ⚠️ Serit YALNIZ "Tümü" filtresinde: okunmamis/gruplar/arsiv
              //    goruntusunde tum kisileri gostermek FILTREYI ANLAMSIZ kilar.
              final sik = (_arama.isEmpty && _filtre == _Filtre.tumu)
                  ? (list.where((c) => c.type == 'direct' && !c.archived).toList()
                    ..sort((a, b) => (b.lastAt ?? DateTime(0))
                        .compareTo(a.lastAt ?? DateTime(0))))
                  : const <Chat>[];
              if (visible.isEmpty && sik.isEmpty) {
                return Center(
                  child: Text(
                      _arama.isNotEmpty
                          ? 'Eşleşen sohbet yok'
                          : switch (_filtre) {
                              _Filtre.okunmamis => 'Okunmamış sohbet yok',
                              _Filtre.gruplar =>
                                'Henüz grubun yok.\nSağ alttan grup oluştur!',
                              _Filtre.arsiv => 'Arşivde sohbet yok',
                              _ => 'Henüz sohbet yok.\nSağ alttan yeni sohbet başlat!',
                            },
                      textAlign: TextAlign.center),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(chatsProvider.notifier).load(),
                child: ListView(
                  children: [
                    if (sik.isNotEmpty) _SikGorusulenSerit(kisiler: sik.take(12).toList()),
                    for (final c in visible) _ChatTile(chat: c),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
      // FAB: mor-gradient DAIRE + (kalem yerine — kullanici istegi). FloatingActionButton
      // gradient desteklemez -> Container decoration + saydam FAB.
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: morGradient,
          boxShadow: [BoxShadow(color: Color(0x556C2BD9), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: FloatingActionButton(
          heroTag: 'fabYeniSohbet', // TURU 76: bkz. akis_ekrani hero serhi
          // ⚠️⚠️ TURU 76: + artik SECENEK SUNUYOR (yeni sohbet / YENI GRUP).
          //    Grup olusturma ekranini yalniz "uzun bas" gibi gizli bir hareketin
          //    arkasina koymak, bu projede iki kez yasanan "OLU DOGMUS OZELLIK"
          //    sinifidir: kod yazilir, kullanici varligini HIC ogrenemez.
          onPressed: () => _yeniSecenek(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// SIK GORUSULEN kisiler yatay seridi (arama input'unun altinda). En son gorusulen 1:1
/// kisiler; avatar + isim; dokun -> sohbeti ac.
class _SikGorusulenSerit extends StatelessWidget {
  const _SikGorusulenSerit({required this.kisiler});
  final List<Chat> kisiler;

  @override
  Widget build(BuildContext context) {
    // ⚠️ `scheme` KALDIRILDI: harf rengini artik ortak `Avatar` belirliyor.
    return Container(
      height: 96,
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Text('Sık görüştüklerin',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF9A9AA0), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: kisiler.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final c = kisiler[i];
                final ad = c.title.isNotEmpty ? c.title : 'Kişi';
                return GestureDetector(
                  onTap: () => context.push('/chat/${c.id}', extra: {
                    'title': ad,
                    'peer_id': c.peerId,
                    'avatar_media_id': c.avatarMediaId,
                  }),
                  child: SizedBox(
                    width: 62,
                    child: Column(children: [
                      // ⚠️ TURU 76: ham CircleAvatar YERINE ortak `Avatar` —
                      //    `users.avatar_url` sunucuda HIC yazilmiyor (kalici bos
                      //    string), fotograf ancak `avatar_media_id` ile (imzali
                      //    R2 adresi) gorunur. Bu serit uygulamanin en cok
                      //    bakilan yeriydi ve DAIMA harf ciziyordu.
                      Avatar(ad: ad, mediaId: c.avatarMediaId, cap: 48),
                      const SizedBox(height: 4),
                      Text(ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
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

  /// [benimMi]: son mesaji BEN mi gonderdim (arama kaydinda gonderen = ARAYAN).
  /// Bilinmiyorsa null -> onizleme yon iddiasinda BULUNMAZ.
  /// ⚠️ TURU 62 — ONIZLEME IKONU (kullanici emri: "uygulamada hicbir 3B ikon
  /// istemiyorum, hepsi 2B olsun"). Onizlemeler eskiden metnin ICINE emoji
  /// koyuyordu (📷 🎥 🎤 📍 📞 📹); emoji sistem emoji fontuyla PARLAK/3B cizilir.
  /// Artik ikon ayri bir Lucide (2B cizgi) widget'i olarak ciziliyor.
  /// ⚠️ YAPMA: onizleme metnine emoji geri koyma.
  IconData? _previewIkon() {
    switch (chat.lastType) {
      case 'image':
        return LucideIcons.image;
      case 'video':
        return LucideIcons.video;
      case 'audio':
        return LucideIcons.mic;
      case 'location':
        return LucideIcons.mapPin;
      case 'system':
        final k = AramaKaydi.coz(chat.lastMessage);
        if (k == null) return null;
        return k.video ? LucideIcons.video : LucideIcons.phone;
      default:
        return null;
    }
  }

  String _preview(bool? benimMi) {
    switch (chat.lastType) {
      case 'image':
        return 'Fotoğraf';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Sesli mesaj';
      case 'location':
        return 'Konum';
      case 'system':
        // TURU 59 — ARAMA KAYDI: eskiden HAM icerik basiliyordu, kullanici sohbet
        // listesinde "call:ended:audio:75" goruyordu. Ayristirma `AramaKaydi`de TEK
        // yerde (balonla ayni kaynak).
        // ⚠️ Taninmayan bicimde de HAM metin BASILMAZ (sozlesme: arama_kaydi.dart) —
        // aksi halde teknik isaretci listeye sizar. Yeni sistem mesaji turu
        // eklendiginde buraya ve `_CallLogChip`e insan-okur metin eklenmelidir.
        return AramaKaydi.coz(chat.lastMessage)?.onizleme(benimMi: benimMi) ??
            'Sistem mesajı';
      default:
        return chat.lastMessage;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // TURU 59: arama kaydi onizlemesinde YON icin. Kimlik veya `last_sender_id`
    // yoksa null kalir -> onizleme yon iddiasinda bulunmaz (guvenli varsayilan).
    final myId = ref.watch(myUserIdProvider).valueOrNull;
    final bool? benimMi = (myId == null || chat.lastSenderId.isEmpty)
        ? null
        : chat.lastSenderId == myId;
    final satir = ListTile(
      // ⚠️ TURU 76: bkz. yukaridaki serh. Grup sohbetinin kendi `avatar_media_id`i
      //    henuz yok -> `Avatar` harf yedegine duser (dogru davranis).
      leading: Avatar(ad: chat.title, mediaId: chat.avatarMediaId, cap: 52),
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
      subtitle: Builder(builder: (context) {
        final ikon = _previewIkon();
        final metin = Text(
          _preview(benimMi),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: chat.unread > 0 ? FontWeight.w600 : FontWeight.normal),
        );
        if (ikon == null) return metin;
        return Row(children: [
          Icon(ikon, size: 14, color: scheme.outline),
          const SizedBox(width: 5),
          Expanded(child: metin),
        ]);
      }),
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
        'avatar_media_id': chat.avatarMediaId,
        'title': chat.title.isNotEmpty ? chat.title : 'Sohbet',
        'peer_id': chat.peerId,
      }),
    );

    // ⚠️⚠️ TURU 76 — KAYDIRMA AKSIYONLARI (kullanici emri: "mesaj sol sag
    //    yapinca sil/arsivle cikmali"). Uygulamada daha once HICBIR swipe
    //    hareketi YOKTU (Dismissible/Slidable proje genelinde 0 kullanim).
    // ⚠️ `Dismissible` DEGIL `Slidable`: Dismissible ogeyi AGACTAN SILER; arsiv
    //    gibi GERI ALINABILIR bir islemde satiri geri getirmek icin ek durum
    //    yonetimi gerekirdi. Slidable panel acar, satir YERINDE kalir.
    // ⚠️ `groupTag` ZORUNLU: ayni gruptaki baska bir satir acilinca bu
    //    kendiliginden KAPANIR (iki satir birden acik kalmaz).
    return Slidable(
      key: ValueKey(chat.id),
      groupTag: 'sohbet',
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _ayar(context, ref, pinned: !chat.pinned),
            backgroundColor: const Color(0xFF3A3A45),
            foregroundColor: Colors.white,
            icon: chat.pinned ? LucideIcons.pinOff : LucideIcons.pin,
            label: chat.pinned ? 'Kaldır' : 'Sabitle',
          ),
          SlidableAction(
            onPressed: (_) => _ayar(context, ref, muted: !chat.sessiz),
            backgroundColor: const Color(0xFF4A4A55),
            foregroundColor: Colors.white,
            icon: chat.sessiz ? LucideIcons.bell : LucideIcons.bellOff,
            label: chat.sessiz ? 'Sesi aç' : 'Sessiz',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _ayar(context, ref, archived: !chat.archived),
            backgroundColor: const Color(0xFF6C2BD9),
            foregroundColor: Colors.white,
            icon: chat.archived ? LucideIcons.archiveRestore : LucideIcons.archive,
            label: chat.archived ? 'Geri al' : 'Arşivle',
          ),
          SlidableAction(
            onPressed: (_) => _sil(context, ref),
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            label: 'Sil',
          ),
        ],
      ),
      child: satir,
    );
  }

  /// Sabitle / arşivle / sessize al. ⚠️ Gonderilmeyen alan sunucuda DEGISMEZ.
  Future<void> _ayar(BuildContext context, WidgetRef ref,
      {bool? pinned, bool? archived, bool? muted}) async {
    final mesajci = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).patch('/chats/${chat.id}', data: {
        if (pinned != null) 'pinned': pinned,
        if (archived != null) 'archived': archived,
        if (muted != null) 'muted': muted,
      });
      await ref.read(chatsProvider.notifier).load();
    } catch (e) {
      mesajci.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  /// Sohbeti BENDEN sil.
  /// ⚠️ Karsi tarafin gecmisi ETKILENMEZ — sunucu satiri silmez, `cleared_at`
  ///    damgasi atar (bkz. internal/chat/grup.go serhi). Metin bunu ACIKCA soyler,
  ///    yoksa kullanici "karsi taraftan da silindi" saniyor.
  Future<void> _sil(BuildContext context, WidgetRef ref) async {
    final mesajci = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sohbet silinsin mi?'),
        content: const Text(
            'Bu sohbet yalnızca sizden silinir. Karşı taraf mesajları görmeye '
            'devam eder.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sil', style: TextStyle(color: Color(0xFFD32F2F)))),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref.read(apiProvider).delete('/chats/${chat.id}');
      await ref.read(chatsProvider.notifier).load();
    } catch (e) {
      mesajci.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
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

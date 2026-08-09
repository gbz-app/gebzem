import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/ws.dart';
import '../../router.dart' show rootMessengerKey;
import '../auth/auth_provider.dart';
import '../calls/active_call_controller.dart';
import '../calls/call_provider.dart';
import 'arama_kaydi.dart';
import 'chats_provider.dart';
import 'grup_bilgi.dart';
import 'models.dart';
import 'moderasyon_sheet.dart'; // turu 74: uzun basma menusu + engelle/sikayet
import '../medya/atac_paneli.dart';
import '../medya/medya_gorsel.dart';
import '../medya/medya_servisi.dart';
import '../medya/tam_ekran_gorsel.dart';
import '../medya/ses_notu_balon.dart';
import '../medya/ses_notu_kaydedici.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.peerId,
    this.avatarMediaId,
    this.isGroup = false,
  });

  final String chatId;
  final String title;
  final String? peerId; // 1:1 sohbette karsi tarafin id'si (arama icin)

  /// ⚠️ TURU 76b — GRUP MU. Basliga dokununca "Grup bilgisi" ekrani acilir
  ///    (uyeler + uye ekle/cikar + gruptan ayril).
  /// ⚠️ `peerId == null` kontrolune GUVENILMEZ: cagiran karsi tarafin kimligini
  ///    bilmiyorsa 1:1 sohbet de "grup" sanilirdi.
  final bool isGroup;

  /// ⚠️ TURU 76: sohbet basliginda AVATAR HIC YOKTU (WhatsApp'ta daima vardir).
  ///    Opsiyonel — cagiran bilmiyorsa harf yedegine duser, EK ISTEK ATILMAZ.
  final String? avatarMediaId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _typingThrottle;
  Timer? _typingUiTimer;
  bool _sending = false;
  // KARSI TARAFIN ARAMA DURUMU (test turu 17 -> 18 DUZELTME): '' | 'audio' | 'video' | 'stream'.
  // YALNIZ IKON RENGI icin kullanilir — kullanici istegi: basliktaki YAZI KALDIRILDI ve
  // dugmeler ARTIK KILITLENMEZ. Sebep (kullanici bulgusu): durum 15sn'de bir tazelendigi icin
  // arama biter bitmez karsi taraf hala "sesli aramada" gorunup ARAMA ENGELLENIYORDU.
  // Artik: (a) her arama bitisinde durum ANINDA tazelenir, (b) tazelenmemis olsa bile
  // dokunus aramayi DENER (son sozu sunucu soyler: gercekten mesgulse 409 mesaji cikar).
  String _peerDurum = '';

  /// TURU 74 — bu kisiyi engelledim mi (menu etiketi icin).
  /// ⚠️ Sunucudan `/users/me/blocks` ile BIR KEZ okunur; engelle/kaldir sonrasi
  ///     yerel olarak cevrilir. Bayat kalirsa zarari YOK: menu yanlis etiket
  ///     gosterir ama sunucu ucu IDEMPOTENT (iki kez engelleme de 200 doner).
  bool _engelli = false;

  /// TURU 74: sunucuda medya acik mi (R2 env). Kapaliysa atac dugmesi CIZILMEZ.
  bool _medyaAcik = false;

  /// ⚠️ TURU 76b: bu bir GRUP sohbeti mi.
  ///    ONCELIK `widget.isGroup` (sohbet listesi `chat.type`den ACIKCA tasir);
  ///    yedek olarak "peerId yoksa gruptur" varsayimi KALIR — grup olusturma
  ///    akisi gibi bayragi gecirmeyen eski yollar bozulmasin.
  ///    Balonlarda gonderen adi YALNIZ grupta cizilir.
  bool get _grupMu => widget.isGroup || widget.peerId == null;
  bool _yukleniyor = false;
  double _ilerleme = 0;

  /// TURU 74: ses notu kaydedicisine erisim (kayit seridi + basili tut alani).
  final _sesKey = GlobalKey<State<SesNotuKaydedici>>();
  Timer? _durumTimer;
  ProviderSubscription? _aramaSub;
  bool _oncekiAramaVar = false;

  @override
  void initState() {
    super.initState();
    // "yaziyor..." etiketini 3 sn sonra dusurmek icin periyodik kontrol
    _typingUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (widget.peerId != null) {
      _engelDurumunuOku(); // turu 74: menu etiketi ("Engelle" / "Engeli kaldır")
    }
    _medyaDurumunuOku();
    if (widget.peerId != null) {
      _durumTazele();
      _durumTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _durumTazele(),
      );
      // ARAMA BITER BITMEZ TAZELE (test turu 18 duzeltmesi): aktif arama null'a dusunce
      // ~1sn sonra sor — sunucunun 'ended' yazmasina zaman taniyip bayat "mesgul"
      // gostergesini ANINDA temizler (kullanici: "kapattim, hemen tekrar arayamiyorum").
      _aramaSub = ref.listenManual(activeCallProvider, (prev, next) {
        final simdi = next.arama != null;
        if (_oncekiAramaVar && !simdi) {
          Future.delayed(const Duration(seconds: 1), _durumTazele);
        }
        _oncekiAramaVar = simdi;
      });
    }
  }

  /// Karsi taraf su an aramada/yayinda mi (GET /users/{id}/presence). Hata sessiz yutulur —
  /// durum bilgisi ek bir kolaylik, sohbeti bloklamaz.
  /// TURU 74 — bu kisiyi engellemis miyim (menu etiketi icin, TEK SEFER).
  /// ⚠️ Hata YUTULUR: engel listesi alinamazsa menu "Engelle" der; ucu idempotent
  ///     oldugu icin yanlis etiket zarar vermez. Sohbet ekranini bloklamaz.
  Future<void> _engelDurumunuOku() async {
    try {
      final res = await ref.read(apiProvider).get('/users/me/blocks');
      final list = (res.data as List?) ?? [];
      final v = list.any((e) => (e as Map)['id'] == widget.peerId);
      if (mounted && v != _engelli) setState(() => _engelli = v);
    } catch (_) {}
  }

  /// ⚠️⚠️ TURU 74 — FOTOĞRAF GÖNDERME AKIŞI.
  ///
  /// Sıra ZORUNLU: seç → sıkıştır+EXIF temizle → R2'ye yükle → commit → mesaj.
  /// Mesaj EN SONDA atılır; medya doğrulanmadan mesaj yazılırsa alıcıda BOŞ balon
  /// çizilirdi (gönderen "gitti" sanar, karşı taraf hiçbir şey görmez).
  ///
  /// ⚠️ `client_ref`: yükleme dakikalar sürebiliyor ve kullanıcı "gitmedi" sanıp
  ///     tekrar basıyor. Sunucu aynı referansla ikinci mesaj AÇMAZ.
  /// ⚠️ Hata YUTULMAZ: kullanıcıya söylenir. "Gönderdim sandım ama gitmemiş" bu
  ///     projede defalarca yaşandı.
  Future<void> _atacAc() async {
    final secim = await atacPaneliAc(context, ref);
    if (secim == null || secim.dosyalar.isEmpty || !mounted) return;

    final altyazi = _input.text.trim();
    setState(() => _yukleniyor = true);
    final servis = ref.read(medyaServisiProvider);
    final notifier = ref.read(messagesProvider(widget.chatId).notifier);
    var gonderilen = 0;

    // ⚠️⚠️ TURU 74b (DENETİM BULGUSU): `try` DÖNGÜNÜN İÇİNDE.
    //     Eskiden dıştaydı: 5 fotoğraftan 3.'sü başarısız olursa (bozuk dosya,
    //     ağ hatası) `throw` döngüyü KOMPLE kesiyordu — kalan 2 fotoğraf HİÇ
    //     denenmiyor, tek genel hata mesajı çıkıyor ve kullanıcı hangisinin
    //     gittiğini BİLMİYORDU.
    var basarisiz = 0;
    try {
      for (var i = 0; i < secim.dosyalar.length; i++) {
        try {
          final ham = secim.dosyalar[i];
          // ⚠️ Sıkıştırma + EXIF temizleme ZORUNLU (gizlilik: konum bilgisi).
          //    Başarısız olursa HAM dosya GÖNDERİLMEZ — sunucu GPS bulursa zaten
          //    422 döner; boşuna 5 MB yükleyip reddedilmesindense burada duruyoruz.
          final hazir = await MedyaServisi.gorseliHazirla(ham);
          if (hazir == null) {
            throw Exception('Fotoğraf hazırlanamadı');
          }
          final mediaId = await servis.yukle(
            dosya: hazir,
            kind: 'image',
            mime: 'image/jpeg',
            ilerleme: (o) {
              if (mounted) {
                setState(() => _ilerleme = (i + o) / secim.dosyalar.length);
              }
            },
          );
          // ⚠️ Altyazı YALNIZCA İLK fotoğrafa yazılır (WhatsApp davranışı);
          //    her fotoğrafa kopyalamak gürültü olurdu.
          await notifier.send(
            i == 0 ? altyazi : '',
            type: 'image',
            mediaId: mediaId,
            clientRef:
                mediaId, // media_id benzersiz -> ideal idempotency anahtarı
          );
          gonderilen++;
        } catch (e) {
          basarisiz++;
          // ⚠️ Tek fotoğraf hatası KALANLARI ENGELLEMEZ; sonuç sonda özetlenir.
          if (secim.dosyalar.length == 1 && mounted) {
            rootMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(apiErrorMessage(e))),
            );
          }
        }
      }
      if (mounted && altyazi.isNotEmpty && gonderilen > 0) _input.clear();
      if (mounted && basarisiz > 0 && secim.dosyalar.length > 1) {
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              '$gonderilen gönderildi, $basarisiz tanesi başarısız',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _ilerleme = 0;
        });
      }
    }
    if (gonderilen > 0) _scrollToBottom();
  }

  /// ⚠️ TURU 74 — SES NOTU GONDER. Kaydedici dosyayi verir, yukleme burada olur.
  /// ⚠️ `waveform` ve `duration_ms` presign istegine gider ve `media_assets`e
  ///     yazilir; karsi taraf dalga formunu SUNUCUDAN alir (yeniden hesaplamaz).
  Future<void> _sesNotuGonder(File dosya, int sureMs, String dalga) async {
    if (!mounted) return;
    // ⚠️⚠️ TURU 74b (DENETİM BULGUSU): notifier ÖNDEN yakalanır. Yükleme
    //     dakikalarca sürebilir; sonrasında `ref.read(...)` widget dispose
    //     olmuşsa `StateError` atar (turu 67'nin "ref after dispose" sınıfı),
    //     `catch` yutar, `mounted` false olduğu için kullanıcıya HİÇBİR ŞEY
    //     söylenmez → **dosya R2'ye yüklendi, mesaj hiç yazılmadı.**
    final notifier = ref.read(messagesProvider(widget.chatId).notifier);
    final servis = ref.read(medyaServisiProvider);
    setState(() => _yukleniyor = true);
    try {
      final mediaId = await servis.yukle(
        dosya: dosya,
        kind: 'audio',
        mime: 'audio/mp4', // m4a (AAC-LC) — kaydedici bu kodeki uretir
        durationMs: sureMs,
        waveform: dalga,
        ilerleme: (o) {
          if (mounted) setState(() => _ilerleme = o);
        },
      );
      await notifier.send(
        '',
        type: 'audio',
        mediaId: mediaId,
        clientRef: mediaId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _ilerleme = 0;
        });
      }
    }
  }

  /// TURU 74 — sunucuda medya açık mı (R2 env). Kapalıysa ataç düğmesi ÇİZİLMEZ.
  /// ⚠️ Görünen ama çalışmayan düğme, turu 66b dersinin tekrarı olurdu.
  Future<void> _medyaDurumunuOku() async {
    try {
      final res = await ref.read(apiProvider).get('/users/me');
      final v = (res.data as Map?)?['media_acik'] == true;
      if (mounted && v != _medyaAcik) setState(() => _medyaAcik = v);
    } catch (_) {}
  }

  Future<void> _durumTazele() async {
    final pid = widget.peerId;
    if (pid == null) return;
    try {
      final res = await ref.read(apiProvider).get('/users/$pid/presence');
      final m = (res.data as Map?) ?? const {};
      final tip = m['call_type'] as String? ?? '';
      final yeni = tip.isNotEmpty
          ? tip
          : (m['in_stream'] == true ? 'stream' : '');
      if (mounted && yeni != _peerDurum) setState(() => _peerDurum = yeni);
    } catch (_) {}
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _typingThrottle?.cancel();
    _typingUiTimer?.cancel();
    _durumTimer?.cancel();
    _aramaSub?.close();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _aramaBasliyor = false;

  /// Sesli/goruntulu arama baslat
  Future<void> _startCall({required bool video}) async {
    final peerId = widget.peerId;
    if (peerId == null || _aramaBasliyor) return;
    _aramaBasliyor =
        true; // cift dokunma -> cift arama / sahte "mesgul" kaydini onle
    try {
      final info = await ref
          .read(callServiceProvider.notifier)
          .start(peerId, video: video);
      if (!mounted) return;
      // FAZ-C: mantik controller'da baslar, ekran saf gorunum olarak acilir
      final ctrl = ref.read(activeCallProvider);
      await ctrl.baslat(
        AramaBilgisi(
          callId: info['call_id'] as String,
          url: info['url'] as String,
          token: info['token'] as String,
          video: video,
          peerName: widget.title,
          peerId: peerId,
        ),
      );
      ctrl.ekraniAc();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      _aramaBasliyor = false;
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

    final typing =
        notifier.typingAt != null &&
        DateTime.now().difference(notifier.typingAt!).inSeconds < 3;

    return Scaffold(
      appBar: AppBar(
        // ⚠️ TURU 76: baslikta AVATAR. Avatari basligin ICINE koyduk (leading'e
        //    degil) — geri oku ve mevcut "actions" duzeni BOZULMAZ.
        titleSpacing: 0,
        // ⚠️⚠️ TURU 76b — GRUPTA BASLIGA DOKUNUNCA "Grup bilgisi" ACILIR.
        //    Sunucudaki UC grup-uye ucu (`GET/POST/DELETE .../members`)
        //    istemciden HIC CAGRILMIYORDU: grup kurulabiliyor ama uyeleri
        //    gorulemiyor, uye eklenemiyor/cikarilamiyordu. Giris noktasi
        //    olmadan yazilan uc = OLU OZELLIK (CLAUDE.md'nin tekrar eden dersi).
        // ⚠️ WhatsApp/Telegram deseni: baslik dokunmatik. Ayri bir ikon
        //    eklemedik — sag ustte zaten iki arama ikonu + menu var.
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _grupMu
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrupBilgiEkrani(
                      chatId: widget.chatId,
                      baslik: widget.title,
                      avatarMediaId: widget.avatarMediaId,
                    ),
                  ),
                )
              : null,
          child: Row(
            children: [
              Avatar(ad: widget.title, mediaId: widget.avatarMediaId, cap: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17),
                    ),
                    // NOT (test turu 18): "Sesli aramada" YAZISI KALDIRILDI (kullanici istemedi).
                    // Durum yalniz arama ikonlarinin renginde ima edilir.
                    if (typing)
                      Text(
                        'yazıyor...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    else if (widget.isGroup)
                      // ⚠️ Kesfedilebilirlik: baslik dokunmatik oldugu ANLASILMALI,
                      //    yoksa ozellik yine "yok" sanilir.
                      const Text(
                        'Grup bilgisi için dokun',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (widget.isGroup)
                const Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
        actions: () {
          // IKON DURUMU (test turu 18 DUZELTMESI): kisi SESLI aramadaysa ses ikonu yesil,
          // goruntu ikonu SOLUK; goruntuluyse tersi. AMA HICBIRI KILITLENMEZ — dokunus her
          // zaman aramayi dener. (Kullanici bulgusu: arama biter bitmez bayat "mesgul"
          // gostergesi yuzunden TEKRAR ARANAMIYORDU. Son sozu SUNUCU soyler.)
          final sesAktif = _peerDurum == 'audio';
          final videoAktif = _peerDurum == 'video';
          final mesgul = _peerDurum.isNotEmpty;
          final soluk = Theme.of(context).disabledColor;
          return [
            IconButton(
              tooltip: 'Görüntülü ara',
              color: videoAktif
                  ? const Color(0xFF25D366)
                  : (mesgul ? soluk : null),
              icon: const Icon(LucideIcons.video),
              onPressed: widget.peerId == null
                  ? null
                  : () => _startCall(video: true),
            ),
            IconButton(
              tooltip: 'Sesli ara',
              color: sesAktif
                  ? const Color(0xFF25D366)
                  : (mesgul ? soluk : null),
              icon: const Icon(LucideIcons.phone),
              onPressed: widget.peerId == null
                  ? null
                  : () => _startCall(video: false),
            ),
            // ⚠️ TURU 74 — MODERASYON MENUSU. App Store Review Guideline 1.2 (UGC)
            //    engelleme ve sikayeti kullanicinin ULASABILECEGI bir yerde sart kosuyor.
            if (widget.peerId != null)
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.ellipsisVertical),
                onSelected: (secim) async {
                  if (secim == 'engelle') {
                    final degisti = await engelleOnayiAc(
                      context,
                      ref,
                      kullaniciId: widget.peerId!,
                      ad: widget.title,
                      suAnEngelli: _engelli,
                    );
                    if (degisti && mounted) {
                      setState(() => _engelli = !_engelli);
                    }
                  } else if (secim == 'sikayet') {
                    await sikayetSheetAc(
                      context,
                      ref,
                      hedefTur: 'kullanici',
                      hedefId: widget.peerId!,
                    );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'engelle',
                    child: Row(
                      children: [
                        Icon(
                          _engelli ? LucideIcons.userCheck : LucideIcons.ban,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(_engelli ? 'Engeli kaldır' : 'Engelle'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sikayet',
                    child: Row(
                      children: [
                        Icon(LucideIcons.flag, size: 18),
                        SizedBox(width: 10),
                        Text('Şikâyet et'),
                      ],
                    ),
                  ),
                ],
              ),
          ];
        }(),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(apiErrorMessage(e))),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('İlk mesajı sen gönder'));
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  // TEST TURU 29 (kullanici: "sana chatte 'aramaya dön' vb. yap dedim,
                  // sen HEADER eklemişsin"): aktif arama kucultulmusken bu satir artik
                  // ust serit DEGIL, mesaj akisinin EN ALTINDA bir BALON (WhatsApp).
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) {
                    if (i == list.length) return const _AktifAramaBalonu();
                    final msg = list[i];
                    final mine = msg.senderId == myId;
                    final showDate =
                        i == 0 ||
                        !_sameDay(list[i - 1].createdAt, msg.createdAt);
                    return Column(
                      children: [
                        if (showDate) _DateChip(date: msg.createdAt),
                        if (msg.type == 'system')
                          _CallLogChip(
                            message: msg,
                            mine: mine,
                            // TURU 58: balona dokununca alttan "Sesli / Goruntulu ara"
                            onAra: widget.peerId == null
                                ? null
                                : (video) => _startCall(video: video),
                          )
                        else
                          // ⚠️ TURU 74 — UZUN BASMA MENUSU (kopyala / herkesten sil /
                          //    sikayet et). App Store 1.2 (UGC) sarti.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () => mesajMenusuAc(
                              context,
                              ref,
                              mesaj: msg,
                              benimMi: mine,
                              chatId: widget.chatId,
                            ),
                            child: _Bubble(
                              message: msg,
                              mine: mine,
                              grup: _grupMu,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // ⚠️ TURU 74 — YÜKLEME İLERLEMESİ. Fotoğraf yüklemesi yavaş hatta
          //    dakikalar sürebiliyor; gösterge olmazsa kullanıcı "gitmedi" sanıp
          //    tekrar basıyor (ve `client_ref` olmasaydı çift mesaj olurdu).
          if (_yukleniyor)
            LinearProgressIndicator(
              value: _ilerleme > 0 ? _ilerleme : null,
              minHeight: 3,
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  // ⚠️ TURU 74 — ATAÇ. Medya sunucuda kapalıysa (R2 env yok) düğme
                  //    HİÇ ÇİZİLMEZ: `GET /users/me` yanıtındaki `media_acik`.
                  //    Görünen ama çalışmayan düğme, turu 66b dersinin tekrarı olurdu.
                  if (_medyaAcik)
                    IconButton(
                      tooltip: 'Ekle',
                      icon: const Icon(LucideIcons.paperclip),
                      onPressed: _yukleniyor ? null : _atacAc,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _send(),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yazın',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        // Faz 2: atas (medya) butonu buraya
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ⚠️ TURU 74 — metin BOŞKEN mikrofon, DOLUYKEN gönder (WhatsApp).
                  //    Ses notu kaydı arama/oda/yayın sırasında ENGELLİ; kapı
                  //    `SesNotuKaydedici._basla` içinde. Ölçülmüş gerekçe:
                  //    turu 64 `!pri`, turu 65 `didActivate` gelmiyor, turu 62-C rota.
                  if (_medyaAcik && _input.text.trim().isEmpty)
                    SesNotuKaydedici(key: _sesKey, onKayit: _sesNotuGonder)
                  else
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
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      label = 'Bugün';
    } else if (now.difference(local).inDays == 1) {
      label = 'Dün';
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

/// TEST TURU 29 — AKTIF ARAMA BALONU (kullanici istegi: "chatte 'aramaya dön' yaz"
/// demistim, HEADER yapilmisti). Arama KUCULTULMUSKEN mesaj akisinin EN ALTINDA,
/// WhatsApp'taki gibi yesil bir BALON olarak durur; dokununca aramaya doner.
/// Arama yoksa/kucultulmemisse hicbir sey cizmez.
class _AktifAramaBalonu extends ConsumerWidget {
  const _AktifAramaBalonu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.watch(activeCallProvider);
    if (ctrl.arama == null || !ctrl.minimized) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Material(
          color: const Color(0xFF075E54),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: ctrl.restore,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.phone,
                    size: 16,
                    color: Color(0xFF25D366),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctrl.isGroup ? 'Grup aramasındasın' : 'Aramadasın',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Geri dönmek için dokun · ${ctrl.durumMetni}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sohbet thread'inde arama kaydi (WhatsApp gibi ortalanmis notr satir).
/// content formati: 'call:missed:audio' | 'call:missed:video'. sender_id her zaman
/// arayan -> mine=true (giden) "cevap yok", mine=false (gelen) "Cevapsiz arama".
class _CallLogChip extends StatelessWidget {
  const _CallLogChip({required this.message, required this.mine, this.onAra});

  final Message message;
  final bool mine;

  /// TURU 58: balona dokununca alttan panel -> secilen tiple arama baslatir.
  /// null ise (peerId yok) balon dokunulamaz kalir.
  final void Function(bool video)? onAra;

  /// WhatsApp deseni: balona dokun -> alttan "Sesli ara / Goruntulu ara".
  void _panelAc(BuildContext context, bool videoVarsayilan) {
    if (onAra == null) return;
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.phone, color: Color(0xFF25D366)),
              title: const Text('Sesli ara'),
              onTap: () {
                Navigator.of(c).pop();
                onAra!(false);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.video, color: Color(0xFF25D366)),
              title: const Text('Görüntülü ara'),
              onTap: () {
                Navigator.of(c).pop();
                onAra!(true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // TURU 59 — ayristirma `AramaKaydi`de TEK yerde (sohbet listesi onizlemesiyle
    // ayni kaynak). ⚠️ YAPMA: burada tekrar `content.split(':')` yazma — iki
    // ayristirici kacinilmaz sekilde birbirinden ayrisir.
    final kayit = AramaKaydi.coz(message.content);
    if (kayit == null) {
      // Arama disi / taninmayan sistem mesaji. Bugun sunucu YALNIZ `call:*` yaziyor;
      // bu dal ULASILMAZ ama ileride yeni bir sistem mesaji eklenirse SESSIZCE
      // YUTULMASIN (turu 48 dersi: "ulasilamaz kod").
      // ⚠️ HAM `message.content` BASILMAZ — `call:group:end:5f2c…` gibi teknik
      // isaretciler kullaniciya sizardi (arama_kaydi.dart'taki sozlesme).
      // Yeni bir sistem mesaji turu eklendiginde BURAYA ve `chats_screen._preview`e
      // insan-okur metin eklenmelidir.
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Chip(
          label: Text('Sistem mesajı', style: TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    // TEST TURU 21 — GRUP ARAMASI KAYDI: 'call:group:invite:<id>' / 'call:group:end:<id>'
    if (kayit.grup) {
      final bitti = kayit.grupBitti;
      final saat = DateFormat.Hm().format(message.createdAt.toLocal());
      final metin = bitti
          ? 'Grup araması sona erdi'
          : (mine
                ? 'Grup araması · davet gönderildi'
                : 'Grup araması · Davet edildiniz');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Chip(
          avatar: Icon(
            LucideIcons.video,
            size: 15,
            color: bitti ? scheme.outline : const Color(0xFF25D366),
          ),
          label: Text('$metin · $saat', style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    // TEST TURU 58 — WHATSAPP BALONU (kullanici ekran goruntusu paylasti).
    // Eskiden ORTADA kucuk bir `Chip` idi; artik mesaj balonlariyla AYNI hizada,
    // ikon + baslik + (sure/durum) + saat tasiyan bir BALON. Dokununca alttan
    // "Sesli ara / Goruntulu ara" paneli acilir.
    // Icerik bicimleri: "call:missed:audio|video" · "call:ended:audio|video:<sn>"
    final video = kayit.video;
    final missed = kayit.cevapsiz;
    final sn = kayit.saniye;
    final time = DateFormat.Hm().format(message.createdAt.toLocal());

    final baslik = video ? 'Görüntülü arama' : 'Sesli arama';
    // "Cevapsız görüntülü arama" / "Cevapsız sesli arama" — Turkce'de sifattan sonra
    // kucuk harf dogru (ekran goruntusundeki Messenger metniyle ayni).
    final baslikKucuk = video ? 'görüntülü arama' : 'sesli arama';
    final String altSatir;
    if (missed) {
      altSatir = mine ? 'Cevap yok' : 'Cevapsız';
    } else if (sn > 0) {
      altSatir = AramaKaydi.sureMetni(sn);
    } else {
      altSatir = mine ? 'Giden arama' : 'Gelen arama';
    }
    final vurgu = missed && !mine; // gelen cevapsiz -> kirmizi
    // Giden/gelen ok ikonu (WhatsApp deseni): balonun sol yuvarlagi
    final okIkon = mine ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft;

    // ⚠️ TURU 63 — MESSENGER TARZI KART (kullanici ekran goruntusu paylasti):
    // yuvarlak ikon + baslik + saat, ALTINDA tam genislikte "Geri ara" dugmesi.
    // Cevapsizda ikon dairesi KIRMIZI dolu; cevaplanan/gidende notr.
    // ⚠️ YAPMA: buraya emoji koyma (turu 62: arayuzde emoji YOK).
    final daireRengi = vurgu
        ? const Color(0xFFE53935)
        : scheme.surfaceContainerHigh;
    final ikonRengi = vurgu ? Colors.white : scheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: daireRengi,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          video ? LucideIcons.video : LucideIcons.phone,
                          size: 19,
                          color: ikonRengi,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              missed && !mine
                                  ? 'Cevapsız $baslikKucuk'
                                  : baslik,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(okIkon, size: 12, color: scheme.outline),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '$altSatir · $time',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: scheme.outline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // "Geri ara" — kartin ICINDE, tam genislikte (ekran goruntusundeki gibi).
                  // Dokununca alttan "Sesli ara / Görüntülü ara" paneli acilir.
                  if (onAra != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: scheme.surfaceContainerHigh.withValues(
                          alpha: 0.9,
                        ),
                        borderRadius: BorderRadius.circular(11),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _panelAc(context, video),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'Geri ara',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, this.grup = false});

  final Message message;
  final bool mine;

  /// ⚠️⚠️ TURU 76 — GRUPTA GONDEREN ADI/AVATARI ZORUNLU.
  ///    Mesaj balonlarinda gonderen bilgisi HIC YOKTU. Grup ozelligi eklendigi
  ///    ANDA sohbet OKUNAMAZ hale gelirdi: 20 kisilik grupta tum mesajlar
  ///    isimsiz gri balon olarak gorunur, kimin yazdigi ayirt edilemezdi.
  ///    Yani grup ucunu tek basina eklemek YETMEZDI.
  /// ⚠️ 1:1'de CIZILMEZ (gereksiz gurultu — zaten iki kisi var).
  final bool grup;

  /// Gonderen adinin rengi — kimlige gore SABIT.
  /// ⚠️ Rastgele DEGIL: her cizimde degisen renk grup sohbetini okunmaz yapar.
  // TURU 78: govde core/theme.dart -> kimlikRengi() icine TASINDI (tek kaynak).

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat.Hm().format(message.createdAt.toLocal());

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
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
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚠️ GRUPTA gonderen adi — KENDI mesajimda cizilmez.
            if (grup && !mine && message.senderName.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      // Ada gore SABIT renk: ayni kisi hep ayni renkte gorunur
                      // (WhatsApp deseni) — okunurlugu ciddi artirir.
                      color: kimlikRengi(message.senderId),
                    ),
                  ),
                ),
              ),
            if (message.deletedForAll)
              Text(
                'Bu mesaj silindi',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: scheme.outline,
                ),
              )
            else ...[
              // ⚠️ TURU 74 — GORSEL BALON. `media_id` var ama artik sunucuda
              //     kaldirilmissa (karantina/silindi) `MedyaGorsel` kirik ikon
              //     cizer; balon YINE DE cizilir (mesaj gecmisi bozulmasin).
              if (message.type == 'image' && (message.mediaId ?? '').isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: message.content.isEmpty ? 0 : 6,
                  ),
                  child: ConstrainedBox(
                    // ⚠️ En-boy SABITLENMEZ: dikey/yatay fotograf kirpilmasin.
                    //     Yukseklik tavani ekranin %45'i — uzun panoramalar balonu
                    //     ele gecirmesin.
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) =>
                              TamEkranGorsel(mediaId: message.mediaId!),
                        ),
                      ),
                      child: MedyaGorsel(
                        mediaId: message.mediaId!,
                        kucuk:
                            true, // liste icinde kucuk resim YETER (veri tasarrufu)
                        fit: BoxFit.cover,
                        radius: 8,
                      ),
                    ),
                  ),
                ),
              // ⚠️ TURU 74 — SES NOTU BALONU. Dalga formu ve süre SUNUCUDAN gelir
              //    (`media_assets.waveform` / `duration_ms`), istemcide yeniden
              //    hesaplanmaz — alıcının dosyayı indirmeden dalga çizebilmesi için.
              if (message.type == 'audio' && (message.mediaId ?? '').isNotEmpty)
                SesNotuBalon(
                  mediaId: message.mediaId!,
                  sureMs: message.durationMs,
                  dalga: message.waveform,
                  benimMi: mine,
                ),
              if (message.content.isNotEmpty)
                Text(message.content, style: const TextStyle(fontSize: 15.5)),
            ],
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
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

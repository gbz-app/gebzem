import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
import 'anket.dart';
import 'arama_kaydi.dart';
import 'chats_provider.dart';
import 'grup_bilgi.dart';
import 'iban_paneli.dart';
import 'models.dart';
import 'moderasyon_sheet.dart'; // turu 74: uzun basma menusu + engelle/sikayet
import 'user_search_screen.dart';
import '../etkinlik/etkinlik_ekranlari.dart';
import '../etkinlik/etkinlik_servisi.dart';
import '../medya/atac_paneli.dart';
import '../medya/konum_servisi.dart';
import '../sosyal/profil_sayfasi.dart';
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

  /// ⚠️ TURU 81 — ses kaydı sürüyor mu? Kaydedici `onDurum` ile bildirir;
  ///    true iken giriş çubuğu (ataç + metin alanı) GİZLENİR ve kaydedici tam
  ///    genişlikte şeride dönüşür. Tek kaynak KAYDEDİCİDİR — burada bağımsız
  ///    bir kayıt durumu tutulmaz.
  bool _sesKayitta = false;
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
    if (secim == null || !mounted) return;

    // ⚠️⚠️ TURU 81 — DOSYASIZ EYLEMLER. Panel yalnizca HANGISININ secildigini
    //    soyler; akisi BURADA yurutuyoruz cunku sheet pop edildikten sonra
    //    onun `context`i olur (turu 74b'de ataç dugmesi tam bu yuzden HIC
    //    calismiyordu).
    switch (secim.eylem) {
      case 'konum':
        await _konumGonder();
        return;
      case 'kisi':
        await _kisiGonder();
        return;
      case 'iban':
        await _ibanGonder();
        return;
      case 'etkinlik':
        await _etkinlikGonder();
        return;
      case 'anket':
        await _anketGonder();
        return;
    }

    if (secim.dosyalar.isEmpty) return;

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

  // ══════════════ TURU 81 — DOSYASIZ PAYLASIMLAR ══════════════
  //
  // ⚠️⚠️ ORTAK KURAL: hepsi `notifier`i **await'ten ONCE** yakalar. Yukleme /
  //    izin diyalogu / secici saniyelerce surebilir ve o sirada ekran dispose
  //    olursa `ref.read` `StateError` atar, `catch` yutar ve is SESSIZCE iptal
  //    olur — bu projede DEFALARCA yasandi (turu 67 · 77b · 78b).

  /// Konum gonder. Icerik "enlem,boylam" DUZ METIN (bkz. `KonumServisi` serhi).
  Future<void> _konumGonder() async {
    final notifier = ref.read(messagesProvider(widget.chatId).notifier);
    final k = await KonumServisi.konumAl();
    if (k == null) return; // KonumServisi kullaniciya sebebi soyledi
    try {
      await notifier.send(
        '${k.enlem.toStringAsFixed(6)},${k.boylam.toStringAsFixed(6)}',
        type: 'location',
      );
      _scrollToBottom();
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  /// Kisi paylas — kullanici seciciden bir profil secilir.
  ///
  /// ⚠️ Icerik "userId|Ad Soyad": ID gorunmez, ad GORUNUR. Tanimadigi tipi
  ///    HAM basan bir yuzey (eski istemci / push) en kotu ihtimalle
  ///    "uuid|Ahmet" gorur — okunabilir bir seydir, JSON coplugu degil.
  Future<void> _kisiGonder() async {
    final notifier = ref.read(messagesProvider(widget.chatId).notifier);
    final secilen = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const UserSearchScreen(secimModu: true),
      ),
    );
    if (secilen == null || !mounted) return;
    final id = (secilen['id'] ?? '').toString();
    final ad = (secilen['name'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      await notifier.send('$id|$ad', type: 'contact');
      _scrollToBottom();
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  /// IBAN gonder.
  ///
  /// ⚠️ IBAN **DOGRULANIR** (TR + 24 hane + mod-97). Gerekce: yanlis IBAN'a
  ///    yapilan havale GERI DONMEZ. Bicimsel dogrulama tum hatalari yakalamaz
  ///    ama tek karakter dusmesi/eklenmesi gibi en sik hatayi yakalar.
  /// ⚠️ Icerik "TR.. |Ad Soyad" DUZ METIN.
  Future<void> _ibanGonder() async {
    final notifier = ref.read(messagesProvider(widget.chatId).notifier);
    final sonuc = await ibanPaneliAc(context);
    if (sonuc == null || !mounted) return;
    try {
      await notifier.send('${sonuc.iban}|${sonuc.ad}', type: 'iban');
      _scrollToBottom();
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  /// Etkinlik olustur ve sohbette paylas.
  ///
  /// ⚠️ ETKINLIK MEVCUT UC ILE olusturulur (`internal/etkinlik`, turu 78) —
  ///    sohbet icin AYRI bir etkinlik yolu YAZILMADI. Ikinci bir olusturma
  ///    yolu kacinilmaz olarak DRIFT ederdi (alanlar, dogrulama, medya).
  /// ⚠️ Icerik "etkinlikId|Baslik".
  Future<void> _etkinlikGonder() async {
    final notifier = ref.read(messagesProvider(widget.chatId).notifier);
    final etkinlikSvc = ref.read(etkinlikServisiProvider);
    // ⚠️ Ekran olusturulan etkinligin **id**'sini (String) doner — mevcut
    //    sozlesme DEGISTIRILMEDI (diger cagiran da onu bekliyor).
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EtkinlikOlusturEkrani()),
    );
    if (id == null || id.isEmpty || !mounted) return;
    // ⚠️ Baslik GONDERIM ANINDA bir kez cekilir ve icerige GOMULUR (baglanti
    //    onizlemesi mantigi). Alternatif "her balon cizerken sunucudan cek"
    //    olurdu ve cok paylasimli bir sohbette N istek demekti.
    //    ⚠️ Baslik sonradan degisirse balondaki metin ESKI kalir — ama dokunus
    //       her zaman GUNCEL detay ekranini acar, yani yanlis bilgiye
    //       goturmez.
    var baslik = '';
    try {
      baslik = (await etkinlikSvc.detay(id)).baslik;
    } catch (_) {
      // ⚠️ Baslik alinamazsa PAYLASIM IPTAL EDILMEZ: etkinlik OLUSTU, onu
      //    sohbette gostermemek daha kotu olurdu. Balon id ile calisir.
    }
    if (!mounted) return;
    try {
      await notifier.send('$id|$baslik', type: 'etkinlik');
      _scrollToBottom();
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  /// Anket olustur ve gonder.
  ///
  /// ⚠️ MESAJI SUNUCU YAZAR (`POST /chats/{id}/polls` tek islemde mesaj +
  ///    anket + secenekler + makbuzlari yazar). Istemci AYRICA `send`
  ///    CAGIRMAZ — cagirsaydi anketsiz IKINCI bir mesaj olusurdu.
  Future<void> _anketGonder() async {
    final taslak = await anketPaneliAc(context);
    if (taslak == null || !mounted) return;
    final anketSvc = ref.read(anketServisiProvider);
    final notifier = ref.read(messagesProvider(widget.chatId).notifier);
    try {
      await anketSvc.olustur(
        chatId: widget.chatId,
        soru: taslak.soru,
        secenekler: taslak.secenekler,
        coklu: taslak.coklu,
      );
      // ⚠️ Liste SUNUCUDAN tazelenir: anket mesaji sunucuda olustugu icin
      //    yerel listeye elle eklemek iki kaynak yaratirdi.
      await notifier.load();
      _scrollToBottom();
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
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
              Avatar(ad: widget.title, mediaId: widget.avatarMediaId, cap: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // ⚠️ TURU 115b — ad KALIN: eskiden govde metniyle ayni
                      //    agirliktaydi ve baslik "baslik gibi" durmuyordu.
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
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
                      Text(
                        'Grup bilgisi için dokun',
                        // ⚠️ TURU 115b — SABIT `Colors.grey` DEGIL: koyu temada
                        //    yeterince ayrilmiyordu (olculdu 2.9:1).
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.isGroup)
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
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
          final scheme = Theme.of(context).colorScheme;
          return [
            IconButton(
              tooltip: 'Görüntülü ara',
              color: videoAktif ? scheme.primary : (mesgul ? soluk : null),
              icon: const Icon(LucideIcons.video),
              onPressed: widget.peerId == null
                  ? null
                  : () => _startCall(video: true),
            ),
            IconButton(
              tooltip: 'Sesli ara',
              color: sesAktif ? scheme.primary : (mesgul ? soluk : null),
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
                  // ⚠️⚠️⚠️ TURU 81 — KAYIT SÜRERKEN GİRİŞ ÇUBUĞU YERİNİ ŞERİDE
                  //    BIRAKIR (Instagram deseni). Kaydedici o anda tam
                  //    genişlikte çizilir: [çöp] ~dalga~ 0:07 [gönder].
                  //    Aksi halde şerit dar bir Row hücresine sıkışır ve
                  //    dalga görünmezdi.
                  // ⚠️ Durum kaydediciden `onDurum` ile gelir; burada AYRI bir
                  //    kayıt bayrağı TUTULMAZ (iki kopya drift ederdi).
                  if (_sesKayitta)
                    Expanded(
                      child: SesNotuKaydedici(
                        key: _sesKey,
                        onKayit: _sesNotuGonder,
                        onDurum: (k) => setState(() => _sesKayitta = k),
                      ),
                    )
                  else ...[
                    // ⚠️ TURU 74 — ATAÇ. Medya sunucuda kapalıysa (R2 env yok) düğme
                    //    HİÇ ÇİZİLMEZ: `GET /users/me` yanıtındaki `media_acik`.
                    //    Görünen ama çalışmayan düğme, turu 66b dersinin tekrarı olurdu.
                    // ⚠️⚠️ TURU 115b — GIRIS CUBUGU MODERNLESTIRILDI (kullanici
                    //    emri: *"chat bolumunu daha profesyonel modern bir
                    //    gorunume getir"*).
                    //    ESKI: atac hapin DISINDA ayri bir `IconButton`, hap
                    //    kendi basina, gonder bir `FloatingActionButton`. Uc ayri
                    //    yukseklik ve uc ayri hizalama vardi.
                    //    YENI: atac hapin ICINDE (WhatsApp/Telegram deseni),
                    //    gonder TEK dolu daire.
                    // ⚠️ `prefixIcon` KULLANILMADI: cok satirli alanda prefix
                    //    DIKEY ORTALANIR, yani 5 satirlik mesajda atac ortada
                    //    asili kalirdi. `Row` + `crossAxisAlignment.end` ile
                    //    ikon DAIMA alt satirda durur.
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // ⚠️ TURU 74 — ATAC. Medya sunucuda kapaliysa (R2 env
                            //    yok) dugme HIC CIZILMEZ: `GET /users/me`
                            //    yanitindaki `media_acik`. Gorunen ama
                            //    calismayan dugme turu 66b dersinin tekrari olurdu.
                            if (_medyaAcik)
                              IconButton(
                                tooltip: 'Ekle',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  LucideIcons.paperclip,
                                  size: 20,
                                ),
                                onPressed: _yukleniyor ? null : _atacAc,
                              ),
                            Expanded(
                              child: TextField(
                                controller: _input,
                                onChanged: _onChanged,
                                onSubmitted: (_) => _send(),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                minLines: 1,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  hintText: 'Mesaj yazın',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.fromLTRB(
                                    _medyaAcik ? 0 : 16,
                                    12,
                                    12,
                                    12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ⚠️ TURU 74 — metin BOŞKEN mikrofon, DOLUYKEN gönder (WhatsApp).
                    //    Ses notu kaydı arama/oda/yayın sırasında ENGELLİ; kapı
                    //    `SesNotuKaydedici._basla` içinde. Ölçülmüş gerekçe:
                    //    turu 64 `!pri`, turu 65 `didActivate` gelmiyor, turu 62-C rota.
                    if (_medyaAcik && _input.text.trim().isEmpty)
                      SesNotuKaydedici(
                        key: _sesKey,
                        onKayit: _sesNotuGonder,
                        onDurum: (k) => setState(() => _sesKayitta = k),
                      )
                    else
                      // ⚠️ `FloatingActionButton` DEGIL: FAB'in kendi 6 dp
                      //    golgesi ve 40 dp sabit olcusu var; giris hapiyla
                      //    hizalanmiyordu. Duz daire hapla AYNI dikey eksende.
                      // ⚠️ Dokunma alani 44 dp (Apple/Material tavsiyesi) —
                      //    ikon 20 dp ama kutu buyuk.
                      Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _sending ? null : _send,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              LucideIcons.send,
                              size: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
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
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Material(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: ctrl.restore,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.phone, size: 16, color: scheme.onPrimary),
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
      builder: (c) {
        final scheme = Theme.of(c).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(LucideIcons.phone, color: scheme.primary),
                title: const Text('Sesli ara'),
                onTap: () {
                  Navigator.of(c).pop();
                  onAra!(false);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.video, color: scheme.primary),
                title: const Text('Görüntülü ara'),
                onTap: () {
                  Navigator.of(c).pop();
                  onAra!(true);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
            color: bitti ? scheme.outline : scheme.primary,
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
              // ⚠️⚠️⚠️ TURU 81 — YAPISAL TIPLER KENDI BALONUNU CIZER.
              //
              //	Bu kapi olmasaydi asagidaki `Text(message.content)` dali
              //	devreye girer ve kullanici sohbette HAM icerik gorurdu:
              //	"41.008200,28.978400" · "TR33…|Ahmet" · "uuid|Konser".
              //	Denetim bu sinifi ("tanimadigi tipin content'ini HAM basma")
              //	acikca isaret etmisti — kapi UC yerde birden gerekiyor:
              //	balon (burasi), sohbet listesi onizlemesi ve PUSH (ikisi de
              //	SUNUCUDA, `handler.go` preview switch'i).
              // ⚠️ ANKET: `content` SORUYU tasir ama balon anketin KENDISINI
              //    cizer (secenekler + oy sayilari). Soruyu ayrica `Text` ile
              //    basmak IKI KEZ gosterirdi.
              if (message.type == 'poll' && message.anket != null)
                AnketBalon(anket: message.anket!, benimMi: mine)
              else if (_yapisalTipler.contains(message.type))
                _YapisalBalon(message: message, benimMi: mine)
              else if (message.content.isNotEmpty)
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

/// ⚠️⚠️ TURU 81 — YAPISAL ICERIK TASIYAN MESAJ TIPLERI.
///
/// Bu kumedeki tiplerin `content` alani KULLANICIYA GOSTERILECEK METIN DEGIL,
/// AYRISTIRILACAK VERIDIR. `_YapisalBalon` disinda hicbir yerde ham basilmamali.
/// ⚠️ Sunucuya yeni bir yapisal tip eklerken BURAYI ve `handler.go`daki
///    onizleme switch'ini BIRLIKTE guncelle.
const _yapisalTipler = {'location', 'contact', 'iban', 'etkinlik'};

/// Konum · Kisi · IBAN · Etkinlik balonlari.
///
/// ⚠️ HEPSI TEK WIDGET: dort ayri balon sinifi, dolgu/yaricap/renk kurallarini
///    dort kez kopyalamak demekti ve bu projede "ayni kuralin iki kopyasi
///    drift eder" hatasi ALTI kez tekrarladi.
class _YapisalBalon extends ConsumerWidget {
  const _YapisalBalon({required this.message, required this.benimMi});

  final Message message;
  final bool benimMi;

  /// "deger|etiket" -> (deger, etiket). Etiket yoksa bos doner.
  (String, String) _bol() {
    final i = message.content.indexOf('|');
    if (i < 0) return (message.content.trim(), '');
    return (
      message.content.substring(0, i).trim(),
      message.content.substring(i + 1).trim(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (message.type) {
      'location' => _konum(context),
      'contact' => _kisi(context),
      'iban' => _iban(context),
      'etkinlik' => _etkinlik(context, ref),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _kart(
    BuildContext context, {
    required IconData ikon,
    required Color renk,
    required String baslik,
    required String alt,
    required String eylem,
    required VoidCallback onEylem,
  }) {
    return ConstrainedBox(
      // ⚠️ Genislik TAVANI: uzun bir IBAN ya da etkinlik basligi balonu
      //    ekrandan tasirmasin.
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(ikon, size: 19, color: renk),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      baslik,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    if (alt.isNotEmpty)
                      Text(
                        alt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ⚠️ Eylem TAM GENISLIKTE ve 40dp: balon icinde kucuk bir metin
          //    baglantisi olsaydi basmak zor olurdu (turu 78b dokunma alani dersi).
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton(
              onPressed: onEylem,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(eylem, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _konum(BuildContext context) {
    final k = KonumServisi.ayrist(message.content);
    if (k == null) {
      // ⚠️ BOZUK ICERIK: ham basmak yerine DURUST etiket.
      return const Text('Konum (okunamadı)', style: TextStyle(fontSize: 14));
    }
    return _kart(
      context,
      ikon: LucideIcons.mapPin,
      renk: const Color(0xFFEF5350),
      baslik: 'Konum',
      alt: '${k.enlem.toStringAsFixed(4)}, ${k.boylam.toStringAsFixed(4)}',
      eylem: 'Haritada aç',
      onEylem: () => KonumServisi.haritadaAc(k.enlem, k.boylam),
    );
  }

  Widget _kisi(BuildContext context) {
    final (id, ad) = _bol();
    return _kart(
      context,
      ikon: LucideIcons.userRound,
      renk: const Color(0xFF42A5F5),
      baslik: ad.isEmpty ? 'Kişi' : ad,
      alt: '',
      eylem: 'Profili gör',
      onEylem: () {
        if (id.isEmpty) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: id)));
      },
    );
  }

  Widget _iban(BuildContext context) {
    final (iban, ad) = _bol();
    return _kart(
      context,
      ikon: LucideIcons.creditCard,
      renk: const Color(0xFF26A69A),
      // ⚠️ IBAN DORTLU GRUPLANIR: 26 karakterlik kesintisiz dize okunamaz ve
      //    kullanici elle karsilastirirken hata yapar.
      baslik: _ibanGruplu(iban),
      alt: ad,
      eylem: 'Kopyala',
      onEylem: () async {
        await Clipboard.setData(ClipboardData(text: iban));
        rootMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('IBAN kopyalandı')),
        );
      },
    );
  }

  static String _ibanGruplu(String s) {
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  Widget _etkinlik(BuildContext context, WidgetRef ref) {
    final (id, baslik) = _bol();
    return _kart(
      context,
      ikon: LucideIcons.calendarDays,
      renk: const Color(0xFFFFA726),
      baslik: baslik.isEmpty ? 'Etkinlik' : baslik,
      alt: '',
      eylem: 'Etkinliği gör',
      // ⚠️ Detay ekrani `Etkinlik` NESNESI istiyor (id degil) — mevcut
      //    sozlesme DEGISTIRILMEDI, dokunusta SUNUCUDAN cekiyoruz.
      //    Bu ayni zamanda DOGRU davranis: balondaki baslik paylasim aninin
      //    fotografidir, detay ise HER ZAMAN guncel olmali.
      onEylem: () async {
        if (id.isEmpty) return;
        final nav = Navigator.of(context);
        try {
          final e = await ref.read(etkinlikServisiProvider).detay(id);
          await nav.push(
            MaterialPageRoute(builder: (_) => EtkinlikDetayEkrani(etkinlik: e)),
          );
        } catch (_) {
          rootMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Etkinlik bulunamadı')),
          );
        }
      },
    );
  }
}

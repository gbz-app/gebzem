import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/tercihler.dart';
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
import 'kisi_bilgi.dart';
import 'iban_paneli.dart';
import 'models.dart';
import 'moderasyon_sheet.dart'; // turu 74: uzun basma menusu + engelle/sikayet
import 'user_search_screen.dart';
import '../etkinlik/etkinlik_ekranlari.dart';
import '../etkinlik/etkinlik_servisi.dart';
import '../medya/atac_paneli.dart';
import '../medya/belge_karti.dart';
import '../medya/medya_kapisi.dart';
import '../medya/video_poster.dart';
import '../medya/konum_servisi.dart';
import '../sosyal/profil_sayfasi.dart';
import '../medya/medya_gorsel.dart';
import '../medya/medya_servisi.dart';
import '../medya/tam_ekran_gorsel.dart';
import '../medya/tam_ekran_video.dart';
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
  /// TURU 180z — "+" seridi acik mi (giris cubugunun USTUNDE).
  bool _atacAcik = false;
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
  /// ⚠️⚠️⚠️ TURU 180z — "+" ARTIK ALT SAYFA ACMIYOR.
  ///
  ///	Kullanici emri: *"artiya bastiginda hemen ustunde popup acilsin,
  ///	INPUTUN USTUNDE; orada resim, gorsel, etkinlik vs hepsi olsun,
  ///	SCROLL seklinde"*. Panel artik giris cubugunun HEMEN USTUNDE bir
  ///	serit (`_AtacSerit`) ve YATAY kayiyor.
  /// ⚠️ Eski `atacPaneliAc` sheet'i SILINMEDI ama BURADAN CAGRILMIYOR;
  ///	eylemler ayni `_atacEylem` govdesinden gecer (tek kaynak).
  void _atacDegistir() {
    FocusScope.of(context).unfocus();
    setState(() => _atacAcik = !_atacAcik);
  }

  /// ⚠️ Dosyasiz eylemler (konum · kisi · IBAN · etkinlik · anket) ve dosyali
  ///	secimler AYNI yerden yurutulur.
  Future<void> _atacEylem(String eylem) async {
    setState(() => _atacAcik = false);
    switch (eylem) {
      case 'foto':
        return _galeriden(video: false);
      case 'video':
        return _galeriden(video: true);
      case 'kamera':
        return _kameradan();
      // ⚠️ TURU 180z — BELGE (sunucu mesaj tipi beyaz listesinde
      //	'document' ZATEN VAR; yeni tip acilmadi).
      case 'belge':
        return _belgeGonder();
      case 'konum':
        return _konumGonder();
      case 'kisi':
        return _kisiGonder();
      case 'iban':
        return _ibanGonder();
      case 'etkinlik':
        return _etkinlikGonder();
      case 'anket':
        return _anketGonder();
    }
  }

  /// ⚠️⚠️⚠️ TURU 180z — SOHBETE **BELGE** (PDF/Word/Excel/txt).
  ///
  /// ⚠️ Sunucu bunu ZATEN destekliyordu: mesaj tipi beyaz listesinde
  ///	`document` VAR ve `media_assets.kind` CHECK'i onu kabul ediyor.
  ///	Eksik olan TEK sey istemci yoluydu.
  /// ⚠️ Uzanti/MIME/boyut kapilari `MedyaSecici.belge` icinde TEK KAYNAKTA.
  Future<void> _belgeGonder() async {
    if (!MedyaKapisi.izinVer(ref)) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            MedyaKapisi.engelSebebi(ref) ?? 'Şu anda dosya seçilemez',
          ),
        ),
      );
      return;
    }
    final dosya = await MedyaSecici.belge(
      uyar: (m) => rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(m)),
      ),
    );
    if (dosya == null || !mounted) return;
    return _medyaGonder(AtacSecimi([dosya], 'document'));
  }

  /// ⚠️ SOLDAKI MOR DAIRE ve serit'teki "Fotoğraf"/"Video" AYNI yoldan gecer.
  Future<void> _galeriden({required bool video}) async {
    if (!MedyaKapisi.izinVer(ref)) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez',
          ),
        ),
      );
      return;
    }
    if (video) {
      // ⚠️ Sure + boyut kapisi `MedyaSecici.video` icinde (tek kaynak).
      final dosya = await MedyaSecici.video(
        sureTavani: const Duration(minutes: 5),
        uyar: (m) => rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(m)),
        ),
        ref: ref,
      );
      if (dosya == null || !mounted) return;
      return _medyaGonder(AtacSecimi([dosya], 'video'));
    }
    final secim = await MedyaSecici.coklu(10);
    if (secim.isEmpty || !mounted) return;
    return _medyaGonder(
      AtacSecimi(secim.map((x) => File(x.path)).toList(), 'image'),
    );
  }

  Future<void> _kameradan() async {
    if (!MedyaKapisi.izinVer(ref)) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            MedyaKapisi.engelSebebi(ref) ?? 'Görüşme sürerken kullanılamaz',
          ),
        ),
      );
      return;
    }
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        // ⚠️ Cekim aninda dusur: 4K fotografi bellege alip sonra sikistirmak
        //    dusuk bellekli cihazlarda uygulamayi olduruyor.
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;
    return _medyaGonder(AtacSecimi([File(x.path)], 'image'));
  }

  // ignore: unused_element
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

    await _medyaGonder(secim);
  }

  /// ⚠️ TURU 180z — YUKLEME ZINCIRI TEK KAYNAK. Uc giris kullaniyor:
  ///	soldaki mor daire · "+" seridi · eski atac sheet'i. Ayri kopyalar
  ///	KACINILMAZ olarak drift ederdi (bu projede ALTI kez yasandi).
  Future<void> _medyaGonder(AtacSecimi secim) async {
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
          // ⚠️⚠️ TURU 180x — VIDEO DALI. Video **SIKISTIRILMAZ**:
          //    `gorseliHazirla` bir JPEG uretir, videoya uygulansaydi dosya
          //    BOZULUR ve karsi tarafta acilmayan bir balon cizilirdi.
          //    Boyut ve SURE kapilari `MedyaSecici.video` icinde (tek kaynak).
          final videoMu = secim.tur == 'video';
          // ⚠️ TURU 180z — BELGE dali: sikistirilmaz, EXIF temizlenmez
          //	(bir PDF'e JPEG uretici uygulamak dosyayi BOZAR).
          final belgeMu = secim.tur == 'document';
          final File hazir;
          if (videoMu || belgeMu) {
            hazir = ham;
          } else {
            // ⚠️ Sıkıştırma + EXIF temizleme ZORUNLU (gizlilik: konum bilgisi).
            //    Başarısız olursa HAM dosya GÖNDERİLMEZ — sunucu GPS bulursa zaten
            //    422 döner; boşuna 5 MB yükleyip reddedilmesindense burada duruyoruz.
            final h = await MedyaServisi.gorseliHazirla(ham);
            if (h == null) {
              throw Exception('Fotoğraf hazırlanamadı');
            }
            hazir = h;
          }
          // ⚠️⚠️⚠️ TURU 180z — **VIDEO POSTERI** (kullanici: *"videolarda
          //	on izleme olsun"*). Sunucu ffmpeg CALISTIRMAZ; poster
          //	istemcide uretilip `thumb_bytes` ile yuklenir. Uretilemezse
          //	video POSTERSIZ gider (en iyi caba).
          final poster = videoMu ? await videoPosteriUret(hazir) : null;
          final ad = ham.uri.pathSegments.last;
          final mediaId = await servis.yukle(
            dosya: hazir,
            kind: secim.tur == '' ? 'image' : secim.tur,
            mime: switch (secim.tur) {
              'video' => 'video/mp4',
              'document' => MedyaSecici.belgeMime(ad),
              _ => 'image/jpeg',
            },
            kucukResim: poster,
            fileName: ad,
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
            // ⚠️ Sunucu mesaj tipi beyaz listesinde 'document' ZATEN
            //	VAR (chat/handler.go) — yeni tip ACILMADI.
            type: secim.tur == '' ? 'image' : secim.tur,
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
      // ⚠️⚠️⚠️ TURU 180z — ZEMIN **TAM SIYAH** (kullanici: *"arka plan siyah
      //	degil"*). Sohbet ekrani temanin `scaffoldBackgroundColor`ini
      //	(`_icerikZemin` = **#1C1C1E**, "siyahin BIR TIK acigi") kullaniyordu;
      //	kardes ekranlarin hepsi `kAiZemin` (**#050308**) ile ciziliyor ve
      //	fark listeden sohbete gecerken GORULUYORDU.
      // ⚠️ `koyuSayfa` ile SARILMADI: bu dosyada onlarca `State` metodu
      //	ciplak `context` okuyor ve `koyuSayfa` temayi `build`in DONDURDUGU
      //	agaca koyar — o metotlar temayi GORMEZ (bu projede ONBIR kez sahaya
      //	cikan tuzak). Zemini dogrudan boyamak ayni sonucu veriyor ve
      //	hicbir renk kaynagini degistirmiyor.
      backgroundColor: kAiZemin,
      appBar: AppBar(
        // ⚠️ Header de AYNI siyah: varsayilan M3 `AppBar` yuzeyi govdeden
        //	acik kalir ve tepede GORUNUR bir dikis birakirdi (turu 180r).
        backgroundColor: kAiZemin,
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
          // ⚠️⚠️ TURU 180z — 1:1'DE DE BASLIK TIKLANABILIR (kullanici emri:
          //	*"direk profile tikladigimiz yerde olsun"*). Eskiden YALNIZ
          //	grupta tiklanabiliyordu; ⋮ kalkinca engelle/sikayet ULASILAMAZ
          //	kalirdi.
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
              : (widget.peerId == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KisiBilgiEkrani(
                            chatId: widget.chatId,
                            peerId: widget.peerId!,
                            baslik: widget.title,
                            avatarMediaId: widget.avatarMediaId,
                            sesliAra: () => _startCall(video: false),
                            goruntuluAra: () => _startCall(video: true),
                          ),
                        ),
                      )),
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
            // ⚠️⚠️ TURU 180z — IKI IKON **OPTIK OLARAK ESITLENDI** (kullanici:
            //	*"video arama ikonu yaninda kucuk kaliyor, onu da buyut
            //	esitle"*).
            //	`size` ikonun CIZILEN murekkebini degil SINIR KUTUSUNU olcer;
            //	Lucide 24'luk izgarada `phone` govdeyi kosegen doldurur,
            //	`video` ise yatay bir dikdortgen ve ayni `size`da GORSEL
            //	OLARAK KUCUK kalir (turu 139'da ayni sinif olculmustu).
            // ⚠️ Yerlesim kutusu DEGISMEZ (`IconButton` 48 dp): satir kaymaz.
            IconButton(
              tooltip: 'Görüntülü ara',
              color: videoAktif ? scheme.primary : (mesgul ? soluk : null),
              icon: const Icon(LucideIcons.video, size: 26),
              onPressed: widget.peerId == null
                  ? null
                  : () => _startCall(video: true),
            ),
            IconButton(
              tooltip: 'Sesli ara',
              color: sesAktif ? scheme.primary : (mesgul ? soluk : null),
              icon: const Icon(LucideIcons.phone, size: 22),
              onPressed: widget.peerId == null
                  ? null
                  : () => _startCall(video: false),
            ),
            // ⚠️⚠️⚠️ TURU 180z — **UC NOKTA (⋮) KALDIRILDI** (kullanici emri:
            //	*"mesajdaki sagdaki 3 noktayi sil, direk profile tikladigimiz
            //	yerde olsun"*). Engelle/Sikayet ULASILAMAZ KALMADI: ikisi de
            //	basliga dokununca acilan `KisiBilgiEkrani`nda.
            // ⚠️ App Store Review Guideline 1.2 (UGC) engelleme ve sikayeti
            //	kullanicinin ULASABILECEGI bir yerde sart kosuyor — o sart
            //	Kisi bilgisi ekraniyla KARSILANIYOR.
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
                              yildizli: tercihler.yildizliMi(
                                widget.chatId,
                                msg.id,
                              ),
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
          // ⚠️⚠️⚠️ TURU 180z — ATAC SERIDI **INPUTUN USTUNDE** (kullanici emri:
          //	*"artiya bastiginda hemen ustunde popup acilsin, inputun
          //	ustunde; resim, gorsel, etkinlik vs hepsi orada olsun, SCROLL
          //	seklinde"*).
          // ⚠️ `showModalBottomSheet` DEGIL: sheet ekranin DIBINDEN acilir ve
          //	giris cubugunu ORTER; kullanici acikca "inputun ustunde" dedi.
          // ⚠️ `AnimatedSize` + `ClipRect`: acilis/kapanis yerinden ziplamadan
          //	olur. `ClipRect` ZORUNLU — `AnimatedSize` kucultme sirasinda
          //	cocugu KIRPMAZ ve icerik giris cubugunun uzerine biner
          //	(turu 180g dersi).
          if (_medyaAcik)
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: _atacAcik
                    ? _AtacSerit(onSec: _atacEylem)
                    : const SizedBox(width: double.infinity, height: 0),
              ),
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
                  else
                    // ⚠️⚠️⚠️ TURU 180z — **HER SEY TEK KAPSULUN (INPUTUN)
                    //	ICINDE** (kullanici emri: *"mesaj inputun icinde olacak
                    //	dedim her sey"*).
                    //	ESKI: [mor daire] [input] [mik] [+] — DORDU DE AYRI
                    //	kutulardi ve hap yalniz yazi alaniydi.
                    //	YENI: tek hap; solda mor daire fotograf, ortada yazi,
                    //	sagda mikrofon/gonder ve "+".
                    // ⚠️⚠️ `CrossAxisAlignment.end` ZORUNLU: `maxLines: 5` ile
                    //	yazi cok satira cikinca hap UZAR; ortalanmis olsaydi
                    //	ikonlar hapin ORTASINDA asili kalir ve ilk satirla
                    //	hizasi bozulurdu (WhatsApp da ikonlari ALTA yaslar).
                    // ⚠️ Medya sunucuda kapaliysa (R2 env yok) medya dugmeleri
                    //	HIC CIZILMEZ (`_medyaAcik`) — gorunen ama calismayan
                    //	dugme turu 66b dersinin tekrari olurdu.
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.06),
                          // ⚠️ Yaricap hapin YARI YUKSEKLIGINDEN buyuk:
                          //	tek satirda tam hap, cok satirda yumusak kose.
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_medyaAcik)
                              _YuvarlakDugme(
                                ikon: LucideIcons.image,
                                ipucu: 'Fotoğraf',
                                // ⚠️ MARKA MORU (`morGradient`) — alt menudeki
                                //	FAB ve hikaye paylas dairesiyle AYNI
                                //	kaynak; sabit hex yazilsaydi biri
                                //	degisince oteki geride kalirdi.
                                gradient: morGradient,
                                onTap: _yukleniyor
                                    ? null
                                    : () => _galeriden(video: false),
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
                                decoration: const InputDecoration(
                                  hintText: 'Mesaj yazın',
                                  border: InputBorder.none,
                                  isDense: true,
                                  // ⚠️ Dikey dolgu 10: ikon dairelerinin
                                  //	(36 dp) dikey merkeziyle yazi TABANI
                                  //	ayni hizaya gelsin.
                                  contentPadding: EdgeInsets.fromLTRB(
                                    10,
                                    10,
                                    6,
                                    10,
                                  ),
                                ),
                              ),
                            ),
                            // ⚠️ TURU 74 — metin BOŞKEN mikrofon, DOLUYKEN
                            //	gönder (WhatsApp). Ses notu kaydı arama/oda/
                            //	yayın sırasında ENGELLİ; kapı
                            //	`SesNotuKaydedici._basla` içinde. Ölçülmüş
                            //	gerekçe: turu 64 `!pri`, turu 65 `didActivate`
                            //	gelmiyor, turu 62-C rota.
                            if (_medyaAcik && _input.text.trim().isEmpty)
                              SesNotuKaydedici(
                                key: _sesKey,
                                onKayit: _sesNotuGonder,
                                onDurum: (k) =>
                                    setState(() => _sesKayitta = k),
                              )
                            else
                              // ⚠️ `FloatingActionButton` DEGIL: FAB'in kendi
                              //	6 dp golgesi ve 40 dp sabit olcusu var;
                              //	hapin ICINE sigmiyordu.
                              Material(
                                color: Theme.of(context).colorScheme.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _sending ? null : _send,
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Icon(
                                      LucideIcons.send,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            // ⚠️ TURU 180z — "+": panel INPUTUN USTUNDE acilir
                            //	(`_AtacSerit`), alt sayfa DEGIL.
                            if (_medyaAcik)
                              IconButton(
                                tooltip: 'Ekle',
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  _atacAcik ? LucideIcons.x : LucideIcons.plus,
                                  size: 21,
                                ),
                                onPressed: _yukleniyor ? null : _atacDegistir,
                              ),
                          ],
                        ),
                      ),
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

  /// ⚠️⚠️ TURU 180z — KULLANICI EMRI: *"tarihler buton icinde degil, BUGÜN
  ///	DÜN vs degil, TAM GUN ya da saat olsun"*.
  ///	  · `Chip` (buton gorunumu) KALKTI -> duz, ortali, soluk metin.
  ///	  · "Bugün"/"Dün" KALKTI -> **tam tarih** (9 Eylül 2026).
  /// ⚠️ Gun adi da yazilir ("Salı"): tam tarihte hangi gun oldugunu okumak
  ///	kullanicinin zaten yaptigi zihinsel isi ustlenir, "Bugün/Dün"un
  ///	tasidigi bilgi de KAYBOLMAZ.
  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final metin = DateFormat('d MMMM yyyy, EEEE', 'tr').format(local);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        metin,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
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
  const _Bubble({
    required this.message,
    required this.mine,
    this.grup = false,
    this.yildizli = false,
  });

  final Message message;
  final bool mine;

  /// ⚠️ TURU 180y — yildiz CIHAZDA tutuluyor; deger DISARIDAN gecirilir ki
  ///	balon `Tercihler`e bagimli olmasin (test edilebilir kalsin).
  final bool yildizli;

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

    // ⚠️⚠️ TURU 180z — **RESIM/VIDEODA BALON ZEMINI YOK** (kullanici emri:
    //	*"resim ve video arka plan rengi olmasin"*). Medya KENDI cercevesini
    //	tasiyor; arkasindaki mor/gri hap gereksiz bir cerceve uretiyordu.
    // ⚠️ YALNIZ altyazisiz medyada: altyazi varsa metnin okunabilmesi icin
    //	zemin GEREKIR (siyah sayfa uzerinde ciplak metin kayardi).
    // ⚠️ Saat + tik satiri KALIR (yalniz zemin kalkti) — gonderildi/okundu
    //	bilgisi medyada da gorunmeli.
    final altyaziBos =
        message.content.trim().isEmpty ||
        message.content.trim() == kTekKullanimlikIsaret;
    final sadeMedya =
        altyaziBos &&
        (message.type == 'image' || message.type == 'video') &&
        (message.mediaId ?? '').isNotEmpty;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: sadeMedya
            ? const EdgeInsets.only(bottom: 2)
            : const EdgeInsets.fromLTRB(12, 8, 8, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: sadeMedya
              ? Colors.transparent
              : (mine ? scheme.bubbleMine : scheme.bubbleOther),
          // ⚠️⚠️ TURU 180z — **TAM RADUS** (kullanici emri: *"sohbetler tam
          //	radus olacak"*). Eskiden bir kose 2 dp idi (WhatsApp'in
          //	"kuyruk" hissi); artik DORT KOSE de esit ve yuvarlak
          //	(Instagram DM dili).
          // ⚠️ 12 -> **18**: tek satirlik balon HAP gorunur; 22 denendi ve
          //	iki satirli balonda kose yayi metnin ilk harfini kirpiyordu
          //	(yatay dolgu 12 dp).
          borderRadius: BorderRadius.circular(18),
          // ⚠️ Zemin yokken GOLGE de olmaz: seffaf bir kutunun altinda
          //	golge, medyanin cevresinde acikligi belli olmayan gri bir
          //	hale birakirdi.
          boxShadow: sadeMedya
              ? null
              : [
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
              // ⚠️⚠️⚠️ TURU 180y — **TEK KULLANIMLIK FOTOGRAF** (kullanici
              //	emri: *"tek kullanimlik mesajlar atilmis gibi"*).
              //
              // ⚠️⚠️ **SUNUCUDA KARSILIGI YOK**: `messages`ta boyle bir tip
              //	ya da bayrak bulunmuyor (beyaz liste: text·image·video·
              //	audio·location·document·contact·iban·etkinlik). Prototipte
              //	gorulebilmesi icin ALTYAZI isaretcisi kullaniliyor
              //	(`kTekKullanimlikIsaret`) ve "acildi" bilgisi CIHAZDA
              //	tutuluyor.
              // ⚠️ DURUST SINIR: gercek tek-kullanimlik DEGIL — karsi taraf
              //	fotografi hala gorebilir, baska cihazda yeniden acilir.
              //	⏳ Gercegi icin `messages`a sutun + goruntulendikten sonra
              //	   icerigi bosaltan bir uc gerekir (BACKEND TURU).
              if (message.type == 'image' &&
                  (message.mediaId ?? '').isNotEmpty &&
                  message.content.trim() == kTekKullanimlikIsaret)
                _TekKullanimlikBalon(mediaId: message.mediaId!)
              else if (message.type == 'image' &&
                  (message.mediaId ?? '').isNotEmpty)
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
              // ⚠️⚠️ TURU 180x — VIDEO BALONU.
              //
              //	`media_kinds` sohbet mesajinda YOK: tur bilgisini
              //	`message.type` tasir, o yuzden ayrim GUVENLI.
              // ⚠️⚠️ Balonda **OYNATICI KURULMAZ**, yer tutucu + oynat rozeti
              //	cizilir. Gerekce olculdu (turu 76b/77b): listede canli
              //	`video_player` kurmak iOS'ta AVAudioSession'a dokunur ve
              //	SUREN ARAMAYI sagirlastirir; ayrica her balon icin ayri
              //	oynatici = isinma + veri. Dokununca TAM EKRAN acilir
              //	(`TamEkranVideo` kendi kapilarini tasiyor).
              // ⚠️ Poster YOK ve UYDURULMAZ: sohbet videosunda sunucu kapak
              //	karesi uretmiyor; sahte bir gorsel cizmek yalan olurdu.
              if (message.type == 'video' && (message.mediaId ?? '').isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: message.content.isEmpty ? 0 : 6,
                  ),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => TamEkranVideo(mediaId: message.mediaId!),
                      ),
                    ),
                    // ⚠️⚠️⚠️ TURU 180z — **ON IZLEME (POSTER)** (kullanici emri:
                    //	*"videolarda on izleme olsun"*). Poster GONDERIM aninda
                    //	uretilip `thumb_bytes` ile yuklenir (`video_poster.dart`).
                    // ⚠️⚠️ `yalnizThumb: true` ZORUNLU: bayraksiz `MedyaGorsel`
                    //	poster yoksa HAM VIDEO adresine duser ve
                    //	`CachedNetworkImage` bir mp4 cozemeyip KIRIK GORSEL cizer
                    //	(turu 83b sinifi). Bayrakla poster yoksa alttaki koyu kutu
                    //	KALIR — eski davranis kaybolmuyor.
                    // ⚠️ BALONDA OYNATICI KURULMAZ (turu 76b/77b): listede canli
                    //	`video_player` iOS'ta AVAudioSession'a dokunur ve SUREN
                    //	ARAMAYI sagirlastirir. Cizilen sey bir GORSEL.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 210,
                        height: 128,
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MedyaGorsel(
                              mediaId: message.mediaId!,
                              kucuk: true,
                              yalnizThumb: true,
                              fit: BoxFit.cover,
                            ),
                            Center(
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.45),
                                ),
                                child: const Icon(
                                  LucideIcons.play,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // ⚠️⚠️⚠️ TURU 180z — **BELGE BALONU**. Bu dal OLMADAN
              //	sunucunun kabul ettigi 'document' mesaji istemcide HIC
              //	CIZILMEZDI (yalniz metin govdesi kalirdi) — ozellik
              //	gonderilebilir ama GORULEMEZ olurdu.
              // ⚠️ Ad, mesajin `content` alanindan gelir (gonderirken dosya
              //	adi altyazi olarak YAZILMAZ; bos ise kart MIME'dan notr bir
              //	ad turetir, UYDURMA ad yazmaz).
              if (message.type == 'document' &&
                  (message.mediaId ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SizedBox(
                    width: 230,
                    child: BelgeKarti(mediaId: message.mediaId!),
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
              // ⚠️ TURU 180y — "tek kullanimlik" ISARETCISI ALTYAZI OLARAK
              //	CIZILMEZ: emulatorde goruldu, balonun altinda ham `[1x]`
              //	yaziyordu. Isaretci teknik bir bayrak, kullanici metni DEGIL.
              else if (message.content.isNotEmpty &&
                  message.content.trim() != kTekKullanimlikIsaret)
                Text(message.content, style: const TextStyle(fontSize: 15.5)),
            ],
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚠️ TURU 180y — YILDIZ ROZETI (kullanici emri). Isaret
                //	CIHAZDA tutulur; sunucuda karsiligi YOK (bkz.
                //	`Tercihler.yildizliMesajlar`). Saatin SOLUNDA duruyor
                //	ki okundu tikiyle karismasin.
                if (yildizli) ...[
                  const Icon(
                    LucideIcons.star,
                    size: 12,
                    color: Color(0xFFF6C445),
                  ),
                  const SizedBox(width: 4),
                ],
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

/// ⚠️⚠️ TURU 180y — TEK KULLANIMLIK FOTOGRAF BALONU.
///
/// Kapali halde icerik CIZILMEZ (indirilmez de): yalniz "Görüntülemek için
/// dokun". Acildiktan sonra CIHAZDA isaretlenir ve balon "Açıldı" der —
/// yani ayni kullanici ikinci kez acamaz.
///
/// ⚠️ Sunucuda karsiligi YOK (cagri yerindeki serh). Karsi taraf ve baska
///	cihazlar bu isareti GORMEZ.
class _TekKullanimlikBalon extends StatefulWidget {
  const _TekKullanimlikBalon({required this.mediaId});
  final String mediaId;

  @override
  State<_TekKullanimlikBalon> createState() => _TekKullanimlikBalonState();
}

class _TekKullanimlikBalonState extends State<_TekKullanimlikBalon> {
  late bool _acildi = tercihler.tekKullanimlikAcildiMi(widget.mediaId);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _acildi
          ? null
          : () async {
              await tercihler.tekKullanimlikAc(widget.mediaId);
              if (!mounted) return;
              setState(() => _acildi = true);
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => TamEkranGorsel(mediaId: widget.mediaId),
                ),
              );
            },
      child: Container(
        width: 210,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              _acildi ? LucideIcons.eyeOff : LucideIcons.eye,
              size: 20,
              color: _acildi ? scheme.outline : scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tek kullanımlık fotoğraf',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _acildi ? 'Açıldı' : 'Görüntülemek için dokun',
                    style: TextStyle(fontSize: 11.5, color: scheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⚠️ TURU 180z — GIRIS CUBUGUNDAKI YUVARLAK DUGME (soldaki mor daire).
///
/// ⚠️ Renk `morGradient` TEK KAYNAGINDAN: alt menudeki FAB ve hikaye paylas
///	dairesi de onu okuyor; sabit hex yazilsaydi biri degisince oteki
///	geride kalirdi (turu 119b'de tam bu yasandi).
/// ⚠️ Olcu 44 dp: klavye acikken ekranin EN ALTINDAKI dugme (turu 115c).
class _YuvarlakDugme extends StatelessWidget {
  const _YuvarlakDugme({
    required this.ikon,
    required this.ipucu,
    required this.onTap,
    this.gradient,
  });

  final IconData ikon;
  final String ipucu;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: ipucu,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              // ⚠️ TURU 180z — 44 -> **36**: dugme artik giris hapinin ICINDE
              //	(kullanici: *"her sey inputun icinde"*). 44 dp kalsaydi hap
              //	52 dp'ye cikip ekranin dibinde sisman bir serit birakirdi.
              //	Dokunma hedefi 36 dp; Material'in 48 dp tavsiyesinin altinda
              //	ama WhatsApp/Instagram da hap ici ikonlari boyle olcuyor ve
              //	hapin KENDISI (44 dp) parmagi yakaliyor.
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(ikon, size: 19, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ⚠️⚠️⚠️ TURU 180z — "+" SERIDI (giris cubugunun HEMEN USTUNDE).
///
/// Kullanici emri: *"orada resim, gorsel, etkinlik vs hepsi olsun, SCROLL
/// seklinde"*. YATAY kaydirilir; oge sayisi arttikca ekran YUKSEKLIGI
/// DEGISMEZ (alt sayfa tavani sorunu yapisal olarak biter — turu 180x'te
/// atac paneli tam bu yuzden 199 px tasmisti).
///
/// ⚠️ **GIF YOK ve BILEREK YOK**: sunucu `image/gif`i beyaz listeden ACIKCA
///	disliyor (`internal/media/sniff.go`: *"animasyonlu GIF kotu sikistirilir
///	ve GIF bombasi bir bellek saldirisidir"*). Gorunen ama HER SEFERINDE
///	hata veren bir dugme koymak turu 66b dersinin tekrari olurdu.
///	⏳ Gerekli: sunucu beyaz listesi + bir GIF saglayicisi (Giphy/Tenor).
class _AtacSerit extends StatelessWidget {
  const _AtacSerit({required this.onSec});

  final ValueChanged<String> onSec;

  static const _ogeler = <({String anahtar, IconData ikon, String ad, Color renk})>[
    (anahtar: 'foto', ikon: LucideIcons.image, ad: 'Fotoğraf', renk: Color(0xFF7C4DFF)),
    (anahtar: 'video', ikon: LucideIcons.video, ad: 'Video', renk: Color(0xFFEC407A)),
    (anahtar: 'kamera', ikon: LucideIcons.camera, ad: 'Kamera', renk: Color(0xFF00BFA5)),
    (anahtar: 'belge', ikon: LucideIcons.fileText, ad: 'Belge', renk: Color(0xFF5C7CFA)),
    (anahtar: 'konum', ikon: LucideIcons.mapPin, ad: 'Konum', renk: Color(0xFFEF5350)),
    (anahtar: 'kisi', ikon: LucideIcons.userRound, ad: 'Kişi', renk: Color(0xFF42A5F5)),
    (anahtar: 'iban', ikon: LucideIcons.creditCard, ad: 'IBAN', renk: Color(0xFF26A69A)),
    (anahtar: 'etkinlik', ikon: LucideIcons.calendarPlus, ad: 'Etkinlik', renk: Color(0xFFFFA726)),
    (anahtar: 'anket', ikon: LucideIcons.vote, ad: 'Anket', renk: Color(0xFF8B5CF6)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ⚠️ Yukseklik YAZI OLCEGINDEN turetilir, sabit dp DEGIL: olcek 1.3'te
    //	ad satiri sigmaz ve sari-siyah tasma seridi cikardi (turu 180w).
    final olcek = MediaQuery.textScalerOf(context);
    const kSatirKutu = 1.45; // Google Sans Flex, olculdu (turu 173)
    // ⚠️⚠️ EMULATORDE OLCULDU: ilk yazimda **BOTTOM OVERFLOWED** cikti.
    //	Yatay `ListView` cocuguna DIKEYDE TIGHT kisit verir, yani `Column`
    //	tam sigmak ZORUNDA; dolgu + ikon + bosluk + yazi TEK TEK toplanir
    //	ve **4 dp pay** eklenir (`TextPainter` satir yuksekligini YUKARI
    //	yuvarlar — turu 137).
    const kDikeyDolgu = 10.0;
    final boy =
        kDikeyDolgu * 2 +
        52 +
        6 +
        (olcek.scale(11) * kSatirKutu).ceilToDouble() +
        4;
    return Container(
      height: boy,
      padding: const EdgeInsets.symmetric(vertical: kDikeyDolgu),
      // ⚠️ `foregroundDecoration`: `decoration`daki bir `Border` cocugun
      //	kisitindan DUSER ve tasmaya katkida bulunur (turu 150/180t).
      foregroundDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _ogeler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (c, i) {
          final o = _ogeler[i];
          return SizedBox(
            width: 60,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSec(o.anahtar),
              // ⚠️⚠️ `FittedBox(scaleDown)` ZORUNLU: yatay `ListView` cocuguna
              //	DIKEYDE **TIGHT** kisit verir; hesap bir piksel bile sasarsa
              //	(font metrigi, yazi olcegi, cihaz yuvarlamasi) sari-siyah
              //	tasma seridi cikar. Bu sarmalla tasma YAPISAL OLARAK
              //	imkansiz — dar kutuda KIRPILMAZ, kuculur (turu 143 dersi).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: o.renk.withValues(alpha: 0.18),
                      ),
                      child: Icon(o.ikon, size: 23, color: o.renk),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      o.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

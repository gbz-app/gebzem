import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:vibration/vibration.dart';

import '../../router.dart' show rootMessengerKey;
import 'medya_kapisi.dart';
import 'ses_notu_kontrol.dart';

/// ⚠️⚠️ SES NOTU KAYDEDİCİ — **tek dokunuş → kaydet, şeritten gönder/sil**.
///
/// ⚠️ TURU 81'de etkileşim DEĞİŞTİ: eskiden "basılı tut → bırak → gönder"
///    (WhatsApp deseni) idi. Kaldırılma gerekçesi `_mikrofonDugmesi`
///    şerhinde — özetle: kayıt başlayınca düğme ağaçtan silindiği için
///    `onLongPressEnd` YAPISAL OLARAK çalışamıyordu.
///
/// ⚠️⚠️ **SERT KAPI:** aktif arama / sesli oda / canlı yayın varken (ÇALMA fazı
/// dahil) kayıt YASAK. Gerekçe TAHMİN DEĞİL, ÖLÇÜM:
///   · turu 64 — ses oturumunu geri alma `!pri` (`0x21707269` =
///     `AVAudioSessionErrorCodeInsufficientPriority`) ile REDDEDİLDİ,
///   · turu 65 — CallKit `didActivate`i HİÇ çağırmadı,
///   · turu 62-C — Android'de ses rotası bozulup hoparlöre atladı.
/// ⚠️ KUYRUĞA ALMA KABUL EDİLMEDİ: görüşme dakikalarca sürer; "4 dakika sonra
///     kendiliğinden başlayan kayıt" kabul edilemez. WhatsApp da engelliyor.
///
/// ⚠️ `allowHapticsAndSystemSoundsDuringRecording: true` **ZORUNLU**: varsayılan
///     `false`, kayıt sırasında GELEN ARAMA ZİLİNİ BASTIRIR ve kullanıcı aramayı
///     kaçırır.
/// ⚠️ Kodek `aacLc` — opus Android 29+ ister, bizim minSdk 24.
class SesNotuKaydedici extends ConsumerStatefulWidget {
  const SesNotuKaydedici({
    super.key,
    required this.onKayit,
    this.onDurum,
  });

  /// (dosya, süreMs, dalgaFormu) — kaydedici GÖNDERMEZ, çağırana verir.
  final void Function(File dosya, int sureMs, String dalga) onKayit;

  /// ⚠️⚠️ TURU 81 — KAYIT DURUMU ÇAĞIRANA BİLDİRİLİR.
  ///
  /// Kayıt başlayınca widget **tüm giriş çubuğunu kaplayan** bir şeride
  /// dönüşür (Instagram deseni: çöp · canlı dalga · süre · gönder). Sohbet
  /// ekranı bunu bilmek ZORUNDA, çünkü o sırada metin alanını ve ataç
  /// düğmesini GİZLEMESİ gerekiyor — aksi halde şerit dar bir Row hücresine
  /// sıkışırdı.
  final void Function(bool kayitta)? onDurum;

  @override
  ConsumerState<SesNotuKaydedici> createState() => _SesNotuKaydediciState();
}

class _SesNotuKaydediciState extends ConsumerState<SesNotuKaydedici> {
  final _kaydedici = AudioRecorder();
  StreamSubscription<Amplitude>? _genlikSub;
  Timer? _sayac;

  /// TURU 74b: `SesNotuKontrol` sahiplik jetonu (başkasının kaydını ezmemek için).
  final Object _sahip = Object();

  bool _kayitta = false;
  int _ms = 0;

  /// Dalga formu kovaları (0-99). Sunucuda `media_assets.waveform` alanına gider.
  final List<int> _dalga = [];

  @override
  void dispose() {
    // ⚠️ Ekran kapanırsa kayıt SÜRMESİN (mikrofon açık kalır, iPhone'da gösterge yanar).
    _temizle(silinsin: true);
    _kaydedici.dispose();
    super.dispose();
  }

  /// ⚠️⚠️ YENİDEN GİRİŞ KİLİDİ (denetim bulgusu). `_basla()` ÜÇ `await`
  ///    içeriyor (izin isteği, kapı, `recorder.start()`) ve `_kayitta`
  ///    bayrağı ancak EN SONDA yazılıyordu. O pencerede ikinci bir dokunuş
  ///    İKİNCİ bir kayıt başlatır: iki `Timer`, iki genlik dinleyicisi ve
  ///    iki dosya oluşur; ilkinin aboneliği kaybolur, mikrofon kaydı SIZAR
  ///    ve iPhone'da gösterge kayıt bittikten sonra da YANAR KALIR.
  /// ⚠️ Bayrak `_kayitta`dan AYRI: `_kayitta` ARAYÜZ durumudur (şerit çizilir
  ///    mi), bu ise AKIŞ kilidi. İkisini birleştirmek şeridi izin diyaloğu
  ///    açıkken çizerdi.
  bool _basliyor = false;

  Future<void> _basla() async {
    if (_basliyor || _kayitta) return;
    _basliyor = true;
    try {
      await _baslaGovde();
    } finally {
      _basliyor = false;
    }
  }

  Future<void> _baslaGovde() async {
    // ⚠️ SERT KAPI — sınıf şerhine bakın. Aksiyon yolunda, yan etkili kontrol.
    if (!MedyaKapisi.izinVer(ref)) return;

    final izin = await Permission.microphone.request();
    if (izin != PermissionStatus.granted) {
      rootMessengerKey.currentState?.showSnackBar(const SnackBar(
          content: Text('Sesli mesaj için mikrofon izni gerekli')));
      return;
    }
    // ⚠️ İzin diyaloğu açıkken arama gelmiş olabilir — İKİNCİ KAPI.
    if (!MedyaKapisi.donanimSerbest(ref)) return;

    final dizin = await getTemporaryDirectory();
    final yol = '${dizin.path}/gz_ses_${DateTime.now().microsecondsSinceEpoch}.m4a';
    try {
      await _kaydedici.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // ⚠️ opus DEĞİL (Android 29+ ister, minSdk 24)
          bitRate: 32000,
          sampleRate: 44100,
          numChannels: 1,
          iosConfig: IosRecordConfig(
            // ⚠️ ZORUNLU: false olsaydı kayıt sırasında GELEN ARAMA ZİLİ bastırılır.
            allowHapticsAndSystemSoundsDuringRecording: true,
          ),
        ),
        path: yol,
      );
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Kayıt başlatılamadı: $e')));
      return;
    }

    // ⚠️⚠️ TURU 74b (DENETIM BULGUSU) — ÜÇÜNCÜ KAPI.
    //     `start()` iOS'ta AVAudioSession'ı `.playAndRecord` yapıp aktive ettiği
    //     için YÜZLERCE MS sürebilir. O pencerede arama gelirse `sustur()`
    //     `_susturucu == null` görüp anında döner → **kayıt ve arama BİRLİKTE
    //     mikrofonu ister.** Bu yüzden `start()` DÖNDÜKTEN SONRA tekrar sorulur.
    if (!MedyaKapisi.donanimSerbest(ref)) {
      try {
        await _kaydedici.stop();
      } catch (_) {}
      return;
    }
    // ⚠️⚠️ ARAMA KAZANIR: arama/oda/yayın kurulurken bu geri çağrı çalışır ve
    //     kayıt DURUR. ⚠️ Kayıt SİLİNMEZ — taslak kalır, kullanıcı sonra gönderir.
    //     ⚠️ `SesSahipligi`e YAZMIYORUZ (bkz. ses_notu_kontrol.dart şerhi).
    SesNotuKontrol.kaydol(_sahip, () async {
      if (!_kayitta) return;
      await _durdur(gonder: false, taslak: true);
    });

    unawaited(Vibration.hasVibrator().then((v) {
      if (v == true) Vibration.vibrate(duration: 30);
    }));

    _dalga.clear();
    _ms = 0;
    setState(() => _kayitta = true);
    widget.onDurum?.call(true);

    _sayac = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _ms += 100);
      // ⚠️ 10 dakika tavanı: sınırsız kayıt hem kotayı hem belleği yer.
      if (_ms >= 600000) _durdur(gonder: true);
    });
    _genlikSub = _kaydedici
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((a) {
      // dBFS (-160..0) -> 0..99
      final n = ((a.current + 45) / 45 * 99).clamp(0, 99).toInt();
      // ⚠️⚠️ TAVANA VURUNCA **KAYAN PENCERE** (denetim bulgusu). Eskiden
      //    `if (_dalga.length < 600) add(n)` idi: 600 kova = 60 saniye, yani
      //    60. saniyeden sonra liste BUYUMEYI DURDURUYOR, `shouldRepaint`
      //    hicbir degisiklik gormuyor ve **canli dalga DONUYORDU** — sayac
      //    akmaya devam ettigi icin kullanici "kayit bozuldu" sanardi
      //    (kayit 10 dakikaya kadar surebiliyor).
      // ⚠️ En eski kova atilir: dalga zaten SON kovalari gosteriyor, yani
      //    atilan veri ekranda ZATEN gorunmuyordu. Sunucuya giden 60 kovalik
      //    ozet de son pencereden turer — kayit uzadikca ozet SON kismi
      //    temsil eder ki bu, donmus bir dalgadan durusttur.
      _dalga.add(n);
      if (_dalga.length > 600) _dalga.removeAt(0);
      // ⚠️⚠️ TURU 81 — CANLI DALGA. Genlik turu 74'ten beri OKUNUYORDU ama
      //    YALNIZCA sunucuya gönderilmek üzere biriktiriliyordu; kayıt
      //    sırasında HİÇBİR ŞEY çizilmiyordu (kullanıcının tek geri bildirimi
      //    mikrofon ikonunun yeşile dönmesiydi ve o da fark edilmiyordu).
      //    Kullanıcı bu yüzden "ses paylaşma YOK" dedi — özellik vardı ama
      //    GÖRÜNMÜYORDU.
      // ⚠️ `setState` BURADA: sayaç zaten 100ms'de bir çiziyor, yani ek maliyet
      //    yok; ayrı bir tik eklemek gereksiz kare üretirdi.
      if (mounted) setState(() {});
    });
  }

  Future<void> _durdur({required bool gonder, bool taslak = false}) async {
    if (!_kayitta) return;
    _sayac?.cancel();
    await _genlikSub?.cancel();
    _genlikSub = null;
    final sure = _ms;
    setState(() => _kayitta = false);
    widget.onDurum?.call(false);
    SesNotuKontrol.birak(_sahip);

    String? yol;
    try {
      yol = await _kaydedici.stop();
    } catch (_) {}
    final dosya = yol == null ? null : File(yol);

    if (!gonder || dosya == null || !dosya.existsSync()) {
      if (dosya != null && !taslak) {
        try {
          await dosya.delete();
        } catch (_) {}
      }
      if (taslak && dosya != null && sure >= 1000 && mounted) {
        // ⚠️ Arama yüzünden kesildi: kayıt SİLİNMEZ, kullanıcıya sunulur.
        rootMessengerKey.currentState?.showSnackBar(const SnackBar(
          duration: Duration(seconds: 4),
          content: Text('Görüşme başladı, kayıt durduruldu. Kaydınız taslakta.'),
        ));
        widget.onKayit(dosya, sure, _dalgaMetni());
      }
      return;
    }
    // ⚠️ 1 saniyenin altı KAZA: kullanıcı düğmeye dokunup çekmiştir.
    if (sure < 1000) {
      try {
        await dosya.delete();
      } catch (_) {}
      rootMessengerKey.currentState?.showSnackBar(const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Sesli mesaj için basılı tutun')));
      return;
    }
    widget.onKayit(dosya, sure, _dalgaMetni());
  }

  /// 60 kovaya indirge — sunucuda tek metin alanı olarak saklanır.
  String _dalgaMetni() {
    if (_dalga.isEmpty) return '';
    const hedef = 60;
    final adim = math.max(1, _dalga.length ~/ hedef);
    final out = <int>[];
    for (var i = 0; i < _dalga.length && out.length < hedef; i += adim) {
      final son = math.min(i + adim, _dalga.length);
      var t = 0;
      for (var j = i; j < son; j++) {
        t += _dalga[j];
      }
      out.add(t ~/ (son - i));
    }
    return out.join(',');
  }

  void _temizle({bool silinsin = false}) {
    _sayac?.cancel();
    _genlikSub?.cancel();
    SesNotuKontrol.kapat(_sahip);
    if (_kayitta) {
      _kaydedici.stop().then((y) {
        if (silinsin && y != null) {
          try {
            File(y).deleteSync();
          } catch (_) {}
        }
      }).catchError((_) => null);
    }
  }

  String get _sureMetni {
    final sn = _ms ~/ 1000;
    return '${(sn ~/ 60).toString().padLeft(2, '0')}:'
        '${(sn % 60).toString().padLeft(2, '0')}';
  }

  /// ⚠️⚠️ TURU 74b (DENETİM BULGUSU — ÖZELLİK ÖLÜ DOĞMUŞTU):
  /// İlk sürümde `build()` **devre dışı bir `IconButton`** döndürüyordu
  /// (`onPressed: null`) ve basılı tutmayı sağlayan `kayitAlani()` ile kayıt
  /// şeridini çizen `kayitSeridi()` **hiçbir yerden çağrılmıyordu**. Yani
  /// mikrofona basılı tutmak HİÇBİR ŞEY yapmıyordu; dolayısıyla ses notu
  /// balonu da hiç oluşmuyordu.
  /// `flutter analyze` bunu YAKALAMAZ: ikisi de public sınıfın public metodu.
  /// ⚠️ YAPMA: `build()`i tekrar gesture'sız bir düğmeye çevirme.
  /// ⚠️⚠️⚠️ TURU 81 — İKİ DURUMLU: mikrofon düğmesi / TAM GENİŞLİKTE kayıt şeridi.
  ///
  /// Kullanıcı: *"ses kaydederken BİR DEFA TIKLAMA yeterli, kayıt esnasında
  /// GERÇEKÇİ SES DALGALARI olmalı"* (Instagram ekran görüntüsü).
  ///
  /// ⚠️ Turu 74'te özellik VARDI ama **KEŞFEDİLEMEZDİ**: mikrofonda yalnız
  ///    `onLongPressStart/End` vardı, `onTap` YOKTU — düz dokunuş hiçbir şey
  ///    yapmıyor, hiçbir geri bildirim vermiyordu. Üstelik `kayitSeridi()`
  ///    **hiçbir yerden çağrılmıyordu** (şerhi "turu 74b'de düzeltildi" dese de
  ///    yalnızca `kayitAlani()` bağlanmıştı), yani kayıt sırasında süre sayacı
  ///    bile görünmüyordu. Kullanıcı bu yüzden "ses paylaşma YOK" dedi.
  @override
  Widget build(BuildContext context) {
    if (_kayitta) return _kayitSeridi(context);
    return _mikrofonDugmesi();
  }

  /// ⚠️⚠️⚠️ YALNIZCA DOKUNUŞ — BASILI TUTMA **KALDIRILDI** (denetim bulgusu:
  /// SEVK ENGELİYDİ).
  ///
  /// ═══════════ NEDEN KALDIRILDI ═══════════
  ///
  /// Turu 81'de kayıt şeridi eklendiğinde `build()` şöyle oldu:
  ///     `if (_kayitta) return _kayitSeridi(...); return _mikrofonDugmesi();`
  /// Yani `_basla()` çağrılır çağrılmaz mikrofonun `GestureDetector`ı
  /// **AĞAÇTAN SİLİNİYOR**. Basılı tutan kullanıcı parmağını kaldırdığında
  /// `onLongPressEnd` **BİR DAHA ÇALIŞAMAZ** (dinleyici artık yok) — kayıt
  /// 10 dakikalık tavana kadar SÜRER ve kullanıcı ne gönderebilir ne iptal
  /// edebilir. Yani "bas-konuş-bırak" YAPISAL OLARAK BOZULDU.
  ///
  /// İlk yazımda şerh "WhatsApp deseni KORUNDU" diyordu — **KORUNMAMIŞTI**.
  /// Bu, projenin en sık tekrarlayan sınıfı ("yorumun anlattığı kontrol
  /// gövdede yok") ve bunu kendi eklememde yaptım.
  ///
  /// ⚠️ Çözüm jesti "onarmak" DEĞİL KALDIRMAK: kullanıcı zaten açıkça
  ///    *"bir defa tıklama yeterli"* dedi ve gönderdiği Instagram ekranında
  ///    da basılı tutma YOK. Tamamlanamayan bir jesti ağaçta bırakmak,
  ///    çalışmayan bir düğme bırakmakla aynı şeydir (turu 66b dersi).
  /// ⚠️ YAPMA: `onLongPress*`ı geri ekleme — şerit tasarımıyla YAPISAL OLARAK
  ///    bağdaşmıyor. Gerekirse önce şeridi mikrofonun ÜSTÜNDE ayrı bir katman
  ///    yap, düğmeyi ağaçta BIRAK.
  Widget _mikrofonDugmesi() => GestureDetector(
        onTap: _basla,
        child: Container(
          // ⚠️ 44dp dokunma alanı (Material 48 / Apple 44). Turu 78b'de
          //    17x17dp bir düğme yüzünden özellik fiilen ulaşılamazdı.
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: const Icon(LucideIcons.mic),
        ),
      );

  /// Kayıt şeridi — giriş çubuğunun YERİNE geçer (Instagram deseni).
  ///
  /// Düzen:  [çöp]  ~~~canlı dalga~~~  0:07  [gönder]
  ///
  /// ⚠️ Süre sayacı ve dalga AYNI şeritte: kullanıcı kaydın gerçekten
  ///    ilerlediğini iki bağımsız işaretten görür (donmuş bir dalga ile
  ///    duran bir sayaç aynı anda olamaz).
  Widget _kayitSeridi(BuildContext context) {
    final mor = Theme.of(context).colorScheme.primary;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: mor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kaydı sil',
            icon: const Icon(LucideIcons.trash2, color: Colors.white, size: 20),
            onPressed: () => _durdur(gonder: false),
          ),
          Expanded(
            child: CustomPaint(
              painter: _DalgaCizer(_dalga),
              size: Size.infinite,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _sureMetni,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              // ⚠️ Sabit genişlikli rakam: sayaç ilerlerken dalga SAĞA SOLA
              //    OYNAMASIN (0:09 -> 0:10 geçişinde bir piksel kayardı).
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          // ⚠️ GÖNDER: beyaz daire içinde mor ok (ekran görüntüsündeki gibi).
          GestureDetector(
            onTap: () => _durdur(gonder: true),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.send, size: 17, color: mor),
            ),
          ),
        ],
      ),
    );
  }
}

/// ⚠️⚠️ TURU 81 — CANLI SES DALGASI. Projedeki **İLK** `CustomPainter`.
///
/// Genlik `record` paketinden 100ms'de bir dBFS olarak gelir ve 0..99'a
/// eşlenir (`_basla` içinde). Bu çizer yalnızca SON kovaları gösterir: şerit
/// dar olduğu için tüm kayıt sığmaz ve sığdırmaya çalışmak çubukları
/// görünmez inceliğe düşürürdü.
///
/// ⚠️ SAĞDAN SOLA akar (yeni ses SAĞDA belirir) — ses kaydı arayüzlerinin
///    evrensel yönü budur; ters yön "geri sarıyor" izlenimi verir.
/// ⚠️ `shouldRepaint` KURULUM ANINDAKI uzunluğa bakar (bkz. yapıcı şerhi):
///    liste YERİNDE büyüdüğü için hem referans eşitliği hem de anlık uzunluk
///    karşılaştırması ANLAMSIZDIR.
class _DalgaCizer extends CustomPainter {
  /// ⚠️⚠️⚠️ UZUNLUK **KURULUM ANINDA** YAKALANIR (denetim bulgusu: dalga HİÇ
  /// çizilmiyordu).
  ///
  /// İlk yazımda `shouldRepaint` şöyleydi:
  ///     `eski.kovalar.length != kovalar.length`
  /// Ama `_dalga` **AYNI LİSTE NESNESİDİR** ve her karede aynı referans
  /// geçilir; yani `eski.kovalar` ile `kovalar` **AYNI NESNE**dir ve
  /// uzunlukları TANIM GEREĞİ eşittir → `shouldRepaint` **HER ZAMAN false**
  /// döner → canlı dalga **HİÇ YENİDEN ÇİZİLMEZ**. Kullanıcı düz bir çizgi
  /// görürdü ve turun görünür işi sessizce ölürdü.
  /// ⚠️ YAPMA: uzunluğu `kovalar.length` üzerinden karşılaştırmaya dönme;
  ///    liste yerinde büyüdüğü için o karşılaştırma anlamsızdır.
  _DalgaCizer(this.kovalar) : _uzunluk = kovalar.length;

  final List<int> kovalar;
  final int _uzunluk;

  @override
  void paint(Canvas canvas, Size size) {
    const cubuk = 3.0;
    const ara = 2.0;
    final adet = math.max(1, (size.width / (cubuk + ara)).floor());
    final bas = math.max(0, kovalar.length - adet);
    final boya = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cubuk;

    for (var i = bas; i < kovalar.length; i++) {
      final x = (i - bas) * (cubuk + ara) + cubuk / 2;
      if (x > size.width) break;
      // ⚠️ En az 3px: sessiz anlar tamamen kaybolmasın (ses notu balonundaki
      //    statik dalgayla AYNI kural — iki çizim tutarlı görünmeli).
      final y = 3 + (kovalar[i] / 99) * (size.height - 6);
      canvas.drawLine(
        Offset(x, (size.height - y) / 2),
        Offset(x, (size.height + y) / 2),
        boya,
      );
    }
  }

  @override
  bool shouldRepaint(_DalgaCizer eski) => eski._uzunluk != _uzunluk;
}

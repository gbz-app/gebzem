import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:video_player/video_player.dart';

import '../medya/medya_kapisi.dart';
import '../medya/medya_gorsel.dart';
import '../medya/medya_servisi.dart';
import '../medya/ses_notu_kontrol.dart';

/// ⚠️⚠️ TURU 75 — GONDERI/REELS VIDEO OYNATICI.
///
/// ⚠️⚠️⚠️ iOS SES OTURUMU — BU DOSYANIN VAROLUS SEBEBI:
///   `video_player` iOS'ta varsayilan olarak `AVAudioSession` kategorisini
///   `.playback` yapar. O kategori **DIGER SESI KESER** — yani bir gonderi
///   videosu, SUREN LiveKit aramasinin/odanin sesini OLDURUR. Bu projede ayni
///   sinif hata (process-global ses oturumu) turu 64/65/73'te defalarca yasandi.
///
///   UC KATMANLI SAVUNMA:
///   (1) `VideoPlayerOptions(mixWithOthers: true)` — oturumu ELE GECIRMEZ.
///   (2) `MedyaKapisi.donanimSerbest` false ise ses ZORLA kapatilir (mixWithOthers
///       "karistir" demek; kullanici arama sesiyle reel sesini AYNI ANDA duymasin).
///   (3) `SesNotuKontrol` defterine kaydolur — arama/oda/yayin BASLARKEN
///       `sustur()` cagriliyor (5 giris noktasinda `await` ile) ve oynatma DURUR.
///
/// ⚠️ YAPMA: `mixWithOthers: true`yi kaldirma.
/// ⚠️ YAPMA: `SesNotuKontrol.kaydol/birak` cagrilarini kaldirma.
/// ⚠️ YAPMA: bu widget'i `SesSahipligi`ne kaydetme — o defter
///    `setAudioEnabled(false)` kararini suruyor; video oynatici WebRTC ses birimi
///    DEGILDIR ve oraya yazilirsa `aramaCanli` YALAN soyler (bkz. ses_notu_kontrol).
class MedyaVideo extends ConsumerStatefulWidget {
  const MedyaVideo({
    super.key,
    this.mediaId = '',
    this.yerelDosya,
    this.kapakMediaId,
    this.otoOynat = false,
    this.dongu = true,
    this.sesli = false,
    this.dolgu = BoxFit.contain,
    this.kontrolGoster = true,
  });

  /// Sunucudaki medya. ⚠️ `yerelDosya` verildiyse BOS olabilir.
  final String mediaId;

  /// ⚠️ TURU 77 — HENUZ YUKLENMEMIS yerel dosya (hikaye editoru onizlemesi).
  ///    Verilirse `mediaId` YOK SAYILIR ve ag istegi ATILMAZ.
  final File? yerelDosya;

  /// Kucuk resim — video hazir olana kadar gosterilir (siyah kare yerine).
  final String? kapakMediaId;

  /// Gorunur olunca kendiliginden oynasin mi (akista SESSIZ, reels'te SESLI).
  final bool otoOynat;
  final bool dongu;

  /// Baslangicta sesli mi. ⚠️ Akista DAIMA `false` — kaydirirken aniden ses
  ///    patlamasi (Instagram/Facebook davranisi da sessiz otomatik oynatma).
  final bool sesli;
  final BoxFit dolgu;
  final bool kontrolGoster;

  @override
  ConsumerState<MedyaVideo> createState() => _MedyaVideoState();
}

class _MedyaVideoState extends ConsumerState<MedyaVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _c;
  bool _hazir = false;
  bool _hata = false;
  bool _sesli = false;
  bool _kullaniciDurdurdu = false;

  /// Arama/oda/yayin surdugu icin oynatici HIC kurulmadi.
  /// ⚠️ `_hata` DEGIL: hata degil, gecici kilit — kapi acilinca kendini onarir.
  bool _kilitli = false;

  /// Oynatmayi BIZ degil, `SesNotuKontrol.sustur()` (arama basladi) durdurdu.
  /// ⚠️ Bu ayrim ZORUNLU: reels'te `kontrolGoster: false` oldugu icin kullanicinin
  ///    elle devam ettirecek DUGMESI YOK — gorusme bitince otomatik devam etmezse
  ///    ekran DONMUS KAREDE kalir.
  bool _aramaDurdurdu = false;

  /// Kilit/durdurma durumunu yoklayan zamanlayici.
  /// ⚠️ `MedyaKapisi.donanimSerbest` bir Notifier DEGIL (birden fazla kaynaktan
  ///    turetiliyor: GSM bayragi, SesSahipligi defteri, call provider). Dinlenecek
  ///    tek bir akis olmadigi icin SEYREK yoklama (1sn) en durust cozum.
  /// ⚠️ YAPMA: yoklamayi hizlandirma; 1sn kullanici icin fark etmez, pil icin eder.
  Timer? _kapiYoklama;

  /// ⚠️ Kurulum ASENKRON (imzali adres + `initialize()`); bu arada widget dispose
  ///    olabilir ya da `mediaId` degisebilir. Her await sonrasi bu jeton kontrol
  ///    edilir — bu projede "bayat async" hatalarinin TEK caresi (turu 19 dersi).
  int _nesil = 0;

  /// Oynatici HENUZ kurulmadi — kullanicinin dokunmasi bekleniyor.
  ///
  /// ⚠️⚠️ TURU 76 — AKISTA VIDEO ARTIK KENDILIGINDEN INDIRILMIYOR.
  ///    Eskiden `initState` KOSULSUZ `_kur()` cagiriyordu ve `initialize()`
  ///    videonun basligini + ilk tamponu INDIRIR. Akista 20 kart varsa 20 video
  ///    bosuna indirilmeye baslardi. Video tavani 16 MB iken bu farkedilmiyordu;
  ///    **100 MB tavanda kullanicinin mobil verisini yakar** (kullanici emri
  ///    geregi tavan 100 MB'a cikarildi).
  /// ⚠️ Kart TAM EKRAN DEGIL — kullanici kaydirip gecebilir. Bu yuzden
  ///    `otoOynat == false` iken oynatici DOKUNANA KADAR kurulmaz. Reels
  ///    (`otoOynat: true`) tam ekrandir ve hemen kurulur — orada dogru olan bu.
  /// ⚠️ YAPMA: `initState`e kosulsuz `_kur()` geri koyma.
  bool _tembel = false;

  @override
  void initState() {
    super.initState();
    _sesli = widget.sesli;
    WidgetsBinding.instance.addObserver(this);
    if (widget.otoOynat) {
      _kur();
    } else {
      _tembel = true;
    }
    _kapiYoklama = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _kapiyiYokla(),
    );
  }

  /// Gorusme bitti mi? Bittiyse kilidi kaldir / duraklatilmis oynatmayi surdur.
  void _kapiyiYokla() {
    if (!mounted) return;
    // ⚠️ Tembel bekleyen oynatici KURULMAZ: kullanici dokunmadi.
    if (_tembel) return;
    final serbest = MedyaKapisi.donanimSerbest(ref);
    if (!serbest) return;
    if (_kilitli) {
      _kur(); // kapi acildi, oynaticiyi simdi kur
      return;
    }
    // ⚠️ Yalniz ARAMA durdurduysa devam et — kullanici elle duraklattiysa
    //    ona saygi duyulur (turu 72 "devam otomatik degil, dugmeyle" karari).
    if (_aramaDurdurdu && widget.otoOynat && !_kullaniciDurdurdu) {
      _aramaDurdurdu = false;
      _sesli = widget.sesli;
      _oynat();
    }
  }

  @override
  void didUpdateWidget(covariant MedyaVideo eski) {
    super.didUpdateWidget(eski);
    if (eski.mediaId != widget.mediaId) {
      _birak();
      _kur();
    } else if (eski.otoOynat != widget.otoOynat) {
      // Gorunurluk degisti: gorunur olan oynar, olmayan DURUR.
      if (widget.otoOynat) {
        _kullaniciDurdurdu = false;
        // ⚠️⚠️ TURU 76b (SEVK ENGELI) — TEMBEL OYNATICI KURULMALI.
        //    Akista kart EKRAN DISINDA kurulur; o an `otoOynat: false` oldugu
        //    icin `initState` `_tembel = true` yapar ve **oynatici HIC
        //    YARATILMAZ**. Kart kaydirilip gorunur olunca buraya duseriz ve
        //    eski kod dogrudan `_oynat()` cagiriyordu — `_c` NULL oldugu icin
        //    HICBIR SEY OLMUYORDU: otomatik oynatma sahada HIC CALISMAZDI.
        //    (PageView'de sorun cikmiyordu cunku komsu sayfa `otoOynat: true`
        //    ile dogrudan kuruluyordu; gorunurluk tabanli akista durum TERS.)
        // ⚠️ YAPMA: bu dali kaldirip yalniz `_oynat()`a donme.
        if (_tembel) {
          _tembel = false;
          _kur();
        } else {
          _oynat();
        }
      } else {
        _c?.pause();
        _c?.seekTo(Duration.zero);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    // ⚠️ Arka planda video oynatmak YOK: pil + veri harcar, ustelik iOS'ta
    //    ses oturumunu arka planda tutmaya calisir. `inactive` DE dahil degil —
    //    o durumdan (bildirim merkezi/app switcher) donuste devam etmeli.
    if (durum == AppLifecycleState.paused ||
        durum == AppLifecycleState.detached) {
      _c?.pause();
    } else if (durum == AppLifecycleState.resumed &&
        widget.otoOynat &&
        !_kullaniciDurdurdu) {
      _oynat();
    }
  }

  Future<void> _kur() async {
    final nesil = ++_nesil;
    // ⚠️⚠️⚠️ TURU 75b (DENETIM BULGUSU) — KURULUM KAPISI.
    //    Eskiden kapi YALNIZ SES SEVIYESINE uygulaniyordu; oynatici KOSULSUZ
    //    kuruluyordu. Ama `video_player` iOS'ta `initialize()` sirasinda
    //    `setMixWithOthers(...)` gonderir ve bu, RTCAudioSession kilidinin
    //    DISINDAN AVAudioSession'i yeniden yapilandirir — yani SUREN LiveKit
    //    aramasinin ses oturumuna dokunur. `mixWithOthers: true` "oturumu ele
    //    gecirme" demek, "oturuga hic dokunma" DEMEK DEGIL.
    //    Bu projede proses-geneli ses oturumu turu 64/65/73'te defalarca yakti.
    // ⚠️ YAPMA: bu kapiyi kaldirma. Gorusme surerken video KURULMAZ; kapak
    //    gorseli + acik bir mesaj gosterilir, gorusme bitince `_yenidenDene`
    //    ile kurulur.
    if (!MedyaKapisi.donanimSerbest(ref)) {
      if (mounted) {
        setState(() {
          _hazir = false;
          _hata = false;
          _kilitli = true;
        });
      }
      return;
    }
    setState(() {
      _hazir = false;
      _hata = false;
      _kilitli = false;
    });
    try {
      // ⚠️⚠️ TURU 77 — YEREL DOSYA DESTEGI (hikaye editoru onizlemesi).
      //    Editorde secilen video HENUZ YUKLENMEDI; `mediaId` yok.
      //    AYRI BIR OYNATICI YAZILMADI cunku bu widget'taki ses kapilari
      //    (`MedyaKapisi.donanimSerbest`, `SesNotuKontrol`, `mixWithOthers`)
      //    bu projenin en kirilgan yerini koruyor — ikinci bir oynatici o
      //    korumalarin DISINDA kalir ve suren aramanin sesini bozar.
      // ⚠️ YAPMA: editorde `VideoPlayerController.file` ile ayri oynatici kurma.
      final VideoPlayerController c;
      if (widget.yerelDosya != null) {
        c = VideoPlayerController.file(
          widget.yerelDosya!,
          // ⚠️⚠️ ZORUNLU — bkz. dosya basligi.
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        final bilgi = await ref
            .read(medyaServisiProvider)
            .adres(widget.mediaId);
        if (!mounted || nesil != _nesil) return;
        final url = (bilgi['url'] ?? '').toString();
        if (url.isEmpty) throw Exception('adres bos');
        c = VideoPlayerController.networkUrl(
          Uri.parse(url),
          // ⚠️⚠️ ZORUNLU — bkz. dosya basligi. Kaldirilirsa suren aramanin sesi olur.
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }
      await c.initialize();
      if (!mounted || nesil != _nesil) {
        unawaited(c.dispose());
        return;
      }
      await c.setLooping(widget.dongu);
      _c = c;
      setState(() => _hazir = true);
      if (widget.otoOynat) _oynat();
    } catch (e) {
      if (!mounted || nesil != _nesil) return;
      setState(() => _hata = true);
      unawaited(Sentry.captureMessage('gonderi video acilamadi: $e'));
    }
  }

  /// ⚠️ SES KARARI TEK YERDE: arama/oda/yayin/GSM canliysa ses KAPALI.
  ///    Her oynatmadan once YENIDEN degerlendirilir (kullanici video acikken
  ///    arama kabul edebilir).
  bool get _sesVerilebilir =>
      _sesli && MedyaKapisi.donanimSerbest(ref) && !MedyaKapisi.pickerAcik;

  Future<void> _oynat() async {
    final c = _c;
    final nesil = _nesil;
    if (c == null || !mounted) return;

    // ⚠️⚠️ TURU 75b (DENETIM BULGUSU) — SIRA DEGISTI: ONCE DEFTERE YAZ, SONRA SES.
    //    Eskiden `await c.setVolume(...)` ONCE kosuyordu ve deftere kaydolma o
    //    await'in ALTINDAYDI. Dart argumani await'ten ONCE degerlendirdigi icin
    //    ses seviyesi 1.0 olarak KESINLESIYOR, ama platform kanali gidis-donusu
    //    suresince oynatici DEFTERDE OLMUYORDU. O pencerede baslayan bir arama
    //    `SesNotuKontrol.sustur()` cagirdiginda bizi BULAMAZ -> video arama
    //    boyunca TAM SESLE calar ve bir daha susturulamaz.
    // ⚠️ YAPMA: `kaydol`u tekrar await'in altina tasima.
    //
    // ⚠️⚠️⚠️ TURU 77b — **YALNIZ SES URETECEKSE DEFTERE GIRILIR. SEVK ENGELIYDI.**
    //    `SesNotuKontrol` **TEK SLOTLUDUR**: `kaydol()` yeni sahip gelince
    //    oncekini SUSTURUR. Akistaki videolar SESSIZ oynadigi halde (turu 76b
    //    karari) kosulsuz kaydoluyordu. Sonuc "PING-PONG":
    //      · akista video gorunurken Reels'e gec -> Reels ~1sn oynar, akistaki
    //        1sn'lik `_kapiYoklama` timer'i sahipligi geri calar, Reels DONAR;
    //        Reels'te `kontrolGoster:false` oldugu icin kullanicinin duzeltme
    //        yolu da YOKTU.
    //      · ayni sekilde VIDEO HIKAYE ve **SESLI MESAJ** (turu 74'te test
    //        edilip onaylanmis ozellik) saniyede bir susup basa donuyordu.
    //    Sessiz bir oynatici hicbir ses donanimi tuketmez; deftere girmesi
    //    ANLAMSIZDI. Girmezse de zarar yok: ses acildigi anda `_sesiCevir`
    //    yeniden kaydolur.
    //    ⚠️ YAPMA: bu kapiyi kaldirip kosulsuz `kaydol`a donme.
    if (_sesVerilebilir) {
      SesNotuKontrol.kaydol(this, () async {
        // ⚠️⚠️ SEBEP AYRIMI ZORUNLU: susturan ARAMA MI, BASKA BIR OYNATICI MI?
        //    Ikisine de `_aramaDurdurdu = true` yazilirsa `_kapiyiYokla`
        //    (1sn'lik timer) "arama bitti" sanip kendini geri baslatir ve
        //    sahipligi geri calar — ping-pongun ikinci yarisi buydu.
        //    Donanim SERBESTSE bizi susturan bir arama degil, baska bir
        //    oynaticidir; o durumda KENDILIGINDEN DEVAM ETMEYIZ.
        _aramaDurdurdu = !MedyaKapisi.donanimSerbest(ref);
        await _c?.pause();
        if (mounted) setState(() => _sesli = false);
      });
    } else {
      // Sessiz oynatici defterden CIKAR (bayat kayit birakmaz).
      SesNotuKontrol.birak(this);
    }

    await c.play();
    // ⚠️ Await SONRASI yeniden degerlendir: bu sirada arama baslamis olabilir.
    if (!mounted || nesil != _nesil) return;
    await c.setVolume(_sesVerilebilir ? 1.0 : 0.0);
    if (mounted) setState(() {});
  }

  Future<void> _sesiCevir() async {
    if (!_sesli && !MedyaKapisi.donanimSerbest(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görüşme sürüyor — video sesi açılamaz')),
      );
      return;
    }
    setState(() => _sesli = !_sesli);
    // Defter kaydi _oynat()'ta yapilmisti; burada yalniz seviye degisiyor.
    await _c?.setVolume(_sesVerilebilir ? 1.0 : 0.0);
  }

  void _duraklatCevir() {
    // ⚠️ TEMBEL YUKLEME: ilk dokunus oynaticiyi KURAR ve oynatir. Akista video
    //    bu dokunusa kadar TEK BAYT indirmez (bkz. `_tembel` serhi).
    if (_tembel) {
      setState(() => _tembel = false);
      _kullaniciDurdurdu = false;
      _kur().then((_) {
        if (mounted && _hazir) _oynat();
      });
      return;
    }
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      _kullaniciDurdurdu = true;
      c.pause();
    } else {
      _kullaniciDurdurdu = false;
      _oynat();
    }
    setState(() {});
  }

  void _birak() {
    _nesil++; // ucan kurulumu gecersiz kil
    SesNotuKontrol.birak(this);
    final c = _c;
    _c = null;
    _hazir = false;
    unawaited(c?.dispose());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kapiYoklama?.cancel();
    _birak();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return GestureDetector(
      onTap: widget.kontrolGoster ? _duraklatCevir : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Kapak: video hazir DEGILKEN gorunur. Siyah kare yerine gercek kare —
          // kaydirirken "bos delik" hissi olmasin.
          //
          // ⚠️ TURU 76 — KAPAK KAYNAGI: ayri bir `kapakMediaId` verilmediyse
          //    VIDEONUN KENDI media_id'sinin KUCUK RESMI denenir. Sunucu her
          //    medya kaydi icin `thumb_key` tutuyor ve `/media/{id}/url`
          //    yanitinda `thumb_url` donduruyor — yani kucuk resim YUKLENMISSE
          //    ek bir alan gerekmeden gorunur. Yuklenmemisse `MedyaGorsel`
          //    sessizce koyu bir kutuya duser (kirik ikon YOK).
          if (!_hazir)
            MedyaGorsel(
              mediaId: widget.kapakMediaId ?? widget.mediaId,
              kucuk: true,
              fit: widget.dolgu,
            ),
          if (_hazir && c != null)
            FittedBox(
              fit: widget.dolgu,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          // ⚠️ Tembel beklerken SPINNER GOSTERME — hicbir sey yuklenmiyor;
          //    donen cark kullaniciya "bekliyor" yalanini soylerdi.
          if (!_hazir && !_hata && !_kilitli && !_tembel)
            const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_kilitli)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.phone, color: Colors.white70, size: 26),
                    SizedBox(height: 8),
                    Text(
                      'Görüşme sürerken video oynatılamaz',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (_hata)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.circleAlert, color: Colors.white70),
                  SizedBox(height: 6),
                  Text(
                    'Video açılamadı',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          // ⚠️ Oynat dugmesi TEMBEL durumda da gorunur — kullanici videonun
          //    orada oldugunu ve dokununca oynayacagini gormeli.
          if (widget.kontrolGoster &&
              (_tembel || (_hazir && c != null && !c.value.isPlaying)))
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(LucideIcons.play, color: Colors.white, size: 28),
                ),
              ),
            ),
          if (_hazir && widget.kontrolGoster)
            Positioned(
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: _sesiCevir,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      _sesVerilebilir
                          ? LucideIcons.volume2
                          : LucideIcons.volumeOff,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          if (_hazir && c != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: widget.kontrolGoster,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF8B5CF6),
                  bufferedColor: Color(0x33FFFFFF),
                  backgroundColor: Color(0x22FFFFFF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

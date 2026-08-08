import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:vibration/vibration.dart';

import '../../router.dart' show rootMessengerKey;
import 'medya_kapisi.dart';
import 'ses_notu_kontrol.dart';

/// ⚠️⚠️ TURU 74 — SES NOTU KAYDEDİCİ (basılı tut → kaydet, bırak → gönder).
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
  const SesNotuKaydedici({super.key, required this.onKayit});

  /// (dosya, süreMs, dalgaFormu) — kaydedici GÖNDERMEZ, çağırana verir.
  final void Function(File dosya, int sureMs, String dalga) onKayit;

  @override
  ConsumerState<SesNotuKaydedici> createState() => _SesNotuKaydediciState();
}

class _SesNotuKaydediciState extends ConsumerState<SesNotuKaydedici> {
  final _kaydedici = AudioRecorder();
  StreamSubscription<Amplitude>? _genlikSub;
  Timer? _sayac;

  bool _kayitta = false;
  bool _iptalBolgesi = false;
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

  Future<void> _basla() async {
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

    // ⚠️⚠️ ARAMA KAZANIR: arama/oda/yayın kurulurken bu geri çağrı çalışır ve
    //     kayıt DURUR. ⚠️ Kayıt SİLİNMEZ — taslak kalır, kullanıcı sonra gönderir.
    //     ⚠️ `SesSahipligi`e YAZMIYORUZ (bkz. ses_notu_kontrol.dart şerhi).
    SesNotuKontrol.kaydol(() async {
      if (!_kayitta) return;
      await _durdur(gonder: false, taslak: true);
    });

    unawaited(Vibration.hasVibrator().then((v) {
      if (v == true) Vibration.vibrate(duration: 30);
    }));

    _dalga.clear();
    _ms = 0;
    setState(() => _kayitta = true);

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
      if (_dalga.length < 600) _dalga.add(n);
    });
  }

  Future<void> _durdur({required bool gonder, bool taslak = false}) async {
    if (!_kayitta) return;
    _sayac?.cancel();
    await _genlikSub?.cancel();
    _genlikSub = null;
    final sure = _ms;
    setState(() => _kayitta = false);
    SesNotuKontrol.birak();

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
    SesNotuKontrol.kapat();
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
  @override
  Widget build(BuildContext context) {
    // Kayıt şeridi giriş çubuğunun ÜSTÜNDE çizilir; onu çağıran taraf
    // `SesNotuKaydedici.seritOf(context)` ile değil, `onSerit` geri çağrısıyla alır.
    return kayitAlani();
  }

  /// Basılı tut alanı — `build()` bunu döndürür.
  Widget kayitAlani() => GestureDetector(
        onLongPressStart: (_) => _basla(),
        onLongPressEnd: (_) => _durdur(gonder: !_iptalBolgesi),
        onLongPressMoveUpdate: (d) {
          // ⚠️ Sola kaydırarak iptal (WhatsApp deseni). Eşik 80px.
          final iptal = d.localOffsetFromOrigin.dx < -80;
          if (iptal != _iptalBolgesi) {
            setState(() => _iptalBolgesi = iptal);
            HapticFeedback.selectionClick();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(LucideIcons.mic,
              color: _kayitta
                  ? (_iptalBolgesi ? Colors.red : const Color(0xFF25D366))
                  : null),
        ),
      );

  /// Kayıt sürerken giriş çubuğunun üstünde çizilen şerit.
  Widget? kayitSeridi() {
    if (!_kayitta) return null;
    return Container(
      color: _iptalBolgesi ? const Color(0x22D32F2F) : const Color(0x2225D366),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Icon(_iptalBolgesi ? LucideIcons.trash2 : LucideIcons.mic,
            size: 18, color: _iptalBolgesi ? Colors.red : const Color(0xFF25D366)),
        const SizedBox(width: 10),
        Text(_sureMetni,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _iptalBolgesi ? 'Bırakınca iptal edilecek' : 'İptal için sola kaydırın',
            style: const TextStyle(fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

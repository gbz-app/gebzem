import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:video_player/video_player.dart';

import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 75 — GONDERI OLUSTURUCU (foto / video / reels / yazi).
///
/// ⚠️⚠️ YUKLEME ILERLEMESI GORUNUR (kullanici emri): her dosya icin YUZDE cubugu,
///    toplam ilerleme ve IPTAL dugmesi. Bu projede "gonderdim sandim ama gitmemis"
///    tekrarlayan bir sikayet — yukleme SESSIZ olamaz.
///
/// ⚠️⚠️ EKRAN KAPANMASI YUKLEMEYI OLDURMEZ mi? OLDURUR — ve bu BILINCLI:
///    arka plan yuklemesi (WorkManager/BGTaskScheduler) ayri bir altyapi ister.
///    Bu yuzden yukleme SURERKEN `PopScope` ile cikis ONAY SORAR ve iptal edilirse
///    `CancelToken` ile ag istegi GERCEKTEN kesilir (yarim dosya R2'de kalirsa
///    sunucunun supurgesi 'beklemede' kaydi zaten temizler).
///
/// ⚠️ DONANIM KAPISI: kamera/galeri secici acilmadan `MedyaKapisi` sorulur —
///    arama/oda/yayin surerken kamera acmak iOS'ta paylasilan `videoCapturer`i
///    calar (turu 50 kok nedeni).
class GonderiOlustur extends ConsumerStatefulWidget {
  const GonderiOlustur({super.key, this.reels = false});

  /// `true` ise DIKEY kisa video (reels) modunda acilir.
  final bool reels;

  @override
  ConsumerState<GonderiOlustur> createState() => _GonderiOlusturState();
}

class _SecilenMedya {
  _SecilenMedya(this.dosya, this.video);
  final File dosya;
  final bool video;

  /// 0.0-1.0. `null` = henuz baslamadi.
  double? ilerleme;
  String? mediaId;
  String? hata;
}

class _GonderiOlusturState extends ConsumerState<GonderiOlustur> {
  final _metin = TextEditingController();
  final List<_SecilenMedya> _medya = [];
  bool _yorumKapali = false;
  bool _yukleniyor = false;
  CancelToken? _iptal;

  /// ⚠️ KENDI ROUTE'UM. `Navigator.pop()` en usteki route'u kapatir, "beni" degil —
  ///    ustumde bir onay diyalogu aciksa yanlis seyi kapatirdi (turu 59b dersi).
  ModalRoute<Object?>? _rota;

  /// Paylasim TAMAMLANDI mi. `PopScope`un onay diyalogu bundan sonra anlamsizdir.
  bool _bitti = false;

  /// ⚠️ Sunucudaki sinirlarla AYNI olmali — istemcide kesmezsek kullanici 16 MB
  ///    videoyu yukler ve commit'te 422 yer (bosa giden veri + kotu deneyim).
  static const int _enFazlaGorsel = 10;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠️ `ModalRoute.of` initState'te CAGRILAMAZ (bagimliliklar henuz kurulmadi).
    _rota ??= ModalRoute.of(context);
  }

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  bool get _reelsMi => widget.reels;

  String get _tur {
    if (_medya.isEmpty) return 'yazi';
    if (_medya.first.video) return _reelsMi ? 'reels' : 'video';
    return 'foto';
  }

  Future<void> _gorselSec() async {
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez');
      return;
    }
    List<XFile> secim = [];
    try {
      // ⚠️ Sistem secici uygulamayi ARKA PLANA alir; `pickerAcik` bunu "gercek
      //    arka plan gecisi" saymayan kapilar icin ZORUNLU (bkz. MedyaKapisi).
      MedyaKapisi.pickerAcik = true;
      secim = await ImagePicker().pickMultiImage(
        limit: _enFazlaGorsel - _medya.length,
      );
    } catch (e) {
      unawaited(Sentry.captureMessage('gonderi gorsel secici hatasi: $e'));
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (secim.isEmpty || !mounted) return;
    // Video secilmisse gorsel eklenemez (karma gonderi YOK — sunucu da reddeder).
    if (_medya.any((m) => m.video)) {
      _uyar('Video ile fotoğraf aynı gönderide olamaz');
      return;
    }
    setState(() {
      for (final x in secim) {
        if (_medya.length >= _enFazlaGorsel) break;
        _medya.add(_SecilenMedya(File(x.path), false));
      }
    });
  }

  /// Reels 90 sn, normal video 5 dk.
  Duration get _sureTavani =>
      _reelsMi ? const Duration(seconds: 90) : const Duration(minutes: 5);

  /// Video suresini olcer. Olculemezse `null` doner (kapiyi ACIK birakir).
  ///
  /// ⚠️ Gecici bir `VideoPlayerController` kurulur ve HEMEN dispose edilir.
  ///    `mixWithOthers: true` ZORUNLU — aksi halde bu kisa olcum bile iOS'ta
  ///    AVAudioSession kategorisini degistirip SUREN ARAMANIN sesini bozardi
  ///    (bkz. sosyal/medya_video.dart baslik serhi).
  static Future<Duration?> _videoSuresi(File f) async {
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.file(
        f,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await c.initialize().timeout(const Duration(seconds: 8));
      final d = c.value.duration;
      return d == Duration.zero ? null : d;
    } catch (_) {
      return null;
    } finally {
      unawaited(c?.dispose());
    }
  }

  Future<void> _videoSec() async {
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez');
      return;
    }
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        // ⚠️⚠️ TURU 76 — `maxDuration` GALERI SECIMLERINDE YOK SAYILIYOR
        //    (image_picker upstream davranisi: yalnizca KAMERA cekiminde
        //    uygulanir). Yani "reels 90 sn / video 5 dk" kurali SAHADA HIC
        //    CALISMIYORDU; kullanici 1 saatlik 4K video secebiliyordu.
        //    Parametre yine de veriliyor (kamera yolunda ise yarar) ama ASIL
        //    kapi asagida, sureyi KENDIMIZ olcerek uygulaniyor.
        maxDuration: _sureTavani,
      );
    } catch (e) {
      unawaited(Sentry.captureMessage('gonderi video secici hatasi: $e'));
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;

    final dosya = File(x.path);

    // ⚠️ BOYUT KAPISI (sunucu tavaniyla ayni). Sunucu da reddeder ama kullanici
    //    100 MB'lik dosyayi bosuna yuklemeye baslamasin.
    final bayt = await dosya.length();
    if (!mounted) return;
    final tavan = kTavanlar['video'] ?? (100 << 20);
    if (bayt > tavan) {
      _uyar('Video çok büyük (en fazla ${(tavan / (1 << 20)).round()} MB)');
      return;
    }

    // ⚠️⚠️ SURE KAPISI — SUREYI KENDIMIZ OLCUYORUZ.
    //    `video_player` zaten bagimli (reels/akis oynaticisi) — ek paket YOK.
    //    Olcum basarisiz olursa (bozuk dosya, kodek yok) video REDDEDILMEZ:
    //    sunucunun bayt tavani son savunma olarak kalir. Sessiz REDDETMEK,
    //    kullanicinin sebebini anlayamayacagi bir duvar olurdu.
    final sure = await _videoSuresi(dosya);
    if (!mounted) return;
    if (sure != null && sure > _sureTavani) {
      _uyar(_reelsMi
          ? 'Reels en fazla 90 saniye olabilir'
          : 'Video en fazla 5 dakika olabilir');
      return;
    }

    setState(() {
      _medya
        ..clear() // tek video
        ..add(_SecilenMedya(dosya, true));
    });
  }

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _paylas() async {
    final metin = _metin.text.trim();
    if (_medya.isEmpty && metin.isEmpty) {
      _uyar('Bir şeyler yaz ya da fotoğraf/video seç');
      return;
    }
    if (_reelsMi && _medya.isEmpty) {
      _uyar('Reels için video seçmelisin');
      return;
    }
    setState(() => _yukleniyor = true);
    _iptal = CancelToken();
    try {
      final servis = ref.read(medyaServisiProvider);
      final idler = <String>[];
      for (final m in _medya) {
        // ⚠️ Zaten yuklenmisse TEKRAR YUKLEME — "tekrar dene" akisinda ayni
        //    dosyayi ikinci kez yuklemek hem veri hem kota israfi.
        if (m.mediaId != null) {
          idler.add(m.mediaId!);
          continue;
        }
        setState(() {
          m.ilerleme = 0;
          m.hata = null;
        });
        File gonderilecek = m.dosya;
        if (!m.video) {
          // ⚠️ EXIF (KONUM) TEMIZLIGI burada olur ve ZORUNLUDUR — sunucu GPS
          //    bulursa 422 doner. Sikistirma basarisiz olursa HAM dosya
          //    GONDERILMEZ (konum sizabilir).
          final hazir = await MedyaServisi.gorseliHazirla(m.dosya);
          if (hazir == null) {
            throw Exception('Fotoğraf hazırlanamadı');
          }
          gonderilecek = hazir;
        }
        final id = await servis.yukle(
          dosya: gonderilecek,
          kind: m.video ? 'video' : 'image',
          mime: m.video ? 'video/mp4' : 'image/jpeg',
          fileName: m.dosya.uri.pathSegments.last,
          iptal: _iptal,
          ilerleme: (p) {
            if (mounted) setState(() => m.ilerleme = p);
          },
        );
        if (!mounted) return;
        setState(() {
          m.mediaId = id;
          m.ilerleme = 1;
        });
        idler.add(id);
      }

      final postId = await ref
          .read(sosyalServisiProvider)
          .gonderiOlustur(
            tur: _tur,
            metin: metin,
            mediaIds: idler,
            yorumKapali: _yorumKapali,
          );
      if (!mounted) return;
      // ⚠️⚠️ TURU 75b (DENETIM BULGUSU — SEVK ENGELIYDI):
      //    `Navigator.pop()` EN USTTEKI route'u kapatir, "beni" DEGIL.
      //    Bu ekranda `PopScope` yukleme surerken bir ONAY DIYALOGU aciyor;
      //    kullanici yukleme biterken geri tusuna basmissa o diyalog ACIK olur ve
      //    `pop(postId)` DIYALOGU kapatir — bu ekran EKRANDA KALIR, cagiran hicbir
      //    sonuc almaz, kullanici "paylasilmadi" sanip TEKRAR basar -> **CIFT GONDERI**.
      //    Ayni sinif hata turu 59b'de aramanin CANLI ekranini olduruyordu.
      // ⚠️ COZUM: kendi route'unu ADRESLE. `_bitti` bayragi PopScope diyalogunu da
      //    anlamsizlastirir (artik yukleme yok).
      _bitti = true;
      final nav = Navigator.of(context);
      nav.popUntil(
        (rota) => rota == _rota,
      ); // ustumdeki her seyi (diyalog) dusur
      nav.pop(postId); // simdi GERCEKTEN en ustteki benim
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      if (CancelToken.isCancel(e)) {
        _uyar('Yükleme iptal edildi');
      } else {
        _uyar(_hataMetni(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _uyar(_hataMetni(e));
    }
  }

  String _hataMetni(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['error'] is String) return d['error'] as String;
      if (e.response?.statusCode == 413) return 'Dosya çok büyük';
      if (e.response?.statusCode == 422) {
        return 'Dosya doğrulanamadı (bozuk ya da desteklenmiyor)';
      }
    }
    final s = e.toString();
    return s.contains('Exception: ')
        ? s.split('Exception: ').last
        : 'Paylaşılamadı';
  }

  double get _toplamIlerleme {
    if (_medya.isEmpty) return 0;
    final t = _medya.fold<double>(0, (a, m) => a + (m.ilerleme ?? 0));
    return t / _medya.length;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ⚠️ Yukleme surerken kazara geri tusu = yarim kalan gonderi.
      // ⚠️ `_bitti` sarti ZORUNLU: paylasim tamamlandiktan sonra kapi ACIK olmali,
      //    yoksa kendi `nav.pop(postId)` cagrimiz da bu kapiya takilirdi.
      canPop: !_yukleniyor || _bitti,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_yukleniyor || _bitti) return;
        // ⚠️ Navigator await'ten ONCE yakalanir: `showDialog` bir async bosluk
        //    acar ve sonrasinda `context` kullanmak (State dispose olduysa)
        //    patlar. Bu projede TAM AYNI sinif hata turu 67'de aramayi
        //    olduruyordu ("Cannot use ref after the widget was disposed").
        final nav = Navigator.of(context);
        final cik = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Yükleme sürüyor'),
            content: const Text(
              'Çıkarsan gönderi paylaşılmayacak. Çıkılsın mı?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Devam et'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Çık', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (cik == true && mounted) {
          _iptal?.cancel('kullanici cikti');
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_reelsMi ? 'Yeni Reels' : 'Yeni gönderi'),
          actions: [
            TextButton(
              onPressed: _yukleniyor ? null : _paylas,
              child: const Text('Paylaş'),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _yukleniyor,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              TextField(
                controller: _metin,
                minLines: 3,
                maxLines: 10,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: _reelsMi
                      ? 'Reels açıklaması...'
                      : 'Neler oluyor? Bir şeyler yaz...',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_medya.isNotEmpty) _onizleme(),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!_reelsMi)
                    OutlinedButton.icon(
                      onPressed: _yukleniyor ? null : _gorselSec,
                      icon: const Icon(LucideIcons.image, size: 18),
                      label: const Text('Fotoğraf'),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _yukleniyor ? null : _videoSec,
                    icon: const Icon(LucideIcons.video, size: 18),
                    label: Text(_reelsMi ? 'Video seç' : 'Video'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _yorumKapali,
                onChanged: _yukleniyor
                    ? null
                    : (v) => setState(() => _yorumKapali = v),
                title: const Text('Yorumları kapat'),
                secondary: const Icon(LucideIcons.messageCircleOff),
              ),
              if (_yukleniyor) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _toplamIlerleme),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _toplamIlerleme >= 0.98
                            ? 'Sunucu doğruluyor...'
                            : 'Yükleniyor %${(_toplamIlerleme * 100).toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _iptal?.cancel('kullanici iptal'),
                      child: const Text('İptal'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _onizleme() {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _medya.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = _medya[i];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: m.video
                    ? Container(
                        width: 100,
                        height: 140,
                        color: const Color(0xFF1A1A24),
                        alignment: Alignment.center,
                        child: const Icon(
                          LucideIcons.video,
                          color: Colors.white70,
                          size: 30,
                        ),
                      )
                    : Image.file(
                        m.dosya,
                        width: 100,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
              ),
              // Yukleme yuzdesi — DOSYA BASINA (kullanici hangi dosyanin
              // takildigini gorebilmeli).
              if (m.ilerleme != null && m.ilerleme! < 1)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColoredBox(
                      color: const Color(0x99000000),
                      child: Center(
                        child: Text(
                          '%${(m.ilerleme! * 100).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (m.mediaId != null)
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(
                    LucideIcons.circleCheck,
                    color: Color(0xFF4CAF50),
                    size: 18,
                  ),
                ),
              if (!_yukleniyor)
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _medya.removeAt(i)),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xAA000000),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          LucideIcons.x,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

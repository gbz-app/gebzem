import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart' show kimlikRengi;
import '../../router.dart' show rootMessengerKey;
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'home_screen.dart' show myProfileProvider;

/// ⚠️⚠️ TURU 74 — PROFİL DÜZENLEME (ad, hakkımda, **profil fotoğrafı**).
///
/// Profil fotoğrafı, medya altyapısının **ilk müşterisi**: tek dosya, tek boyut,
/// tek tip. presign → PUT → commit → `avatar_media_id` zincirinin tamamı burada
/// gerçek kullanıcıyla kanıtlanır.
///
/// ⚠️⚠️ GÜVENLİK: `avatar_url` artık istemciden KABUL EDİLMİYOR (turu 74).
///     Eskiden herkes profil fotoğrafı olarak istediği URL'yi yazabiliyordu; avatar
///     sohbet listesinde HERKESE çizildiği için saldırgan kendi sunucusunu adres
///     verip mesajlaştığı herkesin IP'sini toplayabilirdi (izleme pikseli).
///     Artık yalnızca bizim R2'mize yüklenmiş, sahipliği doğrulanmış medya bağlanır.
class ProfilDuzenleEkrani extends ConsumerStatefulWidget {
  const ProfilDuzenleEkrani({super.key});

  @override
  ConsumerState<ProfilDuzenleEkrani> createState() =>
      _ProfilDuzenleEkraniState();
}

class _ProfilDuzenleEkraniState extends ConsumerState<ProfilDuzenleEkrani> {
  final _ad = TextEditingController();
  final _hakkimda = TextEditingController();
  String? _avatarMediaId;

  /// ⚠️⚠️ TURU 78 — KAPAK icin IKI ALAN gerekiyor, biri yetmez.
  ///
  /// `_kapakMediaId` yeni secilen kapak; `_kapakSilindi` ise "KULLANICI
  /// KALDIRDI" bilgisi. Tek alanla `null` iki AYRI durumu temsil ederdi:
  /// "hic dokunmadim" ve "kaldirdim". Sunucu `null`i "degistirme" olarak
  /// yorumladigi icin (avatar deseni) "Kapağı kaldır" dugmesi **SESSIZCE
  /// HICBIR SEY YAPMAZDI** — ozellik var gorunup fiilen calismazdi.
  /// Bu yuzden kaldirma bos dize `''` NOBETCISI ile gonderilir.
  /// ⚠️ YAPMA: iki alani tek `String?`e indirgeme.
  String? _kapakMediaId;
  bool _kapakSilindi = false;

  bool _yukleniyor = false;
  bool _kapakYukleniyor = false;
  bool _kaydediliyor = false;
  bool _dolduruldu = false;

  @override
  void dispose() {
    _ad.dispose();
    _hakkimda.dispose();
    super.dispose();
  }

  Future<void> _fotoSec(ImageSource kaynak) async {
    // ⚠️ Kamera aktif arama/oda/yayın sırasında ENGELLİ (iOS paylaşılan
    //     videoCapturer). Galeri serbest — sistem picker'ı ayrı süreç.
    if (kaynak == ImageSource.camera && !MedyaKapisi.izinVer(ref)) return;

    final x = await ImagePicker().pickImage(
      source: kaynak,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (x == null || !mounted) return;

    setState(() => _yukleniyor = true);
    try {
      // ⚠️ EXIF temizleme ZORUNLU: profil fotoğrafı da telefonla çekilir ve
      //     konum bilgisi taşır. Sunucu GPS bulursa 422 döner.
      final hazir = await MedyaServisi.gorseliHazirla(File(x.path));
      if (hazir == null) throw Exception('Fotoğraf hazırlanamadı');
      final id = await ref
          .read(medyaServisiProvider)
          .yukle(
            dosya: hazir,
            kind:
                'avatar', // ⚠️ 'image' DEĞİL: sunucu avatar tavanını (4 MB) uygular
            mime: 'image/jpeg',
          );
      if (mounted) setState(() => _avatarMediaId = id);
    } catch (e) {
      if (mounted) {
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  /// ⚠️⚠️ TURU 78 — KAPAK (arka plan) gorseli secimi.
  ///
  /// ⚠️ `kind: 'kapak'` — 'avatar' DEGIL. Avatarin 4 MB tavani 16:9 tam
  ///    genislik bir gorsele dar; ayrica `users/handler.go` avatar baglarken
  ///    `kind='avatar'` sartini uyguluyor, ayni turu paylassalardi o sart
  ///    ANLAMINI YITIRIRDI (kapak avatar yapilabilirdi).
  /// ⚠️ EXIF temizligi ZORUNLU: kapak da telefonla cekilir ve KONUM tasir;
  ///    sunucu GPS bulursa 422 doner.
  /// ⚠️ KIRPMA PAKETI EKLENMEDI (`image_cropper` Android'de UCrop, iOS'ta
  ///    TOCropViewController native bagimliligi + manifest/Info.plist
  ///    degisikligi ister; bu projede iOS derlemesi bu sinif eklemelerle
  ///    defalarca patladi). `BoxFit.cover` gorselin ORTASINI gosterir ve
  ///    onizleme AYNI 16:9 kutuda cizildigi icin kullanici KAYDETMEDEN ONCE
  ///    ne gorunecegini gorur.
  Future<void> _kapakSec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // ⚠️ Avatardan (1200) GENIS: kapak tam genislik cizilir.
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    setState(() => _kapakYukleniyor = true);
    try {
      final hazir = await MedyaServisi.gorseliHazirla(File(x.path));
      if (hazir == null) throw Exception('Görsel hazırlanamadı');
      final id = await ref
          .read(medyaServisiProvider)
          .yukle(dosya: hazir, kind: 'kapak', mime: 'image/jpeg');
      if (mounted) {
        setState(() {
          _kapakMediaId = id;
          _kapakSilindi = false; // yeni kapak secildi: kaldirma niyeti bitti
        });
      }
    } catch (e) {
      if (mounted) {
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _kapakYukleniyor = false);
    }
  }

  Future<void> _fotoPaneli() async {
    final donanim = MedyaKapisi.donanimSerbest(ref);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Galeriden seç'),
              onTap: () {
                Navigator.of(c).pop();
                _fotoSec(ImageSource.gallery);
              },
            ),
            // ⚠️ Görüşme sürerken kamera satırı PASİF (turu 66b: görünen ama
            //     çalışmayan düğme kullanıcıyı yanıltır — sebebi yazılır).
            ListTile(
              enabled: donanim,
              leading: const Icon(LucideIcons.camera),
              title: const Text('Fotoğraf çek'),
              subtitle: donanim
                  ? null
                  : const Text('Görüşme sürerken kullanılamaz'),
              onTap: donanim
                  ? () {
                      Navigator.of(c).pop();
                      _fotoSec(ImageSource.camera);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    try {
      await ref
          .read(apiProvider)
          .patch(
            '/users/me',
            data: {
              'name': _ad.text.trim(),
              'about': _hakkimda.text.trim(),
              // ⚠️ URL DEĞİL id. Sunucu sahipliği ve doğrulanmışlığı kontrol eder.
              if (_avatarMediaId != null) 'avatar_media_id': _avatarMediaId,
              // ⚠️⚠️ TURU 78 — KAPAK: `if (x != null)` deseni BURADA YETMEZ.
              //     Sunucu `null`i "değiştirme" olarak yorumluyor (avatar
              //     deseni), dolayısıyla kaldırma niyeti kaybolurdu. Boş dize
              //     `''` NÖBETÇİSİ "kaldır" demektir.
              //     ⚠️ YAPMA: bu üç durumu tek koşula indirgeme.
              if (_kapakSilindi)
                'kapak_media_id': ''
              else if (_kapakMediaId != null)
                'kapak_media_id': _kapakMediaId,
            },
          );
      // ⚠️ Profil sağlayıcısını tazele — sohbet listesindeki avatar da güncellensin.
      ref.invalidate(myProfileProvider);
      if (mounted) {
        rootMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Profil güncellendi')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(myProfileProvider);
    // ⚠️ Alanları BİR KEZ doldur: her rebuild'de doldurursak kullanıcının
    //     yazdığı metin silinir.
    profil.whenData((p) {
      if (!_dolduruldu) {
        _dolduruldu = true;
        _ad.text = p['name'] as String? ?? '';
        _hakkimda.text = p['about'] as String? ?? '';
        _avatarMediaId ??= p['avatar_media_id'] as String?;
        _kapakMediaId ??= p['kapak_media_id'] as String?;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Profili düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---- KAPAK (arka plan) — TURU 78
          // ⚠️ Onizleme AYNI 16:9 kutuda cizilir: kirpma paketi olmadigi icin
          //    kullanicinin neyin gorunecegini KAYDETMEDEN ONCE gormesi SART.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: GestureDetector(
              onTap: _kapakYukleniyor ? null : _kapakSec,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _kapakOnizleme(context),
              ),
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _kapakYukleniyor ? null : _kapakSec,
                icon: const Icon(LucideIcons.image, size: 17),
                label: const Text('Kapak seç'),
              ),
              // ⚠️ "Kaldır" YALNIZ gosterilecek bir kapak varsa cizilir.
              //    Bos ekranda "kaldır" dugmesi olu dugmedir.
              if (!_kapakSilindi && (_kapakMediaId ?? '').isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    // ⚠️ Nobetci: `_kapakSilindi` PATCH govdesinde `''` olarak
                    //    gider. Yalnizca `_kapakMediaId = null` yapsaydik
                    //    sunucu "degistirme" anlar ve kapak KALKMAZDI.
                    _kapakSilindi = true;
                  }),
                  icon: const Icon(LucideIcons.trash2, size: 17),
                  label: const Text('Kaldır'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Stack(
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: _yukleniyor
                      ? const Center(child: CircularProgressIndicator())
                      : Avatar(
                          ad: _ad.text,
                          mediaId: _avatarMediaId,
                          avatarUrl:
                              profil.valueOrNull?['avatar_url'] as String? ??
                              '',
                          cap: 112,
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _yukleniyor ? null : _fotoPaneli,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          LucideIcons.camera,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _ad,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Adınız',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}), // avatar harfi güncellensin
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hakkimda,
            maxLength: 140,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Hakkımda',
              hintText: 'Kısa bir not',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _kaydediliyor || _yukleniyor ? null : _kaydet,
            icon: _kaydediliyor
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.check),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  /// Kapak onizlemesi: yukleniyor / secili gorsel / kaldirildi-ya-da-yok.
  ///
  /// ⚠️ Kapak YOKKEN bos gri kutu cizilmez — profil basligindaki ile **AYNI**
  ///    kimlik degradesi cizilir. Iki yerde farkli bos-durum cizmek kullaniciya
  ///    "kaydettim ama baska turlu gorundu" dedirtirdi.
  Widget _kapakOnizleme(BuildContext context) {
    if (_kapakYukleniyor) {
      return const ColoredBox(
        color: Color(0xFF14101C),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // ⚠️ "Kaldirildi" isaretliyken MEVCUT kapak gosterilmez — kullanici
    //    kaydetmeden once sonucu gorur.
    final id = _kapakSilindi ? null : _kapakMediaId;
    if (id != null && id.isNotEmpty) {
      return MedyaGorsel(mediaId: id, fit: BoxFit.cover);
    }
    final benimId = (ref.read(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    final c = kimlikRengi(benimId);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.withValues(alpha: .85), c.withValues(alpha: .30)],
        ),
      ),
      child: const Center(
        child: Text(
          'Kapak görseli ekle',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
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
  ConsumerState<ProfilDuzenleEkrani> createState() => _ProfilDuzenleEkraniState();
}

class _ProfilDuzenleEkraniState extends ConsumerState<ProfilDuzenleEkrani> {
  final _ad = TextEditingController();
  final _hakkimda = TextEditingController();
  String? _avatarMediaId;
  bool _yukleniyor = false;
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
      final id = await ref.read(medyaServisiProvider).yukle(
            dosya: hazir,
            kind: 'avatar', // ⚠️ 'image' DEĞİL: sunucu avatar tavanını (4 MB) uygular
            mime: 'image/jpeg',
          );
      if (mounted) setState(() => _avatarMediaId = id);
    } catch (e) {
      if (mounted) {
        rootMessengerKey.currentState
            ?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _fotoPaneli() async {
    final donanim = MedyaKapisi.donanimSerbest(ref);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
            subtitle: donanim ? null : const Text('Görüşme sürerken kullanılamaz'),
            onTap: donanim
                ? () {
                    Navigator.of(c).pop();
                    _fotoSec(ImageSource.camera);
                  }
                : null,
          ),
        ]),
      ),
    );
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    try {
      await ref.read(apiProvider).patch('/users/me', data: {
        'name': _ad.text.trim(),
        'about': _hakkimda.text.trim(),
        // ⚠️ URL DEĞİL id. Sunucu sahipliği ve doğrulanmışlığı kontrol eder.
        if (_avatarMediaId != null) 'avatar_media_id': _avatarMediaId,
      });
      // ⚠️ Profil sağlayıcısını tazele — sohbet listesindeki avatar da güncellensin.
      ref.invalidate(myProfileProvider);
      if (mounted) {
        rootMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Profil güncellendi')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        rootMessengerKey.currentState
            ?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
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
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Profili düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(children: [
              SizedBox(
                width: 112,
                height: 112,
                child: _yukleniyor
                    ? const Center(child: CircularProgressIndicator())
                    : Avatar(
                        ad: _ad.text,
                        mediaId: _avatarMediaId,
                        avatarUrl: profil.valueOrNull?['avatar_url'] as String? ?? '',
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
                      child: Icon(LucideIcons.camera, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ]),
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
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.check),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

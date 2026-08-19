import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'kanal_servisi.dart';

/// ⚠️⚠️ TURU 75 — KANAL OLUSTURMA.
///
/// ⚠️ Kanal adresi (@kanaladi) `users.username` ile AYNI HAVUZDA DEGIL —
///    kanal ve kisi ayri ad uzaylari (sunucu serhinde gerekce yazili).
class KanalOlustur extends ConsumerStatefulWidget {
  const KanalOlustur({super.key});

  @override
  ConsumerState<KanalOlustur> createState() => _KanalOlusturState();
}

class _KanalOlusturState extends ConsumerState<KanalOlustur> {
  final _ad = TextEditingController();
  final _adres = TextEditingController();
  final _aciklama = TextEditingController();
  File? _avatar;
  String? _avatarMediaId;
  bool _calisiyor = false;

  @override
  void dispose() {
    _ad.dispose();
    _adres.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _avatarSec() async {
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez');
      return;
    }
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;
    setState(() {
      _avatar = File(x!.path);
      // ⚠️ Yeni dosya secildi -> ONCEKI yuklemenin id'si GECERSIZ. Sifirlanmazsa
      //    kullanici fotografi degistirse bile ESKI gorsel kaydedilirdi.
      _avatarMediaId = null;
    });
  }

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _olustur() async {
    final ad = _ad.text.trim();
    if (ad.length < 2) {
      _uyar('Topluluk adı en az 2 karakter olmalı');
      return;
    }
    final adres = _adres.text.trim().toLowerCase();
    if (adres.isNotEmpty && !RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(adres)) {
      _uyar('Topluluk adresi 3-24 karakter olmalı (a-z, 0-9, _)');
      return;
    }
    setState(() => _calisiyor = true);
    try {
      if (_avatar != null && _avatarMediaId == null) {
        // ⚠️ EXIF (KONUM) TEMIZLIGI ZORUNLU: sunucu GPS bulursa 422 doner.
        final hazir = await MedyaServisi.gorseliHazirla(_avatar!);
        if (hazir == null) throw Exception('Fotoğraf hazırlanamadı');
        _avatarMediaId = await ref
            .read(medyaServisiProvider)
            .yukle(dosya: hazir, kind: 'avatar', mime: 'image/jpeg');
      }
      final id = await ref
          .read(kanalServisiProvider)
          .olustur(
            ad: ad,
            kullaniciAdi: adres,
            aciklama: _aciklama.text.trim(),
            avatarMediaId: _avatarMediaId ?? '',
          );
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _calisiyor = false);
      // ⚠️ Sunucunun kendi metni GOSTERILIR ("bu kanal adresi alınmış" gibi) —
      //    genel "hata oluştu" demek kullaniciyi cozumden uzaklastirir.
      String m = 'Topluluk oluşturulamadı';
      if (e is DioException && e.response?.data is Map) {
        final s = (e.response!.data as Map)['error'];
        if (s is String && s.isNotEmpty) m = s;
      }
      _uyar(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Topluluk aç'),
        actions: [
          TextButton(
            onPressed: _calisiyor ? null : _olustur,
            child: const Text('Oluştur'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _calisiyor,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Center(
              child: GestureDetector(
                onTap: _avatarSec,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    if (_avatar != null)
                      ClipOval(
                        child: Image.file(
                          _avatar!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Avatar(ad: _ad.text, cap: 96),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF8B5CF6),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          LucideIcons.camera,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _ad,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Topluluk adı',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _adres,
              maxLength: 24,
              inputFormatters: [
                // ⚠️ Bicimleyici SUNUCU KURALIYLA AYNI: buyuk harf/turkce karakter
                //    yazilamaz. Aksi halde kullanici yazar, gonderir, 400 yer.
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Topluluk adresi (isteğe bağlı)',
                prefixText: '@',
                helperText: 'Paylaşılabilir bağlantı: gebzem.app/k/adres',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _aciklama,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(LucideIcons.megaphone, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Topluluk tek yönlüdür: yalnızca sen ve yetkililer gönderi '
                        'paylaşabilir. Aboneler okur ve beğenir, yanıt yazamaz.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_calisiyor) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

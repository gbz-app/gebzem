import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'medya_kapisi.dart';

/// ⚠️⚠️ TURU 74 — ATAÇ PANELİ (mesaj kutusundaki + düğmesi).
///
/// ⚠️ **KAMERA SATIRI, aktif arama/oda/yayın sırasında ÇİZİLMEZ.** Sadece gövdeyi
///     kapatmak YETMEZ — turu 66b dersi: *"bir özelliği bayrakla kapatırken GÖVDEYİ
///     değiştirmek yetmez; o özelliği ÇAĞIRAN ARAYÜZ de gizlenmeli, yoksa düğme
///     SESSİZCE BAŞKA İŞ YAPAR."* Kullanıcı görünen bir düğmeye basıp hiçbir şey
///     olmamasını da anlamaz. Bu yüzden hem satır gizlenir hem gövdede ikinci kapı var.
///
/// ⚠️ Arayüzde EMOJİ YOK — Lucide ikonlar (CLAUDE.md kuralı).
class AtacSecimi {
  const AtacSecimi(this.dosyalar, this.tur);

  final List<File> dosyalar;
  final String tur; // image
}

Future<AtacSecimi?> atacPaneliAc(BuildContext context, WidgetRef ref) async {
  final donanim = MedyaKapisi.donanimSerbest(ref);
  AtacSecimi? sonuc;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const _AtacIkon(LucideIcons.image, Color(0xFF7C4DFF)),
          title: const Text('Fotoğraf'),
          subtitle: const Text('Galeriden seç'),
          onTap: () async {
            Navigator.of(c).pop();
            // ⚠️ Galeri sistem picker'ı AYRI SÜREÇTE çalışır: kameraya/mikrofona
            //     dokunmaz, bu yüzden görüşme sırasında da SERBEST.
            final secim = await ImagePicker().pickMultiImage(limit: 10);
            if (secim.isNotEmpty) {
              sonuc = AtacSecimi(secim.map((x) => File(x.path)).toList(), 'image');
            }
          },
        ),
        // ⚠️⚠️ KAMERA — görüşme sürerken SATIR HİÇ ÇİZİLMEZ (yukarıdaki şerh).
        if (donanim)
          ListTile(
            leading: const _AtacIkon(LucideIcons.camera, Color(0xFF00BFA5)),
            title: const Text('Kamera'),
            subtitle: const Text('Fotoğraf çek'),
            onTap: () async {
              Navigator.of(c).pop();
              // ⚠️ İKİNCİ KAPI: panel açıkken arama gelmiş olabilir.
              if (!MedyaKapisi.izinVer(ref)) return;
              final x = await ImagePicker().pickImage(
                source: ImageSource.camera,
                // ⚠️ Çekim anında düşür: 4K fotoğrafı belleğe alıp sonra sıkıştırmak
                //     düşük bellekli cihazlarda uygulamayı öldürüyor.
                maxWidth: 2400,
                maxHeight: 2400,
                imageQuality: 90,
              );
              if (x != null) sonuc = AtacSecimi([File(x.path)], 'image');
            },
          )
        else
          const ListTile(
            enabled: false,
            leading: _AtacIkon(LucideIcons.camera, Color(0xFF9E9E9E)),
            title: Text('Kamera'),
            subtitle: Text('Görüşme sürerken kullanılamaz'),
          ),
      ]),
    ),
  );
  return sonuc;
}

class _AtacIkon extends StatelessWidget {
  const _AtacIkon(this.ikon, this.renk);

  final IconData ikon;
  final Color renk;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(ikon, size: 20, color: renk),
      );
}

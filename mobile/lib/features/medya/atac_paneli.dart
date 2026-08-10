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
  const AtacSecimi(this.dosyalar, this.tur) : eylem = '';

  /// ⚠️⚠️ TURU 81 — DOSYASIZ EYLEMLER (konum · kişi · IBAN · etkinlik).
  ///
  /// Panel eskiden YALNIZCA dosya döndürebiliyordu (`Fotoğraf` + `Kamera`).
  /// Kullanıcının istediği yeni paylaşımların hiçbiri dosya DEĞİL; yapısal
  /// veri taşıyorlar ve akışları birbirinden farklı (konum izin ister,
  /// kişi seçici açar, IBAN form açar, etkinlik ayrı ekrana gider).
  ///
  /// ⚠️ Panel bu akışları KENDİ YÜRÜTMEZ, yalnızca HANGİSİNİN seçildiğini
  ///    söyler. Gerekçe: sheet `pop` edildikten sonra `context`i ölür ve
  ///    turu 74b'de tam bu yüzden ataç düğmesi HİÇ ÇALIŞMIYORDU (aşağıdaki
  ///    şerh). Akışı sohbet ekranı, kendi canlı `context`iyle yürütür.
  const AtacSecimi.eylemli(this.eylem)
    : dosyalar = const [],
      tur = '';

  final List<File> dosyalar;
  final String tur; // image

  /// '' | 'konum' | 'kisi' | 'iban' | 'etkinlik'
  final String eylem;
}

/// ⚠️⚠️ TURU 74b (DENETİM BULGUSU — ÖZELLİK HİÇ ÇALIŞMIYORDU):
/// İlk sürümde `onTap` ÖNCE `Navigator.pop()` çağırıyor, seçim sonucunu ise
/// `await ImagePicker()...`'dan SONRA bir dış değişkene yazıyordu. Ama
/// `await showModalBottomSheet` **pop anında** (~250 ms) tamamlanır; kullanıcı
/// galeride saniyelerce gezer. Fonksiyon dönerken değişken hâlâ `null` oluyordu
/// → `_atacAc` ilk satırda sessizce çıkıyor → **ataç düğmesi hiçbir şey yapmıyordu,
/// hata da vermiyordu.**
///
/// DOĞRUSU: sonucu **sheet'in dönüş değeriyle** taşı — `pop(deger)` picker'dan
/// SONRA çağrılır, `showModalBottomSheet<AtacSecimi>` onu döndürür.
/// ⚠️ YAPMA: sonucu dış değişkene yazıp `pop()`u öne alma.
/// ⚠️ AYNI TUZAK `moderasyon_sheet.engelleOnayiAc` içinde de vardı — orada da
///     düzeltildi. Yeni bir sheet yazarken bu deseni kullan.
Future<AtacSecimi?> atacPaneliAc(BuildContext context, WidgetRef ref) async {
  final donanim = MedyaKapisi.donanimSerbest(ref);

  return showModalBottomSheet<AtacSecimi>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const _AtacIkon(LucideIcons.image, Color(0xFF7C4DFF)),
          title: const Text('Fotoğraf'),
          subtitle: const Text('Galeriden seç'),
          onTap: () async {
            // ⚠️ Galeri sistem picker'ı AYRI SÜREÇTE çalışır: kameraya/mikrofona
            //     dokunmaz. AMA uygulamayı ARKA PLANA atar ve BİZİM yaşam döngüsü
            //     kodumuz kamerayı kapatabilir — bu yüzden `pickerAcik` bayrağı
            //     ZORUNLU (bkz. MedyaKapisi.pickerAcik şerhi).
            List<XFile> secim = const [];
            try {
              MedyaKapisi.pickerAcik = true;
              secim = await ImagePicker().pickMultiImage(limit: 10);
            } finally {
              MedyaKapisi.pickerAcik = false;
            }
            if (!c.mounted) return;
            Navigator.of(c).pop(secim.isEmpty
                ? null
                : AtacSecimi(secim.map((x) => File(x.path)).toList(), 'image'));
          },
        ),
        // ⚠️⚠️ KAMERA — görüşme sürerken SATIR HİÇ ÇİZİLMEZ (yukarıdaki şerh).
        if (donanim)
          ListTile(
            leading: const _AtacIkon(LucideIcons.camera, Color(0xFF00BFA5)),
            title: const Text('Kamera'),
            subtitle: const Text('Fotoğraf çek'),
            onTap: () async {
              // ⚠️ İKİNCİ KAPI: panel açıkken arama gelmiş olabilir.
              if (!MedyaKapisi.izinVer(ref)) {
                if (c.mounted) Navigator.of(c).pop();
                return;
              }
              XFile? x;
              try {
                MedyaKapisi.pickerAcik = true;
                x = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  // ⚠️ Çekim anında düşür: 4K fotoğrafı belleğe alıp sonra
                  //     sıkıştırmak düşük bellekli cihazlarda uygulamayı öldürüyor.
                  maxWidth: 2400,
                  maxHeight: 2400,
                  imageQuality: 90,
                );
              } finally {
                MedyaKapisi.pickerAcik = false;
              }
              if (!c.mounted) return;
              Navigator.of(c)
                  .pop(x == null ? null : AtacSecimi([File(x.path)], 'image'));
            },
          )
        else
          const ListTile(
            enabled: false,
            leading: _AtacIkon(LucideIcons.camera, Color(0xFF9E9E9E)),
            title: Text('Kamera'),
            subtitle: Text('Görüşme sürerken kullanılamaz'),
          ),
        const Divider(height: 1),
        // ⚠️⚠️ TURU 81 — DOSYASIZ PAYLASIMLAR (kullanici emri).
        //    Bunlar `pop(AtacSecimi.eylemli(...))` ile YALNIZCA SECIMI bildirir;
        //    akisi sohbet ekrani yurutur (bkz. `AtacSecimi.eylemli` serhi).
        ListTile(
          leading: const _AtacIkon(LucideIcons.mapPin, Color(0xFFEF5350)),
          title: const Text('Konum'),
          subtitle: const Text('Bulunduğun yeri gönder'),
          onTap: () => Navigator.of(c).pop(const AtacSecimi.eylemli('konum')),
        ),
        ListTile(
          leading: const _AtacIkon(LucideIcons.userRound, Color(0xFF42A5F5)),
          title: const Text('Kişi'),
          subtitle: const Text('Bir profili paylaş'),
          onTap: () => Navigator.of(c).pop(const AtacSecimi.eylemli('kisi')),
        ),
        ListTile(
          leading: const _AtacIkon(LucideIcons.creditCard, Color(0xFF26A69A)),
          title: const Text('IBAN'),
          subtitle: const Text('Hesap bilgisi gönder'),
          onTap: () => Navigator.of(c).pop(const AtacSecimi.eylemli('iban')),
        ),
        ListTile(
          leading: const _AtacIkon(LucideIcons.calendarPlus, Color(0xFFFFA726)),
          title: const Text('Etkinlik'),
          subtitle: const Text('Etkinlik oluştur ve paylaş'),
          onTap: () =>
              Navigator.of(c).pop(const AtacSecimi.eylemli('etkinlik')),
        ),
      ]),
    ),
  );
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

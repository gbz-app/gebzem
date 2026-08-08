import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'chats_provider.dart';
import 'models.dart';

/// ⚠️⚠️ TURU 74 — MESAJ ISLEMLERI + ENGELLEME/SIKAYET ARAYUZU.
///
/// App Store Review Guideline 1.2 (kullanici uretimi icerik) UC seyi BIRLIKTE sart
/// kosuyor: icerik filtreleme, kullaniciyi ENGELLEME ve taciz edici icerigi BILDIRME.
/// Backend uclari turu 74'te eklendi; burasi onlarin arayuz ayagi.
///
/// ⚠️ ARAYUZDE EMOJI YASAK — tum ikonlar Lucide (CLAUDE.md kurali).
/// ⚠️ MODAL DIALOG YERINE BOTTOM SHEET: turu 15 dersi — modal dialog acikken mesgul
///     muhafizi askida kalabiliyor ve gelen aramalar dusuyordu. Sheet'ler
///     `whenComplete` ile kapanislarini bildirir.

/// Mesaja uzun basinca acilan islem menusu.
Future<void> mesajMenusuAc(
  BuildContext context,
  WidgetRef ref, {
  required Message mesaj,
  required bool benimMi,
  required String chatId,
}) async {
  // Silinmis mesajda yapilacak is yok.
  if (mesaj.deletedForAll) return;
  final mesajci = ScaffoldMessenger.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kopyala — yalniz metin tasiyan mesajlarda anlamli.
          if (mesaj.content.isNotEmpty)
            ListTile(
              leading: const Icon(LucideIcons.copy),
              title: const Text('Kopyala'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: mesaj.content));
                if (c.mounted) Navigator.of(c).pop();
                mesajci.showSnackBar(
                    const SnackBar(content: Text('Kopyalandı')));
              },
            ),
          if (benimMi)
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Color(0xFFD32F2F)),
              title: const Text('Herkesten sil',
                  style: TextStyle(color: Color(0xFFD32F2F))),
              subtitle: const Text('Bu mesaj karşı tarafta da silinir'),
              onTap: () async {
                Navigator.of(c).pop();
                try {
                  await ref
                      .read(messagesProvider(chatId).notifier)
                      .mesajiSil(mesaj.id);
                } catch (e) {
                  mesajci.showSnackBar(
                      SnackBar(content: Text(apiErrorMessage(e))));
                }
              },
            )
          else
            ListTile(
              leading: const Icon(LucideIcons.flag),
              title: const Text('Şikâyet et'),
              onTap: () {
                Navigator.of(c).pop();
                sikayetSheetAc(context, ref,
                    hedefTur: 'mesaj', hedefId: '${mesaj.id}');
              },
            ),
        ],
      ),
    ),
  );
}

/// Sikayet sebebi secimi. Sebepler SABIT liste — serbest metin sunucuda 1000
/// karakterle sinirli ama once kategori isteniyor ki admin kuyrugu siniflandirilabilsin.
Future<void> sikayetSheetAc(
  BuildContext context,
  WidgetRef ref, {
  required String hedefTur, // kullanici | mesaj
  required String hedefId,
}) async {
  const sebepler = <String, String>{
    'spam': 'Spam veya reklam',
    'taciz': 'Taciz veya zorbalık',
    'cinsel': 'Cinsel içerik',
    'siddet': 'Şiddet veya nefret söylemi',
    'sahte': 'Sahte hesap veya dolandırıcılık',
    'diger': 'Diğer',
  };
  final mesajci = ScaffoldMessenger.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Text('Neden şikâyet ediyorsunuz?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          for (final e in sebepler.entries)
            ListTile(
              dense: true,
              title: Text(e.value),
              onTap: () async {
                Navigator.of(c).pop();
                try {
                  await ref.read(apiProvider).post('/reports', data: {
                    'hedef_tur': hedefTur,
                    'hedef_id': hedefId,
                    'sebep': e.key,
                  });
                  mesajci.showSnackBar(const SnackBar(
                      content: Text(
                          'Şikâyetiniz alındı. En kısa sürede incelenecek.')));
                } catch (err) {
                  mesajci.showSnackBar(
                      SnackBar(content: Text(apiErrorMessage(err))));
                }
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Kullaniciyi engelle/engeli kaldir onayi.
/// ⚠️ Engelleme CIFT YONLUDUR (sunucu kurali): engelledikten sonra o kisi sana,
///     sen de ona mesaj gonderemezsin. Kullaniciya bunu ACIKCA soyluyoruz.
Future<bool> engelleOnayiAc(
  BuildContext context,
  WidgetRef ref, {
  required String kullaniciId,
  required String ad,
  required bool suAnEngelli,
}) async {
  final mesajci = ScaffoldMessenger.of(context);
  var sonuc = false;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Text(
              suAnEngelli
                  ? '$ad kişisinin engelini kaldırmak istiyor musunuz?'
                  : '$ad kişisini engellemek istiyor musunuz?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          if (!suAnEngelli)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Text(
                'Bu kişi size mesaj gönderemez, siz de ona gönderemezsiniz. '
                'Engellendiğini kendisine bildirmeyiz.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ListTile(
            leading: Icon(suAnEngelli ? LucideIcons.userCheck : LucideIcons.ban,
                color: suAnEngelli ? null : const Color(0xFFD32F2F)),
            title: Text(suAnEngelli ? 'Engeli kaldır' : 'Engelle',
                style: TextStyle(
                    color: suAnEngelli ? null : const Color(0xFFD32F2F),
                    fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.of(c).pop();
              try {
                final api = ref.read(apiProvider);
                if (suAnEngelli) {
                  await api.delete('/users/$kullaniciId/block');
                } else {
                  await api.post('/users/$kullaniciId/block');
                }
                sonuc = true;
                mesajci.showSnackBar(SnackBar(
                    content: Text(suAnEngelli
                        ? 'Engel kaldırıldı'
                        : '$ad engellendi')));
              } catch (e) {
                mesajci.showSnackBar(
                    SnackBar(content: Text(apiErrorMessage(e))));
              }
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.x),
            title: const Text('Vazgeç'),
            onTap: () => Navigator.of(c).pop(),
          ),
        ],
      ),
    ),
  );
  return sonuc;
}

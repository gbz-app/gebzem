import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../chats/chats_provider.dart';
import '../chats/models.dart';
import '../medya/medya_gorsel.dart';

/// ⚠️⚠️ TURU 76 — GERCEK "PAYLAS" (kullanici emri: "begen/yorum/paylas Instagram gibi").
///
/// KOK NEDEN: kartaki gonder (send) ikonu YALNIZCA panoya link kopyaliyor ve
/// "sohbete yapistirin" diyordu. Yani Instagram'daki ASIL islev — gonderiyi bir
/// sohbete DOGRUDAN gondermek — hic yoktu; kullanici uygulamadan cikip sohbeti
/// bulup elle yapistirmak zorundaydi.
///
/// ⚠️ COKLU SECIM: Instagram'da tek dokunusla birden fazla kisiye gonderilir.
///    Tek tek gondermek 4 dokunus x N kisi ederdi.
/// ⚠️ HATA YUTULMAZ: bir sohbete gonderilemezse kullaniciya HANGI sohbetin
///    basarisiz oldugu soylenir — "gonderdim sandim ama gitmemis" bu projenin
///    tekrarlayan sikayeti (CLAUDE.md).
/// ⚠️ ENGEL: sunucu `SendMessage` icinde CIFT YONLU engel kontrolu yapiyor;
///    engelli birine gonderim NOTR hatayla doner (engellemeyi ifsa etmez).
Future<void> paylasSheetAc(
  BuildContext context,
  WidgetRef ref, {
  required String baglanti,
  String? onizlemeMediaId,
  String? baslik,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaylasSheet(
      baglanti: baglanti,
      onizlemeMediaId: onizlemeMediaId,
      baslik: baslik,
    ),
  );
}

class _PaylasSheet extends ConsumerStatefulWidget {
  const _PaylasSheet({
    required this.baglanti,
    this.onizlemeMediaId,
    this.baslik,
  });

  final String baglanti;
  final String? onizlemeMediaId;
  final String? baslik;

  @override
  ConsumerState<_PaylasSheet> createState() => _PaylasSheetState();
}

class _PaylasSheetState extends ConsumerState<_PaylasSheet> {
  final Set<String> _secili = {};
  bool _gonderiliyor = false;

  /// ⚠️ Liste `chatsProvider`dan gelir — AYRI BIR `/chats` istegi ATILMAZ.
  ///    Ikinci bir kaynak, arsiv/sabitleme durumunda listeyle DRIFT ederdi
  ///    (CLAUDE.md turu 72b/H: "ayni kuralin iki kopyasi drift eder").
  /// ⚠️ ARSIVLENMIS sohbetler ELENIR: kullanici onlari BILEREK gozunun onunden
  ///    kaldirmis; paylasim listesinde geri getirmek arsivlemenin anlamini bozar.
  List<Chat> _liste(List<Chat> hepsi) =>
      hepsi.where((c) => !c.archived).toList();

  Future<void> _gonder() async {
    if (_secili.isEmpty || _gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    final api = ref.read(apiProvider);
    final hepsi = ref.read(chatsProvider).valueOrNull ?? const <Chat>[];
    final basarisiz = <String>[];
    for (final id in _secili) {
      try {
        await api.post(
          '/chats/$id/messages',
          data: {'type': 'text', 'content': widget.baglanti},
        );
      } catch (_) {
        final c = hepsi.where((e) => e.id == id).firstOrNull;
        basarisiz.add((c?.title.isNotEmpty ?? false) ? c!.title : 'Sohbet');
      }
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    final mesajci = ScaffoldMessenger.of(context);
    nav.pop();
    mesajci.showSnackBar(
      SnackBar(
        content: Text(
          basarisiz.isEmpty
              ? 'Gönderildi'
              : 'Gönderilemedi: ${basarisiz.join(", ")}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durum = ref.watch(chatsProvider);
    return SafeArea(
      child: SizedBox(
        // ⚠️ Yukseklik EKRANIN YARISI: sabit piksel verirsek kucuk telefonlarda
        //    (SE) liste bir satira duser, buyuk telefonlarda bosluk kalir.
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Paylaş',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: durum.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(
                  child: Text(
                    'Sohbetler yüklenemedi',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                data: (hepsi) {
                  final liste = _liste(hepsi);
                  if (liste.isEmpty) {
                    return const Center(
                      child: Text(
                        'Henüz sohbetin yok',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (_, i) {
                      final c = liste[i];
                      final secili = _secili.contains(c.id);
                      return ListTile(
                        leading: Avatar(
                          ad: c.title,
                          mediaId: c.avatarMediaId,
                          avatarUrl: c.avatarUrl,
                          cap: 42,
                        ),
                        title: Text(c.title.isEmpty ? 'Sohbet' : c.title),
                        trailing: Icon(
                          secili ? LucideIcons.circleCheck : LucideIcons.circle,
                          color: secili
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        onTap: _gonderiliyor
                            ? null
                            : () => setState(() {
                                secili
                                    ? _secili.remove(c.id)
                                    : _secili.add(c.id);
                              }),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: widget.baglanti),
                      );
                      if (!context.mounted) return;
                      final nav = Navigator.of(context);
                      final m = ScaffoldMessenger.of(context);
                      nav.pop();
                      m.showSnackBar(
                        const SnackBar(content: Text('Bağlantı kopyalandı')),
                      );
                    },
                    icon: const Icon(LucideIcons.link, size: 17),
                    label: const Text('Kopyala'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_secili.isEmpty || _gonderiliyor)
                          ? null
                          : _gonder,
                      child: Text(
                        _gonderiliyor
                            ? 'Gönderiliyor...'
                            : _secili.isEmpty
                            ? 'Gönder'
                            : 'Gönder (${_secili.length})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⚠️⚠️⚠️ TURU 90b — IS ILANI BASVURUSU (ISTEMCI TARAFI).
///
/// ═══════════ NEDEN AYRI BIR TURDA YAZILDI ═══════════
///
/// Turu 90 sunucu tarafini eksiksiz yazdi: `ilan_basvurular` tablosu, BES
/// uc, yetki kapilari, bildirim. Ama ISTEMCIDE **TEK SATIR YOKTU** —
/// `grep -rn "basvur" mobile/lib/` SIFIR donuyordu. Yayin oncesi denetimde
/// UC BAGIMSIZ AJAN ayni sonuca vardi: kullanicinin bu turdaki acik emri
/// (*"herkes is ilani verebilmeli, NORMAL KULLANICILAR BASVURU
/// YAPABILMELI"*) sahada **%100 OLU DOGACAKTI**.
///
/// ⚠️ DERS (bu projede DOKUZUNCU tekrar): bir uc/sutun/servis ekledigin AN
///    onu KULLANAN yolu da yaz. "Sunucu hazir" YARIM istir ve kullanici
///    icin SIFIR degerdir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import '../sosyal/profil_sayfasi.dart';
import 'ilan_servisi.dart';

/// Basvuru durumunun rengi — UC EKRANDA da ayni.
Color basvuruRengi(String durum) => switch (durum) {
  'olumlu' => const Color(0xFF2ECC71),
  'olumsuz' => const Color(0xFFE74C3C),
  'goruldu' => const Color(0xFF3AA9FF),
  'geri_cekildi' => Colors.grey,
  _ => const Color(0xFFF39C12),
};

Widget _rozet(String durum, String etiket) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: basvuruRengi(durum).withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(etiket,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: basvuruRengi(durum))),
);

// ═══════════════════════ 1) BASVUR (alttan sheet) ═══════════════════════

/// Basvuru sheet'ini acar; basvuru GONDERILDIYSE `true` doner.
///
/// ⚠️ `isScrollControlled` + `viewInsets` ZORUNLU: icinde `TextField` var ve
///    klavye acilinca sheet'in altini yerdi.
Future<bool> basvurSheet(BuildContext context, WidgetRef ref, String ilanID,
    String baslik) async {
  final not = TextEditingController();
  var gonderiliyor = false;
  // ⚠️ TURU 90c — KENDI ROUTE'UM. `Navigator.pop()` EN USTTEKI route'u
  //    kapatir, "beni" DEGIL: istek ucustayken kullanici baska bir sey
  //    acarsa (or. klavye ustu bir menu) `pop(true)` YANLIS ROUTE'U
  //    kapatirdi. Turu 59b'de aynen yasandi ve oradaki cozum route'u
  //    ADRESLEMEKTI.
  ModalRoute<Object?>? rota;
  // ⚠️ SONUC POP DEGERINDEN DEGIL, BURADAN okunur: route'u `removeRoute` ile
  //    kaldirmak zorunda kalirsak pop degeri `null` doner ve cagiran taraf
  //    basariyi KACIRIRDI ("Başvurun gönderildi" bildirimi cikmaz, dugme
  //    guncellenmezdi).
  var basarili = false;

  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, yenile) {
        rota ??= ModalRoute.of(c);
        return Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        // ⚠️ TURU 90c — KAYDIRMA SARMALI: buyuk yazi olceginde klavye
        //    acikken `Column` (baslik + aciklama + 4 satirlik TextField +
        //    sayac + dugme) kalan yeri asiyordu -> RenderFlex tasmasi.
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(baslik,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('İlan sahibi adını, kullanıcı adını ve notunu görür.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 14),
            TextField(
              controller: not,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Kısa not (isteğe bağlı)',
                hintText: 'Deneyimin, ne zaman başlayabileceğin...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: gonderiliyor
                  ? null
                  : () async {
                      // ⚠️ CIFT DOKUNMA KAPISI: sunucu idempotent olsa da
                      //    iki istek iki bildirim dogurabilir.
                      yenile(() => gonderiliyor = true);
                      final nav = Navigator.of(c);
                      final mesajci = ScaffoldMessenger.of(c);
                      try {
                        await ref
                            .read(ilanServisiProvider)
                            .basvur(ilanID, not.text.trim());
                        basarili = true;
                        // ⚠️ KENDI route'umu ADRESLE (bkz. `rota` serhi).
                        //    En ustteysem normal pop; degilsem (istek
                        //    ucustayken uste bir sey acilmis) KENDI route'umu
                        //    kaldiririm — BASKASINI kapatmam.
                        final r = rota;
                        if (r == null || r.isCurrent) {
                          nav.pop(true);
                        } else if (r.isActive) {
                          nav.removeRoute(r);
                        }
                      } catch (e) {
                        yenile(() => gonderiliyor = false);
                        mesajci.showSnackBar(
                            const SnackBar(content: Text('Başvuru gönderilemedi')));
                      }
                    },
              child: gonderiliyor
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Başvuruyu gönder'),
            ),
          ],
        ),
        ),
        );
      },
    ),
  );
  not.dispose();
  return basarili;
}

// ═══════════════════ 2) BASVURANLAR (ilan sahibi) ═══════════════════

class BasvuranlarEkrani extends ConsumerStatefulWidget {
  const BasvuranlarEkrani({super.key, required this.ilanID, this.baslik = ''});
  final String ilanID;
  final String baslik;

  @override
  ConsumerState<BasvuranlarEkrani> createState() => _BasvuranlarState();
}

class _BasvuranlarState extends ConsumerState<BasvuranlarEkrani> {
  List<Basvuru>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(ilanServisiProvider).basvurular(widget.ilanID);
      if (!mounted) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Başvurular alınamadı');
    }
  }

  Future<void> _durum(Basvuru b, String yeni) async {
    final mesajci = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(ilanServisiProvider)
          .basvuruDurum(widget.ilanID, b.id, yeni);
      await _yukle();
    } catch (e) {
      mesajci.showSnackBar(
          const SnackBar(content: Text('Güncellenemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Başvuranlar'),
        bottom: widget.baslik.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(widget.baslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: _hata != null
            ? _bosDurum(LucideIcons.circleAlert, _hata!, 'Tekrar dene', _yukle)
            : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                    ? _bosDurum(LucideIcons.inbox, 'Henüz başvuru yok',
                        'Yenile', _yukle)
                    : ListView.separated(
                        // ⚠️ Bos/hata dallarinda da kaydirma SART, yoksa
                        //    asagi-cek-yenile CALISMAZ (turu 83b dersi).
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: l.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (c, i) => _satir(l[i]),
                      ),
      ),
    );
  }

  Widget _satir(Basvuru b) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfilSayfasi(userId: b.userID))),
                  child: Avatar(ad: b.ad, mediaId: b.avatarID, cap: 42),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.ad.isEmpty ? '@${b.kullaniciAdi}' : b.ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (b.kullaniciAdi.isNotEmpty)
                        Text('@${b.kullaniciAdi}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _rozet(b.durum, b.durumEtiketi),
              ],
            ),
            if (b.not.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(b.not, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _durum(b, 'olumlu'),
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('Olumlu'),
                ),
                TextButton.icon(
                  onPressed: () => _durum(b, 'olumsuz'),
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: const Text('Olumsuz'),
                ),
              ],
            ),
          ],
        ),
      );
}

// ═══════════════════ 3) BASVURULARIM (kullanici) ═══════════════════

class BasvurularimEkrani extends ConsumerStatefulWidget {
  const BasvurularimEkrani({super.key});

  @override
  ConsumerState<BasvurularimEkrani> createState() => _BasvurularimState();
}

class _BasvurularimState extends ConsumerState<BasvurularimEkrani> {
  List<Basvuru>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(ilanServisiProvider).basvurularim();
      if (!mounted) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Başvurular alınamadı');
    }
  }

  Future<void> _geriCek(Basvuru b) async {
    final mesajci = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Başvuruyu geri çek'),
        content: Text('"${b.baslik}" ilanına yaptığın başvuru geri çekilecek. '
            'İstersen daha sonra yeniden başvurabilirsin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Geri çek')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref.read(ilanServisiProvider).basvuruGeriCek(b.ilanID);
      await _yukle();
    } catch (e) {
      mesajci.showSnackBar(const SnackBar(content: Text('Geri çekilemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(title: const Text('Başvurularım')),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: _hata != null
            ? _bosDurum(LucideIcons.circleAlert, _hata!, 'Tekrar dene', _yukle)
            : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                    ? _bosDurum(LucideIcons.briefcase,
                        'Henüz bir işe başvurmadın', 'Yenile', _yukle)
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: l.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (c, i) {
                          final b = l[i];
                          return ListTile(
                            title: Text(
                                b.baslik.isEmpty ? 'İlan' : b.baslik,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _rozet(b.durum, b.durumEtiketi),
                              ),
                            ),
                            // ⚠️ GERI CEKME YOLU ZORUNLU: sunucuda uc VAR ve
                            //    onu cagiran ekran olmasaydi bu, kapatmaya
                            //    calistigimiz "olu ozellik" sinifinin
                            //    KENDI ICINDE tekrari olurdu.
                            trailing: b.durum == 'geri_cekildi'
                                ? null
                                : IconButton(
                                    tooltip: 'Geri çek',
                                    icon: const Icon(LucideIcons.trash2,
                                        size: 18),
                                    onPressed: () => _geriCek(b),
                                  ),
                          );
                        },
                      ),
      ),
    );
  }
}

/// Bos/hata durumu — UC EKRANDA ortak.
///
/// ⚠️ `AlwaysScrollableScrollPhysics` + `ListView`: bos ekranda da
///    asagi-cek-yenile calissin (turu 83b'de BES ekranda atlanmisti).
Widget _bosDurum(
        IconData ikon, String metin, String dugme, VoidCallback basinca) =>
    ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(ikon, size: 44, color: Colors.grey),
        const SizedBox(height: 12),
        Center(child: Text(metin, style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 12),
        Center(child: TextButton(onPressed: basinca, child: Text(dugme))),
      ],
    );

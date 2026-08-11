/// ⚠️⚠️ TURU 91 — DIYETISYEN GORUNUMU (danisanlar + liste yazma).
///
/// ⚠️ ULASILAN YOL: **Profil > "Danışanlarım"** (yalniz `hesap_turu=='isletme'`
///    ve `kategori=='diyetisyen'` iken cizilir) + `diyet_istek` bildirimi.
///    Bu satiri yazmak ZORUNLU: bu projede ekran yazilip ona GIDEN yol
///    yazilmamasi DOKUZ kez ozelligi oldurdu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import 'diyet_servisi.dart';

String _bugun() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String _gunAdi(String tarih) {
  final p = tarih.split('-');
  if (p.length != 3) return tarih;
  const aylar = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  final ay = int.tryParse(p[1]) ?? 1;
  return '${int.tryParse(p[2]) ?? 1} ${aylar[(ay - 1).clamp(0, 11)]}';
}

class DanisanlarimEkrani extends ConsumerStatefulWidget {
  const DanisanlarimEkrani({super.key});

  @override
  ConsumerState<DanisanlarimEkrani> createState() => _DanisanlarimState();
}

class _DanisanlarimState extends ConsumerState<DanisanlarimEkrani> {
  List<DiyetBag>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(diyetServisiProvider).danisanlarim();
      if (!mounted) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Yüklenemedi');
    }
  }

  Future<void> _durum(DiyetBag b, String yeni) async {
    final mesajci = ScaffoldMessenger.of(context);
    try {
      await ref.read(diyetServisiProvider).bagDurum(b.id, yeni);
      await _yukle();
    } catch (e) {
      mesajci.showSnackBar(const SnackBar(content: Text('Güncellenemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    // ⚠️ "Onayla" dugmesinin kapisi icin KENDI id'm gerekiyor: sunucudaki
    //    riza kurali `baslatan_id <> me`. Kapi olmadan kullanici kendi
    //    istegini onaylamaya calisir ve 404 yerdi.
    final benimID =
        (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Danışanlarım')),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: _hata != null
            ? _bos(LucideIcons.circleAlert, _hata!, 'Tekrar dene', _yukle)
            : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                    ? _bos(
                        LucideIcons.users,
                        'Henüz danışanın yok.\nDanışanlar sana bağlantı '
                        'isteği gönderdiğinde burada görünecek.',
                        'Yenile',
                        _yukle)
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: l.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _satir(l[i], benimID),
                      ),
      ),
    );
  }

  Widget _satir(DiyetBag b, String benimID) => ListTile(
        leading: Avatar(ad: b.ad, mediaId: b.avatarID, cap: 42),
        title: Text(b.ad.isEmpty ? '@${b.kullaniciAdi}' : b.ad),
        subtitle: Text(b.durumEtiketi),
        trailing: b.durum == 'bekliyor' && b.baslatanID != benimID
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Onayla',
                    icon: const Icon(LucideIcons.check, color: Colors.green),
                    onPressed: () => _durum(b, 'aktif'),
                  ),
                  IconButton(
                    tooltip: 'Reddet',
                    icon: const Icon(LucideIcons.x, color: Colors.red),
                    onPressed: () => _durum(b, 'reddedildi'),
                  ),
                ],
              )
            : b.durum == 'aktif'
                ? IconButton(
                    tooltip: 'Liste gönder',
                    icon: const Icon(LucideIcons.clipboardPlus),
                    onPressed: () async {
                      final ok = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => DiyetListeYazEkrani(danisan: b),
                        ),
                      );
                      if (ok == true && mounted) await _yukle();
                    },
                  )
                : null,
        onTap: b.durum == 'aktif'
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => DanisanDetayEkrani(danisan: b)),
                )
            : null,
      );

  Widget _bos(IconData ikon, String metin, String dugme, VoidCallback bas) =>
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 110),
          Icon(ikon, size: 44, color: Colors.grey),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(metin,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ),
          Center(child: TextButton(onPressed: bas, child: Text(dugme))),
        ],
      );
}

/// Diyetisyenin danisana LISTE yazdigi ekran.
class DiyetListeYazEkrani extends ConsumerStatefulWidget {
  const DiyetListeYazEkrani({super.key, required this.danisan});
  final DiyetBag danisan;

  @override
  ConsumerState<DiyetListeYazEkrani> createState() => _ListeYazState();
}

class _ListeYazState extends ConsumerState<DiyetListeYazEkrani> {
  final _baslik = TextEditingController(text: 'Diyet listesi');
  final _metin = TextEditingController();
  bool _mesgul = false;

  @override
  void dispose() {
    _baslik.dispose();
    _metin.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (_mesgul) return;
    if (_metin.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Liste boş olamaz')));
      return;
    }
    setState(() => _mesgul = true);
    final nav = Navigator.of(context);
    final mesajci = ScaffoldMessenger.of(context);
    try {
      // ⚠️ Servis await'ten ONCE yakalanir (turu 78b dersi).
      await ref.read(diyetServisiProvider).kayitEkle(
            tur: 'liste',
            tarih: _bugun(),
            ad: _baslik.text.trim(),
            userID: widget.danisan.userID,
            veri: {'metin': _metin.text.trim()},
          );
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      mesajci.showSnackBar(const SnackBar(content: Text('Gönderilemedi')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.danisan.ad)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _baslik,
              decoration: const InputDecoration(
                  labelText: 'Başlık', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _metin,
              maxLines: 14,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Liste',
                hintText: 'Pazartesi\nKahvaltı: ...\nÖğle: ...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _mesgul ? null : _gonder,
              child: const Text('Danışana gönder'),
            ),
          ],
        ),
      );
}

/// Diyetisyenin bir danisanin ozetini gordugu ekran.
///
/// ⚠️ Veriyi SUNUCU filtreler (`diyetErisim`): bag `aktif` degilse 404 doner.
///    Istemcide EK kapi YOK — iki kapi KACINILMAZ olarak drift eder ve
///    istemci kapisi zaten atlanabilir.
class DanisanDetayEkrani extends ConsumerStatefulWidget {
  const DanisanDetayEkrani({super.key, required this.danisan});
  final DiyetBag danisan;

  @override
  ConsumerState<DanisanDetayEkrani> createState() => _DanisanDetayState();
}

class _DanisanDetayState extends ConsumerState<DanisanDetayEkrani> {
  DiyetOzet? _ozet;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final o = await ref
          .read(diyetServisiProvider)
          .ozet(userID: widget.danisan.userID);
      if (!mounted) return;
      setState(() {
        _ozet = o;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Veriye erişilemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _ozet;
    return Scaffold(
      appBar: AppBar(title: Text(widget.danisan.ad)),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_hata != null)
              Center(child: Text(_hata!))
            else if (o == null)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()))
            else ...[
              const Text('Son 30 gün',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (o.gunler.isEmpty)
                const Text('Henüz öğün kaydı yok',
                    style: TextStyle(color: Colors.grey))
              else
                for (final g in o.gunler.reversed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_gunAdi(g.tarih)),
                    trailing: Text('${g.kalori} kcal'),
                  ),
              if (o.sonOlcum.isNotEmpty) ...[
                const Divider(height: 28),
                const Text('Son ölçüm',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  ((o.sonOlcum['veri'] as Map?) ?? {})
                      .entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join(' · '),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_screen.dart' show myProfileProvider;
import 'isletme_servisi.dart';

/// ⚠️⚠️ TURU 77 — ISLETME PROFILINE GEC / BILGILERI DUZENLE.
///
/// Kullanici emri: "normal ve isletme profilleri olacak".
///
/// ⚠️ TEK EKRAN hem "gecis" hem "duzenleme" yapar. Ayri bir "isletmeye gec"
///    dugmesi olsaydi kullanici gecip alanlari bos birakabilir ve profili BOS
///    bir isletme olarak gorunurdu.
/// ⚠️ GIRIS NOKTASI: Profil sekmesi -> "İşletme hesabı". Bu projede "kod var
///    ama hicbir dugmeye bagli degil" hatasi BES kez yasandi; giris noktasi
///    ozellikle eklendi.
class IsletmeDuzenleEkrani extends ConsumerStatefulWidget {
  const IsletmeDuzenleEkrani({super.key});

  @override
  ConsumerState<IsletmeDuzenleEkrani> createState() =>
      _IsletmeDuzenleEkraniState();
}

class _IsletmeDuzenleEkraniState extends ConsumerState<IsletmeDuzenleEkrani> {
  final _adres = TextEditingController();
  final _il = TextEditingController();
  final _ilce = TextEditingController();
  final _telefon = TextEditingController();
  final _web = TextEditingController();

  String _kategori = 'yemek';
  List<CalismaGunu> _calisma = [
    for (var g = 1; g <= 7; g++) CalismaGunu(gun: g),
  ];
  bool _yukleniyor = true;
  bool _kaydediliyor = false;
  bool _zatenIsletme = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _adres.dispose();
    _il.dispose();
    _ilce.dispose();
    _telefon.dispose();
    _web.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final id = (ref.read(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    if (id.isEmpty) {
      setState(() => _yukleniyor = false);
      return;
    }
    final i = await ref.read(isletmeServisiProvider).detay(id);
    if (!mounted) return;
    setState(() {
      _yukleniyor = false;
      if (i != null) {
        _zatenIsletme = true;
        _kategori = i.kategori;
        _adres.text = i.adres;
        _il.text = i.il;
        _ilce.text = i.ilce;
        _telefon.text = i.telefon;
        _web.text = i.web;
        // ⚠️ Sunucudan eksik gun gelebilir — 7 gunu TAMAMLA, yoksa listede
        //    bosluk olur ve kullanici o gunu hic ayarlayamaz.
        if (i.calisma.isNotEmpty) {
          _calisma = [
            for (var g = 1; g <= 7; g++)
              i.calisma.where((c) => c.gun == g).firstOrNull ??
                  CalismaGunu(gun: g),
          ];
        }
      }
    });
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    try {
      await ref
          .read(isletmeServisiProvider)
          .kaydet(
            Isletme(
              kategori: _kategori,
              adres: _adres.text.trim(),
              il: _il.text.trim(),
              ilce: _ilce.text.trim(),
              telefon: _telefon.text.trim(),
              web: _web.text.trim(),
              calisma: _calisma,
            ),
          );
      if (!mounted) return;
      // ⚠️ Profil onbellegi TAZELENIR: `hesap_turu` degisti, profil ekrani
      //    isletme duzenini cizmeli. Tazelenmeseydi kullanici degisikligi
      //    ancak uygulamayi yeniden acinca gorurdu.
      ref.invalidate(myProfileProvider);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşletme profilin kaydedildi')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _kaydediliyor = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kaydedilemedi')));
    }
  }

  Future<void> _kisiselYap() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kişisel hesaba dön'),
        content: const Text(
          'İşletme bilgilerin silinmez, saklanır. İstediğin zaman tekrar '
          'işletme hesabına geçebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Geç'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await ref.read(isletmeServisiProvider).kisiselYap();
      if (!mounted) return;
      ref.invalidate(myProfileProvider);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem yapılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_zatenIsletme ? 'İşletme bilgileri' : 'İşletme hesabı'),
        actions: [
          TextButton(
            onPressed: _kaydediliyor ? null : _kaydet,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_zatenIsletme)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'İşletme hesabına geçtiğinde profilinde kategori, adres, telefon '
                've çalışma saatlerin görünür; müşterilerin sana kolayca ulaşır.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: _kategori,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final e in isletmeKategorileri.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _kategori = v ?? 'diger'),
          ),
          const SizedBox(height: 12),
          _alan(_adres, 'Adres', LucideIcons.mapPin, satir: 2),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _alan(_il, 'İl', LucideIcons.building2)),
              const SizedBox(width: 10),
              Expanded(child: _alan(_ilce, 'İlçe', LucideIcons.map)),
            ],
          ),
          const SizedBox(height: 12),
          _alan(
            _telefon,
            'Telefon',
            LucideIcons.phone,
            tip: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _alan(_web, 'Web sitesi', LucideIcons.globe, tip: TextInputType.url),
          const SizedBox(height: 20),
          const Text(
            'ÇALIŞMA SAATLERİ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          for (final c in _calisma) _gunSatiri(c),
          const SizedBox(height: 24),
          if (_zatenIsletme)
            OutlinedButton.icon(
              onPressed: _kisiselYap,
              icon: const Icon(LucideIcons.userRound, size: 18),
              label: const Text('Kişisel hesaba dön'),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _alan(
    TextEditingController c,
    String etiket,
    IconData ikon, {
    int satir = 1,
    TextInputType? tip,
  }) => TextField(
    controller: c,
    keyboardType: tip,
    minLines: satir,
    maxLines: satir,
    decoration: InputDecoration(
      labelText: etiket,
      prefixIcon: Icon(ikon, size: 19),
      border: const OutlineInputBorder(),
    ),
  );

  Widget _gunSatiri(CalismaGunu c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            gunAdlari[c.gun] ?? '',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (c.kapali)
          const Expanded(
            child: Text('Kapalı', style: TextStyle(color: Colors.grey)),
          )
        else ...[
          _saat(c.acilis, (v) => setState(() => c.acilis = v)),
          const Text('  –  '),
          _saat(c.kapanis, (v) => setState(() => c.kapanis = v)),
          const Spacer(),
        ],
        Switch(
          value: !c.kapali,
          onChanged: (v) => setState(() => c.kapali = !v),
        ),
      ],
    ),
  );

  /// ⚠️ `showTimePicker` KULLANILDI (elle metin girisi DEGIL): "9:5" gibi bozuk
  ///    degerler sunucuya gitmesin ve saat hesabi (`simdiAcik`) patlamasin.
  Widget _saat(String deger, void Function(String) onSec) => OutlinedButton(
    onPressed: () async {
      final p = deger.split(':');
      final ilk = TimeOfDay(
        hour: int.tryParse(p.isNotEmpty ? p[0] : '9') ?? 9,
        minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
      );
      final s = await showTimePicker(context: context, initialTime: ilk);
      if (s == null) return;
      onSec(
        '${s.hour.toString().padLeft(2, '0')}:'
        '${s.minute.toString().padLeft(2, '0')}',
      );
    },
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 34),
    ),
    child: Text(deger, style: const TextStyle(fontSize: 13)),
  );
}

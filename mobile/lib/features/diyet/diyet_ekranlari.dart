/// ⚠️⚠️ TURU 91 — DIYETIM (danisan gorunumu).
///
/// Kullanici emri: *"profilde DIYETIM olsun... diyetimde KALORI, YIYECEK ADI,
/// KALORI SAYIMI, OLCUM vb. seyler olacak; DIYET LISTESI — hangi diyetisyenle
/// calisiyorsan diyet listesi olacak, buradan takip edebilsin"*.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

const _ogunler = ['kahvalti', 'ara1', 'ogle', 'ara2', 'aksam'];
const _ogunAdlari = {
  'kahvalti': 'Kahvaltı',
  'ara1': 'Ara öğün',
  'ogle': 'Öğle',
  'ara2': 'İkindi',
  'aksam': 'Akşam',
};

class DiyetimEkrani extends ConsumerStatefulWidget {
  const DiyetimEkrani({super.key});

  @override
  ConsumerState<DiyetimEkrani> createState() => _DiyetimState();
}

class _DiyetimState extends ConsumerState<DiyetimEkrani> {
  String _tarih = _bugun();
  List<DiyetKayit>? _kayitlar;
  List<DiyetBag> _baglar = [];
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final svc = ref.read(diyetServisiProvider);
      // ⚠️ IKI ISTEK PARALEL: seri atmak acilisi iki katina cikarirdi.
      final sonuc = await Future.wait([
        svc.kayitlar(bas: _tarih, bit: _tarih),
        svc.baglarim(),
      ]);
      if (!mounted) return;
      setState(() {
        _kayitlar = sonuc[0] as List<DiyetKayit>;
        _baglar = sonuc[1] as List<DiyetBag>;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Yüklenemedi');
    }
  }

  int get _toplamKalori =>
      (_kayitlar ?? []).where((k) => k.tur == 'ogun').fold(0, (a, k) => a + k.kalori);

  DiyetBag? get _diyetisyenim {
    for (final b in _baglar) {
      if (b.durum == 'aktif') return b;
    }
    return null;
  }

  Future<void> _gunDegistir(int fark) async {
    final p = _tarih.split('-').map(int.parse).toList();
    final d = DateTime(p[0], p[1], p[2]).add(Duration(days: fark));
    // ⚠️ GELECEGE GIDILMEZ: ileri bir gune ogun girmek anlamsiz ve gunluk
    //    ozeti bozar.
    if (d.isAfter(DateTime.now())) return;
    setState(() {
      _tarih = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      _kayitlar = null;
    });
    await _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final k = _kayitlar;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diyetim'),
        actions: [
          IconButton(
            tooltip: 'Ölçüm ekle',
            icon: const Icon(LucideIcons.ruler),
            onPressed: () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                    builder: (_) => OlcumEkleSayfasi(tarih: _tarih)),
              );
              if (ok == true) await _yukle();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _gunSeridi(),
            const SizedBox(height: 16),
            _kaloriKarti(),
            const SizedBox(height: 20),
            if (_hata != null)
              Center(
                child: Column(
                  children: [
                    Text(_hata!),
                    TextButton(
                        onPressed: _yukle, child: const Text('Tekrar dene')),
                  ],
                ),
              )
            else if (k == null)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator()))
            else ...[
              for (final o in _ogunler) _ogunBolumu(o, k),
              const SizedBox(height: 18),
              _diyetisyenKarti(k),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gunSeridi() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => _gunDegistir(-1),
          ),
          Text(
            _tarih == _bugun() ? 'Bugün' : _gunAdi(_tarih),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight),
            // ⚠️ Bugundeysek ileri dugmesi PASIF (gelecege kayit yok).
            onPressed: _tarih == _bugun() ? null : () => _gunDegistir(1),
          ),
        ],
      );

  Widget _kaloriKarti() => Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2BB673), Color(0xFF0E7A52)],
          ),
        ),
        child: Column(
          children: [
            Text(
              '$_toplamKalori',
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
            const Text(
              'kcal alındı',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      );

  Widget _ogunBolumu(String ogun, List<DiyetKayit> hepsi) {
    final liste =
        hepsi.where((k) => k.tur == 'ogun' && k.ogun == ogun).toList();
    final toplam = liste.fold(0, (a, k) => a + k.kalori);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _ogunAdlari[ogun] ?? ogun,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            if (toplam > 0)
              Text('$toplam kcal',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            IconButton(
              icon: const Icon(LucideIcons.plus, size: 18),
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        OgunEkleSayfasi(tarih: _tarih, ogun: ogun),
                  ),
                );
                if (ok == true) await _yukle();
              },
            ),
          ],
        ),
        for (final k in liste)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(k.ad),
            subtitle: Text('${k.veri['gram'] ?? ''} g'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${k.kalori}'),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: () async {
                    final mesajci = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(diyetServisiProvider).kayitKaldir(k.id);
                      await _yukle();
                    } catch (e) {
                      mesajci.showSnackBar(
                          const SnackBar(content: Text('Kaldırılamadı')));
                    }
                  },
                ),
              ],
            ),
          ),
        const Divider(height: 22),
      ],
    );
  }

  Widget _diyetisyenKarti(List<DiyetKayit> kayitlar) {
    final d = _diyetisyenim;
    final listeler = kayitlar.where((k) => k.tur == 'liste').toList();
    if (d == null) {
      return Card(
        child: ListTile(
          leading: const Icon(LucideIcons.userRoundSearch),
          title: const Text('Diyetisyenin yok'),
          subtitle: const Text(
              'Yakınımda\'dan bir diyetisyen bul ve bağlantı isteği gönder'),
          // ⚠️ Bekleyen istek varsa DURUMU SOYLE: aksi halde kullanici
          //    istegini gonderdigini unutup tekrar tekrar arar.
          trailing: _baglar.any((b) => b.durum == 'bekliyor')
              ? const Chip(label: Text('İstek gönderildi'))
              : null,
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Avatar(ad: d.ad, mediaId: d.avatarID, cap: 40),
            title: Text(d.ad.isEmpty ? '@${d.kullaniciAdi}' : d.ad),
            subtitle: const Text('Diyetisyenin'),
          ),
          if (listeler.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Bu gün için gönderilmiş liste yok',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            )
          else
            for (final l in listeler)
              ListTile(
                dense: true,
                leading: const Icon(LucideIcons.clipboardList, size: 18),
                title: Text(l.ad.isEmpty ? 'Diyet listesi' : l.ad),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(l.ad.isEmpty ? 'Diyet listesi' : l.ad),
                    content: SingleChildScrollView(
                      child: Text((l.veri['metin'] ?? '').toString()),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Kapat')),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ═══════════════════ OGUN EKLE ═══════════════════

class OgunEkleSayfasi extends ConsumerStatefulWidget {
  const OgunEkleSayfasi({super.key, required this.tarih, required this.ogun});
  final String tarih;
  final String ogun;

  @override
  ConsumerState<OgunEkleSayfasi> createState() => _OgunEkleState();
}

class _OgunEkleState extends ConsumerState<OgunEkleSayfasi> {
  final _ara = TextEditingController();
  List<Besin> _sonuc = [];
  Besin? _secili;
  int _gram = 100;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    _araBesin('');
  }

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  Future<void> _araBesin(String q) async {
    try {
      final l = await ref.read(diyetServisiProvider).besinler(q);
      if (!mounted) return;
      setState(() => _sonuc = l);
    } catch (_) {}
  }

  Future<void> _kaydet() async {
    final b = _secili;
    if (b == null || _mesgul) return;
    setState(() => _mesgul = true);
    final nav = Navigator.of(context);
    final mesajci = ScaffoldMessenger.of(context);
    try {
      await ref.read(diyetServisiProvider).kayitEkle(
            tur: 'ogun',
            tarih: widget.tarih,
            ad: b.ad,
            kalori: ogunKalorisi(b, _gram),
            veri: {'ogun': widget.ogun, 'gram': _gram},
          );
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      mesajci.showSnackBar(const SnackBar(content: Text('Kaydedilemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _secili;
    return Scaffold(
      appBar: AppBar(title: Text(_ogunAdlari[widget.ogun] ?? 'Öğün ekle')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ara,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.search),
                hintText: 'Yiyecek ara (elma, pilav...)',
                border: OutlineInputBorder(),
              ),
              onChanged: _araBesin,
            ),
          ),
          if (b != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.ad,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _gram.toDouble().clamp(10, 600),
                          min: 10,
                          max: 600,
                          divisions: 59,
                          label: '$_gram g',
                          onChanged: (v) =>
                              setState(() => _gram = v.round()),
                        ),
                      ),
                      SizedBox(
                        width: 84,
                        child: Text(
                          '${ogunKalorisi(b, _gram)} kcal',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _mesgul ? null : _kaydet,
                      child: Text('$_gram g ekle'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: _sonuc.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final x = _sonuc[i];
                return ListTile(
                  dense: true,
                  title: Text(x.ad),
                  subtitle: Text('${x.kalori} kcal / 100 g'),
                  selected: _secili?.ad == x.ad,
                  onTap: () => setState(() {
                    _secili = x;
                    _gram = x.gram;
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════ OLCUM EKLE ═══════════════════

class OlcumEkleSayfasi extends ConsumerStatefulWidget {
  const OlcumEkleSayfasi({super.key, required this.tarih});
  final String tarih;

  @override
  ConsumerState<OlcumEkleSayfasi> createState() => _OlcumEkleState();
}

class _OlcumEkleState extends ConsumerState<OlcumEkleSayfasi> {
  final _kilo = TextEditingController();
  final _bel = TextEditingController();
  final _boy = TextEditingController();
  bool _mesgul = false;

  @override
  void dispose() {
    _kilo.dispose();
    _bel.dispose();
    _boy.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_mesgul) return;
    final veri = <String, dynamic>{};
    for (final e in [
      ('kilo', _kilo.text),
      ('bel', _bel.text),
      ('boy', _boy.text),
    ]) {
      final v = double.tryParse(e.$2.trim().replaceAll(',', '.'));
      if (v != null && v > 0) veri[e.$1] = v;
    }
    if (veri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En az bir ölçüm gir')));
      return;
    }
    setState(() => _mesgul = true);
    final nav = Navigator.of(context);
    final mesajci = ScaffoldMessenger.of(context);
    try {
      await ref.read(diyetServisiProvider).kayitEkle(
            tur: 'olcum', tarih: widget.tarih, ad: 'Ölçüm', veri: veri);
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      mesajci.showSnackBar(const SnackBar(content: Text('Kaydedilemedi')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ölçüm ekle')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final e in [
              ('Kilo (kg)', _kilo),
              ('Bel (cm)', _bel),
              ('Boy (cm)', _boy),
            ]) ...[
              TextField(
                controller: e.$2,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: e.$1, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _mesgul ? null : _kaydet,
              child: const Text('Kaydet'),
            ),
          ],
        ),
      );
}

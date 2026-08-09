import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'urun_servisi.dart';

/// ⚠️⚠️ TURU 77 — ISLETME KATALOGU / MENUSU.
///
/// Kullanici emri: "isletmeler urunlerini yukleyebilecek ya da ChatGPT
/// yardimiyla AI gorsel, AI menu, AI ile tek tek fotograftan problemleri ...".
///
/// ⚠️ AI DUGMELERI YALNIZ SUNUCUDA ACIKSA CIZILIR (`aiDurumProvider`).
///    Kapaliyken cizilseydi kullanici basar ve 503 alirdi.
class UrunKatalogEkrani extends ConsumerStatefulWidget {
  const UrunKatalogEkrani({
    super.key,
    required this.isletmeId,
    required this.isletmeAd,
    this.benimMi = false,
  });

  final String isletmeId;
  final String isletmeAd;
  final bool benimMi;

  @override
  ConsumerState<UrunKatalogEkrani> createState() => _UrunKatalogEkraniState();
}

class _UrunKatalogEkraniState extends ConsumerState<UrunKatalogEkrani> {
  List<Urun>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(urunServisiProvider).liste(widget.isletmeId);
      if (mounted) {
        setState(() {
          _liste = l;
          _hata = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hata = 'Ürünler alınamadı');
    }
  }

  /// Bolume gore grupla (menu gorunumu).
  Map<String, List<Urun>> get _bolumler {
    final m = <String, List<Urun>>{};
    for (final u in _liste ?? const <Urun>[]) {
      m.putIfAbsent(u.bolum.isEmpty ? 'Diğer' : u.bolum, () => []).add(u);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    final l = _liste;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isletmeAd.isEmpty ? 'Ürünler' : widget.isletmeAd),
        actions: [
          // ⚠️ AI MENU dugmesi: YALNIZ sahibine ve YALNIZ AI aciksa.
          if (widget.benimMi && (ai?.acik ?? false))
            IconButton(
              tooltip: 'Menüyü fotoğraftan oku',
              icon: const Icon(LucideIcons.sparkles),
              onPressed: _aiMenu,
            ),
        ],
      ),
      floatingActionButton: widget.benimMi
          ? FloatingActionButton.extended(
              heroTag: 'fabUrunEkle',
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const UrunDuzenleEkrani()),
                );
                if (ok == true) _yukle();
              },
              icon: const Icon(LucideIcons.plus),
              label: const Text('Ürün ekle'),
            )
          : null,
      body: _hata != null
          ? Center(
              child: Text(_hata!, style: const TextStyle(color: Colors.grey)),
            )
          : l == null
          ? const Center(child: CircularProgressIndicator())
          : l.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                  widget.benimMi
                      ? 'Henüz ürün eklemedin.\nSağ alttan ilk ürününü ekle.'
                      : 'Bu işletme henüz ürün eklememiş.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  for (final b in _bolumler.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        b.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    for (final u in b.value) _satir(u),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _satir(Urun u) => ListTile(
    leading: u.mediaIds.isEmpty
        ? null
        : SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: MedyaGorsel(
                mediaId: u.mediaIds.first,
                kucuk: true,
                fit: BoxFit.cover,
              ),
            ),
          ),
    title: Text(u.ad),
    subtitle: u.aciklama.isEmpty
        ? null
        : Text(u.aciklama, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(u.fiyatMetni, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (u.durum == 'tukendi')
          const Text(
            'Tükendi',
            style: TextStyle(fontSize: 11, color: Colors.orange),
          )
        else if (u.durum == 'kaldirildi')
          const Text(
            'Kaldırıldı',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    ),
    onTap: widget.benimMi
        ? () async {
            final ok = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => UrunDuzenleEkrani(urun: u)),
            );
            if (ok == true) _yukle();
          }
        : null,
  );

  /// ⚠️⚠️ AI MENU: menu fotografindan urunleri cikarir.
  ///    Sonuc DOGRUDAN KAYDEDILMEZ — kullaniciya ONERI listesi gosterilir,
  ///    o onaylar. Otomatik kaydetmek yanlis okunan bir fiyati sessizce
  ///    menuye yazardi.
  Future<void> _aiMenu() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Menü okunuyor...')),
          ],
        ),
      ),
    );
    try {
      final hazir = await MedyaServisi.gorseliHazirla(File(x.path));
      if (hazir == null) throw Exception('Görsel hazırlanamadı');
      final mediaId = await ref
          .read(medyaServisiProvider)
          .yukle(dosya: hazir, kind: 'image', mime: 'image/jpeg');
      final sonuc = await ref.read(aiServisiProvider).menu(mediaId: mediaId);
      if (!mounted) return;
      Navigator.of(context).pop(); // bekleme diyalogu
      await _oneriGoster(sonuc);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _oneriGoster(String ham) async {
    // ⚠️ Model bazen bozuk JSON dondurebilir — PATLAMAK YERINE ham metni
    //    gosteriyoruz. Kullanici en azindan sonucu gorur.
    List<Map<String, dynamic>> urunler = [];
    try {
      final j = jsonDecode(ham);
      if (j is Map && j['urunler'] is List) {
        urunler = (j['urunler'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }
    } catch (_) {}

    if (!mounted) return;
    if (urunler.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Menü okunamadı'),
          content: SingleChildScrollView(child: Text(ham)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    final secili = List<bool>.filled(urunler.length, true);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, yenile) => AlertDialog(
          title: Text('${urunler.length} ürün bulundu'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: urunler.length,
              itemBuilder: (_, i) {
                final u = urunler[i];
                final kurus = (u['fiyat_kurus'] as num?)?.toInt() ?? 0;
                return CheckboxListTile(
                  dense: true,
                  value: secili[i],
                  onChanged: (v) => yenile(() => secili[i] = v ?? false),
                  title: Text((u['ad'] ?? '').toString()),
                  subtitle: Text(
                    [
                      if ((u['bolum'] ?? '').toString().isNotEmpty)
                        u['bolum'].toString(),
                      if (kurus > 0) '${kurus ~/ 100} ₺',
                    ].join(' · '),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Menüye ekle'),
            ),
          ],
        ),
      ),
    );
    if (onay != true || !mounted) return;

    var eklenen = 0;
    for (var i = 0; i < urunler.length; i++) {
      if (!secili[i]) continue;
      try {
        await ref.read(urunServisiProvider).ekle({
          'ad': (urunler[i]['ad'] ?? '').toString(),
          'aciklama': (urunler[i]['aciklama'] ?? '').toString(),
          'bolum': (urunler[i]['bolum'] ?? '').toString(),
          'fiyat_kurus': (urunler[i]['fiyat_kurus'] as num?)?.toInt() ?? 0,
          'media_ids': <String>[],
        });
        eklenen++;
      } catch (_) {}
    }
    if (!mounted) return;
    await _yukle();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$eklenen ürün eklendi')));
    }
  }
}

/// Urun ekle / duzenle (+ AI aciklama).
class UrunDuzenleEkrani extends ConsumerStatefulWidget {
  const UrunDuzenleEkrani({super.key, this.urun});
  final Urun? urun;

  @override
  ConsumerState<UrunDuzenleEkrani> createState() => _UrunDuzenleEkraniState();
}

class _UrunDuzenleEkraniState extends ConsumerState<UrunDuzenleEkrani> {
  late final _ad = TextEditingController(text: widget.urun?.ad ?? '');
  late final _aciklama = TextEditingController(
    text: widget.urun?.aciklama ?? '',
  );
  late final _bolum = TextEditingController(text: widget.urun?.bolum ?? '');
  late final _fiyat = TextEditingController(
    text: widget.urun == null || widget.urun!.fiyatKurus == 0
        ? ''
        : (widget.urun!.fiyatKurus / 100).toStringAsFixed(2),
  );

  File? _gorsel;
  bool _kaydediliyor = false;
  bool _aiCalisiyor = false;

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    _bolum.dispose();
    _fiyat.dispose();
    super.dispose();
  }

  Future<void> _gorselSec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;
    setState(() => _gorsel = File(x!.path));
  }

  /// ⚠️ AI ACIKLAMA — urunun fotografindan/adindan satis metni yazar.
  ///    Sonuc alana YAZILIR ama kullanici duzenleyebilir.
  Future<void> _aiAciklama() async {
    setState(() => _aiCalisiyor = true);
    try {
      var mediaId = '';
      if (_gorsel != null) {
        final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
        if (hazir != null) {
          mediaId = await ref
              .read(medyaServisiProvider)
              .yukle(dosya: hazir, kind: 'image', mime: 'image/jpeg');
        }
      }
      final metin = await ref
          .read(aiServisiProvider)
          .urunMetni(mediaId: mediaId, metin: _ad.text.trim());
      if (!mounted) return;
      setState(() => _aciklama.text = metin);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _aiCalisiyor = false);
    }
  }

  Future<void> _kaydet() async {
    if (_ad.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ürün adı gerekli')));
      return;
    }
    setState(() => _kaydediliyor = true);
    try {
      final tl = double.tryParse(_fiyat.text.trim().replaceAll(',', '.')) ?? 0;
      final govde = <String, dynamic>{
        'ad': _ad.text.trim(),
        'aciklama': _aciklama.text.trim(),
        'bolum': _bolum.text.trim(),
        'fiyat_kurus': (tl * 100).round(),
      };
      if (widget.urun == null) {
        final idler = <String>[];
        if (_gorsel != null) {
          final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
          if (hazir == null) throw Exception('Görsel hazırlanamadı');
          idler.add(
            await ref
                .read(medyaServisiProvider)
                .yukle(dosya: hazir, kind: 'image', mime: 'image/jpeg'),
          );
        }
        govde['media_ids'] = idler;
        await ref.read(urunServisiProvider).ekle(govde);
      } else {
        // ⚠️ DUZENLEMEDE MEDYA DEGISMEZ (gonderi duzenlemesiyle ayni kural):
        //    medya degisecekse urun silinip yenisi eklenir.
        await ref.read(urunServisiProvider).guncelle(widget.urun!.id, govde);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _kaydediliyor = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ürün kaldırılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    await ref.read(urunServisiProvider).sil(widget.urun!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.urun == null ? 'Ürün ekle' : 'Ürünü düzenle'),
        actions: [
          if (widget.urun != null)
            IconButton(icon: const Icon(LucideIcons.trash2), onPressed: _sil),
          TextButton(
            onPressed: _kaydediliyor ? null : _kaydet,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.urun == null)
            GestureDetector(
              onTap: _gorselSec,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _gorsel == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.imagePlus, size: 28),
                              SizedBox(height: 6),
                              Text('Ürün fotoğrafı'),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_gorsel!, fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _ad,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Ürün adı',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            controller: _aciklama,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              border: OutlineInputBorder(),
            ),
          ),
          // ⚠️ AI dugmesi YALNIZ sunucuda AI aciksa cizilir.
          if (ai?.acik ?? false)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _aiCalisiyor ? null : _aiAciklama,
                icon: _aiCalisiyor
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.sparkles, size: 17),
                label: Text(
                  _aiCalisiyor
                      ? 'Yazılıyor...'
                      : 'Yapay zekâ ile açıklama yaz'
                            '${ai != null && ai.kalan > 0 ? " (${ai.kalan})" : ""}',
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _bolum,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Bölüm (Ana Yemekler, Tatlılar...)',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            controller: _fiyat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fiyat (₺)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_kaydediliyor)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// ⚠️ AI DANISMA — "fotograftan problemleri anlat" (kullanici emri).
///    Hamburger menuden acilir; isletme hesabi GEREKTIRMEZ.
class AiDanismaEkrani extends ConsumerStatefulWidget {
  const AiDanismaEkrani({super.key});

  @override
  ConsumerState<AiDanismaEkrani> createState() => _AiDanismaEkraniState();
}

class _AiDanismaEkraniState extends ConsumerState<AiDanismaEkrani> {
  final _not = TextEditingController();
  File? _gorsel;
  String _sonuc = '';
  bool _calisiyor = false;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _sec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.camera);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    x ??= await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() => _gorsel = File(x!.path));
  }

  Future<void> _sor() async {
    if (_gorsel == null) return;
    setState(() {
      _calisiyor = true;
      _sonuc = '';
    });
    try {
      final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
      if (hazir == null) throw Exception('Görsel hazırlanamadı');
      final mediaId = await ref
          .read(medyaServisiProvider)
          .yukle(dosya: hazir, kind: 'image', mime: 'image/jpeg');
      final s = await ref
          .read(aiServisiProvider)
          .danisma(mediaId: mediaId, metin: _not.text.trim());
      if (mounted) setState(() => _sonuc = s);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Yapay zekâ danışman')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ⚠️ AI kapaliyken DURUST mesaj — dugme cizip 503 aldirmiyoruz.
          if (!(ai?.acik ?? false))
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Yapay zekâ şu anda kullanılamıyor.\n'
                  'Bu özellik yakında açılacak.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            const Text(
              'Bir fotoğraf çek, ne yapman gerektiğini anlatalım.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _sec,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _gorsel == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.camera, size: 30),
                              SizedBox(height: 6),
                              Text('Fotoğraf çek / seç'),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_gorsel!, fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _not,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Eklemek istediğin bilgi (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_gorsel == null || _calisiyor) ? null : _sor,
              icon: _calisiyor
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.sparkles, size: 18),
              label: Text(_calisiyor ? 'İnceleniyor...' : 'Sor'),
            ),
            if (_sonuc.isNotEmpty) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_sonuc, style: const TextStyle(fontSize: 15)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Yapay zekâ yanılabilir. Önemli konularda uzmana danış.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

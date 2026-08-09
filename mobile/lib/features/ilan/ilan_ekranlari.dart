import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import '../sosyal/gonderi_karti.dart' show gonderiZamani;
import '../sosyal/profil_sayfasi.dart';
import 'ilan_servisi.dart';

/// ⚠️⚠️ TURU 77 — ILAN LISTESI (sahibinden deseni).
///
/// [tur] bos = tum ilanlar; 'hizmet' = HIZMETLER karti.
class IlanListesiEkrani extends ConsumerStatefulWidget {
  const IlanListesiEkrani({super.key, this.tur = '', this.baslik = ''});

  final String tur;
  final String baslik;

  @override
  ConsumerState<IlanListesiEkrani> createState() => _IlanListesiEkraniState();
}

class _IlanListesiEkraniState extends ConsumerState<IlanListesiEkrani> {
  final _arama = TextEditingController();
  Timer? _gecikme;
  int _istekNo = 0;

  List<Ilan>? _liste;
  String? _hata;
  late String _tur = widget.tur;
  String _kategori = '';
  // ⚠️ Il suzgeci ILK SURUMDE arayuzden AYARLANMIYOR (arama kutusu + tur +
  //    kategori yeterli); uc ZATEN destekliyor, ekran eklendiginde buraya
  //    yazilir. Sabit birakip 'ozellik var' izlenimi vermiyoruz.
  final String _il = '';
  bool _benim = false;
  bool _favori = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final jeton = ++_istekNo;
    try {
      final l = await ref
          .read(ilanServisiProvider)
          .liste(
            tur: _tur,
            kategori: _kategori,
            il: _il,
            q: _arama.text.trim(),
            benim: _benim,
            favori: _favori,
          );
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (_) {
      if (!mounted || jeton != _istekNo) return;
      setState(() => _hata = 'İlanlar alınamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    final agac = ref.watch(ilanAgaciProvider);
    final l = _liste;
    final turBilgi = agac.valueOrNull
        ?.where((t) => t.anahtar == _tur)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.baslik.isNotEmpty
              ? widget.baslik
              : (_benim
                    ? 'İlanlarım'
                    : _favori
                    ? 'Favorilerim'
                    : 'İlanlar'),
        ),
        actions: [
          IconButton(
            tooltip: 'Favorilerim',
            icon: Icon(
              LucideIcons.heart,
              color: _favori ? const Color(0xFFFF3B5C) : null,
            ),
            onPressed: () {
              setState(() {
                _favori = !_favori;
                if (_favori) _benim = false;
              });
              _yukle();
            },
          ),
          IconButton(
            tooltip: 'İlanlarım',
            icon: Icon(
              LucideIcons.userRound,
              color: _benim ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () {
              setState(() {
                _benim = !_benim;
                if (_benim) _favori = false;
              });
              _yukle();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fabIlanVer',
        onPressed: () async {
          final id = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => IlanVerEkrani(tur: _tur)),
          );
          if (id != null) _yukle();
        },
        icon: const Icon(LucideIcons.plus),
        label: const Text('İlan ver'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _arama,
              onChanged: (_) {
                _gecikme?.cancel();
                _gecikme = Timer(const Duration(milliseconds: 320), _yukle);
              },
              decoration: InputDecoration(
                hintText: 'İlan ara',
                prefixIcon: const Icon(LucideIcons.search, size: 19),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          // ---- TUR CIPLERI (agac SUNUCUDAN)
          SizedBox(
            height: 44,
            child: agac.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (turler) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _cip('', 'Tümü', tur: true),
                  for (final t in turler) _cip(t.anahtar, t.ad, tur: true),
                ],
              ),
            ),
          ),
          // ---- SECILI TURUN KATEGORILERI
          if (turBilgi != null && turBilgi.kategoriler.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _cip('', 'Hepsi'),
                  for (final k in turBilgi.kategoriler) _cip(k.anahtar, k.ad),
                ],
              ),
            ),
          Expanded(
            child: _hata != null
                ? Center(
                    child: Text(
                      _hata!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        _favori
                            ? 'Henüz favori ilanın yok.'
                            : _benim
                            ? 'Henüz ilan vermedin.'
                            : 'Bu aramaya uygun ilan yok.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _yukle,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: l.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => _satir(l[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cip(String anahtar, String ad, {bool tur = false}) {
    final secili = tur ? _tur == anahtar : _kategori == anahtar;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: ChoiceChip(
        label: Text(ad, style: const TextStyle(fontSize: 12)),
        selected: secili,
        onSelected: (_) {
          setState(() {
            if (tur) {
              _tur = anahtar;
              // ⚠️ Tur degisince kategori SIFIRLANIR: eski turun kategorisi
              //    yeni turde ANLAMSIZ ve sonuc her zaman BOS gelirdi.
              _kategori = '';
            } else {
              _kategori = anahtar;
            }
          });
          _yukle();
        },
      ),
    );
  }

  Widget _satir(Ilan i) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    leading: SizedBox(
      width: 74,
      height: 74,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: i.mediaIds.isEmpty
            ? Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(LucideIcons.image, color: Colors.grey),
              )
            : MedyaGorsel(
                mediaId: i.mediaIds.first,
                kucuk: true,
                fit: BoxFit.cover,
              ),
      ),
    ),
    title: Text(i.baslik, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 3),
        Text(
          i.fiyatMetni,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          [
            [i.ilce, i.il].where((s) => s.isNotEmpty).join(', '),
            gonderiZamani(i.createdAt),
          ].where((s) => s.isNotEmpty).join(' · '),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        // ⚠️ SATILDI/KALDIRILDI rozeti YALNIZ "Ilanlarim" listesinde gorunur
        //    (baska yerde zaten yayindakiler listeleniyor).
        if (!i.yayindaMi)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              i.durum == 'satildi' ? 'Satıldı' : 'Kaldırıldı',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.orange,
              ),
            ),
          ),
      ],
    ),
    onTap: () async {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => IlanDetayEkrani(ilan: i)));
      if (mounted) setState(() {});
    },
  );
}

/// Ilan detayi + SATICIYA MESAJ.
class IlanDetayEkrani extends ConsumerStatefulWidget {
  const IlanDetayEkrani({super.key, required this.ilan});
  final Ilan ilan;

  @override
  ConsumerState<IlanDetayEkrani> createState() => _IlanDetayEkraniState();
}

class _IlanDetayEkraniState extends ConsumerState<IlanDetayEkrani> {
  late Ilan i = widget.ilan;
  int _sayfa = 0;

  Future<void> _favoriCevir() async {
    final eski = i.favorim;
    setState(() => i.favorim = !eski);
    try {
      final s = ref.read(ilanServisiProvider);
      eski ? await s.favoriSil(i.id) : await s.favoriEkle(i.id);
    } catch (_) {
      if (!mounted) return;
      // ⚠️ GERI AL — yalan bir "favoriledin" durumu birakmak, kullanicinin
      //    listesinde gorunmeyen bir kayit demek.
      setState(() => i.favorim = eski);
    }
  }

  /// ⚠️ SATICIYA MESAJ mevcut sohbet hattini kullanir (`POST /chats/direct`).
  ///    Ayri bir "ilan mesajlasmasi" YAZILMADI — ikinci bir mesaj hatti
  ///    bildirim/okundu/engel kurallarini ikiye bolerdi.
  Future<void> _saticiyaMesaj() async {
    try {
      final r = await ref
          .read(apiProvider)
          .post('/chats/direct', data: {'user_id': i.sahibiId});
      if (!mounted) return;
      final chatId = (r.data['chat_id'] ?? r.data['id'] ?? '').toString();
      if (chatId.isEmpty) return;
      context.push(
        '/chat/$chatId',
        extra: {
          'title': i.sahibiAd,
          'peer_id': i.sahibiId,
          'avatar_media_id': i.sahibiAvatarMediaId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _durumDegistir(String durum) async {
    try {
      await ref.read(ilanServisiProvider).guncelle(i.id, {'durum': durum});
      if (!mounted) return;
      setState(() => i.durum = durum);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final benimId = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    final benimIlanim = i.sahibiId == benimId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlan'),
        actions: [
          if (!benimIlanim)
            IconButton(
              icon: Icon(
                LucideIcons.heart,
                color: i.favorim ? const Color(0xFFFF3B5C) : null,
              ),
              onPressed: _favoriCevir,
            ),
          if (benimIlanim)
            PopupMenuButton<String>(
              onSelected: _durumDegistir,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'satildi',
                  child: Text('Satıldı işaretle'),
                ),
                PopupMenuItem(value: 'yayinda', child: Text('Tekrar yayınla')),
                PopupMenuItem(value: 'kaldirildi', child: Text('Kaldır')),
              ],
            ),
        ],
      ),
      body: ListView(
        children: [
          if (i.mediaIds.isNotEmpty)
            SizedBox(
              height: 260,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    itemCount: i.mediaIds.length,
                    onPageChanged: (p) => setState(() => _sayfa = p),
                    itemBuilder: (_, k) =>
                        MedyaGorsel(mediaId: i.mediaIds[k], fit: BoxFit.cover),
                  ),
                  if (i.mediaIds.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${_sayfa + 1}/${i.mediaIds.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black87),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i.baslik,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  i.fiyatMetni,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    [i.ilce, i.il].where((s) => s.isNotEmpty).join(', '),
                    gonderiZamani(i.createdAt),
                    '${i.goruntulenme} görüntülenme',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                // ---- TIPE OZEL OZELLIKLER
                if (i.ozellikler.isNotEmpty) ...[
                  const Divider(height: 26),
                  for (final e in i.ozellikler.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 130,
                            child: Text(
                              e.key,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${e.value}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (i.aciklama.isNotEmpty) ...[
                  const Divider(height: 26),
                  Text(i.aciklama, style: const TextStyle(fontSize: 15)),
                ],
                const Divider(height: 26),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(
                    ad: i.sahibiAd,
                    mediaId: i.sahibiAvatarMediaId,
                    cap: 42,
                  ),
                  title: Text(i.sahibiAd),
                  subtitle: const Text('İlan sahibi'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilSayfasi(userId: i.sahibiId),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!benimIlanim)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saticiyaMesaj,
                      icon: const Icon(LucideIcons.messageCircle, size: 18),
                      label: const Text('Satıcıya mesaj gönder'),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilan ver — FORM SUNUCUDAN URETILIR (tipe ozel alanlar).
class IlanVerEkrani extends ConsumerStatefulWidget {
  const IlanVerEkrani({super.key, this.tur = ''});
  final String tur;

  @override
  ConsumerState<IlanVerEkrani> createState() => _IlanVerEkraniState();
}

class _IlanVerEkraniState extends ConsumerState<IlanVerEkrani> {
  final _baslik = TextEditingController();
  final _aciklama = TextEditingController();
  final _fiyat = TextEditingController();
  final _il = TextEditingController();
  final _ilce = TextEditingController();

  /// Tipe ozel alan degerleri (anahtar -> deger).
  final Map<String, String> _ozellikler = {};
  final List<File> _gorseller = [];

  String _tur = '';
  String _kategori = '';
  bool _fiyatGizli = false;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    _tur = widget.tur;
  }

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    _fiyat.dispose();
    _il.dispose();
    _ilce.dispose();
    super.dispose();
  }

  Future<void> _gorselSec() async {
    if (!MedyaKapisi.izinVer(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez',
          ),
        ),
      );
      return;
    }
    List<XFile> secim = [];
    try {
      MedyaKapisi.pickerAcik = true;
      secim = await ImagePicker().pickMultiImage(limit: 12 - _gorseller.length);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (secim.isEmpty || !mounted) return;
    setState(() => _gorseller.addAll(secim.map((x) => File(x.path))));
  }

  Future<void> _kaydet() async {
    if (_tur.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kategori seç')));
      return;
    }
    if (_baslik.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Başlık gerekli')));
      return;
    }
    setState(() => _kaydediliyor = true);
    try {
      final idler = <String>[];
      for (final g in _gorseller) {
        // ⚠️ EXIF (KONUM) TEMIZLIGI ZORUNLU — sunucu GPS bulursa 422 doner.
        final hazir = await MedyaServisi.gorseliHazirla(g);
        if (hazir == null) throw Exception('Görsel hazırlanamadı');
        idler.add(
          await ref
              .read(medyaServisiProvider)
              .yukle(dosya: hazir, kind: 'image', mime: 'image/jpeg'),
        );
      }
      final tl = double.tryParse(_fiyat.text.trim().replaceAll(',', '.')) ?? 0;
      final id = await ref.read(ilanServisiProvider).olustur({
        'tur': _tur,
        'kategori': _kategori,
        'baslik': _baslik.text.trim(),
        'aciklama': _aciklama.text.trim(),
        // ⚠️ KURUS'a cevrilir (sunucu kurus bekliyor — BIGINT tasma korumasi).
        'fiyat_kurus': _fiyatGizli ? 0 : (tl * 100).round(),
        'fiyat_gizli': _fiyatGizli,
        'il': _il.text.trim(),
        'ilce': _ilce.text.trim(),
        'media_ids': idler,
        'ozellikler': Map.fromEntries(
          _ozellikler.entries.where((e) => e.value.trim().isNotEmpty),
        ),
      });
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _kaydediliyor = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final agac = ref.watch(ilanAgaciProvider);
    final turBilgi = agac.valueOrNull
        ?.where((t) => t.anahtar == _tur)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlan ver'),
        actions: [
          TextButton(
            onPressed: _kaydediliyor ? null : _kaydet,
            child: const Text('Yayınla'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _kaydediliyor,
        child: agac.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Kategoriler alınamadı')),
          data: (turler) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _tur.isEmpty ? null : _tur,
                decoration: const InputDecoration(
                  labelText: 'Tür',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final t in turler)
                    DropdownMenuItem(value: t.anahtar, child: Text(t.ad)),
                ],
                onChanged: (v) => setState(() {
                  _tur = v ?? '';
                  // ⚠️ Tur degisince kategori VE tipe ozel alanlar SIFIRLANIR:
                  //    eski turun alanlari yeni turde ANLAMSIZ ve JSONB'ye
                  //    yanlis veri yazilirdi.
                  _kategori = '';
                  _ozellikler.clear();
                }),
              ),
              if (turBilgi != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _kategori.isEmpty ? null : _kategori,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final k in turBilgi.kategoriler)
                      DropdownMenuItem(value: k.anahtar, child: Text(k.ad)),
                  ],
                  onChanged: (v) => setState(() => _kategori = v ?? ''),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _baslik,
                maxLength: 140,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  border: OutlineInputBorder(),
                ),
              ),
              TextField(
                controller: _aciklama,
                minLines: 3,
                maxLines: 8,
                maxLength: 6000,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _fiyatGizli,
                onChanged: (v) => setState(() => _fiyatGizli = v),
                title: const Text('Fiyat belirtme'),
              ),
              if (!_fiyatGizli)
                TextField(
                  controller: _fiyat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Fiyat (₺)',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _il,
                      decoration: const InputDecoration(
                        labelText: 'İl',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ilce,
                      decoration: const InputDecoration(
                        labelText: 'İlçe',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              // ---- TIPE OZEL ALANLAR (SUNUCUDAN URETILIR)
              if (turBilgi != null && turBilgi.alanlar.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  '${turBilgi.ad.toUpperCase()} BİLGİLERİ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                for (final a in turBilgi.alanlar) _alan(a),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _gorselSec,
                icon: const Icon(LucideIcons.imagePlus, size: 18),
                label: Text('Fotoğraf ekle (${_gorseller.length}/12)'),
              ),
              if (_gorseller.isNotEmpty)
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 10),
                    itemCount: _gorseller.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, k) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _gorseller[k],
                            width: 66,
                            height: 74,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _gorseller.removeAt(k)),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xAA000000),
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
        ),
      ),
    );
  }

  /// ⚠️ ALAN SUNUCUDAN GELEN TANIMDAN cizilir — istemcide sabit form YOK.
  Widget _alan(IlanAlani a) {
    final etiket = a.birim.isEmpty ? a.ad : '${a.ad} (${a.birim})';
    if (a.tip == 'secim') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: _ozellikler[a.anahtar],
          decoration: InputDecoration(
            labelText: etiket,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final s in a.secenekler)
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) => setState(() => _ozellikler[a.anahtar] = v ?? ''),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        keyboardType: a.tip == 'sayi' ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: etiket,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => _ozellikler[a.anahtar] = v,
      ),
    );
  }
}

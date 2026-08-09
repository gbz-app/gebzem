import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import '../sosyal/profil_sayfasi.dart';
import 'etkinlik_servisi.dart';

/// ⚠️⚠️ TURU 77 — ETKINLIK LISTESI (kullanici emri: "etkinlikler soldaki menuye
/// tikladiginda ekranda olacak").
///
/// ⚠️ IKI SEKME: YAKLASAN / GECMIS. Gecmis etkinlikler SILINMEZ (veri
///    politikasi) — yalnizca sorgu suzgecinin diger tarafi.
class EtkinlikListesiEkrani extends ConsumerStatefulWidget {
  const EtkinlikListesiEkrani({super.key});

  @override
  ConsumerState<EtkinlikListesiEkrani> createState() =>
      _EtkinlikListesiEkraniState();
}

class _EtkinlikListesiEkraniState extends ConsumerState<EtkinlikListesiEkrani> {
  final _arama = TextEditingController();
  Timer? _gecikme;
  int _istekNo = 0;

  List<Etkinlik>? _liste;
  String? _hata;
  String _kategori = '';
  bool _gecmis = false;
  bool _benim = false;

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
          .read(etkinlikServisiProvider)
          .liste(
            kategori: _kategori,
            q: _arama.text.trim(),
            gecmis: _gecmis,
            benim: _benim,
          );
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (_) {
      if (!mounted || jeton != _istekNo) return;
      setState(() => _hata = 'Etkinlikler alınamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlikler'),
        actions: [
          IconButton(
            tooltip: _benim ? 'Tüm etkinlikler' : 'Benim etkinliklerim',
            icon: Icon(_benim ? LucideIcons.users : LucideIcons.userRound),
            onPressed: () {
              setState(() => _benim = !_benim);
              _yukle();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fabEtkinlikOlustur',
        onPressed: () async {
          final id = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const EtkinlikOlusturEkrani()),
          );
          if (id != null) _yukle();
        },
        icon: const Icon(LucideIcons.plus),
        label: const Text('Etkinlik oluştur'),
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
                hintText: 'Etkinlik ara',
                prefixIcon: const Icon(LucideIcons.search, size: 19),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Yaklaşan')),
                ButtonSegment(value: true, label: Text('Geçmiş')),
              ],
              selected: {_gecmis},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() => _gecmis = s.first);
                _yukle();
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _cip('', 'Tümü'),
                for (final e in etkinlikKategorileri.entries)
                  _cip(e.key, e.value),
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
                        _gecmis
                            ? 'Geçmiş etkinlik yok.'
                            : 'Yaklaşan etkinlik yok.\nİlk etkinliği sen oluştur!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _yukle,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: l.length,
                      itemBuilder: (_, i) => _kart(l[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cip(String anahtar, String ad) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
    child: ChoiceChip(
      label: Text(ad),
      selected: _kategori == anahtar,
      onSelected: (_) {
        setState(() => _kategori = anahtar);
        _yukle();
      },
    ),
  );

  Widget _kart(Etkinlik e) => Card(
    margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () async {
        final degisti = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => EtkinlikDetayEkrani(etkinlik: e)),
        );
        if (!mounted) return;
        // ⚠️ Silme/katilim degistiyse listeyi SUNUCUDAN tazele; salt setState
        //    bayat nesneyi yeniden cizerdi.
        if (degisti == true) { _yukle(); } else { setState(() {}); }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.mediaIds.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: MedyaGorsel(mediaId: e.mediaIds.first, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.baslik,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        etkinlikZamani(e.baslangic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                if (e.konum.isNotEmpty || e.ilce.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            [
                              e.konum,
                              e.ilce,
                              e.il,
                            ].where((s) => s.isNotEmpty).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        e.kategoriAd,
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.fiyatMetni,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(LucideIcons.users, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${e.katilanSayisi}'
                      '${e.kontenjan > 0 ? "/${e.kontenjan}" : ""}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Etkinlik detayi + KATILIM.
class EtkinlikDetayEkrani extends ConsumerStatefulWidget {
  const EtkinlikDetayEkrani({super.key, required this.etkinlik});
  final Etkinlik etkinlik;

  @override
  ConsumerState<EtkinlikDetayEkrani> createState() =>
      _EtkinlikDetayEkraniState();
}

class _EtkinlikDetayEkraniState extends ConsumerState<EtkinlikDetayEkrani> {
  late Etkinlik e = widget.etkinlik;
  bool _mesgul = false;

  Future<void> _katil(String durum) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    // ⚠️ IYIMSER GUNCELLEME + HATA'DA GERI ALMA (kart/gonderi ile ayni desen).
    final eskiDurum = e.benimDurumum;
    final eskiSayi = e.katilanSayisi;
    setState(() {
      e.benimDurumum = durum;
      if (durum == 'katiliyor' && eskiDurum != 'katiliyor') {
        e.katilanSayisi++;
      } else if (durum != 'katiliyor' && eskiDurum == 'katiliyor') {
        e.katilanSayisi = (e.katilanSayisi - 1).clamp(0, 1 << 30);
      }
    });
    try {
      await ref.read(etkinlikServisiProvider).katil(e.id, durum);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        e.benimDurumum = eskiDurum;
        e.katilanSayisi = eskiSayi;
      });
      // ⚠️ Sunucunun mesaji AYNEN gosterilir ("kontenjan doldu" gibi) —
      //    sessiz basarisizlik YASAK.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(err))));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Etkinlik kaldırılsın mı?'),
        content: const Text('Katılımcılar artık göremez.'),
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
    try {
      await ref.read(etkinlikServisiProvider).sil(e.id);
      // ⚠️ TURU 77b — SONUC DONDURULUR. Eskiden ciplak pop vardi ve liste
      //    yalniz setState yapip YENIDEN YUKLEMIYORDU: kullanici "kaldırdım
      //    ama listede duruyor" gorup tekrar basiyor, sunucu 404 donuyor ve
      //    ekranda "Kaldırılamadı" yaziyordu (oysa ZATEN kaldirilmisti).
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kaldırılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final benimId = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    final benimEtkinligim = e.olusturanId == benimId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlik'),
        actions: [
          if (benimEtkinligim)
            IconButton(icon: const Icon(LucideIcons.trash2), onPressed: _sil),
        ],
      ),
      body: ListView(
        children: [
          if (e.mediaIds.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: MedyaGorsel(mediaId: e.mediaIds.first, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.baslik,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _satir(LucideIcons.calendar, etkinlikZamani(e.baslangic)),
                if (e.bitis != null)
                  _satir(
                    LucideIcons.clock,
                    'Bitiş: ${etkinlikZamani(e.bitis)}',
                  ),
                if ([e.konum, e.ilce, e.il].any((s) => s.isNotEmpty))
                  _satir(
                    LucideIcons.mapPin,
                    [
                      e.konum,
                      e.ilce,
                      e.il,
                    ].where((s) => s.isNotEmpty).join(', '),
                  ),
                _satir(LucideIcons.tag, e.kategoriAd),
                _satir(LucideIcons.ticket, e.fiyatMetni),
                _satir(
                  LucideIcons.users,
                  e.kontenjan > 0
                      ? '${e.katilanSayisi} / ${e.kontenjan} katılımcı'
                      : '${e.katilanSayisi} katılımcı',
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(
                    ad: e.olusturanAd,
                    mediaId: e.olusturanAvatarMediaId,
                    cap: 40,
                  ),
                  title: Text(e.olusturanAd),
                  subtitle: const Text('Düzenleyen'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilSayfasi(userId: e.olusturanId),
                    ),
                  ),
                ),
                if (e.aciklama.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(e.aciklama, style: const TextStyle(fontSize: 15)),
                ],
                const SizedBox(height: 26),
                // ⚠️ GECMIS etkinlikte katilim dugmesi CIZILMEZ — basmanin
                //    anlami yok ve kullaniciyi yaniltir.
                if (!e.gecmisMi && !benimEtkinligim) _katilimDugmeleri(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _katilimDugmeleri() {
    final katiliyor = e.benimDurumum == 'katiliyor';
    final ilgileniyor = e.benimDurumum == 'ilgileniyor';
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: (_mesgul || (e.kontenjanDoldu && !katiliyor))
                ? null
                : () => _katil(katiliyor ? 'vazgecti' : 'katiliyor'),
            icon: Icon(
              katiliyor ? LucideIcons.check : LucideIcons.userPlus,
              size: 18,
            ),
            label: Text(
              katiliyor
                  ? 'Katılıyorsun'
                  : (e.kontenjanDoldu ? 'Kontenjan doldu' : 'Katıl'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _mesgul
              ? null
              : () => _katil(ilgileniyor ? 'vazgecti' : 'ilgileniyor'),
          icon: Icon(
            ilgileniyor ? LucideIcons.star : LucideIcons.starOff,
            size: 18,
          ),
          label: const Text('İlgileniyorum'),
        ),
      ],
    );
  }

  Widget _satir(IconData ikon, String metin) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(metin, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );
}

/// Etkinlik olustur.
class EtkinlikOlusturEkrani extends ConsumerStatefulWidget {
  const EtkinlikOlusturEkrani({super.key});

  @override
  ConsumerState<EtkinlikOlusturEkrani> createState() =>
      _EtkinlikOlusturEkraniState();
}

class _EtkinlikOlusturEkraniState extends ConsumerState<EtkinlikOlusturEkrani> {
  final _baslik = TextEditingController();
  final _aciklama = TextEditingController();
  final _konum = TextEditingController();
  final _il = TextEditingController();
  final _ilce = TextEditingController();
  final _fiyat = TextEditingController();
  final _kontenjan = TextEditingController();

  String _kategori = 'konser';
  DateTime _baslangic = DateTime.now().add(const Duration(days: 1));
  bool _ucretsiz = true;
  File? _gorsel;
  bool _kaydediliyor = false;

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    _konum.dispose();
    _il.dispose();
    _ilce.dispose();
    _fiyat.dispose();
    _kontenjan.dispose();
    super.dispose();
  }

  Future<void> _gorselSec() async {
    // ⚠️ DONANIM KAPISI: arama/oda/yayin surerken kamera acmak iOS'ta
    //    paylasilan `videoCapturer`i calar (turu 50 kok nedeni).
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

  Future<void> _tarihSec() async {
    // ⚠️⚠️ TURU 78 — ÇÖKME DÜZELTMESİ (araştırma bulgusu).
    //    `showDatePicker` `initialDate`in [firstDate, lastDate] ARALIĞINDA
    //    olmasını ASSERTION ile şart koşar. Sınırlar `DateTime.now()`a sabitti;
    //    GEÇMİŞ bir etkinlik düzenlenirken `initialDate < firstDate` olur ve
    //    ekran ASSERTION ile ÇÖKER. Aynı sınıf `lastDate` için de geçerli
    //    (2 yıldan uzak vadeli etkinlik).
    //    FIX: sınırlar mevcut değeri DE kapsayacak şekilde genişletilir.
    //    ⚠️ YAPMA: sınırları tekrar yalnız `now()`a bağlama.
    final simdi = DateTime.now();
    var ilk = simdi.subtract(const Duration(days: 1));
    var son = simdi.add(const Duration(days: 730));
    if (_baslangic.isBefore(ilk)) ilk = _baslangic;
    if (_baslangic.isAfter(son)) son = _baslangic;
    final g = await showDatePicker(
      context: context,
      initialDate: _baslangic,
      firstDate: ilk,
      lastDate: son,
    );
    if (g == null || !mounted) return;
    final s = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_baslangic),
    );
    if (!mounted) return;
    setState(() {
      _baslangic = DateTime(
        g.year,
        g.month,
        g.day,
        s?.hour ?? _baslangic.hour,
        s?.minute ?? _baslangic.minute,
      );
    });
  }

  Future<void> _kaydet() async {
    if (_baslik.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Başlık gerekli')));
      return;
    }
    setState(() => _kaydediliyor = true);
    try {
      final idler = <String>[];
      if (_gorsel != null) {
        // ⚠️ EXIF (KONUM) TEMIZLIGI ZORUNLU — sunucu GPS bulursa 422 doner.
        final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
        if (hazir == null) throw Exception('Görsel hazırlanamadı');
        idler.add(
          await ref
              .read(medyaServisiProvider)
              .yukle(dosya: hazir, kind: 'image', mime: 'image/jpeg'),
        );
      }
      // ⚠️ Fiyat KURUS'a cevrilir (sunucu kurus bekliyor — INT tasmasi icin).
      final tl = double.tryParse(_fiyat.text.trim().replaceAll(',', '.')) ?? 0;
      final id = await ref.read(etkinlikServisiProvider).olustur({
        'baslik': _baslik.text.trim(),
        'aciklama': _aciklama.text.trim(),
        'kategori': _kategori,
        'baslangic': _baslangic.toUtc().toIso8601String(),
        'konum': _konum.text.trim(),
        'il': _il.text.trim(),
        'ilce': _ilce.text.trim(),
        'media_ids': idler,
        'ucretsiz': _ucretsiz,
        'fiyat_kurus': _ucretsiz ? 0 : (tl * 100).round(),
        'kontenjan': int.tryParse(_kontenjan.text.trim()) ?? 0,
      });
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (err) {
      if (!mounted) return;
      setState(() => _kaydediliyor = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(err))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Etkinlik oluştur'),
      actions: [
        TextButton(
          onPressed: _kaydediliyor ? null : _kaydet,
          child: const Text('Yayınla'),
        ),
      ],
    ),
    body: AbsorbPointer(
      absorbing: _kaydediliyor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _gorselSec,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _gorsel == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.imagePlus, size: 30),
                            SizedBox(height: 6),
                            Text('Kapak görseli ekle'),
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
            controller: _baslik,
            maxLength: 140,
            decoration: const InputDecoration(
              labelText: 'Başlık',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _aciklama,
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _kategori,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final e in etkinlikKategorileri.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _kategori = v ?? 'diger'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _tarihSec,
            icon: const Icon(LucideIcons.calendar, size: 18),
            label: Text(etkinlikZamani(_baslangic)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _konum,
            decoration: const InputDecoration(
              labelText: 'Yer (mekân adı / adres)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _ucretsiz,
            onChanged: (v) => setState(() => _ucretsiz = v),
            title: const Text('Ücretsiz'),
          ),
          if (!_ucretsiz)
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
          TextField(
            controller: _kontenjan,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kontenjan (boş = sınırsız)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_kaydediliyor)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 40),
        ],
      ),
    ),
  );
}

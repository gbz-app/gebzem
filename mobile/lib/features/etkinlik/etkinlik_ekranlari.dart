import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../vitrin/vitrin_slider.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import '../sosyal/medya_video.dart';
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
          // ---- UST VITRIN (yaklasan etkinlikler). Bos ise CIZILMEZ.
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: VitrinSlider(dikey: 'etkinlik'),
          ),
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
              // ⚠️ TEK KAYNAK (bkz. KapakGorseli serhi): ilk FOTOGRAF secilir.
              child: KapakGorseli(
                mediaIds: e.mediaIds,
                mediaKinds: e.mediaKinds,
                kucuk: false,
              ),
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

  /// Galeri sayfa gostergesi (karma medya).
  int _sayfa = 0;

  /// ⚠️ TURU 78 — KADRO (sahnedekiler). `null` = henuz yuklenmedi.
  List<Kadro>? _kadro;

  @override
  void initState() {
    super.initState();
    _kadroYukle();
  }

  Future<void> _kadroYukle() async {
    try {
      final k = await ref.read(etkinlikServisiProvider).kadro(e.id);
      if (mounted) setState(() => _kadro = k);
    } catch (_) {
      // ⚠️ SESSIZ: kadro alinamamasi etkinlik detayini BLOKLAMAMALI.
      //    Bos liste cizilir, ozellik yokmus gibi gorunur — kabul edilebilir.
      if (mounted) setState(() => _kadro = const []);
    }
  }

  /// ⚠️ TURU 78 — DUZENLEME. Ayri ekran YOK: "Etkinlik oluştur" ekrani
  ///    `etkinlik:` parametresiyle duzenleme modunda acilir (tek kaynak).
  Future<void> _duzenle() async {
    final degisti = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EtkinlikOlusturEkrani(etkinlik: e)),
    );
    if (degisti != true || !mounted) return;
    // ⚠️ `Etkinlik` modelinin alanlari cogunlukla `final` — yerel yamalama
    //    yapilamaz, SUNUCUDAN taze nesne alinir.
    try {
      final yeni = await ref.read(etkinlikServisiProvider).detay(e.id);
      if (!mounted) return;
      setState(() => e = yeni);
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Etkinlik güncellendi')),
      );
    } catch (_) {
      // Guncelleme SUNUCUDA basarili oldu; yalniz tazeleme patladi.
      // ⚠️ Kullaniciya "guncellenemedi" DEMEK YANLIS olurdu.
      if (mounted) Navigator.of(context).pop(true);
    }
  }

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
          // ⚠️⚠️ TURU 78 — "Düzenle" GIRISI. Sunucu ucu ve ekran yazilip
          //    hicbir dugmeye baglanmasaydi ozellik ULASILAMAZ olurdu; bu
          //    projede "olu dogmus ozellik" hatasi BES kez tekrarladi.
          if (benimEtkinligim)
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(LucideIcons.pencil),
              onPressed: _duzenle,
            ),
          if (benimEtkinligim)
            IconButton(icon: const Icon(LucideIcons.trash2), onPressed: _sil),
        ],
      ),
      body: ListView(
        children: [
          // ⚠️⚠️ TURU 78b — KARMA GALERI (denetim bulgusu). Detay TEK bir
          //    `MedyaGorsel` ciziyordu: coklu medya EKLENEBILIYOR ama YALNIZ
          //    ILKI gorunuyordu, ustelik o ilk medya VIDEO ise KIRIK GORSEL
          //    cizilirdi. Ilan detayindaki galeriyle AYNI yapi kullanildi.
          if (e.mediaIds.isNotEmpty)
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    itemCount: e.mediaIds.length,
                    onPageChanged: (p) => setState(() => _sayfa = p),
                    itemBuilder: (_, k) {
                      final tur = k < e.mediaKinds.length
                          ? e.mediaKinds[k]
                          : 'image';
                      if (tur == 'yok') {
                        return const ColoredBox(
                          color: Color(0xFF14101C),
                          child: Center(
                            child: Text(
                              'Bu içerik kaldırıldı',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        );
                      }
                      if (tur == 'video') {
                        // ⚠️⚠️ `otoOynat: false` + `sesli: false` ZORUNLU:
                        //    iOS'ta ses oturumu PROSES GENELINDE TEKTIR ve
                        //    kendiliginden calan bir video SUREN ARAMAYI
                        //    SAGIRLASTIRIR (turu 64/65/73).
                        return MedyaVideo(
                          mediaId: e.mediaIds[k],
                          otoOynat: false,
                          sesli: false,
                          dolgu: BoxFit.cover,
                        );
                      }
                      return MedyaGorsel(
                        mediaId: e.mediaIds[k],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                  if (e.mediaIds.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${_sayfa + 1}/${e.mediaIds.length}',
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
                _kadroBolumu(benimEtkinligim),
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

  /// ⚠️⚠️ TURU 78 — KADRO (oyuncu / sarkici / konusmaci).
  ///
  /// ⚠️ "Kadro" ile "katilimci" AYRI kavramlar: kadro SAHNEDEKILER, katilim
  ///    RSVP'dir. Ayni listede gosterilmeleri kullaniciyi yanilturdi.
  /// ⚠️ Kadro BOSSA ve etkinlik BENIM DEGILSE bolum HIC CIZILMEZ — bos bir
  ///    "Sahnede" basligi ozelligin var oldugunu ama kullanilmadigini
  ///    dusundururdu.
  Widget _kadroBolumu(bool benimEtkinligim) {
    final k = _kadro;
    if (k == null) return const SizedBox.shrink();
    if (k.isEmpty && !benimEtkinligim) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            const Text(
              'Sahnede',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (benimEtkinligim)
              TextButton.icon(
                onPressed: _kadroEkleSor,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Ekle'),
              ),
          ],
        ),
        if (k.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Sanatçı, oyuncu ya da konuşmacı ekleyebilirsin.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        for (final kisi in k)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            // ⚠️ Kayitli kisi KENDI avatarini kullanir (medya dali (b) zaten
            //    herkese acik); kayitsiz kisi HARF avatari alir. Kadroya ayri
            //    fotograf alani EKLENMEDI — yeni bir medya sutunu
            //    `erisebilir()` icine yeni dal gerektirirdi ve o dal
            //    unutuldugunda medya yukleyenden baska herkese 403 donerdi.
            leading: Avatar(
              ad: kisi.ad,
              mediaId: kisi.avatarMediaId,
              avatarUrl: '',
              cap: 38,
            ),
            title: Text(kisi.ad),
            subtitle: kisi.rol.isEmpty ? null : Text(kisi.rol),
            // ⚠️ Kayitliysa profiline BAGLANIR; degilse dokunulamaz (olu
            //    dokunus alani birakmiyoruz).
            onTap: kisi.userId == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilSayfasi(userId: kisi.userId!),
                    ),
                  ),
            trailing: benimEtkinligim
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 17),
                    onPressed: () => _kadroSil(kisi),
                  )
                : null,
          ),
      ],
    );
  }

  Future<void> _kadroEkleSor() async {
    final ad = TextEditingController();
    final rol = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sahneye ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ad,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'İsim',
                counterText: '',
              ),
            ),
            TextField(
              controller: rol,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Rol (sanatçı, oyuncu, DJ...)',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    final isim = ad.text.trim();
    final gorev = rol.text.trim();
    ad.dispose();
    rol.dispose();
    if (onay != true || isim.isEmpty || !mounted) return;
    try {
      // ⚠️ `userId` GONDERILMIYOR: kadroya yazilan kisi genelde uygulamaya
      //    KAYITLI DEGIL (unlu bir sanatci). Kayitli kisiyi baglamak icin
      //    ayri bir "kullanici ara" akisi gerekir — o AYRI BIR IS.
      await ref
          .read(etkinlikServisiProvider)
          .kadroEkle(e.id, ad: isim, rol: gorev);
      await _kadroYukle();
    } catch (err) {
      if (!mounted) return;
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(err))),
      );
    }
  }

  Future<void> _kadroSil(Kadro kisi) async {
    try {
      await ref.read(etkinlikServisiProvider).kadroSil(e.id, kisi.id);
      await _kadroYukle();
    } catch (err) {
      if (!mounted) return;
      // ⚠️ Sessiz basarisizlik YASAK: kullanici sildigini sanmasin.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(err))),
      );
    }
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
/// Etkinlik olustur **VE** duzenle — **TEK EKRAN**.
///
/// ⚠️⚠️ TURU 78 — AYRI "EtkinlikDuzenleEkrani" YAZILMADI. Iki ekran olsaydi
///    dogrulama, tarih secici, medya yonetimi ve fiyat/kontenjan mantigi IKI
///    KOPYA olurdu; bu projede "ayni kuralin iki kopyasi DRIFT eder" hatasi
///    ALTI kez tekrarladi. [etkinlik] doluysa DUZENLEME modu.
class EtkinlikOlusturEkrani extends ConsumerStatefulWidget {
  const EtkinlikOlusturEkrani({super.key, this.etkinlik});

  /// Doluysa DUZENLEME modu.
  final Etkinlik? etkinlik;

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

  /// ⚠️ TURU 78 — BITIS. Sutun 029'dan beri VARDI ve detay ekrani onu
  ///    CIZIYORDU, ama forma HIC KONULMAMISTI: yani "Bitiş: …" satiri sahada
  ///    ASLA gorunmuyordu (olu ozellik, bu projede besinci tekrar).
  DateTime? _bitis;

  bool _ucretsiz = true;

  /// ⚠️ TURU 78 — COKLU MEDYA. Onceden TEK gorsel (`File? _gorsel`) vardi;
  ///    sunucu ZATEN 10 medya kabul ediyordu. Kullanici emri: "etkinlikte de
  ///    gorsel ve videolar olacak".
  final List<File> _gorseller = [];
  final List<File> _videolar = [];

  /// DUZENLEMEDE: sunucuda ZATEN duran medya id'leri (silinebilir).
  final List<String> _mevcutMedya = [];

  static const _enFazlaMedya = 10;
  static const _enFazlaVideo = 2;

  /// ⚠️ Gonderi/ilan tarafiyla AYNI tavan — yeni bir sure siniri UYDURULMADI.
  static const _videoSuresiTavani = Duration(minutes: 5);

  bool _kaydediliyor = false;

  bool get _duzenleme => widget.etkinlik != null;

  @override
  void initState() {
    super.initState();
    final e = widget.etkinlik;
    if (e == null) return;
    _baslik.text = e.baslik;
    _aciklama.text = e.aciklama;
    _kategori = etkinlikKategorileri.containsKey(e.kategori)
        ? e.kategori
        : 'diger';
    if (e.baslangic != null) _baslangic = e.baslangic!;
    _bitis = e.bitis;
    _konum.text = e.konum;
    _il.text = e.il;
    _ilce.text = e.ilce;
    _ucretsiz = e.ucretsiz;
    if (!e.ucretsiz && e.fiyatKurus > 0) {
      final tl = e.fiyatKurus / 100;
      _fiyat.text = tl == tl.roundToDouble()
          ? tl.round().toString()
          : tl.toStringAsFixed(2);
    }
    if (e.kontenjan > 0) _kontenjan.text = e.kontenjan.toString();
    _mevcutMedya.addAll(e.mediaIds);
  }

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
    // ⚠️ TEK KAYNAK: `limit < 2` tuzagi + `take(kalan)` kirpmasi orada.
    //    Dogrudan `pickMultiImage` cagrilsaydi tavanin BIR ALTINDA dugme
    //    SESSIZCE olurdu (turu 77b bulgusu).
    final kalan =
        _enFazlaMedya -
        _mevcutMedya.length -
        _gorseller.length -
        _videolar.length;
    if (kalan <= 0) {
      _uyar('En fazla $_enFazlaMedya medya eklenebilir');
      return;
    }
    final secim = await MedyaSecici.coklu(kalan);
    if (secim.isEmpty || !mounted) return;
    setState(() => _gorseller.addAll(secim.map((x) => File(x.path))));
  }

  /// ⚠️ TURU 78 — ETKINLIGE VIDEO. Boyut + SURE kapisi `MedyaSecici.video`
  ///    icinde (ilan ve gonderi ile AYNI tek kaynak).
  Future<void> _videoSec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    if (_videolar.length >= _enFazlaVideo) {
      _uyar('En fazla $_enFazlaVideo video eklenebilir');
      return;
    }
    if (_mevcutMedya.length + _gorseller.length + _videolar.length >=
        _enFazlaMedya) {
      _uyar('En fazla $_enFazlaMedya medya eklenebilir');
      return;
    }
    final dosya = await MedyaSecici.video(
      sureTavani: _videoSuresiTavani,
      uyar: _uyar,
    );
    if (dosya == null || !mounted) return;
    setState(() => _videolar.add(dosya));
  }

  /// ⚠️ Kok messenger: bu ekran bir alt-sayfadan acilmis olabilir.
  void _uyar(String m) {
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));
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
      // ⚠️ Baslangic ILERI alinip bitisin GERIDE kalmasi mumkun. Sunucu
      //    `b.After(bas)` sartiyla boyle bir bitisi zaten YOK SAYAR; kullanici
      //    "bitis girdim ama gorunmedi" demesin diye burada TEMIZLENIYOR.
      if (_bitis != null && !_bitis!.isAfter(_baslangic)) _bitis = null;
    });
  }

  /// Bitis saati (istege bagli).
  ///
  /// ⚠️ Sinirlar BASLANGICA gore: bitis baslangictan ONCE olamaz. Sunucu da
  ///    ayni kurali uyguluyor (`b.After(bas)`), burada kullaniciya ONCEDEN
  ///    gosteriliyor — sessizce yok sayilan bir giris kotu deneyimdir.
  Future<void> _bitisSec() async {
    final ilk = _baslangic;
    final son = _baslangic.add(const Duration(days: 30));
    var baslangicDegeri = _bitis ?? _baslangic.add(const Duration(hours: 2));
    if (baslangicDegeri.isBefore(ilk)) baslangicDegeri = ilk;
    if (baslangicDegeri.isAfter(son)) baslangicDegeri = son;
    final g = await showDatePicker(
      context: context,
      initialDate: baslangicDegeri,
      firstDate: ilk,
      lastDate: son,
    );
    if (g == null || !mounted) return;
    final s = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baslangicDegeri),
    );
    if (!mounted) return;
    final secilen = DateTime(
      g.year,
      g.month,
      g.day,
      s?.hour ?? baslangicDegeri.hour,
      s?.minute ?? baslangicDegeri.minute,
    );
    if (!secilen.isAfter(_baslangic)) {
      _uyar('Bitiş, başlangıçtan sonra olmalı');
      return;
    }
    setState(() => _bitis = secilen);
  }

  Future<void> _kaydet() async {
    if (_baslik.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Başlık gerekli')));
      return;
    }
    setState(() => _kaydediliyor = true);
    // ⚠️⚠️ TURU 78b — SERVISLER **TUM AWAIT'LERDEN ONCE** (ayrinti icin
    //    `ilan_ekranlari.dart` `_kaydet` serhi). Ozeti: kaydetme uzun surer
    //    (fotograf sikistirma + yukleme + VIDEO), `PopScope` yok, kullanici
    //    geri basarsa `State` dispose olur ve `ref.read` `StateError` firlatir;
    //    catch yutar -> medya R2'ye YUKLENIR ama `POST /etkinlikler` HIC
    //    ATILMAZ. Turu 77b'deki hikaye hatasinin birebir aynisi.
    //    ⚠️ YAPMA: bu iki satiri await'lerin ALTINA tasima.
    final medyaSvc = ref.read(medyaServisiProvider);
    final etkinlikSvc = ref.read(etkinlikServisiProvider);
    try {
      final idler = <String>[];
      for (final g in _gorseller) {
        // ⚠️ EXIF (KONUM) TEMIZLIGI ZORUNLU — sunucu GPS bulursa 422 doner.
        final hazir = await MedyaServisi.gorseliHazirla(g);
        if (hazir == null) throw Exception('Görsel hazırlanamadı');
        idler.add(
          await medyaSvc.yukle(
            dosya: hazir,
            kind: 'image',
            mime: 'image/jpeg',
          ),
        );
      }
      // ⚠️ VIDEO HAM GIDER — `gorseliHazirla` bir GORSEL sikistiricisidir;
      //    videoya uygulanirsa dosya BOZULUR.
      for (final v in _videolar) {
        idler.add(
          await medyaSvc.yukle(dosya: v, kind: 'video', mime: 'video/mp4'),
        );
      }
      // ⚠️ Fiyat KURUS'a cevrilir (sunucu kurus bekliyor — INT tasmasi icin).
      final tl = double.tryParse(_fiyat.text.trim().replaceAll(',', '.')) ?? 0;
      final govde = <String, dynamic>{
        'baslik': _baslik.text.trim(),
        'aciklama': _aciklama.text.trim(),
        'kategori': _kategori,
        'baslangic': _baslangic.toUtc().toIso8601String(),
        // ⚠️ Bos dize = BITISI KALDIR nobetcisi (sunucuda `null` "degistirme"
        //    demek; ayni tuzak kapak gorselinde de vardi).
        'bitis': _bitis?.toUtc().toIso8601String() ?? '',
        'konum': _konum.text.trim(),
        'il': _il.text.trim(),
        'ilce': _ilce.text.trim(),
        // ⚠️ DUZENLEMEDE: KALAN mevcut medyalar + YENI yuklenenler. Kullanicinin
        //    sildikleri bu listede olmadigi icin etkinlikten duser.
        'media_ids': [..._mevcutMedya, ...idler],
        'ucretsiz': _ucretsiz,
        'fiyat_kurus': _ucretsiz ? 0 : (tl * 100).round(),
        'kontenjan': int.tryParse(_kontenjan.text.trim()) ?? 0,
      };
      if (_duzenleme) {
        await etkinlikSvc.guncelle(widget.etkinlik!.id, govde);
        if (!mounted) return;
        // ⚠️ `true` doner: cagiran ekran SUNUCUDAN tazeler. `Etkinlik` modeli
        //    cogunlukla `final` oldugu icin yerel yamalama yapilamaz.
        Navigator.of(context).pop(true);
        return;
      }
      final id = await etkinlikSvc.olustur(govde);
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (err) {
      // ⚠️ KOK MESSENGER: kullanici kaydetme surerken ekrandan cikmis olabilir.
      if (mounted) setState(() => _kaydediliyor = false);
      _uyar(apiErrorMessage(err));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_duzenleme ? 'Etkinliği düzenle' : 'Etkinlik oluştur'),
      actions: [
        TextButton(
          onPressed: _kaydediliyor ? null : _kaydet,
          child: Text(_duzenleme ? 'Kaydet' : 'Yayınla'),
        ),
      ],
    ),
    body: AbsorbPointer(
      absorbing: _kaydediliyor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- MEDYA (coklu gorsel + video) — TURU 78
          // ⚠️ Onceden TEK kapak gorseli vardi; sunucu ZATEN 10 medya kabul
          //    ediyordu, yani sinir yalnizca ARAYUZDEYDI.
          _medyaSeridi(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _gorselSec,
                  icon: const Icon(LucideIcons.imagePlus, size: 18),
                  label: Text(
                    'Görsel '
                    '(${_mevcutMedya.length + _gorseller.length + _videolar.length}'
                    '/$_enFazlaMedya)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _videoSec,
                  icon: const Icon(LucideIcons.video, size: 18),
                  label: Text('Video (${_videolar.length}/$_enFazlaVideo)'),
                ),
              ),
            ],
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
            label: Text('Başlangıç: ${etkinlikZamani(_baslangic)}'),
          ),
          const SizedBox(height: 8),
          // ⚠️⚠️ TURU 78 — BITIS SECICI. `etkinlikler.bitis` sutunu 029'dan
          //    beri VARDI, sunucu dogruluyordu ve DETAY EKRANI onu CIZIYORDU —
          //    ama FORMA HIC KONULMAMISTI. Yani "Bitiş: …" satiri sahada ASLA
          //    gorunmuyordu: klasik "olu ozellik" (bu projede besinci tekrar).
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _bitisSec,
                  icon: const Icon(LucideIcons.clock, size: 18),
                  label: Text(
                    _bitis == null
                        ? 'Bitiş saati (isteğe bağlı)'
                        : 'Bitiş: ${etkinlikZamani(_bitis)}',
                  ),
                ),
              ),
              // ⚠️ "Kaldır" YALNIZ deger varken cizilir — bos ekranda olu dugme.
              if (_bitis != null)
                IconButton(
                  tooltip: 'Bitişi kaldır',
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => setState(() => _bitis = null),
                ),
            ],
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

  /// Secilmis/mevcut medyalarin yatay seridi.
  ///
  /// ⚠️ UC AYRI KAYNAK tek seritte: sunucudaki medyalar (silinebilir), yeni
  ///    secilen fotograflar, yeni secilen videolar. Tek listede tutulamazlardi
  ///    (biri `String` id, ikisi `File` ve yukleme `kind`leri farkli).
  /// ⚠️ VIDEO ONIZLEMESI CIZILMEZ (koyu kutu + film ikonu): formda oynatici
  ///    kurmak iOS'ta ses oturumuna dokunur ve SUREN ARAMAYI sagirlastirabilir
  ///    (turu 64/65/73).
  Widget _medyaSeridi() {
    if (_mevcutMedya.isEmpty && _gorseller.isEmpty && _videolar.isEmpty) {
      return const SizedBox.shrink();
    }
    Widget kaldir(VoidCallback onTap) => Positioned(
      right: 0,
      top: 0,
      child: GestureDetector(
        onTap: onTap,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xAA000000),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(2),
            child: Icon(LucideIcons.x, size: 13, color: Colors.white),
          ),
        ),
      ),
    );
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        children: [
          for (var k = 0; k < _mevcutMedya.length; k++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 80,
                      child: MedyaGorsel(
                        mediaId: _mevcutMedya[k],
                        kucuk: true,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // ⚠️ Yalniz LISTEDEN cikarir; medya sunucuda SILINMEZ.
                  kaldir(() => setState(() => _mevcutMedya.removeAt(k))),
                ],
              ),
            ),
          for (var k = 0; k < _gorseller.length; k++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _gorseller[k],
                      width: 72,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  kaldir(() => setState(() => _gorseller.removeAt(k))),
                ],
              ),
            ),
          for (var k = 0; k < _videolar.length; k++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Stack(
                children: [
                  Container(
                    width: 72,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14101C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.video,
                      color: Colors.white54,
                    ),
                  ),
                  kaldir(() => setState(() => _videolar.removeAt(k))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

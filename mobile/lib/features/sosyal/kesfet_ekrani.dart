import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../medya/medya_gorsel.dart';
import 'gonderi_detay.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 76 — ARAMA / KESFET SEKMESI (kullanici emri: "alt menude arama
/// olmali ... aramadan kastim normal profil arama, instagram gibi").
///
/// ⚠️ ONEMLI AYRIM: buradaki "arama" TELEFON ARAMASI DEGIL, **PROFIL ARAMA**.
///    Projede `Aramalar` (cagri gecmisi) sekmesi de vardi ve iki kavram AYNI
///    kelimeyi kullaniyor. Cagri gecmisi MESAJ sekmesinin altina segment olarak
///    tasindi; bu sekme SOSYAL ARAMA.
///
/// DUZEN (Instagram):
///   · ust: arama kutusu
///   · kutu BOSKEN: KESFET IZGARASI (3 sutun kapak)
///   · kutu DOLUYKEN: kullanici sonuclari listesi
///
/// ⚠️ GECIKMELI ARAMA (debounce 320ms): her tusa basimda REST atmak hem sunucuyu
///    hem mobil veriyi yakar; ustelik yanitlar SIRASIZ donup eski sonucu
///    yenisinin ustune yazabilir (yaris). Jeton (`_istekNo`) ile bayat yanit
///    ATILIR.
/// ⚠️ YAPMA: debounce'u kaldirma; jeton kapisini kaldirma.
class KesfetEkrani extends ConsumerStatefulWidget {
  const KesfetEkrani({super.key});

  @override
  ConsumerState<KesfetEkrani> createState() => _KesfetEkraniState();
}

class _KesfetEkraniState extends ConsumerState<KesfetEkrani>
    with AutomaticKeepAliveClientMixin {
  final _kutu = TextEditingController();
  final _odak = FocusNode();
  Timer? _gecikme;

  /// Bayat yanit kapisi — bkz. sinif serhi.
  int _istekNo = 0;

  List<Map<String, dynamic>>? _sonuclar;
  bool _araniyor = false;

  final List<Gonderi> _izgara = [];
  bool _izgaraYukleniyor = true;
  String? _izgaraHata;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _izgaraYukle();
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    _kutu.dispose();
    _odak.dispose();
    super.dispose();
  }

  Future<void> _izgaraYukle() async {
    try {
      final r = await ref.read(apiProvider).get('/kesfet');
      if (!mounted) return;
      final l = ((r.data as Map)['posts'] as List?) ?? [];
      setState(() {
        _izgara
          ..clear()
          ..addAll(
            l.map((e) => Gonderi.json((e as Map).cast<String, dynamic>())),
          );
        _izgaraYukleniyor = false;
        _izgaraHata = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _izgaraYukleniyor = false;
        _izgaraHata = 'Keşfet yüklenemedi';
      });
    }
  }

  void _degisti(String q) {
    _gecikme?.cancel();
    final metin = q.trim();
    if (metin.isEmpty) {
      setState(() {
        _sonuclar = null;
        _araniyor = false;
      });
      return;
    }
    setState(() => _araniyor = true);
    _gecikme = Timer(const Duration(milliseconds: 320), () => _ara(metin));
  }

  Future<void> _ara(String q) async {
    final jeton = ++_istekNo;
    try {
      final r = await ref
          .read(apiProvider)
          .get('/users/search', queryParameters: {'q': q});
      // ⚠️ BAYAT YANIT KAPISI: bu istek gecerken kullanici yazmaya devam etmis
      //    olabilir; eski yanit yeniyi EZMEMELI.
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _sonuclar = ((r.data as List?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        _araniyor = false;
      });
    } catch (_) {
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _sonuclar = [];
        _araniyor = false;
      });
    }
  }

  void _profileGit(String userId) {
    if (userId.isEmpty) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: userId)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAlive
    final aramaModu = _kutu.text.trim().isNotEmpty;
    // ⚠️ Bu sekmenin AppBar'i YOK (HomeScreen'de kapatildi — Instagram deseni:
    //    ustte baslik degil ARAMA KUTUSU olur). Bu yuzden `SafeArea` BURADA
    //    ZORUNLU; olmazsa arama kutusu durum cubugunun ALTINA girer.
    // ⚠️ `bottom: false` — alt guvenli alani NavigationBar zaten hallediyor.
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _kutu,
              focusNode: _odak,
              textInputAction: TextInputAction.search,
              onChanged: _degisti,
              decoration: InputDecoration(
                hintText: 'Ara (isim veya @kullanıcıadı)',
                prefixIcon: const Icon(LucideIcons.search, size: 19),
                suffixIcon: aramaModu
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _kutu.clear();
                          _degisti('');
                          _odak.unfocus();
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Expanded(child: aramaModu ? _sonucListesi() : _kesfetIzgarasi()),
        ],
      ),
    );
  }

  Widget _sonucListesi() {
    if (_araniyor && _sonuclar == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final l = _sonuclar ?? const [];
    if (l.isEmpty) {
      return const Center(
        child: Text('Sonuç yok', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: l.length,
      itemBuilder: (_, i) {
        final u = l[i];
        final ad = (u['name'] ?? '').toString();
        return ListTile(
          leading: Avatar(
            ad: ad,
            mediaId: u['avatar_media_id'] as String?,
            avatarUrl: (u['avatar_url'] ?? '').toString(),
            cap: 44,
          ),
          title: Text(ad),
          subtitle: Text('@${(u['username'] ?? '').toString()}'),
          onTap: () => _profileGit((u['id'] ?? '').toString()),
        );
      },
    );
  }

  Widget _kesfetIzgarasi() {
    if (_izgaraYukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_izgaraHata != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_izgaraHata!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() => _izgaraYukleniyor = true);
                _izgaraYukle();
              },
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
    }
    if (_izgara.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.compass, size: 52, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Keşfedilecek gönderi yok.\nYukarıdan kişi arayabilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _izgaraYukle,
      child: GridView.builder(
        padding: const EdgeInsets.all(1),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: _izgara.length,
        itemBuilder: (_, i) {
          final g = _izgara[i];
          // ⚠️ IZGARADA VIDEO OYNATILMAZ — 30 karelik bir gride 30 oynatici
          //    kurmak cihazi kilitler. Kapak gorseli + video rozeti cizilir.
          //    (`MedyaGorsel` video medyasi icin sunucunun urettigi poster'i
          //    kullanir; yoksa koyu zemin doner.)
          final videoMu = g.kind(0) == 'video';
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              // ⚠️ `gonderi` NESNESI verilir (id DEGIL): detay ekrani boylece
              //    ekstra REST atmadan ANINDA cizer ve ayni model paylasildigi
              //    icin begeni/kaydetme degisiklikleri izgaraya da yansir.
              MaterialPageRoute(builder: (_) => GonderiDetay(gonderi: g)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: const Color(0xFF15151F),
                  child: g.mediaIds.isEmpty
                      ? const SizedBox.shrink()
                      // ⚠️ `kucuk: true` ZORUNLU — 3 sutunlu izgarada tam
                      //    cozunurlukte 30 gorsel indirmek kullanicinin mobil
                      //    verisini yakar (profil izgarasi da boyle yapiyor).
                      : MedyaGorsel(
                          mediaId: g.mediaIds.first,
                          kucuk: true,
                          fit: BoxFit.cover,
                        ),
                ),
                if (videoMu)
                  const Positioned(
                    top: 5,
                    right: 5,
                    child: Icon(
                      LucideIcons.play,
                      size: 15,
                      color: Colors.white,
                    ),
                  )
                else if (g.mediaIds.length > 1)
                  const Positioned(
                    top: 5,
                    right: 5,
                    child: Icon(
                      LucideIcons.copy,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

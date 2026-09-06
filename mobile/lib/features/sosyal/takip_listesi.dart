import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 75 — TAKIPCILER / TAKIP EDILENLER LISTESI.
///
/// ⚠️ SAYFALAMA `offset` ILE (backend boyle): bu listeler kronolojik DEGIL,
///    `follows.created_at DESC` ile sabit siralidir ve akis kadar hizli
///    degismez — offset burada guvenli.
class TakipListesi extends ConsumerStatefulWidget {
  const TakipListesi({
    super.key,
    required this.userId,
    required this.tur, // followers | following
    required this.baslik,
    this.kisiAd = '',
    this.kisiKullanici = '',
  });

  final String userId;
  final String tur;
  final String baslik;

  /// ⚠️ TURU 180g — **HEADERDA KISININ ADI** (kullanici: *"takip edilen
  ///	ve takipci, orada HEADERDA KISININ ISMI KULLANICI ADI
  ///	yazsin"*). Bos gecilirse eski davranis (yalniz baslik).
  final String kisiAd;
  final String kisiKullanici;

  @override
  ConsumerState<TakipListesi> createState() => _TakipListesiState();
}

class _TakipListesiState extends ConsumerState<TakipListesi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;

  /// ⚠️⚠️ TURU 180g — **ARAMA ISTEMCIDE** (kullanici: *"takipcilerde ve
  ///	takip edilenlerde arama yok, onu da ekle"*).
  ///	Uc (`/users/{id}/followers`) `q` parametresi ALMIYOR ve
  ///	liste TEK ISTEKTE geliyor — yani suzulen kume kullanicinin
  ///	gordugu kumenin TAMAMI. Sunucuya alan eklemek gerekmez
  ///	(turu 122/141'de ayni gerekce).
  final _aramaCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  /// ⚠️⚠️ Turkce duyarsiz karsilastirma: `toLowerCase` 'İ' harfini
  ///	BIRLESIK NOKTAYA cevirir ve "İSTANBUL" ile "istanbul"
  ///	AYRI sayilir (turu 140'ta olculdu).
  static String _sadelestir(String x) => x
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  List<Map<String, dynamic>> get _gorunen {
    if (_q.trim().isEmpty) return _liste;
    final a = _sadelestir(_q.trim());
    return _liste.where((u) {
      final ad = _sadelestir((u['name'] ?? '').toString());
      final kul = _sadelestir((u['username'] ?? '').toString());
      return ad.contains(a) || kul.contains(a);
    }).toList();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final l = await ref
          .read(sosyalServisiProvider)
          .takipListesi(widget.userId, widget.tur);
      if (!mounted) return;
      setState(() {
        _liste = l;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        // ⚠️ 403 = gizli hesap. Genel "yuklenemedi" demek kullaniciyi yaniltir
        //    (tekrar tekrar dener, hicbir zaman gelmez).
        _hata = e.toString().contains('403')
            ? 'Bu hesap gizli — listeyi göremezsin'
            : 'Liste yüklenemedi';
      });
    }
  }

  /// TURU 176 — **YEMEK EKRANIYLA AYNI HEADER** (kullanici emri:
  /// *"takipci ve takip edilenlerde yemek gibi header olacak, aramada
  /// oyle, daha modern gorunsun"*).
  ///
  /// ⚠️ `AppBar` KULLANILMADI: yemek/arama ekranlarindaki header 44 dp'lik
  ///	bir `Stack` (geri oku solda, baslik GERCEK ortada). `AppBar`
  ///	in kendi yuksekligi 56 ve basligi `centerTitle`a bagli —
  ///	yan yana konunca iki ekran AYNI GORUNMEZDI.
  /// ⚠️⚠️ TURU 180g — Baslikta artik KISININ ADI, altinda kucuk
  ///	"@kullanici · Takipçiler". Onceden yalniz "Takipçiler"
  ///	yaziyordu ve kullanici KIMIN listesine baktigini
  ///	goremiyordu.
  /// ⚠️ Ad BOSSA eski davranis: yalniz baslik, tek satir.
  /// ⚠️ Yukseklik 44 -> **52** (iki satir); geri oku kutusu 44'te KALIR
  ///	(Material dokunma tabani).
  Widget _header(BuildContext context) {
    final ad = widget.kisiAd.trim();
    final kul = widget.kisiKullanici.trim();
    final altSatir = kul.isEmpty
        ? widget.baslik
        : '@$kul · ${widget.baslik}';
    return SizedBox(
        height: ad.isEmpty ? 44 : 52,
        child: Stack(
          children: [
            Center(
              // ⚠️ Yan dolgu ZORUNLU: geri oku 44 dp yer kapliyor ve uzun
              //    bir ad ortalanip onun ALTINA girerdi.
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ad.isEmpty ? widget.baslik : ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                  if (ad.isNotEmpty)
                    Text(
                      altSatir,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.15,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(LucideIcons.arrowLeft, size: 24),
                ),
              ),
            ),
          ],
        ),
    );
  }

  /// ⚠️ Arama kutusu: liste BOSKEN de cizilir mi? HAYIR — bos bir listede
  ///	arama kutusu ULASILAMAZ bir islev gibi durur. Yalniz veri varken.
  Widget _arama(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: TextField(
        controller: _aramaCtrl,
        onChanged: (v) => setState(() => _q = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'İsim veya kullanıcı adı ara',
          prefixIcon: const Icon(LucideIcons.search, size: 19),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          // ⚠️⚠️ `suffixIconConstraints` ZORUNLU: verilmezse
          //	`InputDecorator` 48 dp'lik dokunma tabanini DAYATIR ve
          //	kutu ILK HARFTE ~5 dp SICRAR (turu 141'de olculdu).
          suffixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          suffixIcon: _q.isEmpty
              ? null
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _aramaCtrl.clear();
                    setState(() => _q = '');
                  },
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(LucideIcons.x, size: 17),
                  ),
                ),
          filled: true,
          fillColor: scheme.onSurface.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            // ⚠️ Arama YALNIZ veri varken: bos/hatali listede kutu cizmek
            //    calismayan bir alan gibi gorunurdu.
            if (!_yukleniyor && _hata == null && _liste.isNotEmpty)
              _arama(context),
            Expanded(
              child: _govde(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _govde() {
    return _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _hata != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.lock, size: 34, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(_hata!, textAlign: TextAlign.center),
                ],
              ),
            )
          : _liste.isEmpty
          ? const Center(
              child: Text('Liste boş', style: TextStyle(color: Colors.grey)),
            )
          // ⚠️ Suzgec BOSALTTIYSA sebebi SOYLENIR: "Liste boş" demek
          //    kullaniciyi yanlis yere bakmaya iter.
          : _gorunen.isEmpty
          ? Center(
              child: Text(
                '"${_q.trim()}" ile eşleşen kimse yok',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _gorunen.length,
              itemBuilder: (_, i) {
                final u = _gorunen[i];
                final ad = (u['name'] ?? '').toString();
                final kul = (u['username'] ?? '').toString();
                return ListTile(
                  leading: Avatar(
                    ad: ad,
                    mediaId: u['avatar_media_id'] as String?,
                    avatarUrl: (u['avatar_url'] ?? '').toString(),
                    cap: 42,
                  ),
                  title: Text(ad),
                  subtitle: kul.isEmpty ? null : Text('@$kul'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfilSayfasi(userId: (u['id'] ?? '').toString()),
                    ),
                  ),
                );
              },
            );
  }
}

/// Bekleyen takip istekleri (yalniz GIZLI hesap sahibi gorur).
class TakipIstekleri extends ConsumerStatefulWidget {
  const TakipIstekleri({super.key});

  @override
  ConsumerState<TakipIstekleri> createState() => _TakipIstekleriState();
}

class _TakipIstekleriState extends ConsumerState<TakipIstekleri> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;

  /// ⚠️ Islenen id'ler: onay/red REST'i ucarken ayni satira tekrar basilmasin.
  final _mesgul = <String>{};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final l = await ref.read(sosyalServisiProvider).takipIstekleri();
      if (!mounted) return;
      setState(() {
        _liste = l;
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _karar(String userId, bool onay) async {
    if (!_mesgul.add(userId)) return;
    setState(() {});
    try {
      final s = ref.read(sosyalServisiProvider);
      onay ? await s.istekOnayla(userId) : await s.istekReddet(userId);
      if (!mounted) return;
      setState(() => _liste.removeWhere((u) => (u['id'] ?? '') == userId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı')));
    } finally {
      _mesgul.remove(userId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Takip istekleri')),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _liste.isEmpty
          ? const Center(
              child: Text(
                'Bekleyen istek yok',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _liste.length,
              itemBuilder: (_, i) {
                final u = _liste[i];
                final id = (u['id'] ?? '').toString();
                final calisiyor = _mesgul.contains(id);
                return ListTile(
                  leading: Avatar(
                    ad: (u['name'] ?? '').toString(),
                    mediaId: u['avatar_media_id'] as String?,
                    avatarUrl: (u['avatar_url'] ?? '').toString(),
                    cap: 42,
                  ),
                  title: Text((u['name'] ?? '').toString()),
                  subtitle: Text('@${u['username'] ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          LucideIcons.check,
                          color: Color(0xFF4CAF50),
                        ),
                        onPressed: calisiyor ? null : () => _karar(id, true),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.red),
                        onPressed: calisiyor ? null : () => _karar(id, false),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

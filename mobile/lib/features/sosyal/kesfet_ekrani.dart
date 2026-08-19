import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../../core/api.dart';
import '../medya/medya_gorsel.dart';
import '../ilan/ilan_ekranlari.dart' show IlanDetayEkrani;
import '../ilan/ilan_servisi.dart' show Ilan;
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

  // ⚠️ TURU 115 — `_sonuclar` SILINDI: sonuclar artik SEKME BASINA
  //    `_sonuc` haritasinda tutuluyor.
  // ⚠️ TURU 115 —  SILINDI: yukleme durumu artik SEKME BASINA
  //    ().

  final List<Gonderi> _izgara = [];
  bool _izgaraYukleniyor = true;
  String? _izgaraHata;

  @override
  bool get wantKeepAlive => true;

  /// ⚠️⚠️⚠️ TURU 115 — **TIKTOK TARZI ARAMA** (kullanici emri: *"arama kismi
  ///	icin sana TIKTOK TARZI olsun dedim yapmadin"* + daha once *"arama
  ///	ekrani kategorilerle olsun: kullanici, isletme, ses, konum"*).
  ///
  /// Arama yapilinca sonuclar SEKMELERE ayrilir. Her sekme AYRI bir ucu
  /// cagirir ve sonucu KENDI listesinde tutar:
  ///
  ///	· Kullanıcılar -> GET /users/search?q=
  ///	· İşletmeler   -> GET /isletmeler?q=
  ///	· İlanlar      -> GET /ilanlar?q=
  ///	· Gönderiler   -> GET /ara?q=            (turu 115'te YAZILDI)
  ///	· Ses          -> GET /ara?q=&tur=ses
  ///	· Yer          -> GET /ara?q=&tur=konum
  ///
  /// ⚠️⚠️ SEKME BASINA **TEMBEL**: yalnizca ACILAN sekme istek atar. Altisini
  ///	birden cagirmak tek harfte ALTI ag istegi demekti (debounce 320 ms
  ///	olsa bile). `_sonuc` haritasi hangi sekmenin YUKLENDIGINI tutar.
  /// ⚠️ Arama metni degisince TUM sekme onbellegi temizlenir — aksi halde
  ///    kullanici yeni kelime yazip eski sekmeye gecince ESKI sonucu gorurdu.
  static const _sekmeler = <({String etiket, String tur})>[
    (etiket: 'Kullanıcılar', tur: 'kullanici'),
    (etiket: 'İşletmeler', tur: 'isletme'),
    (etiket: 'Gönderiler', tur: 'gonderi'),
    (etiket: 'İlanlar', tur: 'ilan'),
    (etiket: 'Ses', tur: 'ses'),
    (etiket: 'Yer', tur: 'konum'),
  ];

  /// tur -> sonuc listesi (`null` = henuz yuklenmedi).
  final Map<String, List<dynamic>?> _sonuc = {};
  final Set<String> _yukleniyorTur = {};
  int _sekme = 0;

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
        _sonuc.clear();
      });
      return;
    }
    _gecikme = Timer(const Duration(milliseconds: 320), () => _ara(metin));
  }

  /// Arama metni degisti: TUM sekme onbellegi bosalir, AKTIF sekme yuklenir.
  Future<void> _ara(String q) async {
    _sonuc.clear();
    _yukleniyorTur.clear();
    if (!mounted) return;
    await _sekmeYukle(_sekmeler[_sekme].tur, q);
  }

  /// ⚠️ BAYAT YANIT KAPISI (`_istekNo`): istek ucarken kullanici yazmaya devam
  ///    etmis olabilir; eski yanit yeniyi EZMEMELI. Turu 96'dan beri var,
  ///    cok-sekmeli yapida da KORUNDU.
  Future<void> _sekmeYukle(String tur, String q) async {
    if (q.isEmpty || _sonuc.containsKey(tur) || _yukleniyorTur.contains(tur)) {
      return;
    }
    final jeton = ++_istekNo;
    setState(() => _yukleniyorTur.add(tur));
    try {
      final api = ref.read(apiProvider);
      final List<dynamic> l;
      switch (tur) {
        case 'kullanici':
          final r = await api.get(
            '/users/search',
            queryParameters: {'q': q},
          );
          l = (r.data as List?) ?? [];
        case 'isletme':
          final r = await api.get(
            '/isletmeler',
            queryParameters: {'q': q},
          );
          l = ((r.data as Map)['isletmeler'] as List?) ?? [];
        case 'ilan':
          final r = await api.get('/ilanlar', queryParameters: {'q': q});
          l = ((r.data as Map)['ilanlar'] as List?) ?? [];
        default:
          // gonderi · ses · konum -> tek uc, `tur` parametresiyle
          final r = await api.get(
            '/ara',
            queryParameters: {
              'q': q,
              if (tur != 'gonderi') 'tur': tur,
            },
          );
          l = ((r.data as Map)['posts'] as List?) ?? [];
      }
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _sonuc[tur] = l;
        _yukleniyorTur.remove(tur);
      });
    } catch (_) {
      if (!mounted) return;
      // ⚠️ Hata da ONBELLEKLENIR (bos liste): aksi halde her cizimde istek
      //    tekrar atilir ve ekran spinner'da donerdi.
      setState(() {
        _sonuc[tur] = const [];
        _yukleniyorTur.remove(tur);
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
          if (aramaModu) _sekmeSeridi(),
          Expanded(child: aramaModu ? _sonucGovde() : _kesfetIzgarasi()),
        ],
      ),
    );
  }

  /// Sekme seridi — TikTok'un sonuc sekmeleri.
  ///
  /// ⚠️ `TabBar` KULLANILMADI: `TabController` sekme sayisi degismedigi
  ///    surece dogru calisir ama burada sekme sayisi SABIT ve secim zaten
  ///    `_sekme` alaninda; ayrica `TabBar` kendi kaydirma fizigini getirir.
  ///    Yatay `ListView` + cip daha az hareketli parca.
  Widget _sekmeSeridi() => SizedBox(
    height: 42,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _sekmeler.length,
      itemBuilder: (_, i) {
        final secili = i == _sekme;
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _sekme = i);
              // ⚠️ TEMBEL: sekmeye GECILDIGINDE yuklenir.
              unawaited(
                _sekmeYukle(_sekmeler[i].tur, _kutu.text.trim()),
              );
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: secili
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _sekmeler[i].etiket,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: secili ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _sonucGovde() {
    final tur = _sekmeler[_sekme].tur;
    final l = _sonuc[tur];
    if (l == null || _yukleniyorTur.contains(tur)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (l.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Sonuç yok',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: l.length,
      itemBuilder: (_, i) {
        final m = (l[i] as Map).cast<String, dynamic>();
        return switch (tur) {
          'kullanici' => _kullaniciSatiri(m),
          'isletme' => _isletmeSatiri(m),
          'ilan' => _ilanSatiri(m),
          _ => _gonderiSatiri(m),
        };
      },
    );
  }

  Widget _kullaniciSatiri(Map<String, dynamic> u) {
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
  }

  /// ⚠️ Isletme sonucu da PROFILE gider: isletme bu projede bir KULLANICIDIR
  ///    (`users.hesap_turu='isletme'`), ayri bir detay ekrani YOK.
  Widget _isletmeSatiri(Map<String, dynamic> i) {
    final ad = (i['name'] ?? '').toString();
    final alt = [
      (i['kategori_ad'] ?? '').toString(),
      [
        (i['ilce'] ?? '').toString(),
        (i['il'] ?? '').toString(),
      ].where((x) => x.isNotEmpty).join(', '),
    ].where((x) => x.isNotEmpty).join(' · ');
    return ListTile(
      leading: Avatar(
        ad: ad,
        mediaId: i['avatar_media_id'] as String?,
        avatarUrl: (i['avatar_url'] ?? '').toString(),
        cap: 44,
      ),
      title: Text(ad),
      subtitle: alt.isEmpty ? null : Text(alt),
      trailing: i['dogrulandi'] == true
          ? Icon(
              LucideIcons.badgeCheck,
              size: 17,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () => _profileGit((i['id'] ?? '').toString()),
    );
  }

  Widget _ilanSatiri(Map<String, dynamic> m) {
    final i = Ilan.fromJson(m);
    return ListTile(
      leading: SizedBox(
        width: 52,
        height: 52,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: KapakGorseli(
            mediaIds: i.mediaIds,
            mediaKinds: i.mediaKinds,
            width: 52,
          ),
        ),
      ),
      title: Text(i.baslik, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(i.fiyatEtiketi),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => IlanDetayEkrani(ilan: i)),
      ),
    );
  }

  /// ⚠️ Gonderi sonucu DETAYA gider (izgara hucresi degil liste satiri):
  ///    arama sonucunda metin baglami onemli, kare kapak tek basina hangi
  ///    gonderi oldugunu anlatmiyor.
  Widget _gonderiSatiri(Map<String, dynamic> m) {
    final g = Gonderi.json(m);
    final metin = g.metin.trim();
    final alt = [
      g.yazarAd,
      if (g.konum.isNotEmpty) g.konum,
    ].join(' · ');
    return ListTile(
      leading: SizedBox(
        width: 52,
        height: 52,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: KapakGorseli(
            mediaIds: g.mediaIds,
            mediaKinds: g.mediaKinds,
            width: 52,
          ),
        ),
      ),
      title: Text(
        metin.isEmpty ? '(yazısız gönderi)' : metin,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(alt, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GonderiDetay(gonderi: g)),
      ),
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
    return YenileSarmali(
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
                      // ⚠️⚠️ TURU 83 — `KapakGorseli` (denetim bulgusu, ayni
                      //    kok neden profil izgarasinda SEVK ENGELIYDI):
                      //    `mediaIds.first` TUR KONTROLSUZDU; ilk medyasi
                      //    VIDEO olan bir gonderide thumb bulunmadigi icin
                      //    ham `url`e dusuluyor ve **mp4'un TAMAMI indirilip**
                      //    ardindan KIRIK GORSEL ciziliyordu.
                      //    `KapakGorseli` ILK FOTOGRAFI secer; yalniz-video
                      //    gonderide indirme YAPMADAN yer tutucu cizer.
                      : KapakGorseli(
                          mediaIds: g.mediaIds,
                          mediaKinds: g.mediaKinds,
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

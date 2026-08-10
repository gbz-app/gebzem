import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../vitrin/vitrin_slider.dart';
import '../sosyal/profil_basligi.dart' show kOnayliRengi;
import '../sosyal/profil_sayfasi.dart';
import 'isletme_servisi.dart';

/// ⚠️⚠️ TURU 77 — ISLETME REHBERI.
///
/// ⚠️⚠️ BU EKRAN, HAMBURGER MENUDEKI KARTLARIN GITTIGI YERDIR.
///    Turu 76b'de Yemek / Restoran / Alisveris kartlari HICBIR YERE gitmiyordu
///    ("yakında" diyordu) — bu projede tekrar eden "olu dogmus ozellik"
///    sinifiydi. Artik gercek bir listeye baglaniyor.
///
/// [kategori] bos ise TUM isletmeler; doluysa o kategori.
class IsletmeListesiEkrani extends ConsumerStatefulWidget {
  const IsletmeListesiEkrani({super.key, this.kategori = '', this.baslik = ''});

  final String kategori;
  final String baslik;

  @override
  ConsumerState<IsletmeListesiEkrani> createState() =>
      _IsletmeListesiEkraniState();
}

class _IsletmeListesiEkraniState extends ConsumerState<IsletmeListesiEkrani> {
  final _arama = TextEditingController();
  Timer? _gecikme;

  /// Bayat yanit kapisi — yanitlar SIRASIZ donebilir (kesfet ekraniyla ayni desen).
  int _istekNo = 0;

  List<IsletmeOzet>? _liste;
  String? _hata;
  late String _kategori = widget.kategori;

  /// ⚠️⚠️ TURU 78 — HIZLI KARTLAR ("Şehrimde" / "Onaylı").
  ///
  /// Kullanici emri: "altta kucuk kartlar mesela yemekte yakinimda favoriler
  /// vs diye kartlar olsun".
  ///
  /// ⚠️⚠️ "YAKINIMDA" YERINE "ŞEHRİMDE" — bu bilincli ve DURUST bir karar:
  ///    GPS icin `AndroidManifest.xml`de `ACCESS_*_LOCATION`, `Info.plist`te
  ///    `NSLocation*` anahtarlari YOK. Podfile olmadigi icin
  ///    `permission_handler`in TUM izin isleyicileri derleniyor ve anahtar
  ///    eksikken konum istenirse **iOS uygulamayi ANINDA SONLANDIRIR**.
  ///    Ayrica sistemde tek bir gercek koordinat da yok (bkz. FAZ 0 koordinat
  ///    ezme duzeltmesi). Il/ilce ile ayni isi BUGUN goruyoruz; GPS ayri tur.
  ///    ⚠️ YAPMA: izin anahtarlarini eklemeden konum paketi cagirma.
  String _hizli = '';

  /// Kullanicinin kendi ilcesi — "Şehrimde" kartinin kaynagi.
  /// ⚠️ Bos ise kart CIZILMEZ (olu kart birakmiyoruz).
  String _benimIlce = '';

  @override
  void initState() {
    super.initState();
    _ilceyiOgren();
    _yukle();
  }

  /// Kullanicinin ilcesini KENDI isletme kaydindan ogrenir.
  ///
  /// ⚠️ Bu YALNIZ isletme hesaplarinda dolu olur. Kisisel hesapta ilce bilgisi
  ///    HICBIR YERDE tutulmuyor — o yuzden "Şehrimde" karti onlarda CIZILMEZ.
  ///    Sahte bir varsayilan ("Gebze") koymak YANLIS olurdu: kullanici baska
  ///    ilcedeyse liste yanlis gelir ve sebebini anlamaz.
  Future<void> _ilceyiOgren() async {
    // ⚠️⚠️ TURU 78b — SAGLAYICI HENUZ COZULMEMISSE **BEKLENIR** (denetim).
    //    `myProfileProvider` bir `FutureProvider`dir; `initState`ten cagrilan
    //    bu metot `valueOrNull`u okuyup null bulunca SESSIZCE cikiyordu ve
    //    TEKRAR DENEYEN HICBIR SEY YOKTU -> ekran soguk acildiginda "Şehrimde"
    //    karti KALICI OLARAK cizilmiyordu (ozellik rastgele "yok" gorunuyordu).
    var id = (ref.read(myProfileProvider).valueOrNull?['id'] ?? '').toString();
    if (id.isEmpty) {
      try {
        final p = await ref.read(myProfileProvider.future);
        id = (p['id'] ?? '').toString();
      } catch (_) {
        return; // profil alinamadi: kart cizilmez (durust davranis)
      }
    }
    if (!mounted || id.isEmpty) return;
    try {
      final i = await ref.read(isletmeServisiProvider).detay(id);
      if (mounted && i != null && i.ilce.isNotEmpty) {
        setState(() => _benimIlce = i.ilce);
      }
    } catch (_) {
      // ⚠️ SESSIZ: ilce ogrenilemezse yalnizca "Şehrimde" karti cizilmez.
    }
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
          .read(isletmeServisiProvider)
          .liste(
            kategori: _kategori,
            q: _arama.text.trim(),
            // ⚠️ Hizli kart suzgecleri SUNUCUYA gider. Istemcide suzmek YANLIS
            //    olurdu: sunucu `LIMIT 60` donuyor, istemci 3'e dusurseydi
            //    kullanici "sadece 3 isletme var" sanirdi.
            ilce: _hizli == 'sehrimde' ? _benimIlce : '',
            yalnizOnayli: _hizli == 'onayli',
          );
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (_) {
      if (!mounted || jeton != _istekNo) return;
      setState(() => _hata = 'İşletmeler alınamadı');
    }
  }

  void _aramaDegisti(String _) {
    _gecikme?.cancel();
    // ⚠️ 320ms gecikme — her tusa basista istek atmak sunucuyu bosuna yorar.
    _gecikme = Timer(const Duration(milliseconds: 320), _yukle);
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.baslik.isNotEmpty
              ? widget.baslik
              : (_kategori.isEmpty
                    ? 'İşletmeler'
                    : isletmeKategoriAdi(_kategori)),
        ),
      ),
      body: Column(
        children: [
          // ---- UST VITRIN SLIDER'I (kullanici emri: "ustte slider")
          // ⚠️ Icerik ORGANIK (dogrulanmis isletmeler); `reklamlar` tablosu
          //    ACILMADI — gerekce backend/internal/vitrin/handler.go serhinde.
          // ⚠️ Vitrin BOSSA widget HIC CIZILMEZ (bos gri kutu YOK).
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: VitrinSlider(
              dikey: _kategori.isEmpty ? 'isletme' : _kategori,
            ),
          ),
          // ---- HIZLI KARTLAR (kullanici emri: "altta kucuk kartlar")
          _hizliKartlar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _arama,
              onChanged: _aramaDegisti,
              decoration: InputDecoration(
                hintText: 'İşletme ara',
                prefixIcon: const Icon(LucideIcons.search, size: 19),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          // ---- KATEGORI CIPLERI (tumu + kategoriler)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _cip('', 'Tümü'),
                for (final e in isletmeKategorileri.entries)
                  _cip(e.key, e.value),
              ],
            ),
          ),
          Expanded(
            child: _hata != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _hata!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: _yukle,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  )
                : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'Bu kategoride henüz işletme yok.\n'
                        'İlk işletme sen ol: Profil → İşletme hesabı.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : YenileSarmali(
                    onRefresh: _yukle,
                    child: ListView.separated(
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

  /// ⚠️⚠️ TURU 78 — HIZLI KARTLAR. Kullanici emri: "altta kucuk kartlar,
  ///    mesela yemekte yakinimda, favoriler vs".
  ///
  /// ⚠️ KART SAYISI DEGISKEN: "Şehrimde" YALNIZ kullanicinin ilcesi
  ///    BILINIYORSA cizilir. Bilinmediginde cizip bos sonuc dondurmek
  ///    ozelligi "bozuk" gosterirdi (bu projede "var gorunup calismayan
  ///    ozellik" hatasi BES kez tekrarladi).
  /// ⚠️ Hicbir kart yoksa serit HIC CIZILMEZ (bos yatay bosluk kalmasin).
  Widget _hizliKartlar() {
    final kartlar = <({String anahtar, String ad, IconData ikon})>[
      if (_benimIlce.isNotEmpty)
        (anahtar: 'sehrimde', ad: _benimIlce, ikon: LucideIcons.mapPin),
      (anahtar: 'onayli', ad: 'Onaylı', ikon: LucideIcons.badgeCheck),
    ];
    if (kartlar.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          for (final k in kartlar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: FilterChip(
                avatar: Icon(k.ikon, size: 15),
                label: Text(k.ad),
                selected: _hizli == k.anahtar,
                onSelected: (secili) {
                  // ⚠️ TEK SECIM: ikinci karta basmak oncekini KAPATIR.
                  //    Coklu secim "Şehrimde + Onaylı" gibi bos sonuclar
                  //    uretip kullaniciyi "hic isletme yok" sanisina dusururdu.
                  setState(() => _hizli = secili ? k.anahtar : '');
                  _yukle();
                },
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

  Widget _satir(IsletmeOzet o) => ListTile(
    leading: Avatar(
      ad: o.ad,
      mediaId: o.avatarMediaId,
      avatarUrl: o.avatarUrl,
      cap: 46,
    ),
    title: Row(
      children: [
        Flexible(child: Text(o.ad, overflow: TextOverflow.ellipsis)),
        // ⚠️⚠️ TURU 78 — ROZET RENGI/BOYUTU TEK KAYNAKTAN (`kOnayliRengi`).
        //    Bu rozet iki ekranda ELLE cizilmisti ve ZATEN DRIFT ETMISTI
        //    (burada 15px, profilde 16px, renkler elle yazilmis). Renk artik
        //    `profil_basligi.dart`taki sabitten geliyor.
        // ⚠️ `dogrulandi` alani artik sunucuda `users.onayli`dan doluyor
        //    (JSON alan adi eski istemciler icin korundu).
        if (o.dogrulandi)
          const Padding(
            padding: EdgeInsets.only(left: 5),
            child: Icon(LucideIcons.badgeCheck, size: 15, color: kOnayliRengi),
          ),
      ],
    ),
    subtitle: Text(
      [
        isletmeKategoriAdi(o.kategori),
        if (o.ilce.isNotEmpty || o.il.isNotEmpty)
          [o.ilce, o.il].where((s) => s.isNotEmpty).join(', '),
      ].join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id))),
  );
}

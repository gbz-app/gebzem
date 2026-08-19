import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_screen.dart' show myProfileProvider;
import 'demo_veri.dart' show kDemoAkis;
import 'demo_yorum.dart';
import 'gonderi_hareketleri.dart';
import 'yorum_satiri.dart';
import '../isletme/isletme_kart.dart' show kYanBosluk;
import '../isletme/isletme_listesi.dart' show IsletmeListesiEkrani;
import 'gonderi_karti.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 75 — TEK GONDERI SAYFASI.
///
/// IKI GIRIS YOLU:
///   · `gonderi` HAZIR verilir (profil izgarasindan gelinir) — ANINDA cizilir.
///   · `gonderiId` verilir (bildirimden/derin baglantidan gelinir) — sunucudan cekilir.
///
/// ⚠️ IKISINDEN BIRI ZORUNLU; assert ile derleme zamanina yakin yakalanir.
///    Aksi halde bos ekran acilir ve sebebi belli olmaz.
class GonderiDetay extends ConsumerStatefulWidget {
  const GonderiDetay({super.key, this.gonderi, this.gonderiId})
    : assert(
        gonderi != null || gonderiId != null,
        'gonderi ya da gonderiId verilmeli',
      );

  final Gonderi? gonderi;
  final String? gonderiId;

  @override
  ConsumerState<GonderiDetay> createState() => _GonderiDetayState();
}

class _GonderiDetayState extends ConsumerState<GonderiDetay> {
  Gonderi? _g;

  /// ⚠️ TURU 99 — yanit siralamasi (Threads: "Başlıca" / "Yakınlarda").
  ///    Bugun YALNIZ demo listesini yeniden siralar; sunucuda siralama
  ///    parametresi YOK (`GET /posts/{id}/comments` tek duzen doner).
  String _sirala = 'baslica';

  /// Inline acilmis yanit kumeleri (Threads yeni sayfa ACMAZ).
  final Set<String> _acikYanitlar = <String>{};
  bool _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _g = widget.gonderi;
    if (_g == null) {
      _cek();
    } else {
      // ⚠️⚠️ TURU 76 (DENETIM BULGUSU) — GORUNTULENME HIC ARTMIYORDU.
      //    Sunucu sayaci YALNIZ `GET /posts/{id}` icinde artiriyor. Bu ekran
      //    hazir bir `Gonderi` NESNESIYLE acildiginda (profil izgarasi, kesfet
      //    izgarasi, kaydedilenler — yani GERCEK giris yollarinin COGU) o istek
      //    HIC ATILMIYORDU. Sonuc: kullanicinin ozellikle istedigi
      //    "goruntulenme sayisi" istatistigi pratikte HEP 0 kalirdi.
      // ⚠️ SESSIZ tazeleme: spinner YOK, hata ekrani YOK — elimizde zaten
      //    cizilecek gonderi var; ag hatasi kullaniciya BOS EKRAN gostermemeli.
      unawaited(_sessizTazele());
    }
  }

  /// Sunucudan taze sayilari alir (ve GORUNTULENMEYI artirir).
  ///
  /// ⚠️ `_g` NESNESI DEGISTIRILMEZ, ALANLARI GUNCELLENIR: model akis/izgara ile
  ///    PAYLASILIYOR (bu dosyanin ve kartin dayandigi desen). Yeni nesne
  ///    atasaydik detayda yapilan begeni, geri donuldugunde izgarada gorunmezdi.
  Future<void> _sessizTazele() async {
    try {
      final taze = await ref
          .read(sosyalServisiProvider)
          .gonderiGetir(widget.gonderi!.id);
      if (!mounted) return;
      final g = _g;
      if (g == null) return;
      setState(() {
        g.begeniSayisi = taze.begeniSayisi;
        g.yorumSayisi = taze.yorumSayisi;
        g.begendim = taze.begendim;
        g.kaydettim = taze.kaydettim;
        g.metin = taze.metin;
        g.yorumKapali = taze.yorumKapali;
        g.duzenlendi = taze.duzenlendi;
      });
    } catch (_) {
      // sessiz — ekranda zaten gecerli bir gonderi var
    }
  }

  Future<void> _cek() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final g = await ref
          .read(sosyalServisiProvider)
          .gonderiGetir(widget.gonderiId!);
      if (!mounted) return;
      setState(() {
        _g = g;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      setState(() {
        _yukleniyor = false;
        _hata = s.contains('403')
            ? 'Bu hesap gizli'
            : s.contains('404')
            ? 'Gönderi bulunamadı ya da kaldırıldı'
            : 'Gönderi açılamadı';
      });
    }
  }

  /// ⚠️ TURU 99 — demo yorumlarini gorunum modeline cevirir ve secili
  ///    siralamaya gore dizer.
  ///
  /// ⚠️ "Başlıca" = en cok begeni · "Yakınlarda" = en yeni. Sunucuda
  ///    siralama parametresi YOK; gercek hat baglandiginda uc bir
  ///    `?sirala=` almali, yoksa bu secici GORSEL kalir.
  List<YorumGorunum> _siraliYorumlar(String gonderiId) {
    final l = demoYorumlar(gonderiId).map(_cevir).toList();
    if (_sirala == 'baslica') {
      l.sort((a, b) => b.begeni.compareTo(a.begeni));
    }
    return l;
  }

  YorumGorunum _cevir(DemoYorum d) => YorumGorunum(
    id: d.kullaniciAdi + d.zaman,
    ad: d.ad,
    kullaniciAdi: d.kullaniciAdi,
    zaman: d.zaman,
    metin: d.metin,
    onayli: d.onayli,
    yazarMi: d.sahibi,
    sahipBegendi: d.begendim,
    begeni: d.begeni,
    yorum: d.yorum,
    repost: d.repost,
    paylas: d.paylas,
    yanitlar: d.yanitlar.map(_cevir).toList(),
    medya: d.medya,
    medyaTur: d.medyaTur,
  );

  Future<void> _siralaSec() async {
    final s = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in const [
              ('baslica', 'Başlıca'),
              ('yakin', 'Yakınlarda'),
            ])
              ListTile(
                title: Text(o.$2, style: const TextStyle(fontSize: 16)),
                trailing: _sirala == o.$1
                    ? const Icon(LucideIcons.check, size: 18)
                    : null,
                onTap: () => Navigator.pop(c, o.$1),
              ),
          ],
        ),
      ),
    );
    if (s != null && mounted) setState(() => _sirala = s);
  }

  /// ⚠️⚠️ KONU ETIKETI — **sunucuda karsiligi YOK** (bkz. cagri yerindeki
  ///	serh). Dokunus GERCEK arama ekranini acar; sayi demo verisidir.
  Widget _konuEtiketi(BuildContext context, Gonderi g) {
    const konu = 'Gebze';
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const IsletmeListesiEkrani(ara: konu),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kYanBosluk, 2, kYanBosluk, 10),
        child: Row(
          children: [
            Icon(
              LucideIcons.search,
              size: 15,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              konu,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '· 146 gönderi',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              LucideIcons.chevronRight,
              size: 15,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 99 — SABIT ALT YANIT KUTUSU (Threads).
  ///    Demoda dokunus sunucuya GITMEZ; gercek hat baglandiginda
  ///    `YorumlarSayfasi`daki gonderme yolu buraya tasinir.
  Widget _yanitKutusu(BuildContext context, Gonderi g) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 6, kYanBosluk, 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${g.yazarUsername.isEmpty ? g.yazarAd : g.yazarUsername}\'e yanıt ver...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final benimId = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    final g = _g;
    return Scaffold(
      // ⚠️⚠️⚠️ TURU 98i — THREADS DUZENI (kullanici ekran goruntusu):
      //	baslik **Yazışma**, altinda goruntulenme sayisi; sagda bildirim
      //	ve ••• dugmeleri.
      // ⚠️ Goruntulenme YALNIZ demoda yazilir; gercek gonderide sunucudan
      //    gelen goruntulenme alani kullanilir ve 0 ise HIC yazilmaz
      //    (uydurma sayi YOK).
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Yazışma', style: TextStyle(fontSize: 17)),
            if ((g?.goruntulenme ?? 0) > 0)
              Text(
                '${sayiBicimle(g!.goruntulenme)} görüntüleme',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: g == null ? null : _yanitKutusu(context, g),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : g == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_hata ?? 'Gönderi açılamadı'),
                  if (widget.gonderiId != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _cek,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ],
              ),
            )
          : ListView(
              children: [
                GonderiKarti(
                  key: ValueKey(g.id),
                  gonderi: g,
                  benimId: benimId,
                  detayda: true,
                  profileGit: (uid) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilSayfasi(userId: uid),
                    ),
                  ),
                  // Silinince bu sayfada kalacak bir sey yok.
                  onSilindi: () => Navigator.of(context).pop(),
                ),
                // ⚠️⚠️ TURU 98i — YORUM BOLUMU (Threads duzeni, kullanici
                //	ekran goruntusu): ayrac satiri + threadli yorumlar.
                // ⚠️ YALNIZ DEMODA: gercek yorum hatti YorumlarSayfasinda
                //    duruyor ve DEGISMEDI.
                // ---- KONU ETIKETI ("Çayırova · 146 gönderi >")
                //
                // ⚠️⚠️⚠️ **SUNUCUDA KONU DIYE BIR SEY YOK**: tablo yok,
                //	`posts.konu_id` yok, uc yok, sayac yok, arama yuklemi
                //	yok (grep: sifir eslesme). Bu satir bir ALT SISTEMIN
                //	vitrini; demo disinda cizilirse dokunulan ama BOS ekran
                //	acan bir baglanti olur (turu 93b sinifi).
                // ⚠️ Demoda bile dokunus GERCEK arama ekranini acar —
                //    sahte sonuc uydurulmaz.
                if (kDemoAkis) _konuEtiketi(context, g),
                if (kDemoAkis) ...[
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        // ⚠️ TURU 99 — dokununca ACILIR MENU (Threads).
                        InkWell(
                          onTap: _siralaSec,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _sirala == 'baslica'
                                      ? 'Başlıca'
                                      : 'Yakınlarda',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(LucideIcons.chevronDown, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GonderiHareketleri(gonderi: g),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Hareketi gör',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                                Icon(
                                  LucideIcons.chevronRight,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final y in _siraliYorumlar(g.id)) ...[
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.06),
                    ),
                    // ⚠️ TURU 99b — cizgi GRUBUN olugunda cizilir.
                    YorumGrubu(
                      kok: y,
                      acik: _acikYanitlar.contains(y.id),
                      onYanitlariGoster: () => setState(() {
                        _acikYanitlar.contains(y.id)
                            ? _acikYanitlar.remove(y.id)
                            : _acikYanitlar.add(y.id);
                      }),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ],
            ),
    );
  }
}

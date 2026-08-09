import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_screen.dart' show myProfileProvider;
import '../kanal/kanallar_sekmesi.dart';
import 'bildirim_sayaci.dart';
import 'bildirimler_sayfasi.dart';
import 'gonderi_karti.dart';
import 'hizmet_menusu.dart';
import 'gonderi_olustur.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';
import 'story_seridi.dart';

/// ⚠️⚠️ TURU 75 — ANA SAYFA AKISI (Instagram/Facebook duzeni).
///
/// ⚠️ SAYFALAMA IMLECLI (cursor): son gonderinin `created_at`i `before` olarak
///    gonderilir. `offset` KULLANILMAZ — yeni gonderi gelince satirlar kayar ve
///    ayni gonderi iki kez gorunur.
///
/// ⚠️ SOGUK BASLANGIC: kimseyi takip etmeyen kullaniciya BOS EKRAN gosterilmez;
///    sunucu "kesfet" (herkese acik yeni gonderiler) doner ve ustte serit cikar.
///    Bos akis yeni kullanicinin urunu terk etme sebebidir.
class AkisEkrani extends ConsumerStatefulWidget {
  const AkisEkrani({super.key});

  @override
  ConsumerState<AkisEkrani> createState() => _AkisEkraniState();
}

class _AkisEkraniState extends ConsumerState<AkisEkrani>
    with AutomaticKeepAliveClientMixin {
  final _kaydirma = ScrollController();
  final List<Gonderi> _liste = [];
  bool _ilkYukleme = true;
  bool _dahaVar = true;
  bool _yukleniyor = false;
  bool _kesfet = false;
  String? _hata;

  /// ⚠️ AKIS mi KANALLAR mi. Kanallar AYRI ALT SEKME YAPILMADI: alt menude
  ///    zaten 6 hedef var ve 7.'si etiketleri okunmaz hale getirir.
  int _bolme = 0;

  /// ⚠️ TURU 76b — hikaye seridine erisim: akis YENILENINCE serit de
  ///    yenilenmeli (yeni hikaye paylasan biri aninda gorunsun).
  final _storyKey = GlobalKey<StorySeridiDurumu>();

  /// ⚠️ IndexedStack icinde oldugumuz icin sekme degisince state KORUNUR; ama
  ///    `AutomaticKeepAlive` olmadan ListView kaydirma konumu kaybolabiliyor.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _kaydirma.addListener(_kaydirmaDinle);
    _yenile();
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  void _kaydirmaDinle() {
    if (!_kaydirma.hasClients) return;
    final kalan =
        _kaydirma.position.maxScrollExtent - _kaydirma.position.pixels;
    // 800px kala sonrakini getir — kullanici "yukleniyor" gormeden akmali.
    if (kalan < 800) _dahaGetir();
  }

  Future<void> _yenile() async {
    if (_yukleniyor) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      // ⚠️ Serit de tazelenir — asagi cekince yalniz gonderiler yenilenseydi
      //    yeni hikayeler gorunmezdi.
      unawaited(_storyKey.currentState?.yukle() ?? Future.value());
      final s = await ref.read(sosyalServisiProvider).akis();
      if (!mounted) return;
      setState(() {
        _liste
          ..clear()
          ..addAll(s.gonderiler);
        _kesfet = s.kesfet;
        _dahaVar = s.gonderiler.isNotEmpty;
        _ilkYukleme = false;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ilkYukleme = false;
        _yukleniyor = false;
        _hata = 'Akış yüklenemedi';
      });
    }
  }

  Future<void> _dahaGetir() async {
    if (_yukleniyor || !_dahaVar || _liste.isEmpty) return;
    setState(() => _yukleniyor = true);
    try {
      final s = await ref
          .read(sosyalServisiProvider)
          .akis(before: _liste.last.createdAt);
      if (!mounted) return;
      setState(() {
        // ⚠️ TEKRAR SUZGECI: imlec sinirinda ayni saniyede olusmus gonderiler
        //    hem onceki hem yeni sayfada gelebilir. Id'ye gore eliyoruz —
        //    yoksa listede CIFT KART cizilir (ve `Key` cakismasi patlatir).
        final mevcut = _liste.map((g) => g.id).toSet();
        final yeni = s.gonderiler.where((g) => !mevcut.contains(g.id)).toList();
        _liste.addAll(yeni);
        _dahaVar = s.gonderiler.isNotEmpty;
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
    }
  }

  void _profileGit(String userId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: userId)));
  }

  Future<void> _olustur({bool reels = false}) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => GonderiOlustur(reels: reels)),
    );
    // Paylasildiysa akisi bastan getir — kendi gonderini EN USTTE gormelisin.
    if (id != null && mounted) {
      unawaited(_yenile());
      // Profil sayaci (`gonderi_sayisi`) degisti.
      ref.invalidate(myProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final benimId = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();

    return Scaffold(
      appBar: AppBar(
        // ⚠️⚠️ TURU 76b — SOL UST HAMBURGER (kullanici emri: "anasayfada sol
        //    ustte menu ikonu olsun, 2 satir cizgi").  KULLANILDI:
        //    Akis kok route oldugu icin AppBar oraya geri oku KOYMAZ, cakisma YOK.
        leadingWidth: 46,
        leading: const HamburgerDugmesi(),
        // ⚠️ Baslik yerine BOLME SECICI: "Akış | Kanallar". Kullanicinin kanal
        //    diye bir sey oldugunu GORMESI icin tek yol bu (gizli menu degil).
        title: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Akış')),
            ButtonSegment(value: 1, label: Text('Kanallar')),
          ],
          selected: {_bolme},
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
          ),
          onSelectionChanged: (v) => setState(() => _bolme = v.first),
        ),
        actions: [
          // ⚠️⚠️ TURU 76 — BURADAKI "Reels" DUGMESI KALDIRILDI. Reels artik ALT
          //    MENUDE kendi sekmesi. Ikisini birden birakmak, kullanicinin ayni
          //    ekrani IKI FARKLI yoldan (biri route PUSH'u, digeri sekme)
          //    acabilmesi demekti; push edilen kopya sekme degistirilince
          //    ustte KALIR ve iki oynatici ayni anda yasayabilirdi.
          //    ⚠️ YAPMA: bu dugmeyi geri ekleme.
          // TURU 76: okunmamis rozeti. Sayac WS 'bildirim.yeni' olayinda yerel
          // olarak artar, sayfaya girilince sifirlanir.
          BildirimRozeti(
            child: IconButton(
              icon: const Icon(LucideIcons.bell),
              tooltip: 'Bildirimler',
              onPressed: () async {
                ref.read(bildirimSayaciProvider.notifier).sifirla();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BildirimlerSayfasi()),
                );
                // Sayfada 'okundu' isaretlendi; sunucuyla hizala.
                if (context.mounted) {
                  unawaited(ref.read(bildirimSayaciProvider.notifier).tazele());
                }
              },
            ),
          ),
        ],
      ),
      // ⚠️ FAB yalniz AKIS bolmesinde: kanallar bolmesinin kendi "Kanal aç"
      //    dugmesi var, ust uste binerlerdi.
      floatingActionButton: _bolme == 0
          ? FloatingActionButton(
              // TURU 76: HERO ETIKETI ZORUNLU. Ucun de varsayilan etiketi paylasmasi
              // debug/profile derlemede route gecisinde KIRMIZI EKRAN uretiyordu;
              // release'te assert silindigi icin sessizce SON hero yaziliyor ve
              // ucus YANLIS dugmeyi tasiyordu.
              heroTag: 'fabGonderiOlustur',
              onPressed: _olustur,
              child: const Icon(LucideIcons.plus),
            )
          : null,
      // ⚠️ IndexedStack: bolme degisince kaydirma konumu ve yuklenmis liste
      //    KORUNUR. TabBarView olsaydi komsu bolme dispose olur ve her geciste
      //    yeniden ag istegi atilirdi.
      body: IndexedStack(
        index: _bolme,
        children: [
          RefreshIndicator(onRefresh: _yenile, child: _govde(benimId)),
          const KanallarSekmesi(),
        ],
      ),
    );
  }

  Widget _govde(String benimId) {
    if (_ilkYukleme) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null && _liste.isEmpty) {
      return ListView(
      // ⚠️⚠️ TURU 77b — AlwaysScrollableScrollPhysics ZORUNLU (denetim bulgusu).
      //    Icerik ekrani DOLDURMAYINCA Android varsayilani
      //    (ClampingScrollPhysics) kullanici kaydirmasini KABUL ETMEZ ->
      //    sarmalayici RefreshIndicator TETIKLENMEZ. Ustelik AkisEkrani
      //    IndexedStack icinde CANLI kaldigi icin sekme degistirip donmek de
      //    yeniden yuklemiyordu: YENI kullanici uygulamayi OLDURMEDEN akisini
      //    TAZELEYEMIYORDU (bos akis = tam da yeni kullanicinin durumu).
      //    ⚠️ YAPMA: bos/hata dallarindan bu satiri kaldirma.
      physics: const AlwaysScrollableScrollPhysics(),
        children: [
          StorySeridi(key: _storyKey),
          const SizedBox(height: 120),
          Center(child: Text(_hata!)),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: _yenile,
              child: const Text('Tekrar dene'),
            ),
          ),
        ],
      );
    }
    if (_liste.isEmpty) {
      return ListView(
      // ⚠️⚠️ TURU 77b — AlwaysScrollableScrollPhysics ZORUNLU (denetim bulgusu).
      //    Icerik ekrani DOLDURMAYINCA Android varsayilani
      //    (ClampingScrollPhysics) kullanici kaydirmasini KABUL ETMEZ ->
      //    sarmalayici RefreshIndicator TETIKLENMEZ. Ustelik AkisEkrani
      //    IndexedStack icinde CANLI kaldigi icin sekme degistirip donmek de
      //    yeniden yuklemiyordu: YENI kullanici uygulamayi OLDURMEDEN akisini
      //    TAZELEYEMIYORDU (bos akis = tam da yeni kullanicinin durumu).
      //    ⚠️ YAPMA: bos/hata dallarindan bu satiri kaldirma.
      physics: const AlwaysScrollableScrollPhysics(),
        children: [
          StorySeridi(key: _storyKey),
          const SizedBox(height: 100),
          const Icon(LucideIcons.images, size: 54, color: Colors.grey),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Henüz gönderi yok.\nİlk paylaşımı sen yap ya da birilerini takip et.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _kaydirma,
      // ⚠️ ILK OGE HER ZAMAN HIKAYE SERIDI (kullanici emri: 'anasayfada
      //    storyler'). Serit akisla BIRLIKTE kayar (Instagram deseni) —
      //    sabit birakmak 106px'i kalici olarak yer.
      // +1 hikaye seridi / +1 kesfet seridi / +1 alt yukleme gostergesi
      itemCount: _liste.length + 1 + (_kesfet ? 1 : 0) + 1,
      itemBuilder: (_, i) {
        if (i == 0) return StorySeridi(key: _storyKey);
        var idx = i - 1;
        if (_kesfet) {
          if (idx == 0) return _kesfetSeridi();
          idx = idx - 1;
        }
        if (idx >= _liste.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: _dahaVar
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Hepsi bu kadar',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
            ),
          );
        }
        final g = _liste[idx];
        return GonderiKarti(
          // ⚠️ ANAHTAR ZORUNLU: anahtarsiz, liste yenilenince Flutter kart
          //    state'ini (begeni animasyonu, sayfa indeksi) YANLIS karta tasir.
          key: ValueKey(g.id),
          gonderi: g,
          benimId: benimId,
          profileGit: _profileGit,
          onSilindi: () =>
              setState(() => _liste.removeWhere((x) => x.id == g.id)),
        );
      },
    );
  }

  Widget _kesfetSeridi() => Container(
    width: double.infinity,
    color: const Color(0x228B5CF6),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: const Row(
      children: [
        Icon(LucideIcons.compass, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Keşfet — kimseyi takip etmiyorsun. Beğendiğin kişileri takip et, akışın kişiselleşsin.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

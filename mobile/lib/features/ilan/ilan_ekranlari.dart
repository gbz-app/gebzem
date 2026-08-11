import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../vitrin/vitrin_slider.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import '../sosyal/gonderi_karti.dart' show gonderiZamani;
import '../sosyal/medya_video.dart';
import '../sosyal/profil_sayfasi.dart';
import 'basvuru_ekranlari.dart';
import 'ilan_servisi.dart';

/// ⚠️⚠️ TURU 77 — ILAN LISTESI (sahibinden deseni).
///
/// [tur] bos = tum ilanlar; 'hizmet' = HIZMETLER karti.
class IlanListesiEkrani extends ConsumerStatefulWidget {
  const IlanListesiEkrani({
    super.key,
    this.tur = '',
    this.baslik = '',
    this.benim = false,
  });

  final String tur;
  final String baslik;

  /// ⚠️ TURU 77b — Profildeki **"İlanlarım"** girisi bu bayragi ACAR.
  ///    Eskiden parametre YOKTU: menu "İlanlarım" diyor ama HERKESIN ilanini
  ///    listeleyen ekran aciliyordu; ustelik sunucu `durum='yayinda'` suzdugu
  ///    icin kullanici KENDI 'satildi' ilanini HIC goremiyordu.
  final bool benim;

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
  late bool _benim = widget.benim;
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
          // ⚠️⚠️ TURU 90b — "BASVURULARIM" GIRISI.
          //
          // Ekrani yazmak YETMEZ; ona GIDEN yol yoksa ozellik yine olu
          // kalir. Kullanici basvurusunun durumunu (Olumlu/Olumsuz) ancak
          // buradan gorebilir ve geri cekme yolu da yalniz orada.
          // ⚠️ YALNIZ IS ILANI listesinde cizilir: vasita/emlak listesinde
          //    "Başvurularım" anlamsiz olurdu.
          // ⚠️⚠️ TURU 90c — `_tur`, `widget.tur` DEGIL (denetim bulgusu).
          //    `widget.tur` yalnizca ILK turdur ve SABITTIR; kullanici tur
          //    cipine dokununca (satir ~280) degisen `_tur`dur. Kapi sabite
          //    bagliyken: menuden "Ilanlar"a (tursuz) girip tur cipinden
          //    "Is" secen kullanici, ekran IS ILANLARINI GOSTERDIGI HALDE
          //    "Basvurularim" girisini HIC GORMUYORDU — yani ayni kuralin
          //    iki kopyasi (kapi vs. icerik) DRIFT ETMISTI.
          if (_tur == 'is')
            IconButton(
              tooltip: 'Başvurularım',
              icon: const Icon(LucideIcons.briefcase),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BasvurularimEkrani()),
              ),
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
          // ---- UST VITRIN (organik: yaklasan etkinlikler). Bos ise CIZILMEZ.
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: VitrinSlider(dikey: _tur.isEmpty ? 'ilan' : _tur),
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
                : YenileSarmali(
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
            // ⚠️ TEK KAYNAK: ilk FOTOGRAFI secer; yalniz video varsa video yer
            //    tutucusu cizer (video id'sini MedyaGorsel'e vermek KIRIK
            //    GORSEL demekti — bkz. KapakGorseli serhi).
            : KapakGorseli(
                mediaIds: i.mediaIds,
                mediaKinds: i.mediaKinds,
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

  @override
  void initState() {
    super.initState();
    _sessizTazele();
  }

  /// ⚠️⚠️⚠️ TURU 77b — GORUNTULENME SAYACI (denetim bulgusu).
  ///
  /// Sunucu sayaci **YALNIZ `GET /ilanlar/{id}` icinde** artiriyor. Detay
  /// ekrani ise listeden gelen HAZIR `Ilan` NESNESIYLE aciliyordu ve o istek
  /// **HIC ATILMIYORDU** -> ekranda yazan "N görüntülenme" sahada **OMUR BOYU
  /// 0** kalirdi. Bir satici icin ilanin ise yarayip yaramadigini gosteren TEK
  /// sinyal olu olurdu.
  /// 📌 Bu, turu 76'da GONDERI DETAYINDA yasanip duzeltilen hatanin BIREBIR
  ///    tekrari; ayni cozum uygulaniyor.
  ///
  /// ⚠️⚠️ NESNE DEGISTIRILMEZ, ALANLARI GUNCELLENIR. `i = yeni` yazilsaydi
  ///    model listeyle PAYLASILDIGI icin detayda yapilan favori/durum
  ///    degisikligi geri donuldugunde LISTEDE GORUNMEZDI (turu 76 notu).
  /// ⚠️ Hata YUTULUR: sayac tazelemesi ekrani BOZMAMALI.
  Future<void> _sessizTazele() async {
    try {
      final yeni = await ref.read(ilanServisiProvider).detay(i.id);
      if (!mounted) return;
      setState(() {
        // ⚠️⚠️ NESNE DEGISTIRILMEZ, ALANLARI GUNCELLENIR. `i = yeni` yazilsaydi
        //    liste ESKI ornegi tutmaya devam ederdi ve kullanici geri
        //    donduğunde duzenledigi ilani ESKI haliyle gorurdu (turu 76 dersi).
        i.goruntulenme = yeni.goruntulenme;
        i.durum = yeni.durum;
        i.favorim = yeni.favorim;
        // ---- TURU 78: duzenleme sonrasi degisen alanlar
        i.baslik = yeni.baslik;
        i.aciklama = yeni.aciklama;
        i.fiyatKurus = yeni.fiyatKurus;
        i.fiyatGizli = yeni.fiyatGizli;
        i.kategori = yeni.kategori;
        i.il = yeni.il;
        i.ilce = yeni.ilce;
        i.duzenlendiAt = yeni.duzenlendiAt;
        // ⚠️ Liste REFERANSI korunur, ICERIGI degisir — dis kod (galeri
        //    gostergesi) ayni listeyi tutuyor olabilir.
        // ⚠️ mediaIds ve mediaKinds ARDISIK iki satir — bir daha AYRILMASINLAR.
        //    Biri guncellenip oteki bayat kalirsa galeri YANLIS TIP cizer.
        i.mediaIds
          ..clear()
          ..addAll(yeni.mediaIds);
        i.mediaKinds
          ..clear()
          ..addAll(yeni.mediaKinds);
        i.ozellikler
          ..clear()
          ..addAll(yeni.ozellikler);
      });
    } catch (_) {
      // sessiz
    }
  }

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
  /// ⚠️⚠️ TURU 78 — ILAN BAGLAMLI SOHBET.
  ///
  /// Eskiden duz `POST /chats/direct` cagriliyordu ve mesaj ILAN BAGLAMI
  /// TASIMIYORDU: 20 ilani olan bir satici gelen mesajin HANGI ILAN icin
  /// oldugunu bilemiyor, her seferinde sormak zorunda kaliyordu.
  /// Yeni uc ILAN BASINA AYRI sohbet acar (sahibinden/Letgo davranisi) ve
  /// sohbet listesinde ilan basligi alt yazi olarak gorunur.
  /// ⚠️ YAPMA: `/chats/direct`e geri donme.
  /// ⚠️ TURU 78b — CIFT DOKUNMA KILIDI (denetim bulgusu). `sohbetAc` bir ag
  ///    cagrisidir; dugme cagri boyunca ETKIN kaliyordu ve iki dokunus AYNI
  ///    sohbet ekranini yigina IKI KEZ push ediyordu (kullanici geri tusuna iki
  ///    kez basmak zorunda kalir, "uygulama takildi" hissi verir).
  ///    ⚠️ `finally` ile SIFIRLANIR — hata dalinda kilitli kalirsa dugme bir
  ///       daha calismaz.
  bool _mesajMesgul = false;

  /// ⚠️ TURU 90b — YALNIZ BU OTURUMDAKI dokunusu yansitir, "sunucuda
  ///    basvurum var mi" DEGIL. Sunucu bugun tekil basvuru durumu donduren
  ///    bir uc sunmuyor; ekran acilisinda `Basvurularim` listesini cekip
  ///    aramak, her ilan detayinda FAZLADAN bir istek demekti.
  /// ⚠️ Yaniltici DEGIL: uc IDEMPOTENT (tekrar basvuru 200) ve kullanici
  ///    gercek durumu **Başvurularım** ekraninda goruyor.
  bool _basvurdum = false;

  Future<void> _basvur() async {
    final ok = await basvurSheet(context, ref, i.id, i.baslik);
    if (ok && mounted) {
      setState(() => _basvurdum = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Başvurun gönderildi — durumu "Başvurularım"da '
              'takip edebilirsin')));
    }
  }

  Future<void> _saticiyaMesaj() async {
    if (_mesajMesgul) return;
    _mesajMesgul = true;
    try {
      final chatId = await ref.read(ilanServisiProvider).sohbetAc(i.id);
      if (!mounted || chatId.isEmpty) return;
      context.push(
        '/chat/$chatId',
        extra: {
          'title': i.sahibiAd,
          'peer_id': i.sahibiId,
          'avatar_media_id': i.sahibiAvatarMediaId,
        },
      );
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      _mesajMesgul = false;
    }
  }

  /// ⚠️ TURU 78 — DUZENLEME. Ayri bir ekran YOK: "İlan ver" ekrani
  ///    `ilan:` parametresiyle DUZENLEME modunda acilir (tek kaynak).
  Future<void> _duzenle() async {
    final degisti = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => IlanVerEkrani(ilan: i)));
    if (degisti != true || !mounted) return;
    // ⚠️ Yerel nesneyi YAMAMAK yerine SUNUCUDAN tazeliyoruz: `duzenlendi_at`
    //    ve `media_kinds` gibi alanlari SUNUCU uretiyor.
    await _sessizTazele();
    if (mounted) {
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('İlan güncellendi')),
      );
    }
  }

  Future<void> _durumDegistir(String durum) async {
    try {
      await ref.read(ilanServisiProvider).guncelle(i.id, {'durum': durum});
      if (!mounted) return;
      setState(() => i.durum = durum);
      // ⚠️ TURU 77b — GERI BILDIRIM ZORUNLU: durum rozeti YALNIZ liste
      //    satirinda ciziliyor, dolayisiyla detayda basan kullanici hicbir
      //    degisiklik gormuyordu ve islemin olup olmadigini bilemiyordu.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            durum == 'satildi'
                ? 'İlan "Satıldı" olarak işaretlendi'
                : durum == 'kaldirildi'
                ? 'İlan kaldırıldı'
                : 'İlan yeniden yayında',
          ),
        ),
      );
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
              // ⚠️⚠️ TURU 78 — "Düzenle" BURAYA EKLENDI. Duzenleme ekrani
              //    yazilip HICBIR DUGMEYE BAGLANMASAYDI ozellik ULASILAMAZ
              //    olurdu; bu projede "olu dogmus ozellik" hatasi BES kez
              //    tekrarladi (gizli hesap, kaydedilenler, goruntulenme,
              //    blocks, urun 'tukendi').
              onSelected: (v) {
                if (v == 'duzenle') {
                  _duzenle();
                } else {
                  _durumDegistir(v);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
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
                  // ⚠️⚠️ TURU 78 — KARMA GALERI (foto + video).
                  //    Tur bilgisi `media_kinds`ten gelir ve sunucu SIRA
                  //    KORUYARAK donduruyor: `mediaKinds[k]` <-> `mediaIds[k]`.
                  //    Bu dizi olmasaydi video id'si `MedyaGorsel`e verilir ve
                  //    KIRIK GORSEL cizilirdi (kanal gonderilerinde turu 76b'ye
                  //    kadar tam bu sorun vardi).
                  // ⚠️ Eski sunucudan bos gelirse hepsi FOTOGRAF sayilir —
                  //    guvenli varsayilan.
                  PageView.builder(
                    itemCount: i.mediaIds.length,
                    onPageChanged: (p) => setState(() => _sayfa = p),
                    itemBuilder: (_, k) {
                      final tur = k < i.mediaKinds.length
                          ? i.mediaKinds[k]
                          : 'image';
                      if (tur == 'yok') {
                        // Silinmis medya — dürüst bir yer tutucu.
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
                        // ⚠️⚠️ `otoOynat: false` + `sesli: false` ZORUNLU.
                        //    iOS'ta ses oturumu PROSES GENELINDE TEKTIR;
                        //    ilan detayinda kendiliginden calan bir video
                        //    SUREN ARAMAYI SAGIRLASTIRIR (turu 64/65/73).
                        //    Kullanici oynat dugmesine BASARAK baslatir.
                        // ⚠️ YAPMA: buraya akistaki otomatik oynatmayi tasima.
                        return MedyaVideo(
                          mediaId: i.mediaIds[k],
                          otoOynat: false,
                          sesli: false,
                          // ⚠️⚠️ TURU 78b — `dongu: false` (denetim bulgusu).
                          //    Varsayilan `true`dur ve akis kartlari icin
                          //    dogrudur (kisa reels dongusu). Ilan galerisinde
                          //    ise video bitince BASA DONUP sonsuza kadar
                          //    calmaya devam ediyordu; kullanici baska sekmeye
                          //    gecince pil/veri yakiyor, sesi acilmissa
                          //    kaynagi gorunmeyen bir ses birakiyordu.
                          dongu: false,
                          dolgu: BoxFit.cover,
                        );
                      }
                      return MedyaGorsel(
                        mediaId: i.mediaIds[k],
                        fit: BoxFit.cover,
                      );
                    },
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
                    // ⚠️⚠️ TURU 78b — "düzenlendi" ETIKETI (denetim bulgusu).
                    //    `duzenlendi_at` sunucuda yaziliyor, modelde tasiniyor
                    //    ama HICBIR EKRAN CIZMIYORDU: migration 034'un TEK
                    //    gerekcesi (ALICI GUVENI — fiyat/aciklama sessizce
                    //    degistirilebiliyorsa alici pazarlik ettigi seyin
                    //    aynisi oldugunu bilemez) sahaya ULASMIYORDU.
                    // ⚠️ TARIH GOSTERILMEZ, yalnizca "düzenlendi" — gonderi
                    //    tarafiyla ayni davranis; iki tarih yan yana
                    //    ("2 gün önce · 1 saat önce düzenlendi") kafa karistirir.
                    if (i.duzenlendiAt != null) 'düzenlendi',
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
                // ⚠️⚠️⚠️ TURU 90b — IS ILANINDA **BASVURU** YOLU.
                //
                // Turu 90 sunucuda bes uc acti ama ISTEMCIDE hicbir giris
                // yoktu; kullanicinin acik emri (*"normal kullanicilar
                // basvuru yapabilmeli"*) OLU DOGACAKTI.
                // ⚠️ Dugme TURE KAPILI (`tur == 'is'`): vasita/emlak
                //    ilaninda "Basvur" anlamsizdir ve sunucu da 400 doner.
                if (i.tur == 'is' && !benimIlanim) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _basvur,
                      icon: const Icon(LucideIcons.briefcase, size: 18),
                      label: Text(_basvurdum ? 'Başvurun alındı' : 'Başvur'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // ⚠️ SAHIBI icin basvuranlar listesi — yoksa gelen
                //    basvurulari GORECEK HICBIR YER olmazdi.
                if (i.tur == 'is' && benimIlanim) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BasvuranlarEkrani(
                              ilanID: i.id, baslik: i.baslik),
                        ),
                      ),
                      icon: const Icon(LucideIcons.users, size: 18),
                      label: const Text('Başvuranlar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (!benimIlanim)
                  SizedBox(
                    width: double.infinity,
                    child: i.tur == 'is'
                        ? OutlinedButton.icon(
                            onPressed: _saticiyaMesaj,
                            icon: const Icon(LucideIcons.messageCircle,
                                size: 18),
                            label: const Text('İlan sahibine mesaj'),
                          )
                        : FilledButton.icon(
                            onPressed: _saticiyaMesaj,
                            icon: const Icon(LucideIcons.messageCircle,
                                size: 18),
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
/// İlan ver **VE** ilan düzenle — **TEK EKRAN**.
///
/// ⚠️⚠️ TURU 78 — AYRI BIR "IlanDuzenleEkrani" YAZILMADI. Iki ekran olsaydi
///    alan listesi, dogrulama kurallari, tipe ozel form uretimi ve medya
///    yonetimi IKI KOPYA olurdu; bu projede "ayni kuralin iki kopyasi DRIFT
///    eder" hatasi ALTI kez tekrarladi (turu 72b/H, 75b/2, 77b).
///    [ilan] doluysa ekran DUZENLEME modundadir.
///
/// ⚠️ TUR (vasita/emlak/...) DUZENLEMEDE DEGISTIRILEMEZ: tur degisirse
///    `ozellikler` semasi tamamen degisir (vasitanin "vites"i emlakta
///    anlamsizdir) ve kategori gecersizlesir. Tur degistirmek YENI ILAN demektir.
///    Sunucu da `tur` alanini PATCH'te KABUL ETMIYOR.
class IlanVerEkrani extends ConsumerStatefulWidget {
  const IlanVerEkrani({super.key, this.tur = '', this.ilan});
  final String tur;

  /// Doluysa DUZENLEME modu.
  final Ilan? ilan;

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

  /// YENI secilen (henuz yuklenmemis) dosyalar.
  final List<File> _gorseller = [];

  /// ⚠️ TURU 78 — YENI secilen VIDEOLAR (ayri liste: yukleme `kind`i farkli —
  ///    'video' vs 'image' — ve sikistirma yolu da farkli; videoya
  ///    `gorseliHazirla` UYGULANMAZ).
  final List<File> _videolar = [];

  /// ⚠️ Ilan basina VIDEO tavani. Toplam medya tavani (12) AYRI ve USTTEDIR.
  ///    3 secildi: bir arac/ev ilaninda 1-2 tanitim videosu yeterli; daha
  ///    fazlasi hem R2 maliyeti hem alici icin gorulmeyen icerik.
  static const _enFazlaVideo = 3;

  /// ⚠️ Gonderi tarafiyla AYNI tavan — ucuncu bir sure siniri UYDURULMADI.
  static const _videoSuresi = Duration(minutes: 5);

  /// ⚠️ DUZENLEMEDE: sunucuda ZATEN duran medya id'leri. Kullanici bunlardan
  ///    silebilir; kaydederken "kalanlar + yeni yuklenenler" gonderilir.
  ///    Yeni dosya ile mevcut id'yi tek listede tutmak mumkun degildi
  ///    (biri `File`, oteki `String`) — iki liste bilincli.
  final List<String> _mevcutMedya = [];

  /// ⚠️⚠️ TURU 78b — `_mevcutMedya[k]` ile **AYNI SIRADA** tur bilgisi.
  ///    Bu liste OLMADAN serit bir VIDEO id'sini `MedyaGorsel`e veriyordu ve
  ///    **KIRIK GORSEL** ciziyordu; kullanici videosunu bozulmus sanip
  ///    silebilirdi (geri alinamaz kayip).
  /// ⚠️ IKI LISTE **BIRLIKTE** degisir — ekleme/silmede ikisine de dokun.
  ///    Ayrildiklari an serit YANLIS TIP cizer (ayni kural `Ilan` modelinde de
  ///    ardisik iki satir olarak duruyor).
  final List<String> _mevcutTurler = [];

  String _tur = '';
  String _kategori = '';
  bool _fiyatGizli = false;
  bool _kaydediliyor = false;

  bool get _duzenleme => widget.ilan != null;

  @override
  void initState() {
    super.initState();
    final i = widget.ilan;
    if (i == null) {
      _tur = widget.tur;
      return;
    }
    // ---- DUZENLEME: mevcut degerlerle doldur
    _tur = i.tur;
    _kategori = i.kategori;
    _baslik.text = i.baslik;
    _aciklama.text = i.aciklama;
    _il.text = i.il;
    _ilce.text = i.ilce;
    _fiyatGizli = i.fiyatGizli;
    // ⚠️ KURUS -> TL. Tam sayiysa ondalik YAZILMAZ ("1500" gosterilir,
    //    "1500.00" degil) — kullanici kendi girdigi bicimi gormeli.
    if (!i.fiyatGizli && i.fiyatKurus > 0) {
      final tl = i.fiyatKurus / 100;
      _fiyat.text = tl == tl.roundToDouble()
          ? tl.round().toString()
          : tl.toStringAsFixed(2);
    }
    _mevcutMedya.addAll(i.mediaIds);
    // ⚠️⚠️ TURU 78b — TUR BILGISI DE TASINIR. Eskiden yalniz id'ler alinir,
    //    `i.mediaKinds` ATILIRDI; serit her ogeyi FOTOGRAF sanip video icin
    //    KIRIK GORSEL cizerdi. Eksik/kisa gelirse 'image' varsayilir.
    for (var k = 0; k < i.mediaIds.length; k++) {
      _mevcutTurler.add(k < i.mediaKinds.length ? i.mediaKinds[k] : 'image');
    }
    // ⚠️ `ozellikler` JSONB'den gelir; degerler METIN olarak tutuluyor
    //    (form alanlari metin). Sayi gelirse `toString` ile duzlestirilir.
    i.ozellikler.forEach((k, v) {
      if (v != null) _ozellikler[k] = v.toString();
    });
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
    final kalan = 12 - _mevcutMedya.length - _gorseller.length;
    if (kalan <= 0) {
      // ⚠️ Kok messenger: bu ekran bir alt-sayfadan acilmis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('En fazla 12 fotoğraf eklenebilir')),
      );
      return;
    }
    // ⚠️ TEK KAYNAK: limit<2 tuzagi + take(kalan) kirpmasi orada (MedyaSecici).
    final secim = await MedyaSecici.coklu(kalan);
    if (secim.isEmpty || !mounted) return;
    setState(() => _gorseller.addAll(secim.map((x) => File(x.path))));
  }

  /// ⚠️ TURU 78 — ILANA VIDEO (kullanici emri: "ilanda gorsel ve videolar
  ///    olacak"). Boyut + SURE kapisi `MedyaSecici.video` icinde (TEK KAYNAK).
  Future<void> _videoSec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    if (_videolar.length >= _enFazlaVideo) {
      _uyar('En fazla $_enFazlaVideo video eklenebilir');
      return;
    }
    // ⚠️ Video da TOPLAM 12 medya tavanina dahildir.
    if (_mevcutMedya.length + _gorseller.length + _videolar.length >= 12) {
      _uyar('En fazla 12 medya eklenebilir');
      return;
    }
    final dosya = await MedyaSecici.video(
      sureTavani: _videoSuresi,
      uyar: _uyar,
      ref: ref,
    );
    if (dosya == null || !mounted) return;
    setState(() => _videolar.add(dosya));
  }

  /// ⚠️ Kok messenger: bu ekran bir alt-sayfadan acilmis olabilir ve
  ///    `ScaffoldMessenger.of(context)` olu baglamda kalabilir.
  void _uyar(String m) {
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));
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
    // ⚠️⚠️ TURU 78b — SERVISLER **TUM AWAIT'LERDEN ONCE** YAKALANIR.
    //
    //    Bu ekranda `PopScope` YOK ve kaydetme uzun surer (12 medyaya kadar
    //    fotograf sikistirma + yukleme, ustelik VIDEO da var). Kullanici o
    //    sirada geri tusuna basarsa `State` **DISPOSE OLUR**; disposed bir
    //    `ConsumerState`te `ref.read` **`StateError` FIRLATIR**, asagidaki
    //    `catch` onu yutar ve `if (!mounted) return;` sessizce cikar.
    //    SONUC: medya R2'ye YUKLENMIS olur ama `POST /ilanlar` **HIC ATILMAZ**
    //    -> ilan olusmaz, medya YETIM kalir, kullaniciya HICBIR SEY soylenmez.
    //
    //    ⚠️ Bu, turu 77b'de HIKAYE PAYLASIMINDA sahaya cikan hatanin BIREBIR
    //       aynisidir ve duzeltmesi `story_seridi.dart:122`de duruyor; turu
    //       78'in yeni ekranlari o dersi TEKRARLADI.
    //    ⚠️ YAPMA: bu iki satiri await'lerin ALTINA tasima.
    //    ⚠️ Servis yakalandigi icin is, kullanici ekrandan ciksa bile TAMAMLANIR
    //       (ilan GERCEKTEN olusur) — sessizce iptal etmekten iyisi budur.
    final medyaSvc = ref.read(medyaServisiProvider);
    final ilanSvc = ref.read(ilanServisiProvider);
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
      // ⚠️⚠️ VIDEO HAM GIDER — `gorseliHazirla` UYGULANMAZ (o bir GORSEL
      //    sikistiricisidir; videoya uygularsak dosya BOZULUR).
      // ⚠️⚠️ BILINCLI KABUL EDILEN RISK: video EXIF/`moov` icinde GPS
      //    tasiyabilir ve emlak ilaninda bu EV ADRESI demektir. Tespit kodu
      //    ayri bir is; kullaniciya form ustunde UYARI METNI gosteriliyor.
      //    ⚠️ Fotografta bu risk YOK (`gorseliHazirla` EXIF'i temizliyor).
      for (final v in _videolar) {
        idler.add(
          await medyaSvc.yukle(dosya: v, kind: 'video', mime: 'video/mp4'),
        );
      }
      final tl = double.tryParse(_fiyat.text.trim().replaceAll(',', '.')) ?? 0;
      // ⚠️ DUZENLEMEDE: KALAN mevcut medyalar + YENI yuklenenler. Sunucu
      //    `media_ids`i OLDUGU GIBI yazar (COALESCE), yani kullanicinin
      //    sildikleri bu listede olmadigi icin ilandan dusmus olur.
      final govde = <String, dynamic>{
        'kategori': _kategori,
        'baslik': _baslik.text.trim(),
        'aciklama': _aciklama.text.trim(),
        // ⚠️ KURUS'a cevrilir (sunucu kurus bekliyor — BIGINT tasma korumasi).
        'fiyat_kurus': _fiyatGizli ? 0 : (tl * 100).round(),
        'fiyat_gizli': _fiyatGizli,
        'il': _il.text.trim(),
        'ilce': _ilce.text.trim(),
        'media_ids': [..._mevcutMedya, ...idler],
        'ozellikler': Map.fromEntries(
          _ozellikler.entries.where((e) => e.value.trim().isNotEmpty),
        ),
      };
      if (_duzenleme) {
        await ilanSvc.guncelle(widget.ilan!.id, govde);
        if (!mounted) return;
        // ⚠️ `true` doner: cagiran ekran listeyi/detayi SUNUCUDAN tazeler.
        //    Yerel nesneyi yamamak yerine tazelemek, `duzenlendi_at` gibi
        //    SUNUCUNUN urettigi alanlarin da dogru gelmesini saglar.
        Navigator.of(context).pop(true);
        return;
      }
      // ⚠️ `tur` YALNIZ olusturmada gonderilir — PATCH'te sunucu kabul etmiyor.
      govde['tur'] = _tur;
      final id = await ilanSvc.olustur(govde);
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      // ⚠️ KOK MESSENGER: kullanici kaydetme surerken ekrandan CIKMIS olabilir;
      //    `ScaffoldMessenger.of(context)` o durumda olu baglamda kalir ve hata
      //    kullaniciya HIC ULASMAZDI ("paylastim sandim" sinifi).
      if (mounted) setState(() => _kaydediliyor = false);
      _uyar(apiErrorMessage(e));
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
        title: Text(_duzenleme ? 'İlanı düzenle' : 'İlan ver'),
        actions: [
          TextButton(
            onPressed: _kaydediliyor ? null : _kaydet,
            child: Text(_duzenleme ? 'Kaydet' : 'Yayınla'),
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
              // ⚠️⚠️⚠️ TURU 78b — DUZENLEMEDE TUR **KILITLI** (denetim bulgusu:
              //    VERI KAYBI). Serh "tur duzenlemede degistirilemez" diyordu
              //    ama GOVDEDE KAPI YOKTU.
              //
              //    Yasanacak senaryo: kullanici bir arac ilaninin FIYATINI
              //    duzeltmek icin girer, merakla Tur listesinden "Emlak" secer,
              //    sonra "Vasita"ya GERI doner. `onChanged` HER secimde
              //    `_kategori=''` + `_ozellikler.clear()` calistirir; geri
              //    donus de bir secimdir, yani temizlik IKI KEZ olur ve
              //    marka/model/yil/km/vites/yakit alanlari GERI GELMEZ.
              //    Kaydet'e basinca sunucuya `kategori:''` + `ozellikler:{}`
              //    gider, `COALESCE($8, kategori)` BOS DIZEYI yazar (NULL degil)
              //    ve ilan: kategorisiz + ozelliksiz kalir. Ekranda yesil
              //    "İlan güncellendi" cikar; kullanici kaybi SONRADAN fark eder
              //    ve GERI ALMA YOLU YOKTUR.
              //
              //    ⚠️ `onChanged: null` Dart'ta dropdown'i DEVRE DISI cizer —
              //       ayrica bir `enabled` bayragi gerekmez.
              //    ⚠️ YAPMA: bu kapiyi kaldirma. Tur degistirmek YENI ILAN demek.
              DropdownButtonFormField<String>(
                initialValue: _tur.isEmpty ? null : _tur,
                decoration: InputDecoration(
                  labelText: 'Tür',
                  border: const OutlineInputBorder(),
                  helperText: _duzenleme
                      ? 'Tür değiştirilemez — yeni ilan vermelisin'
                      : null,
                ),
                items: [
                  for (final t in turler)
                    DropdownMenuItem(value: t.anahtar, child: Text(t.ad)),
                ],
                onChanged: _duzenleme
                    ? null
                    : (v) => setState(() {
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
                // ⚠️ TURU 90b — IS ILANINDA ETIKET **MAAS**. Sunucudaki serh
                //    "istemci etiketi ture gore degistirir" diyordu ama
                //    etiketler SABITTI: is ilani verirken "Fiyat (₺)" yaziyordu.
                title: Text(_tur == 'is' ? 'Maaş belirtme' : 'Fiyat belirtme'),
              ),
              if (!_fiyatGizli)
                TextField(
                  controller: _fiyat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _tur == 'is' ? 'Maaş (₺ / ay)' : 'Fiyat (₺)',
                    border: const OutlineInputBorder(),
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
              // ---- DUZENLEMEDE: SUNUCUDA DURAN medyalar (silinebilir)
              // ⚠️ Yeni secilen dosyalardan AYRI listede: biri `File`, oteki
              //    sunucudaki `media_id`. Kaydederken ikisi BIRLESTIRILIR.
              if (_mevcutMedya.isNotEmpty)
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 10),
                    itemCount: _mevcutMedya.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, k) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 66,
                            height: 74,
                            // ⚠️ TURU 78b: ham `MedyaGorsel` DEGIL — video id'si
                            //    verilirse KIRIK GORSEL cizilirdi.
                            child: MedyaKucukResmi(
                              mediaId: _mevcutMedya[k],
                              tur: k < _mevcutTurler.length
                                  ? _mevcutTurler[k]
                                  : 'image',
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            // ⚠️ Yalniz LISTEDEN cikarir; medya sunucuda
                            //    SILINMEZ (veri politikasi). Kullanici
                            //    vazgecip kaydetmezse hicbir sey degismez.
                            // ⚠️ IKI LISTE BIRLIKTE dusurulur — ayrilirlarsa
                            //    kalan ogeler YANLIS TIP cizer.
                            // ⚠️ TURU 78b: dokunma alani 17x17 -> ~37x37
                            //    (etkinlik seridiyle AYNI gerekce).
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() {
                              _mevcutMedya.removeAt(k);
                              if (k < _mevcutTurler.length) {
                                _mevcutTurler.removeAt(k);
                              }
                            }),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 10, bottom: 10),
                              child: DecoratedBox(
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
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _gorselSec,
                      icon: const Icon(LucideIcons.imagePlus, size: 18),
                      // ⚠️ Sayac MEVCUT + YENI toplamini gosterir; yoksa
                      //    duzenlemede "0/12" yazip kullaniciyi 12 fotograf
                      //    daha ekleyebilecegi yanilgisina dusururdu.
                      label: Text(
                        'Fotoğraf '
                        '(${_mevcutMedya.length + _gorseller.length + _videolar.length}/12)',
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
              // ---- YENI SECILEN VIDEOLAR
              if (_videolar.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  // ⚠️ DURUST UYARI: fotograftaki EXIF'i temizliyoruz ama
                  //    videodaki konum verisini SILMIYORUZ (tespit ayri is).
                  //    Emlak ilaninda bu EV ADRESI demek — sessiz gecilemez.
                  child: Text(
                    'Videolar konum bilgisi taşıyabilir. Ev veya iş yeri '
                    'ilanlarında dikkatli ol.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _videolar.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, k) => Stack(
                      children: [
                        // ⚠️ Video ONIZLEMESI cizilmiyor: `MedyaVideo` yerel
                        //    dosyada oynatici KURAR ve iOS'ta ses oturumuna
                        //    dokunur. Formda 3 oynatici kurmak SUREN ARAMAYI
                        //    sagirlastirabilirdi (turu 64/65/73). Koyu bir
                        //    kutu + film ikonu YETERLI.
                        Container(
                          width: 66,
                          height: 74,
                          decoration: BoxDecoration(
                            color: const Color(0xFF14101C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.video,
                            color: Colors.white54,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _videolar.removeAt(k)),
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
              ],
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
  /// ⚠️⚠️⚠️ TURU 77b — **`key` ZORUNLU (SEVK ENGELIYDI).**
  ///
  /// Alanlar `ListView(children: [...])` icinde ve `SliverChildListDelegate`
  /// cocuklari ANAHTARSIZ `KeyedSubtree`ye sarar -> eslesme tamamen **INDEKS**
  /// bazlidir. Tur degisince `_ozellikler.clear()` yapiliyor ama widget'lar
  /// ayni indekste ayni tipte oldugu icin **ELEMENT YENIDEN KULLANILIYOR** ve
  /// Flutter'in `FormFieldState.didUpdateWidget`i `initialValue` degisimini
  /// YOK SAYIYOR. Somut sonuc (Vasita -> Emlak):
  ///   · "Marka" kutusundaki "Ford" yazisi kaliyor, etiket "Metrekare" oluyor,
  ///     ama `_ozellikler['m2']` BOS -> ilan EKSIK OZELLIKLE yayinlaniyor;
  ///   · "Vites: Yari otomatik" (indeks 2) secilipken tur degisirse yeni liste
  ///     2 elemanli olur, `_selectedIndex` 2'de kalir -> debug'da
  ///     `IndexedStack` ASSERT'i (KIRMIZI EKRAN), release'de BOS dropdown.
  /// Kullanici ekranda dolu bir deger GORDUGU icin doldurdugunu saniyor.
  ///
  /// `ValueKey('$_tur:...')` eleman kimligini degistirir -> state SIFIRLANIR.
  /// ⚠️ YAPMA: anahtari kaldirma veya tur onekini cikarma.
  Widget _alan(IlanAlani a) {
    final etiket = a.birim.isEmpty ? a.ad : '${a.ad} (${a.birim})';
    if (a.tip == 'secim') {
      return Padding(
        key: ValueKey('sec:$_tur:${a.anahtar}'),
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
      key: ValueKey('txt:$_tur:${a.anahtar}'),
      padding: const EdgeInsets.only(bottom: 10),
      // ⚠️⚠️⚠️ TURU 78b — `TextField` DEGIL `TextFormField` + `initialValue`
      //    (denetim bulgusu; turu 78'in MANSET ozelligini yarim birakiyordu).
      //
      //    `TextField`in `initialValue` alani YOKTUR ve burada `controller` da
      //    verilmemisti. `initState` mevcut ozellikleri `_ozellikler` haritasina
      //    dogru sekilde yukluyordu ama o degerler EKRANA HIC ULASMIYORDU:
      //    "İlanı düzenle" acildiginda SECIM alanlari (Yakit, Vites) DOLU,
      //    METIN/SAYI alanlari (Marka, Model, Yıl, Kilometre, Metrekare,
      //    Bulunduğu kat, Deneyim) BOS geliyordu. Kullanici kendi ilaninin
      //    bilgisini goremiyor; hepsini elle yeniden yazmadigi surece de bir
      //    seyi bozmus olmuyordu ama ozellik YARIM hissettiriyordu.
      //
      //    ⚠️ `ValueKey` ZORUNLU ve ZATEN VAR: `FormField.didUpdateWidget`
      //       `initialValue` degisimini YOK SAYAR, yani anahtar olmasaydi tur
      //       degisince element yeniden kullanilir ve "Metrekare" kutusunda
      //       "Ford" gorunurdu (turu 77b'de SAHAYA CIKAN hayalet-veri hatasi).
      //    ⚠️ YAPMA: `TextField`e geri donme; anahtari kaldirma.
      child: TextFormField(
        initialValue: _ozellikler[a.anahtar],
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

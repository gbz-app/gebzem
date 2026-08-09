import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import '../chats/moderasyon_sheet.dart';
import '../medya/tam_ekran_gorsel.dart';
import 'gorunurluk.dart';
import 'medya_video.dart';
import 'paylas_sheet.dart';
import 'sosyal_servisi.dart';
import 'yorumlar_sayfasi.dart';

/// ⚠️⚠️ TURU 75 — AKISTAKI GONDERI KARTI (Instagram/Facebook duzeni).
///
/// ⚠️ IYIMSER GUNCELLEME (optimistic update): begeni/kaydetme dokunusta ANINDA
///    cizilir, REST arkada gider. Sunucu HATA donerse **GERI ALINIR** ve kullaniciya
///    soylenir. Bu projede "gonderdim sandim ama gitmemis" defalarca yasandi —
///    sessiz basarisizlik YASAK.
/// ⚠️ YAPMA: begeniyi REST donene kadar bekletme (dokunus 300-800ms olu hissedilir).
class GonderiKarti extends ConsumerStatefulWidget {
  const GonderiKarti({
    super.key,
    required this.gonderi,
    required this.benimId,
    this.onSilindi,
    this.profileGit,
  });

  final Gonderi gonderi;
  final String benimId;
  final VoidCallback? onSilindi;
  final void Function(String userId)? profileGit;

  @override
  ConsumerState<GonderiKarti> createState() => _GonderiKartiState();
}

class _GonderiKartiState extends ConsumerState<GonderiKarti> {
  /// ⚠️ Yeniden giris kilidi: hizli cift dokunus iki REST atar; sunucu idempotent
  ///    ama sayac yerel olarak iki kez oynar (gorsel tutarsizlik).
  bool _mesgul = false;
  int _sayfa = 0;

  /// Cift dokunusta ucan kalp animasyonu.
  bool _kalpGoster = false;

  /// ⚠️ TURU 76b — bu kartin ekranda gorunen orani (0..1). Otomatik video
  ///    oynatmanin BIRINCI kapisi. Bkz. `sosyal/gorunurluk.dart`.
  double _gorunurOran = 0;

  Gonderi get g => widget.gonderi;

  Future<void> _begeniCevir({bool yalnizBegen = false}) async {
    if (_mesgul) return;
    if (yalnizBegen && g.begendim) {
      _kalpAnimasyonu();
      return;
    }
    final eskiDurum = g.begendim;
    final eskiSayi = g.begeniSayisi;
    setState(() {
      g.begendim = !eskiDurum;
      g.begeniSayisi = eskiSayi + (g.begendim ? 1 : -1);
      if (g.begeniSayisi < 0) g.begeniSayisi = 0;
    });
    if (g.begendim) _kalpAnimasyonu();
    unawaited(HapticFeedback.lightImpact());
    _mesgul = true;
    try {
      final s = ref.read(sosyalServisiProvider);
      if (g.begendim) {
        await s.begen(g.id);
      } else {
        await s.begeniGeriAl(g.id);
      }
    } catch (_) {
      if (!mounted) return;
      // ⚠️ GERI AL — yalan bir "beğendin" durumu birakmak, kullanicinin bir daha
      //    begenememesi demek (sunucu ile istemci kalici olarak ayrisir).
      setState(() {
        g.begendim = eskiDurum;
        g.begeniSayisi = eskiSayi;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Beğeni gönderilemedi')));
    } finally {
      _mesgul = false;
    }
  }

  void _kalpAnimasyonu() {
    setState(() => _kalpGoster = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _kalpGoster = false);
    });
  }

  Future<void> _kaydetCevir() async {
    final eski = g.kaydettim;
    setState(() => g.kaydettim = !eski);
    try {
      final s = ref.read(sosyalServisiProvider);
      eski ? await s.kaydetKaldir(g.id) : await s.kaydet(g.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => g.kaydettim = eski);
    }
  }

  Future<void> _yorumlariAc() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YorumlarSayfasi(gonderi: g, benimId: widget.benimId),
      ),
    );
    // ⚠️ TURU 75b: yorum sayfasi ARTIK deger DONDURMUYOR — sayaci PAYLASILAN
    //    model uzerinden (`g.yorumSayisi`) guncelliyor. Sebep: geri donus degeri
    //    icin gereken `PopScope(canPop:false)`, iPhone'da KENAR KAYDIRMA ile
    //    geri donusu tamamen kapatiyordu.
    // ⚠️ Bu yuzden burada yalniz YENIDEN CIZ; deger okuma YOK.
    if (mounted) setState(() {});
  }

  Future<void> _menu() async {
    final benim = g.yazarId == widget.benimId;
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.link),
              title: const Text('Bağlantıyı kopyala'),
              onTap: () => Navigator.pop(c, 'link'),
            ),
            // ⚠️ TURU 76 — kullanici emri: "paylastigim gonderilerde duzenleme".
            if (benim)
              ListTile(
                leading: const Icon(LucideIcons.pencil),
                title: const Text('Düzenle'),
                onTap: () => Navigator.pop(c, 'duzenle'),
              ),
            if (benim)
              ListTile(
                leading: const Icon(LucideIcons.chartNoAxesColumn),
                title: const Text('İstatistikler'),
                onTap: () => Navigator.pop(c, 'istatistik'),
              ),
            if (benim)
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Colors.red),
                title: const Text(
                  'Gönderiyi sil',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(c, 'sil'),
              ),
            if (!benim)
              ListTile(
                leading: const Icon(LucideIcons.flag),
                title: const Text('Şikayet et'),
                onTap: () => Navigator.pop(c, 'sikayet'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || secim == null) return;
    if (secim == 'link') {
      await Clipboard.setData(
        ClipboardData(text: 'https://gebzem.app/p/${g.id}'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
    } else if (secim == 'sil') {
      final onay = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Gönderi silinsin mi?'),
          content: const Text('Bu işlem geri alınamaz.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (onay != true || !mounted) return;
      try {
        await ref.read(sosyalServisiProvider).gonderiSil(g.id);
        widget.onSilindi?.call();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gönderi silinemedi')));
      }
    } else if (secim == 'duzenle') {
      await _duzenle();
    } else if (secim == 'istatistik') {
      await _istatistik();
    } else if (secim == 'sikayet') {
      await sikayetSheetAc(context, ref, hedefTur: 'gonderi', hedefId: g.id);
    }
  }

  /// TURU 76 — aciklama + yorum ayarini duzenle.
  /// ⚠️ MEDYA DEGISTIRILEMEZ (sunucu da kabul etmiyor) — sheet bunu ACIKCA yazar,
  ///    yoksa kullanici "fotografi degistiremiyorum" diye hata sanar.
  Future<void> _duzenle() async {
    final ctrl = TextEditingController(text: g.metin);
    var kapali = g.yorumKapali;
    final sonuc = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        // ⚠️ viewInsets: klavye acilinca sheet YUKARI kayar; yoksa kaydet
        //    dugmesi klavyenin ALTINDA kalir ve ulasilamaz.
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (c2, yenile) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gönderiyi düzenle',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    maxLines: 6,
                    minLines: 3,
                    maxLength: 2200,
                    decoration: const InputDecoration(
                      hintText: 'Açıklama',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: kapali,
                    onChanged: (v) => yenile(() => kapali = v),
                    title: const Text('Yorumları kapat'),
                  ),
                  if (g.mediaIds.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Fotoğraf ve videolar değiştirilemez.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(c2, true),
                      child: const Text('Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final yeniMetin = ctrl.text.trim();
    ctrl.dispose();
    if (sonuc != true || !mounted) return;
    final degistiMi = yeniMetin != g.metin;
    if (!degistiMi && kapali == g.yorumKapali) return;
    // ⚠️ IYIMSER guncelleme + HATA'DA GERI ALMA (kartin geri kalaniyla ayni desen).
    final eskiMetin = g.metin;
    final eskiKapali = g.yorumKapali;
    final eskiDuz = g.duzenlendi;
    setState(() {
      g.metin = yeniMetin;
      g.yorumKapali = kapali;
      // ⚠️ Etiket YALNIZ metin degistiyse — sunucudaki kural birebir ayni.
      if (degistiMi) g.duzenlendi = true;
    });
    try {
      await ref
          .read(sosyalServisiProvider)
          .gonderiDuzenle(g.id, metin: yeniMetin, yorumKapali: kapali);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        g.metin = eskiMetin;
        g.yorumKapali = eskiKapali;
        g.duzenlendi = eskiDuz;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gönderi güncellenemedi')));
    }
  }

  /// TURU 76 — yazara ozel istatistik sayfasi (kullanici emri: "istatistik olmali,
  /// goruntulenme sayisi vs").
  Future<void> _istatistik() async {
    Map<String, int>? veri;
    String? hata;
    try {
      veri = await ref.read(sosyalServisiProvider).istatistik(g.id);
    } catch (_) {
      hata = 'İstatistikler alınamadı';
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gönderi istatistikleri',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (hata != null)
                Text(hata, style: const TextStyle(color: Colors.grey))
              else ...[
                Row(
                  children: [
                    _kutu(
                      LucideIcons.eye,
                      'Görüntülenme',
                      veri?['goruntulenme'] ?? 0,
                    ),
                    _kutu(LucideIcons.heart, 'Beğeni', veri?['begeni'] ?? 0),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _kutu(
                      LucideIcons.messageCircle,
                      'Yorum',
                      veri?['yorum'] ?? 0,
                    ),
                    _kutu(
                      LucideIcons.bookmark,
                      'Kaydetme',
                      veri?['kaydetme'] ?? 0,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ⚠️ DURUSTLUK: goruntulenme akista ARTMIYOR (bkz. Gonderi.goruntulenme
                //    serhi). Bunu yazmazsak kullanici sayiyi "bozuk" sanar.
                const Text(
                  'Görüntülenme yalnız gönderi tam ekran açıldığında sayılır.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kutu(IconData ikon, String baslik, int deger) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(ikon, size: 20),
          const SizedBox(height: 6),
          Text(
            sayiBicimle(deger),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          Text(
            baslik,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    // ⚠️ Gozcu YALNIZ videolu gonderilerde kurulur: fotograf kartlarinda
    //    kaydirma dinleyicisi bosuna calisir (akista onlarca kart var).
    final govde = _icerik(tema);
    if (!g.videoIceriyor) return govde;
    return Gorunurluk(
      onOran: (o) {
        if (!mounted) return;
        // ⚠️ Yalniz ESIGI GECISTE yeniden ciz — her olcumde setState akisi takar.
        final oncekiAcik = _gorunurOran >= 0.6;
        final yeniAcik = o >= 0.6;
        _gorunurOran = o;
        if (oncekiAcik != yeniAcik) setState(() {});
      },
      child: govde,
    );
  }

  Widget _icerik(ThemeData tema) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- BASLIK
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: GestureDetector(
            onTap: () => widget.profileGit?.call(g.yazarId),
            child: Avatar(
              ad: g.yazarAd,
              mediaId: g.yazarAvatarMediaId,
              avatarUrl: g.yazarAvatar,
              cap: 38,
            ),
          ),
          title: GestureDetector(
            onTap: () => widget.profileGit?.call(g.yazarId),
            child: Text(
              g.yazarAd,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          subtitle: Text(
            [
              if (g.yazarUsername.isNotEmpty) '@${g.yazarUsername}',
              gonderiZamani(g.createdAt),
              // ⚠️ TURU 76: duzenlenmis gonderi GORUNUR sekilde isaretlenir.
              //    Sessizce degistirmek, altinda yorum birikmis bir icerigin
              //    anlamini bozmaya izin verirdi.
              if (g.duzenlendi) 'düzenlendi',
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(LucideIcons.ellipsis),
            onPressed: _menu,
          ),
        ),

        // ---- METIN (medya ustunde — Facebook duzeni)
        if (g.metin.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(g.metin, style: const TextStyle(fontSize: 15)),
          ),

        // ---- MEDYA
        if (g.mediaIds.isNotEmpty) _medya(),

        // ---- ETKILESIM CUBUGU (Threads duzeni)
        //
        // ⚠️⚠️ TURU 76b — KULLANICI EMRI: *"gonderilerde halen istatistik ikonu
        //    yok; ikonlarin hepsi ESIT gorunmeli"*.
        //
        //    ESKI HALI IKI SEBEPTEN ESITSIZDI:
        //      · begeni/yorum/paylas `TextButton.icon` idi (ikon 21px, degisken
        //        genislikte etiket, 10px yatay dolgu), kaydet ise ciplak
        //        `IconButton` (24px ikon, 24px dolgu) -> BOYUT ve ARALIK farkli.
        //      · `dolu` bayragi ikonu 21 -> 23px BUYUTUYORDU; begenince satirdaki
        //        hizalama KAYIYORDU.
        //    ARTIK: hepsi ayni `_eylem` bileseni, SABIT 22px ikon + sabit
        //    dokunma alani. "Secili" farki YALNIZ RENKTEN gelir (Lucide'da dolu
        //    kalp yok — bkz. asagidaki serh), boyut DEGISMEZ.
        // ⚠️ YAPMA: buraya farkli bir dugme tipi (IconButton/TextButton) karistirma.
        // ⚠️ YAPMA: `Icons.favorite` (Material) koyma — ikon seti karisir.
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
          child: Row(
            children: [
              _eylem(
                ikon: LucideIcons.heart,
                sayi: g.begeniSayisi,
                renk: g.begendim ? const Color(0xFFFF3B5C) : null,
                vurgu: g.begendim,
                onTap: _begeniCevir,
              ),
              _eylem(
                ikon: LucideIcons.messageCircle,
                sayi: g.yorumSayisi,
                onTap: g.yorumKapali ? null : _yorumlariAc,
              ),
              _eylem(
                ikon: LucideIcons.send,
                onTap: () => _sohbeteGonder(context),
              ),
              // ⚠️⚠️ ISTATISTIK IKONU — kullanici "hala istatistik ikonu yok" dedi.
              //    Eskiden istatistik YALNIZ ••• menusunun icindeydi; menuye
              //    girmeden gorunmuyordu, yani pratikte YOKTU.
              //    Yanindaki sayi GORUNTULENME (Instagram'in "N goruntulenme"si).
              // ⚠️ YALNIZ YAZARA gosterilir: baskasinin izlenme sayisi kullaniciya
              //    bir sey ifade etmez ve dusuk sayi yazari utandirir.
              if (g.yazarId == widget.benimId)
                _eylem(
                  ikon: LucideIcons.chartNoAxesColumn,
                  sayi: g.goruntulenme,
                  onTap: _istatistik,
                ),
              const Spacer(),
              _eylem(
                ikon: LucideIcons.bookmark,
                renk: g.kaydettim ? tema.colorScheme.primary : null,
                vurgu: g.kaydettim,
                onTap: _kaydetCevir,
              ),
            ],
          ),
        ),
        // ---- "N beğenme" (Instagram deseni) — dokununca BEGENENLER listesi
        if (g.begeniSayisi > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: GestureDetector(
              onTap: _begenenler,
              child: Text(
                '${sayiBicimle(g.begeniSayisi)} beğenme',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        // ---- "N yorumun tümünü gör" (Instagram deseni)
        if (!g.yorumKapali && g.yorumSayisi > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
            child: GestureDetector(
              onTap: _yorumlariAc,
              child: Text(
                g.yorumSayisi == 1
                    ? '1 yorumu gör'
                    : '${sayiBicimle(g.yorumSayisi)} yorumun tümünü gör',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
        if (g.yorumKapali)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Yorumlar kapalı',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 8),
        const Divider(height: 1),
      ],
    );
  }

  /// ⚠️⚠️ TURU 76b — MEDYA DUZENI **THREADS** (kullanici ekran goruntusu gonderdi:
  /// *"anasayfa boyle olacak, gorseller bu sekilde olacak, arada video da
  /// olabilir direk otomatik oynayacak"*).
  ///
  /// ESKI (Instagram): tam genislikte `PageView`, altta nokta gostergesi.
  /// YENI (Threads): YATAY KAYAN serit — her medya ~%78 genislikte, YUVARLAK
  /// KOSELI, aralarinda bosluk; SONRAKI MEDYA SAGDAN SARKAR ve boylece "devami
  /// var" bilgisi NOKTA GOSTERGESI OLMADAN anlasilir.
  ///
  /// ⚠️ NOKTA GOSTERGESI KALDIRILDI: sarkan onizleme zaten ayni bilgiyi veriyor;
  ///    ikisi birden gorsel gurultu (Threads'te de yok).
  /// ⚠️ TEK medyada serit KURULMAZ — tek ogeyi kaydirilabilir yapmak "devami
  ///    var" yanilgisi uretir.
  /// ⚠️ `ClipRRect` + `borderRadius` HER OGEDE: ekran goruntusundeki koseler
  ///    yuvarlak.
  Widget _medya() {
    final coklu = g.mediaIds.length > 1;
    // ⚠️ 4:5 (dikey) — telefonla cekilen fotograflarin cogunlugu dikey.
    //    Reels DIKEY (9:16) oldugu icin ayrilir.
    final enBoy = g.tur == 'reels' ? 9 / 16 : 4 / 5;

    return LayoutBuilder(
      builder: (context, kisit) {
        final tamGenislik = kisit.maxWidth - 24; // 12 sol + 12 sag dolgu
        // ⚠️ %78: sagdan sarkan parca ~%16 kalir — "devami var" belli olur ama
        //    ana medya hala baskin. Daha dar yapmak okunurlugu bozar.
        final ogeGenislik = coklu ? kisit.maxWidth * 0.78 : tamGenislik;
        final yukseklik = ogeGenislik / enBoy;

        return SizedBox(
          height: yukseklik,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!coklu)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GestureDetector(
                    onDoubleTap: () => _begeniCevir(yalnizBegen: true),
                    child: _medyaKutusu(0, ogeGenislik, yukseklik),
                  ),
                )
              else
                NotificationListener<ScrollNotification>(
                  // ⚠️ Yatay kaydirmada ORTADAKI ogeyi buluruz: otomatik oynayan
                  //    video YALNIZ o olmali (iki video ayni anda calmasin —
                  //    iOS ses oturumu proses genelinde TEK).
                  onNotification: (n) {
                    if (n.metrics.axis != Axis.horizontal) return false;
                    final adim = ogeGenislik + 8;
                    final i = (n.metrics.pixels / adim).round().clamp(
                      0,
                      g.mediaIds.length - 1,
                    );
                    if (i != _sayfa) setState(() => _sayfa = i);
                    return false;
                  },
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    // ⚠️ Kaydirma HIZLI ve tahmin edilebilir olsun diye oge
                    //    genisligine OTURAN bir fizik: serbest birakinca en
                    //    yakin ogeye yaslanir (Threads davranisi).
                    physics: const PageScrollPhysics(),
                    itemCount: g.mediaIds.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => GestureDetector(
                      onDoubleTap: () => _begeniCevir(yalnizBegen: true),
                      child: _medyaKutusu(i, ogeGenislik, yukseklik),
                    ),
                  ),
                ),
              if (_kalpGoster)
                const IgnorePointer(
                  child: Icon(
                    LucideIcons.heart,
                    size: 92,
                    color: Color(0xEEFF3B5C),
                  ),
                ),
              if (coklu)
                Positioned(
                  top: 10,
                  right: 20,
                  child: _rozet('${_sayfa + 1}/${g.mediaIds.length}'),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Galerideki TEK kutu — yuvarlak koseli, sabit olculu.
  Widget _medyaKutusu(int i, double genislik, double yukseklik) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: genislik,
      height: yukseklik,
      child: ColoredBox(
        color: const Color(0xFF0B0B12),
        child: _tekMedya(g.mediaIds[i], i),
      ),
    ),
  );

  Widget _tekMedya(String id, int sira) {
    // ⚠️⚠️ TURU 76 — TUR ARTIK MEDYA BASINA. Eskiden `g.videoMu` (GONDERI
    //    seviyesi) okunuyordu; karma galeride bu YAPISAL OLARAK YANLIS olurdu:
    //    'foto' turlu bir gonderideki VIDEO, MedyaGorsel'e verilip BOZUK KARE
    //    cizerdi (ya da hicbir sey). Sunucu artik `media_kinds` donduruyor.
    // ⚠️ YAPMA: burayi tekrar `g.videoMu`ya baglama.
    final t = g.kind(sira);
    if (t == 'yok') {
      // Medya sunucudan SILINMIS (sikayet/kaldirma). Bos kare yerine DURUST etiket.
      return const ColoredBox(
        color: Color(0xFF15151F),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.imageOff, color: Colors.white38, size: 34),
              SizedBox(height: 8),
              Text(
                'Bu içerik kaldırıldı',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    if (t == 'video') {
      // ⚠️⚠️ TURU 76b — AKISTA VIDEO ARTIK **OTOMATIK** OYNAR (kullanici emri:
      //    "arada videoda olabilir direk otomatik oynuyacak videolar").
      //
      //    IKI KAPI BIRDEN saglanmali:
      //      (1) KART ekranda yeterince gorunuyor (`_gorunurOran >= 0.6`)
      //      (2) galeride ORTADAKI oge bu (`_sayfa == sira`)
      //    Aksi halde akistaki 20 kartin tum videolari ayni anda calisir:
      //    cihaz isinir, mobil veri yanar ve iOS'ta ses oturumu PROSES
      //    GENELINDE TEK oldugu icin SUREN ARAMA SAGIRLASIR (turu 64/65/73).
      //
      // ⚠️⚠️ SESSIZ BASLAR (`sesli: false`) — bu bir tercih degil ZORUNLULUK:
      //    kaydirirken kendiliginden ses patlatmak hem kotu bir deneyim hem de
      //    iOS'ta AVAudioSession'i ele gecirip aramayi bozar. Kullanici
      //    oynaticidaki hoparlor dugmesiyle sesi acar (`MedyaVideo` cizer).
      // ⚠️ YAPMA: `sesli: true` yapma. ⚠️ YAPMA: kapilardan birini kaldirma.
      return MedyaVideo(
        mediaId: id,
        otoOynat: _gorunurOran >= 0.6 && _sayfa == sira,
        sesli: false,
        dolgu: BoxFit.cover,
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TamEkranGorsel(mediaId: id))),
      child: MedyaGorsel(mediaId: id, fit: BoxFit.contain),
    );
  }

  Widget _rozet(String metin) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x99000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        metin,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    ),
  );

  /// Etkilesim cubugundaki TEK eylem bileseni.
  ///
  /// ⚠️⚠️ TUM IKONLAR BUNDAN CIZILIR — kullanici emri "ikonlarin hepsi esit
  ///    gorunmeli". Ikon boyutu SABIT 22, dokunma alani SABIT 40x40.
  /// ⚠️ "Secili" hali BOYUTU DEGISTIRMEZ (eskiden 21->23 buyuyup satiri
  ///    kaydiriyordu); yalniz RENK degisir + tek seferlik kisa bir pop
  ///    animasyonu oynar. Lucide tasarim geregi YALNIZ CIZGI ikon icerir
  ///    (dolu kalp YOK) ve emoji YASAK (CLAUDE.md turu 62).
  /// ⚠️ Sayi 0 ise HIC yazilmaz (Threads/Instagram deseni) — "0" yazmak hem
  ///    gorsel gurultu hem yeni gonderide moral bozucu.
  Widget _eylem({
    required IconData ikon,
    VoidCallback? onTap,
    int? sayi,
    bool vurgu = false,
    Color? renk,
  }) {
    final etkin = onTap != null;
    final c =
        renk ??
        (etkin
            ? Theme.of(context).iconTheme.color
            : Theme.of(context).disabledColor);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: vurgu ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              // ⚠️ SABIT BOYUT — `scale` yalniz gorsel; yerlesim etkilenmez.
              child: SizedBox(
                width: 22,
                height: 22,
                child: Icon(ikon, size: 22, color: c),
              ),
            ),
            if (sayi != null && sayi > 0) ...[
              const SizedBox(width: 6),
              Text(
                sayiBicimle(sayi),
                style: TextStyle(
                  color: c,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ⚠️ TURU 76: eskiden YALNIZCA panoya kopyalayip "sohbete yapistirin" diyordu.
  ///    Artik gercek paylasim sayfasi (coklu sohbet secimi + kopyala) aciliyor.
  Future<void> _sohbeteGonder(BuildContext context) =>
      paylasSheetAc(context, ref, baglanti: 'https://gebzem.app/p/${g.id}');

  /// TURU 76 — begeni sayisina dokununca BEGENENLER listesi (Instagram deseni).
  /// ⚠️ Servis ucu (`begenenler`) turu 75'ten beri VARDI ama HICBIR EKRAN
  ///    CAGIRMIYORDU — olu kod. Kullaniciya gorunur hale getirildi.
  Future<void> _begenenler() async {
    if (g.begeniSayisi == 0) return;
    List<Map<String, dynamic>>? liste;
    try {
      liste = await ref.read(sosyalServisiProvider).begenenler(g.id);
    } catch (_) {
      liste = null;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(c).size.height * 0.55,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Beğenenler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: liste == null
                    ? const Center(
                        child: Text(
                          'Liste alınamadı',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: liste.length,
                        itemBuilder: (_, i) {
                          final u = liste![i];
                          final uid = (u['id'] ?? '').toString();
                          return ListTile(
                            leading: Avatar(
                              ad: (u['name'] ?? '').toString(),
                              mediaId: u['avatar_media_id'] as String?,
                              avatarUrl: (u['avatar_url'] ?? '').toString(),
                              cap: 40,
                            ),
                            title: Text((u['name'] ?? '').toString()),
                            subtitle: Text(
                              '@${(u['username'] ?? '').toString()}',
                            ),
                            onTap: widget.profileGit == null
                                ? null
                                : () {
                                    Navigator.pop(c);
                                    widget.profileGit!(uid);
                                  },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1.2B / 43,5B / 980 gibi kisa sayi.
String sayiBicimle(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final b = n / 1000;
    return '${b.toStringAsFixed(b < 10 ? 1 : 0)}B';
  }
  final m = n / 1000000;
  return '${m.toStringAsFixed(m < 10 ? 1 : 0)}M';
}

/// "3dk", "5sa", "2g", "12 Tem" — WhatsApp/Instagram tarzi.
/// ⚠️ Sunucu saati ile cihaz saati ARASINDAKI FARK kucuk negatif degerler
///    uretebilir; "şimdi" ile kapatiliyor (kullaniciya "-2dk" gostermek yerine).
String gonderiZamani(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final f = DateTime.now().difference(t);
  if (f.inSeconds < 60) return 'şimdi';
  if (f.inMinutes < 60) return '${f.inMinutes}dk';
  if (f.inHours < 24) return '${f.inHours}sa';
  if (f.inDays < 7) return '${f.inDays}g';
  const aylar = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  return '${t.day} ${aylar[t.month - 1]}';
}

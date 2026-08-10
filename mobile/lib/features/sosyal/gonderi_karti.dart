import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_screen.dart' show aktifSekme;
import '../medya/medya_gorsel.dart';
import '../chats/moderasyon_sheet.dart';
import '../medya/tam_ekran_gorsel.dart';
import '../medya/tam_ekran_video.dart';
import 'gorunurluk.dart';
import 'medya_olcu.dart';
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

  /// ⚠️⚠️ TURU 81 — Threads galerisinin kaydiricisi. `PageController` DEGIL
  ///    `ScrollController`: ogeler artik DEGISKEN GENISLIKTE (her medya kendi
  ///    oraninda cizilir) ve `PageView` tanim geregi ESIT genislik ister.
  ///    Ayrinti: `_medya()` icindeki serh.
  /// ⚠️ `initState`te (alan baslaticisinda) kurulur — build icinde kurulsaydi
  ///    her cizimde YENI controller olusur ve kaydirma konumu SIFIRLANIRDI
  ///    (turu 76b dersi).
  late final ScrollController _seritCtrl = ScrollController();

  @override
  void dispose() {
    _seritCtrl.dispose();
    super.dispose();
  }

  Gonderi get g => widget.gonderi;

  /// [i]. medyanin en-boy orani, bozuk degere karsi korumali.
  ///
  /// ⚠️ `medyaKutusu` ayni korumayi KENDI ICINDE yapar; bu yardimci yalnizca
  ///    galeri genisligini ORTAK yukseklikten turetirken (o yol `medyaKutusu`a
  ///    ugramaz) ayni savunmanin gecerli kalmasi icin var.
  double _oran(int i) {
    final o = g.enBoy(i);
    return (o.isFinite && o > 0) ? o : 0.8;
  }

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
    // ⚠️⚠️ TURU 80 — GENISLIK TAVANI (tablet/genis ekran).
    //    Yukseklik tavani TEK BASINA tablette 536x340'lik asiri YATAY bir kutu
    //    birakiyor ve 776dp genisliginde METIN SATIRI OKUNMUYOR.
    // ⚠️ Tavan KARTIN KENDI kokunde: UC cagiran var (akis_ekrani, gonderi_detay,
    //    kaydedilenler_sayfasi) ve ucune ayri ayri koymak drift demekti.
    final govde = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kKolonTavani),
        child: _icerik(tema),
      ),
    );
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
          // ⚠️⚠️ TURU 82b — KULLANICI ADI KALDIRILDI, ZAMAN ISMIN SAGINA
          //    (kullanici emri: *"isim altinda kullanici adi olmasin, zaman
          //    1dk mesela ismin saginda olacak"*).
          //    Alt satir tamamen bosaldigi icin `subtitle` YOK -> `ListTile`
          //    tek satira duser ve baslik ~16dp KISALIR (yan fayda).
          // ⚠️ Isim `Flexible` + ellipsis: uzun ad zamani EZMEZ; zaman
          //    `Flexible` DEGIL cunku her zaman TAM gorunmeli.
          // ⚠️ YAPMA: `@kullaniciadi`ni geri ekleme.
          title: GestureDetector(
            onTap: () => widget.profileGit?.call(g.yazarId),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    g.yazarAd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  [
                    gonderiZamani(g.createdAt),
                    // ⚠️ TURU 76: duzenlenmis gonderi GORUNUR isaretlenir.
                    //    Sessizce degistirmek, altinda yorum birikmis bir
                    //    icerigin anlamini bozmaya izin verirdi.
                    if (g.duzenlendi) 'düzenlendi',
                  ].join(' · '),
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
          // ⚠️ `subtitle` YOK -> ListTile tek satira duser, baslik kisalir.
          dense: true,
          visualDensity: VisualDensity.compact,
          horizontalTitleGap: 10,
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
                // ⚠️ Begenenler listesinin TEK girisi (alt satir kaldirildi).
                onUzunBas: g.begeniSayisi > 0 ? _begenenler : null,
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
        // ⚠️⚠️ TURU 82b — "N beğenme" ALT SATIRI KALDIRILDI (kullanici emri:
        //    *"begeni attigimda saginda rakam olacak, ALTTA YAZMAYACAK"*).
        //    Sayi zaten kalbin SAGINDA (`_eylem(sayi:)`), yani bu satir AYNI
        //    bilgiyi ikinci kez yaziyordu.
        // ⚠️ BEGENENLER LISTESI KAYBOLMADI: giris artik kalbin kendisine UZUN
        //    BASMA (asagidaki `_eylem(onUzunBas:)`). Satiri silip listeyi de
        //    olduren bir degisiklik "olu ozellik" sinifini yeniden acardi.
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
        // ⚠️ TURU 82b — GONDERI AYRACI SAYDAMLASTIRILDI (kullanici emri:
        //    *"gonderi ayraclarini biraz saydamlastir"*). Material'in
        //    varsayilan `Divider` rengi temanin `outlineVariant`idir ve koyu
        //    temada belirgin bir cizgi birakiyordu; artik metin renginin
        //    **%8**'i — kartlari ayirmaya yetiyor, goze carpmiyor.
        // ⚠️ `height: 1` KALIR (ayirici bosluk); yalniz RENK ve KALINLIK degisti.
        // ⚠️ Bu YALNIZ akistaki kart ayracidir; "Beğenenler" sayfasindaki
        //    baslik ayraci (asagida) BILEREK belirgin birakildi.
        Divider(
          height: 1,
          thickness: 0.5,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
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

    return LayoutBuilder(
      builder: (context, kisit) {
        final kolon = kisit.maxWidth - kKartYanDolgu * 2;
        // ⚠️⚠️⚠️ TURU 82 — KUTU ORANI = MEDYA ORANI (turu 81'in hatasi burada).
        //    Turu 81 yuksekligi SABITLIYOR, genisligi kolona kirpiyordu ->
        //    4:5 bir fotograf kolonun %59'unda kalip SAGINDA 150dp BOSLUK
        //    birakiyordu (kullanicinin "sol sag birseyler doluyor" dedigi sey).
        //    Artik genislik tavana takilirsa YUKSEKLIK DE ORANLA kuculur.
        //    Ayrinti + reddedilen alternatifler: `medya_olcu.dart` serhi.
        // ⚠️ YAPMA: burada kendi hesabini yazma — olculer TEK KAYNAKTA.
        // ⚠️ YAPMA: disariya sabit bir `height` verme; yukseklik ARTIK degisken.
        final tavan = medyaTavani(context, kolon);

        // TEK medya: kolonun TAMAMINI kullanabilir (4:5 ve daha genis her
        // fotograf kolonu DOLDURUR). COKLU galeri: oge kolonun %78'iyle
        // sinirli ki sonraki medya sagdan SARKSIN (galeri oldugunun tek ipucu).
        final ogeTavani = coklu ? kolon * kGaleriOgeOrani : kolon;
        ({double w, double h}) kutuOf(int i) =>
            medyaKutusu(tavan, g.enBoy(i), ogeTavani);

        // ⚠️⚠️ Galeride TUM ogeler AYNI YUKSEKLIKTE ve o yukseklik
        //    **ICERIKTEN BAGIMSIZ**. Onceki surumde ogelerin EN KISASI
        //    aliniyordu ve tek bir yatay fotograf BUTUN GALERIYI cokertiyordu
        //    (4:5 ogeler 285x357 -> 128x160). Gerekce + olcumler:
        //    `medya_olcu.dart::galeriSatirYuksekligi` serhi.
        // ⚠️ YAPMA: yuksekligi tekrar ogelerden turetme.
        final satirY = coklu
            ? galeriSatirYuksekligi(tavan, ogeTavani)
            : kutuOf(0).h;

        // Galeride oge genisligi ORTAK yukseklikten turer (oran korunur).
        //
        // ⚠️ 96dp ALT TABAN: `satirY` ogelerin EN KISASI oldugu icin KARMA bir
        //    galeride (ornegin 16:9 + 9:16) satir yatay ogeye gore alcalir ve
        //    dikey oge cok darlasir. Olculdu: 390x844'te 9:16 oge **69dp**'ye
        //    dusuyordu — pul kadar, dokunulamaz. Taban `medya_olcu.dart`ta
        //    zaten belgeli ama galeri yolu `medyaKutusu`a UGRAMADIGI icin onu
        //    ATLIYORDU. Taban bagladiginda yalniz O OGE hafifce kirpilir
        //    (kacinilmaz: sabit yukseklikli bir satirda 16:9 ile 9:16 ayni
        //    anda kirpilmadan duramaz) ve tam ekran yolu kurtarma saglar.
        double genislikOf(int i) => coklu
            ? math.max(math.min(ogeTavani, satirY * _oran(i)), 96.0)
            : kutuOf(i).w;

        return SizedBox(
          height: satirY,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!coklu)
                // ⚠️ TEK medya SOLA DAYALI cizilir (Threads/Instagram) —
                //    ortalanmis olsaydi dar (dikey) bir fotograf metin
                //    bloguyla hizasini kaybederdi.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kKartYanDolgu),
                    child: GestureDetector(
                      onDoubleTap: () => _begeniCevir(yalnizBegen: true),
                      child: _medyaKutusu(0, genislikOf(0), satirY),
                    ),
                  ),
                )
              else
                // ⚠️⚠️⚠️ TURU 81 — `PageView` TERK EDILDI, SEBEBI YAPISAL:
                //    `PageView` TANIM GEREGI tum sayfalari ESIT GENISLIKTE
                //    cizer (`viewportFraction` tek bir orandir). Degisken
                //    genislik onunla MUMKUN DEGIL.
                //
                // ⚠️ TURU 76b'nin YASAGI IHLAL EDILMIYOR: o yasak `ListView`in
                //    KENDISINE degil **`PageScrollPhysics`e** aitti. O fizik
                //    sayfa genisligini "viewport'un tamami" sanar ve esit
                //    olmayan ogelerde yaslanma her ogede biraz daha kayar.
                //    Burada `PageScrollPhysics` KULLANILMIYOR — serbest
                //    kaydirma var, yani o hata YAPISAL OLARAK olusamaz.
                // ⚠️ YAPMA: buraya `PageScrollPhysics` ya da `snap` ekleme.
                //
                // ⚠️ `_sayfa` artik KAYDIRMA KONUMUNDAN turetilir (asagidaki
                //    `NotificationListener`): otomatik video oynatma ve sayac
                //    rozeti ona bagli.
                NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is! ScrollUpdateNotification &&
                        n is! ScrollEndNotification) {
                      return false;
                    }
                    // ⚠️⚠️⚠️ TURU 82 — AKTIF OGE **VIEWPORT MERKEZINDEN**
                    //    bulunur, kaydirma ofsetinden DEGIL.
                    //
                    //    Onceki hesap `x`i (ham ofset) ogelerin baslangic
                    //    toplamlariyla karsilastiriyordu. Ama `ListView`
                    //    ogeleri viewport'a SIGDIGI icin `maxScrollExtent`
                    //    cok kucuk olabilir ve ofset ilk ogenin YARISINA bile
                    //    ULASAMAZ -> `_sayfa` **0'DA TAKILI KALIR**.
                    //    Olculdu (390x844, 16:9 + 9:16 galeri):
                    //      icerik 518dp · viewport 390dp · maxScroll **128dp**
                    //      ilk ogenin yarisi 143dp  ->  128 < 143  = ASLA GECMEZ
                    //    Sonuc: 2. medyanin OTO-OYNATMA kapisi (`_sayfa==sira`)
                    //    hic acilmiyor, sayac rozeti "1/2"de donuyor ve videoda
                    //    tam ekran dugmesi gorunmuyordu. Yani coklu galerinin
                    //    ikinci ve sonraki ogeleri fiilen OLU IDI.
                    // ⚠️ YAPMA: karsilastirmayi ham ofsete geri dondurme.
                    if (!_seritCtrl.hasClients) return false;
                    final x = _seritCtrl.offset;
                    final vp = _seritCtrl.position.viewportDimension;
                    final merkez = x + vp / 2;
                    var sol = kKartYanDolgu; // ListView'in sol dolgusu
                    var yeni = 0;
                    for (var i = 0; i < g.mediaIds.length; i++) {
                      final w = genislikOf(i);
                      // Ogenin sag kenari + boslugun yarisi merkezi geciyorsa
                      // merkez BU ogenin uzerindedir.
                      if (merkez < sol + w + kGaleriAra / 2) {
                        yeni = i;
                        break;
                      }
                      sol += w + kGaleriAra;
                      yeni = i;
                    }
                    if (yeni != _sayfa) setState(() => _sayfa = yeni);
                    return false;
                  },
                  child: ListView.builder(
                    controller: _seritCtrl,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(
                      left: kKartYanDolgu,
                      right: kKartYanDolgu,
                    ),
                    itemCount: g.mediaIds.length,
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.only(
                        right: i == g.mediaIds.length - 1 ? 0 : kGaleriAra,
                      ),
                      child: GestureDetector(
                        onDoubleTap: () => _begeniCevir(yalnizBegen: true),
                        child: _medyaKutusu(i, genislikOf(i), satirY),
                      ),
                    ),
                  ),
                ),
              // ⚠️ TURU 82b — CIFT DOKUNUS KALBI KUCULDU VE YUMUSADI.
              //    Kullanici: *"patlama olmasin, hafif COK HAFIF animasyonla"*.
              //    92px + tam opak kirmizi bir "patlama" idi; artik 54px, yari
              //    saydam ve 160ms'de yumusakca belirip kayboluyor.
              // ⚠️ YAPMA: boyutu geri buyutme; `easeOutBack`/`elasticOut` gibi
              //    geri sekmeli egri kullanma (patlama hissi ondan gelir).
              if (_kalpGoster)
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _kalpGoster ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: const Icon(
                      LucideIcons.heart,
                      size: 54,
                      color: Color(0xCCFF3B5C),
                    ),
                  ),
                ),
              // ⚠️⚠️ TURU 80 — ROZET `_medyaKutusu`NUN ICINE TASINDI.
              //    Eskiden burada `Positioned(top:10, right:20)` idi ve bu DIS
              //    `Stack`e, yani KART genisligine goreydi: 390px ekranda aktif
              //    medya x=12..296 arasindayken rozet x~340-370'e ciziliyordu —
              //    yani sayac AKTIF medyanin degil, **SAGDAN SARKAN KOMSU**
              //    medyanin uzerinde duruyordu.
              // ⚠️ YAPMA: rozeti tekrar dis Stack'e koyma.
            ],
          ),
        );
      },
    );
  }

  /// Galerideki TEK kutu — yuvarlak koseli, sabit olculu.
  ///
  /// ⚠️ Yaricap `kMedyaYaricap` (18) — TEK KAYNAK, bkz. `medya_olcu.dart`.
  Widget _medyaKutusu(int i, double? genislik, double yukseklik) => ClipRRect(
    borderRadius: BorderRadius.circular(kMedyaYaricap),
    child: SizedBox(
      width: genislik,
      height: yukseklik,
      child: ColoredBox(
        color: const Color(0xFF0B0B12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _tekMedya(g.mediaIds[i], i),
            // ⚠️ TURU 80 — SAYAC ROZETI ARTIK KUTUNUN ICINDE (bkz. yukaridaki
            //    serh). YALNIZ coklu galeride ve YALNIZ AKTIF kutuda cizilir;
            //    her kutuya cizilseydi sarkan komsuda da gorunur ve "iki sayac"
            //    izlenimi verirdi.
            if (g.mediaIds.length > 1 && i == _sayfa)
              Positioned(
                top: 8,
                right: 8,
                child: _rozet('${_sayfa + 1}/${g.mediaIds.length}'),
              ),
            // ⚠️⚠️ TURU 80b — VIDEODA TAM EKRAN CIKISI (denetim bulgusu).
            //    Yukseklik tavani kutuyu YATAY yaptigi icin 9:16 bir video
            //    `cover` ile ~%58 KIRPILIYOR. Fotografta kurtarma yolu VARDI
            //    (dokun -> TamEkranGorsel); videoda HIC YOKTU.
            // ⚠️ Dugme SOL ALTTA: sag ust sayac rozetinin, sag alt ise
            //    `MedyaVideo`nun kendi hoparlor dugmesinin yeri.
            //
            // ⚠️⚠️ `i == _sayfa` KAPISI (turu 80b denetimi): coklu galeride
            //    SAGDAN SARKAN komsu medya da ciziliyor; kapi olmadan orada
            //    da bir tam ekran dugmesi belirir ve "iki dugme" izlenimi
            //    verirdi. Turu 80 sayac rozetinde AYNI kapiyi tam bu yuzden
            //    koymustu — yeni katman onu atlamisti.
            //
            // ⚠️⚠️ DOKUNMA ALANI **44dp** (turu 78b dersi: medya kaldirma
            //    dugmesi 17x17dp idi ve basilamiyordu; Material 48 / Apple 44).
            //    Bu dugme KIRPILAN ICERIGIN TEK KURTARMA YOLU — kucuk kalirsa
            //    ozellik fiilen ulasilamaz olur. Gorunen daire kucuk kalir,
            //    dokunma alani `SizedBox` + `behavior` ile buyutulur.
            // ⚠️⚠️⚠️ TURU 82b — SOL ALTTAKI TAM EKRAN DUGMESI KALDIRILDI
            //    (kullanici emri: *"anasayfadaki videolarda buyutme ikonu,
            //    soldaki ikon olmasin"*).
            //
            // ⚠️ AMA KURTARMA YOLU KAYBOLMADI — kaybolsaydi turun getirdigi
            //    %20 kisaltma yuzunden KIRPILAN video bir daha tam haliyle
            //    GORULEMEZDI ("olu ozellik" sinifi). Giris **UZUN BASMA**ya
            //    tasindi: gorunmez, dugme degil, ve videonun kendi `onTap`i
            //    (duraklat/devam) ile CAKISMAZ.
            // ⚠️ YAPMA: videoya TAM ALANLI `onTap` ekleme — oynaticinin kendi
            //    dinleyicisi jest arenasini kazanip dokunusu YUTAR (turu 77b:
            //    video hikayede ileri/geri dokunusu tam bu yuzden calismiyordu).
            //    `onLongPress` AYRI bir tanidir, arena cakismasi olusmaz.
            if (g.kind(i) == 'video' && i == _sayfa)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TamEkranVideo(mediaId: g.mediaIds[i]),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
      //
      // ⚠️⚠️⚠️ TURU 77b — **UCUNCU VE DORDUNCU KAPI EKLENDI (SEVK ENGELIYDI).**
      //    Yalniz gorunurluk + sayfa kapilariyla video, kullanici BASKA SEKMEYE
      //    gecince ya da ustune BASKA EKRAN acilinca DURMUYORDU:
      //      (3) `aktifSekme == 0` — `IndexedStack` secili olmayan cocuklari da
      //          agacta CANLI ve LAYOUT EDILMIS tutar; sekme degisimi kaydirma
      //          uretmedigi icin gorunurluk gozcusu de HIC yeniden olcmuyordu.
      //          Ustelik Stack tum cocuklari AYNI konuma yerlestirdigi icin
      //          gozcuyu duzeltmek TEK BASINA yetmezdi.
      //      (4) `ModalRoute.isCurrent` — yorumlar/profil/detay/hikaye ekrani
      //          acildiginda akis ALTTA kalir; video oynamaya devam ediyordu.
      //    Ikisi de mobil veri yakiyor ve iOS'ta ses donanimini gereksiz tutuyordu.
      // ⚠️ YAPMA: `sesli: true` yapma. ⚠️ YAPMA: DORT kapidan birini kaldirma.
      return ValueListenableBuilder<int>(
        valueListenable: aktifSekme,
        builder: (context, sekme, _) => MedyaVideo(
          mediaId: id,
          otoOynat:
              _gorunurOran >= 0.6 &&
              _sayfa == sira &&
              sekme == 0 &&
              (ModalRoute.of(context)?.isCurrent ?? true),
          sesli: false,
          // ⚠️ TURU 82b — AKISTA ALT ILERLEME CUBUGU YOK (kullanici emri).
          //    Reels/hikaye/tam ekranda TRUE kalir (orada islevsel).
          ilerlemeGoster: false,
          // ⚠️ TEK KAYNAK: `medya_olcu.dart::kMedyaDolgu`. Sabit turu 81'de
          //    tanimlanmis ama HIC KULLANILMAMISTI (denetim yakaladi) — iki
          //    dal da `BoxFit.cover`i ELLE yaziyordu, yani sabiti degistirmek
          //    HICBIR SEYI degistirmezdi ("olu sabit" sinifi).
          dolgu: kMedyaDolgu,
        ),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TamEkranGorsel(mediaId: id))),
      // ⚠️⚠️ TURU 80 — `cover` (eskiden `contain`). MEVCUT HATAYDI: video dali
      //    `BoxFit.cover` kullaniyordu, fotograf dali `contain` — yani KARMA
      //    galeride (turu 76'nin `media_kinds` ile actigi tam senaryo) video
      //    kutuyu doldururken FOTOGRAF ayni kutuda SIYAH BANTLA ciziliyordu.
      //    Yukseklik tavani geldikten sonra kutu daha YATAY oldugu icin o
      //    bantlar BUYUYECEKTI, yani hata gorunurlesecekti.
      // ⚠️ `TamEkranGorsel` `contain` KALIR — kirpilmamis hali orada gorunur.
      // ⚠️ TEK KAYNAK — bkz. video dalindaki serh.
      child: MedyaGorsel(mediaId: id, fit: kMedyaDolgu),
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

  /// ⚠️⚠️⚠️ TURU 82 — IKON **OPTIK** BOYUTU. Kullanici: *"begeni yorum vs
  /// ikonlar esit gorunmuyor; olculer aynidir ama goruntude biri kucuk biri
  /// buyuk"*.
  ///
  /// **KULLANICI HAKLI VE OLCU DE DOGRUYDU** — ikisi celismiyor. Hepsi
  /// nominal 22px'ti; sorun `size`in ikonun **CIZILEN MUREKKEBINI** degil
  /// **SINIR KUTUSUNU** olcmesi. Lucide 24'luk izgarada her sembol kutuyu
  /// FARKLI doldurur, dolayisiyla ayni `size` FARKLI gorunur:
  ///
  ///   heart          ~20x18 dolu govde        -> optik olarak EN BUYUK
  ///   messageCircle  ~19x19 daire             -> buyuk
  ///   bookmark       ~13x18 DAR dikdortgen    -> dar goze KUCUK gelir
  ///   send           ~19x19 ama ucgen + BOSLUK-> mürekkep az, KUCUK gorunur
  ///   chartNoAxes…   ~18x14 kisa cubuklar     -> KUCUK gorunur
  ///
  /// Cozum tipografideki "optical sizing" ile ayni: **gorsel agirligi dusuk
  /// olan sembole daha buyuk nominal boy** verilir. Yerlesim kutusu 24x24
  /// SABIT kaldigi icin satir kaymaz.
  ///
  /// ⚠️ YAPMA: hepsini tekrar tek bir sabite (22) esitleme — "esit olcu"
  ///    ESIT GORUNUM DEMEK DEGIL; kullanicinin sikayeti tam olarak buydu.
  /// ⚠️ Cubuga YENI ikon eklersen buraya da bir satir ekle; haritada olmayan
  ///    ikon 22'ye duser (guvenli varsayilan, sessiz bozulma yok).
  /// ⚠️⚠️⚠️ TURU 82b — **KALP YUKARI CEKILDI, YON HATALIYDI.**
  ///
  /// Turu 82'de kalbi 21'e DUSURMUSTUM ("govdeyi doldurur" varsayimi).
  /// Kullanici tam tersini gordu: *"kalp diger ikonlarin yaninda COK KUCUK
  /// duruyor"*. **KULLANICI HAKLI** — varsayimim yanlis eksende kuruluydu:
  /// Lucide `heart` YATAYDA genis ama **DIKEYDE KISA** (~20x17 govde), yani
  /// ayni `size` degerinde gozun algiladigi YUKSEKLIK digerlerinden kucuktur.
  /// `messageCircle` (19x19 daire) ve `bookmark` (13x18) dikeyde daha doludur.
  /// Optik denge YUKSEKLIGE gore kurulur -> kalp EN BUYUK nominal boyu alir.
  ///
  /// ⚠️ Yerlesim kutusu **26x26 SABIT** — nominal boy degisse de satir kaymaz.
  /// ⚠️ YAPMA: kalbi tekrar kucultme; hepsini tek sabite esitleme
  ///    ("esit olcu" ESIT GORUNUM demek degil — turu 82 dersi).
  /// ⚠️ Cubuga yeni ikon eklersen buraya da satir ekle (haritada olmayan 23'e
  ///    duser: guvenli varsayilan, sessiz bozulma yok).
  static double _optikBoy(IconData ikon) {
    if (ikon == LucideIcons.heart) return 26;
    if (ikon == LucideIcons.messageCircle) return 23;
    if (ikon == LucideIcons.send) return 24;
    if (ikon == LucideIcons.bookmark) return 24;
    if (ikon == LucideIcons.chartNoAxesColumn) return 24;
    return 23;
  }

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
    VoidCallback? onUzunBas,
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
      // ⚠️ "N beğenme" satiri kaldirilinca BEGENENLER listesinin TEK girisi
      //    burasi kaldi (bkz. yukaridaki serh). Yalnizca kalpte doludur.
      onLongPress: onUzunBas,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        // ⚠️ TURU 82 — yatay dolgu 8 -> 6. Ikon KUTUSU 22'den 24'e cikti
        //    (optik denge icin); dolgu kisilmasaydi cubuk 5 ogede net +10dp
        //    genisleyecekti ve asagidaki tavan hesabinin payi erirdi.
        //    Dokunma hedefi: 6+24+6 = 36 genislik x 42 yukseklik — 44dp'lik
        //    Apple tavsiyesinin altinda kalan tek eksen genislik ve ogeler
        //    BITISIK oldugu icin komsu hedefe basma riski YOK.
        // ⚠️ TURU 82b — 6 -> 5: ikon kutusu 24'ten 26'ya cikti (kalp optik
        //    duzeltmesi), bes ogede net +10dp. Dolgu kisilarak geri alindi ki
        //    asagidaki tasma tavani AYNEN gecerli kalsin
        //    (5*(5+26+5) + 3*(6+40) = 318dp, en dar telefonda 18dp pay).
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              // ⚠️ TURU 82b — kullanici: *"PATLAMA OLMASIN, hafif COK HAFIF
              //    animasyonla olacak"*. 1.12 + `easeOutBack` (geri sekmeli,
              //    "pop" hissi veren egri) -> **1.04 + `easeOut`**.
              // ⚠️ YAPMA: `easeOutBack`e donme — o egri 1.0'i ASIP geri geldigi
              //    icin degeri dusursen bile "patlama" hissi KALIR.
              scale: vurgu ? 1.04 : 1.0,
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              // ⚠️ SABIT YERLESIM KUTUSU — `scale` ve optik duzeltme yalnizca
              //    GORSEL; kutu 26x26 sabit oldugu icin satir HIC kaymaz.
              child: SizedBox(
                width: 26,
                height: 26,
                child: Center(
                  child: Icon(ikon, size: _optikBoy(ikon), color: c),
                ),
              ),
            ),
            if (sayi != null && sayi > 0) ...[
              const SizedBox(width: 6),
              // ⚠️⚠️ TURU 82 — SAYININ GENISLIGI **SERT TAVANLI**.
              //
              //    Cubuk bir `Row` ve ortasinda `Spacer` var; sabit cocuklar
              //    kolonu asarsa Spacer 0'a duser ve RenderFlex SARI-SIYAH
              //    TASMA SERIDI cizer. Olcum (360dp telefon, kolon 336):
              //      · normal olcek        -> 313dp   (pay 23dp)
              //      · yazi olcegi 1.3     -> 335dp   (pay 1dp!)
              //      · yazi olcegi 1.5     -> TASMA
              //    Yani erisilebilirlik ayarini acan kullanicida cubuk
              //    kiriliyordu. Bu bir SEVK ENGELI degil ama gorunur bir hata
              //    ve turun konusu tam da "cubuk duzgun gorunsun".
              //
              // ⚠️ 40dp SERT tavan olceklerden BAGIMSIZ bir ust sinir kurar:
              //    en fazla 5 karakter ("999B"/"12.3M" — `sayiBicimle` tavani)
              //    13px'te ~35dp, olcek 1.3'te ~45dp -> ellipsis devreye girer
              //    ama TASMA YAPISAL OLARAK IMKANSIZ hale gelir.
              //    Yeni worst-case: 5*(12+24) + 3*(6+40) = 318 < 336 ✓
              // ⚠️ YAPMA: bu tavani kaldirma ya da `Flexible` ile degistirme —
              //    `Flexible` bu Row'da (mainAxisSize.min, dis Row'un esnek
              //    OLMAYAN cocugu) sinirsiz kisit alir ve HICBIR SEY YAPMAZ.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 40),
                child: Text(
                  sayiBicimle(sayi),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
/// ⚠️⚠️ TURU 82b — TURKCE BINLIK BICIM (kullanici emri: *"rakamlar binlik
/// olsun, mesela 1.3bin"*).
///
///     999      -> "999"
///     1340     -> "1,3 bin"
///     23500    -> "24 bin"
///     1240000  -> "1,2 mn"
///
/// ⚠️ ONDALIK AYIRAC **VIRGUL** (Turkce yazim) — `toStringAsFixed` nokta
///    uretir, o yuzden acikca cevriliyor.
/// ⚠️ Kisaltma "B" DEGIL "bin": tek harf "B" Turkce'de "bin"i cagristirmiyor
///    ve "byte"la karisiyordu.
/// ⚠️ Bicimin TAVANI 6 karakter ("1000 bin" olusamaz cunku 1e6'da "mn"ye
///    geciliyor). Etkilesim cubugundaki 40dp sert tavan bunu varsayar.
String sayiBicimle(int n) {
  String v(double x) =>
      x.toStringAsFixed(x < 10 ? 1 : 0).replaceAll('.', ',').replaceAll(',0', '');
  if (n < 1000) return '$n';
  if (n < 1000000) return '${v(n / 1000)} bin';
  return '${v(n / 1000000)} mn';
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

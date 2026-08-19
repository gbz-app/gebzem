import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/denetleyici_sahibi.dart';

import '../home/home_screen.dart' show aktifSekme;
import '../medya/konum_servisi.dart';
import '../medya/medya_gorsel.dart';
import '../medya/ses_notu_balon.dart';
import '../chats/anket.dart';
import '../chats/moderasyon_sheet.dart';
import '../medya/tam_ekran_gorsel.dart';
import '../medya/tam_ekran_video.dart';
import 'gorunurluk.dart';
import '../isletme/isletme_kart.dart' show kYuzeyGri, kYanBosluk;
import 'demo_veri.dart';
import 'demo_yorum.dart';
import 'thread_cizgi.dart';
import 'yorum_satiri.dart';
import 'gonderi_detay.dart';
import 'gonderi_menusu.dart';
import 'medya_olcu.dart';
import 'medya_video.dart';
import 'paylas_sheet.dart';
import 'sosyal_servisi.dart';
import 'yorumlar_sayfasi.dart';

/// ⚠️⚠️ TURU 98c — BASLIK SATIRININ **YAN DOLGUSU** (kullanici: *"sol sag
///	bosluklar yemekteki gibi olacak"*) — kategori ekraniyla ayni olcu.
///
/// ⚠️ Metnin girintisi BU SABITTEN TURETILIR (`+ avatar 38 + kBaslikAra`);
///    iki yerde ayri sayi yazilirsa metin adin altindan KAYAR.
const double kBaslikYanDolgu = kYanBosluk;

/// Avatar ile ad arasindaki bosluk.
const double kBaslikAra = 10;

/// Baslik avatarinin capi. Metnin girintisi bundan TURETILIR.
const double kAvatarCap = 38;

/// ⚠️⚠️ TURU 98f — **AD -> ACIKLAMA** ve **ACIKLAMA -> MEDYA** bosluklari
///	AYNI sabitten gelir (kullanici emri: *"esit olsun"*). Tek sayi
///	oldugu icin biri degisip oteki geride KALAMAZ.
const double kIcBosluk = 8;

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
    this.detayda = false,
    this.profileGit,
  });

  final Gonderi gonderi;
  final String benimId;
  final VoidCallback? onSilindi;

  /// ⚠️ TURU 98i — kart DETAY ekraninda cizilirken akistaki tek yanit
  ///    TEKRARLANMAZ (yorumlarin tamami zaten altta listeleniyor).
  final bool detayda;
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

  /// ⚠️ Animasyonun BASTAN oynamasi icin anahtar tohumu (bkz. `_kalpAnimasyonu`).
  int _kalpSayac = 0;

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

  /// ⚠️ TURU 98c — tasarim demosu: bu kart sunucuda YOK (bkz. demo_veri).
  bool get _demo => demoKimlik(g.yazarId);

  /// Demo icerikte ag cagrisi yerine DURUST bir bilgi verilir.
  void _demoUyar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('Bu bir tasarım demosu — gerçek içerik değil'),
      ),
    );
  }

  /// ⚠️ Akista gosterilecek TEK demo yaniti (yoksa null).
  late final DemoYorum? _akisYaniti =
      // ⚠️ `demoKimlik` SART: kapi olmadan sahte yanit GERCEK
      //    gonderilerin altinda da ciziliyordu (emulatorde gorundu).
      kDemoAkis && _demo && !g.sponsorlu && !widget.detayda
      ? demoAkisYaniti(g.id)
      : null;

  /// ⚠️ Cevrim detay/panel ile AYNI fonksiyondan (`demoYorumGorunumu`) gecer;
  ///    turu 101'de burada UCUNCU bir elle-cevrim vardi ve `sahipBegendi`yi
  ///    "ben begendim" alanindan besliyordu.
  late final YorumGorunum? _akisYanitGorunum = _akisYaniti == null
      ? null
      : demoYorumGorunumu(
          _akisYaniti,
          gonderiId: g.id,
          yazarKullaniciAdi: g.yazarUsername,
          yol: 'akis',
        );

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
    // ⚠️ DEMO: iyimser guncelleme EKRANDA KALIR, sunucuya GIDILMEZ.
    if (_demo) return;
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
    // ⚠️ Sayac ARTAR: `ValueKey(_kalpSayac)` sayesinde art arda cift
    //    dokunuslarda animasyon BASTAN oynar (aksi halde ikinci dokunusta
    //    widget "ayni" sayilip hicbir sey oynamazdi).
    setState(() {
      _kalpGoster = true;
      _kalpSayac++;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _kalpGoster = false);
    });
  }

  Future<void> _kaydetCevir() async {
    final eski = g.kaydettim;
    setState(() => g.kaydettim = !eski);
    if (_demo) return; // ⚠️ TURU 98c — demo icerik sunucuya gitmez.
    try {
      final s = ref.read(sosyalServisiProvider);
      eski ? await s.kaydetKaldir(g.id) : await s.kaydet(g.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => g.kaydettim = eski);
    }
  }

  Future<void> _yorumlariAc() async {
    // ⚠️⚠️ TURU 98i — DEMODA yorum dokunusu **GONDERI DETAYINI** acar
    //	(kullanici: *"gonderiye tikladigimda gonderi detayini boyle
    //	istiyorum"*). Gercek akista `YorumlarSayfasi` acilmaya devam
    //	eder — o hat DEGISMEDI.
    if (_demo) {
      if (widget.detayda) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => GonderiDetay(gonderi: g)));
      return;
    }
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

  /// ⚠️⚠️⚠️ TURU 98l — ••• MENUSU (kullanici emri + Threads/Facebook
  ///	referans gorselleri). Gorunum ve maddeler `gonderi_menusu.dart`ta
  ///	TEK KAYNAK; burada yalnizca SECIMIN KARSILIGI kosuluyor.
  ///
  /// ⚠️ Demo gonderide menu ACILIR (kullanici gormek istiyor) ama sunucuya
  ///    giden hicbir eylem kosmaz.
  Future<void> _menu() async {
    final benim = g.yazarId == widget.benimId;
    final secim = await gonderiMenusuAc(
      context,
      benimGonderim: benim,
      sponsorlu: g.sponsorlu,
      kaydedildi: g.kaydettim,
    );
    if (!mounted || secim == null) return;

    switch (secim) {
      case MenuSecim.kopyala:
        await Clipboard.setData(
          ClipboardData(text: 'https://gebzem.app/p/${g.id}'),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
      case MenuSecim.kaydet:
        await _kaydetCevir();
      case MenuSecim.duzenle:
        await _duzenle();
      case MenuSecim.istatistik:
        await _istatistik();
      case MenuSecim.sil:
        await _silOnayla();
      case MenuSecim.engelle:
        if (_demo) return _demoUyar();
        await engelleOnayiAc(
          context,
          ref,
          kullaniciId: g.yazarId,
          ad: g.yazarAd,
          suAnEngelli: false,
        );
      case MenuSecim.sikayet:
      case MenuSecim.reklamSikayet:
        if (_demo) return _demoUyar();
        await sikayetSheetAc(context, ref, hedefTur: 'gonderi', hedefId: g.id);
      // ⚠️⚠️ ASAGIDAKILERIN SUNUCU KARSILIGI **YOK** (bkz. gonderi_menusu.dart
      //	serhi). Sessizce hicbir sey yapmak yerine DURUSTCE soyleniyor —
      //	bu projede "dugme var, is yok" sinifi alti kez sahaya cikti.
      case MenuSecim.ilgilenmiyorum:
      case MenuSecim.sessize:
      case MenuSecim.kisitla:
        _bilgi(
          'Bu seçenek henüz aktif değil — akış tercihleri sunucuda tutulmuyor.',
        );
      case MenuSecim.reklamIlgimiCekiyor:
      case MenuSecim.reklamIlgimiCekmiyor:
      case MenuSecim.reklamGizle:
      case MenuSecim.reklamNeden:
      case MenuSecim.reklamHakkinda:
        _bilgi('Bu bir tasarım demosu — reklam altyapısı henüz yok.');
    }
  }

  void _bilgi(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 3)),
    );
  }

  /// Gonderiyi sil (onay diyalogu ile).
  Future<void> _silOnayla() async {
    if (_demo) return _demoUyar();
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
  }

  /// TURU 76 — aciklama + yorum ayarini duzenle.
  /// ⚠️ MEDYA DEGISTIRILEMEZ (sunucu da kabul etmiyor) — sheet bunu ACIKCA yazar,
  ///    yoksa kullanici "fotografi degistiremiyorum" diye hata sanar.
  Future<void> _duzenle() async {
    final ctrl = TextEditingController(text: g.metin);
    var kapali = g.yorumKapali;
    // ⚠️ TURU 90c — konum kaldirma anahtari (yalniz konumlu gonderide cizilir).
    var konumSil = false;
    final sonuc = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DenetleyiciSahibi(
        denetleyiciler: [ctrl],
        child: Padding(
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
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
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
                    // ⚠️⚠️ TURU 90c — KONUM KALDIRMA (GIZLILIK).
                    //    Sunucu ucu turu 90b'de acildi ama ISTEMCIDE cagiran
                    //    yol YOKTU; yanlislikla ev konumunu paylasan kullanicinin
                    //    tek caresi HALA gonderiyi silmekti (begeni/yorum/
                    //    goruntulenme ile birlikte).
                    if (g.konumVar)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: konumSil,
                        onChanged: (v) => yenile(() => konumSil = v),
                        title: const Text('Konumu kaldır'),
                        subtitle: Text(
                          g.konum.isEmpty ? 'Konum ekli' : g.konum,
                          style: const TextStyle(fontSize: 12),
                        ),
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
      ),
    );
    // ⚠️ Metin SENKRON okunur; birakmayi DenetleyiciSahibi yapar.
    final yeniMetin = ctrl.text.trim();
    if (sonuc != true || !mounted) return;
    final degistiMi = yeniMetin != g.metin;
    // ⚠️ `konumSil` de "degisiklik var mi" kapisina GIRER — girmeseydi
    //    kullanici YALNIZ konumu kaldirmak istediginde istek HIC ATILMAZDI
    //    (anahtar acilir, "Kaydet"e basilir, hicbir sey olmazdi).
    if (!degistiMi && kapali == g.yorumKapali && !konumSil) return;
    // ⚠️ IYIMSER guncelleme + HATA'DA GERI ALMA (kartin geri kalaniyla ayni desen).
    final eskiMetin = g.metin;
    final eskiKapali = g.yorumKapali;
    final eskiDuz = g.duzenlendi;
    final eskiKonum = g.konum;
    final eskiEnlem = g.enlem;
    final eskiBoylam = g.boylam;
    setState(() {
      g.metin = yeniMetin;
      g.yorumKapali = kapali;
      // ⚠️ Etiket YALNIZ metin degistiyse — sunucudaki kural birebir ayni.
      if (degistiMi) g.duzenlendi = true;
      if (konumSil) {
        g.konum = '';
        g.enlem = 0;
        g.boylam = 0;
      }
    });
    try {
      await ref
          .read(sosyalServisiProvider)
          .gonderiDuzenle(
            g.id,
            metin: yeniMetin,
            yorumKapali: kapali,
            konumKaldir: konumSil,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        g.metin = eskiMetin;
        g.yorumKapali = eskiKapali;
        g.duzenlendi = eskiDuz;
        g.konum = eskiKonum;
        g.enlem = eskiEnlem;
        g.boylam = eskiBoylam;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gönderi güncellenemedi')));
    }
  }

  /// TURU 76 — yazara ozel istatistik sayfasi (kullanici emri: "istatistik olmali,
  /// goruntulenme sayisi vs").
  Future<void> _istatistik() async {
    if (_demo) return _demoUyar();
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
        // ---- BASLIK + METIN (TEK BLOK)
        //
        // ⚠️⚠️⚠️ TURU 98f — `ListTile` BIRAKILDI (kullanici emri):
        //	*"profil isimleri profil resminin UST KISMI ile hizali olsun ve
        //	profil ismi ile aciklama arasindaki bosluk, aciklama ile resim
        //	arasindaki boslukla ESIT olsun"*.
        //
        //	`ListTile` bunlarin IKISINI DE YAPAMAZ: baslik dikeyde
        //	ORTALANIR (38 dp avatarin ortasina) ve aciklama satiri
        //	`ListTile`in DISINDA kaldigi icin aradaki bosluk avatarin
        //	yuksekliginden artakalan pay + dolgu olur — yani ELLE
        //	AYARLANAMAZ.
        //
        // ⚠️ YENI YAPI: `Row(crossAxisAlignment: start)` -> ad, avatarin UST
        //	kenariyla ayni cizgide baslar. Ad ve aciklama AYNI kolonda
        //	oldugu icin aralarindaki bosluk TEK SABITTEN (`kIcBosluk`)
        //	gelir; ayni sabit bu blogun ALTINA da konur, yani
        //	**ad -> aciklama** ve **aciklama -> medya** bosluklari
        //	YAPISAL OLARAK esittir.
        // ⚠️ YAPMA: burayı tekrar `ListTile`a cevirme.
        Padding(
          padding: const EdgeInsets.only(
            left: kBaslikYanDolgu,
            // ⚠️ 8 EKSIK: `IconButton` kutusu (40) ikondan (24) 8 dp genis;
            //    boylece ••• ikonunun GORUNEN sag kenari tam
            //    `kBaslikYanDolgu` cizgisine oturur.
            right: kBaslikYanDolgu - 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    _demo ? _demoUyar() : widget.profileGit?.call(g.yazarId),
                child: Avatar(
                  ad: g.yazarAd,
                  mediaId: g.yazarAvatarMediaId,
                  avatarUrl: g.yazarAvatar,
                  cap: kAvatarCap,
                ),
              ),
              const SizedBox(width: kBaslikAra),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _demo
                          ? _demoUyar()
                          : widget.profileGit?.call(g.yazarId),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              g.yazarAd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // ⚠️ TURU 98d — kullanici: "1 tik daha buyuk".
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            g.sponsorlu
                                ? 'Sponsorlu'
                                : [
                                    gonderiZamani(g.createdAt),
                                    // ⚠️ TURU 76: duzenlenmis gonderi GORUNUR isaretlenir.
                                    if (g.duzenlendi) 'düzenlendi',
                                  ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: g.sponsorlu
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ⚠️⚠️ TURU 90 — KONUM (yalniz varsa cizilir). Dokununca
                    //    cihazin KENDI harita uygulamasi acilir.
                    if (g.konumVar)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => KonumServisi.haritadaAc(g.enlem, g.boylam),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3, bottom: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ⚠️ TURU 90b — RENK TEMADAN (sabit mavi acik
                              //    temada 2.27:1 kontrast veriyordu).
                              Icon(
                                LucideIcons.mapPin,
                                size: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  g.konum.isEmpty ? 'Konum' : g.konum,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // ---- ACIKLAMA (adin ALTINDA, adla AYNI kolonda)
                    if (g.metin.isNotEmpty) ...[
                      const SizedBox(height: kIcBosluk),
                      Text(g.metin, style: const TextStyle(fontSize: 15)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.ellipsis),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: _menu,
              ),
            ],
          ),
        ),
        // ⚠️ ACIKLAMA -> MEDYA boslugu, AD -> ACIKLAMA boslugu ile AYNI
        //    sabittir (kullanici emri).
        const SizedBox(height: kIcBosluk),

        // ---- SES (medyadan ONCE kontrol edilir — ses bir galeri DEGILDIR)
        //
        // ⚠️⚠️ TURU 83 — GONDERIDE SES (kullanici emri: "gonderide ses olmasi
        //    elzem"). MIGRATION GEREKMEDI: `media_assets.kind` CHECK'i 037'den
        //    beri 'audio' kabul ediyor ve `posts.media_ids` bir medya dizisi —
        //    yani ALTYAPI ZATEN VARDI, eksik olan YALNIZCA bu cizim daliydi.
        //    (Turu 81 dersi: "buyuk bir istek geldiginde once bunun ne kadari
        //    zaten var diye sor.")
        // ⚠️ `_medya()`DAN ONCE: ses `MedyaGorsel`e gitseydi KIRIK GORSEL
        //    cizilirdi (turu 78b'de ilan/etkinlik seritlerinde tam bu oldu).
        // ⚠️ `SesNotuBalon` SOHBETTEKI BILESENIN AYNISI — ikinci bir oynatici
        //    yazmak `SesNotuKontrol` defterini (tek-slot ses sahipligi, turu 73)
        //    ATLARDI ve gelen arama gonderi sesini SUSTURAMAZDI.
        if (g.sesliMi)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kKartYanDolgu,
              0,
              kKartYanDolgu,
              8,
            ),
            child: SesNotuBalon(
              mediaId: g.mediaIds.first,
              // ⚠️ Sure/dalga gonderi hattinda TASINMIYOR (mesajdaki gibi ayri
              //    sutunlar yok). Balon ikisi de bos/0 iken sureyi oynaticidan
              //    ogrenir ve duz bir serit cizer — bilgi UYDURULMAZ.
              sureMs: 0,
              dalga: '',
              benimMi: g.yazarId == widget.benimId,
            ),
          )
        // ---- MEDYA
        else if (g.mediaIds.isNotEmpty)
          _medya(),

        // ---- SPONSORLU BAGLANTI KARTI (alan adi + eylem cagrisi)
        //
        // ⚠️ TURU 98i — Threads sponsorlu gonderisinde medyanin ALTINDA
        //    alan adi ve bir dugme satiri var; kullanici bunu istedi.
        // ⚠️ Tiklama YOK: gercek reklam altyapisi (hedef URL, tiklama
        //    sayaci, gizlilik metni) YOK; sahte bir baglanti acmak
        //    kullaniciya YALAN olurdu.
        if (g.sponsorlu)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kKartYanDolgu,
              8,
              kKartYanDolgu,
              4,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kYuzeyGri(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.sponsorAlan,
                          style: TextStyle(
                            fontSize: 12,
                            color: tema.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          g.sponsorCta,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: tema.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),

        // ---- ANKET
        //
        // ⚠️⚠️ TURU 83 — `AnketBalon` SOHBETTEKI BILESENIN AYNISI. Oylama,
        //    sayim, kapatma ve `yayinlaBirlestir` (WS ile gelen sayimlari
        //    KENDI oyumu EZMEDEN birlestirme — turu 81b sevk engeli) hepsi
        //    orada TEK KAYNAK olarak duruyor.
        // ⚠️ `benimMi` = anketi BEN mi olusturdum. Gonderi anketinde anketi
        //    olusturan DAIMA gonderinin yazaridir (sunucu `creator_id`yi
        //    `posts.author_id`den bagimsiz almaz — `Create` icinde `me`).
        if (g.anket != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kKartYanDolgu,
              0,
              kKartYanDolgu,
              8,
            ),
            child: AnketBalon(
              anket: g.anket!,
              benimMi: g.yazarId == widget.benimId,
            ),
          ),

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
        // ⚠️ TURU 98h — `Icons.favorite` YALNIZ "begenildi" halinde kullanilir
        //    (Lucide dolu kalp icermiyor, olculdu); baska yerde ikon seti KARISTIRMA.
        // ⚠️⚠️⚠️ TURU 98c — **TASMA OLCULDU VE YAPISAL OLARAK KAPATILDI.**
        //
        //	Turu 98b'de bes eylemin DORDU sayi tasimaya basladi (begeni ·
        //	yorum · paylas · repost). 82b'nin sabit butcesi UC sayiya gore
        //	hesaplanmisti (`5*(5+26+5) + 3*(6+40) = 318dp`), dolayisiyla
        //	gecersiz kaldi. **360 dp'de EMULATORDE OLCULDU: satir 9.3 piksel
        //	TASIYOR ve KAYDET IKONU EKRAN DISINDA kaliyordu.**
        //	(411 dp test cihazinda GORUNMUYORDU — turu 70b/90b dersinin
        //	birebir tekrari: dar ekranda olcmeden "sigiyor" deme.)
        //
        // ⚠️⚠️ COZUM SABIT BUTCE DEGIL: her yeni sayi/ikon o butceyi yeniden
        //	bozar ve hata YINE dar ekranda ortaya cikar. Sol grup artik
        //	`Expanded` ile SINIRLI genislik alir ve `FittedBox(scaleDown)` ile
        //	**yalnizca GEREKTIGINDE** kucultulur:
        //	  · 411 dp / normal yazi -> olcek 1.0, HICBIR SEY degismez
        //	  · 360 dp -> ~%97, gozle fark edilmez
        //	  · yazi olcegi 1.3-2.0 -> orantili kucultme, TASMA YOK
        // ⚠️ Kaydet ikonu `FittedBox`IN DISINDA: saga dayali kalmali ve
        //    kucultulmemeli (tek ogedir, yer sorunu cikarmaz).
        // ⚠️ `Spacer` KALDIRILDI — `Expanded` zaten bosluu doldurur; ikisi
        //    birlikte iki esnek cocuk demek olurdu.
        // ⚠️ YAPMA: `FittedBox`i kaldirip sabit butce hesabina donme.
        Padding(
          // ⚠️⚠️ TURU 98m — CUBUK KENARLARI **MEDYAYLA AYNI HIZADA**
          //	(kullanici: "gorsel ile begen ikonu ayni hizada degil").
          //	_eylem kendi 5 dp yatay dolgusunu tasir: 11+5 = 16 (medya
          //	kenari). Sagda kaydet glyphi kutusundan 6 dp iceride: 10+6 = 16.
          // ⚠️ OLCULDU (emulator): sol 10 -> 16.0 ✓ · sag dolgu ARTINCA ikon
          //    ICERI kacar: 10 iken 19.8, 14 iken 24.0 idi -> 6 ile 16.
          padding: const EdgeInsets.fromLTRB(10, 2, 6, 0),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _eylem(
                          // ⚠️⚠️⚠️ TURU 98h — BEGENILINCE **DOLU KIRMIZI
                          //	KALP** (kullanici emri).
                          // ⚠️ Lucide 3.1.14te DOLU KALP YOK (heart ·
                          //	heartCrack · heartPlus · heartX ... hepsi
                          //	CIZGI). YALNIZ bu durumda Material
                          //	`Icons.favorite` kullanilir; bos hali Lucide.
                          // ⚠️ "Ikon seti karistirma" kurali BILEREK ve
                          //	TEK NOKTADA esnetildi.
                          ikon: g.begendim ? Icons.favorite : LucideIcons.heart,
                          sayi: g.begeniSayisi,
                          renk: g.begendim ? const Color(0xFFFF3B5C) : null,
                          vurgu: g.begendim,
                          onTap: _begeniCevir,
                          // ⚠️⚠️ Begenenler listesinin TEK girisi (alt satir
                          //    kaldirildi). Uzun basma GORUNMEZ bir yol oldugu icin
                          //    `tooltip` ile ipucu veriliyor — denetim "sifir ipucu"
                          //    diye bildirdi ve HAKLIYDI: bu projede "ozellik var ama
                          //    KESFEDILEMIYOR" hatasi turu 81'de de yasandi.
                          onUzunBas: g.begeniSayisi > 0 ? _begenenler : null,
                          ipucu: g.begeniSayisi > 0
                              ? 'Beğen · uzun bas: beğenenler'
                              : 'Beğen',
                        ),
                        _eylem(
                          ikon: LucideIcons.messageCircle,
                          sayi: g.yorumSayisi,
                          onTap: g.yorumKapali ? null : _yorumlariAc,
                        ),
                        // ⚠️⚠️ TURU 98b — PAYLAS ARTIK **SAYI** gosterir + yanina
                        //	**REPOST** ikonu (kullanici emri).
                        // ⚠️⚠️⚠️ **DURUST SINIR:** sunucuda paylasim/repost SAYACI
                        //	YOK. Sayi yalnizca DEMO verisinde doludur; gercek akista
                        //	`0` gelir ve `_eylem` sifiri HIC yazmaz (Threads deseni),
                        //	yani kullaniciya SAHTE bir sayi gosterilmez.
                        // ⚠️ Repost dokununca ne yapacagi HENUZ YOK: backend ucu,
                        //    tablo ve akis semantigi gerekiyor. Simdilik paylasim
                        //    sayfasini acar — kullaniciya "yakinda" demez, ISE
                        //    YARAR bir sey yapar.
                        _eylem(
                          ikon: LucideIcons.send,
                          sayi: g.paylasimSayisi,
                          onTap: () => _sohbeteGonder(context),
                        ),
                        _eylem(
                          // ⚠️ TURU 98h — kullanici emri: **alinti yap**
                          //    ( -> ).
                          ikon: LucideIcons.redo2,
                          sayi: g.repostSayisi,
                          onTap: () => _sohbeteGonder(context),
                          ipucu: "Yeniden paylaş",
                        ),
                        // ⚠️⚠️ ISTATISTIK IKONU — kullanici "hala istatistik ikonu yok" dedi.
                        //    Eskiden istatistik YALNIZ ••• menusunun icindeydi; menuye
                        //    girmeden gorunmuyordu, yani pratikte YOKTU.
                        //    Yanindaki sayi GORUNTULENME (Instagram'in "N goruntulenme"si).
                        // ⚠️ YALNIZ YAZARA gosterilir: baskasinin izlenme sayisi kullaniciya
                        //    bir sey ifade etmez ve dusuk sayi yazari utandirir.
                        if (g.yazarId == widget.benimId)
                          _eylem(
                            // ⚠️ TURU 98 — kullanici emri: istatistik ikonu **trendingUp**.
                            ikon: LucideIcons.trendingUp,
                            sayi: g.goruntulenme,
                            onTap: _istatistik,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
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
        // ---- AKISTA TEK YANIT (Threads deseni)
        //
        // ⚠️⚠️ TURU 98i — kullanici: *"anasayfada da bazen yorumlari
        //	gosteriyor"*. Gonderinin ALTINDA bir yanit ve sola dogru bir
        //	THREAD CIZGISI cizilir.
        // ⚠️ YALNIZ DEMODA (`demoAkisYaniti` null doner degilse): gercek
        //	akista sunucu boyle bir alan DONDURMUYOR, dolayisiyla hicbir
        //	kartta cizilmez.
        // ⚠️ Detay ekraniyla AYNI bilesen kullanilir (`DemoYorumSatiri`);
        //    ikinci bir kopya yazilsaydi drift ederdi.
        // ⚠️⚠️⚠️ TURU 101 — AKISTAKI TEK YANIT **DUZ DIKEY CIZGIYLE**
        //	baglanir (kullanici referansi: Threads akisinda gonderinin
        //	altindaki yanit sola DUZ bir cizgiyle baglidir — KIVRIM YOK;
        //	kivrim yalniz detaydaki "Yanıtları göster" hedefinde olur).
        // ⚠️ Cizgi gonderi avatarinin ALTINDAN baslar ve yanit avatarinin
        //    MERKEZINDE biter; iki ucu da avatar merkezine hizali.
        if (_akisYaniti != null)
          Stack(
            children: [
              // ⚠️⚠️ GEOMETRI **HEDEFTEN** TURER (turu 102 kurali):
              //	cizgi yanit avatarinin MERKEZINDEN gecer ve TAM O
              //	MERKEZDE biter. Turu 101'de sol dolgu gonderi avatarina
              //	(38 dp) gore hesaplaniyordu; cizgi merkezi 35, yanit
              //	avatarinin merkezi 33 idi -> **2 dp saga kacik**.
              // ⚠️ Yukseklik `bottom` ile verilemez: yigin yuksekligi yanit
              //	satirinin (medyaya gore degisen) boyudur; `bottom: 0`
              //	cizgiyi ICERIGIN ALTINA indirirdi. `height` ile avatar
              //	merkezinde durdurulur: ust dolgu (10) + capin yarisi.
              Positioned(
                left: kYanBosluk,
                top: 0,
                height: 10 + kYorumAvatar / 2,
                width: kYorumAvatar,
                child: CustomPaint(
                  painter: ThreadCizgi(
                    kivrimli: false,
                    renk: threadCizgiRengi(context),
                  ),
                ),
              ),
              YorumSatiri(y: _akisYanitGorunum!),
            ],
          ),

        // ⚠️⚠️ TURU 98b — KART SONU ILE AYRAC ARASI **12** (kullanici:
        //	*"ilk gonderinin sonu ile profil ismi bitisik olmus"*).
        //	Ayracin ALTINDA da nefes var (asagida): 8 + ayrac + 12 =
        //	sonraki kartin basligi artik yapisik degil.
        const SizedBox(height: 12),
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
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        // ⚠️ Ayractan SONRA da nefes: sonraki kartin `ListTile` basligi
        //    `dense` oldugu icin ayraca yapisiyordu.
        const SizedBox(height: 12),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: kKartYanDolgu,
                    ),
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
              // ⚠️⚠️ ANIMASYON `AnimatedOpacity` ILE **YAPILAMAZ** (denetim
              //    bulgusu): widget `if (_kalpGoster)` kapisinin ICINDE
              //    oldugu icin agaca ZATEN `opacity: 1` ile giriyor ve
              //    `AnimatedOpacity` gecis yapacak bir ONCEKI deger
              //    bulamiyordu -> **animasyon HIC OYNAMIYORDU** (olu kod).
              //    Cikarken de widget bir anda agactan siliniyordu.
              // ⚠️ `TweenAnimationBuilder` kapisiz calisir: her kuruldugunda
              //    0 -> 1 gecisini GERCEKTEN oynatir.
              // ⚠️ `ValueKey` ZORUNLU: art arda cift dokunusta widget yeniden
              //    kurulup animasyonun BASTAN oynamasi icin.
              if (_kalpGoster)
                IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_kalpSayac),
                    tween: Tween(begin: 0.6, end: 1.0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    builder: (_, t, cocuk) => Opacity(
                      // Sonda hafifce solar — "cok hafif" istegi.
                      opacity: (t.clamp(0.0, 1.0)) * 0.85,
                      child: Transform.scale(
                        scale: 0.85 + t * 0.15,
                        child: cocuk,
                      ),
                    ),
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
        // ⚠️ TURU 98 — DEMO'da medya kutusu **GRI** (kullanici: *"gri
        //    icerikler olsun"*). Gercek akista koyu kalir: fotograf/video
        //    letterbox'i icin dogru olan odur.
        color: kDemoAkis ? kYuzeyGri(context) : const Color(0xFF0B0B12),
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
    // ⚠️ TURU 98h — DOLU kalp (Material) cizgili kalpten daha "dolgun"
    //    gorunur; 26 yerine 24 ile ayni optik agirliga oturur.
    if (ikon == Icons.favorite) return 24;
    if (ikon == LucideIcons.messageCircle) return 23;
    // ⚠️ TURU 98h — PAYLAS 24 -> **23** (kullanici: *"paylas digerlerine
    //    gore bir tik buyuk, o da esit olsun"*).
    if (ikon == LucideIcons.send) return 23;
    if (ikon == LucideIcons.bookmark) return 24;
    if (ikon == LucideIcons.trendingUp) return 24;
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
    String? ipucu,
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
    final govde = InkWell(
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
              // ⚠️⚠️ TAVAN 40 -> **46dp** (denetim bulgusu). Sayi bicimi turu
              //    83'te "999B" (4 karakter) yerine **"1,3 bin"** (7 karakter)
              //    uretmeye basladi; 13px'te ~46dp eder ve 40dp tavan sayaci
              //    NORMAL yazi olceginde bile KIRPIYORDU ("1,3 b…").
              //    Yani turun kendi getirdigi bicim, kendi tavanini asiyordu.
              // ⚠️ Tavan yine SERT: yazi olcegi ne olursa olsun ellipsis
              //    devreye girer, TASMA yapisal olarak IMKANSIZ kalir.
              //    Worst-case (yazarin kendi gonderisi, UC sayac da dolu):
              //      5*(5+26+5) + 3*(6+46) = 336dp
              //    En dar telefonda (360dp ekran, kolon 348) 12dp pay kalir.
              // ⚠️ 46'nin uzerine cikarma: 52'de worst-case 354dp olur ve
              //    360dp telefonda TASAR.
              // ⚠️ YAPMA: bu tavani kaldirma ya da `Flexible` ile degistirme —
              //    `Flexible` bu Row'da (mainAxisSize.min, dis Row'un esnek
              //    OLMAYAN cocugu) sinirsiz kisit alir ve HICBIR SEY YAPMAZ.
              ConstrainedBox(
                // ⚠️ TURU 98h — yazi 13 -> 15 olunca tavan da buyudu
                //    (46 -> 54); tasma korumasini `FittedBox` yapiyor.
                constraints: const BoxConstraints(maxWidth: 54),
                // ⚠️⚠️⚠️ TURU 98h — SAYI DEGISINCE **YUKARI KAYARAK**
                //	degisir ve begenildiyse **KIRMIZI** olur (kullanici
                //	emri: *"yanindaki sayi yukari efekt olacak, sayi
                //	artisi yazida kirmizi olacak"*).
                //
                // ⚠️ `ValueKey(sayi)`: anahtar degismezse `AnimatedSwitcher`
                //	HICBIR SEY oynatmaz — eski/yeni ayni widget sayilir.
                // ⚠️ Cikan eski sayi YUKARI, gelen yeni sayi ASAGIDAN
                //	gelir; ikisi de ayni yonde akar (sayac hissi).
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (cocuk, an) => ClipRect(
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.6),
                        end: Offset.zero,
                      ).animate(an),
                      child: FadeTransition(opacity: an, child: cocuk),
                    ),
                  ),
                  child: Text(
                    sayiBicimle(sayi),
                    key: ValueKey<int>(sayi),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c,
                      // ⚠️ TURU 98h — kullanici: *"yazilar ikonlarla AYNI
                      //    boyutta olsun"*. Ikon murekkebi ~23 dp; 15 punto
                      //    metnin gorunen yuksekligi buna oturur.
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    // ⚠️ `Tooltip` uzun basmada da cikar; `onLongPress` ILE CAKISMAZ
    //    (Tooltip kendi jestini `GestureDetector` uzerinden DEGIL,
    //    `Listener` ile kurar ve olayi TUKETMEZ).
    return ipucu == null ? govde : Tooltip(message: ipucu, child: govde);
  }

  /// ⚠️ TURU 76: eskiden YALNIZCA panoya kopyalayip "sohbete yapistirin" diyordu.
  ///    Artik gercek paylasim sayfasi (coklu sohbet secimi + kopyala) aciliyor.
  Future<void> _sohbeteGonder(BuildContext context) async {
    if (_demo) return _demoUyar();
    return _sohbeteGonderAsil(context);
  }

  Future<void> _sohbeteGonderAsil(BuildContext context) =>
      paylasSheetAc(context, ref, baglanti: 'https://gebzem.app/p/${g.id}');

  /// TURU 76 — begeni sayisina dokununca BEGENENLER listesi (Instagram deseni).
  /// ⚠️ Servis ucu (`begenenler`) turu 75'ten beri VARDI ama HICBIR EKRAN
  ///    CAGIRMIYORDU — olu kod. Kullaniciya gorunur hale getirildi.
  Future<void> _begenenler() async {
    if (_demo) return _demoUyar();
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
/// ⚠️⚠️⚠️ ILK YAZIMDA IKI HATA VARDI — ikisi de KENDI KONTROLUMDE olculdu:
///
///   1. **`replaceAll(',0', '')` GLOBAL bir dize islemiydi.** Bir deger 10'un
///      hemen ALTINDAYKEN yuvarlanip "10.0" uretirse (or. 9,95 -> "10.0")
///      sonuc "10,0" olur ve global replace ",0"yi silip **"1"** birakirdi:
///      **9.950 begeni "1 bin" yerine "1" gorunurdu — 10 KAT HATA.**
///   2. **`999.999` bin dalinda kalip "1000 bin" uretiyordu** (olmasi gereken
///      "1 mn"). Ustelik 8 karakterdi ve serhim "tavan 6 karakter, '1000 bin'
///      OLUSAMAZ" diyordu — **serh govdeyi yanlis anlatiyordu.**
///
/// ⚠️ COZUM: ONCE YUVARLA, SONRA BIRIM SEC. Dize ameliyati YOK; ondalik
///    basamak sayisi karara gore veriliyor ve virgul TEK SEFER cevriliyor.
/// ⚠️ Cikti TAVANI: **7 karakter** ("999 bin"). Etkilesim cubugundaki 40dp
///    sert tavan bunu varsayar.
/// ⚠️ YAPMA: `.0` kirpmayi tekrar `replaceAll` ile yapma.
String sayiBicimle(int n) {
  if (n < 0) return '0';
  if (n < 1000) return '$n';

  /// Deger + birim uretir. [x] birime bolunmus deger.
  /// Ondalik YALNIZ 10'un altinda ve kirpildiktan SONRA hala anlamliysa yazilir.
  String bicim(double x, String birim) {
    final tekBasamak = (x * 10).round() / 10;
    // ⚠️⚠️ **CIFT YUVARLAMA TUZAGI**: burada `tekBasamak.round()` yazmak
    //    HATALIYDI. 999,499 once 0,1 basamagina yuvarlanip 999,5 oluyor,
    //    sonra tam sayiya yuvarlanip **1000** cikiyordu ("1000 bin").
    //    Tam sayi dali HAM degerden (`x`) yuvarlanir; `tekBasamak` yalnizca
    //    "ondalik gerekli mi" KARARI icin kullanilir.
    if (tekBasamak >= 10) return '${x.round()} $birim';
    final tam = tekBasamak.truncate();
    final ondalik = ((tekBasamak - tam) * 10).round();
    return ondalik == 0 ? '$tam $birim' : '$tam,$ondalik $birim';
  }

  final bin = n / 1000;
  // ⚠️ Terfi olcutu **YUVARLANMIS** degere bakar: 999.500 yuvarlaninca
  //    "1000 bin" olurdu, bu yuzden milyona gecer. 999.499 ise "999 bin"
  //    olarak KALIR (dogru ve daha kisa).
  if (bin.round() < 1000) return bicim(bin, 'bin');
  return bicim(n / 1000000, 'mn');
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../../core/api.dart';
import '../chats/chats_provider.dart';
import '../chats/moderasyon_sheet.dart';
import '../home/profil_duzenle.dart';
import '../isletme/isletme_duzenle.dart';
import '../isletme/isletme_servisi.dart';
import '../diyet/diyet_servisi.dart';
import '../randevu/randevu_al.dart';
import '../isletme/urun_ekranlari.dart';
import '../medya/medya_gorsel.dart';
import 'gonderi_karti.dart' show sayiBicimle;
import '../medya/tam_ekran_gorsel.dart';
import 'gonderi_detay.dart';
import 'profil_basligi.dart';
import '../home/home_screen.dart' show HesabimEkrani, myProfileProvider;
import '../ilan/ilan_ekranlari.dart' show IlanDetayEkrani;
import '../ilan/ilan_servisi.dart';
import '../talep/talep_servisi.dart' show dugunKategorileri;
import 'sosyal_servisi.dart';
import 'kaydedilenler_sayfasi.dart';
import 'takip_listesi.dart';

/// ⚠️⚠️ TURU 75 — KULLANICI PROFILI (Instagram duzeni).
///
/// ⚠️ GIZLI HESAP KAPISI: `icerikKilitli` ise gonderiler CEKILMEZ — sunucu zaten
///    403 doner ama bosuna istek atmak hem gecikme hem gurultu.
///
/// ⚠️ ENGELLEME BURADAN DA YAPILIR: App Store 1.2 engellemeyi kullanici uretimi
///    icerigin GORULDUGU her yerde erisilebilir kilmayi bekliyor; sohbete girmek
///    zorunda birakmak kabul edilmez.
/// ⚠️⚠️⚠️ TURU 108 — PROFIL SEKMELERI (kullanici emri: *"profilde gonderi,
///	ses, video, reels, verilen ilan, dolap yani 2.el ilanlar gorunmeli;
///	ilanlarim, taleplerim burada olsun"*).
///
/// ⚠️⚠️ **ENUM, `int` DEGIL.** Eski hal duz bir indeksti (0/1/2) ve anlami
///	UC AYRI yerde kodluydu: suzgec · bos metin · serit. Uc girisken sekiz
///	girise cikinca bu, CLAUDE.md'de kayitli **"6'ya ekle, 7.'yi unut"**
///	sinifidir (turu 76'da "Kaydedilenler"i BOMBOS birakan hata). Enum,
///	`switch`te eksik dal birakilirsa DERLEYICIYI patlatir.
/// ⚠️ Ayrica kosullu sekmeler (`_benimMi`) `int` indekslerini KAYDIRIRDI:
///    birinde 5 = Ilanlarim, otekinde 5 = baska bir sey.
/// ⚠️⚠️ TURU 115 — enum **PUBLIC** (eski adi `_Sekme`): `HesabimEkrani`
///	listesindeki "Hizmetlerim"/"Düğünüm"/"İlanlarım"/"Taleplerim"
///	kisayollari profili DOGRUDAN o sekmede aciyor. Ikinci bir liste ekrani
///	yazilmadigi icin liste/yukleme/bos-durum mantigi TEK YERDE kaliyor.
enum ProfilSekmesi {
  tumu,
  foto,
  video,
  reels,
  ses,
  ilan,
  dolap,
  hizmet,
  talep,
  dugun,
}

extension ProfilSekmesiBilgi on ProfilSekmesi {
  String get etiket => switch (this) {
    ProfilSekmesi.tumu => 'Gönderiler',
    ProfilSekmesi.foto => 'Fotoğraf',
    ProfilSekmesi.video => 'Video',
    ProfilSekmesi.reels => 'Reels',
    ProfilSekmesi.ses => 'Ses',
    ProfilSekmesi.ilan => 'İlanlarım',
    ProfilSekmesi.dolap => 'Dolap',
    ProfilSekmesi.hizmet => 'Hizmetlerim',
    ProfilSekmesi.talep => 'Taleplerim',
    ProfilSekmesi.dugun => 'Düğünüm',
  };

  IconData get ikon => switch (this) {
    ProfilSekmesi.tumu => LucideIcons.layoutGrid,
    ProfilSekmesi.foto => LucideIcons.image,
    ProfilSekmesi.video => LucideIcons.video,
    ProfilSekmesi.reels => LucideIcons.clapperboard,
    ProfilSekmesi.ses => LucideIcons.audioLines,
    ProfilSekmesi.ilan => LucideIcons.tag,
    ProfilSekmesi.dolap => LucideIcons.shirt,
    ProfilSekmesi.hizmet => LucideIcons.wrench,
    ProfilSekmesi.talep => LucideIcons.clipboardList,
    ProfilSekmesi.dugun => LucideIcons.heartHandshake,
  };

  String get bosMetin => switch (this) {
    ProfilSekmesi.tumu => 'Henüz gönderi yok',
    ProfilSekmesi.foto => 'Henüz fotoğraf yok',
    ProfilSekmesi.video => 'Henüz video yok',
    ProfilSekmesi.reels => 'Henüz reels yok',
    ProfilSekmesi.ses => 'Henüz ses paylaşımı yok',
    ProfilSekmesi.ilan => 'Henüz ilan vermedin',
    ProfilSekmesi.dolap => 'Dolabında ürün yok',
    ProfilSekmesi.hizmet => 'Henüz hizmet ilanın yok',
    ProfilSekmesi.talep => 'Henüz talebin yok',
    ProfilSekmesi.dugun => 'Henüz düğün talebin yok',
  };

  /// Sunucu `?tur=` degeri (gonderi sekmeleri icin).
  ///
  /// ⚠️ **SES ICIN AYRI TUR YOK**: `posts.tur` CHECK'i (migration 021)
  ///    yalniz `foto|video|reels|yazi` kabul eder. Ses gonderisi
  ///    `tur='foto'` + `media_kinds[0]=='audio'`tir; bu yuzden Ses de
  ///    Fotograf da AYNI sayfayi ceker, ayrim ISTEMCIDE yapilir.
  /// ⚠️ Reels ISTEMCIDE ayirt EDILEMEZ (medya turu yine `video`) — sunucu
  ///    suzgeci ZORUNLU.
  String? get sunucuTuru => switch (this) {
    ProfilSekmesi.foto || ProfilSekmesi.ses => 'foto',
    ProfilSekmesi.video => 'video',
    ProfilSekmesi.reels => 'reels',
    _ => null,
  };

  /// ⚠️ Ilan tabanli sekmeler YALNIZ kendi profilimde: `/ilanlar` ucunda
  ///    `?user_id=` YOKTUR (yalniz `benim=1`), yani baskasinin ilanlarini
  ///    listeleyecek bir yol YOK. Menude HIC gosterilmez.
  bool get ilanMi =>
      this == ProfilSekmesi.ilan ||
      this == ProfilSekmesi.dolap ||
      this == ProfilSekmesi.hizmet ||
      this == ProfilSekmesi.talep ||
      this == ProfilSekmesi.dugun;

  /// Ilan turu (`/ilanlar?tur=`).
  String get ilanTuru => switch (this) {
    ProfilSekmesi.dolap => 'ikinci_el',
    ProfilSekmesi.hizmet => 'hizmet',
    // ⚠️ Dugun AYRI BIR TUR DEGIL: sunucuda dugun talepleri de
    //    `tur='talep'`tir, yalniz KATEGORILERI farklidir. Ayrim asagida
    //    (`_dugunMu`) sunucunun agacindan gelen bayrakla yapilir.
    ProfilSekmesi.talep || ProfilSekmesi.dugun => 'talep',
    _ => '',
  };
}

class ProfilSayfasi extends ConsumerStatefulWidget {
  const ProfilSayfasi({
    super.key,
    required this.userId,
    this.sekmeModu = false,
    this.baslangicSekmesi,
  });
  final String userId;

  /// ⚠️⚠️ TURU 108 — ALT MENUNUN PROFIL SEKMESI (kullanici emri: *"profile
  ///	tikladigimda DIREK PROFIL gelmeli"*). Eskiden o sekme AYARLAR
  ///	listesini aciyordu; kendi profiline ulasmak IKI dokunustu.
  ///
  /// Sekme modunda:
  ///   · geri oku YOK (sekmenin altinda bir yigin yok),
  ///   · AppBar'da **dis carkla** hesap/ayarlar listesine gecilir,
  ///   · sekmeye her donuste liste TAZELENIR (`IndexedStack` cocugu CANLI
  ///     tutar; `initState` bir kez kosar ve yeni gonderi GORUNMEZDI).
  final bool sekmeModu;

  /// ⚠️⚠️ TURU 115 — profil BELIRLI BIR SEKMEDE acilir (`Hesabım` >
  ///	"Hizmetlerim" / "Düğünüm" / "İlanlarım" / "Taleplerim").
  ///
  /// ⚠️ Ikinci bir liste ekrani YAZILMADI: liste sorgusu, yukleme, bos
  ///    durum ve hata dallari TEK YERDE (bu dosyada) kaliyor. Ayri bir
  ///    ekran acilsaydi "ayni kuralin iki kopyasi drift eder" sinifi.
  /// ⚠️ `null` = varsayilan (Gönderiler).
  final ProfilSekmesi? baslangicSekmesi;

  @override
  ConsumerState<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends ConsumerState<ProfilSayfasi> {
  Profil? _p;

  /// ⚠️⚠️ SEKME BASINA ONBELLEK. Sunucu profil gonderilerini **LIMIT 30**
  ///	ile donduruyor ve sayfalama YOK; tek listeyi istemcide suzmek uc
  ///	sekmede "durust sinir" iken sekiz sekmede YALAN olurdu (30
  ///	fotografi olan hesabin videosu HIC gorunmezdi).
  /// ⚠️ Her sekme ILK secildiginde kendi istegini atar; sonraki secimlerde
  ///    AG ISTEGI YOK. Asagi-cek TUM onbellegi temizler.
  final Map<ProfilSekmesi, List<Gonderi>> _gonderiOnbellek = {};
  final Map<ProfilSekmesi, List<Ilan>> _ilanOnbellek = {};
  final Set<ProfilSekmesi> _sekmeYukleniyor = {};
  final Map<ProfilSekmesi, String> _sekmeHata = {};
  ProfilSekmesi _sekme = ProfilSekmesi.tumu;

  /// Menunun capalanacagi dugme.
  final _seciciAnahtar = GlobalKey();
  bool _yukleniyor = true;
  bool _takipMesgul = false;


  /// ⚠️ Bu profil BENIM mi. myProfileProvider ASENKRON yuklenir; henuz gelmediyse
  ///    false olur ve o kisa anda yabanci dugmeleri cizilir — zararsiz, cunku
  ///    build provider degisiminde yeniden kosar.
  bool _benimMi = false;
  String? _hata;

  /// ⚠️⚠️ TURU 115 — sekmeler arasi GERCEK sayfali kaydirma.
  ///
  /// ⚠️ `initState`te kurulur, `build` icinde DEGIL: her cizimde yeni bir
  ///    controller olusturmak kaydirma konumunu SIFIRLAR (turu 76b dersi).
  late final PageController _sayfaCtrl;

  @override
  void initState() {
    super.initState();
    // ⚠️ TURU 115 — istenen sekme BASTAN secilir; verisi `_yukle`den sonra
    //    `_sekmeYukle` ile gelir (asagidaki cagri).
    final b = widget.baslangicSekmesi;
    if (b != null) _sekme = b;
    // ⚠️ `_sekmeler` `_benimMi`ye bagli ve o daha yuklenmedi; baslangic
    //    sayfasi TAM LISTEDEN hesaplanir (`ProfilSekmesi.values`).
    _sayfaCtrl = PageController(
      initialPage: ProfilSekmesi.values.indexOf(_sekme).clamp(0, 9),
    );
    _yukle();
  }

  @override
  void dispose() {
    _sayfaCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    // ⚠️ TURU 82b — YENIDEN GIRME KAPISI. `_yukle` BES yerden cagriliyor
    //    (asagi-cek · takip · engelle · profil duzenlemeden donus · gizli
    //    hesap anahtari); ucusta bir istek varken ikincisini acmak iki paralel
    //    yukleme ve yaris demekti. `_p != null` sarti ZORUNLU: gercek ilk
    //    yuklemeyi ENGELLEMEMELI.
    if (_yukleniyor && _p != null) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final s = ref.read(sosyalServisiProvider);
      final p = await s.profil(widget.userId);
      if (!mounted) return;
      List<Gonderi> g = [];
      if (!p.icerikKilitli) {
        try {
          g = await s.kullaniciGonderileri(widget.userId);
        } catch (_) {
          // Gonderiler alinamadi ama PROFIL gorunmeli — kismi basari.
        }
      }
      if (!mounted) return;
      setState(() {
        _p = p;
        // ⚠️ Asagi-cek TUM sekme onbellegini temizler: yalniz aktif
        //    sekmeyi tazelemek digerlerini BAYAT birakirdi.
        _gonderiOnbellek
          ..clear()
          ..[ProfilSekmesi.tumu] = g;
        _ilanOnbellek.clear();
        _sekmeHata.clear();
        _yukleniyor = false;
      });
      // ⚠️⚠️⚠️ TURU 113 (denetim, YUKSEK) — **AKTIF SEKME YENIDEN YUKLENIR.**
      //
      //	Usttteki `clear()` TUM sekme onbellegini bosaltir ama `_sekmeYukle`
      //	YALNIZ iki yerden cagriliyordu (menuden secim · "Tekrar dene").
      //	Yani kullanici "İlanlarım"/"Videolar"/"Ses" sekmesindeyken
      //	asagi-cekerse: spinner YOK (`_sekmeYukleniyor` bos), tekrar-dene
      //	YOK (`_sekmeHata` temizlendi), liste BOS -> ekran **"Henüz ilanın
      //	yok"** yaziyordu. Kullanicinin KENDI verisi hakkinda YALAN.
      //	Ayni yol takip · engelle · profil duzenlemeden donusle de
      //	tetikleniyordu; tek kurtarma baska sekmeye gecip geri gelmekti.
      // ⚠️ `tumu` HARIC: onu yukaridaki `kullaniciGonderileri` zaten yazdi.
      // ⚠️ YAPMA: bu satiri kaldirma.
      if (_sekme != ProfilSekmesi.tumu) unawaited(_sekmeYukle(_sekme));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = e.toString().contains('404')
            ? 'Kullanıcı bulunamadı'
            : 'Profil yüklenemedi';
      });
    }
  }

  Future<void> _takipCevir() async {
    final p = _p;
    if (p == null || _takipMesgul) return;
    setState(() => _takipMesgul = true);
    final eskiTakip = p.takipEdiyorum;
    final eskiIstek = p.istekBekliyor;
    final eskiSayi = p.takipciSayisi;
    try {
      final s = ref.read(sosyalServisiProvider);
      if (eskiTakip || eskiIstek) {
        await s.takibiBirak(p.id);
        if (!mounted) return;
        setState(() {
          p.takipEdiyorum = false;
          p.istekBekliyor = false;
          // ⚠️ Sayac YALNIZ onayli takip dususe gecer (bekleyen istek sayaca
          //    hic girmemisti — backend de ayni kurali uyguluyor).
          if (eskiTakip) p.takipciSayisi = (eskiSayi - 1).clamp(0, 1 << 30);
        });
      } else {
        final onayli = await s.takipEt(p.id);
        if (!mounted) return;
        setState(() {
          p.takipEdiyorum = onayli;
          p.istekBekliyor = !onayli;
          if (onayli) p.takipciSayisi = eskiSayi + 1;
        });
        // Gizli hesabi yeni takip ettiysek gonderiler ARTIK gorulebilir.
        // ⚠️ Onbellek: gizli hesabi yeni takip ettiysek gonderiler ARTIK
        //    gorulebilir; TUM sekmeler bayat oldugu icin bastan yuklenir.
        if (onayli && (_gonderiOnbellek[ProfilSekmesi.tumu] ?? const []).isEmpty) {
          unawaited(_yukle());
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        p.takipEdiyorum = eskiTakip;
        p.istekBekliyor = eskiIstek;
        p.takipciSayisi = eskiSayi;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı')));
    } finally {
      if (mounted) setState(() => _takipMesgul = false);
    }
  }

  Future<void> _menu() async {
    final p = _p;
    if (p == null) return;
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚠️ Kendi profilimde engelle/sikayet ANLAMSIZ (denetim bulgusu).
            if (!_benimMi)
              ListTile(
                leading: Icon(
                  p.engelledim ? LucideIcons.userCheck : LucideIcons.ban,
                ),
                title: Text(p.engelledim ? 'Engeli kaldır' : 'Engelle'),
                onTap: () => Navigator.pop(c, 'engel'),
              ),
            if (!_benimMi)
              ListTile(
                leading: const Icon(LucideIcons.flag),
                title: const Text('Şikayet et'),
                onTap: () => Navigator.pop(c, 'sikayet'),
              ),
            if (_benimMi)
              ListTile(
                leading: const Icon(LucideIcons.link),
                title: const Text('Profil bağlantısını kopyala'),
                onTap: () => Navigator.pop(c, 'link'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || secim == null) return;
    if (secim == 'link') {
      final ad = p.username.isEmpty ? p.id : p.username;
      await Clipboard.setData(ClipboardData(text: 'https://gebzem.app/u/$ad'));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
    } else if (secim == 'sikayet') {
      await sikayetSheetAc(context, ref, hedefTur: 'kullanici', hedefId: p.id);
    } else if (secim == 'engel') {
      final onay = await engelleOnayiAc(
        context,
        ref,
        kullaniciId: p.id,
        ad: p.ad,
        suAnEngelli: p.engelledim,
      );
      // ⚠️ Engelleme takibi de DUSURUR (backend `takibiKaldir` cagiriyor) —
      //    bu yuzden profili TAMAMEN yeniden yukluyoruz, yerel yamalama YOK.
      if (onay && mounted) unawaited(_yukle());
    }
  }

  @override
  Widget build(BuildContext context) {
    _benimMi =
        (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '').toString() ==
        widget.userId;
    // ⚠️⚠️⚠️ TURU 82b — "PROFILDE YENILEDIGIMDE EKRAN PATLIYOR, BEYAZ OLUYOR"
    //    (kullanici bildirimi). **KOK NEDEN BURASIYDI.**
    //
    //    Bu satir `_yukleniyor` bayragina bakiyordu ve o bayrak SADECE ilk
    //    yuklemede degil **HER YENILEMEDE** true oluyor. Kosul asagidaki
    //    `Scaffold` + `AppBar` + `RefreshIndicator` + `ListView`in USTUNDE
    //    oldugu icin asagi-cek jesti sayfanin TAMAMINI agactan siliyordu:
    //      · AppBar gidiyor        -> geri dugmesi kayboluyor
    //      · RefreshIndicator gidiyor -> jestin sahibi yok oluyor
    //      · kapak/avatar/sayaclar/izgara gidiyor
    //    Geriye AppBar'siz bos bir `Scaffold` kaliyor ve **turu 81'in ACIK
    //    TEMASI** ile zemin `0xFFF2F2F5` oldugu icin ekran BEYAZ patliyor.
    //    (Koyu temada da ayni sey oluyordu, sadece "normal yukleme" gibi
    //    goründügü için fark edilmemisti — acik tema bedeli gorunur yapti.)
    //
    //    ⚠️ Ayni yol BES kullanici eyleminde tetikleniyordu: asagi-cek ·
    //       takip etme · engelleme · profili duzenleyip donme · gizli hesap
    //       anahtari. Yani hata "yenileme"den cok daha genis bir yuzeydeydi.
    //
    // FIX: tam sayfa bosaltma YALNIZ **gercek ilk yuklemede** (`_p == null`).
    // Yenilemede ESKI PROFIL EKRANDA KALIR; donen spinner'i zaten
    // `RefreshIndicator` ciziyor.
    // ⚠️ `AppBar()` KORUNDU — ilk yuklemede bile geri dugmesi kaybolmasin.
    // ⚠️ YAPMA: kosulu tekrar ciplak `_yukleniyor`a dondurme.
    if (_yukleniyor && _p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _p;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_hata ?? 'Profil açılamadı'),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _yukle,
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // ⚠️⚠️⚠️ TURU 108 — **SEFFAF HEADER** (kullanici emri).
      //
      // ⚠️ `extendBodyBehindAppBar` TEK BASINA YETMEZ: Scaffold o modda
      //    govdeye `padding.top = max(durumCubugu, appBarBoyu)` verir ve
      //    `ListView` (padding: null) bunu OTOMATIK uygular -> kapak ~90 dp
      //    ASAGI ITILIR, tepede bos serit kalir. Bu yuzden asagida
      //    `padding` ACIKCA veriliyor. Hata SESSIZ: analyze temiz, uygulama
      //    cokmez, yalniz EKRANDA gorunur.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // ⚠️ Sekme modunda geri oku YOK: altinda bir yigin yok.
        automaticallyImplyLeading: !widget.sekmeModu,
        title: Text(p.username.isEmpty ? p.ad : '@${p.username}'),
        actions: [
          // ⚠️⚠️ HESABIM GIRISI — eski profil sekmesindeki 15 satirin (isletme
          //    hesabi · randevular · basvurular · bildirim · engellenenler ·
          //    ayarlar · cikis) BASKA girisi YOK. ⚠️ YAPMA: bunu kaldirma.
          if (widget.sekmeModu && _benimMi)
            IconButton(
              tooltip: 'Hesabım',
              icon: const Icon(LucideIcons.settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HesabimEkrani()),
              ),
            ),
          IconButton(icon: const Icon(LucideIcons.ellipsis), onPressed: _menu),
        ],
      ),
      body: YenileSarmali(
        onRefresh: _yukle,
        child: ListView(
          // ⚠️ TURU 82b — `AlwaysScrollableScrollPhysics` ZORUNLU: icerigi
          //    ekrandan KISA profillerde (gonderisi olmayan hesap) Android'in
          //    varsayilan `ClampingScrollPhysics`i overscroll uretmedigi icin
          //    asagi-cek jesti HIC TETIKLENMIYORDU — yani o hesaplarda
          //    yenileme yolu FIILEN YOKTU. Turu 77b'de akis icin duzeltilen
          //    sinifin aynisi.
          physics: const AlwaysScrollableScrollPhysics(),
          // ⚠️ Bkz. `extendBodyBehindAppBar` serhi: padding ACIKCA verilmezse
          //    `BoxScrollView` MediaQuery dikey dolgusunu otomatik uygular ve
          //    kapak AppBar'in ARKASINA GECMEZ.
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            // ⚠️⚠️ TURU 78 — KAPAK + LOGO/AVATAR + ONAYLI ROZET.
            //    Ust `SizedBox(height: 16)` KALDIRILDI: kapak AppBar'a YAPISIK
            //    baslamali, arada bosluk olursa "arka plan resmi" hissi kaybolur.
            // ⚠️ `SliverAppBar`a GECILMEDI (bilincli): bu sayfa `ListView` +
            //    `RefreshIndicator` + `shrinkWrap` izgara + kilitli hesap dali
            //    uzerine kurulu; sliver'a gecmek 756 satirin cekirdegini bastan
            //    yazmak demek. Kazanc yalnizca "kapak kaydirirken cokme"
            //    animasyonu olurdu ve ayni turda kapak + rozet + sliver birlikte
            //    degisseydi bir ariza cikinca SEBEP AYIRT EDILEMEZDI (turu 67).
            ProfilBasligi(
              p: p,
              // ⚠️ Avatara dokunus YALNIZ gercek bir medya varsa is yapar.
              //    `avatarMediaId` bossa (harf avatari) `onTap` NULL gecilir —
              //    dokunulabilir gorunup hicbir sey yapmayan bir alan
              //    birakmak bu projede tekrar eden "olu dugme" sinifidir.
              onAvatarDokun: (p.avatarMediaId ?? '').isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TamEkranGorsel(mediaId: p.avatarMediaId!),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            ProfilAdSatiri(ad: p.ad, onayli: p.onayli),
            if (p.gizli)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.lock, size: 13, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'Gizli hesap',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            if (p.hakkinda.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 10, 30, 0),
                child: Text(p.hakkinda, textAlign: TextAlign.center),
              ),
            if (p.baglanti.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text(
                    p.baglanti,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ),
            // TURU 77 — ISLETME BILGI SERIDI. Profil bir ISLETME hesabiysa
            // kategori/adres/telefon/calisma saatleri ve Urunler/Menu girisi
            // burada cizilir. Kisisel hesapta HIC cizilmez.
            _isletmeSeridi(p),
            const SizedBox(height: 16),
            _sayaclar(p),
            const SizedBox(height: 14),
            _dugmeler(p),
            const SizedBox(height: 8),
            const Divider(height: 1),
            if (p.icerikKilitli)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                child: Column(
                  children: [
                    Icon(LucideIcons.lock, size: 42, color: Colors.grey),
                    SizedBox(height: 14),
                    Text(
                      'Bu hesap gizli',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gönderilerini görmek için takip isteği gönder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            else ...[
              // ⚠️ TURU 82b — INSTAGRAM TARZI SEKME SERIDI (kullanici emri:
              //    *"profilde gonderi, fotograf, video vb alan olsun Instagram
              //    gibi, hepsi bir yerde, tikladiginda ona gecsin"*).
              _sekmeSecici(),
              // ⚠️⚠️⚠️ TURU 114 — **SEKMELER ARASI YATAY KAYDIRMA** (kullanici
              //	emri: *"profilde gonderi fotograf video sol sag kaydirmali
              //	olsun"*).
              //
              // ⚠️⚠️ `PageView` **KULLANILMADI** ve bu bilincli bir karar:
              //	sekme icerikleri (izgara / ilan listesi / bos durum) FARKLI
              //	YUKSEKLIKTE ve hepsi DIS `ListView`in cocugu olarak akiyor.
              //	`PageView` sayfalarina SINIRSIZ yukseklik verilemez; sabit
              //	bir yukseklik vermek ya icerigi KIRPARDI ya da kisa
              //	sekmelerde devasa bos alan birakirdi. Ustelik `PageView`
              //	tum sekmeleri agacta CANLI tutar — on sekmenin izgarasi
              //	aynı anda medya cozerdi (turu 76b ses/pil dersi).
              //
              //	Bunun yerine JEST yakalanir: yatay suruklemede bir onceki /
              //	sonraki sekmeye gecilir. Dikey kaydirma ETKILENMEZ — jest
              //	arenasinda yatay ve dikey tanıyıcılar AYRI eksenlerde
              //	yarisir.
              // ⚠️ `HitTestBehavior.opaque`: bos/hata durumlarinda cizilen
              //    alan da jesti ALIR (aksi halde tam o durumda kaydirma
              //    calismazdi — kullanici "bazen oluyor" derdi).
              // ⚠️⚠️⚠️ TURU 115 — **GERCEK SAYFALI KAYDIRMA** (kullanici:
              //	*"profilde gonderi fotograf scroll SOL SAG gibi olacak dedim,
              //	onu da yapmadin"*).
              //
              //	Turu 114 yalnizca bir JEST eklemisti (`onHorizontalDragEnd`):
              //	icerik parmakla KAYMIYOR, aninda degisiyordu. Artik `PageView`
              //	var — icerik parmagi TAKIP EDER ve yaslanir.
              //
              // ⚠️⚠️ SABIT YUKSEKLIK ZORUNLU: `PageView` cocuklarina SINIRSIZ
              //	yukseklik VERILEMEZ ve bu blok dis `ListView`in cocugu.
              //	Yukseklik EKRANDAN turetilir (sabit px DEGIL, yazi olcegi
              //	buyudugunde de oranli kalir).
              // ⚠️ `PageView` komsu sayfayi ONCEDEN KURMAZ
              //    (`allowImplicitScrolling` varsayilan false), yani on
              //    sekmenin izgarasi AYNI ANDA medya cozmez (turu 76b dersi).
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.62,
                child: PageView.builder(
                  controller: _sayfaCtrl,
                  itemCount: _sekmeler.length,
                  // ⚠️ Secici ile sayfa SENKRON: kaydirinca ustteki etiket de
                  //    degisir ve gerekiyorsa veri CEKILIR.
                  onPageChanged: (i) {
                    final x = _sekmeler[i];
                    if (x == _sekme) return;
                    setState(() => _sekme = x);
                    unawaited(_sekmeYukle(x));
                  },
                  itemBuilder: (_, i) => _sekmeSayfasi(_sekmeler[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Isletme profiliyse bilgi seridi; degilse HIC yer kaplamaz.
  Widget _isletmeSeridi(Profil p) =>
      IsletmeSeridi(userId: p.id, ad: p.ad, benimMi: _benimMi);

  Widget _sayaclar(Profil p) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _sayac('Gönderi', p.gonderiSayisi, null),
      _sayac(
        'Takipçi',
        p.takipciSayisi,
        // ⚠️ Gizli hesabin listeleri kilitli (sunucu 403); dokunusu KAPAT.
        p.icerikKilitli
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TakipListesi(
                    userId: p.id,
                    tur: 'followers',
                    baslik: 'Takipçiler',
                  ),
                ),
              ),
      ),
      _sayac(
        'Takip',
        p.takipSayisi,
        p.icerikKilitli
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TakipListesi(
                    userId: p.id,
                    tur: 'following',
                    baslik: 'Takip edilenler',
                  ),
                ),
              ),
      ),
    ],
  );

  Widget _sayac(String etiket, int deger, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          Text(
            sayiBicimle(deger),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            etiket,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  Widget _dugmeler(Profil p) {
    // ⚠️⚠️ TURU 75b (DENETIM BULGUSU): KENDI PROFILIMDE "Takip et" / "Mesaj" /
    //    "Engelle" / "Şikayet et" cikiyordu. Ekran kendi kimligimle de aciliyor
    //    (Profil sekmesi -> "Gönderilerim ve profilim") ama hicbir "bu benim"
    //    kapisi yoktu: kendini takip etmeye calisinca sunucu 400 doner, kendini
    //    engelleme/sikayet ise anlamsiz.
    if (_benimMi) return _kendiDugmelerim();

    final takipli = p.takipEdiyorum;
    final bekliyor = p.istekBekliyor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              onPressed: _takipMesgul || p.engelledim ? null : _takipCevir,
              style: takipli || bekliyor
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
              child: Text(
                p.engelledim
                    ? 'Engellendi'
                    : bekliyor
                    ? 'İstek gönderildi'
                    : takipli
                    ? 'Takiptesin'
                    : (p.beniTakipEdiyor ? 'Geri takip et' : 'Takip et'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.messageCircle, size: 17),
              label: const Text('Mesaj'),
              // ⚠️ Engelledigimiz kisiyle sohbet ACILMAZ (sunucu da reddeder).
              onPressed: p.engelledim ? null : () => _sohbetAc(p),
            ),
          ),
        ],
      ),
    );
  }

  /// Kendi profilim: duzenle + kaydedilenler + GIZLI HESAP anahtari.
  ///
  /// ⚠️⚠️ GIZLI HESAP ANAHTARI BURADA OLMAK ZORUNDA: `gizlilikAyarla()` servisi
  ///    yazilmisti ama HICBIR YERDEN CAGRILMIYORDU. Sonucu zincirlemeydi —
  ///    hicbir kullanici gizli hesap OLAMADIGI icin su kodun HEPSI ULASILAMAZDI:
  ///    takip isteklerinin 'bekliyor' dali, FollowApprove/FollowReject uclari,
  ///    "Takip istekleri" ekrani ve profil/liste ekranlarindaki kilit dallari.
  ///    (Denetim bunu ORTA seviye "olu ozellik" olarak yakaladi.)
  // ⚠️ TURU 107 — parametre KALDIRILDI: gizli hesap anahtari Ayarlara
  //    tasindi ve profil nesnesine burada ihtiyac kalmadi.
  Widget _kendiDugmelerim() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.pencil, size: 16),
                label: const Text('Profili düzenle'),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProfilDuzenleEkrani(),
                    ),
                  );
                  if (mounted) unawaited(_yukle());
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.bookmark, size: 16),
                // ⚠️⚠️ TURU 113 (denetim) — **KIRPILIYORDU.** Gereken 115.7 dp,
                //	alan 102.2 dp -> 13.5 dp kirpma; "Kaydedilenler" TEK
                //	KELIME oldugu icin sarilamaz ve `Text` varsayilani
                //	`clip` oldugu icin uc nokta bile cikmiyordu.
                //	Ayni sinif yazi olceginde daha da agirlasiyordu.
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Kaydedilenler'),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const KaydedilenlerSayfasi(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // ⚠️⚠️⚠️ TURU 107 — **GIZLI HESAP ANAHTARI AYARLARA TASINDI**
      //	(kullanici emri: *"profilde gizli hesap alani orada olmamali,
      //	ayarlarda olacak"*).
      //
      // ⚠️ Ozellik ULASILAMAZ KALMADI: yeni yeri `AyarlarEkrani` >
      //    "Gizlilik" bolumu. O anahtarin BIR girisi olmak ZORUNDA —
      //    yoksa hicbir kullanici gizli hesap olamaz ve takip isteginin
      //    "bekliyor" dali, onay/red uclari, "Takip istekleri" ekrani ve
      //    profil kilit dallari TOPTAN olu kalir (turu 75b bulgusu).
      // ⚠️ YAPMA: iki yere birden koyma (ayni kuralin iki kopyasi).
    ],
  );


  /// ⚠️ Sohbet acma AYNI yolu kullanir (POST /chats/direct) — `user_search_screen`
  ///    desenininin birebir esi. Ayri bir uc/servis YAZILMADI (drift eder).
  Future<void> _sohbetAc(Profil p) async {
    try {
      final chat = await ref
          .read(apiProvider)
          .post('/chats/direct', data: {'user_id': p.id});
      if (!mounted) return;
      ref.read(chatsProvider.notifier).load();
      context.push(
        '/chat/${chat.data['chat_id']}',
        extra: {'title': p.ad.isEmpty ? p.username : p.ad, 'peer_id': p.id},
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sohbet açılamadı')));
    }
  }

  /// Aktif sekmenin gonderi listesi.
  ///
  /// ⚠️⚠️ **BEYAZ LISTE, KARA LISTE DEGIL** (turu 108 denetim bulgusu):
  ///	eski kod fotograf sekmesini `kind(0) != 'video'` ile suzuyordu, yani
  ///	*"video degilse fotograftir"* varsayiyordu. Ses gonderisinin `kind(0)`
  ///	degeri **`audio`** — bu yuzden **ses gonderileri FOTOGRAF sekmesinde
  ///	gorunuyordu**. Artik `== 'image'`.
  List<Gonderi> get _sekmeliListe {
    final ham = _gonderiOnbellek[_sekme] ?? const <Gonderi>[];
    return switch (_sekme) {
      ProfilSekmesi.foto =>
        ham.where((g) => g.mediaIds.isNotEmpty && g.kind(0) == 'image').toList(),
      ProfilSekmesi.ses => ham.where((g) => g.sesliMi).toList(),
      _ => ham,
    };
  }

  /// Menude gosterilecek sekmeler.
  ///
  /// ⚠️ Ilan tabanli sekmeler YALNIZ kendi profilimde: `/ilanlar` ucu
  ///    `?user_id=` KABUL ETMIYOR (yalniz `benim=1`). Baskasinin profilinde
  ///    menude HIC gorunmezler — "yakinda" YAZILMAZ (turu 76b'de denendi,
  ///    turu 77'de geri alindi: `hizmet_menusu.dart` serhi).
  /// Dugun dali — **`talep_servisi.dart` TEK KAYNAGINDAN**.
  ///
  /// ⚠️ Ayni kume "Teklif iste" ekraninda da dallari ayirmak icin
  ///    kullaniliyor (`talep_ekranlari.dart`). Ikinci bir kopya yazmak
  ///    kacinilmaz olarak drift ederdi.
  /// ⚠️ Sunucuda hepsi `tur=talep`tir; dal ayrimi bir SUNUM tercihidir
  ///    (bkz. o dosyanin serhi) — bu yuzden istemcide durmasi bilincli.
  List<ProfilSekmesi> get _sekmeler => [
    for (final x in ProfilSekmesi.values)
      if (!x.ilanMi || _benimMi) x,
  ];

  /// Secili sekmenin verisini ceker (yalniz ILK secimde).
  ///
  /// ⚠️ `_sekmeYukleniyor` yeniden-girme kapisi: sekmeye hizli hizli
  ///    dokunmak ayni istegi tekrar tekrar atardi.
  Future<void> _sekmeYukle(ProfilSekmesi x) async {
    if (_sekmeYukleniyor.contains(x)) return;
    if (_gonderiOnbellek.containsKey(x) || _ilanOnbellek.containsKey(x)) return;
    setState(() {
      _sekmeYukleniyor.add(x);
      _sekmeHata.remove(x);
    });
    try {
      if (x.ilanMi) {
        var l = await ref
            .read(ilanServisiProvider)
            .liste(tur: x.ilanTuru, benim: true);
        // ⚠️⚠️ **DUGUN ILE HIZMET TALEBI AYNI TURDEDIR** (sunucu:
        //	`tur='talep'`), ayrim KATEGORIDEDIR. `/ilanlar` suzgeci TEK
        //	ESITLIK kabul ettigi icin dokuz dugun kategorisi tek istekle
        //	suzulemez; ayrim ISTEMCIDE, sunucunun AGACINDAN gelen
        //	`dugun` bayragiyla yapilir.
        // ⚠️ Kategori listesi Dart'a YAZILMAZ (turu 77): yeni bir dugun
        //    kategorisi eklendiginde eski surumler onu sessizce hizmet
        //    dalina dusururdu.
        if (x == ProfilSekmesi.dugun || x == ProfilSekmesi.talep) {
          l = l
              .where(
                (i) => x == ProfilSekmesi.dugun
                    ? dugunKategorileri.contains(i.kategori)
                    : !dugunKategorileri.contains(i.kategori),
              )
              .toList();
        }
        if (!mounted) return;
        setState(() => _ilanOnbellek[x] = l);
      } else {
        final l = await ref
            .read(sosyalServisiProvider)
            .kullaniciGonderileri(widget.userId, tur: x.sunucuTuru);
        if (!mounted) return;
        setState(() => _gonderiOnbellek[x] = l);
      }
    } catch (_) {
      if (!mounted) return;
      // ⚠️ Sekme basina AYRI hata: bir sekmenin ag hatasi digerinin dolu
      //    listesini silmemeli (turu 80b dersi).
      setState(() => _sekmeHata[x] = 'Yüklenemedi');
    } finally {
      if (mounted) setState(() => _sekmeYukleniyor.remove(x));
    }
  }

  // ⚠️ TURU 115 — `_sekmeKaydir` SILINDI: yerini GERCEK `PageView` aldi;
  //    jest artik sayfayi PARMAKLA tasiyor, aninda atlamiyor.

  /// Tek bir sekmenin sayfasi (`PageView` cocugu).
  ///
  /// ⚠️ Her sayfa KENDI dikey kaydirmasina sahiptir: dis liste basligi
  ///    kaydirir, ic liste icerigi. `PageStorageKey` ile her sekmenin
  ///    kaydirma konumu KORUNUR.
  /// ⚠️ Yukleme/hata/bos dallari SAYFANIN KENDISINDE: eskiden `_sekme`ye
  ///    bakiyorlardi ve `PageView`de komsu sayfa da cizildigi icin YANLIS
  ///    sayfada spinner gorunurdu.
  Widget _sekmeSayfasi(ProfilSekmesi x) => ListView(
    key: PageStorageKey<String>('sekme-${x.name}'),
    padding: EdgeInsets.zero,
    children: [_sekmeIcerigi(x)],
  );

  Widget _sekmeIcerigi(ProfilSekmesi x) {
    final soluk = Theme.of(context).colorScheme.onSurface.withValues(
      alpha: 0.6,
    );
    if (_sekmeYukleniyor.contains(x)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_sekmeHata[x] != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_sekmeHata[x]!, style: TextStyle(color: soluk)),
              TextButton(
                onPressed: () {
                  _sekmeHata.remove(x);
                  unawaited(_sekmeYukle(x));
                },
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }
    if (x.ilanMi) return _ilanListesi();
    final l = _gonderiOnbellek[x] ?? const <Gonderi>[];
    if (l.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text(x.bosMetin, style: TextStyle(color: soluk))),
      );
    }
    return _izgara();
  }
  Widget _sekmeSecici() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        key: _seciciAnahtar,
        child: Semantics(
          button: true,
          label: 'Görünüm: ${_sekme.etiket}',
          child: InkWell(
            onTap: _sekmeSec,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_sekme.ikon, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    _sekme.etiket,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 109 — **ASAGI DOGRU ACILAN MENU** (kullanici emri:
  ///	*"tikladigim menu ... asagi dogru video reels secenekleri olsun"*).
  ///
  /// ⚠️ Turu 108'de bu bir ALTTAN SAYFA () idi;
  ///    kullanici *"eski halindeki gibi yapmaliydin, boyle degil"* dedi.
  ///    Menu artik dugmenin ALTINA capalanir ve ASAGI acilir.
  /// ⚠️ Konum dugmenin indan TURETILIR (sabit sayi YOK); ekranin
  ///    dibine yakinken Flutter menuyu kendiliginden yukari kaydirir.
  /// ⚠️ Secili satirda **TIK** cizilir (kullanicinin istedigi "ok ikonu").
  Future<void> _sekmeSec() async {
    final kutu = context.findRenderObject() as RenderBox?;
    final dugme = _seciciAnahtar.currentContext?.findRenderObject() as RenderBox?;
    if (kutu == null || dugme == null) return;
    final sol = dugme.localToGlobal(Offset.zero, ancestor: kutu);
    final scheme = Theme.of(context).colorScheme;
    final secim = await showMenu<ProfilSekmesi>(
      context: context,
      // ⚠️ Dugmenin ALT kenarindan basla: menu asagi dogru acilsin.
      position: RelativeRect.fromLTRB(
        sol.dx,
        sol.dy + dugme.size.height,
        kutu.size.width - sol.dx - dugme.size.width,
        0,
      ),
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.10)),
      ),
      items: [
        for (final x in _sekmeler) ...[
          // ⚠️ Gonderi sekmeleriyle ilan sekmeleri arasinda AYRAC: ikisi
          //    farkli kaynaktan besleniyor (gonderi ucu vs. ilan ucu).
          if (x == ProfilSekmesi.ilan)
            const PopupMenuDivider(height: 9),
          PopupMenuItem<ProfilSekmesi>(
            value: x,
            height: 46,
            child: Row(
              children: [
                Icon(x.ikon, size: 19),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    x.etiket,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _sekme == x
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (_sekme == x)
                  Icon(LucideIcons.check, size: 17, color: scheme.primary),
              ],
            ),
          ),
        ],
      ],
    );
    if (secim == null || !mounted) return;
    _sekmeyeGec(secim);
  }

  /// Sekme degistirmenin TEK KAPISI (menuden secim + yatay kaydirma).
  ///
  /// ⚠️ Iki cagri yeri ayri ayri `setState`+`_sekmeYukle` yazsaydi biri
  ///    guncellenip oteki geride kalirdi — bu projede ALTI kez yasanan
  ///    "ayni kuralin iki kopyasi drift eder" sinifi.
  void _sekmeyeGec(ProfilSekmesi x) {
    if (x == _sekme) return;
    setState(() => _sekme = x);
    unawaited(_sekmeYukle(x));
    // ⚠️ TURU 115 — menuden secim SAYFAYI da tasir; aksi halde etiket
    //    degisir ama icerik ESKI sayfada kalirdi.
    final i = _sekmeler.indexOf(x);
    if (i >= 0 && _sayfaCtrl.hasClients) {
      _sayfaCtrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }
  /// Ilan tabanli sekmelerin listesi (Ilanlarim · Dolap · Taleplerim).
  ///
  /// ⚠️ Izgara DEGIL LISTE: ilanin kapagi cogu zaman yok (is ilani) ve
  ///    baslik + fiyat kare bir hucreye sigmaz.
  Widget _ilanListesi() {
    final l = _ilanOnbellek[_sekme] ?? const <Ilan>[];
    if (l.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            _sekme.bosMetin,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final i in l)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              i.baslik,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(i.fiyatEtiketi),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => IlanDetayEkrani(ilan: i)),
            ),
          ),
      ],
    );
  }

  Widget _izgara() {
    final liste = _sekmeliListe;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: liste.length,
      itemBuilder: (_, i) {
        final g = liste[i];
        return GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => GonderiDetay(gonderi: g))),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (g.mediaIds.isNotEmpty)
                // ⚠️⚠️⚠️ TURU 83 — **SEVK ENGELI DUZELTMESI** (denetim bulgusu).
                //
                //    Eskiden burada `MedyaGorsel(mediaId: g.mediaIds.first)`
                //    vardi ve TUR KONTROLU YAPMIYORDU. Yeni "Videolar" sekmesi
                //    TANIMI GEREGI yalniz `kind(0)=='video'` gonderileri
                //    listeledigi icin O SEKMEDEKI HER HUCRE bir VIDEO id'sini
                //    goruntu bileseni gonderiyordu:
                //      · thumb uretilmedigi icin (`kucukResim:` repodaki 17
                //        `yukle()` cagrisinin HICBIRINDE gecmiyor) ham `url`e
                //        dusuyor -> **mp4'un TAMAMI indiriliyor**,
                //      · ardindan goruntu cozucu patliyor -> **KIRIK GORSEL**.
                //    Yani sekme hem bozuk goruyor hem kullanicinin mobil
                //    verisini yakiyordu.
                //
                // ⚠️ `KapakGorseli` TAM BU IS ICIN yazilmis TEK KAYNAK:
                //    ILK FOTOGRAFI secer, yalniz-video gonderide `null` doner
                //    ve INDIRME YAPMADAN video yer tutucusu cizer.
                // ⚠️ YAPMA: buraya `MedyaGorsel(... mediaIds.first ...)` geri koyma.
                KapakGorseli(mediaIds: g.mediaIds, mediaKinds: g.mediaKinds)
              else
                Container(
                  color: const Color(0xFF1A1A24),
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.center,
                  child: Text(
                    g.metin,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              // ⚠️⚠️ TURU 76 — ROZET ARTIK **ILK MEDYANIN TURUNDEN** (gonderi
              //    seviyesindeki `videoMu`dan DEGIL). Karma galeri geldiginde
              //    `tur='foto'` olan ama ILK OGESI VIDEO olan gonderiler
              //    oynatma rozeti ALMIYORDU — kapak donuk bir kare gibi duruyordu.
              // ⚠️ `else if` ZORUNLU: iki rozet de `right:5, top:5` konumunda;
              //    ikisi birden cizilirse UST USTE BINER (okunmaz simge yigini).
              if (g.kind(0) == 'video')
                const Positioned(
                  right: 5,
                  top: 5,
                  child: Icon(LucideIcons.play, size: 15, color: Colors.white),
                )
              else if (g.mediaIds.length > 1)
                const Positioned(
                  right: 5,
                  top: 5,
                  child: Icon(LucideIcons.copy, size: 14, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// ⚠️⚠️ TURU 77 — PROFILDEKI ISLETME SERIDI.
///
/// Kullanici emri: "normal ve isletme profilleri olacak".
///
/// ⚠️ AYRI BIR WIDGET (profil_sayfasi'nin state'ine gomulmedi): isletme
///    bilgisi AYRI bir uctan (`/users/{id}/isletme`) geliyor ve profilin
///    yuklenmesini BEKLETMEMELI. Bilgi gelene kadar serit CIZILMEZ, profil
///    normal gorunur.
/// ⚠️ Isletme DEGILSE hicbir sey cizilmez (404 -> null).
class IsletmeSeridi extends ConsumerStatefulWidget {
  const IsletmeSeridi({
    super.key,
    required this.userId,
    required this.ad,
    required this.benimMi,
  });

  final String userId;
  final String ad;
  final bool benimMi;

  @override
  ConsumerState<IsletmeSeridi> createState() => _IsletmeSeridiState();
}

class _IsletmeSeridiState extends ConsumerState<IsletmeSeridi> {
  Isletme? _i;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  /// ⚠️⚠️ TURU 80b — HATA YUTULMAZ AMA EKRANI DA DUSURMEZ (denetim).
  ///
  ///	`detay()` turu 77b'de BILEREK "404'te null, digerlerinde FIRLAT"
  ///	yapilmisti (veri kaybi dersi). Ama burada `try/catch` YOKTU: mobil
  ///	agda tek bir kopma `initState`ten baslayan bu async akisi
  ///	YAKALANMAMIS ISTISNA ile bitiriyor, `_i` null kaliyor ve serit —
  ///	dolayisiyla **"Randevu al" dugmesi** — hic cizilmiyordu. Serit
  ///	`SizedBox.shrink()` dondugu icin kullaniciya HICBIR IPUCU da yoktu.
  ///
  /// ⚠️ TEK tekrar denemesi (1.2sn): serit YARDIMCI bir bilesendir, profilin
  ///    kendisi degil — sonsuz yeniden deneme mobil veriyi ve pili yakardi.
  /// ⚠️ Servis await'ten ONCE yakalanir (turu 78b: disposed State'te `ref.read`
  ///    StateError firlatir).
  Future<void> _yukle({bool tekrar = true}) async {
    final svc = ref.read(isletmeServisiProvider);
    try {
      final i = await svc.detay(widget.userId);
      if (mounted) setState(() => _i = i);
    } catch (_) {
      if (!mounted || !tekrar) return;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      await _yukle(tekrar: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _i;
    // ⚠️ Isletme degilse (ya da henuz yuklenmediyse) HIC yer kaplamaz.
    if (i == null) return const SizedBox.shrink();
    final bugun = i.calisma
        .where((c) => c.gun == DateTime.now().weekday)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(
                      isletmeKategoriAdi(i.kategori),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  // ⚠️⚠️ TURU 78 — BURADAKI IKINCI TIK KALDIRILDI.
                  //    Onayli rozeti artik profil BASLIGINDA, adin yaninda
                  //    ciziliyor (`ProfilAdSatiri`). Ayni bilgi iki yerde
                  //    cizilseydi -- ki ZATEN DRIFT ETMISTI, burada 16px,
                  //    isletme listesinde 15px -- kullanici "iki cesit onay mi
                  //    var?" diye sorardi.
                  // ⚠️ YAPMA: buraya tekrar rozet ekleme; rozet TEK yerde
                  //    (`ProfilAdSatiri`) cizilir ve rengi `kOnayliRengi`.
                  const Spacer(),
                  // ⚠️ "Şu an açık" YALNIZ calisma saati GIRILMISSE cizilir;
                  //    bos veriyle "kapalı" demek YANILTICI olurdu.
                  if (i.calisma.isNotEmpty)
                    Text(
                      i.simdiAcik ? 'Şu an açık' : 'Şu an kapalı',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i.simdiAcik
                            ? const Color(0xFF2BB673)
                            : Colors.grey,
                      ),
                    ),
                ],
              ),
              if (i.adres.isNotEmpty || i.ilce.isNotEmpty)
                _satir(
                  LucideIcons.mapPin,
                  [i.adres, i.ilce, i.il].where((s) => s.isNotEmpty).join(', '),
                ),
              if (bugun != null && !bugun.kapali)
                _satir(
                  LucideIcons.clock,
                  'Bugün ${bugun.acilis} - ${bugun.kapanis}',
                ),
              if (i.telefon.isNotEmpty) _satir(LucideIcons.phone, i.telefon),
              if (i.web.isNotEmpty) _satir(LucideIcons.globe, i.web),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UrunKatalogEkrani(
                            isletmeId: widget.userId,
                            isletmeAd: widget.ad,
                            benimMi: widget.benimMi,
                            // TURU 89 - modul SUNUCUDAN gelir.
                            modul: i.modul,
                          ),
                        ),
                      ),
                      icon: const Icon(LucideIcons.bookOpen, size: 17),
                      // TURU 89 - kategoriye gore: Odalar / Hizmetler / Menü.
                      //    Kategoriden ISTEMCIDE tahmin edilmez.
                      label: Text(i.modul.ad),
                    ),
                  ),
                  // ⚠️⚠️ TURU 80 — REZERVASYON / RANDEVU DUGMESI.
                  //
                  //    Kullanici emri: "restoran/yemek firmalarindan
                  //    rezervasyon, doktor vs.den randevu alinabilmeli".
                  //
                  // ⚠️ YALNIZ `randevuAcik` TRUE iken cizilir ve bu bilgi
                  //    SUNUCUDAN gelir. Kategoriden tahmin edilseydi, ayari
                  //    ACMAMIS bir isletmede de dugme cizilir ve kullanici 404
                  //    alirdi — projede ALTI kez yasanan "ozellik var gorunup
                  //    calismiyor" sinifi.
                  // ⚠️ KENDI profilinde CIZILMEZ: kendi isletmenden randevu
                  //    alinamaz (sunucu da 400 doner). Sahip icin ayarlar
                  //    "İşletme bilgilerim" ekranindan ulasilir.
                  if (!widget.benimMi && i.randevuAcik) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RandevuAlEkrani(
                              isletmeId: widget.userId,
                              isletmeAd: widget.ad,
                            ),
                          ),
                        ),
                        icon: const Icon(LucideIcons.calendarPlus, size: 17),
                        label: FittedBox(
                          // ⚠️⚠️ TURU 113 (denetim) — "Rezervasyon" gereken
                          //	110.2 dp, alan 90.2 dp: NORMAL olcekte bile
                          //	20 dp tasiyordu (kardesi "Hizmetler" siyor,
                          //	yani YALNIZ sagdaki dugme bozuktu).
                          fit: BoxFit.scaleDown,
                          child: Text(
                            i.rezervasyonMu ? 'Rezervasyon' : 'Randevu al',
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (widget.benimMi) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const IsletmeDuzenleEkrani(),
                          ),
                        );
                        if (mounted) _yukle();
                      },
                      child: const Icon(LucideIcons.pencil, size: 17),
                    ),
                  ],
                ],
              ),

              // ⚠️⚠️⚠️ TURU 93b — DIYETISYEN BAGLANTISI: **SEVK ENGELI**
              //	(denetimde yakalandi, build ONCESI).
              //
              //	`DiyetServisi.bagIste()` yazilmisti ama **HICBIR YERDEN
              //	CAGRILMIYORDU** (`grep -rn "bagIste" lib/` -> yalniz
              //	TANIMIN KENDISI). Yani hicbir kullanici bir `diyet_bag`
              //	satiri OLUSTURAMIYORDU ve zincirin TAMAMI oluydu:
              //	  · `Danışanlarım` HER diyetisyende DAIMA bos
              //	  · `Diyetim` DAIMA "Diyetisyenin yok — Yakınımda'dan bir
              //	    diyetisyen bul ve baglanti istegi gonder" diyordu ama
              //	    **oyle bir dugme UYGULAMADA YOKTU**
              //	  · `DiyetListeYazEkrani` / `DanisanDetayEkrani`
              //	    ULASILAMAZ
              //	  · `diyet_istek` / `diyet_liste` bildirimleri HIC dogmaz
              //	Kullanicinin manset emri (*"hangi diyetisyenle
              //	calisiyorsan DIYET LISTESI olacak"*) sahada TAMAMEN oluydu;
              //	yalniz kendi kendine ogun/olcum girisi calisiyordu.
              //
              // ⚠️ DOGRU YER BURASI: bir diyetisyene ulasmanin gercek yolu
              //    onun PROFILIDIR (rehber/harita -> kart -> profil). Menuye
              //    konsaydi kullanici once "hangi diyetisyen" sorusunu
              //    cozmek zorunda kalirdi.
              // ⚠️ YALNIZ `kategori == 'diyetisyen'` VE baskasinin profili.
              // ⚠️ YAPMA: bu girisi kaldirma — kaldirilirsa diyet ozelliginin
              //    TAMAMI tekrar olu kalir.
              if (!widget.benimMi && i.kategori == 'diyetisyen') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _bagIsteDiyetisyen,
                    icon: const Icon(LucideIcons.heartPulse, size: 17),
                    label: const Text('Diyetisyenim ol'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Diyetisyene baglanti istegi gonderir.
  ///
  /// ⚠️ ONAY KARSI TARAFTAN GELIR: `diyet_bag` `bekliyor` dogar ve
  ///    `baslatan_id <> onaylayan` kapisi sunucuda uygulanir (kimse kendi
  ///    istegini onaylayamaz). Yani bu dugme "bagi kurar" DEMEK DEGIL,
  ///    "istek gonderir" demektir — mesaj da oyle yazildi.
  /// ⚠️ **RIZA**: diyet verisi SAGLIK VERISIDIR; bag olmadan hicbir taraf
  ///    otekinin kaydini goremez (`diyetErisim` fail-closed).
  /// ⚠️ CIFT DOKUNMA KORUMASI (`_bagIstendi`): iki hizli dokunus IKI istek
  ///    atardi. Sunucu `UNIQUE(danisan_id,diyetisyen_id)` ile korunuyor ama
  ///    kullaniciya IKI hata mesaji gosterilirdi.
  bool _bagIstendi = false;

  Future<void> _bagIsteDiyetisyen() async {
    if (_bagIstendi) return;
    setState(() => _bagIstendi = true);
    // ⚠️ Servis ve mesajci TUM await'lerden ONCE yakalanir: kullanici
    //    istek ucarken geri basarsa `ref.read` `StateError` firlatir ve
    //    `catch` onu yutar -> istek gider ama kullanici HICBIR SEY gormez
    //    (turu 77b/78b dersi).
    final svc = ref.read(diyetServisiProvider);
    final mesajci = ScaffoldMessenger.of(context);
    try {
      await svc.bagIste(diyetisyenID: widget.userId);
      mesajci.showSnackBar(
        const SnackBar(
          content: Text(
            'Bağlantı isteği gönderildi. Diyetisyen onaylayınca '
            '"Diyetim" ekranında görünecek.',
          ),
        ),
      );
    } catch (e) {
      // ⚠️ SUNUCUNUN mesaji gosterilir ("zaten bağlısınız" gibi durumlari
      //    jenerik bir metne cevirmek kullaniciyi tekrar tekrar denemeye
      //    iter — turu 93b denetiminin `apiErrorMessage` bulgusu).
      mesajci.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _bagIstendi = false);
    }
  }

  Widget _satir(IconData ikon, String metin) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 15, color: Colors.grey),
        const SizedBox(width: 7),
        Expanded(child: Text(metin, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

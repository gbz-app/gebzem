import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../../core/theme.dart';
import 'isletme_bilgi.dart';
import '../../core/api.dart';
import '../chats/chats_provider.dart';
import '../chats/moderasyon_sheet.dart';
import '../home/profil_duzenle.dart';
import '../isletme/isletme_duzenle.dart';
import '../isletme/isletme_servisi.dart';
import '../randevu/randevu_al.dart';
import '../isletme/urun_ekranlari.dart';
import '../medya/medya_gorsel.dart';
import 'gonderi_karti.dart' show sayiBicimle;
import 'gonderi_detay.dart';
import 'profil_basligi.dart';
import 'reels_sayfasi.dart';
import '../home/home_screen.dart' show HesabimEkrani, myProfileProvider;
import '../ilan/ilan_ekranlari.dart' show IlanDetayEkrani;
import '../ilan/ilan_servisi.dart';
import '../talep/talep_servisi.dart' show dugunKategorileri;
import 'demo_veri.dart' show kDemoAkis, demoGonderiler;
import 'istatistik_ekrani.dart';
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
  /// TURU 176 — **GENEL** (kullanici emri: *"yemek/hacimahalle bilgi
  /// karti olmasin, onu gonderinin soluna GENEL olarak koy: adres,
  /// iletisim, calisma saatleri, harita, ozellikler"*).
  ///
  /// ⚠️ Sekmelerin **ILKI**: kullanicinin tarif ettigi yer "gonderinin
  ///	SOLU" ve serit soldan basliyor.
  genel,
  tumu,
  foto,
  video,
  reels,

  /// ⚠️⚠️ TURU 180g — **BEGENILENLER** (kullanici emri).
  ///
  /// ⚠️ YALNIZ KENDI PROFILIMDE: baskasinin neyi begendigi GIZLIDIR
  ///	(Instagram da boyle) ve sunucu ucu `/users/me/begeniler`,
  ///	yani baskasi icin cagrilacak bir yol ZATEN YOK.
  begeni,

  /// ⚠️⚠️⚠️ TURU 180u — **REPOST** (kullanici emri: *"revet yani tekrar
  ///	paylasma profildeki alanla koy ... repost ekle yani tekrar
  ///	paylasilan"*).
  ///
  /// ⚠️⚠️ **SUNUCUDA REPOST KAVRAMI YOK** (olculdu: `backend/` genelinde
  ///	`repost|reshare|share_count` icin SIFIR eslesme; `posts.tur`
  ///	CHECK'i yalniz foto/video/reels/yazi; repost ucu ve tablosu YOK).
  ///	`Gonderi.repostSayisi` alani VAR ama `Gonderi.json` onu HIC
  ///	OKUMUYOR — yani gercek akista DAIMA 0.
  /// ⚠️ Bu yuzden sekme **`begeni`nin isletme dalindaki desenle** cizilir:
  ///	icerik yoksa BOS LISTE degil **"Repost yakında"** denir. Bos liste
  ///	"bu kisi hic repost yapmamis" YALANI olurdu (turu 176/179 dersi).
  repost,
  // ⚠️⚠️ TURU 176 — **`ses` KALDIRILDI** (kullanici emri: *"sesi kaldir,
  //	ses paylasma vs kalksin; SADECE MESAJLARDA ses paylasimi
  //	olacak"*). Enum degeri SILINDI, cunku `switch`ler
  //	tukenmis (exhaustive) yazilmis ve olu bir deger birakmak
  //	her birinde ULASILAMAZ bir dal birakirdi.
  ilan,
  /// ⚠️⚠️ TURU 180 — **IS ILANI** (kullanici: *"profile is ilanini da
  ///	ekle, is ilani detaylarini da ekle"*).
  ///
  /// ⚠️ Sunucuda AYRI bir tur: `/ilanlar?tur=is`. `ilan` sekmesi bu turu
  ///	ZATEN disariyor mu? HAYIR — `ilan` bos `tur` ile TUM ilanlari
  ///	getiriyordu. Iki sekme ayni kaydi listelememesi icin `ilan`
  ///	sekmesi artik is ilanlarini ELER (bkz. `_ilanYukle`).
  isIlani,
  dolap,
  hizmet,
  talep,
  dugun,
}

extension ProfilSekmesiBilgi on ProfilSekmesi {
  String get etiket => switch (this) {
    ProfilSekmesi.genel => 'Genel',
    ProfilSekmesi.tumu => 'Gönderiler',
    ProfilSekmesi.foto => 'Fotoğraf',
    ProfilSekmesi.video => 'Video',
    ProfilSekmesi.reels => 'Reels',
    ProfilSekmesi.begeni => 'Beğeniler',
    ProfilSekmesi.repost => 'Repost',
    ProfilSekmesi.ilan => 'İlanlarım',
    ProfilSekmesi.isIlani => 'İş İlanları',
    ProfilSekmesi.dolap => 'Dolap',
    ProfilSekmesi.hizmet => 'Hizmetlerim',
    ProfilSekmesi.talep => 'Taleplerim',
    ProfilSekmesi.dugun => 'Düğünüm',
  };

  IconData get ikon => switch (this) {
    ProfilSekmesi.genel => LucideIcons.info,
    ProfilSekmesi.tumu => LucideIcons.layoutGrid,
    ProfilSekmesi.foto => LucideIcons.image,
    ProfilSekmesi.video => LucideIcons.video,
    ProfilSekmesi.reels => LucideIcons.clapperboard,
    ProfilSekmesi.begeni => LucideIcons.heart,
    ProfilSekmesi.repost => LucideIcons.repeat2,
    ProfilSekmesi.ilan => LucideIcons.tag,
    ProfilSekmesi.isIlani => LucideIcons.briefcase,
    ProfilSekmesi.dolap => LucideIcons.shirt,
    ProfilSekmesi.hizmet => LucideIcons.wrench,
    ProfilSekmesi.talep => LucideIcons.clipboardList,
    ProfilSekmesi.dugun => LucideIcons.heartHandshake,
  };

  String get bosMetin => switch (this) {
    ProfilSekmesi.genel => 'Bilgi yok',
    ProfilSekmesi.tumu => 'Henüz gönderi yok',
    ProfilSekmesi.foto => 'Henüz fotoğraf yok',
    ProfilSekmesi.video => 'Henüz video yok',
    ProfilSekmesi.reels => 'Henüz reels yok',
    ProfilSekmesi.begeni => 'Henüz beğendiğin gönderi yok',
    ProfilSekmesi.repost => 'Henüz repost yok',
    ProfilSekmesi.ilan => 'Henüz ilan vermedin',
    ProfilSekmesi.isIlani => 'Henüz iş ilanı yok',
    ProfilSekmesi.dolap => 'Dolabında ürün yok',
    ProfilSekmesi.hizmet => 'Henüz hizmet ilanın yok',
    ProfilSekmesi.talep => 'Henüz talebin yok',
    ProfilSekmesi.dugun => 'Henüz düğün talebin yok',
  };

  /// Sunucu `?tur=` degeri (gonderi sekmeleri icin).
  ///
  /// ⚠️ Reels ISTEMCIDE ayirt EDILEMEZ (medya turu yine `video`) — sunucu
  ///    suzgeci ZORUNLU.
  /// ⚠️ TURU 176 — Ses sekmesi kaldirildi; `posts.tur` CHECK'ine ve
  ///	sunucuya DOKUNULMADI (mevcut ses gonderileri Fotograf
  ///	sekmesinde gorunmeye devam eder, veri KAYBOLMAZ).
  String? get sunucuTuru => switch (this) {
    ProfilSekmesi.foto => 'foto',
    ProfilSekmesi.video => 'video',
    ProfilSekmesi.reels => 'reels',
    _ => null,
  };

  /// ⚠️ Ilan tabanli sekmeler YALNIZ kendi profilimde: `/ilanlar` ucunda
  ///    `?user_id=` YOKTUR (yalniz `benim=1`), yani baskasinin ilanlarini
  ///    listeleyecek bir yol YOK. Menude HIC gosterilmez.
  bool get ilanMi =>
      this == ProfilSekmesi.ilan ||
      this == ProfilSekmesi.isIlani ||
      this == ProfilSekmesi.dolap ||
      this == ProfilSekmesi.hizmet ||
      this == ProfilSekmesi.talep ||
      this == ProfilSekmesi.dugun;

  /// Ilan turu (`/ilanlar?tur=`).
  String get ilanTuru => switch (this) {
    ProfilSekmesi.isIlani => 'is',
    ProfilSekmesi.dolap => 'ikinci_el',
    ProfilSekmesi.hizmet => 'hizmet',
    // ⚠️ Dugun AYRI BIR TUR DEGIL: sunucuda dugun talepleri de
    //    `tur='talep'`tir, yalniz KATEGORILERI farklidir. Ayrim asagida
    //    (`_dugunMu`) sunucunun agacindan gelen bayrakla yapilir.
    ProfilSekmesi.talep || ProfilSekmesi.dugun => 'talep',
    _ => '',
  };
}

// ⚠️ TURU 178 — profil zemini SIYAH; tema `core/theme.dart`taki TEK
//    KAYNAKTAN gelir (`kKoyuTema` / `koyuSayfa`).

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

  /// Kisayoldan (Ayarlar > İlanlarım/Hizmetlerim/Düğünüm/Taleplerim) gelinen
  /// ve normal serit filtresinden GECMEYEN sekme — `initState`te bir kez
  /// yakalanir, ekran yasadigi surece seritte cizilir.
  ProfilSekmesi? _kisayolSekme;

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

  /// TURU 176 — **ISLETME DETAYI ARTIK SAYFANIN KENDI ALANI.**
  ///
  /// ⚠️⚠️ Onceden yalnizca `IsletmeSeridi` (bilgi karti) icindeydi. Artik
  ///	AYNI veriyi IKI yer okuyor: **Genel sekmesi** ve **yuzen
  ///	Menü/Rezervasyon geçisi**. Iki ayri yerde ayri ayri
  ///	cekilseydi ayni profil icin IKI istek gider ve biri
  ///	digerinden once dondugunde ekran tutarsiz cizilirdi
  ///	(bu projede ALTI kez yasanan "ayni kuralin iki kopyasi"
  ///	sinifi).
  Isletme? _isletme;

  /// Menunun capalanacagi dugme.
  bool _yukleniyor = true;
  bool _takipMesgul = false;

  /// ⚠️ Bu profil BENIM mi. myProfileProvider ASENKRON yuklenir; henuz gelmediyse
  ///    false olur ve o kisa anda yabanci dugmeleri cizilir — zararsiz, cunku
  ///    build provider degisiminde yeniden kosar.
  bool _benimMi = false;
  String? _hata;

  // ⚠️⚠️⚠️ TURU 180j — **`_sayfaCtrl` (PageController) SILINDI.**
  //	Turu 115'te sekmeler arasi "gercek sayfali kaydirma" icin
  //	konulmustu ve dogru calisiyordu; ama sabit yukseklikli bir
  //	`PageView`, sayfanin ICINE IKINCI bir dikey kaydirma alani
  //	koyuyordu (bkz. `_icerikAlani`). Yatay gecis KAYBOLMADI —
  //	`onHorizontalDragEnd` jestiyle (turu 114 deseni) suruyor.

  /// ⚠️ Sekme seridini secili sekmeye kaydirmak icin.
  final _seritCtrl = ScrollController();

  /// ⚠️⚠️⚠️ TURU 180e — **BOS SEKME EKRANA SIGMALI** (kullanici: *"gonderi
  ///	yok vs orada asagi cekme OLMAYACAK, tam orada YUKSEKLIKTEN
  ///	ORTALI olsun"*).
  ///
  ///	Sekme sayfasi SABIT `ekran * 0.62` yuksekligindedir. Bos
  ///	durum o kutunun ORTASINA konunca, kutunun buyuk kismi ekranin
  ///	ALTINDA kaldigi icin blok **HIC GORUNMUYORDU** ve kaydirma da
  ///	kapali oldugu icin ulasilamiyordu (emulatorde olculdu: serit
  ///	altinda yalnizca ~169 dp kaliyor, kutu ise 496 dp).
  ///
  ///	Cozum: serit seridinin EKRANDAKI ALT KENARI olculur ve bos
  ///	sekmede sayfa yuksekligi "geri kalan gorunur alan" yapilir.
  /// ⚠️ Olcum YALNIZ bos sekmede yapilir; orada kaydirma kapali oldugu
  ///	icin ofset SABITTIR (dolu sekmede liste kayar ve deger bayatlar).
  /// ⚠️ Sayfa yuksekligi seridin KONUMUNU degistirmez (serit USTTE) ->
  ///	olcum/yerlesim dongusu YAPISAL OLARAK imkansiz.
  final GlobalKey _seritAnahtar = GlobalKey();
  double? _seritAlt;

  /// ⚠️⚠️ TURU 180g — Gorunur alanin ALT siniri EKRANIN dibi DEGIL,
  ///	**LISTENIN KENDI alt kenari**. Kendi profilimde sayfa ALT
  ///	MENULU bir `Scaffold`un govdesinde yasiyor; ekran
  ///	yuksekliginden hesaplayinca bos durum blogu alt menunun
  ///	ARKASINDA kaliyordu (emulatorde goruldu).
  final GlobalKey _listeAnahtar = GlobalKey();
  final _seciliSekmeAnahtar = GlobalKey();

  // ⚠️⚠️ **STATE METOTLARI `Theme`I GORMEZ** (turu 135c/138 sinifi):
  //	`build`in DONDURDUGU agaca konan `Theme`, State'in KENDI
  //	`context`inin ALTINDA kalir; `Theme.of(context)` yalniz ATA
  //	elemanlari gezdigi icin UYGULAMANIN temasini cozer. Bu
  //	yuzden metotlar rengi buradan okur.
  ColorScheme get _ks => kKoyuTema.colorScheme;

  /// Acik sekmenin icerigi BOS mu (yalniz `_seritiOlc` kapisinda kullanilir).
  /// ⚠️ Yuklenirken `false`: cark donerken olcum istemek gereksiz.
  /// ⚠️⚠️ TURU 180e — **OLCUT `_sekmeIcerigi` ILE BIREBIR AYNI OLMALI.**
  ///	Onceden `g != null && g.isEmpty` yaziyordu, yani ONBELLEK HENUZ
  ///	YOKKEN (`null`) "bos degil" diyordu. Oysa `_sekmeIcerigi` ayni
  ///	durumda `?? const []` ile BOS DURUMU CIZIYOR. Iki olcut
  ///	ayrisinca ekranda "gonderi yok" gorunurken serit ALTI HIC
  ///	olculmuyor ve blok ekranin altinda kalip gorunmuyordu.
  bool get _bosSekme => _sekmeBos(_sekme);

  /// ⚠️⚠️⚠️ TURU 180g — **SAYFA YUKSEKLIGI SEKMEDEN BAGIMSIZ.**
  ///	(kullanici: *"alttaki 'henuz gonderi yok' alani GECISLERDE
  ///	BUYUYOR, PATLIYOR"*).
  ///
  ///	Turu 180e'de yukseklik BOS sekmede kisaltiliyordu. Ama
  ///	`PageView` kaydirirken IKI sayfa AYNI kutuyu paylasir:
  ///	bos sekmeden dolu sekmeye gecerken izgara 60 dp'lik kutuya
  ///	sikisiyor ve **RenderFlex tasmasi** veriyordu.
  /// ⚠️ Bos durumun ortalanmasi artik `_gorunurSerit` ile, SAYFA BOYUNA
  ///	DOKUNMADAN yapiliyor.
  /// ⚠️ YAPMA: yuksekligi tekrar `_bosSekme`ye baglama.
  ///
  /// ⚠️⚠️⚠️ TURU 180j — **`_sayfaBoyu` SILINDI, `PageView` KALKTI.**
  ///	Sabit yukseklikli bir `PageView` demek, sayfanin ICINDE IKINCI
  ///	bir dikey kaydirma alani demekti (bkz. `_icerikAlani` serhi).
  ///	Olcum istegi artik `_olcumIste()` ile veriliyor.

  /// Bos durum blogunun ortalanacagi GORUNUR yukseklik.
  ///
  /// ⚠️ Olculmediyse makul bir taban doner; tek yeniden cizimle oturur.
  /// ⚠️⚠️ TURU 180j — **YUZEN HAP DUSULMESI KALKTI**: Menü artik
  ///	`_dugmeler` satirinda ve listenin USTUNDE cizilen hicbir sey
  ///	kalmadi. Eski `hap` terimi burada CIFT SAYIM olurdu.
  double _gorunurSerit(BuildContext c) {
    final ekran = MediaQuery.sizeOf(c).height;
    final alt = _seritAlt;
    if (alt == null) return ekran * 0.18;
    // ⚠️ Liste olculemezse ekran dibine duseriz (yalniz ILK kare).
    final lb = _listeAnahtar.currentContext?.findRenderObject();
    final altSinir = (lb is RenderBox && lb.hasSize)
        ? lb.localToGlobal(Offset.zero).dy + lb.size.height
        : ekran - MediaQuery.paddingOf(c).bottom;
    final kalan = altSinir - alt;
    // ⚠️⚠️ TABAN 120 DEGIL **56**: emulatorde olculdu - serit altinda
    //	yalnizca 60-80 dp kaliyor ve 120'lik taban kutuyu ekranin ALTINA
    //	tasirip metni gorunmez yapiyordu. Blok zaten `FittedBox` icinde,
    //	yani kucuk kutuda KIRPILMAZ, kuculur.
    return kalan.clamp(56.0, ekran * 0.62);
  }

  /// Serit olcumunu bir SONRAKI kareye ister (bos durumun ortalanmasi icin).
  ///
  /// ⚠️ TURU 180j — eskiden bu cagri `_sayfaBoyu` icinde gizliydi; o metot
  ///	`PageView` ile birlikte kalkinca olcum de KAYBOLUYORDU (bos durum
  ///	ekranin tepesine yapisirdi). Artik `build`den ACIKCA isteniyor.
  void _olcumIste() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _seritiOlc());
  }

  void _seritiOlc() {
    if (!mounted || !_bosSekme) return;
    final r = _seritAnahtar.currentContext?.findRenderObject();
    if (r is! RenderBox || !r.hasSize) return;
    final alt = r.localToGlobal(Offset.zero).dy + r.size.height;
    // ⚠️ 0,5 dp esigi ZORUNLU: esiksiz karsilastirma yuvarlama gurultusunde
    //    setState -> yeniden olcum dongusu uretirdi.
    if (_seritAlt != null && (_seritAlt! - alt).abs() < 0.5) return;
    setState(() => _seritAlt = alt);
  }

  /// Sayfanin uc dali da (yukleniyor · hata · icerik) bundan gecer.
  Widget _koyuSar(Widget c) => koyuSayfa(c);

  @override
  void initState() {
    super.initState();
    // ⚠️ TURU 115 — istenen sekme BASTAN secilir; verisi `_yukle`den sonra
    //    `_sekmeYukle` ile gelir (asagidaki cagri).
    final b = widget.baslangicSekmesi;
    if (b != null) _sekme = b;
    // ⚠️⚠️ TURU 180u — kisayoldan gelinen sekme serit BES sekmeye indigi
    //	icin artik filtreden GECMEYEBILIR. Burada BIR KEZ yakalanir ve
    //	`_sekmeler` sonuna eklenir; boylece "İlanlarım" kisayolu hem
    //	calisir hem de kullanici nerede oldugunu GORUR.
    // ⚠️ `_sekme` uzerinden hesaplansaydi baska sekmeye dokunuldugunda
    //	serit ORTADAN bir oge kaybederdi.
    if (b != null && !_seritte(b)) _kisayolSekme = b;
    // ⚠️ `_sekmeler` `_benimMi`ye bagli ve o daha yuklenmedi; baslangic
    //    sayfasi TAM LISTEDEN hesaplanir (`ProfilSekmesi.values`).
    // ⚠️⚠️⚠️ TURU 180e — **INDEKS `_sekmeler`DEN, `values`TEN DEGIL.**
    //
    //	Onceden `ProfilSekmesi.values.indexOf(_sekme)` yaziyordu ama
    //	`_sekmeler` `genel` ve `video`yu ELIYOR: `tumu` degerler
    //	listesinde 1. sirada, cizilen seritte ise 0. sirada. Sonuc
    //	SAHADA goruldu — serit "Gönderiler"i secili gosterirken sayfa
    //	**FOTOGRAF** sekmesini ("Henüz fotoğraf yok") ciziyordu.
    // ⚠️ `clamp(0, 9)` de KORUMA DEGILDI: sekme sayisi 9'un altina
    //	dustugunde var olmayan bir sayfa istenirdi.
    // ⚠️⚠️ TURU 180j — **`PageController` KALKTI**: sekme icerigi artik
    //	dis listenin dogrudan cocugu (bkz. `_icerikAlani`), yani
    //	senkronlanacak ikinci bir kaydirma konumu YOK. Turu 180e/180g'de
    //	yasanan "serit ile sayfa ayrisiyor" sinifi da YAPISAL OLARAK
    //	bitti: cizilen tek sey `_sekme`.
    _yukle();
  }

  @override
  void dispose() {
    _seritCtrl.dispose();
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
      // ⚠️ Isletme detayi SESSIZ ve BAGIMSIZ cekilir: kisisel hesapta
      //    404 doner ve `_isletme` null kalir — Genel sekmesi ve yuzen
      //    geçis o zaman HIC cizilmez.
      unawaited(_isletmeYukle());
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
        if (onayli &&
            (_gonderiOnbellek[ProfilSekmesi.tumu] ?? const []).isEmpty) {
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

  // ignore: unused_element
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
    // ⚠️⚠️⚠️ TURU 180d — **YUKLEME EKRANINDA `AppBar` YOK** (kullanici:
    //	*"bir isletmeye girerken ESKI HEADER gorunup gidiyor, yumusak
    //	gecis olsun"*).
    //
    //	Sebep: yuklenirken cizilen `AppBar` **Material'in VARSAYILAN
    //	header'i** — geri oku platforma gore, zemin tema rengi. Veri
    //	gelince yerini seffaf/blur header'a birakiyordu ve arada bir
    //	kare "baska bir baslik" yanip sonuyordu.
    // ⚠️ Cikis yolu KAYBOLMAZ: ayni blur geri oku yuklenirken de cizilir
    //	(yavas agda kullanici kilitli kalmasin).
    // ⚠️ Zemin `kProfilZemin`: acilis karesi ile yuklu profil AYNI renkte,
    //	boylece gecis "parlama" yapmaz.
    if (_yukleniyor && _p == null) {
      return _koyuSar(Scaffold(
        body: Stack(
          children: [
            const Center(child: CircularProgressIndicator()),
            if (!widget.sekmeModu)
              SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: _BlurDaire(
                        child: Icon(LucideIcons.arrowLeft, size: 22),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ));
    }
    final p = _p;
    if (p == null) {
      return _koyuSar(Scaffold(
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
      ));
    }

    return _koyuSar(Scaffold(
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
        // ⚠️⚠️ TURU 178 — **BASLIK KALDIRILDI** (kullanici: *"@gebze...
        //	bu etiketi kaldir, gerek yok"*). Ad ZATEN kapagin
        //	hemen altinda buyuk puntoyla yaziyor; ustte tekrari
        //	ayni bilgiyi IKI KEZ gostermekti.
        // ⚠️⚠️ **GERI OKU YEMEK EKRANIYLA AYNI**: `automaticallyImplyLeading`
        //	Material'in kendi `BackButton`unu cizer ve o PLATFORMA
        //	GORE degisir (Android ok / iOS chevron). Yemek ekraninda
        //	ise 44 dp kutuda `LucideIcons.arrowLeft` var - kullanici
        //	farki gordu (*"geri donme ikonu bunda yemektekigibi
        //	degil"*). Artik ACIKCA ayni ikon veriliyor.
        automaticallyImplyLeading: false,
        // ⚠️⚠️⚠️ TURU 180ae — **SEKME MODUNDA SOL UST = DUZENLEME IKONU**
        //	(kullanici emri: *"profil duzenle ve kaydedilen butonlari
        //	kaldir, onun yerine sol uste icon ekle, duzenleme ikonu
        //	yeterli"*).
        // ⚠️ Sekme modunda geri oku ZATEN yoktu (altinda yigin yok) — o
        //	bos yuva kullanildi, hicbir sey ORTULMEDI.
        // ⚠️⚠️ YALNIZ KENDI profilimde: baskasinin profilinde "duzenle"
        //	ikonu cizmek OLU bir dugme olurdu.
        leading: widget.sekmeModu
            ? (_benimMi
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfilDuzenleEkrani(),
                          ),
                        );
                        if (mounted) unawaited(_yukle());
                      },
                      child: const SizedBox(
                        width: 52,
                        height: 52,
                        child: Center(
                          child: _BlurDaire(
                            child: Icon(LucideIcons.pencil, size: 20),
                          ),
                        ),
                      ),
                    )
                  : null)
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Center(
                    child: _BlurDaire(
                      child: Icon(LucideIcons.arrowLeft, size: 22),
                    ),
                  ),
                ),
              ),
        actions: [
          // ⚠️⚠️⚠️ TURU 180ae — **HAMBURGER KALDIRILDI, YERINE ISTATISTIK**
          //	(kullanici emri: *"en sagdaki carkin sagindaki hamburger
          //	iconu kaldir gereksiz, **disin SOLUNA** istatistik alani ekle
          //	ve istatistik sayfasini olustur"*).
          //
          // ⚠️⚠️ **SIRA: `actions` SOLDAN SAGA cizilir.** Ilk yazimda bu
          //	blok listenin SONUNA konmustu ve istatistik ekranda disin
          //	**SAGINDA** cikti (emulatorde goruldu) — yani emrin TERSI.
          //	Dislinin soluna almanin yolu bloku listenin BASINA tasimaktir.
          // ⚠️ YAPMA: bu bloku tekrar `actions`in sonuna tasima.
          //
          // ⚠️⚠️ **HAMBURGERIN ICI OLU KALMADI**: `_menu` sheet'i
          //	paylas/kopyala/engelle/sikayet tasiyordu ve o eylemlerin
          //	BASKA girisi VAR — kendi profilimde "Hesabım" (disli),
          //	baskasinin profilinde `_dugmeler` satirindaki eylemler.
          //	`_menu` govdesi SILINMEDI (asagida `unused_element` serhi).
          // ⚠️ Istatistik YALNIZ KENDI profilimde: baskasinin kac gonderi
          //	begendigi GIZLIDIR ve uc zaten `/users/me/...` (turu 180g
          //	"Beğeniler" karariyla ayni).
          if (_benimMi)
            IconButton(
              tooltip: 'İstatistik',
              icon: const _BlurDaire(
                child: Icon(LucideIcons.chartNoAxesColumn, size: 22),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IstatistikEkrani(profil: _p),
                ),
              ),
            ),
          // ⚠️⚠️ HESABIM GIRISI — eski profil sekmesindeki 15 satirin (isletme
          //    hesabi · randevular · basvurular · bildirim · engellenenler ·
          //    ayarlar · cikis) BASKA girisi YOK. ⚠️ YAPMA: bunu kaldirma.
          if (widget.sekmeModu && _benimMi)
            IconButton(
              tooltip: 'Hesabım',
              icon: const Icon(LucideIcons.settings),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HesabimEkrani())),
            ),
          // ⚠️⚠️ TURU 176 — **"..." YERINE IKI CIZGILI HAMBURGER**
          //	(kullanici emri: *"sagda ... nokta yerine hamburger
          //	ikonu, 2 tane alt ust; ustteki daha uzun soldan saga,
          //	alttaki kisa ama SAGDA olsun"*).
          //
          // ⚠️ Hazir ikon KULLANILAMAZ: Lucide'in `menu` UC esit cizgi,
          //	`alignRight` ise UC cizgidir (kaynaktan bakildi).
          //	Istenen bicim IKI cizgi ve ASIMETRIK - elle cizildi.
          // ⚠️ Dokunma alani 44 dp korunur (Material tabani); cizgiler
          //    onun ICINDE, saga yasli.
          // ⚠️⚠️ TURU 179 — **ISLETME HAKKINDA (soru isareti)** (kullanici:
          //	*"sag ustte hamburger menunun SOLUNA soru isareti,
          //	isletme hakkinda bilgi ... tikladiginda %95 popup"*).
          // ⚠️ YALNIZ isletme profilinde ve YALNIZ veri GELDIYSE cizilir:
          //	kisisel hesapta ya da `_isletme == null` iken dugme
          //	BOS bir panel acardi ("olu dugme" sinifi).
          if (_isletme != null)
            IconButton(
              tooltip: 'İşletme hakkında',
              icon: const _BlurDaire(
                child: Icon(LucideIcons.circleHelp, size: 22),
              ),
              onPressed: () => isletmeBilgiAc(
                context,
                ad: _p?.ad ?? '',
                isletme: _isletme!,
              ),
            ),
        ],
      ),
      // ⚠️⚠️⚠️ TURU 180j — **ALTTAKI YUZEN HAP TAMAMEN KALKTI.**
      //	Menü artik `_dugmeler` satirinda (Mesaj'in saginda),
      //	rezervasyon ise profilden CIKARILDI (kullanici emri).
      //	Yigin TEK COCUKLU kaldi; `Stack` sarmali BILEREK duruyor —
      //	kaldirmak 230 satirlik bir yeniden girintileme demek ve bu
      //	dosyada biciimlendirme gurultusu incelemeyi imkansiz kilar
      //	(turu 157 dersi: bu repoda `dart format` KOSTURULMAZ).
      //
      // 📌 TARIHSEL (turu 176-178): hap once `floatingActionButton` idi;
      //	`Scaffold` FAB'i HER ZAMAN bir olcek gecisiyle gosterdigi ve
      //	isletme detayi AG ISTEGIYLE sonradan geldigi icin cubuk her
      //	profil acilisinda "buyuyerek" giriyordu. `FloatingAction
      //	ButtonAnimator.noAnimation` YETMEZDI (o yalniz KONUM
      //	animatoru) — cozum FAB'i HIC kullanmamak olmustu.
      // ⚠️ YAPMA: alta yeniden yuzen bir cubuk koyacaksan FAB DEGIL,
      //	bu yigina `Positioned` olarak ekle ve `_gorunurSerit`teki
      //	"kalan alan" hesabindan boyunu DUS (yoksa bos durum blogu
      //	cubugun ARKASINDA kalir — turu 180e'de emulatorde goruldu).
      body: Stack(
        children: [
          YenileSarmali(
        onRefresh: _yukle,
        child: ListView(
          // ⚠️ Bos durum blogu bu listenin ALT KENARINA gore ortalanir
          //    (bkz. `_listeAnahtar` serhi).
          key: _listeAnahtar,
          // ⚠️ TURU 82b — `AlwaysScrollableScrollPhysics` ZORUNLU: icerigi
          //    ekrandan KISA profillerde (gonderisi olmayan hesap) Android'in
          //    varsayilan `ClampingScrollPhysics`i overscroll uretmedigi icin
          //    asagi-cek jesti HIC TETIKLENMIYORDU — yani o hesaplarda
          //    yenileme yolu FIILEN YOKTU. Turu 77b'de akis icin duzeltilen
          //    sinifin aynisi.
          // ⚠️⚠️⚠️ TURU 180d — **CEKERKEN ICERIK ASAGI INMEZ** (kullanici:
          //	*"yukaridan cektigimde SIYAH ALAN oluyor; ekran asagi
          //	inmeyecek, LOADING olacak daire seklinde"*).
          //
          //	iOS'ta varsayilan `BouncingScrollPhysics`tir: liste
          //	asiri cekmede PARMAGI TAKIP EDER ve `extendBodyBehind
          //	AppBar` yuzunden kapagin USTUNDE zemin rengi (siyah)
          //	gorunur. `ClampingScrollPhysics` icerigi YERINDE
          //	tutar; yalnizca `RefreshIndicator`in dairesi iner.
          // ⚠️ `AlwaysScrollable` SARMALI KALIR: bos listede de asagi-cek
          //	calismali (turu 83b'de dort kardes ekranda ayni sinif).
          //
          // ⚠️⚠️⚠️ TURU 180j — **BOS SEKMEDEKI `NeverScrollable` KALDIRILDI**
          //	(kullanici: *"yukaridan asagi cekme olsun, LOADING ekranda
          //	olsun, YENILESIN"*).
          //
          //	Turu 180e'de bos sekmede kaydirma tamamen kapatilmisti;
          //	ama `RefreshIndicator` bir OVERSCROLL bildirimiyle
          //	tetiklenir ve `NeverScrollableScrollPhysics` o bildirimi
          //	HIC uretmez -> gonderisi olmayan her profilde YENILEME
          //	YOLU FIILEN YOKTU (turu 82b/83b'de dort kardes ekranda
          //	kapatilan sinifin bu ekranda geri gelmis hali).
          // ⚠️ Turu 180e'nin gerekcesi ("cekince bos alan gorunuyordu")
          //	`ClampingScrollPhysics` sayesinde ZATEN gecersiz: icerik
          //	YERINDE kalir, yalnizca yenileme dairesi iner.
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
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
              // ⚠️⚠️ TURU 180k — KAPAK SLIDERI (isletme). Veri `Isletme`den
              //	geliyor ve `_isletme` AG ISTEGIYLE SONRADAN dolar;
              //	`KapakSlider.didUpdateWidget` bu gecisi karsiliyor
              //	(yoksa slider ilk BOS haliyle donardi).
              // ⚠️ Bos ise `ProfilBasligi` ESKI davranisa duser (tek kapak).
              kapakMedyalari: _isletme?.kapakMedyalari ?? const <String>[],
              kapakTurleri: _isletme?.kapakTurleri ?? const <String>[],
              // ⚠️ TURU 179 — nokta YALNIZ calisma saati GIRILMIS bir
              //    isletmede cizilir; `null` gecilirse HIC cizilmez
              //    (bkz. `ProfilBasligi.acik` serhi).
              acik: (_isletme?.calisma.isNotEmpty ?? false)
                  ? _isletme!.simdiAcik
                  : null,
              // ⚠️ Avatara dokunus YALNIZ gercek bir medya varsa is yapar.
              //    `avatarMediaId` bossa (harf avatari) `onTap` NULL gecilir —
              //    dokunulabilir gorunup hicbir sey yapmayan bir alan
              //    birakmak bu projede tekrar eden "olu dugme" sinifidir.
              // ⚠️⚠️ TURU 180d — **LOGO DAIRE OLARAK, ORTADA, ARKASI BLUR**
              //	(kullanici emri). Onceden tam ekran KARE bir gorsel
              //	aciliyordu ve dairesel avatarla ilgisi yoktu.
              onAvatarDokun: (p.avatarMediaId ?? '').isEmpty
                  ? null
                  : () => _logoAc(p.avatarMediaId!),
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
            // ⚠️⚠️⚠️ TURU 180u — **ETIKET CIPLERI CAGRI YERINDEN CIKARILDI**
            //	(kullanici emri: *"20 spor salonu gibi seyler profilde
            //	gorunmesin"*).
            //
            //	`_profilEtiketleri` yas + takim + **12'ye kadar ILGI ALANI**
            //	cipi ciziyordu (`profil_secenekleri.dart` icinde "Spor
            //	salonu" da var, `kEnFazlaIlgi = 12`). 14 cip alt alta
            //	sariyor ve profilin ustunu dolduruyordu.
            //
            // ⚠️⚠️ **KAYIT FORMU OLU KALMADI**: ayni alanlar
            //	`profil_duzenle.dart` uzerinden HALA duzenlenebiliyor ve
            //	`PATCH /users/me` ile sunucuya yaziliyor. Yani turu 120'nin
            //	"veri toplanir ama hicbir yerde gorunmez" endisesi bu
            //	kaldirmayla GECERLI DEGIL.
            // ⚠️ Govde SILINMEDI (`ignore: unused_element`): karar tek
            //	satirla geri alinabilsin — bu dosyada uye silmek BES kez
            //	komsu uyeyi goturdu.
            // TURU 77 — ISLETME BILGI SERIDI. Profil bir ISLETME hesabiysa
            // kategori/adres/telefon/calisma saatleri ve Urunler/Menu girisi
            // burada cizilir. Kisisel hesapta HIC cizilmez.
            // ⚠️ TURU 176 — bilgi karti buradan KALDIRILDI; icerigi artik
            //    **Genel** sekmesinde (bkz. `_genelSayfasi`).
            const SizedBox(height: 16),
            _sayaclar(p),
            // ⚠️⚠️⚠️ TURU 180d — **YAPAY ZEKA YORUMU BURAYA** (kullanici:
            //	*"gonderi/takip vs ILE takip et/mesaj ARASINDA yapay
            //	zeka yorumunu koy; oraya yapay zekanin GENEL YORUMUNU
            //	gostermen gerekiyor"*). Dokunus yorum panelini acar.
            _aiOzetSatiri(p),
            const SizedBox(height: 12),
            _dugmeler(p),
            // ⚠️ TURU 179 — 8 -> **22** (kullanici: *"gonderiler vs alt menu
            //	ile takip et mesaj bunlarin arasindaki boslugu ARTTIR"*).
            // ⚠️ TURU 180g — 22 -> **16**: yapay zeka karti buyudu ve alttaki
            //	bos duruma kalan yer 60 dp'ye dusmustu (olculdu).
            const SizedBox(height: 16),
            // ⚠️ TURU 176 — **USTTEKI AYIRICI KALDIRILDI** (kullanici:
            //	*"yukaridaki cizgiyi kaldir"*). Sekme seridinin
            //	KENDI alt ayiricisi duruyor ve secim cizgisi artik
            //	onun tam ustune biniyor; iki cizgi ust uste
            //	seridi bir kutu gibi gosteriyordu.
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
              KeyedSubtree(key: _seritAnahtar, child: _sekmeSeridi()),
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
              // ⚠️⚠️⚠️ TURU 180j — **`PageView` KALDIRILDI, TEK KAYDIRMA**
              //	(kullanici: *"sayfa yukari asagi TAKILIYOR, gonderi
              //	alaninda yukari asagi cekme var, bunu kaldir; yukari
              //	asagi NORMAL bir sekilde olsun"*).
              //
              //	KOK NEDEN: turu 115'in `PageView`i SABIT yukseklikli
              //	bir kutuydu ve her sayfasi KENDI `ListView`iydi
              //	(`_sekmeSayfasi`). Yani sayfada IKI dikey kaydirma
              //	alani vardi: dis liste (baslik+sekmeler) ve ic liste
              //	(gonderiler). Parmak izgaranin uzerindeyken surukleme
              //	ICTEKINE gidiyor, o kendi ucuna gelene kadar dis liste
              //	KIMILDAMIYORDU — kullanicinin "takiliyor" dedigi sey
              //	tam olarak bu ic ice kaydirma catismasi.
              //
              //	Artik secili sekmenin icerigi dis listenin DOGRUDAN
              //	cocugu: `_izgara` (`shrinkWrap` + `NeverScrollable`)
              //	ve `_ilanListesi` (`Column`) zaten kaydirilamaz, yani
              //	sayfada TEK kaydirilabilir alan kaliyor.
              // ⚠️⚠️ YATAY GECIS KAYBOLMADI: turu 114'un jest desenine
              //	donuldu (`onHorizontalDragEnd`). Dikey kaydirmayi
              //	ETKILEMEZ — jest arenasinda yatay ve dikey taniyicilar
              //	AYRI eksenlerde yarisir. Kaybedilen tek sey icerigin
              //	parmagi TAKIP ETMESI; kazanilan sey sayfanin tek parca
              //	kaymasi.
              // ⚠️ YAPMA: buraya tekrar sabit yukseklikli bir `PageView`
              //	ya da kendi `ListView`ini kuran bir sekme sayfasi koyma.
              _icerikAlani(),
            ],
          ],
        ),
          ),
        ],
      ),
    ));
  }

  /// Isletme profiliyse bilgi seridi; degilse HIC yer kaplamaz.

  /// ⚠️⚠️⚠️ TURU 120 — PROFIL ETIKETLERI: **yas · takim · ilgi alanlari**.
  ///
  /// Kayit akisinin "Biraz da senden" adiminda toplanan veriyi GOSTEREN tek
  /// yer burasi. Olmasaydi form OLU olurdu (bkz. cagri yerindeki serh).
  ///
  /// ⚠️ **HICBIRI ZORUNLU DEGIL**: ucu de bossa satir HIC cizilmez —
  ///    "Yaş: belirtilmemiş" gibi bos alanlar profili kirletir.
  /// ⚠️ Yas etiketi yalnizca sayi ("28"): gun/ay sorulmadigi icin
  ///    "28 yaşında" demek ±1 yillik hatayi KESIN BILGI gibi sunardi
  ///    (bkz. `Profil.yas` serhi).
  /// ⚠️ Renkler TEMADAN: bu ekran acik/koyu temanin ikisinde de kullaniliyor;
  ///    sabit renk koyu temada okunmaz olurdu (turu 81b kontrast dersi).
  /// ⚠️ `Wrap` — `Row` DEGIL: 12 ilgi alani tek satira sigmaz ve `Row`
  ///    RenderFlex tasma seridi cizerdi.
  // ignore: unused_element
  Widget _profilEtiketleri(Profil p) {
    final yas = p.yas;
    final takim = p.takim.trim();
    if (yas == null && takim.isEmpty && p.ilgiAlanlari.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = _ks;
    Widget etiket(String metin, IconData ikon, {bool vurgulu = false}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: vurgulu
                ? scheme.primary.withValues(alpha: 0.10)
                : scheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: vurgulu
                  ? scheme.primary.withValues(alpha: 0.28)
                  : scheme.onSurface.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ikon,
                size: 13,
                color: vurgulu
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 5),
              Text(
                metin,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: vurgulu
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 7,
        runSpacing: 7,
        children: [
          if (yas != null) etiket('$yas', LucideIcons.cake, vurgulu: true),
          if (takim.isNotEmpty)
            etiket(takim, LucideIcons.volleyball, vurgulu: true),
          for (final i in p.ilgiAlanlari) etiket(i, LucideIcons.tag),
        ],
      ),
    );
  }

  // ⚠️⚠️ TURU 176 — **BILGI KARTI CAGRI YERINDEN CIKARILDI** (kullanici:
  //	*"yemek hacimahalle vs bilgi karti olmasin, onu gonderinin
  //	soluna GENEL olarak koy"*). Icerik `_genelSayfasi`na tasindi.
  // ⚠️ `IsletmeSeridi` sinifi SILINMEDI: baska bir ekrandan cagrilirsa
  //    diye duruyor ve bu dosyada silme riski yuksek (turu 67'de buyuk
  //    dosyada coklu blok duzenlemesi dosyayi BOZMUSTU).
  // ignore: unused_element
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
                    // ⚠️ TURU 180g — header artik KIMIN listesi oldugunu
                    //    yaziyor (kullanici emri).
                    kisiAd: p.ad,
                    kisiKullanici: p.username,
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
                    kisiAd: p.ad,
                    kisiKullanici: p.username,
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

  /// ⚠️⚠️ Yapay zeka **GENEL YORUMU** — buton DEGIL, okunabilir bir ozet.
  ///
  /// ⚠️ Metin `isletme_bilgi.dart`taki ORNEK yorumlardan TURETILIR
  ///	(`aiOzetMetni`), bir MODEL CIKTISI DEGILDIR — panelin icinde
  ///	bu ACIKCA yaziyor. Sahte bir "AI analizi" gostermek olmayan
  ///	bir yetenegi varmis gibi anlatmak olurdu.
  /// ⚠️ YALNIZ ISLETMEDE cizilir: kisisel hesabin yorumu YOKTUR.
  /// ⚠️ `PageRouteBuilder` + `opaque: false`: arkadaki profil GORUNUR
  ///	kalmali, yoksa "arkasi blurlu" istegi karsilanamaz
  ///	(varsayilan route arkayi tamamen kapatir).
  /// ⚠️ `BackdropFilter` TAM EKRANI kaplar; `ClipOval` YOK cunku
  ///	bulaniklastirilan sey ARKA PLAN, gorselin kendisi degil.
  /// ⚠️ Perdeye dokunus kapatir (`Navigator.pop`) — kullanici buyutulmus
  ///	logodan cikmanin yolunu aramak zorunda kalmasin.
  void _logoAc(String mediaId) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (c, anim, _) => FadeTransition(
          opacity: anim,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(c).maybePop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Center(
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutBack,
                  ),
                  child: LayoutBuilder(
                    builder: (_, kisit) {
                      // ⚠️ Cap EKRANDAN turetilir (sabit dp DEGIL): kucuk
                      //    telefonda tasar, tablette kucuk kalirdi.
                      final cap = math.min(
                        kisit.maxWidth * 0.72,
                        kisit.maxHeight * 0.5,
                      );
                      return ClipOval(
                        child: SizedBox(
                          width: cap,
                          height: cap,
                          child: MedyaGorsel(
                            mediaId: mediaId,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 180g — **YAPAY ZEKA KARTI** (kullanici bir referans
  ///	gorsel gonderdi: koyu gri kart · ust satirda DAIRE ROZET +
  ///	ad · sagda "daha fazla bilgi ↗" · altta BEYAZ govde metni,
  ///	uc satirda kesilip "…" ile bitiyor).
  ///
  /// ⚠️ Kart zemini artik MOR TONLU DEGIL notr gri: referansta vurgu
  ///	yalniz ROZET ve BAGLANTI yazisinda, govde metni beyaz.
  /// ⚠️⚠️ Baglanti yazisi `Flexible` + ellipsis: ust satirda iki metin
  ///	ve iki ikon var ve yazi olcegi 1.3'te sabit butce TASAR
  ///	(turu 98c'de birebir olculen sinif). Kisalan taraf
  ///	BILEREK baglanti — "Yapay zekâ" etiketi KIMLIKTIR,
  ///	kirpilmamali.
  /// ⚠️ Kartin TAMAMI tiklanabilir kalir: "daha fazla bilgi" yalniz
  ///	GORUNUR bir isarettir, 44 dp'lik bir dokunma hedefi degil.
  Widget _aiOzetSatiri(Profil p) {
    if (_isletme == null) return const SizedBox.shrink();
    final scheme = _ks;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => yorumlarAc(context, isletmeAd: p.ad),
          child: Padding(
            // ⚠️ TURU 180g — dolgu ESIT ve DAHA DAR (kullanici: *"padding
            //    ic boslugu azalt, esit dagilsin, daha fazla okunsun"*).
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⚠️⚠️ TURU 180g — **ROZET IKONU, "daha fazla bilgi" VE OK
                //	KALDIRILDI** (kullanici emri). Kart ZATEN tamamen
                //	tiklanabilir; uc ayri isaret (ikon + baglanti + ok)
                //	metne ayrilacak yeri yiyordu.
                // ⚠️ Boylece ust satirdaki `Spacer`/`Flexible` yarisi da
                //	YAPISAL OLARAK ortadan kalkti (varsayilan olcekte
                //	bile "daha fazla…" diye kirpiliyordu).
                Text(
                  'Yapay zekâ',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  aiOzetMetni,
                  // ⚠️ Uc satir: ozet burada OKUNSUN diye. Tamami yorum
                  //    panelinde.
                  // ⚠️ 3 -> **4 satir** (kullanici: "daha fazla okunsun");
                  //    tamami yorum panelinde.
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dugmeler(Profil p) {
    // ⚠️⚠️ TURU 75b (DENETIM BULGUSU): KENDI PROFILIMDE "Takip et" / "Mesaj" /
    //    "Engelle" / "Şikayet et" cikiyordu. Ekran kendi kimligimle de aciliyor
    //    (Profil sekmesi -> "Gönderilerim ve profilim") ama hicbir "bu benim"
    //    kapisi yoktu: kendini takip etmeye calisinca sunucu 400 doner, kendini
    //    engelleme/sikayet ise anlamsiz.
    if (_benimMi) return _kendiDugmelerim();

    final takipli = p.takipEdiyorum;
    final bekliyor = p.istekBekliyor;
    // ⚠️⚠️ TURU 179 — yan bosluk 40 -> **24** (kullanici: *"takip et ve
    //	mesaj bunlarin genisligini biraz daha AZALT"*).
    //	⚠️ 52 DENENDI ve EMULATORDE GERI ALINDI: satira UCUNCU dugme
    //	("Yorumlar") girince `FittedBox` metinleri kucultmeye
    //	basladi ve "Takip et"/"Yorumlar" yazilari "Mesaj"dan
    //	GORUNUR bicimde ufak kaldi. Dugmeler turu 176'daki 12 dp'ye
    //	gore HALA dar; degisen yalniz kucultmenin devreye girmemesi.
    // ⚠️ Hepsi `Expanded` oldugu icin ESITLIK KORUNUR; degisen yalniz
    //    satirin dis payi.
    // ⚠️⚠️ **YORUMLAR ORTAYA** (kullanici: *"takip et ve mesaj arasina
    //	yorumlar olsun"*) ve YALNIZ ISLETMEDE cizilir: kisisel
    //	hesabin "yorumu" YOKTUR, dugme HER ZAMAN bos bir panel
    //	acardi.
    // ⚠️ Uc dugme dar ekranda sigmali: metinler kisa ('Takip'/'Mesaj')
    //	ve `FittedBox(scaleDown)` ile korunuyor (turu 143 dersi:
    //	Flutter tek kelimeyi ORTADAN BOLER).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  p.engelledim
                      ? 'Engellendi'
                      : bekliyor
                      ? 'İstek gönderildi'
                      : takipli
                      ? 'Takiptesin'
                      : (p.beniTakipEdiyor ? 'Geri takip' : 'Takip et'),
                ),
              ),
            ),
          ),
          // ⚠️⚠️ TURU 180d — ucuncu dugme KALDIRILDI: yapay zeka yorumu
          //    artik sayaclarin ALTINDA bir SATIR (bkz. `_aiOzetSatiri`).
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              // ⚠️ Engelledigimiz kisiyle sohbet ACILMAZ (sunucu da reddeder).
              onPressed: p.engelledim ? null : () => _sohbetAc(p),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Mesaj'),
              ),
            ),
          ),
          // ⚠️⚠️⚠️ TURU 180j — **MENU MESAJIN SAGINDA, REZERVASYON YOK**
          //	(kullanici: *"isletme profilinde menuyu mesaj butonun
          //	saginda koy, rezervasyonu kaldir"*).
          //
          //	Onceden burada REZERVASYON vardi (turu 180h) ve Menü
          //	alttaki YUZEN HAPTA duruyordu. Ikisi de yer degistirmedi,
          //	biri KALDIRILDI: rezervasyon girisi artik profilde HIC
          //	cizilmiyor, Menü ise hapin yerine bu satira gecti.
          // ⚠️⚠️ **YUZEN HAP TAMAMEN KALKTI** — hapin tasidigi TEK dugme
          //	Menü idi; bos bir kabuk birakmak ekranin dibinde anlamsiz
          //	bir golge olurdu. Bu ayni zamanda `_gorunurSerit`teki
          //	"hap kadar yukari it" hesabini da gereksiz kildi.
          // ⚠️ YALNIZ ISLETME hesabinda cizilir (`_isletme != null`):
          //	kisisel hesabin menusu/katalogu YOKTUR ve dugme her
          //	dokunusta bos bir sayfa acardi ("olu dugme" sinifi).
          // ⚠️ Etiket SUNUCUDAN (`i.modul.ad` -> Menü / Odalar /
          //	Hizmetler); istemcide TAHMIN EDILMEZ (turu 89).
          if (_isletme != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UrunKatalogEkrani(
                      isletmeId: widget.userId,
                      isletmeAd: p.ad,
                      benimMi: _benimMi,
                      modul: _isletme!.modul,
                    ),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_isletme!.modul.ad),
                ),
              ),
            ),
          ],
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
  /// ⚠️⚠️⚠️ TURU 180ae — **KENDI PROFILIMDE ARTIK DUGME YOK.**
  ///
  /// Kullanici emri: *"profilde profil duzenle ve kaydedilen butonlari
  /// kaldir gereksiz, onun yerine sol uste icon ekle duzenleme ikonu
  /// yeterli"* + *"isletme hesabindaki hizmetleri yonet / menuyu yonet
  /// bunlar olmasin, ayarlardan yapilsin"*.
  ///
  /// ⚠️⚠️ **HICBIR OZELLIK ULASILAMAZ KALMADI** (bu projede o sinif DOKUZ
  ///	kez sahaya cikti) — girisler TASINDI:
  ///	  · Profili duzenle -> header'da **sol ust kalem ikonu**
  ///	  · Kaydedilenler   -> Hesabım (disli) ekrani
  ///	  · "…yonet" (katalog) -> Hesabım > **Işletme bilgilerim**
  /// ⚠️ Uc girisin UCU DE bu turda ACIKCA dogrulandi; biri eksik olsaydi
  ///	isletme sahibi kendi menusune BIR DAHA giremezdi (turu 180o'da
  ///	birebir bu yasandi).
  Widget _kendiDugmelerim() => const SizedBox.shrink();

  // ignore: unused_element
  Widget _eskiKendiDugmelerim() => Column(
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
      // ⚠️⚠️⚠️ TURU 180o — **ISLETME KENDI KATALOGUNA GIREMIYORDU.**
      //
      //	Kullanici sorusu: *"otel odasinda galeri vs ... her sey var mi?"*
      //	Emulatorde OTEL HESABIYLA bakildi: kendi profilinde **Odalar
      //	dugmesi YOKTU**. Kok neden `_dugmeler`in ILK SATIRI:
      //	`if (_benimMi) return _kendiDugmelerim();` — erken donus,
      //	altindaki `if (_isletme != null)` modul dugmesine HIC
      //	ULASILMIYORDU.
      //	Sonuc: isletme sahibi oda/menu/hizmet EKLEYEMIYOR, mevcutlari
      //	DUZENLEYEMIYORDU; katalog YALNIZ musteri gozuyle (baskasinin
      //	profilinden) acilabiliyordu ve sahip kendi profilinde
      //	"baskasi" olamaz. Ayarlar > "Isletme bilgilerim" alt yazisi
      //	*"...calisma saatleri, menu"* diyordu ama o ekranda da giris
      //	YOKTU — yani vaat GOVDEDE KARSILIKSIZDI.
      // ⚠️ TAM GENISLIK, kardeslerinin ALTINDA: turu 179'da olculdu —
      //	ucuncu dugme AYNI SATIRA girince `FittedBox` metinleri
      //	kucultuyor ve "Profili duzenle" okunmaz hale geliyor.
      // ⚠️ Etiket SUNUCUDAN (`_isletme!.modul.ad`): Menü / Odalar /
      //	Hizmetler. Istemcide TAHMIN EDILMEZ (turu 89).
      if (_isletme != null) ...[
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(LucideIcons.bookOpen, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${_isletme!.modul.ad}ı yönet'),
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UrunKatalogEkrani(
                      isletmeId: widget.userId,
                      isletmeAd: _p?.ad ?? '',
                      benimMi: true,
                      modul: _isletme!.modul,
                    ),
                  ),
                );
                if (mounted) unawaited(_yukle());
              },
            ),
          ),
        ),
      ],
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
        ham
            .where((g) => g.mediaIds.isNotEmpty && g.kind(0) == 'image')
            .toList(),
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
  /// ⚠️ TURU 180 — **`video` de seritten CIKARILDI** (kullanici: *"oradaki
  ///	video ikonunu kaldir"*). Videolar `tumu` ve `reels`
  ///	sekmelerinde ZATEN gorunuyor; ayri bir sekme ayni icerigi
  ///	ucuncu kez listeliyordu.
  ///
  /// ⚠️⚠️ TURU 179 — **`genel` SEKMESI SERITTEN CIKARILDI** (kullanici:
  ///	*"gonderinin solundaki GENEL bilgileri sag ustteki soru
  ///	isaretine tikladiginda %95 POPUP olarak acilsin"*).
  ///
  /// ⚠️ Enum degeri SILINMEDI: `switch`ler TUKENMIS yazilmis ve olu bir
  ///	deger her birinde ULASILAMAZ dal birakirdi (turu 176 dersi).
  ///	Govdesi (`_genelSayfasi`) da DURUYOR — panel onu KULLANMIYOR
  ///	ama seritten kaldirma TEK SATIRLA geri alinabilsin.
  List<ProfilSekmesi> get _sekmeler => [
    for (final x in ProfilSekmesi.values)
      // ⚠️⚠️ TURU 180 — `isIlani` **HERKESE** gorunur (kullanici emri:
      //	*"profile is ilanini da ekle"*). Digerleri (`ilan`,
      //	`dolap`, `talep`…) YALNIZ kendi profilinde: onlar
      //	"ilanlarim/taleplerim" gibi BIRINCI SAHIS bolumler ve
      //	baskasinin profilinde "Henüz ilan vermedin" demek
      //	sacma olurdu.
      // ⚠️ Bir isletmenin IS ILANI ise MUSTERIYI ilgilendirir — zaten
      //	herkese acik bir liste (`/ilanlar?tur=is&user_id=`).
      // ⚠️⚠️⚠️ TURU 180m — **`begeni` ISLETME PROFILINDE DE CIZILIR**
      //	(kullanici UC KEZ istedi: *"isletme sayfasinda begeni yeri koy
      //	dedim 3 defa, halen koymamissin"*).
      //
      //	Turu 180g'de sekme YALNIZ kendi profilimde cizilyordu ve
      //	gerekcesi gizlilikti ("baskasinin neyi begendigi gizlidir").
      //	Kullanici karari BUNU GECERSIZ KILAR — ustelik yalnizca
      //	ISLETME hesaplari icin: bir isletmenin begendigi icerik
      //	musteriye ilgi alanini gosterir, kisisel hesabin begenisi
      //	hala GIZLI kalir.
      // ⚠️⚠️ **VERI HENUZ GELMIYOR — DURUST SINIR.** Sunucudaki uc
      //	`/users/me/begeniler`, yani BASKASI icin cagrilacak bir yol
      //	YOK. Sekme cizilir ve icerik "yakinda" der; gercek liste
      //	`GET /users/{id}/begeniler` acildiginda gelir (BACKEND TURU —
      //	kullanici emri: *"backendi sonra yap, arayuzu hizli cikart"*).
      // ⚠️ YAPMA: sekmeyi bos liste ile cizme — "bu isletme hicbir sey
      //	begenmemis" YALANI olurdu (turu 176/179 dersi).
      // ⚠️⚠️⚠️ TURU 180u — **SERIT BES SEKMEYE INDI** (kullanici emri:
      //	*"gonderiler resim reels begeni repost ekle yani tekrar
      //	paylasilan DIGERLERINI KALDIR"*).
      //
      //	Kalanlar: `tumu` · `foto` · `reels` · `begeni` · `repost`.
      //	Cikanlar: `ilan` · `isIlani` · `dolap` · `hizmet` · `talep` ·
      //	`dugun` (turu 180'de eklenen `isIlani` DAHIL — kullanici
      //	kararini GERI ALDI).
      // ⚠️ Enum degerleri ve govdeleri (`_ilanListesi`, `_ilanKarti`,
      //	`_sekmeYukle`in ilan dali) SILINMEDI: bu dosyada uye silmek
      //	BES kez komsu uyeyi goturdu, ustelik asagidaki KISAYOL dali
      //	onlari HALA cizdiriyor.
      if (_seritte(x)) x,
    // ⚠️⚠️⚠️ **KISAYOL SEKMESI SERITE GERI EKLENIR.**
    //	`home_screen.dart`taki DORT ayar satiri (İlanlarım · Hizmetlerim ·
    //	Düğünüm · Taleplerim) profili `baslangicSekmesi` ile aciyor.
    //	O sekme seritte cizilmezse: (a) kullanici hangi listede oldugunu
    //	GOREMEZ, (b) `_icerikAlani`nin yatay jesti `indexOf` -1 dondugu
    //	icin OLUR, (c) `_seridiKaydir` hedef bulamaz.
    // ⚠️ Deger `initState`te BIR KEZ yakalanir (`_kisayolSekme`); `_sekme`
    //	uzerinden hesaplansaydi kullanici baska sekmeye dokununca serit
    //	ORTADAN bir oge kaybeder ve liste ZIPLARDI.
    if (_kisayolSekme != null) _kisayolSekme!,
  ];

  /// Serit filtresinin TEK KAYNAGI (kisayol dali bunun DISINDA).
  bool _seritte(ProfilSekmesi x) =>
      // ⚠️⚠️ `begeni` ISLETME profilinde de cizilir (turu 180m, kullanici
      //	UC KEZ istedi); kisisel hesabin begenisi GIZLI kalir.
      // ⚠️⚠️ `repost` AYNI KAPIDAN gecer: sunucuda uc YOK, baskasinin
      //	profilinde "yakinda" der (bkz. enum serhi).
      x == ProfilSekmesi.tumu ||
      x == ProfilSekmesi.foto ||
      x == ProfilSekmesi.reels ||
      ((x == ProfilSekmesi.begeni || x == ProfilSekmesi.repost) &&
          (_benimMi || _isletme != null));

  /// TURU 176 — alttaki yuzen **Menü / Rezervasyon** geçisi.
  ///
  /// ⚠️⚠️⚠️ TURU 180j — **CAGRI YERI KALDIRILDI, GOVDE DURUYOR.**
  ///	Menü artik `_dugmeler` satirinda (Mesaj'in saginda), rezervasyon
  ///	ise profilden TAMAMEN cikarildi (kullanici emri) — hapin
  ///	tasiyacagi hicbir sey kalmadi.
  ///	Govde SILINMEDI: bu dosyada uye silmek BES kez komsu uyeyi de
  ///	goturdu (turu 127/138/140/141/143) ve karar tek satirla geri
  ///	alinabilsin isteniyor.
  /// ⚠️ Isletme degilse ya da hicbir yetenek yoksa **null** doner ve
  ///	Scaffold hicbir sey cizmez (bos bir kabuk birakmak ekranin
  ///	dibinde anlamsiz bir golge birakirdi).
  // ignore: unused_element
  Widget? _menuRezervasyon() {
    final i = _isletme;
    if (i == null) return null;
    final scheme = _ks;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(26),
        color: scheme.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _gecisDugmesi(
              ikon: LucideIcons.bookOpen,
              // TURU 89 - kategoriye gore Menü / Odalar / Hizmetler;
              //    ad SUNUCUDAN gelir, istemcide tahmin EDILMEZ.
              etiket: i.modul.ad,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UrunKatalogEkrani(
                    isletmeId: widget.userId,
                    isletmeAd: _p?.ad ?? '',
                    benimMi: _benimMi,
                    modul: i.modul,
                  ),
                ),
              ),
            ),
            // ⚠️⚠️ TURU 180h — **REZERVASYON BURADAN KALDIRILDI**
            //	(kullanici: *"rezervasyon mesajin saginda olsun,
            //	menu orada kalsin"*). Yuzen gecis artik TEK
            //	dugme: Menü. Rezervasyon `_dugmeler` satirinda.
            //	Rezervasyon artik `_dugmeler` satirinda.
          ],
        ),
      ),
    );
  }

  Widget _gecisDugmesi({
    required IconData ikon,
    required String etiket,
    required VoidCallback onTap,
    bool vurgulu = false,
  }) {
    final scheme = _ks;
    final on = vurgulu ? scheme.onPrimary : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: vurgulu ? scheme.primary : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 17, color: on),
            const SizedBox(width: 8),
            Text(
              etiket,
              style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: on),
            ),
          ],
        ),
      ),
    );
  }

  /// TURU 176 — **GENEL SEKMESI** (kullanici emri: *"gonderinin soluna
  /// Genel olarak koy; adres, iletisim, calisma saatleri, harita"*).
  ///
  /// ⚠️⚠️ **GOMULU HARITA CIZILMEDI, BILINCLI.** `GoogleMap` her profil
  ///	acilisinda bir **Dynamic Maps** yuklemesi demek ($7/1000 —
  ///	turu 169'da olculen tabloya gore 50K kullanicida aylik
  ///	binlerce dolar). Yerine konum SATIRI + dokununca CIHAZIN
  ///	harita uygulamasi acilir: kullanici icin ayni is, bize
  ///	maliyeti **0**.
  /// ⏳ **"Ozellikler" (kredi karti · wifi) YAZILMADI**: `Isletme`
  ///	modelinde ve sunucuda BOYLE BIR ALAN YOK (olculdu). Sabit
  ///	bir liste basmak "bu isletme kredi karti aliyor" YALANI
  ///	olurdu (turu 135'te kur seridi TAM BU SEBEPLE silindi).
  ///	Once migration + `PUT /users/me/isletme` alani gerekiyor.
  Widget _genelSayfasi() {
    final i = _isletme;
    final scheme = _ks;
    if (i == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
        child: Center(
          child: Text(
            'Bilgi yok',
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      );
    }
    final adres =
        [i.adres, i.ilce, i.il].where((x) => x.isNotEmpty).join(', ');
    const gunAd = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (i.calisma.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    i.simdiAcik ? LucideIcons.circleCheck : LucideIcons.clock,
                    size: 16,
                    color: i.simdiAcik
                        ? const Color(0xFF2BB673)
                        : scheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    i.simdiAcik ? 'Şu an açık' : 'Şu an kapalı',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: i.simdiAcik
                          ? const Color(0xFF2BB673)
                          : scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          if (adres.isNotEmpty)
            _genelSatir(LucideIcons.mapPin, 'Adres', adres,
                // ⚠️ Dokunus YALNIZ koordinat VARSA: koordinatsiz bir
                //    adresle harita acmak bos ekran gosterirdi.
                onTap: (i.enlem != null && i.boylam != null)
                    ? () => _haritadaAc(i.enlem!, i.boylam!, adres)
                    : null),
          if (i.telefon.isNotEmpty)
            _genelSatir(LucideIcons.phone, 'Telefon', i.telefon,
                onTap: () => _telefonAc(i.telefon)),
          if (i.web.isNotEmpty)
            _genelSatir(LucideIcons.globe, 'Web', i.web),
          if (i.calisma.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Çalışma saatleri',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface),
            ),
            const SizedBox(height: 6),
            // ⚠️ **YEDI GUNUN HEPSI** yazilir (eski kart yalnizca BUGUNU
            //    gosteriyordu). Kullanici *"calisma saatleri"* dedi;
            //    tek gun bir "saat" degil bir "durum" bildirir.
            for (var g = 1; g <= 7; g++)
              Builder(builder: (_) {
                final c = i.calisma.where((e) => e.gun == g).firstOrNull;
                final bugunMu = DateTime.now().weekday == g;
                final metin = (c == null || c.kapali)
                    ? 'Kapalı'
                    : '${c.acilis} - ${c.kapanis}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 46,
                        child: Text(
                          gunAd[g - 1],
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                bugunMu ? FontWeight.w800 : FontWeight.w600,
                            color: scheme.onSurface
                                .withValues(alpha: bugunMu ? 1 : 0.65),
                          ),
                        ),
                      ),
                      Text(
                        metin,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              bugunMu ? FontWeight.w800 : FontWeight.w500,
                          color: scheme.onSurface
                              .withValues(alpha: bugunMu ? 1 : 0.65),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _genelSatir(IconData ikon, String etiket, String deger,
      {VoidCallback? onTap}) {
    final scheme = _ks;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ikon,
                size: 17,
                color: scheme.onSurface.withValues(alpha: 0.55)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiket,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    deger,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            // ⚠️ Ok YALNIZ dokunulabilir satirda: dokunulamayan bir satirda
            //    ok cizmek "olu dugme" olurdu.
            if (onTap != null)
              Icon(LucideIcons.chevronRight,
                  size: 17,
                  color: scheme.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }

  /// Cihazin harita uygulamasini acar (**bize maliyeti 0**).
  Future<void> _haritadaAc(double lat, double lng, String ad) async {
    final u = Uri.parse(
        'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(ad)})');
    // ⚠️ `geo:` semasi yoksa (bazi cihazlarda) web haritasina duser.
    if (!await launchUrl(u, mode: LaunchMode.externalApplication)) {
      await launchUrl(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _telefonAc(String t) async {
    await launchUrl(Uri.parse('tel:$t'));
  }

  /// Isletme detayini ceker. **Hata SESSIZ**: kisisel hesapta 404 NORMAL.
  ///
  /// ⚠️ Servis await'ten ONCE yakalanir (turu 78b: disposed State'te
  ///	`ref.read` StateError firlatir ve `catch` onu yutar).
  Future<void> _isletmeYukle() async {
    final svc = ref.read(isletmeServisiProvider);
    try {
      final i = await svc.detay(widget.userId);
      if (mounted) setState(() => _isletme = i);
    } catch (_) {
      // SESSIZ - isletme olmayan hesapta bu beklenen durumdur.
    }
  }

  /// Secili sekmenin verisini ceker (yalniz ILK secimde).
  ///
  /// ⚠️ `_sekmeYukleniyor` yeniden-girme kapisi: sekmeye hizli hizli
  ///    dokunmak ayni istegi tekrar tekrar atardi.
  Future<void> _sekmeYukle(ProfilSekmesi x) async {
    // ⚠️ Genel sekmesinin verisi `_isletme` ile ZATEN cekiliyor; buraya
    //    girseydi `_gonderiOnbellek`e bos liste yazip sekmeyi "yuklendi
    //    ama bos" durumuna dusururdu.
    if (x == ProfilSekmesi.genel) return;
    if (_sekmeYukleniyor.contains(x)) return;
    if (_gonderiOnbellek.containsKey(x) || _ilanOnbellek.containsKey(x)) return;
    setState(() {
      _sekmeYukleniyor.add(x);
      _sekmeHata.remove(x);
    });
    try {
      if (x.ilanMi) {
        // ⚠️⚠️ TURU 180 — IS ILANI sekmesi BASKASININ profilinde de cizilir,
        //	bu yuzden `benim` DEGIL `sahibi` ile sorulur. `benim: true`
        //	birakilsaydi kullanici HER profilde KENDI is ilanlarini
        //	gorurdu — sessiz ve fark edilmesi zor bir hata.
        final isSekmesi = x == ProfilSekmesi.isIlani;
        var l = await ref.read(ilanServisiProvider).liste(
              tur: x.ilanTuru,
              benim: isSekmesi ? false : true,
              sahibi: isSekmesi ? widget.userId : '',
            );
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
      } else if (x == ProfilSekmesi.begeni) {
        // ⚠️ TURU 180g — AYRI UC: `/users/me/begeniler`. `kullaniciGonderileri`
        //    ile getirilemez (o `?tur=` suzgeci alir, KAYNAK tabloyu degil).
        // ⚠️⚠️⚠️ TURU 180m — **YALNIZ KENDI PROFILIMDE CAGRILIR.**
        //	Uc `/users/me/begeniler`, yani DAIMA OKUYANIN begenilerini
        //	dondurur. Kapi olmasaydi baskasinin (isletmenin) profilinde
        //	**KENDI BEGENILERIM** o isletmenin begenileri gibi
        //	cizilirdi — sessiz ve fark edilmesi cok zor bir YANLIS VERI.
        //	Isletme profilinde sekme CIZILIR ama icerik durustce
        //	"yakinda" der (bkz. `_sekmeIcerigi`).
        // ⚠️ YAPMA: bu kapiyi kaldirip listeyi baskasinin profiline basma.
        if (!_benimMi) {
          if (!mounted) return;
          setState(() => _gonderiOnbellek[x] = const <Gonderi>[]);
          return;
        }
        final l = await ref.read(sosyalServisiProvider).begenilenler();
        if (!mounted) return;
        setState(() => _gonderiOnbellek[x] = l);
      } else if (x == ProfilSekmesi.repost) {
        // ⚠️⚠️⚠️ TURU 180u — **HICBIR AG ISTEGI ATILMAZ: REPOST UCU YOK.**
        //	`kullaniciGonderileri`ye dusseydi `?tur=repost` giderdi ve
        //	sunucunun beyaz listesi (foto/video/reels/yazi) bunu **400**
        //	ile reddederdi -> sekme kalici "Yüklenemedi" gosterirdi.
        // ⚠️ Onbellege YAZMAK ZORUNLU: yazilmazsa `_sekmeIcerigi` veriyi
        //	`null` gorur ve sekme SONSUZ spinner'da kalir.
        // ⚠️ Demo yalniz KENDI profilimde: baskasinin profilinde benim
        //	demo repostlarimi cizmek turu 180m'de begeni icin yasanan
        //	"yanlis kisinin verisi" hatasinin aynisi olurdu.
        if (!mounted) return;
        setState(
          () => _gonderiOnbellek[x] = (kDemoAkis && _benimMi)
              ? demoGonderiler().where((g) => g.repostSayisi > 0).toList()
              : const <Gonderi>[],
        );
        return;
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
  // ⚠️⚠️ TURU 180j — `PageView` de KALKTI (bkz. `_icerikAlani`); yatay gecis
  //    yeniden JESTLE yapiliyor, yani turu 114 desenine donuldu.

  /// SECILI sekmenin icerigi — dis listenin DOGRUDAN cocugu.
  ///
  /// ⚠️⚠️⚠️ TURU 180j — **SAYFADA TEK DIKEY KAYDIRMA ALANI VAR.**
  ///	Buradan donen agacin KENDI dikey kaydirmasi OLMAMALIDIR;
  ///	`_izgara` (`shrinkWrap` + `NeverScrollableScrollPhysics`),
  ///	`_ilanListesi` (`Column`) ve bos/hata/yukleme dallari bu
  ///	sozlesmeye uyar. Buraya bir `ListView`/`GridView` (kaydirmasi
  ///	acik) koyulursa ic ice kaydirma catismasi GERI GELIR.
  ///
  /// ⚠️⚠️ **BOS DAL `Center` ILE ORTALANIR AMA SARMALSIZ DEGIL:**
  ///	`_bosDurum` kendi `SizedBox(height: _gorunurSerit(...))`unu
  ///	tasiyor, yani sinirsiz dikey kisitta da ortalanabiliyor
  ///	(turu 180e/180g dersi: `ListView` icindeki `Center` ORTALAMAZ).
  ///
  /// ⚠️ Yatay jest: **`onHorizontalDragEnd`** — hiz esigi 120 px/sn
  ///	(turu 114'te olculdu; daha dusuk esik dikey kaydirmanin hafif
  ///	yatay bilesenini de sekme degisimi sanardi).
  /// ⚠️ `HitTestBehavior.opaque` ZORUNLU: bos/hata durumlarinda cizilen
  ///	alan da jesti ALMALI, yoksa tam o durumda gecis calismazdi.
  Widget _icerikAlani() {
    // ⚠️ Bos durumun ortalanmasi icin serit alt kenari OLCULMELI.
    _olcumIste();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 120) return;
        final l = _sekmeler;
        final i = l.indexOf(_sekme);
        if (i < 0) return;
        // ⚠️ Sola cekmek (negatif hiz) SONRAKI sekme.
        final j = v < 0 ? i + 1 : i - 1;
        if (j < 0 || j >= l.length) return;
        _sekmeyeGec(l[j]);
      },
      child: KeyedSubtree(
        // ⚠️ Anahtar SEKMEYE bagli: sekme degisince eski icerigin element
        //	agaci YENIDEN KULLANILMAZ. Aksi halde izgara -> ilan listesi
        //	gecisinde Flutter ayni elemanlari eslestirmeye calisir ve
        //	medya cozucusu bir kare boyunca ESKI gonderiyi cizerdi.
        key: ValueKey<String>('sekme-${_sekme.name}'),
        child: _sekmeIcerigi(_sekme),
      ),
    );
  }

  /// Sekmenin icerigi BOS mu (`_sekmeIcerigi`nin bos daliyla BIREBIR).
  bool _sekmeBos(ProfilSekmesi x) {
    if (x == ProfilSekmesi.genel) return false;
    // ⚠️ TURU 180u — "yakinda" dallari BOS SAYILMAZ: `_bosDurum` cizilmiyor,
    //	yani serit alt kenari olcumu (`_gorunurSerit`) devreye girmemeli.
    if (x == ProfilSekmesi.begeni && !_benimMi) return false;
    if (x == ProfilSekmesi.repost && !(kDemoAkis && _benimMi)) return false;
    if (_sekmeYukleniyor.contains(x) || _sekmeHata[x] != null) return false;
    if (x.ilanMi) return (_ilanOnbellek[x] ?? const []).isEmpty;
    return (_gonderiOnbellek[x] ?? const []).isEmpty;
  }

  Widget _sekmeIcerigi(ProfilSekmesi x) {
    // ⚠️⚠️ TURU 176 — **GENEL SEKMESI EN BASTA ELE ALINIR.** Asagidaki
    //	yukleme/hata/bos dallari `_gonderiOnbellek`e bakiyor ve
    //	Genel'in boyle bir onbellegi YOK: kapi konmasaydi sekme
    //	KALICI olarak "Bilgi yok" gosterirdi.
    if (x == ProfilSekmesi.genel) return _genelSayfasi();
    // ⚠️ TURU 178 — `Theme.of(context)` DEGIL: bu bir State metodu ve
    //    `build`in kurdugu koyu temayi GORMEZ (turu 135c/138). Acik temali
    //    bir cihazda "Henüz gönderi yok" siyah zemine KOYU GRI cizilip
    //    okunamiyordu (emulatorde goruldu).
    final soluk = _ks.onSurface.withValues(alpha: 0.6);
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
    // ⚠️⚠️ TURU 180m — BASKASININ profilinde `begeni` sekmesi cizilir ama
    //	VERI HENUZ YOK (uc `/users/me/begeniler`). Bos liste basmak
    //	"bu isletme hicbir sey begenmemis" YALANI olurdu; durustce
    //	soyleniyor. ⏳ `GET /users/{id}/begeniler` BACKEND TURUNDA.
    if (x == ProfilSekmesi.begeni && !_benimMi) {
      return _yakindaDurum(x, soluk);
    }
    // TURU 180u — REPOST: sunucuda uc YOK. Demo disinda (ya da baskasinin
    //	profilinde) BOS LISTE degil durustce "yakinda" denir; bos liste
    //	"bu kisi hic repost yapmamis" YALANI olurdu.
    if (x == ProfilSekmesi.repost && !(kDemoAkis && _benimMi)) {
      return _yakindaDurum(x, soluk);
    }
    final l = _gonderiOnbellek[x] ?? const <Gonderi>[];
    if (l.isEmpty) return _bosDurum(x, soluk);
    return _izgara();
  }

  /// ⚠️⚠️⚠️ TURU 115 — **INSTAGRAM/TWITTER TARZI SEKME SERIDI** (kullanici
  ///	emri: *"profilde gonderi fotograf INSTAGRAM VE TWITTER GIBI SOLDAN
  ///	SAGA DOGRU MENU tarzi olsun"*).
  ///
  /// ⚠️⚠️ **ACILIR MENU KALDIRILDI.** Turu 108-109'da sekme secimi bir
  ///	`showMenu` idi: kullanici hangi sekmelerin VAR OLDUGUNU ancak menuyu
  ///	acinca goruyordu. Instagram ve Twitter'da sekmeler EKRANDA DURUR ve
  ///	yatay kayar. Kullanici bunu UC KEZ soyledi.
  ///
  /// ⚠️ Secili sekmenin ALTINDA CIZGI (Twitter deseni) — ayrim yalniz renkle
  ///    yapilsaydi renk korlugunde ayirt edilemezdi (turu 80 karari).
  /// ⚠️ Kalinlik SABIT (w700): secimle degisseydi etiket genisligi degisir ve
  ///    serit her dokunusta OYNARDI (turu 97c'de akis secicisinde olculdu).
  /// ⚠️ Secili sekme GORUS ALANINA KAYDIRILIR (`ensureVisible`): 10 sekme
  ///    var, sagdakiler ekran disinda kaliyor ve kullanici hangisinde
  ///    oldugunu goremezdi.
  /// Secili sekmeyi GORUS ALANINA getirir.
  ///
  /// ⚠️ `addPostFrameCallback` ZORUNLU: secim `setState` ile yeni yazildi,
  ///    hedefin `RenderBox`i BU KAREDE henuz olusmadi.
  /// ⚠️ `hasClients` kapisi: serit henuz cizilmemis olabilir.
  void _seridiKaydir() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _seciliSekmeAnahtar.currentContext;
      if (!mounted || c == null || !_seritCtrl.hasClients) return;
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    });
  }

  /// ⚠️⚠️ TURU 180 — **BOS DURUM: DAIRE ICINDE IKON + ORTALANMIS**
  ///	(kullanici: *"henuz gonderi yok / fotograf yok, o gorunmez
  ///	beyaz cizgi ile alt bolumun ORTASINDA olsun; ustunde
  ///	DAIRE ICINDE gonderi ikonu olsun, digerlerinde video vs"*).
  ///
  /// ⚠️ Ikon SEKMEDEN gelir (`x.ikon`): her sekme kendi simgesini alir,
  ///	ayri bir tablo yazilsaydi sekme eklendiginde geride kalirdi.
  /// ⚠️⚠️ **YUKSEKLIK SABIT DEGIL**: blok, seridin ALTINDA EKRANDA KALAN
  ///	alani (`_gorunurSerit`) kaplar ve icerik DIKEYDE ORTALANIR.
  ///	Onceden `vertical: 60` dolgusu vardi ve metin blogun
  ///	TEPESINDE duruyordu — kullanicinin gordugu buydu.
  /// ⚠️⚠️⚠️ TURU 180j — **`SizedBox` SARMALI ARTIK HAYATI**: bu blok dis
  ///	`ListView`in dogrudan cocugu, yani dikey kisit SINIRSIZ.
  ///	`Center` sinirsiz kisitta ORTALAYAMAZ (turu 180e dersi) —
  ///	`_gorunurSerit` ile verilen ACIK yukseklik olmasa blok yine
  ///	sayfanin tepesine yapisirdi. ⚠️ YAPMA: bu `SizedBox`i kaldirma.
  /// ⚠️ TURU 180j — eski "yuzen hap kadar yukari it" terimi KALKTI: hap
  ///	artik cizilmiyor (Menü, `_dugmeler` satirinda).
  /// ⚠️⚠️ TURU 180g — Blok, seridin ALTINDA **EKRANDA GERCEKTEN KALAN**
  ///	alanda ortalanir; ekranin altina tasan bir kutuda ortalamak
  ///	blogu GORUNMEZ yapardi.
  /// ⚠️ TURU 180m — "veri yok" DEGIL "henuz baglanmadi" durumu.
  ///	`_bosDurum` ile ayni gorsel dil; degisen YALNIZ metin.
  Widget _yakindaDurum(ProfilSekmesi x, Color soluk) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: _gorunurSerit(context),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _ks.onSurface.withValues(alpha: 0.35),
                        width: 1.6,
                      ),
                    ),
                    child: Icon(x.ikon, size: 23, color: soluk),
                  ),
                  const SizedBox(height: 10),
                  // ⚠️⚠️⚠️ TURU 180u — METIN **ENUM'DAN TURETILIR**, koda
                  //	gomulu DEGIL. Onceden sabit "Beğeniler yakında"
                  //	yaziyordu; repost sekmesi eklenince o sekmede de
                  //	"Beğeniler yakında" cikacakti — `flutter analyze`
                  //	TEMIZ gecer, hata YALNIZ EKRANDA gorunurdu.
                  Text(
                    '${x.etiket} yakında',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: soluk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _bosDurum(ProfilSekmesi x, Color soluk) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
        height: _gorunurSerit(context),
        child: Center(
        // ⚠️⚠️ `FittedBox(scaleDown)` ZORUNLU: kalan alan cihaza gore 60-400 dp
        //	arasinda degisir ve sabit olculu blok dar ekranda RenderFlex
        //	tasmasi (sari-siyah serit) uretirdi. `scaleDown` yalnizca
        //	GEREKTIGINDE kucultur, buyutmez.
        // ⚠️ Bedeli biliniyor (docs/yazi-olcegi.md): `FittedBox` yazi
        //	olceginin bir kismini geri alir. Bos durum etiketi icin kabul
        //	edilebilir; alternatif metnin KIRPILMASIYDI.
        child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              // ⚠️ 74 -> 62 -> **52**: kalan alan olculdu (60-80 dp) ve
              //    `FittedBox` olcegi 0,55'e kadar dusuyordu; dogal boy
              //    kuculunce olcek ~0,95'te kaliyor, metin OKUNUR oluyor.
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ⚠️ Cember dolgusu DEGIL KENARLIK: dolu bir daire siyah
                //    zeminde leke gibi durur (emulatorde bakildi).
                border: Border.all(
                  color: _ks.onSurface.withValues(alpha: 0.35),
                  width: 1.6,
                ),
              ),
              child: Icon(x.ikon, size: 23, color: soluk),
            ),
            const SizedBox(height: 10),
            Text(
              x.bosMetin,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: soluk,
              ),
            ),
          ],
        ),
        ),
        ),
        ),
      );

  Widget _sekmeSeridi() {
    final scheme = _ks;
    final l = _sekmeler;
    // ⚠️⚠️ TURU 115c — YUKSEKLIK **OLCEKTEN TURETILIR**, sabit 46 DEGIL.
    //	Olculdu: icerik = max(ikon 17, etiket) + 6 + 2,5 ->
    //	  olcek 1.0 = 26,5 · 1.5 = 35,5 · 1.8 = 41,5 · **2.0 = 44,5**
    //	yani 46 dp tavaninda pay yalnizca **1,5 dp** kaliyordu ve 2.1de
    //	TASACAKTI (iOS erisilebilirlik olcekleri 2.0i asabilir).
    // ⚠️ Taban 46 KORUNUR (kullanicinin gordugu olcu); yalniz gerektiginde
    //    buyur. ⚠️ YAPMA: sabit sayiya geri donme.
    final olcek = MediaQuery.textScalerOf(context);
    // ⚠️⚠️ TURU 125 — **SEKMELER AYIRICI CIZGININ USTUNDE** (kullanici
    //	emri: *"profillerde gönderi vs bunlar çizginin üzerinde olacak,
    //	instagram ve twitter gibi"*).
    //
    //	Onceden serit tek basinaydi: sekmeler ile altindaki icerik
    //	arasinda hicbir ayrim yoktu ve secili sekmenin 26 dp`lik kisa
    //	cizgisi havada duruyordu. Instagram/Twitter`da serit TAM
    //	GENISLIKTE bir ayirici uzerinde oturur; secim gostergesi o
    //	ayiricinin USTUNE biner.
    // ⚠️ Ayirici `Divider` DEGIL `Container`: `Divider` kendi dikey
    //    boslugunu ekler ve serit yuksekligi 16 dp buyurdu.
    // ⚠️ Serit yuksekligi DEGISMEDI (46 taban + yazi olcegi); ayirici
    //    ONUN ALTINA ek 1 dp olarak biner.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: math.max(46.0, olcek.scale(14.5) * 1.252 + 25.5),
          child: ListView.builder(
            controller: _seritCtrl,
            scrollDirection: Axis.horizontal,
            // ⚠️ TURU 178 — serit dolgusu 10 -> 6 ve oge dolgusu 10 -> 18:
            //    sekmeler GENISLEDI (kullanici: *"genel fotograf vs
            //    bunlari genislet, cok dar olmus"*).
            padding: const EdgeInsets.symmetric(horizontal: 6),
            itemCount: l.length,
            itemBuilder: (_, i) {
              final x = l[i];
              final secili = x == _sekme;
              return Semantics(
                button: true,
                selected: secili,
                label: x.etiket,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _sekmeyeGec(x),
                  child: Container(
                    key: secili ? _seciliSekmeAnahtar : null,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    // ⚠️⚠️ TURU 180 — **`IntrinsicWidth` ZORUNLU.**
                    //
                    //	Cizginin ikon+yazi genisliginde olmasi icin
                    //	`crossAxisAlignment: stretch` gerekiyor; ama
                    //	bu `Column` YATAY bir `ListView`in cocugu ve
                    //	orada genislik kisiti SINIRSIZDIR. `stretch`
                    //	sinirsiz genislige yayilmaya calisip SERIDI
                    //	TAMAMEN COKERTIYORDU (emulatorde goruldu:
                    //	sekmeler EKRANDAN KAYBOLDU).
                    //	`IntrinsicWidth` once cocuklarin dogal
                    //	genisligini olcer, `stretch` de o olcuye
                    //	yayilir.
                    // ⚠️ Maliyeti var (fazladan bir olcum gecisi) ama serit
                    //	en fazla 8 oge tasiyor.
                    child: IntrinsicWidth(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ⚠️⚠️ TURU 176 — **SECILI OLMAYANDA SADECE IKON**
                        //	(kullanici emri: *"secili olmayan menude
                        //	sadece icon olsun"*).
                        // ⚠️ Erisilebilirlik KAYBOLMAZ: disaridaki
                        //    `Semantics(label: x.etiket)` etiketi HER
                        //    durumda okur (ekran okuyucu icin metin var).
                        Row(
                          // ⚠️ `stretch` altinda `Row` TUM genislige
                          //    yayilirdi; `min` + `center` ile icerik
                          //    kadar kalir ve cizgi de o kadar olur.
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              x.ikon,
                              // ⚠️ TURU 180 — 17 -> **19** (kullanici:
                              //    *"ikonlari 1 tik daha buyut"*).
                              size: 19,
                              color: secili
                                  ? scheme.onSurface
                                  : scheme.onSurface.withValues(alpha: 0.45),
                            ),
                            if (secili) ...[
                              const SizedBox(width: 6),
                              Text(
                                x.etiket,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ],
                        ),
                        // ⚠️⚠️ TURU 176 — bosluk 6 -> **0**: kullanici
                        //	*"secili oldugunda BEYAZ hafif gorunmeyen
                        //	cizginin TAM USTUNE olsun"* dedi. 6 dp
                        //	bosluk cizgiyi ayiricidan KOPARIYORDU.
                        const Spacer(),
                        // ⚠️⚠️ TURU 180 — **CIZGI IKON+YAZI GENISLIGINDE**
                        //	(kullanici: *"aktif menu cizgi, ikon ve yazi
                        //	genisliginde olsun"*). Sabit 26 dp idi ve
                        //	secili sekmenin altinda ORTADA kisa bir
                        //	cubuk gibi duruyordu.
                        // ⚠️ `SizedBox(width: double.infinity)` ILE OLMAZ:
                        //	`Column` bir `ListView` ogesinin icinde ve
                        //	sinirsiz genislik ister -> RenderFlex
                        //	hatasi. Cizgi ustteki `Row`un GENISLIGINI
                        //	miras alsin diye `Column`a
                        //	`crossAxisAlignment: stretch` verilir ve
                        //	genislik ICERIKTEN gelir.
                        // ⚠️ Cizgi SECILI OLMASA DA yer kaplar (saydam): aksi
                        //    halde secim degisince satir 2 dp ziplardi.
                        Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: secili
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // ⚠️⚠️⚠️ TURU 180ae — **TAM GENISLIKTEKI AYIRICI KALDIRILDI**
        //	(kullanici emri: *"profildeki borderi da kaldir"*).
        //	Onceden burada `Container(height: 1, %10 beyaz)` vardi.
        // ⚠️ Secili sekmenin BEYAZ cubugu DURUYOR — kaldirilan sey yalnizca
        //	sayfayi yatay kesen cizgi; secim gostergesi gitseydi hangi
        //	sekmede oldugumuz ANLASILMAZDI.
        // ⚠️ Serit yuksekligi DEGISMEZ: cizgi `Column`un AYRI bir cocuguydu
        //	ve ustteki `SizedBox(height: ...)` ona bagli DEGIL.
      ],
    );
  }

  // ⚠️ TURU 115 — `_sekmeSec` (acilir menu) SILINDI: yerini EKRANDA DURAN
  //    yatay sekme seridi aldi (Instagram/Twitter deseni). Kullanici acilir
  //    menuyu UC KEZ reddetti.

  /// Sekme degistirmenin TEK KAPISI (menuden secim + yatay kaydirma).
  ///
  /// ⚠️ Iki cagri yeri ayri ayri `setState`+`_sekmeYukle` yazsaydi biri
  ///    guncellenip oteki geride kalirdi — bu projede ALTI kez yasanan
  ///    "ayni kuralin iki kopyasi drift eder" sinifi.
  void _sekmeyeGec(ProfilSekmesi x) {
    if (x == _sekme) return;
    setState(() => _sekme = x);
    unawaited(_sekmeYukle(x));
    // ⚠️⚠️ TURU 180j — `PageController` KALKTI: cizilen icerik dogrudan
    //	`_sekme`den turetildigi icin (`_icerikAlani`) senkronlanacak
    //	ikinci bir kaydirma konumu YOK. Turu 115'in `animateToPage`
    //	cagrisi burada OLU KOD olurdu.
    _seridiKaydir();
  }

  /// Ilan tabanli sekmelerin listesi (Ilanlarim · Dolap · Taleplerim).
  ///
  /// ⚠️ Izgara DEGIL LISTE: ilanin kapagi cogu zaman yok (is ilani) ve
  ///    baslik + fiyat kare bir hucreye sigmaz.
  Widget _ilanListesi() {
    final l = _ilanOnbellek[_sekme] ?? const <Ilan>[];
    // ⚠️ TURU 180 — bos durum GONDERI sekmeleriyle AYNI dilde (daire
    //    icinde ikon + ortalanmis metin); iki farkli bos ekran dili
    //    ayni sayfada tutarsiz duruyordu.
    if (l.isEmpty) {
      return _bosDurum(_sekme, _ks.onSurface.withValues(alpha: 0.6));
    }
    // ⚠️ TURU 180j — **UST BOSLUK** (kullanici: *"is ilanlarinda ILK ILAN
    //	yukari cok dayanmis, boslugu ayarla"*). Kartin kendi dolgusu
    //	5 dp ve sekme seridinin ayiricisina yapisiyordu; 14 dp ek pay
    //	ile ilk kart nefes aliyor. Alt pay da simetrik (son kart
    //	ekranin dibine yapismasin).
    return Padding(
      padding: const EdgeInsets.only(top: 9, bottom: 14),
      child: Column(children: [for (final i in l) _ilanKarti(i)]),
    );
  }

  /// Ilan kartinin sol karesi.
  ///
  /// ⚠️⚠️ TURU 180j — **MEDYASI OLMAYAN ILANDA ISLETMENIN LOGOSU CIZILIR**
  ///	(kullanici: *"ilanlardaki resimler MARKANIN LOGOSU olacak"*).
  ///	Is ilanlarinin neredeyse hicbirinin gorseli yok ve eski hal
  ///	gri bir valiz ikonuydu — liste kimliksiz gorunuyordu.
  /// ⚠️ SIRA: ilanin KENDI medyasi > isletmenin avatari > notr ikon.
  ///	Ilanin gorseli varsa o KAZANIR; logo yalnizca BOSLUGU doldurur,
  ///	gercek ilan fotografinin yerine GECMEZ.
  /// ⚠️ `BoxFit.contain` + hafif zemin: logo cogu zaman KARE DEGIL
  ///	(turu 140'ta olculdu, burgerking 500x545) ve `cover` onu
  ///	ustten/alttan KIRPARDI.
  /// ⚠️ `kucuk: true` (thumb): kare 88 dp ve ham avatar 1600x1600
  ///	olabiliyor — tam cozunurluk liste basina ~10 MB gecici RAM
  ///	demekti (turu 91 dersi).
  Widget _ilanGorseli(Ilan i, ColorScheme scheme) {
    if (i.mediaIds.isNotEmpty) {
      return KapakGorseli(mediaIds: i.mediaIds, mediaKinds: i.mediaKinds);
    }
    final logo = _p?.avatarMediaId ?? '';
    if (logo.isNotEmpty) {
      return ColoredBox(
        color: scheme.onSurface.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: MedyaGorsel(mediaId: logo, kucuk: true, fit: BoxFit.contain),
        ),
      );
    }
    return ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.11),
      child: Icon(
        _sekme == ProfilSekmesi.isIlani
            ? LucideIcons.briefcase
            : LucideIcons.image,
        size: 26,
        color: scheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }

  /// ⚠️⚠️ TURU 180 — **ILAN KARTI** (kullanici: *"is ilanini da ekle, is
  ///	ilani detaylarini da ekle; arayuzu guzel yapmani istiyorum"*).
  ///
  /// Onceki hal duz bir `ListTile` idi: baslik + fiyat + chevron. Yeni
  /// kart menu kalemleriyle AYNI dili konusuyor (kendi zemini, 18 radus,
  /// gorsel alani) — profilde iki farkli liste dili kalmasin.
  /// ⚠️ Kapak `KapakGorseli`: ilk FOTOGRAFI secer ve yalniz-video ilanda
  ///	INDIRME YAPMADAN yer tutucu cizer (turu 83b dersi:
  ///	`mediaIds.first` video id'si olabilir ve KIRIK GORSEL cizerdi).
  /// ⚠️ Gorsel alani DAIMA cizilir: kosullu olsaydi kimi kart 88 dp kimi
  ///	0 dp olur ve liste ZIPLARDI.
  Widget _ilanKarti(Ilan i) {
    final scheme = _ks;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => IlanDetayEkrani(ilan: i)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: _ilanGorseli(i, scheme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.baslik,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i.fiyatEtiketi,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ⚠️ Konum VARSA cizilir: bos bir satir kart
                      //    yuksekligini bosuna buyuturdu.
                      if (i.ilce.isNotEmpty || i.il.isNotEmpty)
                        Row(
                          children: [
                            // ⚠️ TURU 180j — `mapPin` -> **`navigation`**
                            //	(kullanici: *"konumlar NAVIGATOR KONUM
                            //	olacak"*). Ayni ikon haritadaki kendi
                            //	konum gostergemizde de kullaniliyor,
                            //	yani uygulama genelinde TEK dil.
                            Icon(
                              LucideIcons.navigation,
                              size: 13,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                [i.ilce, i.il]
                                    .where((x) => x.isNotEmpty)
                                    .join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          // ⚠️⚠️ TURU 180h — **REELS, REELS TARZINDA ACILIR** (kullanici:
          //	*"reels videolari GONDERI GIBI aciliyor, reels video
          //	tarzinda acilmasi gerekiyor"*). Tam ekran, dikey
          //	kaydirmali oynatici; digerleri gonderi detayi.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => g.tur == 'reels'
                  ? ReelsSayfasi(baslangic: g)
                  : GonderiDetay(gonderi: g),
            ),
          ),
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
                        // ⚠️ TURU 178 — popup (bkz. `randevuAlAc`).
                        onPressed: () => randevuAlAc(
                          context,
                          isletmeId: widget.userId,
                          isletmeAd: widget.ad,
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
            ],
          ),
        ),
      ),
    );
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

/// ⚠️⚠️ TURU 180 — **HEADER IKONLARININ ARKASINDA BLUR DAIRE** (kullanici:
///	*"geri, soru isareti ve sagdaki menu arkasina blur daire
///	yap"*).
///
/// ⚠️ **GEREKCE SUS DEGIL OKUNABILIRLIK**: header `extendBodyBehindAppBar`
///	ile KAPAK FOTOGRAFININ uzerinde duruyor ve fotograf her
///	renkte olabilir. Beyaz bir ikon acik gokyuzunde ya da beyaz
///	bir tabelada KAYBOLUR (McDonald's kapaginda tam bu yasandi).
///
/// ⚠️ `ClipOval` ZORUNLU: `BackdropFilter` kirpilmazsa bulaniklik TUM
///	ekrana yayilir (Flutter'da bilinen tuzak — filtre kendi
///	sinirini CIZMEZ).
/// ⚠️ Bulanik katmanin USTUNE hafif bir siyah dolgu konur: yalniz blur,
///	acik bir zeminde beyaz ikonu HALA gorunmez birakirdi.
class _BlurDaire extends StatelessWidget {
  const _BlurDaire({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            // ⚠️ TURU 180d 36 -> 42, TURU 180g 42 -> **48** (kullanici iki
            //    kez *"blur daireleri bir tik daha buyut"* dedi).
            // ⚠️⚠️ Dokunma kutulari da 44 -> **52**: kutu 44'te kalsaydi
            //	daire KIRPILIRDI (`ClipOval` kutuya sigar).
            width: 48,
            height: 48,
            alignment: Alignment.center,
            color: Colors.black.withValues(alpha: 0.28),
            child: child,
          ),
        ),
      );
}

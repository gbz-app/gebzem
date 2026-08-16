import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (sistem cubugu)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart'
    show kAltMenuZemin, kAltMenuAktifIkon, kAltMenuPasifIkon;
import '../chats/chats_provider.dart';
import '../medya/medya_gorsel.dart';
import '../sosyal/hizmet_menusu.dart' show hizmetMenusuAc;
import 'home_screen.dart' show myProfileProvider;

/// ⚠️ Cubuk yuksekligi (guvenli alanin USTUNDE). Tum hucrelerin dokunma
///    hedefi bu yukseklige ESITTIR (Material asgari 48 dp fazlasiyla saglanir).
const double kAltMenuBoy = 66;

/// ⚠️⚠️ TURU 96m — IKONLAR **BU KADAR YUKARI** cekilir (kullanici emri:
///	*"iconu yukari kaldir biraz daha"*).
///
/// ⚠️ Kaldirma `padding` ile DEGIL `Transform.translate` ile yapilir: dolguyla
///    yapilsaydi cocuga kalan yukseklik azalir ve logo (52) ile cubuk (66)
///    arasindaki pay eriyip **RenderFlex tasmasi** riski dogardi. Ceviri bir
///    CIZIM donusumudur, yerlesimi daraltmaz.
const double kAltMenuIkonKaldir = 5;

/// Ikon boyu (NOMINAL taban).
/// ⚠️ TURU 96o — kullanici emri *"ikonlari 2px daha buyut"*: 24 -> **26**.
/// ⚠️ Bazi ikonlar bundan SAPAR: bkz. `_ikonBoy` (optik denge).
const double kAltMenuIkonBoy = 26;

/// ⚠️⚠️ ORTADAKI LOGO DAIRESI. Kullanici *"daire 5px daha buyut, logoyu da o
///	oranda buyut"* dedi (logo daireyi TAM doldurdugu icin ikisi birlikte
///	buyur): 47 -> **52**.
const double kAltMenuLogoCap = 52;

/// ⚠️⚠️⚠️ TURU 96n — LOGONUN IKI YANINDAKI **NEFES PAYI** (kullanici:
///	*"ikonlar ortadaki menuye cok yaklasmis"*). Yer tutucu hucrenin
///	genisligi `kAltMenuLogoCap + kAltMenuLogoBosluk`tur.
///
/// ⚠️⚠️ Logo yer tutucusunun EK payi. Bu sayi 6 esnek hucreden calindigi icin
///	**ikonlarin ARASINI da belirler**: buyudukce hucreler daralir, ikonlar
///	birbirine YAKLASIR.
///	Gecmis: 12 -> 32 -> 60 (*"cok yapisik"* -> GERI AL) -> 12 ->
///	**30** (kullanici: *"aralarindaki boslugu 1 tik daha azalt"*).
///	411 dp'de hucre 57.0 -> **52.0**.
/// ⚠️ 360 dp'de hucre 41.3 dp'ye iner; daha fazlasi dokunma hedefini
///    kullanilamaz yapar (muhafiz testi 360 dp'de olcer).
const double kAltMenuLogoBosluk = 30;

/// ⚠️⚠️⚠️ TURU 96p — LOGO KALDIRMASI **CUBUGUN ICINDE KALACAK KADAR**.
///
///	Istenen 10 dp'ydi (ikonlarin 5'i + 10). AMA 96o'da bunu saglamak icin
///	logonun cubugun USTUNE tasmasina izin verilmis, tasan pay da cubugun
///	ustune SAYDAM bir serit olarak eklenmisti. Kullanici bunu sahada gordu:
///	*"alt menu ustunde 5-10px bir alan var, kesit gibi"*. Ardindan cubuk
///	komple siyaha boyanip yuvarlak koseleri kaldirilinca da haklı olarak
///	*"radius nerede, yuksekligi neden artirdin"* dedi.
///
///	**KARAR: cubuk 66 dp ve YUVARLAK KOSELI kalir; logo DISARI TASMAZ.**
///	Bu, kaldirmayi geometrik olarak sinirlar:
///	  `(kAltMenuBoy - kAltMenuLogoCap) / 2` = (66 - 52) / 2 = **7 dp**
///	Deger `min` ile TURETILIR — logo ya da cubuk boyu degisirse kendiliginden
///	uyar ve **kirpilma/tasma YAPISAL OLARAK imkansiz** olur.
/// ⚠️ Daha fazla kaldirma isteniyorsa tek yol logoyu KUCULTMEK ya da cubugu
///    UZATMAK; ikisi de kullaniciya sorulmadan yapilmaz.
/// ⚠️⚠️⚠️ TURU 96z — kullanici *"ortadaki logoyu 10px yukari kaldir"* dedi.
///	Cubuk 66, logo 52 oldugu icin TASMADAN en fazla 7 dp kaldirilabiliyordu;
///	istenen 10 dp fazlasi ancak logonun cubuktan **TASMASIYLA** mumkun.
///
/// ⚠️⚠️ **TASMA CUBUGU UZATMAZ.** Turu 96o'da tasma payi cubugun ustune
///	SAYDAM BIR SERIT olarak eklenmisti ve kullanici bunu *"kesit gibi bir
///	alan"* diye bildirdi. Bu kez cubuk 66 dp ve YUVARLAK KOSELI kalir;
///	logo yalnizca `ClipRRect`in DISINDA cizilerek yukari TASAR.
/// ⚠️ Bedeli: tasan ~10 dp GORUNUR ama TIKLANMAZ (Flutter ebeveyn kutusunun
///    disini hit-test etmez). Logonun kalan ~42 dp'si dokunma hedefi olarak
///    fazlasiyla yeterli (Material asgari 48 dp'ye yakin).
const double kAltMenuLogoKaldir = kAltMenuIkonKaldir + 12;

/// Alt menu — **3 sol · LOGO · 3 sag**.
///
/// ⚠️⚠️⚠️ TURU 96l — `home_screen` ICINDEN BURAYA TASINDI (TEK KAYNAK).
///	Kullanici kategori ekraninda da alt menuyu istedi (*"alt menuyu getir,
///	alt menu gorunmesi gerekiyor"*). Menu `home_screen`in private bir
///	metoduydu; ikinci ekrana KOPYALANSAYDI rozet sayaci, logo davranisi ve
///	"bir tik yukarida" dolgusu birinde guncellenip otekinde geride kalirdi
///	— bu projede "ayni kuralin iki kopyasi drift eder" sinifi ALTI kez
///	sahaya cikti.
///
/// ⚠️⚠️⚠️ TURU 96m — **ETIKETLER KALDIRILDI** (kullanici emri: *"iconlardaki
///	anasayfa vb alt yazi olmayacak"*). Metin YALNIZCA ekrandan kalkti,
///	`Semantics(label:)` olarak **DURUYOR**: gorunur etiketi olmayan bir
///	ikon ekran okuyucuda "dugme" diye okunur ve TalkBack kullanicisi hangi
///	sekmede oldugunu ANLAYAMAZ.
/// ⚠️ YAPMA: `etiket` parametresini "kullanilmiyor" diye silme — a11y'nin
///    TEK kaynagi odur.
///
/// ⚠️ [secili] `null` ise HICBIR oge secili cizilmez: kategori ekrani bir
///	sekme DEGILDIR, uzerine PUSH edilmis bir route'tur. Orada "Anasayfa"yi
///	secili gostermek kullaniciya YALAN soylerdi.
/// ⚠️ Sekme INDEKSLERI (0..5) DEGISMEZ: `aktifSekme` ve akistaki videolarin
///    ses guvenligi kapisi bunlara bagli (bkz. `home_screen` serhi).
class AltMenu extends ConsumerWidget {
  const AltMenu({super.key, required this.secili, required this.onSec});

  /// Secili sekme; `null` = bu ekran bir sekme degil.
  final int? secili;
  final void Function(int sira) onSec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final okunmamis = ref
            .watch(chatsProvider)
            .valueOrNull
            ?.where((c) => !c.archived)
            .fold<int>(0, (a, c) => a + c.unread) ??
        0;
    // ⚠️⚠️⚠️ TURU 96m — SISTEM GEZINME CUBUGU (alttaki "pill") IKONLARI ACIK.
    //
    //	Cubuk siyaha cevrilince Android'in kendi cizdigi gezinme cizgisi ACIK
    //	temada KOYU kaliyor ve siyah serit uzerinde **GORUNMEZ** oluyordu —
    //	yani bu satir kozmetik degil, degisikligin GEREKTIRDIGI kapatma.
    //
    // ⚠️ Flutter sistem stilini ekranin **EN UST** ve **EN ALT** noktasindaki
    //    `AnnotatedRegion`lardan ayri ayri okur (`RendererBinding
    //    ._updateSystemChrome`): buradaki deger yalniz GEZINME cubugu
    //    alanlarini etkiler, durum cubugu `main.dart`taki uygulama geneli
    //    varsayilandan gelmeye DEVAM eder (turu 85c).
    // ⚠️ YAPMA: buraya `statusBar*` alanlari ekleme — yaprak annotation
    //    kazanir ve koyu/acik tema mantigini SESSIZCE ezersin.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: kAltMenuZemin,
        systemNavigationBarDividerColor: kAltMenuZemin,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      // ⚠️⚠️⚠️ TURU 96p — **CUBUK: 66 dp + UST KOSELERDE 20 RADIUS.** Ikisi de
      //	KULLANICI ISTEGI ve degistirilmez.
      //
      //	96o'da bu ikisi de bozulmustu: logonun tasmasina izin vermek icin
      //	cubuk UZATILMIS, "kenarlik olmasin" cumlesi de YANLIS anlasilip
      //	**radius kaldirilmisti**. Kullanici ikisini de sordu:
      //	*"radius nerede, yuksekligi neden artirdin anlamadim"* ve
      //	netlestirdi: *"sadece alt menude border vb kalinlik olmayacak"*.
      //
      // ⚠️ "Kenarlik yok" demek **`Border`/`BoxShadow`/ayirici cizgi yok**
      //    demektir; RADIUS bir kenarlik DEGILDIR.
      // ⚠️ YAPMA: buraya `Border`, `BoxShadow`, `Divider` ya da ust cizgi
      //    ekleme; radius'u kaldirma; yuksekligi degistirme.
      // ⚠️ TURU 96z — logo `ClipRRect`in DISINDA (yukari tasabilsin diye);
      //    `clipBehavior: Clip.none` ZORUNLU, yoksa Stack tasan kismi keser.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
        ClipRRect(
        // ALT MENU sol/sag (ust kose) RADIUS (test turu 7).
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: ColoredBox(
          // ⚠️ TURU 96m — zemin TEMADAN DEGIL sabit siyah (`theme.dart`).
          color: kAltMenuZemin,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: kAltMenuBoy,
              // ⚠️ TURU 96z — logo ARTIK BURADA DEGIL: cubugun ustune tastigi
              //    icin `ClipRRect`in DISINDAKI dis `Stack`te ciziliyor.
              //    Burada yalnizca YER TUTUCUSU var (asagida).
              child: Row(
                // ⚠️ `stretch`: her hucre cubugun TAM YUKSEKLIGINI kaplar,
                //    yani dokunma hedefi ikon degil HUCRENIN TAMAMIDIR.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _oge(0, LucideIcons.house, 'Anasayfa'),
                  _oge(1, LucideIcons.search, 'Ara'),
                  _oge(2, LucideIcons.clapperboard, 'Reels'),
                  // ⚠️ Logonun YERI: govdesi dis Stack'te cizilir, burada
                  //    yalnizca YER TUTAR. Bu sayede "3 sol · logo · 3 sag"
                  //    simetrisi bozulmaz.
                  //
                  // ⚠️⚠️⚠️ TURU 98c — YER TUTUCU **ARTIK DOKUNMA HEDEFI**
                  //	(emulatorde OLCULDU, gercek hata):
                  //	logonun cubuktan tasan ~10 dp'lik ust seridi Flutter
                  //	tarafindan hit-test EDILMEZ (ebeveyn kutusunun disi) ve
                  //	dokunus **ALTTAKI AKISA** duser. Kor bir dokunusta
                  //	gonderinin "Paylaş" sayfasi acildi — yani logonun ust
                  //	kenarina basan kullanici RASTGELE bir akis eylemi
                  //	tetikliyordu.
                  //	Cubugun ICINDEKI bu hucre de ayni menuyu actigi icin
                  //	hedef 42 dp'den **66 dp'ye** cikar ve isabetsiz dokunus
                  //	pratikte kalmaz.
                  // ⚠️ Tasan serit HALA tiklanmaz; onu tiklatmanin tek yolu
                  //    cubugu uzatmak ya da logoyu kucultmekti — kullanici
                  //    IKISINI DE acikca reddetti (96p/96z).
                  // ⚠️ YAPMA: burayi tekrar duz `SizedBox` yapma.
                  SizedBox(
                    width: kAltMenuLogoCap + kAltMenuLogoBosluk,
                    child: Semantics(
                      button: true,
                      label: 'Menü',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => hizmetMenusuAc(context),
                      ),
                    ),
                  ),
                  // ⚠️ OKUNMAMIS ROZETI: mesaj sekmesi alt menude ve kullanici
                  //    surekli akista/reels'te olacagi icin rozet OLMADAN yeni
                  //    mesaji HIC fark etmezdi.
                  _oge(3, LucideIcons.messageCircle, 'Mesaj',
                      rozet: okunmamis),
                  _oge(4, LucideIcons.radio, 'Canlı'),
                  _profil(),
                ],
              ),
            ),
          ),
        ),
        ),
        // ⚠️⚠️⚠️ TURU 96z — LOGO **CUBUGUN USTUNE TASAR** ve bu yuzden
        //	`ClipRRect`in DISINDA, dis `Stack`te cizilir.
        //
        // ⚠️ Konum ELLE YAZILMAZ, TURETILIR: cubugun dikey ortasi eksi
        //    logonun yarisi eksi kaldirma. Sabitlerden biri degisirse
        //    kendiliginden uyar.
        // ⚠️ `left/right: 0` + `Center`: Row'daki yer tutucu da tam ortada
        //    oldugu icin ikisi cakisir.
        Positioned(
          left: 0,
          right: 0,
          top: kAltMenuBoy / 2 - kAltMenuLogoCap / 2 - kAltMenuLogoKaldir,
          child: Center(child: _logo(context)),
        ),
        ],
      ),
    );
  }

  /// Bir menu hucresi: tam yukseklikte dokunma hedefi + yukari cekilmis icerik.
  ///
  /// ⚠️ **DALGA YOK** (`GestureDetector`): kullanici "tikladiginda titreme
  ///    olmasin" dedi ve bu kural tum uygulamaya tasindi.
  Widget _hucre({
    required int sira,
    required String etiket,
    required bool aktif,
    required Widget cocuk,
  }) =>
      Expanded(
        child: Semantics(
          button: true,
          selected: aktif,
          label: etiket,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSec(sira),
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -kAltMenuIkonKaldir),
                child: cocuk,
              ),
            ),
          ),
        ),
      );

  /// Tek menu ogesi.
  ///
  /// ⚠️ Secili/secili degil ayrimi **RENKLE**: aktif beyaz, pasif gri
  ///    (kullanici emri). Boyut DEGISMEZ — buyuyup kuculen ikon satiri
  ///    oynatir ve goz bunu titreme olarak okur.
  Widget _oge(int sira, IconData ikon, String etiket, {int rozet = 0}) {
    final aktif = secili == sira;
    final renk = aktif ? kAltMenuAktifIkon : kAltMenuPasifIkon;
    final boy = _ikonBoy(ikon);
    return _hucre(
      sira: sira,
      etiket: etiket,
      aktif: aktif,
      cocuk: rozet > 0
          ? _RozetliIkon(ikon: ikon, sayi: rozet, renk: renk, boy: boy)
          : Icon(ikon, size: boy, color: renk),
    );
  }

  /// ⚠️⚠️⚠️ TURU 96n — **OPTIK BOY** (kullanici: *"canli yayin ikonu kucuk
  ///	kalmis, onu da buyut biraz"*).
  ///
  ///	`size` ikonun CIZILEN murekkebini degil **SINIR KUTUSUNU** olcer.
  ///	Lucide `radio` ikonu iki yana acilan yaylardan olusur ve **dikeyde
  ///	kisadir**; ayni `size` degerinde goz onu kardeslerinden KUCUK gorur.
  ///	Kullanici olculeri degil GORUNTUYU okur, dolayisiyla haklidir.
  ///
  /// ⚠️ Bu, turu 82'nin *"ESIT OLCU ESIT GORUNUM DEMEK DEGIL"* dersinin ayni
  ///    uygulamasidir (`gonderi_karti._optikBoy`). Iki harita BILEREK ayri:
  ///    farkli ikon kumesi + farkli nominal taban (24 vs 23); ortak bir
  ///    "global ikon boyu kaydi" iki cubugu birbirine baglar ve birinde
  ///    yapilan ayar otekini SESSIZCE bozardi.
  /// ⚠️ Cubuga yeni ikon eklersen buraya bakmayi UNUTMA; haritada olmayan
  ///    ikon `kAltMenuIkonBoy`a duser (guvenli varsayilan).
  double _ikonBoy(IconData ikon) {
    // ⚠️ 24 -> 28 -> **31**: kullanici 28'i de kucuk buldu ("1 tik daha
    //    buyut"). Olculdu: 24'te murekkep 22.6x16.0 dp, 28'de 25.1x18.7 dp —
    //    yani kardeslerinin (~19.8 dikey) HALA altindaydi. 31'de dikey
    //    murekkep ~20.7 dp ile hizalanir.
    if (ikon == LucideIcons.radio) return 33;
    return kAltMenuIkonBoy;
  }

  /// Profil sekmesi (sira 5).
  ///
  /// ⚠️⚠️ TURU 96m — **FOTOGRAF YOKSA HARF YAZILMAZ** (kullanici emri: *"profilde
  ///	a vb yazmasin, eger resim yoksa o da pasif icon renginde olsun"*).
  ///	`Avatar` fotograf yokken `CircleAvatar` + BAS HARF cizer; alt menude bu
  ///	hem etiketleri kaldirdigimiz "yazisiz" dile aykiriydi hem de tema
  ///	renginde bir daire oldugu icin siyah seritte YAMA gibi duruyordu.
  ///	Fotografsiz kullanici artik diger sekmelerle AYNI dilde bir ikon gorur.
  Widget _profil() => _hucre(
        sira: 5,
        etiket: 'Profil',
        aktif: secili == 5,
        cocuk: _ProfilIkonu(secili: secili == 5),
      );

  /// ⚠️⚠️⚠️ TURU 96n — LOGO **OLDUGU GIBI** cizilir (kullanici emri, IKI KEZ
  ///	tekrarlandi: *"sana verdigim logoyu aynen koy, daire yapma"* ve
  ///	*"koseleri vs bosver, dosyadaki logoyu suanki boyutu ile koy, radius
  ///	kose vs verme, 10px yukarida duracak sekilde"*).
  ///
  ///	Yani: **kirpma YOK · daire YOK · radius YOK · arka plan/kart YOK.**
  ///
  /// ⚠️⚠️ TURU 96m'DE NE OLMUSTU (bir daha denenmesin): logo 52'lik bir
  ///	`ClipOval` icine konmustu. Kullanici *"logonun koseleri sikintili"*
  ///	dedi ve HAKLIYDI — daireye kirpmak, gorselin KENDI kose sanatini
  ///	kesiyordu.
  /// ⚠️ Zaten GEREKSIZDI (olculdu): `assets/icon/logo.png` **512x512 RGBA**,
  ///    piksellerinin **%7.8'i saydam** ve kose yuvarlatmasi gorselin
  ///    **%23'u** — yani dosya ZATEN yuvarlatilmis koseli ve siyah seritte
  ///    sert kare kenar OLUSTURMAZ. Kirpmak sorunu cozmuyor, URETIYORDU.
  ///
  /// ⚠️ Logo dosyasi TEK KAYNAK: `assets/icon/logo.png`. Gorunum degisecekse
  ///    **DOSYA** degisir, buraya sekil kodu yazilmaz.
  /// ⚠️ **DAVRANIS: ANASAYFA.** Dokununca hicbir sey yapmayan bir dugme bu
  ///    projede "olu ozellik" sinifidir.
  Widget _logo(BuildContext context) => Semantics(
        button: true,
        // ⚠️ Etiket ARTIK 'Menü' (davranis degisti); 'Anasayfa' demek ekran
        //    okuyucu kullanicisina YANLIS bilgi olurdu.
        label: 'Menü',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // ⚠️⚠️ TURU 96n — DAVRANIS: **HIZMET MENUSU** (kullanici emri: *"alt
          //	menudeki logo tiklandiginda menu gelecek, anasayfada sol ustteki
          //	hamburgere tikladigin gibi"*). Onceden `onSec(0)` ile anasayfaya
          //	gidiyordu.
          // ⚠️ Sheet acma kodu BURAYA KOPYALANMADI: `hizmetMenusuAc` TEK
          //    KAYNAK (`sosyal/hizmet_menusu.dart`) — hamburger dugmesi de
          //    ayni fonksiyonu cagirir.
          onTap: () => hizmetMenusuAc(context),
          // ⚠️⚠️ TURU 96n — LOGO **5 dp KUCUK BIR DAIREYE DOLDURULUR**
          //    (kullanici emri: *"logodan 5px daha kucuk daire icine logoyu
          //    doldur"*). Yani daire 52-5 = 47 dp ve gorsel daireyi TAM
          //    doldurur (`cover`) — ic dolgu YOK.
          //
          // ⚠️⚠️⚠️ **TIRTIKLI KENAR (kullanici: "cevresinde tirtiklar
          //	olusuyor") — SEBEBI OLCEK.** Dosya 512x512; cubukta 47 dp =
          //	**123 piksel** cizilir, yani **4.2 KAT** kucultme. Flutter
          //	varsayilan olarak gorseli TAM COZUNURLUKTE cozer ve cizim
          //	aninda `FilterQuality.low` (bilineer, mipmap YOK) ile
          //	kuculturr; bu oranda bilineer ornekleme logonun ince ic
          //	halkalarinda **aliasing** uretir ve kenarlar tirtikli gorunur.
          //
          //	IKI KATMANLI COZUM (ikisi de gerekli):
          //	1. `cacheWidth/Height` — gorsel **HEDEF PIKSEL BOYUNDA
          //	   COZULUR**; kucultmeyi cizici degil KOD COZUCU yapar (dogru
          //	   filtre + daha az RAM). Turu 91'in `memCacheWidth` dersinin
          //	   asset karsiligi.
          //	2. `filterQuality: medium` — kalan olcekleme icin bilineer
          //	   yerine daha iyi filtre.
          // ⚠️ `devicePixelRatio` ILE CARPILIR; carpilmazsa gorsel bu kez
          //    BULANIK cizilir (turu 91'de birebir bu tuzak yasandi).
          // ⚠️⚠️⚠️ **KIRPMA (ClipOval) KULLANILMAZ — "TIRTIKLI KENAR"IN SEBEBI
          //	OYDU.** Kullanici iki kez *"logonun cevresinde tirtiklar
          //	olusuyor"* dedi. Olculdu: `ClipOval` ile kenarda **0 gecis
          //	pikseli** vardi, yani hicbir yumusatma yok — merdiven basamagi.
          //	Uygulama **Impeller (OpenGLES)** ile calisiyor ve kirpma yolunun
          //	kenar yumusatmasi bu boyutta gorunur sekilde kaba.
          //
          //	COZUM: daire KIRPILARAK degil **SEKIL OLARAK CIZILIR**
          //	(`BoxShape.circle` + `DecorationImage`). Boylece gorsel bir
          //	daire geometrisine SHADER olarak doldurulur ve kenar
          //	yumusatmasini GPU'nun kendi daire cizimi yapar.
          // ⚠️ YAPMA: buraya tekrar `ClipOval`/`ClipRRect` koyma.
          //
          // ⚠️ `ResizeImage` = olcek kalitesi: dosya 512x512, cizim 47 dp
          //    (~123 px) — 4 kat kucultmede kod cozucu yeniden orneklemezse
          //    ince halkalar aliasing yapar. `devicePixelRatio` ILE carpilir,
          //    yoksa bu kez BULANIK cizilir (turu 91 tuzagi).
          child: Builder(builder: (context) {
            const cap = kAltMenuLogoCap;
            final px = (cap * MediaQuery.devicePixelRatioOf(context)).round();
            return Container(
              width: cap,
              height: cap,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: ResizeImage(
                    const AssetImage('assets/icon/logo.png'),
                    width: px,
                    height: px,
                  ),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            );
          }),
        ),
      );
}

// ⚠️⚠️ TURU 96l — ASAGIDAKI IKI SINIF `home_screen.dart`tan **TASINDI**,
//    yeniden yazilmadi: govdeleri kopyalansaydi avatar cercevesi, rozet
//    rengi ve capi iki dosyada AYRI AYRI yasar ve drift ederdi.
// ⚠️ YAPMA: bunlari `home_screen`e geri kopyalama.

class _ProfilIkonu extends ConsumerWidget {
  const _ProfilIkonu({required this.secili});

  /// Secili sekmede ikon RENGI degistirilemedigi icin (avatar bir fotograf)
  /// ayrim CERCEVE ile yapilir.
  final bool secili;

  static const double _cap = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(myProfileProvider).valueOrNull;
    final mediaId = p?['avatar_media_id'] as String?;
    final url = (p?['avatar_url'] ?? '').toString();
    final fotografVar = (mediaId != null && mediaId.isNotEmpty) || url.isNotEmpty;

    // ⚠️⚠️⚠️ TURU 96n — FOTOGRAF YOKSA **DUZ DAIRE** (kullanici emri: *"sagdaki
    //	profil ikon olmayacak, oraya profil resmi gelecek, yoksa hafif gri
    //	renkte daire olsun DEDIM SANA"*).
    //
    //	Yani bu hucre bir SEKME IKONU degil, **AVATARIN YERI**: fotograf
    //	varsa fotograf, yoksa onun boslugu. Kullanici ikonu ("bir insan
    //	silueti") da harfi de REDDETTI — ikisi de "resim" gibi degil "ikon"
    //	gibi okunuyor.
    // ⚠️ Cap avatarla AYNI (`_cap`): fotografi olan ile olmayan kullanici
    //    arasinda daire boyu OYNAMAZ, satir titremez.
    // ⚠️ Renk kardes sekmelerle AYNI kaynaktan (aktif beyaz / pasif gri).
    // ⚠️ YAPMA: buraya tekrar `Icon` veya bas harf koyma.
    if (!fotografVar) {
      return Container(
        width: _cap,
        height: _cap,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: secili ? kAltMenuAktifIkon : kAltMenuPasifIkon,
        ),
      );
    }

    final avatar = Avatar(
      ad: (p?['name'] ?? '').toString(),
      mediaId: mediaId,
      avatarUrl: url,
      cap: _cap,
    );
    // ⚠️ Pasifken fotograf SOLDURULUR: renk veremedigimiz tek oge budur, o
    //    yuzden "pasif" hissi opaklikla verilir (siyah zemine karisir).
    if (!secili) return Opacity(opacity: 0.55, child: avatar);
    // ⚠️ Cerceve DISARIDAN cizilir (avatarin capini KUCULTMEZ): `Container`in
    //    kendi kenarligi cocugu iceri iterdi ve secili/secili-degil arasinda
    //    fotograf boyutu OYNAR, alt menu titrerdi.
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // ⚠️ Cerceve de AKTIF IKON RENGI (beyaz): tema `primary`si siyah
        //    seritte diger aktif ikonlarla ayni dili konusmuyordu.
        border: Border.all(color: kAltMenuAktifIkon, width: 2),
      ),
      child: Padding(padding: const EdgeInsets.all(1.5), child: avatar),
    );
  }
}

class _RozetliIkon extends StatelessWidget {
  const _RozetliIkon({
    required this.ikon,
    required this.sayi,
    required this.renk,
    required this.boy,
  });

  final IconData ikon;
  final int sayi;

  /// ⚠️ Boy DISARIDAN gelir (`_ikonBoy`): burada sabit yazilsaydi optik
  ///    ayarlar yalniz ROZETSIZ ikonlara uygulanirdi.
  final double boy;

  /// ⚠️ TURU 96m — renk ARTIK ZORUNLU PARAMETRE. Onceden `Icon(ikon)` ambient
  ///    `IconTheme`den beslenirdi; cubuk siyaha cevrilince o renk (acik temada
  ///    KOYU) siyah zeminde GORUNMEZ olurdu.
  final Color renk;

  @override
  Widget build(BuildContext context) {
    final ikonu = Icon(ikon, size: boy, color: renk);
    if (sayi <= 0) return ikonu;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ikonu,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 17),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              sayi > 99 ? '99+' : '$sayi',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

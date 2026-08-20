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
/// ⚠️⚠️⚠️ TURU 112b — **ILK UYGULAMA TERSTI (olculdu).**
///
///	Kullanici *"mevcut logo 2px daha buyut"* dedi. Ilk denemede DIS cap
///	52 -> 54 yapildi ama iceriye 2 dp halka dolgusu kondu; sonuc: GORUNEN
///	logo 52 -> **50 dp KUCULDU**. Daire buyudu, logo kuculdu — istenenin
///	TAM TERSI.
///
///	Dogrusu: gorunen logo () 54 olmali, yani dis cap
///	54 + 2*halka = **58**.
/// ⚠️ Geometri elle dogrulandi: alttan tasma YOK (29 + 29 = 58 <= 66) ·
///    360 dp'de hucre 45.3 dp (>= 40) · 411 dp'de logo-komsu boslugu 28.9
///    (>= 16). Bedel: hit-test ALMAYAN ust serit 11 -> 13 dp.
/// ⚠️ YAPMA: halkayi buyuterek "daha gradient" yapmaya calisma — gorunen
///    logo yine kuculur; gerekirse CAP da birlikte buyutulur.
/// ⚠️⚠️ TURU 116 — **BU SERH DUZELTILDI.** Eskiden *"kaldirma payi bu
///	sayidan TURETILIYOR ... tasma yapisal olarak imkansiz"* diyordu.
///	GOVDEDE OYLE BIR TURETME YOK: `kAltMenuLogoKaldir` duz bir sabittir
///	(`kAltMenuIkonKaldir + 12` = **17 dp**). `min(...)` govdede turu
///	96z'de SILINDI; `dart:math` bu dosyaya import bile EDILMIYOR.
///	Ust tasma **KASITLIDIR** (13 dp) ve sinirini `alt_menu_test.dart`
///	cizer — serh degil, TEST.
const double kAltMenuLogoCap = 58;

/// ⚠️⚠️ TURU 112 — GRADIENT HALKANIN KALINLIGI.
///
/// ⚠️ Halka DISARIYA eklenmez, ICERIDEN alinir: dis cap
///    `kAltMenuLogoCap` OLARAK KALIR. Buyuseydi logo cubuktan DAHA COK
///    tasardi — tasan kisim hit-test ALMAZ (turu 98c) ve kor dokunuslar
///    ALTTAKI akisa duserdi.
///    ⚠️ TURU 116: burada eskiden `min(15, (kAltMenuBoy - cap) / 2)`
///       yaziyordu; o hesap govdede YOK (bkz. `kAltMenuLogoKaldir`).
const double kAltMenuLogoHalka = 2;

/// Gorselin cizildigi IC daire.
const double kAltMenuLogoIcCap = kAltMenuLogoCap - kAltMenuLogoHalka * 2;

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
///	  `(kAltMenuBoy - kAltMenuLogoCap) / 2` = (66 - 58) / 2 = **4 dp**
///	⚠️⚠️ TURU 116 — burada eskiden *"(66 - 52) / 2 = 7 dp"* ve *"deger
///	   `min` ile TURETILIR ... tasma YAPISAL OLARAK imkansiz"* yaziyordu.
///	   IKISI DE YANLIS: cap turu 112'de 52 -> **58** oldu ve `min(...)`
///	   govdeden turu 96z'de SILINDI. Bugun kaldirma SABIT 17 dp, yani
///	   tasma imkansiz DEGIL — **KASITLI** (asagi bak).
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
/// ⚠️ Bedeli: tasan kisim GORUNUR ama TIKLANMAZ (Flutter ebeveyn kutusunun
///    disini hit-test etmez).
///    OLCUM (turu 116, sabitlerden turetildi — elle sayi YAZILMADI):
///      kaldirma 17 dp · tasmasiz tavan 4 dp -> **ust tasma 13 dp**
///      cubuk icinde kalan **45 dp** (dokunma hedefi; Material 48'e yakin)
///    ⚠️ Eski serh "tasan ~10 / kalan ~42" diyordu — cap 52 iken dogruydu.
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
    final okunmamis =
        ref
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
      // ⚠️⚠️⚠️ TURU 98h — KOSELERDE **BEYAZLIK** (kullanici sahada gordu:
      //	*"alt menude beyazliklar var, radusun yaninda sayfa gecislerinde
      //	gorunuyor"*).
      //
      //	Cubugun ust koseleri 20 dp yuvarlak; o iki ucgen alan SAYDAM
      //	kalir ve ARKASINDAKI ne varsa gorunur. Route gecisi sirasinda
      //	arkada gelen sayfa BEYAZ oldugu icin koselerde beyaz parlamalar
      //	cikiyordu.
      // ⚠️ COZUM: cubugun ARKASINA uygulama zemini boyanir; boylece kose
      //    ucgenleri gecis boyunca da uygulama zemini rengindedir.
      // ⚠️ Radius KALDIRILMADI (kullanici emri, turu 96p).
      // ⚠️⚠️⚠️ TURU 98n — KOSELERDEKI BEYAZLIK **IKINCI KEZ**.
      //
      //	98hde koselerin arkasina `scaffoldBackgroundColor` boyanmisti.
      //	O renk TEMA seviyesindedir (acik gri); Reels/canli gibi KENDI
      //	SIYAH zeminini boyayan ekranlarda kose ucgenleri **BEYAZ CENTIK**
      //	gibi cikti (kullanici sahada gordu).
      //
      // ⚠️ DOGRUSU **HICBIR SEY BOYAMAMAK**: `Scaffold` kendi zeminini
      //	`bottomNavigationBar`IN ARKASINA DA cizer. Saydam birakinca kose
      //	ucgeni her ekranda O EKRANIN gercek zemin rengini gosterir —
      //	acik ekranda acik, siyah ekranda siyah.
      // ⚠️ YAPMA: buraya tekrar sabit/tema rengi koyma.
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
                      //	logonun cubuktan tasan ust seridi (13 dp) Flutter
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
                      _oge(
                        3,
                        LucideIcons.messageCircle,
                        'Mesaj',
                        rozet: okunmamis,
                      ),
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
  }) => Expanded(
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
  /// ⚠️ Zaten GEREKSIZDI (o gunku dosya olculmustu): logo yuvarlatilmis
  ///    koseliydi ve siyah seritte sert kare kenar OLUSTURMUYORDU.
  ///    Kirpmak sorunu cozmuyor, URETIYORDU.
  ///
  /// ⚠️⚠️ TURU 116 — **LOGO DEGISTI, YUKARIDAKI OLCUM BAYATLADI.**
  ///	Kullanici yeni bir logo verdi (`logo2.png`, 1600x1600) ve
  ///	`assets/icon/logo.png` ondan uretildi (`tool/logo_uret.dart`).
  ///	YENI OLCUM (araç bastı, tahmin degil):
  ///	  · 512x512 **RGBA** (alfa KORUNDU)
  ///	  · saydam piksel **%21.3** — mukemmel ic-teget dairenin teorik
  ///	    degeri %21.46, yani gorsel bir **TAM DAIRE**
  ///	  · kenar dolgusu **sol=0 ust=0 sag=0 alt=0**
  ///	  · orta satirda opak genislik **512/512 px**
  ///
  /// ⚠️⚠️ **KENAR DOLGUSU SIFIR OLMAK ZORUNDA.** Asagidaki cizim
  ///	`BoxDecoration(shape: circle)` + `BoxFit.cover` kullaniyor: kare
  ///	gorsel `kAltMenuLogoIcCap` (54 dp) kutuya oturur ve DAIRESEL
  ///	kirpilir. Kaynaktaki daire
  ///	kanvasa ic-teget DEGILSE (kenarda saydam dolgu varsa) ekranda
  ///	logonun cevresinde **BOSLUK HALKASI** olusur ve logo kardeslerinden
  ///	KUCUK gorunur. `tool/logo_uret.dart` bu dolguyu OLCER ve sifir
  ///	degilse UYARIR — logo degistirilirken o uyariya bak.
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
      // ⚠️⚠️ TURU 96n — logo bir DAIREYE DOLDURULUR (kullanici emri:
      //    *"logodan 5px daha kucuk daire icine logoyu doldur"*); gorsel
      //    daireyi TAM doldurur (`cover`) — ic dolgu YOK.
      // ⚠️ TURU 116: eski serh "daire 52-5 = **47 dp**" diyordu. Bugunku
      //    gercek: dis cap `kAltMenuLogoCap` = 58, halka 2 dp ICERIDEN
      //    alindigi icin gorselin kutusu `kAltMenuLogoIcCap` = **54 dp**.
      //    ⚠️ Sayiyi tekrar ELLE yazma — SABITIN ADINI yaz, yoksa bir
      //       sonraki olcu degisiminde yine bayatlar.
      //
      // ⚠️⚠️ **TIRTIKLI KENAR (kullanici: "cevresinde tirtiklar
      //	olusuyor")** — dosya 512x512, gorsel `kAltMenuLogoIcCap` (54 dp)
      //	kutuya cizilir; dpr 3'te **162 px**, yani ~**3,2 kat** kucultme
      //	(dpr 2'de 108 px / 4,7 kat). Flutter
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
      // ⚠️⚠️⚠️ TURU 116 — **BU BLOKTAKI TEORI YANLISTI, DUZELTILDI.**
      //	Eskiden *"daire KIRPILARAK degil SEKIL OLARAK cizilir; kenar
      //	yumusatmasini GPU'nun kendi daire cizimi yapar"* deniyordu.
      //	**Flutter SDK kaynagi bunu CURUTUYOR:**
      //	  `box_decoration.dart` -> `Path()..addOval(rect)`
      //	  `decoration_image.dart` -> `canvas.clipPath(..., AA)`
      //	Yani `BoxShape.circle` + `DecorationImage` ile `ClipOval`
      //	**AYNI ILKELI** ve ayni anti-alias yolunu kullanir. Ortada bir
      //	"shader dolgusu" YOK.
      //
      //	⚠️⚠️ "TIRTIK"IN GERCEK KOK NEDENI **EMULATOR OLCEGI**: CLAUDE.md
      //	turu 96n dort ayri denemeyi (cacheWidth+medium ·
      //	antiAliasWithSaveLayer · kirpmayi kaldirma · Skia ile derleme)
      //	**piksel piksel AYNI** buldu ve kullanici telefonda tirtik
      //	OLMADIGINI dogruladi.
      // ⚠️ `ClipOval` YINE DE KULLANILMAZ — ama sebebi anti-alias degil:
      //    fazladan bir katman + hit-test yuzeyi eklemesi. Mevcut yazim
      //    ayni sonucu tek kutuda verir.
      //
      // ⚠️ `ResizeImage` = olcek kalitesi: dosya 512x512, cizim
      //    `kAltMenuLogoIcCap` (54 dp) — kod cozucu yeniden orneklemezse
      //    ince kenarlar aliasing yapar. `devicePixelRatio` ILE carpilir,
      //    yoksa bu kez BULANIK cizilir (turu 91 tuzagi).
      child: Builder(
        builder: (context) {
          const cap = kAltMenuLogoCap;
          // ⚠️⚠️ TURU 116 — COZUNURLUK **IC** CAPTAN TURETILIR.
          //	Gorseli tasiyan ic `Container` (asagida) ebeveynin
          //	`padding: all(kAltMenuLogoHalka)` payi yuzunden
          //	`kAltMenuLogoIcCap` (54 dp) kisiti alir — DIS cap (58) degil.
          //	`px` dis captan turetiliyordu: dpr 3'te 174 px cozulup
          //	162 px'e ciziliyordu (piksel olarak ~%15 fazla is).
          //	Kok: turu 112 halkayi ICERIDEN alip ic kutuyu ekledi, bu
          //	satira dokunmadi — artik koddu.
          // ⚠️ Yon GUVENLIYDI (fazla ornekleme, bulaniklik DEGIL); yine de
          //    dogrusu ic cap. ⚠️ `kAltMenuLogoIcCap` bu satirdan ONCE
          //    govdede HICBIR YERDEN okunmuyordu (yalniz testte).
          final px =
              (kAltMenuLogoIcCap * MediaQuery.devicePixelRatioOf(context))
                  .round();
          // ⚠️⚠️⚠️ TURU 112 — **TURUNCU-MORUMSU GRADIENT HALKA** (kullanici
          //	emri: *"alt menuyu turuncu morumsu daire yap ... o daireyi
          //	boyle istedigim tarzda gradient bir renk olarak yap"*).
          //
          // ⚠️⚠️ HALKA **DISARIYA** eklenmez, ICERIDEN alinir: dis cap
          //	`kAltMenuLogoCap` OLARAK KALIR. Cap buyuseydi logo cubuktan
          //	DAHA COK tasardi (turu 98c: tasan kisim hit-test ALMAZ ve kor
          //	dokunuslar ALTTAKI akisa duserdi).
          //	⚠️ TURU 116: burada eskiden `min(15, (66 - cap) / 2)` yaziyordu;
          //	   o hesap govdede YOK (turu 96z'de silindi). Kaldirma SABIT.
          // ⚠️ Renkler SABIT (tema-bagimsiz): alt menu zemini de sabit
          //    siyah; temadan boyanirsa acik temada halka kaybolur
          //    (turu 96m dersi).
          const halka = kAltMenuLogoHalka;
          return Container(
            width: cap,
            height: cap,
            padding: const EdgeInsets.all(halka),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF9A3C), // turuncu
                  Color(0xFFFF5E7A), // pembe gecis
                  Color(0xFF8B3FFF), // mor
                ],
              ),
            ),
            // ⚠️ `Container` (DecoratedBox DEGIL): muhafiz
            //    (`alt_menu_test.dart`) gorseli tasiyan kutuyu
            //    `Container` + `BoxDecoration.image` ile buluyor.
            child: Container(
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
            ),
          );
        },
      ),
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
    final fotografVar =
        (mediaId != null && mediaId.isNotEmpty) || url.isNotEmpty;

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

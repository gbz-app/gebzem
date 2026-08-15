import 'dart:math' as math;

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

/// Ikon boyu (NOMINAL taban) — `theme.dart`taki `navigationBarTheme` ile AYNI.
/// ⚠️ Bazi ikonlar bundan SAPAR: bkz. `_ikonBoy` (optik denge).
const double kAltMenuIkonBoy = 24;

/// ⚠️⚠️ ORTADAKI LOGO (kullanici emri: *"bir tik daha buyuk"*): 48 -> **52**.
const double kAltMenuLogoCap = 52;

/// ⚠️⚠️⚠️ TURU 96n — LOGONUN IKI YANINDAKI **NEFES PAYI** (kullanici:
///	*"ikonlar ortadaki menuye cok yaklasmis"*). Yer tutucu hucrenin
///	genisligi `kAltMenuLogoCap + kAltMenuLogoBosluk`tur.
///
/// ⚠️⚠️ **GERI ALINDI — ILK DEGERINDE (12).** Kullanici once *"ikonlar ortadaki
///	menuye cok yaklasmis"* dedi, 32 ve 60 denendi; sonucu gorunce *"ikonlara
///	ne yaptiysan GERI AL"* dedi. Buyuk pay 6 esnek hucreden calindigi icin
///	ikonlari ekran kenarlarina dogru sikistiriyor ve ortada buyuk bir boşluk
///	birakiyordu.
/// ⚠️ YAPMA: bu sayiyi kullanici ACIKCA istemeden buyutme.
const double kAltMenuLogoBosluk = 12;

/// ⚠️⚠️⚠️ TURU 96n — LOGO IKONLARDAN **10 dp DAHA YUKARIDA** (kullanici emri:
///	*"logoyu ... mevcut boyutu ile koy, 10px yukarida duracak sekilde"*).
const double kAltMenuLogoKaldir = kAltMenuIkonKaldir + 10;

/// Logonun siyah cubugun UST KENARINDAN tasan miktari.
///
/// ⚠️⚠️ **ELLE YAZILMAZ, TURETILIR.** Logo cubuktan tasiyor; bu deger cubugun
///	ustune konan SAYDAM SERIDIN yuksekligidir. Boylece:
///	· `ClipRRect` logoyu **KIRPMAZ** (kirpsaydi ust %15'i kesilirdi),
///	· `Stack` kendi yuksekligine dahil ettigi icin **tasma uyarisi olusmaz**,
///	· logonun TAMAMI dokunulabilir kalir (Flutter, ebeveyn kutusunun DISINA
///	  tasan alani hit-test ETMEZ — orasi gorunur ama tiklanmaz olurdu).
/// ⚠️ Sabitlerden biri degisirse bu deger KENDILIGINDEN uyar; asagidaki
///    muhafiz testi de ayni formulden okur.
final double kAltMenuLogoTasma =
    math.max(0.0, kAltMenuLogoCap / 2 + kAltMenuLogoKaldir - kAltMenuBoy / 2);

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
      // ⚠️⚠️⚠️ TURU 96n — LOGO CUBUGUN USTUNE TASAR, bu yuzden `ClipRRect`in
      //	**DISINDA** cizilir. Icinde kalsaydi ust %15'i KIRPILIRDI (kirpma
      //	sessizdir: ne analiz ne test uyarir, yalniz ekranda gorunur).
      // ⚠️ Ustteki saydam serit `kAltMenuLogoTasma` kadar; Stack yuksekligine
      //    dahil oldugu icin hem RenderFlex tasmasi hem "gorunur ama
      //    tiklanmaz" hatasi YAPISAL OLARAK olusmaz.
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: kAltMenuLogoTasma),
            child: ClipRRect(
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
                    child: Row(
                      // ⚠️ `stretch`: her hucre cubugun TAM YUKSEKLIGINI kaplar,
                      //    yani dokunma hedefi ikon degil HUCRENIN TAMAMIDIR.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _oge(0, LucideIcons.house, 'Anasayfa'),
                        _oge(1, LucideIcons.search, 'Ara'),
                        _oge(2, LucideIcons.clapperboard, 'Reels'),
                        // ⚠️ Logonun YERI: govdesi Stack'te cizilir, burada
                        //    yalnizca YER TUTAR. Bu sayede "3 sol · logo ·
                        //    3 sag" simetrisi bozulmaz.
                        const SizedBox(
                            width: kAltMenuLogoCap + kAltMenuLogoBosluk),
                        // ⚠️ OKUNMAMIS ROZETI: mesaj sekmesi alt menude ve
                        //    kullanici surekli akista/reels'te olacagi icin
                        //    rozet OLMADAN yeni mesaji HIC fark etmezdi.
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
          ),
          // ⚠️ `left/right: 0` + `Center`: logo cubugun YATAY ORTASINA oturur —
          //    Row'daki yer tutucu da tam ortada oldugu icin ikisi cakisir.
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: _logo(context))),
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
    if (ikon == LucideIcons.radio) return 31;
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
            const cap = kAltMenuLogoCap - 5;
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

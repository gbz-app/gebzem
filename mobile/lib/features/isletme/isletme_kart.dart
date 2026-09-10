/// ⚠️⚠️⚠️ TURU 94 — ISLETME KARTI **TEK KAYNAK**.
///
/// Kategori/rehber listesi ve "Favorilerim" AYNI karti ciziyor. Kart iki
/// ekrana kopyalansaydi puan/teslimat/kampanya/kalp birinde guncellenip
/// otekinde geride kalirdi — bu projede "ayni kuralin iki kopyasi drift
/// eder" sinifi ALTI kez sahaya cikti.
///
/// ⚠️ YAPMA: bu widget'i cagiran ekrana kopyalama.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import '../sosyal/profil_basligi.dart' show kOnayliRengi;
import '../sosyal/profil_sayfasi.dart';
import 'isletme_menu_seridi.dart'; // turu 180ag: kartin altindaki menu seridi
import 'isletme_servisi.dart';

/// ⚠️⚠️ TURU 93 — YAN BOSLUK **TEK KAYNAK** (kullanici emri: *"hepsi bir
///    container icinde sol sag bosluk icinde"*). Header, slider, arama
///    kutusu, 60x60 kartlar, filtre satiri ve isletme kartlari AYNI hizada
///    durur.
/// ⚠️ YAPMA: bu ekranda elle 12/14/16 gibi yatay dolgu yazma — bir tanesi
///    guncellenip otekiler unutuldugunda hizalama SESSIZCE bozulur.
const double kYanBosluk = 16;

/// ⚠️⚠️⚠️ TURU 96e — KARTLAR ARASI DIKEY BOSLUK.
///
/// ⚠️ ONCEKI TUR YANLIS ANLASILDI: kullanici *"isletmelerdeki sol sag ust
///    alt bosluk 30px"* dediginde LISTENIN yan dolgusu 30 yapilmis, kartlar
///    daralmisti. Duzeltme: *"sen isletme kartlarini neden kuculttun? ben
///    KART ICINDE oradaki 300 TL indirim, sag ustteki favori bunlar 25px
///    bosluk icinde olsun dedim"*. Yani 30 DIS degil, 25 IC boslukmus.
/// ⚠️ Yatay dolgu `kYanBosluk`a GERI DONDU: kartlar yine slider, input ve
///    "İşletmeler (N)" basligiyla AYNI hizada.
/// ⚠️ Bu sabit artik YALNIZ kartlar arasindaki dikey bosluk.
const double kKartAralik = 30;

/// ZEMINLI kart icin ic dolgu + kartlar arasi bosluk.
///
/// ⚠️⚠️ `kKartAralik` (30) BURADA KULLANILMAZ: o deger zemini OLMAYAN
///	kartlar icin secilmisti — ayrimi BOSLUK yapiyordu. Kart artik kendi
///	zeminini tasiyor, yani ayrim GORSEL; 30 dp birakilsaydi kartlar
///	birbirinden kopuk, sayfa dagilmis gorunurdu.
/// ⚠️ `kKartAralik` DEGISTIRILMEDI — `ilan_ekranlari.dart` onu HALA
///	kullaniyor ve orada zemin YOK (turu 96k dersi: bir sabiti degistirirken
///	TUM cagri yerlerini greple).
const double kKartIcDolgu = 12;
const double kZeminliKartAralik = 14;

/// ⚠️⚠️ KAPAGA BINEN OGELERIN (kampanya rozeti · kalp) KENARDAN BOSLUGU
///    (kullanici emri: 25 -> **15px**, dort yandan).
/// ⚠️ TEK KAYNAK: rozet SOL-ALT, kalp SAG-UST — ikisi de bu sabiti kullanir.
///    Ayri sayilar yazilsaydi biri guncellenip oteki geride kalirdi.
const double kKartIcBosluk = 15;

/// ⚠️⚠️ KART KAPAGINDAKI FAVORI KALBI — **24 -> 28** (kullanici emri:
///	*"kalpleri 4px daha buyut"*).
///
/// ⚠️ TEK KAYNAK: dolu ve bos hal AYNI sabiti kullanir. Iki yere ayri sayi
///    yazilsaydi dokununca kalbin BOYU ZIPLARDI.
/// ⚠️ DOKUNMA KUTUSU 38x38 SABIT KALDI: 28'lik glif rahat siger (5 dp pay)
///    ve kapaktaki yerlesim (`kKartIcBosluk`) DEGISMEZ — kalp buyurken
///    kenardan uzakligi ayni kalir.
/// ⚠️ 32'ye CIKARMA: kutuya 3 dp pay kalir ve kalp kapak koseine yapisik
///    gorunur; ayrica kampanya rozetiyle optik agirligi esitlenirdi.
const double kKalpOlcu = 28;

/// Kalbin beyaz konturunu KALINLASTIRAN golge ofseti — **TEK KAYNAK**
/// (dort yon de bunu okur; ayri sayilar yazilsaydi kontur bir yandan kalin
/// obur yandan ince olurdu).
///
/// ⚠️ TURU 180ag: **0.5 -> 0.35** (kullanici emri: *"kalpteki kalinligi
///	1 tik azalt"*). 0'a cekme — cizgi acik zeminde silikleşir.
const double _kKalpKontur = 0.35;

/// ⚠️⚠️⚠️ TURU 180ae — **LISTE KARTINDAKI KARE FOTOGRAF** (Preply mantigi:
///	16:9 kapak yerine solda kare kucuk gorsel).
///
/// ⚠️ 92 dp SECILDI, tahminle DEGIL TURETILEREK: sagdaki kolonun tasidigi
///	uc satir (ad 16 · etiket 24 · kutu ~46) + iki bosluk (6 + 8) = **~92**.
///	Fotograf o kolonla AYNI boyda olsun ki kart "L" gibi kirik gorunmesin.
/// ⚠️ `kKartIcBosluk` (kapaga binen ogelerin kenar payi) burada KULLANILMAZ:
///	kalp artik fotografin uzerinde DEGIL, sagdaki satirin icinde.
const double kKartFoto = 92;

/// ⚠️⚠️ **EKRANDAKI TEK GRI.** Slider zemini, kapak yer tutucusu ve 60x60
///    kartlar AYNI tonu kullanir (kullanici emri: *"ayni grilikte olsun"*).
/// ⚠️ YAPMA: bu ekranlarda elle `0xFFE7E7EA` gibi bir gri yazma.
Color kYuzeyGri(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF2A2A2E)
    : const Color(0xFFE7E7EA);

/// KART ZEMINI (kullanici emri: *"kartlarin arka planini koymamissin"*).
///
/// ⚠️⚠️ RENK MERDIVENININ "kart" BASAMAGI: sayfa `kAiZemin` (#17171A) ise
///	kart ONUN BIR TIK USTU (#1D1D21) olmak ZORUNDA — ayni ton verilseydi
///	kart zemininden AYIRT EDILEMEZ ve "arka plan yok" gorunumu (tam da
///	sikayet edilen sey) geri gelirdi.
/// ⚠️ Fotograf yer tutucusu (`kYuzeyGri` = #2A2A2E) kartin BIR TIK USTUNDE
///	kalir; ic ice merdiven boylece bozulmaz.
/// ⚠️ Bu bir FONKSIYON, sabit DEGIL: `Theme.of(c)` cagirir ve widget
///	`build`inde cagrildigi icin `koyuSayfa`nin temasini DOGRU cozer
///	(State metodundan cagrilirsa turu 180w tuzagina duser — YAPMA).
Color kKartZemin(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF1D1D21)
    : const Color(0xFFF4F4F6);

/// ⚠️⚠️⚠️ TURU 96 — **KOSE YARICAPI: TEK MANTIK.**
///
/// Kullanici: *"onayli gibi butonlardaki radius mantigi tum kart, input vb.
/// radius verilen HER SEYDE ayni olmali — olcuye gore radius ne verilmisse
/// digerleri de ayni mantikta gorunmeli"*. HAKLIYDI: ekranda **BES FARKLI**
/// yaricap vardi ve hicbiri digerinden turemiyordu —
///	  slider 22 · kapak 14 · 60x60 kutu 16 · kampanya rozeti 8 · cip 16
/// Yani ayni ekrandaki iki kutu, ayni tasarim dilini konusmuyordu.
///
/// ⚠️⚠️⚠️ **YARICAP = ARAMA KUTUSUNUN ORANI** (kullanici emri, UCUNCU
///	yazimda dogru anlasildi):
///	*"slider, alttaki kartlar, input, sagdaki gorunum vs. bunlarin radius
///	mantigi SU ANKI ISLETME ARA INPUT radius mantigi gibi olacak; kart
///	uzerindeki '300 TL indirim' de"*.
///
///	ONCEKI IKI DENEME NEDEN YANLISTI:
///	  1. "Kucuk oge = HAP (boy/2)" -> cipler TAM YUVARLAK oldu, kullanici
///	     *"butonlari tam radius yapmissin"* diye reddetti.
///	  2. "Her yerde SABIT 14" -> 48px'lik inputta hos duruyor ama **32px'lik
///	     cipte 14, yuksekligin %44'u** demek; goz onu yine HAP olarak
///	     gorur. Kullanici IKINCI KEZ ayni sikayeti yapti — hakliydi,
///	     cunku sabit bir sayi kucuk ogede oransal olarak BUYUR.
///
///	DOGRUSU: yaricap OGENIN YUKSEKLIGINE ORANLI olmali ve o oran, kullanicinin
///	BEGENDIGI referanstan gelmeli — arama kutusu **48 boyunda 14** yaricap
///	kullaniyor, yani **%29**.
///
/// ⚠️ TAVAN/TABAN ZORUNLU: oran ciplak birakilsaydi 200px'lik slider **58**
///    yaricap alir ve dev bir hapa donerdi; 26px'lik rozet ise 7.5 ile
///    neredeyse KESKIN kose olurdu. `clamp(8, 18)` ikisini de kapatir ve
///    60x60 kutunun degeriyle (17.4) suruklu devam eder.
/// ⚠️ YAPMA: sabit bir sayiya geri donme; orani degistirirken referansin
///    (arama kutusu) hala 14 aldigini DOGRULA.
/// ⚠️ YAPMA: bu ekranlarda elle `BorderRadius.circular(16)` gibi bir sayi
///    yazma; DAIMA bu fonksiyonu, ogenin GERCEK yuksekligiyle cagir.
double kYaricap(double yukseklik) => (yukseklik * 0.29).clamp(8.0, 18.0);

/// Buyuk yuzeyler (slider, kapak, panel) — tavana dayanir.
/// ⚠️ Ayri bir SAYI DEGIL, ayni fonksiyonun tavani: kural tek.
final double kYaricapBuyuk = kYaricap(1000);

/// ⚠️⚠️⚠️ **VURGU RENGI: SIYAH — YESIL DEGIL** (kullanici emri, IKINCI kez:
///	*"filtreye tikladigimda YESIL RENKLER VAR, KALDIR; SIYAH bizim
///	rengimiz"* + *"dönere tikladigimda yesil oluyor, siyah olacak"*).
///
///	Bu ekranlar `Theme.of(context).colorScheme.primary` kullaniyordu ve
///	uygulamanin temasinda o renk YESIL. Kullanici bu ekranda yesili iki
///	ayri turda reddetti: secili filtre kutusu, "İşletmeleri listele"
///	dugmesi, secili alt kategori ve filtre noktasi hep yesildi.
///
/// ⚠️ Koyu temada siyah GORUNMEZ olurdu -> orada beyaz.
/// ⚠️ TEK KAYNAK: bu ekranlarda vurgu gereken HER yer bunu cagirir.
///
/// ⚠️⚠️ TURU 115b — **YASAGIN GEREKCESI DEGISTI, YASAK DARALDI.**
///	Yukaridaki "`colorScheme.primary` yazilirsa YESIL geri gelir" hukmu
///	artik GECERSIZ: tema tohumu turu 115b'de logodaki MORA cevrildi
///	(`core/theme.dart`), yani `primary` = marka moru.
///	Bu fonksiyon YINE DE DURUYOR cunku kullanici bu ekranlarin
///	siyah/beyaz aksanini GORUP ONAYLADI (turu 93: *"filtrelerde YESIL
///	YOK"*) — degistirmek onaylanmis bir gorunumu bozmak olurdu.
/// ⚠️ TEK ISTISNA: **PUAN** (yildiz + sayi) `primary` kullanir. `kVurgu`
///    acik temada SIYAH doner ve puan normal metinden AYIRT EDILEMEZDI;
///    puan bir vurgudur, govde metni degil.
/// ⚠️ YAPMA: bu ekranlarda BASKA yerlerde `primary`/`secondary` kullanma.
Color kVurgu(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? Colors.white
    : const Color(0xFF1A1A1A);

/// TURU 180w — `koyuSayfa` ALTINDAKI State METOTLARI icin SABIT degerler.
///
/// UYARI NEDEN GEREKLI: `koyuSayfa` temayi `build`in DONDURDUGU agaca
///    koyar; bir `State` metodunun ciplak `context`i o `Theme`in
///    USTUNDE kalir ve `kYuzeyGri(context)` **ACIK** temayi cozup
///    kutulari BEYAZ cizer (emulatorde olculdu — turu 135c/138/178
///    tuzaginin ONUNCU tekrari).
/// UYARI Degerler `kYuzeyGri`/`kVurgu`nin KOYU DALIYLA BIREBIR ayni;
///    biri degisirse OTEKI DE degismeli.
/// UYARI Yalniz DAIMA koyu cizilen ekranlarda kullan (ilan · etkinlik ·
///    talep · yemek). Tema duyarli bir ekranda kullanmak ACIK temada
///    okunmayan bir yuzey birakir.
const kYuzeyGriKoyu = Color(0xFF2A2A2E);
const kVurguKoyu = Colors.white;

/// Liste gorunumundeki genis kart.
class IsletmeKarti extends ConsumerStatefulWidget {
  const IsletmeKarti({super.key, required this.o, this.favoriDegisti});

  final IsletmeOzet o;

  /// Kalbe dokununca cagrilir. "Favorilerim" ekrani karti listeden DUSURUR.
  final void Function(bool favori)? favoriDegisti;

  @override
  ConsumerState<IsletmeKarti> createState() => _IsletmeKartiState();
}

class _IsletmeKartiState extends ConsumerState<IsletmeKarti> {
  late bool _favori = widget.o.favorim;
  bool _mesgul = false;

  /// ⚠️ IYIMSER GUNCELLEME: kalp ANINDA doner, istek arkada gider. Ag
  ///    yavassa 300ms bekleyip donen bir kalp "dokundum mu?" hissi verir.
  /// ⚠️ HATA DALINDA **GERI ALINIR**: aksi halde kullanici favoriledigini
  ///    sanip listede bulamazdi.
  /// ⚠️ CIFT DOKUNMA KILIDI: iki hizli dokunus iki istek atardi ve son
  ///    yanit hangisiyse o kazanirdi (yaris).
  Future<void> _cevir() async {
    if (_mesgul) return;
    final yeni = !_favori;
    setState(() {
      _favori = yeni;
      _mesgul = true;
    });
    // ⚠️ Servis TUM await'lerden ONCE yakalanir: kullanici geri basarsa
    //    `ref.read` `StateError` firlatir ve `catch` onu yutar (turu 77b).
    final svc = ref.read(isletmeServisiProvider);
    try {
      await svc.favoriCevir(widget.o.id, yeni);
      widget.o.favorim = yeni;
      widget.favoriDegisti?.call(yeni);
    } catch (_) {
      if (mounted) setState(() => _favori = !yeni);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  /// ⚠️⚠️⚠️ TURU 180ae — **ISLETME KARTI PREPLY MANTIGINDA YENIDEN KURULDU**
  ///	(kullanici emri: *"kart görünümlerini de sana görsel atacağım o
  ///	şekilde göster / sadece MANTIĞINI al"*).
  ///
  /// ═══════════ REFERANSTAN ALINAN **MANTIK** (gorsel DEGIL) ═══════════
  ///
  ///	solda KARE FOTOGRAF · saginda ad + onay tiki · altinda ETIKETLER ·
  ///	altinda **IKI KUTU** (fiyat / puan) · sonra aciklama satiri ·
  ///	en altta IKONLU meta · sag ustte KALP.
  ///
  /// ⚠️⚠️ **16:9 KAPAK KALDIRILDI.** Referans duzende buyuk kapak YOK; kart
  ///	bir SATIR (fotograf + bilgi). Kapak kalsaydi kart ~2 kat uzar ve
  ///	referansin en belirgin ozelligi (ekranda daha cok isletme gorme)
  ///	kaybolurdu.
  /// ⚠️ Gorsel kaynagi sirasi DEGISMEDI: **kapak -> avatar -> notr kutu**.
  ///	Kirik gorsel CIZILMEZ (turu 93 karari).
  ///
  /// ═══════════ NE **UYDURULMADI** (turu 135 dersi) ═══════════
  ///
  /// · **ACIKLAMA METNI YOK**: `IsletmeOzet`te (ve sunucunun liste yanitinda)
  ///   `aciklama` alani YOK. Referanstaki tanitim satirinin karsiligi olarak
  ///   GERCEK olan tek sey ADRES — o cizilir, yoksa satir HIC cizilmez.
  ///   Sahte bir tanitim cumlesi yazmak, uzerine karar verilen bir YALAN
  ///   olurdu.
  /// · Kutular yalniz VERISI VARSA cizilir; ikisi de yoksa satir CIZILMEZ.
  ///   "0 TL" / "★ 0" yanlis bilgidir.
  ///
  /// ⚠️ Kalp SAG UST'te KALDI (kullanici emri) ama artik kapagin UZERINDE
  ///	degil, kartin icinde: zemin fotograf olmadigi icin "beyaz kontur acik
  ///	fotografta kayboluyor" sinifi (turu 96d/96j) YAPISAL OLARAK bitti.
  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final ks = Theme.of(context).colorScheme;
    final soluk = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.62);
    final gorselID = (o.kapakMediaId != null && o.kapakMediaId!.isNotEmpty)
        ? o.kapakMediaId!
        : (o.avatarMediaId ?? '');
    // ⚠️⚠️⚠️ TURU 180ag — **ETIKET SERIDI KARTTAN TAMAMEN KALKTI**
    //	(kullanici emri: *"isim altindaki yemek butonu kaldir, oraya
    //	aciklama yaz"*). Onceden burada `etiketler` listesi kuruluyordu:
    //	  · kategori adi (`isletmeKategorileri[o.kategori]`) — turu 180ag'de
    //	    KALDIRILDI; yerini ACIKLAMA aldi.
    //	  · kampanya etiketleri — turu 180af'te KALDIRILMISTI (*"buradaki
    //	    yemek 300 TL indirim vs bunlar olmasin"*).
    //
    // ⚠️ VERI OLU KALMADI: `o.kategori` ve `o.kampanyalar` MODELDE ve
    //	sunucuda AYNEN duruyor; izgara/serit kartlari `kampanyaRozetleri` ve
    //	kendi etiketleriyle onlari HALA ciziyor.
    // ⚠️ YAPMA: `...o.kampanyalar.take(2)` ya da kategori hapini buraya geri
    //	koyma.
    return Padding(
      padding: const EdgeInsets.only(bottom: kZeminliKartAralik),
      child: GestureDetector(
        // ⚠️ **DALGA YOK** (kullanici emri: "tikladiginda titreme olmasin").
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id))),
        // ⚠️⚠️ KART ZEMINI (kullanici emri). Zemin OLMADAN kart sayfayla ayni
        //	renkteydi ve "kart" degil "liste satiri" gibi duruyordu.
        // ⚠️ Yaricap `kYaricap` TEK KAYNAGINDAN (hap kurali) — elle sayi
        //	yazilsaydi ekrandaki ALTINCI farkli yaricap olurdu (turu 96).
        child: Container(
          decoration: BoxDecoration(
            color: kKartZemin(context),
            borderRadius: BorderRadius.circular(kYaricap(kKartFoto)),
          ),
          // ⚠️⚠️ `clipBehavior` ZORUNLU: menu seridi kartin GERCEK kenarina
          //	kadar kayiyor ve kirpilmazsa ogeler yuvarlak koselerin DISINA
          //	tasar.
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // ⚠️⚠️ IC DOLGU ARTIK `Container`IN KENDISINDE DEGIL: menu seridi
            //	kartin kenarina kadar kaymak ZORUNDA (turu 144 dersi:
            //	kolonda kalsaydi serit kartin IC kenarinda biter ve ogeler
            //	"duvara carpmis gibi" dururdu). Dolgu metin bloklarina
            //	devredildi; serit kendi yatay dolgusunu KENDI tasiyor.
            Padding(
              padding: const EdgeInsets.all(kKartIcDolgu),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(kYaricap(kKartFoto)),
                  child: SizedBox(
                    width: kKartFoto,
                    height: kKartFoto,
                    child: gorselID.isEmpty
                        ? ColoredBox(color: kYuzeyGri(context))
                        // ⚠️ Genislik ACIKCA verilir: yoksa gorsel 2048px'e
                        //    kadar decode edilir (turu 91: ~9 MB gecici
                        //    RAM/kart). `kucuk: true` — 92 dp'lik bir kare
                        //    icin ham 1600x1600 avatari cozmek gereksiz.
                        : MedyaGorsel(
                            mediaId: gorselID,
                            fit: BoxFit.cover,
                            width: kKartFoto,
                            kucuk: true,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // ⚠️⚠️⚠️ KALP **SAG UCTA** (kullanici emri: *"sağ
                          //	üstte kalp"*) — EMULATORDE OLCULDU ve ilk
                          //	yazimda TUTMAMISTI: ad + tik + kalp duz bir
                          //	`Row`da sirayla dizilince kisa adlarda kalp
                          //	ADIN HEMEN YANINDA kaliyordu (McDonald's
                          //	kartinda gorundu).
                          //
                          // ⚠️⚠️ COZUM `Spacer` DEGIL: `Spacer` bir
                          //	`Expanded`dir ve ad da `Flexible` oldugu icin
                          //	ikisi kalan alani PAYLASIR — uzun bir ad,
                          //	yerin YARISINDA kirpilirdi (yaninda bos alan
                          //	dururken).
                          // ⚠️ Dogru cozum: **ad + tik ikilisini `Expanded`
                          //	bir `Row`a almak.** Ikili tum kalan alani alir,
                          //	kalp SAG UCA itilir; ad uzun oldugunda `Flexible`
                          //	+ ellipsis kirpar ve tik ADIN YANINDA kalir.
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    o.ad,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (o.dogrulandi)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Icon(
                                      LucideIcons.badgeCheck,
                                      size: 16,
                                      color: kOnayliRengi,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IsletmeKapakKalbi(dolu: _favori, onTap: _cevir),
                        ],
                      ),
                      // ⚠️⚠️⚠️ TURU 180ag — **ACIKLAMA, KATEGORI ETIKETININ
                      //	TAM YERINDE** (kullanici emri: *"isim altindaki
                      //	yemek butonu kaldir, oraya aciklama yaz"*).
                      //
                      //	Onceden burada `_etiketSeridi` ("Yemek" hapi)
                      //	vardi. Kategori bilgisi KAYBOLMADI: ekranin
                      //	kendisi ZATEN o kategorinin listesi (baslik
                      //	"2 Restoran") ve izgara/serit kartlari etiketi
                      //	cizmeye devam ediyor.
                      // ⚠️⚠️ **UYDURMA CUMLE YAZILMADI**: `aciklama`
                      //	sunucudan gelir ve BUGUN BOS gelir (`isletmeler`
                      //	tablosunda sutun YOK — 48 migration tarandi).
                      //	O durumda satir HIC CIZILMEZ.
                      // ⚠️ YAPMA: bos gelince `o.adres`e geri dusme
                      //	(kullanici acikca *"acik adres yazma"* dedi) ya da
                      //	sabit bir tanitim metni basma (turu 135).
                      if (o.aciklama.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          o.aciklama.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: soluk,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _kutular(context, o, ks, soluk),
                    ],
                  ),
                ),
              ],
            ),
            // ⚠️ IKONLU META — `vitrinSatiri` **TEK KAYNAK** (izgara ve serit
            //    kartlari da onu cizer); kopyalanmadi.
            // ⚠️⚠️ Puan burada TEKRAR CIZILMEZ (`puanHaric: true`): kutuya
            //    tasindi. Iki yerde birden cizilseydi ayni sayi ayni kartta
            //    IKI KEZ gorunurdu.
            const SizedBox(height: 9),
            vitrinSatiri(context, o, kompakt: false, puanHaric: true),
                ],
              ),
            ),
            // ⚠️⚠️⚠️ TURU 180ag — **MENU SERIDI** (kullanici emri: *"altina
            //	menuler gelsin menu ekle · sol sag scroll · menu icinde resim
            //	menu ismi ve fiyat"*).
            //
            // ⚠️⚠️ **KAPI `urunSayisi > 0`**: liste ucu urun ADI/GORSELI
            //	dondurmuyor, yani serit isletme basina AYRI bir istek
            //	(`/users/{id}/urunler`) demek — turu 17'de kapatilan N+1.
            //	Bu tek kapi, urunu OLMAYAN isletmeler icin istegi tamamen
            //	kaldirir; kalani `UrunDeposu` (tembel + semafor 4 + tek ucus
            //	+ onbellek) sinirlar. Ayrintili gerekce
            //	`isletme_menu_seridi.dart` basinda.
            // ⚠️ YAPMA: bu kapiyi kaldirma — 60 kayitlik listede kosulsuz
            //	cagri 60 es zamanli istek demektir.
            if (o.urunSayisi > 0)
              IsletmeMenuSeridi(
                isletmeId: o.id,
                isletmeAd: o.ad,
                urunSayisi: o.urunSayisi,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kategori + kampanya etiketleri (referanstaki rozet/etiket seridi).
  ///
  /// ⚠️ `Wrap` — `Row` DEGIL: uc etiket dar telefonda tek satira sigmaz ve
  ///	`Row` RenderFlex tasma seridi cizerdi.
  /// ⚠️ Yukseklik ACIKCA verilir: yaricap ondan turuyor (hap kurali); dolguya
  ///	birakilsaydi yazi olcegi degisince yaricap "hap" olmaktan cikardi.
  ///
  /// ⚠️⚠️ TURU 180ag — **CAGRI YERI KAPATILDI, GOVDE DURUYOR** (kullanici
  ///	emri: kategori hapinin yerine aciklama). Bu dosyada uye silmek
  ///	komsu uyeyi goturme riski tasiyor ve karar tek satirla geri
  ///	alinabilsin isteniyor (projenin yerlesik deseni).
  // ignore: unused_element
  Widget _etiketSeridi(BuildContext c, List<String> etiketler) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in etiketler)
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: kYuzeyGri(c),
                borderRadius: BorderRadius.circular(kYaricap(24)),
              ),
              // ⚠️⚠️ `Center(widthFactor: 1)` — `alignment:` DEGIL:
              //	alignment'li bir `Container` gelen GEVSEK kisitin TAMAMINI
              //	kaplar ve `Wrap` cocuguna ekran genisligi kadar kisit
              //	verdigi icin etiket **TAM GENISLIKTE** cizilirdi
              //	(`kampanyaRozetleri`nde emulatorde birebir bu yasandi).
              child: Center(
                widthFactor: 1,
                child: Text(
                  e,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      );

  /// Referanstaki **IKI KUTU**: fiyat ve puan.
  ///
  /// ⚠️⚠️ Kutu YALNIZ verisi VARSA cizilir; ikisi de yoksa `SizedBox.shrink`.
  ///	"0 TL" / "★ 0" yazmak YANLIS BILGIDIR (bu projede kapak/teslimat/
  ///	mesafe de ayni kurali izliyor).
  /// ⚠️ Kutular ICERIK KADAR yer kaplar (`Wrap`); `Expanded` ile satirin
  ///	yarisina gerilselerdi tek kutulu bir kart iki kutulu kartla AYNI
  ///	gorunur ve bilgi eksikligi GIZLENIRDI.
  Widget _kutular(
    BuildContext c,
    IsletmeOzet o,
    ColorScheme ks,
    Color? soluk,
  ) {
    final fiyat = o.minFiyatKurus;
    final kutular = <Widget>[
      if (fiyat != null && fiyat > 0)
        _kutu(
          c,
          // ⚠️ **"₺" YERINE "TL"**: bazi Android yazi tiplerinde ₺ glifi
          //    eksik ve tofu (kutu) cizilir (turu 110/179 karari).
          '${(fiyat / 100).round()} TL',
          'en uygun',
          null,
          soluk,
        ),
      if (o.puan != null)
        _kutu(
          c,
          o.puan!.toStringAsFixed(1).replaceAll('.', ','),
          // ⚠️ Oy sayisi YOKSA alt satir "degerlendirme" DEMEZ — olmayan bir
          //    sayiyi ima etmemek icin ikincil metin BOS birakilir.
          o.puanSayisi > 0 ? '${o.puanSayisi} oy' : '',
          ks.primary,
          soluk,
        ),
    ];
    if (kutular.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: kutular);
  }

  /// Tek kutu: buyuk deger + altinda kucuk etiket.
  ///
  /// ⚠️ Yildiz YALNIZ puan kutusunda (`renk != null`): fiyat kutusuna da
  ///	konsaydi iki kutu ayirt edilemezdi.
  Widget _kutu(
    BuildContext c,
    String deger,
    String etiket,
    Color? renk,
    Color? soluk,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: kYuzeyGri(c),
          borderRadius: BorderRadius.circular(kYaricap(46)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (renk != null) ...[
                  // ⚠️ Yildiz da AYNI kalinlikta (satirdaki tek ince ikon
                  //    kalmasin) — `vitrinSatiri` ile ayni karar.
                  kalinIkon(LucideIcons.star, olcu: 14, renk: renk),
                  const SizedBox(width: 4),
                ],
                Text(
                  deger,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: renk,
                  ),
                ),
              ],
            ),
            if (etiket.isNotEmpty)
              Text(
                etiket,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: kMetaKalinlik,
                  color: soluk,
                ),
              ),
          ],
        ),
      );
}

/// Kapaga binen kalp.
///
/// ⚠️⚠️⚠️ TURU 96 — **BEYAZ DAIRE KALDIRILDI** (kullanici emri: *"favori
///	arkasindaki beyaz daire kaldir, favori BEYAZ olacak border;
///	tikladiginda TAM PEMBE olacak, sadece oynama/patlama olmasin"*).
///
///	Zemin kalkinca ikonun kapak fotografi uzerinde okunmasi gerekiyor:
///	beyaz bir cizgi, acik renkli bir fotografta KAYBOLURDU. Cozum
///	**yumusak koyu golge** — daire gibi gorseli kapatmaz ama ikonu her
///	fotograftan ayirir.
///
/// ⚠️⚠️ IKI HALDE DE **AYNI `size`** (24). Onceki kod dolu halde 21, bos
///	halde 20 kullaniyordu: kalbe her dokunusta ikon 1px **ZIPLIYORDU** —
///	kullanicinin *"kuculme / oynama"* dedigi sey tam buydu. Olcek
///	animasyonu YOK; degisen tek sey RENK.
/// ⚠️ YAPMA: iki dala farkli `size` yazma; buraya `AnimatedScale`/`Transform`
///    ekleme.
///
/// ⚠️ Lucide'da **dolu kalp glifi YOK** (paket tarandi: heart, heartCrack,
///    heartOff... hepsi cizgi). Dolu hal Material'in `Icons.favorite`i —
///    duz 2B siluet, "emoji/3B yasak" kuralini IHLAL ETMEZ.
/// ⚠️ Dokunma alani 38dp — kapak uzerinde daha buyugu gorseli kapatir;
///    Material 48 kurali burada gorsel butunlugu lehine BILINCLI esnetildi
///    (kartin tamami zaten dokunulabilir, kalp ikincil eylem).
/// ⚠️ TURU 96j — `_Kalp` -> **PUBLIC**. Kullanici IKI TUR ust uste "dolu
///    halde beyaz border kaybolmasin" dedi; kalici muhafiz
///    (`test/liste_basligi_test.dart`) bu bileseni DOGRUDAN kurup golge
///    sayisini/ofsetini olcuyor. Private kalsaydi test edilemezdi.
/// ⚠️ YAPMA: tekrar private yapma (muhafiz derlenmez).
class IsletmeKapakKalbi extends StatelessWidget {
  const IsletmeKapakKalbi({super.key, required this.dolu, required this.onTap});

  final bool dolu;
  final VoidCallback onTap;

  // ⚠️⚠️ TURU 96d — **KOYU GOLGE KALDIRILDI** (kullanici emri: *"isletme
  //	kartlarinda favori ikonu ARKA PLAN GOLGESINI kaldir"*).
  //
  // ⚠️ BEDELI BILINIYOR: beyaz kontur, ACIK RENKLI bir kapak fotografi
  //    uzerinde okunurlugunu kaybedebilir. Beyaz kalinlastirma golgeleri
  //    (asagida) DURUYOR ve cizgiyi bir tik belirgin tutuyor.
  // ⚠️ YAPMA: okunurluk icin daire/zemin geri koyma (o da ayri bir turda
  //    kaldirilmisti).

  @override
  Widget build(BuildContext context) {
    const pembe = Color(0xFFE11D48);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        // ⚠️⚠️⚠️ TURU 96j — BEYAZ KONTUR ARTIK **PEMBENIN USTUNE CIZILIYOR**
        //	(kullanici UCUNCU KEZ bildirdi: *"kalbe tikladigimda beyaz border
        //	GORUNMUYOR"*).
        //
        //	ONCEKI IKI DENEME NEDEN TUTMADI — ikisi de GOLGEYDI:
        //	  turu 96g: 0.5px x 4 yon · turu 96j (ilk): 1.1px x 8 yon
        //	Golge glifin **DISINA**, yani KAPAGIN uzerine tasar. Tohumdaki
        //	isletmelerin cogunda kapak yok ve yer tutucu **ACIK GRI**
        //	(`kYuzeyGri` = 0xFFE7E7EA ≈ 231). Beyaz (255) ile acik gri (231)
        //	arasindaki fark GOZLE SECILEMEZ. Yani halka piksel olarak VARDI
        //	(401 saf beyaz piksel olculdu) ama kullanici HAKLI olarak
        //	goremiyordu: beyaz, beyaza yakin bir zeminin ustundeydi.
        //
        //	COZUM: kontur artik ZEMINE degil **PEMBE KUTLENIN USTUNE** cizilir
        //	(`Icons.favorite` + ustune `Icons.favorite_border` BEYAZ). Beyaz
        //	ile pembe (0xFFE11D48) arasindaki kontrast ~4.3:1 — zemin ne
        //	olursa olsun (beyaz kapak, acik gri, koyu fotograf) kontur
        //	GORUNUR. Artik "kaybolabilecegi" bir zemin YOK.
        //
        // ⚠️ IKI GLIF **MATERIAL CIFTI** (`favorite` + `favorite_border`):
        //	ayni siluet icin tasarlanmislardir, kenar cizgisi dolgunun
        //	sinirina TAM oturur. Lucide'in `heart`i ile karistirilamaz —
        //	silueti farklidir ve beyaz cizgi pembenin bir yaninda TASAR,
        //	obur yaninda ICERIDE kalirdi.
        // ⚠️ BOS HAL DE `favorite_border`a cevrildi: iki hal AYNI silueti
        //	kullanmak ZORUNDA, yoksa dokununca kalbin SEKLI ZIPLARDI.
        // ⚠️ YAPMA: konturu tekrar `shadows` ile uretmeye donme.
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (dolu)
                const Icon(Icons.favorite, size: kKalpOlcu, color: pembe),
              // ⚠️ Kenar cizgisi HER IKI HALDE de cizilir; dolu halde pembenin
              //    ustune biner ve "beyaz border" tam olarak budur.
              // ⚠️ Golgeler cizgiyi bir tik KALINLASTIRIR (Lucide/Material
              //    ikonlari FONT'tur, `strokeWidth` YOKTUR).
              const Icon(
                Icons.favorite_border,
                size: kKalpOlcu,
                color: Colors.white,
                // ⚠️⚠️ TURU 180ag — KALINLIK **BIR TIK AZALDI** (kullanici
                //	emri: *"kalpteki kalinligi 1 tik azalt"*): ofset
                //	**0.5 -> 0.35** (dort yon de AYNI sabitten).
                //
                // ⚠️ Lucide/Material ikonlari FONT'tur, `strokeWidth`
                //	YOKTUR — kalinlik ancak ayni renkte kaydirilmis
                //	golgelerle simule edilir. Inceltmenin TEK dogru kolu
                //	bu ofsettir.
                // ⚠️ `size` (`kKalpOlcu`) ile INCELTME: o cizgiyi de
                //	inceltir ama IKONU DA kucultur; kullanici boyut degil
                //	KALINLIK istedi (turu 175 dersi).
                // ⚠️ Golgeleri TAMAMEN kaldirma: koyu golge turu 96d'de
                //	zaten kaldirildi, kalan beyaz golgeler cizgiyi acik
                //	zeminde bir tik belirgin tutuyor.
                shadows: [
                  Shadow(color: Colors.white, offset: Offset(_kKalpKontur, 0)),
                  Shadow(color: Colors.white, offset: Offset(-_kKalpKontur, 0)),
                  Shadow(color: Colors.white, offset: Offset(0, _kKalpKontur)),
                  Shadow(color: Colors.white, offset: Offset(0, -_kKalpKontur)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kampanya rozetleri — kapagin **SOL ALTINA** biner.
///
/// ⚠️ Metin SUNUCUDAN gelir (`isletmeler.kampanyalar`); istemcide sabit
///    yazilsaydi yeni bir kampanya cumlesi MAGAZA ONAYI gerektirirdi.
/// ⚠️ EN FAZLA IKI rozet: ucuncusu 360dp'de kapagin yarisini kapatiyor.
/// ⚠️ Rozet DUGME DEGIL (`IgnorePointer`): bir eylemi yok, kapagin tamami
///    zaten isletmeye gidiyor.
Widget kampanyaRozetleri(IsletmeOzet o) {
  if (o.kampanyalar.isEmpty) return const SizedBox.shrink();
  return Positioned(
    left: kKartIcBosluk,
    bottom: kKartIcBosluk,
    // ⚠️ Kalbin ALTINA girmesin: kalbin dokunma alani (38) + kendi bosluğu.
    right: kKartIcBosluk + 38,
    child: IgnorePointer(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final k in o.kampanyalar.take(2))
            Container(
              // ⚠️ YUKSEKLIK **ACIKCA** verilir: yaricap ondan turuyor
              //    (hap kurali). Dolguya birakilsaydi yazi olcegi degisince
              //    yukseklik kayar ve yaricap "hap" olmaktan cikardi.
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                // ⚠️ 8 -> hap (13): cipler ve arama kutusuyla AYNI mantik.
                borderRadius: BorderRadius.circular(kYaricap(26)),
              ),
              // ⚠️⚠️ `Center(widthFactor: 1)` — `Container`a `alignment`
              //	VERILEMEZ: alignment'li bir Container gelen kisitin
              //	TAMAMINI kaplar; `Wrap` cocuguna ekran genisligi kadar
              //	gevsek kisit verdigi icin rozet **TAM GENISLIKTE** cizilir
              //	(ilk denemede tam bu oldu, emulatorde goruldu).
              //	`widthFactor: 1` yatayda ICERIGE sarilmayi zorlar, dikeyde
              //	ise 26px'lik kutunun ortasina yerlestirir.
              // ⚠️ YAPMA: buraya `alignment: Alignment.center` koyma.
              child: Center(
                widthFactor: 1,
                child: Text(
                  k,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// ★ puan (oy) · teslimat suresi · min. tutar.
///
/// ⚠️ Her parca YALNIZ verisi VARSA cizilir (migration 046'da hepsi
///    OPSIYONEL). NULL iken "★ 0" ya da "0 dk" YANLIS BILGI olurdu.
/// ⚠️⚠️ `puan` bir DEGERLENDIRME SISTEMINDEN gelmiyor — editoryal bir sayi.
/// ⚠️⚠️ TURU 180ae — **`puanHaric`**: liste karti puani artik KUTUDA
///	gosteriyor (Preply mantigi). Varsayilan `false`, yani izgara ve serit
///	kartlarinin davranisi **BIREBIR AYNI** kaldi.
/// ⚠️ Ayri bir "kutusuz vitrin satiri" fonksiyonu YAZILMADI: bu projede ayni
///	kuralin iki kopyasi ALTI kez drift etti.
Widget vitrinSatiri(
  BuildContext c,
  IsletmeOzet o, {
  required bool kompakt,
  bool puanHaric = false,
}) {
  final soluk = Theme.of(
    c,
  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.62);
  // ⚠️ 13 -> 14 -> **13** (kullanici emri, turu 96g: "baslik altindaki
  //    bilgileri 1px kucuk"). Kompakt (izgara) dali 12ye iner.
  final boy = kompakt ? 12.0 : 13.0;
  final p = <Widget>[];

  if (o.puan != null && !puanHaric) {
    p.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⚠️ Yildiz da AYNI kalinlikta (satirdaki tek ince ikon kalmasin).
          // ⚠️⚠️ TURU 115b — PUAN ARTIK **MARKA RENGINDE** (kullanici emri:
          //	*"yesil renk yapma artik, genel tasarima uy"*). Onceki ton
          //	Yemeksepeti yesiliydi (0xFF16A34A) ve uygulamanin logosu MOR.
          // ⚠️ "Açık/Kapalı" gostergesi YESIL KALDI (asagida): orasi bir DURUM
          //    isareti (trafik isigi semantigi), marka aksani DEGIL. Onu da
          //    mora cevirmek "acik" ile "kapali"yi ayirt edilemez yapardi.
          kalinIkon(
            LucideIcons.star,
            olcu: 14,
            renk: Theme.of(c).colorScheme.primary,
          ),
          const SizedBox(width: 3),
          Text(
            o.puan!.toStringAsFixed(1).replaceAll('.', ','),
            style: TextStyle(
              fontSize: boy,
              fontWeight: FontWeight.w700,
              color: Theme.of(c).colorScheme.primary,
            ),
          ),
          if (!kompakt && o.puanSayisi > 0) ...[
            const SizedBox(width: 3),
            // ⚠️ Oy sayisi da `w600` — satirdaki TEK ince parca kalsaydi
            //    "(320)" digerlerinin yaninda soluk bir kaza gibi gorunurdu.
            Text(
              '(${o.puanSayisi})',
              style: TextStyle(
                fontSize: boy,
                color: soluk,
                fontWeight: kMetaKalinlik,
              ),
            ),
          ],
        ],
      ),
    );
  }
  // ⚠️ TESLIMAT SURESI — saat ikonu (kullanici emri: "bunlara modern
  //    ikonlar ekle"). Ikon metnin ANLAMINI tasir; yalnizca "25-35 dk"
  //    yazmak tarama sirasinda sayiyi neyle karistiracagini belirsiz birakir.
  if (o.teslimatDkMin != null && o.teslimatDkMax != null) {
    p.add(
      _ikonluMetin(
        LucideIcons.clock,
        '${o.teslimatDkMin}-${o.teslimatDkMax} dk',
        boy,
        soluk,
      ),
    );
  }
  // ⚠️ MIN. TUTAR — cuzdan ikonu. **"₺" YERINE "TL"** (kullanici emri):
  //    bazi Android yazi tiplerinde ₺ glifi eksik ve tofu (kutu) cizilir.
  if (o.minTutarKurus != null && o.minTutarKurus! > 0) {
    p.add(
      _ikonluMetin(
        LucideIcons.wallet,
        'Min. ${(o.minTutarKurus! / 100).round()} TL',
        boy,
        soluk,
      ),
    );
  }
  // ⚠️⚠️ MESAFE — "1,2 km" / "300 m" (kullanici emri).
  //
  // ⚠️ Konum izni YOKSA ya da isletme koordinat girmemisse `mesafeMetni`
  //    BOS doner ve HICBIR SEY cizilmez. "0 m" ya da "?" yazmak yanlis
  //    bilgi olurdu; bu projede kapak/puan/teslimat da ayni kurali izliyor.
  if (o.mesafeMetni.isNotEmpty) {
    // ⚠️ IKON `mapPin` -> `navigation` (kullanici emri): cip seridindeki
    //    "Yakınımda" ile AYNI ikon — ikisi de mesafeden bahsediyor.
    p.add(_ikonluMetin(LucideIcons.navigation, o.mesafeMetni, boy, soluk));
  }
  if (p.isEmpty) return const SizedBox.shrink();

  // ⚠️ Ikonlar ayirici gorevi de goruyor; ARADAKI NOKTA KALDIRILDI (ikon +
  //    nokta birlikte satiri gurultulu yapiyordu).
  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 3,
    children: p,
  );
}

/// Ikon + metin ikilisi — vitrin satirinin tek yapi tasi.
/// ⚠️⚠️ TURU 96j — META YAZISI **`w600`** (kullanici emri: *"restoran
///	altindaki kartlarin 25-35 dk vb. bunlari BIR TIK KALINLASTIR, filtre
///	vb. gibi olsun"*).
///
/// ⚠️ Hedef ACIKCA VERILDI: suzgec cipleriyle AYNI (`fontSize: 13` +
///    `FontWeight.w600` — bkz. `isletme_listesi.dart` cip govdesi). Bu yuzden
///    "bir tik" varsayilan `w400`ten w500'e DEGIL, dogrudan **w600**a cikti;
///    kullanicinin istedigi sey referansa ESITLENMEKTI.
/// ⚠️ **RENK DEGISMEDI** (`soluk`, alpha .62): kalinlik artarken renk de
///    koyulsaydi meta satiri isletme ADIYLA yarisir ve hiyerarsi bozulurdu.
/// ⚠️ IKON BOYU 14'te KALDI: 13px yazinin yaninda 14px ikon zaten bir tik
///    buyuk; kalinlikla birlikte ikonu da buyutmek satiri sismis gosterirdi.
const FontWeight kMetaKalinlik = FontWeight.w600;

/// Bir tik **KALIN** cizilmis ikon.
///
/// ⚠️⚠️⚠️ `lucide_icons_flutter` ikonlari bir **FONT** olarak sunar (glif),
///	SVG DEGIL — `strokeWidth` YOKTUR ve `Icon`a yazilirsa DERLENMEZ.
///	Kalinlik, AYNI RENKTE ±[yayilma] kaydirilmis DORT golgeyle simule edilir:
///	glif kendi uzerine hafifce yayilir ve cizgi kalinlasir.
///
/// ⚠️⚠️ TEK KAYNAK (turu 96j): suzgec cipleri (`_cipIkon`) ve kart meta
///	satiri AYNI teknigi kullanmak ZORUNDA — kullanicinin emri zaten
///	*"filtre butonlari gibi yapar misin kalinliklarini"* idi. Iki yerde ayri
///	ayri yazilsaydi biri guncellenip oteki ince kalirdi (bu projede "ayni
///	kuralin iki kopyasi" sinifi ALTI kez sahaya cikti).
/// ⚠️ `yayilma` BUYUTULURSE glif BULANIKLASIR (golge, kenar yumusatmali bir
///    kopyadir). 0.4 olculdu: cizgi belirginlesiyor, keskinlik bozulmuyor.
Widget kalinIkon(
  IconData ikon, {
  required double olcu,
  required Color? renk,
  double yayilma = 0.4,
}) => Icon(
  ikon,
  size: olcu,
  color: renk,
  shadows: renk == null
      ? null
      : [
          for (final d in [
            Offset(yayilma, 0),
            Offset(-yayilma, 0),
            Offset(0, yayilma),
            Offset(0, -yayilma),
          ])
            Shadow(color: renk, offset: d),
        ],
);

Widget _ikonluMetin(IconData ikon, String metin, double boy, Color? renk) =>
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ⚠️ TURU 96j — ikon da metinle BIRLIKTE kalinlasti (kullanici emri:
        //    *"25-35 gibi bunlarin IKONLARINI kalinlastirmamissin"*).
        kalinIkon(ikon, olcu: 14, renk: renk),
        const SizedBox(width: 4),
        Text(
          metin,
          style: TextStyle(
            fontSize: boy,
            color: renk,
            fontWeight: kMetaKalinlik,
          ),
        ),
      ],
    );

/// **Açık/Kapalı · En uygun XX ₺ · İlçe** — hepsi gercek alanlardan turer.
Widget bilgiSatiri(BuildContext c, IsletmeOzet o) {
  final soluk = Theme.of(c).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
  final acik = isletmeAcikMi(o.calisma);
  final kapanis = _bugunKapanis(o.calisma);
  final parcalar = <Widget>[];

  // ⚠️ `null` = calisma saati TANIMSIZ -> hicbir sey yazilmaz. "Kapalı"
  //    yazmak, saatini girmemis isletmeyi HAKSIZ yere kapali gosterirdi.
  if (acik != null) {
    parcalar.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: acik ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            acik
                ? (kapanis.isEmpty ? 'Açık' : 'Açık · $kapanis\'a kadar')
                : 'Kapalı',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: acik ? const Color(0xFF16A34A) : soluk,
            ),
          ),
        ],
      ),
    );
  }
  final f = o.minFiyatKurus;
  if (f != null && f > 0) {
    parcalar.add(
      Text(
        'En uygun ${(f / 100).round()} TL',
        style: TextStyle(fontSize: 13, color: soluk),
      ),
    );
  }
  // ⚠️ TEK SATIRDA KALSIN diye yalniz ILCE: kategori zaten ekranin basligi.
  final yer = o.ilce.isNotEmpty
      ? o.ilce
      : (o.il.isNotEmpty ? o.il : isletmeKategoriAdi(o.kategori));
  if (yer.isNotEmpty) {
    parcalar.add(Text(yer, style: TextStyle(fontSize: 13, color: soluk)));
  }
  if (parcalar.isEmpty) return const SizedBox.shrink();

  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 2,
    children: [
      for (var i = 0; i < parcalar.length; i++) ...[
        if (i > 0) Text('·', style: TextStyle(fontSize: 13, color: soluk)),
        parcalar[i],
      ],
    ],
  );
}

/// Bugün için işletme açık mı? `null` = çalışma saati tanımsız.
///
/// ⚠️ TURU 96 — **PUBLIC**: filtre ekranindaki "Şu an açık" suzgeci de bunu
///    cagirir. Ikinci bir kopya yazilsaydi gece yarisini asan mesai kurali
///    iki yerde yasar ve DRIFT ederdi.
///
/// ⚠️ `gun` **1=Pazartesi**, Dart'in `DateTime.weekday` degeriyle BIREBIR ayni.
/// ⚠️ GECE YARISINI ASAN mesai (22:00-02:00) destekleniyor.
bool? isletmeAcikMi(List<dynamic> calisma) {
  final bugun = _bugunKaydi(calisma);
  if (bugun == null) return null;
  if (bugun['kapali'] == true) return false;
  final a = _dk(bugun['acilis']);
  final k = _dk(bugun['kapanis']);
  if (a == null || k == null) return null;
  final now = DateTime.now();
  final s = now.hour * 60 + now.minute;
  return k > a ? (s >= a && s < k) : (s >= a || s < k);
}

/// ⚠️⚠️ TURU 96d — "Gece Kuşu" karti icin: **gec saate kadar acik mi?**
///
/// Olcut: bugunun kapanisi **23:00 ve sonrasi**, ya da mesai GECE YARISINI
/// ASIYOR (kapanis <= acilis, ornegin 22:00-02:00).
/// ⚠️ Bu, `isletmeAcikMi`den AYRI bir sorudur: ogle vakti acik olan bir
///    yer "gece kusu" DEGILDIR. Iki olcut tek fonksiyona sikistirilsaydi
///    kartin adi yuklemiyle AYRISIRDI.
/// ⚠️ Calisma saati TANIMSIZ ise **false**: bilinmeyen bir yeri "gece acik"
///    saymak yanlis bilgi olurdu (bu dosyadaki genel kural).
bool isletmeGeceAcikMi(List<dynamic> calisma) {
  final b = _bugunKaydi(calisma);
  if (b == null || b['kapali'] == true) return false;
  final a = _dk(b['acilis']);
  final k = _dk(b['kapanis']);
  if (a == null || k == null) return false;
  if (k <= a) return true; // gece yarisini asiyor
  return k >= 23 * 60;
}

String _bugunKapanis(List<dynamic> calisma) {
  final b = _bugunKaydi(calisma);
  if (b == null || b['kapali'] == true) return '';
  return (b['kapanis'] ?? '').toString();
}

Map<String, dynamic>? _bugunKaydi(List<dynamic> calisma) {
  for (final g in calisma) {
    if (g is Map && (g['gun'] as num?)?.toInt() == DateTime.now().weekday) {
      return g.cast<String, dynamic>();
    }
  }
  return null;
}

/// "09:00" -> 540. Bozuk deger `null`.
int? _dk(dynamic s) {
  final p = (s ?? '').toString().split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

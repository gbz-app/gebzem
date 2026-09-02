import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../etkinlik/etkinlik_ekranlari.dart';
import '../ilan/ilan_ekranlari.dart';
import '../isletme/isletme_listesi.dart';
import '../isletme/yakinimda_ekrani.dart';
import '../ai/gebzem_ai.dart';
import '../isletme/urun_servisi.dart' show aiDurumProvider;
import '../talep/talep_ekranlari.dart';
import '../home/home_screen.dart' show aktifSekme;
import '../isletme/kategori_slider.dart';
import '../medya/medya_gorsel.dart' show Avatar;
import 'kesfet_ekrani.dart';
import '../../core/theme.dart' show morLogo, kAiZemin, AiZemin, kAiKartYuzey;
import '../home/home_screen.dart' show myProfileProvider;
import 'package:permission_handler/permission_handler.dart';

import '../isletme/isletme_servisi.dart' show isletmeServisiProvider;
import '../medya/konum_servisi.dart';
// ⚠️⚠️⚠️ TURU 96s — MENU KARTLARI **KATEGORI EKRANIYLA AYNI DILDE** (kullanici
//	emri: *"kartlarin genisliklerini diyorum, yemekteki gibi; renk ve yazi
//	tipleri de oyle olsun"*). Olcu/renk/yazi sabitleri BURADAN alinir,
//	KOPYALANMAZ — iki ekran birlikte doner.
import '../isletme/isletme_kart.dart' show kYanBosluk, kYaricap;

/// ⚠️⚠️ TURU 76b/77 — ANASAYFA SOL UST MENU.
///
/// Kullanici emri (76b): *"anasayfada sol ustte menu ikonu olsun, 2 tane 2
/// satir cizgi hamburger tarzi; tikladigimda yemek, restoran, alisveris kartlar
/// olsun; ikon YOK, kart altinda yazi sadece"*.
/// Kullanici emri (77): *"etkinlikler ... soldaki menuye tikladiginda ekranda
/// olacak"* + ilanlar + hizmetler + isletmeler.
///
/// ⚠️⚠️ KARTLARDA IKON YOK — KULLANICI ACIKCA BOYLE ISTEDI. Kart bir renk
///    gecisli zemin + ALTINDA yazidir. ⚠️ YAPMA: kartlarin icine ikon koyma.
///
/// ⚠️⚠️ TURU 76b'DE KARTLAR HICBIR YERE GITMIYORDU ("yakında" diyordu) —
///    bu projede tekrar eden "olu dogmus ozellik" sinifiydi. TURU 77'de
///    HEPSI GERCEK EKRANLARA BAGLANDI:
///      Etkinlikler → EtkinlikListesiEkrani
///      İlanlar     → IlanListesiEkrani (tum turler)
///      Hizmetler   → IlanListesiEkrani(tur: 'hizmet')
///      İşletmeler  → IsletmeListesiEkrani (tum kategoriler)
///      Yemek/Restoran/Cafe → IsletmeListesiEkrani(kategori: ...)
///      Yapay zekâ  → AiDanismaEkrani (YALNIZ sunucuda AI aciksa)
///    ⚠️ YAPMA: bir karti "yakında" haline geri dondurme; ekran yoksa karti
///       EKLEME.
///
/// ⚠️ DUZEN: 12 bolum (AI acikken 12, kapaliyken 11), 3 SUTUNLU IZGARA.
///    Tek satirlik Row 4. kartta
///    RenderFlex overflow verirdi (turu 60/62 dersi). Sheet KAYDIRILABILIR
///    (`isScrollControlled` + yukseklik tavani) — kucuk ekranda tasmasin.
/// ⚠️⚠️⚠️ TURU 130 — **TASARIM ONIZLEME BAYRAGI.**
///
///	Kullanici emri: *"simdilik yakinimdakilere sahte isimler yaz"*.
///
/// ⚠️⚠️⚠️ **YAYIN ONCESI `false` YAPILACAK.** Acikken ekranda GERCEK
///	OLMAYAN veri gorunur: uydurma isletme adlari ve mesafeler.
/// ⚠️ Kod SILINMEDI, bayrakla kapatiliyor (CLAUDE.md kurali): bayrak
///    `false` olunca gercek davranis AYNEN geri gelir.
/// ⚠️⚠️ TURU 135 — kardes bayrak `kSkorOnizleme` ARTIK YOK: mac karti ve
///	detay ekrani kullanici emriyle TAMAMEN KALDIRILDI (asagida).
const kYakinOnizleme = true;

/// ⚠️⚠️⚠️ TURU 147 — HAVA DURUMU + DOVIZ seridi ONIZLEME bayragi.
///
/// **YAYIN ONCESI `false` YAPILACAK.** Bu projede ne hava ne kur verisi
/// var (tablo yok, uc yok, dis servis anahtari yok); serit ORNEK degerler
/// gosterir ve bunu ekranda "örnek" ibaresiyle SOYLER.
/// ⚠️ Turu 135'te `kur_serit.dart` tam bu yuzden SILINMISTI; kullanici
///    turu 147'de seridi ACIKCA geri istedi.
const kHavaDovizOnizleme = true;

/// ⚠️⚠️ TURU 134 — YAKINIMDA kartinda **ad ile mesafe arasindaki bosluk**
///	(kullanici emri: *"400m isim arasindaki boslugu biraz arttir"*).
///
/// ⚠️ **TEK KAYNAK OLMAK ZORUNDA:** bu sayi hem kartta (`SizedBox`) hem
///	seridin YUKSEKLIK BUTCESINDE kullaniliyor. Ikisi ayrisirsa kart
///	butceden uzun olur ve yazi olcegi 1.3`te serit TASAR (turu 129`da
///	birebir bu yasandi, muhafiz 2.7 px olctu).
const kYakinAdAra = 3.0;

/// ⚠️⚠️⚠️ TURU 135 — **MENU SLIDERI BOS VE YEREL** (kullanici emri:
///	*"slider'daki mac olayini da kaldir, slider bos olsun, sol sag
///	scroll, 1-2 tane daha ekle"*).
///
///	Slaytlarin ICI ZATEN BOS cizilir (`kategori_slider.dart` -> `_slayt`:
///	yalnizca yuvarlak yuzey; baslik/alt metin turu 95'te kaldirildi).
///	Yani sunucudan gelen tek sey slayt **SAYISIYDI**.
///
/// ⚠️⚠️ **SAYI ARTIK SUNUCUDAN ALINMIYOR — SEBEBI DAYANIKLILIK:** eski
///	`_menuSlaytProvider` `/isletme-kesif` cagiriyordu ve istek patlar ya
///	da bos donerse `_slider` **`SizedBox.shrink()`** donuyordu, yani
///	kullanicinin gordugu slider AG HATASINDA TAMAMEN KAYBOLUYORDU.
///	Icerigi olmayan bir yer tutucu icin bu kabul edilemez; ustelik menu
///	acilisinda gereksiz bir istek daha atiliyordu.
/// ⚠️ Turu 77 kurali ("liste sunucudan gelir") BURADA GECERLI DEGIL: bu
///    sayi hicbir sorguyu/yetkiyi/siralamayi beslemiyor, YALNIZCA kac
///    bos kart cizilecegini soyluyor.
/// ⚠️ **2'DEN KUCUK YAPMA:** `KategoriSlider` tek slaytta zamanlayiciyi
///    KURMAZ ve komsu kart sarkmadigi icin kaydirilabildigi ANLASILMAZ.
/// ⚠️ Gercek kampanya/reklam gorseli geldiginde: slaytlar yine buradan
///    beslenir, sozlesme degistirmeden bir listeye baglanir.
const kMenuSlaytAdedi = 3;

/// ⚠️⚠️ TURU 135 — BOS SLAYTIN YUZEY OPAKLIGI (menu kartlarininki 0.12).
///
///	OLCULDU (denetim): 0.12 ile slayt `#1E1925`, zemin `#050308` ->
///	**1.19:1**. Icinde ikon/yazi olmayan 200 dp'lik bir blok icin bu
///	fiilen gorunmez demek. 0.20'de `#2E2839` -> **~1.45:1**.
/// ⚠️ Kartlarin 0.12'sine DOKUNULMADI: onlarda etiket ve ikon var,
///    ayrica o sayi GebzemAI mesaj balonuyla AYNI olmak zorunda
///    (`core/theme.dart` serhi).
const kSlaytAlfa = 0.20;

/// ⚠️⚠️ TURU 134 — **IKON KUTUSU KART YUZEYINDEN BIR TIK KOYU** (kullanici
///	emri: *"ikonlarin arka plan rengi kart renginden 1 tik kapali
///	olsun"*).
///
/// ⚠️ Siyah uzerine opaklik: kart yuzeyi zaten yari saydam mor; uzerine
///    yine mor koymak onu ACARDI, koyulastirmazdi.
/// ⚠️⚠️ TURU 135 — bu iki yardimci **`kur_serit.dart`TA TANIMLIYDI** ve o
///	dosya silinince menu DERLENMEZ oldu (YAKINIMDA kartlari ikisini de
///	kullaniyor). Buraya tasindilar: tek cagiran BU dosya.
/// ⚠️ Ucuncu bir ekran da kullanmaya baslarsa `core/`e tasi — cagri
///    yerlerine KOPYALAMA.
Color kIkonKutusu(BuildContext c) => Colors.black.withValues(alpha: 0.22);

/// ⚠️ Lucide bir FONT`tur (glif), SVG DEGIL — `strokeWidth` YOKTUR.
///    Kalinlik ayni renkte ±0.4 px kaydirilmis DORT GOLGE ile simule edilir
///    (turu 93 teknigi). ⚠️ `Icon`a `strokeWidth` yazarsan DERLENMEZ.
class KalinIkon extends StatelessWidget {
  const KalinIkon({
    super.key,
    required this.ikon,
    required this.boy,
    required this.renk,
  });

  final IconData ikon;
  final double boy;
  final Color renk;

  @override
  Widget build(BuildContext context) => Icon(
    ikon,
    size: boy,
    color: renk,
    shadows: [
      Shadow(color: renk, offset: const Offset(0.4, 0)),
      Shadow(color: renk, offset: const Offset(-0.4, 0)),
      Shadow(color: renk, offset: const Offset(0, 0.4)),
      Shadow(color: renk, offset: const Offset(0, -0.4)),
    ],
  );
}

class HizmetMenusu extends ConsumerStatefulWidget {
  const HizmetMenusu({super.key});

  @override
  ConsumerState<HizmetMenusu> createState() => _HizmetMenusuState();
}

// ⚠️⚠️ TURU 132 — **ANIMASYON CONTROLLER`I KALDIRILDI.** Zemin artik STATIK
//	(`AiZemin`); sureklı `repeat` eden bir controller hicbir seyi
//	besliyor olmadigi halde her karede tick uretiyordu.
class _HizmetMenusuState extends ConsumerState<HizmetMenusu> {
  @override
  Widget build(BuildContext context) {
    final aiAcik = ref.watch(aiDurumProvider).valueOrNull?.acik ?? false;

    // ⚠️ Liste BURADA kuruluyor cunku AI karti KOSULLU (sunucuda kapaliysa
    //    HIC cizilmez — basip 503 almasin).
    final bolumler = <_Bolum>[
      // ⚠️⚠️ TURU 85 — "YAKINIMDA" (kullanici emri: *"menuye tikladigimizda
      //    acilan pencereye yakinimda eklemeliyiz"*). Ustte harita, altta
      //    mesafeye gore sirali kartlar.
      // ⚠️ ILK SIRADA: konum tabanli kesif menunun EN DEGERLI girisidir ve
      //    izgarada ilk hucre en cok dokunulan yerdir.
      // ⚠️ TURU 85b: serh "ILK SIRADA" diyordu ama kart 4. siradaydi
      //    (denetim bulgusu) — GERCEKTEN one alindi.
      _Bolum('Yakınımda', [
        const Color(0xFF3AA9FF),
        const Color(0xFF6C2BD9),
      ], (c) => const YakinimdaEkrani()),
      // ⚠️⚠️ TURU 91 — IKI YENI KART **ILK IKI SIRADA** (kullanici emri:
      //    "dugun kategorisi ekle birde DIYET kategorisi ekle").
      //    Basa konmalarinin sebebi olculmus: 360x640'ta izgarada kaydirma
      //    yapmadan yalniz ILK IKI SATIR (6 kart) gorunuyor; yeni ozellikler
      //    KESFEDILEBILIR olmali.
      // ⚠️⚠️ TURU 96q — **DUGUN ile ORGANIZASYON AYRILDI** (kullanici emri:
      //	*"Düğün ve Organizasyonu ayır"*). Ikisi de AYNI ekrana gider
      //	(`TalepAkisiEkrani` = teklif iste): ayrim KULLANICININ ZIHNINDEKI
      //	ayrimdir — dugun eden ile kurumsal/organizasyon isi arayan ayni
      //	karta bakmak zorunda kalmasin.
      // ⚠️ Yeni EKRAN acilmadi: talep akisi zaten kategori agacini sunucudan
      //    cekip soruyor (turu 91).
      // ⚠️⚠️ TURU 114 — Dugun/Organizasyon artik **DAL PARAMETRESIYLE** aciliyor
      //	(kullanici emri: *"dugun kategorisi de yemek gibi olsun"* +
      //	*"dugun de step step olsun"*). Ekran yemek duzeninde bir KATEGORI
      //	IZGARASI cizer ve her hucre ADIM ADIM SIHIRBAZI acar.
      // ⚠️ Organizasyon da `dugun` dalina gider: sunucudaki talep kategorileri
      //    (`dugunKategorileri`) ikisini AYNI kumede tutuyor; ayri bir kume
      //    acmak sunucu tarafinda karsiligi olmayan bir ayrim uydurmak olurdu.
      _Bolum('Düğün', [
        const Color(0xFFFF6B9D),
        const Color(0xFFC2185B),
      ], (c) => const TalepAkisiEkrani(dal: 'dugun')),
      _Bolum('Organizasyon', [
        const Color(0xFFFF9A6B),
        const Color(0xFFC24A18),
      ], (c) => const TalepAkisiEkrani(dal: 'dugun')),
      _Bolum('Etkinlikler', [
        const Color(0xFF8B3FFF),
        const Color(0xFF5A1EBE),
      ], (c) => const EtkinlikListesiEkrani()),
      _Bolum('İlan', [
        const Color(0xFF2BB673),
        const Color(0xFF12805A),
      ], (c) => const IlanListesiEkrani()),
      // ⚠️⚠️⚠️ TURU 114 — "Hizmet" karti artik **HIZMET AL (adim adim)** ekranini
      //	aciyor (kullanici emri: *"hizmetler hizmet al step step olsun"*).
      //
      //	Onceden `IlanListesiEkrani(tur: 'hizmet')` — yani yayinlanmis hizmet
      //	ILANLARININ listesi — aciliyordu. Kullanicinin istedigi TERS YON:
      //	hizmet ARAYAN kisi bir form doldurup isletmelerden teklif alsin.
      //	O akis (`TalepSihirbaziEkrani`) ZATEN vardi ama yalnizca Dugun
      //	kartindan ulasilabiliyordu — hizmet dali pratikte KESFEDILEMEZDI.
      // ⚠️ Hizmet ILANLARI listesi ULASILAMAZ KALMADI: ayni ekranin sag ust
      //    kosesindeki "Taleplerim" ve "İlan" karti o listeyi tasiyor.
      _Bolum('Hizmet', [
        const Color(0xFF3AA9FF),
        const Color(0xFF12547A),
      ], (c) => const TalepAkisiEkrani(dal: 'hizmet')),
      // ⚠️ TURU 90 — kullanici emri: *"is ilani ve OTELLER KATEGORILERDE
      //    olmali"*. Ikisi de MEVCUT ekranlara baglanir, yeni ekran YOK:
      //    · İş İlanları -> `IlanListesiEkrani(tur: 'is')` ('Hizmetler'in
      //      birebir ayni kalibi; 'is' turu turu 90'da `ilan.Turler`e eklendi)
      //    · Oteller     -> `IsletmeListesiEkrani(kategori: 'otel')`
      //      ('Yemek'/'Sağlık' kartlariyla ayni kalip)
      _Bolum(
        'İş İlanları',
        [const Color(0xFF0EA5A5), const Color(0xFF0B5F63)],
        (c) => const IlanListesiEkrani(tur: 'is', baslik: 'İş İlanları'),
      ),
      _Bolum(
        'Otel',
        [const Color(0xFF6C7BFF), const Color(0xFF2A3390)],
        (c) => const IsletmeListesiEkrani(kategori: 'otel', baslik: 'Oteller'),
      ),
      _Bolum('Yemek', [
        const Color(0xFFFF7A45),
        const Color(0xFFFF3B5C),
      ], (c) => const IsletmeListesiEkrani(kategori: 'yemek', baslik: 'Yemek')),
      // ⚠️⚠️ TURU 96t — 'Restoran' ve 'Cafe' AYRI IKI KART (kullanici
      //	listesinde ikisi de var) ama **AYNI VERI KATEGORISINE** gider:
      //	veritabaninda tek bir `kafe` kategorisi var ve kafe ile restoran
      //	onun altinda. Ayri anahtar acmak, isletmelerin o alani YENIDEN
      //	doldurmasini gerektirirdi (turu 92'nin alt-kategori gerekcesi).
      _Bolum(
        'Restoran',
        [const Color(0xFFFF3B5C), const Color(0xFF8B1E3A)],
        (c) => const IsletmeListesiEkrani(kategori: 'kafe', baslik: 'Restoran'),
      ),
      _Bolum('Cafe', [
        const Color(0xFFC98A5B),
        const Color(0xFF7A4A22),
      ], (c) => const IsletmeListesiEkrani(kategori: 'kafe', baslik: 'Kafe')),
      // ⚠️⚠️ TURU 143 — **"Alışveriş" KARTI KALDIRILDI** (kullanici emri:
      //	*"alisveris kategorisini kaldir"*). Kart `kategori: 'market'`
      //	aciyordu; o kategori SUNUCUDA ve `isletmeKategorileri`nde
      //	DURUYOR ve haritadaki cip seridinden ("Market") hala ULASILABILIR
      //	— yani veri OLU KALMADI, yalnizca menudeki GIRIS kalkti.
      // ⚠️ YAPMA: bunu "olu kategori" diye `isletmeKategorileri`den ya da
      //    sunucudan silme; kayitli market isletmeleri var.
      // ⚠️ TURU 80 (kullanici emri: "bu alanda kategoriler eğitim ve sağlık ekle").
      //    Iki anahtar ZATEN sistemde: `isletmeKategorileri` (istemci) ve
      //    `isletme/handler.go` (sunucu) 'egitim'/'saglik' taniyor; ayrica
      //    `vitrin/handler.go` `isletmeDikeyleri` haritasinda da VARLAR, yani
      //    inis sayfasinin ust slider'i DOGRU calisir.
      //    ⚠️ MIGRATION GEREKMEZ: `isletmeler.kategori` sutununda CHECK YOK.
      _Bolum(
        'Eğitim',
        [const Color(0xFFEC4FA0), const Color(0xFF7B1E6A)],
        (c) => const IsletmeListesiEkrani(kategori: 'egitim', baslik: 'Eğitim'),
      ),
      _Bolum(
        'Sağlık',
        [const Color(0xFF17C3CE), const Color(0xFF0A5B78)],
        (c) => const IsletmeListesiEkrani(kategori: 'saglik', baslik: 'Sağlık'),
      ),
      // ⚠️ TURU 96v — 'Yapay zekâ' karti HIZLI ERISIME tasindi (GebzemAI).
    ];

    // ⚠️ TURU 90 — "Yakınımda" listeden AYRILIR: ustte tek basina cizilir.
    //    Listede de kalsaydi kullanici onu IKI KEZ gorurdu.
    // ⚠️⚠️ TURU 128 — artik ustte **YAKINIMDA SERIDI** var (Eczane/Bakkal/
    //	Akaryakit/Cami), yani ayri bir "Yakınımda" KARTI da gereksiz kaldi.
    //	Degisken KALDIRILDI; kart yalnizca kategoriler listesinden elenir.
    final kategoriler = bolumler.where((b) => b.ad != 'Yakınımda').toList();

    // ⚠️⚠️⚠️ TURU 96t — **SIRALAMA KULLANICI TARAFINDAN VERILDI**:
    //	*"Yemek Restorant Cafe Alışveriş Hizmet İlan Düğün Eğitim Sağlık
    //	Otel diye daha güzel ve sıralı şekilde"*.
    //
    // ⚠️ Siralama LISTENIN KENDISINDE degil BURADA yapilir: kart tanimlari
    //    (renk, hedef ekran, gerekce serhleri) yillardir o sirada duruyor
    //    ve tasinsalardi serhler kartlardan KOPARDI.

    // ⚠️ TURU 121 — Listede OLMAYAN kartlar (Organizasyon, Etkinlikler,
    //    İş İlanları) tanim sirasini KORUYARAK bunlarin ARDINA dizilir;
    //    yeni bir kart eklendiginde sessizce kaybolmaz, sona eklenir.
    // ⚠️ TURU 121 — "İşletmeler", "Topluluklar" ve "Diyet" kartlari
    //    KULLANICI EMRIYLE KALDIRILDI.
    //    · Topluluklar: kanallara giris KAYBOLMADI — Mesajlar ekranindaki
    //      "+" menusunde "Toplulukları keşfet" girisi VAR
    //      (`chats_screen.dart` -> `KanallarSayfasi`). Grep ile dogrulandi.
    //    · İşletmeler: parametresiz `IsletmeListesiEkrani()` (tum
    //      kategoriler) girisi kaldi. Sinif ULASILABILIR (gonderi
    //      detayindan `ara:` ile aciliyor) ama menuden "hepsine gozat"
    //      yolu YOK — kullanici karari.
    const sira = [
      'Yemek',
      'Restoran',
      'Cafe',
      // ⚠️ TURU 143 — 'Alışveriş' CIKARILDI (kart da kaldirildi).
      'Hizmet',
      'İlan',
      'Düğün',
      'Eğitim',
      'Sağlık',
      'Otel',
    ];
    final yerler = {
      for (var i = 0; i < kategoriler.length; i++) kategoriler[i].ad: i,
    };
    int agirlik(_Bolum b) {
      final i = sira.indexOf(b.ad);
      return i >= 0 ? i : 1000 + (yerler[b.ad] ?? 0);
    }

    kategoriler.sort((a, b) => agirlik(a).compareTo(agirlik(b)));

    // ⚠️⚠️ **EKLEME SIRALAMADAN SONRA** olmak ZORUNDA (emulatorde goruldu):
    //	ustteki  bilmedigi adlara 1000+ verir, yani ONCE
    //	eklenseydi GebzemAI ve Sosyal listenin **SONUNA** atilirdi —
    //	nitekim ilk denemede oyle oldu.
    // ⚠️ YAPMA: bu blogu un ustune tasima.
    // ⚠️⚠️⚠️ TURU 128 — **GebzemAI ve Sosyal KATEGORILERIN BASINDA**
    //	(kullanici emri: *"hizli erisimdeki GebzemAI ve Sosyal`i
    //	kategorilerin basina al"*).
    //
    //	Ikisi de bir ISLETME KATEGORISI DEGIL — biri yapay zeka ekrani,
    //	oteki akis sekmesi. Ama kullanicinin zihninde menudeki "gidilecek
    //	yerler" listesinin ilk iki maddesi bunlar; siralama urun karari.
    //
    // ⚠️⚠️ Bu iki giris asagidaki `hizli` listesinden CIKARILDI
    //	(`_sehirRehberi`): iki yerde ayni kart, "hangisine bassam"
    //	sorusu uretir ve turu 76b`de birebir bu yuzden ikinci FAB
    //	kaldirilmisti.
    // ⚠️ GebzemAI yalniz sunucuda AI ACIKSA cizilir (`aiAcik`):
    //    kapaliyken kart basildiginda 503 alinirdi — "olu ozellik".
    // ⚠️ SIRA: ONCE sekme yazilir, SONRA route kapatilir (turu 115).
    //    Ters sirada `HomeScreen` eski sekmesiyle bir kare cizer.
    kategoriler.insertAll(0, [
      if (aiAcik)
        _Bolum('GebzemAI', [
          const Color(0xFF00C2A8),
          const Color(0xFF00695C),
        ], (c) => const GebzemAiEkrani()),
      _Bolum.eylem(
        'Sosyal',
        [const Color(0xFF7A5CFF), const Color(0xFF3A2A8A)],
        (c) {
          aktifSekme.value = 0;
          Navigator.of(c).popUntil((r) => r.isFirst);
        },
      ),
    ]);

    // ⚠️⚠️⚠️ TURU 96q — **HIZLI ERISIM SATIRI** (kullanici emri: *"Yakınımda...
    //	onun da sagina nobetci, cilingir vs ekle"*). Yakinimda kucultulup
    //	yanina iki kart daha kondu; ucu de ESIT genislikte.
    //
    // ⚠️⚠️ **DURUST SINIR — "NOBETCI" VERISI YOK.** Bu projede nobetci eczane
    //	bilgisi HICBIR YERDE tutulmuyor (resmi kaynak + ayri entegrasyon
    //	ister; CLAUDE.md turu 89'da bilerek kapsam disi birakildi). Bu yuzden
    //	kart **"Eczaneler"** adiyla ve eczane kategorisini (mesafeye gore)
    //	acacak sekilde baglandi.
    // ⚠️ YAPMA: karta "Nöbetçi Eczane" yazip eczane listesi acma — kullanici
    //    kapali eczaneye gider ve bu, projenin en pahali hata sinifi olan
    //    "arayuz soz veriyor, veri yok" durumudur.
    // ⚠️⚠️ TURU 96t — HIZLI ERISIM **BES KART** (kullanici emri:
    //	*"Yakınımda, Nöbetçi Eczane, Durak, Taksi, Akaryakıt gibi"*).
    //
    // ⚠️⚠️⚠️ **DURUST SINIR — BU KARTLAR SADECE KAYITLI ISLETMEYI GOSTERIR.**
    //	Projede belediye/POI verisi YOK: nobetci eczane listesi, otobus
    //	duragi konumlari ve akaryakit istasyonu veritabani HICBIR YERDE
    //	tutulmuyor (resmi kaynak + ayri entegrasyon ister).
    //	Kartlar bu yuzden **ARAMA KISAYOLU** olarak baglandi: ilgili
    //	kategori acilir ve arama kutusuna terim GORUNUR sekilde yazilir.
    //	Kayitli isletme yoksa liste BOS doner — bu bir hata degil, verinin
    //	olmamasidir; kullanici da neyin arandigini kutuda GORUR.
    // ⚠️ YAPMA: bu kartlara sahte/gomulu liste yazma.
    final hizli = <_Bolum>[
      // ⚠️⚠️ TURU 128 — **GebzemAI ve Sosyal BURADAN KALDIRILDI**,
      //	kategorilerin BASINA tasindi (kullanici emri). Tanimlar
      //	`kategoriler.insertAll(0, ...)` icinde.
      // ⚠️ YAPMA: buraya geri ekleme — ayni giris iki yerde cizilirdi.
      // ⚠️ TURU 115 gerekcesi (Sosyal AKISI acar, aramayi DEGIL) tanimla
      //    birlikte `kategoriler.insertAll` blogunda korunuyor.
      // ⚠️⚠️ TURU 124 — **HIZLI ERISIM KARTLARI ARTIK HARITAYA GIDIYOR**
      //	(kullanici emri: *"hızlı erişimde GebzemAI ve Sosyal haricinde
      //	diğer kartlara tıkladığımızda Yakınımdaki haritaya gidecek"*).
      //
      //	Bu kartlarin ortak yani ACIL/ANLIK ihtiyac olmalari: eczane,
      //	taksi, akaryakit, durak. Bunlarda kullanicinin sorusu "hangileri
      //	var" DEGIL **"en yakini nerede"** — yani cevabi HARITA verir,
      //	liste degil.
      // ⚠️ `YakinimdaEkrani` `kategori` parametresini ZATEN aliyor
      //    (turu 92) — yeni ekran/uc GEREKMEDI.
      _Bolum('Nöbetçi Eczane', [
        const Color(0xFF20C997),
        const Color(0xFF0B7A5A),
      ], (c) => const YakinimdaEkrani(kategori: 'eczane')),
      // ⚠️⚠️ TURU 96y — SIRA **GEREKLILIGE GORE** (kullanici emri:
      //	*"olmasi gereken gerekliligie gore sirala"*). Ilk dokuz kisayol
      //	izgarada gorunur; gerisi 'Tümü' listesinden ulasilir.
      //	Taksi ve akaryakit acil ihtiyactir; DURAK ise verisi olmayan
      //	(kayitli isletme arayan) bir kisayol oldugu icin onlarin ARDINDA.
      _Bolum('Taksi', [
        const Color(0xFFFFC531),
        const Color(0xFFB88600),
      ], (c) => const YakinimdaEkrani(kategori: 'hizmet')),
      _Bolum('Akaryakıt', [
        const Color(0xFFFF7A45),
        const Color(0xFFB33A12),
      ], (c) => const YakinimdaEkrani(kategori: 'oto')),
      // ⚠️⚠️⚠️ TURU 150 - **DURAK MODU** (kullanici emri: *"girişte
      //	ilk ekranda durak dedigimde alt kisimda bana EN YAKIN
      //	DURAKLAR gorunmeli"*).
      // ⚠️⚠️ ONCEDEN `kategori: hizmet` ACIYORDU - yani "Durak"a
      //	dokunan kullanici TEMIZLIK/NAKLIYAT isletmelerini
      //	goruyordu. Durust olmayan bu esleme BITTI.
      _Bolum('Durak', [
        const Color(0xFF6C7BFF),
        const Color(0xFF2A3390),
      ], (c) => const YakinimdaEkrani(durakla: true)),
      // ⚠️⚠️ TURU 96x — BES YENI KISAYOL (kullanici: *"ekle bir seyler
      //	daha"*). Hepsi **ZATEN VAR OLAN** isletme kategorileridir
      //	(`isletmeKategorileri`): yeni ekran, yeni uc, yeni migration YOK.
      // ⚠️ YAPMA: buraya karsiligi olmayan bir baslik ekleme — kart
      //    gercek bir ekrana gitmiyorsa EKLENMEZ (turu 76b dersi).
      _Bolum('Kuaför', [
        const Color(0xFFEC4FA0),
        const Color(0xFF7B1E6A),
      ], (c) => const YakinimdaEkrani(kategori: 'kuafor')),
      _Bolum('Güzellik', [
        const Color(0xFFFF6B9D),
        const Color(0xFFB03060),
      ], (c) => const YakinimdaEkrani(kategori: 'guzellik')),
      _Bolum('Oto Servis', [
        const Color(0xFF6C7BFF),
        const Color(0xFF2A3390),
      ], (c) => const YakinimdaEkrani(kategori: 'oto')),
      _Bolum('Emlak', [
        const Color(0xFF17C3CE),
        const Color(0xFF0A5B78),
      ], (c) => const YakinimdaEkrani(kategori: 'emlak')),
      _Bolum('Spor', [
        const Color(0xFF2BB673),
        const Color(0xFF0E7A52),
      ], (c) => const YakinimdaEkrani(kategori: 'spor')),
    ];
    // ⚠️⚠️ TURU 128 — GebzemAI/Sosyal kategorilere tasinince eski siralama
    //	turetmesi (turu 96w: "Sosyal'in indeksinden") GECERSIZ kaldi.
    //
    // ⚠️⚠️⚠️ **YAKINIMDA SERIDIYLE TEKRAR EDENLER CIKARILDI** (emulatorde
    //	goruldu): ustteki YAKINIMDA bolumu Eczane/Bakkal/Akaryakit/Cami
    //	cizdigi icin ŞEHİR REHBERİ'nde duran **Yakınımda**, **Nöbetçi
    //	Eczane** ve **Akaryakıt** kartlari AYNI EKRANI aciyordu. Ayni
    //	sayfada ayni hedefe giden iki kart "hangisine bassam" sorusu
    //	uretir — turu 76b'de ikinci FAB birebir bu yuzden kaldirilmisti.
    // ⚠️ Eleme ADA gore yapilir: hedef ekran bir closure oldugu icin
    //    karsilastirilamaz, ayrica ad kullanicinin GORDUGU seydir.
    // ⚠️ `Oto Servis` KALDI: ayni kategoriye gitse de kullanicinin
    //    aradigi sey farkli (servis vs benzin) ve adi ayirt edici.
    const yakinimdaSeridi = {'Yakınımda', 'Nöbetçi Eczane', 'Akaryakıt'};
    final hizliTumu = hizli
        .where((b) => !yakinimdaSeridi.contains(b.ad))
        .toList();

    // ⚠️⚠️⚠️ TURU 96v — **SAYFANIN TAMAMI BIRLIKTE KAYAR** (kullanici emri:
    //	*"asagi inerken sadece kategoriler iniyor; komple asagi inmesi
    //	gerekiyor, slider dahil"*).
    //
    //	Onceki yapida govde bir `Column`du ve YALNIZ izgara `Flexible` icinde
    //	kaydiriliyordu; baslik, slider ve hizli erisim EKRANA CIVILIYDI.
    //	Artik hepsi ayni `CustomScrollView`in sliver'lari.
    // ⚠️ `SingleChildScrollView` + `shrinkWrap` SECILMEDI: o kurulum TUM
    //    kartlari HER KAREDE layout ettirir (turu 91 performans dersi).
    //    `SliverGrid` tembel kalir.
    // ⚠️ Yukseklik TAVANI (0.82) KALDIRILDI: sheet ZATEN ekranin %95'i
    //    (`FractionallySizedBox`, turu 96o). Ikinci tavan icerigi sikistirip
    //    altta olu bosluk birakiyordu.
    final etiketAlani = MediaQuery.textScalerOf(context).scale(14) * 1.15 * 2;
    final hucreBoy = kKesifKutu + 5 + etiketAlani;
    // ⚠️⚠️⚠️ TURU 129 — **ZEMIN GEBZEMAI ILE BIREBIR** (kullanici emri:
    //	*"arka plan rengini birebir aynisini yapmani istiyorum,
    //	mantigini"*). Siyah + alt ucta iki radyal mor parlama; bilesen
    //	`core/theme.dart` -> `AiZemin` (TEK KAYNAK, KOPYALANMADI —
    //	kopya kacinilmaz olarak drift ederdi).
    //
    // ⚠️⚠️ **`Theme` SARMALI ZORUNLU.** Menu simdiye kadar ACIK temadaydi:
    //	kart yuzeyi acik gri, yazilar SIYAH. Koyu zemine gecerken bunlar
    //	oldugu gibi birakilsaydi yazilar OKUNMAZDI (turu 115b: sohbet
    //	balonlari birebir ayni hatayla **1.23:1** olculmustu). Sarmal
    //	`brightness: dark` verir ve `onSurface` KENDILIGINDEN beyaza
    //	doner — alt bilesenler tek tek boyanmak zorunda kalmaz.
    // ⚠️ `scaffoldBackgroundColor: transparent`: zemin `AiZemin`e ait,
    //    ustune ikinci bir opak katman binmemeli.
    // ⚠️ `fontFamily` ACIKCA veriliyor: `ThemeData.dark()` SIFIRDAN
    //    kurulur ve uygulamanin Google Sans ayarini TASIMAZ (turu 127`de
    //    GebzemAI ekraninda birebir bu yasandi, yazi tipi degismisti).
    // ⚠️ YAPMA: sarmali kaldirip renkleri cagri yerlerine yazma.
    // ⚠️⚠️ TURU 129 — **DURUM CUBUGU IKONLARI ACIK** (emulatorde
    //	goruldu: siyah zemin + koyu ikon = saat/pil/sinyal GORUNMUYORDU).
    // ⚠️ Cikista otomatik geri doner: AnnotatedRegion yaprak dugumdur,
    //    ekran sokulunce ustteki deger yeniden gecerli olur (turu 85c).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: kAiZemin,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Theme(
        data: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: morLogo,
            brightness: Brightness.dark,
          ).copyWith(surface: kAiZemin),
          scaffoldBackgroundColor: Colors.transparent,
          textTheme: ThemeData.dark(
            useMaterial3: true,
          ).textTheme.apply(fontFamily: 'Google Sans'),
          primaryTextTheme: ThemeData.dark(
            useMaterial3: true,
          ).primaryTextTheme.apply(fontFamily: 'Google Sans'),
        ),
        child: AiZemin(
          // ⚠️⚠️⚠️ TURU 129 — **`Material` SARMALI ZORUNLU** (emulatorde
          //	goruldu: butun kart etiketleri — Eczane/Taksi/Sosyal/Yemek —
          //	zeminle KAYNASIP OKUNMAZ olmustu).
          //
          //	Sebep: `DefaultTextStyle`i `Material` saglar. Bu ekran bir
          //	`Scaffold`un ICINDE DEGIL (`Theme` > `AiZemin` > `SafeArea`),
          //	dolayisiyla yazi rengi USTTEKI route`un ACIK TEMASINDAN
          //	geliyordu: siyah yazi, siyah zemin.
          //	`Theme` sarmali `onSurface`i beyaza cevirir ama renk BELIRTMEYEN
          //	`Text`ler onu ancak bir `Material` uzerinden gorur.
          //
          // ⚠️ `MaterialType.transparency`: zemin `AiZemin`e ait; `canvas`
          //    olsaydi opak bir katman gradyani KAPATIRDI.
          // ⚠️ Turu 119`da acilis katmaninda BIREBIR ayni sinif yasanmisti
          //    (orada metin monospace + sari altcizgiyle cizilmisti).
          // ⚠️ YAPMA: bu sarmali kaldirma.
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              // ⚠️⚠️⚠️ TURU 135 — **`Builder` ZORUNLU** (denetimde OLCULDU).
              //
              //	`Theme.of` YALNIZCA ATA elemanlari gezer. Yukaridaki koyu
              //	`Theme` bu `build`in DONDURDUGU agacta, yani `build`in
              //	KENDI `context`i onun **USTUNDE** kaliyor. Alt cizerlere
              //	(`_slider` · `_kart` · `_yakinKart` · `_selamlama`) o
              //	context gecirildigi icin `Theme.of(...)` ekranin koyu
              //	semasini DEGIL, **uygulamanin acik/koyu temasini**
              //	cozuyordu.
              //
              //	OLCULDU (denetim, gecici widget testiyle cizilen renk
              //	okundu): uygulama ACIK temadayken slayt yuzeyi
              //	`#6C2BD9 @%12` -> `#110821`, zemin `#050308` ->
              //	**kontrast 1.056:1**. Bu projenin kendi olcutu turu
              //	115b'de 1,09:1 icin "fiilen gorunmuyordu" diyor. Yani
              //	acik temadaki kullanici 200 dp'lik BOS bir alan gorur ve
              //	turu 135'in emri ("slider bos olsun, sol sag scroll")
              //	OLU DOGARDI. Koyu temada 1.194:1 ile fark edilmiyordu.
              //	⚠️ Hata turu 129'dan beri LATENT'ti: o slot turu 130-134
              //	   boyunca OPAK bir fotograftı (mac karti), yuzey rengi
              //	   hic cizilmiyordu.
              //
              // ⚠️ YAPMA: `Builder`i kaldirip `build`in kendi `context`ini
              //    asagi gecirme; yeni bir cizer eklerken de BU context'i
              //    (govdedeki `context`) kullan.
              child: Builder(
                builder: (context) => CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ⚠️⚠️⚠️ TURU 112 — **GERI OKU KALDIRILDI** (kullanici emri:
                        //	*"acilan pencerede geri tusu ... olmasin"*).
                        //
                        // ⚠️ Kapanma yolu KAYBOLMADI: sayfa normal bir route ve
                        //    sistemin geri jesti/tusu calisir. Ayrica bir karta
                        //    dokunmak hedef ekrani ustune acar.
                        // ⚠️ YAPMA: geri okunu geri koyma.
                        const SizedBox(height: 10),
                        // ⚠️⚠️⚠️ TURU 129 — **"Gebzem" BASLIGI KALDIRILDI**,
                        //	yerine KISISEL SELAMLAMA (kullanici emri: *"Gebzem
                        //	yazisini kaldir, oraya Iyi Geceler, altina kisinin
                        //	ismi, ismin solunda daire icinde profil fotografi,
                        //	en sagda arama ikonu"*).
                        _selamlama(context, ref),
                        // ⚠️⚠️⚠️ TURU 148 — **HAVA + DOVIZ SERIDI: SOL-SAG
                        //	KAYDIRILIR ve dokununca ALTTAN CHART ACILIR**
                        //	(kullanici emri: *"hava durumu ve doviz SOL SAG
                        //	olsun, bunlara tikladiginda CHARTLAR ACILACAK
                        //	ALTTAN"*).
                        //	Turu 147'de serit aramanin YANINDA dar bir
                        //	kutucuktu; orada ne kaydirma ne chart sigardi.
                        _havaDovizSeridi(context),
                        const SizedBox(height: 12),
                        // ⚠️ Slider `Padding`in DISINDA: yan boslugu KENDI
                        //    `viewportFraction`indan uretir (turu 96t).
                        _slider(context),
                        const SizedBox(height: 14),
                        // ⚠️⚠️⚠️ TURU 128 — **"YAKINIMDA" SERIDI** (kullanici emri:
                        //	*"Sehir Rehberi`nin ustune Yakinimda olsun, orada Eczane
                        //	Bakkal Akaryakit Cami gorunsun, kart seklinde ufak kart"*).
                        //
                        // ⚠️⚠️ **DURUST SINIR — POI VERISI YOK.** Bu dortu de
                        //	`isletmeler` tablosundan beslenir, yani YALNIZ KAYITLI
                        //	ISLETMEYI gosterir. Belediye/harita POI verisi projede
                        //	HICBIR YERDE tutulmuyor (turu 96t karari).
                        //	· Eczane   -> `eczane` kategorisi (VAR)
                        //	· Bakkal   -> `market` kategorisi (VAR; bakkal onun icinde)
                        //	· Akaryakıt-> `oto` kategorisi (VAR)
                        //	· Cami     -> **KARSILIGI OLAN KATEGORI YOK** -> `diger`.
                        //	  Kayitli bir cami yoksa liste BOS doner; bu bir hata
                        //	  DEGIL, verinin olmamasidir.
                        // ⚠️ YAPMA: bu kartlara gomulu/sahte liste yazma.
                        // ⚠️ YAPMA: "Nöbetçi Eczane" yazip eczane listesi acma —
                        //    nobet verisi YOK, kullanici kapali eczaneye giderdi.
                        // ⚠️⚠️⚠️ TURU 134 — **"· ÖRNEK" EKI KALDIRILDI** (kullanici
                        //	emri: *"YAKINIMDA yanindaki ornegi sil"*).
                        //
                        //	Turu 132 denetimi bu eki, kartlar uydurma isletme adi
                        //	ve mesafe yazdigi icin koymustu. Kullanici gordu ve
                        //	KALDIRILMASINI istedi — karar ONUN.
                        // ⚠️⚠️ **UYARI YAPISAL OLARAK KAYBOLMADI:** `kYakinOnizleme`
                        //	bayragi DURUYOR ve yayindan once `false` YAPILACAK.
                        //	Ekranda ibare yokken bayragi ACIK birakmak, kullaniciya
                        //	uydurma veriyi UYARISIZ gostermek demektir.
                        _bolumBasligi('YAKINIMDA'),
                        const SizedBox(height: 10),
                        _yakinSerit(context, ref, [
                          _Bolum(
                            'Eczane',
                            [const Color(0xFF20C997), const Color(0xFF0B7A5A)],
                            (c) => const YakinimdaEkrani(kategori: 'eczane'),
                            mesafeKategorisi: 'eczane',
                            ikon: LucideIcons.pill,
                          ),
                          _Bolum(
                            'Bakkal',
                            [const Color(0xFFFFC531), const Color(0xFFB88600)],
                            (c) => const YakinimdaEkrani(kategori: 'market'),
                            mesafeKategorisi: 'market',
                            ikon: LucideIcons.shoppingBasket,
                          ),
                          _Bolum(
                            'Akaryakıt',
                            [const Color(0xFFFF7A45), const Color(0xFFB33A12)],
                            (c) => const YakinimdaEkrani(kategori: 'oto'),
                            mesafeKategorisi: 'oto',
                            ikon: LucideIcons.fuel,
                          ),
                          _Bolum(
                            'Cami',
                            [const Color(0xFF6C7BFF), const Color(0xFF2A3390)],
                            (c) => const YakinimdaEkrani(kategori: 'diger'),
                            // ⚠️⚠️ TURU 129 — kullanici **"hepsinde mesafe yaz"**
                            //	dedi; Cami de mesafe kategorisi aldi.
                            // ⚠️⚠️ **DURUST SINIR:** burada olculen sey EN YAKIN CAMI
                            //	DEGIL, `diger` kategorisindeki en yakin kayitli
                            //	isletmedir. Projede cami/POI verisi YOK ve
                            //	`isletmeler` tablosunda cami diye bir kategori de
                            //	yok. Kullaniciya soylendi; karar ONUN.
                            mesafeKategorisi: 'diger',
                            // ⚠️ Lucide'de cami glifi YOK; `landmark` en yakin notr
                            //    karsilik (dini bir sembol uydurulmadi).
                            ikon: LucideIcons.landmark,
                          ),
                        ]),
                        // ⚠️⚠️⚠️ TURU 135 — **"PİYASA" BOLUMU TAMAMEN KALDIRILDI**
                        //	(kullanici emri: *"piyasa verilerini kaldiralim,
                        //	gerek yok"*).
                        //
                        //	Turu 132-134'te burada dolar/euro/altin/bitcoin
                        //	seridi ve dokununca acilan grafikli panel vardi;
                        //	**HER SAYISI UYDURMAYDI** (projede kur/emtia verisi
                        //	ne tabloda ne bir ucta ne de bir dis servis
                        //	anahtarinda var). `kur_serit.dart` dosyasi da SILINDI.
                        // ⚠️ YAPMA: gercek bir kur kaynagi (uc + anahtar +
                        //    onbellek) baglanmadan buraya fiyat yazan hicbir
                        //    bilesen koyma — yanlis kura bakip islem yapan
                        //    kullanici PARA KAYBEDER.
                        const SizedBox(height: 18),
                        if (hizliTumu.isNotEmpty) ...[
                          // ⚠️⚠️⚠️ TURU 128 — **"HIZLI ERİŞİM" -> "ŞEHİR REHBERİ"**
                          //	ve **IKI SATIRLI SABIT IZGARA -> TEK SATIR YATAY
                          //	KAYDIRMA** (kullanici emri).
                          //
                          // ⚠️⚠️ 'Tümü' karti KALDIRILMADI, serit SONUNA kondu:
                          //	serit artik TUM kisayollari tasiyor (kaydirarak
                          //	hepsine ulasilir) ama kategorilere giden tek liste
                          //	girisi de KAYBOLMAMALI.
                          // ⚠️ YAPMA: eski 2 x 5 izgaraya donme — kullanici tek
                          //    satir istedi ve iki satir sayfanin yarisini yiyordu.
                          _bolumBasligi('ŞEHİR REHBERİ'),
                          const SizedBox(height: 10),
                          _ufakSerit(context, [
                            ...hizliTumu,
                            // ⚠️ 'Tümü' listesi HEM kisayollari HEM kategorileri
                            //    icerir: hicbir giris ULASILAMAZ kalmasin.
                            _tumuBolumu([...hizliTumu, ...kategoriler]),
                          ]),
                        ],
                        const SizedBox(height: 18),
                        _bolumBasligi('KATEGORİLER'),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: kIzgaraAralik,
                        mainAxisSpacing: kIzgaraAralik,
                        // ⚠️ Oran DEGIL sabit yukseklik: kart = gri kutu + 5 + iki
                        //    satirlik etiket (kategori ekraniyla birebir).
                        mainAxisExtent: hucreBoy,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _kart(context, kategoriler[i]),
                        childCount: kategoriler.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 96w — HIZLI ERISIMIN SONUNDAKI **"Tümü"** KARTI (kullanici
  ///	emri: *"en sonunda hepsi ya da tumu gibi bir sey olsun, tikladiginda
  ///	LISTE seklinde gelsin"*).
  ///
  /// ⚠️ Liste ekrani **AYNI `_Bolum` LISTESINDEN** beslenir: ikinci bir menu
  ///    tanimi yazilsaydi yeni bir kart eklendiginde biri guncellenip oteki
  ///    geride kalirdi (bu projede "ayni kuralin iki kopyasi drift eder"
  ///    sinifi ALTI kez sahaya cikti).
  _Bolum _tumuBolumu(List<_Bolum> hepsi) => _Bolum('Tümü', [
    const Color(0xFF8E8E93),
    const Color(0xFF4A4A4F),
  ], (c) => _TumuEkrani(bolumler: hepsi));

  /// Kart etiketi — kategori ekranindaki kesif kartiyla AYNI yazi (14/1.15/w600).
  Widget _etiket(String ad) => Text(
    ad,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 14,
      height: 1.15,
      fontWeight: FontWeight.w600,
    ),
  );

  /// ⚠️⚠️⚠️ TURU 135 — MENUNUN UST SLIDERI: **BOS YER TUTUCU KARUSEL.**
  ///
  ///	Kullanici emri: *"slider'daki mac olayini da kaldir, slider bos
  ///	olsun, sol sag scroll, 1-2 tane daha ekle"*.
  ///
  ///	Turu 130-134 boyunca burada `assets/vitrin/re1.jpg` uzerine yazilmis
  ///	UYDURMA bir mac skoru ("Türkiye 1 - 0 Almanya", "Arda Turan '20")
  ///	duruyordu ve dokununca ayni sekilde uydurma bir detay ekrani
  ///	aciliyordu. **IKISI DE SILINDI** (`skor_detay.dart` dosyasi ve
  ///	varligin kendisi dahil): projede mac verisi ne tabloda ne bir ucta
  ///	VAR; kalmasi, yayin oncesi kapatilmayi bekleyen ikinci bir "sahte
  ///	veri" borcuydu.
  ///
  /// ⚠️ Kategori ekranlariyla **AYNI BILESEN** (`KategoriSlider`): olcu,
  ///    yaricap, komsu kartin sarkma miktari ve kaydirma fizigi TEK
  ///    KAYNAKTAN gelir — kopyalanirsa drift eder.
  /// ⚠️ Slaytlarin ICI BOS: bilesen zaten metin CIZMIYOR (turu 95), alanlar
  ///    yalnizca `Slayt` sozlesmesini koruyor.
  /// ⚠️ `WidgetRef` parametresi KALDIRILDI: slider artik sunucudan hicbir
  ///    sey okumuyor (bkz. `kMenuSlaytAdedi`), duran bir parametre okuyucuyu
  ///    "burada bir istek var" sanmaya iterdi.
  Widget _slider(BuildContext context) => SizedBox(
    height: KategoriSlider.yukseklik,
    // ⚠️ TURU 129 — slider zemini kart yuzeyiyle AYNI FORMULDEN gelir
    //    (kullanici: *"kartlar vs sliderda rengi de"*).
    // ⚠️⚠️ TURU 135 — **YALNIZ OPAKLIK YUKSEK: 0.12 -> `kSlaytAlfa`.**
    //	Kartlarda ikon + etiket var, yani kutu solgun olsa bile bolum
    //	OKUNUYOR. Slaytin ICI ise TAMAMEN BOS (kullanici emri) — tek
    //	gorsel isaret dolgunun kendisi. 0.12'de olculen kontrast
    //	**1.19:1**, yani 200 dp'lik blok neredeyse gorunmuyordu.
    // ⚠️ Renk yine `kAiKartYuzey`ten TURETILIR (tek kaynak): marka moru
    //    degisirse slider da doner. ⚠️ YAPMA: buraya sabit hex yazma.
    child: KategoriSlider(
      slaytlar: _bosSlaytlar,
      yuzey: kAiKartYuzey(context, alfa: kSlaytAlfa),
    ),
  );

  /// ⚠️ **BIR KEZ** uretilir (`static final`): her `build`de yeni bir liste
  ///    kurulsaydi `KategoriSlider.didUpdateWidget` uzunlugu ayni gorup
  ///    islem yapmasa bile gereksiz cop uretirdik.
  /// ⚠️ Adet `kMenuSlaytAdedi`den TURETILIR — elle uc satir yazilsaydi sabit
  ///    degistiginde ikisi ayrisirdi (bu projede "ayni kuralin iki kopyasi
  ///    drift eder" sinifi ALTI kez sahaya cikti).
  static final List<Slayt> _bosSlaytlar = List<Slayt>.filled(
    kMenuSlaytAdedi,
    (baslik: '', alt: ''),
  );

  /// Hedef ekrani acar.
  ///
  /// ⚠️⚠️ TURU 106 — **MENU ARTIK POP EDILMEZ.** Sheet doneminde once
  ///	`pop` sonra `push` yapiliyordu; hedef ekrandan geri donen
  ///	kullanici menuyu bulamiyor, tek "geri" ile akisa dusuyordu.
  /// ⚠️ YAPMA: buraya tekrar `nav.pop()` ekleme.
  void _ac(BuildContext context, _Bolum b) {
    // ⚠️ TURU 115 — bolum ya EKRAN acar ya da bir EYLEM calistirir.
    final eylem = b.eylem;
    if (eylem != null) {
      eylem(context);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: b.ac!));
  }

  /// Kategori KARTI — izgara hucresi (kullanici emri: "eski halinin kucuk hali").
  ///
  /// ⚠️ IKON YOK (turu 76b kurali): kutu bir RENK GECISIDIR, yazi ALTINDA.
  /// ⚠️ `RepaintBoundary`: her kart kendi katmaninda cizilir; biri
  ///    degistiginde (dokunma dalgasi) DIGER 15 kart yeniden BOYANMAZ.
  ///    Turu 91 performans maddesi.
  /// ⚠️ [kutuBoy] verilmezse izgara olcusu (`kKesifKutu`). Hizli erisim
  ///    kartlari bunun **%80**'ini kullanir (turu 96w kullanici emri).
  /// ⚠️⚠️⚠️ TURU 129 — **SELAMLAMA SATIRI** (menunun yeni basligi).
  ///
  ///	[profil dairesi]  İyi Geceler / Mikail        [arama]
  ///
  /// ⚠️⚠️ **SELAMLAMA SAATTEN TURETILIR, SABIT DEGIL.** "İyi Geceler"
  ///	yazip birakmak gunun her saatinde ayni seyi soylerdi.
  /// ⚠️ Ad SUNUCUDAN gelir (`myProfileProvider`), UYDURULMAZ. Profil
  ///    henuz gelmediyse ya da ad bossa ikinci satir CIZILMEZ —
  ///    "Merhaba null" EKRANA CIKAMAZ.
  /// ⚠️ Yalniz ILK KELIME: "Ahmet Yılmaz" iki satiri asar.
  /// ⚠️⚠️ Avatar `Avatar` bilesenidir (tek kaynak): fotograf yoksa
  ///	HARF dairesine duser — menude ayri bir yer tutucu YAZILMADI.
  /// ⚠️ Arama ikonu `KesfetEkrani`i acar; alt menudeki "Ara" sekmesiyle
  ///    AYNI ekran, ikinci bir arama ekrani ACILMADI.
  /// ⚠️⚠️⚠️ TURU 147 — **HAVA DURUMU + DOVIZ SERIDI** (kullanici emri).
  ///
  /// ⚠️⚠️⚠️ **DEGERLER ORNEKTIR — GERCEK VERI YOK VE UYDURULMADI.**
  ///	Bu projede ne hava ne kur verisi var: tabloda yok, sunucuda uc yok,
  ///	bir dis servis anahtari yok. Turu 135'te `kur_serit.dart` **TAM BU
  ///	YUZDEN SILINMISTI** (*"her sayisi uydurmaydi"*).
  ///	Kullanici seridi ACIKCA geri istedi; bu yuzden:
  ///	  · degerlerin yaninda **"örnek"** ibaresi DURUYOR,
  ///	  · dokununca acilan sayfa verinin BAGLI OLMADIGINI soyluyor,
  ///	  · `kHavaDovizOnizleme` bayragi YAYIN ONCESI `false` yapilacak.
  /// ⚠️ YAPMA: "örnek" ibaresini kaldirma; sayilari "guncel" gibi sunma;
  ///    saatten/gunden turetip CANLI gorunmesini saglama.
  /// ⚠️⚠️⚠️ **DEGERLER ORNEKTIR — GERCEK VERI YOK VE UYDURULMADI.**
  ///	Bu projede ne hava ne kur verisi var: tabloda yok, sunucuda uc yok,
  ///	bir dis servis anahtari yok. Turu 135'te `kur_serit.dart` **TAM BU
  ///	YUZDEN SILINMISTI** (*"her sayisi uydurmaydi"*).
  ///	Kullanici seridi ACIKCA geri istedi; bu yuzden her kartta ve chart
  ///	sayfasinin basinda **"Örnek"** ibaresi DURUYOR ve
  ///	`kHavaDovizOnizleme` bayragi YAYIN ONCESI `false` yapilacak.
  /// ⚠️ YAPMA: "Örnek" ibaresini kaldirma; sayilari saatten/gunden
  ///    turetip CANLI gorunmesini saglama.
  static const _havaDovizKalemler = <({
    IconData ikon,
    String ad,
    String deger,
    String fark,
    bool arti,
    int renk,
    List<double> seri,
  })>[
    (
      ikon: LucideIcons.sun,
      ad: 'Gebze',
      deger: '24°',
      fark: 'Parçalı bulutlu',
      arti: true,
      renk: 0xFFFFC531,
      seri: [19, 20, 22, 23, 25, 26, 24, 23, 21, 20, 19, 18],
    ),
    (
      ikon: LucideIcons.dollarSign,
      ad: 'Dolar',
      deger: '43,20',
      fark: '%0,4',
      arti: true,
      renk: 0xFF2BB673,
      seri: [42.1, 42.3, 42.2, 42.6, 42.8, 42.7, 43.0, 43.1, 42.9, 43.2],
    ),
    (
      ikon: LucideIcons.euro,
      ad: 'Euro',
      deger: '47,05',
      fark: '%0,2',
      arti: false,
      renk: 0xFF3AA9FF,
      seri: [47.4, 47.3, 47.5, 47.2, 47.0, 47.1, 46.9, 47.0, 47.1, 47.05],
    ),
    (
      ikon: LucideIcons.coins,
      ad: 'Gram Altın',
      deger: '3.410',
      fark: '%0,9',
      arti: true,
      renk: 0xFFFF7A3C,
      seri: [3320, 3345, 3330, 3360, 3375, 3355, 3390, 3400, 3385, 3410],
    ),
  ];

  /// ⚠️⚠️⚠️ TURU 148 — **HAVA + DOVIZ SERIDI (SOL-SAG KAYDIRILIR).**
  ///
  /// ⚠️ Serit YALNIZ menude (`kAiZemin`, sabit siyah) ciziliyor ve menu
  ///    zorla koyu tema kuruyor; renkler ona gore secildi.
  Widget _havaDovizSeridi(BuildContext context) {
    if (!kHavaDovizOnizleme) return const SizedBox.shrink();
    final onRenk = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        // ⚠️ Yukseklik yazi olceginden TURETILIR: sabit dp olsaydi olcek
        //    1.3/2.0'da kart TASARDI (turu 121d dersi).
        height: (MediaQuery.textScalerOf(context).scale(13) * 1.25 * 2 + 30)
            .ceilToDouble(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
          itemCount: _havaDovizKalemler.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final k = _havaDovizKalemler[i];
            final renk = Color(k.renk);
            return Material(
              color: kAiKartYuzey(context),
              borderRadius: BorderRadius.circular(kYaricap(56)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _havaDovizChart(context, i),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(k.ikon, size: 16, color: renk),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            k.deger,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: onRenk,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            // ⚠️ DURUST ISARET: her kartta "Örnek".
                            '${k.ad} · Örnek',
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: onRenk.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 148 — **ALTTAN ACILAN CHART** (kullanici emri).
  ///
  /// Cizim `CustomPainter` ile yapilir; PAKET EKLENMEDI (turu 116b dersi:
  /// her yeni paket derleme yuzeyine risk ekler ve bu bir arayuz turu).
  // ⚠️⚠️ TURU 157 - **`static` YAPILDI** ki haritadaki "hava durumu"
  //	dugmesi de AYNI sheeti acabilsin. Govde zaten yalniz
  //	`_havaDovizKalemler` (static) ve `_CiziciCizer` kullaniyor,
  //	hicbir ornek uyesi YOK.
  // ⚠️⚠️ YAPMA: cagri yerine IKINCI bir "24°" tablosu yazma; bu
  //	projede kopyalanan sabit BES kez drift uretti.
  static void _havaDovizChart(BuildContext context, int i) {
    final k = _havaDovizKalemler[i];
    final renk = Color(k.renk);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: kAiZemin,
      builder: (c) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(k.ikon, size: 20, color: renk),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        k.ad,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      k.deger,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${k.arti ? "▲" : "▼"} ${k.fark}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: k.arti
                        ? const Color(0xFF2BB673)
                        : const Color(0xFFFF5E5E),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _CiziciCizer(seri: k.seri, renk: renk),
                  ),
                ),
                const SizedBox(height: 14),
                // ⚠️ DURUST SINIR: chart'in ALTINDA, kullanici grafigi
                //    gordukten HEMEN SONRA okusun.
                Text(
                  'Bu grafik ve değerler örnektir; henüz gerçek bir veri '
                  'kaynağına bağlı değil.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selamlama(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(myProfileProvider).valueOrNull;
    final tamAd = (profil?['name'] ?? '').toString().trim();
    final ad = tamAd.isEmpty ? '' : tamAd.split(RegExp(r'\s+')).first;
    final saat = DateTime.now().hour;
    final selam = saat < 5
        ? 'İyi Geceler'
        : saat < 12
        ? 'Günaydın'
        : saat < 18
        ? 'İyi Günler'
        : saat < 22
        ? 'İyi Akşamlar'
        : 'İyi Geceler';
    // ⚠️⚠️ TURU 130 — selamlamanin SAGINDA ikon (kullanici emri: *"İyi
    //	Geceler`in sagina ay ikonu koy"*).
    // ⚠️ Ikon da SAATTEN turetilir: gunduz "İyi Günler"in yaninda ay
    //    durmasi anlamsiz olurdu. Gece/aksam AY, sabah/oglen GUNES.
    // ⚠️ Lucide bir FONT`tur (glif) — `strokeWidth` YOKTUR.
    final selamIkon = (saat < 5 || saat >= 18)
        ? LucideIcons.moon
        : LucideIcons.sun;
    final onRenk = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, 6, 0),
      child: Row(
        children: [
          Avatar(
            ad: tamAd,
            mediaId: profil?['avatar_media_id'] as String?,
            avatarUrl: (profil?['avatar_url'] ?? '').toString(),
            cap: 42,
          ),
          const SizedBox(width: 11),
          // ⚠️ `Expanded` ZORUNLU: uzun bir ad arama ikonunu ekran
          //    disina iterdi.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚠️ `Row` + `Flexible`: uzun bir selamlama ikonu ekran
                //    disina itmesin.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        selam,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          // ⚠️ TURU 129 — 0.6 -> **0.78**: koyu zeminde
                          //    0.6 okunmuyordu (emulatorde goruldu).
                          color: onRenk.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      selamIkon,
                      size: 13,
                      color: onRenk.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                if (ad.isNotEmpty)
                  Text(
                    ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ara',
            icon: const Icon(LucideIcons.search, size: 22),
            // ⚠️⚠️⚠️ TURU 130 — **`Scaffold` SARMALI ZORUNLU** (kullanici:
            //	*"aramaya tikladigimda ekran patliyor"* — HAKLIYDI).
            //
            //	`KesfetEkrani` `Scaffold` DONDURMEZ: `HomeScreen`de bir
            //	SEKME olarak yasiyor ve Scaffold`u ORASI saglıyor. Tek
            //	basina push edilince (a) `Material` bulunamadigi icin
            //	`TextField` patliyor, (b) govdedeki `Column` SINIRSIZ
            //	yukseklik kisiti aliyor.
            // ⚠️ Ekranin KENDISI degistirilmedi: sekme olarak kullanimi
            //    AYNEN duruyor, eksik olan kabuk BURADA veriliyor.
            // ⚠️ Geri oku: ekranin kendi AppBar`i YOK (Instagram deseni,
            //    ustte arama kutusu var) — cikis yolu SART.
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(LucideIcons.arrowLeft),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    title: const Text('Ara'),
                  ),
                  body: const KesfetEkrani(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️ TURU 128 — bolum basliklari TEK KAYNAK. Uc yerde (YAKINIMDA /
  ///    ŞEHİR REHBERİ / KATEGORİLER) ayni stil kopyalanmisti; biri
  ///    degisince otekiler geride kalirdi.
  /// ⚠️ `letterSpacing` KULLANILMAZ (kullanici yasagi, turu 96u).
  Widget _bolumBasligi(String metin) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
    child: Text(
      metin,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
      ),
    ),
  );

  /// ⚠️⚠️⚠️ TURU 128 — **YAKINIMDA SERIDI: ICINDE AD + MESAFE OLAN KART**
  ///	(kullanici emri: *"yakinimdakiler kart tarzi olacak, icinde ismi
  ///	ne kadar yakinda o sekilde yazacak"*).
  ///
  ///	SEHIR REHBERI seridinden FARKLI: orada kutu BOS ve yazi ALTINDA;
  ///	burada yazi KUTUNUN ICINDE ve altinda mesafe var.
  ///
  /// ⚠️⚠️ Mesafe **GERCEK**: `yakinMesafeProvider` her kategorinin en
  ///	yakin isletmesini sunucudan olcer. Izin yoksa / konum yoksa /
  ///	o kategoride kayit yoksa **HICBIR SEY CIZILMEZ** — "0 m" ya da
  ///	tahmini bir sayi YAZILMAZ (turu 128 `mesafeMetni` kurali).
  /// ⚠️ Yukleme sirasinda da bos: bir yer tutucu ("... m") yaniltici
  ///    olurdu; kart mesafe gelince BUYUMEZ cunku yukseklik SABIT.
  Widget _yakinSerit(BuildContext context, WidgetRef ref, List<_Bolum> ogeler) {
    final sonuc = ref.watch(yakinMesafeProvider).valueOrNull;
    final olcek = MediaQuery.textScalerOf(context);
    // ⚠️ Yukseklik yazi olceginden TURETILIR: iki satir (ad + mesafe) +
    //    dolgu. Sabit dp olcek 1.3/2.0`da TASARDI.
    // ⚠️ Ikon dairesi 34 dp; iki satirlik yazi ondan kisa kalabilir,
    //    bu yuzden taban 34 + dikey dolgu (20).
    // ⚠️⚠️⚠️ **SATIR YUKSEKLIGI TAHMIN EDILMEZ, DAYATILIR.**
    //
    //	Once carpan 1.25, sonra 1.27 denendi ve IKISI DE TASTI (muhafiz
    //	testi olctu: **2.7 px**). Sebep: `height:` verilmemis bir `Text`in
    //	satir yuksekligi FONTUN metriginden gelir (ascent+descent+lineGap)
    //	ve o sayi tahmin edilen carpanlardan BUYUK cikiyordu.
    //
    // ⚠️ COZUM: iki `Text` de **`height: 1.2`** tasiyor; butce de AYNI
    //    sayidan turetiliyor. Artik olcu font degisse bile TUTAR —
    //    bagimlilik YAPISAL OLARAK kesildi.
    // ⚠️ +2 dp pay: `TextPainter` satir yuksekligini YUKARI yuvarlar
    //    (turu 121 dersi).
    // ⚠️ YAPMA: `Text`lerden `height`i kaldirma; kaldirirsan bu hesap
    //    yeniden TAHMINE doner ve tasma geri gelir.
    // ⚠️⚠️ TURU 134 — ad ile mesafe arasina **`kAdAra` (3 dp)** kondu
    //	(kullanici emri: *"400m isim arasindaki boslugu biraz arttir, cok
    //	yakinlar"*). Butce AYNI sabittan besleniyor — kartta 3, hesapta 0
    //	yazilsaydi olcek 1.3`te tekrar TASARDI.
    const kSatir = 1.2;
    final yazi =
        olcek.scale(14.5) * kSatir + kYakinAdAra + olcek.scale(12.5) * kSatir;
    final boy = (yazi > 34 ? yazi : 34.0) + 22.0;
    return SizedBox(
      height: boy,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
        physics: const BouncingScrollPhysics(),
        itemCount: ogeler.length,
        separatorBuilder: (_, _) => const SizedBox(width: kIzgaraAralik),
        itemBuilder: (_, i) {
          final b = ogeler[i];
          final km = b.mesafeKategorisi.isEmpty
              ? 0.0
              : (sonuc?.km[b.mesafeKategorisi] ?? 0.0);
          return _yakinKart(
            context,
            b,
            km,
            // ⚠️ `sonuc == null` = HENUZ YUKLENIYOR. O anda "Yakında yok"
            //    yazmak YANLIS olurdu; yukleme bitene kadar "Konumu aç"
            //    dali da yaniltici. Ucuncu bir hal: bos birak.
            yukleniyor: sonuc == null,
            konumVar: sonuc?.konumVar ?? false,
          );
        },
      ),
    );
  }

  /// ⚠️ Mesafe bicimi `IsletmeOzet.mesafeMetni` ile AYNI kuraldan
  ///    turetilir (1 km alti metre, ustu virgullu km) — iki yerde iki
  ///    farkli bicim ayni uygulamada tutarsizlik olurdu.
  /// ⚠️ `km <= 0` = BILINMIYOR -> bos.
  static String _kmMetni(double km) => km <= 0
      ? ''
      : (km < 1
            ? '${(km * 1000).round()} m'
            : '${km.toStringAsFixed(1).replaceAll('.', ',')} km');

  /// ⚠️ Kart genisligi EKRANDAN turetilir: iki bucuk kart sigar, ucuncusu
  ///    SARKAR — serit boylece kaydirilabildigini soyler.
  Widget _yakinKart(
    BuildContext context,
    _Bolum b,
    double km, {
    required bool yukleniyor,
    required bool konumVar,
  }) {
    // ⚠️⚠️ TURU 130 — ONIZLEME acikken kartta UYDURMA isletme adi ve
    //	mesafe yazar (bkz. `_kOnizlemeYakin`). Bayrak kapaninca gercek
    //	olcume doner.
    final onizleme = kYakinOnizleme ? _kOnizlemeYakin[b.ad] : null;
    final metin = _kmMetni(km);
    // ⚠️⚠️ **UC AYRI HAL, UC AYRI METIN** (denetim buldu: onceden hepsi
    //	"Konumu aç" diyordu ve konum ACIKKEN bile oyle kaliyordu).
    //	· yukleniyor       -> bos (yaniltici bir sey yazma)
    //	· konum yok        -> "Konumu aç"  (kullanicinin yapacagi is bu)
    //	· konum var, kayit yok -> "Yakında yok" (DURUST: o kategoride
    //	  konumlu kayitli isletme YOK; canli veride market/oto boyle)
    // ⚠️ SAHTE MESAFE YAZILMAZ.
    final altMetin = onizleme != null
        ? onizleme.mesafe
        : metin.isNotEmpty
        ? metin
        : yukleniyor
        ? ''
        : (konumVar ? 'Yakında yok' : 'Konumu aç');
    // ⚠️⚠️ TURU 142 — kart artik SABIT BEYAZ yazi kullaniyor (kullanici
    //	emri). Bu GUVENLI, cunku serit YALNIZ menude (`kAiZemin`, sabit
    //	siyah) ciziliyor. ⚠️ Serit acik zeminli bir ekrana tasinirsa yazi
    //	GORUNMEZ olur — o gun renk yine temadan turetilmeli (turu 115b).

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _ac(context, b),
        behavior: HitTestBehavior.opaque,
        child: Container(
          // ⚠️ TURU 134 — kullanici *"kartlarin genisligini biraz azalt"*
          //    dedi: bolen 2.1 -> **2.05** (bolen buyudukce kart DARALIR).
          // ⚠️⚠️ ILK DENEMEDE 2.25 YAZILMISTI ve denetim olctu: 360/375 dp'de
          //	ic alan 73,7 dp'ye dusuyor, DORT onizleme adinin DORDU DE
          //	kirpiliyordu ("Gül Eczane…"). Emulator 411 dp oldugu icin
          //	ORADA GORUNMUYORDU — turu 70b/98c dersinin tekrari.
          //	2.05 kur kartlariyla da AYNI bolen (iki serit alt alta).
          width:
              (MediaQuery.sizeOf(context).width -
                  kYanBosluk * 2 -
                  kIzgaraAralik * 2) /
              2.05,
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          decoration: BoxDecoration(
            // ⚠️ TURU 129 — yuzey artik GebzemAI`daki kendi mesaj
            //    balonumla AYNI (tek kaynak: `kAiKartYuzey`).
            color: kAiKartYuzey(context),
            borderRadius: BorderRadius.circular(kYaricap(60)),
          ),
          child: Row(
            children: [
              // ⚠️⚠️ TURU 142 — **IKON KALDIRILDI** (kullanici emri:
              //	*"yakinimdaki ikonlari kaldir"*). Kart artik yalniz AD +
              //	MESAFE tasiyor; `b.ikon` kaynak modelde DURUYOR (sehir
              //	rehberi seridi ve baska cagri yerleri onu kullanabilir).

              // ⚠️ `Expanded` ZORUNLU: "Akaryakıt" gibi uzun bir ad sabit
              //    genislikte TASARDI.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // ⚠️ Onizlemede UYDURMA isletme adi; normalde
                      //    kartin kendi adi ("Eczane", "Bakkal"...).
                      onizleme?.ad ?? b.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        // ⚠️ `height` ACIKCA verilir (asagidaki serhe bak).
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // ⚠️ TURU 134 — ad ile mesafe arasi (kullanici emri).
                    //    Ayni sabit `_yakinSerit` butcesinde de var.
                    const SizedBox(height: kYakinAdAra),
                    // ⚠️ Mesafe YOKSA satir HIC cizilmez ama kart yuksekligi
                    //    DEGISMEZ (serit disarida sabit yukseklikte) — veri
                    //    gelince kartlar ZIPLAMAZ.
                    // ⚠️⚠️ TURU 128 — alt satir **DAIMA** cizilir (kullanici:
                    //	*"altina mesafeleri de yazsana"*). Onceden mesafe
                    //	bilinmiyorken satir HIC cizilmiyordu ve kartlar
                    //	"yarim" duruyordu.
                    // ⚠️ SAHTE MESAFE YAZILMAZ: bilinmiyorsa SEBEBI yazilir
                    //    ("Konumu aç"). "0 m" ya da tahmini bir sayi
                    //    kullaniciya YANLIS BILGI olurdu.
                    Text(
                      altMetin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // ⚠️⚠️ TURU 134 — **MESAFE VURGU RENGINDE** (emulatorde
                      //	goruldu: 0.78 opak gri, koyu zeminde adin
                      //	yaninda SILIK kaliyordu ve kartin en degerli
                      //	bilgisi en gorunmez ogeydi — turu 117`deki "AI
                      //	kalan hakki" hatasinin ayni sinifi).
                      // ⚠️⚠️ Renk YALNIZ GERCEK BIR MESAFEYE verilir.
                      //	"Konumu aç" / "Yakında yok" bir DURUM metnidir,
                      //	veri DEGIL; onlari da vurguya boyamak kullaniciya
                      //	"burada bir olcu var" izlenimi verirdi.
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: (metin.isNotEmpty || onizleme != null)
                            ? FontWeight.w700
                            : FontWeight.w600,
                        // ⚠️⚠️ TURU 142 — kullanici emri: *"alttaki renkleri
                        //	de BEYAZ yap"*. Onceden kartin kendi vurgu
                        //	rengiydi (turu 134); artik iki dal da beyaz,
                        //	durum metni yalniz OPAKLIKLA ayrilir.
                        color: (metin.isNotEmpty || onizleme != null)
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 128 — **UFAK KART SERIDI** (tek satir, yatay kaydirma).
  ///
  ///	Kullanici emri: *"tek satir scroll olsun sol sag ... kart seklinde
  ///	ufak kart"*. Hem YAKINIMDA hem ŞEHİR REHBERİ bunu kullanir.
  ///
  /// ⚠️⚠️ Kart genisligi **EKRANDAN TURETILIR** (dort bucuk kart sigar),
  ///	sabit dp DEGIL: 360 dp`de sabit bir sayi ya cok genis ya cok dar
  ///	dururdu. Yarim kartin sarkmasi KASITLI — serit kaydirilabildigini
  ///	boyle soyler (nokta gostergesi ya da ok koymadan).
  /// ⚠️ Kutu orani izgarayla AYNI (`0.878`): iki farkli oran ayni ekranda
  ///    "bir yerde bozuk" hissi verirdi.
  /// ⚠️ Yukseklik yazi olceginden TURETILIR (`etiketAlani`), sabit dp
  ///    DEGIL: olcek 1.3/2.0`da iki satirlik etiket TASARDI.
  /// ⚠️ `ListView` cocuguna DIKEYDE TIGHT kisit verir; bu yuzden serit
  ///    `SizedBox` ile ACIK yukseklik alir (turu 121d dersi).
  /// ⚠️ Yan dolgu `padding`ten gelir, ilk/son kartin DISINDA — kartlar
  ///    kenara yapismaz ama kaydirma ekranin ucundan baslar.
  Widget _ufakSerit(BuildContext context, List<_Bolum> ogeler) {
    final etiketAlani = MediaQuery.textScalerOf(context).scale(14) * 1.15 * 2;
    return LayoutBuilder(
      builder: (c, bc) {
        final en = (bc.maxWidth - kYanBosluk * 2 - kIzgaraAralik * 4) / 4.5;
        final kutu = en * 0.878;
        return SizedBox(
          height: kutu + 5 + etiketAlani,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
            physics: const BouncingScrollPhysics(),
            itemCount: ogeler.length,
            separatorBuilder: (_, _) => const SizedBox(width: kIzgaraAralik),
            itemBuilder: (_, i) => SizedBox(
              width: en,
              child: _kart(context, ogeler[i], kutuBoy: kutu),
            ),
          ),
        );
      },
    );
  }

  Widget _kart(
    BuildContext context,
    _Bolum b, {
    double? kutuBoy,
  }) => RepaintBoundary(
    child: GestureDetector(
      onTap: () => _ac(context, b),
      // ⚠️ `opaque`: kutunun ALTINDAKI bosluga (yazi ile kutu arasi) dokunmak
      //    da karti acar; aksi halde kullanici "bastim acilmadi" der.
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚠️⚠️⚠️ TURU 96s — KUTU **KATEGORI EKRANININ KESIF KARTIYLA BIREBIR**
          //	(kullanici emri: *"yemekteki gibi renk ve yazi tipleri de oyle
          //	olsun"*): renkli gradyan DEGIL, `kYuzeyGri` yuzey + `kYaricap`.
          //	Sabitler ORADAN import edilir, kopyalanmaz.
          // ⚠️ YAPMA: buraya gradyan/ikon/harf geri koyma (kullanici kategori
          //    ekraninda kutu icine konan HER SEYI uc kez kaldirtti).
          SizedBox(
            height: kutuBoy ?? kKesifKutu,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kAiKartYuzey(context),
                borderRadius: BorderRadius.circular(
                  kYaricap(kutuBoy ?? kKesifKutu),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          // ⚠️⚠️ ETIKET ALANI **SABIT IKI SATIR** — kesif izgarasindaki formulun
          //	AYNISI. Icerige gore degisseydi "Organizasyon" gibi iki satira
          //	saran etiketler o hucreyi uzatir, `Row`/`GridView` yuksekligi
          //	en uzun hucreye gore olusur ve izgaranin alt sinirî DALGALANIRDI
          //	(turu 96k'da olculen hata).
          // ⚠️ Yukseklik yazi olceginden TURETILIR (sabit px DEGIL): kullanici
          //    yazi boyutunu buyutunce alan da buyur.
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(14) * 1.15 * 2,
            child: Center(
              // ⚠️⚠️⚠️ TURU 96v — COK KELIMELI AD **IKI SATIRA SARAR**
              //	(kullanici emri: *"Nöbetçi Eczane — 'eczane' altta olsun,
              //	yemekteki gibi"*). Kategori ekranindaki kesif kartlari da
              //	boyle davranir ('Yeni Restourant').
              // ⚠️ Kucultme (FittedBox) YALNIZ **BOSLUKSUZ** adlara
              //    uygulanir: 'Organizasyon' saracak yer bulamadigi icin
              //    kelimenin ORTASINDAN bolunuyordu ('Organizasyo/n').
              // TURU 96s - UZUN TEK KELIME KELIMENIN ORTASINDAN BOLUNMESIN.
              // 'Organizasyon' 86 dp'lik hucreye tek satirda sigmiyor ve
              // Flutter onu 'Organizasyo / n' diye BOLUYORDU (bosluksuz
              // kelimede sarma noktasi yok). FittedBox yalniz SIGMAYAN
              // etiketi bir tik kucultur; sigan etiketler 14 dp kalir.
              // ⚠️⚠️ **BOSLUKLU AD FittedBox'A HIC GIRMEZ.** `FittedBox`
              //    cocuguna SINIRSIZ genislik verir; icindeki `Text` bu yuzden
              //    SARAMAZ. Bosluklu adin iki satira sarabilmesi icin hucrenin
              //    SINIRLI genisligini gormesi sart.
              // ⚠️ YAPMA: iki dali tek `FittedBox`ta `fit` degistirerek
              //    birlestirme (`BoxFit.none` sarma degil TASMA verir).
              child: b.ad.contains(' ')
                  ? _etiket(b.ad)
                  : FittedBox(fit: BoxFit.scaleDown, child: _etiket(b.ad)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Bolum {
  _Bolum(
    this.ad,
    this.renkler,
    this.ac, {
    this.mesafeKategorisi = '',
    this.ikon,
  }) : eylem = null;

  /// ⚠️⚠️ TURU 115 — EKRAN ACMAYAN bolum (ornek: 'Sosyal' bir ALT MENU
  ///	SEKMESINE doner). Ayri bir kart bileseni YAZILMADI: gorunum ayni
  ///	kalmali, degisen yalnizca DOKUNUS DAVRANISI.
  /// ⚠️ Ikisinden TAM BIRI dolu olur; `_ac` bunu okur.
  _Bolum.eylem(this.ad, this.renkler, this.eylem)
    : ac = null,
      mesafeKategorisi = '',
      ikon = null;

  final String ad;
  final List<Color> renkler;

  /// ⚠️ HER BOLUM GERCEK BIR EKRANA GIDER. `null` (yakında) DESTEGI YOK —
  ///    ekran yoksa kart EKLENMEZ. (`eylem` dolu olan bolumlerde `null`.)
  final Widget Function(BuildContext)? ac;

  /// Ekran acmak yerine cagrilacak is (sekme degistirme gibi).
  final void Function(BuildContext)? eylem;

  /// ⚠️⚠️ TURU 128 — kartta **"ne kadar yakinda"** yazilacaksa hangi
  ///	isletme kategorisinin olculecegi. BOS ise mesafe CIZILMEZ.
  ///
  /// ⚠️⚠️ **"Cami" BILEREK BOS.** O kart `diger` kategorisini aciyor ve
  ///	o kategorideki en yakin kayit bir cami DEGIL, herhangi bir sey
  ///	olabilir — mesafeyi yazsaydik kullaniciya YANLIS BILGI vermis
  ///	olurduk. Projede cami/POI verisi YOK.
  /// ⚠️ YAPMA: buraya "yakinsa yakindir" diye `diger` yazma.
  final String mesafeKategorisi;

  /// ⚠️⚠️ TURU 128 — YAKINIMDA kartinin ikonu (kullanici emri: *"ikon
  ///	ekle ve biraz daha profesyonel yap"*).
  ///
  /// ⚠️ **YALNIZ YAKINIMDA SERIDINDE.** Kategori/Sehir Rehberi kartlari
  ///    IKONSUZ kalir — kullanici turu 76b`de kart icine ikon koymayi
  ///    ACIKCA reddetti (*"ikon YOK, kart altinda yazi sadece"*) ve o
  ///    karar bu turda DEGISMEDI. Buradaki kart FARKLI bir bilesendir:
  ///    yazi kutunun ICINDE ve altinda mesafe var.
  /// ⚠️ Lucide bir FONT`tur (glif) — `strokeWidth` YOKTUR.
  final IconData? ikon;
}

/// ⚠️⚠️⚠️ TURU 96w — **"Tümü" LISTESI** (kullanici emri: *"tikladiginda liste
///	seklinde gelsin"*).
///
///	Menudeki HER bolum burada tek sutunlu bir liste olarak gorunur. Kartlarda
///	ad kisadir ve kutu renksizdir; listede ise ad + KUCUK RENK NOKTASI vardir,
///	yani kullanici menude gordugu rengi burada da taniyabilir.
///
/// ⚠️ Bolum listesi DISARIDAN gelir (`bolumler`): bu ekran KENDI menusunu
///    TANIMLAMAZ. Aksi halde menuye eklenen yeni bir kart burada eksik kalir
///    ve fark ancak kullanici sikayet edince anlasilirdi.
class _TumuEkrani extends StatelessWidget {
  const _TumuEkrani({required this.bolumler});

  final List<_Bolum> bolumler;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tümü')),
    body: ListView.separated(
      itemCount: bolumler.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final b = bolumler[i];
        return ListTile(
          // ⚠️ Renk NOKTASI: menudeki kart renginin ta kendisi.
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: b.renkler),
            ),
          ),
          title: Text(
            b.ad,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          // ⚠️ Bu ekran bir ROUTE (sheet DEGIL): once pop etmeye gerek yok,
          //    hedef ekran bunun USTUNE push edilir ve geri tusu buraya
          //    doner.
          // ⚠️ TURU 115 — eylem tipli bolumler (or. Sosyal) burada da
          //    DOGRU davranmali; iki cagri yeri ayrisirsa "Tümü" listesinden
          //    dokunmak patlar ( null).
          onTap: () {
            final eylem = b.eylem;
            if (eylem != null) {
              eylem(context);
              return;
            }
            Navigator.of(context).push(MaterialPageRoute(builder: b.ac!));
          },
        );
      },
    ),
  );
}

/// Anasayfa AppBar'inin sol ustundeki hamburger dugmesi.
///
/// ⚠️⚠️⚠️ TURU 96n — MENUYU ACAN **TEK KAYNAK**.
///
///	Kullanici alt menudeki logoya dokununca da bu menunun acilmasini istedi
///	(*"alt menudeki logo tiklandiginda menu gelecek, anasayfada sol ustteki
///	hamburgere tikladigin gibi"*). Acma kodu `HamburgerDugmesi`nin ICINDE
///	gomuluydu; alt menuye KOPYALANSAYDI `isScrollControlled` gibi ayarlar
///	iki yerde yasar ve biri guncellenince oteki sessizce eskirdi (bu projede
///	"ayni kuralin iki kopyasi drift eder" sinifi ALTI kez sahaya cikti).
///
/// ⚠️ YAPMA: cagri yerlerinde dogrudan `showModalBottomSheet` yazma.
/// ⚠️⚠️⚠️ TURU 96o — PANEL **FILTRE PANELIYLE AYNI OLCUDE** (kullanici emri:
///	*"alttaki logoya bastigimda menu, filtre gibi genislik yukseklik ayni
///	olsun"*). Ucu de `isletme_filtre.dart`taki `isletmeFiltreAc` ile BIREBIR:
///	  · `isScrollControlled: true` — olmadan tavan ekranin 9/16'si olur ve
///	    izgaranin yarisi KIRPILIR,
///	  · genislik **%100** (`constraints` YAZILMAZ; varsayilan zaten tam
///	    genisliktir — `maxWidth` yazmak buyuk ekranda ORTALAR),
///	  · yukseklik **%95** (`FractionallySizedBox`), ust koseler **18** radius.
/// ⚠️ `useSafeArea` KULLANILMAZ: kullanilirsa yukseklik ekranin degil GUVENLI
///    ALANIN %95'i olur (turu 96b'de olculdu: %89,6).
/// ⚠️ Iki panel ayrisirsa kullanici farki ANINDA gorur; olculer degisecekse
///    IKISI BIRLIKTE degisir.
/// ⚠️⚠️⚠️ TURU 106 — MENU **TAM EKRAN** (kullanici emri: *"alttaki logoya
///	tikladigim menu tam ekran olacak, birde geri gelirken sikinti
///	yapiyor o ekran"*).
///
/// ═══════════ GERI DONUS NEDEN BOZUKTU ═══════════
///
/// Menu bir **alttan sayfa** (`showModalBottomSheet`) idi ve bir karta
/// dokununca `_ac` once sheet'i **POP** edip sonra hedef ekrani PUSH
/// ediyordu. Sonuc:
///   · kapanma animasyonu ile acilma animasyonu UST USTE biniyor,
///   · hedef ekrandan GERI donuldugunde menu ARTIK YOK — kullanici bir
///     anda akista buluyordu kendini. "Geri" bir adim degil IKI adim
///     geri gitmis gibi davraniyordu.
///
/// Artik menu NORMAL BIR ROUTE: kart `push` eder, geri tusu KATEGORIDEN
/// MENUYE, bir daha basinca akisa doner. Yigin ekranda gorunenle ayni.
/// ⚠️ YAPMA: bunu tekrar `showModalBottomSheet`e cevirme.
Future<void> hizmetMenusuAc(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const HizmetMenusuSayfasi()));

/// Menunun tam ekran kabugu.
///
/// ⚠️ AppBar'da BASLIK YOK: govdenin kendi basligi ("Gebzem · Şehrindeki
///    her şey") zaten var; ikisi birden ayni metni iki kez yazardi.
class HizmetMenusuSayfasi extends StatelessWidget {
  const HizmetMenusuSayfasi({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: HizmetMenusu());
}

/// ⚠️ IKI CIZGI (kullanici emri: "2 tane 2 satir cizgi hamburger tarzi").
///    Lucide'in `menu` ikonu UC cizgidir; bu yuzden ikon KULLANILMADI, iki
///    cizgi ELLE cizildi.
/// ⚠️ YAPMA: `LucideIcons.menu` koyma (uc cizgi olur).
class HamburgerDugmesi extends StatelessWidget {
  const HamburgerDugmesi({super.key});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).iconTheme.color;
    return IconButton(
      tooltip: 'Menü',
      onPressed: () => hizmetMenusuAc(context),
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cizgi(renk, 20),
          const SizedBox(height: 5),
          _cizgi(renk, 14),
        ],
      ),
    );
  }

  Widget _cizgi(Color? renk, double genislik) => Container(
    width: genislik,
    height: 2,
    decoration: BoxDecoration(
      color: renk,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}

/// ⚠️⚠️⚠️ TURU 128 — **YAKINIMDA KARTLARINDA GERCEK MESAFE** (kullanici
///	emri: *"yakinimdakiler kart tarzi olacak, icinde ismi ne kadar
///	yakinda o sekilde yazacak"*).
///
///	Her kategori icin **EN YAKIN** isletmenin mesafesini dondurur
///	(`{kategori: km}`).
///
/// ⚠️⚠️ **TEK ISTEK, DORT KART.** Kategori basina ayri cagri (4 istek)
///	yapilmadi: uc `kategori` bosken TUM yakindakileri **km ASC**
///	sirali donduruyor, yani her kategorinin ILK gorulen kaydi zaten
///	EN YAKINIDIR. Dort istek hem menu acilisini gecirir hem sunucuyu
///	gereksiz yorardi (turu 17 N+1 dersi).
///
/// ⚠️⚠️ **IZIN ISTENMEZ, YALNIZCA SORULUR.** `KonumServisi.konumAl()`
///	izin DIYALOGU acar; menuyu acar acmaz konum izni sormak sert bir
///	surtunme olurdu. Izin ZATEN verilmisse konum alinir, verilmemisse
///	mesafe HIC gosterilmez (kartlar yine calisir).
///
/// ⚠️ Hata/izinsiz/konumsuz durumda **BOS HARITA** doner ve kartta
///    hicbir sey cizilmez — "0 m" ya da tahmini bir sayi YAZILMAZ.
///    (`IsletmeOzet.mesafeMetni` de ayni kurali uyguluyor.)
/// ⚠️ `autoDispose`: menu kapaninca birakilir, bir sonraki acilista
///    TAZE olculur — kullanici baska bir semte gitmis olabilir.
/// ⚠️⚠️⚠️ TURU 129 — **`konumVar` AYRI DONER** (denetim buldu).
///
///	Onceden yalniz `Map` donuyordu ve BOS harita IKI FARKLI seyi
///	aniniyordu: (a) konum alinamadi, (b) konum alindi ama o
///	kategoride yakinda KAYIT YOK. Kart ikisine de "Konumu aç"
///	diyordu — konum ACIKKEN bile. Kullanici Ayarlar`a gidip konumun
///	zaten acik oldugunu goruyor, geri donuyor, kart yine ayni seyi
///	soyluyordu.
/// ⚠️ Iki durum artik AYRI metin uretir ("Konumu aç" / "Yakında yok").
typedef YakinSonuc = ({bool konumVar, Map<String, double> km});

final yakinMesafeProvider = FutureProvider.autoDispose<YakinSonuc>((ref) async {
  // ⚠️ `status` OKUR, `request` ETMEZ: ikincisi diyalog acardi.
  if (!await Permission.locationWhenInUse.isGranted) {
    return (konumVar: false, km: <String, double>{});
  }
  final k = await KonumServisi.konumAl(sessiz: true);
  if (k == null) return (konumVar: false, km: <String, double>{});
  final liste = await ref
      .read(isletmeServisiProvider)
      .yakinimda(enlem: k.enlem, boylam: k.boylam, km: 15);
  final en = <String, double>{};
  for (final i in liste) {
    // ⚠️ Liste km ASC sirali: ilk gorulen EN YAKINDIR, sonrakiler
    //    yazilmaz.
    if (i.km > 0) en.putIfAbsent(i.kategori, () => i.km);
  }
  return (konumVar: true, km: en);
});

/// ⚠️⚠️⚠️ TURU 130 — **YAKINIMDA ONIZLEME VERISI** (kullanici emri:
///	*"simdilik yakinimdakilere sahte isimler yaz, Gül Eczanesi 400 m
///	gibi"*).
///
/// ⚠️⚠️⚠️ **BU VERI UYDURMADIR.** Ne bu isletmeler ne bu mesafeler
///	gercektir; hicbiri sunucudan gelmez. Amac YALNIZCA kartin dolu
///	halinin nasil durdugunu gormek.
///
/// ⚠️⚠️ **`kYakinOnizleme = false` YAPILINCA TAMAMEN DEVRE DISI KALIR**
///	ve kartlar gercek olcume doner (izin varsa mesafe, yoksa
///	"Konumu aç", kayit yoksa "Yakında yok").
/// ⚠️ Karta dokunmak GERCEK ekrani acar — onizleme yalniz ETIKETI
///    degistirir, hedefi DEGISTIRMEZ. Yani kullanici uydurma bir
///    isletme sayfasina DUSMEZ.
/// ⚠️ Anahtar kart ADIDIR (`_Bolum.ad`), kategori degil: Cami`nin
///    kategorisi `diger` ve o kategoriye baska kartlar da baglanabilir.
const _kOnizlemeYakin = <String, ({String ad, String mesafe})>{
  'Eczane': (ad: 'Gül Eczanesi', mesafe: '400 m'),
  'Bakkal': (ad: 'Şen Market', mesafe: '250 m'),
  'Akaryakıt': (ad: 'Petrol Ofisi', mesafe: '1,2 km'),
  'Cami': (ad: 'Merkez Camii', mesafe: '650 m'),
};

/// ⚠️⚠️⚠️ TURU 148 — **ORNEK CIZGI GRAFIGI** (kullanici emri: *"tikladiginda
///	chartlar acilacak alttan"*).
///
/// ⚠️ Harici PAKET EKLENMEDI: `CustomPainter` ile ciziliyor. Turu 116b
///    dersi — her yeni paket derleme yuzeyine risk ekler ve bu bir arayuz
///    turu; grafik ihtiyaci tek bir cizgi ve dolgudan ibaret.
/// ⚠️ Seri ORNEKTIR (bkz. `_havaDovizKalemler` serhi); grafigin ALTINDA
///    kullaniciya ACIKCA soyleniyor.
class _CiziciCizer extends CustomPainter {
  const _CiziciCizer({required this.seri, required this.renk});

  final List<double> seri;
  final Color renk;

  @override
  void paint(Canvas canvas, Size size) {
    if (seri.length < 2) return;
    var enAz = seri.first;
    var enCok = seri.first;
    for (final d in seri) {
      if (d < enAz) enAz = d;
      if (d > enCok) enCok = d;
    }
    // ⚠️ Sifira bolme kapisi: duz bir seride `enCok - enAz == 0` olur.
    final aralik = (enCok - enAz).abs() < 0.0001 ? 1.0 : enCok - enAz;
    // ⚠️ Ust/alt 10 dp pay: cizgi kutunun kenarina yapismasin.
    const pay = 10.0;
    final h = size.height - pay * 2;
    Offset nokta(int i) => Offset(
          size.width * (i / (seri.length - 1)),
          pay + h - ((seri[i] - enAz) / aralik) * h,
        );

    final yol = Path()..moveTo(nokta(0).dx, nokta(0).dy);
    for (var i = 1; i < seri.length; i++) {
      yol.lineTo(nokta(i).dx, nokta(i).dy);
    }

    // Dolgu (cizginin altinda solan bir alan).
    final dolgu = Path.from(yol)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      dolgu,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [renk.withValues(alpha: 0.28), renk.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      yol,
      Paint()
        ..color = renk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Son nokta vurgusu.
    final son = nokta(seri.length - 1);
    canvas.drawCircle(son, 4.5, Paint()..color = renk);
    canvas.drawCircle(son, 2.0, Paint()..color = kAiZemin);
  }

  @override
  bool shouldRepaint(_CiziciCizer eski) =>
      eski.renk != renk || !identical(eski.seri, seri);
}

/// ⚠️⚠️⚠️ TURU 157 - **HAVA/DOVIZ GRAFIGINE TEK GIRIS.**
///
///	Kullanici emri: *"- altina SADECE HAVA DURUMUNU koy"*.
///	Haritadaki dugme bu fonksiyonu cagirir; anasayfadaki serit de
///	ayni govdeyi kullanir. Ikinci bir kopya YOK.
///
/// ⚠️⚠️ **DEGERLER ORNEKTIR.** Projede hava tablosu, sunucu ucu ve dis
///	servis anahtari YOK. Acilan sheet'in EN ALTINDAKI
///	*"Bu grafik ve değerler örnektir"* cumlesi bu yuzden ZORUNLU
///	ve kaldirilamaz.
/// ⚠️⚠️ YAPMA: bunu `kHavaDovizOnizleme` kapisi OLMADAN cagirma -
///	bayrak false olunca giris de kaybolmali.
/// ⚠️ `i = 0` HAVA; 1-4 doviz/altin.
void havaDovizChartAc(BuildContext context, {int kalem = 0}) =>
    _HizmetMenusuState._havaDovizChart(context, kalem);

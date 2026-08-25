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
///      Yemek/Restoran/Alışveriş → IsletmeListesiEkrani(kategori: ...)
///      Yapay zekâ  → AiDanismaEkrani (YALNIZ sunucuda AI aciksa)
///    ⚠️ YAPMA: bir karti "yakında" haline geri dondurme; ekran yoksa karti
///       EKLEME.
///
/// ⚠️ DUZEN: 12 bolum (AI acikken 12, kapaliyken 11), 3 SUTUNLU IZGARA.
///    Tek satirlik Row 4. kartta
///    RenderFlex overflow verirdi (turu 60/62 dersi). Sheet KAYDIRILABILIR
///    (`isScrollControlled` + yukseklik tavani) — kucuk ekranda tasmasin.
/// ⚠️ TURU 96q — MENUNUN SLIDER VERISI. Kategori ekraninin kullandigi
///    `/isletme-kesif` ucunun **VARSAYILAN** (kategorisiz) slayt seti.
/// ⚠️ `autoDispose` DEGIL: menu her acilista yeniden istek atmasin — slayt
///    metinleri sunucuda sabit ve nadiren degisir.
final _menuSlaytProvider = FutureProvider<List<Slayt>>((ref) async {
  final d = await ref.read(isletmeServisiProvider).kesif('');
  return d.slaytlar;
});

class HizmetMenusu extends ConsumerStatefulWidget {
  const HizmetMenusu({super.key});

  @override
  ConsumerState<HizmetMenusu> createState() => _HizmetMenusuState();
}

class _HizmetMenusuState extends ConsumerState<HizmetMenusu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dalga;

  @override
  void initState() {
    super.initState();
    _dalga = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dalga.dispose();
    super.dispose();
  }

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
      _Bolum(
        'Alışveriş',
        [const Color(0xFF7A5CFF), const Color(0xFF3A2A8A)],
        (c) =>
            const IsletmeListesiEkrani(kategori: 'market', baslik: 'Alışveriş'),
      ),
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
      'Alışveriş',
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
      _Bolum(
        'Nöbetçi Eczane',
        [const Color(0xFF20C997), const Color(0xFF0B7A5A)],
        (c) => const YakinimdaEkrani(kategori: 'eczane'),
      ),
      // ⚠️⚠️ TURU 96y — SIRA **GEREKLILIGE GORE** (kullanici emri:
      //	*"olmasi gereken gerekliligie gore sirala"*). Ilk dokuz kisayol
      //	izgarada gorunur; gerisi 'Tümü' listesinden ulasilir.
      //	Taksi ve akaryakit acil ihtiyactir; DURAK ise verisi olmayan
      //	(kayitli isletme arayan) bir kisayol oldugu icin onlarin ARDINDA.
      _Bolum(
        'Taksi',
        [const Color(0xFFFFC531), const Color(0xFFB88600)],
        (c) => const YakinimdaEkrani(kategori: 'hizmet'),
      ),
      _Bolum(
        'Akaryakıt',
        [const Color(0xFFFF7A45), const Color(0xFFB33A12)],
        (c) => const YakinimdaEkrani(kategori: 'oto'),
      ),
      _Bolum(
        'Durak',
        [const Color(0xFF6C7BFF), const Color(0xFF2A3390)],
        (c) => const YakinimdaEkrani(kategori: 'hizmet'),
      ),
      // ⚠️⚠️ TURU 96x — BES YENI KISAYOL (kullanici: *"ekle bir seyler
      //	daha"*). Hepsi **ZATEN VAR OLAN** isletme kategorileridir
      //	(`isletmeKategorileri`): yeni ekran, yeni uc, yeni migration YOK.
      // ⚠️ YAPMA: buraya karsiligi olmayan bir baslik ekleme — kart
      //    gercek bir ekrana gitmiyorsa EKLENMEZ (turu 76b dersi).
      _Bolum(
        'Kuaför',
        [const Color(0xFFEC4FA0), const Color(0xFF7B1E6A)],
        (c) => const YakinimdaEkrani(kategori: 'kuafor'),
      ),
      _Bolum(
        'Güzellik',
        [const Color(0xFFFF6B9D), const Color(0xFFB03060)],
        (c) => const YakinimdaEkrani(kategori: 'guzellik'),
      ),
      _Bolum(
        'Oto Servis',
        [const Color(0xFF6C7BFF), const Color(0xFF2A3390)],
        (c) => const YakinimdaEkrani(kategori: 'oto'),
      ),
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
        colorScheme:
            ColorScheme.fromSeed(
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
        dalga: _dalga,
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
            child: CustomScrollView(
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
                const SizedBox(height: 12),
                // ⚠️ Slider `Padding`in DISINDA: yan boslugu KENDI
                //    `viewportFraction`indan uretir (turu 96t).
                _slider(context, ref),
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

  /// Menunun ust slider'i — kategori ekraniyla **AYNI BILESEN**.
  ///
  /// ⚠️ Veri gelmeden ya da bos donunce **HICBIR SEY cizilmez** (bos gri kutu
  ///    yerine hic yer kaplamamak: turu 93b'de kesif istegi patlayinca ekranin
  ///    tepesinde 350px bos gri kutu kalmasi bulgusuydu).
  Widget _slider(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_menuSlaytProvider).valueOrNull ?? const [];
    if (s.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: KategoriSlider.yukseklik,
      // ⚠️ TURU 129 — slider zemini de kart yuzeyiyle AYNI (kullanici:
      //    *"kartlar vs sliderda rengi de"*).
      child: KategoriSlider(slaytlar: s, yuzey: kAiKartYuzey(context)),
    );
  }

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
                Text(
                  selam,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: onRenk.withValues(alpha: 0.6),
                  ),
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const KesfetEkrani(),
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
  Widget _yakinSerit(
    BuildContext context,
    WidgetRef ref,
    List<_Bolum> ogeler,
  ) {
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
    const kSatir = 1.2;
    final yazi = olcek.scale(14.5) * kSatir + olcek.scale(12.5) * kSatir;
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
    final metin = _kmMetni(km);
    // ⚠️⚠️ **UC AYRI HAL, UC AYRI METIN** (denetim buldu: onceden hepsi
    //	"Konumu aç" diyordu ve konum ACIKKEN bile oyle kaliyordu).
    //	· yukleniyor       -> bos (yaniltici bir sey yazma)
    //	· konum yok        -> "Konumu aç"  (kullanicinin yapacagi is bu)
    //	· konum var, kayit yok -> "Yakında yok" (DURUST: o kategoride
    //	  konumlu kayitli isletme YOK; canli veride market/oto boyle)
    // ⚠️ SAHTE MESAFE YAZILMAZ.
    final altMetin = metin.isNotEmpty
        ? metin
        : yukleniyor
        ? ''
        : (konumVar ? 'Yakında yok' : 'Konumu aç');
    // ⚠️⚠️ Yazi rengi TEMADAN: `kYuzeyGri` koyu temada KOYU bir yuzey
    //	doner ve sabit `Colors.black` orada OKUNMAZDI (turu 115b dersi:
    //	"bir zemin rengini degistirirken, o zemine gore secilmis ON PLAN
    //	renklerini de ara").
    final onRenk = Theme.of(context).colorScheme.onSurface;
    // ⚠️ Ikon dairesi kartin KENDI renginden: dort kart yan yana durdugunda
    //    ayirt edilebilir olsun. Zemin %14 opaklikta — ikonun kendisi tam
    //    renkte, daire soluk.
    final vurgu = b.renkler.first;
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _ac(context, b),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width:
              (MediaQuery.sizeOf(context).width -
                  kYanBosluk * 2 -
                  kIzgaraAralik * 2) /
              2.1,
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          decoration: BoxDecoration(
            // ⚠️ TURU 129 — yuzey artik GebzemAI`daki kendi mesaj
            //    balonumla AYNI (tek kaynak: `kAiKartYuzey`).
            color: kAiKartYuzey(context),
            borderRadius: BorderRadius.circular(kYaricap(60)),
          ),
          child: Row(
            children: [
              // ── IKON ──
              if (b.ikon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: vurgu.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(b.ikon, size: 18, color: vurgu),
                ),
                const SizedBox(width: 9),
              ],
              // ⚠️ `Expanded` ZORUNLU: "Akaryakıt" gibi uzun bir ad sabit
              //    genislikte TASARDI.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        // ⚠️ `height` ACIKCA verilir (asagidaki serhe bak).
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: onRenk.withValues(alpha: metin.isEmpty ? 0.4 : 0.55),
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
            separatorBuilder: (_, _) =>
                const SizedBox(width: kIzgaraAralik),
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
      separatorBuilder: (_, __) => const Divider(height: 1),
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
Future<void> hizmetMenusuAc(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const HizmetMenusuSayfasi()),
    );

/// Menunun tam ekran kabugu.
///
/// ⚠️ AppBar'da BASLIK YOK: govdenin kendi basligi ("Gebzem · Şehrindeki
///    her şey") zaten var; ikisi birden ayni metni iki kez yazardi.
class HizmetMenusuSayfasi extends StatelessWidget {
  const HizmetMenusuSayfasi({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: HizmetMenusu(),
  );
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

final yakinMesafeProvider = FutureProvider.autoDispose<YakinSonuc>(
  (ref) async {
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
  },
);

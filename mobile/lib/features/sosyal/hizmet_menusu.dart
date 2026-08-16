import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../etkinlik/etkinlik_ekranlari.dart';
import '../kanal/kanallar_sekmesi.dart' show KanallarSayfasi;
import '../ilan/ilan_ekranlari.dart';
import '../isletme/isletme_listesi.dart';
import '../isletme/yakinimda_ekrani.dart';
import '../isletme/urun_ekranlari.dart' show AiDanismaEkrani;
import '../isletme/urun_servisi.dart' show aiDurumProvider;
import '../diyet/diyet_ekranlari.dart';
import '../talep/talep_ekranlari.dart';
import 'kesfet_ekrani.dart';
import '../isletme/kategori_slider.dart';
import '../isletme/isletme_servisi.dart' show isletmeServisiProvider;
// ⚠️⚠️⚠️ TURU 96s — MENU KARTLARI **KATEGORI EKRANIYLA AYNI DILDE** (kullanici
//	emri: *"kartlarin genisliklerini diyorum, yemekteki gibi; renk ve yazi
//	tipleri de oyle olsun"*). Olcu/renk/yazi sabitleri BURADAN alinir,
//	KOPYALANMAZ — iki ekran birlikte doner.
import '../isletme/isletme_kart.dart'
    show kYanBosluk, kYaricap, kYuzeyGri;
import '../isletme/isletme_listesi.dart' show kKesifKutu, kIzgaraAralik;

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
class HizmetMenusu extends ConsumerWidget {
  const HizmetMenusu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      _Bolum('Düğün', [
        const Color(0xFFFF6B9D),
        const Color(0xFFC2185B),
      ], (c) => const TalepAkisiEkrani()),
      _Bolum('Organizasyon', [
        const Color(0xFFFF9A6B),
        const Color(0xFFC24A18),
      ], (c) => const TalepAkisiEkrani()),
      _Bolum('Diyet', [
        const Color(0xFF2BB673),
        const Color(0xFF0E7A52),
      ], (c) => const DiyetimEkrani()),
      _Bolum('Etkinlikler', [
        const Color(0xFF8B3FFF),
        const Color(0xFF5A1EBE),
      ], (c) => const EtkinlikListesiEkrani()),
      _Bolum('İlan', [
        const Color(0xFF2BB673),
        const Color(0xFF12805A),
      ], (c) => const IlanListesiEkrani()),
      _Bolum('Hizmet', [
        const Color(0xFF3AA9FF),
        const Color(0xFF12547A),
      ], (c) => const IlanListesiEkrani(tur: 'hizmet', baslik: 'Hizmetler')),
      // ⚠️ TURU 90 — kullanici emri: *"is ilani ve OTELLER KATEGORILERDE
      //    olmali"*. Ikisi de MEVCUT ekranlara baglanir, yeni ekran YOK:
      //    · İş İlanları -> `IlanListesiEkrani(tur: 'is')` ('Hizmetler'in
      //      birebir ayni kalibi; 'is' turu turu 90'da `ilan.Turler`e eklendi)
      //    · Oteller     -> `IsletmeListesiEkrani(kategori: 'otel')`
      //      ('Yemek'/'Sağlık' kartlariyla ayni kalip)
      _Bolum('İş İlanları', [
        const Color(0xFF0EA5A5),
        const Color(0xFF0B5F63),
      ], (c) => const IlanListesiEkrani(tur: 'is', baslik: 'İş İlanları')),
      _Bolum('Otel', [
        const Color(0xFF6C7BFF),
        const Color(0xFF2A3390),
      ], (c) => const IsletmeListesiEkrani(kategori: 'otel', baslik: 'Oteller')),
      _Bolum('İşletmeler', [
        const Color(0xFFFFB03A),
        const Color(0xFFFF7A45),
      ], (c) => const IsletmeListesiEkrani()),
      _Bolum('Yemek', [
        const Color(0xFFFF7A45),
        const Color(0xFFFF3B5C),
      ], (c) => const IsletmeListesiEkrani(kategori: 'yemek', baslik: 'Yemek')),
      // ⚠️⚠️ TURU 96t — 'Restoran' ve 'Cafe' AYRI IKI KART (kullanici
      //	listesinde ikisi de var) ama **AYNI VERI KATEGORISINE** gider:
      //	veritabaninda tek bir `kafe` kategorisi var ve kafe ile restoran
      //	onun altinda. Ayri anahtar acmak, isletmelerin o alani YENIDEN
      //	doldurmasini gerektirirdi (turu 92'nin alt-kategori gerekcesi).
      _Bolum('Restoran', [
        const Color(0xFFFF3B5C),
        const Color(0xFF8B1E3A),
      ], (c) => const IsletmeListesiEkrani(kategori: 'kafe', baslik: 'Restoran')),
      _Bolum('Cafe', [
        const Color(0xFFC98A5B),
        const Color(0xFF7A4A22),
      ], (c) => const IsletmeListesiEkrani(kategori: 'kafe', baslik: 'Kafe')),
      _Bolum('Alışveriş', [
        const Color(0xFF7A5CFF),
        const Color(0xFF3A2A8A),
      ], (c) => const IsletmeListesiEkrani(kategori: 'market', baslik: 'Alışveriş')),
      // ⚠️ TURU 80 (kullanici emri: "bu alanda kategoriler eğitim ve sağlık ekle").
      //    Iki anahtar ZATEN sistemde: `isletmeKategorileri` (istemci) ve
      //    `isletme/handler.go` (sunucu) 'egitim'/'saglik' taniyor; ayrica
      //    `vitrin/handler.go` `isletmeDikeyleri` haritasinda da VARLAR, yani
      //    inis sayfasinin ust slider'i DOGRU calisir.
      //    ⚠️ MIGRATION GEREKMEZ: `isletmeler.kategori` sutununda CHECK YOK.
      _Bolum('Eğitim', [
        const Color(0xFFEC4FA0),
        const Color(0xFF7B1E6A),
      ], (c) => const IsletmeListesiEkrani(kategori: 'egitim', baslik: 'Eğitim')),
      _Bolum('Sağlık', [
        const Color(0xFF17C3CE),
        const Color(0xFF0A5B78),
      ], (c) => const IsletmeListesiEkrani(kategori: 'saglik', baslik: 'Sağlık')),
      // ⚠️⚠️⚠️ TURU 80 — KANALLAR **BURAYA TASINDI**.
      //    Kullanici anasayfadaki "Akış | Kanallar" secicisini kaldirmami
      //    istedi; ama o secici KANALLARIN **TEK GIRIS NOKTASIYDI**
      //    (`kanallar_sekmesi.dart` yalnizca `akis_ekrani.dart`tan import
      //    ediliyordu — grep ile dogrulandi). Yeni bir ev VERILMESEYDI kanal
      //    ozelligi TAMAMEN ULASILAMAZ kalirdi; bu projede ALTI kez yasanan
      //    "olu ozellik" sinifi.
      //    ⚠️ YAPMA: bu karti kaldirma — kanallara baska giris YOK.
      _Bolum('Kanallar', [
        const Color(0xFF4A6CF7),
        const Color(0xFF1B2A6B),
      ], (c) => const KanallarSayfasi()),
      // ⚠️ TURU 96v — 'Yapay zekâ' karti HIZLI ERISIME tasindi (GebzemAI).
    ];

    // ⚠️ TURU 90 — "Yakınımda" listeden AYRILIR: ustte tek basina cizilir.
    //    Listede de kalsaydi kullanici onu IKI KEZ gorurdu.
    final yakinimda = bolumler
        .where((b) => b.ad == 'Yakınımda')
        .cast<_Bolum?>()
        .firstWhere((_) => true, orElse: () => null);
    final kategoriler =
        bolumler.where((b) => b.ad != 'Yakınımda').toList();


    // ⚠️⚠️⚠️ TURU 96t — **SIRALAMA KULLANICI TARAFINDAN VERILDI**:
    //	*"Yemek Restorant Cafe Alışveriş Hizmet İlan Düğün Eğitim Sağlık
    //	Otel diye daha güzel ve sıralı şekilde"*.
    //
    // ⚠️ Siralama LISTENIN KENDISINDE degil BURADA yapilir: kart tanimlari
    //    (renk, hedef ekran, gerekce serhleri) yillardir o sirada duruyor
    //    ve tasinsalardi serhler kartlardan KOPARDI.
    // ⚠️ Listede OLMAYAN kartlar (Organizasyon, Diyet, Etkinlikler, İş
    //    İlanları, İşletmeler, Kanallar, Yapay zekâ) tanim sirasini
    //    KORUYARAK bunlarin ARDINA dizilir — yeni bir kart eklendiginde
    //    sessizce kaybolmaz, sona eklenir.
    const sira = [
      'Yemek', 'Restoran', 'Cafe', 'Alışveriş', 'Hizmet',
      'İlan', 'Düğün', 'Eğitim', 'Sağlık', 'Otel',
    ];
    final yerler = {
      for (var i = 0; i < kategoriler.length; i++) kategoriler[i].ad: i,
    };
    int agirlik(_Bolum b) {
      final i = sira.indexOf(b.ad);
      return i >= 0 ? i : 1000 + (yerler[b.ad] ?? 0);
    }

    kategoriler.sort((a, b) => agirlik(a).compareTo(agirlik(b)));

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
      // ⚠️⚠️ TURU 96v — **GebzemAI ve Sosyal EN BASTA** (kullanici emri).
      // ⚠️ GebzemAI yalniz sunucuda AI ACIKSA cizilir (`aiAcik`): kapaliyken
      //    kart basildiginda 503 alinirdi — bu projede 'olu ozellik' sinifi.
      //    Ayni sebeple kategoriler izgarasindaki 'Yapay zekâ' karti
      //    KALDIRILDI: iki yerde ayni giris gereksiz tekrar.
      if (aiAcik)
        _Bolum('GebzemAI', [
          const Color(0xFF00C2A8),
          const Color(0xFF00695C),
        ], (c) => const AiDanismaEkrani()),
      // ⚠️ 'Sosyal' = KESFET ekrani (profil arama + gonderi izgarasi).
      //    O ekranin KENDI `Scaffold`i YOK (ana sekme olarak yaziImis),
      //    bu yuzden route'a alinirken `Scaffold` ile SARILIR — aksi halde
      //    zeminsiz ve baslıksiz acilirdi.
      _Bolum('Sosyal', [
        const Color(0xFF7A5CFF),
        const Color(0xFF3A2A8A),
      ], (c) => Scaffold(
            appBar: AppBar(title: const Text('Sosyal')),
            body: const KesfetEkrani(),
          )),
      _Bolum('Nöbetçi Eczane', [
        const Color(0xFF20C997),
        const Color(0xFF0B7A5A),
      ], (c) => const IsletmeListesiEkrani(
          kategori: 'eczane', baslik: 'Eczaneler')),
      // ⚠️⚠️ TURU 96y — SIRA **GEREKLILIGE GORE** (kullanici emri:
      //	*"olmasi gereken gerekliligie gore sirala"*). Ilk dokuz kisayol
      //	izgarada gorunur; gerisi 'Tümü' listesinden ulasilir.
      //	Taksi ve akaryakit acil ihtiyactir; DURAK ise verisi olmayan
      //	(kayitli isletme arayan) bir kisayol oldugu icin onlarin ARDINDA.
      _Bolum('Taksi', [
        const Color(0xFFFFC531),
        const Color(0xFFB88600),
      ], (c) => const IsletmeListesiEkrani(
          kategori: 'hizmet', baslik: 'Taksi', ara: 'taksi')),
      _Bolum('Akaryakıt', [
        const Color(0xFFFF7A45),
        const Color(0xFFB33A12),
      ], (c) => const IsletmeListesiEkrani(
          kategori: 'oto', baslik: 'Akaryakıt & Oto')),
      _Bolum('Durak', [
        const Color(0xFF6C7BFF),
        const Color(0xFF2A3390),
      ], (c) => const IsletmeListesiEkrani(
          kategori: 'hizmet', baslik: 'Durak', ara: 'durak')),
      // ⚠️⚠️ TURU 96x — BES YENI KISAYOL (kullanici: *"ekle bir seyler
      //	daha"*). Hepsi **ZATEN VAR OLAN** isletme kategorileridir
      //	(`isletmeKategorileri`): yeni ekran, yeni uc, yeni migration YOK.
      // ⚠️ YAPMA: buraya karsiligi olmayan bir baslik ekleme — kart
      //    gercek bir ekrana gitmiyorsa EKLENMEZ (turu 76b dersi).
      _Bolum('Kuaför', [
        const Color(0xFFEC4FA0),
        const Color(0xFF7B1E6A),
      ], (c) => const IsletmeListesiEkrani(
          kategori: 'kuafor', baslik: 'Kuaför')),
      _Bolum('Güzellik', [
        const Color(0xFFFF6B9D),
        const Color(0xFFB03060),
      ], (c) => const IsletmeListesiEkrani(
          kategori: 'guzellik', baslik: 'Güzellik Merkezi')),
      _Bolum('Oto Servis', [
        const Color(0xFF6C7BFF),
        const Color(0xFF2A3390),
      ], (c) => const IsletmeListesiEkrani(
          kategori: 'oto', baslik: 'Oto & Servis')),
      _Bolum('Emlak', [
        const Color(0xFF17C3CE),
        const Color(0xFF0A5B78),
      ], (c) => const IsletmeListesiEkrani(
          kategori: 'emlak', baslik: 'Emlak')),
      _Bolum('Spor', [
        const Color(0xFF2BB673),
        const Color(0xFF0E7A52),
      ], (c) => const IsletmeListesiEkrani(
          kategori: 'spor', baslik: 'Spor')),
    ];
    // ⚠️ Hizli erisim listesi BURADA kurulur: `yakinimda` nullable ve
    //    Dart bunu closure icinde daraltmiyor (analiz hatasi verdi).
    //    Koleksiyon-if ile tek seferde null-guvenli hale getirilir.
    // ⚠️⚠️ TURU 96w — SIRA: **GebzemAI · Sosyal · Yakınımda · ...**
    //	(kullanici emri: *"yakinimda sosyalden sonra olacak"*).
    //	`hizli` listesinin ilk iki ogesi GebzemAI ve Sosyal; Yakinimda
    //	onlarin ARDINA eklenir, kalanlar (eczane/durak/taksi/akaryakit)
    //	sirasini korur.
    // ⚠️ AI kapaliyken `hizli` bir oge eksik baslar; bu yuzden konum SABIT
    //    SAYIYLA degil, 'Sosyal'in indeksinden TURETILIR.
    final sosyalNo = hizli.indexWhere((b) => b.ad == 'Sosyal');
    final hizliTumu = <_Bolum>[
      ...hizli.take(sosyalNo + 1),
      if (yakinimda != null) yakinimda,
      ...hizli.skip(sosyalNo + 1),
    ];

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
    final etiketAlani =
        MediaQuery.textScalerOf(context).scale(14) * 1.15 * 2;
    final hucreBoy = kKesifKutu + 5 + etiketAlani;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: kYanBosluk),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gebzem',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Şehrindeki her şey',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ⚠️ Slider `Padding`in DISINDA: yan boslugu KENDI
                //    `viewportFraction`indan uretir (turu 96t).
                _slider(ref),
                const SizedBox(height: 14),
                if (hizliTumu.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: kYanBosluk),
                    child: Text(
                      'HIZLI ERİŞİM',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ⚠️ TEK SATIR + YATAY KAYDIRMA (turu 96u). Kart genisligi
                  //    izgarayla AYNI: ekranda dort kart, besincisi SARKAR.
                  // ⚠️⚠️⚠️ TURU 96w — **IKI SATIR + YATAY KAYDIRMA** ve
                  //	kartlar kategori kartlarindan **%20 KUCUK**
                  //	(kullanici emri).
                  //
                  // ⚠️ `GridView` YATAY yonde: `crossAxisCount: 2` burada
                  //    SUTUN degil **SATIR** sayisidir (cross ekseni dikey).
                  //    Ogeler once ASAGI, sonra SAGA akar.
                  // ⚠️ Kart genisligi izgara hucresinin **0.8 KATI**; kutu
                  //    yuksekligi de ayni oranda. Etiket yazisi KUCULMEZ
                  //    (14 dp) — okunurluk kartin suslemesinden onemli.
                  // ⚠️⚠️⚠️ TURU 96y — **SABIT 2 x 5 = 10 HUCRE, KAYDIRMA YOK**
                  //	(kullanici emri: *"sol sag 5 tane olacak, 2 satir
                  //	olacak, 2. satirin sonunda 'hepsi' diyecek"*).
                  //
                  // ⚠️ Yatay kaydirmali izgara KALDIRILDI: orada ogeler
                  //    once ASAGI sonra SAGA akiyordu, yani okuma sirasi
                  //    sutun sutundu ve kullanici *"yerleri degistirme"*
                  //    dedi. Dikey izgarada sira SOLDAN SAGA'dir.
                  // ⚠️ Ilk **DOKUZ** kisayol cizilir, onuncu hucre 'Tümü';
                  //    gerisi o listeden ulasilir (hicbiri KAYBOLMAZ).
                  LayoutBuilder(
                    builder: (c, bc) {
                      // ⚠️⚠️ TURU 96x — SATIRDA **BES KART** (kullanici emri:
                      //	*"5 satir yapsana, 4 tane olmus"*). Genislik
                      //	dogrudan BESE bolunur; onceki hal 'dortlu izgaranin
                      //	%80'i' idi ve ekranda yine DORT kart cikiyordu.
                      // ⚠️ Kutu oraninin izgarayla AYNI kalmasi icin
                      //    yukseklik genislikten TURETILIR (78/88.8 = 0.878);
                      //    sabit yazilsaydi kartlar dar ekranda kare,
                      //    genisde basik gorunurdu.
                      final en =
                          (bc.maxWidth - kYanBosluk * 2 - kIzgaraAralik * 4) /
                              5;
                      final kutu = en * 0.878;
                      final satirBoy = kutu + 5 + etiketAlani;
                      // ⚠️ 9 kisayol + 'Tümü' = 10 hucre (2 x 5).
                      final gosterilen = [
                        ...hizliTumu.take(9),
                        // ⚠️ 'Tümü' listesi HEM hizli kisayollari HEM
                        //    kategorileri icerir: izgaraya sigmayan hicbir
                        //    giris ULASILAMAZ kalmasin.
                        _tumuBolumu([...hizliTumu, ...kategoriler]),
                      ];
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: kYanBosluk),
                        // ⚠️ Kendi kaydirmasi YOK: sayfanin tamami zaten
                        //    `CustomScrollView` icinde kayiyor (turu 96v).
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: kIzgaraAralik,
                          mainAxisSpacing: kIzgaraAralik,
                          mainAxisExtent: satirBoy,
                        ),
                        itemCount: gosterilen.length,
                        itemBuilder: (_, i) =>
                            _kart(context, gosterilen[i], kutuBoy: kutu),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: kYanBosluk),
                  child: Text(
                    'KATEGORİLER',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),
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
  _Bolum _tumuBolumu(List<_Bolum> hepsi) => _Bolum(
        'Tümü',
        [const Color(0xFF8E8E93), const Color(0xFF4A4A4F)],
        (c) => _TumuEkrani(bolumler: hepsi),
      );

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
  Widget _slider(WidgetRef ref) {
    final s = ref.watch(_menuSlaytProvider).valueOrNull ?? const [];
    if (s.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: KategoriSlider.yukseklik,
      child: KategoriSlider(slaytlar: s),
    );
  }

  /// Sheet'i kapatip hedef ekrani acar.
  ///
  /// ⚠️⚠️ `Navigator.of(context)` **POP'TAN ONCE** yakalanir. Pop'tan sonra
  ///    okunursa sheet'in context'i OLU olur ve ekran HIC ACILMAZ
  ///    (turu 59b/75b'nin "yanlis route" sinifi).
  void _ac(BuildContext context, _Bolum b) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: b.ac));
  }

  /// Kategori KARTI — izgara hucresi (kullanici emri: "eski halinin kucuk hali").
  ///
  /// ⚠️ IKON YOK (turu 76b kurali): kutu bir RENK GECISIDIR, yazi ALTINDA.
  /// ⚠️ `RepaintBoundary`: her kart kendi katmaninda cizilir; biri
  ///    degistiginde (dokunma dalgasi) DIGER 15 kart yeniden BOYANMAZ.
  ///    Turu 91 performans maddesi.
  /// ⚠️ [kutuBoy] verilmezse izgara olcusu (`kKesifKutu`). Hizli erisim
  ///    kartlari bunun **%80**'ini kullanir (turu 96w kullanici emri).
  Widget _kart(BuildContext context, _Bolum b, {double? kutuBoy}) =>
      RepaintBoundary(
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
                color: kYuzeyGri(context),
                borderRadius:
                    BorderRadius.circular(kYaricap(kutuBoy ?? kKesifKutu)),
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
  _Bolum(this.ad, this.renkler, this.ac);
  final String ad;
  final List<Color> renkler;

  /// ⚠️ HER BOLUM GERCEK BIR EKRANA GIDER. `null` (yakında) DESTEGI YOK —
  ///    ekran yoksa kart EKLENMEZ.
  final Widget Function(BuildContext) ac;
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
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              // ⚠️ Bu ekran bir ROUTE (sheet DEGIL): once pop etmeye gerek yok,
              //    hedef ekran bunun USTUNE push edilir ve geri tusu buraya
              //    doner.
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: b.ac)),
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
Future<void> hizmetMenusuAc(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.95,
        child: HizmetMenusu(),
      ),
    );

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

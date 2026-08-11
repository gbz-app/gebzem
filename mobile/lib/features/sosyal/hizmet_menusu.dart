import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../etkinlik/etkinlik_ekranlari.dart';
import '../kanal/kanallar_sekmesi.dart' show KanallarSayfasi;
import '../ilan/ilan_ekranlari.dart';
import '../isletme/isletme_listesi.dart';
import '../isletme/yakinimda_ekrani.dart';
import '../isletme/urun_ekranlari.dart' show AiDanismaEkrani;
import '../isletme/urun_servisi.dart' show aiDurumProvider;
import '../diyet/diyet_ekranlari.dart';
import '../talep/talep_ekranlari.dart';

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
      _Bolum('Düğün & Organizasyon', [
        const Color(0xFFFF6B9D),
        const Color(0xFFC2185B),
      ], (c) => const TalepAkisiEkrani()),
      _Bolum('Diyet', [
        const Color(0xFF2BB673),
        const Color(0xFF0E7A52),
      ], (c) => const DiyetimEkrani()),
      _Bolum('Etkinlikler', [
        const Color(0xFF8B3FFF),
        const Color(0xFF5A1EBE),
      ], (c) => const EtkinlikListesiEkrani()),
      _Bolum('İlanlar', [
        const Color(0xFF2BB673),
        const Color(0xFF12805A),
      ], (c) => const IlanListesiEkrani()),
      _Bolum('Hizmetler', [
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
      _Bolum('Oteller', [
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
      _Bolum('Restoran', [
        const Color(0xFFFF3B5C),
        const Color(0xFF8B1E3A),
      ], (c) => const IsletmeListesiEkrani(kategori: 'kafe', baslik: 'Kafe & Restoran')),
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
      if (aiAcik)
        _Bolum('Yapay zekâ', [
          const Color(0xFF00C2A8),
          const Color(0xFF00695C),
        ], (c) => const AiDanismaEkrani()),
    ];

    // ⚠️ TURU 90 — "Yakınımda" listeden AYRILIR: ustte tek basina cizilir.
    //    Listede de kalsaydi kullanici onu IKI KEZ gorurdu.
    final yakinimda = bolumler
        .where((b) => b.ad == 'Yakınımda')
        .cast<_Bolum?>()
        .firstWhere((_) => true, orElse: () => null);
    final kategoriler =
        bolumler.where((b) => b.ad != 'Yakınımda').toList();

    return SafeArea(
      child: ConstrainedBox(
        // ⚠️ Yukseklik TAVANI: 12 kart kucuk telefonda sheet'i ekran disina
        //    taşırırdı. Icerik daha uzunsa `GridView` kaydirilir.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const Text(
                'Gebzem',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              const Text(
                'Şehrindeki her şey',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              // ⚠️⚠️⚠️ TURU 91 — DUZEN **IZGARAYA DONDU** (kullanici emri:
              //    *"kategoriler ALT ALTA yapmissin ama SOLDAN SAGA 5 tane
              //    ALTA DOGRU kart olacakti, ESKI HALININ KUCUK HALI
              //    olacakti — duzelt"*).
              //
              //    Turu 90'da kullanici "5 tane alt alta" demis, ben TEK
              //    SUTUN yapmistim. Turu 91'de netlestirdi: kartlar SOLDAN
              //    SAGA aksin, ASAGI dogru ~5 SATIR olsun ve eski (turu 76b)
              //    kartlarin KUCULTULMUS hali olsun.
              //
              // ⚠️ "Yakınımda" USTTE AYRI ve KATEGORILER basligi KALIR —
              //    onlar turu 90'da acikca istenmisti ve degismedi.
              //
              // ═══════ OLCU (hesaplanmis, tahmin degil) ═══════
              //    3 sutun · yatay bosluk 10 · dis dolgu 2x16
              //    hucre genisligi 360dp'de (360-32-20)/3 = 102.7
              //                    414dp'de (414-32-20)/3 = 120.7
              //    `childAspectRatio: 0.82` -> yukseklik 125.2 / 147.2
              //    16 kart = 6 satir; kaydirilarak tamami gorunur.
              // ⚠️ Kart ESKI TASARIMIN KUCUGU: kare gradyan kutu (yaricap 18)
              //    + ALTINDA yazi — turu 76b'nin "IKON YOK, yazi kartin
              //    ALTINDA" kurali BOYLECE GERI GELDI (tek sutunda yazi
              //    icerideydi cunku alt alta yazi satiri iki katina cikariyordu).
              if (yakinimda != null) _yakinimdaSatiri(context, yakinimda),
              const SizedBox(height: 18),
              const Text(
                'KATEGORİLER',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                // ⚠️ TURU 91 PERFORMANS — `shrinkWrap: true` KALDIRILDI.
                //    `Flexible` zaten SINIRLI yukseklik veriyor; `shrinkWrap`
                //    ise TUM cocuklari HER KAREDE layout ettiriyordu
                //    (16 kart x her cizim). Kullanicinin "bir tik kasiyor"
                //    tarifine katkida bulunan noktalardan biri.
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: kategoriler.length,
                  itemBuilder: (_, i) => _kart(context, kategoriler[i]),
                ),
              ),
            ],
          ),
        ),
      ),
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

  /// "Yakınımda" — listeden AYRI, daha yuksek ve vurgulu (kullanici emri).
  Widget _yakinimdaSatiri(BuildContext context, _Bolum b) => GestureDetector(
    onTap: () => _ac(context, b),
    child: Container(
      // ⚠️⚠️ TURU 90b — SABIT `height` DEGIL, `minHeight` (olculdu).
      //    Sabit 78dp iken alt yazi 360dp ekranda yazi olcegi 1.5'te IKI
      //    SATIRA sariyor ve kutu 82.8dp gerekiyordu -> RenderFlex tasmasi
      //    (360x640 @1.5'te 17px, tum cihazlarda @2.0'da 47px).
      //    ⚠️ Kardes `_satir` bu ikisini (maxLines + esnek yukseklik) ZATEN
      //       dogru yapiyordu; ASIMETRININ KENDISI hatanin isaretiydi.
      constraints: const BoxConstraints(minHeight: 78),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: b.renkler,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            b.ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Çevrendeki işletmeleri haritada gör',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: Colors.white70),
          ),
        ],
      ),
    ),
  );

  /// Kategori satiri — TEK SUTUN, tam genislik.
  ///
  /// ⚠️ IKON YOK (kullanici emri, turu 76b): satir bir renk gecisli zemindir.
  ///    Tek sutunda yaziyi kartin ALTINA koymak her satiri iki kat uzatir ve
  ///    "5 tane alt alta" istegi SAGLANAMAZDI; bu yuzden yazi ICINDE.
  /// Kategori KARTI — izgara hucresi (kullanici emri: "eski halinin kucuk hali").
  ///
  /// ⚠️ IKON YOK (turu 76b kurali): kutu bir RENK GECISIDIR, yazi ALTINDA.
  /// ⚠️ `RepaintBoundary`: her kart kendi katmaninda cizilir; biri
  ///    degistiginde (dokunma dalgasi) DIGER 15 kart yeniden BOYANMAZ.
  ///    Turu 91 performans maddesi.
  Widget _kart(BuildContext context, _Bolum b) => RepaintBoundary(
    child: GestureDetector(
      onTap: () => _ac(context, b),
      // ⚠️ `opaque`: gradyan kutunun ALTINDAKI bosluga (yazi ile kutu arasi)
      //    dokunmak da karti acar; aksi halde kullanici "bastim acilmadi" der.
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: b.renkler,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          // ⚠️ `maxLines: 2` + ellipsis: "Düğün & Organizasyon" gibi uzun
          //    adlar 102dp genislikte tek satira SIGMAZ; tek satirda
          //    "Düğün &…" olurdu. Iki satir izgara yuksekligine dahil
          //    (childAspectRatio hesabinda sayildi).
          Text(
            b.ad,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

/// Anasayfa AppBar'inin sol ustundeki hamburger dugmesi.
///
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
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        // ⚠️ ZORUNLU: 12 kartlik izgara varsayilan yukseklige SIGMAZ.
        isScrollControlled: true,
        showDragHandle: false,
        builder: (_) => const HizmetMenusu(),
      ),
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

/// ⚠️⚠️⚠️ TURU 121 — **KATEGORI EKRANLARININ ORTAK KABUGU** (kullanici emri:
///	*"yemek kategorisini biz REFERANS olarak yaptik, dolayisiyla diger tum
///	kategoriler AYNI MANTIKTA olacak — restoran, cafe, hizmet, ilan vb.
///	oradaki kategorilerin hepsini ayni mantikta tasarla, SADECE ICERIK
///	FARKLI olacak"*).
///
/// ═══════════ SORUN ═══════════
/// Menudeki kartlar UC FARKLI gorsel dile aciliyordu:
///   · Yemek/Restoran/Cafe/Alisveris/Egitim/Saglik/Otel -> `IsletmeListesi`
///     (AppBar YOK, sabit header + alt menu + slider + kutu izgarasi + serit)
///   · Ilan / Is Ilanlari -> `IlanListesi`      (Material `AppBar`, alt menu YOK)
///   · Hizmet / Dugun / Organizasyon -> `TalepAkisi` (Material `AppBar`)
///   · Etkinlikler -> `EtkinlikListesi`         (Material `AppBar` + Column)
/// Yani ayni menuden acilan kartlar farkli uygulamalardan gelmis gibi
/// duruyordu.
///
/// ═══════════ COZUM ═══════════
/// Bu dosya, **Yemek ekranindaki gorsel kabugu** yeniden kullanilabilir hale
/// getirir: 44 dp'lik sabit header · `AltMenu` · arama kutusu · bolum
/// basligi · 4 sutunlu kutu izgarasi · 70 dp'lik yatay kutu seridi · 32 dp
/// cip seridi.
///
/// ⚠️⚠️ **OLCULER KOPYALANMADI, IMPORT EDILDI.** `kBosluk`, `kInputBoy`,
///	`kKesifKutu`, `kAltKutu`... hepsi `isletme_listesi.dart`ta tanimli ve
///	BURADAN OKUNUYOR. Kopyalasaydik bu projede alti kez yasanan *"ayni
///	kuralin iki kopyasi DRIFT EDER"* hatasini yedinci kez uretirdik:
///	Yemek ekraninda bir olcu degistiginde otekiler geride kalirdi.
///
/// ⚠️ **YEMEK EKRANINA DOKUNULMADI** — o REFERANS ve calisiyor. Kabuk onun
///    olculerini okur; ileride Yemek de bu kabuga gecirilebilir.
/// ⚠️ YAPMA: buraya sabit sayi yazma; gerekli olcu yoksa
///    `isletme_listesi.dart`ta tanimla ve BURADAN import et.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/yenile.dart';
import '../home/alt_menu.dart';
import '../home/home_screen.dart' show aktifSekme;
import 'isletme_kart.dart'
    show kYanBosluk, kYaricap, kYuzeyGri, kVurgu, kalinIkon;
import 'isletme_listesi.dart'
    show
        kBaslikBosluk,
        kBaslikOptik,
        kBosluk,
        kHeaderPay,
        kInputBoy,
        kIzgaraAralik,
        kSegBoy,
        kSegDolgu,
        kSegHucre,
        kSegHucreBoy,
        kSegIkon,
        kSegYukari;

/// Notr yazi rengi — header ikonlari ve baslik.
///
/// ⚠️ Tema vurgusu KULLANILMAZ: Yemek ekraninda da notr; renkli bir baslik
///    kartlarla yarisirdi.
Color kabukYazi(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? Colors.white
    : const Color(0xFF1A1A1A);

/// Notr kenarlik — arama kutusu, cipler ve secici kutusu AYNI dili konusur.
BorderSide kabukKenar(BuildContext c) => BorderSide(
  color:
      (Theme.of(c).brightness == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: 0.14),
);

// ═══════════════════════ SAYFA KABUGU ═══════════════════════

/// Yemek ekraniyla AYNI iskelet: AppBar YOK, 44 dp sabit header, altta
/// `AltMenu`, govde `CustomScrollView`.
///
/// ⚠️⚠️ **`AltMenu` ZORUNLU**: Yemek ekraninda var ve kullanici kategoriler
///	arasinda gezerken alt menuyu kaybetmemeli. `AppBar`li ekranlarda alt
///	menu YOKTU — kullanici bir kategoriye girince uygulamanin geri
///	kalanina erisemiyordu (yalniz geri tusu).
/// ⚠️ `onSec` Yemek ekranindaki desenin BIREBIR aynisi: sekmeyi yaz ve
///    menu route'unu kapat. Ikinci bir notifier ACILMAZ.
class KategoriKabugu extends StatelessWidget {
  const KategoriKabugu({
    super.key,
    required this.baslik,
    required this.slivers,
    this.sol,
    this.sagIkon,
    this.sagIpucu,
    this.sagBasildi,
    this.onYenile,
    this.altDugme,
  });

  final String baslik;

  /// Govde sliver'lari (arama, izgara, liste...).
  final List<Widget> slivers;

  /// Header'in SOL kosesi. Verilmezse **geri oku** cizilir.
  ///
  /// ⚠️ Yemek ekraninda burada KONUM SECICI duruyor (isletme listesi konuma
  ///    gore siralaniyor). Ilan/Etkinlik/Talep ekranlarinda konum secimi bir
  ///    sey degistirmiyor; oralarda geri oku DAHA DOGRU — kullanici menuden
  ///    geldigi icin cikis yolu gorunur olmali.
  final Widget? sol;

  final IconData? sagIkon;
  final String? sagIpucu;
  final VoidCallback? sagBasildi;
  final Future<void> Function()? onYenile;

  /// Yuzen eylem dugmesi (or. "İlan ver").
  final Widget? altDugme;

  @override
  Widget build(BuildContext context) {
    final govde = CustomScrollView(
      // ⚠️ Bos listede de asagi-cek calissin (turu 83b dersi).
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
    return Scaffold(
      bottomNavigationBar: AltMenu(
        secili: null,
        onSec: (sira) {
          aktifSekme.value = sira;
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
      // ⚠️⚠️ TURU 121 — FAB **YUKARI KALDIRILDI** (emulatorde goruldu).
      //	 varken Flutter FABi cubugun hemen ustune
      //	koyuyor; alt menunun ortadan TASAN logo dairesiyle ayni bantta
      //	kaliyor ve dugme cubuga YAPISIK gorunuyordu.
      floatingActionButton: altDugme == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: altDugme,
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: onYenile == null
                  ? govde
                  : YenileSarmali(onRefresh: onYenile!, child: govde),
            ),
          ],
        ),
      ),
    );
  }

  /// 44 dp header — Yemek ekranindaki `_header()` ile AYNI olculer.
  ///
  /// ⚠️ Yan dolgudan `kHeaderPay` DUSULUR: ikonun DOKUNMA KUTUSU gorunen
  ///    glifden genistir, cikarilmazsa header alttaki arama kutusundan
  ///    iceride durur.
  /// ⚠️⚠️ DURUST SINIR (turu 121c denetimi): bu **glif side-bearing**
  ///	telafisi DEGILDIR — ikona ozel bir duzeltme uygulanmiyor, tek bir
  ///	sabit dusuluyor. Ikonlar arasi ~1 px`lik kalan sapma KABUL EDILMIS
  ///	durumdur. Serhin onceki hali "OPTIK TELAFILI" diyordu ve govdede
  ///	boyle bir hesap YOKTU.
  Widget _header(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: kYanBosluk - kHeaderPay,
      right: kYanBosluk - kHeaderPay,
    ),
    child: SizedBox(
      height: 44,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child:
                sol ??
                _daire(
                  context,
                  LucideIcons.arrowLeft,
                  'Geri',
                  () => Navigator.of(context).maybePop(),
                ),
          ),
          // ⚠️ Baslik `Stack` + `Center` ile GERCEK merkezde: `Row` icinde
          //    ortalansaydi sag/sol ikonlarin genisligi farkli oldugu icin
          //    baslik kayardi.
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 44 + kBaslikOptik),
              child: Text(
                baslik,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: kabukYazi(context),
                ),
              ),
            ),
          ),
          if (sagIkon != null)
            Align(
              alignment: Alignment.centerRight,
              child: _daire(
                context,
                sagIkon!,
                sagIpucu ?? '',
                sagBasildi ?? () {},
              ),
            ),
        ],
      ),
    ),
  );

  /// ⚠️ Daire YOK, ciplak ikon (turu 96b kullanici emri) ama dokunma alani
  ///    44 dp KALIR (Material 48 / Apple 44 kurali).
  Widget _daire(
    BuildContext c,
    IconData ikon,
    String ipucu,
    VoidCallback onTap,
  ) => Semantics(
    button: true,
    label: ipucu,
    child: GestureDetector(
      // ⚠️ **DALGA YOK**: kullanici "tikladiginda titreme olmasin" dedi.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: Icon(ikon, size: 24, color: kabukYazi(c))),
      ),
    ),
  );
}

// ═══════════════════════ ARAMA KUTUSU ═══════════════════════

/// Yemek ekranindaki arama kutusunun AYNISI.
///
/// ⚠️ Yukseklik `kInputBoy` (48) — ama `SizedBox`la SARILMAZ: `InputDecorator`
///	cerceveyi kendi `containerHeight`ine gore cizer, sarmalayinca kutu 48
///	yer kaplar ama CERCEVE 33 kalirdi (Yemek ekraninda olculdu). Dogru yol:
///	prefix/suffix'i `kInputBoy` yuksekliginde bir kutuya koymak.
/// ⚠️ Ipucu ve gercek metin AYNI stil — farkli olsalardi kullanici yazmaya
///    basladigi an yazi boyu ZIPLARDI.
/// ⚠️ Arama ikonu `size` ile degil DORT GOLGE ile kalinlastirilir: Lucide bir
///    FONT'tur, `strokeWidth` YOKTUR.
Widget kabukArama({
  required BuildContext context,
  required TextEditingController controller,
  required String ipucu,
  required ValueChanged<String> onChanged,
}) {
  final koyu = Theme.of(context).brightness == Brightness.dark;
  final odak = koyu ? const Color(0xFFE8E8EA) : const Color(0xFF1A1A1A);
  final ikonRenk = koyu ? Colors.white70 : Colors.black87;
  const yaziStili = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
  final dolu = controller.text.isNotEmpty;

  OutlineInputBorder kenar(BorderSide s) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(kYaricap(kInputBoy)),
    borderSide: s,
  );

  return TextField(
    controller: controller,
    onChanged: onChanged,
    style: yaziStili,
    decoration: InputDecoration(
      hintText: ipucu,
      hintStyle: yaziStili.copyWith(
        color: (koyu ? Colors.white : Colors.black).withValues(alpha: 0.45),
      ),
      isDense: true,
      contentPadding: EdgeInsets.zero,
      prefixIcon: SizedBox(
        height: kInputBoy,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(
            LucideIcons.search,
            size: 21,
            color: ikonRenk,
            shadows: [
              for (final d in const [
                Offset(0.4, 0),
                Offset(-0.4, 0),
                Offset(0, 0.4),
                Offset(0, -0.4),
              ])
                Shadow(color: ikonRenk, offset: d),
            ],
          ),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(),
      // ⚠️ TEMIZLE (X) yalniz metin VARKEN: bos alanda duran bir X
      //    "silinecek bir sey var" izlenimi verir.
      suffixIcon: dolu
          ? SizedBox(
              width: 44,
              height: kInputBoy,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kYuzeyGri(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.x, size: 15, color: ikonRenk),
                  ),
                ),
              ),
            )
          : null,
      suffixIconConstraints: const BoxConstraints(),
      enabledBorder: kenar(kabukKenar(context)),
      border: kenar(kabukKenar(context)),
      focusedBorder: kenar(BorderSide(color: odak, width: 1.6)),
    ),
  );
}

// ═══════════════════════ BOLUM BASLIGI ═══════════════════════

/// "Mutfaklar", "Kategoriler" gibi bolum basliklari — 17/w700.
///
/// ⚠️ Sol dolgu OPTIK TELAFILI (`kBaslikOptik`): harf glifi kendi kutusunda
///    bosluk tasir, duz 16 verilirse baslik altindaki kartlardan 1 dp saga
///    kayik gorunur.
Widget kabukBolumBasligi(BuildContext c, String baslik, {Widget? sag}) =>
    Padding(
      padding: EdgeInsets.only(
        left: kYanBosluk - kBaslikOptik,
        right: kYanBosluk,
        bottom: kBaslikBosluk,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              baslik,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: kabukYazi(c),
              ),
            ),
          ),
          if (sag != null) sag,
        ],
      ),
    );

// ⚠️⚠️ TURU 121c — **KUTU IZGARASI / KUTU SERIDI KABUGA ALINMADI** (durust sinir).
//
//	Ilk yazimda `KabukKutuIzgara` ve `KabukKutuSerit` buraya kondu ama
//	HICBIR YERDEN CAGRILMADI: uc ekran (ilan tur izgarasi, ilan alt kategori
//	seridi, talep kategori izgarasi) kendi govdesini tasimaya devam etti.
//	Olu bir "tek kaynak" drift`i ONLEMEZ — yalnizca serhi YALANCI yapar,
//	bu yuzden iki sinif SILINDI.
//
// ⚠️ Neden ortaklastirilmadi: uc cagri yeri YAPISAL OLARAK farkli —
//	· ilan tur izgarasi ve alt kategori seridi birer **BOX** widget
//	  (`SliverToBoxAdapter` icinde), kabuk surumu ise **SLIVER** idi;
//	· hucre icerikleri ayni degil (talep`te aciklama satiri var);
//	· uc yerin yazi olculeri de ayni degil.
//	Hepsini tek bilesene zorlamak parametre sismesi uretirdi.
//
// ⚠️⚠️ ASIL DRIFT RISKI KAPATILDI: **SAYILAR** zaten TEK KAYNAKTA —
//	`kKesifKutu` · `kAltKutu` · `kIzgaraAralik` · `kYaricap` · `kYuzeyGri`
//	· `kVurgu` hepsi `isletme_listesi.dart` / `isletme_kart.dart`tan
//	IMPORT ediliyor. Turu 121c denetimi kenarlik (2 dp `primary` -> 1.6 dp
//	`kVurgu`) ve yazi (11/w500-w800 -> 13/w600) sapmalarini yakalayip
//	REFERANSA hizaladi.
// ⚠️ YAPMA: buraya kullanilmayan bir "ortak" bilesen geri koyma; gercekten
//	ortaklastiracaksan UC cagri yerini de AYNI commit`te devret.

// ═══════════════════════ CIP SERIDI (32 dp) ═══════════════════════

/// Filtre cipi — Yemek ekranindaki `_hizliCip` ile AYNI olculer.
class KabukCip {
  const KabukCip(this.ad, this.ikon, this.secili, this.basildi);
  final String ad;
  final IconData ikon;
  final bool secili;
  final VoidCallback basildi;
}

/// 40 dp'lik serit icinde 32 dp cipler (Yemek ekraniyla ayni).
///
/// ⚠️ Yazi **w600 SABIT**: secilince kalinlassaydi cipin genisligi degisir
///    ve serit ZIPLARDI (Yemek ekraninda olculdu).
Widget kabukCipSeridi(BuildContext c, List<KabukCip> cipler) => SizedBox(
  height: 40,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    padding: EdgeInsets.only(left: kYanBosluk),
    itemCount: cipler.length,
    itemBuilder: (_, i) {
      final cip = cipler[i];
      final vurgu = kVurgu(c);
      return Padding(
        padding: EdgeInsets.only(right: i == cipler.length - 1 ? 12 : 8),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: cip.basildi,
          // TURU 121c — Center ZORUNLU (referanstaki _hizliCip ile birebir):
          // ListView cocuguna DIKEYDE TIGHT kisit verir, yani Container
          // height:32 yazsa bile 40 dp cizilirdi. Cipler Yemek ekranindan
          // 8 dp KALIN duruyordu (turu 96da olculerek duzeltilmis hatanin
          // birebir tekrari). Dokunma alani 40 dp KALIR: GestureDetector
          // Center in DISINDA.
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kYaricap(32)),
                // ⚠️ KALINLIK SABIT 1.4: secilince 1.0 -> 1.4 degisseydi cip
                //    her iki yandan 0.4 dp genisler ve SAGINDAKI TUM cipler
                //    kayardi (yazi kalinligi icin ZATEN yazili olan kural).
                border: Border.fromBorderSide(
                  BorderSide(
                    color: cip.secili ? vurgu : kabukKenar(c).color,
                    width: 1.4,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  kalinIkon(
                    cip.ikon,
                    olcu: 13,
                    renk: cip.secili ? vurgu : kabukYazi(c),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cip.ad,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cip.secili ? vurgu : kabukYazi(c),
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
);

/// Sliver arasi standart bosluk.
SliverToBoxAdapter kabukBosluk([double h = kBosluk]) =>
    SliverToBoxAdapter(child: SizedBox(height: h));

// ═══════════════════════ GORUNUM SECICI (buyuk / kucuk kart) ═══════════════

/// ⚠️⚠️⚠️ TURU 121b — **BUYUK / KUCUK KART SECICISI** (kullanici emri:
///	*"kartlar buyuk ve kucuk kartlar gibi"*).
///
/// Yemek ekranindaki `_gorunumSecici`nin ORTAK hali. Fark: orada UC segment
/// var (liste · kart · **harita**); burada IKI — cunku ilan ve etkinlik
/// ekranlarinda harita gorunumu YOK.
/// ⚠️⚠️ **CALISMAYAN SEGMENT KOYULMAZ**: ucuncusunu "tutarlilik olsun" diye
///	eklemek, dokununca hicbir sey yapmayan bir dugme demekti — bu projede
///	"arayuz soz veriyor, karsiligi yok" sinifi.
///
/// ⚠️ Segment kutusu (kenarlik + dolgu) ZORUNLU: turu 96j'de kaldirildi,
///    kullanici REDDETTI (*"hepsi BIR SEYIN ICINDE border olacak, aktif ikon
///    ARKA RENGI olacak"*). Aktif segment dolu gri zeminle isaretlenir.
/// ⚠️ Ilk ikon `listFilter` — kullanici SECIMI (turu 96j), cikarim degil.
class KabukGorunumSecici extends StatelessWidget {
  const KabukGorunumSecici({
    super.key,
    required this.izgara,
    required this.onSec,
  });

  final bool izgara;
  final ValueChanged<bool> onSec;

  @override
  Widget build(BuildContext context) {
    Widget segment(IconData ikon, String ipucu, bool aktif, VoidCallback ac) =>
        Semantics(
          button: true,
          selected: aktif,
          label: ipucu,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ac,
            child: SizedBox(
              width: kSegHucre,
              height: kSegHucreBoy,
              child: Center(
                child: Container(
                  width: kSegHucre,
                  height: kSegBoy,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: aktif ? kYuzeyGri(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(kYaricap(kSegBoy)),
                  ),
                  child: Icon(ikon, size: kSegIkon, color: kabukYazi(context)),
                ),
              ),
            ),
          ),
        );
    return Transform.translate(
      // ⚠️ Baslik ile optik hiza: kutu, 17 px basligin taban cizgisinden
      //    2 dp asagi kaliyordu (Yemek ekraninda olculdu).
      offset: const Offset(0, -kSegYukari),
      child: Container(
        padding: const EdgeInsets.all(kSegDolgu),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            kYaricap(kSegHucreBoy + kSegDolgu * 2),
          ),
          border: Border.fromBorderSide(kabukKenar(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            segment(
              LucideIcons.listFilter,
              'Büyük kartlar',
              !izgara,
              () => onSec(false),
            ),
            segment(
              LucideIcons.layoutGrid,
              'Küçük kartlar',
              izgara,
              () => onSec(true),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⚠️⚠️ TURU 121c — **KUCUK KART IZGARASININ HUCRE YUKSEKLIGI**.
///
/// Yemek ekrani `childAspectRatio: 0.86` kullaniyor ve orada DOGRU: kartin
/// altinda ad + **IKI** bilgi satiri var. Ilan ve etkinlik kartlarinda BIR
/// bilgi satiri var; ayni orani kopyalayinca hucrenin altinda **~58 dp bos
/// alan** kaliyor ve izgara "kopuk" gorunuyordu (emulatorde olculdu).
///
/// Bu yuzden yukseklik ORANDAN degil **ICERIKTEN** turetilir:
///   kapak (16:9) + 7 + ad satiri + 2 + bilgi satirlari
/// ⚠️ Metin yuksekligi `textScaler` ile olceklenir — sabit dp yazilsaydi yazi
///    olcegi 1.3'te ad kirpilirdi (turu 114'te talep izgarasinda YASANDI).
/// ⚠️ `childAspectRatio` KULLANILMAZ: oran genislige baglidir, metin ise
///    DEGILDIR; ikisini tek sayiya sikistirmak her ekran genisliginde ya
///    bosluk ya kirpma uretir.
/// ⚠️⚠️ SATIR YUKSEKLIGI **ACIKCA** verilir (`height:`), FONT METRIGINE
///	BIRAKILMAZ. Ilk yazimda carpanlar tahminle (1.25/1.30) secilmisti ve
///	emulatorde **"BOTTOM OVERFLOWED BY 3.9 PIXELS"** cikti: uygulamanin
///	fontu Roboto degil ve kendi satir araligi daha genis. Artik hem kart
///	hem olcu AYNI carpani kullaniyor, yani hesap TAHMIN degil SOZLESME.
/// ⚠️ YAPMA: kartta `height:` vermeden bu olcuyu kullanma.
const double kKucukKartAdBoy = 14;
const double kKucukKartBilgiBoy = 12;
const double kKucukKartSatir = 1.30;

/// Kucuk kartin AD satiri stili (izgara hucresiyle TEK KAYNAK).
const TextStyle kKucukKartAdStili = TextStyle(
  fontSize: kKucukKartAdBoy,
  fontWeight: FontWeight.w700,
  height: kKucukKartSatir,
);

/// Kucuk kartin BILGI satiri stili. Renk cagirana birakilir (ilanda vurgu,
/// etkinlikte soluk gri) — YALNIZ olcu ortaktir.
TextStyle kKucukKartBilgiStili(Color renk, {FontWeight? kalinlik}) => TextStyle(
  fontSize: kKucukKartBilgiBoy,
  height: kKucukKartSatir,
  fontWeight: kalinlik,
  color: renk,
);

SliverGridDelegate kabukIzgaraOlcu(BuildContext c, {int bilgiSatiri = 1}) {
  final en = (MediaQuery.sizeOf(c).width - kYanBosluk * 2 - kIzgaraAralik) / 2;
  final olcek = MediaQuery.textScalerOf(c);
  final ad = olcek.scale(kKucukKartAdBoy) * kKucukKartSatir;
  final bilgi = olcek.scale(kKucukKartBilgiBoy) * kKucukKartSatir * bilgiSatiri;
  // ⚠️ 1 dp PAY: `TextPainter` satir yuksekligini YUKARI yuvarlar. Paysiz
  //    hesap yarim pikselde bile sari-siyah tasma seridi cizdirir.
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: kIzgaraAralik,
    mainAxisSpacing: 20,
    mainAxisExtent: en * 9 / 16 + 7 + ad + 2 + bilgi + 1,
  );
}

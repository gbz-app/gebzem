/// ⚠️⚠️⚠️ TURU 96 — FILTRE EKRANI (kullanici emri + referans ekran goruntusu).
///
/// Kullanici: *"filtreye tikladiginda %100 genislikte ve %95 yukseklikte
/// olacak · filtrede olacaklari resim olarak gonderiyorum, sen de arastir,
/// fiyat araliklari vs. bize uygun bir arayuz olsun"*.
///
/// ⚠️⚠️ **REFERANSTAKI HER BOLUM ALINMADI — ALINAMAZDI.**
///	Gonderilen ekranda "Ödeme Yöntemleri" (Online Ödeme / Nakit / Kredi
///	Kartı / MultiNet ...) bir bolum olarak duruyor. Bu projede **odeme
///	yontemi diye bir veri YOK**: ne `isletmeler` tablosunda bir sutun, ne
///	girisi olan bir ekran, ne de siparis/odeme modeli var. Cizilseydi
///	kullanici secer, liste DEGISMEZ ve ozellik "bozuk" gorunurdu — bu
///	projede "sutun var, yazan yol yok" sinifi YEDI kez sahaya cikti;
///	tersi (arayuz var, veri yok) daha da kotudur.
/// ⚠️ YAPMA: odeme yontemi bolumunu "yer tutucu" diye ekleme.
///
/// CIZILEN BOLUMLERIN HEPSI **GERCEK ALANDAN** besleniyor:
///	  · Siralama          -> puan · teslimat_dk_max · min_tutar_kurus · km
///	  · Kategori          -> isletmeler.kategori
///	  · Min. sepet tutari -> isletmeler.min_tutar_kurus   (migration 046)
///	  · Puan              -> isletmeler.puan              (migration 046)
///	  · Teslimat suresi   -> isletmeler.teslimat_dk_max   (migration 046)
///	  · Kampanyali        -> isletmeler.kampanyalar       (migration 046)
///	  · Su an acik        -> isletmeler.calisma (istemcide hesaplanir)
///
/// ⚠️⚠️ **SUZME SIMDILIK ISTEMCIDE** (bilincli, gecici): sunucudaki
///	`/isletmeler` ucu bu parametreleri KABUL ETMIYOR ve bu tur SALT
///	ARAYUZ turu (kullanici emri: *"sadece arayuzu gelistiriyoruz, su an
///	hiz icin"*). Sunucu `LIMIT 60` donduruyor; yani cok isletme oldugunda
///	"60'in icinden suzulmus" sonuc, "hepsinden suzulmus" sonuctan FARKLI
///	olabilir.
/// ⚠️ **BACKEND TURUNDA ILK IS BU**: suzgecler `/isletmeler` ucuna
///    parametre olarak tasinmali. O zamana kadar sinir DURUSTCE burada
///    yazili (bkz. `uygula` serhi).
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'isletme_kart.dart' show kYaricap, kVurgu, kYuzeyGri, isletmeAcikMi, isletmeGeceAcikMi;
import 'isletme_servisi.dart';

/// Liste siralamasi.
enum Siralama { onerilen, puan, teslimat, minTutar, mesafe }

/// ⚠️ TURU 96g — **PUBLIC**: cip seridi de siralama adini yaziyor
///    ("Sıralama · Puana göre"). Iki kopya olsaydi biri guncellenip oteki
///    geride kalirdi.
String siralamaAdi(Siralama s) => _siralamaAdi[s] ?? '';

const _siralamaAdi = {
  Siralama.onerilen: 'Önerilen',
  Siralama.puan: 'Puana göre',
  Siralama.teslimat: 'Teslimat süresi',
  Siralama.minTutar: 'Min. tutar',
  Siralama.mesafe: 'Mesafe',
};

/// Secili filtreler. **DEGISTIRILEBILIR**: sheet uzerinde duzenlenir, sheet
/// "Listele" ile kapaninca cagiran ekran ayni nesneyi kullanmaya devam eder.
class IsletmeFiltre {
  IsletmeFiltre();

  Siralama siralama = Siralama.onerilen;

  /// `null` = tumu. Kurus cinsinden TAVAN (`min_tutar_kurus <= bu`).
  int? minTutarTavanKurus;

  /// `null` = tumu. `puan >= bu`.
  double? puanTaban;

  /// `null` = tumu. `teslimat_dk_max <= bu`.
  int? teslimatTavanDk;

  bool kampanyali = false;
  bool suAnAcik = false;

  /// ⚠️ TURU 96d — "Gece Kuşu" karti: **gec saate kadar acik**.
  ///    `suAnAcik`tan AYRI bir olcut; ikisi birlikte de secilebilir
  ///    ("su an acik VE gece gec kapaniyor" anlamli bir istek).
  bool geceAcik = false;

  /// ⚠️ TURU 96d — "Yeni Restourant" karti: **puani henuz olmayan**.
  ///    Sunucu kayit tarihi dondurmuyor; elde kalan tek durust gosterge bu
  ///    (gerekce `isletme_listesi.dart`taki kart serhinde).
  bool puansiz = false;

  /// Kac suzgec aktif? Arama kutusundaki noktayi ve "Temizle" dugmesini besler.
  /// ⚠️ Siralama SAYILMAZ: "Önerilen" disina cikmak bir SUZGEC degil, bir
  ///    goruntuleme tercihidir; nokta cizilseydi kullanici "neden az sonuc
  ///    var" diye filtre arardi.
  int get aktifSayi =>
      (minTutarTavanKurus != null ? 1 : 0) +
      (puanTaban != null ? 1 : 0) +
      (teslimatTavanDk != null ? 1 : 0) +
      (kampanyali ? 1 : 0) +
      (suAnAcik ? 1 : 0) +
      (geceAcik ? 1 : 0) +
      (puansiz ? 1 : 0);

  void temizle() {
    siralama = Siralama.onerilen;
    minTutarTavanKurus = null;
    puanTaban = null;
    teslimatTavanDk = null;
    kampanyali = false;
    suAnAcik = false;
    geceAcik = false;
    puansiz = false;
  }

  /// ⚠️⚠️ VERISI OLMAYAN KAYIT **ELENIR**, gecirilmez.
  ///
  ///	`puan` NULL olan bir isletme "4.5 ve üstü" suzgecinden gecmemelidir:
  ///	kullanici puani yuksek yerleri istedi, puani BILINMEYEN yeri degil.
  ///	Tersi (NULL'i gecirmek) suzgeci ETKISIZ gosterir ve "filtre
  ///	calismiyor" hissi verir.
  /// ⚠️ Liste **KOPYALANIR** (`toList`): yerinde siralamak cagiran ekranin
  ///    ham listesini bozar ve "Önerilen"e donuldugunde ESKI SIRA GERI
  ///    GELMEZDI.
  List<IsletmeOzet> uygula(List<IsletmeOzet> ham) {
    var l = ham.where((o) {
      if (minTutarTavanKurus != null &&
          (o.minTutarKurus == null || o.minTutarKurus! > minTutarTavanKurus!)) {
        return false;
      }
      if (puanTaban != null && (o.puan == null || o.puan! < puanTaban!)) {
        return false;
      }
      if (teslimatTavanDk != null &&
          (o.teslimatDkMax == null || o.teslimatDkMax! > teslimatTavanDk!)) {
        return false;
      }
      if (kampanyali && o.kampanyalar.isEmpty) return false;
      // ⚠️ `null` = calisma saati TANIMSIZ -> ELENIR (yukaridaki kural).
      if (suAnAcik && isletmeAcikMi(o.calisma) != true) return false;
      if (geceAcik && !isletmeGeceAcikMi(o.calisma)) return false;
      // ⚠️ "Yeni" = puani HENUZ YOK. `0` degil **null** aranir: 0 puan bir
      //    degerlendirmedir, yokluk degil.
      if (puansiz && o.puan != null) return false;
      return true;
    }).toList();

    // ⚠️ Siralamada da VERISI OLMAYAN KAYIT SONA atilir (`?? sonsuz`):
    //    varsayilan 0 verilseydi puani olmayan isletme "en yuksek puanli"
    //    listenin BASINDA cikardi.
    switch (siralama) {
      case Siralama.onerilen:
        break; // sunucunun dondurdugu sira
      case Siralama.puan:
        l.sort((a, b) => (b.puan ?? -1).compareTo(a.puan ?? -1));
      case Siralama.teslimat:
        l.sort((a, b) => (a.teslimatDkMax ?? 1 << 30)
            .compareTo(b.teslimatDkMax ?? 1 << 30));
      case Siralama.minTutar:
        l.sort((a, b) =>
            (a.minTutarKurus ?? 1 << 40).compareTo(b.minTutarKurus ?? 1 << 40));
      case Siralama.mesafe:
        // ⚠️ `km <= 0` = mesafe BILINMIYOR (konum izni yok / koordinat yok).
        l.sort((a, b) => (a.km <= 0 ? double.infinity : a.km)
            .compareTo(b.km <= 0 ? double.infinity : b.km));
    }
    return l;
  }
}

/// Filtre ekranini acar. `true` donerse kullanici "Listele" dedi.
///
/// ⚠️ **%100 GENISLIK + %95 YUKSEKLIK** (kullanici emri):
///	  · `isScrollControlled: true` ZORUNLU — olmadan tavan ekranin 9/16'si
///	    olur ve bolumlerin yarisi KIRPILIR (turu 90b'de "Olustur" sheet'i
///	    tam bu yuzden 44px tasiyordu).
///	  · `constraints` ile genislik dayatilmaz: `showModalBottomSheet`
///	    varsayilani ZATEN tam genisliktir. `maxWidth` yazmak buyuk
///	    ekranlarda ortalar ve %100 olmaktan CIKARIRDI.
///
/// ⚠️⚠️ `useSafeArea` **KULLANILMADI** ve sebebi olculdu: acikken panel
///	ekranin %95'i degil **GUVENLI ALANIN** %95'i oluyordu (emulatorde
///	2151px = ekranin %89,6'si — durum cubugu 63px + jest cubugu 73px
///	once dusuluyor). Kullanici ACIKCA "ekranin %95'i" dedi.
/// ⚠️ Bunun bedeli, panelin ust kenarinin centik/durum cubugu bolgesine
///    girebilmesidir; o yuzden **baslik satiri kendi `SafeArea`sini tasir**
///    (asagida). Yani panel %95, ICERIK yine centigin altinda.
/// ⚠️ YAPMA: `useSafeArea: true` geri ekleme (yukseklik %95 OLMAKTAN CIKAR)
///    ya da basliktaki `SafeArea`yi kaldirma (baslik centigin altina girer).
Future<bool> isletmeFiltreAc(BuildContext context, IsletmeFiltre f) async {
  final sonuc = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (c) => FractionallySizedBox(
      // ⚠️ Kullanici emri: EKRANIN **%95**'i.
      heightFactor: 0.95,
      child: _FiltrePaneli(f: f),
    ),
  );
  return sonuc == true;
}

class _FiltrePaneli extends StatefulWidget {
  const _FiltrePaneli({required this.f});
  final IsletmeFiltre f;

  @override
  State<_FiltrePaneli> createState() => _FiltrePaneliState();
}

class _FiltrePaneliState extends State<_FiltrePaneli> {
  IsletmeFiltre get f => widget.f;

  @override
  Widget build(BuildContext context) {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final yazi = koyu ? Colors.white : const Color(0xFF1A1A1A);
    return Column(
      children: [
        _baslik(yazi),
        Divider(height: 1, color: kYuzeyGri(context)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              _bolum('Sıralama', [
                for (final s in Siralama.values)
                  _secenek(
                    _siralamaAdi[s]!,
                    f.siralama == s,
                    () => setState(() => f.siralama = s),
                  ),
              ], yazi),
              _ayirac(),
              _bolum('Minimum sepet tutarı', [
                _secenek('Tümü', f.minTutarTavanKurus == null,
                    () => setState(() => f.minTutarTavanKurus = null)),
                // ⚠️ Esikler TL cinsinden yazilir, KURUS'a burada cevrilir:
                //    iki birimi ayni satirda tutmak "260 TL"yi 26000 sanma
                //    hatasinin en sik sebebi.
                for (final tl in const [150, 200, 300, 400, 500])
                  _secenek(
                    '$tl TL ve altı',
                    f.minTutarTavanKurus == tl * 100,
                    () => setState(() => f.minTutarTavanKurus = tl * 100),
                  ),
              ], yazi),
              _ayirac(),
              _bolum('Puan', [
                _secenek('Tümü', f.puanTaban == null,
                    () => setState(() => f.puanTaban = null)),
                for (final p in const [4.5, 4.0, 3.5, 3.0])
                  _secenek(
                    '${p.toStringAsFixed(1).replaceAll('.', ',')} ve üstü',
                    f.puanTaban == p,
                    () => setState(() => f.puanTaban = p),
                    ikon: LucideIcons.star,
                  ),
              ], yazi),
              _ayirac(),
              _bolum('Teslimat süresi', [
                _secenek('Tümü', f.teslimatTavanDk == null,
                    () => setState(() => f.teslimatTavanDk = null)),
                for (final d in const [30, 45, 60])
                  _secenek(
                    '$d dk ve altı',
                    f.teslimatTavanDk == d,
                    () => setState(() => f.teslimatTavanDk = d),
                    ikon: LucideIcons.clock,
                  ),
              ], yazi),
              _ayirac(),
              // ⚠️ Bu iki secenek COKLU (birbirini kapatmaz): "kampanyali VE
              //    su an acik" anlamli bir istek.
              _bolum('Diğer', [
                _secenek(
                  'Kampanyalı',
                  f.kampanyali,
                  () => setState(() => f.kampanyali = !f.kampanyali),
                  ikon: LucideIcons.tag,
                ),
                _secenek(
                  'Şu an açık',
                  f.suAnAcik,
                  () => setState(() => f.suAnAcik = !f.suAnAcik),
                  ikon: LucideIcons.doorOpen,
                ),
                // ⚠️ Panel ile KESIF KARTLARI ayni suzgeci paylasir: birinden
                //    secilen otekinde de secili gorunur. Iki ayri alan
                //    tutulsaydi kullanici "kapattim ama hala suzuyor" derdi.
                _secenek(
                  'Gece Kuşu',
                  f.geceAcik,
                  () => setState(() => f.geceAcik = !f.geceAcik),
                  ikon: LucideIcons.moon,
                ),
                _secenek(
                  'Yeni (puanı yok)',
                  f.puansiz,
                  () => setState(() => f.puansiz = !f.puansiz),
                  ikon: LucideIcons.sparkles,
                ),
              ], yazi),
            ],
          ),
        ),
        _altDugme(),
      ],
    );
  }

  /// X · "Filtre" · Temizle
  ///
  /// ⚠️ "Temizle" YALNIZ aktif suzgec varken cizilir: hicbir sey secili
  ///    degilken duran bir "Temizle" dugmesi, kullaniciya "bir yerde bir
  ///    filtre acik" izlenimi verir.
  /// ⚠️⚠️ `SafeArea(bottom: false)` ZORUNLU: panel ekranin %95'i oldugu icin
  ///    ust kenari centik/durum cubugu bolgesine girebilir (bkz.
  ///    `isletmeFiltreAc` serhi). Bu sarmal olmasaydi "Filtre" basligi ve
  ///    X dugmesi centigin ALTINDA KALIRDI.
  Widget _baslik(Color yazi) => SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          // ⚠️⚠️⚠️ TURU 96f — BASLIK **GERCEK MERKEZDE** (kullanici:
          //	*"filtrelemede Filtreleme yazsin, tam ortada degil"*).
          //
          //	ONCEKI HAL `Row` + `Expanded` idi: soldaki X (48) ile sagdaki
          //	Temizle kutusu (88) ESIT OLMADIGI icin "orta" 20 dp saga
          //	kayiyordu. `Stack` + `Center` bunu yapisal olarak cozer:
          //	baslik yanindaki ogelerden BAGIMSIZ, panelin gercek ortasinda.
          // ⚠️ YAPMA: tekrar `Row`+`Expanded`e donme.
          child: Stack(
            children: [
              Center(
                child: Text(
                  'Filtreleme',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: yazi),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(LucideIcons.x, size: 22, color: yazi),
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              // ⚠️ "Temizle" BURADAN KALKTI -> alt satira (kullanici emri:
              //    *"2 buton olsun liste ve temizle"*). Ustte de durursa
              //    AYNI EYLEM IKI YERDE olurdu.
            ],
          ),
        ),
      );

  /// ⚠️ TURU 96f — AYRAC **DAHA SOLUK** (kullanici emri). Varsayilan
  ///    `Divider` temanin cizgi rengini kullaniyordu ve bolumleri
  ///    ayirmaktan cok BOLUYORDU.
  Widget _ayirac() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Divider(
          height: 1,
          thickness: 1,
          color: (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black)
              .withValues(alpha: 0.06),
        ),
      );

  Widget _bolum(String baslik, List<Widget> secenekler, Color yazi) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: yazi)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: secenekler),
        ],
      );

  /// Tek secenek kutusu.
  ///
  /// ⚠️⚠️ SECILI HAL **KUTUYU BUYUTMEZ**: kenarlik kalinligi ve yazi
  ///	kalinligi SABIT, degisen yalnizca RENK. Kalin yazi daha genistir;
  ///	secince genislik degisseydi yanindaki kutular yana kayardi
  ///	(kullanici: *"tikladiginda patlama vb. oynama olmasin"* — hizli
  ///	ciplerde tam bu yasanmisti).
  /// ⚠️ Yaricap `kYaricap` — ekrandaki HER kutuyla ayni (kullanici emri).
  /// ⚠️ **DALGA YOK**: `InkWell` degil `GestureDetector`.
  Widget _secenek(String etiket, bool secili, VoidCallback onTap,
      {IconData? ikon}) {
    final vurgu = kVurgu(context);
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final notr = (koyu ? Colors.white : Colors.black).withValues(alpha: 0.14);
    final yazi = koyu ? Colors.white : const Color(0xFF1A1A1A);
    return Semantics(
      button: true,
      selected: secili,
      label: etiket,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kYaricap(46)),
            color: secili ? vurgu.withValues(alpha: 0.08) : null,
            border:
                Border.all(color: secili ? vurgu : notr, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ikon != null) ...[
                Icon(ikon, size: 16, color: secili ? vurgu : yazi),
                const SizedBox(width: 7),
              ],
              Text(
                etiket,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: secili ? vurgu : yazi,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 96f — ALT SATIRDA **IKI DUGME** (kullanici emri:
  ///	*"temizle alttaki butonun saginda olsun, 2 buton olsun: liste ve
  ///	temizle"*).
  ///
  /// ⚠️ "Temizle" USTTEN KALKTI: ayni eylem iki yerde durursa hangisinin
  ///    ne yaptigi belirsizlesir.
  /// ⚠️ SOLDA **Listele** (birincil, dolu, GENIS), SAGDA **Temizle**
  ///    (ikincil, cerceveli, DAR) — kullanicinin verdigi sira.
  /// ⚠️ "Temizle" paneli KAPATMAZ: kullanici temizleyip yeni secim yapmak
  ///    isteyebilir. Kapatsaydi her temizlemede paneli yeniden acmasi
  ///    gerekirdi.
  /// ⚠️ Aktif suzgec yoksa "Temizle" **PASIF**: basildiginda hicbir sey
  ///    olmayan aktif bir dugme "bozuk" gorunur.
  /// ⚠️ `SafeArea` ZORUNLU: jest cubugu olan telefonlarda dugmeler cubugun
  ///    ALTINDA kalir ve dokunulamaz.
  Widget _altDugme() {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final vurgu = kVurgu(context);
    final aktif = f.aktifSayi > 0;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: kYuzeyGri(context))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      // ⚠️ Renk TEMADAN ALINMAZ: varsayilan `primary` YESIL
                      //    ve kullanici bu ekranda yesili reddetti.
                      backgroundColor: vurgu,
                      foregroundColor: koyu ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kYaricap(52)),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Listele',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: vurgu,
                      side: BorderSide(
                          color: vurgu.withValues(alpha: aktif ? 1 : 0.25)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kYaricap(52)),
                      ),
                    ),
                    onPressed: aktif ? () => setState(f.temizle) : null,
                    child: const Text('Temizle',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

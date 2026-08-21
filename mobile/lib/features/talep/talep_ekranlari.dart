/// ⚠️⚠️⚠️ TURU 91 — TEKLIF ISTEGI: AKIS + ADIM ADIM SIHIRBAZ.
///
/// Kullanici emri: *"dugun mu yapmak istiyorsun HIZMET mi almak istiyorsun,
/// burada STEP STEP — ornegin dugun yapmak istiyorum, salon sececek, misafir
/// sayisi, neler istiyor, dis mekan mi vs; sonra bu bilgiler ornegin KUAFORE
/// teklif gidecek, DIGERLERINE gidecek, onlar da KARSI TEKLIF verecekler"*.
///
/// ═══════════ FORM SUNUCUDAN URETILIR ═══════════
///
/// Adimlar ve alanlar `GET /ilan-kategoriler` -> `talep` turunden gelir
/// (`Alan.adim` ile gruplanir). Yani yeni bir soru eklemek ISTEMCI
/// GUNCELLEMESI GEREKTIRMEZ.
/// ⚠️ YAPMA: soru listesini Dart'a yazma (turu 77 kurali).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ⚠️ TURU 114 — "yemek" duzeninin olcu/renk sabitleri BURADAN gelir,
//    KOPYALANMAZ (iki ekran birlikte doner).
import '../isletme/isletme_kart.dart'
    show kYanBosluk, kYaricap, kYuzeyGri, kVurgu;
import '../isletme/isletme_listesi.dart'
    show
        kBosluk,
        kKesifKutu,
        kIzgaraAralik,
        kBaslikBosluk,
        kAltKutu,
        kAltIcBosluk;
import '../ilan/ilan_ekranlari.dart' show IlanDetayEkrani, IlanListesiEkrani;
import '../ilan/ilan_servisi.dart';
// ⚠️ TURU 121 — kategori ekranlarinin ORTAK KABUGU (Yemek referansi).
import '../isletme/kategori_kabuk.dart';
import '../isletme/kategori_slider.dart';
import '../isletme/isletme_servisi.dart' show isletmeServisiProvider;
import 'talep_servisi.dart';

// ═══════════════════ 1) DAL SECIMI + KATEGORI ═══════════════════

/// ⚠️⚠️⚠️ TURU 114 — TEKLIF/HIZMET AKISI **"YEMEK" DUZENINDE** (kullanici
///	emirleri: *"dugun kategorisi de yemek gibi olsun"* · *"hizmetler hizmet
///	al step step olsun"* · *"dugun de step step olsun"* · *"hepsi yemek
///	mantiginda olsun"*).
///
/// ═══════════ NEDEN ISLETME LISTESI DEGIL ═══════════
///
/// "Yemek gibi" ilk bakista *"dugun isletmelerini listele"* demek gibi
/// duruyor. **YAPILAMAZ VE YAPILMAMALI:** `isletme.Kategoriler` haritasinda
/// `dugun` ya da `organizasyon` diye bir anahtar YOK (kaynaktan dogrulandi),
/// yani boyle bir liste **HER ZAMAN BOS** donerdi. Bu, projede alti kez
/// tekrarlanan *"ozellik var gorunup fiilen yok"* sinifinin yenisi olurdu.
///
/// Bunun yerine **GORSEL DIL** yemekten alindi (arama kutusu + "KATEGORİLER"
/// basligi + 4 sutunlu gri kutu izgarasi + altinda yazi) ama izgaradaki
/// hucreler **TALEP KATEGORILERI**dir ve dokununca **ADIM ADIM SIHIRBAZ**
/// acilir. Boylece uc emir birden karsilanir ve tek bir sahte veri cizilmez.
///
/// ⚠️ Olcu/renk sabitleri `isletme_kart.dart` ve `isletme_listesi.dart`ten
///    **IMPORT EDILIR**, kopyalanmaz — iki ekran birlikte doner.
/// ⚠️ Kategori listesi SUNUCUDAN (`GET /ilan-kategoriler`); Dart'a sabit
///    yazmak turu 77 kuralinin ihlali olurdu.
class TalepAkisiEkrani extends ConsumerStatefulWidget {
  const TalepAkisiEkrani({super.key, this.dal});

  /// `'dugun'` · `'hizmet'` · `null` (ikisi de).
  ///
  /// ⚠️ Dal ayrimi ISTEMCIDE (bkz. `talep_servisi.dart` serhi): sunucuda
  ///    hepsi ayni `tur='talep'`tir ve bu bir SUNUM tercihidir.
  final String? dal;

  @override
  ConsumerState<TalepAkisiEkrani> createState() => _TalepAkisiState();
}

class _TalepAkisiState extends ConsumerState<TalepAkisiEkrani> {
  final _arama = TextEditingController();
  String _q = '';

  /// ⚠️⚠️ TURU 122 — **TALEPLERIM ARTIK BU EKRANDA** (kullanici emri:
  ///	*"butun kategoriler AYNI OLACAK ayni mantik"*).
  ///
  ///	Onceden ekran YALNIZ kategori kartlarindan ibaretti: ne liste ne
  ///	filtre cipi vardi ve taleplerine ancak SAG USTTEKI ikondan
  ///	ulasabiliyordun. Yemek ve Ilan ekranlarinda liste EKRANIN KENDISINDE
  ///	oldugu icin bu ekran ailenin disinda duruyordu.
  /// ⚠️ Sag ustteki "Taleplerim" girisi KALDIRILMADI: teklif akisinin
  ///    tum gecmisi orada (kapanmis talepler dahil).
  /// ⚠️ TURU 123 — slider slaytlari (Yemek ekraniyla AYNI uc).
  List<Slayt> _slaytlar = const [];

  /// ⚠️⚠️ TURU 124 — **ALT ALAN SERIDI** (kullanici emri: *"hizmetlerde
  ///	yemek gibi ana kartlar bir de ALTINDA hizmetlerin ALT ALANLARI"*).
  ///
  ///	Yemek ekraninda kesif kutularinin ALTINDA "Mutfaklar" 60x60 seridi
  ///	var; burada YOKTU. Sunucu `/isletme-kesif?kategori=hizmet` icin
  ///	zaten alt kategori donduruyor (Tadilat · Nakliyat · Temizlik ·
  ///	Tesisat · Elektrik) — yeni uc GEREKMEDI.
  /// ⚠️ Serit bir ARAMA KISAYOLUDUR: dokununca arama kutusunu doldurur
  ///    (Yemek`teki alt kategori seridiyle AYNI davranis).
  List<({String ad, String ara})> _altKategoriler = const [];
  String _altSecili = '';

  /// ⚠️⚠️ TURKCE KUCULTME **ELLE** yapilir.
  ///
  ///	Dart'in `toLowerCase()`i `'İ'` (U+0130) icin `'i' + BIRLESIK NOKTA`
  ///	uretir; yani kullanici *"is"* yazdiginda **"İş Yeri Temizliği"**
  ///	kategorisi ESLESMEZDI (aranan `is`, uretilen `i̇s`). Ayni tuzak sunucu
  ///	tarafinda da kayitli (turu 91: `strings.ToLower` "İSPANAK" aramasini
  ///	bozuyordu) ve orada da ELLE cozuldu.
  /// ⚠️ `I` -> `ı` ve `İ` -> `i` ONCE uygulanir, sonra kalanlar icin
  ///    `toLowerCase()`.
  static String _kucult(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  @override
  void initState() {
    super.initState();
    _slaytlariYukle();
  }

  /// Slider slaytlari + ALT ALAN seridi — Yemek ekraniyla AYNI uc.
  ///
  /// ⚠️ AYRI ve SESSIZ: ekranin ASIL isi kategori kartlari, ikisi de
  ///    cizilmezse ekran calismaya devam eder. Kurtarma asagi-cek.
  Future<void> _slaytlariYukle() async {
    try {
      final d = await ref.read(isletmeServisiProvider).kesif('hizmet');
      if (!mounted) return;
      setState(() {
        _slaytlar = d.slaytlar;
        _altKategoriler = d.altKategoriler;
      });
    } catch (_) {
      // sessiz: slider ve serit cizilmez
    }
  }

  String get _baslik => switch (widget.dal) {
    'dugun' => 'Düğün & Organizasyon',
    'hizmet' => 'Hizmet al',
    _ => 'Teklif iste',
  };

  @override
  Widget build(BuildContext context) {
    final agac = ref.watch(ilanAgaciProvider);
    // ⚠️⚠️ TURU 121 — **AppBar KALDIRILDI**, Yemek ekranindaki 44 dp
    //	sabit header + `AltMenu` kabugu kullaniliyor (kullanici emri:
    //	*"diger tum kategoriler AYNI MANTIKTA olacak"*).
    // ⚠️ Sag ust "Taleplerim" girisi KORUNDU: teklif akisinin tek
    //    donus yolu orasi.
    return KategoriKabugu(
      baslik: _baslik,
      // ⚠️ TURU 124 — Yemek ekraninin header`inda sagda **KALP** var
      //    (Favorilerim). Bu ekranda yoktu.
      sagIkon: LucideIcons.heart,
      sagIpucu: 'Favorilerim',
      sagBasildi: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const IlanListesiEkrani(
            favori: true,
            baslik: 'Favorilerim',
          ),
        ),
      ),
      onYenile: _slaytlariYukle,
      slivers: agac.when(
        loading: () => const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        error: (e, _) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _hataGovde(context, ref),
          ),
        ],
        data: (turler) {
          final talep = turler.where((t) => t.anahtar == 'talep').firstOrNull;
          if (talep == null) {
            // ⚠️ DURUST HATA: sunucu `talep` turunu dondurmuyorsa ozellik
            //    KULLANILAMAZ. Bos liste "hicbir kategori yok" gibi YANLIS
            //    bir izlenim verirdi.
            return const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Teklif isteği şu anda kullanılamıyor.\n'
                    'Uygulamayı güncellemen gerekebilir.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ];
          }
          final hepsi = talep.kategoriler.where((k) {
            // ⚠️⚠️ TURU 121 — **DIYET KATEGORISI ELENIR** (kullanici emri:
            //	*"diyet ile ilgili ne varsa kaldir"*).
            //	Sunucu `/ilan-kategoriler` yanitinda `diyet_program` hala
            //	donuyor; istemci onu CIZMEZ. Sunucudan silmek BACKEND isi ve
            //	arayuz turunda yapilmaz (kural 9) — liste geldiginde
            //	suzuluyor.
            // ⚠️ Sunucu kaldirilirsa bu satir ZARARSIZ kalir (eslesme olmaz).
            if (k.anahtar == 'diyet_program') return false;
            if (widget.dal == 'dugun') {
              return dugunKategorileri.contains(k.anahtar);
            }
            if (widget.dal == 'hizmet') {
              return !dugunKategorileri.contains(k.anahtar);
            }
            return true;
          }).toList();
          // ⚠️ Arama ISTEMCIDE suzuyor: liste sunucudan TEK SEFERDE geliyor
          //    ve ~15 kalem. Sunucuya `q` eklemek fazladan bir istek ve
          //    fazladan bir uc demekti.
          final q = _kucult(_q);
          final gosterilen = q.isEmpty
              ? hepsi
              : hepsi.where((k) => _kucult(k.ad).contains(q)).toList();

          return [
              // ⚠️⚠️ TURU 123 — **"Hangi hizmeti almak istiyorsun?" BASLIK
              //	BLOGU KALDIRILDI.** Yemek ve Ilan ekranlarinda boyle bir
              //	blok YOK; yalniz burada vardi ve ekrani ailenin disinda
              //	gosteriyordu (kullanici emri: *"yemegin AYNISI"*).
              //
              // ⚠️ TURU 121 — arama kutusu KABUKTAN (Yemek ile birebir):
              //    48 dp, notr kenarlik, kalinlastirilmis arama ikonu,
              //    dolu iken temizle (X) dairesi.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  kYanBosluk,
                  0,
                  kYanBosluk,
                  kBosluk,
                ),
                sliver: SliverToBoxAdapter(
                  child: kabukArama(
                    context: context,
                    controller: _arama,
                    ipucu: 'Ne Aramıştın?',
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                ),
              ),
              // ── SLIDER (Yemek ile AYNI yer, AYNI bilesen) ──
              if (_slaytlar.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: KategoriSlider(slaytlar: _slaytlar),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: kBosluk)),
              ],
              // ⚠️ Bolum basligi da kabuktan: Yemek ekranindaki
              //    "Mutfaklar" ile AYNI olcu (17/w700 + optik telafi).
              //    Onceki hal 11.5/w800 GRI bir etiketti ve ayni menuden
              //    acilan iki ekran farkli dilde konusuyordu.
              // ⚠️ TURU 123 — "Kategoriler" basligi KALDIRILDI (Yemek`te
              //    kutu izgarasinin ustunde baslik YOK).
              if (gosterilen.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(kYanBosluk, 24, kYanBosluk, 24),
                    child: Text(
                      q.isEmpty
                          ? 'Bu dalda kategori bulunamadı'
                          : 'Aramanla eşleşen kategori yok',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    kYanBosluk,
                    0,
                    kYanBosluk,
                    28,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          // ⚠️ 4 sutun: menudeki kategori izgarasiyla BIREBIR
                          //    (turu 96q kullanici emri).
                          crossAxisCount: 4,
                          crossAxisSpacing: kIzgaraAralik,
                          mainAxisSpacing: kIzgaraAralik,
                          // ⚠️⚠️⚠️ TURU 114 (denetim) — **ORAN DEGIL SABIT
                          //	YUKSEKLIK.** Ilk yazimda `childAspectRatio: 0.78`
                          //	vardi; hucre yuksekligi GENISLIKTEN turedigi icin
                          //	yazi olcegi buyudugunde etiket alani BUYUYOR ama
                          //	hucre BUYUMUYORDU.
                          //	OLCULDU (gercek `flutter test` + font metrikleri):
                          //	  411 dp · olcek 1.5 -> hucre 109.94 dp,
                          //	  icerik 131.30 dp -> **21.36 dp TASMA**.
                          //	Formul menudeki izgaranin AYNISI: gri kutu + 5 +
                          //	IKI SATIRLIK etiket, etiket yazi olceginden
                          //	TURETILIR. Boylece tasma YAPISAL OLARAK imkansiz.
                          // ⚠️ YAPMA: `childAspectRatio`a geri donme.
                          // +1 dp pay: TextPainter satir yuksekligini YUKARI
                          // yuvarlar; paysiz hesap 0.1 px tasma seridi
                          // cizdiriyordu (etkinlikte olculdu).
                          mainAxisExtent:
                              kKesifKutu +
                              5 +
                              MediaQuery.textScalerOf(context).scale(14) *
                                  1.15 *
                                  2 +
                              1,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (c, i) => _kategoriKarti(talep, gosterilen[i]),
                      childCount: gosterilen.length,
                    ),
                  ),
                ),
              // ⚠️ TURU 123 — "NASIL ÇALIŞIR" blogu KALDIRILDI: Yemek ve
              //    Ilan ekranlarinda YOK. Akis zaten kendini anlatiyor
              //    (karta dokun -> adim adim form).

              // ══════════ ALT ALAN SERIDI (Yemek`teki "Mutfaklar") ══════════
              //
              // ⚠️⚠️ TURU 124 — kullanici emri: *"hizmetlerde yemek gibi ana
              //	kartlar bir de ALTINDA hizmetlerin ALT ALANLARI"*.
              //	Ana kartlar (yukarida) TALEP kategorileridir ve dokununca
              //	SIHIRBAZ acar; bu serit ise bir **ARAMA KISAYOLUDUR**
              //	(Yemek`teki alt kategori seridiyle AYNI davranis).
              // ⚠️ Icerik SUNUCUDAN (`/isletme-kesif?kategori=hizmet`):
              //	Tadilat · Nakliyat · Temizlik · Tesisat · Elektrik.
              // ⚠️ Serit YOKSA baslik da cizilmez (Yemek`teki kural).
              if (_altKategoriler.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: kabukBolumBasligi(context, 'Hizmet alanları'),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: kBaslikBosluk),
                ),
                SliverToBoxAdapter(child: _altSerit()),
                kabukBosluk(),
              ],

              // ⚠️ TURU 124 — "Taleplerim" BOLUMU KALDIRILDI (kullanici emri:
              //	*"taleplerim kaldir"*). Taleplere erisim KAYBOLMADI:
              //	profildeki "İlanlarım" girisi `tur: talep` ile ayni listeyi
              //	aciyor.
              kabukBosluk(90),
          ];
        },
      ),
    );
  }

  /// 60x60 alt alan seridi — Yemek ekranindaki "Mutfaklar" seridinin AYNISI.
  ///
  /// ⚠️ Yukseklik yazi olceginden TURETILIR (sabit dp DEGIL): olcek 1.3`te
  ///    iki satirlik ad tasardi.
  /// ⚠️ Ayni oge tekrar secilince suzgec KALKAR; secim arama kutusunu
  ///    doldurur, yani sonuc GORUNUR bir yerden geri alinabilir.
  Widget _altSerit() {
    final olcek = MediaQuery.textScalerOf(context);
    final boy = kAltKutu + kAltIcBosluk + olcek.scale(13) * 1.15 * 2 + 1;
    return SizedBox(
      height: boy,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: kYanBosluk),
        itemCount: _altKategoriler.length,
        itemBuilder: (_, i) {
          final a = _altKategoriler[i];
          final secili = _altSecili == a.ara;
          return Padding(
            padding: EdgeInsets.only(
              right: i == _altKategoriler.length - 1 ? kYanBosluk : kIzgaraAralik,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _altSecili = secili ? '' : a.ara;
                  _arama.text = _altSecili;
                  _q = _altSecili;
                });
              },
              child: SizedBox(
                width: kAltKutu,
                child: Column(
                  children: [
                    // Cocuksuz DecoratedBox GENISLIK kisiti GEVSEK oldugunda
                    // SIFIR genislik alir ve kutu HIC CIZILMEZ (emulatorde
                    // goruldu: yalniz yazilar vardi). Referans da Container
                    // kullaniyor.
                    Container(
                      width: kAltKutu,
                      height: kAltKutu,
                      decoration: BoxDecoration(
                          color: kYuzeyGri(context),
                          borderRadius: BorderRadius.circular(
                            kYaricap(kAltKutu),
                          ),
                          border: Border.all(
                            color: secili
                                ? kVurgu(context)
                                : Colors.transparent,
                            width: 1.6,
                          ),
                      ),
                    ),
                    SizedBox(height: kAltIcBosluk),
                    Expanded(
                      child: Text(
                        a.ad,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Izgara hucresi — menudeki kategori kartiyla BIREBIR ayni dil.
  ///
  /// ⚠️ IKON YOK, HARF YOK: kutu bir YUZEYDIR, yazi ALTINDA (kullanici
  ///    kategori ekraninda kutu icine konan HER SEYI uc kez kaldirtti).
  Widget _kategoriKarti(IlanTuru talep, ({String anahtar, String ad}) k) =>
      RepaintBoundary(
        child: GestureDetector(
          // ⚠️ `opaque`: kutu ile yazi arasindaki bosluga dokunmak da acar.
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TalepSihirbaziEkrani(tur: talep, kategori: k),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ⚠️ `AspectRatio` DEGIL sabit yukseklik: menudeki izgara da
              //    `kKesifKutu` kullaniyor ve iki ekran yan yana ayni
              //    gorunmeli.
              SizedBox(
                height: kKesifKutu,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kYuzeyGri(context),
                    borderRadius: BorderRadius.circular(kYaricap(kKesifKutu)),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              // ⚠️⚠️ ETIKET ALANI **SABIT IKI SATIR**: icerige gore
              //	degisseydi uzun adlar hucreyi uzatir ve izgaranin alt
              //	siniri DALGALANIRDI (turu 96k'da olculen hata).
              //	Yukseklik yazi olceginden TURETILIR.
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(14) * 1.15 * 2,
                child: Center(
                  child: Text(
                    k.ad,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _hataGovde(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Kategoriler yüklenemedi'),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => ref.invalidate(ilanAgaciProvider),
          child: const Text('Tekrar dene'),
        ),
      ],
    ),
  );
}

// ═══════════════════ 2) ADIM ADIM SIHIRBAZ ═══════════════════

class TalepSihirbaziEkrani extends ConsumerStatefulWidget {
  const TalepSihirbaziEkrani({
    super.key,
    required this.tur,
    required this.kategori,
  });

  final IlanTuru tur;
  final ({String anahtar, String ad}) kategori;

  @override
  ConsumerState<TalepSihirbaziEkrani> createState() => _SihirbazState();
}

class _SihirbazState extends ConsumerState<TalepSihirbaziEkrani> {
  int _adim = 0;
  bool _gonderiliyor = false;

  /// Alan anahtari -> deger. `cok_secim` icin `List<String>`.
  final Map<String, dynamic> _cevaplar = {};
  final _il = TextEditingController();
  final _ilce = TextEditingController();
  final _not = TextEditingController();

  /// ⚠️⚠️⚠️ TURU 93b — ALANLAR **KATEGORIYE GORE SUNUCUDAN** (denetim).
  ///
  ///	Onceden `widget.tur.alanlar` kullaniliyordu ve o liste TEK'ti: 15
  ///	kategorinin HEPSINDE ayni sorular ciziliyordu. "Temizlik" talebi
  ///	acan kullaniciya *"Kişi sayısı"*, *"Mekân: KIR DÜĞÜNÜ"*,
  ///	*"İhtiyacın olanlar: GELİNLİK, GELİN ARABASI"* soruluyordu;
  ///	*"Diyet & Beslenme Programı"* talebinde de aynisi.
  ///	Kullanicinin emri acikca IKI DALDI.
  /// ⚠️ ILK CIZIM `widget.tur.alanlar` ile yapilir (ekran BOS ACILMAZ),
  ///    suzulmus liste gelince yerine gecer. Istek patlarsa TAM liste
  ///    kalir — fazla soru sormak, HIC soru sormamaktan iyidir.
  late List<TalepAdimi> _adimlar = adimlaraBol(widget.tur.alanlar);

  /// Sunucudan gelen adimlar + SON ADIM (konum/not/ozet).
  int get _toplam => _adimlar.length + 1;
  bool get _sonAdim => _adim >= _adimlar.length;

  @override
  void dispose() {
    _il.dispose();
    _ilce.dispose();
    _not.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _alanlariSuz();
  }

  Future<void> _alanlariSuz() async {
    try {
      final agac = await ref
          .read(ilanServisiProvider)
          .agac(kategori: widget.kategori.anahtar);
      final talep = agac.where((t) => t.anahtar == 'talep').firstOrNull;
      if (!mounted || talep == null || talep.alanlar.isEmpty) return;
      setState(() {
        _adimlar = adimlaraBol(talep.alanlar);
        // ⚠️ Adim indisi TASABILIR: suzulmus listede daha az adim olabilir.
        if (_adim >= _adimlar.length) _adim = _adimlar.length - 1;
      });
    } catch (_) {
      // ⚠️ SESSIZ: tam liste ekranda kalir (bkz. `_adimlar` serhi).
    }
  }

  /// ⚠️ Bu adimdaki ZORUNLU alanlarin hepsi dolu mu?
  bool get _devamEdilebilir {
    if (_sonAdim) return true;
    for (final a in _adimlar[_adim].alanlar) {
      if (!a.zorunlu) continue;
      final v = _cevaplar[a.anahtar];
      if (v == null || (v is String && v.trim().isEmpty) ||
          (v is List && v.isEmpty)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _gonder() async {
    if (_gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    final nav = Navigator.of(context);
    final mesajci = ScaffoldMessenger.of(context);
    try {
      // ⚠️ `ozellikler` SERBEST JSONB: sunucu alanlari DOGRULAMAZ, yalnizca
      //    saklar. Tur tanimi da sunucudan geldigi icin yeni alan eklemek
      //    ISTEMCI GUNCELLEMESI GEREKTIRMEZ.
      // ⚠️ Servis await'ten ONCE yakalanir (turu 78b dersi: disposed State'te
      //    `ref.read` StateError firlatir ve is SESSIZCE iptal olur —
      //    "gonderdim sandim, gitmemis").
      final svc = ref.read(ilanServisiProvider);
      final id = await svc.olustur({
        'tur': 'talep',
        'kategori': widget.kategori.anahtar,
        'baslik': widget.kategori.ad,
        'aciklama': _not.text.trim(),
        'il': _il.text.trim(),
        'ilce': _ilce.text.trim(),
        'ozellikler': _cevaplar,
      });
      // ⚠️⚠️⚠️ TURU 93b — **TALEP OLUSTU, KULLANICI IKINCI KEZ GONDERIYORDU**
      //	(denetimde yakalandi).
      //
      //	Iki ag cagrisi TEK `try` icindeydi: `olustur` BASARILI olup
      //	talep sunucuda olusuyor ve fan-out bildirimleri GIDIYOR, ardindan
      //	`detay` bir ag hickirigiyla firlatinca `catch` "Talep
      //	olusturulamadi" basiyordu. Kullanici tekrar basiyor -> **IKINCI
      //	TALEP** + hedef isletmelere **IKINCI BILDIRIM**. `ilanlar`da
      //	tekillik kisiti YOK, yani kayit kaliciydi.
      //
      // ⚠️ FIX: `detay` AYRI bir `try` icinde. Basarisiz olursa talep
      //    YINE OLUSMUSTUR; kullaniciya oyle soylenir ve sihirbaz kapanir —
      //    "olusturulamadi" YALANI bir daha soylenmez.
      // ⚠️ `IlanDetayEkrani` bir `Ilan` NESNESI istiyor (id degil); nesne
      //    gecmek listeden acilan ilanla AYNI nesnenin paylasilmasini
      //    saglar (turu 76).
      final Ilan ilan;
      try {
        ilan = await svc.detay(id);
      } catch (_) {
        if (!mounted) return;
        nav.pop(true);
        mesajci.showSnackBar(const SnackBar(
          content: Text('Talebin oluşturuldu. Detayı "Taleplerim"den açabilirsin.'),
        ));
        return;
      }
      if (!mounted) return;
      // ⚠️ Sihirbazi YIGINDAN KALDIRIP detaya gidiyoruz: kullanici geri
      //    tusuna bastiginda doldurdugu forma DONMEMELI (talep zaten
      //    olusturuldu; ikinci kez gondermeye calisirdi).
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => IlanDetayEkrani(ilan: ilan)),
      );
      mesajci.showSnackBar(const SnackBar(
        content: Text('Talebin oluşturuldu — teklifler burada görünecek'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _gonderiliyor = false);
      mesajci.showSnackBar(
          const SnackBar(content: Text('Talep oluşturulamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kategori.ad),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_adim + 1) / _toplam),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: _sonAdim ? _sonAdimGovde() : _adimGovde(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (_adim > 0)
                    TextButton(
                      onPressed: _gonderiliyor
                          ? null
                          : () => setState(() => _adim--),
                      child: const Text('Geri'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: (!_devamEdilebilir || _gonderiliyor)
                        ? null
                        : () {
                            if (_sonAdim) {
                              _gonder();
                            } else {
                              setState(() => _adim++);
                            }
                          },
                    child: _gonderiliyor
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Text(_sonAdim ? 'Talebi gönder' : 'Devam'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _adimGovde() => [
        for (final a in _adimlar[_adim].alanlar) ...[
          _alan(a),
          const SizedBox(height: 18),
        ],
      ];

  List<Widget> _sonAdimGovde() => [
        const Text('Nerede?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _il,
          decoration: const InputDecoration(
              labelText: 'İl', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _ilce,
          decoration: const InputDecoration(
              labelText: 'İlçe', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 22),
        const Text('Eklemek istediğin bir şey var mı?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _not,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Detaylar, özel istekler...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        // ⚠️⚠️ GORUNURLUK UYARISI **ZORUNLU** (migration 045 karari).
        //    Talep `ilanlar` tablosunda yasiyor ve o tablo HERKESE ACIK.
        //    Kullanici bunu bilmeden ozel bilgi yazarsa, yazdigi sey tum
        //    oturum sahiplerine gorunur. Uyariyi gostermemek, gizlilik
        //    beklentisini SESSIZCE ihlal etmek olurdu.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.info, size: 18, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bu talep herkese açıktır. Telefon veya adres yazma — '
                  'işletmeler sana uygulama üzerinden ulaşacak.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ];

  /// Tek bir alanin girisi — TIPE gore.
  ///
  /// ⚠️ `ValueKey` ZORUNLU: adim degisince Flutter ayni tipteki elementi
  ///    YENIDEN KULLANIR ve `TextField`in eski degeri yeni alanda gorunur
  ///    ("hayalet veri" — turu 77b'de ilan formunda tam bu yasandi:
  ///    "Metrekare" kutusunda "Ford" yaziyordu).
  Widget _alan(IlanAlani a) {
    final etiket = a.zorunlu ? '${a.ad} *' : a.ad;
    switch (a.tip) {
      case 'secim':
        return Column(
          key: ValueKey('secim:${a.anahtar}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiket,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in a.secenekler)
                  ChoiceChip(
                    label: Text(s),
                    selected: _cevaplar[a.anahtar] == s,
                    onSelected: (_) =>
                        setState(() => _cevaplar[a.anahtar] = s),
                  ),
              ],
            ),
          ],
        );
      case 'cok_secim':
        final secili = (_cevaplar[a.anahtar] as List?)?.cast<String>() ?? [];
        return Column(
          key: ValueKey('cok:${a.anahtar}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiket,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Birden fazla seçebilirsin',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in a.secenekler)
                  FilterChip(
                    label: Text(s),
                    selected: secili.contains(s),
                    onSelected: (v) => setState(() {
                      final l = [...secili];
                      v ? l.add(s) : l.remove(s);
                      _cevaplar[a.anahtar] = l;
                    }),
                  ),
              ],
            ),
          ],
        );
      case 'tarih':
        final v = (_cevaplar[a.anahtar] ?? '').toString();
        return Column(
          key: ValueKey('tarih:${a.anahtar}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiket,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.calendar, size: 18),
              label: Text(v.isEmpty ? 'Tarih seç' : v),
              onPressed: () async {
                final simdi = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: simdi.add(const Duration(days: 30)),
                  firstDate: simdi,
                  // ⚠️ Dugun genelde 1-2 yil once planlanir; tavan 2 yil.
                  lastDate: simdi.add(const Duration(days: 730)),
                  helpText: a.ad,
                  cancelText: 'Vazgeç',
                  confirmText: 'Seç',
                );
                if (d == null || !mounted) return;
                setState(() => _cevaplar[a.anahtar] =
                    '${d.day}.${d.month}.${d.year}');
              },
            ),
          ],
        );
      case 'sayi':
        return TextFormField(
          key: ValueKey('sayi:${a.anahtar}'),
          initialValue: (_cevaplar[a.anahtar] ?? '').toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: etiket,
            suffixText: a.birim.isEmpty ? null : a.birim,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _cevaplar[a.anahtar] = v.trim()),
        );
      default:
        return TextFormField(
          key: ValueKey('metin:${a.anahtar}'),
          initialValue: (_cevaplar[a.anahtar] ?? '').toString(),
          decoration: InputDecoration(
            labelText: etiket,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _cevaplar[a.anahtar] = v.trim()),
        );
    }
  }
}

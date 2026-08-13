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
import 'isletme_servisi.dart';

/// ⚠️⚠️ **EKRANDAKI TEK GRI.** Slider zemini, kapak yer tutucusu ve 60x60
///    kartlar AYNI tonu kullanir (kullanici emri: *"ayni grilikte olsun"*).
/// ⚠️ YAPMA: bu ekranlarda elle `0xFFE7E7EA` gibi bir gri yazma.
Color kYuzeyGri(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark
        ? const Color(0xFF2A2A2E)
        : const Color(0xFFE7E7EA);

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

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final gorselID = (o.kapakMediaId != null && o.kapakMediaId!.isNotEmpty)
        ? o.kapakMediaId!
        : (o.avatarMediaId ?? '');
    // ⚠️ Kapak genisligi ACIKCA verilir: yoksa gorsel 2048px'e kadar decode
    //    edilir (turu 91 performans dersi, ~9 MB gecici RAM/kart).
    final kartGenislik = MediaQuery.sizeOf(context).width - 32;
    return Padding(
      // ⚠️ Kartlar arasi bosluk, ad-gorsel boslugunun ~3.5 kati: goz hangi
      //    ismin hangi gorsele ait oldugunu ancak boyle ayirir.
      padding: const EdgeInsets.only(bottom: 32),
      child: GestureDetector(
        // ⚠️ **DALGA YOK** (kullanici emri: "tikladiginda titreme olmasin").
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              // ⚠️ Kapak, slider, 60x60 kutu, cip ve input ARTIK AYNI yaricapi
              //    kullanir (bkz. `kYaricap` serhi).
              borderRadius: BorderRadius.circular(kYaricapBuyuk),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: gorselID.isEmpty
                        ? ColoredBox(color: kYuzeyGri(context))
                        : MedyaGorsel(
                            mediaId: gorselID,
                            fit: BoxFit.cover,
                            width: kartGenislik,
                          ),
                  ),
                  kampanyaRozetleri(o),
                  // ⚠️ KALP **SAG UST** (referans ekran). Kapaga biner;
                  //    altta rozetler var, ustte bos alan.
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _Kalp(dolu: _favori, onTap: _cevir),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Flexible(
                  child: Text(
                    o.ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      // ⚠️ 16 -> 17 (kullanici emri: "isletme yazi tipi 1px").
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (o.dogrulandi)
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Icon(LucideIcons.badgeCheck,
                        size: 16, color: kOnayliRengi),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            // ⚠️ IKINCI SATIR ("Açık · … · En uygun … · Gebze") **KALDIRILDI**
            //    (kullanici emri: *"alttaki kartlardaki en uygun, Gebze vs
            //    sil"*). Kart artik TEK bilgi satiri tasiyor: puan · sure ·
            //    min. tutar. Ayrinti karta dokununca acilan profilde zaten
            //    var; iki satir kartlari uzatip listeyi agirlastiriyordu.
            // ⚠️ `bilgiSatiri` SILINMEDI: acik/kapali bilgisi isletme
            //    profilinde kullanilabilir. Burada CAGRILMIYOR.
            vitrinSatiri(context, o, kompakt: false),
          ],
        ),
      ),
    );
  }
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
class _Kalp extends StatelessWidget {
  const _Kalp({required this.dolu, required this.onTap});

  final bool dolu;
  final VoidCallback onTap;

  /// Fotograftan ayiran yumusak koyu golge — IKI HALDE DE ayni.
  static const _golge = Shadow(
    color: Color(0x66000000),
    blurRadius: 5,
  );

  @override
  Widget build(BuildContext context) {
    const pembe = Color(0xFFE11D48);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Center(
          child: dolu
              ? const Icon(Icons.favorite,
                  size: 24, color: pembe, shadows: [_golge])
              // ⚠️ BOS HAL: **BEYAZ** cizgi (kullanici emri). Lucide bir FONT
              //    oldugu icin `strokeWidth` YOKTUR; kalinlik ayni renkte
              //    ±0.5px kaydirilmis dort golgeyle simule edilir.
              // ⚠️ Koyu golge LISTENIN BASINDA: golgeler sirayla ve glifin
              //    ARKASINA cizilir, yani once koyu bulanik yayilma, ustune
              //    beyaz kalinlastirma gelir. Ters sirada koyu golge beyaz
              //    kalinlastirmayi ORTERDI.
              : const Icon(
                  LucideIcons.heart,
                  size: 24,
                  color: Colors.white,
                  shadows: [
                    _golge,
                    Shadow(color: Colors.white, offset: Offset(0.5, 0)),
                    Shadow(color: Colors.white, offset: Offset(-0.5, 0)),
                    Shadow(color: Colors.white, offset: Offset(0, 0.5)),
                    Shadow(color: Colors.white, offset: Offset(0, -0.5)),
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
    left: 8,
    bottom: 8,
    right: 52, // kalbin altina girmesin
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
Widget vitrinSatiri(BuildContext c, IsletmeOzet o, {required bool kompakt}) {
  final soluk =
      Theme.of(c).textTheme.bodyMedium?.color?.withValues(alpha: 0.62);
  // ⚠️ 13 -> 14 (kullanici emri: "dakika, fiyat 1px daha buyuk").
  final boy = kompakt ? 13.0 : 14.0;
  final p = <Widget>[];

  if (o.puan != null) {
    p.add(Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.star, size: 14, color: Color(0xFF16A34A)),
        const SizedBox(width: 3),
        Text(
          o.puan!.toStringAsFixed(1).replaceAll('.', ','),
          style: TextStyle(
            fontSize: boy,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF16A34A),
          ),
        ),
        if (!kompakt && o.puanSayisi > 0) ...[
          const SizedBox(width: 3),
          Text('(${o.puanSayisi})',
              style: TextStyle(fontSize: boy, color: soluk)),
        ],
      ],
    ));
  }
  // ⚠️ TESLIMAT SURESI — saat ikonu (kullanici emri: "bunlara modern
  //    ikonlar ekle"). Ikon metnin ANLAMINI tasir; yalnizca "25-35 dk"
  //    yazmak tarama sirasinda sayiyi neyle karistiracagini belirsiz birakir.
  if (o.teslimatDkMin != null && o.teslimatDkMax != null) {
    p.add(_ikonluMetin(LucideIcons.clock, '${o.teslimatDkMin}-${o.teslimatDkMax} dk',
        boy, soluk));
  }
  // ⚠️ MIN. TUTAR — cuzdan ikonu. **"₺" YERINE "TL"** (kullanici emri):
  //    bazi Android yazi tiplerinde ₺ glifi eksik ve tofu (kutu) cizilir.
  if (o.minTutarKurus != null && o.minTutarKurus! > 0) {
    p.add(_ikonluMetin(LucideIcons.wallet,
        'Min. ${(o.minTutarKurus! / 100).round()} TL', boy, soluk));
  }
  // ⚠️⚠️ MESAFE — "1,2 km" / "300 m" (kullanici emri).
  //
  // ⚠️ Konum izni YOKSA ya da isletme koordinat girmemisse `mesafeMetni`
  //    BOS doner ve HICBIR SEY cizilmez. "0 m" ya da "?" yazmak yanlis
  //    bilgi olurdu; bu projede kapak/puan/teslimat da ayni kurali izliyor.
  if (o.mesafeMetni.isNotEmpty) {
    p.add(_ikonluMetin(LucideIcons.mapPin, o.mesafeMetni, boy, soluk));
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
Widget _ikonluMetin(IconData ikon, String metin, double boy, Color? renk) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 14, color: renk),
        const SizedBox(width: 4),
        Text(metin, style: TextStyle(fontSize: boy, color: renk)),
      ],
    );

/// **Açık/Kapalı · En uygun XX ₺ · İlçe** — hepsi gercek alanlardan turer.
Widget bilgiSatiri(BuildContext c, IsletmeOzet o) {
  final soluk =
      Theme.of(c).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
  final acik = isletmeAcikMi(o.calisma);
  final kapanis = _bugunKapanis(o.calisma);
  final parcalar = <Widget>[];

  // ⚠️ `null` = calisma saati TANIMSIZ -> hicbir sey yazilmaz. "Kapalı"
  //    yazmak, saatini girmemis isletmeyi HAKSIZ yere kapali gosterirdi.
  if (acik != null) {
    parcalar.add(Row(
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
    ));
  }
  final f = o.minFiyatKurus;
  if (f != null && f > 0) {
    parcalar.add(Text('En uygun ${(f / 100).round()} ₺',
        style: TextStyle(fontSize: 13, color: soluk)));
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

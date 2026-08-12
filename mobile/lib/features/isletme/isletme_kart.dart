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
              borderRadius: BorderRadius.circular(14),
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
/// ⚠️ OPAK BEYAZ ZEMIN: kapak fotografi acik ya da koyu olabilir; ciplak bir
///    ikon bazi fotograflarda GORUNMEZ olurdu.
/// ⚠️ Dokunma alani 36dp — kapak uzerinde daha buyugu gorseli kapatir;
///    Material 48 kurali burada gorsel butunlugu lehine esnetildi ve
///    BILINCLIDIR (kartin tamami zaten dokunulabilir, kalp ikincil eylem).
class _Kalp extends StatelessWidget {
  const _Kalp({required this.dolu, required this.onTap});

  final bool dolu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const pembe = Color(0xFFE11D48);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        // ⚠️⚠️ SECILI HAL **DOLU PEMBE** (kullanici emri: *"kalbe
        //	tikladigimda TAM PEMBE olsun"*).
        //
        //	Lucide'da **dolu kalp glifi YOK** (paket tarandi: heart,
        //	heartCrack, heartOff... hepsi cizgi). O yuzden secili halde
        //	Material'in `Icons.favorite`i kullaniliyor — 2B ve dolu.
        //	⚠️ Bu, "arayuzde Lucide kullan" kuralinin BILINCLI istisnasi:
        //	   kural 3B/emoji ikonlara karsiydi; `Icons.favorite` duz 2B
        //	   bir siluet. Alternatif (cizgi ikonu golgeyle doldurmaya
        //	   calismak) kirli bir kenar birakiyordu.
        child: dolu
            ? const Icon(Icons.favorite, size: 21, color: pembe)
            // ⚠️ BOS HAL: cizgi **1px DAHA KALIN** (kullanici emri).
            //    Lucide bir FONT oldugu icin `strokeWidth` YOKTUR; kalinlik
            //    ayni renkte ±0.5px kaydirilmis dort golgeyle simule edilir.
            : const Icon(
                LucideIcons.heart,
                size: 20,
                color: Color(0xFF4B5563),
                shadows: [
                  Shadow(color: Color(0xFF4B5563), offset: Offset(0.5, 0)),
                  Shadow(color: Color(0xFF4B5563), offset: Offset(-0.5, 0)),
                  Shadow(color: Color(0xFF4B5563), offset: Offset(0, 0.5)),
                  Shadow(color: Color(0xFF4B5563), offset: Offset(0, -0.5)),
                ],
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
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
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
  final acik = _acikMi(o.calisma);
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
/// ⚠️ `gun` **1=Pazartesi**, Dart'in `DateTime.weekday` degeriyle BIREBIR ayni.
/// ⚠️ GECE YARISINI ASAN mesai (22:00-02:00) destekleniyor.
bool? _acikMi(List<dynamic> calisma) {
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

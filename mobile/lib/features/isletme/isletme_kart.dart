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
                      fontSize: 16,
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
            vitrinSatiri(context, o, kompakt: false),
            const SizedBox(height: 2),
            bilgiSatiri(context, o),
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
  Widget build(BuildContext context) => GestureDetector(
        // ⚠️ `opaque`: dairenin bos kosesine dokunmak da calisir.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            LucideIcons.heart,
            size: 19,
            // ⚠️ Dolu kalp KIRMIZI ve DOLGULU gorunsun diye ikon rengi
            //    degistirilir; Lucide'da ayri bir "dolu kalp" glifi yok.
            color: dolu ? const Color(0xFFE11D48) : const Color(0xFF6B7280),
          ),
        ),
      );
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
  final boy = kompakt ? 12.0 : 13.0;
  final p = <Widget>[];

  if (o.puan != null) {
    p.add(Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.star, size: 13, color: Color(0xFF16A34A)),
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
  if (o.teslimatDkMin != null && o.teslimatDkMax != null) {
    p.add(Text('${o.teslimatDkMin}-${o.teslimatDkMax} dk',
        style: TextStyle(fontSize: boy, color: soluk)));
  }
  if (o.minTutarKurus != null && o.minTutarKurus! > 0) {
    p.add(Text('Min. ${(o.minTutarKurus! / 100).round()} ₺',
        style: TextStyle(fontSize: boy, color: soluk)));
  }
  if (p.isEmpty) return const SizedBox.shrink();

  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 7,
    runSpacing: 2,
    children: [
      for (var i = 0; i < p.length; i++) ...[
        if (i > 0) Text('·', style: TextStyle(fontSize: boy, color: soluk)),
        p[i],
      ],
    ],
  );
}

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

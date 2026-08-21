import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart' show kimlikRengi;
import '../medya/medya_gorsel.dart';
import 'sosyal_servisi.dart' show Profil;

/// ⚠️⚠️ TURU 78 — PROFIL BASLIGI: KAPAK + LOGO/AVATAR + ONAYLI ROZET.
///
/// Kullanici emri: *"isletmelerde arka plan resmi, logo ortada; ayni sekilde
/// normal kullanicilarda da arka plan resmi olacak; onayli hesap ikonu da olsun"*.
///
/// ⚠️ AYRI DOSYA: `profil_sayfasi.dart` 756 satir ve icinde 145 satirlik
///    `IsletmeSeridi` de var. Bu blok oraya eklenseydi 930+ satira cikardi;
///    turu 67'de buyuk bir dosyada coklu blok duzenlemesi DOSYAYI BOZMUSTU.
///    Baslik durumsuz (saf `Profil` -> widget) oldugu icin cikarmasi mekanik.
/// ⚠️ `IsletmeSeridi` BU TURDA TASINMADI — kazanci yok, sirf calkanti olurdu.

/// ⚠️ Avatar olculeri: halka DOLU DAIRE olarak cizilir (Border DEGIL — dairesel
///    border + cocuk kirpmasi kenarda tirtikli cikiyor).
const double _avatarCap = 96;
const double _halka = 4;
const double _avatarDis = _avatarCap + _halka * 2; // 104
const double _tasma = _avatarDis / 2; // 52

/// Onayli rozeti rengi. ⚠️ `IsletmeSeridi`ndeki rozetle AYNI renk — iki farkli
/// mavi tik kullaniciyi "iki cesit onay mi var?" sorusuna dusururdu.
const Color kOnayliRengi = Color(0xFF3AA9FF);

/// Kapak yuksekligi. **TURU 82b: %30 KISALTILDI** (kullanici emri:
/// *"profildeki header cok yuksek, %30 yuksekligini dusur"*).
///
/// ⚠️ Onceki deger 16:9 + 240dp tavan idi. Yeni deger **16:11.2 + 168dp tavan**
///    — ikisi de tam olarak `x0.70`, yani kisaltma HEM dar HEM genis ekranda
///    ayni oranda uygulanir. Yalniz tavani dusurmek genis ekranda etkili
///    olurdu ama telefonda (oran bagliyor) HICBIR SEY degistirmezdi:
///      390dp genislik -> eski 219dp, yalniz tavan dusseydi yine 219dp kalirdi.
/// ⚠️ 16:9 secilme gerekcesi (Facebook Sayfa / Google Isletme kapagiyla ayni
///    dil) ARTIK GECERSIZ; kullanici acikca daha alcak bir kapak istedi.
/// ⚠️⚠️ TAVAN ZORUNLU KALIR: tablette saf oran ekranin yarisini yerdi. Gorsel
///    `BoxFit.cover` oldugu icin tavanda KIRPILIR, ESNEMEZ.
/// ⚠️ `num.clamp` **num** dondurur (double DEGIL) — `math.min` kullanildi.
/// ⚠️⚠️ TURU 125 — 0.70 -> **0.92** (kullanici emri: *"arka kapak
///	yüksekliği arttır"*, Instagram/Twitter profil kapagi gibi).
///	390 dp genislikte: 153 dp -> **202 dp**.
/// ⚠️ TAVAN (240) ve  DURUYOR: tablette kapak ekranin
///    yarisini yemez, gorsel esnemez KIRPILIR.
const double kKapakKisaltma = 0.92;
double kapakYuksekligi(double genislik) =>
    math.min(genislik * 9 / 16, 240.0) * kKapakKisaltma;

class ProfilBasligi extends StatelessWidget {
  const ProfilBasligi({super.key, required this.p, this.onAvatarDokun});

  final Profil p;
  final VoidCallback? onAvatarDokun;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // ⚠️ `MediaQuery` DEGIL `LayoutBuilder`: bu widget bir `ListView` cocugu;
    //    gercek genisligi ekran genisliginden farkli olabilir (tablet/bolunmus
    //    ekran). MediaQuery kullansaydik kapak tasar ya da dar kalirdi.
    builder: (context, kisit) {
      final kh = kapakYuksekligi(kisit.maxWidth);
      return SizedBox(
        // ⚠️⚠️ YUKSEKLIK TASMAYI **ICERIR** (kh + 52). Boylece hicbir cocuk
        //    Stack'in disina cikmaz.
        //
        //    NEDEN BOYLE (turu 60 + hit-test tuzagi):
        //      · `Stack` varsayilani `Clip.hardEdge`tir; tasan cocuk KIRPILIR.
        //        Turu 60'ta bir rozet tam bu yuzden "ciziliyor ama gorunmuyor"
        //        haline gelmisti.
        //      · `clipBehavior: Clip.none` + negatif offset COZUM DEGILDIR:
        //        `RenderBox.hitTest` `size.contains(position)` kontrolu yapar,
        //        yani Stack sinirinin DISINA tasan cocuk **DOKUNUS ALMAZ**.
        //        Avatara basip fotografi buyutme SESSIZCE olurdu — ayni
        //        "ciziliyor ama calismiyor" sinifi.
        //    ⚠️ YAPMA: `Clip.none` + negatif `bottom` desenine gecme.
        height: kh + _tasma,
        child: Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, height: kh, child: _kapak()),
            Positioned(
              top: kh - _tasma,
              left: 0,
              right: 0,
              // ⚠️ `height` VERILMEK ZORUNDA: yalniz `top` verilip
              //    `height`/`bottom` verilmezse dikey kisit GEVSEK olur ve
              //    icindeki `Center` sinirsiz eksende buyumeye calisip patlar.
              height: _avatarDis,
              child: Center(child: _avatar(context)),
            ),
          ],
        ),
      );
    },
  );

  Widget _kapak() {
    final id = p.kapakMediaId;
    if (id != null && id.isNotEmpty) {
      // ⚠️ `kucuk: false` — kapak TAM GENISLIK cizilir; kucuk resim burada
      //    BULANIK cikar. (Izgarada `kucuk: true` dogru, burada DEGIL.)
      return MedyaGorsel(mediaId: id, fit: BoxFit.cover);
    }
    // ⚠️ Kapak yokken BOS GRI KUTU cizilmez — kimlikten turetilen sakin bir
    //    degrade. Her profil kendine ozgu ama gurultusuz bir zemin alir.
    // ⚠️ IKON/EMOJI KONULMAZ (kullanici emri: arayuzde emoji yok).
    final c = kimlikRengi(p.id);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // ⚠️ TURU 115b — DOYGUNLUK DUSURULDU (.85 -> .50). Kimlik rengi
          //    ekranin ustunde MARKA MORUYLA yarisir hale gelmisti (mavi bir
          //    kapak + mor dugmeler). Kimlik ayrimi KORUNUR, baskinligi biter.
          colors: [c.withValues(alpha: .50), c.withValues(alpha: .16)],
        ),
      ),
    );
  }

  /// Halka = zemin renginde DOLU daire + ortasinda avatar.
  ///
  /// ⚠️ Renk TEMADAN alinir; sabit beyaz yazilsaydi koyu temada leke gibi dururdu.
  Widget _avatar(BuildContext context) => GestureDetector(
    onTap: onAvatarDokun,
    child: Container(
      width: _avatarDis,
      height: _avatarDis,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Center(
        child: Avatar(
          ad: p.ad,
          mediaId: p.avatarMediaId,
          avatarUrl: p.avatarUrl,
          cap: _avatarCap,
        ),
      ),
    ),
  );
}

/// Ad + onayli rozeti. **Ortalanmis** (kisisel ve isletme AYNI duzen).
///
/// ⚠️ Kullanici "logo ortada" dedi ve "normal kullanicilarda da ayni sekilde"
///    diye ekledi. Mevcut profil duzeni ZATEN ortali (avatar/ad/hakkinda/
///    baglanti hepsi `Center`). Instagram'in sola dayali duzenine gecmek
///    kisisel profili de bastan yazmak demekti ve sayaclari avatarin SAGINA
///    bir `Row`a tasimayi gerektirirdi — tam da turu 60 tuzagi.
class ProfilAdSatiri extends StatelessWidget {
  const ProfilAdSatiri({super.key, required this.ad, required this.onayli});

  final String ad;
  final bool onayli;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Row(
      // ⚠️ `min` + `center`: ad KISAYSA rozet adin DIBINDE durur, ekranin
      //    sagina firlamaz. `max` olsaydi rozet hep kenarda kalirdi.
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ⚠️⚠️ TURU 60 — `Flexible` ZORUNLU. Row'un hicbir cocugu esnek degilse
        //    RenderFlex hepsini SINIRSIZ genislikle olcer; uzun ad ekrandan
        //    tasar, ust katman kirpar ve rozet "ciziliyor ama gorunmuyor"
        //    haline gelir. `ellipsis` de o halde HIC calismaz.
        // ⚠️⚠️ TURU 62 — `Flexible` YALNIZ KENDI EKSENINDE guvenlidir. Burasi
        //    bir **ROW** cocugu (yatay) — dogru. Bunu bir `Column`a tasirsan
        //    yukseklik sinirsiz oldugu icin RenderFlex ASSERTION ile KIRMIZI
        //    EKRAN verir.
        Flexible(
          child: Text(
            ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        if (onayli) ...[
          const SizedBox(width: 5),
          // ⚠️ Rozet `Flexible`in **DISINDA**: iceride olsaydi uzun adda
          //    rozetin KENDISI kirpilirdi. Ad kisalir, rozet ASLA kaybolmaz.
          const Icon(LucideIcons.badgeCheck, size: 18, color: kOnayliRengi),
        ],
      ],
    ),
  );
}

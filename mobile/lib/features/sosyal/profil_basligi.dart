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
  const ProfilBasligi({
    super.key,
    required this.p,
    this.onAvatarDokun,
    this.acik,
  });

  final Profil p;
  final VoidCallback? onAvatarDokun;

  /// ⚠️⚠️ TURU 179 — **ACIK/KAPALI NOKTASI** (kullanici emri: *"logonun
  ///	sag altinda YESIL daire olsun acik olduguna isaret, degilse
  ///	hafif KAHVE rengi"*).
  ///
  /// ⚠️ **`null` = NOKTA HIC CIZILMEZ.** Kisisel hesabin "acik/kapali"
  ///	diye bir durumu YOKTUR; calisma saati girilmemis bir
  ///	isletmede de bilgi YOKTUR. Uc durum (acik · kapali · bilgi
  ///	yok) iki renge indirgenseydi, saatini girmemis her isletme
  ///	"KAPALI" gorunurdu — olmayan bir veriyi iddia etmek olurdu.
  final bool? acik;

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
            // ⚠️⚠️ TURU 176 — **KAPAK SOL/SAG/ALT RADUSLU** (kullanici:
            //	*"header resim alani sol sag asagi dogru raduslu
            //	olsun"*).
            // ⚠️ UST kose radussuz: kapak durum cubugunun ALTINA giriyor
            //    (`extendBodyBehindAppBar`) ve ustte yuvarlatilirsa
            //    ekranin tepesinde iki kenar bosluk gorunurdu.
            // ⚠️ Kirpici `Positioned`in ICINDE: disina konsaydi avatarin
            //    kapaktan TASAN kismi da kirpilirdi.
            // ⚠️⚠️ TURU 179 — **KOSELER TERS (KONKAV)** (kullanici:
            //	*"alt sol ve sag alt raduslar YUKARI bakiyor, ASAGI
            //	dogru bakmali"*). Bkz. `_TersKoseKirpici`.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: kh,
              child: ClipPath(
                clipper: const _TersKoseKirpici(22),
                child: _kapak(),
              ),
            ),
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
    child: SizedBox(
      width: _avatarDis,
      height: _avatarDis,
      // ⚠️ `clipBehavior: none` ZORUNLU: nokta halkanin KENARINA oturuyor
      //    ve `Stack` varsayilani onu KIRPARDI.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
          if (acik != null) _durumNoktasi(context, acik!),
        ],
      ),
    ),
  );

  /// Acik: yesil · kapali: **hafif kahve** (kullanici emri).
  ///
  /// ⚠️ Zemin renginde bir HALKA sart: nokta koyu bir fotografin uzerine
  ///	gelirse kenari kaybolur ve leke gibi durur.
  /// ⚠️ Konum 45 derece (sag-alt) ve `_avatarCap`tan TURETILIR: sabit dp
  ///	yazilsaydi avatar olcusu degisince nokta daireden KOPARDI.
  Widget _durumNoktasi(BuildContext context, bool acikMi) {
    const cap = 20.0;
    const halka = 3.0;
    // 45 derecelik nokta: merkezden r/√2 kadar saga ve asagi.
    final r = _avatarCap / 2;
    final pay = (_avatarDis - _avatarCap) / 2;
    final k = pay + r + r * 0.7071 - cap / 2;
    return Positioned(
      left: k,
      top: k,
      child: Container(
        width: cap,
        height: cap,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: acikMi ? const Color(0xFF2BB673) : const Color(0xFF8A6A4F),
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: halka,
          ),
        ),
      ),
    );
  }
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

/// ⚠️⚠️⚠️ TURU 179 — **TERS (KONKAV) ALT KOSE.**
///
/// Kullanici: *"logonun arkasindaki slider'in alt sol ve sag alt raduslari
/// YUKARI bakiyor, ASAGI dogru bakmali"*.
///
/// Normal `ClipRRect` kosede yayin merkezini dikdortgenin ICINE koyar; kose
/// yuvarlanarak KESILIR ve kavis yukari bakar:
///
///	|          |          <- normal            |          |   <- ters
///	\__________/                              _/          \_
///
/// Burada merkez tam KOSE NOKTASINA (w, h) alinir ve yay TERS yonde
/// cizilir: kose OYULUR, alt kenarin ORTASI asagi sarkar — yani kavis
/// ASAGI bakar.
///
/// ⚠️ `clockwise: false` KRITIK: `true` birakilirsa yay merkezi yine ice
///	duser ve sonuc SIRADAN bir yuvarlak kose olur (degisiklik
///	EKRANDA HIC GORUNMEZ).
/// ⚠️ Yaricap yuksekligin yarisiyla SINIRLANIR: cok kisa bir kapakta
///	iki yay ust uste binip `Path` kendini KESERDI (kirpma sonucu
///	ongorulemez olur).
class _TersKoseKirpici extends CustomClipper<Path> {
  const _TersKoseKirpici(this.yaricap);

  final double yaricap;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = yaricap.clamp(0.0, h / 2).toDouble();
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - r)
      // ⚠️ Merkez (w, h): yay kosenin ICINI oyar.
      ..arcToPoint(
        Offset(w - r, h),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(r, h)
      ..arcToPoint(
        Offset(0, h - r),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..close();
  }

  @override
  bool shouldReclip(_TersKoseKirpici eski) => eski.yaricap != yaricap;
}

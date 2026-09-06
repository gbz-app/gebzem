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
/// ⚠️ TURU 180d — kavis artik YUKARI dogru (bkz. `_AltKavisKirpici`), yani
///	kapagin ALT KENARI tam `kh`de. Ek pay GEREKMEZ; `+15`
///	kullanicinin "15 px yukselt" emrinden KALIR.
/// ⚠️ TURU 180 — **+15 dp** (kullanici: *"slider 15px daha yukselt"*).
///	Ek yukseklik ORANIN DISINDA toplanir: carpanin icine
///	konsaydi dar ekranda 15 dp'den AZ, genis ekranda FAZLA
///	buyurdu — kullanicinin verdigi olcu MUTLAK.
/// ⚠️ Alt kavisin derinligi (`kKapakKavis`) bu yuksekligin ICINDEDIR:
///	kapak ortada `kh` kadar, kenarlarda `kh - kavis` kadar
///	gorunur. Avatarin dikey konumu da `kh`den turedigi icin
///	ikisi BIRLIKTE kayar.
/// Alt kavisin derinligi. ⚠️ `kapakYuksekligi`ye EKLENIR (bkz. kirpici).
const double kKapakKavis = 22;

double kapakYuksekligi(double genislik) =>
    math.min(genislik * 9 / 16, 240.0) * kKapakKisaltma + 15;

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
            // ⚠️⚠️⚠️ TURU 180 — **ALT KENAR ASAGI DOGRU KAVISLI.**
            //
            //	Turu 179'da kose kose ters radus denendi; kullanici
            //	*"allah askina ALTA DOGRU yapacaksin"* diye
            //	duzeltti. Istenen sey KOSE degil **ALT KENARIN
            //	KENDISI**: ortasi asagi sarkan bir yay.
            //	Bkz. `_AltKavisKirpici`.
            // ⚠️⚠️ **KAVIS PAYI `kh`ye EKLENIR** (`kh + kKapakKavis`):
            //	eklenmezse sarkan koseler `Positioned`in ALT KENARINDA
            //	KIRPILIR ve sekil sirdan bir dikdortgene doner —
            //	degisiklik EKRANDA HIC GORUNMEZ (turu 180'de birebir
            //	bu yasandi). Alt kenarin ORTASI yine tam `kh`de kalir,
            //	yani avatarin konumu (`kh - _tasma`) DEGISMEZ.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: kh + kKapakKavis,
              child: ClipPath(
                clipper: const _AltKavisKirpici(kKapakKavis),
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
          // ⚠️ TURU 180g — yesil **bir tik acildi** (kullanici emri):
          //    #2BB673 -> #34D07F. Kahve DEGISMEDI (kapali durum).
          color: acikMi ? const Color(0xFF34D07F) : const Color(0xFF8A6A4F),
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

/// ⚠️⚠️⚠️ **KAPAK ALT KOSELERI: TERS RADUS (KAVIS MERKEZI DISARIDA).**
///
/// Kullanicinin NET tarifi (uc denemeden sonra): *"header duz olacak,
/// sadece radus asagi dogru olacak; o daire asagi dogru bakacak, ICINDE
/// DEGIL DISINDA bakacak radus"*.
///
/// Normal `ClipRRect`te yayin merkezi dikdortgenin ICINDEDIR ve kose
/// YUVARLANARAK KESILIR. Burada merkez tam KOSE NOKTASINA — yani seklin
/// DISINA — alinir ve yay TERS yonde cizilir:
///
///	   normal              ters (istenen)
///	  |        |          |          |
///	  \________/          _/          \_
///
/// Sonuc: alt kenar ORTADA DUZ kalir, iki alt kose duz hattin ALTINA
/// SARKAR ("kulak"). Alttaki koyu sayfa boylece NORMAL yuvarlak ust
/// koselerle basliyormus gibi gorunur (Spotify/Airbnb deseni).
///
/// ⚠️⚠️ TURU 180f — kullanici bunu EMULATORDE UC SECENEK arasindan
///	SECTI (A normal · B ters/oyuk · C ayna/sarkan). Onceki iki hal
///	(kose noktasinda merkezli oyuk, ve alt kenarin tamami sarkan
///	yay) ACIKCA REDDEDILDI. **Geri donme.**
///
/// ⚠️⚠️ **`clockwise: false` KRITIK**: `true` birakilirsa merkez yine ICE
///	duser ve sonuc SIRADAN bir yuvarlak kose olur — degisiklik
///	EKRANDA HIC GORUNMEZ.
/// ⚠️ Yaricap yuksekligin yarisiyla sinirlanir: kisa bir kapakta iki yay
///	ust uste binip `Path` kendini KESERDI.
class _AltKavisKirpici extends CustomClipper<Path> {
  const _AltKavisKirpici(this.yaricap);

  final double yaricap;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    // ⚠️ Yaricap hem yukseklik hem GENISLIGIN YARISI ile sinirlanir: cok
    //    dar bir kutuda iki yay ust uste biner ve `Path` kendini KESERDI.
    final r = yaricap.clamp(0.0, math.min(h, w / 2)).toDouble();
    // Duz alt kenarin y'si; koseler bunun `r` kadar ALTINA sarkar.
    final taban = h - r;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      // ⚠️ Yan kenar DUZ HATTIN ALTINA iner: kose "kulak" gibi sarkar.
      ..lineTo(w, h)
      // ⚠️ Merkez (w - r, h) — duz alt hattin UZERINDE, seklin DISINDA.
      ..arcToPoint(
        Offset(w - r, taban),
        radius: Radius.circular(r),
        clockwise: false,
      )
      // ⚠️ Alt kenar ORTADA DUZ (kullanici: "header normal duz olacak").
      ..lineTo(r, taban)
      ..arcToPoint(
        Offset(0, h),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..close();
  }

  @override
  bool shouldReclip(_AltKavisKirpici eski) => eski.yaricap != yaricap;
}

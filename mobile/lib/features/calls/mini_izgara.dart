import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// KUCUK PENCERE IZGARASI (test turu 17 — kullanici istegi: "alta indirdigimizde izgara
/// olsun: 2 kisi sol/sag, 3 kisi ustte 2 + altta 1, 4 kisi 4 bolum").
/// Sistem PiP penceresi VE uygulama-ici yuzen pencere bunu kullanir; 1:1 arama, grup
/// aramasi ve canli yayin ORTAK.
///
/// Buyuk izgaradan (yayinIzgara) FARKI: kucuk pencerede bosluk birakmak yerine kutular
/// alani TAMAMEN doldurur (en-boy korunmaz, goruntu `cover` ile kirpilir) — pencere zaten
/// kucuk, ortada bosluk kalmasi kotu duruyordu.
/// En fazla 4 kutu cizilir; kalanlar sag-altta "+N" rozetiyle belirtilir.
/// TEST TURU 41 — [ustUste]: 2 kisilik duzende UST/ALT bolme yerine WhatsApp/Instagram
/// gorunumu — KARSI TARAF tam pencereyi kaplar, KENDI goruntum sag-altta KUCUK bir kutu
/// olarak ONUN USTUNE biner. Kullanici: "karsinin goruntusunun uzerine kendi goruntumde
/// var ufak, o nasil oluyor" + "ekranin uzerine yapacaktik ya".
///
/// ⚠️ Bu YALNIZ kameranin CANLI oldugu yerlerde anlamlidir:
///   · uygulama-ici yuzen pencere (her iki platform, uygulama ON PLANDA)
///   · Android sistem PiP (pencere uygulamanin KENDISI, kamera yasar)
/// iPhone'un SISTEM PiP'inde kamera OS tarafindan durdurulur (olcum: oturum=false,
/// kesinti sebep=1 videoDeviceNotAvailableInBackground) -> orada kucuk kutu DONMUS KARE
/// olurdu; o pencere native cizildigi icin buraya zaten ugramaz.
/// TEST TURU 52 — KUCUK PENCERE IZGARASI (kullanici karari 31 Tem).
/// KURAL (WhatsApp deseni; [kutular] listesinde BEN her zaman SONDAYIM):
///   · 2 kisi  -> karsi taraf TAM pencere, BEN sag-altta kucuk kutu (ustune biner)
///   · 3 kisi  -> iki karsi taraf UST/ALT, BEN yine sag-altta kucuk kutu
///   · 4 kisi  -> HERKES ESIT KUTU: 2x2 ceyrek
///   · 4'ten fazlasi -> ilk 4 kutu + sag-altta "+N" rozeti
///
/// ⚠️ TAVAN 4 (31 Tem, kullanici: "8'li arama ile riske atiyoruz gibi geliyor, aciklari
/// ve buglari minimumda tutmak istiyorum"). Grup aramasi da 4'e indirildi
/// (`maxGrupKatilimci`). Gerekce: SFU iletimi N*(N-1) ile kare artiyor; istemci N-1
/// video COZUYOR ve VP8 iPhone'da yazilimla cozuluyor; 8 kutu ~74x64pt'ye dusuyor;
/// 5-8 icin ayri satir duzenleri kod yuzeyini buyutuyor. CLAUDE.md turu 17 kurali da
/// zaten "4'ten fazla kutu cizme" diyordu.
/// ⚠️ YAPMA: 2/3 kisideki kose kutusunu izgaraya cevirme (WhatsApp gorunumu);
/// tavani backend `maxGrupKatilimci` ile FARKLI yapma.
const int kMiniEnFazlaKutu = 4;

Widget miniIzgara(List<Widget> kutular, {bool ustUste = false}) {
  final hepsi = kutular.length;
  if (hepsi == 0) return const SizedBox.shrink();
  const bosluk = 0.0; // turu 53: kutular arasi SIYAH CIZGI olmasin (kullanici istegi)

  /// Sag-alt kose kutusu (BEN) — buyuk gorunumun USTUNE biner.
  /// TEST TURU 52 — iOS native kutusuyla BIREBIR AYNI olcu (kullanici: "ayni olculer
  /// Android'de de olsun"): genislik %34, en-boy 6:5 (eskiden 4:3 — %10 kisaldi),
  /// kose yaricapi 14 (buyuk ekrandaki kutuyla ayni), CERCEVE YOK, kenar boslugu 5.
  /// ⚠️ YAPMA: bu sayilari iOS tarafindan (AppDelegate `yerelAyarla`) ayirma —
  /// ikisi ayni gorunmek zorunda.
  Widget koseli(Widget buyuk, Widget ben) => LayoutBuilder(builder: (_, c) {
        // ⚠️⚠️ TURU 70 — kullanici istegi "%10 daha genis, %20 daha yuksek".
        // ⚠️⚠️ TURU 70b (DENETIM BULGUSU — ARITMETIK HATASI DUZELTILDI):
        //     Ilk surumde bu iki sayi ARAMA EKRANI kutusundan kopyalanmisti
        //     (0.3720 / 1.5584). Ama iki yuzeyin TABANI FARKLIYDI: arama ekrani
        //     140x200 (en-boy 1.4286), PiP kutusu 0.34W / 6:5 (en-boy 1.2).
        //     Ayni sayiyi kullanmak PiP kutusunu %20 degil **%42** uzatiyordu
        //     ve 5:6 pencerede karsi tarafin videosunun ~yarisini yiyordu.
        //     DOGRUSU: her yuzey KENDI tabanindan buyur.
        //       genislik: 0.34 * 1.10 = 0.3740
        //       yukseklik: 0.34 * 1.2 * 1.20 = 0.4896W -> en-boy 0.4896/0.3740 = 1.3091
        // ⚠️ YAPMA: bu sayilari call_screen.dart icindeki _selfOran/_selfEnBoy
        //     ile ESITLEME — o AYRI bir yuzey ve tabani farkli.
        // ⚠️ Bu iki sayi iOS AppDelegate.swift yerelAyarla icindeki
        //     multiplier degerleriyle BIREBIR AYNI olmali (iPhone sistem PiP
        //     kutusunu orasi cizer) — kullanici emri: iPhone ve Android AYNI.
        final kw = c.maxWidth * 0.3740;
        final kh = kw * 1.3091;
        // ⚠️⚠️ TAVAN 0.405 -> 0.55 (ZORUNLU): yeni kh = 0.4896*W.
        // Eski tavan 0.405*H idi; 5:6 pencerede H = 1.2*W -> tavan = 0.486*W,
        // yani yeni kutuyu KIL PAYI KIRPARDI. Flutter kirpar, iOS (tavansiz)
        // kirpmaz -> Android ile iPhone AYRISIRDI = sikayetin YENI KOPYASI.
        // 0.55*H = 0.66*W ile pay %26 — OEM PiP orani biraz sapsa bile kirpmaz.
        // ⚠️ YAPMA: tavani tamamen KALDIRMA — 3 kutulu duzende kose kutusu iki
        //     dikey kutuyu birden orter (tek yatay korumasi odur).
        final tavan = c.maxHeight * 0.55;
        return Stack(children: [
          Positioned.fill(child: buyuk),
          Positioned(
            right: 5,
            bottom: 5,
            width: kw,
            height: kh > tavan ? tavan : kh,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ben,
            ),
          ),
        ]);
      });

  // 2 kisi: karsi taraf TAM + BEN kosede (turu 41 davranisi, AYNEN korundu).
  if (hepsi == 2 && ustUste) return koseli(kutular[0], kutular[1]);

  // 3 kisi: iki karsi taraf UST/ALT + BEN kosede (turu 52 — kullanici: "1 yukari
  // 2 asagi, ben sagda kucuk"). Kucuk pencere DAR oldugu icin iki dikey goruntuyu
  // yan yana koymak asiri kirpiyordu; ust/alt dogru duruyor (turu 24 dersi).
  if (hepsi == 3 && ustUste) {
    return koseli(
      Column(children: [
        Expanded(child: kutular[0]),
        const SizedBox(height: bosluk),
        Expanded(child: kutular[1]),
      ]),
      kutular[2],
    );
  }

  final n = hepsi > kMiniEnFazlaKutu ? kMiniEnFazlaKutu : hepsi;

  // Son satirda TEK kutu kalirsa: tek `Expanded` satirin TAMAMINI kaplar, yani kutu
  // kendiliginden TAM GENISLIK olur (yarim genislikte solda kalmaz) — ek kod gerekmez.
  Widget satir(List<Widget> ogeler) => Row(children: [
        for (var i = 0; i < ogeler.length; i++) ...[
          if (i > 0) const SizedBox(width: bosluk),
          Expanded(child: ogeler[i]),
        ],
      ]);

  Widget icerik;
  if (n == 1) {
    icerik = kutular[0];
  } else if (n == 2) {
    // 2 kisi (kose kutusu KAPALI yol): UST - ALT (turu 24 kullanici istegi).
    icerik = Column(children: [
      Expanded(child: kutular[0]),
      const SizedBox(height: bosluk),
      Expanded(child: kutular[1]),
    ]);
  } else {
    // 3-8 kisi: 2 SUTUN, son satirda tek kalirsa TAM GENISLIK.
    // (Tam ekran grup izgarasiyla AYNI kural — tutarli gorunum.)
    const sutun = 2;
    final satirSayisi = (n + sutun - 1) ~/ sutun;
    icerik = Column(children: [
      for (var r = 0; r < satirSayisi; r++) ...[
        if (r > 0) const SizedBox(height: bosluk),
        Expanded(
          child: satir([
            for (var i = r * sutun; i < ((r + 1) * sutun).clamp(0, n); i++)
              kutular[i],
          ]),
        ),
      ],
    ]);
  }
  if (hepsi <= kMiniEnFazlaKutu) return icerik;
  return Stack(children: [
    Positioned.fill(child: icerik),
    Positioned(
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(8)),
        child: Text('+${hepsi - kMiniEnFazlaKutu}',
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    ),
  ]);
}

/// Kucuk pencere kutusu: video VARSA render, yoksa harf avatari (kamera kapali / sesli).
/// TEST TURU 52 — TUTARLI "KAMERA DURAKLATILDI" GORUNUMU.
/// Kullanici: "yazinin arkasinda BAZEN mor daire var, hep ayni olsun."
/// Ayni durum eskiden UC FARKLI bicimde ciziliyordu: uygulama icinde blur+yazi,
/// iOS PiP'te mor daire+yazi, Android PiP'te mor daire+HARF (yazi YOK).
/// Artik UC yerde de AYNI: koyu zemin + siyah seffaf hap icinde beyaz yazi.
/// ⚠️ YAPMA: buraya CircleAvatar / mor daire geri koyma.
class _DuraklatildiOrtusu extends StatelessWidget {
  const _DuraklatildiOrtusu();
  static const metin = 'Kamera duraklatıldı';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16202A),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          metin,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class MiniKutu extends StatelessWidget {
  const MiniKutu({
    super.key,
    this.track,
    this.harf = '?',
    this.mirror = false,
    this.beklemede = false,
  });

  final lk.VideoTrack? track;
  final String harf;
  final bool mirror;

  /// Track VAR ama kamera KAPALI: son kare yerine ortu cizilir (donmus kare gostermeyiz).
  final bool beklemede;

  @override
  Widget build(BuildContext context) {
    final t = track;
    if (t == null || beklemede) {
      // Track hic yok VEYA mute -> AYNI gorunum (mor daire YOK).
      return const _DuraklatildiOrtusu();
    }
    return IgnorePointer(
      child: lk.VideoTrackRenderer(t,
          key: ValueKey('mini-${t.mediaStreamTrack.id}'),
          fit: lk.VideoViewFit.cover,
          mirrorMode: mirror
              ? lk.VideoViewMirrorMode.mirror
              : lk.VideoViewMirrorMode.off),
    );
  }
}

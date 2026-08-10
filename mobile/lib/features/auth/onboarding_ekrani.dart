import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tercihler.dart';
import '../../core/theme.dart';

/// ⚠️⚠️⚠️ TURU 81 — ILK ACILIS ONBOARDING (4 EKRAN).
///
/// Kullanici emri: *"uygulama ilk acilisinda 4 tane onboarding olsun"* +
/// gonderdigi ekran goruntuleri (kalin baslik, bir kelimesi **italik vurgu**,
/// altinda gorsel/kart kompozisyonu).
///
/// ═══════════ TASARIM KARARLARI ═══════════
///
/// ⚠️ GORSEL ASSET **KULLANILMIYOR**, kompozisyon KOD ILE ciziliyor. Gerekce:
///   · Uygulamada bugun `assets/` altinda YALNIZ ikon kaynagi var; onboarding
///     icin 4 adet yuksek cozunurluklu gorsel eklemek APK'yi buyutur ve her
///     cihaz oraninda dogru gorunmesi icin birden fazla varyant ister.
///   · Kod ile cizilen kompozisyon TEMAYA UYUM SAGLAR (acik/koyu) — sabit
///     gorsel acik temada yanlis kontrastla dururdu.
/// ⚠️ EMOJI YOK — Lucide 2B ikon (kullanici emri, turu 62).
///
/// ⚠️⚠️ "GORULDU" BAYRAGI **SON SAYFADA DEGIL, CIKISTA** yazilir: kullanici
///    "Atla" derse de bir daha gormemeli. Yalniz son sayfada yazilsaydi
///    atlayan kullanici her acilista tekrar gorurdu.
/// ⚠️ Bayrak CIHAZ YERELIDIR (`shared_preferences`) — hesaba bagli degil.
///    Sunucuya yazmak yeni bir uc + migration demekti ve onboarding'in
///    hesaptan ONCE gosterilmesi gerekiyor (henuz oturum YOK).
class OnboardingEkrani extends ConsumerStatefulWidget {
  const OnboardingEkrani({super.key, required this.onBitti});

  /// ⚠️ Yonlendirmeyi EKRAN YAPMAZ, cagiran yapar (router tek kaynak).
  final VoidCallback onBitti;

  @override
  ConsumerState<OnboardingEkrani> createState() => _OnboardingEkraniState();
}

class _OnboardingEkraniState extends ConsumerState<OnboardingEkrani> {
  final _ctrl = PageController();
  int _sayfa = 0;

  /// ⚠️⚠️ TURU 84 — ACIKLAMALAR **KISALTILDI** (kullanici emri: *"baslik alta
  ///    KISA PROFESYONEL aciklama"*). Onceki metinler iki cumleydi ve ozellik
  ///    SAYIYORDU ("gruplar, sesli odalar, canli yayin da burada").
  ///    Yeni metinler TEK CUMLE ve **faydayi** soyluyor, ozellik listelemiyor —
  ///    profesyonel onboarding dili budur.
  /// ⚠️ YAPMA: buraya ozellik listesi geri koyma; her satir tek cumle kalsin.
  static const _sayfalar = <_Sayfa>[
    _Sayfa(
      baslik: 'Mesajlaş, ara,',
      vurgu: 'görüntülü konuş',
      alt: 'Yakınlarınla anlık mesajlaş, sesli ve görüntülü görüş.',
      ikonlar: [LucideIcons.messageCircle, LucideIcons.phone, LucideIcons.video],
    ),
    _Sayfa(
      baslik: 'Paylaş,',
      vurgu: 'keşfet',
      alt: 'Anlarını paylaş, şehrinde olan biteni akışında gör.',
      ikonlar: [LucideIcons.images, LucideIcons.compass, LucideIcons.heart],
    ),
    _Sayfa(
      baslik: 'Şehrindeki',
      vurgu: 'işletmeler',
      alt: 'Restoran, kuaför, doktor — hepsi tek uygulamada.',
      ikonlar: [LucideIcons.store, LucideIcons.utensils, LucideIcons.ticket],
    ),
    _Sayfa(
      baslik: 'Rezervasyon ve',
      vurgu: 'randevu',
      alt: 'Müsait saati seç, randevunu tek dokunuşla al.',
      ikonlar: [
        LucideIcons.calendarCheck,
        LucideIcons.clock,
        LucideIcons.circleCheck,
      ],
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _bitir() async {
    // ⚠️ Bayrak ONCE yazilir, sonra yonlendirilir: ters sirada olsaydi
    //    yonlendirme sirasinda uygulama oldurulurse onboarding TEKRAR cikardi.
    await tercihler.onboardingGorulduYaz();
    if (mounted) widget.onBitti();
  }

  @override
  Widget build(BuildContext context) {
    final son = _sayfa == _sayfalar.length - 1;
    return Scaffold(
      // ⚠️⚠️ TURU 84 — **ZEMIN BEYAZ** (kullanici emri: "arka plan beyaz").
      //
      //    Tema `scaffoldBackgroundColor`i KULLANILMAZ: koyu temada zemin
      //    `0xFF1C1C1E` olurdu ve kullanicinin acikca istedigi beyaz tasarim
      //    yalnizca acik temadaki kullanicilarda gorunurdu.
      // ⚠️ ZEMIN SABITLENDIGI ICIN YAZI RENKLERI DE SABIT (`_kOnboardYazi` /
      //    `_kOnboardAltYazi`). Temadan alinsaydi koyu temada BEYAZ yazi
      //    BEYAZ zemine cizilirdi — turu 81b'de sohbet balonlarinda yasanan
      //    1.23:1 kontrast hatasinin birebir aynisi.
      // ⚠️ YAPMA: buradaki renkleri temaya baglama.
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              // ⚠️ Renk SABIT: temadan alinsaydi koyu temada BEYAZ olur ve
              //    beyaz zeminde GORUNMEZDI (zemin artik sabit beyaz).
              child: TextButton(
                onPressed: _bitir,
                style: TextButton.styleFrom(foregroundColor: _kOnboardAltYazi),
                child: const Text('Atla'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _sayfalar.length,
                onPageChanged: (i) => setState(() => _sayfa = i),
                itemBuilder: (_, i) => _SayfaGorunumu(s: _sayfalar[i]),
              ),
            ),
            // Nokta gostergesi
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_sayfalar.length, (i) {
                final aktif = i == _sayfa;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: aktif ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    // ⚠️ Pasif nokta rengi de SABIT (zemin beyaz — temadan
                    //    alinsaydi koyu temada beyaz nokta beyaz zemine
                    //    cizilir ve gosterge KAYBOLURDU).
                    color: aktif
                        ? morLogo
                        : _kOnboardAltYazi.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: son
                      ? _bitir
                      : () => _ctrl.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: morLogo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    son ? 'Başla' : 'Devam',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⚠️ Onboarding zemini SABIT BEYAZ oldugu icin yazi renkleri de SABIT.
///    Temadan alinsalardi koyu temada beyaz-uzeri-beyaz cikardi.
const Color _kOnboardYazi = Color(0xFF14141A);
const Color _kOnboardAltYazi = Color(0xFF6B6B76);

class _Sayfa {
  const _Sayfa({
    required this.baslik,
    required this.vurgu,
    required this.alt,
    required this.ikonlar,
  });

  final String baslik;

  /// Baslikta ITALIK ve MOR cizilen kelime (kullanicinin gonderdigi tasarim).
  final String vurgu;
  final String alt;
  final List<IconData> ikonlar;
}

class _SayfaGorunumu extends StatelessWidget {
  const _SayfaGorunumu({required this.s});

  final _Sayfa s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      child: Column(
        // ⚠️⚠️ TURU 84 — **YAZILAR SOLA DAYALI** (kullanici emri: *"arka plan
        //    beyaz, yazilar solda, baslik alta kisa profesyonel aciklama"*).
        //    Onceki tasarim her seyi ORTALIYORDU.
        // ⚠️ `crossAxisAlignment: start` TEK BASINA YETMEZ: `Text` ve
        //    `RichText` kendi ICLERINDE de `textAlign` tasir; ikisi de
        //    `TextAlign.left`a cevrildi. Yalniz biri degistirilseydi cok
        //    satirli baslik yine ortalanirdi.
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ⚠️ Gorsel kompozisyon da SOLA hizalandi; ortada birakilsaydi
          //    yazilarla ayni dikey cizgide durmaz, tasarim dagilirdi.
          SizedBox(
            height: 168,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _kart(scheme, s.ikonlar[0], 78, 100, 0.5),
                const SizedBox(width: 10),
                _kart(scheme, s.ikonlar[1], 100, 140, 1.0),
                const SizedBox(width: 10),
                _kart(scheme, s.ikonlar[2], 78, 100, 0.5),
              ],
            ),
          ),
          const SizedBox(height: 40),
          RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              style: TextStyle(
                fontSize: 30,
                height: 1.18,
                fontWeight: FontWeight.w800,
                // ⚠️ Zemin BEYAZ oldugu icin yazi rengi TEMADAN ALINMAZ —
                //    koyu temada beyaz yaziyi beyaz zemine cizerdi (turu 81b'de
                //    sohbet balonlarinda yasanan 1.23:1 kontrast hatasinin
                //    birebir aynisi).
                color: _kOnboardYazi,
              ),
              children: [
                TextSpan(text: '${s.baslik}\n'),
                TextSpan(
                  text: s.vurgu,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: morLogo,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.alt,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: _kOnboardAltYazi,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kart(
    ColorScheme scheme,
    IconData ikon,
    double g,
    double y,
    double opaklik,
  ) => Opacity(
    opacity: opaklik,
    child: Container(
      width: g,
      height: y,
      decoration: BoxDecoration(
        gradient: morGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: morLogo.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(ikon, color: Colors.white, size: g * 0.38),
    ),
  );
}

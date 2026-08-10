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

  static const _sayfalar = <_Sayfa>[
    _Sayfa(
      baslik: 'Mesajlaş, ara,',
      vurgu: 'görüntülü konuş',
      alt:
          'Anlık mesajlaşma, sesli ve görüntülü arama. '
          'Gruplar, sesli odalar ve canlı yayın da burada.',
      ikonlar: [LucideIcons.messageCircle, LucideIcons.phone, LucideIcons.video],
    ),
    _Sayfa(
      baslik: 'Paylaş,',
      vurgu: 'keşfet',
      alt:
          'Fotoğraf ve videolarını paylaş, hikâye at. '
          'Takip ettiklerin ve Keşfet akışıyla şehrinde olan biteni gör.',
      ikonlar: [LucideIcons.images, LucideIcons.compass, LucideIcons.heart],
    ),
    _Sayfa(
      baslik: 'Şehrindeki',
      vurgu: 'işletmeler',
      alt:
          'Restoran, kuaför, doktor, eğitim, sağlık… '
          'Menülere bak, ürünleri incele, etkinlikleri kaçırma.',
      ikonlar: [LucideIcons.store, LucideIcons.utensils, LucideIcons.ticket],
    ),
    _Sayfa(
      baslik: 'Rezervasyon ve',
      vurgu: 'randevu',
      alt:
          'Restoranda masa ayırt, doktordan randevu al. '
          'Müsait saatleri gör, tek dokunuşla talebini gönder.',
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
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _bitir,
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
                    color: aktif
                        ? morLogo
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.25),
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
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ⚠️ Kompozisyon: uc yuvarlak kart, ortadaki buyuk. Gonderilen
          //    tasarimdaki "kart yigini" hissini asset olmadan verir.
          SizedBox(
            height: 190,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _kart(scheme, s.ikonlar[0], 92, 120, 0.55),
                const SizedBox(width: 12),
                _kart(scheme, s.ikonlar[1], 118, 165, 1.0),
                const SizedBox(width: 12),
                _kart(scheme, s.ikonlar[2], 92, 120, 0.55),
              ],
            ),
          ),
          const SizedBox(height: 36),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 28,
                height: 1.22,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
              children: [
                TextSpan(text: '${s.baslik}\n'),
                TextSpan(
                  text: s.vurgu,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: morLogoAcik,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.alt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.62),
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

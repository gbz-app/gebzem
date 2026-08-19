import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../core/tercihler.dart';
// ⚠️ TURU 89 — izin dizisi TEK KAYNAK (bkz. o dosyanin serhi).
import '../auth/permissions_screen.dart' show izinleriTopluIste;
import 'ayar_bilesenleri.dart';

/// ⚠️⚠️⚠️ TURU 81 — AYARLAR. Uygulamada BUGUNE KADAR HIC ayarlar ekrani yoktu.
///
/// Kullanici emri: *"dark ve beyaz 2 tema olarak yapalim, ayarlardan beyaz
/// temayi da secelim"*.
///
/// ⚠️ UC SECENEK sunuluyor (iki degil): **Sistem** varsayilan kalir, cunku
///    telefonunu gece otomatik koyuya alan kullanicilarin cogunlugu icin
///    dogru davranis budur ve uygulamayi sistemden KOPARMAK bir gerileme
///    olurdu. Kullanicinin istedigi "beyaz temayi secebilme" bu kumede
///    ZATEN var.
/// ⚠️ Secim ANINDA uygulanir (kaydet dugmesi YOK) — tema degisikligi geri
///    donusu kolay ve sonucu aninda gorunur bir tercihtir.
///
/// ⚠️⚠️ TURU 105 — GORUNUM, Profil sekmesiyle **AYNI BILESENLERDEN** kuruldu
///	(`AyarBolumu` / `AyarSatiri`). Iki ekran ayri ayri stillenirse
///	kacinilmaz olarak drift eder.
/// ⚠️ Eski `_Baslik` bileseninde **`letterSpacing: 1.1`** vardi — kullanici
///    emriyle harf araligi YASAK; bolum basliklari artik ortak bilesenden
///    gelir ve harf araligi kullanmaz.
class AyarlarEkrani extends ConsumerWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mod = ref.watch(temaProvider);
    final harita = ref.watch(haritaStiliProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AyarBolumu(
            baslik: 'Görünüm',
            satirlar: [
              _tema(
                ref,
                mod,
                ThemeMode.system,
                LucideIcons.smartphone,
                'Sistem',
                'Telefonun ayarını izler',
              ),
              _tema(
                ref,
                mod,
                ThemeMode.light,
                LucideIcons.sun,
                'Açık',
                'Beyaz tema',
              ),
              _tema(
                ref,
                mod,
                ThemeMode.dark,
                LucideIcons.moon,
                'Koyu',
                'Siyah tema',
              ),
            ],
          ),
          // ⚠️⚠️ TURU 89 — HARITA RENGI (kullanici emri: *"ayarlardan harita
          //    rengi ayarlanmali, GECE ve UBER'in gri beyaz tarzi"*).
          //    Secim `haritaStiliProvider`da; harita `style:` parametresini
          //    CALISMA ANINDA guncelliyor (yeniden kurulmuyor).
          AyarBolumu(
            baslik: 'Harita',
            satirlar: [
              _harita(
                ref,
                harita,
                'sistem',
                LucideIcons.smartphone,
                'Sistem',
                'Uygulama temasına uyar',
              ),
              _harita(
                ref,
                harita,
                'gri',
                LucideIcons.map,
                'Açık gri',
                'Sade, düşük renkli gündüz görünümü',
              ),
              _harita(
                ref,
                harita,
                'gece',
                LucideIcons.moonStar,
                'Gece',
                'Koyu harita',
              ),
            ],
          ),
          // ⚠️⚠️⚠️ TURU 89 — IZIN KURTARMA YOLU **ZORUNLU**.
          //
          //	Bu tur, ayri izin ekranini (`PermissionsScreen` + kayit 4. adim)
          //	KALDIRDI ve izinleri onboarding sayfalarina tasidi. Onboarding
          //	bayragi KALICIDIR (`shared_preferences`), yani bir kez bitiren
          //	kullanici o sayfalari BIR DAHA GORMEZ.
          //	Bu giris OLMASAYDI: izinleri reddeden kullanicinin uygulamayi
          //	SILIP YENIDEN KURMAKTAN baska donus yolu KALMAZDI.
          // ⚠️ YAPMA: bu girisi kaldirma.
          AyarBolumu(
            baslik: 'İzinler',
            satirlar: [
              AyarSatiri(
                ikon: LucideIcons.shieldCheck,
                baslik: 'İzinleri yeniden iste',
                altBaslik: 'Mikrofon, kamera, bildirim, kilit ekranı',
                onTap: () async {
                  await izinleriTopluIste();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('İzin ayarları güncellendi')),
                  );
                },
              ),
              AyarSatiri(
                ikon: LucideIcons.settings,
                baslik: 'Telefon ayarlarını aç',
                altBaslik: 'Kalıcı reddedilen izinler yalnızca buradan verilir',
                // ⚠️ "Bir daha sorma" denmis bir izin `request()` ile ASLA geri
                //    alinamaz; tek yol sistem ayarlaridir.
                onTap: openAppSettings,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 0),
            child: Text(
              'Bu ayarlar bu cihazda saklanır; hesabına bağlı değildir.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tema secenegi.
  ///
  /// ⚠️ Secili durum IKI isaretle anlatilir: tik ikonu + vurgulu renk. Tek
  ///    isaret (yalniz renk) renk korlugunde ayirt edilemezdi.
  Widget _tema(
    WidgetRef ref,
    ThemeMode mevcut,
    ThemeMode deger,
    IconData ikon,
    String baslik,
    String altBaslik,
  ) => AyarSatiri(
    ikon: ikon,
    baslik: baslik,
    altBaslik: altBaslik,
    secili: mevcut == deger,
    onTap: () => ref.read(temaProvider.notifier).ayarla(deger),
  );

  /// Harita stili secenegi — tema `_tema`sinin ikizi.
  ///
  /// ⚠️ Ayri bir yardimci: tema `ThemeMode`, harita `String` tutuyor. Tek
  ///    jenerik yardimci yazmak iki tercihin tipini gevsetirdi.
  Widget _harita(
    WidgetRef ref,
    String mevcut,
    String deger,
    IconData ikon,
    String baslik,
    String altBaslik,
  ) => AyarSatiri(
    ikon: ikon,
    baslik: baslik,
    altBaslik: altBaslik,
    secili: mevcut == deger,
    onTap: () => ref.read(haritaStiliProvider.notifier).ayarla(deger),
  );
}

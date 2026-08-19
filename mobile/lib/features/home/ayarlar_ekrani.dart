import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../core/tercihler.dart';
// ⚠️ TURU 89 — izin dizisi TEK KAYNAK (bkz. o dosyanin serhi).
import '../auth/permissions_screen.dart' show izinleriTopluIste;
import '../sosyal/sosyal_servisi.dart' show sosyalServisiProvider;
import 'ayar_bilesenleri.dart';
import 'home_screen.dart' show myProfileProvider;

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
class AyarlarEkrani extends ConsumerStatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  ConsumerState<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends ConsumerState<AyarlarEkrani> {
  /// ⚠️ Istek ucarken anahtar KILITLENIR: cift dokunus iki PATCH atar ve
  ///    ikinci yanit birincinin sonucunu EZER.
  bool _gizlilikMesgul = false;

  @override
  Widget build(BuildContext context) {
    final mod = ref.watch(temaProvider);
    final harita = ref.watch(haritaStiliProvider);
    final profil = ref.watch(myProfileProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // ⚠️⚠️⚠️ TURU 107 — **GIZLI HESAP** (kullanici emri: *"profilde
          //	gizli hesap alani orada olmamali, ayarlarda olacak"*).
          //
          // ⚠️⚠️ BU ANAHTARIN BIR GIRISI OLMAK ZORUNDA. Turu 75b denetimi
          //	olctu: anahtar hicbir yerden cagrilmayinca hicbir kullanici
          //	gizli hesap OLAMIYOR ve buna bagli HER SEY olu kaliyor —
          //	takip isteginin "bekliyor" dali, FollowApprove/Reject uclari,
          //	"Takip istekleri" ekrani, profil ve liste kilit dallari.
          // ⚠️ YAPMA: bu satiri kaldirma; profile geri koyup burada da
          //    birakma (ayni kuralin iki kopyasi drift eder).
          // ⚠️ Profil henuz gelmediyse bolum CIZILMEZ: varsayilan `false`
          //    gostermek "hesabin acik" YALANI olurdu.
          if (profil != null)
            AyarBolumu(
              baslik: 'Gizlilik',
              satirlar: [
                _gizliHesap(profil),
              ],
            ),
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

  /// Gizli hesap anahtari.
  ///
  /// ⚠️ `AyarSatiri` bir SATIRDIR, anahtar degil: durum sagdaki DEGER
  ///    metniyle ("Açık"/"Kapalı") ve dokunusla cevrilir. Ayri bir
  ///    `Switch` bileseni eklemek gruplu kart dilini bozardi.
  /// ⚠️ Durum RENKLE degil METINLE anlatilir (renk korlugu).
  Widget _gizliHesap(Map<String, dynamic> profil) {
    final gizli = profil['gizli'] == true;
    return AyarSatiri(
      ikon: gizli ? LucideIcons.lock : LucideIcons.lockOpen,
      baslik: 'Gizli hesap',
      altBaslik: 'Gönderilerini yalnızca onayladığın takipçiler görür',
      deger: _gizlilikMesgul ? '...' : (gizli ? 'Açık' : 'Kapalı'),
      onTap: _gizlilikMesgul ? null : () => _gizlilikCevir(!gizli),
    );
  }

  Future<void> _gizlilikCevir(bool yeni) async {
    setState(() => _gizlilikMesgul = true);
    try {
      await ref.read(sosyalServisiProvider).gizlilikAyarla(yeni);
      if (!mounted) return;
      // ⚠️ Profil TAMAMEN tazelenir: gizliden ACIGA gecerken sunucu
      //    BEKLEYEN TUM istekleri otomatik onaylar ve takipci sayisi
      //    DEGISIR — yerel yamalama yanlis sayi gosterirdi.
      ref.invalidate(myProfileProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gizlilik ayarı değiştirilemedi')),
      );
    } finally {
      if (mounted) setState(() => _gizlilikMesgul = false);
    }
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

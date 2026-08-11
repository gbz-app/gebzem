import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../../core/tercihler.dart';
// ⚠️ TURU 89 — izin dizisi TEK KAYNAK (bkz. o dosyanin serhi).
import '../auth/permissions_screen.dart' show izinleriTopluIste;

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
class AyarlarEkrani extends ConsumerWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mod = ref.watch(temaProvider);
    final harita = ref.watch(haritaStiliProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          const _Baslik('GÖRÜNÜM'),
          _secenek(
            context,
            ref,
            mod,
            ThemeMode.system,
            LucideIcons.smartphone,
            'Sistem',
            'Telefonun ayarını izler',
          ),
          _secenek(
            context,
            ref,
            mod,
            ThemeMode.light,
            LucideIcons.sun,
            'Açık',
            'Beyaz tema',
          ),
          _secenek(
            context,
            ref,
            mod,
            ThemeMode.dark,
            LucideIcons.moon,
            'Koyu',
            'Siyah tema',
          ),
          const Divider(height: 32),
          // ⚠️⚠️ TURU 89 — HARITA RENGI (kullanici emri: *"ayarlardan harita
          //    rengi ayarlanmali, GECE ve UBER'in gri beyaz tarzi"*).
          //    Secim `haritaStiliProvider`da; harita `style:` parametresini
          //    CALISMA ANINDA guncelliyor (yeniden kurulmuyor).
          const _Baslik('HARİTA'),
          _haritaSecenek(context, ref, harita, 'sistem', LucideIcons.smartphone,
              'Sistem', 'Uygulama temasına uyar'),
          _haritaSecenek(context, ref, harita, 'gri', LucideIcons.map,
              'Açık gri', 'Sade, düşük renkli gündüz görünümü'),
          _haritaSecenek(context, ref, harita, 'gece', LucideIcons.moonStar,
              'Gece', 'Koyu harita'),
          const Divider(height: 32),
          // ⚠️⚠️⚠️ TURU 89 — IZIN KURTARMA YOLU **ZORUNLU**.
          //
          //	Bu tur, ayri izin ekranini (`PermissionsScreen` + kayit 4. adim)
          //	KALDIRDI ve izinleri onboarding sayfalarina tasidi. Onboarding
          //	bayragi KALICIDIR (`shared_preferences`), yani bir kez bitiren
          //	kullanici o sayfalari BIR DAHA GORMEZ.
          //	Bu giris OLMASAYDI: izinleri reddeden kullanicinin uygulamayi
          //	SILIP YENIDEN KURMAKTAN baska donus yolu KALMAZDI.
          // ⚠️ YAPMA: bu girisi kaldirma.
          const _Baslik('İZİNLER'),
          ListTile(
            leading: const Icon(LucideIcons.shieldCheck),
            title: const Text('İzinleri yeniden iste'),
            subtitle: const Text(
              'Mikrofon, kamera, bildirim ve kilit ekranı arama izni',
            ),
            onTap: () async {
              await izinleriTopluIste();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('İzin ayarları güncellendi')),
              );
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.settings),
            title: const Text('Telefon ayarlarını aç'),
            subtitle: const Text(
              'Kalıcı olarak reddettiğin izinler yalnızca buradan verilebilir',
            ),
            // ⚠️ "Bir daha sorma" denmis bir izin `request()` ile ASLA geri
            //    alinamaz; tek yol sistem ayarlaridir.
            onTap: () => openAppSettings(),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Bu ayarlar bu cihazda saklanır; hesabına bağlı değildir.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// Harita stili secenegi — tema `_secenek`inin ikizi.
  ///
  /// ⚠️ Ayri bir yardimci: tema `ThemeMode`, harita `String` tutuyor. Tek
  ///    jenerik yardimci yazmak iki tercihin tipini gevsetirdi.
  Widget _haritaSecenek(
    BuildContext context,
    WidgetRef ref,
    String mevcut,
    String deger,
    IconData ikon,
    String baslik,
    String altBaslik,
  ) {
    final secili = mevcut == deger;
    return ListTile(
      leading: Icon(ikon),
      title: Text(baslik),
      subtitle: Text(altBaslik),
      trailing: secili
          ? Icon(LucideIcons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => ref.read(haritaStiliProvider.notifier).ayarla(deger),
    );
  }

  Widget _secenek(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mevcut,
    ThemeMode deger,
    IconData ikon,
    String baslik,
    String altBaslik,
  ) {
    final secili = mevcut == deger;
    return ListTile(
      leading: Icon(ikon),
      title: Text(baslik),
      subtitle: Text(altBaslik),
      // ⚠️ Secili durum IKI isaretle: tik ikonu + kalin baslik degil, tik +
      //    vurgulu renk. Tek isaret renk korlugunde ayirt edilemezdi.
      trailing: secili
          ? Icon(LucideIcons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => ref.read(temaProvider.notifier).ayarla(deger),
    );
  }
}

/// Bolum basligi (GÖRÜNÜM / HARİTA ...).
///
/// ⚠️ Iki bolum ayni bicimi kullaniyor; elle kopyalansaydi biri degistiginde
///    oteki geride kalirdi.
class _Baslik extends StatelessWidget {
  const _Baslik(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(
      metin,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: Colors.grey,
      ),
    ),
  );
}

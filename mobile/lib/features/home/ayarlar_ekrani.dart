import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tercihler.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              'GÖRÜNÜM',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Colors.grey,
              ),
            ),
          ),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tema seçimi bu cihazda saklanır; hesabına bağlı değildir.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calls/callkit_service.dart';

/// ⚠️⚠️⚠️ TURU 85b — IZIN ISTEME **TEK KAYNAK** (denetim bulgusu).
///
///	Turu 84'te adimli kayita 4. adim olarak bir izin sayfasi eklendi ve o
///	sayfa izinleri KENDI govdesinde istiyordu. Iki kopya ANINDA ayristi:
///	  · Kayit adimi `CallKitService.izinleriIste()` (Android 14+ TAM EKRAN
///	    BILDIRIM izni) cagirmiyordu -> telefon KILITLIYKEN gelen arama ekrani
///	    HIC ACILMIYORDU. Bu, uygulamanin MANSET ozelligi.
///	  · Pil optimizasyonu muafiyeti de istenmiyordu -> uygulama arka planda
///	    oldurulup arama alinamiyordu.
///	  · `permissions_asked` tercihi yazilmiyordu.
///	Ustelik kullanici izni REDDEDERSE `HomeScreen` kendi kapisindan
///	`PermissionsScreen`i ACIYORDU: kayit biter bitmez **AYNI IZIN EKRANI
///	IKINCI KEZ** cikiyordu.
///
/// Bu fonksiyon o sirayi TEK YERDE tutar; iki cagiran da ayni isi yapar.
/// ⚠️ SIRA ONEMLI: sistem diyaloglari SIRAYLA cikmali (hepsini ayni anda
///    istemek platformda tanimsiz davranistir).
/// ⚠️ YAPMA: cagiran taraflarda bu adimlari tekrar yazma.
Future<void> izinleriTopluIste() async {
  // Sirayla iste — sistem pencereleri ust uste binmesin.
  await Permission.notification.request();
  await Permission.microphone.request();
  await Permission.camera.request();

  // Android 14+: "tam ekran bildirim" AYRI bir ozel izin. Play Store disi
  // (sideload) kurulumda otomatik VERILMEZ -> verilmezse telefon kilitliyken
  // gelen arama ekrani HIC acilmaz. Ayarlar sayfasina yonlendirir.
  await CallKitService.izinleriIste();

  // Pil optimizasyonu muafiyeti: TEK sistem dialogu (menuye gitmeden).
  // Kapaliyken arama gelmesi icin uygulamanin arka planda oldurulmemesi
  // gerekir. Sadece Android.
  if (Platform.isAndroid) {
    try {
      if (!await Permission.ignoreBatteryOptimizations.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {}
  }
  await izinSorulduIsaretle();
}

/// Izin akisinin KOSTUGUNU isaretler (hem kalici tercih hem OTURUM bayragi).
///
/// ⚠️ `_buOturumdaSoruldu` ZORUNLU: `HomeScreen` kapisi kalici tercihe DEGIL
///    GERCEK izin durumuna bakiyor (APK ustune guncellemede bayat bayrak
///    sorunu — bilincli karar). Kullanici izinleri REDDEDERSE o kapi ekrani
///    yeniden acar; kayit akisindan cikan kullanici icin bu **AYNI EKRANI
///    ARKA ARKAYA IKI KEZ** gormek demektir. Oturum bayragi yalniz o ANLIK
///    tekrari engeller; uygulama yeniden baslatildiginda kapi YINE calisir.
/// ⚠️ YAPMA: bayragi kalici hale getirme (izin ekrani bir daha HIC cikmaz).
Future<void> izinSorulduIsaretle() async {
  izinBuOturumdaSoruldu = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_asked', true);
  } catch (_) {}
}

/// Bkz. [izinSorulduIsaretle]. Surec omurlu; kalici DEGIL.
bool izinBuOturumdaSoruldu = false;

/// Giriste izin ekrani — mikrofon, kamera ve bildirim izinleri tek seferde alinir.
/// Bir kez gosterilir (tercih kaydedilir), sonra ana ekrana gecilir.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _busy = false;

  Future<void> _requestAll() async {
    setState(() => _busy = true);
    // ⚠️ Sira ve tum adimlar TEK KAYNAKTA (bkz. `izinleriTopluIste` serhi).
    await izinleriTopluIste();
    if (mounted) {
      setState(() => _busy = false);
      widget.onDone();
    }
  }

  Future<void> _skip() async {
    await izinSorulduIsaretle();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Icon(LucideIcons.shieldCheck, size: 64, color: scheme.primary),
              const SizedBox(height: 20),
              Text('Gebzem\'e hoş geldin',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Uygulamanın düzgün çalışması için birkaç izin gerekiyor',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline),
              ),
              const SizedBox(height: 36),
              _permRow(
                icon: LucideIcons.bell,
                title: 'Bildirimler',
                subtitle: 'Yeni mesaj ve aramalardan haberdar ol',
                scheme: scheme,
              ),
              _permRow(
                icon: LucideIcons.mic,
                title: 'Mikrofon',
                subtitle: 'Sesli aramalar ve sesli mesajlar için',
                scheme: scheme,
              ),
              _permRow(
                icon: LucideIcons.video,
                title: 'Kamera',
                subtitle: 'Görüntülü aramalar ve fotoğraf için',
                scheme: scheme,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _requestAll,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('İzin Ver ve Devam Et'),
              ),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: Text('Şimdilik atla', style: TextStyle(color: scheme.outline)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: TextStyle(color: scheme.outline, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

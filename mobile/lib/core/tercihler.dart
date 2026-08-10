import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ⚠️⚠️ TURU 81 — CIHAZ TERCIHLERI (tema, onboarding gorulme durumu).
///
/// ═══════════ NEDEN `AppStorage` DEGIL ═══════════
///
/// `AppStorage` **guvenli depo**dur (Keychain/Keystore) ve orada YALNIZ
/// oturum jetonu + kullanici kimligi durur. Tema tercihi ve "onboarding
/// gorulda mu" bilgisi SIR DEGILDIR; guvenli depoya yazmak
///   (a) her okumada kripto islemi demektir (acilis yolunda gereksiz gecikme),
///   (b) iOS'ta `first_unlock` oncesi `PlatformException` firlatir ve tema
///       okunamazsa uygulama YANLIS temada acilirdi.
/// ⚠️ YAPMA: bu iki degeri `AppStorage`a tasima.
///
/// ⚠️ `shared_preferences` ZATEN kurulu (^2.5.5) — yeni bagimlilik YOK.
class Tercihler {
  Tercihler(this._p);

  /// ⚠️ NULL OLABILIR: `SharedPreferences` acilamazsa uygulama YINE DE ACILIR
  ///    ve varsayilanlarla calisir. `late` bir alan birakilsaydi ilk erisimde
  ///    `LateInitializationError` ile ACILISTA COKERDI — tema tercihi ugruna
  ///    uygulamayi kaybetmek kabul edilemez.
  final SharedPreferences? _p;

  static const _kTema = 'tema_modu';
  static const _kOnboarding = 'onboarding_goruldu';

  /// 'sistem' | 'acik' | 'koyu'
  ThemeMode get temaModu => switch (_p?.getString(_kTema)) {
    'acik' => ThemeMode.light,
    'koyu' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> temaYaz(ThemeMode m) async {
    await _p?.setString(_kTema, switch (m) {
      ThemeMode.light => 'acik',
      ThemeMode.dark => 'koyu',
      ThemeMode.system => 'sistem',
    });
  }

  /// ⚠️⚠️⚠️ IKI DURUM BIRBIRINDEN AYRILIR — ilk yazimda AYRILMAMISTI ve
  /// ozellik OLU DOGACAKTI:
  ///
  ///	`_p?.getBool(k) ?? true` ifadesi
  ///	  · "depo ACILAMADI"        (_p == null)      -> null
  ///	  · "anahtar HENUZ YAZILMADI" (temiz kurulum) -> null
  ///	durumlarinin IKISINI DE `true`ya cevirir. Ikincisi TAM OLARAK
  ///	onboarding'in GOSTERILMESI gereken durumdur — yani **temiz kurulumda
  ///	onboarding HIC ACILMAZDI** ve dort ekran yazilmis olmasina ragmen
  ///	kullanici onlari GORMEZDI ("olu ozellik" sinifinin bir ornegi daha).
  ///
  /// ⚠️ Depo YOKSA `true` doner (gosterme): bayrak YAZILAMAYACAGI icin
  ///    her acilista tekrar gosterilir ve kullanici uygulamaya HIC giremezdi.
  /// ⚠️ Depo VARSA ve anahtar yoksa `false` doner: onboarding GOSTERILIR.
  bool get onboardingGoruldu {
    final p = _p;
    if (p == null) return true;
    return p.getBool(_kOnboarding) ?? false;
  }

  Future<void> onboardingGorulduYaz() async {
    await _p?.setBool(_kOnboarding, true);
  }
}

/// ⚠️ Acilista BIR KEZ kurulur ve `main()` icinde `await` edilir.
///
/// ⚠️⚠️ NEDEN `FutureProvider` DEGIL: tema ve onboarding kararinin
///    `MaterialApp` kurulurken HAZIR olmasi gerekir. `FutureProvider`
///    kullanilsaydi ilk kare varsayilan (koyu) temayla cizilir, sonra
///    tercih gelince ekran ANIDEN degisirdi ("tema atlamasi").
Tercihler tercihler = Tercihler(null);

/// ⚠️ ISTISNA FIRLATMAZ — cagirani `try` ile sarmalamak GEREKMEZ.
Future<void> tercihleriYukle() async {
  try {
    tercihler = Tercihler(await SharedPreferences.getInstance());
  } catch (_) {
    tercihler = Tercihler(null);
  }
}

/// Secili tema modu. Ayarlar ekrani bunu degistirir, `main.dart` dinler.
///
/// ⚠️ Baslangic degeri DISKTEN gelir (yukarida `late` alan `main()`de dolduruldu),
///    yani ilk kare DOGRU temayla cizilir.
class TemaNotifier extends StateNotifier<ThemeMode> {
  TemaNotifier() : super(tercihler.temaModu);

  Future<void> ayarla(ThemeMode m) async {
    state = m;
    await tercihler.temaYaz(m);
  }
}

final temaProvider = StateNotifierProvider<TemaNotifier, ThemeMode>(
  (ref) => TemaNotifier(),
);

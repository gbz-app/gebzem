import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/push.dart';
import 'core/tercihler.dart';
import 'core/ws.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/forgot_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/kayit_akisi.dart';
import 'features/auth/onboarding_ekrani.dart';
import 'features/auth/otp_screen.dart';
// ⚠️ `register_screen.dart` ARTIK IMPORT EDILMIYOR: `/register` turu 84'te
//    `KayitAkisi`ya baglandi. DOSYA SILINMEDI (sifre sifirlama akisi onun
//    yardimcilarini paylasiyor); yalniz bu rotadan cozuldu.
import 'features/chats/chat_screen.dart';
import 'features/chats/user_search_screen.dart';
import 'features/home/home_screen.dart';

/// Gelen arama ekrani Navigator'in DISINDA (MaterialApp.builder) yasar; oradan
/// sayfa acabilmek icin kok Navigator'a bu anahtarla ulasiyoruz.
final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// ⚠️⚠️⚠️ TURU 85b — OTURUM DEGISIMINDE **ROUTER YENIDEN KURULMAZ**.
///
///	Onceden `routerProvider` govdesinde `ref.watch(authProvider)` vardi.
///	Riverpod'da `watch` = **saglayiciyi YENIDEN CALISTIR**, yani her oturum
///	degisiminde YEPYENI bir `GoRouter` uretiliyordu. `MaterialApp.router` yeni
///	`routerConfig`i alinca gezinme yiginini ATAR ve `initialLocation: '/'`
///	ile SIFIRDAN tohumlar.
///
///	SONUC (SEVK ENGELI): turu 84'un adimli kayit akisinda 3. adim hesabi
///	olusturup oturumu aciyor -> `authProvider` degisiyor -> router BASTAN
///	kuruluyor ve kullanici ANINDA `/`ye dusuyor. Asagidaki `redirect`e
///	yazdigim `/register` ISTISNASI **HIC CALISMIYORDU**, cunku onu tasiyan
///	router nesnesi coptu. Yani **4. ADIM (IZINLER) HICBIR ZAMAN GORUNMEZDI**
///	— tam da o istisnanin engellemeye calistigi hata, BASKA bir katmandan.
///
///	FIX: router BIR KEZ kurulur; oturum degisimi `refreshListenable` ile
///	yalnizca `redirect`i YENIDEN KOSTURUR (yigin korunur).
///
/// ⚠️ Yan etkiler (WS baglantisi + push kaydi) da buraya tasindi; eskiden
///    saglayici govdesindeydiler ve govde artik tekrar kosmuyor.
/// ⚠️ `fireImmediately` YOK: `authProvider` `null` (kontrol ediliyor) ile
///    baslar, gercek deger `_init()` sonrasi GELIR ve dinleyici onu yakalar.
/// ⚠️ YAPMA: `routerProvider` govdesine tekrar `ref.watch(authProvider)` koyma.
class _OturumDinleyicisi extends ChangeNotifier {
  _OturumDinleyicisi(this._ref) {
    _kapat = _ref.listen<String?>(authProvider, (_, yeni) {
      if (yeni != null && yeni.isNotEmpty) {
        _ref.read(wsProvider).connect();
        _ref.read(pushProvider).register();
      }
      notifyListeners();
    }, fireImmediately: true).close;
  }

  final Ref _ref;
  late final void Function() _kapat;

  @override
  void dispose() {
    _kapat();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final oturum = _OturumDinleyicisi(ref);
  ref.onDispose(oturum.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: oturum,
    redirect: (context, state) {
      // ⚠️ `watch` DEGIL `read` — bkz. `_OturumDinleyicisi` serhi. Tazeleme
      //    isini `refreshListenable` yapiyor; burada watch etmek routeri
      //    yeniden kurar ve kayit akisini bozardi.
      final auth = ref.read(authProvider);
      // ⚠️⚠️⚠️ TURU 81 — ONBOARDING **EN USTTE** (kullanici emri: "uygulama
      //    ilk acilisinda 4 tane onboarding olsun").
      //
      // ⚠️ Oturum kontrolunden ONCE gelir: onboarding hesaptan BAGIMSIZDIR ve
      //    henuz oturum YOKKEN gosterilmelidir. Asagiya konsaydi kullanici
      //    once LOGIN ekranini gorur, onboarding ancak ondan sonra cikardi.
      // ⚠️ Bayrak CIHAZ YEREL (`shared_preferences`, `main()`de yuklendi) —
      //    senkron okunur, yani redirect'i BEKLETMEZ.
      if (!tercihler.onboardingGoruldu) {
        return state.matchedLocation == '/onboarding' ? null : '/onboarding';
      }
      // ⚠️ Onboarding bittiyse o rotada KALINMAZ (geri tusuyla donulemesin).
      if (state.matchedLocation == '/onboarding') return '/';

      if (auth == null) return null; // oturum kontrol ediliyor (splash aninda)
      final loggedIn = auth.isNotEmpty;
      final onAuthPage = [
        '/login',
        '/register',
        '/otp',
        '/forgot',
      ].contains(state.matchedLocation);
      if (!loggedIn && !onAuthPage) return '/login';
      // ⚠️⚠️⚠️ TURU 84 — `/register` **ISTISNA**: adimli kayit akisi hesabi
      //    3. adimda olusturur (yani OTURUM ACILIR) ve ardindan 4. adimda
      //    IZINLERI ister.
      //
      //    Bu istisna OLMASAYDI: `kayitTamamla` oturumu acar acmaz
      //    `loggedIn && onAuthPage` kosulu dogru olur ve router kullaniciyi
      //    ANINDA `/`ye atardi -> **IZIN ADIMI HIC GORUNMEZDI** ve
      //    `PermissionsScreen`in yillardir olu kalmasina yol acan hatanin
      //    aynisi bu kez YENI akista tekrarlanirdi.
      //
      // ⚠️ Akis kendi bitisini `context.go('/')` ile YAPAR (izin ver ya da
      //    "Şimdilik geç"). Yani kullanici burada MAHSUR KALMAZ.
      // ⚠️ YAPMA: bu istisnayi kaldirma; kaldirilirsa izin adimi sessizce olur.
      if (loggedIn && onAuthPage && state.matchedLocation != '/register') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/onboarding',
        // ⚠️ Yonlendirmeyi EKRAN YAPMAZ: bayragi yazip `go('/')` diyor ve
        //    yukaridaki redirect dogru hedefe (login ya da ana ekran) tasiyor.
        //    Ekranin kendisi "login mi ana ekran mi" karari VERMEMELI.
        builder: (ctx, _) => OnboardingEkrani(onBitti: () => ctx.go('/')),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      // TURU 84 - ADIMLI KAYIT (telefon -> OTP -> bilgiler -> izinler).
      // Kullanici emri. Eski tek-sayfalik RegisterScreen ve /otp rotasi
      // SILINMEDI: sifre sifirlama akisi /otp mantigini paylasiyor ve
      // yayindaki eski surumler o yollari kullaniyor.
      // YAPMA: /register i tekrar RegisterScreen e baglama.
      GoRoute(
        path: '/register',
        builder: (_, state) {
          // ⚠️ Giris ekrani numarayi ve kodu `extra` ile tasir (bkz.
          //    `KayitAkisi` serhi). Dogrudan gelinirse ikisi de null.
          final extra = (state.extra as Map?) ?? {};
          return KayitAkisi(
            telefon: extra['telefon'] as String?,
            devOtp: extra['otp'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? {};
          return OtpScreen(
            phone: extra['phone'] as String? ?? '',
            devOtp: extra['dev_otp'] as String?,
          );
        },
      ),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotScreen()),
      GoRoute(path: '/search', builder: (_, _) => const UserSearchScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? {};
          return ChatScreen(
            chatId: state.pathParameters['id']!,
            title: extra['title'] as String? ?? 'Sohbet',
            peerId: extra['peer_id'] as String?,
            avatarMediaId: extra['avatar_media_id'] as String?,
            isGroup: extra['is_group'] == true,
          );
        },
      ),
    ],
  );
});

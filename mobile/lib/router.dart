import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/push.dart';
import 'core/tercihler.dart';
import 'core/ws.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/forgot_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_ekrani.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/chats/chat_screen.dart';
import 'features/chats/user_search_screen.dart';
import 'features/home/home_screen.dart';

/// Gelen arama ekrani Navigator'in DISINDA (MaterialApp.builder) yasar; oradan
/// sayfa acabilmek icin kok Navigator'a bu anahtarla ulasiyoruz.
final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  // girisliyken WebSocket'i ac + push kaydini yap
  if (auth != null && auth.isNotEmpty) {
    ref.read(wsProvider).connect();
    ref.read(pushProvider).register();
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
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
      final onAuthPage = ['/login', '/register', '/otp', '/forgot']
          .contains(state.matchedLocation);
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/';
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
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/push.dart';
import 'core/ws.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/forgot_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/chats/chat_screen.dart';
import 'features/chats/user_search_screen.dart';
import 'features/home/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  // girisliyken WebSocket'i ac + push kaydini yap
  if (auth != null && auth.isNotEmpty) {
    ref.read(wsProvider).connect();
    ref.read(pushProvider).register();
  }

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
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
          );
        },
      ),
    ],
  );
});

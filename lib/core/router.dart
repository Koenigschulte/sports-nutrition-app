import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/storage/secure_storage.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/plan/week_plan_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/shopping/shopping_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/plan',
    redirect: (context, state) async {
      final token = await getToken();
      final isAuth = token != null;
      final isOnAuthPage =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuth && !isOnAuthPage) return '/login';
      if (isAuth && isOnAuthPage) return '/plan';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/plan', builder: (_, __) => const WeekPlanScreen()),
      GoRoute(path: '/shopping', builder: (_, __) => const ShoppingScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Seite nicht gefunden: ${state.error}')),
    ),
  );
});

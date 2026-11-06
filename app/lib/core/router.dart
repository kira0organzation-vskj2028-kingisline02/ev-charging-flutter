import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'secure_store.dart';
import '../data/models/user_model.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/verify_otp_screen.dart';
import '../features/map/map_screen.dart';
import '../features/charger_detail/charger_detail_screen.dart';
import '../features/booking/booking_screen.dart';
import '../features/booking/payment_screen.dart';
import '../features/booking/live_session_screen.dart';
import '../features/my_bookings/my_bookings_screen.dart';
import '../features/host/host_dashboard_screen.dart';
import '../features/host/add_charger_screen.dart';
import '../features/profile/profile_screen.dart';

final authStateProvider = StateProvider<UserModel?>((ref) => null);

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/map',
    redirect: (context, state) {
      final isAuthRoute = state.uri.path.startsWith('/auth');
      final isLoggedIn = user != null;

      // Unauthenticated users can view map, but need login for booking, host, my-bookings
      if (!isLoggedIn &&
          (state.uri.path.startsWith('/bookings') ||
              state.uri.path.startsWith('/host') ||
              state.uri.path.startsWith('/profile'))) {
        return '/auth/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/map';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/charger/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ChargerDetailScreen(chargerId: id);
        },
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return BookingScreen(chargerId: id);
        },
      ),
      GoRoute(
        path: '/payment/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PaymentScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return LiveSessionScreen(bookingId: id);
        },
      ),
      GoRoute(
        path: '/my-bookings',
        builder: (context, state) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: '/host',
        builder: (context, state) => const HostDashboardScreen(),
      ),
      GoRoute(
        path: '/host/add-charger',
        builder: (context, state) => const AddChargerScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/verify-otp',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return VerifyOtpScreen(email: email);
        },
      ),
    ],
  );
});


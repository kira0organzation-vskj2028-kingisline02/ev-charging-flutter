import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/secure_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = SecureStore();
  final user = await store.getUser();

  runApp(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => user),
      ],
      child: const ChargeBridgeApp(),
    ),
  );
}

class ChargeBridgeApp extends ConsumerWidget {
  const ChargeBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ChargeBridge EV Sharing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}

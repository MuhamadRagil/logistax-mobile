import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

// Catatan: Firebase/FCM sengaja belum diaktifkan (belum ada google-services.json).
// Notifikasi in-app via GET /notifications tetap berfungsi.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LogistaxApp()));
}

class LogistaxApp extends ConsumerWidget {
  const LogistaxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Logistax',
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

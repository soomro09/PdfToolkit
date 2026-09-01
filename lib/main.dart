import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'feature/splash/views/splash_view.dart';
import 'services/local_storage_service.dart';
import 'viewmodels/recent_files_viewmodel.dart';
import '../../../core/constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final localStorageService = LocalStorageService();
  await localStorageService.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorageService),
      ],
      child: const PdfToolkitApp(),
    ),
  );
}

class PdfToolkitApp extends ConsumerWidget {
  const PdfToolkitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = ref.watch(accentColorProvider);

    AppColors.primaryRed = accentColor;
    AppColors.primaryRedDark = HSLColor.fromColor(accentColor)
        .withLightness(
          (HSLColor.fromColor(accentColor).lightness - 0.15).clamp(0.0, 1.0),
        )
        .toColor();
    AppColors.accentRedLight = accentColor.withOpacity(0.12);

    return MaterialApp(
      title: 'PDF Toolkit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        primaryColor: accentColor,
        colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
          primary: accentColor,
        ),
      ),
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(), // 🚀 Replaced HomeScreen with SplashScreen
    );
  }
}

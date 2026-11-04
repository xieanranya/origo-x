import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'core/reader/reader_design_migration.dart';
import 'pages/shell/app_palette.dart';
import 'pages/shell/home_shell.dart';
import 'services/core/app_settings_service.dart';
import 'services/core/theme_notifier.dart';
import 'services/reader_aloud_service.dart';
import 'services/reader_aloud_session.dart';
import 'services/tts_service.dart';
import 'utils/reader_themes.dart';

// 2.8.0：外壳按开源阅读重构后重新触发双端构建。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 必须在读取主题配色 / AppSettingsNotifier 之前完成：覆盖安装时把旧的
  // 字号、字重、主题、行高一次性迁移到精校基线。
  await ReaderDesignMigration.ensureApplied();
  await ReaderThemes.loadSavedPalette();
  runApp(const LocalReaderApp());
}

class LocalReaderApp extends StatelessWidget {
  const LocalReaderApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeNotifier()),
      ChangeNotifierProvider(create: (_) => AppSettingsNotifier()),
      ChangeNotifierProvider(create: (_) => TtsService()),
      ChangeNotifierProxyProvider<TtsService, ReaderAloudService>(
        create: (context) =>
            ReaderAloudService(systemEngine: context.read<TtsService>()),
        update: (_, engine, service) =>
            service ?? ReaderAloudService(systemEngine: engine),
      ),
      ChangeNotifierProvider(create: (_) => ReaderAloudSession()),
    ],
    child: Consumer2<ThemeNotifier, AppSettingsNotifier>(
      builder: (_, theme, settings, _) => MaterialApp(
        title: '易读',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(theme.accentColor, Brightness.light),
        darkTheme: _buildTheme(theme.accentColor, Brightness.dark),
        themeMode: theme.themeMode,
        locale: settings.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeShell(),
      ),
    ),
  );
}

/// 墨韵国风基础主题：全局宋体 + 宣纸底 + 去 M3 默认紫。
ThemeData _buildTheme(Color seed, Brightness brightness) {
  final base = ThemeData(
    colorSchemeSeed: seed,
    useMaterial3: true,
    brightness: brightness,
    fontFamily: AppFont.serif,
  );
  final paper = brightness == Brightness.light
      ? const Color(0xFFF1ECE0)
      : const Color(0xFF151815);
  final surface = brightness == Brightness.light
      ? const Color(0xFFFFFDF8)
      : const Color(0xFF262B26);
  return base.copyWith(
    scaffoldBackgroundColor: paper,
    canvasColor: paper,
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.light
          ? const Color(0xFF26261F)
          : const Color(0xFFE6E2D4),
      contentTextStyle: TextStyle(
        fontFamily: AppFont.serif,
        fontFamilyFallback: AppFont.fallback,
        fontSize: 13,
        letterSpacing: 0.6,
        color: brightness == Brightness.light
            ? const Color(0xFFF7F4EC)
            : const Color(0xFF20241F),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: brightness == Brightness.light
          ? const Color(0x1426261F)
          : const Color(0x1FE6E2D4),
      thickness: 1,
      space: 1,
    ),
  );
}

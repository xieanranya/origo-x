import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'core/reader/reader_design_migration.dart';
import 'pages/shell/home_shell.dart';
import 'services/core/app_settings_service.dart';
import 'services/core/theme_notifier.dart';
import 'services/reader_aloud_service.dart';
import 'services/reader_aloud_session.dart';
import 'services/tts_service.dart';
import 'utils/reader_themes.dart';

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
        theme: ThemeData(
          colorSchemeSeed: theme.accentColor,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: theme.accentColor,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: theme.themeMode,
        locale: settings.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeShell(),
      ),
    ),
  );
}

import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/product_notifier_service.dart';
import 'screens/mode_selection_screen.dart';

class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for non-web platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI
    ffi.sqfliteFfiInit();
    // Change the default factory
    ffi.databaseFactory = ffi.databaseFactoryFfi;
  }

  await SettingsService.init(); // Asegura que _prefs se inicialice

  final settings = SettingsService(); // Obtiene la instancia del singleton
  
  // El tema se inicializará directamente en el ChangeNotifierProvider

  // Configura el idioma por defecto
  final String defaultLocale = Platform.localeName.split('_')[0];
  final String appLanguage = settings.language.isNotEmpty 
      ? settings.language 
      : (['es', 'en', 'pt'].contains(defaultLocale) ? defaultLocale : 'es');
  
  // Establece el idioma en las preferencias si no está establecido
  if (settings.language.isEmpty) {
    await settings.setLanguage(appLanguage);
  }
  
  // Configura EasyLocalization
  await EasyLocalization.ensureInitialized();
  
  // Lee el valor después de que init() se haya completado.
  final bool initialIsDarkMode = settings.isDarkMode;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider(
          create: (context) => ThemeNotifier(
            isDarkMode: initialIsDarkMode,
            settingsService: settings,
          ),
        ),
        Provider(create: (_) => ProductNotifierService()),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('es'),
          Locale('en'),
          Locale('pt'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        startLocale: Locale(appLanguage),
        child: const MyApp(),
      ),
    ),
  );
}

class ThemeNotifier with ChangeNotifier {
  bool _isDarkMode;
  final SettingsService _settingsService;

  ThemeNotifier({
    required bool isDarkMode,
    required SettingsService settingsService,
  }) : _isDarkMode = isDarkMode,
       _settingsService = settingsService;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    // Llama al método setDarkMode existente en tu SettingsService
    await _settingsService.setDarkMode(_isDarkMode);
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    
    return MaterialApp(
      title: 'Gestor de Ventas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      initialRoute: '/',
      routes: {
        '/': (context) => const ModeSelectionScreen(),
        '/mode_selection': (context) => const ModeSelectionScreen(),
        // Agrega aquí otras rutas según sea necesario
      },
      onGenerateRoute: (settings) {
        // Maneja rutas no definidas
        return MaterialPageRoute(
          builder: (context) => const ModeSelectionScreen(),
        );
      },
    );
  }
}

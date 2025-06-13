import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/product_notifier_service.dart';
import 'utils/currency_formatter.dart';

void main() async {
  // No es necesaria ninguna configuración especial para SQLite
  // sqflite usará automáticamente la implementación correcta según la plataforma
  
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicios
  await SettingsService.init();
  
  // Inicializar el formateador de moneda
  final settings = SettingsService();
  CurrencyFormatter.init(settings);
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class ThemeNotifier with ChangeNotifier {
  bool _isDarkMode;
  final SettingsService _settings = SettingsService();

  ThemeNotifier({bool? isDarkMode}) : _isDarkMode = isDarkMode ?? false;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _settings.setDarkMode(_isDarkMode);
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final platformDispatcher = WidgetsBinding.instance.platformDispatcher;
    final isDark = platformDispatcher.platformBrightness == Brightness.dark;
    
    return MultiProvider(
      providers: [
        Provider(create: (_) => ProductNotifierService()),
        ChangeNotifierProvider(
          create: (_) => ThemeNotifier(
            isDarkMode: isDark,
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          return Consumer<ThemeNotifier>(
            builder: (context, themeNotifier, child) {
              return MaterialApp(
                title: 'Gestor de Ventas',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeNotifier.themeMode,
                navigatorKey: GlobalKey<NavigatorState>(),
                builder: (context, child) {
                  return Navigator(
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      builder: (context) => child!,
                    ),
                  );
                },
                home: const HomeScreen(),
              );
            },
          );
        },
      ),
    );
  }
}

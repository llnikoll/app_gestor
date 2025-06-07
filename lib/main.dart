import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'utils/currency_formatter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await SettingsService.init();
  
  // Initialize currency formatter
  final settings = SettingsService();
  CurrencyFormatter.init(settings);
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class ThemeNotifier extends ChangeNotifier {
  final SettingsService _settings = SettingsService();
  
  bool get isDarkMode => _settings.isDarkMode;
  
  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;
  
  void toggleTheme() {
    _settings.setDarkMode(!isDarkMode);
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
  }
}

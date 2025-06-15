import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/auth_service.dart';
import 'services/product_notifier_service.dart';
import 'utils/currency_formatter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp();

  // Initialize FFI for non-web platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI
    ffi.sqfliteFfiInit();
    // Change the default factory
    ffi.databaseFactory = ffi.databaseFactoryFfi;
  }

  await SettingsService.init(); // Asegura que _prefs se inicialice

  final settings = SettingsService(); // Obtiene la instancia del singleton
  CurrencyFormatter.init(
    settings,
  );

  // Lee el valor después de que init() se haya completado.
  final bool initialIsDarkMode = settings.isDarkMode;

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider(
          create: (context) => ThemeNotifier(
            isDarkMode: initialIsDarkMode,
            settingsService: settings,
          ),
        ),
        Provider(create: (_) => ProductNotifierService()),
      ],
      child: const MyApp(),
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
    final authService = Provider.of<AuthService>(context);

    return MaterialApp(
      title: 'Gestor de Ventas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      home: StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // Si el usuario está autenticado, mostrar el HomeScreen
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          
          // Si no está autenticado, mostrar la pantalla de inicio de sesión
          return const LoginScreen();
        },
      ),
    );
  }
}

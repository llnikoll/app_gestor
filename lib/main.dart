import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de Ventas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      // Asegurarse de que el Navigator esté disponible
      navigatorKey: GlobalKey<NavigatorState>(),
      // Usar un builder para asegurar que el contexto tenga acceso al Navigator
      builder: (context, child) {
        return Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (context) => child!,
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}

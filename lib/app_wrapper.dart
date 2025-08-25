import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/purchase_service.dart';
import 'screens/subscription_screen.dart';
import 'screens/mode_selection_screen.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  AppWrapperState createState() => AppWrapperState();
}

class AppWrapperState extends State<AppWrapper> {
  bool _isLoading = true;
  bool _hasPremiumAccess = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    // Inicializar el servicio de compras
    final purchaseService = Provider.of<PurchaseService>(context, listen: false);
    await purchaseService.init();
    
    // Verificar si el usuario tiene acceso premium
    final hasAccess = await purchaseService.hasPremiumAccess();
    
    if (mounted) {
      setState(() {
        _hasPremiumAccess = hasAccess;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Si el usuario no tiene acceso premium, mostrar la pantalla de suscripción
    if (!_hasPremiumAccess) {
      return const SubscriptionScreen();
    }

    // Si el usuario tiene acceso premium, mostrar la aplicación principal
    return const ModeSelectionScreen();
  }
}

import 'package:flutter/material.dart';
import 'package:gestor_pocket/services/purchase_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  SubscriptionScreenState createState() => SubscriptionScreenState();
}

class SubscriptionScreenState extends State<SubscriptionScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  bool _isLoading = true;
  bool _isPurchasing = false;
  int _trialDaysLeft = 0;
  bool _hasPremium = false;

  @override
  void initState() {
    super.initState();
    _initPurchaseService();
  }

  Future<void> _initPurchaseService() async {
    await _purchaseService.init();
    final hasPremium = await _purchaseService.hasPremiumAccess();
    final trialDaysLeft = await _purchaseService.getTrialDaysLeft();
    
    if (mounted) {
      setState(() {
        _hasPremium = hasPremium;
        _trialDaysLeft = trialDaysLeft;
        _isLoading = false;
      });
    }
  }

  Future<void> _purchaseFullVersion() async {
    setState(() => _isPurchasing = true);
    
    try {
      await _purchaseService.purchaseFullVersion();
      // La validación de la compra se manejará en el listener
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar la compra')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    await _purchaseService.restorePurchases();
    // Esperar un momento para que se procese la restauración
    await Future.delayed(const Duration(seconds: 2));
    await _initPurchaseService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Versión Premium'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasPremium
              ? _buildPremiumActive()
              : _buildSubscriptionOptions(),
    );
  }

  Widget _buildPremiumActive() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            '¡Versión Premium Activada!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            'Disfruta de todas las funciones sin restricciones.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.rocket_launch, size: 80, color: Colors.blue),
          const SizedBox(height: 20),
          const Text(
            'Desbloquea todas las funciones',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            _trialDaysLeft > 0
                ? 'Tu prueba gratuita termina en $_trialDaysLeft días'
                : 'Tu prueba gratuita ha expirado',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildPricingCard(),
          const SizedBox(height: 20),
          const Text(
            '¿Qué incluye?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildFeature('Acceso ilimitado a todas las funciones'),
          _buildFeature('Sin publicidad'),
          _buildFeature('Soporte prioritario'),
          _buildFeature('Actualizaciones gratuitas'),
          const SizedBox(height: 40),
          _buildPurchaseButton(),
          const SizedBox(height: 15),
          TextButton(
            onPressed: _restorePurchases,
            child: const Text('¿Ya has comprado? Restaurar compra'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pago único. Sin renovaciones automáticas.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.blue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Versión Completa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              '\$5.00',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Pago único',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return ElevatedButton(
      onPressed: _isPurchasing ? null : _purchaseFullVersion,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: _isPurchasing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'COMPRAR AHORA',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_id_service.dart';

/// Singleton service to handle in-app purchases and trial period
class PurchaseService extends ChangeNotifier {
  // Singleton instance
  static final PurchaseService _instance = PurchaseService._internal();
  
  // Factory constructor to return the same instance
  factory PurchaseService() => _instance;
  
  // Private constructor
  PurchaseService._internal() {
    // No inicializar aquí, esperar a que se llame a init()
  }
  
  // Product IDs
  static const String _fullVersionId = 'version_completa';
  static const String _trialKey = 'trial_start_date';
  static const String _purchaseKey = 'is_premium';
  
  // State
  bool? _hasPremiumAccess;
  InAppPurchase? _inAppPurchase;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  

  
  // Getters
  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  
  // Inicializar el servicio
  Future<void> init() async {
    try {
      // Inicializar la instancia de InAppPurchase
      _inAppPurchase = InAppPurchase.instance;
      
      // Verificar disponibilidad
      try {
        _isAvailable = await _inAppPurchase?.isAvailable() ?? false;
        
        if (!_isAvailable) {
          if (kDebugMode) {
            print('In-App Purchases no está disponible en esta plataforma');
          }
          return;
        }
        
        // Configurar listeners solo si está disponible
        _inAppPurchase?.purchaseStream.listen(_handlePurchaseUpdate);
        
        // Cargar productos
        await _loadProducts();
        
        // Verificar compras existentes
        await _checkExistingPurchases();
      } catch (e) {
        if (kDebugMode) {
          print('Error al inicializar compras: $e');
        }
        _isAvailable = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar el servicio de compras: $e');
      }
    }
  }
  
  // Cargar productos disponibles
  Future<void> _loadProducts() async {
    if (_inAppPurchase == null) return;
    
    final Set<String> kIds = {_fullVersionId};
    final ProductDetailsResponse response = 
        await _inAppPurchase!.queryProductDetails(kIds);
        
    if (response.notFoundIDs.isNotEmpty) {
      if (kDebugMode) {
        print('Productos no encontrados: ${response.notFoundIDs}');
      }
    }
    
    _products = response.productDetails;
  }
  
  // Check if user has premium access (from purchase or trial)
  Future<bool> hasPremiumAccess() async {
    if (_hasPremiumAccess != null) return _hasPremiumAccess!;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Check if user has purchased
    final bool? hasPurchased = prefs.getBool(_purchaseKey);
    if (hasPurchased == true) {
      _hasPremiumAccess = true;
      return true;
    }
    
    // Check trial period first
    final String? trialStartDateStr = prefs.getString(_trialKey);
    if (trialStartDateStr != null) {
      final DateTime trialStartDate = DateTime.parse(trialStartDateStr);
      final DateTime trialEndDate = trialStartDate.add(const Duration(days: 7));
      final bool isTrialActive = DateTime.now().isBefore(trialEndDate);
      
      if (isTrialActive) {
        _hasPremiumAccess = true;
        return true;
      } else {
        // Solo marcar como que usó la prueba cuando realmente se agota
        await DeviceIdService.markTrialUsed();
        _hasPremiumAccess = false;
        return false;
      }
    }
    
    // Verificar si este dispositivo ya usó la prueba (solo si no hay fecha de inicio)
    final bool hasUsedTrial = await DeviceIdService.hasUsedTrial();
    if (hasUsedTrial) {
      _hasPremiumAccess = false;
      return false;
    }
    
    // If no purchase and no trial, start trial
    await prefs.setString(_trialKey, DateTime.now().toIso8601String());
    _hasPremiumAccess = true;
    return true;
  }

  // Check existing purchases
  Future<void> _checkExistingPurchases() async {
    try {
      final currentInAppPurchase = _inAppPurchase;
      if (currentInAppPurchase == null) return;
      
      final bool available = await currentInAppPurchase.isAvailable();
      if (!available) return;
      
      // Get available products
      // Listen to purchase updates
      final Stream<List<PurchaseDetails>> purchaseUpdated = 
          currentInAppPurchase.purchaseStream;
      
      // Usar un completer para manejar la finalización de la verificación
      final completer = Completer<void>();
      
      // Configurar el listener de actualizaciones de compras
      final StreamSubscription<List<PurchaseDetails>> subscription = 
          purchaseUpdated.listen(
        (List<PurchaseDetails> purchaseDetailsList) async {
          // Procesar cada compra
          for (final purchase in purchaseDetailsList) {
            if (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored) {
              await _validatePurchase(purchase);
            }
          }
          
          // Completar después de procesar las compras
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('Error en el stream de compras: $error');
          }
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        cancelOnError: true,
      );
      
      // Verificar si el servicio está disponible
      final purchase = _inAppPurchase;
      if (purchase == null) return;
      
      final bool isAvailable = await purchase.isAvailable();
      if (isAvailable) {
        try {
          // Obtener las compras existentes a través del stream
          await purchase.restorePurchases();
          
          // Esperar un tiempo razonable para que lleguen las actualizaciones
          await Future.any([
            completer.future,
            Future.delayed(const Duration(seconds: 5)),
          ]);
        } catch (e) {
          if (kDebugMode) {
            print('Error al restaurar compras: $e');
          }
        }
      }
      
      // Cancelar la suscripción
      await subscription.cancel();
      
      // Notificar a los listeners
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar compras existentes: $e');
      }
    }
  }
  
  // Manejar actualizaciones de compras
  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      try {
        if (purchaseDetails.status == PurchaseStatus.pending) {
          // Mostrar UI de compra pendiente si es necesario
          if (kDebugMode) {
            print('Compra pendiente: ${purchaseDetails.productID}');
          }
        } else if (purchaseDetails.status == PurchaseStatus.error) {
          // Manejar error
          if (kDebugMode) {
            print('Error en la compra: ${purchaseDetails.error}');
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                  purchaseDetails.status == PurchaseStatus.restored) {
          // Validar la compra
          await _validatePurchase(purchaseDetails);
          // Notificar a los listeners después de validar la compra
          notifyListeners();
        }
        
        // Completar la compra si es necesario
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase!.completePurchase(purchaseDetails);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error al procesar la compra: $e');
        }
      }
    }
  }
  
  // Validar una compra
  Future<void> _validatePurchase(PurchaseDetails purchaseDetails) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
    
    // Si es una restauración, también actualizamos el estado
    if (purchaseDetails.status == PurchaseStatus.restored) {
      await prefs.setBool('is_premium', true);
    }
  }
  
  // Comprar la versión completa
  Future<void> purchaseFullVersion() async {
    if (_products.isEmpty) {
      await _loadProducts();
    }
    
    if (_products.isNotEmpty) {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: _products.first,
      );
      
      if (_inAppPurchase != null) {
        await _inAppPurchase!.buyNonConsumable(
          purchaseParam: purchaseParam,
        );
      }
    }
  }
  
  // Restaurar compras
  Future<void> restorePurchases() async {
    try {
      if (_inAppPurchase == null) return;
      await _inAppPurchase!.restorePurchases();
    } catch (e) {
      if (kDebugMode) {
        print('Error al restaurar compras: $e');
      }
    }
  }
  
  // Obtener días restantes de prueba
  Future<int> getTrialDaysLeft() async {
    final prefs = await SharedPreferences.getInstance();
    final trialStart = prefs.getString(_trialKey);
    
    if (trialStart == null) return 7; // Si no hay registro de prueba, devolver el máximo
    
    final startDate = DateTime.parse(trialStart);
    final now = DateTime.now();
    final difference = now.difference(startDate).inDays;
    final daysLeft = 7 - difference;
    
    return daysLeft > 0 ? daysLeft : 0;
  }
}

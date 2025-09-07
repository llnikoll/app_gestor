import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'device_id_service.dart';

final _logger = Logger('PurchaseService');

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

  // ID del producto de compra única en Google Play
  static const String _premiumProductId = 'version_premium';
  static const String _trialKey = 'trial_start_date';
  static const String _purchaseKey = 'is_premium';

  // State
  bool? _hasPremiumAccess;
  InAppPurchase? _inAppPurchase;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isLoadingProducts =
      false; // Nueva variable para controlar carga en progreso

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
    if (_inAppPurchase == null || _isLoadingProducts) return;

    _isLoadingProducts = true;
    final Set<String> kIds = {_premiumProductId}; // Usar el ID de compra única
    try {
      final ProductDetailsResponse response =
          await _inAppPurchase!.queryProductDetails(kIds);

      if (response.notFoundIDs.isNotEmpty) {
        _logger.warning('Producto no encontrado: ${response.notFoundIDs}');
        _logger.info(
            'Asegúrate de que el producto $_premiumProductId esté configurado en Google Play Console como un producto de compra única (no suscripción)');
      }

      _products = response.productDetails;

      if (_products.isNotEmpty) {
        _logger.fine(
            'Producto cargado: ${_products.map((p) => '${p.id} (${p.title})').toList()}');
      }
    } catch (e) {
      _logger.severe('Error al cargar productos', e);
      rethrow;
    } finally {
      _isLoadingProducts = false;
    }
  }

  // Verificar si el usuario tiene acceso premium (por compra o prueba)
  Future<bool> hasPremiumAccess() async {
    if (_hasPremiumAccess != null) return _hasPremiumAccess!;

    final prefs = await SharedPreferences.getInstance();

    // 1. Verificar si ya compró la versión premium
    final bool? hasPurchased = prefs.getBool(_purchaseKey);
    if (hasPurchased == true) {
      _hasPremiumAccess = true;
      return true;
    }

    // 2. Verificar período de prueba
    final String? trialStartDateStr = prefs.getString(_trialKey);
    if (trialStartDateStr != null) {
      final DateTime trialStartDate = DateTime.parse(trialStartDateStr);
      final DateTime trialEndDate =
          trialStartDate.add(const Duration(days: 15));

      if (DateTime.now().isBefore(trialEndDate)) {
        // Período de prueba activo
        _hasPremiumAccess = true;
        return true;
      } else {
        // Período de prueba terminado
        await DeviceIdService.markTrialUsed();
        _hasPremiumAccess = false;
        return false;
      }
    }

    // 3. Verificar si ya usó la prueba en este dispositivo
    final bool hasUsedTrial = await DeviceIdService.hasUsedTrial();
    if (hasUsedTrial) {
      _hasPremiumAccess = false;
      return false;
    }

    // 4. Si es la primera vez, iniciar prueba de 15 días
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
  Future<void> _handlePurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
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
          try {
            // Primero validar la compra
            await _validatePurchase(purchaseDetails);

            // Luego completar la compra si se validó correctamente
            if (purchaseDetails.pendingCompletePurchase) {
              await _inAppPurchase?.completePurchase(purchaseDetails);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error al procesar la compra: $e');
            }
          }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_purchaseKey, true);
      _hasPremiumAccess = true;

      // Si es una restauración, también actualizamos el estado
      if (purchaseDetails.status == PurchaseStatus.restored) {
        await prefs.setBool(_purchaseKey, true);
        _hasPremiumAccess = true;
      }

      // Notificar a los listeners después de actualizar el estado
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error al validar la compra: $e');
      }
    }
  }

  // Comprar la versión premium (compra única)
  Future<bool> purchasePremium() async {
    try {
      if (_products.isEmpty) {
        await _loadProducts();
        // Si ya hay productos cargados, no intentar cargar de nuevo
        if (_products.isEmpty) {
          _logger.severe('No se encontró el producto $_premiumProductId');
          return false;
        }
      }

      final purchase = _inAppPurchase;
      if (purchase == null) {
        _logger.warning('El servicio de compras no está disponible');
        return false;
      }

      final bool available = await purchase.isAvailable();
      if (!available) {
        _logger.warning('El servicio de compras no está disponible');
        return false;
      }

      final product = _products.firstWhere(
        (p) => p.id == _premiumProductId,
        orElse: () {
          _logger.warning('No se encontró el producto $_premiumProductId');
          throw Exception('Producto no disponible');
        },
      );

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      final bool success = await purchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (success) {
        _logger.info('Flujo de compra iniciado correctamente');
      } else {
        _logger.warning('No se pudo iniciar el flujo de compra');
      }

      return success;
    } catch (e) {
      _logger.severe('Error al intentar comprar la versión premium', e);
      return false;
    }
  }

  // Restaurar compras
  Future<bool> restorePurchases() async {
    try {
      final purchase = _inAppPurchase;
      if (purchase == null) {
        _logger.warning('El servicio de compras no está disponible');
        return false;
      }

      final bool available = await purchase.isAvailable();
      if (!available) {
        _logger.warning('El servicio de compras no está disponible');
        return false;
      }

      _logger.info('Iniciando restauración de compras...');
      await purchase.restorePurchases();
      return true;
    } catch (e) {
      _logger.severe('Error al restaurar compras', e);
      return false;
    }
  }

  // Obtener días restantes de prueba
  Future<int> getTrialDaysLeft() async {
    final prefs = await SharedPreferences.getInstance();
    final String? trialStartDateStr = prefs.getString(_trialKey);

    if (trialStartDateStr == null) {
      // Si no hay fecha de inicio, es la primera vez
      return 15;
    }

    final DateTime trialStartDate = DateTime.parse(trialStartDateStr);
    final DateTime trialEndDate = trialStartDate.add(const Duration(days: 15));
    final Duration difference = trialEndDate.difference(DateTime.now());

    final int daysLeft = difference.inDays.clamp(0, 15);
    return daysLeft;
  }
}

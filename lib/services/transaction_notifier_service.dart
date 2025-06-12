import 'package:flutter/foundation.dart';

/// Servicio para notificar cambios en transacciones (ventas y gastos)
class TransactionNotifierService {
  // Singleton pattern
  static final TransactionNotifierService _instance = 
      TransactionNotifierService._internal();
  
  // Notifiers
  final ValueNotifier<int> _salesUpdateNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _expensesUpdateNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _transactionsUpdateNotifier = ValueNotifier<int>(0);

  // Private constructor
  TransactionNotifierService._internal();

  // Factory constructor
  factory TransactionNotifierService() {
    return _instance;
  }

  // Getters para los notifiers
  ValueNotifier<int> get salesNotifier => _salesUpdateNotifier;
  ValueNotifier<int> get expensesNotifier => _expensesUpdateNotifier;
  ValueNotifier<int> get transactionsNotifier => _transactionsUpdateNotifier;

  // Métodos para notificar cambios
  void notifySalesUpdate() {
    debugPrint('Notificando actualización de ventas');
    _salesUpdateNotifier.value++;
    _transactionsUpdateNotifier.value++;
    debugPrint('Valores actuales - Ventas: ${_salesUpdateNotifier.value}, Transacciones: ${_transactionsUpdateNotifier.value}');
  }

  void notifyExpensesUpdate() {
    debugPrint('Notificando actualización de gastos');
    _expensesUpdateNotifier.value++;
    _transactionsUpdateNotifier.value++;
    debugPrint('Valores actuales - Gastos: ${_expensesUpdateNotifier.value}, Transacciones: ${_transactionsUpdateNotifier.value}');
  }

  void notifyTransactionsUpdate() {
    debugPrint('Notificando actualización general de transacciones');
    _transactionsUpdateNotifier.value++;
    debugPrint('Valor actual de transacciones: ${_transactionsUpdateNotifier.value}');
  }
}

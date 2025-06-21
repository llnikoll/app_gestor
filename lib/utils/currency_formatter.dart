import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class CurrencyFormatter {
  // Formatear un número como moneda usando el contexto para acceder al SettingsService
  static String format(BuildContext context, double amount) {
    final settings = Provider.of<SettingsService>(context, listen: true);
    final currency = settings.currentCurrency;
    
    return NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: currency.decimalDigits,
    ).format(amount);
  }
}

// Extensión para facilitar el uso
// Ejemplo: context.formattedCurrency(1000)
extension CurrencyFormatterExtension on BuildContext {
  String formattedCurrency(double amount) {
    return CurrencyFormatter.format(this, amount);
  }
  
  String formattedAmountWithSymbol(double amount, String symbol, {int decimalDigits = 0}) {
    return NumberFormat.currency(
      locale: 'es_PY',
      symbol: symbol,
      decimalDigits: decimalDigits,
    ).format(amount);
  }
}

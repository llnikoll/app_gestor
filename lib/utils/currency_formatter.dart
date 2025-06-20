import 'package:intl/intl.dart';
import '../services/settings_service.dart';

class CurrencyFormatter {
  static final CurrencyFormatter _instance = CurrencyFormatter._internal();
  static late SettingsService _settings;

  factory CurrencyFormatter() => _instance;
  
  // Constructor privado
  CurrencyFormatter._internal();

  // Inicializar con el servicio de configuración
  static void init(SettingsService settings) {
    _settings = settings;
  }

  // Formatear un número como moneda
  static String format(double amount) {
    final currency = _settings.currentCurrency;
    
    return NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: currency.decimalDigits,
    ).format(amount);
  }


}

// Extensión para facilitar el uso
// Ejemplo: 1000.formattedCurrency
// O: 1000.formattedCurrencyWithSymbol('₲')
extension NumCurrencyExtension on num {
  String get formattedCurrency => CurrencyFormatter.format(toDouble());
  
  String formattedCurrencyWithSymbol(String symbol) {
    return NumberFormat.currency(
      locale: 'es_PY',
      symbol: symbol,
      decimalDigits: 0,
    ).format(this);
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_model.dart';

class SettingsService with ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  static late SharedPreferences _prefs;

  static const String _darkModeKey = 'darkMode';
  static const String _notificationsKey = 'notifications';
  static const String _biometricAuthKey = 'biometricAuth';
  static const String _languageKey = 'language';
  static const String _currencyKey = 'currency';
  static const String _printerKey = 'printer';

  static const bool _defaultDarkMode = false;
  static const bool _defaultNotifications = true;
  static const bool _defaultBiometricAuth = false;
  static const String _defaultLanguage = 'es';
  static const String _defaultCurrency = 'PYG';
  static const String _defaultPrinter = 'Predeterminada';

  Currency get currentCurrency => Currency.getByCode(currency);

  bool get isDarkMode => _prefs.getBool(_darkModeKey) ?? _defaultDarkMode;
  bool get notificationsEnabled => _prefs.getBool(_notificationsKey) ?? _defaultNotifications;
  bool get biometricAuthEnabled => _prefs.getBool(_biometricAuthKey) ?? _defaultBiometricAuth;
  String get language => _prefs.getString(_languageKey) ?? _defaultLanguage;
  String get currency => _prefs.getString(_currencyKey) ?? _defaultCurrency;
  String get printer => _prefs.getString(_printerKey) ?? _defaultPrinter;

  SettingsService._internal();

  factory SettingsService() => _instance;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_darkModeKey, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_notificationsKey, value);
  }

  Future<void> setBiometricAuthEnabled(bool value) async {
    await _prefs.setBool(_biometricAuthKey, value);
  }

  Future<void> setLanguage(String languageCode) async {
    await _prefs.setString(_languageKey, languageCode);
  }

  Future<bool> updateCurrency(String newCurrency) async {
    await _prefs.setString(_currencyKey, newCurrency);
    notifyListeners(); // Notificar a los oyentes sobre el cambio
    return true;
  }
  
  // Método alternativo para mantener compatibilidad
  Future<void> setCurrency(String currencyCode) async {
    await updateCurrency(currencyCode);
  }

  List<Currency> get supportedCurrencies => Currency.currencies;

  Future<void> setPrinter(String printerName) async {
    await _prefs.setString(_printerKey, printerName);
  }

  Future<void> resetToDefault() async {
    await _prefs.clear();
  }

  static List<Map<String, dynamic>> get availableLanguages => [
    {'code': 'es', 'name': 'Español'},
    {'code': 'en', 'name': 'English'},
    {'code': 'pt', 'name': 'Português'},
  ];

  static List<Map<String, dynamic>> get availableCurrencies => [
    {'code': 'PYG', 'name': 'Guaraní (₲)', 'symbol': '₲'},
    {'code': 'ARS', 'name': 'Peso Argentino (\$)', 'symbol': '\$'},
    {'code': 'BRL', 'name': 'Real Brasileño (R\$)', 'symbol': 'R\$'},
    {'code': 'MXN', 'name': 'Peso Mexicano (\$)', 'symbol': '\$'},
    {'code': 'USD', 'name': 'Dólar Americano (\$)', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro (€)', 'symbol': '€'},
    {'code': 'GTQ', 'name': 'Quetzal (Q)', 'symbol': 'Q'},
    {'code': 'PEN', 'name': 'Sol (S/.)', 'symbol': 'S/.'},
  ];

  static List<String> get availablePrinters => [
    'Predeterminada',
    'Impresora 1',
    'Impresora 2',
    'Impresora Bluetooth',
  ];

  static String getCurrencySymbol(String currencyCode) {
    final currency = availableCurrencies.firstWhere(
          (curr) => curr['code'] == currencyCode,
      orElse: () => {'symbol': '\$'},
    );
    return currency['symbol'] as String;
  }

  static String formatCurrency(double amount, {String? currencyCode}) {
    final code = currencyCode ?? _instance.currency;
    final symbol = getCurrencySymbol(code);
    return '$symbol${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    )}';
  }
}
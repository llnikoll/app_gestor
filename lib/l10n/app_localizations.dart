import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;
  final Map<String, String> _localizedStrings;

  AppLocalizations(this.locale, this._localizedStrings);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Static member to have a simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // List of supported locales
  static const List<Locale> supportedLocales = [
    Locale('es', ''),
    Locale('en', ''),
    Locale('pt', ''),
  ];

  // List of localizations delegates
  static const List<LocalizationsDelegate> localizationsDelegates =
      <LocalizationsDelegate>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  String translate(String key) => _localizedStrings[key] ?? key;

  // Static method to load the translations
  static Future<AppLocalizations> load(Locale locale) async {
    // Load the language JSON file from the "l10n" folder
    final Map<String, String> localizedStrings = {};

    try {
      // Load the JSON file
      final String filePath = 'assets/translations/${locale.languageCode}.json';
      final String jsonString = await rootBundle.loadString(filePath);

      // Parse the JSON string using the top-level jsonDecode function
      final Map<String, dynamic> jsonMap =
          jsonDecode(jsonString) as Map<String, dynamic>;

      // Extract the translations
      jsonMap.forEach((key, value) {
        if (key.startsWith('@')) return; // Skip metadata
        localizedStrings[key] = value.toString();
      });
    } catch (e) {
      debugPrint('Error loading language file: $e');
      // Fallback to English if the language file is not found
      if (locale.languageCode != 'en') {
        return load(const Locale('en', ''));
      }
    }

    return AppLocalizations(locale, localizedStrings);
  }

  // Getters for the translated strings
  String get appTitle => translate('appTitle');
  String get settings => translate('settings');
  String get darkTheme => translate('darkTheme');
  String get language => translate('language');
  String get spanish => translate('spanish');
  String get english => translate('english');
  String get portuguese => translate('portuguese');
  String get selectLanguage => translate('selectLanguage');
  String get currency => translate('currency');
  String get printer => translate('printer');
  String get notifications => translate('notifications');
  String get biometricAuth => translate('biometricAuth');
  String get appVersion => translate('appVersion');
  String get helpAndSupport => translate('helpAndSupport');
  String get privacyPolicy => translate('privacyPolicy');
  String get termsAndConditions => translate('termsAndConditions');
  String get logout => translate('logout');
  String get resetSettings => translate('resetSettings');
  String get resetSettingsConfirmation =>
      translate('resetSettingsConfirmation');
  String get cancel => translate('cancel');
  String get reset => translate('reset');
  String get settingsRestored => translate('settingsRestored');
}

// Delegate class for AppLocalizations
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['es', 'en', 'pt'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations.load(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

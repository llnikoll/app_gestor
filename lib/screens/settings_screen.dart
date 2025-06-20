import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _settings;
  String _appVersion = '1.0.0';
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _initPackageInfo();
    _appVersion = 'Cargando...';
  }

  Future<void> _initPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  void _showLanguageDialog() {
    final BuildContext dialogContext = context;
    final navigator = Navigator.of(dialogContext);
    final currentLocale = EasyLocalization.of(context)?.locale ?? const Locale('es');

    showDialog(
      context: dialogContext,
      builder: (BuildContext context) => AlertDialog(
        title: Text('selectLanguage'.tr()),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<Locale>(
                title: const Text('Español'),
                value: const Locale('es'),
                groupValue: currentLocale,
                onChanged: (Locale? value) async {
                  if (value != null) {
                    await _changeLocale(value);
                    if (!mounted) return;
                    navigator.pop();
                  }
                },
              ),
              RadioListTile<Locale>(
                title: const Text('English'),
                value: const Locale('en', 'US'),
                groupValue: currentLocale,
                onChanged: (Locale? value) async {
                  if (value != null) {
                    await _changeLocale(value);
                    if (!mounted) return;
                    navigator.pop();
                  }
                },
              ),
              RadioListTile<Locale>(
                title: const Text('Português'),
                value: const Locale('pt', 'BR'),
                groupValue: currentLocale,
                onChanged: (Locale? value) async {
                  if (value != null) {
                    await _changeLocale(value);
                    if (!mounted) return;
                    navigator.pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeLocale(Locale locale) async {
    // Guardar solo el código de idioma sin el país
    await _settings.setLanguage(locale.languageCode);
    if (!mounted) return;
    
    // Establecer el locale completo (con código de país si existe)
    await context.setLocale(locale);
    if (!mounted) return;
    
    // Actualizar la UI
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Idioma cambiado a ${_getLanguageName(locale.languageCode)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'es':
        return 'Español';
      case 'en':
        return 'English';
      case 'pt':
        return 'Português';
      default:
        return languageCode;
    }
  }

  void _showCurrencyDialog() {
    final BuildContext dialogContext = context;
    final navigator = Navigator.of(dialogContext);
    final currentCurrency = _settings.currency;

    showDialog(
      context: dialogContext,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seleccionar moneda'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _settings.supportedCurrencies.length,
            itemBuilder: (BuildContext context, int index) {
              final currency = _settings.supportedCurrencies[index];
              return RadioListTile<String>(
                title: Text('${currency.name} (${currency.symbol})'),
                value: currency.code,
                groupValue: currentCurrency,
                onChanged: (String? value) async {
                  if (value != null) {
                    await _settings.setCurrency(value);
                    if (!mounted) return;
                    setState(() {});
                    navigator.pop();
                    
                    // Usar el contexto del diálogo para mostrar el mensaje
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Moneda cambiada a ${currency.name}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showPrinterDialog() {
    final BuildContext dialogContext = context;
    final navigator = Navigator.of(dialogContext);

    showDialog(
      context: dialogContext,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seleccionar impresora'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: SettingsService.availablePrinters.length,
            itemBuilder: (BuildContext context, int index) {
              final printer = SettingsService.availablePrinters[index];
              return RadioListTile<String>(
                title: Text(printer),
                value: printer,
                groupValue: _settings.printer,
                onChanged: (String? value) async {
                  if (value != null) {
                    await _settings.setPrinter(value);
                    if (!mounted) return;
                    setState(() {});
                    navigator.pop();
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      color: Theme.of(context).cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500, 
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle, 
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<bool> _isBiometricAvailable() async {
    try {
      final bool isMobile =
          Theme.of(context).platform == TargetPlatform.android ||
          Theme.of(context).platform == TargetPlatform.iOS;
      if (!isMobile) return false;
      return true;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('settings'.tr()),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) => AlertDialog(
                      title: const Text('Restaurar configuración'),
                      content: const Text('¿Estás seguro de que deseas restaurar la configuración predeterminada?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _settings.resetToDefault();
                            if (!mounted) return;
                            setState(() {});
                            themeNotifier.toggleTheme();
                            if (!mounted) return;
                            navigator.pop();
                            if (!mounted) return;
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('Configuración restaurada')),
                            );
                          },
                          child: const Text('Restaurar'),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Restaurar valores por defecto',
              ),
            ],
          ),
          body: ListView(
            children: [
              _buildSectionTitle('APARIENCIA'),
              _buildSettingItem(
                icon: Icons.brightness_6,
                title: 'Tema oscuro',
                trailing: Switch(
                  value: themeNotifier.isDarkMode,
                  onChanged: (value) {
                    themeNotifier.toggleTheme();
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text('language'.tr()),
                subtitle: Text({
                  'es': 'Español',
                  'en': 'English',
                  'pt': 'Português',
                }[context.locale.languageCode] ?? 'Español'),
                onTap: _showLanguageDialog,
              ),
              _buildSectionTitle('PREFERENCIAS'),
              _buildSettingItem(
                icon: Icons.attach_money,
                title: 'Moneda',
                subtitle: '${_settings.currentCurrency.name} (${_settings.currentCurrency.symbol})',
                onTap: _showCurrencyDialog,
              ),
              _buildSettingItem(
                icon: Icons.print,
                title: 'Impresora',
                subtitle: _settings.printer,
                onTap: _showPrinterDialog,
              ),
              _buildSettingItem(
                icon: Icons.notifications,
                title: 'Notificaciones',
                trailing: Switch(
                  value: _settings.notificationsEnabled,
                  onChanged: (value) async {
                    await _settings.setNotificationsEnabled(value);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
              ),
              _buildSettingItem(
                icon: Icons.fingerprint,
                title: 'Autenticación biométrica',
                trailing: FutureBuilder<bool>(
                  future: _isBiometricAvailable(),
                  builder: (context, snapshot) {
                    final isAvailable = snapshot.data ?? false;
                    return Switch(
                      value: _settings.biometricAuthEnabled && isAvailable,
                      onChanged: isAvailable
                          ? (bool value) async {
                              await _settings.setBiometricAuthEnabled(value);
                              if (mounted) {
                                setState(() {});
                              }
                            }
                          : null,
                      activeColor: isAvailable
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    );
                  },
                ),
                subtitle: _settings.biometricAuthEnabled
                    ? 'Activado'
                    : 'Desactivado',
              ),
              _buildSectionTitle('INFORMACIÓN'),
              _buildSettingItem(
                icon: Icons.info_outline,
                title: 'Versión de la aplicación',
                subtitle: _packageInfo != null 
                    ? 'Versión $_appVersion\n${_packageInfo!.packageName}'
                    : 'Cargando...',
                isLoading: _packageInfo == null,
                onTap: _packageInfo != null ? () {
                  // Verificar actualizaciones
                } : null,
              ),
              _buildSettingItem(
                icon: Icons.help_outline,
                title: 'Ayuda y soporte',
                onTap: () {
                  // Navegar a la pantalla de ayuda
                },
              ),
              _buildSettingItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Política de privacidad',
                onTap: () async {
                  final url = Uri.parse('https://tudominio.com/privacidad');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
              _buildSettingItem(
                icon: Icons.description_outlined,
                title: 'Términos y condiciones',
                onTap: () async {
                  final url = Uri.parse('https://tudominio.com/terminos');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
              _buildSectionTitle('CUENTA'),
              _buildSettingItem(
                icon: Icons.logout,
                title: 'logout'.tr(),
                onTap: () {
                  // Cerrar sesión
                },
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '© 2023 Tu Empresa. Todos los derechos reservados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

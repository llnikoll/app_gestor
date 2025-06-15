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
    if (!mounted) return;
    setState(() {
      _packageInfo = packageInfo;
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  void _showLanguageDialog() {
    final BuildContext dialogContext = context;
    final navigator = Navigator.of(dialogContext);

    showDialog(
      context: dialogContext,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seleccionar idioma'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: SettingsService.availableLanguages.length,
            itemBuilder: (BuildContext context, int index) {
              final lang = SettingsService.availableLanguages[index];
              return RadioListTile<String>(
                title: Text(lang['name']),
                value: lang['code'],
                groupValue: _settings.language,
                onChanged: (String? value) async {
                  if (value != null) {
                    await _settings.setLanguage(value);
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

  void _showCurrencyDialog() {
    final BuildContext dialogContext = context;
    final navigator = Navigator.of(dialogContext);

    showDialog(
      context: dialogContext,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seleccionar moneda'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: SettingsService.availableCurrencies.length,
            itemBuilder: (BuildContext context, int index) {
              final currency = SettingsService.availableCurrencies[index];
              return RadioListTile<String>(
                title: Text(currency['name']),
                value: currency['code'],
                groupValue: _settings.currency,
                onChanged: (String? value) async {
                  if (value != null) {
                    await _settings.setCurrency(value);
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 13))
            : null,
        trailing: trailing,
        onTap: onTap,
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
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
                      content: const Text(
                        '¿Estás seguro de que deseas restaurar la configuración predeterminada?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await _settings.resetToDefault();
                              if (!mounted) return;
                              setState(() {});
                              themeNotifier.toggleTheme();
                              if (!mounted) return;
                              navigator.pop();
                              if (!mounted) return;
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Configuración restaurada'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error al restaurar configuración: $e',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
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
              _buildSettingItem(
                icon: Icons.language,
                title: 'Idioma',
                subtitle: SettingsService.availableLanguages.firstWhere(
                  (lang) => lang['code'] == _settings.language,
                  orElse: () => {'name': 'Español'},
                )['name'],
                onTap: _showLanguageDialog,
              ),
              _buildSectionTitle('PREFERENCIAS'),
              _buildSettingItem(
                icon: Icons.attach_money,
                title: 'Moneda',
                subtitle: SettingsService.availableCurrencies.firstWhere(
                  (curr) => curr['code'] == _settings.currency,
                  orElse: () => {'name': 'Guaraní (₲)'},
                )['name'],
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
                  onChanged: (value) {
                    // Capture context before async operation
                    final currentContext = context;
                    final currentScaffoldMessenger = ScaffoldMessenger.of(
                      currentContext,
                    );

                    _settings
                        .setNotificationsEnabled(value)
                        .then((_) {
                          if (mounted) {
                            setState(() {});
                          }
                        })
                        .catchError((e) {
                          if (!mounted) return;
                          currentScaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al actualizar notificaciones: $e',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        });
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
                          ? (bool value) {
                              // Capture context before async operation
                              final currentContext = context;
                              final currentScaffoldMessenger =
                                  ScaffoldMessenger.of(currentContext);

                              _settings
                                  .setBiometricAuthEnabled(value)
                                  .then((_) {
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  })
                                  .catchError((e) {
                                    if (!mounted) return;
                                    currentScaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error al actualizar autenticación biométrica: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  });
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
                onTap: _packageInfo != null
                    ? () {
                        // Verificar actualizaciones
                      }
                    : null,
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
                title: 'Cerrar sesión',
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

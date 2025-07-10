import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../widgets/company_logo_picker.dart';

class ChangeAdminPasswordDialog extends StatefulWidget {
  const ChangeAdminPasswordDialog({super.key});

  @override
  State<ChangeAdminPasswordDialog> createState() =>
      _ChangeAdminPasswordDialogState();
}

class _ChangeAdminPasswordDialogState extends State<ChangeAdminPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = Provider.of<SettingsService>(context, listen: false);

      // Verificar la contraseña actual
      final isCurrentValid =
          await settings.verifyAdminPassword(_currentPasswordController.text);
      if (!isCurrentValid) {
        setState(() {
          _errorMessage = 'La contraseña actual es incorrecta';
          _isLoading = false;
        });
        return;
      }

      // Actualizar la contraseña
      await settings.setAdminPassword(_newPasswordController.text);

      if (!mounted) return;

      // Mostrar mensaje de éxito y cerrar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cambiar la contraseña: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña de administrador'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su contraseña actual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una nueva contraseña';
                  }
                  if (value.length < 4) {
                    return 'La contraseña debe tener al menos 4 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor confirme la nueva contraseña';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Cambiar contraseña'),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
  }

  void _showLanguageDialog() {
    final BuildContext dialogContext = context;
    final navigator = Navigator.of(dialogContext);
    final currentLocale =
        EasyLocalization.of(context)?.locale ?? const Locale('es');

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
        content:
            Text('Idioma cambiado a ${_getLanguageName(locale.languageCode)}'),
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
      builder: (BuildContext context) {
        return AlertDialog(
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
                      if (context.mounted) {
                        navigator.pop();
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
        );
      },
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
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8), // Increased vertical margin
      elevation: 4, // Increased elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // More rounded corners
      ),
      color: Theme.of(context).cardColor,
      child: InkWell(
        // Added InkWell for ripple effect
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16), // Increased padding
          child: Row(
            children: [
              Container(
                width: 48, // Larger icon container
                height: 48, // Larger icon container
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .primaryColor
                      .withValues(alpha: 0.15), // More opaque background
                  borderRadius:
                      BorderRadius.circular(12), // More rounded icon background
                ),
                child: Icon(icon,
                    color: Theme.of(context).primaryColor,
                    size: 28), // Larger icon
              ),
              const SizedBox(width: 16), // Increased spacing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, // Bolder title
                            fontSize: 16, // Slightly larger font size
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontSize: 14, // Slightly larger font size
                                color: Colors.grey[700], // Slightly darker grey
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12), // Increased padding
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              // Larger font size
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18, // Increased font size
              letterSpacing: 0.8, // Increased letter spacing
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
          ),
          body: ListView(
            children: [
              _buildSectionTitle('APARIENCIA'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    Text(
                      'Logo de la Empresa',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const CompanyLogoPicker(size: 120),
                    const SizedBox(height: 8),
                    Text(
                      'Toca para cambiar el logo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
                subtitle: {
                      'es': 'Español',
                      'en': 'English',
                      'pt': 'Português',
                    }[context.locale.languageCode] ??
                    'Español',
                onTap: _showLanguageDialog,
              ),
              _buildSectionTitle('PREFERENCIAS'),
              Consumer<SettingsService>(
                builder: (context, settings, child) {
                  return _buildSettingItem(
                    icon: Icons.attach_money,
                    title: 'Moneda',
                    subtitle:
                        '${settings.currentCurrency.name} (${settings.currentCurrency.symbol})',
                    onTap: _showCurrencyDialog,
                  );
                },
              ),
              _buildSectionTitle('SEGURIDAD'),
              _buildSettingItem(
                icon: Icons.lock_outline,
                title: 'Cambiar contraseña de administrador',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const ChangeAdminPasswordDialog(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

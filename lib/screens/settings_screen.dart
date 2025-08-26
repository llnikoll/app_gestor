import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../main.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../widgets/company_logo_picker.dart';
import './donation_screen.dart';

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

      final isCurrentValid =
          await settings.verifyAdminPassword(_currentPasswordController.text);
      if (!isCurrentValid) {
        setState(() {
          _errorMessage = 'La contraseña actual es incorrecta';
          _isLoading = false;
        });
        return;
      }

      await settings.setAdminPassword(_newPasswordController.text);

      if (!mounted) return;

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
  final _backupService = BackupService();
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
  }

  Future<void> _createBackup() async {
    if (!mounted) return;
    setState(() => _isBackingUp = true);
    try {
      final path = await _backupService.createBackup();
      if (mounted) {
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Copia de seguridad guardada en: ${p.basename(path)}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Operación cancelada por el usuario')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear la copia: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¡ADVERTENCIA MUY IMPORTANTE!'),
        content: const Text(
            'Restaurar una copia de seguridad reemplazará TODOS sus datos actuales (productos, ventas, configuraciones, etc.) de forma permanente.\n\nEsta acción no se puede deshacer. ¿Está seguro de que desea continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('SÍ, RESTAURAR'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operación de restauración cancelada.')),
        );
      }
      return;
    }

    setState(() => _isRestoring = true);

    try {
      await DatabaseService().close();

      final success = await _backupService.restoreFromFile(result.files.single.path!);

      if (mounted) {
        if (success) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Restauración Completa'),
              content: const Text(
                  'Los datos se han restaurado correctamente. La aplicación debe reiniciarse para aplicar los cambios.\n\nLa aplicación se cerrará ahora. Por favor, vuelva a abrirla.'),
              actions: [
                TextButton(
                  onPressed: () => exit(0),
                  child: const Text('ACEPTAR Y CERRAR'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La restauración ha fallado.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error grave durante la restauración: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
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
    await _settings.setLanguage(locale.languageCode);
    if (!mounted) return;

    await context.setLocale(locale);
    if (!mounted) return;

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
      return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 16),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ));
    }
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .primaryColor
                      .withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: Theme.of(context).primaryColor,
                    size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
                                fontSize: 14,
                                color: Colors.grey[700],
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
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.8,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(0.0), // Altura cero para la AppBar
            child: AppBar(
              elevation: 0, // Sin sombra
              toolbarHeight: 0, // Altura cero
            ),
          ),
          body: ListView(
            children: [
              _buildSectionTitle('APARIENCIA'),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              _buildSectionTitle('DATOS'),
              _buildSettingItem(
                icon: Icons.backup_outlined,
                title: 'Crear copia de seguridad',
                subtitle: 'Guarda tus datos en un archivo .zip',
                isLoading: _isBackingUp,
                onTap: _isBackingUp ? null : _createBackup,
              ),
              _buildSettingItem(
                icon: Icons.restore_page_outlined,
                title: 'Restaurar desde copia de seguridad',
                subtitle: 'Sobrescribe los datos actuales',
                isLoading: _isRestoring,
                onTap: _isRestoring ? null : _restoreBackup,
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
              _buildSectionTitle('SOPORTE'),
              _buildSettingItem(
                icon: Icons.volunteer_activism,
                title: 'Apoyar al Desarrollador',
                subtitle: 'Ayúdanos a mantener la aplicación',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DonationScreen()),
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
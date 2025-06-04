import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/primary_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _biometricAuth = false;
  String _selectedLanguage = 'es';
  String _selectedCurrency = 'MXN';
  String _printerName = 'Predeterminada';
  final String _appVersion = '1.0.0';

  final List<Map<String, dynamic>> _languages = [
    {'code': 'es', 'name': 'Español'},
    {'code': 'en', 'name': 'English'},
    {'code': 'pt', 'name': 'Português'},
  ];

  final List<Map<String, dynamic>> _currencies = [
    {'code': 'MXN', 'name': 'Peso Mexicano (\$)'},
    {'code': 'USD', 'name': 'Dólar Americano (\$)'},
    {'code': 'EUR', 'name': 'Euro (€)'},
    {'code': 'GTQ', 'name': 'Quetzal (Q)'},
    {'code': 'PEN', 'name': 'Sol (S/.)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _biometricAuth = prefs.getBool('biometricAuth') ?? false;
      _selectedLanguage = prefs.getString('language') ?? 'es';
      _selectedCurrency = prefs.getString('currency') ?? 'MXN';
      _printerName = prefs.getString('printer') ?? 'Predeterminada';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar idioma'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _languages.length,
            itemBuilder: (context, index) {
              final lang = _languages[index];
              return RadioListTile<String>(
                title: Text(lang['name']),
                value: lang['code'],
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                    _saveSetting('language', value);
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar moneda'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _currencies.length,
            itemBuilder: (context, index) {
              final currency = _currencies[index];
              return RadioListTile<String>(
                title: Text(currency['name']),
                value: currency['code'],
                groupValue: _selectedCurrency,
                onChanged: (value) {
                  setState(() {
                    _selectedCurrency = value!;
                    _saveSetting('currency', value);
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showPrinterDialog() {
    final printers = ['Predeterminada', 'Impresora 1', 'Impresora 2', 'Impresora Bluetooth'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar impresora'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: printers.length,
            itemBuilder: (context, index) {
              final printer = printers[index];
              return RadioListTile<String>(
                title: Text(printer),
                value: printer,
                groupValue: _printerName,
                onChanged: (value) {
                  setState(() {
                    _printerName = value!;
                    _saveSetting('printer', value);
                  });
                  Navigator.pop(context);
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
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withAlpha(26), // 0.1 * 255 ≈ 26
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // Guardar configuración
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuración guardada')),
              );
            },
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
              value: _isDarkMode,
              onChanged: (value) {
                setState(() {
                  _isDarkMode = value;
                  _saveSetting('darkMode', value);
                });
              },
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
          _buildSettingItem(
            icon: Icons.language,
            title: 'Idioma',
            subtitle: _languages.firstWhere(
              (lang) => lang['code'] == _selectedLanguage,
              orElse: () => {'name': 'Español'},
            )['name'],
            onTap: _showLanguageDialog,
          ),
          _buildSectionTitle('PREFERENCIAS'),
          _buildSettingItem(
            icon: Icons.attach_money,
            title: 'Moneda',
            subtitle: _currencies.firstWhere(
              (curr) => curr['code'] == _selectedCurrency,
              orElse: () => {'name': 'MXN - Peso Mexicano'},
            )['name'],
            onTap: _showCurrencyDialog,
          ),
          _buildSettingItem(
            icon: Icons.print,
            title: 'Impresora',
            subtitle: _printerName,
            onTap: _showPrinterDialog,
          ),
          _buildSettingItem(
            icon: Icons.notifications,
            title: 'Notificaciones',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                  _saveSetting('notifications', value);
                });
              },
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
          _buildSettingItem(
            icon: Icons.fingerprint,
            title: 'Autenticación biométrica',
            trailing: Switch(
              value: _biometricAuth,
              onChanged: (value) {
                setState(() {
                  _biometricAuth = value;
                  _saveSetting('biometricAuth', value);
                });
              },
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
          _buildSectionTitle('INFORMACIÓN'),
          _buildSettingItem(
            icon: Icons.info_outline,
            title: 'Versión de la aplicación',
            subtitle: 'Versión $_appVersion',
            onTap: () {
              // Verificar actualizaciones
            },
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
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
            child: PrimaryButton(
              text: 'Cerrar sesión',
              icon: Icons.logout,
              onPressed: () {
                // Cerrar sesión
              },
              isOutlined: true,
              color: Colors.red,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
              child: Text(
                '© 2023 Tu Empresa. Todos los derechos reservados.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

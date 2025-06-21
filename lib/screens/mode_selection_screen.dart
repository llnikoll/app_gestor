import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import 'home_screen.dart';
import 'caja_screen.dart'; // Import CajaScreen using relative path

class AdminPasswordDialog extends StatefulWidget {
  const AdminPasswordDialog({super.key});

  @override
  State<AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<AdminPasswordDialog> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isIncorrect = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context, listen: false);

    return AlertDialog(
      title: const Text('Acceso de Administrador'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese la contraseña de administrador:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese la contraseña';
                }
                return null;
              },
            ),
            if (_isIncorrect) ...[
              const SizedBox(height: 8),
              const Text(
                'Contraseña incorrecta',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              // Store the password and verify it
              final password = _passwordController.text;
              
              // Use a local function to handle the result
              void handleVerificationResult(bool isValid) {
                if (!mounted) return;
                if (isValid) {
                  Navigator.of(context).pop(true);
                } else {
                  setState(() => _isIncorrect = true);
                }
              }
              
              // Perform the async operation and handle the result
              settings.verifyAdminPassword(password).then(handleVerificationResult);
            }
          },
          child: const Text('Ingresar'),
        ),
      ],
    );
  }
}

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _checkFirstRun();
    }
  }

  Future<void> _checkFirstRun() async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    if (settings.isFirstRun) {
      // Usar un pequeño retraso para asegurar que el árbol de widgets esté completamente construido
      await Future.delayed(Duration.zero);
      if (mounted) {
        await _showAdminPasswordSetup();
      }
    }
  }

  Future<void> _showAdminPasswordSetup() async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final settings = Provider.of<SettingsService>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    final navigator = Navigator.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Configuración Inicial'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Establezca una contraseña de administrador',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 4) {
                      return 'La contraseña debe tener al menos 4 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != passwordController.text) {
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
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                await settings.setAdminPassword(passwordController.text);
                if (mounted) {
                  navigator.pop();
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Método para manejar el botón atrás
  Future<bool> _onWillPop() async {
    // En dispositivos móviles, mostrar diálogo de confirmación
    if (MediaQuery.of(context).size.width < 600) {
      final bool? shouldPop = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Salir de la aplicación'),
          content: const Text('¿Estás seguro de que quieres salir de la aplicación?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      return shouldPop ?? false;
    } else {
      // En escritorio, simplemente salir sin diálogo de confirmación
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si estamos en un dispositivo de escritorio
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    
    // Usar WillPopScope con comentario para ignorar la advertencia de deprecación
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: isDesktop 
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _onWillPop().then((shouldPop) {
                  if (shouldPop) {
                    SystemNavigator.pop(animated: true);
                  }
                }),
              ),
              title: const Text('Selección de Modo'),
            )
          : null,
        body: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),
                  // Logo de la aplicación
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    height: 150,
                    width: 150,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SELECCIONE EL MODO',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _ModeCard(
                    icon: Icons.admin_panel_settings,
                    title: 'MODO ADMINISTRADOR',
                    subtitle: 'Acceso completo al sistema',
                    onTap: () async {
                      final settings =
                          Provider.of<SettingsService>(context, listen: false);
                      final navigator = Navigator.of(context);

                      if (settings.hasAdminPassword) {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => const AdminPasswordDialog(),
                        );
                        if (!mounted) return;
                        if (result == true) {
                          navigator.pushReplacement(
                            MaterialPageRoute(
                                builder: (context) => const HomeScreen()),
                          );
                        }
                      } else {
                        if (!mounted) return;
                        navigator.pushReplacement(
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 40),
                  _ModeCard(
                    icon: Icons.point_of_sale,
                    title: 'MODO CAJA',
                    subtitle: 'Atención al cliente',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const CajaScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: theme.primaryColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

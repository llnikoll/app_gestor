import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // Para copiar al portapapeles

class DonationScreen extends StatelessWidget {
  const DonationScreen({super.key});

  final String paypalMeLink = 'https://paypal.me/niko.oviedo@gmail.com';
  final String bankAccountDetails = '''
Nombre del Banco: UENO
Número de Cuenta: 619283639 (Caja de Ahorro)
Alias: 0993539237
Titular: 4175624
Código SWIFT/BIC: [Consultar con el banco para transferencias internacionales]
''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apoya al Desarrollador'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png', // Ruta a tu logo
                height: 100, // Ajusta el tamaño según sea necesario
                width: 100,
              ),
              const SizedBox(height: 24),
              Text(
                '¡Gracias por considerar apoyar el desarrollo de esta aplicación!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Tu contribución nos ayuda a mantener la aplicación actualizada, añadir nuevas funciones y ofrecer soporte continuo.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Sección PayPal
              Text(
                'Donar vía PayPal:',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, // Ocupa todo el ancho disponible
                child: FilledButton.icon(
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(paypalMeLink))) {
                      if (!context.mounted) return;
                      await launchUrl(Uri.parse(paypalMeLink));
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudo abrir el enlace de PayPal.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.paypal),
                  label: const Text('Donar con PayPal'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Sección Transferencia Bancaria
              Text(
                'Donar vía Transferencia Bancaria:',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 8, // Mayor elevación para un efecto más moderno
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.symmetric(horizontal: 0), // Sin margen horizontal
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        bankAccountDetails,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: bankAccountDetails));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Detalles bancarios copiados al portapapeles.')),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar Detalles'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                '¡Cada pequeña contribución es muy apreciada y nos motiva a seguir mejorando!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
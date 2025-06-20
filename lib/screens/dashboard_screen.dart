import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/producto_model.dart'; // Asegúrate que esta ruta sea correcta
import '../services/database_service.dart'; // Asegúrate que esta ruta sea correcta
import '../services/product_notifier_service.dart'; // Asegúrate que esta ruta sea correcta
import '../services/settings_service.dart';
import '../widgets/primary_button.dart'; // Asegúrate que esta ruta sea correcta
import 'home_screen.dart'; // Asegúrate que esta ruta sea correcta
import 'product_form_screen.dart'; // Asegúrate que esta ruta sea correcta
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  ProductNotifierService? _productNotifier;
  late Future<Map<String, dynamic>> _dashboardData;
  late NumberFormat currencyFormat;
  late SettingsService _settingsService;
  final numberFormat = NumberFormat.decimalPattern(
    'es_PY',
  ); // Para números generales

  @override
  void initState() {
    super.initState();
    // La carga inicial se moverá a didChangeDependencies para asegurar que
    // _productNotifier esté disponible.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_productNotifier == null) {
      _productNotifier = Provider.of<ProductNotifierService>(
        context,
        listen: false,
      );
      _settingsService = SettingsService();
      currencyFormat = NumberFormat.currency(
        symbol: '${_settingsService.currentCurrency.symbol} ',
        decimalDigits: _settingsService.currentCurrency.decimalDigits,
        locale: _settingsService.currentCurrency.locale,
      );
      _productNotifier!.notifier.addListener(_onProductUpdate);
      _loadDashboardData(); // Carga inicial de datos
    }
  }

  @override
  void dispose() {
    _productNotifier?.notifier.removeListener(_onProductUpdate);
    super.dispose();
  }

  void _onProductUpdate() {
    if (mounted) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() {
        _dashboardData = _getDashboardData();
      });
    }
  }

  Future<Map<String, dynamic>> _getDashboardData() async {
    try {
      final db = DatabaseService();
      final products = await db.getProductos();
      final totalProducts = products.length;
      // Productos con stock bajo (entre 1 y 9 unidades)
      final lowStockProducts = products
          .where((p) => p.stock > 0 && p.stock < 10)
          .length;
      // Productos sin stock (0 o menos unidades)
      final outOfStockProducts = products.where((p) => p.stock <= 0).length;

      double totalInventoryValue = 0;
      for (var product in products) {
        totalInventoryValue += product.precioVenta * product.stock;
      }

      // Simulación de datos para futuras secciones. Reemplazar con lógica real.
      final topSellingProducts = <Producto>[];
      final recentSales = <Map<String, dynamic>>[];

      return {
        'totalProducts': totalProducts,
        'lowStockProducts': lowStockProducts,
        'outOfStockProducts': outOfStockProducts,
        'totalInventoryValue': totalInventoryValue,
        'topSellingProducts': topSellingProducts,
        'recentSales': recentSales,
      };
    } catch (e) {
      debugPrint('Error al cargar los datos del dashboard: $e');
      rethrow;
    }
  }

  int _getCrossAxisCount(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 2; // Móviles
    if (screenWidth < 1024) return 3; // Tablets pequeñas, móviles en horizontal
    return 4; // Tablets grandes, Escritorio
  }

  double _getChildAspectRatioForStats(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return 1 / 1.15; // Tarjetas de estadísticas más altas en móviles
    }
    if (screenWidth < 1024) {
      return 3 / 2.3;
    }
    return 3 / 2.2; // Tarjetas de estadísticas más anchas en pantallas grandes
  }

  double _getChildAspectRatioForActions(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return 2 / 1.1; // Botones de acción ligeramente más altos
    }
    return 2.5 / 1; // Botones de acción más anchos en pantallas grandes
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Panel de Control',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: colorScheme.primary,
        elevation: 1.0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colorScheme.onPrimary),
            tooltip: 'Actualizar datos',
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: colorScheme.primary,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _dashboardData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: colorScheme.primary),
                        const SizedBox(height: 20),
                        Text(
                          'Cargando datos...',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          color: colorScheme.error,
                          size: 50,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error al Cargar Datos',
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No se pudo conectar para obtener la información. Verifica tu conexión e inténtalo de nuevo.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                          onPressed: _loadDashboardData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            textStyle: textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData ||
                  snapshot.data == null ||
                  snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colorScheme.secondary,
                          size: 50,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay datos para mostrar',
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Parece que aún no hay información registrada en el panel.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Actualizar'),
                          onPressed: _loadDashboardData,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                    child: Text(
                      'Resumen General',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme
                            .primary, // Destacar título con color primario
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: _getCrossAxisCount(context),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: _getChildAspectRatioForStats(context),
                    children: [
                      _buildStatCard(
                        'Productos Totales',
                        numberFormat.format(data['totalProducts']),
                        Icons.inventory_2_outlined,
                        Colors.blue.shade700,
                      ),
                      _buildStatCard(
                        'Bajo Stock (<10)',
                        numberFormat.format(data['lowStockProducts']),
                        Icons.warning_amber_outlined,
                        Colors.orange.shade700,
                      ),
                      _buildStatCard(
                        'Agotados',
                        numberFormat.format(data['outOfStockProducts']),
                        Icons.error_outline_rounded,
                        Colors.red.shade700,
                      ),
                      _buildStatCard(
                        'Valor Inventario', // Título más corto
                        currencyFormat.format(data['totalInventoryValue']),
                        Icons.monetization_on_outlined,
                        Colors.green.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Acciones Rápidas',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: _getCrossAxisCount(context),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: _getChildAspectRatioForActions(context),
                    children: [
                      PrimaryButton(
                        text: 'Nueva Venta',
                        icon: Icons.point_of_sale_rounded,
                        onPressed: () =>
                            HomeScreen.of(context)?.onItemTapped(1),
                      ),
                      PrimaryButton(
                        text: 'Agregar Producto',
                        icon: Icons.add_shopping_cart_rounded,
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                insetPadding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                  vertical: 24.0,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: 600,
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                          0.8,
                                    ),
                                    child: const ProductFormScreen(),
                                  ),
                                ),
                              );
                            },
                          );
                          if (result == true) _loadDashboardData();
                        },
                      ),
                      PrimaryButton(
                        text: 'Ver Inventario',
                        icon: Icons.inventory_rounded,
                        onPressed: () =>
                            HomeScreen.of(context)?.onItemTapped(2),
                      ),
                      PrimaryButton(
                        text: 'Generar Reporte',
                        icon: Icons.bar_chart_rounded,
                        onPressed: () =>
                            HomeScreen.of(context)?.onItemTapped(4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20), // Espacio final
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/producto_model.dart';
import '../services/database_service.dart';
import '../services/product_notifier_service.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';
import 'product_form_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  ProductNotifierService? _productNotifier;
  late Future<Map<String, dynamic>> _dashboardData;
  final currencyFormat = NumberFormat.currency(symbol: 'Gs. ', decimalDigits: 0, locale: 'es_PY');
  final numberFormat = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _dashboardData = _getDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Obtener el notificador de productos solo una vez
    _productNotifier ??= Provider.of<ProductNotifierService>(
      context,
      listen: false,
    );

    // Escuchar cambios en el notificador
    _productNotifier!.notifier.addListener(_onProductUpdate);
  }

  @override
  void dispose() {
    // Limpiar el listener cuando el widget se destruya
    _productNotifier?.notifier.removeListener(_onProductUpdate);
    super.dispose();
  }

  // Método que se ejecuta cuando hay una actualización de productos
  void _onProductUpdate() {
    if (mounted) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _dashboardData = _getDashboardData();
    });
  }

  Future<Map<String, dynamic>> _getDashboardData() async {
    try {
      final db = DatabaseService();
      final products = await db.getProductos();

      // Calcular estadísticas
      final totalProducts = products.length;
      final lowStockProducts = products.where((p) => p.stock < 10).length;
      final outOfStockProducts = products.where((p) => p.stock <= 0).length;

      // Calcular valor total del inventario
      double totalInventoryValue = 0;
      for (var product in products) {
        try {
          debugPrint(
            'Procesando producto: ${product.id} - ${product.nombre} - Precio: ${product.precioVenta} - Stock: ${product.stock}',
          );
          totalInventoryValue += product.precioVenta * product.stock;
        } catch (e) {
          debugPrint(
            'Error procesando producto ${product.id} - ${product.nombre}: $e',
          );
          rethrow;
        }
      }

      // Obtener productos más vendidos (vacío por ahora hasta tener datos reales)
      final topSellingProducts = <Producto>[];

      // Ventas recientes (vacío por ahora hasta tener datos reales)
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Panel de Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: Material(
        color: theme.scaffoldBackgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _dashboardData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const Center(
                          child: CircularProgressIndicator(),
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
                                Icons.error_outline,
                                color: theme.colorScheme.error,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar los datos',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error?.toString() ?? 'Error desconocido',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loadDashboardData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Reintentar'),
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
                        // Título y resumen
                        Text(
                          'Resumen General',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tarjetas de estadísticas
                        GridView.count(
                          crossAxisCount: constraints.maxWidth > 900
                              ? 4
                              : constraints.maxWidth > 600
                                  ? 2
                                  : 1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: constraints.maxWidth > 900
                              ? 1.8
                              : constraints.maxWidth > 600
                                  ? 2.0
                                  : 2.2,
                          children: [
                            _buildStatCard(
                              'Productos Totales',
                              numberFormat.format(data['totalProducts'] ?? 0),
                              Icons.inventory_2,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              'Bajo Stock',
                              numberFormat.format(data['lowStockProducts'] ?? 0),
                              Icons.warning_amber,
                              Colors.orange,
                            ),
                            _buildStatCard(
                              'Sin Stock',
                              numberFormat.format(data['outOfStockProducts'] ?? 0),
                              Icons.block,
                              Colors.red,
                            ),
                            _buildStatCard(
                              'Valor Total',
                              currencyFormat.format(data['totalInventoryValue'] ?? 0),
                              Icons.attach_money,
                              Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Sección de acciones rápidas
                        Text(
                          'Acciones Rápidas',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            // Botón Agregar Producto
                            PrimaryButton(
                              text: 'Agregar Producto',
                              icon: Icons.add,
                              onPressed: () async {
                                final result = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return Dialog(
                                      child: Container(
                                        padding: const EdgeInsets.all(16.0),
                                        child: const SingleChildScrollView(
                                          child: ProductFormScreen(),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                if (result == true) {
                                  // Recargar datos si es necesario
                                  _loadDashboardData();
                                }
                              },
                              height: 50,
                            ),
                            // Botón Ver Inventario
                            PrimaryButton(
                              text: 'Ver Inventario',
                              icon: Icons.inventory,
                              onPressed: () {
                                // Navegar a la pantalla de inventario
                                HomeScreen.of(context)?.onItemTapped(2);
                              },
                              height: 50,
                            ),
                            // Botón Generar Reporte
                            PrimaryButton(
                              text: 'Generar Reporte',
                              icon: Icons.bar_chart,
                              onPressed: () {
                                // Navegar a la pantalla de reportes
                                HomeScreen.of(context)?.onItemTapped(3);
                              },
                              height: 50,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

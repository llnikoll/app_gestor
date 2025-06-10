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
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final numberFormat = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
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

    // Cargar datos iniciales
    _loadDashboardData();
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
                style: const TextStyle(
                  fontSize: 18,
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
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _dashboardData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Error al cargar los datos'),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadDashboardData,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título y resumen
                      const Text(
                        'Resumen General',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tarjetas de estadísticas
                      GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width > 900
                            ? 4
                            : MediaQuery.of(context).size.width > 600
                            ? 2
                            : 1,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio:
                            MediaQuery.of(context).size.width > 900
                            ? 1.8
                            : MediaQuery.of(context).size.width > 600
                            ? 2.0
                            : 2.2,
                        children: [
                          _buildStatCard(
                            'Productos Totales',
                            numberFormat.format(data['totalProducts']),
                            Icons.inventory_2,
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'Bajo Stock',
                            '${data['lowStockProducts']}',
                            Icons.warning_amber,
                            Colors.orange,
                          ),
                          _buildStatCard(
                            'Agotados',
                            '${data['outOfStockProducts']}',
                            Icons.error_outline,
                            Colors.red,
                          ),
                          _buildStatCard(
                            'Valor del Inventario',
                            currencyFormat.format(data['totalInventoryValue']),
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Acciones rápidas
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Text(
                          'Acciones Rápidas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width > 900
                            ? 4
                            : MediaQuery.of(context).size.width > 600
                            ? 2
                            : 1,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio:
                            MediaQuery.of(context).size.width > 900
                            ? 4.0
                            : MediaQuery.of(context).size.width > 600
                            ? 3.5
                            : 3.0,
                        children: [
                          // Botón Nueva Venta
                          PrimaryButton(
                            text: 'Nueva Venta',
                            icon: Icons.point_of_sale,
                            onPressed: () {
                              // Navegar a la pantalla de ventas usando el HomeScreenState
                              HomeScreen.of(context)?.onItemTapped(
                                1,
                              ); // El índice 1 corresponde a la pantalla de ventas
                            },
                            height: 50,
                          ),
                          // Botón Agregar Producto
                          PrimaryButton(
                            text: 'Agregar Producto',
                            icon: Icons.add_circle_outline,
                            onPressed: () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    child: Container(
                                      padding: const EdgeInsets.all(16.0),
                                      child: SingleChildScrollView(
                                        child: const ProductFormScreen(),
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
                              HomeScreen.of(context)?.onItemTapped(
                                2,
                              ); // Ajusta el índice según corresponda
                            },
                            height: 50,
                          ),
                          // Botón Generar Reporte
                          PrimaryButton(
                            text: 'Generar Reporte',
                            icon: Icons.bar_chart,
                            onPressed: () {
                              // Navegar a la pantalla de reportes
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
    );
  }
}

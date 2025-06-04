import 'package:flutter/material.dart';
import '../models/producto_model.dart';
import '../services/database_service.dart';
import '../widgets/primary_button.dart';
import 'product_form_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardData;
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final numberFormat = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
        totalInventoryValue += product.precioVenta * product.stock;
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
      throw Exception('Error al cargar los datos del dashboard: $e');
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(Producto product) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory, color: Colors.grey),
      ),
      title: Text(
        product.nombre,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('Stock: ${product.stock}'),
      trailing: Text(
        currencyFormat.format(product.precioVenta),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 72, 168, 75),
        ),
      ),
    );
  }

  Widget _buildRecentSalesItem(Map<String, dynamic> sale) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.receipt, color: Colors.green),
      ),
      title: Text(
        sale['product'],
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text('${sale['quantity']} unidades • ${sale['date']}'),
      trailing: Text(
        currencyFormat.format(sale['amount']),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título y acciones
            Row(
              children: [
                const Text(
                  'Panel de Control',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadDashboardData,
                  tooltip: 'Actualizar',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Estadísticas
            FutureBuilder<Map<String, dynamic>>(
              future: _dashboardData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      children: [
                        const Text('Error al cargar los datos'),
                        const SizedBox(height: 8),
                        PrimaryButton(
                          text: 'Reintentar',
                          onPressed: _loadDashboardData,
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData) {
                  return const Center(child: Text('No hay datos disponibles'));
                }

                final data = snapshot.data!;

                return Column(
                  children: [
                    // Tarjetas de estadísticas
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 4
                          : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
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

                    // Productos más vendidos
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Productos con Bajo Stock',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Productos con menos de 10 unidades en stock',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if ((data['topSellingProducts'] as List).isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    'No hay productos con bajo stock',
                                  ),
                                ),
                              )
                            else
                              ...(data['topSellingProducts'] as List<Producto>)
                                  .where((p) => p.stock < 10)
                                  .take(5)
                                  .map((product) => _buildProductItem(product)),
                            const SizedBox(height: 8),
                            if ((data['topSellingProducts'] as List)
                                .where((p) => p.stock < 10)
                                .isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // Navegar a la pantalla de productos con filtro de bajo stock
                                  },
                                  child: const Text('Ver todos'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ventas recientes
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ventas Recientes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Últimas transacciones realizadas',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if ((data['recentSales'] as List).isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text('No hay ventas recientes'),
                                ),
                              )
                            else
                              ...(data['recentSales'] as List<dynamic>).map(
                                (sale) => _buildRecentSalesItem(sale),
                              ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // Navegar a la pantalla de ventas
                                },
                                child: const Text('Ver todas las ventas'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Acciones rápidas
            const Text(
              'Acciones Rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3,
              children: [
                // Botón Nueva Venta
                PrimaryButton(
                  text: 'Nueva Venta',
                  icon: Icons.point_of_sale,
                  onPressed: () {
                    // Navegar a la pantalla de nueva venta
                  },
                  height: 50,
                ),
                // Botón Agregar Producto
                PrimaryButton(
                  text: 'Agregar Producto',
                  icon: Icons.add_circle_outline,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductFormScreen(),
                      ),
                    );
                  },
                  height: 50,
                ),
                // Botón Ver Inventario
                PrimaryButton(
                  text: 'Ver Inventario',
                  icon: Icons.inventory,
                  onPressed: () {
                    // Navegar a la pantalla de inventario
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
        ),
      ),
    );
  }
}

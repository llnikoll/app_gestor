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
  final currencyFormat = NumberFormat.currency(
    symbol: 'Gs. ',
    decimalDigits: 0,
    locale: 'es_PY',
  );
  final numberFormat = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _productNotifier ??= Provider.of<ProductNotifierService>(
      context,
      listen: false,
    );
    _productNotifier!.notifier.addListener(_onProductUpdate);
    _loadDashboardData();
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
    setState(() {
      _dashboardData = _getDashboardData();
    });
  }

  Future<Map<String, dynamic>> _getDashboardData() async {
    try {
      final db = DatabaseService();
      final products = await db.getProductos();
      final totalProducts = products.length;
      final lowStockProducts = products.where((p) => p.stock < 10).length;
      final outOfStockProducts = products.where((p) => p.stock <= 0).length;
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel de Control',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 24.0,
              ),
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
                          Text(
                            'Error al cargar los datos',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loadDashboardData,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Reintentar',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen General',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: _getCrossAxisCount(context),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: _getChildAspectRatio(context),
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
                      const SizedBox(height: 32),
                      Text(
                        'Acciones Rápidas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: _getCrossAxisCount(context),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: _getActionButtonAspectRatio(context),
                        children: [
                          PrimaryButton(
                            text: 'Nueva Venta',
                            icon: Icons.point_of_sale,
                            onPressed: () {
                              HomeScreen.of(context)?.onItemTapped(1);
                            },
                            height: 60,
                          ),
                          PrimaryButton(
                            text: 'Agregar Producto',
                            icon: Icons.add_circle_outline,
                            onPressed: () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(20.0),
                                      constraints: BoxConstraints(
                                        maxWidth: 500,
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                            0.8,
                                      ),
                                      child: const SingleChildScrollView(
                                        child: ProductFormScreen(),
                                      ),
                                    ),
                                  );
                                },
                              );
                              if (result == true) {
                                _loadDashboardData();
                              }
                            },
                            height: 60,
                          ),
                          PrimaryButton(
                            text: 'Ver Inventario',
                            icon: Icons.inventory,
                            onPressed: () {
                              HomeScreen.of(context)?.onItemTapped(2);
                            },
                            height: 60,
                          ),
                          PrimaryButton(
                            text: 'Generar Reporte',
                            icon: Icons.bar_chart,
                            onPressed: () {},
                            height: 60,
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

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 500) return 2;
    return 1;
  }

  double _getChildAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 1.6;
    if (width > 800) return 1.8;
    if (width > 500) return 2.0;
    return 2.2;
  }

  double _getActionButtonAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 3.5;
    if (width > 800) return 3.0;
    if (width > 500) return 2.8;
    return 2.5;
  }
}

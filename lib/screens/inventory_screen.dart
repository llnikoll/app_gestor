import 'package:flutter/material.dart';
import 'inventory_entries_screen.dart';
import 'product_form_screen.dart';
import '../models/producto_model.dart';
import '../services/database_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  InventoryScreenState createState() => InventoryScreenState();
}

class InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  List<Producto> _productos = [];
  bool _isLoading = true;

  Future<void> _loadProducts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final db = DatabaseService();
      final productos = await db.getProductos();

      if (mounted) {
        setState(() {
          _productos = productos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar productos: $e')),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadProducts();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Productos'),
            Tab(icon: Icon(Icons.assignment), text: 'Entradas'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _loadProducts,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _productos.isEmpty
                  ? const Center(child: Text('No hay productos'))
                  : ListView.builder(
                      itemCount: _productos.length,
                      itemBuilder: (context, index) {
                        final producto = _productos[index];
                        return ListTile(
                          title: Text(producto.nombre),
                          subtitle: Text('Stock: ${producto.stock}'),
                          trailing: Text(
                            '\$${producto.precioVenta.toStringAsFixed(2)}',
                          ),
                          onTap: () async {
                            // Navegar a la pantalla de edición de producto
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProductFormScreen(product: producto),
                              ),
                            );
                            
                            // Si se editó el producto exitosamente, actualizar la lista
                            if (result == true && mounted) {
                              _loadProducts();
                            }
                          },
                        );
                      },
                    ),
            ),
            const InventoryEntriesScreen(),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                // Navegar a la pantalla de agregar producto y esperar el resultado
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductFormScreen(),
                  ),
                );

                // Si se agregó un producto exitosamente, actualizar la lista
                if (result == true && mounted) {
                  _loadProducts();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

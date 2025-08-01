import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/product_image_viewer.dart';
import 'inventory_entries_screen.dart';
import 'product_form_screen.dart';
import '../models/producto_model.dart';
import '../services/database_service.dart';
import '../services/product_notifier_service.dart';
import '../utils/currency_formatter.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  InventoryScreenState createState() => InventoryScreenState();
}

class InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  ProductNotifierService? _productNotifier;
  late TabController _tabController;
  int _currentIndex = 0;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  List<Producto> _productos = [];
  List<Producto> _filteredProducts = [];
  bool _isLoading = true;
  String _selectedCategory = 'Todas las categorías';
  List<String> _categories = ['Todas las categorías'];
  final TextEditingController _searchController = TextEditingController();

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
          _filteredProducts = List.from(productos);
          _isLoading = false;
        });

        // Recargar las categorías después de cargar los productos
        _loadCategories();
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Obtener el notificador de productos solo una vez
    _productNotifier ??=
        Provider.of<ProductNotifierService>(context, listen: false);

    // Escuchar cambios en el notificador
    _productNotifier!.notifier.addListener(_onProductUpdate);

    // Cargar productos iniciales
    _loadProducts();
  }

  @override
  void dispose() {
    // Limpiar el listener cuando el widget se destruya
    _productNotifier?.notifier.removeListener(_onProductUpdate);
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Método que se ejecuta cuando hay una actualización de productos
  void _onProductUpdate() {
    if (mounted) {
      _loadProducts();
    }
  }

  // Método para cargar las categorías
  Future<void> _loadCategories() async {
    try {
      final db = DatabaseService();
      final productos = await db.getProductos();

      final categorias = productos
          .map((p) => p.categoria)
          .where((c) => c.isNotEmpty && c.toLowerCase() != 'general')
          .toSet()
          .toList();

      categorias.sort();

      if (!mounted) return;
      setState(() {
        _categories = ['Todas las categorías'];
        _categories.addAll(categorias);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar categorías: $e')),
      );
    }
  }

  void _applyFilter(String category) {
    if (!mounted) return;
    setState(() {
      _selectedCategory = category;
      if (category == 'Todas las categorías' || category.toLowerCase() == 'generales') {
        _filteredProducts = List.from(_productos);
      } else {
        _filteredProducts = _productos
            .where((producto) => producto.categoria == category)
            .toList();
      }
    });
  }

  // Widget para construir el selector de categorías
  Widget _buildCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Categoría',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide:
                BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!.withValues(alpha: 0.7)
              : Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        items: _categories.map((String category) {
          return DropdownMenuItem<String>(
            value: category,
            child: Text(category),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            _applyFilter(newValue);
          }
        },
      ),
    );
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentIndex = _tabController.index;
      });
    }
  }

  // Widget para mostrar información en un chip
  Widget _buildInfoChip(String text, Color color, {double fontSize = 12.0}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CurrencyFormatter ya está configurado globalmente

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
            // Pestaña de Productos
            Column(
              children: [
                // Selector de categorías
                _buildCategoryFilter(),
                // Lista de productos con RefreshIndicator
                Expanded(
                  child: RefreshIndicator(
                    key: _refreshIndicatorKey,
                    onRefresh: _loadProducts,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredProducts.isEmpty
                            ? const Center(
                                child: Text('No hay productos disponibles'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final producto = _filteredProducts[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                      horizontal: 8.0,
                                    ),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                      leading: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 60,
                                          maxHeight: 60,
                                        ),
                                        child: ProductImageViewer(
                                          imageUrl: producto.imagenUrl,
                                          width: 60,
                                          height: 60,
                                          borderRadius: 8.0,
                                        ),
                                      ),
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            producto.nombre,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (producto.descripcion.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 2.0),
                                              child: RichText(
                                                text: TextSpan(
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color,
                                                  ),
                                                  children: [
                                                    const TextSpan(
                                                      text: 'Descripción: ',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500),
                                                    ),
                                                    TextSpan(
                                                      text:
                                                          producto.descripcion,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .normal),
                                                    ),
                                                  ],
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 6),
                                          Text(
                                            'Precio: ${context.formattedCurrency(producto.precioVenta)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          if (producto.categoria.isNotEmpty)
                                            Text(
                                                'Categoría: ${producto.categoria}'),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              _buildInfoChip(
                                                'Stock: ${producto.stock}',
                                                producto.stock > 0
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontSize: 12,
                                              ),
                                              if (producto
                                                  .codigoBarras.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 8.0),
                                                  child: _buildInfoChip(
                                                    'Código: ${producto.codigoBarras}',
                                                    Colors.blueGrey,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      onTap: () async {
                                        final result = await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return Dialog(
                                              child: SizedBox(
                                                width: 600,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.9,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          SingleChildScrollView(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(16.0),
                                                        child: IntrinsicWidth(
                                                          child:
                                                              ProductFormScreen(
                                                            product: producto,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );

                                        if (result == true) {
                                          _loadProducts();
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
            // Pestaña de Entradas
            const InventoryEntriesScreen(),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'inventory_fab',
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return Dialog(
                      child: SizedBox(
                        width: 600,
                        height: MediaQuery.of(context).size.height * 0.9,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(16.0),
                                child: IntrinsicWidth(
                                  child: ProductFormScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
                if (result == true) {
                  _loadProducts();
                }
              },
              label: const Text('Nuevo Producto'),
              icon: const Icon(Icons.add),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            )
          : null,
    );
  }
}

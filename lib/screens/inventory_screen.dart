import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/product_image_viewer.dart';
import 'inventory_entries_screen.dart';
import 'product_form_screen.dart';
import '../models/producto_model.dart';
import '../models/categoria_model.dart';
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
      if (category == 'Todas las categorías' ||
          category.toLowerCase() == 'generales') {
        _filteredProducts = List.from(_productos);
      } else {
        _filteredProducts = _productos
            .where((producto) => producto.categoria == category)
            .toList();
      }
    });
  }

  // Widget para construir el selector de categorías
  Future<void> _editCategory(String currentCategory) async {
    if (!mounted) return;

    final controller = TextEditingController(text: currentCategory);
    final db = DatabaseService();
    final categorias = await db.getCategorias();
    if (!mounted) return;

    final categoria = categorias.firstWhere((c) => c.nombre == currentCategory);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Categoría'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ingrese el nuevo nombre',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != currentCategory) {
      try {
        final updatedCategoria = Categoria(
          id: categoria.id,
          nombre: result,
          fechaCreacion: categoria.fechaCreacion,
        );
        await db.updateCategoria(updatedCategoria);
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Categoría actualizada con éxito')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar la categoría: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(String categoryName) async {
    if (!mounted) return;

    final db = DatabaseService();
    final categorias = await db.getCategorias();
    if (!mounted) return;

    final categoria = categorias.firstWhere((c) => c.nombre == categoryName);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text(
          '¿Está seguro que desea eliminar la categoría "$categoryName"?\n\n'
          'Nota: No se puede eliminar una categoría que tenga productos asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await db.deleteCategoria(categoria.id!);
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Categoría eliminada con éxito')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

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
          if (category == 'Todas las categorías') {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(category),
            );
          }
          return DropdownMenuItem<String>(
            value: category,
            child: Row(
              children: [
                Expanded(child: Text(category)),
                if (category != 'Todas las categorías') ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      // Cerrar el dropdown
                      Navigator.of(context).pop();
                      // Editar categoría
                      _editCategory(category);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () {
                      // Cerrar el dropdown
                      Navigator.of(context).pop();
                      // Eliminar categoría
                      _deleteCategory(category);
                    },
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            _applyFilter(newValue);
          }
        },
        selectedItemBuilder: (BuildContext context) {
          return _categories.map<Widget>((String category) {
            return Container(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              child: Text(
                category,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList();
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
        border: Border.all(color: color.withOpacity(0.3), width: 1.0),
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

  void _showProductDetails(BuildContext context, Producto producto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(producto.nombre),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (producto.imagenUrl?.isNotEmpty == true)
                Center(
                  child: ProductImageViewer(
                    imageUrl: producto.imagenUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 16),
              if (producto.descripcion.isNotEmpty) ...[
                const Text(
                  'Descripción:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  producto.descripcion,
                  style: const TextStyle(fontSize: 15),
                ),
                const Divider(height: 24),
              ],
              _buildDetailRow(
                  'Precio', context.formattedCurrency(producto.precioVenta)),
              const SizedBox(height: 8),
              if (producto.categoria.isNotEmpty)
                _buildDetailRow('Categoría', producto.categoria),
              if (producto.codigoBarras.isNotEmpty)
                _buildDetailRow('Código', producto.codigoBarras),
              _buildDetailRow('Stock', '${producto.stock} unidades',
                  color: producto.stock > 0 ? Colors.green : Colors.red),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[800],
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
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
                                    child: InkWell(
                                      onTap: () async {
                                        final result =
                                            await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ProductFormScreen(
                                              product: producto,
                                            ),
                                            fullscreenDialog: true,
                                          ),
                                        );

                                        if (result == true) {
                                          _loadProducts();
                                        }
                                      },
                                      onLongPress: () => _showProductDetails(
                                          context, producto),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                        leading: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 50,
                                            maxHeight: 50,
                                          ),
                                          child: ProductImageViewer(
                                            imageUrl: producto.imagenUrl,
                                            width: 50,
                                            height: 50,
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
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              context.formattedCurrency(
                                                  producto.precioVenta),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: _buildInfoChip(
                                          '${producto.stock} u.',
                                          producto.stock > 0
                                              ? Colors.green
                                              : Colors.red,
                                          fontSize: 11,
                                        ),
                                      ),
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

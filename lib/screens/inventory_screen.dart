import 'package:flutter/material.dart';
import '../models/producto_model.dart';
import '../services/database_service.dart';
import '../widgets/primary_button.dart';
import 'package:intl/intl.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  InventoryScreenState createState() => InventoryScreenState();
}

class InventoryScreenState extends State<InventoryScreen> {
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Todas';
  List<String> _categories = ['Todas'];
  bool _isLoading = true;
  List<Producto> _products = [];
  List<Producto> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = DatabaseService();
      final products = await db.getProductos();
      
      // Obtener categorías únicas
      final categories = await db.getCategorias();
      
      setState(() {
        _products = products;
        _filteredProducts = List.from(products);
        _categories = ['Todas', ...categories.map((cat) => cat.nombre)];
        _isLoading = false;
      });
      
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el inventario: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _products.where((product) {
        // Filtrar por búsqueda
        final matchesSearch = _searchQuery.isEmpty ||
            product.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.codigoBarras.toLowerCase().contains(_searchQuery.toLowerCase());
        
        // Filtrar por categoría
        final matchesCategory = _selectedCategory == 'Todas' || 
            product.categoria == _selectedCategory;
            
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Widget _buildProductCard(Producto product) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: product.imagenUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imagenUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.inventory_2, color: Colors.grey),
                  ),
                )
              : const Icon(Icons.inventory_2, color: Colors.grey),
        ),
        title: Text(
          product.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Código: ${product.codigoBarras}'),
            Text('Categoría: ${product.categoria}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStockColor(product.stock).withAlpha(51), // 0.2 * 255 ≈ 51
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Stock: ${product.stock}',
                    style: TextStyle(
                      color: _getStockColor(product.stock),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  currencyFormat.format(product.precioVenta),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // Ver detalles del producto
        },
      ),
    );
  }

  Color _getStockColor(int stock) {
    if (stock <= 0) {
      return Colors.red;
    } else if (stock < 10) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventario',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Barra de búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar productos...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.barcode_reader, color: Colors.white70),
                      onPressed: () {
                        // Escanear código de barras
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(51), // 255 * 0.2 ≈ 51
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', _selectedCategory == 'Todas', () {
                        setState(() {
                          _selectedCategory = 'Todas';
                          _applyFilters();
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Bajo Stock', _selectedCategory == 'Bajo Stock', () {
                        setState(() {
                          _selectedCategory = 'Bajo Stock';
                          _filteredProducts = _products.where((p) => p.stock < 10 && p.stock > 0).toList();
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Agotados', _selectedCategory == 'Agotados', () {
                        setState(() {
                          _selectedCategory = 'Agotados';
                          _filteredProducts = _products.where((p) => p.stock <= 0).toList();
                        });
                      }),
                      ..._categories.where((cat) => cat != 'Todas').map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: _buildFilterChip(category, _selectedCategory == category, () {
                            setState(() {
                              _selectedCategory = category;
                              _applyFilters();
                            });
                          }),
                        );
                      })
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contenido
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No se encontraron productos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedCategory != 'Todas' || _searchQuery.isNotEmpty
                                  ? 'Intenta con otros filtros o términos de búsqueda'
                                  : 'Aún no hay productos en el inventario',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              text: 'Agregar Producto',
                              icon: Icons.add,
                              onPressed: () {
                                // Navegar a la pantalla de agregar producto
                              },
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            return _buildProductCard(_filteredProducts[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navegar a la pantalla de agregar producto
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar Producto'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Theme.of(context).primaryColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: isSelected 
          ? Theme.of(context).primaryColor 
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[300]!,
        ),
      ),
      onPressed: onTap,
    );
  }
}

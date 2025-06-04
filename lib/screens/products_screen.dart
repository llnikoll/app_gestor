import 'dart:io';

import 'package:flutter/material.dart';
import '../models/producto_model.dart';
import '../services/database_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/search_bar.dart' as custom;
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  ProductsScreenState createState() => ProductsScreenState();
}

class ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Producto>> _productsFuture;
  String _searchQuery = '';
  String _selectedCategory = 'Todas';
  List<String> _categories = ['Todas'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
      _loadCategories();
    });
  }

  // Verifica si un archivo existe en la ruta especificada
  Future<bool> _checkIfFileExists(String filePath) async {
    if (filePath.isEmpty) return false;
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final db = DatabaseService();
      List<Producto> products = await db.getProductos();
      
      // Filtrar por búsqueda si hay un término de búsqueda
      if (_searchQuery.isNotEmpty) {
        products = products.where((product) {
          return product.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              product.codigoBarras.contains(_searchQuery);
        }).toList();
      }
      
      // Filtrar por categoría si no es 'Todas'
      if (_selectedCategory != 'Todas') {
        products = products.where((product) => product.categoria == _selectedCategory).toList();
      }

      if (!mounted) return;
      setState(() {
        _productsFuture = Future.value(products);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _loadCategories() async {
    if (!mounted) return;
    
    try {
      final db = DatabaseService();
      final categories = await db.getCategorias();
      
      if (!mounted) return;
      setState(() {
        _categories = ['Todas', ...categories.map((cat) => cat.nombre)];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar categorías: $e')),
        );
      }
    }
  }

  Future<void> _deleteProduct(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text('¿Estás seguro de que deseas eliminar este producto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = DatabaseService();
        await db.deleteProducto(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto eliminado correctamente')),
          );
          _loadProducts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el producto: $e')),
          );
        }
      }
    }
  }

  Widget _buildProductCard(Producto product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductFormScreen(product: product),
            ),
          ).then((_) => _loadProducts());
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Imagen del producto
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: product.imagenUrl != null && product.imagenUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<bool>(
                          future: _checkIfFileExists(product.imagenUrl!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final fileExists = snapshot.data ?? false;
                            
                            if (!fileExists) {
                              return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
                            }
                            
                            return Image.file(
                              File(product.imagenUrl!),
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
                              },
                            );
                          },
                        ),
                      )
                    : const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              // Información del producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${product.codigoBarras}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Categoría: ${product.categoria}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '\$${product.precioVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Stock: ${product.stock}',
                          style: TextStyle(
                            color: product.stock <= 0
                                ? Colors.red
                                : product.stock < 10
                                    ? Colors.orange
                                    : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de búsqueda y filtros
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Barra de búsqueda
              custom.SearchBar(
                controller: _searchController,
                hintText: 'Buscar productos...',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _loadProducts();
                },
                onBarcodeScanned: () {
                  // Implementar escaneo de código de barras
                },
              ),
              const SizedBox(height: 12),
              // Filtros
              Row(
                children: [
                  // Filtro por categoría
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                          _loadProducts();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botón para agregar producto
                  SizedBox(
                    width: 150, // Ancho fijo para el botón
                    child: PrimaryButton(
                      text: 'Agregar',
                      icon: Icons.add,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProductFormScreen(),
                          ),
                        ).then((_) => _loadProducts());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Lista de productos
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<Producto>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('No se encontraron productos'),
                      );
                    } else {
                      final products = snapshot.data!;
                      return RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return Dismissible(
                              key: Key(product.id.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                color: Colors.red,
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                await _deleteProduct(product.id!);
                                return false; // No eliminar el widget aquí, ya que se actualiza la lista
                              },
                              child: _buildProductCard(product),
                            );
                          },
                        ),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }
}

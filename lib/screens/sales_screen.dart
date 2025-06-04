import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/producto_model.dart';
import '../models/venta_model.dart';
import '../services/database_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  SalesScreenState createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  // Controladores
  final _searchController = TextEditingController();
  final _clienteController = TextEditingController();
  late TabController _tabController;

  // Datos
  final List<Producto> _productos = [];
  final List<Producto> _filteredProducts = [];
  final List<Venta> _ventas = [];
  final List<Map<String, dynamic>> _cartItems = [];

  // Estado
  bool _isLoading = true;
  String _metodoPago = 'Efectivo';

  // Instancia de la base de datos
  late final DatabaseService _databaseService;

  // Formato de moneda
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _databaseService = DatabaseService();
    _loadData();

    // Escuchar cambios en el campo de búsqueda
    _searchController.addListener(() {
      _filterProducts(_searchController.text);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _clienteController.dispose();
    super.dispose();
  }

  // Cargar datos iniciales
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final productos = await _databaseService.getProductos();
      final ventas = await _databaseService.getVentas();
      
      // Cargar detalles de cada venta
      for (var venta in ventas) {
        final detalles = await _databaseService.getVentaDetalles(venta.id!);
        venta.limpiarItems();
        for (var detalle in detalles) {
          venta.agregarItem(detalle);
        }
      }
      
      if (mounted) {
        setState(() {
          _productos.clear();
          _productos.addAll(productos);
          _ventas.clear();
          _ventas.addAll(ventas);
          _filteredProducts.clear();
          _filteredProducts.addAll(productos);
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Filtrar productos por búsqueda
  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts.clear();
        _filteredProducts.addAll(_productos);
      });
      return;
    }

    final queryLower = query.toLowerCase();
    setState(() {
      _filteredProducts.clear();
      _filteredProducts.addAll(
        _productos.where((producto) {
          final barcodeLower = producto.codigoBarras.toLowerCase();
          return producto.nombre.toLowerCase().contains(queryLower) ||
                barcodeLower.contains(queryLower);
        }),
      );
    });
  }

  // Agregar producto al carrito
  void _addToCart(Producto producto) {
    if (producto.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay suficiente stock disponible')),
      );
      return;
    }

    final index = _cartItems.indexWhere((item) => item['id'] == producto.id);

    setState(() {
      if (index >= 0) {
        // Si ya está en el carrito, aumentar cantidad si hay stock
        if (producto.stock > _cartItems[index]['cantidad']) {
          _cartItems[index]['cantidad']++;
          _cartItems[index]['subtotal'] =
              _cartItems[index]['cantidad'] *
              _cartItems[index]['precioUnitario'];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay suficiente stock disponible')),
          );
        }
      } else {
        // Si no está en el carrito, agregarlo
        _cartItems.add({
          'id': producto.id,
          'nombre': producto.nombre,
          'precioUnitario': producto.precioVenta,
          'cantidad': 1,
          'subtotal': producto.precioVenta,
          'producto': producto,
        });
      }
    });
  }

  // Actualizar cantidad de un producto en el carrito
  void _updateQuantity(int index, int change) {
    if (index < 0 || index >= _cartItems.length) return;

    final producto = _cartItems[index]['producto'] as Producto;
    final newQuantity = _cartItems[index]['cantidad'] + change;

    if (newQuantity <= 0) {
      setState(() => _cartItems.removeAt(index));
      return;
    }

    if (newQuantity > producto.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay suficiente stock disponible')),
      );
      return;
    }

    setState(() {
      _cartItems[index]['cantidad'] = newQuantity;
      _cartItems[index]['subtotal'] =
          newQuantity * _cartItems[index]['precioUnitario'];
    });
  }

  // Limpiar el carrito
  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _clienteController.clear();
      _metodoPago = 'Efectivo';
    });

    // Cerrar teclado si está abierto
    FocusScope.of(context).unfocus();
  }

  // Calcular el total del carrito
  double get _totalCarrito {
    return _cartItems.fold(
      0,
      (total, item) => total + (item['subtotal'] as double),
    );
  }

  // Procesar la venta
  Future<void> _procesarVenta() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El carrito está vacío')));
      return;
    }

    final cliente = _clienteController.text.trim();
    if (cliente.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingrese el nombre del cliente'),
        ),
      );
      return;
    }

    try {
      final venta = Venta(
        cliente: cliente,
        total: _totalCarrito,
        metodoPago: _metodoPago,
        items: List<Map<String, dynamic>>.from(
          _cartItems.map(
            (item) => ({
              'productoId': item['id'],
              'cantidad': item['cantidad'],
              'precioUnitario': item['precioUnitario'],
              'subtotal': item['subtotal'],
            }),
          ),
        ),
      );

      final ventaId = await _databaseService.insertVenta(venta);

      if (ventaId > 0 && mounted) {
        // Check mounted before using context
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Venta registrada exitosamente')),
          );
        }
        _clearCart();
        await _loadData(); // Recargar datos para actualizar el historial
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la venta: $e')),
        );
      }
    }
  }

  // Placeholder for _getStatusColor
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Construir un ítem de venta para el historial
  Widget _buildSaleItem(Map<String, dynamic> sale) {
    // Assuming the map contains keys like 'id', 'cliente', 'items', 'metodoPago', 'fecha', 'total', 'status'
    final int id = sale['id'] ?? 0;
    final String cliente = sale['cliente'] ?? 'No especificado';
    final List<dynamic> items = sale['items'] ?? [];
    final String metodoPago = sale['metodoPago'] ?? 'Desconocido';
    final String fecha =
        sale['fecha'] ??
        'Fecha desconocida'; // Assuming date is stored as String
    final double total = (sale['total'] as num?)?.toDouble() ?? 0.0;
    final String status =
        sale['status'] ?? 'Desconocido'; // Assuming status is stored

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_long, color: Colors.blue, size: 30),
        ),
        title: Text(
          'Venta #$id',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Cliente: $cliente'),
            Text('${items.length} productos • $metodoPago'),
            Text(
              fecha,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(total),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withAlpha(51), // 0.2 * 255 ≈ 51
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          // Ver detalles de la venta
          // You might want to navigate to a detail screen or show a dialog
        },
      ),
    );
  }

  // Construir un ítem del carrito
  Widget _buildCartItem(Map<String, dynamic> item) {
    // Using the correct keys from _addToCart
    final int id = item['id'];
    final String nombre = item['nombre'];
    final double precioUnitario = item['precioUnitario'];
    final int cantidad = item['cantidad'];
    final double subtotal = item['subtotal'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8.0,
          vertical: 4.0,
        ),
        minLeadingWidth: 36,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.inventory_2, color: Colors.grey, size: 20),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${currencyFormat.format(precioUnitario)} c/u',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 90),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () {
                      // Disminuir cantidad
                      final index = _cartItems.indexWhere(
                        (cartItem) => cartItem['id'] == id,
                      );
                      if (index != -1) {
                        _updateQuantity(index, -1);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$cantidad',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () {
                      // Aumentar cantidad
                      final index = _cartItems.indexWhere(
                        (cartItem) => cartItem['id'] == id,
                      );
                      if (index != -1) {
                        _updateQuantity(index, 1);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Text(
                currencyFormat.format(subtotal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.point_of_sale), text: 'Nueva Venta'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña de Nueva Venta
          Column(
            children: [
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onChanged: (value) {
                    _filterProducts(value);
                  },
                ),
              ),
              // Lista de productos
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                    ? const Center(child: Text('No hay productos disponibles'))
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final producto = _filteredProducts[index];
                          return ListTile(
                            title: Text(producto.nombre),
                            subtitle: Text(
                              'Stock: ${producto.stock} | \$${producto.precioVenta.toStringAsFixed(2)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.green,
                              ),
                              onPressed: () {
                                _addToCart(producto);
                              },
                            ),
                          );
                        },
                      ),
              ),
              // Resumen del carrito
              _buildResumenCarrito(),
            ],
          ),
          // Pestaña de Historial
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _ventas.isEmpty
              ? const Center(child: Text('No hay ventas registradas'))
              : ListView.builder(
                  itemCount: _ventas.length,
                  itemBuilder: (context, index) {
                    final venta = _ventas[index];
                    // Pass the Venta object directly or convert it to a Map if _buildSaleItem expects a Map
                    // Based on the original code structure, it seems _buildSaleItem was intended to handle a Map
                    return _buildSaleItem(venta.toMap());
                  },
                ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _tabController.animateTo(0);
                });
              },
              tooltip: 'Nueva Venta',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // Construir el resumen del carrito
  Widget _buildResumenCarrito() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      constraints: const BoxConstraints(
        minWidth: double.infinity,
      ),
      child: _cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'El carrito está vacío',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lista de productos en el carrito
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return _buildCartItem(item);
                    },
                  ),
                ),
                const Divider(height: 1),
                // Total y botón de pago
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${_cartItems.fold(0.0, (sum, item) => sum + (item['subtotal'] as num)).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cartItems.isEmpty ? null : _procesarVenta,
                      child: const Text('Procesar Venta'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

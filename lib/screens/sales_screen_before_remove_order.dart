import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import '../models/producto_model.dart';
import '../models/venta_model.dart';
import '../models/cliente_model.dart';
import '../models/carrito_item_model.dart';
import '../services/database_service.dart';
import '../widgets/primary_button.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  SalesScreenState createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController(
    text: '1',
  );

  // Variables para la pestaña de nueva venta
  final List<CarritoItem> _carrito = [];
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  Cliente? _clienteSeleccionado;
  String _metodoPagoSeleccionado = 'Efectivo';
  
  // Filtros de productos
  final TextEditingController _filtroBusquedaController = TextEditingController();
  String _filtroCategoria = 'Todas';
  String _filtroOrden = 'Nombre (A-Z)';
  final double _filtroPrecioMin = 0;
  final double _filtroPrecioMax = 1000000;
  
  // Controladores para los filtros
  void _actualizarFiltroCategoria(String? value) => _actualizarFiltro(
        value,
        (v) => _filtroCategoria = v,
      );

  void _actualizarFiltroOrden(String? value) => _actualizarFiltro(
        value,
        (v) => _filtroOrden = v,
      );

  void _actualizarFiltro<T>(
    T? value,
    void Function(T) actualizarFiltro,
  ) {
    if (value != null) {
      setState(() => actualizarFiltro(value));
      _aplicarFiltros();
    }
  }
  final List<String> _metodosPago = [
    'Efectivo',
    'Tarjeta de Crédito',
    'Tarjeta de Débito',
    'Transferencia',
  ];
  final TextEditingController _montoRecibidoController =
      TextEditingController();
  double _montoRecibido = 0.0;
  bool _isLoading = false;
  bool _isLoadingVentas = false;
  List<Venta> _ventas = [];
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarProductos();
    _cargarVentas();
  }

  @override
  void dispose() {
    _montoRecibidoController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _cantidadController.dispose();
    _filtroBusquedaController.dispose();
    super.dispose();
  }

  // ========== MÉTODOS DE CARGA DE DATOS ==========

  Future<void> _cargarProductos() async {
    try {
      setState(() => _isLoading = true);
      _productos = await _databaseService.getProductos();
      _aplicarFiltros();
    } catch (e) {
      _mostrarError('Error al cargar productos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cargarVentas() async {
    if (!mounted) return;

    try {
      setState(() => _isLoadingVentas = true);

      final ventas = await _databaseService.getVentasPorRangoFechas(
        _fechaInicio,
        _fechaFin.add(const Duration(days: 1)), // Incluir el día completo
      );

      if (mounted) {
        setState(() {
          _ventas = ventas;
          _ventas.sort(
            (a, b) => b.fecha.compareTo(a.fecha),
          ); // Ordenar por fecha más reciente
        });
      }
    } catch (e) {
      debugPrint('Error al cargar ventas: $e');
      if (mounted) {
        _mostrarError('Error al cargar el historial de ventas');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingVentas = false);
      }
    }
  }

  // ========== MÉTODOS DEL CARRITO ==========

  void _agregarProductoAlCarrito(Producto producto, int cantidad) {
    setState(() {
      final index = _carrito.indexWhere(
        (item) => item.producto.id == producto.id,
      );

      if (index >= 0) {
        _carrito[index].cantidad += cantidad;
      } else {
        _carrito.add(CarritoItem(producto: producto, cantidad: cantidad));
      }
    });

    Navigator.of(context).pop();
    _cantidadController.text = '1';
  }

  void _eliminarProductoDelCarrito(int index) {
    setState(() {
      _carrito.removeAt(index);
    });
  }

  void _actualizarCantidadProducto(int index, int nuevaCantidad) {
    if (nuevaCantidad > 0) {
      setState(() {
        _carrito[index].cantidad = nuevaCantidad;
      });
    } else {
      _eliminarProductoDelCarrito(index);
    }
  }

  double _calcularTotal() {
    return _carrito.fold(0, (total, item) => total + item.subtotal);
  }

  // ========== MÉTODOS DE BÚSQUEDA Y FILTRADO ==========


  // Método para aplicar todos los filtros
  void _aplicarFiltros() {
    setState(() {
      // Aplicar filtro de búsqueda
      String busqueda = _filtroBusquedaController.text.toLowerCase();
      
      _productosFiltrados = _productos.where((producto) {
        // Filtro por búsqueda en nombre o código de barras
        bool coincideBusqueda = busqueda.isEmpty ||
            producto.nombre.toLowerCase().contains(busqueda) ||
            producto.codigoBarras.toLowerCase().contains(busqueda);
        
        // Filtro por categoría
        bool coincideCategoria = _filtroCategoria == 'Todas' || 
            producto.categoria.toLowerCase() == _filtroCategoria;
        
        // Filtro por rango de precios
        bool enRangoPrecio = producto.precioVenta >= _filtroPrecioMin &&
            producto.precioVenta <= _filtroPrecioMax;
        
        return coincideBusqueda && coincideCategoria && enRangoPrecio;
      }).toList();

      // Aplicar ordenamiento
      _aplicarOrden();
    });
  }

  // Método para aplicar el ordenamiento
  void _aplicarOrden() {
    switch (_filtroOrden) {
      case 'Nombre (A-Z)':
        _productosFiltrados.sort((a, b) => a.nombre.compareTo(b.nombre));
        break;
      case 'Nombre (Z-A)':
        _productosFiltrados.sort((a, b) => b.nombre.compareTo(a.nombre));
        break;
      case 'Precio (menor a mayor)':
        _productosFiltrados.sort((a, b) => a.precioVenta.compareTo(b.precioVenta));
        break;
      case 'Precio (mayor a menor)':
        _productosFiltrados.sort((a, b) => b.precioVenta.compareTo(a.precioVenta));
        break;
      case 'Stock (mayor a menor)':
        _productosFiltrados.sort((a, b) => b.stock.compareTo(a.stock));
        break;
    }
  }

  // Método para manejar cambios en la búsqueda
  void _filtrarProductos(String query) {
    _aplicarFiltros();
  }

  // ========== MÉTODOS DE PROCESO DE VENTA ==========

  // Calcular el vuelto
  double get _calcularVuelto {
    if (_metodoPagoSeleccionado != 'Efectivo' || _montoRecibido <= 0) {
      return 0.0;
    }
    final total = _calcularTotal();
    return _montoRecibido - total;
  }

  // Formatear moneda
  String _formatoMoneda(double valor) {
    return NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
      locale: 'es_CL',
    ).format(valor);
  }

  // Mostrar diálogo de pago
  Future<void> _mostrarDialogoPago() async {
    final total = _calcularTotal();
    _montoRecibidoController.text = total.toStringAsFixed(0);

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Pago en Efectivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total a Pagar: ${_formatoMoneda(total)}'),
              const SizedBox(height: 16),
              TextField(
                controller: _montoRecibidoController,
                decoration: const InputDecoration(
                  labelText: 'Monto Recibido',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _montoRecibido = double.tryParse(value) ?? 0.0;
                  });
                },
              ),
              if (_montoRecibido > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Vuelto: ${_formatoMoneda(_calcularVuelto)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _montoRecibido >= total
                  ? () {
                      Navigator.pop(context);
                      _procesarVentaConMetodoPago();
                    }
                  : null,
              child: const Text('Confirmar Pago'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarVenta() async {
    if (_carrito.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El carrito está vacío')));
      return;
    }

    if (_metodoPagoSeleccionado.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un método de pago')),
      );
      return;
    }

    // Mostrar diálogo de pago para pagos en efectivo
    if (_metodoPagoSeleccionado == 'Efectivo') {
      await _mostrarDialogoPago();
      return;
    }

    // Para otros métodos de pago, procesar directamente
    await _procesarVentaConMetodoPago();
  }

  Future<void> _procesarVentaConMetodoPago() async {
    if (_carrito.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El carrito está vacío')));
      return;
    }

    final total = _calcularTotal();

    // Crear la venta
    final venta = Venta(
      clienteId: _clienteSeleccionado?.id,
      clienteNombre: _clienteSeleccionado?.nombre ?? 'Cliente ocasional',
      total: total,
      metodoPago: _metodoPagoSeleccionado,
      items: _carrito
          .map(
            (item) => {
              'producto_id': item.producto.id,
              'nombre_producto': item.producto.nombre,
              'cantidad': item.cantidad,
              'precio_unitario': item.producto.precioVenta,
              'subtotal': item.subtotal,
            },
          )
          .toList(),
    );

    setState(() {
      _isLoading = true;
    });

    try {
      // Procesar la venta
      await DatabaseService().insertVenta(venta);

      // Recargar datos
      await Future.wait([_cargarProductos(), _cargarVentas()]);

      if (!mounted) return;

      // Limpiar el carrito
      setState(() {
        _carrito.clear();
        _clienteSeleccionado = null;
        _metodoPagoSeleccionado = 'Efectivo'; // Resetear al valor por defecto
      });

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Venta registrada exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Cambiar a la pestaña de historial
      _tabController.animateTo(1);
    } catch (e) {
      debugPrint('Error al procesar venta: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al registrar la venta: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _seleccionarCliente() async {
    // Schedule the client selection for the next frame
    await SchedulerBinding.instance.endOfFrame;

    if (!mounted) return;

    final clientes = await DatabaseService().getAllClientes();

    if (!mounted) return;

    if (clientes.isEmpty) {
      if (ScaffoldMessenger.maybeOf(context) == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes registrados')),
      );
      return;
    }

    final clienteSeleccionado = await showDialog<Cliente>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Cliente'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: clientes.length,
            itemBuilder: (context, index) {
              final cliente = clientes[index];
              return ListTile(
                title: Text(cliente.nombre),
                subtitle: Text(cliente.telefono ?? ''),
                onTap: () => Navigator.pop(context, cliente),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (clienteSeleccionado != null) {
      setState(() {
        _clienteSeleccionado = clienteSeleccionado;
      });
    }
  }

  Future<void> _seleccionarMetodoPago() async {
    // Schedule the method selection for the next frame
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return;

    final metodo = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: _metodosPago.length,
        itemBuilder: (context, index) {
          final metodo = _metodosPago[index];
          return ListTile(
            title: Text(metodo),
            onTap: () => Navigator.pop(context, metodo),
          );
        },
      ),
    );

    if (metodo != null && mounted) {
      setState(() => _metodoPagoSeleccionado = metodo);
    }
  }

  // ========== MÉTODOS DE LA INTERFAZ DE USUARIO ==========

  void _mostrarDialogoCantidad(Producto producto) {
    _cantidadController.text = '1';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Agregar ${producto.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Precio: \$${producto.precioVenta.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: _cantidadController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final cantidad = int.tryParse(_cantidadController.text) ?? 1;
              if (cantidad > 0) {
                _agregarProductoAlCarrito(producto, cantidad);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Widget _buildNuevaVentaTab() {
    // Obtener categorías únicas para el filtro
    final categorias = _productos.map((p) => p.categoria).toSet().toList()..sort();
    categorias.insert(0, 'Todas');
    
    final opcionesOrden = [
      'Nombre (A-Z)',
      'Nombre (Z-A)',
      'Precio (menor a mayor)',
      'Precio (mayor a menor)',
      'Stock (mayor a menor)',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filtros de búsqueda
        Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Barra de búsqueda
                TextField(
                  controller: _filtroBusquedaController,
                  decoration: InputDecoration(
                    labelText: 'Buscar producto',
                    hintText: 'Nombre o código de barras',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _filtroBusquedaController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _filtroBusquedaController.clear();
                              _aplicarFiltros();
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => _filtrarProductos(value),
                ),
                const SizedBox(height: 8),
                
                // Filtros adicionales
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filtroCategoria,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        ),
                        items: categorias.map((categoria) {
                          return DropdownMenuItem(
                            value: categoria,
                            child: Text(categoria),
                          );
                        }).toList(),
                        onChanged: _actualizarFiltroCategoria,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filtroOrden,
                        decoration: const InputDecoration(
                          labelText: 'Ordenar por',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        ),
                        items: opcionesOrden.map((opcion) {
                          return DropdownMenuItem(
                            value: opcion,
                            child: Text(opcion),
                          );
                        }).toList(),
                        onChanged: _actualizarFiltroOrden,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Lista de productos
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _productosFiltrados.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No se encontraron productos',
                              style: TextStyle(fontSize: 16)),
                          Text('Ajusta los filtros e intenta de nuevo',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _productosFiltrados.length,
                      itemBuilder: (context, index) {
                        final producto = _productosFiltrados[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            title: Text(producto.nombre),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Precio: \$${producto.precioVenta.toStringAsFixed(0)}'),
                                Text('Stock: ${producto.stock} | ${producto.categoria}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_shopping_cart, color: Colors.green),
                              onPressed: producto.stock > 0
                                  ? () => _mostrarDialogoCantidad(producto)
                                  : null,
                            ),
                            onTap: producto.stock > 0
                                ? () => _mostrarDialogoCantidad(producto)
                                : null,
                          ),
                        );
                      },
                    ),
        ),

        // Resumen del carrito
        if (_carrito.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                const Text(
                  'Resumen de la Venta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._carrito.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return ListTile(
                    title: Text('${item.producto.nombre} x${item.cantidad}'),
                    subtitle: Text('\$${item.subtotal.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _actualizarCantidadProducto(
                            index,
                            item.cantidad - 1,
                          ),
                        ),
                        Text(item.cantidad.toString()),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _actualizarCantidadProducto(
                            index,
                            item.cantidad + 1,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _eliminarProductoDelCarrito(index),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${_calcularTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Selección de cliente
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    _clienteSeleccionado?.nombre ?? 'Seleccionar Cliente',
                  ),
                  subtitle: Text(
                    _clienteSeleccionado?.telefono ?? 'Cliente ocasional',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _seleccionarCliente,
                ),
                // Selección de método de pago
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text('Método de pago'),
                  subtitle: Text(_metodoPagoSeleccionado),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _seleccionarMetodoPago,
                ),
                // Botón de procesar venta
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: PrimaryButton(
                    onPressed: _procesarVenta,
                    text: 'PROCESAR VENTA',
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistorialTab() {
    return Column(
      children: [
        // Filtros de fecha
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('Desde'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaInicio)),
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: _fechaInicio,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (fecha != null) {
                      setState(() => _fechaInicio = fecha);
                      _cargarVentas();
                    }
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('Hasta'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaFin)),
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: _fechaFin,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (fecha != null) {
                      setState(() => _fechaFin = fecha);
                      _cargarVentas();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Lista de ventas
        Expanded(
          child: _isLoadingVentas
              ? const Center(child: CircularProgressIndicator())
              : _ventas.isEmpty
              ? const Center(
                  child: Text(
                    'No hay ventas registradas en el período seleccionado',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarVentas,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _ventas.length,
                    itemBuilder: (context, index) {
                      final venta = _ventas[index];
                      return _buildVentaItem(venta);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildVentaItem(Venta venta) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          'Cliente: ${venta.clienteNombre ?? 'Cliente no especificado'}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${venta.totalFormateado}'),
            Text(
              'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha)}',
            ),
            Text('Método: ${venta.metodoPago}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _mostrarDetalleVenta(venta),
      ),
    );
  }

  Widget _buildDetalleVenta(Venta venta) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text(
              'Cliente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(venta.clienteNombre ?? 'Cliente no especificado'),
          ),
          const Divider(),
          ListTile(
            title: const Text(
              'Fecha',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha)),
          ),
          const Divider(),
          ListTile(
            title: const Text(
              'Método de pago',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(venta.metodoPago),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Productos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...venta.items.map(
            (item) => ListTile(
              title: Text(item['nombre_producto'] ?? 'Producto desconocido'),
              subtitle: Text(
                '${item['cantidad']} x ${NumberFormat.currency(symbol: '\$').format(item['precio_unitario'])}',
              ),
              trailing: Text(
                NumberFormat.currency(symbol: '\$').format(item['subtotal']),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  venta.totalFormateado,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDetalleVenta(Venta venta) async {
    try {
      setState(() => _isLoading = true);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Detalle de Venta #${venta.id}'),
          content: _buildDetalleVenta(venta),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar el detalle: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ========== MÉTODOS DE MENSAJES ==========

  Future<void> _mostrarError(String mensaje) async {
    if (!mounted) return;
    if (ScaffoldMessenger.maybeOf(context) == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: _buildTabBar(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNuevaVentaTab(),
          _buildHistorialTab(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          // Botón Nueva Venta
          Expanded(
            child: InkWell(
              onTap: () => _tabController.animateTo(0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _tabController.index == 0 ? Colors.white : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_shopping_cart, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      'Nueva Venta',
                      style: TextStyle(
                        fontSize: 12,
                        color: _tabController.index == 0 ? Colors.white : Colors.white70,
                        fontWeight: _tabController.index == 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Botón Historial
          Expanded(
            child: InkWell(
              onTap: () => _tabController.animateTo(1),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _tabController.index == 1 ? Colors.white : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      'Historial',
                      style: TextStyle(
                        fontSize: 12,
                        color: _tabController.index == 1 ? Colors.white : Colors.white70,
                        fontWeight: _tabController.index == 1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

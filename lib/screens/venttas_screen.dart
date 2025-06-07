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
  final Map<int, int> _productosSeleccionados =
      {}; // Mapa de ID de producto a cantidad
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  Cliente? _clienteSeleccionado;
  String _metodoPagoSeleccionado = 'Efectivo';
  final TextEditingController _numeroTransaccionController = TextEditingController();

  // Filtros de productos
  final TextEditingController _filtroBusquedaController =
      TextEditingController();
  String _filtroCategoria = 'Todas';
  final double _filtroPrecioMin = 0;
  final double _filtroPrecioMax = 1000000;

  // Actualizar filtro de categoría
  void _actualizarFiltroCategoria(String? value) {
    if (value != null) {
      setState(() => _filtroCategoria = value);
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
  // Variables para la pestaña de historial
  List<Venta> _ventas = [];
  bool _isLoadingVentas = false;
  DateTime _fechaInicio = DateTime.now(); // Por defecto, mostrar el día actual
  DateTime _fechaFin = DateTime.now();
  String? _filtroMetodoPago; // null = todos los métodos
  final List<String> _metodosPagoDisponibles = [
    'Efectivo',
    'Tarjeta de Crédito',
    'Tarjeta de Débito',
    'Transferencia',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _productosFiltrados = [];
    
    // Establecer las fechas para mostrar el día actual por defecto
    final ahora = DateTime.now();
    _fechaInicio = DateTime(ahora.year, ahora.month, ahora.day);
    _fechaFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
    
    // Programar la carga de datos para el siguiente frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargarProductos();
        _cargarVentas();
      }
    });
  }

  @override
  void dispose() {
    _montoRecibidoController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _cantidadController.dispose();
    _filtroBusquedaController.dispose();
    _numeroTransaccionController.dispose(); // Limpiar el controlador de número de transacción
    super.dispose();
  }

  // ========== MÉTODOS DE CARGA DE DATOS ==========

  Future<void> _cargarProductos() async {
    if (!mounted) return;
    
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      
      // Usar una variable local para los datos cargados
      final productos = await _databaseService.getProductos();
      
      if (mounted) {
        setState(() {
          _productos = productos;
          _productosFiltrados = List.from(_productos); // Inicializar _productosFiltrados con todos los productos
          
          // Aplicar filtros después de cargar los productos
          _aplicarFiltros();
        });
      }
    } catch (e) {
      debugPrint('Error al cargar productos: $e');
      if (mounted) {
        _mostrarError('Error al cargar productos: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cargarVentas() async {
    if (!mounted) return;

    try {
      if (mounted) {
        setState(() => _isLoadingVentas = true);
      }

      // Asegurarse de que las fechas tengan la hora correcta
      final fechaInicio = DateTime(_fechaInicio.year, _fechaInicio.month, _fechaInicio.day);
      final fechaFin = DateTime(_fechaFin.year, _fechaFin.month, _fechaFin.day, 23, 59, 59);
      
      debugPrint('Cargando ventas desde ${fechaInicio.toString()} hasta ${fechaFin.toString()}');
      
      // Usar una variable local para los datos cargados
      List<Venta> ventasCargadas = [];
      
      // Cargar todas las ventas en el rango de fechas
      try {
        ventasCargadas = await _databaseService.getVentasPorRangoFechas(
          fechaInicio,
          fechaFin,
        );
        debugPrint('Se encontraron ${ventasCargadas.length} ventas en el rango');
      } catch (e) {
        debugPrint('Error al cargar ventas: $e');
        rethrow;
      }

      // Aplicar filtro por método de pago si está seleccionado
      if (_filtroMetodoPago != null && _filtroMetodoPago!.isNotEmpty) {
        ventasCargadas = ventasCargadas
            .where((venta) => venta.metodoPago == _filtroMetodoPago)
            .toList();
      }

      // Ordenar por fecha más reciente
      ventasCargadas.sort((a, b) => b.fecha.compareTo(a.fecha));

      // Actualizar el estado solo si el widget aún está montado
      if (mounted) {
        setState(() {
          _ventas = ventasCargadas;
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

  Future<void> _agregarProductoAlCarrito(Producto producto, int cantidad) async {
    if (producto.id == null) return;

    setState(() {
      // Actualizar productos seleccionados
      _productosSeleccionados.update(
        producto.id!,
        (value) => value + cantidad,
        ifAbsent: () => cantidad,
      );

      // Buscar si el producto ya está en el carrito
      final index = _carrito.indexWhere(
        (item) => item.producto.id == producto.id,
      );

      if (index != -1) {
        // Si el producto ya está en el carrito, actualizar la cantidad
        _carrito[index] = CarritoItem(
          producto: producto,
          cantidad: _carrito[index].cantidad + cantidad,
        );
      } else {
        // Si el producto no está en el carrito, agregarlo
        _carrito.add(CarritoItem(producto: producto, cantidad: cantidad));
      }
    });
    
    // Recargar la lista de productos para asegurar que los stocks estén actualizados
    if (mounted) {
      await _cargarProductos();
    }
  }

  Future<void> _confirmarSeleccionProductos() async {
    // Si no hay productos seleccionados, no hacemos nada
    if (_productosSeleccionados.isEmpty) return;

    // Cerrar cualquier diálogo abierto
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Esperar al siguiente frame para asegurar que los diálogos anteriores se cierren
    await SchedulerBinding.instance.endOfFrame;

    if (!mounted) return;

    // Mostrar diálogo de confirmación con cliente y método de pago
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Venta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Resumen de la compra:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Lista de productos seleccionados
              ..._productosSeleccionados.entries.map((entry) {
                final producto = _productos.firstWhere(
                  (p) => p.id == entry.key,
                  orElse: () => Producto(
                    id: -1,
                    codigoBarras: 'NO_ENCONTRADO',
                    nombre: 'Producto no encontrado',
                    descripcion: 'Producto no encontrado en la base de datos',
                    categoria: 'General',
                    precioCompra: 0,
                    precioVenta: 0,
                    stock: 0,
                    fechaCreacion: DateTime.now(),
                    activo: false,
                  ),
                );
                return ListTile(
                  title: Text(producto.nombre),
                  subtitle: Text('Cantidad: ${entry.value}'),
                  trailing: Text(
                    '\$${(producto.precioVenta * entry.value).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),

              const Divider(),

              // Total
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                      '\$${_calcularTotalSeleccionado().toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Selector de cliente
              Card(
                child: ListTile(
                  title: Text(
                    _clienteSeleccionado?.nombre ?? 'Seleccionar Cliente',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _clienteSeleccionado?.telefono ??
                        'Sin cliente seleccionado',
                  ),
                  leading: const Icon(Icons.person_outline),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () async {
                    Navigator.pop(context, false);
                    await _seleccionarCliente();
                    // Volver a abrir el diálogo con los datos actualizados
                    if (mounted) {
                      await _confirmarSeleccionProductos();
                    }
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Selector de método de pago
              Card(
                child: ListTile(
                  title: const Text(
                    'Método de Pago',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_metodoPagoSeleccionado),
                  leading: const Icon(Icons.payment),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () async {
                    Navigator.pop(context, false);
                    await _seleccionarMetodoPago();
                    // Volver a abrir el diálogo con los datos actualizados
                    if (mounted) {
                      await _confirmarSeleccionProductos();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed:
                _clienteSeleccionado != null &&
                    _metodoPagoSeleccionado.isNotEmpty
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Confirmar Venta'),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      // Agregar productos al carrito
      final productosParaAgregar = <MapEntry<int, int>>[];
      
      // Primero, recolectar todos los IDs de productos a agregar
      _productosSeleccionados.forEach((productoId, cantidad) {
        // Solo necesitamos el ID y la cantidad para agregar al carrito
        productosParaAgregar.add(MapEntry(productoId, cantidad));
      });
      
      // Luego, agregar cada producto al carrito y esperar a que se complete
      for (final entry in productosParaAgregar) {
        final productoId = entry.key;
        final cantidad = entry.value;
        final producto = _productos.firstWhere(
          (p) => p.id == productoId,
          orElse: () => Producto(
            id: -1,
            codigoBarras: 'NO_ENCONTRADO',
            nombre: 'Producto no encontrado',
            descripcion: 'Producto no encontrado en la base de datos',
            categoria: 'General',
            precioCompra: 0,
            precioVenta: 0,
            stock: 0,
            fechaCreacion: DateTime.now(),
            activo: false,
          ),
        );
        await _agregarProductoAlCarrito(producto, cantidad);
      }

      // Limpiar selección
      setState(() {
        _productosSeleccionados.clear();
      });

      // Mostrar diálogo de pago
      if (mounted) {
        await _mostrarDialogoPago();
      }
    }
  }

  void _eliminarProductoDelCarrito(int index) {
    setState(() {
      _carrito.removeAt(index);
    });
  }

  void _actualizarCantidadProducto(int index, int nuevaCantidad) {
    final producto = _carrito[index].producto;

    // Verificar que la nueva cantidad no exceda el stock disponible
    if (nuevaCantidad > producto.stock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No hay suficiente stock disponible. Stock actual: ${producto.stock}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (nuevaCantidad > 0) {
      setState(() {
        _carrito[index].cantidad = nuevaCantidad;
        // Actualizar también el mapa de productos seleccionados
        _productosSeleccionados[producto.id!] = nuevaCantidad;
      });
    } else {
      _eliminarProductoDelCarrito(index);
    }
  }

  double _calcularTotal() {
    return _carrito.fold(0, (total, item) => total + item.subtotal);
  }

  double _calcularTotalSeleccionado() {
    return _productosSeleccionados.entries.fold(0, (total, entry) {
      try {
        final producto = _productos.firstWhere((p) => p.id == entry.key);
        return total + (producto.precioVenta * entry.value);
      } catch (e) {
        debugPrint('Error calculando total: $e');
        return total;
      }
    });
  }

  // ========== MÉTODOS DE BÚSQUEDA Y FILTRADO ==========

  // Método para aplicar todos los filtros
  void _aplicarFiltros() {
    setState(() {
      // Aplicar filtro de búsqueda
      String busqueda = _filtroBusquedaController.text.toLowerCase();

      _productosFiltrados = _productos.where((producto) {
        // Filtro por búsqueda en nombre o código de barras
        bool coincideBusqueda =
            busqueda.isEmpty ||
            producto.nombre.toLowerCase().contains(busqueda) ||
            producto.codigoBarras.toLowerCase().contains(busqueda);

        // Filtro por categoría (insensible a mayúsculas/minúsculas)
        bool coincideCategoria =
            _filtroCategoria == 'Todas' ||
            producto.categoria.toLowerCase() == _filtroCategoria.toLowerCase();

        // Filtro por rango de precios
        bool enRangoPrecio =
            producto.precioVenta >= _filtroPrecioMin &&
            producto.precioVenta <= _filtroPrecioMax;

        return coincideBusqueda && coincideCategoria && enRangoPrecio;
      }).toList();

      // Aplicar ordenamiento
      _aplicarOrden();
    });
  }

  // Método para aplicar el ordenamiento
  void _aplicarOrden() {
    // Ordenar por nombre por defecto
    _productosFiltrados.sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  // Método para manejar cambios en la búsqueda
  void _filtrarProductos(String query) {
    _aplicarFiltros();
  }

  // ========== MÉTODOS DE PROCESO DE VENTA ==========

  // Calcular el vuelto
  double get _calcularVuelto {
    if (_montoRecibido <= 0) return 0.0;
    final total = _calcularTotal();
    final vuelto = _montoRecibido - total;
    return vuelto > 0 ? vuelto : 0.0;
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
    _montoRecibido = total; // Inicializar _montoRecibido con el total
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
              const SizedBox(height: 16),
              if (_montoRecibido > 0) ...[
                _montoRecibido >= _calcularTotal()
                    ? Text(
                        'Vuelto: ${_formatoMoneda(_calcularVuelto)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      )
                    : Text(
                        'Monto insuficiente',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.orange[800],
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

    // Verificar si se requiere número de transacción
    if ((_metodoPagoSeleccionado == 'Transferencia' ||
            _metodoPagoSeleccionado == 'Tarjeta de Crédito' ||
            _metodoPagoSeleccionado == 'Tarjeta de Débito') &&
        (_numeroTransaccionController.text.trim().isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ingrese el número de transacción para continuar')),
      );
      return;
    }

    // Mostrar diálogo de pago solo para efectivo
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
      // Incluir número de transacción si corresponde
      referenciaPago: (_metodoPagoSeleccionado == 'Transferencia' ||
              _metodoPagoSeleccionado == 'Tarjeta de Crédito' ||
              _metodoPagoSeleccionado == 'Tarjeta de Débito')
          ? _numeroTransaccionController.text.trim()
          : null,
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
      // Debug: Imprimir información de la venta antes de guardar
      debugPrint('Guardando venta - Método de pago: ${venta.metodoPago}, Referencia: ${venta.referenciaPago}');
    
      // Procesar la venta
      await DatabaseService().insertVenta(venta);

      // Recargar datos
      await Future.wait([_cargarProductos(), _cargarVentas()]);

      if (!mounted) return;

      // Limpiar el carrito y controles
      setState(() {
        _carrito.clear();
        _clienteSeleccionado = null;
        _metodoPagoSeleccionado = 'Efectivo'; // Resetear al valor por defecto
        _numeroTransaccionController.clear(); // Limpiar número de transacción
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

    // Controlador para el campo de búsqueda
    final searchController = TextEditingController();
    List<Cliente> clientesFiltrados = List.from(clientes);

    final clienteSeleccionado = await showDialog<Cliente>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Seleccionar Cliente'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo de búsqueda
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar por nombre o RUC',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                clientesFiltrados = List.from(clientes);
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        clientesFiltrados = List.from(clientes);
                      } else {
                        final searchLower = value.toLowerCase();
                        clientesFiltrados = clientes.where((cliente) {
                          final nombreMatch = cliente.nombre
                              .toLowerCase()
                              .contains(searchLower);
                          final rucMatch =
                              cliente.ruc?.toLowerCase().contains(
                                searchLower,
                              ) ??
                              false;
                          return nombreMatch || rucMatch;
                        }).toList();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Lista de clientes filtrados
                SizedBox(
                  height: 300,
                  width: double.maxFinite,
                  child: clientesFiltrados.isEmpty
                      ? const Center(child: Text('No se encontraron clientes'))
                      : ListView.builder(
                          itemCount: clientesFiltrados.length,
                          itemBuilder: (context, index) {
                            final cliente = clientesFiltrados[index];
                            return ListTile(
                              title: Text(cliente.nombre),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (cliente.ruc?.isNotEmpty ?? false)
                                    Text('RUC: ${cliente.ruc}'),
                                  if (cliente.telefono?.isNotEmpty ?? false)
                                    Text('Tel: ${cliente.telefono}'),
                                ],
                              ),
                              onTap: () => Navigator.pop(context, cliente),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );

    if (clienteSeleccionado != null) {
      setState(() => _clienteSeleccionado = clienteSeleccionado);
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
      // Si el método de pago requiere número de transacción, mostramos un diálogo
      if (metodo == 'Transferencia' || 
          metodo == 'Tarjeta de Crédito' || 
          metodo == 'Tarjeta de Débito') {
        _numeroTransaccionController.clear();
        
        final numeroTransaccion = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Número de ${metodo.toLowerCase()}'),
            content: TextField(
              controller: _numeroTransaccionController,
              decoration: InputDecoration(
                labelText: 'Número de transacción',
                hintText: 'Ingrese el número de $metodo',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  if (_numeroTransaccionController.text.trim().isNotEmpty) {
                    Navigator.pop(context, _numeroTransaccionController.text.trim());
                  }
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );

        if (numeroTransaccion == null || numeroTransaccion.isEmpty) {
          // Si el usuario cancela o no ingresa un número, no cambiamos el método de pago
          return;
        }
        
        // Guardamos el número de transacción en el controlador
        _numeroTransaccionController.text = numeroTransaccion;
      } else {
        // Para otros métodos de pago, limpiamos el número de transacción
        _numeroTransaccionController.clear();
      }
      
      setState(() => _metodoPagoSeleccionado = metodo);
    }
  }

  Widget _buildNuevaVentaTab() {
    // Obtener categorías únicas para el filtro
    final categorias = _productos.map((p) => p.categoria).toSet().toList()
      ..sort();
    categorias.insert(0, 'Todas');

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
                              _filtrarProductos('');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => _filtrarProductos(value),
                ),
                const SizedBox(height: 8),

                // Filtros adicionales
                DropdownButtonFormField<String>(
                  value: _filtroCategoria,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                  ),
                  items: categorias.map((categoria) {
                    return DropdownMenuItem(
                      value: categoria,
                      child: Text(categoria),
                    );
                  }).toList(),
                  onChanged: _actualizarFiltroCategoria,
                ),
              ],
            ),
          ),
        ),

        // Lista de productos
        Expanded(
          child: _productosFiltrados.isEmpty
              ? const Center(child: Text('No se encontraron productos'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _productosFiltrados.length,
                  itemBuilder: (context, index) {
                    final producto = _productosFiltrados[index];
                    final cantidad = _productosSeleccionados[producto.id!] ?? 0;
                    final estaSeleccionado = cantidad > 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 8.0,
                      ),
                      elevation: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Columna de información del producto
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Precio: \$${producto.precioVenta.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Stock: ${producto.stock}',
                                    style: TextStyle(
                                      color: producto.stock > 0
                                          ? Colors.grey[600]
                                          : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (estaSeleccionado) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: \$${(producto.precioVenta * cantidad).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Controles de cantidad
                            if (producto.stock > 0)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Botón -
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: cantidad > 0
                                          ? () {
                                              setState(() {
                                                if (cantidad > 1) {
                                                  _productosSeleccionados[producto
                                                          .id!] =
                                                      cantidad - 1;
                                                } else {
                                                  _productosSeleccionados
                                                      .remove(producto.id!);
                                                }
                                              });
                                            }
                                          : null,
                                    ),
                                    // Cantidad
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        cantidad > 0
                                            ? cantidad.toString()
                                            : '0',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    // Botón +
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: cantidad < producto.stock
                                          ? () {
                                              setState(() {
                                                _productosSeleccionados[producto
                                                        .id!] =
                                                    (cantidad + 1);
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Sin stock',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Botón flotante para confirmar la selección
        if (_productosSeleccionados.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _confirmarSeleccionProductos,
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text(
                'Ver (${_productosSeleccionados.length})\n\$${_calcularTotalSeleccionado().toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Theme.of(context).primaryColor,
              elevation: 4,
            ),
          ),
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
                          onPressed: () {
                            _actualizarCantidadProducto(
                              index,
                              item.cantidad - 1,
                            );
                          },
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
        // Filtros de fecha y método de pago
        Card(
          margin: const EdgeInsets.all(8.0),
          child: Column(
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
                            lastDate: DateTime.now().add(const Duration(days: 1)),
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
                            lastDate: DateTime.now().add(const Duration(days: 1)),
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
              // Filtro por método de pago
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButtonFormField<String>(
                  value: _filtroMetodoPago,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos los métodos'),
                    ),
                    ..._metodosPagoDisponibles.map((metodo) => DropdownMenuItem(
                          value: metodo,
                          child: Text(metodo),
                        )),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _filtroMetodoPago = value;
                      _cargarVentas();
                    });
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
    // Mensaje de depuración
    debugPrint('Venta ID: ${venta.id} - Referencia: ${venta.referenciaPago} - Método: ${venta.metodoPago}');
    
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
            if (venta.referenciaPago != null && venta.referenciaPago!.isNotEmpty)
              Text(
                'Transacción: ${venta.referenciaPago}',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (venta.metodoPago.toLowerCase().contains('tarjeta') && venta.referenciaPago != null && venta.referenciaPago!.isNotEmpty)
                  Text('${venta.metodoPago} (Transacción: ${venta.referenciaPago})')
                else
                  Text(venta.metodoPago),
                if (venta.referenciaPago != null && venta.referenciaPago!.isNotEmpty && !venta.metodoPago.toLowerCase().contains('tarjeta'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Transacción: ${venta.referenciaPago}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
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
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Nueva Venta'),
            Tab(icon: Icon(Icons.assignment), text: 'Historial'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            RefreshIndicator(
              onRefresh: _cargarProductos,
              child: _buildNuevaVentaTab(),
            ),
            RefreshIndicator(
              onRefresh: _cargarVentas,
              child: _buildHistorialTab(),
            ),
          ],
        ),
      ),
    );
  }
}

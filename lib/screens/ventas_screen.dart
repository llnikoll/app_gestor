import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/producto_model.dart';
import '../models/venta_model.dart';
import '../models/cliente_model.dart';
import '../models/carrito_item_model.dart';
import '../services/database_service.dart';
import '../services/product_notifier_service.dart';
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
  final Map<int, int> _productosSeleccionados = {};
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  Cliente? _clienteSeleccionado;
  String? _metodoPagoSeleccionado = 'Efectivo'; // Valor por defecto
  final TextEditingController _numeroTransaccionController =
      TextEditingController();

  // Filtros de productos
  final TextEditingController _filtroBusquedaController =
      TextEditingController();
  final String _filtroCategoria = 'Todas';
  final double _filtroPrecioMin = 0;
  final double _filtroPrecioMax = 1000000;
  String? _filtroMetodoPago;

  void _actualizarFiltroCategoria(String? value) {
    if (value != null && mounted) {
      setState(() {
        _aplicarFiltros(filtroCategoria: value);
      });
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
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _productosFiltrados = [];

    // Establecer las fechas para mostrar el día actual por defecto
    final ahora = DateTime.now();
    _fechaInicio = DateTime(ahora.year, ahora.month, ahora.day);
    _fechaFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
  }

  ProductNotifierService? _productNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _productNotifier ??= Provider.of<ProductNotifierService>(
      context,
      listen: false,
    );
    _productNotifier!.notifier.addListener(_onProductUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargarProductos();
        _cargarVentas();
      }
    });
  }

  @override
  void dispose() {
    _productNotifier?.notifier.removeListener(_onProductUpdate);
    _montoRecibidoController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _cantidadController.dispose();
    _filtroBusquedaController.dispose();
    _numeroTransaccionController.dispose();
    super.dispose();
  }

  void _onProductUpdate() {
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _cargarProductos();
          _cargarVentas();
        }
      });
    }
  }

  Future<void> _cargarProductos() async {
    if (!mounted) return;
    try {
      setState(() => _isLoading = true);
      final productos = await _databaseService.getProductos();
      if (mounted) {
        setState(() {
          _productos = productos;
          _productosFiltrados = List.from(_productos);
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
      setState(() => _isLoadingVentas = true);
      final fechaInicio = DateTime(
        _fechaInicio.year,
        _fechaInicio.month,
        _fechaInicio.day,
      );
      final fechaFin = DateTime(
        _fechaFin.year,
        _fechaFin.month,
        _fechaFin.day,
        23,
        59,
        59,
      );
      debugPrint(
        'Cargando ventas desde ${fechaInicio.toString()} hasta ${fechaFin.toString()}',
      );
      List<Venta> ventasCargadas = await _databaseService
          .getVentasPorRangoFechas(fechaInicio, fechaFin);
      debugPrint('Se encontraron ${ventasCargadas.length} ventas en el rango');
      if (_filtroMetodoPago != null && _filtroMetodoPago!.isNotEmpty) {
        ventasCargadas = ventasCargadas
            .where((venta) => venta.metodoPago == _filtroMetodoPago)
            .toList();
      }
      ventasCargadas.sort((a, b) => b.fecha.compareTo(a.fecha));
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

  Widget _buildProductImage(String imageName) {
    if (imageName.startsWith('http') || imageName.startsWith('https')) {
      return Image.network(
        imageName,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
      );
    }
    return FutureBuilder<String>(
      future: _getImagePath(imageName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorImage();
        }
        final imagePath = snapshot.data!;
        if (imagePath.isEmpty) return _buildErrorImage();
        return Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
        );
      },
    );
  }

  Widget _buildErrorImage() {
    return const Center(
      child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
    );
  }

  Future<String> _getImagePath(String imageName) async {
    try {
      final externalDir =
          '/storage/emulated/0/Android/data/com.example.app_gestor_ventas/files/product_images';
      final externalPath = '$externalDir/$imageName';
      final externalFile = File(externalPath);
      if (await externalFile.exists()) {
        debugPrint(
          'Imagen encontrada en almacenamiento externo: $externalPath',
        );
        return externalPath;
      }
      final Directory appDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDir.path}/product_images/$imageName';
      debugPrint('Buscando imagen en: $localPath');
      final localFile = File(localPath);
      if (await localFile.exists()) {
        debugPrint('Imagen encontrada en almacenamiento local: $localPath');
        return localPath;
      }
      debugPrint('No se encontró la imagen en ninguna ubicación: $imageName');
      return '';
    } catch (e) {
      debugPrint('Error al obtener ruta de imagen: $e');
      return '';
    }
  }

  Future<void> _agregarProductoAlCarrito(
    Producto producto,
    int cantidad,
  ) async {
    if (producto.id == null) return;
    if (!mounted) return;

    setState(() {
      final index = _carrito.indexWhere(
        (item) => !item.esVentaCasual && item.producto?.id == producto.id,
      );
      if (index != -1) {
        _carrito[index] = CarritoItem.producto(
          producto: producto,
          cantidad: _carrito[index].cantidad + cantidad,
        );
      } else {
        _carrito.add(
          CarritoItem.producto(producto: producto, cantidad: cantidad),
        );
      }
      _productosSeleccionados[producto.id!] =
          (_productosSeleccionados[producto.id!] ?? 0) + cantidad;
    });

    if (!mounted) return;
    await _cargarProductos();
  }

  void _eliminarProductoDelCarrito(int index) {
    setState(() {
      final item = _carrito[index];
      if (!item.esVentaCasual && item.producto?.id != null) {
        _productosSeleccionados.remove(item.producto!.id!);
      }
      _carrito.removeAt(index);
    });
  }

  void _agregarVentaCasualAlCarrito({
    required String descripcion,
    required double monto,
    int cantidad = 1,
  }) {
    setState(() {
      _carrito.add(
        CarritoItem.ventaCasual(
          descripcion: descripcion,
          monto: monto,
          cantidad: cantidad,
        ),
      );
    });
  }

  void _actualizarCantidadProducto(int index, int nuevaCantidad) {
    if (index < 0 || index >= _carrito.length) return;
    final item = _carrito[index];
    final producto = item.producto;
    if (item.esVentaCasual || producto == null) {
      setState(() {
        _carrito[index].cantidad = nuevaCantidad;
      });
      return;
    }
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
        if (producto.id != null) {
          _productosSeleccionados[producto.id!] = nuevaCantidad;
        }
      });
    } else {
      _eliminarProductoDelCarrito(index);
    }
  }

  double _calcularTotalSeleccionado() {
    return _carrito.fold(0, (total, item) => total + item.subtotal);
  }

  void _aplicarFiltros({String? filtroCategoria}) {
    String busqueda = _filtroBusquedaController.text.toLowerCase();
    final categoria = filtroCategoria ?? _filtroCategoria;

    _productosFiltrados = _productos.where((producto) {
      bool cumpleBusqueda =
          producto.nombre.toLowerCase().contains(busqueda) ||
          producto.codigoBarras.toLowerCase().contains(busqueda);

      bool cumpleCategoria =
          categoria == 'Todas' || producto.categoria == categoria;

      bool cumplePrecio =
          producto.precioVenta >= _filtroPrecioMin &&
          producto.precioVenta <= _filtroPrecioMax;

      return cumpleBusqueda && cumpleCategoria && cumplePrecio;
    }).toList();
    _aplicarOrden();
  }

  void _aplicarOrden() {
    _productosFiltrados.sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  void _filtrarProductos(String query) {
    _aplicarFiltros();
  }

  String _formatoMoneda(double valor) {
    final formatter = NumberFormat('#,##0', 'es_PY');
    return 'Gs. ${formatter.format(valor)}';
  }

  // Método para manejar el resultado del diálogo de pago
  void _manejarDialogoPago(BuildContext? dialogContext) {
    // Verificar si el widget está montado antes de continuar
    if (!mounted) return;

    // Guardar el contexto actual
    final currentContext = context;

    // Función para mostrar mensaje de error
    void showError() {
      if (!mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
          content: Text('Error al procesar el pago'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Función para procesar el resultado exitoso
    void processResult(bool resultado) {
      if (!mounted) return;
      if (resultado == true) {
        _procesarVentas(dialogContext);
      }
    }

    // Mostrar el diálogo y manejar el resultado
    _mostrarDialogoPago().then(
      processResult,
      onError: (error) {
        debugPrint('Error en el diálogo de pago: $error');
        if (mounted) showError();
      },
    );
  }

  // Método para mostrar el diálogo de pago
  Future<bool> _mostrarDialogoPago() async {
    final total = _calcularTotalSeleccionado();
    _montoRecibido = total;
    _montoRecibidoController.text = total.toStringAsFixed(0);

    // Create a local TextEditingController for the dialog
    final dialogMontoController = TextEditingController(
      text: _montoRecibido.toStringAsFixed(0),
    );
    double dialogMonto = _montoRecibido;
    bool pagoConfirmado = false;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Pago en Efectivo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total a Pagar: ${_formatoMoneda(total)}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dialogMontoController,
                    decoration: const InputDecoration(
                      labelText: 'Monto Recibido',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final newValue = double.tryParse(value) ?? 0.0;
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          dialogMonto = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (dialogMonto > 0) ...[
                    dialogMonto >= total
                        ? Text(
                            'Vuelto: ${_formatoMoneda(dialogMonto - total)}',
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
                  onPressed: () {
                    pagoConfirmado = false;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: dialogMonto >= total
                      ? () {
                          _montoRecibido = dialogMonto;
                          _montoRecibidoController.text = dialogMonto
                              .toStringAsFixed(0);
                          pagoConfirmado = true;
                          Navigator.pop(dialogContext);
                        }
                      : null,
                  child: const Text('Confirmar Pago'),
                ),
              ],
            );
          },
        ),
      );

      return pagoConfirmado;
    } finally {
      // Clean up the dialog controller
      dialogMontoController.dispose();
    }
  }

  Future<void> _procesarVenta({
    BuildContext? dialogContext,
    bool esPagoEnEfectivo = false,
  }) async {
    // Guardar el contexto localmente para usarlo después de operaciones asíncronas
    final localContext = context;

    if (_carrito.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        localContext,
      ).showSnackBar(const SnackBar(content: Text('El carrito está vacío')));
      return;
    }

    // Si no es pago en efectivo, verificar número de transacción para métodos que lo requieran
    if (!esPagoEnEfectivo &&
        (_metodoPagoSeleccionado == 'Transferencia' ||
            _metodoPagoSeleccionado == 'Tarjeta de Crédito' ||
            _metodoPagoSeleccionado == 'Tarjeta de Débito') &&
        _numeroTransaccionController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese el número de transacción para continuar'),
        ),
      );
      return;
    }

    // Asegurarse de que _metodoPagoSeleccionado no sea nulo
    if (_metodoPagoSeleccionado == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un método de pago')),
      );
      return;
    }

    // Si es pago en efectivo, mostrar el diálogo de pago
    if (!esPagoEnEfectivo && _metodoPagoSeleccionado == 'Efectivo') {
      _manejarDialogoPago(dialogContext);
      return;
    }

    // Si llegamos aquí, es porque es un pago que no requiere diálogo de efectivo
    // o ya pasamos por el diálogo de efectivo (esPagoEnEfectivo = true)
    _procesarVentas(dialogContext);
  }

  // Método separado para procesar las ventas (tanto normales como casuales)
  Future<void> _procesarVentas(BuildContext? dialogContext) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Procesar ventas casuales primero
      final ventasCasuales = _carrito
          .where((item) => item.esVentaCasual)
          .toList();
      for (final item in ventasCasuales) {
        await DatabaseService().insertVentaCasual(
          monto: item.subtotal,
          descripcion: item.descripcionVentaCasual ?? 'Venta Casual',
          metodoPago: _metodoPagoSeleccionado!,
          referenciaPago:
              (_metodoPagoSeleccionado == 'Transferencia' ||
                  _metodoPagoSeleccionado == 'Tarjeta de Crédito' ||
                  _metodoPagoSeleccionado == 'Tarjeta de Débito')
              ? _numeroTransaccionController.text.trim()
              : null,
          clienteId: _clienteSeleccionado?.id,
          clienteNombre: _clienteSeleccionado?.nombre,
        );
      }

      // Procesar productos normales si existen
      final productosNormales = _carrito
          .where((item) => !item.esVentaCasual)
          .toList();
      if (productosNormales.isNotEmpty) {
        final venta = Venta(
          clienteId: _clienteSeleccionado?.id,
          clienteNombre: _clienteSeleccionado?.nombre ?? 'Cliente ocasional',
          total: productosNormales.fold(
            0.0,
            (sum, item) => sum + item.subtotal,
          ),
          metodoPago: _metodoPagoSeleccionado!,
          referenciaPago:
              (_metodoPagoSeleccionado == 'Transferencia' ||
                  _metodoPagoSeleccionado == 'Tarjeta de Crédito' ||
                  _metodoPagoSeleccionado == 'Tarjeta de Débito')
              ? _numeroTransaccionController.text.trim()
              : null,
          items: productosNormales
              .map(
                (item) => {
                  'tipo': 'producto',
                  'producto_id': item.producto?.id,
                  'nombre_producto':
                      item.producto?.nombre ?? 'Producto sin nombre',
                  'cantidad': item.cantidad,
                  'precio_unitario': item.producto?.precioVenta ?? 0.0,
                  'subtotal': item.subtotal,
                  'descripcion': item.producto?.descripcion ?? '',
                },
              )
              .toList(),
        );

        await DatabaseService().insertVenta(venta);
      }

      // Actualizar la lista de ventas y productos
      await Future.wait([_cargarProductos(), _cargarVentas()]);
      if (!mounted) return;

      // Cerrar el diálogo antes de limpiar el estado
      if (dialogContext != null && dialogContext.mounted) {
        if (Navigator.canPop(dialogContext)) {
          Navigator.pop(dialogContext);
        }
      }

      // Limpiar el estado
      if (mounted) {
        setState(() {
          _carrito.clear();
          _clienteSeleccionado = null;
          _metodoPagoSeleccionado = null;
          _numeroTransaccionController.clear();
          _productosSeleccionados.clear();
        });
      }

      // Mostrar mensaje de éxito
      if (!mounted) return;
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
      debugPrint('Error al guardar venta: $e');
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
    final clientes = await DatabaseService().getAllClientes();
    if (!mounted) return;
    if (clientes.isEmpty) {
      if (ScaffoldMessenger.maybeOf(context) == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes registrados')),
      );
      return;
    }

    // Create a local TextEditingController and state for the dialog
    final searchController = TextEditingController();
    List<Cliente> clientesFiltrados = List.from(clientes);

    try {
      final clienteSeleccionado = await showDialog<Cliente>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            // Filter function to avoid code duplication
            void filterClients(String query) {
              if (query.isEmpty) {
                clientesFiltrados = List.from(clientes);
              } else {
                final searchLower = query.toLowerCase();
                clientesFiltrados = clientes.where((cliente) {
                  final nombreMatch = cliente.nombre.toLowerCase().contains(
                    searchLower,
                  );
                  final rucMatch =
                      cliente.ruc?.toLowerCase().contains(searchLower) ?? false;
                  return nombreMatch || rucMatch;
                }).toList();
              }
            }

            // Initial filter
            if (searchController.text.isNotEmpty) {
              filterClients(searchController.text);
            }

            return AlertDialog(
              title: const Text('Seleccionar Cliente'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                  if (dialogContext.mounted) {
                                    setDialogState(() {
                                      filterClients('');
                                    });
                                  }
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            filterClients(value);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      width: double.maxFinite,
                      child: clientesFiltrados.isEmpty
                          ? const Center(
                              child: Text('No se encontraron clientes'),
                            )
                          : ListView.builder(
                              itemCount: clientesFiltrados.length,
                              itemBuilder: (context, index) {
                                final cliente = clientesFiltrados[index];
                                return ListTile(
                                  title: Text(cliente.nombre),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (cliente.ruc?.isNotEmpty ?? false)
                                        Text('RUC: ${cliente.ruc}'),
                                      if (cliente.telefono?.isNotEmpty ?? false)
                                        Text('Tel: ${cliente.telefono}'),
                                    ],
                                  ),
                                  onTap: () =>
                                      Navigator.pop(dialogContext, cliente),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        ),
      );

      if (clienteSeleccionado != null && mounted) {
        setState(() => _clienteSeleccionado = clienteSeleccionado);
      }
    } finally {
      // Always dispose the controller
      searchController.dispose();
    }
  }

  Future<void> _mostrarDialogoVentaCasual() async {
    final montoController = TextEditingController();
    final descripcionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Venta Casual'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: montoController,
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    prefixText: 'Gs. ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                  onChanged: (value) {
                    if (value.isEmpty) return;
                    final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                    final number = int.tryParse(cleanValue) ?? 0;
                    final formatted = number.toString().replaceAllMapped(
                      RegExp(r'\B(?=(\d{3})+(?!\d))'),
                      (match) => '.',
                    );
                    if (formatted != value) {
                      montoController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese un monto';
                    }
                    final cleanValue = value.replaceAll('.', '');
                    final monto = double.tryParse(cleanValue);
                    if (monto == null || monto <= 0) {
                      return 'El monto debe ser mayor a cero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Ej: Venta de servicio',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese una descripción';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Agregar al Carrito'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      final montoStr = montoController.text.trim().replaceAll('.', '');
      final monto = double.parse(montoStr);
      final descripcion = descripcionController.text.trim();
      if (mounted) {
        _agregarVentaCasualAlCarrito(descripcion: descripcion, monto: monto);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Venta casual agregada al carrito'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _mostrarDialogoCarrito() async {
    if (_carrito.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El carrito está vacío')));
      return;
    }
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Detalles del Carrito'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._carrito.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return ListTile(
                      title: Text(
                        item.esVentaCasual
                            ? item.descripcionVentaCasual ?? 'Venta Casual'
                            : '${item.producto!.nombre} x${item.cantidad}',
                      ),
                      subtitle: Text(
                        item.esVentaCasual
                            ? 'Monto: ${_formatoMoneda(item.subtotal)}'
                            : 'Subtotal: ${_formatoMoneda(item.subtotal)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              setDialogState(() {
                                _actualizarCantidadProducto(
                                  index,
                                  item.cantidad - 1,
                                );
                              });
                            },
                          ),
                          Text(item.cantidad.toString()),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setDialogState(() {
                                _actualizarCantidadProducto(
                                  index,
                                  item.cantidad + 1,
                                );
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                _eliminarProductoDelCarrito(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
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
                          _formatoMoneda(_calcularTotalSeleccionado()),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      _clienteSeleccionado?.nombre ?? 'Seleccionar Cliente',
                    ),
                    subtitle: Text(
                      _clienteSeleccionado?.telefono ?? 'Cliente ocasional',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      await _seleccionarCliente();
                      if (dialogContext.mounted) {
                        setDialogState(() {});
                      }
                    },
                  ),
                  // Selector de método de pago
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título del selector
                      const Padding(
                        padding: EdgeInsets.only(
                          left: 16.0,
                          top: 8.0,
                          bottom: 4.0,
                        ),
                        child: Text(
                          'Método de Pago',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      // Lista de botones de métodos de pago
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _metodosPago.length,
                          itemBuilder: (context, index) {
                            final metodo = _metodosPago[index];
                            final bool isSelected =
                                _metodoPagoSeleccionado == metodo;
                            final bool needsReference = [
                              'Transferencia',
                              'Tarjeta de Crédito',
                              'Tarjeta de Débito',
                            ].contains(metodo);

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                                vertical: 4.0,
                              ),
                              child: ChoiceChip(
                                label: Text(metodo),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setDialogState(() {
                                      _metodoPagoSeleccionado = metodo;
                                      if (!needsReference) {
                                        _numeroTransaccionController.clear();
                                      }
                                    });
                                  }
                                },
                                selectedColor: Theme.of(
                                  context,
                                ).primaryColor.withAlpha((0.2 * 255).round()),
                                backgroundColor: Colors.grey[200],
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Campo para número de transacción (solo visible cuando es necesario)
                      if (_metodoPagoSeleccionado == 'Transferencia' ||
                          _metodoPagoSeleccionado == 'Tarjeta de Crédito' ||
                          _metodoPagoSeleccionado == 'Tarjeta de Débito')
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: TextFormField(
                            controller: _numeroTransaccionController,
                            decoration: InputDecoration(
                              labelText: 'Número de transacción',
                              hintText: 'Ingrese el número de transacción',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              prefixIcon: const Icon(
                                Icons.confirmation_number,
                                size: 20,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                  // El campo de número de transacción se muestra arriba, solo para métodos que lo requieren
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            PrimaryButton(
              onPressed: () {
                // Validar que se haya seleccionado un método de pago
                if (_metodoPagoSeleccionado == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Seleccione un método de pago'),
                    ),
                  );
                  return;
                }

                // Validar que si el método de pago requiere número de transacción, este no esté vacío
                if ((_metodoPagoSeleccionado == 'Transferencia' ||
                        _metodoPagoSeleccionado == 'Tarjeta de Crédito' ||
                        _metodoPagoSeleccionado == 'Tarjeta de Débito') &&
                    _numeroTransaccionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ingrese el número de transacción para continuar',
                      ),
                    ),
                  );
                  return;
                }

                // Si todo está bien, procesar la venta
                _procesarVenta(dialogContext: dialogContext);
              },
              text: 'CONFIRMAR VENTA',
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNuevaVentaTab() {
    final categorias = _productos.map((p) => p.categoria).toSet().toList()
      ..sort();
    categorias.insert(0, 'Todas');
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: ElevatedButton.icon(
                onPressed: _mostrarDialogoVentaCasual,
                icon: const Icon(Icons.add_shopping_cart, size: 20),
                label: const Text('Venta Casual'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: _productosFiltrados.isEmpty
                  ? const Center(child: Text('No se encontraron productos'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: _productosFiltrados.length,
                      itemBuilder: (context, index) {
                        final producto = _productosFiltrados[index];
                        final cantidad = producto.id != null
                            ? _productosSeleccionados[producto.id!] ?? 0
                            : 0;
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
                                if (producto.imagenUrl != null &&
                                    producto.imagenUrl!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: _buildProductImage(
                                          producto.imagenUrl!,
                                        ),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (producto.descripcion.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Descripción: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              TextSpan(
                                                text: producto.descripcion,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Precio: ${_formatoMoneda(producto.precioVenta)}',
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
                                    ],
                                  ),
                                ),
                                if (producto.stock > 0)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove,
                                            size: 18,
                                          ),
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
                                                    final index = _carrito
                                                        .indexWhere(
                                                          (item) =>
                                                              !item
                                                                  .esVentaCasual &&
                                                              item
                                                                      .producto
                                                                      ?.id ==
                                                                  producto.id,
                                                        );
                                                    if (index != -1) {
                                                      if (cantidad > 1) {
                                                        _carrito[index]
                                                                .cantidad =
                                                            cantidad - 1;
                                                      } else {
                                                        _carrito.removeAt(
                                                          index,
                                                        );
                                                      }
                                                    }
                                                  });
                                                }
                                              : null,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            cantidad.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: cantidad < producto.stock
                                              ? () {
                                                  _agregarProductoAlCarrito(
                                                    producto,
                                                    1,
                                                  );
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: PrimaryButton(
                onPressed: _procesarVenta,
                text: 'VER CARRITO Y PROCESAR VENTA',
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistorialTab() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('Desde'),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(_fechaInicio),
                        ),
                        onTap: () async {
                          final fecha = await showDatePicker(
                            context: context,
                            initialDate: _fechaInicio,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
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
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(_fechaFin),
                        ),
                        onTap: () async {
                          final fecha = await showDatePicker(
                            context: context,
                            initialDate: _fechaFin,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
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
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButtonFormField<String>(
                  value: _filtroMetodoPago,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos los métodos'),
                    ),
                    ..._metodosPago.map(
                      (metodo) =>
                          DropdownMenuItem(value: metodo, child: Text(metodo)),
                    ),
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
    final bool esVentaCasual = venta.items.any(
      (item) => item['tipo'] == 'venta_casual',
    );
    final primerProducto = venta.items.isNotEmpty ? venta.items.first : null;
    final tieneMasProductos = venta.items.length > 1;

    debugPrint(
      'Venta ID: ${venta.id} - Referencia: ${venta.referenciaPago} - Método: ${venta.metodoPago} - Es casual: $esVentaCasual',
    );

    // Obtener el título de la venta
    String tituloVenta = venta.clienteNombre ?? 'Venta Casual';
    if (esVentaCasual && primerProducto != null) {
      tituloVenta =
          primerProducto['nombre_producto']?.toString() ?? 'Venta Casual';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () => _mostrarDetalleVenta(venta),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tituloVenta,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatoMoneda(venta.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (esVentaCasual && primerProducto != null) ...[
                Text(
                  '• ${primerProducto['nombre_producto']} (${primerProducto['cantidad']} x ${_formatoMoneda(primerProducto['precio_unitario'])})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (primerProducto['descripcion'] != null &&
                    primerProducto['descripcion'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 2),
                    child: Text(
                      primerProducto['descripcion'].toString(),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ] else if (primerProducto != null) ...[
                Text(
                  '• ${primerProducto['nombre_producto']} (${primerProducto['cantidad']} x ${_formatoMoneda(primerProducto['precio_unitario'])})',
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (primerProducto['descripcion'] != null &&
                    primerProducto['descripcion'].toString().isNotEmpty &&
                    primerProducto['descripcion'] !=
                        primerProducto['nombre_producto'])
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 2),
                    child: Text(
                      primerProducto['descripcion'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              if (tieneMasProductos && !esVentaCasual) ...[
                const SizedBox(height: 4),
                Text(
                  '+ ${venta.items.length - 1} producto${venta.items.length > 2 ? 's' : ''} más...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '${venta.metodoPago}${venta.referenciaPago != null && venta.referenciaPago!.isNotEmpty ? ' • ${venta.referenciaPago}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetalleVenta(Venta venta) {
    final bool esVentaCasual = venta.items.any(
      (item) => item['tipo'] == 'venta_casual',
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!esVentaCasual) ...[
            ListTile(
              title: const Text(
                'Cliente',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(venta.clienteNombre ?? 'Cliente no especificado'),
            ),
            const Divider(),
          ],
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
                if (venta.metodoPago.toLowerCase().contains('tarjeta') &&
                    venta.referenciaPago != null &&
                    venta.referenciaPago!.isNotEmpty)
                  Text(
                    '${venta.metodoPago} (Transacción: ${venta.referenciaPago})',
                  )
                else
                  Text(venta.metodoPago),
                if (venta.referenciaPago != null &&
                    venta.referenciaPago!.isNotEmpty &&
                    !venta.metodoPago.toLowerCase().contains('tarjeta'))
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              esVentaCasual ? 'Detalles de la venta' : 'Productos',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...venta.items.map(
            (item) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(
                    item['nombre_producto'] ?? 'Venta Casual',
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['cantidad']} x ${_formatoMoneda(item['precio_unitario'])}',
                      ),
                      if (item['descripcion'] != null &&
                          item['descripcion'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${item['descripcion']}',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Subtotal: ${_formatoMoneda(item['subtotal'])}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    _formatoMoneda(item['subtotal']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
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
                  _formatoMoneda(venta.total),
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
        builder: (dialogContext) => AlertDialog(
          title: Text('Detalle de Venta #${venta.id}'),
          content: _buildDetalleVenta(venta),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoCarrito,
        backgroundColor: Colors.blue,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            const Icon(Icons.shopping_cart),
            if (_carrito.isNotEmpty)
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _carrito.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

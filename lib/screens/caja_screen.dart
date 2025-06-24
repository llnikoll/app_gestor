import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../models/producto_model.dart';
import '../models/cliente_model.dart';
import '../models/venta_model.dart';
import '../models/categoria_model.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  @override
  CajaScreenState createState() => CajaScreenState();
}

class CajaScreenState extends State<CajaScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          NuevaVentaTab(
              onVentaExitosa: () => setState(() => _selectedIndex = 1)),
          const HistorialTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_shopping_cart),
            label: 'Nueva Venta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}

// Pestaña de Nueva Venta
class NuevaVentaTab extends StatefulWidget {
  final VoidCallback onVentaExitosa;
  const NuevaVentaTab({super.key, required this.onVentaExitosa});

  @override
  NuevaVentaTabState createState() => NuevaVentaTabState();
}

class NuevaVentaTabState extends State<NuevaVentaTab> {
  final TextEditingController _searchController = TextEditingController();
  late final TextEditingController _montoRecibidoController;
  String? _selectedCategory;
  List<Producto> _productos = [];
  final List<Map<String, dynamic>> _carrito = [];
  Cliente? _selectedCliente;
  String _metodoPago = 'Efectivo';
  String? _referenciaPago;
  double _montoRecibido = 0.0;

  @override
  void initState() {
    super.initState();
    _montoRecibidoController = TextEditingController();
    _loadProductos();
    _loadCategorias();
  }

  @override
  void dispose() {
    _montoRecibidoController.dispose();
    super.dispose();
  }

  Future<void> _loadProductos() async {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    final productos =
        await databaseService.getProductos(categoria: _selectedCategory);
    setState(() => _productos = productos);
  }

  Future<void> _loadCategorias() async {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    final categorias = await databaseService.getCategorias();
    setState(() => _selectedCategory ??=
        categorias.isNotEmpty ? categorias.first.nombre : 'Todas');
  }

  void _filtrarProductos(String query) {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    databaseService.buscarProductos(query).then((productos) {
      setState(() => _productos = productos
          .where((p) =>
              _selectedCategory == null || p.categoria == _selectedCategory)
          .toList());
    });
  }

  void _agregarAlCarrito(Producto producto) {
    setState(() {
      final existingItem = _carrito.firstWhere(
        (item) => item['producto'].id == producto.id,
        orElse: () => {},
      );
      if (existingItem.isNotEmpty) {
        existingItem['cantidad'] += 1;
      } else {
        _carrito.add({'producto': producto, 'cantidad': 1});
      }
    });
  }

  void _agregarVentaCasual() {
    showDialog(
      context: context,
      builder: (context) {
        double monto = 0.0;
        String descripcion = '';
        return AlertDialog(
          title: const Text('Venta Casual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Monto'),
                keyboardType: TextInputType.number,
                onChanged: (value) => monto = double.tryParse(value) ?? 0.0,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Descripción'),
                onChanged: (value) => descripcion = value,
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
                if (monto > 0) {
                  setState(() {
                    _carrito.add({
                      'producto': null,
                      'cantidad': 1,
                      'monto': monto,
                      'descripcion':
                          descripcion.isEmpty ? 'Venta Casual' : descripcion,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarCarrito() {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El carrito está vacío')));
      return;
    }
    // Resetear el controlador al abrir el diálogo
    _montoRecibidoController.text =
        _montoRecibido > 0 ? _montoRecibido.toString() : '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final total = _carrito.fold<double>(
            0,
            (sum, item) =>
                sum +
                (item['producto'] != null
                    ? item['producto'].precioVenta * item['cantidad']
                    : item['monto']),
          );
          return AlertDialog(
            title: const Text('Carrito'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var item in _carrito)
                    ListTile(
                      title:
                          Text(item['producto']?.nombre ?? item['descripcion']),
                      subtitle: Text(
                          'Cantidad: ${item['cantidad']} - Subtotal: ${NumberFormat.currency(symbol: Provider.of<SettingsService>(context, listen: false).currentCurrency.symbol).format(item['producto'] != null ? item['producto'].precioVenta * item['cantidad'] : item['monto'])}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                setDialogState(() {
                                  if (item['cantidad'] > 1) {
                                    item['cantidad'] -= 1;
                                  } else {
                                    _carrito.remove(item);
                                  }
                                });
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                setDialogState(() => _carrito.remove(item));
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ListTile(
                    title: const Text('Cliente'),
                    subtitle: Text(_selectedCliente?.nombre ?? 'Ninguno'),
                    onTap: () => _seleccionarCliente(setDialogState),
                  ),
                  DropdownButton<String>(
                    value: _metodoPago,
                    items: const [
                      DropdownMenuItem(
                          value: 'Efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(
                          value: 'Tarjeta de Crédito',
                          child: Text('Tarjeta de Crédito')),
                      DropdownMenuItem(
                          value: 'Tarjeta de Débito',
                          child: Text('Tarjeta de Débito')),
                      DropdownMenuItem(
                          value: 'Transferencia', child: Text('Transferencia')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _metodoPago = value!),
                  ),
                  if (_metodoPago != 'Efectivo')
                    TextField(
                      decoration: const InputDecoration(
                          labelText: 'Número de Transacción'),
                      onChanged: (value) => _referenciaPago = value,
                    ),
                  const Divider(),
                  ListTile(
                    title: const Text('Total:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    trailing: Text(
                      NumberFormat.currency(
                        symbol:
                            Provider.of<SettingsService>(context, listen: false)
                                .currentCurrency
                                .symbol,
                        decimalDigits:
                            Provider.of<SettingsService>(context, listen: false)
                                .currentCurrency
                                .decimalDigits,
                      ).format(total),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  if (_metodoPago == 'Efectivo') ...[
                    if (_montoRecibido > 0) ...[
                      ListTile(
                        title: Text(
                          _montoRecibido >= total ? 'Vuelto:' : 'Falta:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _montoRecibido >= total
                                ? Colors.green
                                : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                        trailing: Text(
                          NumberFormat.currency(
                            symbol: Provider.of<SettingsService>(context,
                                    listen: false)
                                .currentCurrency
                                .symbol,
                            decimalDigits: Provider.of<SettingsService>(context,
                                    listen: false)
                                .currentCurrency
                                .decimalDigits,
                          ).format((_montoRecibido - total).abs()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _montoRecibido >= total
                                ? Colors.green
                                : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Monto Recibido',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: _montoRecibidoController,
                      onChanged: (value) {
                        final monto = double.tryParse(value) ?? 0.0;
                        // Actualizamos el estado del widget padre
                        setState(() {
                          _montoRecibido = monto;
                        });
                        // Forzamos la actualización del diálogo
                        setDialogState(() {});
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => _confirmarVenta(total),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _seleccionarCliente(void Function(void Function()) setDialogState) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar Cliente'),
          content: FutureBuilder<List<Cliente>>(
            future: Provider.of<DatabaseService>(context, listen: false)
                .getClientes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final clientes = snapshot.data!;
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: clientes.length,
                  itemBuilder: (context, index) {
                    final cliente = clientes[index];
                    return ListTile(
                      title: Text(cliente.nombre),
                      subtitle: Text(cliente.ruc ?? cliente.telefono ?? ''),
                      onTap: () {
                        setState(() =>
                            setDialogState(() => _selectedCliente = cliente));
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  // Método para reiniciar el formulario después de una venta exitosa
  void _resetearFormulario() {
    setState(() {
      _carrito.clear();
      _selectedCliente = null;
      _metodoPago = 'Efectivo';
      _referenciaPago = null;
      _montoRecibido = 0.0;
    });
  }

  Future<void> _confirmarVenta(double total) async {
    // Validación inicial
    if (_metodoPago == 'Efectivo' && _montoRecibido < total) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monto recibido insuficiente')),
      );
      return;
    }

    // Obtener servicios necesarios
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);

    // Crear objeto de venta
    final venta = Venta(
      clienteId: _selectedCliente?.id,
      clienteNombre: _selectedCliente?.nombre,
      total: total,
      metodoPago: _metodoPago,
      referenciaPago: _metodoPago != 'Efectivo' ? _referenciaPago : null,
      items: _carrito.map((item) {
        final producto = item['producto'] as Producto?;
        final cantidad = item['cantidad'] as int;
        final monto = item['monto'] as double?;
        final descripcion = item['descripcion'] as String?;

        return {
          'producto_id': producto?.id,
          'cantidad': cantidad,
          'precio_unitario': producto?.precioVenta ?? monto ?? 0.0,
          'subtotal': producto != null
              ? producto.precioVenta * cantidad
              : (monto ?? 0.0) * cantidad,
          'descripcion':
              descripcion, // Guardar en 'descripcion' para compatibilidad
          'notas':
              descripcion, // También guardar en 'notas' para compatibilidad con código existente
        };
      }).toList(),
    );

    try {
      // Insertar la venta en la base de datos
      await databaseService.insertVenta(venta);
      if (!mounted) return;

      // Notificar el cambio
      databaseService.notifyDataChanged();

      // Cerrar el diálogo antes de actualizar la UI
      if (mounted) {
        Navigator.pop(context);
      }

      // Actualizar la UI
      _resetearFormulario();

      // Notificar a la pestaña principal para que actualice el historial
      if (mounted) {
        widget.onVentaExitosa();
      }

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venta registrada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar la venta: $e')),
        );
      }
    }
  }

  void _escanearCodigoBarras() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (result != null) {
      _searchController.text = result;
      _filtrarProductos(result);
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar producto',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _loadProductos();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _escanearCodigoBarras,
                  ),
                ],
              ),
            ),
            onChanged: _filtrarProductos,
          ),
          FutureBuilder<List<Categoria>>(
            future: Provider.of<DatabaseService>(context, listen: false)
                .getCategorias(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final categorias = snapshot.data!;
              return DropdownButton<String>(
                value: _selectedCategory,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ...categorias.map((c) =>
                      DropdownMenuItem(value: c.nombre, child: Text(c.nombre))),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                  _loadProductos();
                },
              );
            },
          ),
          ElevatedButton(
            onPressed: _agregarVentaCasual,
            child: const Text('Venta Casual'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _productos.length,
              itemBuilder: (context, index) {
                final producto = _productos[index];
                return ListTile(
                  leading: producto.imagenUrl != null
                      ? Image.network(producto.imagenUrl!,
                          width: 50,
                          height: 50,
                          errorBuilder: (_, __, ___) => const Icon(Icons.error))
                      : const Icon(Icons.error),
                  title: Text(producto.nombre),
                  subtitle: Text(
                      '${NumberFormat.currency(symbol: Provider.of<SettingsService>(context, listen: false).currentCurrency.symbol).format(producto.precioVenta)} - Stock: ${producto.stock}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _agregarAlCarrito(producto),
                  ),
                );
              },
            ),
          ),
          FloatingActionButton(
            onPressed: _mostrarCarrito,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.shopping_cart),
                if (_carrito.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.red,
                      child: Text(
                        _carrito.length.toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pantalla de Escaneo de Códigos de Barras
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear Código')),
      body: MobileScanner(
        onDetect: (barcodeCapture) {
          if (barcodeCapture.barcodes.isNotEmpty) {
            final barcode = barcodeCapture.barcodes.first;
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
            }
          }
        },
        errorBuilder: (context, error) => Center(
          child: Text('Error al escanear: $error'),
        ),
      ),
    );
  }
}

// Pestaña de Historial
class HistorialTab extends StatefulWidget {
  const HistorialTab({super.key});

  @override
  HistorialTabState createState() => HistorialTabState();
}

class HistorialTabState extends State<HistorialTab> {
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();
  String _metodoPagoFiltro = 'Todos los métodos';
  List<Venta> _ventas = [];
  late final DatabaseService _databaseService;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadVentas();
  }

  // Usar un listener para actualizar cuando cambien los datos
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Asegurarse de que solo agregamos el listener una vez
    _databaseService.removeListener(_loadVentas);
    _databaseService.addListener(_loadVentas);
  }

  @override
  void dispose() {
    // Remover el listener cuando el widget se desmonte
    _databaseService.removeListener(_loadVentas);
    super.dispose();
  }

  // Método auxiliar para construir filas de información en el diálogo
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  bool _isLoading = false;

  Future<void> _loadVentas() async {
    // Evitar múltiples cargas simultáneas
    if (_isLoading) return;

    _isLoading = true;

    try {
      debugPrint('Cargando ventas...');
      final ventas = await _databaseService.getVentasPorRangoFechas(
        _fechaInicio.subtract(
            const Duration(hours: 1)), // Un poco de margen para la zona horaria
        _fechaFin.add(const Duration(days: 1)), // Incluir todo el día
      );

      debugPrint('Ventas cargadas: ${ventas.length}');

      // Filtrar por método de pago si no es 'Todos los métodos'
      List<Venta> ventasFiltradas = ventas;
      if (_metodoPagoFiltro != 'Todos los métodos') {
        ventasFiltradas =
            ventas.where((v) => v.metodoPago == _metodoPagoFiltro).toList();
      }

      // Ordenar por fecha descendente (más reciente primero)
      ventasFiltradas.sort((a, b) => b.fecha.compareTo(a.fecha));

      // Solo actualizar el estado si el widget sigue montado
      if (mounted) {
        setState(() {
          _ventas = ventasFiltradas;
          debugPrint('Ventas actualizadas: ${_ventas.length}');
        });
      }
    } catch (e) {
      // Manejar el error de manera apropiada
      debugPrint('Error al cargar ventas: $e');

      // Si hay un error, podemos mostrar un mensaje al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al cargar el historial: ${e.toString()}')),
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: _fechaInicio,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (selectedDate != null) {
                    setState(() => _fechaInicio = selectedDate);
                    _loadVentas();
                  }
                },
                child: Text(
                    'Inicio: ${DateFormat('dd/MM/yyyy').format(_fechaInicio)}'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: _fechaFin,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (selectedDate != null) {
                    setState(() => _fechaFin = selectedDate);
                    _loadVentas();
                  }
                },
                child:
                    Text('Fin: ${DateFormat('dd/MM/yyyy').format(_fechaFin)}'),
              ),
            ],
          ),
          DropdownButton<String>(
            value: _metodoPagoFiltro,
            items: const [
              DropdownMenuItem(
                  value: 'Todos los métodos', child: Text('Todos los métodos')),
              DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
              DropdownMenuItem(
                  value: 'Tarjeta de Crédito',
                  child: Text('Tarjeta de Crédito')),
              DropdownMenuItem(
                  value: 'Tarjeta de Débito', child: Text('Tarjeta de Débito')),
              DropdownMenuItem(
                  value: 'Transferencia', child: Text('Transferencia')),
            ],
            onChanged: (value) {
              setState(() => _metodoPagoFiltro = value!);
              _loadVentas();
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _ventas.length,
              itemBuilder: (context, index) {
                final venta = _ventas[index];
                // Verificar si es una venta casual (sin cliente y con un solo ítem)
                final isVentaCasual =
                    venta.clienteNombre == null && venta.items.length == 1;
                final descripcionVenta = isVentaCasual
                    ? (venta.items.first['descripcion'] ?? 'Venta Casual')
                    : (venta.clienteNombre ?? 'Venta Casual');

                // Mostrar el método de pago con referencia si existe
                String metodoPagoText = venta.metodoPago;
                if (venta.referenciaPago != null &&
                    venta.referenciaPago!.isNotEmpty) {
                  metodoPagoText += ' #${venta.referenciaPago}';
                }

                return ListTile(
                  title: Text(
                    descripcionVenta,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${venta.totalFormateado} • ${venta.fechaFormateada}'),
                      Text(
                        metodoPagoText,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  trailing: venta.items.length > 1
                      ? const Icon(Icons.expand_more)
                      : null,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Detalles de la Venta',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildInfoRow('Cliente:',
                                  venta.clienteNombre ?? 'Venta Casual'),
                              _buildInfoRow('Fecha:', venta.fechaFormateada),
                              _buildInfoRow('Método de Pago:',
                                  '${venta.metodoPago}${venta.referenciaPago != null ? ' #${venta.referenciaPago}' : ''}'),

                              // Mostrar descripción de la venta casual si existe
                              ...(venta.clienteNombre == null &&
                                      venta.items.isNotEmpty
                                  ? (() {
                                      final item = venta.items.first;
                                      final descripcion = item['descripcion'] ??
                                          item['notas'] ??
                                          item['nombre_producto'];

                                      if (descripcion != null &&
                                          descripcion != 'Venta Casual') {
                                        return [
                                          _buildInfoRow('Descripción:',
                                              descripcion.toString())
                                        ];
                                      }
                                      return <Widget>[];
                                    })()
                                  : <Widget>[]),

                              const SizedBox(height: 16),
                              const Text('Productos:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const Divider(),
                              ...venta.items.map((item) {
                                final productoNombre = item['nombre_producto'];
                                // Usar la descripción del ítem si está disponible, de lo contrario usar 'Venta Casual'
                                final descripcion = item['descripcion'] ??
                                    item['notas'] ??
                                    'Venta Casual';
                                final cantidad = item['cantidad'];
                                final subtotal = item['subtotal'];
                                final currencySymbol =
                                    Provider.of<SettingsService>(context,
                                            listen: false)
                                        .currentCurrency
                                        .symbol;

                                // Determinar el texto a mostrar como título del ítem
                                String tituloItem =
                                    productoNombre ?? descripcion;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tituloItem,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$cantidad x ${NumberFormat.currency(symbol: currencySymbol).format(subtotal / cantidad)} = ${NumberFormat.currency(symbol: currencySymbol).format(subtotal)}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    // Mostrar notas adicionales si existen y son diferentes al nombre
                                    if (descripcion != 'Venta Casual' &&
                                        productoNombre != null &&
                                        descripcion != productoNombre)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4.0, left: 8.0),
                                        child: Text(
                                          descripcion,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    const Divider(),
                                  ],
                                );
                              }),

                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  Text(
                                    venta.totalFormateado,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

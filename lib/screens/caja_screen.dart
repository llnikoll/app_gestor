import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    // Filtrar para excluir la categoría 'generales' (ignorando mayúsculas/minúsculas)
    final categoriasFiltradas = categorias
        .where((c) => c.nombre.toLowerCase() != 'generales')
        .toList();
    setState(() => _selectedCategory = 
        categoriasFiltradas.isNotEmpty ? categoriasFiltradas.first.nombre : null);
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

  String formatearNumero(String value) {
    if (value.isEmpty) return '';

    // Separar parte entera y decimal
    final parts = value.split(',');
    String parteEntera = parts[0];
    String parteDecimal = parts.length > 1 ? ',${parts[1]}' : '';

    // Agregar puntos de miles a la parte entera
    String resultado = '';
    int contador = 0;

    for (int i = parteEntera.length - 1; i >= 0; i--) {
      resultado = parteEntera[i] + resultado;
      contador++;
      if (contador == 3 && i > 0) {
        resultado = '.$resultado';
        contador = 0;
      }
    }

    return resultado + parteDecimal;
  }

  void _agregarVentaCasual() {
    showDialog(
      context: context,
      builder: (context) {
        double monto = 0.0;
        String descripcion = '';
        final settingsService =
            Provider.of<SettingsService>(context, listen: false);
        final currencySymbol = settingsService.currentCurrency.symbol;

        // Controlador para el campo de monto con formato
        final montoController = TextEditingController();

        void actualizarMonto(String value) {
          // Si el valor está vacío, limpiar todo
          if (value.isEmpty) {
            monto = 0.0;
            montoController.text = '';
            return;
          }

          // Obtener solo números y comas
          String cleanValue = value.replaceAll(RegExp(r'[^\d,]'), '');

          // Validar que no haya más de una coma
          final parts = cleanValue.split(',');
          if (parts.length > 2) {
            // Si hay más de una coma, mantener solo la primera
            cleanValue = '${parts[0]},${parts[1]}';
          }

          // Limitar a 2 decimales después de la coma
          if (parts.length == 2 && parts[1].length > 2) {
            cleanValue = '${parts[0]},${parts[1].substring(0, 2)}';
          }

          // Formatear el número con puntos de miles
          String formattedValue = formatearNumero(cleanValue);

          // Actualizar el controlador con el cursor al final
          montoController.value = TextEditingValue(
            text: formattedValue,
            selection: TextSelection.collapsed(offset: formattedValue.length),
          );

          // Actualizar el valor numérico
          if (cleanValue.isNotEmpty) {
            monto = double.tryParse(
                    cleanValue.replaceAll('.', '').replaceAll(',', '.')) ??
                0.0;
          } else {
            monto = 0.0;
          }
        }

        return AlertDialog(
          title: const Text('Venta Casual'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: montoController,
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    border: const OutlineInputBorder(),
                    prefixText: '$currencySymbol ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: actualizarMonto,
                  inputFormatters: [
                    // Permitir solo números y comas
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
                    // Validar el formato
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      // Permitir siempre el borrado
                      if (newValue.text.length < oldValue.text.length) {
                        return newValue;
                      }

                      final text = newValue.text;

                      // No permitir comenzar con coma
                      if (text.startsWith(',')) return oldValue;

                      // No permitir múltiples comas
                      if ((text.split(',').length - 1) > 1) return oldValue;

                      // Limitar a 2 decimales después de la coma
                      final parts = text.split(',');
                      if (parts.length == 2 && parts[1].length > 2) {
                        return oldValue;
                      }

                      return newValue;
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                    hintText: 'Ingrese una descripción para esta venta',
                  ),
                  maxLines: 3,
                  onChanged: (value) => descripcion = value.trim(),
                ),
              ],
            ),
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
                      'notas':
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

    // Obtener la configuración de moneda actual
    final settingsService =
        Provider.of<SettingsService>(context, listen: false);
    final currencySymbol = settingsService.currentCurrency.symbol;
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: settingsService.currentCurrency.decimalDigits,
      locale: settingsService.currentCurrency.locale,
    );

    // Resetear el controlador al abrir el diálogo
    _montoRecibidoController.text = _montoRecibido > 0
        ? _montoRecibido
            .toStringAsFixed(settingsService.currentCurrency.decimalDigits)
        : '';

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
                    Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 0),
                      child: ListTile(
                        leading: item['producto']?.imagenUrl != null &&
                                item['producto'].imagenUrl.toString().isNotEmpty
                            ? Container(
                                width: 60,
                                height: 60,
                                padding: const EdgeInsets.all(4.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: item['producto'].imagenUrl.toString().startsWith('http')
                                      ? CachedNetworkImage(
                                          imageUrl: item['producto'].imagenUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2.0),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/${item['producto'].imagenUrl}',
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                                          ),
                                        ),
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: const Center(
                                  child: Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 28),
                                ),
                              ),
                        title: Text(
                          item['producto']?.nombre ?? item['descripcion'],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cantidad: ${item['cantidad']}'),
                            Text(
                              'Subtotal: ${formatter.format(item['producto'] != null ? item['producto'].precioVenta * item['cantidad'] : item['monto'])}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
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
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  setDialogState(() => _carrito.remove(item));
                                });
                              },
                            ),
                          ],
                        ),
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
                      formatter.format(total),
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
                          formatter.format((_montoRecibido - total).abs()),
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
                      decoration: InputDecoration(
                        labelText: 'Monto Recibido',
                        border: const OutlineInputBorder(),
                        prefixText: '$currencySymbol ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      controller: _montoRecibidoController,
                      onChanged: (value) {
                        // Si el valor está vacío, limpiar todo
                        if (value.isEmpty) {
                          setState(() {
                            _montoRecibido = 0.0;
                            _montoRecibidoController.text = '';
                          });
                          setDialogState(() {});
                          return;
                        }

                        // Obtener solo números y comas
                        String cleanValue =
                            value.replaceAll(RegExp(r'[^\d,]'), '');

                        // Validar que no haya más de una coma
                        final parts = cleanValue.split(',');
                        if (parts.length > 2) {
                          // Si hay más de una coma, mantener solo la primera
                          cleanValue = '${parts[0]},${parts[1]}';
                        }

                        // Limitar a 2 decimales después de la coma
                        if (parts.length == 2 && parts[1].length > 2) {
                          cleanValue =
                              '${parts[0]},${parts[1].substring(0, 2)}';
                        }

                        // Formatear el número con puntos de miles
                        String formattedValue = formatearNumero(cleanValue);

                        // Actualizar el controlador
                        _montoRecibidoController.value = TextEditingValue(
                          text: formattedValue,
                          selection: TextSelection.collapsed(
                              offset: formattedValue.length),
                        );

                        // Actualizar el valor numérico
                        if (cleanValue.isNotEmpty) {
                          _montoRecibido = double.tryParse(cleanValue
                                  .replaceAll('.', '')
                                  .replaceAll(',', '.')) ??
                              0.0;
                        } else {
                          _montoRecibido = 0.0;
                        }

                        // Forzar la actualización del diálogo
                        setDialogState(() {});
                      },
                      inputFormatters: [
                        // Permitir solo números y comas
                        FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
                        // Validar el formato
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          // Permitir siempre el borrado
                          if (newValue.text.length < oldValue.text.length) {
                            return newValue;
                          }

                          final text = newValue.text;

                          // No permitir comenzar con coma
                          if (text.startsWith(',')) return oldValue;

                          // No permitir múltiples comas
                          if ((text.split(',').length - 1) > 1) return oldValue;

                          // Limitar a 2 decimales después de la coma
                          final parts = text.split(',');
                          if (parts.length == 2 && parts[1].length > 2) {
                            return oldValue;
                          }

                          return newValue;
                        }),
                      ],
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
        final notas = item['notas'] as String?;
        final esVentaCasual = producto == null && descripcion != null;

        // Para ventas casuales, usar la descripción como nombre del producto
        final nombreProducto = esVentaCasual
            ? (descripcion.isNotEmpty ? descripcion : 'Venta Casual')
            : producto?.nombre;

        // Para ventas casuales, usar el monto como precio unitario
        final precioUnitario =
            esVentaCasual ? (monto ?? 0.0) : (producto?.precioVenta ?? 0.0);

        // Para ventas casuales, el subtotal es el monto * cantidad
        final subtotal = esVentaCasual
            ? (monto ?? 0.0) * cantidad
            : (producto?.precioVenta ?? 0.0) * cantidad;

        return {
          'producto_id': producto?.id,
          'cantidad': cantidad,
          'precio_unitario': precioUnitario,
          'subtotal': subtotal,
          'nombre_producto': nombreProducto,
          'descripcion': descripcion ?? 'Venta casual',
          'notas': notas ?? descripcion ?? 'Venta casual',
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
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                  child: InkWell(
                    onTap: () => _agregarAlCarrito(producto),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      leading: producto.imagenUrl != null && producto.imagenUrl!.isNotEmpty
                          ? Container(
                              width: 60,
                              height: 60,
                              padding: const EdgeInsets.all(4.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: producto.imagenUrl!.startsWith('http')
                                    ? CachedNetworkImage(
                                        imageUrl: producto.imagenUrl!,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(strokeWidth: 2.0),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/${producto.imagenUrl}',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                                        ),
                                      ),
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: const Center(
                                child: Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 28),
                              ),
                            ),
                      title: Text(
                        producto.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${NumberFormat.currency(symbol: Provider.of<SettingsService>(context, listen: false).currentCurrency.symbol).format(producto.precioVenta)} - Stock: ${producto.stock}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                        onPressed: () => _agregarAlCarrito(producto),
                      ),
                    ),
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
  bool _soloVentasCasuales = false;
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
      // Ajustar fechas para incluir todo el rango
      final fechaInicio =
          DateTime(_fechaInicio.year, _fechaInicio.month, _fechaInicio.day);
      final fechaFin =
          DateTime(_fechaFin.year, _fechaFin.month, _fechaFin.day, 23, 59, 59);

      debugPrint(
          'Buscando ventas desde ${fechaInicio.toIso8601String()} hasta ${fechaFin.toIso8601String()}');

      final ventas = await _databaseService.getVentasPorRangoFechas(
        fechaInicio,
        fechaFin,
      );

      debugPrint('Ventas cargadas: ${ventas.length}');

      // Filtrar por método de pago si no es 'Todos los métodos'
      List<Venta> ventasFiltradas = ventas;
      if (_metodoPagoFiltro != 'Todos los métodos') {
        ventasFiltradas =
            ventas.where((v) => v.metodoPago == _metodoPagoFiltro).toList();
      }

      // Filtrar por tipo de venta (casual o no)
      if (_soloVentasCasuales) {
        ventasFiltradas = ventasFiltradas
            .where((v) => v.clienteNombre == 'Venta Casual')
            .toList();
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historial de Ventas'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.receipt), text: 'Todas'),
              Tab(icon: Icon(Icons.person), text: 'Por Cliente'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
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
                        child: Text(
                            'Fin: ${DateFormat('dd/MM/yyyy').format(_fechaFin)}'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _metodoPagoFiltro,
                          items: const [
                            DropdownMenuItem(
                              value: 'Todos los métodos',
                              child: Text('Todos los métodos'),
                            ),
                            DropdownMenuItem(
                              value: 'Efectivo',
                              child: Text('Efectivo'),
                            ),
                            DropdownMenuItem(
                              value: 'Tarjeta de Crédito',
                              child: Text('Tarjeta de Crédito'),
                            ),
                            DropdownMenuItem(
                              value: 'Transferencia',
                              child: Text('Transferencia'),
                            ),
                            DropdownMenuItem(
                              value: 'Débito',
                              child: Text('Débito'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _metodoPagoFiltro = value);
                              _loadVentas();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: 'Mostrar solo ventas casuales',
                        child: FilterChip(
                          label: const Text('Casuales'),
                          selected: _soloVentasCasuales,
                          onSelected: (selected) {
                            setState(() => _soloVentasCasuales = selected);
                            _loadVentas();
                          },
                          backgroundColor: _soloVentasCasuales
                              ? Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.2)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                      child: ListView.builder(
                    itemCount: _ventas.length,
                    itemBuilder: (context, index) {
                      final venta = _ventas[index];
                      // Verificar si es una venta casual (sin cliente y con un solo ítem)
                      final isVentaCasual = venta.clienteNombre == null &&
                          venta.items.length == 1;
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
                            Text('${NumberFormat.currency(
                              symbol: Provider.of<SettingsService>(context,
                                      listen: false)
                                  .currentCurrency
                                  .symbol,
                              decimalDigits: Provider.of<SettingsService>(
                                      context,
                                      listen: false)
                                  .currentCurrency
                                  .decimalDigits,
                              locale: Provider.of<SettingsService>(context,
                                      listen: false)
                                  .currentCurrency
                                  .locale,
                            ).format(venta.total)} • ${venta.fechaFormateada}'),
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
                          // Calculate sale details
                          final saleDetails =
                              _calculateSaleDetails(venta.items, context);
                          final currencyFormat =
                              saleDetails['currencyFormat'] as NumberFormat;
                          final subtotal = saleDetails['subtotal'] as double;
                          final totalDiscount =
                              saleDetails['totalDiscount'] as double;
                          final hasDiscount =
                              saleDetails['hasDiscount'] as bool;

                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Detalles de la Venta',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildInfoRow('Cliente:',
                                        venta.clienteNombre ?? 'Venta Casual'),
                                    _buildInfoRow(
                                        'Fecha:', venta.fechaFormateada),
                                    _buildInfoRow('Método de Pago:',
                                        '${venta.metodoPago}${venta.referenciaPago != null ? ' #${venta.referenciaPago}' : ''}'),

                                    // Mostrar descripción de la venta casual si existe
                                    if (venta.clienteNombre == null &&
                                        venta.items.isNotEmpty)
                                      for (final item in venta.items)
                                        if (item['descripcion'] != null &&
                                            item['descripcion'] !=
                                                'Venta Casual')
                                          _buildInfoRow('Descripción:',
                                              item['descripcion'].toString()),
                                    const SizedBox(height: 8),

                                    const SizedBox(height: 16),
                                    const Text('Productos:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const Divider(),
                                    ...venta.items.map((item) {
                                      final productoNombre =
                                          item['nombre_producto'];
                                      final descripcion = item['descripcion'] ??
                                          item['notas'] ??
                                          'Venta Casual';
                                      final cantidad = item['cantidad'];
                                      final subtotal = item['subtotal'];
                                      final settingsService =
                                          Provider.of<SettingsService>(context,
                                              listen: false);
                                      final formatter = NumberFormat.currency(
                                        symbol: settingsService
                                            .currentCurrency.symbol,
                                        decimalDigits: settingsService
                                            .currentCurrency.decimalDigits,
                                        locale: settingsService
                                            .currentCurrency.locale,
                                      );

                                      return ListTile(
                                        title:
                                            Text('$productoNombre x $cantidad'),
                                        subtitle: Text(descripcion),
                                        trailing:
                                            Text(formatter.format(subtotal)),
                                      );
                                    }),
                                    const SizedBox(height: 16),
                                    _buildInfoRow('Subtotal:',
                                        currencyFormat.format(subtotal)),
                                    if (hasDiscount && totalDiscount > 0)
                                      _buildInfoRow('Descuento:',
                                          '-${currencyFormat.format(totalDiscount)}'),
                                    _buildInfoRow(
                                      'Total:',
                                      NumberFormat.currency(
                                        symbol: Provider.of<SettingsService>(
                                                context,
                                                listen: false)
                                            .currentCurrency
                                            .symbol,
                                        decimalDigits:
                                            Provider.of<SettingsService>(
                                                    context,
                                                    listen: false)
                                                .currentCurrency
                                                .decimalDigits,
                                        locale: Provider.of<SettingsService>(
                                                context,
                                                listen: false)
                                            .currentCurrency
                                            .locale,
                                      ).format(venta.total),
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
                  )),
                ],
              ),
            ),
            // Vista de ventas por cliente
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // Filtros de fecha
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
                        child: Text(
                            'Fin: ${DateFormat('dd/MM/yyyy').format(_fechaFin)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Lista de clientes con ventas
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getVentasAgrupadasPorCliente(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('No hay ventas por cliente'));
                        }

                        final clientesConVentas = snapshot.data!;
                        return ListView.builder(
                          itemCount: clientesConVentas.length,
                          itemBuilder: (context, index) {
                            final cliente = clientesConVentas[index];
                            final ventas = cliente['ventas'] as List<Venta>;
                            final totalVentas = ventas.fold(
                                0.0, (sum, venta) => sum + venta.total);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4.0, horizontal: 8.0),
                              child: ExpansionTile(
                                title: Text(
                                  cliente['nombre'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${ventas.length} ventas • Total: ${NumberFormat.currency(
                                    symbol: Provider.of<SettingsService>(
                                            context,
                                            listen: false)
                                        .currentCurrency
                                        .symbol,
                                    decimalDigits: 2,
                                  ).format(totalVentas)}',
                                ),
                                children: ventas.map((venta) {
                                  return ListTile(
                                    title: Text(
                                      '${DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha)} • ${venta.metodoPago}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    trailing: Text(
                                      NumberFormat.currency(
                                        symbol: Provider.of<SettingsService>(
                                                context,
                                                listen: false)
                                            .currentCurrency
                                            .symbol,
                                        decimalDigits: 2,
                                      ).format(venta.total),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    onTap: () {
                                      // Mostrar detalles de la venta
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title:
                                              const Text('Detalles de Venta'),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                    'Cliente: ${cliente['nombre']}'),
                                                Text(
                                                    'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha)}'),
                                                Text(
                                                    'Método de pago: ${venta.metodoPago}'),
                                                if (venta.referenciaPago !=
                                                        null &&
                                                    venta.referenciaPago!
                                                        .isNotEmpty)
                                                  Text(
                                                      'Referencia: ${venta.referenciaPago}'),
                                                const SizedBox(height: 16),
                                                const Text('Productos:',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                ...venta.items.map((item) =>
                                                    ListTile(
                                                      title: Text(
                                                          '${item['nombre_producto']} x${item['cantidad']}'),
                                                      trailing: Text(
                                                        NumberFormat.currency(
                                                          symbol: Provider.of<
                                                                      SettingsService>(
                                                                  context,
                                                                  listen: false)
                                                              .currentCurrency
                                                              .symbol,
                                                          decimalDigits: 2,
                                                        ).format(item[
                                                                'precio_unitario'] *
                                                            item['cantidad']),
                                                      ),
                                                    )),
                                                const Divider(),
                                                Text(
                                                  'Total: ${NumberFormat.currency(
                                                    symbol: Provider.of<
                                                                SettingsService>(
                                                            context,
                                                            listen: false)
                                                        .currentCurrency
                                                        .symbol,
                                                    decimalDigits: 2,
                                                  ).format(venta.total)}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cerrar'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Obtener ventas agrupadas por cliente
  Future<List<Map<String, dynamic>>> _getVentasAgrupadasPorCliente() async {
    try {
      // Obtener todas las ventas en el rango de fechas
      final ventas = await _databaseService.getVentasPorRangoFechas(
        _fechaInicio.subtract(const Duration(hours: 1)),
        _fechaFin.add(const Duration(days: 1)),
      );

      // Filtrar por método de pago si no es 'Todos los métodos'
      List<Venta> ventasFiltradas = ventas;
      if (_metodoPagoFiltro != 'Todos los métodos') {
        ventasFiltradas =
            ventas.where((v) => v.metodoPago == _metodoPagoFiltro).toList();
      }

      // Agrupar ventas por cliente
      final Map<String, Map<String, dynamic>> clientesMap = {};

      for (final venta in ventasFiltradas) {
        final clienteId = venta.clienteId?.toString() ?? 'sin_cliente';
        final clienteNombre = venta.clienteNombre ?? 'Cliente Ocasional';

        if (!clientesMap.containsKey(clienteId)) {
          clientesMap[clienteId] = {
            'id': clienteId,
            'nombre': clienteNombre,
            'ventas': <Venta>[],
          };
        }

        clientesMap[clienteId]!['ventas'].add(venta);
      }

      // Convertir el mapa a lista y ordenar por nombre de cliente
      final clientesList = clientesMap.values.toList();
      clientesList.sort((a, b) => (a['nombre'] as String)
          .toLowerCase()
          .compareTo((b['nombre'] as String).toLowerCase()));

      // Ordenar las ventas de cada cliente por fecha (más reciente primero)
      for (final cliente in clientesList) {
        final ventasCliente = cliente['ventas'] as List<Venta>;
        ventasCliente.sort((a, b) => b.fecha.compareTo(a.fecha));
      }

      return clientesList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error al agrupar ventas por cliente: $e');
      return [];
    }
  }

  // Helper method to calculate sale details
  Map<String, dynamic> _calculateSaleDetails(
      List<Map<String, dynamic>> items, BuildContext context) {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final currencyFormat = NumberFormat.currency(
      symbol: settings.currentCurrency.symbol,
      decimalDigits: settings.currentCurrency.decimalDigits,
      locale: settings.currentCurrency.locale,
    );

    double subtotal = 0;
    double totalDiscount = 0;
    bool hasDiscount = false;

    for (final item in items) {
      // Calculate subtotal
      final precioUnitario = item['precio_unitario'] is double
          ? item['precio_unitario'] as double
          : (item['precio_unitario'] as num).toDouble();
      final cantidad = item['cantidad'] is int
          ? item['cantidad'] as int
          : (item['cantidad'] as num).toInt();
      subtotal += (precioUnitario * cantidad);

      // Calculate discount if it exists
      if (item['descuento'] != null) {
        final descuento = item['descuento'] is double
            ? item['descuento'] as double
            : ((item['descuento'] as num).toDouble());
        if (descuento > 0) {
          totalDiscount += descuento;
          hasDiscount = true;
        }
      }
    }

    return {
      'subtotal': subtotal,
      'totalDiscount': totalDiscount,
      'hasDiscount': hasDiscount,
      'currencyFormat': currencyFormat,
    };
  }
}

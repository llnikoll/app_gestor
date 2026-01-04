import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../widgets/product_image_viewer.dart';
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
        toolbarHeight: 0, // Altura reducida
        elevation: 0, // Sin sombra
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
  final TextEditingController _referenciaPagoController =
      TextEditingController();
  final NumberFormat formatter = NumberFormat.currency(
    locale: 'es_PY',
    symbol: '₲ ',
    decimalDigits: 0,
  );
  String? _selectedCategory = 'Todas';
  String _metodoPago = 'Efectivo';
  double _montoRecibido = 0.0;
  List<Producto> _productos = [];
  final List<Map<String, dynamic>> _carrito = [];
  Cliente? _selectedCliente;

  @override
  void initState() {
    super.initState();
    _montoRecibidoController = TextEditingController();
    _loadProductos();
  }

  bool _puedeProcesarVenta() {
    // Verificar que se haya seleccionado un cliente
    if (_selectedCliente == null) return false;

    // Verificar que el carrito no esté vacío
    if (_carrito.isEmpty) return false;

    // Calcular el total de la venta
    final totalVenta = _carrito.fold<double>(
      0,
      (sum, item) =>
          sum +
          (item['producto'] != null
              ? item['producto'].precioVenta * item['cantidad']
              : item['monto']),
    );

    // Validaciones según el método de pago
    if (_metodoPago != 'Efectivo') {
      // Para pagos no en efectivo, se requiere referencia de pago
      return _referenciaPagoController.text.isNotEmpty;
    } else {
      // Para pagos en efectivo, verificar monto recibido
      if (_montoRecibidoController.text.isEmpty) return false;

      final montoIngresado = double.tryParse(_montoRecibidoController.text
          .replaceAll(RegExp(r'[^\d,]'), '')
          .replaceAll(',', '.'));

      if (montoIngresado == null) return false;

      return montoIngresado >= totalVenta;
    }
  }

  Future<void> _procesarVenta() async {
    if (!mounted) return;

    try {
      // Calcular el total de la venta
      final total = _carrito.fold<double>(
        0,
        (sum, item) =>
            sum +
            (item['producto'] != null
                ? item['producto'].precioVenta * item['cantidad']
                : item['monto']),
      );

      // Crear la venta
      final venta = Venta(
        clienteId: _selectedCliente?.id,
        clienteNombre: _selectedCliente?.nombre,
        total: total,
        metodoPago: _metodoPago,
        referenciaPago:
            _metodoPago != 'Efectivo' ? _referenciaPagoController.text : null,
        items: [],
      );

      // Agregar los ítems al carrito
      for (var item in _carrito) {
        if (item['producto'] != null) {
          // Es un producto
          venta.agregarItem({
            'producto_id': item['producto'].id,
            'cantidad': item['cantidad'],
            'precio_unitario': item['producto'].precioVenta,
            'subtotal': item['producto'].precioVenta * item['cantidad'],
            'descripcion': item['producto'].nombre,
          });
        } else {
          // Es una venta casual
          venta.agregarItem({
            'producto_id': null,
            'cantidad': 1,
            'precio_unitario': item['monto'],
            'subtotal': item['monto'],
            'descripcion': item['descripcion'],
          });
        }
      }

      // Obtener la instancia del DatabaseService
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);

      // Guardar la venta en la base de datos
      final ventaId = await databaseService.insertVenta(venta);

      if (mounted) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Venta #$ventaId procesada por ${formatter.format(total)}'),
            duration: const Duration(seconds: 3),
          ),
        );

        // Notificar a los listeners que hay datos nuevos
        databaseService.notifyDataChanged();

        // Limpiar el formulario después de la venta
        _resetearFormulario();

        // Notificar al padre que la venta fue exitosa
        widget.onVentaExitosa();
      }
    } catch (e) {
      if (mounted) {
        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la venta: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      // Re-lanzar el error para que pueda ser manejado por el llamador si es necesario
      rethrow;
    }
  }

  @override
  void dispose() {
    _montoRecibidoController.dispose();
    super.dispose();
  }

  Future<void> _loadProductos() async {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    final categoria =
        (_selectedCategory == 'Todas' || _selectedCategory == 'Generales')
            ? null
            : _selectedCategory;
    final productos = await databaseService.getProductos(categoria: categoria);
    if (!mounted) return;
    setState(() => _productos = productos);
  }

  void _filtrarProductos(String query) {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    databaseService.buscarProductos(query).then((productos) {
      if (!mounted) return;
      setState(() {
        if (_selectedCategory == 'Todas' || _selectedCategory == 'Generales') {
          _productos = productos;
        } else {
          _productos =
              productos.where((p) => p.categoria == _selectedCategory).toList();
        }
        // Ordenar productos por nombre
        _productos.sort((a, b) => a.nombre.compareTo(b.nombre));
      });
    });
  }

  void _mostrarDetallesProducto(BuildContext context, Producto producto) {
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
              _buildDetailRow('Precio', formatter.format(producto.precioVenta)),
              const SizedBox(height: 8),
              if (producto.categoria.isNotEmpty)
                _buildDetailRow('Categoría', producto.categoria),
              if (producto.codigoBarras.isNotEmpty)
                _buildDetailRow('Código', producto.codigoBarras),
              _buildDetailRow(
                'Stock',
                '${producto.stock} ${producto.stock == 1 ? 'unidad' : 'unidades'}',
                color: producto.stock > 0 ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (producto.stock > 0)
            ElevatedButton(
              onPressed: () {
                _agregarAlCarrito(producto);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${producto.nombre} agregado al carrito'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Text('Agregar al carrito'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to safely find an item in the cart
  Map<String, dynamic>? _findCartItem(Producto producto) {
    try {
      return _carrito.firstWhere(
        (item) => item['producto']?.id == producto.id,
      );
    } catch (e) {
      return null;
    }
  }

  void _agregarAlCarrito(Producto producto) {
    if (!mounted) return;

    final existingItem = _findCartItem(producto);

    if (existingItem != null) {
      // Si el producto ya está en el carrito, incrementar la cantidad
      final int cantidadActual = existingItem['cantidad'] ?? 0;
      if (cantidadActual < producto.stock) {
        if (!mounted) return;
        setState(() {
          existingItem['cantidad'] = cantidadActual + 1;
        });
      } else {
        // Mostrar mensaje de que no hay suficiente stock
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay suficiente stock de ${producto.nombre}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Si el producto no está en el carrito, agregarlo con cantidad 1
      if (!mounted) return;
      setState(() {
        _carrito.add({
          'producto': producto,
          'cantidad': 1,
        });
      });
    }
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
                  if (!mounted) return;
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
                  if (!mounted) return;
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

  // Método auxiliar para construir líneas de resumen de pago
  Widget _buildResumenLinea(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? textColor,
    double fontSize = 16,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize - 2,
              color: Colors.grey[600],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor ?? Theme.of(context).textTheme.titleLarge?.color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarCarrito() {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

                return Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 500, maxHeight: 700),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Encabezado
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_cart,
                                  color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              const Text(
                                'Carrito de Compras',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 24),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),

                        // Contenido desplazable
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Lista de productos
                                ..._carrito.map((item) {
                                  final nombre = item['producto']?.nombre ??
                                      item['descripcion'];

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Imagen del producto
                                          Container(
                                            width: 70,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: item['producto']
                                                            ?.imagenUrl !=
                                                        null &&
                                                    item['producto']
                                                        .imagenUrl
                                                        .toString()
                                                        .isNotEmpty
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: ProductImageViewer(
                                                      imageUrl: item['producto']
                                                          .imagenUrl,
                                                      width: 70,
                                                      height: 70,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Center(
                                                    child: Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      color: Colors.grey[400],
                                                      size: 32,
                                                    ),
                                                  ),
                                          ),

                                          const SizedBox(width: 8),

                                          // Detalles del producto
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nombre,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${formatter.format(item['producto']?.precioVenta ?? item['monto'])} c/u',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .primaryColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),

                                                // Contador de cantidad y botones
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Botón para disminuir cantidad
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(
                                                            Icons.remove,
                                                            size: 16),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(
                                                          minWidth: 28,
                                                          minHeight: 28,
                                                          maxWidth: 28,
                                                          maxHeight: 28,
                                                        ),
                                                        onPressed: () {
                                                          if (!mounted) return;
                                                          setState(() {
                                                            setDialogState(() {
                                                              if (item[
                                                                      'cantidad'] >
                                                                  1) {
                                                                item['cantidad'] -=
                                                                    1;
                                                              } else {
                                                                _carrito.remove(
                                                                    item);
                                                              }
                                                            });
                                                          });
                                                        },
                                                      ),
                                                    ),

                                                    // Cantidad actual
                                                    SizedBox(
                                                      width: 30,
                                                      child: Text(
                                                        '${item['cantidad']}',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),

                                                    // Botón para aumentar cantidad
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .primaryColor
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: IconButton(
                                                        icon: Icon(Icons.add,
                                                            size: 16,
                                                            color: Theme.of(
                                                                    context)
                                                                .primaryColor),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(
                                                          minWidth: 28,
                                                          minHeight: 28,
                                                          maxWidth: 28,
                                                          maxHeight: 28,
                                                        ),
                                                        onPressed: () {
                                                          if (!mounted) return;

                                                          final producto =
                                                              item['producto'];
                                                          if (producto !=
                                                                  null &&
                                                              producto
                                                                  is Producto) {
                                                            if (item[
                                                                    'cantidad'] >=
                                                                producto
                                                                    .stock) {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'No hay suficiente stock disponible. Stock actual: ${producto.stock}'),
                                                                  duration:
                                                                      const Duration(
                                                                          seconds:
                                                                              2),
                                                                ),
                                                              );
                                                              return;
                                                            }
                                                          }

                                                          setState(() {
                                                            setDialogState(() {
                                                              item['cantidad'] +=
                                                                  1;
                                                            });
                                                          });
                                                        },
                                                      ),
                                                    ),

                                                    // Botón para eliminar
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 18,
                                                          color: Colors.red),
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth: 28,
                                                        minHeight: 28,
                                                        maxWidth: 28,
                                                        maxHeight: 28,
                                                      ),
                                                      onPressed: () {
                                                        if (!mounted) return;
                                                        setState(() {
                                                          setDialogState(() =>
                                                              _carrito.remove(
                                                                  item));
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                                const SizedBox(height: 16),

                                // Sección de Cliente
                                Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      _seleccionarCliente(setDialogState);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_outline,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              size: 28),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Cliente',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _selectedCliente?.nombre ??
                                                      'Seleccionar cliente',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (_selectedCliente?.ruc !=
                                                        null &&
                                                    _selectedCliente!
                                                        .ruc!.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'RUC: ${_selectedCliente!.ruc}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right,
                                              color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Sección de Método de Pago
                                Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Método de pago',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _metodoPago,
                                              isExpanded: true,
                                              icon: const Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: Colors.grey),
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'Efectivo',
                                                  child: Text('Efectivo'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'Tarjeta de Crédito',
                                                  child: Text(
                                                      'Tarjeta de Crédito'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'Tarjeta de Débito',
                                                  child:
                                                      Text('Tarjeta de Débito'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'Transferencia',
                                                  child: Text('Transferencia'),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                if (value != null) {
                                                  setDialogState(() {
                                                    _metodoPago = value;
                                                    // Clear the reference when changing payment method
                                                    if (value != 'Efectivo') {
                                                      _referenciaPagoController
                                                          .clear();
                                                    } else {
                                                      _montoRecibidoController
                                                          .clear();
                                                      _montoRecibido = 0.0;
                                                    }
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        if (_metodoPago != 'Efectivo')
                                          TextFormField(
                                            controller:
                                                _referenciaPagoController,
                                            onChanged: (value) {
                                              // Update the dialog state when the reference changes
                                              setState(() {});
                                              setDialogState(() {});
                                            },
                                            decoration: InputDecoration(
                                              labelText:
                                                  'Número de Transacción',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                    color: Colors.grey[300]!),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                    color: Colors.grey[300]!),
                                              ),
                                            ),
                                            style:
                                                const TextStyle(fontSize: 15),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Sección de Resumen y Pago
                                Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        // Subtotal
                                        _buildResumenLinea(
                                          context,
                                          'Subtotal',
                                          formatter.format(total),
                                        ),

                                        // Descuento (opcional, puedes implementarlo si es necesario)
                                        // _buildResumenLinea(
                                        //   context,
                                        //   'Descuento',
                                        //   '-${formatter.format(0)}',
                                        //   isBold: false,
                                        //   textColor: Colors.green,
                                        // ),

                                        const Divider(height: 24, thickness: 1),

                                        // Total
                                        _buildResumenLinea(
                                          context,
                                          'Total a Pagar',
                                          formatter.format(total),
                                          isBold: true,
                                          fontSize: 18,
                                        ),

                                        // Sección de pago en efectivo
                                        if (_metodoPago == 'Efectivo') ...[
                                          const SizedBox(height: 16),
                                          TextFormField(
                                            controller:
                                                _montoRecibidoController,
                                            decoration: InputDecoration(
                                              labelText: 'Monto Recibido',
                                              prefixText: '$currencySymbol ',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                    color: Colors.grey[300]!),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                    color: Colors.grey[300]!),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 14),
                                            ),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500),
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            onChanged: (value) {
                                              // Si el valor está vacío, limpiar todo
                                              if (value.isEmpty) {
                                                if (!mounted) return;
                                                setState(() {
                                                  _montoRecibido = 0.0;
                                                  _montoRecibidoController
                                                      .text = '';
                                                });
                                                setDialogState(() {});
                                                return;
                                              }

                                              // Obtener solo números y comas
                                              String cleanValue =
                                                  value.replaceAll(
                                                      RegExp(r'[^\d,]'), '');

                                              // Validar que no haya más de una coma
                                              final parts =
                                                  cleanValue.split(',');
                                              if (parts.length > 2) {
                                                // Si hay más de una coma, mantener solo la primera
                                                cleanValue =
                                                    '${parts[0]},${parts[1]}';
                                              }

                                              // Limitar a 2 decimales después de la coma
                                              if (parts.length == 2 &&
                                                  parts[1].length > 2) {
                                                cleanValue =
                                                    '${parts[0]},${parts[1].substring(0, 2)}';
                                              }

                                              // Formatear el número con puntos de miles
                                              String formattedValue =
                                                  formatearNumero(cleanValue);

                                              // Actualizar el controlador
                                              _montoRecibidoController.value =
                                                  TextEditingValue(
                                                text: formattedValue,
                                                selection:
                                                    TextSelection.collapsed(
                                                        offset: formattedValue
                                                            .length),
                                              );

                                              // Actualizar el valor numérico
                                              if (cleanValue.isNotEmpty) {
                                                _montoRecibido =
                                                    double.tryParse(cleanValue
                                                            .replaceAll('.', '')
                                                            .replaceAll(
                                                                ',', '.')) ??
                                                        0.0;
                                              } else {
                                                _montoRecibido = 0.0;
                                              }

                                              // Forzar la actualización del diálogo
                                              setDialogState(() {});
                                            },
                                            inputFormatters: [
                                              // Permitir solo números y comas
                                              FilteringTextInputFormatter.allow(
                                                  RegExp(r'[\d,]')),
                                              // Validar el formato
                                              TextInputFormatter.withFunction(
                                                  (oldValue, newValue) {
                                                // Permitir siempre el borrado
                                                if (newValue.text.length <
                                                    oldValue.text.length) {
                                                  return newValue;
                                                }

                                                final text = newValue.text;

                                                // No permitir comenzar con coma
                                                if (text.startsWith(',')) {
                                                  return oldValue;
                                                }

                                                // No permitir múltiples comas
                                                if ((text.split(',').length -
                                                        1) >
                                                    1) {
                                                  return oldValue;
                                                }

                                                // Limitar a 2 decimales después de la coma
                                                final parts = text.split(',');
                                                if (parts.length == 2 &&
                                                    parts[1].length > 2) {
                                                  return oldValue;
                                                }

                                                return newValue;
                                              }),
                                            ],
                                          ),

                                          // Mostrar vuelto o faltante
                                          if (_montoRecibido > 0) ...[
                                            const SizedBox(height: 12),
                                            _buildResumenLinea(
                                              context,
                                              _montoRecibido >= total
                                                  ? 'Vuelto'
                                                  : 'Falta',
                                              formatter.format(
                                                  (_montoRecibido - total)
                                                      .abs()),
                                              isBold: true,
                                              textColor: _montoRecibido >= total
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontSize: 16,
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Botones de acción
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar',
                                    style: TextStyle(fontSize: 15)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _puedeProcesarVenta()
                                    ? () {
                                        _procesarVenta();
                                        Navigator.pop(context);
                                      }
                                    : null,
                                // Add a tooltip to explain why the button is disabled
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Procesar Venta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ));
  }

  Future<void> _seleccionarCliente(
      Function(void Function()) setDialogState) async {
    final searchController = TextEditingController();
    List<Cliente> clientesFiltrados = [];

    await showDialog<Cliente>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Seleccionar Cliente'),
              content: FutureBuilder<List<Cliente>>(
                future: Provider.of<DatabaseService>(context, listen: false)
                    .getClientes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final clientes = snapshot.data!;

                  // Filtrar clientes basado en la búsqueda
                  if (searchController.text.isEmpty) {
                    clientesFiltrados = clientes;
                  } else {
                    final searchTerm = searchController.text.toLowerCase();
                    clientesFiltrados = clientes.where((cliente) {
                      return cliente.nombre
                              .toLowerCase()
                              .contains(searchTerm) ||
                          (cliente.ruc?.toLowerCase().contains(searchTerm) ??
                              false) ||
                          (cliente.telefono
                                  ?.toLowerCase()
                                  .contains(searchTerm) ??
                              false);
                    }).toList();
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Barra de búsqueda
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, RUC o teléfono',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          onChanged: (_) {
                            setState(
                                () {}); // Actualiza la UI al cambiar el texto
                          },
                        ),
                      ),
                      // Lista de clientes
                      SizedBox(
                        width: double.maxFinite,
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: clientesFiltrados.isEmpty
                            ? const Center(
                                child: Text('No se encontraron clientes'))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: clientesFiltrados.length,
                                itemBuilder: (context, index) {
                                  final cliente = clientesFiltrados[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 0),
                                    child: ListTile(
                                      title: Text(
                                        cliente.nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (cliente.ruc != null &&
                                              cliente.ruc!.isNotEmpty)
                                            Text('RUC: ${cliente.ruc}'),
                                          if (cliente.telefono != null &&
                                              cliente.telefono!.isNotEmpty)
                                            Text('Tel: ${cliente.telefono}'),
                                        ],
                                      ),
                                      onTap: () {
                                        if (!mounted) return;
                                        setDialogState(
                                            () => _selectedCliente = cliente);
                                        Navigator.of(context).pop(cliente);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Método para reiniciar el formulario después de una venta exitosa
  void _resetearFormulario() {
    if (!mounted) return;
    setState(() {
      _carrito.clear();
      _selectedCliente = null;
      _metodoPago = 'Efectivo';
      _montoRecibido = 0.0;
      _montoRecibidoController.clear();
      _referenciaPagoController.clear();
    });
  }

  void _escanearCodigoBarras() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (result != null) {
      _searchController.text = result;
      if (!mounted) return;
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
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]!.withValues(alpha: 0.7)
                  : Colors.grey[100],
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const Text(
                  'Categoría: ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                FutureBuilder<List<Categoria>>(
                  future: Provider.of<DatabaseService>(context, listen: false)
                      .getCategorias(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final categorias = snapshot.data!
                        .where((c) => c.nombre.toLowerCase() != 'general')
                        .toList();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'Todas',
                            child: Text('Todas'),
                          ),
                          ...categorias.map((c) => DropdownMenuItem(
                                value: c.nombre,
                                child: Text(c.nombre),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                          _loadProductos();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              itemCount: _productos.length,
              itemBuilder: (context, index) {
                final producto = _productos[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 8.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _agregarAlCarrito(producto),
                    onLongPress: () =>
                        _mostrarDetallesProducto(context, producto),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          // Imagen del producto
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ProductImageViewer(
                                imageUrl: producto.imagenUrl,
                                width: 70,
                                height: 70,
                                borderRadius: 8.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Detalles del producto
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
                                  NumberFormat.currency(
                                    symbol: Provider.of<SettingsService>(
                                            context,
                                            listen: false)
                                        .currentCurrency
                                        .symbol,
                                    decimalDigits: 0,
                                  ).format(producto.precioVenta),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Controles de cantidad del carrito
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botón para quitar del carrito
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red, size: 32),
                                  onPressed: () {
                                    if (!mounted) return;
                                    final existingItem =
                                        _findCartItem(producto);
                                    if (existingItem != null) {
                                      if (existingItem['cantidad'] > 1) {
                                        if (mounted) {
                                          setState(() {
                                            existingItem['cantidad'] -= 1;
                                          });
                                        }
                                      } else {
                                        if (mounted) {
                                          setState(() {
                                            _carrito.removeWhere((item) =>
                                                item['producto']?.id ==
                                                producto.id);
                                          });
                                        }
                                      }
                                    }
                                  },
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                                // Cantidad actual en el carrito
                                Container(
                                  width: 36,
                                  alignment: Alignment.center,
                                  child: Text(
                                    (_findCartItem(producto)?['cantidad'] ?? 0)
                                        .toString(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Botón para agregar al carrito
                                Builder(
                                  builder: (context) {
                                    final cartItem = _findCartItem(producto);
                                    final cantidadEnCarrito =
                                        cartItem?['cantidad'] ?? 0;
                                    final sinStock =
                                        cantidadEnCarrito >= producto.stock;

                                    return IconButton(
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        color: sinStock
                                            ? Colors.grey
                                            : Colors.blue,
                                        size: 32,
                                      ),
                                      onPressed: sinStock
                                          ? null
                                          : () => _agregarAlCarrito(producto),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botón de Venta Casual
                ElevatedButton.icon(
                  onPressed: _agregarVentaCasual,
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                  label: const Text('Venta Casual'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),

                // Botón del carrito con contador
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
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
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

  // Método para seleccionar fecha de inicio
  Future<void> _seleccionarFechaInicio() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (fecha != null) {
      final newStartDate = DateTime(fecha.year, fecha.month, fecha.day);
      setState(() {
        _fechaInicio = newStartDate;
      });
      _loadVentas();
    }
  }

  // Método para seleccionar fecha de fin
  Future<void> _seleccionarFechaFin() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaFin,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (fecha != null) {
      final newEndDate =
          DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59, 999);
      setState(() {
        _fechaFin = newEndDate;
      });
      _loadVentas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
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
                  // Selector de fechas
                  Card(
                    margin: const EdgeInsets.all(8.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Filtrar por fecha',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12.0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                      onPressed: _seleccionarFechaInicio,
                                      icon: const Icon(Icons.calendar_today,
                                          size: 18),
                                      label: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          formatter.format(_fechaInicio),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'hasta',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12.0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                      onPressed: _seleccionarFechaFin,
                                      icon: const Icon(Icons.calendar_today,
                                          size: 18),
                                      label: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          formatter.format(_fechaFin),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Filtros adicionales
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
                              setState(() {
                                _metodoPagoFiltro = value;
                              });
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

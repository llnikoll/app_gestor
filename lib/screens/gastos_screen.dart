import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../models/gasto_model.dart';
import '../models/producto_model.dart';
import '../models/categoria_model.dart';
import 'gasto_form_screen.dart';
import '../services/product_notifier_service.dart';
import '../utils/currency_formatter.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final DatabaseService _db = DatabaseService();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  List<Gasto> _gastos = [];
  bool _isLoading = true;
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('=== Inicializando GastosScreen ===');
    }
    // Establecer la fecha actual como fecha inicial y final por defecto
    final ahora = DateTime.now();
    _fechaInicio = DateTime(ahora.year, ahora.month, ahora.day);
    _fechaFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59, 999);
    if (kDebugMode) {
      debugPrint('Fecha de inicio: ${_fechaInicio.toIso8601String()}');
      debugPrint('Fecha de fin: ${_fechaFin.toIso8601String()}');
    }
    _cargarGastos();
  }

  @override
  void dispose() {
    // Aquí puedes limpiar cualquier controlador o suscripción
    super.dispose();
  }

  // Función para formatear montos según la moneda configurada
  String _formatearMoneda(double monto) {
    return context.formattedCurrency(monto);
  }

  // Función para calcular el total de gastos
  double calcularTotal() {
    return _gastos.fold(0.0, (sum, item) => sum + item.monto);
  }

  Future<void> _cargarGastos() async {
    if (kDebugMode) {
      debugPrint('=== _cargarGastos() llamado ===');
      debugPrint('_fechaInicio: ${_fechaInicio.toIso8601String()}');
      debugPrint('_fechaFin: ${_fechaFin.toIso8601String()}');
    }

    if (!mounted) return;

    try {
      // Solo actualizar el estado si el widget está montado
      if (mounted) {
        setState(() => _isLoading = true);
      }

      // Asegurarse de que las fechas estén en el rango correcto del día
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
        999,
      );

      if (kDebugMode) {
        debugPrint(
          'Cargando gastos desde ${fechaInicio.toIso8601String()} hasta ${fechaFin.toIso8601String()}',
        );
        debugPrint(
          'Fecha inicio (formateada): ${fechaInicio.toIso8601String()}',
        );
        debugPrint('Fecha fin (formateada): ${fechaFin.toIso8601String()}');
      }

      final gastos = await _db.getGastosPorRangoFechas(fechaInicio, fechaFin);

      if (kDebugMode) {
        debugPrint('Se encontraron ${gastos.length} gastos');
        for (var gasto in gastos) {
          debugPrint(
            'Gasto: ${gasto.descripcion} - Fecha: ${gasto.fecha.toIso8601String()}',
          );
        }
      }

      // Verificar nuevamente si el widget sigue montado antes de actualizar el estado
      if (mounted) {
        setState(() {
          _gastos = gastos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _mostrarError('Error al cargar gastos: $e');
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  Future<void> _seleccionarFechaInicio() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      setState(() => _fechaInicio = fecha);
      await _cargarGastos();
    }
  }

  Future<void> _seleccionarFechaFin() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaFin,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      setState(() => _fechaFin = fecha);
      await _cargarGastos();
    }
  }

  void _mostrarOpciones() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.receipt),
            title: const Text('Nuevo Gasto'),
            onTap: () {
              Navigator.pop(context);
              _mostrarDialogoNuevoGasto();
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('Compra de Producto'),
            onTap: () {
              Navigator.pop(context);
              _mostrarDialogoCompraProducto();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoNuevoGasto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GastoFormScreen()),
    );

    if (result == true && mounted) {
      await _cargarGastos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarGastos),
        ],
      ),
      body: Column(
        children: [
          // Filtro de fechas
          Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filtrar por fecha',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onSurface,
                              ),
                              onPressed: _seleccionarFechaInicio,
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _dateFormat.format(_fechaInicio),
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
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onSurface,
                              ),
                              onPressed: _seleccionarFechaFin,
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _dateFormat.format(_fechaFin),
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
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Total: ${_formatearMoneda(calcularTotal())}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Lista de gastos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _gastos.isEmpty
                    ? const Center(child: Text('No hay gastos registrados'))
                    : ListView.builder(
                        itemCount: _gastos.length,
                        itemBuilder: (context, index) {
                          final gasto = _gastos[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(gasto.descripcion),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Categoría: ${gasto.categoria}'),
                                  Text(
                                    '${gasto.fecha.day}/${gasto.fecha.month}/${gasto.fecha.year}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (gasto.notas?.isNotEmpty ?? false) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      gasto.notas!,
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Text(
                                _formatearMoneda(gasto.monto),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'expenses_fab',
        onPressed: _mostrarOpciones,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _mostrarDialogoCompraProducto() async {
    try {
      // Paso 1: Seleccionar categoría
      final List<Categoria> categorias = (await _db.getCategorias())
          .where((categoria) => categoria.nombre.toLowerCase() != 'general')
          .toList();

      if (!mounted) return;

      if (categorias.isEmpty) {
        _mostrarError('No hay categorías disponibles');
        return;
      }

      final String? categoriaSeleccionada = await showDialog<String>(
        context: context,
        builder: (BuildContext context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500, minWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Seleccionar Categoría',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: categorias.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(categorias[index].nombre),
                        onTap: () =>
                            Navigator.pop(context, categorias[index].nombre),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (categoriaSeleccionada == null || !mounted) return;

      // Paso 2: Obtener productos
      final productos = await _db.getProductos();
      if (!mounted) return;

      // Filtrar productos por categoría seleccionada y que estén activos
      final productosFiltrados = productos
          .where((p) => p.activo && p.categoria == categoriaSeleccionada)
          .toList();

      if (productosFiltrados.isEmpty) {
        _mostrarError('No hay productos activos en la categoría seleccionada');
        return;
      }

      // Paso 3: Mostrar selección de producto
      final productoSeleccionado = await showDialog<Producto>(
        context: context,
        builder: (BuildContext context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500, minWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Seleccionar Producto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: productosFiltrados.length,
                    itemBuilder: (context, index) {
                      final producto = productosFiltrados[index];
                      return ListTile(
                        title: Text(producto.nombre),
                        subtitle: Text('Stock: ${producto.stock}'),
                        onTap: () => Navigator.pop(context, producto),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted || productoSeleccionado == null) return;

      // Función para formatear un número para mostrar en el input (sin separadores de miles)
      String formatearNumeroParaInput(num valor) {
        // Eliminar decimales y formatear como entero
        return valor.toInt().toString();
      }

      // Paso 4: Ingresar detalles de la compra
      final cantidadController = TextEditingController(text: '1');
      final precioController = TextEditingController(
        text: formatearNumeroParaInput(productoSeleccionado.precioCompra),
      );
      final notasController = TextEditingController();

      // Función para calcular el total
      String calcularTotal() {
        if (cantidadController.text.isEmpty || precioController.text.isEmpty) {
          return _formatearMoneda(0);
        }
        // Obtener valores numéricos de los controladores
        final cantidad =
            double.tryParse(cantidadController.text.replaceAll('.', '')) ?? 0;
        final precio =
            double.tryParse(precioController.text.replaceAll('.', '')) ?? 0;
        final total = cantidad * precio;
        return _formatearMoneda(total);
      }

      final settings = Provider.of<SettingsService>(context, listen: false);
      final currencySymbol = settings.currentCurrency.symbol;

      final confirmado = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Registrar Compra'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productoSeleccionado.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: cantidadController,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: precioController,
                        decoration: InputDecoration(
                          labelText: 'Precio Unitario',
                          prefixText: '$currencySymbol ',
                          suffixText: currencySymbol,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          // Formatear el número mientras se escribe
                          if (value.isNotEmpty) {
                            // Eliminar todo lo que no sea dígito
                            final soloNumeros = value.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );
                            final monto = int.tryParse(soloNumeros) ?? 0;
                            final formateado = _formatearMoneda(
                              monto.toDouble(),
                            );

                            // Actualizar el controlador solo si el valor formateado es diferente
                            if (formateado != value) {
                              precioController.value = TextEditingValue(
                                text: formateado,
                                selection: TextSelection.collapsed(
                                  offset: formateado.length,
                                ),
                              );
                            }
                          }
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: notasController,
                        decoration: const InputDecoration(
                          labelText: 'Notas (opcional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(0, 245, 245, 245),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumen de la compra',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:'),
                                Text(
                                  calcularTotal(),
                                  style: const TextStyle(
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
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Obtener valores numéricos eliminando los separadores de miles
                      final cantidad = double.tryParse(
                        cantidadController.text.replaceAll('.', ''),
                      );
                      final precio = double.tryParse(
                        precioController.text.replaceAll('.', ''),
                      );

                      if (cantidad == null || cantidad <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ingrese una cantidad válida'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      if (precio == null || precio <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ingrese un precio válido'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context, true);
                    },
                    child: const Text('Confirmar Compra'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || confirmado != true) return;

      try {
        final cantidad = double.parse(cantidadController.text).toInt();
        final precio = double.parse(precioController.text);
        final notas = notasController.text;

        await _db.registrarCompraProducto(
          productoId: productoSeleccionado.id ?? 0,
          productoNombre: productoSeleccionado.nombre,
          cantidad: cantidad,
          precioUnitario: precio,
          notas: notas,
        );

        if (mounted) {
          _mostrarError('Compra registrada exitosamente');
          await _cargarGastos();

          // Notificar que se ha actualizado el inventario
          final productNotifier = ProductNotifierService();
          productNotifier.notifyProductUpdate();
        }
      } catch (e) {
        if (mounted) {
          _mostrarError('Error al procesar la compra: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al procesar la compra: $e');
      }
    }
  }
}

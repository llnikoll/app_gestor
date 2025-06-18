import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:app_gestor_ventas/services/database_service.dart';
import 'package:app_gestor_ventas/services/transaction_notifier_service.dart';

// Extensión para capitalizar la primera letra de un String
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

// Modelos para los datos
class SalesData {
  final String periodo;
  final double ventas;

  SalesData(this.periodo, this.ventas);
}

class CategoryData {
  final String nombre;
  final double monto;
  final Color color;

  CategoryData(this.nombre, this.monto, this.color);
}

class FinancialData {
  final String concepto;
  final double monto;
  final Color color;

  FinancialData(this.concepto, this.monto, this.color);
}

class ClienteData {
  final String nombre;
  final int compras;
  final double montoTotal;

  ClienteData(this.nombre, this.compras, this.montoTotal);
}

class ProductoData {
  final String nombre;
  final int cantidad;
  final double montoTotal;

  ProductoData(this.nombre, this.cantidad, this.montoTotal);
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  // Función para formatear montos en guaraníes
  String _formatearMoneda(double monto) {
    return NumberFormat.currency(
      symbol: 'Gs. ',
      decimalDigits: 0,
      locale: 'es_PY',
    ).format(monto).replaceAll(',', '.');
  }

  // Controlador para las pestañas
  late TabController _tabController;

  // Servicio de base de datos
  final DatabaseService _dbService = DatabaseService();

  // Rango de fechas seleccionado - Por defecto, el día actual
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      0,
      0,
      0,
    ),
    end: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      23,
      59,
      59,
      999,
    ),
  ); // CAMBIO: Establecer el rango de fechas al día actual por defecto

  // Datos para los gráficos y tablas
  final List<SalesData> _ventasData = [];
  List<SalesData> _gastosData = [];
  final List<FinancialData> _financialData = [];
  final List<ClienteData> _clientesData = [];
  final List<ProductoData> _productosData = [];

  // Datos para la pestaña de Gastos
  double _gastosDiaSeleccionado = 0.0;
  int _gastosCountDiaSeleccionado = 0;
  List<Map<String, dynamic>> _gastosDiaSeleccionadoLista = [];

  // Estado de carga y errores
  bool _isLoading = true;
  String _errorMessage = '';

  // Notificador para actualizar la UI cuando cambian los datos
  final ValueNotifier<int> _dataUpdated = ValueNotifier<int>(0);

  // Usar la instancia singleton directamente
  final TransactionNotifierService _transactionNotifier =
      TransactionNotifierService();
  late final VoidCallback _onTransactionUpdated;

  // Variables para almacenar los datos del resumen financiero
  double _ventasTotales = 0.0;
  double _gastosTotales = 0.0;
  double _gananciasTotales = 0.0;

  // Datos para el ranking de productos
  List<Map<String, dynamic>> _productosMasVendidos = [];

  // Datos para el resumen del día
  double _ventasHoy = 0.0;
  int _ventasCountHoy = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Configurar el listener para actualizar los datos cuando haya cambios en las transacciones
    _onTransactionUpdated = () {
      if (mounted) {
        final value = _transactionNotifier.transactionsNotifier.value;
        debugPrint(
          'Notificación de transacción recibida (valor: $value) - Recargando datos...',
        );
        _cargarDatos(); // CAMBIO: Asegurar que se recarguen los datos al recibir notificaciones
      }
    };

    // Agregar el listener al notifier
    _transactionNotifier.transactionsNotifier.addListener(
      _onTransactionUpdated,
    );
    debugPrint('Listener de transacciones registrado en ReportsScreen');

    // Cargar los datos iniciales
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    await _cargarDatos();
    await _cargarVentas();
    await _cargarGastos();
    await _cargarClientes();
    await _cargarProductos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      }

      debugPrint('Iniciando carga de datos...');

      // Cargar en secuencia para evitar problemas de concurrencia
      final stopwatch = Stopwatch()..start();

      await _cargarVentas();
      debugPrint('Ventas cargadas en ${stopwatch.elapsedMilliseconds}ms');
      stopwatch.reset();

      await _cargarGastos();
      debugPrint('Gastos cargados en ${stopwatch.elapsedMilliseconds}ms');
      stopwatch.reset();

      await _cargarProductos();
      debugPrint('Productos cargados en ${stopwatch.elapsedMilliseconds}ms');
      stopwatch.reset();

      await _cargarClientes();
      debugPrint('Clientes cargados en ${stopwatch.elapsedMilliseconds}ms');

      debugPrint('Carga de datos completada exitosamente');

      // Forzar actualización de la UI después de cargar todos los datos
      if (mounted) {
        _dataUpdated.value++;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _cargarDatos: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    void showErrorSnackBar(String message) {
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));
    }

    try {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: _selectedDateRange,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Theme.of(context).primaryColor,
                onPrimary: Colors.white,
                surface: Theme.of(context).scaffoldBackgroundColor,
                onSurface:
                    Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black,
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
            child: child!,
          );
        },
      );

      if (!mounted) return;

      if (picked != null) {
        final startDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        final endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
          999,
        );

        final newDateRange = DateTimeRange(start: startDate, end: endDate);

        setState(() {
          _selectedDateRange = newDateRange;
        });
        await _cargarDatos();
      }
    } catch (e) {
      debugPrint('Error al seleccionar rango de fechas: $e');
      showErrorSnackBar('Error al seleccionar fechas: $e');
    }
  }

  Future<void> _cargarVentas() async {
    if (!mounted) return;

    try {
      debugPrint(
        'Buscando ventas desde ${_selectedDateRange.start} hasta ${_selectedDateRange.end}',
      );

      final ventas = await _dbService.getVentasPorRango(
        _selectedDateRange.start,
        _selectedDateRange.end,
      );

      debugPrint('Ventas encontradas: ${ventas.length}');

      final ventasPorDia = <DateTime, double>{};
      double totalVentas = 0;
      double ventasDiaSeleccionado = 0.0;
      int ventasCountDiaSeleccionado = 0;
      final productosMap = <String, Map<String, dynamic>>{};

      for (var venta in ventas) {
        try {
          final fecha = DateTime(
            venta.fecha.year,
            venta.fecha.month,
            venta.fecha.day,
          );

          if (venta.total.isNaN || venta.total.isInfinite) {
            debugPrint(
              'Advertencia: Venta ${venta.id} tiene un total inválido: ${venta.total}',
            );
            continue;
          }

          ventasPorDia[fecha] = (ventasPorDia[fecha] ?? 0) + venta.total;
          totalVentas += venta.total;

          if (venta.fecha.year == _selectedDateRange.end.year &&
              venta.fecha.month == _selectedDateRange.end.month &&
              venta.fecha.day == _selectedDateRange.end.day) {
            ventasDiaSeleccionado += venta.total;
            ventasCountDiaSeleccionado++;
          }

          final detalles = await _dbService.getDetallesVenta(venta.id!);
          for (var detalle in detalles) {
            final productoId = detalle['producto_id'].toString();
            if (productoId != 'null') {
              if (!productosMap.containsKey(productoId)) {
                productosMap[productoId] = {
                  'id': detalle['producto_id'],
                  'nombre':
                      detalle['nombre_producto'] ?? 'Producto desconocido',
                  'cantidad': 0,
                  'total': 0.0,
                };
              }
              productosMap[productoId]!['cantidad'] +=
                  detalle['cantidad'] as int;
              productosMap[productoId]!['total'] += (detalle['subtotal'] as num)
                  .toDouble();
            }
          }

          debugPrint(
            'Venta: ${venta.id} - Fecha: ${venta.fecha} - Total: ${venta.total}',
          );
        } catch (e) {
          debugPrint('Error procesando venta ${venta.id}: $e');
          continue;
        }
      }

      final productosList = productosMap.values.toList();
      productosList.sort(
        (a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int),
      );
      final topProductos = productosList.take(10).toList();

      final fechasOrdenadas = ventasPorDia.keys.toList()..sort();
      final ventasData = fechasOrdenadas
          .map(
            (fecha) => SalesData(
              DateFormat('dd/MM').format(fecha),
              ventasPorDia[fecha]!,
            ),
          )
          .toList();

      debugPrint('Total de ventas calculado: $totalVentas');

      if (!mounted) return;

      setState(() {
        _ventasData.clear();
        _ventasData.addAll(ventasData);
        _productosMasVendidos = topProductos;
        _ventasHoy = ventasDiaSeleccionado;
        _ventasCountHoy = ventasCountDiaSeleccionado;
      });

      _updateFinancialData(totalVentas, -1);
    } catch (e, stackTrace) {
      debugPrint('Error cargando ventas: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar ventas: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ventas: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _cargarGastos() async {
    if (!mounted) return;

    try {
      debugPrint(
        'Buscando gastos desde ${_selectedDateRange.start} hasta ${_selectedDateRange.end}',
      );

      final gastos = await _dbService.getGastosPorRango(
        _selectedDateRange.start,
        _selectedDateRange.end,
      );

      debugPrint('Gastos encontrados: ${gastos.length}');

      final gastosPorDia = <DateTime, double>{};
      double totalGastos = 0;
      _gastosDiaSeleccionado = 0.0;
      _gastosCountDiaSeleccionado = 0;
      _gastosDiaSeleccionadoLista = [];

      for (var gasto in gastos) {
        try {
          final fecha = DateTime(
            gasto.fecha.year,
            gasto.fecha.month,
            gasto.fecha.day,
          );

          if (gasto.monto.isNaN || gasto.monto.isInfinite) {
            debugPrint(
              'Advertencia: Gasto ${gasto.id} tiene un monto inválido: ${gasto.monto}',
            );
            continue;
          }

          gastosPorDia[fecha] = (gastosPorDia[fecha] ?? 0) + gasto.monto;
          totalGastos += gasto.monto;

          if (gasto.fecha.year == _selectedDateRange.end.year &&
              gasto.fecha.month == _selectedDateRange.end.month &&
              gasto.fecha.day == _selectedDateRange.end.day) {
            _gastosDiaSeleccionado += gasto.monto;
            _gastosCountDiaSeleccionado++;
            _gastosDiaSeleccionadoLista.add({
              'descripcion': gasto.descripcion,
              'monto': gasto.monto,
              'categoria': gasto.categoria,
              'fecha': gasto.fecha.toIso8601String(),
            });
          }
        } catch (e) {
          debugPrint('Error procesando gasto: $e');
          continue;
        }
      }

      final fechasOrdenadas = gastosPorDia.keys.toList()..sort();
      final List<SalesData> gastosData = [];
      for (var fecha in fechasOrdenadas) {
        gastosData.add(
          SalesData(
            DateFormat('dd/MM').format(fecha),
            gastosPorDia[fecha] ?? 0,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _gastosData = gastosData;
        });
      }

      debugPrint(
        'Datos de gastos para el gráfico: ${gastosData.length} puntos',
      );

      _updateFinancialData(-1, totalGastos);
    } catch (e, stackTrace) {
      debugPrint('Error cargando gastos: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar gastos: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar gastos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    }
  }

  void _updateFinancialData(double totalVentas, double totalGastos) {
    if (!mounted) return;

    debugPrint(
      'Iniciando actualización de datos financieros - Ventas: $totalVentas, Gastos: $totalGastos',
    );

    try {
      if (totalVentas >= 0) {
        debugPrint('Actualizando ventas de $_ventasTotales a $totalVentas');
        _ventasTotales = totalVentas;
      }

      if (totalGastos >= 0) {
        debugPrint('Actualizando gastos de $_gastosTotales a $totalGastos');
        _gastosTotales = totalGastos;
      }

      _gananciasTotales = _ventasTotales - _gastosTotales;

      _financialData.clear();
      _financialData.addAll([
        FinancialData('Ventas', _ventasTotales, Colors.green),
        FinancialData('Gastos', _gastosTotales, Colors.red),
        FinancialData('Ganancias', _gananciasTotales, Colors.blue),
      ]);

      debugPrint(
        'Datos financieros actualizados - Ventas: $_ventasTotales, Gastos: $_gastosTotales, Ganancias: $_gananciasTotales',
      );

      if (mounted) {
        _dataUpdated.value++;
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _updateFinancialData: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al actualizar datos financieros: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _cargarProductos() async {
    if (!mounted) return;

    try {
      debugPrint(
        'Buscando productos más vendidos desde ${_selectedDateRange.start} hasta ${_selectedDateRange.end}',
      );

      final productos = await _dbService.getProductosMasVendidos(
        _selectedDateRange.start,
        _selectedDateRange.end,
      );

      debugPrint('Productos encontrados: ${productos.length}');

      final productosData = <ProductoData>[];

      for (var entry in productos.entries) {
        try {
          final nombreProducto = entry.key;
          final cantidad = entry.value['cantidad'] ?? 0;
          final total = (entry.value['total'] ?? 0).toDouble();

          if (cantidad < 0 || total.isNaN || total.isInfinite) {
            debugPrint(
              'Advertencia: Datos inválidos para el producto $nombreProducto - Cantidad: $cantidad, Total: $total',
            );
            continue;
          }

          productosData.add(ProductoData(nombreProducto, cantidad, total));
          debugPrint(
            'Producto: $nombreProducto - Cantidad: $cantidad - Total: $total',
          );
        } catch (e) {
          debugPrint('Error procesando producto ${entry.key}: $e');
          continue;
        }
      }

      if (!mounted) return;

      setState(() {
        _productosData.clear();
        _productosData.addAll(productosData);
      });

      debugPrint('Total de productos procesados: ${productosData.length}');
    } catch (e, stackTrace) {
      debugPrint('Error cargando productos: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar productos: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar productos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _cargarClientes() async {
    if (!mounted) return;

    try {
      debugPrint(
        'Buscando clientes frecuentes desde ${_selectedDateRange.start} hasta ${_selectedDateRange.end}',
      );

      final clientes = await _dbService.getClientesFrecuentes(
        _selectedDateRange.start,
        _selectedDateRange.end,
      );

      debugPrint('Clientes encontrados: ${clientes.length}');

      final clientesData = <ClienteData>[];

      for (var entry in clientes.entries) {
        try {
          final nombreCliente = entry.key;
          final compras = entry.value['compras'] ?? 0;
          final total = (entry.value['total'] ?? 0).toDouble();

          if (compras < 0 || total.isNaN || total.isInfinite) {
            debugPrint(
              'Advertencia: Datos inválidos para el cliente $nombreCliente - Compras: $compras, Total: $total',
            );
            continue;
          }

          clientesData.add(ClienteData(nombreCliente, compras, total));
          debugPrint(
            'Cliente: $nombreCliente - Compras: $compras - Total: $total',
          );
        } catch (e) {
          debugPrint('Error procesando cliente ${entry.key}: $e');
          continue;
        }
      }

      if (!mounted) return;

      setState(() {
        _clientesData.clear();
        _clientesData.addAll(clientesData);
      });

      debugPrint('Total de clientes procesados: ${clientesData.length}');
    } catch (e, stackTrace) {
      debugPrint('Error cargando clientes: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar clientes: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _dataUpdated,
      builder: (context, value, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Informes'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.summarize), text: 'Resumen'),
                Tab(icon: Icon(Icons.shopping_cart), text: 'Ventas'),
                Tab(icon: Icon(Icons.money_off), text: 'Gastos'),
              ],
            ),
            actions: const [],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildResumenTab(),
                    _buildVentasTab(),
                    _buildGastosTab(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildResumenTab() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDateRangeInfo(),
          const SizedBox(height: 20),
          _buildFinancialSummary(),
        ],
      ),
    );
  }

  Widget _buildVentasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeInfo(),
          const SizedBox(height: 20),
          _buildResumenHoy(),
          const SizedBox(height: 20),
          _buildSalesChart(),
          const SizedBox(height: 20),
          const Text(
            'Productos más vendidos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildProductosRanking(),
        ],
      ),
    );
  }

  Widget _buildDateRangeInfo() {
    final formatter = DateFormat('dd/MM/yyyy');
    return Builder(
      builder: (BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.date_range),
          title: const Text('Rango de fechas seleccionado:'),
          subtitle: Text(
            '${formatter.format(_selectedDateRange.start)} - ${formatter.format(_selectedDateRange.end)}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_calendar),
            onPressed: () => _selectDateRange(context),
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return ValueListenableBuilder<int>(
      valueListenable: _dataUpdated,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
              child: Text(
                'Resumen Financiero',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
              childAspectRatio: 2.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              padding: const EdgeInsets.all(16.0),
              children: _financialData
                  .map((data) => _buildSummaryCard(data))
                  .toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(FinancialData data) {
    IconData icon;
    switch (data.concepto) {
      case 'Ventas':
        icon = Icons.attach_money_rounded;
        break;
      case 'Gastos':
        icon = Icons.money_off_rounded;
        break;
      case 'Ganancias':
        icon = Icons.trending_up_rounded;
        break;
      default:
        icon = Icons.analytics_rounded;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: data.color.withValues(
                      red: ((data.color.r * 255.0) * 0.1).roundToDouble(),
                      green: ((data.color.g * 255.0) * 0.1).roundToDouble(),
                      blue: ((data.color.b * 255.0) * 0.1).roundToDouble(),
                      alpha: (data.color.a * 255.0).roundToDouble(),
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(icon, color: data.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.concepto,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatearMoneda(data.monto),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGastosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeInfo(),
          const SizedBox(height: 20),
          _buildResumenGastos(),
          const SizedBox(height: 20),
          _buildGastosChart(),
          const SizedBox(height: 20),
          const Text(
            'Gastos por Categoría',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildListaGastos(),
        ],
      ),
    );
  }

  Widget _buildResumenGastos() {
    final fechaSeleccionada = DateFormat(
      'dd/MM/yyyy',
    ).format(_selectedDateRange.end);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Resumen de Gastos: ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  fechaSeleccionada,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResumenItem(
                  'Gastos',
                  _gastosCountDiaSeleccionado.toString(),
                  Icons.receipt,
                  Colors.red,
                ),
                _buildResumenItem(
                  'Total',
                  _formatearMoneda(_gastosDiaSeleccionado),
                  Icons.money_off,
                  Colors.orange,
                ),
                _buildResumenItem(
                  'Promedio',
                  _gastosCountDiaSeleccionado > 0
                      ? _formatearMoneda(
                          _gastosDiaSeleccionado / _gastosCountDiaSeleccionado,
                        )
                      : _formatearMoneda(0),
                  Icons.bar_chart,
                  Colors.deepOrange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGastosChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gastos por Período',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _gastosData.isEmpty
                  ? const Center(
                      child: Text('No hay datos de gastos disponibles'),
                    )
                  : SfCartesianChart(
                      primaryXAxis: const CategoryAxis(
                        labelRotation: 45,
                        labelStyle: TextStyle(fontSize: 10),
                      ),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.currency(
                          symbol: 'Gs. ',
                          decimalDigits: 0,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        LineSeries<SalesData, String>(
                          dataSource: _gastosData,
                          xValueMapper: (SalesData gasto, _) => gasto.periodo,
                          yValueMapper: (SalesData gasto, _) => gasto.ventas,
                          name: 'Gastos',
                          color: Colors.red,
                          markerSettings: const MarkerSettings(
                            isVisible: true,
                            color: Colors.red,
                            borderColor: Colors.white,
                            borderWidth: 2,
                          ),
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            labelAlignment: ChartDataLabelAlignment.top,
                            textStyle: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
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
  }

  Widget _buildListaGastos() {
    if (_gastosDiaSeleccionadoLista.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No hay gastos registrados')),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _gastosDiaSeleccionadoLista.length,
        itemBuilder: (context, index) {
          final gasto = _gastosDiaSeleccionadoLista[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              child: const Icon(Icons.money_off, color: Colors.red),
            ),
            title: Text(
              gasto['descripcion'] ?? 'Sin descripción',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Categoría: ${gasto['categoria'] ?? 'Sin categoría'}\n${DateFormat('HH:mm').format(DateTime.parse(gasto['fecha']))}',
            ),
            trailing: Text(
              _formatearMoneda((gasto['monto'] as num).toDouble()),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResumenHoy() {
    final fechaSeleccionada = DateFormat(
      'dd/MM/yyyy',
    ).format(_selectedDateRange.end);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Resumen del día: ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  fechaSeleccionada,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResumenItem(
                  'Ventas',
                  _ventasCountHoy.toString(),
                  Icons.receipt,
                  Colors.blue,
                ),
                _buildResumenItem(
                  'Total',
                  _formatearMoneda(_ventasHoy),
                  Icons.attach_money,
                  Colors.green,
                ),
                _buildResumenItem(
                  'Promedio',
                  _ventasCountHoy > 0
                      ? _formatearMoneda(_ventasHoy / _ventasCountHoy)
                      : _formatearMoneda(0),
                  Icons.bar_chart,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSalesChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ventas por Período',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Últimos ${_ventasData.length} ${_ventasData.length == 1 ? 'día' : 'días'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _ventasData.isEmpty
                  ? const Center(
                      child: Text('No hay datos de ventas disponibles'),
                    )
                  : SfCartesianChart(
                      primaryXAxis: const CategoryAxis(
                        labelRotation: 45,
                        labelStyle: TextStyle(fontSize: 10),
                      ),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.compactCurrency(
                          symbol: 'Gs. ',
                          decimalDigits: 0,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        LineSeries<SalesData, String>(
                          dataSource: _ventasData,
                          xValueMapper: (SalesData sales, _) => sales.periodo,
                          yValueMapper: (SalesData sales, _) => sales.ventas,
                          name: 'Ventas',
                          markerSettings: const MarkerSettings(isVisible: true),
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            labelAlignment: ChartDataLabelAlignment.top,
                          ),
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductosRanking() {
    if (_productosMasVendidos.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No hay datos de productos vendidos')),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _productosMasVendidos.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final producto = _productosMasVendidos[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.1),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              producto['nombre'] ?? 'Producto desconocido',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('${producto['cantidad']} unidades'),
            trailing: Text(
              _formatearMoneda((producto['total'] as num).toDouble()),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('Dispose de ReportsScreen - Removiendo listeners');
    try {
      _transactionNotifier.transactionsNotifier.removeListener(
        _onTransactionUpdated,
      );
      debugPrint('Listener de transacciones removido correctamente');
    } catch (e) {
      debugPrint('Error al remover listener de transacciones: $e');
    }

    _tabController.dispose();
    _dataUpdated.dispose();
    super.dispose();
  }
}

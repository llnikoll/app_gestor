import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/transaction_notifier_service.dart';
import '../services/settings_service.dart';
import '../utils/currency_formatter.dart';

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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Servicio de configuración
  late final SettingsService _settingsService;

  // Función para formatear montos según la moneda configurada
  String _formatearMoneda(double monto) {
    return context.formattedCurrency(monto);
  }

  // Obtener el símbolo de moneda actual
  String get _currencySymbol {
    return _settingsService.currentCurrency.symbol;
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
  final List<Map<String, dynamic>> _productosMasVendidos = [];

  // Datos para el resumen del día
  double _ventasHoy = 0.0;
  int _ventasCountHoy = 0;

  // Chart controller for ventas
  ChartSeriesController? _ventasChartController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService();
    _tabController = TabController(
      length: 3,
      vsync: this,
      // Prevent animations when switching tabs to avoid disposed object issues
      animationDuration: Duration.zero,
    );

    // Ensure the tab controller is kept alive
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Configurar el listener para actualizar los datos cuando haya cambios en las transacciones
    _onTransactionUpdated = () {
      if (!mounted) return;
      final value = _transactionNotifier.transactionsNotifier.value;
      debugPrint(
        'Notificación de transacción recibida (valor: $value) - Recargando datos...',
      );
      _cargarDatos();
    };

    // Agregar el listener al notifier
    _transactionNotifier.transactionsNotifier
        .addListener(_onTransactionUpdated);
    debugPrint('Listener de transacciones registrado en ReportsScreen');

    // Cargar los datos iniciales solo cuando la pestaña esté activa
    _tabController.addListener(_handleTabChange);

    // Cargar los datos iniciales al inicio si la pestaña de resumen es la primera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tabController.index == 0) {
        _cargarTodo();
      }
    });
  }

  void _handleTabChange() {
    if (!mounted || _tabController.indexIsChanging) return;

    // Only load data if we're switching to the first tab (index 0)
    if (_tabController.index == 0) {
      _cargarTodo();
    }
  }

  Future<void> _cargarTodo() async {
    if (!mounted) return;

    try {
      await _cargarDatos();
      if (!mounted) return;

      await _cargarVentas();
      if (!mounted) return;

      await _cargarGastos();
      if (!mounted) return;

      await _cargarClientes();
      if (!mounted) return;

      await _cargarProductos();
    } catch (e) {
      debugPrint('Error en _cargarTodo: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      debugPrint('Iniciando carga de datos...');

      final stopwatch = Stopwatch()..start();

      // Cargar en paralelo para reducir tiempos de espera
      final futures = [
        _cargarVentas().then((_) {
          debugPrint('Ventas cargadas en ${stopwatch.elapsedMilliseconds}ms');
          stopwatch.reset();
        }),
        _cargarGastos().then((_) {
          debugPrint('Gastos cargados en ${stopwatch.elapsedMilliseconds}ms');
          stopwatch.reset();
        }),
        _cargarProductos().then((_) {
          debugPrint(
              'Productos cargados en ${stopwatch.elapsedMilliseconds}ms');
          stopwatch.reset();
        }),
        _cargarClientes().then((_) {
          debugPrint('Clientes cargados en ${stopwatch.elapsedMilliseconds}ms');
        }),
      ];

      await Future.wait(futures);

      debugPrint('Carga de datos completada exitosamente');

      // Forzar actualización de la UI después de cargar todos los datos
      if (!mounted) return;
      _dataUpdated.value++;
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error en _cargarDatos: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar datos: ${e.toString()}';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

      final ventasPorDia = <String, double>{};
      double totalVentas = 0;
      double ventasHoy = 0;
      int ventasCountHoy = 0;

      for (var venta in ventas) {
        try {
          final fecha = DateFormat('dd/MM/yyyy').format(venta.fecha);
          ventasPorDia[fecha] = (ventasPorDia[fecha] ?? 0) + venta.total;
          totalVentas += venta.total;
          
          // Calcular ventas del día seleccionado
          if (venta.fecha.year == _selectedDateRange.end.year &&
              venta.fecha.month == _selectedDateRange.end.month &&
              venta.fecha.day == _selectedDateRange.end.day) {
            ventasHoy += venta.total;
            ventasCountHoy++;
          }
        } catch (e) {
          debugPrint('Error procesando venta: $e');
          continue;
        }
      }

      final ventasData = ventasPorDia.entries
          .map((e) => SalesData(e.key, e.value))
          .toList()
        ..sort((a, b) => a.periodo.compareTo(b.periodo));

      if (!mounted) return;
      
      setState(() {
        _ventasTotales = totalVentas;
        _ventasHoy = ventasHoy;
        _ventasCountHoy = ventasCountHoy;
      });
      
      _updateVentasData(ventasData);
      _updateFinancialData(totalVentas, _gastosTotales);

      debugPrint('Total de ventas procesadas: ${ventasData.length}');
      debugPrint('Ventas hoy: $ventasCountHoy, Total: $ventasHoy');
    } catch (e, stackTrace) {
      debugPrint('Error cargando ventas: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar ventas: ${e.toString()}';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar ventas: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      rethrow;
    }
  }

  // Update ventas data using controller
  void _updateVentasData(List<SalesData> newData) {
    if (!mounted) return;

    try {
      // Update the data first
      _ventasData.clear();
      _ventasData.addAll(newData);

      // Only update via controller if it's safe to do so
      if (mounted && _ventasChartController != null) {
        // Use a post-frame callback to ensure the widget is still in the tree
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          try {
            final oldData = List<SalesData>.from(_ventasData);
            final addedIndices = <int>[];
            final updatedIndices = <int>[];

            for (int i = 0; i < newData.length; i++) {
              if (i >= oldData.length) {
                addedIndices.add(i);
              } else if (newData[i].periodo != oldData[i].periodo ||
                  newData[i].ventas != oldData[i].ventas) {
                updatedIndices.add(i);
              }
            }

            _ventasChartController?.updateDataSource(
              addedDataIndexes: addedIndices,
              updatedDataIndexes: updatedIndices,
              removedDataIndexes: const <int>[],
            );
          } catch (e) {
            debugPrint('Error updating chart data: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('Error in _updateVentasData: $e');
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

      if (!mounted) return;
      setState(() {
        _gastosData = gastosData;
      });

      debugPrint(
        'Datos de gastos para el gráfico: ${gastosData.length} puntos',
      );

      _updateFinancialData(-1, totalGastos);
    } catch (e, stackTrace) {
      debugPrint('Error cargando gastos: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar gastos: ${e.toString()}';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar gastos: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
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

      if (!mounted) return;

      _dataUpdated.value++;
    } catch (e, stackTrace) {
      debugPrint('Error en _updateFinancialData: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
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

      _productosMasVendidos.clear();

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

          _productosMasVendidos.add({
            'nombre': nombreProducto,
            'cantidad': cantidad,
            'total': total,
          });
          
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
        _productosData.addAll(productos.entries.map((entry) => ProductoData(
          entry.key,
          entry.value['cantidad'] ?? 0,
          (entry.value['total'] ?? 0).toDouble(),
        )));
      });

      debugPrint('Total de productos procesados: ${_productosMasVendidos.length}');
    } catch (e, stackTrace) {
      debugPrint('Error cargando productos: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar productos: ${e.toString()}';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar productos: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
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

      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar clientes: ${e.toString()}';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar clientes: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return ValueListenableBuilder<int>(
      valueListenable: _dataUpdated,
      builder: (context, value, _) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 3.0,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.normal),
              tabs: const [
                Tab(
                  icon: Icon(Icons.bar_chart),
                  text: 'Resumen',
                ),
                Tab(
                  icon: Icon(Icons.shopping_cart),
                  text: 'Ventas',
                ),
                Tab(
                  icon: Icon(Icons.money_off),
                  text: 'Gastos',
                ),
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

  Future<void> _seleccionarFechaInicio() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _selectedDateRange.start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      final newStartDate = DateTime(fecha.year, fecha.month, fecha.day);
      if (!mounted) return;
      setState(() {
        _selectedDateRange = DateTimeRange(
          start: newStartDate,
          end: _selectedDateRange.end,
        );
      });
      await _cargarDatos();
    }
  }

  Future<void> _seleccionarFechaFin() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _selectedDateRange.end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      final newEndDate =
          DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59, 999);
      if (!mounted) return;
      setState(() {
        _selectedDateRange = DateTimeRange(
          start: _selectedDateRange.start,
          end: newEndDate,
        );
      });
      await _cargarDatos();
    }
  }

  Widget _buildDateRangeInfo() {
    final formatter = DateFormat('dd/MM/yyyy');
    return Card(
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
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
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
                            formatter.format(_selectedDateRange.start),
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
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
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
                            formatter.format(_selectedDateRange.end),
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
    );
  }

  Widget _buildFinancialSummary() {
    return ValueListenableBuilder<int>(
      valueListenable: _dataUpdated,
      builder: (context, value, _) {
        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen Financiero',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _financialData.map((data) {
                    IconData icon;
                    switch (data.concepto) {
                      case 'Ventas':
                        icon = Icons.attach_money;
                        break;
                      case 'Gastos':
                        icon = Icons.money_off;
                        break;
                      case 'Ganancias':
                        icon = Icons.bar_chart;
                        break;
                      default:
                        icon = Icons.analytics_rounded;
                    }
                    return _buildResumenItem(
                      data.concepto,
                      _formatearMoneda(data.monto),
                      icon,
                      data.color,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
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
          Text(
            'Gastos por Categoría',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
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
      elevation: 6, // Increased elevation
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0)), // More rounded corners
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Increased padding
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Resumen de Gastos: ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                  Text(
                    fechaSeleccionada,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .error, // Changed color
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // Increased spacing
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
                            _gastosDiaSeleccionado /
                                _gastosCountDiaSeleccionado,
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
      ),
    );
  }

  Widget _buildGastosChart() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastos por Período',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: _gastosData.isEmpty
                  ? Center(
                      child: Text(
                        'No hay datos de gastos disponibles para este período.',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : SfCartesianChart(
                      primaryXAxis: CategoryAxis(
                        labelRotation: 45,
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                        majorGridLines: const MajorGridLines(
                            width: 0), // Removed grid lines
                      ),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.currency(
                          symbol: '$_currencySymbol ',
                          decimalDigits: 0,
                        ),
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                        majorGridLines: const MajorGridLines(
                            width: 0.5,
                            color: Colors.grey), // Lighter grid lines
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
                            shape: DataMarkerType.circle,
                            borderColor: Colors.white,
                            borderWidth: 2,
                            width: 8,
                            height: 8,
                          ),
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            labelAlignment: ChartDataLabelAlignment.top,
                            textStyle: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          width: 3, // Thicker line
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
        elevation: 6, // Increased elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0), // More rounded corners
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0), // Increased padding
          child: Center(
            child: Text(
              'No hay gastos registrados para este período.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 6, // Increased elevation
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0)), // More rounded corners
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _gastosDiaSeleccionadoLista.length,
        itemBuilder: (context, index) {
          final gasto = _gastosDiaSeleccionadoLista[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10), // Increased padding
            leading: CircleAvatar(
              backgroundColor:
                  Colors.red.withOpacity(0.15), // More opaque background
              child: const Icon(Icons.money_off,
                  color: Colors.red, size: 28), // Larger icon
            ),
            title: Text(
              gasto['descripcion'] ?? 'Sin descripción',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold), // Larger and bolder title
            ),
            subtitle: Text(
              'Categoría: ${gasto['categoria'] ?? 'Sin categoría'}\nFecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(gasto['fecha']))}', // Added "Fecha:" and full date format
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700]), // Adjusted text style
            ),
            trailing: Text(
              _formatearMoneda((gasto['monto'] as num).toDouble()),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ), // Larger and bolder trailing text
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
      elevation: 6, // Increased elevation
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0)), // More rounded corners
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Resumen del día: ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                Text(
                  fechaSeleccionada,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary, // Changed color
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Increased spacing
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
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16), // Increased padding
            decoration: BoxDecoration(
              color: color.withValues(
                  alpha: 0.15), // Slightly more opaque background
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32), // Larger icon
          ),
          const SizedBox(height: 12), // Increased spacing
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  // Larger font size
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4), // Increased spacing
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  // Larger font size
                  color: Colors.grey[700],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart() {
    return Card(
      elevation: 6, // Increased elevation
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0)), // More rounded corners
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ventas por Período',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                Text(
                  'Últimos ${_ventasData.length} ${_ventasData.length == 1 ? 'día' : 'días'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 20), // Increased spacing
            SizedBox(
              height: 280, // Increased height
              child: _ventasData.isEmpty
                  ? Center(
                      child: Text(
                        'No hay datos de ventas disponibles para este período.',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : SfCartesianChart(
                      primaryXAxis: CategoryAxis(
                        labelRotation: 45,
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                        majorGridLines: const MajorGridLines(
                            width: 0), // Removed grid lines
                      ),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.currency(
                          symbol: '$_currencySymbol ',
                          decimalDigits: 0,
                        ),
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                        majorGridLines: const MajorGridLines(
                            width: 0.5,
                            color: Colors.grey), // Lighter grid lines
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        LineSeries<SalesData, String>(
                          onRendererCreated: (ChartSeriesController controller) {
                            _ventasChartController = controller;
                          },
                          dataSource: _ventasData,
                          xValueMapper: (SalesData venta, _) => venta.periodo,
                          yValueMapper: (SalesData venta, _) => venta.ventas,
                          name: 'Ventas',
                          color: Theme.of(context).primaryColor,
                          markerSettings: const MarkerSettings(
                            isVisible: true,
                            shape: DataMarkerType.circle,
                            borderColor: Colors.white,
                            borderWidth: 2,
                            width: 8,
                            height: 8,
                          ),
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            labelAlignment: ChartDataLabelAlignment.top,
                            textStyle: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          width: 3, // Thicker line
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
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Text(
              'No hay datos de productos vendidos para este período.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _productosMasVendidos.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 20,
          endIndent: 20,
          color: Colors.grey[300],
        ),
        itemBuilder: (context, index) {
          final producto = _productosMasVendidos[index];
          final nombre = producto['nombre'] as String? ?? 'Producto desconocido';
          final cantidad = (producto['cantidad'] as int?) ?? 0;
          final total = (producto['total'] as num?)?.toDouble() ?? 0.0;
          
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            title: Text(
              nombre,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: Text(
              '$cantidad ${cantidad == 1 ? 'unidad' : 'unidades'}' ,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            trailing: Text(
              _formatearMoneda(total),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Remove the transaction listener if it was added
    try {
      _transactionNotifier.transactionsNotifier.removeListener(_onTransactionUpdated);
    } catch (e) {
      debugPrint('Error removing transaction listener: $e');
    }
    
    // Clear data lists
    _clientesData.clear();
    _productosData.clear();
    _gastosDiaSeleccionadoLista.clear();
    _productosMasVendidos.clear();
    _ventasData.clear();
    _gastosData.clear();
    
    // Dispose controllers and notifiers
    _tabController.dispose();
    // No need to dispose _ventasChartController as it doesn't have a dispose method
    _dataUpdated.dispose();
    
    super.dispose();
  }
}

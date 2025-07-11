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
    with SingleTickerProviderStateMixin {
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
  List<Map<String, dynamic>> _productosMasVendidos = [];

  // Datos para el resumen del día
  double _ventasHoy = 0.0;
  int _ventasCountHoy = 0;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService();
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
              productosMap[productoId]!['total'] +=
                  (detalle['subtotal'] as num).toDouble();
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
      final newEndDate = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59, 999);
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () {},
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 140,
            maxWidth: double.infinity,
          ),
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(icon, color: data.color, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatearMoneda(data.monto),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.concepto,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
      ),
    );
  }

  Widget _buildGastosChart() {
    return Card(
      elevation: 6, // Increased elevation
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0)), // More rounded corners
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Increased padding
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
            const SizedBox(height: 20), // Increased spacing
            SizedBox(
              height: 280, // Increased height
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
                  Colors.red.withValues(alpha: 0.15), // More opaque background
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
                          dataSource: _ventasData,
                          xValueMapper: (SalesData sales, _) => sales.periodo,
                          yValueMapper: (SalesData sales, _) => sales.ventas,
                          name: 'Ventas',
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
                          color: Theme.of(context).primaryColor,
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
        elevation: 6, // Increased elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0), // More rounded corners
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0), // Increased padding
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
      elevation: 6, // Increased elevation
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0)), // More rounded corners
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _productosMasVendidos.length,
        separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: Colors.grey[300]), // Lighter divider
        itemBuilder: (context, index) {
          final producto = _productosMasVendidos[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10), // Increased padding
            leading: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.15), // More opaque background
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18, // Larger font size
                ),
              ),
            ),
            title: Text(
              producto['nombre'] ?? 'Producto desconocido',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold), // Larger and bolder title
            ),
            subtitle: Text(
              '${producto['cantidad']} unidades',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700]), // Adjusted text style
            ),
            trailing: Text(
              _formatearMoneda((producto['total'] as num).toDouble()),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ), // Larger and bolder trailing text
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

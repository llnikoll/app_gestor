import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:app_gestor_ventas/services/database_service.dart';

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

  // Rango de fechas seleccionado
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  // Datos para los gráficos y tablas
  final List<SalesData> _ventasData = [];
  final List<FinancialData> _financialData = [];
  final List<ClienteData> _clientesData = [];
  final List<ProductoData> _productosData = [];
  // _categoriasData se eliminó porque no se estaba utilizando

  // Estado de carga y errores
  bool _isLoading = true;
  String _errorMessage = '';

  // Notificador para actualizar la UI cuando cambian los datos
  // Usamos un booleano que alternamos para forzar la reconstrucción
  final ValueNotifier<bool> _dataUpdated = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
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
        setState(() {
          _isLoading = false;
        });
        _dataUpdated.value = !_dataUpdated.value; // Alternar el valor para forzar la actualización
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _cargarDatos: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos: ${e.toString()}';
        });

        // Mostrar snackbar con el error
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
    // Función para mostrar el SnackBar de manera segura
    void showErrorSnackBar(String message) {
      if (!mounted) return;
      
      // Usar el ScaffoldMessenger del contexto raíz
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
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

      // Verificar si el widget sigue montado después del await
      if (!mounted) return;
      
      if (picked != null && picked != _selectedDateRange) {
        setState(() {
          _selectedDateRange = picked;
        });
        await _cargarDatos();
      }
    } catch (e) {
      debugPrint('Error al seleccionar rango de fechas: $e');
      
      // Mostrar el error usando la función segura
      showErrorSnackBar('Error al seleccionar fechas: $e');
    }
  }

  Future<void> _cargarVentas() async {
    if (!mounted) return;

    try {
      debugPrint(
        'Buscando ventas desde ${_selectedDateRange.start} hasta ${_selectedDateRange.end}',
      );

      // Obtener ventas de la base de datos
      final ventas = await _dbService.getVentasPorRango(
        _selectedDateRange.start,
        _selectedDateRange.end,
      );

      debugPrint('Ventas encontradas: ${ventas.length}');

      // Procesar ventas por día para el gráfico de líneas
      final ventasPorDia = <DateTime, double>{};
      double totalVentas = 0;

      for (var venta in ventas) {
        try {
          final fecha = DateTime(
            venta.fecha.year,
            venta.fecha.month,
            venta.fecha.day,
          );

          // Validar que el total sea un número válido
          if (venta.total.isNaN || venta.total.isInfinite) {
            debugPrint(
              'Advertencia: Venta ${venta.id} tiene un total inválido: ${venta.total}',
            );
            continue;
          }

          ventasPorDia[fecha] = (ventasPorDia[fecha] ?? 0) + venta.total;
          totalVentas += venta.total;

          debugPrint(
            'Venta: ${venta.id} - Fecha: ${venta.fecha} - Total: ${venta.total}',
          );
        } catch (e) {
          debugPrint('Error procesando venta ${venta.id}: $e');
          continue; // Continuar con la siguiente venta en caso de error
        }
      }

      // Ordenar las fechas para asegurar un orden cronológico
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

      // Actualizar el estado en un solo setState
      setState(() {
        _ventasData.clear();
        _ventasData.addAll(ventasData);
      });

      // Actualizar los datos financieros
      _updateFinancialData(totalVentas, -1);
    } catch (e, stackTrace) {
      debugPrint('Error cargando ventas: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar ventas: ${e.toString()}';
        });

        // Mostrar snackbar con el error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ventas: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Relanzar el error para que pueda ser manejado por _cargarDatos
      rethrow;
    }
  }

  Future<void> _cargarGastos() async {
    if (!mounted) return;

    try {
      debugPrint(
        'Buscando gastos desde ${_selectedDateRange.start} hasta ${_selectedDateRange.end}',
      );

      // Obtener gastos de la base de datos
      final gastos = await _dbService.getGastosPorRango(
        _selectedDateRange.start,
        _selectedDateRange.end,
      );

      debugPrint('Gastos encontrados: ${gastos.length}');

      // Calcular total de gastos para el resumen
      double totalGastos = 0;

      for (var gasto in gastos) {
        try {
          // Validar que el monto sea un número válido
          if (gasto.monto.isNaN || gasto.monto.isInfinite) {
            debugPrint(
              'Advertencia: Gasto ${gasto.id} tiene un monto inválido: ${gasto.monto}',
            );
            continue;
          }

          totalGastos += gasto.monto;
          debugPrint(
            'Gasto: ${gasto.id} - Fecha: ${gasto.fecha} - Monto: ${gasto.monto}',
          );
        } catch (e) {
          debugPrint('Error procesando gasto ${gasto.id}: $e');
          continue; // Continuar con el siguiente gasto en caso de error
        }
      }

      debugPrint('Total de gastos calculado: $totalGastos');

      if (!mounted) return;

      // Actualizar los datos financieros con el total de gastos
      _updateFinancialData(-1, totalGastos);
    } catch (e, stackTrace) {
      debugPrint('Error cargando gastos: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar gastos: ${e.toString()}';
        });

        // Mostrar snackbar con el error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar gastos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Relanzar el error para que pueda ser manejado por _cargarDatos
      rethrow;
    }
  }

  void _updateFinancialData(double totalVentas, double totalGastos) {
    if (!mounted) return;

    debugPrint(
      'Iniciando actualización de datos financieros - Ventas: $totalVentas, Gastos: $totalGastos',
    );

    try {
      // Obtener los valores actuales si existen
      double ventasActuales = 0;
      double gastosActuales = 0;

      // Usar try-catch para evitar errores si la lista está vacía o no tiene los elementos esperados
      if (_financialData.isNotEmpty) {
        try {
          final ventasData = _financialData.firstWhere(
            (data) => data.concepto == 'Ventas',
            orElse: () => FinancialData('Ventas', 0, Colors.green),
          );
          ventasActuales = ventasData.monto;

          final gastosData = _financialData.firstWhere(
            (data) => data.concepto == 'Gastos',
            orElse: () => FinancialData('Gastos', 0, Colors.red),
          );
          gastosActuales = gastosData.monto;
        } catch (e) {
          debugPrint('Error al obtener datos financieros actuales: $e');
          // Continuar con valores por defecto si hay un error
        }
      }

      debugPrint(
        'Valores actuales - Ventas: $ventasActuales, Gastos: $gastosActuales',
      );

      // Actualizar solo los valores que se están pasando (si son mayores o iguales a 0)

      if (totalVentas >= 0) {
        debugPrint('Actualizando ventas de $ventasActuales a $totalVentas');
        ventasActuales = totalVentas;
      }

      if (totalGastos >= 0) {
        debugPrint('Actualizando gastos de $gastosActuales a $totalGastos');
        gastosActuales = totalGastos;
      }

      // Siempre actualizar los datos financieros para asegurar que estén actualizados
      if (mounted) {
        setState(() {
          _financialData.clear();
          _financialData.addAll([
            FinancialData('Ventas', ventasActuales, Colors.green),
            FinancialData('Gastos', gastosActuales, Colors.red),
            FinancialData(
              'Ganancias',
              ventasActuales - gastosActuales,
              Colors.blue,
            ),
          ]);
        });

        debugPrint(
          'Datos financieros actualizados - Ventas: $ventasActuales, Gastos: $gastosActuales, Ganancias: ${ventasActuales - gastosActuales}',
        );

        // Alternar el valor para forzar la reconstrucción del ValueListenableBuilder
        _dataUpdated.value = !_dataUpdated.value;
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _updateFinancialData: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        // Mostrar snackbar con el error
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

      // Procesar productos más vendidos
      final productosData = <ProductoData>[];

      for (var entry in productos.entries) {
        try {
          final nombreProducto = entry.key;
          final cantidad = entry.value['cantidad'] ?? 0;
          final total = (entry.value['total'] ?? 0).toDouble();

          // Validar datos
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
          continue; // Continuar con el siguiente producto en caso de error
        }
      }

      if (!mounted) return;

      // Actualizar el estado en un solo setState
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

        // Mostrar snackbar con el error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar productos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Relanzar el error para que pueda ser manejado por _cargarDatos
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

      // Procesar clientes frecuentes
      final clientesData = <ClienteData>[];

      for (var entry in clientes.entries) {
        try {
          final nombreCliente = entry.key;
          final compras = entry.value['compras'] ?? 0;
          final total = (entry.value['total'] ?? 0).toDouble();

          // Validar datos
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
          continue; // Continuar con el siguiente cliente en caso de error
        }
      }

      if (!mounted) return;

      // Actualizar el estado en un solo setState
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

        // Mostrar snackbar con el error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Relanzar el error para que pueda ser manejado por _cargarDatos
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Forzar la reconstrucción cuando los datos cambien
    return ValueListenableBuilder<bool>(
      valueListenable: _dataUpdated,
      builder: (context, _, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Informes'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.analytics), text: 'Resumen'),
                Tab(icon: Icon(Icons.bar_chart), text: 'Ventas'),
                Tab(icon: Icon(Icons.category), text: 'Categorías'),
                Tab(icon: Icon(Icons.people), text: 'Clientes'),
              ],
            ),
            actions: [
              Builder(
                builder: (BuildContext context) => IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: () => _selectDateRange(context),
                  tooltip: 'Seleccionar rango de fechas',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _cargarDatos,
                tooltip: 'Actualizar datos',
              ),
            ],
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
                    _buildCategoriasTab(),
                    _buildClientesTab(),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _cargarDatos,
            child: const Icon(Icons.refresh),
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
        children: [
          _buildDateRangeInfo(),
          const SizedBox(height: 20),
          _buildSalesChart(),
          const SizedBox(height: 20),
          _buildSalesTable(),
        ],
      ),
    );
  }

  Widget _buildCategoriasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildDateRangeInfo(),
          const SizedBox(height: 20),
          _buildCategoriesChart(),
          const SizedBox(height: 20),
          _buildCategoriesTable(),
        ],
      ),
    );
  }

  Widget _buildClientesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildDateRangeInfo(),
          const SizedBox(height: 20),
          _buildTopClientsChart(),
          const SizedBox(height: 20),
          _buildClientsTable(),
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
    // Usar ValueListenableBuilder para reconstruir cuando los datos cambien
    return ValueListenableBuilder<bool>(
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

  // Resto de los métodos para las otras pestañas...
  Widget _buildSalesChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ventas por Día',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.currency(symbol: 'Gs. '),
                ),
                series: <CartesianSeries>[
                  LineSeries<SalesData, String>(
                    dataSource: _ventasData,
                    xValueMapper: (SalesData sales, _) => sales.periodo,
                    yValueMapper: (SalesData sales, _) => sales.ventas,
                    name: 'Ventas',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTable() {
    // Implementación de la tabla de ventas
    return const SizedBox.shrink();
  }

  Widget _buildCategoriesChart() {
    // Implementación del gráfico de categorías
    return const SizedBox.shrink();
  }

  Widget _buildCategoriesTable() {
    // Implementación de la tabla de categorías
    return const SizedBox.shrink();
  }

  Widget _buildTopClientsChart() {
    // Implementación del gráfico de clientes
    return const SizedBox.shrink();
  }

  Widget _buildClientsTable() {
    // Implementación de la tabla de clientes
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dataUpdated.dispose();
    super.dispose();
  }
}

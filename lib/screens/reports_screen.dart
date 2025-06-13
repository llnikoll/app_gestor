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

  // Rango de fechas seleccionado
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

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

  // Notificador para actualizar la UI
  final ValueNotifier<int> _dataUpdated = ValueNotifier<int>(0);

  // Notificador de transacciones
  final TransactionNotifierService _transactionNotifier =
      TransactionNotifierService();
  late final VoidCallback _onTransactionUpdated;

  // Variables para el resumen financiero
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

    // Configurar listener para transacciones
    _onTransactionUpdated = () {
      if (mounted) {
        _cargarDatos();
      }
    };

    _transactionNotifier.transactionsNotifier.addListener(
      _onTransactionUpdated,
    );
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
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await Future.wait([
        _cargarVentas(),
        _cargarGastos(),
        _cargarProductos(),
        _cargarClientes(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _dataUpdated.value++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar datos: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
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
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDateRange = DateTimeRange(
          start: picked.start,
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
            999,
          ),
        );
      });
      await _cargarDatos();
    }
  }

  Future<void> _cargarVentas() async {
    final ventas = await _dbService.getVentasPorRango(
      _selectedDateRange.start,
      _selectedDateRange.end,
    );
    final ventasPorDia = <DateTime, double>{};
    double totalVentas = 0;
    double ventasDiaSeleccionado = 0.0;
    int ventasCountDiaSeleccionado = 0;
    final productosMap = <String, Map<String, dynamic>>{};

    for (var venta in ventas) {
      final fecha = DateTime(
        venta.fecha.year,
        venta.fecha.month,
        venta.fecha.day,
      );
      if (!venta.total.isNaN && !venta.total.isInfinite) {
        ventasPorDia[fecha] = (ventasPorDia[fecha] ?? 0) + venta.total;
        totalVentas += venta.total;

        if (fecha.day == _selectedDateRange.end.day &&
            fecha.month == _selectedDateRange.end.month &&
            fecha.year == _selectedDateRange.end.year) {
          ventasDiaSeleccionado += venta.total;
          ventasCountDiaSeleccionado++;
        }

        final detalles = await _dbService.getDetallesVenta(venta.id!);
        for (var detalle in detalles) {
          final productoId = detalle['producto_id'].toString();
          if (productoId != 'null') {
            productosMap.putIfAbsent(
              productoId,
              () => {
                'id': detalle['producto_id'],
                'nombre': detalle['nombre_producto'] ?? 'Producto desconocido',
                'cantidad': 0,
                'total': 0.0,
              },
            );
            productosMap[productoId]!['cantidad'] += detalle['cantidad'] as int;
            productosMap[productoId]!['total'] += (detalle['subtotal'] as num)
                .toDouble();
          }
        }
      }
    }

    final productosList = productosMap.values.toList()
      ..sort((a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int));
    final topProductos = productosList.take(10).toList();
    final ventasData =
        ventasPorDia.entries
            .map(
              (entry) =>
                  SalesData(DateFormat('dd/MM').format(entry.key), entry.value),
            )
            .toList()
          ..sort(
            (a, b) => DateFormat(
              'dd/MM',
            ).parse(a.periodo).compareTo(DateFormat('dd/MM').parse(b.periodo)),
          );

    if (mounted) {
      setState(() {
        _ventasData.clear();
        _ventasData.addAll(ventasData);
        _productosMasVendidos = topProductos;
        _ventasHoy = ventasDiaSeleccionado;
        _ventasCountHoy = ventasCountDiaSeleccionado;
      });
      _updateFinancialData(totalVentas, -1);
    }
  }

  Future<void> _cargarGastos() async {
    final gastos = await _dbService.getGastosPorRango(
      _selectedDateRange.start,
      _selectedDateRange.end,
    );
    final gastosPorDia = <DateTime, double>{};
    double totalGastos = 0;

    _gastosDiaSeleccionado = 0.0;
    _gastosCountDiaSeleccionado = 0;
    _gastosDiaSeleccionadoLista = [];

    for (var gasto in gastos) {
      final fecha = DateTime(
        gasto.fecha.year,
        gasto.fecha.month,
        gasto.fecha.day,
      );
      if (!gasto.monto.isNaN && !gasto.monto.isInfinite) {
        gastosPorDia[fecha] = (gastosPorDia[fecha] ?? 0) + gasto.monto;
        totalGastos += gasto.monto;

        if (fecha.day == _selectedDateRange.end.day &&
            fecha.month == _selectedDateRange.end.month &&
            fecha.year == _selectedDateRange.end.year) {
          _gastosDiaSeleccionado += gasto.monto;
          _gastosCountDiaSeleccionado++;
          _gastosDiaSeleccionadoLista.add({
            'descripcion': gasto.descripcion,
            'monto': gasto.monto,
            'categoria': gasto.categoria,
            'fecha': gasto.fecha.toIso8601String(),
          });
        }
      }
    }

    final gastosData =
        gastosPorDia.entries
            .map(
              (entry) =>
                  SalesData(DateFormat('dd/MM').format(entry.key), entry.value),
            )
            .toList()
          ..sort(
            (a, b) => DateFormat(
              'dd/MM',
            ).parse(a.periodo).compareTo(DateFormat('dd/MM').parse(b.periodo)),
          );

    if (mounted) {
      setState(() {
        _gastosData = gastosData;
      });
      _updateFinancialData(-1, totalGastos);
    }
  }

  void _updateFinancialData(double totalVentas, double totalGastos) {
    if (totalVentas >= 0) _ventasTotales = totalVentas;
    if (totalGastos >= 0) _gastosTotales = totalGastos;
    _gananciasTotales = _ventasTotales - _gastosTotales;

    _financialData.clear();
    _financialData.addAll([
      FinancialData('Ventas', _ventasTotales, Colors.green),
      FinancialData('Gastos', _gastosTotales, Colors.red),
      FinancialData('Ganancias', _gananciasTotales, Colors.blue),
    ]);

    if (mounted) _dataUpdated.value++;
  }

  Future<void> _cargarProductos() async {
    final productos = await _dbService.getProductosMasVendidos(
      _selectedDateRange.start,
      _selectedDateRange.end,
    );
    final productosData = <ProductoData>[];

    for (var entry in productos.entries) {
      final cantidad = entry.value['cantidad'] ?? 0;
      final total = (entry.value['total'] ?? 0).toDouble();
      if (cantidad >= 0 && !total.isNaN && !total.isInfinite) {
        productosData.add(ProductoData(entry.key, cantidad, total));
      }
    }

    if (mounted) {
      setState(() {
        _productosData.clear();
        _productosData.addAll(productosData);
      });
    }
  }

  Future<void> _cargarClientes() async {
    final clientes = await _dbService.getClientesFrecuentes(
      _selectedDateRange.start,
      _selectedDateRange.end,
    );
    final clientesData = <ClienteData>[];

    for (var entry in clientes.entries) {
      final compras = entry.value['compras'] ?? 0;
      final total = (entry.value['total'] ?? 0).toDouble();
      if (compras >= 0 && !total.isNaN && !total.isInfinite) {
        clientesData.add(ClienteData(entry.key, compras, total));
      }
    }

    if (mounted) {
      setState(() {
        _clientesData.clear();
        _clientesData.addAll(clientesData);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return ValueListenableBuilder<int>(
      valueListenable: _dataUpdated,
      builder: (context, _, _) {
        return Scaffold(
          extendBodyBehindAppBar: false,
          appBar: AppBar(
            toolbarHeight: 20,
            centerTitle: true,
            elevation: 2,
            shadowColor: Theme.of(
              context,
            ).colorScheme.shadow.withValues(alpha: 0.1),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: SafeArea(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isLargeScreen,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.summarize), text: 'Resumen'),
                    Tab(icon: Icon(Icons.shopping_cart), text: 'Ventas'),
                    Tab(icon: Icon(Icons.money_off), text: 'Gastos'),
                  ],
                ),
              ),
            ),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResumenTab(isLargeScreen),
                      _buildVentasTab(isLargeScreen),
                      _buildGastosTab(isLargeScreen),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildResumenTab(bool isLargeScreen) {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView(
        padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
        children: [
          _buildDateRangeInfo(isLargeScreen),
          SizedBox(height: isLargeScreen ? 24 : 16),
          _buildFinancialSummary(isLargeScreen),
        ],
      ),
    );
  }

  Widget _buildVentasTab(bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeInfo(isLargeScreen),
          SizedBox(height: isLargeScreen ? 24 : 16),
          _buildResumenHoy(isLargeScreen),
          SizedBox(height: isLargeScreen ? 24 : 16),
          _buildSalesChart(isLargeScreen),
          SizedBox(height: isLargeScreen ? 24 : 16),
          Text(
            'Productos más vendidos',
            style: TextStyle(
              fontSize: isLargeScreen ? 20 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isLargeScreen ? 16 : 10),
          _buildProductosRanking(isLargeScreen),
        ],
      ),
    );
  }

  Widget _buildGastosTab(bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeInfo(isLargeScreen),
          SizedBox(height: isLargeScreen ? 24 : 16),
          _buildResumenGastos(isLargeScreen),
          SizedBox(height: isLargeScreen ? 24 : 16),
          _buildGastosChart(isLargeScreen),
          SizedBox(height: isLargeScreen ? 24 : 16),
          Text(
            'Gastos por Categoría',
            style: TextStyle(
              fontSize: isLargeScreen ? 20 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isLargeScreen ? 16 : 10),
          _buildListaGastos(isLargeScreen),
        ],
      ),
    );
  }

  Widget _buildDateRangeInfo(bool isLargeScreen) {
    final formatter = DateFormat('dd/MM/yyyy');
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 24 : 16,
          vertical: isLargeScreen ? 12 : 8,
        ),
        leading: Icon(Icons.date_range, size: isLargeScreen ? 28 : 24),
        title: Text(
          'Rango de fechas seleccionado:',
          style: TextStyle(
            fontSize: isLargeScreen ? 16 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${formatter.format(_selectedDateRange.start)} - ${formatter.format(_selectedDateRange.end)}',
          style: TextStyle(fontSize: isLargeScreen ? 14 : 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit_calendar, size: isLargeScreen ? 28 : 24),
          onPressed: () => _selectDateRange(context),
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(bool isLargeScreen) {
    return ValueListenableBuilder<int>(
      valueListenable: _dataUpdated,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: isLargeScreen ? 24 : 16,
                top: 16,
                bottom: 8,
              ),
              child: Text(
                'Resumen Financiero',
                style: TextStyle(
                  fontSize: isLargeScreen ? 20 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isLargeScreen ? 3 : 1,
              childAspectRatio: isLargeScreen ? 3 : 2.5,
              crossAxisSpacing: isLargeScreen ? 24 : 16,
              mainAxisSpacing: isLargeScreen ? 24 : 16,
              padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
              children: _financialData
                  .map((data) => _buildSummaryCard(data, isLargeScreen))
                  .toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(FinancialData data, bool isLargeScreen) {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isLargeScreen ? 12 : 8),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: data.color,
                size: isLargeScreen ? 32 : 24,
              ),
            ),
            SizedBox(width: isLargeScreen ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.concepto,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 18 : 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 8 : 4),
                  Text(
                    _formatearMoneda(data.monto),
                    style: TextStyle(
                      fontSize: isLargeScreen ? 22 : 20,
                      fontWeight: FontWeight.bold,
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

  Widget _buildResumenHoy(bool isLargeScreen) {
    final fechaSeleccionada = DateFormat(
      'dd/MM/yyyy',
    ).format(_selectedDateRange.end);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Resumen del día: ',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  fechaSeleccionada,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 20 : 18,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isLargeScreen ? 24 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResumenItem(
                  'Ventas',
                  _ventasCountHoy.toString(),
                  Icons.receipt,
                  Colors.blue,
                  isLargeScreen,
                ),
                _buildResumenItem(
                  'Total',
                  _formatearMoneda(_ventasHoy),
                  Icons.attach_money,
                  Colors.green,
                  isLargeScreen,
                ),
                _buildResumenItem(
                  'Promedio',
                  _ventasCountHoy > 0
                      ? _formatearMoneda(_ventasHoy / _ventasCountHoy)
                      : _formatearMoneda(0),
                  Icons.bar_chart,
                  Colors.orange,
                  isLargeScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenGastos(bool isLargeScreen) {
    final fechaSeleccionada = DateFormat(
      'dd/MM/yyyy',
    ).format(_selectedDateRange.end);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Resumen de Gastos: ',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  fechaSeleccionada,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 20 : 18,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isLargeScreen ? 24 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResumenItem(
                  'Gastos',
                  _gastosCountDiaSeleccionado.toString(),
                  Icons.receipt,
                  Colors.red,
                  isLargeScreen,
                ),
                _buildResumenItem(
                  'Total',
                  _formatearMoneda(_gastosDiaSeleccionado),
                  Icons.money_off,
                  Colors.orange,
                  isLargeScreen,
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
                  isLargeScreen,
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
    bool isLargeScreen,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isLargeScreen ? 16 : 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: isLargeScreen ? 32 : 24),
        ),
        SizedBox(height: isLargeScreen ? 12 : 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isLargeScreen ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isLargeScreen ? 14 : 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSalesChart(bool isLargeScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ventas por Período',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Últimos ${_ventasData.length} ${_ventasData.length == 1 ? 'día' : 'días'}',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 14 : 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            SizedBox(height: isLargeScreen ? 24 : 16),
            SizedBox(
              height: isLargeScreen ? 300 : 250,
              child: _ventasData.isEmpty
                  ? const Center(
                      child: Text('No hay datos de ventas disponibles'),
                    )
                  : SfCartesianChart(
                      primaryXAxis: CategoryAxis(
                        labelRotation: 45,
                        labelStyle: TextStyle(
                          fontSize: isLargeScreen ? 12 : 10,
                        ),
                      ),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.compactCurrency(
                          symbol: 'Gs. ',
                          decimalDigits: 0,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        color: Theme.of(context).primaryColor,
                        textStyle: const TextStyle(color: Colors.white),
                      ),
                      series: <CartesianSeries>[
                        LineSeries<SalesData, String>(
                          dataSource: _ventasData,
                          xValueMapper: (SalesData sales, _) => sales.periodo,
                          yValueMapper: (SalesData sales, _) => sales.ventas,
                          name: 'Ventas',
                          color: Theme.of(context).primaryColor,
                          markerSettings: MarkerSettings(
                            isVisible: true,
                            color: Theme.of(context).primaryColor,
                            borderColor: Colors.white,
                            borderWidth: 2,
                          ),
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            labelAlignment: ChartDataLabelAlignment.top,
                            textStyle: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: isLargeScreen ? 12 : 10,
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

  Widget _buildGastosChart(bool isLargeScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastos por Período',
              style: TextStyle(
                fontSize: isLargeScreen ? 18 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isLargeScreen ? 24 : 16),
            SizedBox(
              height: isLargeScreen ? 300 : 250,
              child: _gastosData.isEmpty
                  ? const Center(
                      child: Text('No hay datos de gastos disponibles'),
                    )
                  : SfCartesianChart(
                      primaryXAxis: CategoryAxis(
                        labelRotation: 45,
                        labelStyle: TextStyle(
                          fontSize: isLargeScreen ? 12 : 10,
                        ),
                      ),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.currency(
                          symbol: 'Gs. ',
                          decimalDigits: 0,
                        ),
                      ),
                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        color: Colors.red,
                        textStyle: const TextStyle(color: Colors.white),
                      ),
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
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            labelAlignment: ChartDataLabelAlignment.top,
                            textStyle: TextStyle(
                              color: Colors.red,
                              fontSize: isLargeScreen ? 12 : 10,
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

  Widget _buildProductosRanking(bool isLargeScreen) {
    if (_productosMasVendidos.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
          child: const Center(
            child: Text('No hay datos de productos vendidos'),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _productosMasVendidos.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final producto = _productosMasVendidos[index];
          return ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 24 : 16,
              vertical: isLargeScreen ? 12 : 8,
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.1),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: isLargeScreen ? 16 : 14,
                ),
              ),
            ),
            title: Text(
              producto['nombre'] ?? 'Producto desconocido',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isLargeScreen ? 16 : 14,
              ),
            ),
            subtitle: Text(
              '${producto['cantidad']} unidades',
              style: TextStyle(fontSize: isLargeScreen ? 14 : 12),
            ),
            trailing: Text(
              _formatearMoneda((producto['total'] as num).toDouble()),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isLargeScreen ? 18 : 16,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListaGastos(bool isLargeScreen) {
    if (_gastosDiaSeleccionadoLista.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
          child: const Center(child: Text('No hay gastos registrados')),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _gastosDiaSeleccionadoLista.length,
        itemBuilder: (context, index) {
          final gasto = _gastosDiaSeleccionadoLista[index];
          return ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 24 : 16,
              vertical: isLargeScreen ? 12 : 8,
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              child: const Icon(Icons.money_off, color: Colors.red),
            ),
            title: Text(
              gasto['descripcion'] ?? 'Sin descripción',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isLargeScreen ? 16 : 14,
              ),
            ),
            subtitle: Text(
              'Categoría: ${gasto['categoria'] ?? 'Sin categoría'}\n${DateFormat('HH:mm').format(DateTime.parse(gasto['fecha']))}',
              style: TextStyle(fontSize: isLargeScreen ? 14 : 12),
            ),
            trailing: Text(
              _formatearMoneda((gasto['monto'] as num).toDouble()),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isLargeScreen ? 18 : 16,
                color: Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _transactionNotifier.transactionsNotifier.removeListener(
      _onTransactionUpdated,
    );
    _tabController.dispose();
    _dataUpdated.dispose();
    super.dispose();
  }
}

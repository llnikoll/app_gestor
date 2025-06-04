import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  ReportsScreenState createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final numberFormat = NumberFormat.decimalPattern();
  late TabController _tabController;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _selectedReportType = 'ventas';
  String _selectedTimeRange = 'mes';

  // Datos de ejemplo para gráficos
  final List<Map<String, dynamic>> _salesData = [
    {'day': 'Lun', 'sales': 35, 'profit': 12},
    {'day': 'Mar', 'sales': 28, 'profit': 10},
    {'day': 'Mié', 'sales': 42, 'profit': 15},
    {'day': 'Jue', 'sales': 31, 'profit': 11},
    {'day': 'Vie', 'sales': 55, 'profit': 20},
    {'day': 'Sáb', 'sales': 48, 'profit': 18},
    {'day': 'Dom', 'sales': 25, 'profit': 9},
  ];

  final List<Map<String, dynamic>> _topProducts = [
    {'name': 'Producto A', 'sales': 45, 'revenue': 2250.00},
    {'name': 'Producto B', 'sales': 32, 'revenue': 1600.00},
    {'name': 'Producto C', 'sales': 28, 'revenue': 1400.00},
    {'name': 'Producto D', 'sales': 22, 'revenue': 1100.00},
    {'name': 'Producto E', 'sales': 18, 'revenue': 900.00},
  ];

  final List<Map<String, dynamic>> _salesByCategory = [
    {'category': 'Electrónica', 'sales': 42, 'revenue': 4200.00},
    {'category': 'Ropa', 'sales': 35, 'revenue': 2800.00},
    {'category': 'Hogar', 'sales': 28, 'revenue': 2100.00},
    {'category': 'Deportes', 'sales': 15, 'revenue': 1200.00},
    {'category': 'Otros', 'sales': 10, 'revenue': 800.00},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogTheme: Theme.of(context).dialogTheme.copyWith(
              backgroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  Widget _buildDateRangeSelector() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(Icons.date_range, color: Colors.blue),
        title: const Text('Rango de fechas'),
        subtitle: Text(
          '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
        ),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: () => _selectDateRange(context),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final timeRanges = [
      {'value': 'dia', 'label': 'Hoy'},
      {'value': 'semana', 'label': 'Esta semana'},
      {'value': 'mes', 'label': 'Este mes'},
      {'value': 'anio', 'label': 'Este año'},
      {'value': 'personalizado', 'label': 'Personalizado'},
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: timeRanges.length,
        itemBuilder: (context, index) {
          final range = timeRanges[index];
          final isSelected = _selectedTimeRange == range['value'];
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTimeRange = range['value'] as String;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  range['label'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    final reportTypes = [
      {'value': 'ventas', 'label': 'Ventas', 'icon': Icons.bar_chart},
      {'value': 'productos', 'label': 'Productos', 'icon': Icons.inventory_2},
      {'value': 'categorias', 'label': 'Categorías', 'icon': Icons.category},
    ];

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: reportTypes.length,
        itemBuilder: (context, index) {
          final type = reportTypes[index];
          final isSelected = _selectedReportType == type['value'];
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedReportType = type['value'] as String;
              });
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(26), // 0.1 * 255 ≈ 26
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[300]!,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type['icon'] as IconData,
                    color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalesChart() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ventas por Día',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelRotation: 0,
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compactCurrency(
                    symbol: '\$',
                    decimalDigits: 0,
                  ),
                ),
                series: <CartesianSeries>[
                  ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: _salesData,
                    xValueMapper: (data, _) => data['day'] as String,
                    yValueMapper: (data, _) => data['sales'].toDouble(),
                    name: 'Ventas',
                    color: Theme.of(context).primaryColor,
                    width: 0.5,
                    spacing: 0.2,
                  ),
                ],
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'Ventas: \$point.y',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsList() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Productos Más Vendidos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _topProducts.length,
            itemBuilder: (context, index) {
              final product = _topProducts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(product['name'] as String),
                subtitle: Text('${product['sales']} ventas'),
                trailing: Text(
                  currencyFormat.format(product['revenue']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSalesByCategory() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ventas por Categoría',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                series: <CircularSeries>[
                  DoughnutSeries<Map<String, dynamic>, String>(
                    dataSource: _salesByCategory,
                    xValueMapper: (data, _) => data['category'] as String,
                    yValueMapper: (data, _) => data['revenue'] as double,
                    dataLabelMapper: (data, _) =>
                        '${data['category']}\n${currencyFormat.format(data['revenue'])}',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      useSeriesColor: true,
                      textStyle: TextStyle(fontSize: 12),
                    ),
                    radius: '70%',
                    innerRadius: '60%',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Ventas',
              '\$12,450.75',
              Icons.attach_money,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Total Productos',
              '1,245',
              Icons.inventory_2,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Clientes',
              '245',
              Icons.people,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(26), // 0.1 * 255 ≈ 26
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // Exportar reporte
            },
            tooltip: 'Exportar Reporte',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // Imprimir reporte
            },
            tooltip: 'Imprimir',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Gráficos'),
            Tab(icon: Icon(Icons.table_chart), text: 'Tablas'),
            Tab(icon: Icon(Icons.summarize), text: 'Resumen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña de Gráficos
          SingleChildScrollView(
            child: Column(
              children: [
                _buildReportTypeSelector(),
                _buildTimeRangeSelector(),
                if (_selectedTimeRange == 'personalizado') _buildDateRangeSelector(),
                if (_selectedReportType == 'ventas') _buildSalesChart(),
                if (_selectedReportType == 'productos') _buildTopProductsList(),
                if (_selectedReportType == 'categorias') _buildSalesByCategory(),
              ],
            ),
          ),
          // Pestaña de Tablas
          SingleChildScrollView(
            child: Column(
              children: [
                _buildReportTypeSelector(),
                _buildTimeRangeSelector(),
                if (_selectedTimeRange == 'personalizado') _buildDateRangeSelector(),
                _buildTopProductsList(),
              ],
            ),
          ),
          // Pestaña de Resumen
          SingleChildScrollView(
            child: Column(
              children: [
                _buildTimeRangeSelector(),
                if (_selectedTimeRange == 'personalizado') _buildDateRangeSelector(),
                _buildSummaryCards(),
                _buildSalesChart(),
                _buildSalesByCategory(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

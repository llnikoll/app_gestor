import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_gestor_ventas/models/gasto_model.dart';
import 'package:app_gestor_ventas/services/database_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.money_off), text: 'Gastos'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Ventas'),
            Tab(icon: Icon(Icons.analytics), text: 'Informes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const GastosTab(),
          const Center(child: Text('Contenido de Ventas')),
          const Center(child: Text('Contenido de Informes')),
        ],
      ),
    );
  }
}

class GastosTab extends StatefulWidget {
  const GastosTab({super.key});

  @override
  State<GastosTab> createState() => _GastosTabState();
}

class _GastosTabState extends State<GastosTab> {
  final DatabaseService _dbService = DatabaseService();
  List<Gasto> _gastos = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _cargarGastos();
  }

  Future<void> _cargarGastos() async {
    try {
      setState(() => _isLoading = true);
      final db = await _dbService.database;
      final gastos = await db.query(
        'gastos',
        orderBy: 'fecha DESC',
      );
      
      setState(() {
        _gastos = gastos.map((e) => Gasto.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar los gastos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_gastos.isEmpty) {
      return const Center(child: Text('No hay gastos registrados'));
    }

    return RefreshIndicator(
      onRefresh: _cargarGastos,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _gastos.length,
        itemBuilder: (context, index) {
          final gasto = _gastos[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: ListTile(
              title: Text(
                gasto.descripcion,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Categoría: ${gasto.categoria}'),
                  Text(
                    DateFormat('dd/MM/yyyy - HH:mm').format(gasto.fecha),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (gasto.notas?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Notas: ${gasto.notas}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
              trailing: Text(
                '\$${gasto.monto.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

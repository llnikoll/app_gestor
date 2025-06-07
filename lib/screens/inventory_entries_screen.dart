import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entrada_inventario_model.dart';
import '../services/database_service.dart';

class InventoryEntriesScreen extends StatefulWidget {
  const InventoryEntriesScreen({super.key});

  @override
  InventoryEntriesScreenState createState() => InventoryEntriesScreenState();
}

class InventoryEntriesScreenState extends State<InventoryEntriesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late Future<List<EntradaInventario>> _entradasFuture;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');

  @override
  void initState() {
    super.initState();
    _loadEntradas();
  }

  void _loadEntradas() {
    setState(() {
      _entradasFuture = _databaseService.getEntradasInventario(
        fechaInicio: _dateRange.start,
        fechaFin: _dateRange.end,
      );
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange,
    );
    
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _loadEntradas();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtro de fechas
        Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateFormat('dd/MM/yyyy').format(_dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange.end)}',
                  style: const TextStyle(fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Cambiar rango'),
                ),
              ],
            ),
          ),
        ),
        // Lista de entradas
        Expanded(
          child: FutureBuilder<List<EntradaInventario>>(
            future: _entradasFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }


              final entradas = snapshot.data ?? [];

              if (entradas.isEmpty) {
                return const Center(
                  child: Text('No hay entradas registradas'),
                );
              }


              // Calcular total gastado
              double totalGastado = 0;
              for (var entrada in entradas) {
                totalGastado += entrada.total;
              }

              return Column(
                children: [
                  // Resumen
                  Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: const Text(
                        'Total Gastado',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        _currencyFormat.format(totalGastado),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                  // Lista de entradas
                  Expanded(
                    child: ListView.builder(
                      itemCount: entradas.length,
                      itemBuilder: (context, index) {
                        final entrada = entradas[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: ListTile(
                            title: Text(entrada.productoNombre),
                            subtitle: Text(
                              '${entrada.cantidad} x ${_currencyFormat.format(entrada.precioUnitario)}',
                            ),
                            trailing: Text(
                              _currencyFormat.format(entrada.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            onTap: () {
                              // Mostrar detalles de la entrada
                              _showEntryDetails(entrada);
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
        ),
      ],
    );
  }

  void _showEntryDetails(EntradaInventario entrada) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles de Entrada'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Producto', entrada.productoNombre),
              _buildDetailRow('Cantidad', entrada.cantidad.toString()),
              _buildDetailRow(
                'Precio Unitario',
                _currencyFormat.format(entrada.precioUnitario),
              ),
              _buildDetailRow(
                'Total',
                _currencyFormat.format(entrada.total),
                isBold: true,
              ),
              if (entrada.proveedorNombre != null)
                _buildDetailRow('Proveedor', entrada.proveedorNombre!),
              if (entrada.notas != null && entrada.notas!.isNotEmpty)
                _buildDetailRow('Notas', entrada.notas!),
              _buildDetailRow(
                'Fecha',
                DateFormat('dd/MM/yyyy HH:mm').format(entrada.fecha),
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
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

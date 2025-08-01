import 'package:flutter/material.dart';
import 'dart:io';
import '../models/entrada_inventario_model.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';

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
  // Función para formatear montos según la moneda configurada
  String _formatearMoneda(double monto) {
    return context.formattedCurrency(monto);
  }

  @override
  void initState() {
    super.initState();
    _loadEntradas();
  }

  void _loadEntradas() {
    setState(() {
      _entradasFuture = _databaseService
          .getEntradasInventario(
        fechaInicio: _dateRange.start,
        fechaFin: _dateRange.end,
      )
          .then((entradas) {
        // Ordenar por fecha descendente
        entradas.sort((a, b) => b.fecha.compareTo(a.fecha));
        return entradas;
      });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entradas de Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'Seleccionar rango de fechas',
          ),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rango de fechas:',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_dateRange.start.year}-${_dateRange.start.month.toString().padLeft(2, '0')}-${_dateRange.start.day.toString().padLeft(2, '0')} - ${_dateRange.end.year}-${_dateRange.end.month.toString().padLeft(2, '0')}-${_dateRange.end.day.toString().padLeft(2, '0')}',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Cambiar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
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
                          'Total: ${_formatearMoneda(totalGastado)}',
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
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.1),
                                child: Icon(Icons.input,
                                    color: Theme.of(context).primaryColor),
                              ),
                              title: Text(
                                entrada.productoNombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cantidad: ${entrada.cantidad}',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    'Precio Unitario: ${_formatearMoneda(entrada.precioUnitario)}',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    'Fecha: ${entrada.fecha.day.toString().padLeft(2, '0')}/${entrada.fecha.month.toString().padLeft(2, '0')}/${entrada.fecha.year}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                _formatearMoneda(entrada.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 18,
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
      ),
    );
  }

  // Método para abrir la imagen en pantalla completa
  Widget _buildSafeImage(String imageUrl) {
    if (imageUrl.startsWith('http') || imageUrl.startsWith('https')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
      );
    } else {
      // Si es una ruta local, tratar como archivo
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
      );
    }
  }

  void _showFullScreenImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: _buildSafeImage(imageUrl),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
      );
    }

    return GestureDetector(
      onTap: () => _showFullScreenImage(imageUrl),
      child: Hero(
        tag: 'product-image-$imageUrl',
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildSafeImage(imageUrl),
        ),
      ),
    );
  }

  void _showEntryDetails(EntradaInventario entrada) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildProductImage(entrada.productoImagenUrl),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entrada.productoNombre,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (entrada.productoDescripcion?.isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                entrada.productoDescripcion!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow('Cantidad', '${entrada.cantidad} unidades'),
                _buildDetailRow(
                  'Precio Unitario',
                  _formatearMoneda(entrada.precioUnitario),
                ),
                _buildDetailRow(
                  'Total',
                  _formatearMoneda(entrada.total),
                  isBold: true,
                ),
                if (entrada.productoPrecioVenta != null)
                  _buildDetailRow(
                    'Precio de Venta',
                    _formatearMoneda(entrada.productoPrecioVenta!),
                  ),
                _buildDetailRow(
                  'Stock Actual',
                  '${entrada.productoStock} unidades',
                ),
                if (entrada.proveedorNombre != null)
                  _buildDetailRow('Proveedor', entrada.proveedorNombre!),
                _buildDetailRow(
                  'Fecha',
                  '${entrada.fecha.day.toString().padLeft(2, '0')}/${entrada.fecha.month.toString().padLeft(2, '0')}/${entrada.fecha.year} ${entrada.fecha.hour.toString().padLeft(2, '0')}:${entrada.fecha.minute.toString().padLeft(2, '0')}',
                ),
                if (entrada.notas != null && entrada.notas!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Notas:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entrada.notas!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
                color: isBold ? Theme.of(context).primaryColor : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

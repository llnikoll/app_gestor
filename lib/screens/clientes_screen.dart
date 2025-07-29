import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:gestor_pocket/models/cliente_model.dart';
import 'package:gestor_pocket/screens/cliente_form_screen.dart';
import 'package:gestor_pocket/services/database_service.dart';
import 'package:gestor_pocket/services/product_notifier_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  ProductNotifierService? _productNotifier;
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final List<Cliente> _clientes = [];
  String _searchQuery = '';
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Obtener el notificador de productos solo una vez
    _productNotifier ??=
        Provider.of<ProductNotifierService>(context, listen: false);

    // Escuchar cambios en el notificador
    _productNotifier!.notifier.addListener(_onProductUpdate);

    // Cargar clientes iniciales
    _loadClientes();
  }

  @override
  void dispose() {
    // Limpiar el listener cuando el widget se destruya
    _productNotifier?.notifier.removeListener(_onProductUpdate);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Método que se ejecuta cuando hay una actualización de productos
  void _onProductUpdate() {
    if (mounted) {
      _loadClientes();
    }
  }

  Future<void> _loadClientes() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final clientes = await _databaseService.getClientes(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (!mounted) return;
      setState(() {
        _clientes.clear();
        _clientes.addAll(clientes);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar clientes: $e')));
      }
    }
  }

  void _navigateToCustomerForm({Cliente? cliente}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerFormScreen(cliente: cliente),
      ),
    );

    if (result == true) {
      _loadClientes();
    }
  }

  List<Cliente> get _filteredClientes {
    if (_searchQuery.isEmpty) return _clientes;

    return _clientes.where((cliente) {
      final query = _searchQuery.toLowerCase();
      return cliente.nombre.toLowerCase().contains(query) ||
          (cliente.email?.toLowerCase().contains(query) ?? false) ||
          (cliente.telefono?.contains(_searchQuery) ?? false) ||
          (cliente.ruc?.contains(_searchQuery) ?? false);
    }).toList();
  }

  Future<void> _deleteCustomer(Cliente cliente) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${cliente.nombre}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _databaseService.deleteCliente(cliente.id!);
        if (!mounted) return;

        setState(() {
          _clientes.removeWhere((c) => c.id == cliente.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente eliminado correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el cliente: $e')),
          );
        }
      }
    }
  }

  Widget _buildCustomerCard(Cliente cliente) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final fechaRegistro = dateFormat.format(cliente.fechaRegistro);
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(cliente.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar Cliente'),
            content: Text(
              '¿Estás seguro de que deseas eliminar a ${cliente.nombre}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      onDismissed: (direction) => _deleteCustomer(cliente),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: InkWell(
          onTap: () => _navigateToCustomerForm(cliente: cliente),
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        cliente.nombre.isNotEmpty
                            ? cliente.nombre[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cliente.nombre,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (cliente.email != null && cliente.email!.isNotEmpty)
                          ..._buildInfoRow(
                            Icons.email_outlined,
                            cliente.email!,
                          ),
                        if (cliente.telefono != null &&
                            cliente.telefono!.isNotEmpty)
                          ..._buildInfoRow(
                            Icons.phone_outlined,
                            cliente.telefono!,
                          ),
                        if (cliente.direccion != null &&
                            cliente.direccion!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ..._buildInfoRow(
                            Icons.location_on_outlined,
                            cliente.direccion!,
                            maxLines: 2,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Registrado',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fechaRegistro,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInfoRow(IconData icon, String text, {int maxLines = 1}) {
    return [
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 80,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.6)),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'No se encontraron clientes que coincidan con "$_searchQuery"'
                : 'Aún no hay clientes registrados',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Intenta ajustar tu búsqueda o agrega un nuevo cliente.'
                : 'Comienza agregando tu primer cliente para gestionar sus datos y ventas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _navigateToCustomerForm(),
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar Nuevo Cliente'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClientes,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, teléfono o email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 2.0),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]!.withValues(alpha: 0.7)
                    : Colors.grey[100],
                hintStyle: TextStyle(
                  color: Theme.of(context).hintColor,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
              onChanged: (value) {
                _searchQuery = value;
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  _loadClientes();
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _clientes.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadClientes,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _filteredClientes.length,
                          itemBuilder: (context, index) {
                            final cliente = _filteredClientes[index];
                            return _buildCustomerCard(cliente);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'customers_fab',
        onPressed: () => _navigateToCustomerForm(),
        tooltip: 'Agregar cliente',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

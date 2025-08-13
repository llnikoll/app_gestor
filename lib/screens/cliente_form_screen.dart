import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../services/database_service.dart';

class CustomerFormScreen extends StatefulWidget {
  final Cliente? cliente;

  const CustomerFormScreen({super.key, this.cliente});

  @override
  CustomerFormScreenState createState() => CustomerFormScreenState();
}

class CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  // Controladores para los campos del formulario
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _rucController = TextEditingController();
  final _notasController = TextEditingController();

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.cliente != null;

    // Si estamos en modo edición, cargamos los datos del cliente
    if (_isEditMode) {
      _nombreController.text = widget.cliente!.nombre;
      _direccionController.text = widget.cliente!.direccion ?? '';
      _telefonoController.text = widget.cliente!.telefono ?? '';
      _emailController.text = widget.cliente!.email ?? '';
      _rucController.text = widget.cliente!.ruc ?? '';
      _notasController.text = widget.cliente!.notas ?? '';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _rucController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final cliente = Cliente(
        id: widget.cliente?.id,
        nombre: _nombreController.text.trim(),
        direccion: _direccionController.text.trim().isNotEmpty
            ? _direccionController.text.trim()
            : null,
        telefono: _telefonoController.text.trim().isNotEmpty
            ? _telefonoController.text.trim()
            : null,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        ruc: _rucController.text.trim().isNotEmpty
            ? _rucController.text.trim()
            : null,
        notas: _notasController.text.trim().isNotEmpty
            ? _notasController.text.trim()
            : null,
      );

      if (_isEditMode) {
        await _db.updateCliente(cliente);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente actualizado correctamente')),
        );
      } else {
        await _db.insertCliente(cliente);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente agregado correctamente')),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true); // Retornar true para indicar éxito
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el cliente: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Cliente' : 'Nuevo Cliente'),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isLoading ? null : _confirmDelete,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campo Nombre
                    TextFormField(
                      controller: _nombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre Completo *',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.7)
                                : Colors.grey[100],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingrese el nombre del cliente';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Campo Teléfono
                    TextFormField(
                      controller: _telefonoController,
                      decoration: InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.7)
                                : Colors.grey[100],
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Campo Email
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.7)
                                : Colors.grey[100],
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null; // Correo vacío es válido (no requerido)
                        }

                        // Expresión regular más flexible
                        final emailRegex = RegExp(
                            r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}');

                        final isValid = emailRegex.hasMatch(value);

                        if (!isValid) {
                          return 'Por favor ingrese un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Campo RUC
                    TextFormField(
                      controller: _rucController,
                      decoration: InputDecoration(
                        labelText: 'RUC',
                        prefixIcon: const Icon(Icons.numbers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.7)
                                : Colors.grey[100],
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Campo Dirección
                    TextFormField(
                      controller: _direccionController,
                      decoration: InputDecoration(
                        labelText: 'Dirección',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.7)
                                : Colors.grey[100],
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Campo Notas
                    TextFormField(
                      controller: _notasController,
                      decoration: InputDecoration(
                        labelText: 'Notas',
                        prefixIcon: const Icon(Icons.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.7)
                                : Colors.grey[100],
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Botón de guardar
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveCustomer,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isEditMode
                                  ? 'Actualizar Cliente'
                                  : 'Agregar Cliente',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: const Text('¿Está seguro de que desea eliminar este cliente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _db.deleteCliente(widget.cliente!.id!);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente eliminado correctamente')),
      );

      Navigator.of(context).pop(true); // Retornar true para indicar éxito
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el cliente: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

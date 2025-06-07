import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/gasto_model.dart';
import '../services/database_service.dart';

class GastoFormScreen extends StatefulWidget {
  final Gasto? gasto;

  const GastoFormScreen({super.key, this.gasto});

  @override
  State<GastoFormScreen> createState() => _GastoFormScreenState();
}

class _GastoFormScreenState extends State<GastoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  final _notasController = TextEditingController();
  String _categoriaSeleccionada = 'Gastos varios';
  bool _isLoading = false;

  final List<String> _categorias = [
    'Gastos varios',
    'Insumos',
    'Salario',
    'Servicios'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.gasto != null) {
      _descripcionController.text = widget.gasto!.descripcion;
      _montoController.text = widget.gasto!.monto.toStringAsFixed(2);
      _categoriaSeleccionada = widget.gasto!.categoria;
      _notasController.text = widget.gasto!.notas ?? '';
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _guardarGasto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Para nuevos gastos, usar la fecha y hora actual
      // Para ediciones, mantener la fecha original pero actualizar la hora a la actual
      final fechaActual = DateTime.now();
      final fechaGasto = widget.gasto != null
          ? DateTime(
              widget.gasto!.fecha.year,
              widget.gasto!.fecha.month,
              widget.gasto!.fecha.day,
              fechaActual.hour,
              fechaActual.minute,
              fechaActual.second,
              fechaActual.millisecond,
              fechaActual.microsecond,
            )
          : fechaActual;

      final gasto = Gasto(
        id: widget.gasto?.id,
        descripcion: _descripcionController.text,
        monto: double.parse(_montoController.text),
        categoria: _categoriaSeleccionada,
        fecha: fechaGasto,
        notas: _notasController.text.isNotEmpty ? _notasController.text : null,
      );
      
      if (kDebugMode) {
        debugPrint('Guardando gasto con fecha: ${fechaGasto.toIso8601String()}');
      }

      final db = DatabaseService();
      if (widget.gasto != null) {
        await db.updateGasto(gasto);
      } else {
        await db.insertGasto(gasto);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Error al guardar el gasto: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _eliminarGasto() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Gasto'),
        content: const Text('¿Está seguro de eliminar este gasto?'),
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

    if (confirmado == true && mounted) {
      try {
        setState(() => _isLoading = true);
        await DatabaseService().deleteGasto(widget.gasto!.id!);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        _mostrarError('Error al eliminar: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gasto == null ? 'Nuevo Gasto' : 'Editar Gasto'),
        actions: [
          if (widget.gasto != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isLoading ? null : _eliminarGasto,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese una descripción';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _montoController,
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese un monto';
                        }
                        final monto = double.tryParse(value);
                        if (monto == null || monto <= 0) {
                          return 'Ingrese un monto válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                      ),
                      items: _categorias
                          .map((categoria) => DropdownMenuItem(
                                value: categoria,
                                child: Text(categoria),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _categoriaSeleccionada = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notasController,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _guardarGasto,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Guardar Gasto'),
                    ),
                    if (widget.gasto == null) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

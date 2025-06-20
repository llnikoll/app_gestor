import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/gasto_model.dart';
import '../models/currency_model.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

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
      _montoController.text = _formatearMoneda(widget.gasto!.monto);
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

  // Función para formatear montos según la moneda configurada
  String _formatearMoneda(double monto) {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final currency = Currency.getByCode(settings.currency);
    final formatter = NumberFormat.currency(
      locale: 'es_PY',
      symbol: currency.symbol,
      decimalDigits: 0,
    );
    return formatter.format(monto);
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

      // Obtener el valor numérico del monto (eliminar puntos de miles)
      final valorMonto = _montoController.text.replaceAll('.', '').trim();
      final monto = double.parse(valorMonto);

      final gasto = Gasto(
        id: widget.gasto?.id,
        descripcion: _descripcionController.text,
        monto: monto,
        categoria: _categoriaSeleccionada,
        fecha: fechaGasto,
        notas: _notasController.text.isNotEmpty ? _notasController.text : null,
      );

      if (kDebugMode) {
        debugPrint(
            'Guardando gasto con fecha: ${fechaGasto.toIso8601String()}');
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
    final settings = Provider.of<SettingsService>(context);
    final currency = Currency.getByCode(settings.currency);
    final currencySymbol = currency.symbol;

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
                      decoration: InputDecoration(
                        labelText: 'Monto',
                        prefixText: '$currencySymbol ',
                        border: const OutlineInputBorder(),
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese un monto';
                        }
                        // Eliminar puntos de separación de miles para validar
                        final valorSinPuntos = value.replaceAll('.', '').trim();
                        final monto = int.tryParse(valorSinPuntos);
                        if (monto == null || monto <= 0) {
                          return 'Ingrese un monto válido';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (value.isEmpty) return;

                        // Guardar la posición del cursor
                        final cursorPosition =
                            _montoController.selection.base.offset;

                        // Eliminar todo lo que no sea dígito
                        final soloNumeros =
                            value.replaceAll(RegExp(r'[^0-9]'), '');
                        final monto = int.tryParse(
                                soloNumeros.isEmpty ? '0' : soloNumeros) ??
                            0;

                        // Formatear el número
                        final formateado = _formatearMoneda(monto.toDouble());

                        // Calcular la nueva posición del cursor
                        int newCursorPosition = cursorPosition;
                        if (cursorPosition > formateado.length) {
                          newCursorPosition = formateado.length;
                        } else if (cursorPosition < formateado.length - 1 &&
                            formateado.length > value.length) {
                          // Ajustar la posición cuando se inserta un separador de miles
                          newCursorPosition++;
                        }

                        // Actualizar el controlador solo si el valor formateado es diferente
                        if (formateado != value) {
                          _montoController.value = TextEditingValue(
                            text: formateado,
                            selection: TextSelection.collapsed(
                                offset: newCursorPosition),
                          );
                        }
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
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
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

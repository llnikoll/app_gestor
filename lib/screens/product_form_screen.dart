
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../utils/image_helper.dart';
import '../services/settings_service.dart';
import '../models/categoria_model.dart';
import '../services/product_notifier_service.dart';
import '../models/producto_model.dart';
import '../services/database_service.dart';
import '../widgets/custom_text_field.dart';
import 'scanner_screen.dart';


class ProductFormScreen extends StatefulWidget {
  final Producto? product;

  const ProductFormScreen({super.key, this.product});

  @override
  ProductFormScreenState createState() => ProductFormScreenState();
}

class ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codigoBarrasController;
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  String? _selectedCategoria;
  late TextEditingController _precioCompraController;
  late TextEditingController _precioVentaController;
  late TextEditingController _stockController;

  final _nuevaCategoriaController = TextEditingController();
  final List<Categoria> _categorias = [];
  final DatabaseService _databaseService = DatabaseService();

  String? _imagenPath;
  bool _isLoading = false;
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();
  late String _currencySymbol;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.product != null;
    _currencySymbol = Provider.of<SettingsService>(context, listen: false)
        .currentCurrency
        .symbol;

    // Inicializar controladores con datos del producto si existe
    if (widget.product != null) {
      final product = widget.product!;
      _codigoBarrasController = TextEditingController(
        text: product.codigoBarras,
      );
      _nombreController = TextEditingController(text: product.nombre);
      _descripcionController = TextEditingController(text: product.descripcion);

      // Formatear precios sin decimales y con separadores de miles
      final priceFormat = NumberFormat('#,##0', 'es-PY');

      _precioCompraController = TextEditingController(
        text: priceFormat.format(product.precioCompra.toInt()),
      );

      _precioVentaController = TextEditingController(
        text: priceFormat.format(product.precioVenta.toInt()),
      );

      _stockController = TextEditingController(text: product.stock.toString());

      _selectedCategoria = product.categoria;
      _imagenPath = product.imagenUrl;
    } else {
      // Inicializar controladores vacíos para nuevo producto
      _codigoBarrasController = TextEditingController();
      _nombreController = TextEditingController();
      _descripcionController = TextEditingController();
      _precioCompraController = TextEditingController();
      _precioVentaController = TextEditingController();
      _stockController = TextEditingController(text: '0');
      _selectedCategoria = null; // Forzar la selección de categoría para nuevos productos
    }

    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    try {
      final fetchedCategories = await _databaseService.getCategorias();
      setState(() {
        _categorias.clear();
        // Filtrar la categoría 'General'
        _categorias.addAll(fetchedCategories.where((c) => c.nombre.toLowerCase() != 'general'));

        // Si no hay categorías (después de filtrar), crear una por defecto 'Sin Categoría'
        if (_categorias.isEmpty) {
          _databaseService
              .insertCategoria(
                Categoria(nombre: 'Sin Categoría', fechaCreacion: DateTime.now()),
              )
              .then(
                (_) => _cargarCategorias(),
              ); // Recargar categorías después de crear la por defecto
          return;
        }

        // Si el producto existente tenía 'General' o no hay categoría seleccionada,
        // establecer la primera categoría como seleccionada.
        if (_selectedCategoria == null || _selectedCategoria!.toLowerCase() == 'general') {
          _selectedCategoria = _categorias.first.nombre;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar categorías: $e')),
        );
      }
    }
  }

  Future<void> _mostrarDialogoNuevaCategoria() async {
    _nuevaCategoriaController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.category, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Nueva Categoría'),
          ],
        ),
        content: TextField(
          controller: _nuevaCategoriaController,
          decoration: InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ej: Bebidas, Snacks, etc.',
            prefixIcon: const Icon(Icons.label_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nuevaCategoriaController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && _nuevaCategoriaController.text.trim().isNotEmpty) {
      try {
        final nuevaCategoria = Categoria(
          nombre: _nuevaCategoriaController.text.trim(),
          fechaCreacion: DateTime.now(),
        );

        await _databaseService.insertCategoria(nuevaCategoria);
        await _cargarCategorias();

        setState(() {
          _selectedCategoria = _nuevaCategoriaController.text.trim();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al crear categoría: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _codigoBarrasController.dispose();
    _nombreController.dispose();
    _descripcionController.dispose();
    _nuevaCategoriaController.dispose();
    _precioCompraController.dispose();
    _precioVentaController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  // Método auxiliar para mostrar mensajes de error
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final savedImageName = await ImageHelper.saveImage(File(image.path));
        setState(() {
          _imagenPath = savedImageName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final savedImageName = await ImageHelper.saveImage(File(photo.path));
        setState(() {
          _imagenPath = savedImageName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al tomar foto: $e')));
      }
    }
  }

  Future<bool> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final db = DatabaseService();
      final codigoBarras = _codigoBarrasController.text.trim();
      final nombre = _nombreController.text.trim();
      final descripcion = _descripcionController.text.trim();
      final categoria = _selectedCategoria ?? 'General';
      final stock = int.parse(_stockController.text);

      // Verificar si el código de barras ya existe (solo para nuevos productos o si cambió el código)
      if (!_isEditing || (widget.product?.codigoBarras != codigoBarras)) {
        final productoExistente = await db.getProductoPorCodigo(codigoBarras);
        if (productoExistente != null) {
          throw Exception(
            'Ya existe un producto con el código de barras: $codigoBarras',
          );
        }
      }

      // Si hay una imagen, asegurarse de que se guarde en el directorio de la app
      String? imagenUrl = _imagenPath;

      // Limpiar los puntos de los miles y convertir a double
      final precioCompra = double.parse(
        _precioCompraController.text.replaceAll('.', ''),
      );
      final precioVenta = double.parse(
        _precioVentaController.text.replaceAll('.', ''),
      );

      if (_isEditing) {
        // Actualizar el producto existente
        final productoActualizado = Producto(
          id: widget.product!.id,
          codigoBarras: codigoBarras,
          nombre: nombre,
          descripcion: descripcion,
          categoria: categoria,
          precioCompra: precioCompra,
          precioVenta: precioVenta,
          stock: stock,
          imagenUrl: imagenUrl,
          fechaCreacion: widget.product!.fechaCreacion,
          fechaActualizacion: DateTime.now(),
          activo: widget.product?.activo ?? true,
        );

        debugPrint('Actualizando producto: ${productoActualizado.toMap()}');
        final result = await db.updateProducto(productoActualizado);
        debugPrint('Resultado de la actualización: $result');
      } else {
        // Crear un nuevo producto
        final nuevoProducto = Producto(
          codigoBarras: codigoBarras,
          nombre: nombre,
          descripcion: descripcion,
          categoria: categoria,
          precioCompra: precioCompra,
          precioVenta: precioVenta,
          stock: stock,
          imagenUrl: imagenUrl,
        );
        debugPrint('Insertando nuevo producto: ${nuevoProducto.toMap()}');
        await db.insertProducto(nuevoProducto);
      }

      // Notificar que se ha actualizado un producto
      if (mounted) {
        // Obtener el servicio de notificación de productos
        final productNotifier = Provider.of<ProductNotifierService>(
          context,
          listen: false,
        );

        // Notificar después de que se haya completado el guardado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          productNotifier.notifyProductUpdate();
          if (mounted) {
            // Mostrar mensaje de éxito
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isEditing
                      ? '✅ Producto actualizado correctamente'
                      : '✅ Producto agregado correctamente',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pop(true);
          }
        });
        return true;
      }
      return false;
    } on Exception catch (e) {
      String mensajeError = 'Error al guardar el producto';

      // Manejar errores específicos de la base de datos
      if (e.toString().contains('UNIQUE constraint failed') ||
          e.toString().contains('SQLITE_CONSTRAINT_UNIQUE')) {
        mensajeError = 'Error: Ya existe un producto con ese código de barras';
      } else if (e.toString().contains('no such table')) {
        mensajeError = 'Error: La tabla de productos no existe';
      } else {
        mensajeError = 'Error: ${e.toString()}';
      }

      _showErrorSnackBar(mensajeError);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.category_outlined,
              size: 18,
              color: Colors.deepPurple,
            ),
            const SizedBox(width: 6),
            const Text(
              'Categoría',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedCategoria,
                  decoration: InputDecoration(
                    hintText: 'Seleccione una categoría',
                    prefixIcon: const Icon(
                      Icons.label_outline,
                      color: Colors.deepPurple,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.deepPurple,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  items: _categorias.map<DropdownMenuItem<String>>((categoria) {
                    return DropdownMenuItem<String>(
                      value: categoria.nombre,
                      child: Text(
                        categoria.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoria = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione una categoría';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _mostrarDialogoNuevaCategoria,
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 28,
                  color: Colors.deepPurple,
                ),
                tooltip: 'Agregar categoría',
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        if (_categorias.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(0, 255, 248, 225),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No hay categorías. Crea una nueva categoría haciendo clic en el botón +',
                      style: TextStyle(fontSize: 13, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 800.0 : screenWidth;
    final maxHeight = screenHeight * 0.95;
    final padding = isTablet ? 32.0 : 20.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: maxWidth,
        height: maxHeight,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header con AppBar
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.deepPurple],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: AppBar(
                  title: Row(
                    children: [
                      Icon(
                        _isEditing ? Icons.edit : Icons.add_shopping_cart,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isEditing ? 'Editar Producto' : 'Nuevo Producto',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    if (_isEditing)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: _confirmDeleteProduct,
                          tooltip: 'Eliminar producto',
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context, false),
                        tooltip: 'Cerrar',
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido principal - Área desplazable
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(padding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: maxHeight - 200, // Ajuste de altura
                      ),
                      child: _buildForm(),
                    ),
                  ),
                ),
              ),

              // Footer con botón de guardar mejorado
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: padding / 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 32,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: Colors.deepPurple.withValues(alpha: 0.3),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Color.fromARGB(255, 255, 255, 255),
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(_isEditing ? Icons.update : Icons.save,
                            size: 20),
                    label: Text(
                      _isLoading
                          ? 'Guardando...'
                          : _isEditing
                              ? 'ACTUALIZAR PRODUCTO'
                              : 'GUARDAR PRODUCTO',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este producto?',
        ),
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

    if (confirmed == true && widget.product?.id != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        await DatabaseService().deleteProducto(widget.product!.id!);
        if (!mounted) return;

        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar el producto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildForm() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sección de imagen
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _imagenPath != null && _imagenPath!.isNotEmpty
                            ? FutureBuilder<String>(
                                future: ImageHelper.getImagePath(_imagenPath!),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  final imagePath = snapshot.data;
                                  if (imagePath == null || imagePath.isEmpty) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    );
                                  }

                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(imagePath),
                                      width: 150,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Agregar imagen',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        if (_imagenPath != null && _imagenPath!.isNotEmpty)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library, size: 20),
                          label: const Text('Galería'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: const Size(120, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: TextButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt, size: 20),
                          label: const Text('Cámara'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: const Size(120, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Formulario
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Código de barras
              TextFormField(
                  controller: _codigoBarrasController,
                  decoration: InputDecoration(
                    labelText: 'Código de barras',
                    hintText: 'Opcional',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () async {
                        final result = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ScannerScreen(),
                          ),
                        );
                        if (result != null) {
                          _codigoBarrasController.text = result;
                        }
                      },
                    ),
                  ),
                  keyboardType: TextInputType.text,
                ),
              const SizedBox(height: 16),

              // Nombre
              CustomTextField(
                controller: _nombreController,
                label: 'Nombre del Producto',
                hint: 'Ingrese el nombre del producto',
                isRequired: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese el nombre del producto';
                  }
                  return null;
                },
                // Added modern styling
                borderRadius: 12.0,
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]!.withValues(alpha: 0.7)
                    : Colors.grey[100],
              ),
              const SizedBox(height: 16),

              // Categoría
              _buildCategoryField(),
              const SizedBox(height: 16),

              // Precio de compra y venta
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _precioCompraController,
                      label: 'Precio de Compra ($_currencySymbol)',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final cleanValue = value.replaceAll('.', '');
                          final number = int.tryParse(cleanValue) ?? 0;
                          final formatted = NumberFormat(
                            '#,##0',
                            'es-PY',
                          ).format(number);

                          if (formatted != value) {
                            _precioCompraController.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                          }
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        final cleanValue = value.replaceAll('.', '');
                        final price = int.tryParse(cleanValue);
                        if (price == null || price < 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                      // Added modern styling
                      borderRadius: 12.0,
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]!.withValues(alpha: 0.7)
                          : Colors.grey[100],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _precioVentaController,
                      label: 'Precio de Venta ($_currencySymbol)',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final cleanValue = value.replaceAll('.', '');
                          final number = int.tryParse(cleanValue) ?? 0;
                          final formatted = NumberFormat(
                            '#,##0',
                            'es-PY',
                          ).format(number);

                          if (formatted != value) {
                            _precioVentaController.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                          }
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        final cleanValue = value.replaceAll('.', '');
                        final price = int.tryParse(cleanValue);
                        if (price == null || price < 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stock
              CustomTextField(
                controller: _stockController,
                label: 'Stock Inicial',
                hint: '0',
                keyboardType: TextInputType.number,
                isRequired: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese el stock inicial';
                  }
                  final stock = int.tryParse(value);
                  if (stock == null || stock < 0) {
                    return 'Stock inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Descripción
              CustomTextField(
                controller: _descripcionController,
                label: 'Descripción (Opcional)',
                hint: 'Ingrese una descripción del producto',
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

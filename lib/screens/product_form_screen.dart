import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/producto_model.dart';
import '../models/categoria_model.dart';
import '../services/database_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/custom_text_field.dart';

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

  @override
  void initState() {
    super.initState();
    _isEditing = widget.product != null;
    
    _codigoBarrasController = TextEditingController(text: widget.product?.codigoBarras ?? '');
    _nombreController = TextEditingController(text: widget.product?.nombre ?? '');
    _descripcionController = TextEditingController(text: widget.product?.descripcion ?? '');
    _precioCompraController = TextEditingController(
      text: widget.product?.precioCompra != null
          ? widget.product!.precioCompra.toStringAsFixed(2)
          : '',
    );
    _precioVentaController = TextEditingController(
      text: widget.product?.precioVenta != null
          ? widget.product!.precioVenta.toStringAsFixed(2)
          : '',
    );
    _stockController = TextEditingController(
      text: widget.product?.stock != null ? widget.product!.stock.toString() : '0',
    );
    _selectedCategoria = widget.product?.categoria;
    _imagenPath = widget.product?.imagenUrl;

    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    try {
      final categorias = await _databaseService.getCategorias();
      setState(() {
        _categorias.clear();
        _categorias.addAll(categorias);
        
        // If no categories exist, create a default one
        if (_categorias.isEmpty) {
          _databaseService.insertCategoria(Categoria(
            nombre: 'General',
            fechaCreacion: DateTime.now(),
          )).then((_) => _cargarCategorias()); // Reload categories after creating default
          return;
        }
        
        // Set selected category if not already set
        if (_selectedCategoria == null || _selectedCategoria!.isEmpty) {
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
        title: const Text('Nueva Categoría'),
        content: TextField(
          controller: _nuevaCategoriaController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ej: Bebidas, Snacks, etc.',
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
            child: const Text('Guardar'),
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

  // Método para guardar una imagen en el directorio de la aplicación
  Future<String> _saveImageToAppDir(String imagePath) async {
    try {
      if (imagePath.isEmpty) return '';
      
      // Obtener el directorio de documentos de la aplicación
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/product_images');
      
      // Crear el directorio si no existe
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      // Generar un nombre de archivo único
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imagePath).toLowerCase();
      final fileName = 'product_$timestamp$extension';
      
      // Obtener el archivo de origen
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('El archivo de imagen no existe: $imagePath');
      }
      
      // Crear el archivo de destino
      final File savedImage = File('${imagesDir.path}/$fileName');
      
      // Copiar la imagen al directorio de la aplicación
      await imageFile.copy(savedImage.path);
      
      debugPrint('Imagen guardada en: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      debugPrint('Error en _saveImageToAppDir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la imagen: ${e.toString()}')),
        );
      }
      // Si hay un error, devolver la ruta original como último recurso
      return imagePath;
    }
  }
  
  Future<bool> _checkIfFileExists(String filePath) async {
    if (filePath.isEmpty) return false;
    
    try {
      final file = File(filePath);
      final exists = await file.exists();
      
      // Si el archivo no existe, verificar si es una ruta relativa
      if (!exists) {
        // Intentar con la ruta absoluta
        final appDir = await getApplicationDocumentsDirectory();
        final absolutePath = '${appDir.path}/$filePath';
        final absoluteFile = File(absolutePath);
        return await absoluteFile.exists();
      }
      
      return exists;
    } catch (e) {
      debugPrint('Error en _checkIfFileExists: $e');
      return false;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final savedImagePath = await _saveImageToAppDir(image.path);
        
        setState(() {
          _imagenPath = savedImagePath;
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
        final savedImagePath = await _saveImageToAppDir(photo.path);
        
        setState(() {
          _imagenPath = savedImagePath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e')),
        );
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
      
      // Si es una edición, verificar si el código de barras cambió
      if (_isEditing && widget.product?.codigoBarras != codigoBarras) {
        final productoExistente = await db.getProductoPorCodigo(codigoBarras);
        if (productoExistente != null) {
          throw Exception('Ya existe un producto con el código de barras: $codigoBarras');
        }
      }
      
      // Si hay una nueva imagen, asegurarse de que se guarde en el directorio de la app
      String? imagenUrl = _imagenPath;
      if (imagenUrl != null && !imagenUrl.contains('product_images')) {
        imagenUrl = await _saveImageToAppDir(imagenUrl);
      }
      
      final producto = Producto(
        id: widget.product?.id,
        codigoBarras: codigoBarras,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        categoria: _selectedCategoria ?? 'General',
        precioCompra: double.parse(_precioCompraController.text),
        precioVenta: double.parse(_precioVentaController.text),
        stock: int.parse(_stockController.text),
        imagenUrl: imagenUrl,
      );

      if (_isEditing) {
        await db.updateProducto(producto);
      } else {
        await db.insertProducto(producto);
      }

      if (mounted) {
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
            const Text(
              'Categoría',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCategoria,
                decoration: InputDecoration(
                  hintText: 'Seleccione una categoría',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: _categorias
                    .map<DropdownMenuItem<String>>((categoria) {
                  return DropdownMenuItem<String>(
                    value: categoria.nombre,
                    child: Text(categoria.nombre),
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
            const SizedBox(width: 8),
            IconButton(
              onPressed: _mostrarDialogoNuevaCategoria,
              icon: const Icon(Icons.add_circle_outline, size: 32),
              tooltip: 'Agregar categoría',
            ),
          ],
        ),
        if (_categorias.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'No hay categorías. Crea una nueva categoría haciendo clic en el botón +',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Nuevo Producto'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDeleteProduct,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Future<void> _confirmDeleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text('¿Estás seguro de que deseas eliminar este producto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        
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

  Widget _buildBody() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Sección de imagen
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!), 
                        ),
                        child: _imagenPath != null && _imagenPath!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: FutureBuilder<bool>(
                                  future: _checkIfFileExists(_imagenPath!),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    
                                    final fileExists = snapshot.data ?? false;
                                    
                                    if (!fileExists) {
                                      return const Center(
                                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                      );
                                    }
                                    
                                    return Image.file(
                                      File(_imagenPath!),
                                      width: 150,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                        );
                                      },
                                    );
                                  },
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Agregar imagen', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
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
                            child: const Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: const Text('Galería'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text('Cámara'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
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
              CustomTextField(
                controller: _codigoBarrasController,
                label: 'Código de Barras',
                hint: 'Ingrese el código de barras',
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese el código de barras';
                  }
                  return null;
                },
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
                      label: 'Precio de Compra',
                      hint: '0.00',
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _precioVentaController,
                      label: 'Precio de Venta',
                      hint: '0.00',
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        final price = double.tryParse(value);
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
              const SizedBox(height: 32),
              
              // Botón de guardar
              PrimaryButton(
                text: _isEditing ? 'Actualizar Producto' : 'Guardar Producto',
                onPressed: _saveProduct,
                isFullWidth: true,
                icon: Icons.save,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/producto_model.dart';
import '../services/database_service.dart';

class StockProductsScreen extends StatelessWidget {
  final String title;
  final bool showLowStock;
  final bool showOutOfStock;

  const StockProductsScreen({
    super.key,
    required this.title,
    this.showLowStock = false,
    this.showOutOfStock = false,
  }) : assert(
          showLowStock != showOutOfStock,
          'Solo uno de showLowStock o showOutOfStock debe ser true',
        );

  Future<List<Producto>> _getProducts() async {
    final db = DatabaseService();
    final products = await db.getProductos();

    if (showLowStock) {
      return products.where((p) => p.stock > 0 && p.stock < 10).toList();
    } else if (showOutOfStock) {
      return products.where((p) => p.stock <= 0).toList();
    }

    return [];
  }

  // --- Funciones para construir la imagen del producto ---

  // Widget principal que decide qué tipo de imagen mostrar.
  Widget _buildProductImage(String? imageUrl, String productName, ThemeData theme) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderImage(productName, theme);
    }

    Uri uri;
    try {
      uri = Uri.parse(imageUrl);
    } catch (e) {
      debugPrint("No se pudo parsear la URL de la imagen: '$imageUrl'. Error: $e");
      return _buildPlaceholderImage(productName, theme);
    }

    // Si el esquema es http o https, es una imagen de red.
    if (uri.isScheme('http') || uri.isScheme('https')) {
      return _buildNetworkImage(imageUrl, productName, theme);
    } 
    
    // Para cualquier otro caso (esquema 'file' o sin esquema), se trata como archivo local.
    return FutureBuilder<File?>(
      future: _getLocalFile(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
          // Si tenemos un archivo válido, lo mostramos.
          return ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.file(
              snapshot.data!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint("Error en Image.file para '${snapshot.data!.path}': $error");
                return _buildPlaceholderImage(productName, theme);
              },
            ),
          );
        }
        // Mientras carga o si no se encuentra el archivo, muestra el placeholder.
        return _buildPlaceholderImage(productName, theme);
      },
    );
  }

  // Obtiene el objeto File para una ruta de imagen local, manejando diferentes formatos.
  /// Obtiene el objeto File para una ruta de imagen local, manejando diferentes formatos y corrigiendo URIs tipo file:// en Windows.
Future<File?> _getLocalFile(String imagePath) async {
  try {
    String finalPath = imagePath;

    // Si la ruta comienza con 'file://', limpiamos el prefijo correctamente
    if (imagePath.startsWith('file://')) {
      // Para Windows, toFilePath puede arrojar error si la URI está mal formada o si no hay host
      try {
        finalPath = Uri.parse(imagePath).toFilePath(windows: Platform.isWindows);
      } catch (e) {
        // Si falla, quitamos el prefijo manualmente
        finalPath = imagePath.replaceFirst(RegExp(r'^file://+'), '');
      }
    }

    // Eliminar posibles barras iniciales extra en Windows (ej: '/C:/...')
    if (Platform.isWindows && finalPath.startsWith('/')) {
      finalPath = finalPath.substring(1);
    }

    File file;
    // Caso 2: La ruta es absoluta.
    if (path.isAbsolute(finalPath)) {
      file = File(finalPath);
    } 
    // Caso 3: La ruta es relativa o es solo un nombre de archivo (como en inventario)
    else {
      final directory = await getApplicationDocumentsDirectory();
      // Busca en la subcarpeta 'product_images' igual que inventario
      final localPath = path.join(directory.path, 'product_images', finalPath);
      file = File(localPath);
    }

    if (await file.exists()) {
      return file;
    }
  } catch (e) {
    debugPrint("Excepción al obtener el archivo local para la ruta '$imagePath': $e");
  }
  // Si hay un error o el archivo no existe, devuelve null.
  return null;
}



  // Construye la imagen desde una URL de red.
  Widget _buildNetworkImage(String imageUrl, String productName, ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholderImage(productName, theme),
        errorWidget: (context, url, error) {
          debugPrint('Error cargando imagen de red: $url, error: $error');
          return _buildPlaceholderImage(productName, theme);
        },
      ),
    );
  }

  // Construye un widget de placeholder cuando no hay imagen.
  Widget _buildPlaceholderImage(String productName, ThemeData theme) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: theme.primaryColor.withAlpha(26),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Center(
        child: Text(
          productName.isNotEmpty ? productName[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: FutureBuilder<List<Producto>>(
        future: _getProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar los productos: ${snapshot.error}'),
            );
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: theme.hintColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay productos para mostrar',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    showLowStock
                        ? 'No hay productos con bajo stock'
                        : 'No hay productos agotados',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      // Imagen del producto
                      _buildProductImage(product.imagenUrl, product.nombre, theme),

                      const SizedBox(width: 12),

                      // Información del producto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Código: ${product.codigoBarras}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stock y precio
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Stock: ${product.stock}',
                            style: TextStyle(
                              color: product.stock <= 0
                                  ? Colors.red
                                  : product.stock < 10
                                      ? Colors.orange
                                      : null,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bs. ${product.precioVenta.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode

class ProductImageViewer extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final double borderRadius;

  const ProductImageViewer({
    super.key,
    required this.imageUrl,
    this.width = 60,
    this.height = 60,
    this.fit = BoxFit.cover,
    this.borderRadius = 8.0,
  });

  // Método auxiliar para construir una imagen de error
  Widget _buildErrorImage(String? debugMessage) {
    if (kDebugMode && debugMessage != null) {
      debugPrint(debugMessage);
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.broken_image,
        size: width * 0.5, // Adjust icon size based on widget size
        color: Colors.grey,
      ),
    );
  }

  // Método para obtener la ruta completa de una imagen local
  Future<String> _getImagePath(String imageName) async {
    try {
      // Primero intentamos con el almacenamiento externo (Android/iOS específicos)
      // Esta ruta es específica para Android y puede variar.
      // Para iOS, getApplicationDocumentsDirectory() es más común.
      // Se asume que 'product_images' es una subcarpeta dentro de 'files'
      // o el directorio de documentos de la aplicación.
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final externalPath = '${externalDir.path}/product_images/$imageName';
        final externalFile = File(externalPath);
        if (await externalFile.exists()) {
          if (kDebugMode) {
            debugPrint('Imagen encontrada en almacenamiento externo: $externalPath');
          }
          return externalPath;
        }
      }

      // Si no está en almacenamiento externo o no es Android, buscamos en el directorio de documentos de la app
      final Directory appDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDir.path}/product_images/$imageName';
      if (kDebugMode) {
        debugPrint('Buscando imagen en almacenamiento local: $localPath');
      }

      final localFile = File(localPath);
      if (await localFile.exists()) {
        if (kDebugMode) {
          debugPrint('Imagen encontrada en almacenamiento local: $localPath');
        }
        return localPath;
      }

      if (kDebugMode) {
        debugPrint('No se encontró la imagen en ninguna ubicación: $imageName');
      }
      return ''; // Retorna una cadena vacía si no se encuentra
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error al obtener ruta de imagen para $imageName: $e');
      }
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorImage('URL de imagen nula o vacía.');
    }

    // Si es una URL de red, usar CachedNetworkImage
    if (imageUrl!.startsWith('http') || imageUrl!.startsWith('https')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
          ),
          errorWidget: (context, url, error) => _buildErrorImage(
              'Error al cargar imagen de red: $url. Error: $error'),
        ),
      );
    } else {
      // Para imágenes locales, usar FutureBuilder para cargarlas de forma asíncrona
      return FutureBuilder<String>(
        future: _getImagePath(imageUrl!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildErrorImage(
                'Error al cargar imagen local: $imageUrl. Error: ${snapshot.error}');
          }

          final imagePath = snapshot.data!;

          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              File(imagePath),
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _buildErrorImage(
                  'Error al renderizar imagen de archivo: $imagePath. Error: $error'),
            ),
          );
        },
      );
    }
  }
}

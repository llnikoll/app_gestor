
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class ImageHelper {
  // Directorio donde se guardarán las imágenes de los productos.
  static const String _imagesDirName = 'product_images';

  // Obtiene el directorio de imágenes de la aplicación.
  // Crea el directorio si no existe.
  static Future<Directory> getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, _imagesDirName));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  // Guarda un archivo de imagen en el directorio de imágenes de la aplicación.
  // Devuelve el nombre del archivo guardado.
  static Future<String> saveImage(File imageFile) async {
    try {
      final imagesDir = await getImagesDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path).toLowerCase();
      final fileName = 'product_$timestamp$extension';
      final savedImage = await imageFile.copy(path.join(imagesDir.path, fileName));
      
      if (kDebugMode) {
        print('Imagen guardada en: ${savedImage.path}');
      }
      
      return fileName;
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar la imagen: $e');
      }
      rethrow;
    }
  }

  // Obtiene la ruta completa de un archivo de imagen a partir de su nombre.
  // Devuelve una cadena vacía si el archivo no se encuentra.
  static Future<String> getImagePath(String? fileName) async {
    if (fileName == null || fileName.isEmpty) {
      return '';
    }

    try {
      final imagesDir = await getImagesDirectory();
      final imagePath = path.join(imagesDir.path, fileName);
      final imageFile = File(imagePath);

      if (await imageFile.exists()) {
        return imagePath;
      } else {
        if (kDebugMode) {
          print('La imagen no existe en la ruta: $imagePath');
        }
        return '';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener la ruta de la imagen: $e');
      }
      return '';
    }
  }
}

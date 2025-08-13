import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  static const _dbName = 'gestor_ventas.db';
  static const _logoDirName = 'app_logo';

  Future<String?> createBackup() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(appDocDir.path, _dbName);

      if (!await File(dbPath).exists()) {
        throw Exception('No se pudo encontrar la base de datos.');
      }

      final encoder = ZipFileEncoder();
      final tempDir = await getTemporaryDirectory();
      final backupFileName =
          'backup_gestorpocket_${DateTime.now().toIso8601String().split('T').first}.zip';
      final zipPath = p.join(tempDir.path, backupFileName);

      encoder.create(zipPath);

      // 1. Add database file
      encoder.addFile(File(dbPath), p.basename(dbPath));

      // 2. Add all image files from the root documents directory
      final files = appDocDir.listSync();
      for (var entity in files) {
        if (entity is File) {
          final extension = p.extension(entity.path).toLowerCase();
          if (extension == '.png' ||
              extension == '.jpg' ||
              extension == '.jpeg') {
            encoder.addFile(entity, p.basename(entity.path));
          }
        }
      }

      // 3. Add logo directory if it exists
      final logoPath = p.join(appDocDir.path, _logoDirName);
      if (await Directory(logoPath).exists()) {
        encoder.addDirectory(Directory(logoPath), includeDirName: true);
      }

      encoder.close();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar copia de seguridad',
        fileName: backupFileName,
      );

      if (result != null) {
        final savedFile = File(zipPath);
        // Ensure the destination directory exists
        final destDir = Directory(p.dirname(result));
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
        await savedFile.copy(result);
        await savedFile.delete();
        return result;
      }

      // If user cancels, delete the temp file
      await File(zipPath).delete();
      return null;
    } catch (e) {
      debugPrint('Error al crear la copia de seguridad: $e');
      rethrow;
    }
  }

  Future<bool> restoreFromFile(String zipPath) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final zipFile = File(zipPath);

      // Extract the archive
      final inputStream = InputFileStream(zipFile.path);
      final archive = ZipDecoder().decodeBuffer(inputStream);

      for (final file in archive) {
        final filename = p.join(appDocDir.path, file.name);
        if (file.isFile) {
          final outFile = File(filename);
          // Ensure parent directory exists
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filename).create(recursive: true);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error al restaurar la copia de seguridad: $e');
      return false;
    }
  }
}
import 'dart:io';

import 'package:flutter/material.dart';

void main() async {
  final directory = Directory('lib');
  final textStrings = <String>{};

  // Patrones a buscar
  final patterns = [
    'Text(',
    'title:',
    'hint:',
    'label:',
    'message:',
    'button:',
    'error:',
    'success:',
    'warning:',
    'info:',
  ];

  // Buscar en todos los archivos .dart
  await for (var entity in directory.list(recursive: true)) {
    if (entity.path.endsWith('.dart') &&
        !entity.path.contains('.g.dart') &&
        !entity.path.contains('main.dart') &&
        !entity.path.contains('app_localizations.dart') &&
        !entity.path.endsWith('find_texts_simple.dart')) {
      try {
        final content = await File(entity.path).readAsString();
        final lines = content.split('\n');

        for (var line in lines) {
          line = line.trim();

          // Buscar líneas que contengan algún patrón de interés
          if (patterns.any((pattern) => line.contains(pattern))) {
            // Extraer texto entre comillas
            final matches = RegExp('["\']([^"\']+)["\']').allMatches(line);
            for (var match in matches) {
              final text = match.group(1) ?? '';
              if (text.length > 2 &&
                  !text.contains(' ') &&
                  !text.contains('{') &&
                  !text.contains('}')) {
                textStrings.add(text);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error procesando archivo ${entity.path}: $e');
      }
    }
  }

  // Ordenar alfabéticamente
  final sortedTexts = textStrings.toList()..sort();

  // Mostrar resultados
  debugPrint('\n=== Textos encontrados (${sortedTexts.length}) ===\n');
  for (var text in sortedTexts) {
    debugPrint('  "$text": "$text",');
  }
}

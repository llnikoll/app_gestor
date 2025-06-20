// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';

void main() async {
  final directory = Directory('lib');
  final strings = <String>{};
  
  // Pattern to extract text from Text() widgets
  final textPattern = RegExp(r'Text\s*\(\s*"([^"]+)"');
  
  // Pattern to extract literal strings
  final literalPattern = RegExp(r'"([^"\s]+)"');
  
  // Pattern to extract .tr() keys
  final trPattern = RegExp(r'"([^"\s]+)"\s*\.tr\(');
  
  // Pattern to extract context.tr() texts
  final contextTrPattern = RegExp(r'context\.tr\(\s*"([^"]+)"\s*\)');

  try {
    await for (final entity in directory.list(recursive: true)) {
      final path = entity.path;
      if (path.endsWith('.dart') && 
          !path.contains('.g.dart') && 
          !path.contains('main.dart') &&
          !path.contains('app_localizations.dart') &&
          !path.contains('find_texts.dart')) {
        
        try {
          final content = await File(path).readAsString();
          
          // Extract text from Text() widgets
          for (final match in textPattern.allMatches(content)) {
            final text = match.group(1);
            if (text != null && text.trim().isNotEmpty) {
              strings.add(text);
            }
          }
          
          // Extract literal strings (with some filtering)
          for (final match in literalPattern.allMatches(content)) {
            final text = match.group(1);
            if (text != null && 
                text.trim().length > 2 && 
                !text.startsWith('assets/') &&
                !text.startsWith(r'$') && 
                !text.contains('{') &&
                !text.contains('}') &&
                !text.contains('(') &&
                !text.contains(')') &&
                !text.contains(' ') &&
                !text.contains('@') &&
                !text.contains('//') &&
                !text.contains('/*') &&
                !text.endsWith('.')) {
              strings.add(text);
            }
          }
          
          // Extract .tr() keys
          for (final match in trPattern.allMatches(content)) {
            final text = match.group(1);
            if (text != null) {
              strings.add(text);
            }
          }
          
          // Extract context.tr() texts
          for (final match in contextTrPattern.allMatches(content)) {
            final text = match.group(1);
            if (text != null) {
              strings.add(text);
            }
          }
          
        } catch (e) {
          print('Error processing file $path: $e');
        }
      }
    }
    
    // Sort the strings
    final sortedStrings = strings.toList()..sort();
    
    // Create a map of translations
    final translations = <String, String>{};
    for (final str in sortedStrings) {
      if (str.trim().isNotEmpty) {
        // Create a key from the text (replace non-alphanumeric with _ and convert to lowercase)
        final key = str.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        translations[key] = str.trim();
      }
    }
    
    // Save to a JSON file
    const jsonEncoder = JsonEncoder.withIndent('  ');
    final jsonContent = jsonEncoder.convert(translations);
    await File('found_strings.json').writeAsString(jsonContent);
    
    print('Found ${translations.length} unique strings.');
    print('Results saved to found_strings.json');
    
  } catch (e) {
    print('Error: $e');
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class LogoService with ChangeNotifier {
  String? _logoPath;
  static const String _logoPathKey = 'company_logo_path';

  String? get logoPath => _logoPath;

  LogoService() {
    loadLogo();
  }

  Future<void> loadLogo() async {
    final prefs = await SharedPreferences.getInstance();
    _logoPath = prefs.getString(_logoPathKey);
    if (_logoPath != null && await File(_logoPath!).exists()) {
      notifyListeners();
    } else {
      _logoPath = null; // Reset if file doesn't exist
    }
  }

  Future<void> pickAndSaveLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_logoPathKey, savedImage.path);
      _logoPath = savedImage.path;
      notifyListeners();
    }
  }

  Future<void> deleteLogo() async {
    if (_logoPath != null) {
      final file = File(_logoPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _logoPath = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logoPathKey);
      notifyListeners();
    }
  }
}
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'device_unique_id';
  
  // Obtener o crear un ID único para el dispositivo
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      // Generar un nuevo ID único
      deviceId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }
  
  // Verificar si el dispositivo ya usó la prueba
  static Future<bool> hasUsedTrial() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();
    return prefs.getBool('${deviceId}_used_trial') ?? false;
  }
  
  // Marcar que este dispositivo ya usó la prueba
  static Future<void> markTrialUsed() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();
    await prefs.setBool('${deviceId}_used_trial', true);
  }
}

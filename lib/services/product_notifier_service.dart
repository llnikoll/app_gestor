import 'package:flutter/foundation.dart';

class ProductNotifierService {
  static final ProductNotifierService _instance = ProductNotifierService._internal();
  final ValueNotifier<int> _productUpdateNotifier = ValueNotifier<int>(0);

  factory ProductNotifierService() {
    return _instance;
  }

  ProductNotifierService._internal();

  ValueNotifier<int> get notifier => _productUpdateNotifier;

  void notifyProductUpdate() {
    _productUpdateNotifier.value++;
  }
}

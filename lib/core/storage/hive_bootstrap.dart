import 'package:hive_flutter/hive_flutter.dart';

class HiveBootstrap {
  static Future<void>? _initFuture;

  static Future<void> ensureInitialized() {
    _initFuture ??= Hive.initFlutter();
    return _initFuture!;
  }
}

import 'package:finance_frontend/core/logger/app_logger.dart';

class AppLog {
  static void d(String message) => logger.d(message);
  static void e(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.e(message, error: error, stackTrace: stackTrace);
}

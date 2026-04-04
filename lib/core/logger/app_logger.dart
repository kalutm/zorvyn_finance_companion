import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

final logger = Logger(
  level: kReleaseMode ? Level.off : Level.debug,
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 120,
    colors: true,
    printEmojis: false,
  ),
);


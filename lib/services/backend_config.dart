import 'package:flutter/foundation.dart';

class BackendConfig {
  const BackendConfig._();

  // Android Studio's emulator reaches the development computer at 10.0.2.2.
  static const baseUrl = String.fromEnvironment(
    'ECOAIR_BACKEND_URL',
    defaultValue: kDebugMode ? 'http://10.0.2.2:3001' : '',
  );
}

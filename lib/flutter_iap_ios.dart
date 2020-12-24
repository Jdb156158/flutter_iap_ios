
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterIapIos {
  static const MethodChannel _channel =
      const MethodChannel('flutter_iap_ios');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}

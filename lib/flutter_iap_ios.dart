
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterIapIos {
  static const MethodChannel _channel =
      const MethodChannel('flutter_iap_ios');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<bool> initProducts ({
    var list,
  }) async {
    final bool ret = await _channel.invokeMethod('initProducts',list);
    return ret;
  }
}

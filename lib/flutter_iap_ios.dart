
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterIapIos {
  static const MethodChannel _channel =
      const MethodChannel('flutter_iap_ios');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<List> initProducts ({
    var list,
  }) async {
    final List ret = await _channel.invokeMethod('initProducts',list);
    return ret;
  }

  static Future<bool> hasSubscribe()  async {
    final bool ret = await _channel.invokeMethod('hasSubscribe');
    return ret;
  }

  static Future<bool> initRestore()  async {
    final bool ret = await _channel.invokeMethod('initRestore');
    return ret;
  }

  static Future<bool> payProductId({var productId})  async {
    final bool ret = await _channel.invokeMethod('payProductId',productId);
    return ret;
  }

}

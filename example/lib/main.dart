import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_iap_ios/flutter_iap_ios.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  String _subscribeState = '当前未购买任何订阅型商品';

  bool _isHaveData;
  List _iosResultsList = [{'title' : '0000','desc' : '1111','productId' : '2222'}];

  @override
  void initState() {
    super.initState();
    initPlatformState();
    initProducts();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await FlutterIapIos.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> initProducts() async {

    var list = ['vipmonth'];

    List iosResultsList;

    iosResultsList =  await FlutterIapIos.initProducts(list: list);
    if(iosResultsList.length>0){
      setState(() {
        print("========initProducts=======setState");
        _iosResultsList = iosResultsList;
        _isHaveData = true;
        //商品列表初始化完成后在验证是否有购买订阅类产品，是否在有效期内
        checkHasSubscribe();
      });
    }

  }

  Future<void> checkHasSubscribe() async {
    bool ret = await FlutterIapIos.hasSubscribe();
    if(ret){
      setState(() {
        _subscribeState = '当前已经购买订阅型商品，并且在有效期内';
      });
    }else{
      setState(() {

        _subscribeState = '当前未购买任何订阅型商品或购买的订阅商品已过期';
      });
    }
  }



  Future<void> _restore() async {
    bool ret =  await FlutterIapIos.initRestore();
    if(ret){
      setState(() {
        _subscribeState = '恢复订阅购买成功！';
      });
    }else{
      setState(() {
        _subscribeState = '恢复订阅购买失败！';
      });
    }
  }

  Future<void>  _buyProductId(String productId) async {
    print(productId);
    bool ret =  await FlutterIapIos.payProductId(productId: productId);
    if(ret){
      setState(() {
        _subscribeState = '订阅购买成功！';
      });
    }else{
      setState(() {
        _subscribeState = '订阅购买失败！';
      });
    }
  }


  List<Widget> _MyBody() {
    var list = _iosResultsList.map((value) {
      return ListTile(
        title: Text(value["title"]),
        subtitle:Text(value["desc"]) ,
        trailing : Icon(Icons.arrow_forward_ios),
        leading: Icon(Icons.account_balance_wallet_outlined),
        onTap: (){
          _buyProductId(value["productId"]);
        },
      );

    });
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column (
            children: [
              SizedBox(
                height: 50,
              ),
              Text('苹果用户内购状态: $_subscribeState\n'),
              SizedBox(
                height: 20,
              ),
              OutlineButton.icon(
                icon: Icon(Icons.restore),
                label: Text("恢复购买"),
                onPressed: _restore,
              ),
              _isHaveData==false?Text('********暂时未获取到商品列表********'):Expanded(child: ListView(
                children: this._MyBody(),
              )),
              //Text('Running on: $_platformVersion\n'),
            ],
          )
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:payment_flutter/home_page.dart';
import 'package:payment_flutter/payment_ex.dart';
import 'package:pgw_sdk/core/pgw_sdk_delegate.dart';
import 'package:pgw_sdk/enum/api_response_code.dart';
import 'package:pgw_sdk/enum/api_environment.dart';

void main() async {
  Map<String, dynamic> pgwsdkParams = {'apiEnvironment': APIEnvironment.sandbox};

  await PGWSDK().initialize(pgwsdkParams, (error) {
    //Get error response and display error.
  }).whenComplete(() {
    runApp(const MyApp());
  });
}

Future<void> initialize() async {
  Map<String, dynamic> request = {'apiEnvironment': APIEnvironment.sandbox, 'log': true};

  await PGWSDK().initialize(request, (error) {
    log(error);

    ///Handle exception error
    ///Get error response and display error
    // CustomTabBar.showAlertDialog(Constants.titlePGWSDKError, 'Error: $error');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payment Gateway Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

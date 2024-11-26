import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:payment_flutter/home_page.dart';
import 'package:pgw_sdk/core/pgw_sdk_delegate.dart';
import 'package:pgw_sdk/enum/api_environment.dart';
import 'package:pgw_sdk/enum/api_response_code.dart';

class PaymentEx extends StatefulWidget {
  const PaymentEx({super.key});

  @override
  State<PaymentEx> createState() => _PaymentExState();
}

class _PaymentExState extends State<PaymentEx> {
  @override
  void initState() {
    super.initState();
    // getPaymentToken();
  }

  bool isLoading = false;
  String? paymentToken;
  String? respCode;
  String? respDesc;

  Future<void> getPaymentToken() async {
    setState(() {
      isLoading = true;
    });

    final Map<String, dynamic> paymentPayload = {
      "merchantID": "JT03",
      "invoiceNo": DateTime.now().millisecondsSinceEpoch.toString(),
      "description": 'widget.description',
      "amount": "100",
      "currencyCode": "IDR",
      "nonceStr": DateTime.now().millisecondsSinceEpoch.toString(),
      "paymentChannel": ["CC"]
    };

    const String merchantKey =
        '27987D9549844E0B4F5F4DCA69FEB716FAA5F095513F6F619FBDC8E865471DE7';

    try {
      final jwt = JWT(paymentPayload);
      String signedToken =
          jwt.sign(SecretKey(merchantKey), algorithm: JWTAlgorithm.HS256);

      final response = await http.post(
        Uri.parse('https://sandbox-pgw.2c2p.com/payment/4.3/paymentToken'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'payload': signedToken,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final responseToken = jsonResponse['payload'] as String;

        final JWT decodedJWT = JWT.verify(
          responseToken,
          SecretKey(merchantKey),
        );

        if (decodedJWT.payload['respCode'] == '0000') {
          setState(() {
            print(decodedJWT.payload['paymentToken']);
            paymentToken = decodedJWT.payload['paymentToken'];
            respDesc = decodedJWT.payload['respDesc'];
            respCode = decodedJWT.payload['respCode'];
          });
        } else {
          log('Payment token generation failed: ${decodedJWT.payload['respDesc']}');
        }
      }
    } catch (e) {
      log('Error in payment process: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              ElevatedButton(
                  onPressed: () {
                    getPaymentToken();
                  },
                  child: const Text('Get token')),
              ElevatedButton(
                  onPressed: () {
                    clientId();
                  },
                  child: const Text('clientId')),
              ElevatedButton(
                  onPressed: () {
                    configuration();
                  },
                  child: const Text('configuration')),
            ],
          ),
          Row(
            children: [
              ElevatedButton(
                  onPressed: () {
                    paymentOption();
                  },
                  child: const Text('paymentOption')),
            ],
          )
        ],
      ),
    );
  }

  void configuration() {
    PGWSDK().configuration((response) {
      print(response);
      // CustomTabBar.showAlertDialog(
      //     Constants.apiConfiguration.$1, prettyJson(response, indent: 2));
    }, (error) {
      print(error);

      ///Handle exception error
      ///Get error response and display error
      // CustomTabBar.showAlertDialog(Constants.titlePGWSDKError, 'Error: $error');
    });
  }

  void clientId() {
    PGWSDK().clientId((response) {
      log(response);
    }, (error) {
      ///Handle exception error
      ///Get error response and display error
      log('$error');
    });
  }

  void paymentOption() {
    Map<String, dynamic> request = {
      'paymentToken':
          'kSAops9Zwhos8hSTSeLTUUHKYCNd7QyGHLC04z211x9fGYPJI9eP5agTnl415EFjjUWhF8auwhPst3lqUUTMCY81g9/AQ66uO8w2KRmiAms=',
      "clientID": "E380BEC2BFD727A4B6845133519F3AD7",
      "locale": "en"
    };

    PGWSDK().paymentOption(request, (response) {
      if (response['responseCode'] == APIResponseCode.apiSuccess) {
        response['channels'].forEach((channel) {
          String channelName = channel['name'];
          debugPrint('channel: $channelName');
        });

        Map<String, dynamic> merchantInfo = response['merchantInfo'];
        String merchantName = merchantInfo['name'];
        String merchantId = merchantInfo['id'];

        debugPrint('merchant info >> name: $merchantName, id: $merchantId');
      } else {
        ///Get error response and display error
      }
      print(response);
      // CustomTabBar.showAlertDialog(
      //     Constants.apiPaymentOption.$1, prettyJson(response, indent: 2));
    }, (error) {
      print(error);

      ///Handle exception error
      ///Get error response and display error
      // CustomTabBar.showAlertDialog(Constants.titlePGWSDKError, 'Error: $error');
    });
  }
}

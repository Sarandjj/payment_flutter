import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

class PaymentPage extends StatefulWidget {
  final double amount;
  final String description;

  const PaymentPage({
    super.key,
    required this.amount,
    required this.description,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool isLoading = false;
  String? paymentUrl;
  String? paymentToken;
  String? respCode;
  String? respDesc;
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  bool showWebView = false; // Add this to control WebView visibility

  double progress = 0;

  @override
  @override
  void initState() {
    super.initState();
    enableWebViewDebugging();
    sendPaymentRequest();
  }

  Future<void> enableWebViewDebugging() async {
    // if (WebViewEnvironment.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    // }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  // Add this method to handle payment URL opening
  void _openPaymentUrl() {
    setState(() {
      showWebView = true;
    });
  }

  Future<void> sendPaymentRequest() async {
    setState(() {
      isLoading = true;
    });

    final Map<String, dynamic> paymentPayload = {
      "merchantID": "JT03",
      "invoiceNo": DateTime.now().millisecondsSinceEpoch.toString(),
      "description": widget.description,
      "amount": widget.amount,
      "currencyCode": "IDR",
      "nonceStr": DateTime.now().millisecondsSinceEpoch.toString(),
      "paymentChannel": ["ALL"]
    };

    const String merchantKey =
        '27987D9549844E0B4F5F4DCA69FEB716FAA5F095513F6F619FBDC8E865471DE7';

    try {
      final jwt = JWT(paymentPayload);
      String signedToken =
          jwt.sign(SecretKey(merchantKey), algorithm: JWTAlgorithm.HS256);

      print("signedToken: $signedToken");
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

        // Extract the payload from the response
        final responseToken = jsonResponse['payload'] as String;
        print("responseToken: $responseToken");
        final JWT decodedJWT = JWT.verify(
          responseToken,
          SecretKey(merchantKey),
        );

        final extractedPaymentUrl = decodedJWT.payload['webPaymentUrl'];
        // final paymentToken = decodedJWT.payload['paymentToken'];
        print(extractedPaymentUrl);
        final respCode1 = decodedJWT.payload['respCode'];
        // final respDesc = decodedJWT.payload['respDesc'];

        if (respCode1 == '0000') {
          setState(() {
            paymentUrl = extractedPaymentUrl;
            paymentToken = decodedJWT.payload['paymentToken'];
            print(paymentToken);
            respDesc = decodedJWT.payload['respDesc'];
            respCode = decodedJWT.payload['respCode'] ?? '';
          });
        } else {
          _showError('Payment token generation failed: $respDesc');
          print('respCode: $respCode');
        }
      } else {
        _showError('Failed to get payment token. Status: ${response.statusCode}');
        print('respCode: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error in payment process: $e');
      print(e);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          if (isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing payment...'),
                ],
              ),
            )
          else if (!showWebView && paymentUrl != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 16),
                          _buildDetailRow('Response Code', respCode ?? ''),
                          _buildDetailRow('Response Description', respDesc ?? ''),
                          _buildDetailRow('Payment Token', paymentToken ?? ''),
                          const SizedBox(height: 16),
                          const Text(
                            'Payment URL:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    paymentUrl!,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () => _copyToClipboard(paymentUrl!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _openPaymentUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Proceed to Payment'),
                    ),
                  ),
                ],
              ),
            )
          else if (showWebView && paymentUrl != null)
            Stack(
              children: [
                // Update the InAppWebView configuration in your widget:
                InAppWebView(
                  key: webViewKey,
                  initialUrlRequest: URLRequest(
                    url: WebUri(paymentUrl!),
                  ),
                  initialSettings: InAppWebViewSettings(
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    iframeAllow: "camera; microphone",
                    iframeAllowFullscreen: true,
                    javaScriptEnabled: true, // Add this
                    domStorageEnabled: true, // Add this
                    supportMultipleWindows: true, // Add this
                    useWideViewPort: true, // Add this
                    loadWithOverviewMode: true, // Add this
                  ),
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    debugPrint("Started loading: $url");
                    setState(() {
                      progress = 0;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    debugPrint("Finished loading: $url");
                    setState(() {
                      progress = 1.0;
                    });

                    if (url.toString().contains('success')) {
                      Navigator.of(context).pop(true);
                    } else if (url.toString().contains('failure')) {
                      Navigator.of(context).pop(false);
                    }
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    var uri = navigationAction.request.url!;
                    debugPrint("Override URL: $uri");

                    // Allow all navigation
                    return NavigationActionPolicy.ALLOW;
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      this.progress = progress / 100;
                    });
                  },
                  onLoadError: (controller, url, code, message) {
                    debugPrint("Load Error: Code: $code, Message: $message");
                    _showError('Error loading: $message');
                  },
                  onLoadHttpError: (controller, url, statusCode, description) {
                    debugPrint(
                        "HTTP Error: Status: $statusCode, Description: $description");
                    _showError('HTTP Error: $description');
                  },
                ),
                if (progress < 1.0) LinearProgressIndicator(value: progress),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

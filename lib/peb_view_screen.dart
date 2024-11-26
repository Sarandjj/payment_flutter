import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pgw_sdk/core/pgw_sdk_delegate.dart';
import 'package:pgw_sdk/core/pgw_webview_navigation_delegate.dart';
import 'package:pgw_sdk/enum/api_response_code.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PGWWebViewScreen extends StatefulWidget {
  final String redirectUrl;

  const PGWWebViewScreen({super.key, required this.redirectUrl});

  @override
  State<PGWWebViewScreen> createState() => _PGWWebViewScreenState();
}

class _PGWWebViewScreenState extends State<PGWWebViewScreen> {
  WebViewController? _webViewController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
  }

  void _initializeWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(PGWNavigationDelegate(
        onHttpAuthRequest: (HttpAuthRequest request) {
          log('onHttpAuthRequest', error: request.toString());
        },
        onProgress: (int progress) {
          log('onProgress: $progress');
        },
        onPageStarted: (String url) {
          log('onPageStarted: $url');
        },
        onPageFinished: (String url) {
          log('onPageFinished: $url');
        },
        onWebResourceError: (WebResourceError error) {
          log('onWebResourceError: ${error.description}');
        },
        onUrlChange: (UrlChange change) {
          log('onUrlChange: ${change.url}');
        },
        onInquiry: (String paymentToken) {
          log('onInquiry called with payment token: $paymentToken');

          // Prevent multiple processing
          if (_isProcessing) return;
          _isProcessing = true;

          // Perform transaction status inquiry
          _performTransactionStatusInquiry(paymentToken);
        },
      ))
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }

  void _performTransactionStatusInquiry(String paymentToken) {
    Map<String, dynamic> request = {'paymentToken': paymentToken, 'additionalInfo': true};

    PGWSDK().transactionStatus(request, (response) {
      // Use a safe navigation method
      _safeNavigation(response);
      print('res $response');
    }, (error) {
      // Use a safe navigation method
      _safeNavigation({'error': error}, isSuccess: false);
    });
  }

  void _safeNavigation(Map<String, dynamic> transactionDetails, {bool isSuccess = true}) {
    // Check if the widget is still mounted before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Use root navigator to ensure navigation works
      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TransactionResultPage(
            transactionDetails: transactionDetails,
            status: isSuccess,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PGWWebViewScreen')),
      body: _webViewController != null
          ? WebViewWidget(controller: _webViewController!)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

// Transaction Result Page (as in previous example)
class TransactionResultPage extends StatelessWidget {
  final Map<String, dynamic> transactionDetails;
  final bool status;

  const TransactionResultPage(
      {super.key, required this.transactionDetails, required this.status});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(status ? 'Transaction Successful' : 'Transaction Failed'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    status ? Icons.check_circle : Icons.error,
                    color: status ? Colors.green : Colors.red,
                    size: 100,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    status ? 'Payment Successful' : 'Payment Failed',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: status ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Detailed transaction information

                  if (status && transactionDetails['additionalInfo'] != null)
                    ..._buildTransactionDetails(transactionDetails['additionalInfo']),
                  if (!status)
                    Text(
                      transactionDetails['error']?.toString() ??
                          transactionDetails['responseDescription'] ??
                          'Unknown error occurred',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTransactionDetails(Map<String, dynamic> additionalInfo) {
    return [
      Text('Invoice No: ${additionalInfo['transactionInfo']?['invoiceNo'] ?? 'N/A'}'),
      Text('Reference No: ${additionalInfo['referenceNo'] ?? 'N/A'}'),
      Text('Amount: ${additionalInfo['amount'] ?? 'N/A'}'),
      // Add more transaction details as needed
    ];
  }
}

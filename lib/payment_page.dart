import 'dart:convert';
import 'dart:developer';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:payment_flutter/peb_view_screen.dart';
import 'package:pgw_sdk/core/pgw_sdk_delegate.dart';
import 'package:pgw_sdk/enum/api_response_code.dart';

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
  String? paymentToken;
  String? respCode;
  String? respDesc;

  // Form controllers
  final _cardNumberController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    getPaymentToken();
  }

  Future<void> getPaymentToken() async {
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
            paymentToken = decodedJWT.payload['paymentToken'];
            respDesc = decodedJWT.payload['respDesc'];
            respCode = decodedJWT.payload['respCode'];
          });
        } else {
          _showError(
              'Payment token generation failed: ${decodedJWT.payload['respDesc']}');
        }
      }
    } catch (e) {
      _showError('Error in payment process: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Construct billing address
      Map<String, dynamic> userAddress = {
        'billingAddress1': '128 Beach Road',
        'billingAddress2': '#21-04',
        'billingAddress3': 'Guoco Midtown',
        'billingCity': 'Singapore',
        'billingState': 'Singapore',
        'billingPostalCode': '189773',
        'billingCountryCode': 'SG'
      };

      // Construct payment code
      Map<String, dynamic> paymentCode = {
        'channelCode': 'CC',
      };

      // Construct payment request with card details
      Map<String, dynamic> paymentRequest = {
        'cardNo': '4111111111111111',
        'expiryMonth': 12,
        'expiryYear': 2026,
        'securityCode': '123',
        // ...userAddress
      };

      // Construct final transaction request
      Map<String, dynamic> transactionRequest = {
        'paymentToken': paymentToken,
        'payment': {'code': paymentCode, 'data': paymentRequest}
      };

      // Process the payment using SDK with proper error handling
      PGWSDK().proceedTransaction(transactionRequest, (response) {
        if (response['responseCode'] == APIResponseCode.transactionAuthenticateRedirect ||
            response['responseCode'] ==
                APIResponseCode.transactionAuthenticateFullRedirect) {
          log('Payment response: $response');
          // Handle redirect if needed
          String redirectUrl = response['data'];
          _navigateToWebView(redirectUrl!);
          // _handleRedirect(redirectUrl);
        } else if (response['responseCode'] == APIResponseCode.transactionCompleted) {
          Navigator.of(context).pop(true); // Success
        } else {
          log('Payment response: $response');
          String errorMessage = response['responseMessage'] ?? 'Payment failed';
          _showError(errorMessage);
        }
      }, (error) {
        // Handle PlatformException properly
        if (error is PlatformException) {
          log('Payment response: ${error.message}');
          _showError('Payment error: ${error.message}');
        } else {
          _showError('An unexpected error occurred: $error');
        }
      });
    } catch (e) {
      _showError('Error processing payment: $e');
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
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing payment...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount: ${widget.amount} IDR',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _cardNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Card Number',
                                hintText: '4111 1111 1111 1111',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter card number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _expiryMonthController,
                                    decoration: const InputDecoration(
                                      labelText: 'Month (MM)',
                                      hintText: '12',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _expiryYearController,
                                    decoration: const InputDecoration(
                                      labelText: 'Year (YYYY)',
                                      hintText: '2026',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cvvController,
                              decoration: const InputDecoration(
                                labelText: 'CVV',
                                hintText: '123',
                              ),
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter CVV';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Pay Now'),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        // onPressed: processPayment,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PGWWebViewScreen(
                                redirectUrl:
                                    "https://demo2.2c2p.com/2C2PFrontEnd/storedCardPaymentV2/MPaymentProcess.aspx?token=a8f37a71fb1342e6899de7f3b0b89cc5&ver=2",
                              ),
                            ),
                          );
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Pay Now'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _navigateToWebView(String redirectUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PGWWebViewScreen(
          redirectUrl: redirectUrl,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }
}

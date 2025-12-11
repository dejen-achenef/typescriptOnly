import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:go_router/go_router.dart';

// To test this screen, you can set it as the `home` in your main.dart:
// home: const VerifyOtpScreen(email: 'your.email@example.com'),

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  // State for OTP input
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;

  // State for the resend countdown timer
  late Timer _timer;
  int _secondsRemaining = 59;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers and focus nodes for 6 digits
    _focusNodes = List.generate(6, (index) => FocusNode());
    _controllers = List.generate(6, (index) => TextEditingController());
    startTimer();
  }

  void startTimer() {
    // Reset timer state
    setState(() => _canResend = false);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  void resendCode() {
    // TODO: Implement your API call to resend the code
    print('Resending code...');
    setState(() => _secondsRemaining = 59);
    startTimer();
  }

  @override
  void dispose() {
    // IMPORTANT: Dispose all controllers and focus nodes to prevent memory leaks
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer.cancel();
    super.dispose();
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty) {
      // Move to the next field if a digit is entered
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last digit entered, unfocus and attempt to verify
        _focusNodes[index].unfocus();
        _verifyOtp();
      }
    }
  }

  void _handleBackspace(int index) {
    // Move to the previous field on backspace if the current field is empty
    if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _verifyOtp() {
    final enteredOtp = _controllers.map((c) => c.text).join();
    if (enteredOtp.length == 6) {
      print('Verifying OTP: $enteredOtp');
      // TODO: Add your OTP verification logic (e.g., API call)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Verifying OTP: $enteredOtp')));
      context.push('/resetpassword');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(theme, context),
              const SizedBox(height: 48),
              Text(
                'Enter Verification Code',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a 6-digit code to ${widget.email}',
                style: theme.textTheme.labelMedium?.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 48),

              // Responsive OTP Input Row
              _buildOtpInputRow(),
              const SizedBox(height: 32),

              _buildResendSection(theme),
              const SizedBox(height: 48),
              _buildDivider(theme),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Verify',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _buildLoginLink(theme),
            ],
          ),
        ),
      ),
    );
  }

  // This widget makes the OTP boxes responsive
  Widget _buildOtpInputRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth =
            (constraints.maxWidth - (5 * 10)) / 6; // 6 boxes, 5 spaces of 10px

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (index) => _OtpInputBox(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              onChanged: (value) => _onOtpChanged(value, index),
              onBackspace: () => _handleBackspace(index),
              width: boxWidth,
            ),
          ),
        );
      },
    );
  }

  Widget _buildResendSection(ThemeData theme) {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            text: "Didn't receive it? ",
            style: theme.textTheme.labelLarge,
            children: [
              TextSpan(
                text: 'Resend',
                style: theme.textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = _canResend ? resendCode : null,
              ),
            ],
          ),
        ),
        // Show timer only when it's counting down
        if (!_canResend) ...[
          const SizedBox(height: 8),
          Text(
            'Resend in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
            style: theme.textTheme.labelLarge,
          ),
        ],
      ],
    );
  }
}

// A dedicated, reusable widget for a single OTP input box
class _OtpInputBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  final double width;

  const _OtpInputBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: width * 1.1, // Slightly taller than wide for better aesthetics
      child: RawKeyboardListener(
        focusNode: FocusNode(), // Dummy focus node for the listener
        onKey: (event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (controller.text.isEmpty) {
              onBackspace();
            }
          }
        },
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          maxLength: 1,
          onChanged: onChanged,
          decoration: InputDecoration(
            counterText: '', // Hide the maxLength counter
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildHeader(ThemeData theme, BuildContext context) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 12),
      Text(
        'ThyScan',
        style: Theme.of(context).textTheme.titleLarge!.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ],
  );
}

Widget _buildDivider(ThemeData theme) {
  return Row(
    children: [
      const Expanded(child: Divider(thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text('or', style: theme.textTheme.labelMedium),
      ),
      const Expanded(child: Divider(thickness: 1)),
    ],
  );
}

Widget _buildLoginLink(ThemeData theme) {
  return Center(
    child: Text.rich(
      TextSpan(
        text: 'Already have an account? ',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.labelMedium?.color,
        ),
        children: [
          TextSpan(
            text: 'Log in',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // TODO: Navigate to Login Screen
                print('Navigate to Login');
              },
          ),
        ],
      ),
    ),
  );
}

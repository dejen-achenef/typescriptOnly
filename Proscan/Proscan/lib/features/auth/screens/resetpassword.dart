import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// To test this screen, you can set it as the `home` in your main.dart:
// home: const CreateNewPasswordScreen(),

class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key});

  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State for password visibility and validation checks
  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  bool _hasMin8Chars = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    // Listener to update password requirement checks in real-time
    _newPasswordController.addListener(_updatePasswordRequirements);
  }

  void _updatePasswordRequirements() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMin8Chars = password.length >= 8;
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  void dispose() {
    // Clean up controllers
    _newPasswordController.removeListener(_updatePasswordRequirements);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _resetPassword() {
    // Validate the form. If it's valid, proceed.
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // TODO: Implement your password reset logic here (e.g., API call)
      print('Password Reset Successful!');
      print('New Password: ${_newPasswordController.text}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resetting your password...')),
      );
      // TODO: Navigate to a success screen or back to login
    }
    context.push('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 48),
                Text(
                  'Create New Password',
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your new password must be different from previous ones.',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Password Fields
                _CustomPasswordField(
                  controller: _newPasswordController,
                  labelText: 'New Password',
                  hintText: 'Enter your new password',
                  isObscured: _isNewPasswordObscured,
                  onToggleVisibility: () => setState(
                    () => _isNewPasswordObscured = !_isNewPasswordObscured,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter a password';
                    if (!_hasMin8Chars || !_hasNumber || !_hasSpecialChar)
                      return 'Password does not meet requirements';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _CustomPasswordField(
                  controller: _confirmPasswordController,
                  labelText: 'Confirm Password',
                  hintText: 'Confirm your new password',
                  isObscured: _isConfirmPasswordObscured,
                  onToggleVisibility: () => setState(
                    () => _isConfirmPasswordObscured =
                        !_isConfirmPasswordObscured,
                  ),
                  validator: (value) {
                    if (value != _newPasswordController.text)
                      return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Password Requirement Checkers
                _buildPasswordRequirements(),
                const SizedBox(height: 40),

                // Reset Password Button
                ElevatedButton(
                  onPressed: _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: MediaQuery.sizeOf(context).width * 0.29,
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for displaying password requirements with dynamic checkmarks
  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PasswordRequirement(
          text: 'Minimum 8 characters',
          isValid: _hasMin8Chars,
        ),
        const SizedBox(height: 8),
        _PasswordRequirement(text: 'At least 1 number', isValid: _hasNumber),
        const SizedBox(height: 8),
        _PasswordRequirement(
          text: 'At least 1 special character',
          isValid: _hasSpecialChar,
        ),
      ],
    );
  }
}

class _CustomPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final bool isObscured;
  final VoidCallback onToggleVisibility;
  final String? Function(String?)? validator;

  const _CustomPasswordField({
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.isObscured,
    required this.onToggleVisibility,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isObscured,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: theme.textTheme.labelMedium?.color),
            filled: true,
            fillColor: theme
                .colorScheme
                .surfaceVariant, // This color adapts to light/dark theme
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 12,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isObscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: theme.colorScheme.primary,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  final String text;
  final bool isValid;

  const _PasswordRequirement({required this.text, required this.isValid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validColor = theme.colorScheme.primary;
    final invalidColor = theme.textTheme.labelMedium?.color;

    return Row(
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          firstChild: Icon(Icons.check_circle, color: validColor, size: 18),
          secondChild: Icon(
            Icons.check_circle_outline,
            color: invalidColor,
            size: 18,
          ),
          crossFadeState: isValid
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: isValid ? validColor : invalidColor),
        ),
      ],
    );
  }
}

// Consistent header from other auth screens
Widget _buildHeader(ThemeData theme) {
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
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    ],
  );
}

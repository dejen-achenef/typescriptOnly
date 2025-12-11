import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('6-digit code sent to ${_emailCtrl.text}'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      context.push('/verifyotp');
    }
  }

  // Professional, theme-aware input fill
  // Light: subtle brand-tinted surface; Dark: subtle white overlay on surface
  Color _inputFillColor(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.06), cs.surface)
        : Color.alphaBlend(cs.primary.withOpacity(0.04), cs.surface);
  }

  Color _inputBorderColor(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return isDark
        ? Colors.white.withOpacity(0.12)
        : cs.outline.withOpacity(0.25);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive horizontal padding and max content width
            final double horizontalPad = (constraints.maxWidth * 0.075).clamp(
              16.0,
              28.0,
            );
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  24,
                  horizontalPad,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        'Reset your password',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: scheme.onBackground,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'Enter your email and we\'ll send you a 6-digit code to reset your password.',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: scheme.onBackground.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field (floating label)
                            _buildFloatingField(
                              label: 'Email Address',
                              hint: 'yourname@example.com',
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              icon: Iconsax.sms,
                              keyboardType: TextInputType.emailAddress,
                              scheme: scheme,
                              fillColor: _inputFillColor(context),
                              borderColor: _inputBorderColor(context),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                final emailRx = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                );
                                if (!emailRx.hasMatch(v.trim())) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Send Code Button
                            _buildSendCodeButton(scheme),
                            const SizedBox(height: 28),

                            // Divider
                            _buildDivider(scheme),
                            const SizedBox(height: 24),

                            // Social Login
                            _buildSocialLogin(scheme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Login Link
                      _buildLoginSection(scheme),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required ColorScheme scheme,
    required Color fillColor,
    required Color borderColor,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _sendCode(),
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: scheme.onBackground,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
          color: scheme.onBackground.withOpacity(0.6),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.inter(
          color: scheme.onBackground.withOpacity(0.42),
        ),
        prefixIcon: Icon(icon, size: 20, color: scheme.primary),
        suffixIcon: suffix,
        filled: true,
        fillColor: fillColor, // refined fill
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildSendCodeButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : Text(
                'Send Reset Code',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: scheme.outline.withOpacity(0.2), thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or continue with',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: scheme.onBackground.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: scheme.outline.withOpacity(0.2), thickness: 1),
        ),
      ],
    );
  }

  Widget _buildSocialLogin(ColorScheme scheme) {
    final bg = _inputFillColor(context);
    final border = _inputBorderColor(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(
          icon: Icons.g_mobiledata,
          onTap: () {},
          bg: bg,
          borderColor: border,
          scheme: scheme,
        ),
        const SizedBox(width: 16),
        _buildSocialButton(
          icon: Icons.apple,
          onTap: () {},
          bg: bg,
          borderColor: border,
          scheme: scheme,
        ),
        const SizedBox(width: 16),
        _buildSocialButton(
          icon: Icons.facebook,
          onTap: () {},
          bg: bg,
          borderColor: border,
          scheme: scheme,
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme scheme,
    required Color bg,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Icon(
          icon,
          color: scheme.onBackground.withOpacity(0.7),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildLoginSection(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Remember your password? ',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: scheme.onBackground.withOpacity(0.7),
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/login'),
          child: Text(
            'Log In',
            style: GoogleFonts.inter(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

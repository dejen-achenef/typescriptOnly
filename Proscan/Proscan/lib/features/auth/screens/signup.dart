import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:thyscan/providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;

  // Animations
  late final AnimationController _nebulaController;
  late final AnimationController _shimmerController;
  late final AnimationController _entranceController;
  late final List<AnimationController> _starControllers;
  final List<Star> _stars = [];

  @override
  void initState() {
    super.initState();

    // Background Animations (Only visible in Dark Mode)
    _nebulaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _starControllers = List.generate(10, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2000 + (index * 500)),
      )..repeat(reverse: true);
    });

    _initializeStars();
    for (final controller in _starControllers) controller.forward();

    // Entrance Animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entranceController.forward();
    });
  }

  void _initializeStars() {
    final random = Random();
    for (int i = 0; i < 60; i++) {
      _stars.add(
        Star(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 1.5 + 0.5,
          opacity: random.nextDouble(),
          controllerIndex: random.nextInt(_starControllers.length),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    _nebulaController.dispose();
    _shimmerController.dispose();
    _entranceController.dispose();
    for (var c in _starControllers) c.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please agree to the Terms & Conditions',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authController = ref.read(authControllerProvider.notifier);

    try {
      final requiresEmailConfirmation = await authController.signUpWithEmail(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        fullName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
      );

      if (!mounted) return;

      if (requiresEmailConfirmation) {
        // Email confirmation is required
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Account created! Please check your email to confirm your account.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
          // Navigate to login screen
          context.go('/login');
        }
        return;
      }

      // Auth state should update immediately via stream (we emit directly in AuthService)
      // Check state right away - should be authenticated by now
      final authState = ref.read(authControllerProvider);
      
      if (!mounted) return;

      if (authState.isAuthenticated) {
        // Show success message and navigate immediately
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account created successfully!',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        context.go('/appmainscreen');
      } else if (authState.error != null) {
        // Show error if authentication failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.error!, style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Check if this is an email confirmation error (expected behavior)
      final authState = ref.read(authControllerProvider);
      final errorMessage = authState.error ?? '';

      if (errorMessage.contains('check your email') ||
          errorMessage.contains('confirm your account')) {
        // This is expected - email confirmation required
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: GoogleFonts.inter()),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        // Navigate to login screen
        context.go('/login');
      } else {
        // Actual error occurred
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.isNotEmpty
                  ? errorMessage
                  : 'An error occurred. Please try again.',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    HapticFeedback.mediumImpact();

    final authController = ref.read(authControllerProvider.notifier);

    try {
      await authController.signInWithGoogle();

      if (!mounted) return;

      // Auth state should update immediately via stream (we emit directly in AuthService)
      // Check state right away - should be authenticated by now
      final authState = ref.read(authControllerProvider);
      
      if (authState.isAuthenticated) {
        // Navigate immediately when authenticated
        context.go('/appmainscreen');
      } else if (authState.error != null && 
                 !authState.error!.toLowerCase().contains('cancelled')) {
        // Show error if authentication failed (but not for cancellation)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.error!, style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Error is already handled in the controller (cancellation is silent)
      final authState = ref.read(authControllerProvider);
      if (authState.error != null && 
          !authState.error!.toLowerCase().contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.error!, style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors
    final bgColor = isDark ? const Color(0xFF050508) : Colors.white;
    final textColor = isDark
        ? Colors.white
        : const Color(0xFF1E293B); // Slate-800
    final primaryColor = isDark
        ? const Color(0xFF4FACFE)
        : const Color(0xFF2563EB); // Bright Blue

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Background: Stars/Nebula ONLY for Dark Mode
          if (isDark) _buildNightSky(size),

          // 2. Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildAnimatedEntry(
                          delay: 0,
                          child: Center(
                            child: Text(
                              'Create your account',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Form Fields
                        _buildAnimatedEntry(
                          delay: 100,
                          child: Column(
                            children: [
                              _buildField(
                                label: 'Full Name',
                                controller: _nameCtrl,
                                focusNode: _nameFocus,
                                icon: Iconsax.user,
                                nextFocus: _emailFocus,
                                isDark: isDark,
                                primaryColor: primaryColor,
                              ),
                              const SizedBox(height: 16),

                              _buildField(
                                label: 'Email Address',
                                controller: _emailCtrl,
                                focusNode: _emailFocus,
                                icon: Iconsax.sms,
                                nextFocus: _passFocus,
                                keyboardType: TextInputType.emailAddress,
                                isDark: isDark,
                                primaryColor: primaryColor,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Email is required';
                                  }
                                  final emailRegex = RegExp(
                                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                  );
                                  if (!emailRegex.hasMatch(v.trim())) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _buildField(
                                label: 'Password',
                                controller: _passCtrl,
                                focusNode: _passFocus,
                                icon: Iconsax.lock,
                                nextFocus: _confirmFocus,
                                obscureText: _obscurePass,
                                isDark: isDark,
                                primaryColor: primaryColor,
                                toggleObscure: () => setState(
                                  () => _obscurePass = !_obscurePass,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (v.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _buildField(
                                label: 'Confirm Password',
                                controller: _confirmCtrl,
                                focusNode: _confirmFocus,
                                icon: Iconsax.lock_1,
                                obscureText: _obscureConfirm,
                                isLast: true,
                                isDark: isDark,
                                primaryColor: primaryColor,
                                onSubmitted: (_) => _signup(),
                                toggleObscure: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (v != _passCtrl.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Terms
                        _buildAnimatedEntry(
                          delay: 200,
                          child: _buildTermsAgreement(
                            isDark,
                            primaryColor,
                            textColor,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Button
                        _buildAnimatedEntry(
                          delay: 300,
                          child: _buildButton(primaryColor),
                        ),

                        const SizedBox(height: 32),

                        // Divider
                        _buildAnimatedEntry(
                          delay: 400,
                          child: _buildDivider(isDark, textColor),
                        ),

                        const SizedBox(height: 32),

                        // Google Sign-In Button
                        _buildAnimatedEntry(
                          delay: 500,
                          child: _buildGoogleSignInButton(isDark, primaryColor),
                        ),

                        const SizedBox(height: 24),

                        // Login Link
                        _buildAnimatedEntry(
                          delay: 600,
                          child: _buildLoginLink(primaryColor, textColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildNightSky(Size size) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _nebulaController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.6 + sin(_nebulaController.value) * 0.2,
                      -0.3,
                    ),
                    radius: 1.5,
                    colors: const [Color(0xFF1A1F35), Colors.transparent],
                  ),
                ),
              );
            },
          ),
        ),
        ..._stars.map(
          (star) => Positioned(
            left: size.width * star.x,
            top: size.height * star.y,
            child: AnimatedBuilder(
              animation: _starControllers[star.controllerIndex],
              builder: (context, child) {
                final val = _starControllers[star.controllerIndex].value;
                return Opacity(
                  opacity: star.opacity * (0.5 + sin(val * pi) * 0.5),
                  child: Container(
                    width: star.size,
                    height: star.size,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedEntry({required int delay, required Widget child}) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        final double start = delay / 1000;
        final double end = start + 0.4;
        final curve = CurvedAnimation(
          parent: _entranceController,
          curve: Interval(start, end, curve: Curves.easeOutQuart),
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
    FocusNode? nextFocus,
    bool obscureText = false,
    bool isLast = false,
    VoidCallback? toggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final isFocused = focusNode.hasFocus;

        // PROFESSIONAL LIGHT MODE COLORS
        // Fill: Very subtle gray (#F8FAFC)
        // Border: Light gray (#E2E8F0)
        // Focus: Primary Color

        final fillColor = isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF8FAFC);

        final borderColor = isDark
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFFE2E8F0);

        final iconColor = isDark
            ? Colors.white54
            : const Color(0xFF94A3B8); // Slate-400

        final labelColor = isDark
            ? Colors.white60
            : const Color(0xFF64748B); // Slate-500

        final textColor = isDark
            ? Colors.white
            : const Color(0xFF0F172A); // Slate-900

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isFocused
                ? (isDark ? Colors.white.withOpacity(0.08) : Colors.white)
                : fillColor,
            border: Border.all(
              color: isFocused ? primaryColor : borderColor,
              width: isFocused ? 1.5 : 1,
            ),
            boxShadow: isFocused && !isDark
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            obscureText: obscureText,
            textInputAction: isLast
                ? TextInputAction.done
                : TextInputAction.next,
            onFieldSubmitted: (v) {
              if (onSubmitted != null) onSubmitted(v);
              if (nextFocus != null)
                FocusScope.of(context).requestFocus(nextFocus);
            },
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              labelText: label,
              labelStyle: GoogleFonts.inter(
                color: isFocused ? primaryColor : labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                icon,
                color: isFocused ? primaryColor : iconColor,
                size: 20,
              ),
              suffixIcon: toggleObscure != null
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Iconsax.eye_slash : Iconsax.eye,
                        color: iconColor,
                        size: 20,
                      ),
                      onPressed: toggleObscure,
                    )
                  : null,
            ),
            validator:
                validator ??
                (v) => (v == null || v.isEmpty) ? '$label is required' : null,
          ),
        );
      },
    );
  }

  Widget _buildTermsAgreement(
    bool isDark,
    Color primaryColor,
    Color textColor,
  ) {
    final borderColor = isDark ? Colors.white38 : const Color(0xFFCBD5E1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _agreeToTerms = !_agreeToTerms);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _agreeToTerms ? primaryColor : Colors.transparent,
              border: Border.all(
                color: _agreeToTerms ? primaryColor : borderColor,
                width: 1.5,
              ),
            ),
            child: _agreeToTerms
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                color: textColor.withOpacity(0.6),
                fontSize: 14,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(Color primaryColor) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return GestureDetector(
      onTap: isLoading ? null : _signup,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: primaryColor,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              Text(
                'Create Account',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark, Color textColor) {
    final divColor = isDark
        ? Colors.white.withOpacity(0.1)
        : const Color(0xFFE2E8F0);
    return Row(
      children: [
        Expanded(child: Divider(color: divColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or sign up with',
            style: GoogleFonts.inter(
              color: textColor.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: divColor)),
      ],
    );
  }

  Widget _buildGoogleSignInButton(bool isDark, Color primaryColor) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    final bgColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return GestureDetector(
      onTap: isLoading ? null : _signInWithGoogle,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.g_mobiledata, color: iconColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Sign up with Google',
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink(Color primaryColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: GoogleFonts.inter(color: textColor.withOpacity(0.6)),
        ),
        GestureDetector(
          onTap: () => context.push('/login'),
          child: Text(
            'Sign In',
            style: GoogleFonts.inter(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class Star {
  final double x, y, size, opacity;
  final int controllerIndex;
  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.controllerIndex,
  });
}

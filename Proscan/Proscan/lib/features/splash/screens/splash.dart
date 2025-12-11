import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/services/app_logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();

    // Check authentication and navigate accordingly
    _checkAuthAndNavigate();
  }

  /// Checks authentication state and navigates to appropriate screen
  /// OFFLINE-FIRST: Always goes to HomeScreen, never blocks on login
  Future<void> _checkAuthAndNavigate() async {
    // Wait for minimum splash duration (1.8 seconds for animation)
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    // OFFLINE-FIRST: Always go to HomeScreen (never block on login)
    // AuthService will silently initialize in background and auto-login if online
    // If offline or no session, user stays in Guest Mode
    AppLogger.info('Splash: Navigating to HomeScreen (offline-first, no blocking)');
    if (mounted) {
      context.go('/appmainscreen');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double scale = size.width / 375;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(
            0xFF0A0F1C,
          ), // Dark professional background
          body: Stack(
            children: [
              // Subtle background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5,
                    colors: [const Color(0xFF1A233D), const Color(0xFF0A0F1C)],
                  ),
                ),
              ),

              // Very subtle grid pattern for professional look
              Opacity(
                opacity: 0.03,
                child: CustomPaint(size: size, painter: _GridPainter()),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Premium Logo Container
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow effect
                        Container(
                          width: 160 * scale,
                          height: 160 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF3DCC4B).withValues(alpha: 0.2),
                                const Color(0xFF3DCC4B).withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),

                        // Main logo container
                        Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 120 * scale,
                            height: 120 * scale,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A233D),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3DCC4B,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 20 * scale,
                                  spreadRadius: 2 * scale,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 30 * scale,
                                  spreadRadius: 5 * scale,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFF2D3746),
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Scanner icon
                                Center(
                                  child: Icon(
                                    Icons.document_scanner_rounded,
                                    size: 50 * scale,
                                    color: const Color(0xFF3DCC4B),
                                  ),
                                ),

                                // Animated scanning line
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    return Positioned(
                                      top:
                                          25 * scale +
                                          (70 * scale * _controller.value),
                                      left: 15 * scale,
                                      right: 15 * scale,
                                      child: Container(
                                        height: 2 * scale,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(
                                                0xFF3DCC4B,
                                              ).withValues(alpha: 0.0),
                                              const Color(0xFF3DCC4B),
                                              const Color(
                                                0xFF3DCC4B,
                                              ).withValues(alpha: 0.0),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            1,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Corner accents
                                Positioned(
                                  top: 20 * scale,
                                  left: 20 * scale,
                                  child: Container(
                                    width: 8 * scale,
                                    height: 8 * scale,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3DCC4B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 20 * scale,
                                  right: 20 * scale,
                                  child: Container(
                                    width: 8 * scale,
                                    height: 8 * scale,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3DCC4B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 40 * scale),

                    // App Name with Professional Typography
                    SlideTransition(
                      position: _slideAnimation,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Text(
                          'ThyScan',
                          style: GoogleFonts.poppins(
                            fontSize: 42 * scale,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 40.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

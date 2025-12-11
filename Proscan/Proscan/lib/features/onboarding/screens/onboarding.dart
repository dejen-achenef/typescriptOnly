import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _nebulaController;
  late final AnimationController _shimmerController;
  late final List<AnimationController> _starControllers;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Precision Scan',
      description: 'Our AI beam detects edges and enhances clarity instantly.',
      icon: Icons.document_scanner_rounded,
      gradient: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      iconAnimation: IconAnimationType.scan,
    ),
    OnboardingItem(
      title: 'Smart Extraction',
      description:
          'Watch raw pixels transform into editable text before your eyes.',
      icon: Icons.text_snippet_rounded,
      gradient: [Color(0xFFD4FC79), Color(0xFF96E6A1)],
      iconAnimation: IconAnimationType.text,
    ),
    OnboardingItem(
      title: 'Cloud Sync',
      description: 'Documents float seamlessly to your secure private storage.',
      icon: Icons.cloud_upload_rounded,
      gradient: [Color(0xFFF093FB), Color(0xFFF5576C)],
      iconAnimation: IconAnimationType.cloud,
    ),
  ];

  final List<Star> _stars = [];

  @override
  void initState() {
    super.initState();

    // Background Nebula Breathing
    _nebulaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    // Button Shimmer
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Star Twinkling
    _starControllers = List.generate(10, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2000 + (index * 500)),
      )..repeat(reverse: true);
    });

    _initializeStars();

    for (final controller in _starControllers) controller.forward();
  }

  void _initializeStars() {
    final random = Random();
    for (int i = 0; i < 120; i++) {
      _stars.add(
        Star(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 2 + 0.5,
          depth: random.nextDouble(),
          opacity: random.nextDouble(),
          controllerIndex: random.nextInt(_starControllers.length),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nebulaController.dispose();
    _shimmerController.dispose();
    for (var c in _starControllers) c.dispose();
    super.dispose();
  }

  void _onGetStarted() {
    HapticFeedback.mediumImpact();
    context.go('/signup');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF050508), // Deepest black/blue
      body: Stack(
        children: [
          // 1. Persistent Night Sky Background
          _buildNightSky(size),

          // 2. Page Content
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _items.length,
                  // This keeps pages alive so animations don't reset
                  allowImplicitScrolling: true,
                  itemBuilder: (context, index) {
                    return OnboardingPageWidget(item: _items[index]);
                  },
                ),
              ),

              // 3. Bottom Controls (Restored Layout)
              _buildBottomControls(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNightSky(Size size) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double scrollOffset = 0;
        if (_pageController.hasClients &&
            _pageController.position.haveDimensions) {
          scrollOffset = _pageController.page ?? 0;
        }

        return Stack(
          children: [
            // Animated Gradient Nebula
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _nebulaController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          0.2 + sin(_nebulaController.value) * 0.2,
                          -0.4 + cos(_nebulaController.value) * 0.2,
                        ),
                        radius: 1.2,
                        colors: [Color(0xFF1A1F35), Colors.transparent],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Parallax Stars
            ..._stars.map((star) {
              double parallaxX =
                  (size.width * star.x) - (scrollOffset * 40 * star.depth);

              return Positioned(
                left: parallaxX,
                top: size.height * star.y,
                child: AnimatedBuilder(
                  animation: _starControllers[star.controllerIndex],
                  builder: (context, child) {
                    final val = _starControllers[star.controllerIndex].value;
                    final twinkle = 0.3 + (sin(val * pi) + 1) / 2 * 0.7;

                    return Opacity(
                      opacity: star.opacity * twinkle,
                      child: Container(
                        width: star.size,
                        height: star.size,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: star.size > 1.5
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.4),
                                    blurRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // --- RESTORED BUTTON LAYOUT ---
  Widget _buildBottomControls() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        int page = 0;
        if (_pageController.hasClients &&
            _pageController.position.haveDimensions) {
          page = _pageController.page?.round() ?? 0;
        }
        final isLast = page == _items.length - 1;
        final currentGradient = _items[page % _items.length].gradient;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
            child: Column(
              children: [
                // 1. Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_items.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == page ? 32 : 8,
                      height: 6,
                      decoration: BoxDecoration(
                        color: index == page
                            ? currentGradient.first
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: index == page
                            ? [
                                BoxShadow(
                                  color: currentGradient.first.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 30),

                // 2. Main Button
                GestureDetector(
                  onTap: isLast
                      ? _onGetStarted
                      : () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        ),
                  child: Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: currentGradient),
                      borderRadius: BorderRadius.circular(
                        28,
                      ), // Full pill shape
                      boxShadow: [
                        BoxShadow(
                          color: currentGradient.first.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          isLast ? "Get Started" : "Continue",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        // Shimmer Overlay
                        AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            return Positioned.fill(
                              child: FractionallySizedBox(
                                widthFactor: 0.5,
                                child: Transform.translate(
                                  offset: Offset(
                                    MediaQuery.of(context).size.width *
                                            _shimmerController.value *
                                            2 -
                                        200,
                                    0,
                                  ),
                                  child: Transform.rotate(
                                    angle: 0.5,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white24,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Skip Button (Restored)
                Opacity(
                  opacity: isLast ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: isLast,
                    child: TextButton(
                      onPressed: _onGetStarted,
                      child: Text(
                        "Skip for now",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==============================================================================
// SEPARATE WIDGET TO HANDLE PERSISTENT ANIMATION STATE
// ==============================================================================
class OnboardingPageWidget extends StatefulWidget {
  final OnboardingItem item;
  const OnboardingPageWidget({super.key, required this.item});

  @override
  State<OnboardingPageWidget> createState() => _OnboardingPageWidgetState();
}

class _OnboardingPageWidgetState extends State<OnboardingPageWidget>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(); // CONTINUOUS LOOP
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // THIS IS THE MAGIC KEY: Keeps the animation running even when scrolled partially away
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          _buildHeroIcon(),
          const SizedBox(height: 50),
          _buildText(),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildHeroIcon() {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Ambient Glow
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.item.gradient.first.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 2. Glassmorphic Container
          ClipRRect(
            borderRadius: BorderRadius.circular(120),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                ),
                child: _buildAnimationContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationContent() {
    // We use specific "Seamless Loops" here
    switch (widget.item.iconAnimation) {
      case IconAnimationType.scan:
        return _buildSeamlessScan();
      case IconAnimationType.text:
        return _buildSeamlessText();
      case IconAnimationType.cloud:
        return _buildSeamlessCloud();
    }
  }

  // --- SEAMLESS SCAN ANIMATION ---
  Widget _buildSeamlessScan() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Sawtooth wave 0 -> 1
        final t = _controller.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Document Outline
            Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30, width: 2),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (i) {
                  // Lines light up as scanner passes them
                  final linePos = (i + 1) / 4;
                  // Smooth fade in/out based on scanner distance
                  final dist = (t - linePos).abs();
                  final glow = (1.0 - (dist * 5)).clamp(0.0, 1.0);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        Colors.white24,
                        widget.item.gradient.first,
                        glow,
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: glow > 0.5
                          ? [
                              BoxShadow(
                                color: widget.item.gradient.first,
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),
            // Scanner Beam
            Positioned(
              top: 50 + (t * 140) - 20, // Moves continuously top to bottom
              child: Opacity(
                // Fade out at very top and very bottom for seamless look
                opacity:
                    1.0 -
                    (2 * (0.5 - t).abs() - 0.8).clamp(0.0, 1.0) *
                        5, // Complex fade logic
                child: Container(
                  width: 160,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        widget.item.gradient.first,
                        widget.item.gradient.last,
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.item.gradient.first,
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- SEAMLESS TEXT ANIMATION ---
  Widget _buildSeamlessText() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.image_outlined, size: 80, color: Colors.white12),
            ...List.generate(3, (i) {
              // Staggered Sine Waves
              // Each line has a different phase shift so they bob independently
              final t = _controller.value;
              final offset = i * (2 * pi / 3);
              final yShift = sin(t * 2 * pi + offset) * 8;
              final opacity = (sin(t * 2 * pi + offset) + 1) / 2 * 0.5 + 0.5;

              return Positioned(
                top: 100 + (i * 20.0) + yShift,
                left: 120 + (i % 2 == 0 ? 10.0 : -10.0), // Zigzag layout
                child: Container(
                  width: 60 + (i * 10.0),
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.item.gradient[i % 2].withOpacity(opacity),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: widget.item.gradient[i % 2].withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // --- SEAMLESS CLOUD ANIMATION ---
  Widget _buildSeamlessCloud() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Cloud Base
            Positioned(
              top: 70,
              child: Icon(Icons.cloud_queue, size: 80, color: Colors.white),
            ),
            // Flowing Data Dots
            ...List.generate(6, (i) {
              // Infinite flow logic
              final step = 1.0 / 6; // spacing
              final rawPos = (t + (i * step)) % 1.0; // 0 -> 1 loop

              // Path: Bottom (170) to Cloud (100)
              final yPos = 170 - (rawPos * 70);

              // Fade in at bottom, fade out entering cloud
              double opacity = 1.0;
              if (rawPos < 0.2) opacity = rawPos * 5;
              if (rawPos > 0.8) opacity = (1 - rawPos) * 5;

              // Gentle sway
              final xSway = sin(rawPos * pi * 4) * 5;

              return Positioned(
                top: yPos,
                left: 115 + xSway,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.item.gradient.last,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.item.gradient.first,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildText() {
    return Column(
      children: [
        Text(
          widget.item.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.item.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// MODELS

class Star {
  final double x;
  final double y;
  final double size;
  final double depth;
  final double opacity;
  final int controllerIndex;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.depth,
    required this.opacity,
    required this.controllerIndex,
  });
}

enum IconAnimationType { scan, text, cloud }

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final IconAnimationType iconAnimation;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.iconAnimation,
  });
}

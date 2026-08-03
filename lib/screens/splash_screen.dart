import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/web_helper.dart';
import 'signup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  double _progress = 0.0;
  Timer? _progressTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Remove the static web bootstrap splash overlay if we are on Web
    removeWebSplash();

    // 1. Set up the animations for fade-in and scale-in
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut), // 1.2s equivalent
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      // Custom ease out cubic/bezier approximation using Curves.easeOutCubic
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic), // 1.5s equivalent
    );

    _animationController.forward();

    // 2. Simulate loading progress non-linearly (every 30ms)
    _startProgressSimulation();
  }

  void _startProgressSimulation() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Non-linear speed to feel more natural/organic
      final double increment = _random.nextDouble() * 0.02; // Random increment up to 2%
      
      setState(() {
        _progress = (_progress + increment).clamp(0.0, 1.0);
      });

      if (_progress >= 1.0) {
        timer.cancel();
        _transitionToSignUp();
      }
    });
  }

  void _transitionToSignUp() {
    if (!mounted) return;
    
    // Premium transition: Fade out splash screen and fade in SignUp screen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SignUpScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }


  @override
  void dispose() {
    _animationController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsiveness (matching md breakpoint in tailwind = 768)
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 768;
    final double logoSize = isDesktop ? 256.0 : 192.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFFFFFFFF), // Center color
              Color(0xFFFCF8F9), // Edge vignette color
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo section with Fade & Scale Animation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    // Scale from 0.92 to 1.0
                    scale: 0.92 + (0.08 * _scaleAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: logoSize,
                  height: logoSize,
                  child: Image.asset(
                    'assets/images/splashscreen_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Graceful fallback if the asset is missing
                      return const Icon(
                        Icons.shield,
                        size: 96,
                        color: Color(0xFF301427),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 48), // mt-12 in tailwind spacing
              
              // Progress Bar Section
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 128, // w-32 in tailwind
                  height: 1.5, // h-[1px] subtle thin bar
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9999),
                    color: const Color(0xFF807479).withOpacity(0.3), // outline-variant/30
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _progress,
                      child: Container(
                        color: const Color(0xFF301427), // primary from theme config
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

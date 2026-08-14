import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'signup_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();

    super.dispose();
  }

  void _handleSignIn() {
    // Clear any previous error message
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulated API Call
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF301427),
          content: Text(
            'Signed in successfully! Welcome back.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );

      // Navigate to the DashboardScreen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Custom light theme configuration matching your exact CSS and Tailwind colors
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFCF8F9),
      primaryColor: const Color(0xFF301427),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF301427),
        brightness: Brightness.light,
        primary: const Color(0xFF301427),
        secondary: const Color(0xFF6C5963),
        surface: const Color(0xFFFCF8F9),
        onSurface: const Color(0xFF1B1B1C),
        outlineVariant: const Color(0xFFD1C3C9),
        outline: const Color(0xFF807479),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6F3F4), // bg-surface-container-low
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF301427), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
        ),
        prefixIconColor: const Color(0xFF807479),
        suffixIconColor: const Color(0xFF4E4449),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );

    return Theme(
      data: lightTheme,
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Background Subtle Atmospheric blur spheres
            Positioned(
              top: -150,
              right: -150,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF2D9E4).withOpacity(0.3), // secondary-container
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFCCE5FF).withOpacity(0.3), // tertiary-fixed
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 2. Main content scroll area
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Header Section
                        _buildHeader(),
                        const SizedBox(height: 16),

                        // Signin Form Card
                        _buildFormCard(),
                        const SizedBox(height: 16),

                        // Error Card displayed above social login buttons
                        _buildErrorCard(),

                        // Social Authentication Separator & Buttons
                        _buildSocialSection(),
                        const SizedBox(height: 24),

                        // Footer Navigation Links
                        _buildFooter(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Support Help FAB
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {},
                elevation: 3,
                backgroundColor: const Color(0xFF6C5963), // secondary
                shape: const CircleBorder(),
                mini: true,
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo Container
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD1C3C9).withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/images/app_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.shield,
              size: 32,
              color: Color(0xFF301427),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF301427), // primary
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sign in to continue your journey towards total security and peace of mind.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF4E4449), // on-surface-variant
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1C3C9).withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email Address Input
            const Text(
              'Email Address',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1B1C),
              ),
            ),
            const SizedBox(height: 4),
            _FocusScaleWrapper(
              focusNode: _emailFocus,
              child: TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Color(0xFF1B1B1C), fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.mail_outline, size: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),

            // Password Input
            const Text(
              'Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1B1C),
              ),
            ),
            const SizedBox(height: 4),
            _FocusScaleWrapper(
              focusNode: _passwordFocus,
              child: TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Color(0xFF1B1B1C), fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 18),

            // Sign In Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF301427),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBA1A1A).withOpacity(0.5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFBA1A1A),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFBA1A1A),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _errorMessage = null;
              });
            },
            child: const Icon(
              Icons.close,
              color: Color(0xFFBA1A1A),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialSection() {
    return Column(
      children: [
        // "Or continue with" divider
        Row(
          children: [
            const Expanded(
              child: Divider(color: Color(0xFFD1C3C9)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  fontSize: 10.5,
                  color: const Color(0xFF807479),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const Expanded(
              child: Divider(color: Color(0xFFD1C3C9)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Google button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD1C3C9)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://www.gstatic.com/images/branding/product/2x/gsa_android_64dp.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.g_mobiledata,
                    size: 20,
                    color: Color(0xFF4E4449),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Google',
                  style: TextStyle(
                    color: Color(0xFF4E4449),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(
            fontSize: 13.5,
            color: Color(0xFF4E4449),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const SignUpScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          },
          child: const Text(
            'Sign Up',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF301427),
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom widget to animate focus scaling (increases size by 1% on focus)
class _FocusScaleWrapper extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;
  const _FocusScaleWrapper({required this.focusNode, required this.child});

  @override
  State<_FocusScaleWrapper> createState() => _FocusScaleWrapperState();
}

class _FocusScaleWrapperState extends State<_FocusScaleWrapper> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isFocused ? 1.01 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: widget.child,
    );
  }
}

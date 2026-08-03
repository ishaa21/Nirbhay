import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    
    super.dispose();
  }

  void _handleSignUp() {
    // Clear any previous error message
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_agreeToTerms) {
      setState(() {
        _errorMessage = 'You must agree to the Terms of Service and Privacy Policy.';
      });
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

      // Special verification hook: type 'Error' to simulate an HTTP error card
      if (_nameController.text.trim().toLowerCase() == 'error') {
        setState(() {
          _errorMessage = 'Network request failed: The auth server took too long to respond. Please check your internet connection and try again.';
        });
        return;
      }

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF301427),
          content: Text(
            'Account created successfully! Redirecting...',
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // Ensures 50-54px field height
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
                    constraints: const BoxConstraints(maxWidth: 440), // Slightly narrower for a cleaner premium feel
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Header Section
                        _buildHeader(),
                        const SizedBox(height: 16), // Reduced gap to form

                        // Signup Form Card
                        _buildFormCard(),
                        const SizedBox(height: 16), // Reduced gap

                        // Error Card displayed above social login buttons
                        _buildErrorCard(),

                        // Social Authentication Separator & Buttons
                        _buildSocialSection(),
                        const SizedBox(height: 24), // Reduced spacing

                        // Footer Navigation Links
                        _buildFooter(),
                        const SizedBox(height: 12), // Buffer so it doesn't clip
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Support Help FAB (Optional addition for Safety context)
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
        // Logo Container (Slightly smaller, 64px instead of 80px)
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
        const SizedBox(height: 10), // Reduced gap
        const Text(
          'Join Nirbhay',
          style: TextStyle(
            fontSize: 24, // Slightly smaller and cleaner
            fontWeight: FontWeight.bold,
            color: Color(0xFF301427), // primary
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4), // Reduced gap
        const Text(
          'Create an account to start your journey towards total security and peace of mind.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13, // Slightly smaller for premium look
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
      padding: const EdgeInsets.all(16), // Reduced card padding
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full Name Input
            const Text(
              'Full Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1B1C),
              ),
            ),
            const SizedBox(height: 4), // Reduced label gap
            _FocusScaleWrapper(
              focusNode: _nameFocus,
              child: TextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                keyboardType: TextInputType.name,
                style: const TextStyle(color: Color(0xFF1B1B1C), fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full Name is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 10), // Reduced field spacing

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
                    return 'Email Address is required';
                  }
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 10),

            // Phone Number Input
            const Text(
              'Phone Number',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1B1C),
              ),
            ),
            const SizedBox(height: 4),
            _FocusScaleWrapper(
              focusNode: _phoneFocus,
              child: TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Color(0xFF1B1B1C), fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '+91 00000-00000',
                  prefixIcon: Icon(Icons.call_outlined, size: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 10),

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
                  hintText: 'Create a strong password',
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
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 10),

            // Terms Checkbox (More compact)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _agreeToTerms,
                    activeColor: const Color(0xFF301427),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      setState(() {
                        _agreeToTerms = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4E4449),
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms',
                          style: TextStyle(
                            color: Color(0xFF301427),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: Color(0xFF301427),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Create Account Submit Button (Reduced height to 48px)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
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
                        'Create Account',
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
        color: const Color(0xFFFFDAD6), // light red background from error-container
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
        // "Or sign up with" divider
        Row(
          children: [
            const Expanded(
              child: Divider(color: Color(0xFFD1C3C9)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR SIGN UP WITH',
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
        const SizedBox(height: 12), // Reduced gap

        // Google & Facebook buttons
        Row(
          children: [
            Expanded(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Google',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF4E4449),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Facebook_Logo_%282019%29.png/480px-Facebook_Logo_%282019%29.png',
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Facebook',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF4E4449),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 13.5,
          color: Color(0xFF4E4449),
        ),
        children: [
          TextSpan(text: 'Already have an account? '),
          TextSpan(
            text: 'Sign In',
            style: TextStyle(
              color: Color(0xFF301427),
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
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

import 'dart:convert';

import '../utils/theme_controller.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/push_token_service.dart';
import '../widgets/server_config_cog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  String? selectedUser;
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<Offset> _anyelSlideAnimation;
  late Animation<Offset> _alexisSlideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _anyelSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _alexisSlideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectUser(String user) {
    setState(() {
      selectedUser = user;
      _errorMessage = null;
    });
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeController.forward();
    });
  }

  void _back() {
    _fadeController.reverse();
    _slideController.reverse().then((_) {
      setState(() {
        selectedUser = null;
        _passwordController.clear();
        _errorMessage = null;
      });
    });
  }

  String _extractMessageFromText(String text) {
    final patterns = <RegExp>[
      RegExp(r'message\s*:\s*\\"([^\\"]+)\\"', caseSensitive: false),
      RegExp(r'message\s*:\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'message\s*:\s*([^,}\]]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)!.trim().replaceAll(r'\"', '"');
      }
    }

    return text;
  }

  String _extractErrorMessage(
    Object error, {
    String fallback = 'Error al iniciar sesión',
  }) {
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (raw.isEmpty) return fallback;

    final withoutPrefix = raw.replaceFirst(
      RegExp(r'^Login fallido:\s*', caseSensitive: false),
      '',
    );

    try {
      final decoded = jsonDecode(withoutPrefix);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message.trim();
        }
        final nestedError = decoded['error'];
        if (nestedError is String && nestedError.isNotEmpty) {
          final nestedMessage = _extractMessageFromText(nestedError);
          return nestedMessage == nestedError
              ? nestedError.trim()
              : nestedMessage.trim();
        }
      }
    } catch (_) {
      // Ignore JSON parsing errors and continue with text parsing.
    }

    final extracted = _extractMessageFromText(withoutPrefix);
    if (extracted.isNotEmpty) return extracted;
    return fallback;
  }

  Future<void> _login() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa tu contraseña';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.login(selectedUser!, _passwordController.text);
      await PushTokenService.instance.syncTokenWithBackend();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      }
    } catch (e) {
      final error = _extractErrorMessage(e);
      setState(() {
        _errorMessage = error.contains('Inicio de sesión fallido')
            ? 'Contraseña incorrecta'
            : error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeProvider.of(context);
    final isDark = themeController.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2d2640) : Colors.white;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1a1625), const Color(0xFF2d2640)]
                : [const Color(0xFFF5E6FF), const Color(0xFFE6D7FF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8),
                  child: ServerConfigCog(
                    iconColor: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Text(
                          '💕',
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Anyel x Alexis',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bienvenidos',
                        style: TextStyle(
                          fontSize: 18,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (selectedUser == null) ...[
                        Text(
                          '¿Quién eres?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildUserAvatar(
                                'anyel',
                                'assets/frog.png',
                                'Anyel',
                                const Color(0xFF90EE90),
                              ),
                              const SizedBox(width: 48),
                              _buildUserAvatar(
                                'alexis',
                                'assets/duck.png',
                                'Alexis',
                                const Color(0xFFFFD700),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        SlideTransition(
                          position: selectedUser == 'anyel'
                              ? _anyelSlideAnimation
                              : _alexisSlideAnimation,
                          child: Column(
                            children: [
                              Hero(
                                tag: 'avatar_$selectedUser',
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selectedUser == 'anyel'
                                        ? const Color(0xFF90EE90)
                                            .withValues(alpha: 0.3)
                                        : const Color(0xFFFFD700)
                                            .withValues(alpha: 0.3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: selectedUser == 'anyel'
                                            ? const Color(0xFF90EE90)
                                                .withValues(alpha: 0.5)
                                            : const Color(0xFFFFD700)
                                                .withValues(alpha: 0.5),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Image.asset(
                                        selectedUser == 'anyel'
                                            ? 'assets/frog.png'
                                            : 'assets/duck.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                selectedUser == 'anyel' ? 'Anyel' : 'Alexis',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  enabled: !_isLoading,
                                  style: TextStyle(color: textColor),
                                  onChanged: (_) {
                                    if (_errorMessage != null) {
                                      setState(() {
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Contraseña',
                                    hintStyle: TextStyle(
                                      color: textColor.withValues(alpha: 0.5),
                                    ),
                                    filled: true,
                                    fillColor: cardColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: textColor.withValues(alpha: 0.7),
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.remove_red_eye_outlined,
                                        color: textColor.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => _login(),
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _back,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: cardColor,
                                          foregroundColor: textColor,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Text(
                                          'Atrás',
                                          style: TextStyle(
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              selectedUser == 'anyel'
                                                  ? const Color(0xFF90EE90)
                                                  : const Color(0xFFFFD700),
                                          foregroundColor: Colors.black87,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Colors.black87,
                                                  ),
                                                ),
                                              )
                                            : const Text(
                                                'Entrar',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(
    String username,
    String imagePath,
    String name,
    Color color,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _selectUser(username),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Column(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Hero(
                  tag: 'avatar_$username',
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.3),
                      border: Border.all(
                        color: color,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ThemeProvider.of(context).isDark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

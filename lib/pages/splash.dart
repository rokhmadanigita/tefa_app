import 'package:flutter/material.dart';
import 'package:tefa_app/main.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _startWave = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _startWave = true;
        });

        _controller.forward().then((_) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const AuthCheck(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/banner/logo.png',
                    width: 160,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.blur_on_rounded, size: 100, color: Colors.blue),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "TEFA STORE",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_startWave)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ClipPath(
                  clipper: SoftWaveClipper(_controller.value),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomRight,
                        end: Alignment.topLeft,
                        colors: [
                          Color(0xFF1E3C72),
                          Color(0xFF2A5298),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class SoftWaveClipper extends CustomClipper<Path> {
  final double progress;
  SoftWaveClipper(this.progress);

  @override
  Path getClip(Size size) {
    Path path = Path();

    double move = progress * 1.6;

    path.moveTo(size.width, size.height);

    path.lineTo(size.width, size.height * (1 - move));

    path.cubicTo(
      size.width * 0.8, size.height * (1 - move * 1.2),
      size.width * 0.2, size.height * (1 - move * 0.8),
      size.width * (1 - move * 1.5), size.height,
    );

    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
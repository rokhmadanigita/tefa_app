import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool isLoading = false;

  bool isPasswordHidden = true;
  bool isConfirmPasswordHidden = true;

  final supabase = Supabase.instance.client;

  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  late AnimationController _controller;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  void toggleMode() {
    setState(() => isLogin = !isLogin);
  }

  String _getFriendlyErrorMessage(dynamic e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return "Email atau password salah. Silakan coba lagi.";
      } else if (msg.contains('user already exists')) {
        return "Email sudah terdaftar. Silakan gunakan email lain atau login.";
      } else if (msg.contains('email not confirmed')) {
        return "Email Anda belum dikonfirmasi. Cek kotak masuk email Anda.";
      } else if (msg.contains('password is too short')) {
        return "Password terlalu pendek, minimal harus 6 karakter.";
      } else if (msg.contains('invalid email')) {
        return "Format email tidak valid. Gunakan contoh: user@gmail.com";
      } else if (msg.contains('too many requests')) {
        return "Terlalu banyak mencoba. Tunggu sebentar lalu coba lagi.";
      } else if (msg.contains('network')) {
        return "Koneksi internet bermasalah. Periksa jaringan Anda.";
      }
      return e.message;
    }
    return "Terjadi kesalahan sistem. Silakan coba lagi nanti.";
  }

  Future<void> authenticate() async {
    final emailText = email.text.trim();
    final passwordText = password.text.trim();

    if (emailText.isEmpty || passwordText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password tidak boleh kosong")),
      );
      return;
    }

    if (!isLogin && passwordText != confirmPassword.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konfirmasi password tidak cocok")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: emailText,
          password: passwordText,
        );
      } else {
        await supabase.auth.signUp(
          email: emailText,
          password: passwordText,
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getFriendlyErrorMessage(e)),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 350,
              child: CustomPaint(
                painter: TopWavePainter(),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 280,
              child: CustomPaint(
                painter: BottomWavePainter(),
              ),
            ),
          ),

          const MovingEmoji(emoji: "🛒", top: 60, left: 30, duration: Duration(seconds: 2)),
          const MovingEmoji(emoji: "💻", top: 40, right: 80, duration: Duration(seconds: 3)),
          const MovingEmoji(emoji: "🔧", top: 100, right: 30, duration: Duration(seconds: 1), size: 25),
          const MovingEmoji(emoji: "🎓", top: 220, left: 20, duration: Duration(seconds: 1)),
          const MovingEmoji(emoji: "✨", top: 200, right: 40, duration: Duration(seconds: 1)),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: FadeTransition(
                opacity: fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    Text(
                      "TEFA",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        fontFamily: 'Serif',
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "STORE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        fontFamily: 'Serif',
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Inovasi Siswa untuk Masa Depan!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF6DA0B8),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 40),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Stack(
                              children: [
                                AnimatedAlign(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
                                  child: FractionallySizedBox(
                                    widthFactor: 0.5,
                                    child: Container(
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6DA0B8).withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () { if (!isLogin) toggleMode(); },
                                        behavior: HitTestBehavior.opaque,
                                        child: Center(
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 300),
                                            style: TextStyle(
                                              color: isLogin ? Colors.white : const Color(0xFF6DA0B8),
                                              fontWeight: FontWeight.bold,
                                            ),
                                            child: const Text("Log in"),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () { if (isLogin) toggleMode(); },
                                        behavior: HitTestBehavior.opaque,
                                        child: Center(
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 300),
                                            style: TextStyle(
                                              color: !isLogin ? Colors.white : const Color(0xFF6DA0B8),
                                              fontWeight: FontWeight.bold,
                                            ),
                                            child: const Text("Sign In"),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 35),
                          _buildShadowField(
                            controller: email,
                            hint: "Enter email or username",
                          ),
                          const SizedBox(height: 18),
                          _buildShadowField(
                            controller: password,
                            hint: "Password",
                            isPassword: true,
                            isHidden: isPasswordHidden,
                            onToggle: () => setState(() => isPasswordHidden = !isPasswordHidden),
                          ),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1.0,
                                  child: child,
                                ),
                              );
                            },
                            child: isLogin
                                ? const SizedBox.shrink(key: ValueKey('login_mode'))
                                : Column(
                                    key: const ValueKey('signup_mode'),
                                    children: [
                                      const SizedBox(height: 18),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                                        child: _buildShadowField(
                                          controller: confirmPassword,
                                          hint: "Confirm Password",
                                          isPassword: true,
                                          isHidden: isConfirmPasswordHidden,
                                          onToggle: () => setState(() => isConfirmPasswordHidden = !isConfirmPasswordHidden),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),

                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6DA0B8).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: isLoading ? null : authenticate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6DA0B8),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: Text(
                                          isLogin ? "Log in" : "Sign up",
                                          key: ValueKey(isLogin),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const HomePage()),
                              );
                            },
                            child: const Text(
                              "Lewati",
                              style: TextStyle(
                                color: Color(0xFF6DA0B8), 
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShadowField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool isHidden = false,
    VoidCallback? onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && isHidden,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility, color: Colors.grey[300], size: 18),
                  onPressed: onToggle,
                )
              : null,
        ),
      ),
    );
  }
}

class MovingEmoji extends StatefulWidget {
  final String emoji;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final Duration duration;
  final double size;

  const MovingEmoji({
    super.key, 
    required this.emoji, 
    this.top, 
    this.left, 
    this.right, 
    this.bottom, 
    required this.duration,
    this.size = 35,
  });

  @override
  State<MovingEmoji> createState() => _MovingEmojiState();
}

class _MovingEmojiState extends State<MovingEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
    _animation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 0.15)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      left: widget.left,
      right: widget.right,
      bottom: widget.bottom,
      child: SlideTransition(
        position: _animation,
        child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
      ),
    );
  }
}

class TopWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final gradient = const LinearGradient(
      colors: [Color(0xFF23447D), Color(0xFF6DA0B8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    paint.shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    Path path = Path();
    path.lineTo(0, size.height * 0.6);
    path.cubicTo(
      size.width * 0.2, size.height * 0.4,
      size.width * 0.4, size.height * 0.7,
      size.width * 0.6, size.height * 0.4,
    );
    path.cubicTo(
      size.width * 0.8, size.height * 0.1,
      size.width * 0.9, size.height * 0.35,
      size.width, size.height * 0.1,
    );
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final gradient = const LinearGradient(
      colors: [Color(0xFF6DA0B8), Color(0xFF23447D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    paint.shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    Path path = Path();
    path.moveTo(0, size.height * 0.95);
    path.cubicTo(
      size.width * 0.2, size.height * 0.75,
      size.width * 0.4, size.height * 0.95,
      size.width * 0.6, size.height * 0.7,
    );
    path.cubicTo(
      size.width * 0.8, size.height * 0.5,
      size.width * 0.9, size.height * 0.8,
      size.width, size.height * 0.45,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
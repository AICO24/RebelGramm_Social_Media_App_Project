import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// removed FontAwesome usage; keep imports minimal
import 'package:flutter_svg/flutter_svg.dart';

import '../services/auth_service.dart';
import '../screens/register_screen.dart';
import '../screens/home_screen.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  bool _obscurePassword = true;

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboard,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          border: InputBorder.none,
          suffixIcon: suffix,
        ),
      ),
    );
  }

  void login() async {
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    
    setState(() => loading = true);
    final auth = AuthService();
    try {
      final user = await auth.signIn(emailController.text, passwordController.text);
      if (user != null) {
        if (!mounted) return;
        final provider = Provider.of<UserProvider>(context, listen: false);
        provider.setUser(user);
        provider.startListening(user.id);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFF121212)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                children: [
                  // logo (app brand)
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF833AB4),
                          Color(0xFFE1306C),
                          Color(0xFFF56040),
                          Color(0xFFF77737),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0,4)),
                      ],
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/images/rebelgram-icon.svg',
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),

                  SizedBox(height: 32),

                  // card for inputs
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0,6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // username
                        _buildInputField(
                          controller: emailController,
                          hint: 'Phone, username or email',
                          obscure: false,
                          keyboard: TextInputType.emailAddress,
                        ),
                        SizedBox(height: 16),
                        // password
                        _buildInputField(
                          controller: passwordController,
                          hint: 'Password',
                          obscure: _obscurePassword,
                          suffix: GestureDetector(
                            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                            child: Text(
                              _obscurePassword ? 'Show' : 'Hide',
                              style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        // login button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: loading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0095F6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: loading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(color: Colors.white70)),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: Text('Sign up', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

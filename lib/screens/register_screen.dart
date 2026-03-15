import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// removed FontAwesome usage; keep imports minimal
import 'package:flutter_svg/flutter_svg.dart';

import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import '../providers/user_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController fullnameController = TextEditingController();
  bool loading = false;
  bool _obscurePassword = true;

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboard,
    IconData? prefixIcon,
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
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey[500], size: 20) : null,
          suffixIcon: suffix,
        ),
      ),
    );
  }

  void register() async {
    if (emailController.text.trim().isEmpty || 
        passwordController.text.isEmpty || 
        usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }
    
    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    
    setState(() => loading = true);
    final auth = AuthService();
    try {
      final user = await auth.signUp(
        emailController.text, 
        passwordController.text, 
        usernameController.text,
      );
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
          content: Text('Register failed: $e'),
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
                    width: 80,
                    height: 80,
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
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // card
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0,6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Create account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                        SizedBox(height: 8),
                        Text("Let's set up your account", style: TextStyle(color: Colors.white70)),
                        SizedBox(height: 24),
                        _buildInputField(controller: usernameController, hint: 'Username', prefixIcon: Icons.alternate_email),
                        SizedBox(height: 16),
                        _buildInputField(controller: fullnameController, hint: 'Full Name', prefixIcon: Icons.person_outline),
                        SizedBox(height: 16),
                        _buildInputField(controller: emailController, hint: 'Email', keyboard: TextInputType.emailAddress, prefixIcon: Icons.email_outlined),
                        SizedBox(height: 16),
                        _buildInputField(
                          controller: passwordController,
                          hint: 'Password',
                          obscure: _obscurePassword,
                          prefixIcon: Icons.lock_outline,
                          suffix: GestureDetector(
                            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                            child: Text(_obscurePassword ? 'Show' : 'Hide', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600)),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'By signing up, you agree to our Terms, Privacy Policy and Cookies Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: loading ? null : register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0095F6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: loading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text('Sign up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Have an account? ', style: TextStyle(color: Colors.white70)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('Log in', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600)),
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


import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/gradient_button.dart';
import 'enter_pin_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),

          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // TOP HEADER
                Row(
                  children: [
                    Image.asset(
                      "assets/images/logo.JPG",
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(width: 10),

                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DATASHIELD",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          "Secure Mobile Data & Management System",
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),

                // CENTER LOGIN CONTENT
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const Text(
                            "Welcome Back",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            "Login to continue",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 40),

                          CustomTextField(
                            controller: emailController,
                            hintText: "Email Address",
                            prefixIcon: Icons.email,
                            keyboardType: TextInputType.emailAddress,

                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Email is required";
                              }

                              final emailRegex = RegExp(
                                r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$',
                              );

                              if (!emailRegex.hasMatch(value.trim())) {
                                return "Enter a valid email";
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          CustomTextField(
                            controller: passwordController,
                            hintText: "Password",
                            prefixIcon: Icons.lock,
                            obscureText: hidePassword,

                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Password is required";
                              }
                              return null;
                            },

                            suffixIcon: IconButton(
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white,
                              ),

                              onPressed: () {
                                setState(() {
                                  hidePassword = !hidePassword;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 35),

                          GradientButton(
                            text: "Login",

                            onPressed: () {
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EnterPinScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 25),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              const Text(
                                "Don't have an account?",
                                style: TextStyle(color: Colors.white70),
                              ),

                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  );
                                },

                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    color: Colors.pinkAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

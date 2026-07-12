import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/custom_textfield.dart';

import 'create_pin_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService authService = AuthService();

  final TextEditingController nameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool hidePassword = true;

  bool hideConfirmPassword = true;

  bool isStrongPassword(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$',
    );

    return regex.hasMatch(password);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 15),

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

                const SizedBox(height: 35),

                const Text(
                  "Sign Up",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Create your account",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const SizedBox(height: 35),

                CustomTextField(
                  controller: nameController,
                  hintText: "Full Name",
                  prefixIcon: Icons.person,

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Full name is required";
                    }

                    if (value.trim().length < 3) {
                      return "Enter a valid name";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 15),

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

                const SizedBox(height: 15),

                CustomTextField(
                  controller: passwordController,
                  hintText: "Password",
                  prefixIcon: Icons.lock,
                  obscureText: hidePassword,

                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Password is required";
                    }

                    if (value.length < 8) {
                      return "Password must be at least 8 characters";
                    }

                    return null;
                  },

                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 15),

                CustomTextField(
                  controller: confirmPasswordController,
                  hintText: "Confirm Password",
                  prefixIcon: Icons.lock_outline,
                  obscureText: hideConfirmPassword,

                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please confirm your password";
                    }

                    if (value != passwordController.text) {
                      return "Passwords do not match";
                    }

                    return null;
                  },

                  suffixIcon: IconButton(
                    icon: Icon(
                      hideConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        hideConfirmPassword = !hideConfirmPassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 25),

                const SizedBox(height: 30),

                GradientButton(
                  text: "Create Account",
                  onPressed: () async {
                    // Validate all form fields
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }

                    bool success = await authService.signup(
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                      password: passwordController.text,
                    );

                    if (!mounted) return;

                    if (success) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreatePinScreen(),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Unable to create account."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account?",
                      style: TextStyle(color: Colors.white70),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: Colors.pinkAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

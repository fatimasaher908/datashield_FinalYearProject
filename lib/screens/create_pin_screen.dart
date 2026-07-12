import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'verify_pin_screen.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String pin = "";

  void addDigit(String digit) {
    if (pin.length < 6) {
      setState(() {
        pin += digit;
      });

      if (pin.length == 6) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => VerifyPinScreen(pin: pin)),
          );
        });
      }
    }
  }

  void deleteDigit() {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
      });
    }
  }

  Widget buildPinCircle(int index) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: index < pin.length ? Colors.white : Colors.transparent,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  Widget numberButton(String number) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => addDigit(number),
      child: Container(
        width: 82,
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget keypadRow(String first, String second, String third) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          numberButton(first),
          numberButton(second),
          numberButton(third),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            children: [
              const SizedBox(height: 15),

              Row(
                children: [
                  Image.asset("assets/images/logo.JPG", width: 42, height: 42),

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
                "Create PIN",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Create your 6-digit security PIN",
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) => buildPinCircle(index)),
              ),

              const SizedBox(height: 40),

              keypadRow("1", "2", "3"),
              keypadRow("4", "5", "6"),
              keypadRow("7", "8", "9"),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 82, height: 62),

                  numberButton("0"),

                  const SizedBox(width: 82, height: 62),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: deleteDigit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.backspace_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "Delete",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              const Text(
                "Your PIN will be securely saved after verification.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xff2D1458);

  static const Color card = Color(0xff4B2C82);

  static const Color cardDark = Color(0xff40246F);

  static const Color lightPurple = Color(0xff7252C8);

  static const Color pink = Color(0xffFF5AA8);

  static const Color blue = Color(0xff48C6EF);

  static const Color white = Colors.white;

  static const Color grey = Color(0xffC9C9C9);
  static const Color cyan = Color(0xFF67E8F9);
  static const Color textField = Color(0xff5B3B96);

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [blue, pink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xff56338F), Color(0xff6D45B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
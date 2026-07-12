import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

void main() {

  WidgetsFlutterBinding.ensureInitialized();

  runApp(const DataShieldApp());

}


class DataShieldApp extends StatelessWidget {

  const DataShieldApp({super.key});


  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'DataShield',

      home: const SplashScreen(),

    );

  }

}
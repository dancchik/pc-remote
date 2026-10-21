import 'package:flutter/material.dart';

import 'screens/pc_list_screen.dart';

void main() {
  runApp(const PcRemoteApp());
}

class PcRemoteApp extends StatelessWidget {
  const PcRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PC Remote',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      home: const PcListScreen(),
    );
  }
}

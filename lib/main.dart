import 'package:flutter/material.dart';
import 'map_page.dart';

void main() {
  runApp(const FaithMapApp());
}

class FaithMapApp extends StatelessWidget {
  const FaithMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FaithMap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A4B7D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A4B7D),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}

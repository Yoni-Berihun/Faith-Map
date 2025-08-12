import 'package:flutter/material.dart';
import 'map_page.dart';  // Make sure this path is correct based on your project structure

void main() {
	runApp(const MyApp());
}

class MyApp extends StatelessWidget {
	const MyApp({super.key});

	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			debugShowCheckedModeBanner: false,
			title: 'Faith Map',
			theme: ThemeData(
				primarySwatch: Colors.blue,
			),
			home: const MapPage(),
		);
	}
}

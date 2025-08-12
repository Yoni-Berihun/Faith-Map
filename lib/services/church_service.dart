import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class ChurchService {
  static Future<List<Map<String, dynamic>>> loadProtestantChurches() async {
    try {
       print("1. Trying to load JSON file...");
      final jsonString = await rootBundle.loadString('assets/data/churches.json');
      print("2. File loaded successfully!");
      return List<Map<String, dynamic>>.from(json.decode(jsonString));
      
    } catch (e) {
      debugPrint('Error loading churches: $e');
      return [];
    }
  }

  static LatLng getChurchLocation(Map<String, dynamic> church) {
    return LatLng(
      church['latitude']?.toDouble() ?? 0.0,
      church['longitude']?.toDouble() ?? 0.0,
    );
  }
  
  static void debugPrint(String s) {}
}
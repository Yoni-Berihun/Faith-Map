// lib/services/location_service.dart
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();

  // Check if location services are enabled
  Future<bool> _isLocationEnabled() async {
    return await _location.serviceEnabled();
  }

  // Request permission and get current location
  Future<LatLng?> getCurrentLocation() async {
    if (!await _isLocationEnabled()) {
      await _location.requestService();  // Enable location services
    }

    final permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      await _location.requestPermission();  // Request location permission
    }

    final locationData = await _location.getLocation();
    return LatLng(locationData.latitude!, locationData.longitude!);
  }
}
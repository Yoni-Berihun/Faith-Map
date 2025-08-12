import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:location/location.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

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

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  LatLng? _userLocation;
  List<Map<String, dynamic>> _churches = [];
  bool _isLoading = true;
  bool _locationError = false;
  final List<AnimationController> _pulseControllers = [];
  final Distance _distanceCalculator = Distance();
  final MapController _mapController = MapController();
  final Location _locationService = Location();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _churches = [];
      _pulseControllers.clear();
    });

    try {
      await Future.wait([_loadChurchData(), _getUserLocation()]);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _locationError = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChurchData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/churches.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      setState(() {
        _churches = jsonList.map((church) => church as Map<String, dynamic>).toList();
        
        // Initialize animation controllers
        for (var _ in _churches) {
          _pulseControllers.add(
            AnimationController(
              vsync: this,
              duration: const Duration(seconds: 2),
            )..repeat(reverse: true),
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading churches: $e');
      setState(() => _churches = []);
    }
  }

  Future<void> _getUserLocation() async {
    try {
      // Check if location service is enabled
      if (!await _locationService.serviceEnabled()) {
        await _locationService.requestService();
      }

      // Check permissions
      var permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
      }

      if (permission == PermissionStatus.granted) {
        final locationData = await _locationService.getLocation();
        setState(() {
          _userLocation = LatLng(locationData.latitude!, locationData.longitude!);
          _locationError = false;
        });
        _mapController.move(_userLocation!, 14.0);
      } else {
        throw Exception('Location permission denied');
      }
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        _locationError = true;
        _userLocation = const LatLng(9.0300, 38.7600); // Default to Addis Ababa
      });
    }
  }

  void _showChurchDetails(Map<String, dynamic> church) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChurchDetailsCard(
        church: church,
        userLocation: _userLocation,
        distanceCalculator: _distanceCalculator,
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _pulseControllers) {
      controller.dispose();
    }
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FaithMap"),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _userLocation ?? const LatLng(9.145, 40.4897),
              zoom: _userLocation != null ? 14.0 : 6.0,
              onTap: (_, tapPosition) {
                for (var church in _churches) {
                  final churchPos = LatLng(
                    church['latitude']?.toDouble() ?? 0,
                    church['longitude']?.toDouble() ?? 0,
                  );
                  if (_distanceCalculator.as(
                        LengthUnit.Meter, 
                        tapPosition, 
                        churchPos,
                      ) < 100) {
                    _showChurchDetails(church);
                    break;
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.faithmap',
              ),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      builder: (ctx) => Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.location_pin,
                            color: _locationError ? Colors.orange : Colors.blue,
                            size: 40,
                          ),
                          if (_locationError)
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: List<Marker>.generate(_churches.length, (index) {
                  final church = _churches[index];
                  return Marker(
                    point: LatLng(
                      church['latitude']?.toDouble() ?? 0,
                      church['longitude']?.toDouble() ?? 0,
                    ),
                    width: 60,
                    height: 60,
                    builder: (ctx) => GestureDetector(
                      onTap: () => _showChurchDetails(church),
                      child: _PulsingChurchMarker(
                        controller: _pulseControllers[index],
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_locationError)
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Using approximate location. Ensure GPS is enabled for accurate positioning.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _loadData,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.refresh),
            mini: true,
            tooltip: 'Refresh Map',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _getUserLocation,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}

class _PulsingChurchMarker extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _PulsingChurchMarker({
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, child) {
        return Transform.scale(
          scale: 0.8 + (controller.value * 0.4),
          child: Icon(
            PhosphorIcons.church(PhosphorIconsStyle.fill),
            color: color.withOpacity(0.8 + (controller.value * 0.2)),
            size: 32,
          ),
        );
      },
    );
  }
}

class _ChurchDetailsCard extends StatefulWidget {
  final Map<String, dynamic> church;
  final LatLng? userLocation;
  final Distance distanceCalculator;

  const _ChurchDetailsCard({
    required this.church,
    this.userLocation,
    required this.distanceCalculator,
  });

  @override
  State<_ChurchDetailsCard> createState() => __ChurchDetailsCardState();
}

class __ChurchDetailsCardState extends State<_ChurchDetailsCard> {
  int _currentPage = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  String _calculateDistance() {
    if (widget.userLocation == null) return 'Distance unknown';
    
    final churchLoc = LatLng(
      widget.church['latitude']?.toDouble() ?? 0,
      widget.church['longitude']?.toDouble() ?? 0,
    );
    
    final distance = widget.distanceCalculator.as(LengthUnit.Meter, widget.userLocation!, churchLoc);
    return '${(distance / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final images = (widget.church['images'] as List?)?.whereType<String>().toList() ?? [];
    final serviceTimes = (widget.church['serviceTimes'] as List?)?.whereType<String>().toList() ?? [];

    return GestureDetector(
      onTap: () {}, // Prevent dismiss when tapping inside
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8, // Limit height to 80% of screen
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image carousel
                        if (images.isNotEmpty)
                          _buildImageCarousel(context, images)
                        else
                          _buildImagePlaceholder(context),
                        
                        const SizedBox(height: 20),
                        
                        // Church name
                        Text(
                          widget.church['name'] ?? 'Unknown Church',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Details grid
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildDetailCard(
                              context,
                              icon: Icons.person,
                              title: 'Pastor',
                              value: widget.church['pastor'] ?? 'Not specified',
                            ),
                            if (widget.church['pastorPhone'] != null)
                              InkWell(
                                onTap: () => launchUrl(Uri.parse('tel:${widget.church['pastorPhone']}')),
                                child: _buildDetailCard(
                                  context,
                                  icon: Icons.phone,
                                  title: 'Contact',
                                  value: widget.church['pastorPhone'],
                                  isClickable: true,
                                ),
                              ),
                            _buildDetailCard(
                              context,
                              icon: Icons.local_parking,
                              title: 'Parking',
                              value: widget.church['hasParking'] == true ? 'Available' : 'Limited',
                            ),
                            _buildDetailCard(
                              context,
                              icon: Icons.language,
                              title: 'Language',
                              value: widget.church['language'] ?? 'Amharic',
                            ),
                            _buildDetailCard(
                              context,
                              icon: Icons.location_on,
                              title: 'Distance',
                              value: _calculateDistance(),
                            ),
                            _buildDetailCard(
                              context,
                              icon: Icons.directions,
                              title: 'Directions',
                              value: widget.church['directionDescription'] ?? '',
                            ),
                          ],
                        ),
                        
                        // Service times section
                        const SizedBox(height: 24),
                        Text(
                          'Service Schedule',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        ...serviceTimes.map((time) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle, size: 8),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  time,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        )),
                        
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(BuildContext context, List<String> images) {
    return Column(
      children: [
        CarouselSlider(
          items: images.map((url) => ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildImagePlaceholder(context),
            ),
          )).toList(),
          options: CarouselOptions(
            height: 200,
            aspectRatio: 16/9,
            viewportFraction: 0.9,
            enableInfiniteScroll: images.length > 1,
            autoPlay: images.length > 1,
            enlargeCenterPage: true,
            onPageChanged: (index, reason) {
              setState(() {
                _currentPage = index;
              });
            },
          ),
          carouselController: _carouselController,
        ),
        if (images.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: images.asMap().entries.map((entry) {
              return GestureDetector(
                onTap: () => _carouselController.animateTo(entry.key),
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary
                        .withOpacity(_currentPage == entry.key ? 0.9 : 0.4),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Icon(
          Icons.church,
          size: 60,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    bool isClickable = false,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClickable
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value.isNotEmpty ? value : '--',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

extension on CarouselSliderController {
  void animateTo(int key) {}
}
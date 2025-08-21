
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'; // Added for debugPrint

class ChurchSearchState extends ChangeNotifier {
  String _searchQuery = '';
  List<Map<String, dynamic>> _allChurches = [];
  List<Map<String, dynamic>> _filteredChurches = [];
  bool _isSearching = false;

  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get filteredChurches => _filteredChurches;
  bool get isSearching => _isSearching;

  void updateSearchQuery(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _applyFilters();
      _isSearching = false;
      notifyListeners();
    } else {
      _isSearching = true;
      notifyListeners();
      
      // Simulate search delay for better UX
      Future.delayed(const Duration(milliseconds: 500), () {
        _applyFilters();
        _isSearching = false;
        notifyListeners();
      });
    }
  }

  void setAllChurches(List<Map<String, dynamic>> churches) {
    _allChurches = List.from(churches);
    _applyFilters();
  }

  void _applyFilters() {
    _filteredChurches = _allChurches.where((church) {
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final name = (church['name'] ?? '').toString().toLowerCase();
        final leader = (church['churchLeader'] ?? '').toString().toLowerCase();
        final direction = (church['directionDescription'] ?? '')
            .toString()
            .toLowerCase();
        final language = (church['language'] ?? '').toString().toLowerCase();

        if (!name.contains(searchLower) &&
            !leader.contains(searchLower) &&
            !direction.contains(searchLower) &&
            !language.contains(searchLower)) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  LatLng? _userLocation;
  bool _isLoading = true;
  bool _locationError = false;
  AnimationController? _pulseController;
  final MapController _mapController = MapController();
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  double _currentZoom = 6.0;
  bool _isSatelliteView = false;
  bool _showOnboarding = false;

  final ChurchSearchState _searchState = ChurchSearchState();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _searchState.addListener(_onSearchStateChanged);
    _checkFirstTime();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
  bool serviceEnabled;
  LocationPermission permission;
  // Check if location services are enabled
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    await Geolocator.openLocationSettings();
    return;
  }
  // Check for permission status
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // User denied permissions permanently
      return;
    }
  }
  if (permission == LocationPermission.deniedForever) {
    // Open app settings so user can manually enable
    await Geolocator.openAppSettings();
    return;
  }
  // If permission is granted, fetch current location
  _getUserLocation();
}

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTime') ?? true;
    if (isFirstTime) {
      setState(() {
        _showOnboarding = true;
      });
    } else {
      _loadData();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    setState(() {
      _showOnboarding = false;
    });
    _loadData();
  }

  void _onSearchStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchState.removeListener(_onSearchStateChanged);
    _searchState.dispose();
    _pulseController?.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
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
      final jsonString = await rootBundle.loadString(
        'assets/data/churches.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);
      final churches = jsonList
          .map((church) => church as Map<String, dynamic>)
          .toList();

      _searchState.setAllChurches(churches);
    } catch (e) {
      debugPrint('Error loading churches: $e');
      _searchState.setAllChurches([]);
    }
  }

  Future<void> _getUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _userLocation = LatLng(
          position.latitude,
          position.longitude,
        );
        _locationError = false;
      });
      _mapController.move(_userLocation!, 14.0);
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        _locationError = true;
        _userLocation = const LatLng(9.0300, 38.7600);
      });
    }
  }

  void _showChurchDetails(Map<String, dynamic> church) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _ChurchDetailsCard(church: church, userLocation: _userLocation),
    );
  }

  void _toggleSatelliteView() {
    setState(() {
      _isSatelliteView = !_isSatelliteView;
    });
  }

  List<Marker> _getVisibleMarkers() {
    final churches = _searchState.filteredChurches;
    return List<Marker>.generate(churches.length, (index) {
      final church = churches[index];
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
            controller: _pulseController!,
            color: const Color(0xFF2196F3),
          ),
        ),
      );
    });
  }

  Widget _buildSearchIndicator() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _searchState.isSearching
            ? Container(
                key: const Key('search_indicator'),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Searching churches...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(key: Key('empty_search_indicator')),
      ),
    );
  }

  Widget _buildNoResultsFound() {
    final showNoResults = _searchState.searchQuery.isNotEmpty &&
        _searchState.filteredChurches.isEmpty &&
        !_searchState.isSearching;

    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: showNoResults
              ? Container(
                  key: const Key('no_results'),
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No churches found',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try different search terms or check your spelling',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          _searchController.clear();
                          _searchState.updateSearchQuery('');
                        },
                        child: const Text('Clear Search'),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: Key('has_results')),
        ),
      ),
    );
  }

  Widget _buildMapContent() {
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: ListenableBuilder(
              listenable: _searchState,
              builder: (context, child) {
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search churches, leaders, languages, or directions...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchState.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              if (mounted) {
                                _searchState.updateSearchQuery('');
                              }
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onChanged: (value) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        if (mounted) {
                          _searchState.updateSearchQuery(value);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _userLocation ?? const LatLng(9.145, 40.4897),
                    zoom: _userLocation != null ? 14.0 : 6.0,
                    minZoom:3,
                    maxZoom:19,
                    bounds:LatLngBounds(const LatLng(-35, -180), const LatLng(85, 180)),
                    boundsOptions:const FitBoundsOptions(padding: EdgeInsets.all(20)),
                    onMapEvent: (event) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _currentZoom != event.zoom) {
                          setState(() => _currentZoom = event.zoom);
                        }
                      });
                    },
                  ),
                  children: [
                    _isSatelliteView
                        ? TileLayer(
                            urlTemplate:
                                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                            userAgentPackageName: 'com.example.faithmap',
                            maxZoom:20,
                            maxNativeZoom:19,
                            subdomains: ['a', 'b', 'c'],
                          )
                        : TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.faithmap',
                            maxZoom:20,
                            maxNativeZoom:19,
                          ),
                    
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            builder: (ctx) => Icon(
                              Icons.location_pin,
                              color: _locationError
                                  ? Colors.orange
                                  : const Color.fromARGB(255, 8, 98, 171),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ListenableBuilder(
                      listenable: _searchState,
                      builder: (context, child) {
                        return MarkerClusterLayerWidget(
                          options: MarkerClusterLayerOptions(
                            markers: _getVisibleMarkers(),
                            builder: (context, markers) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    markers.length.toString(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            },
                            maxClusterRadius: 80,
                            size: const Size(40, 40),
                            fitBoundsOptions: const FitBoundsOptions(
                              padding: EdgeInsets.all(50),
                              maxZoom: 15,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                // Loading indicator for initial load
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                
                // Search in progress indicator
                _buildSearchIndicator(),
                
                // No results found message
                _buildNoResultsFound(),
                
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
                
                // View mode indicator
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isSatelliteView ? 'Satellite View' : 'Map View',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _toggleSatelliteView,
            backgroundColor: _isSatelliteView
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            mini: true,
            heroTag: 'satellite_fab',
            child: Icon(_isSatelliteView ? Icons.map : Icons.satellite),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _getUserLocation,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            heroTag: 'location_fab',
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    } else {
      return _buildMapContent();
    }
  }
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildSlide(
                    imagePath: 'assets/images/Slide_1.png',
                    title: '',
                    description: 'Discover churches near you with ease.',
                  ),
                  _buildSlide(
                    imagePath: 'assets/images/Slide_2.png',
                    title: '',
                    description: 'Search by church name, leader, language, or directions.',
                  ),
                  _buildSlide(
                    imagePath: 'assets/images/Slide_3.png',
                    title: '',
                    description: 'Get service times, contact details, and more.',
                  ),
                ],
              ),
            ),
            _buildPageIndicator(),
            const SizedBox(height: 20),
            if (_currentPage == 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: FilledButton(
                  onPressed: widget.onComplete,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Let\'s Goooo'),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({
    required String imagePath,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: double.infinity,
            fit: BoxFit.contain,  
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.4),
          ),
        );
      }),
    );
  }
}
// ... Keep the rest of your existing _PulsingChurchMarker and _ChurchDetailsCard classes unchanged ...

class _PulsingChurchMarker extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _PulsingChurchMarker({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, child) {
        return Transform.scale(
          scale: 0.8 + (controller.value * 0.4),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2 + (controller.value * 0.1)),
                  blurRadius: 4 + (controller.value * 2),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              PhosphorIcons.church(PhosphorIconsStyle.fill),
              color: color.withOpacity(0.8 + (controller.value * 0.2)),
              size: 32,
            ),
          ),
        );
      },
    );
  }
}

class _ChurchDetailsCard extends StatefulWidget {
  final Map<String, dynamic> church;
  final LatLng? userLocation;

  const _ChurchDetailsCard({required this.church, this.userLocation});

  @override
  __ChurchDetailsCardState createState() => __ChurchDetailsCardState();
}

class __ChurchDetailsCardState extends State<_ChurchDetailsCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    final images = (widget.church['images'] as List?)?.whereType<String>().toList() ?? [];
    if (images.length > 1) {
      _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_pageController.hasClients) {
          final nextPage = (_currentPage + 1) % images.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Widget _buildImageGallery(BuildContext context) {
    final images = (widget.church['images'] as List?)?.whereType<String>().toList() ?? [];
    
    if (images.isEmpty) {
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

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _buildImageWidget(images[index]),
                ),
              );
            },
          ),
        ),
        if (images.length > 1) 
          const SizedBox(height: 12),
        if (images.length > 1)
          _buildPageIndicator(images.length),
      ],
    );
  }

  Widget _buildPageIndicator(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.4),
          ),
        );
      }),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    final images = (widget.church['images'] as List?)?.whereType<String>().toList() ?? [];
    
    return GestureDetector(
      onTap: () {
        if (images.length > 1) {
          _autoSlideTimer?.cancel();
          _startAutoSlide();
        }
      },
      child: Stack(
        children: [
          if (imageUrl.startsWith('http'))
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorPlaceholder();
              },
            )
          else if (imageUrl.startsWith('assets/'))
            Image.asset(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorPlaceholder();
              },
            )
          else
            _buildErrorPlaceholder(),
          
          if (images.length > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentPage + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 40,
        ),
      ),
    );
  }

  String _getLeaderTitle(String? titleType) {
    switch (titleType) {
      case 'priest':
        return 'Priest';
      case 'minister':
        return 'Minister';
      case 'reverend':
        return 'Reverend';
      case 'bishop':
        return 'Bishop';
      case 'elder':
        return 'Elder';
      default:
        return 'Church Leader'; // Generic term as fallback
    }
  }

  String _calculateDistance() {
    if (widget.userLocation == null) return 'Distance unknown';

    final churchLoc = LatLng(
      widget.church['latitude']?.toDouble() ?? 0,
      widget.church['longitude']?.toDouble() ?? 0,
    );

    if (churchLoc.latitude == 0 || churchLoc.longitude == 0) {
      return 'Location unavailable';
    }

    final distance = const Distance().as(LengthUnit.Meter, widget.userLocation!, churchLoc);
    return '${(distance / 1000).toStringAsFixed(1)} km away';
  }

  String _calculateEstimatedTravelTime() {
    if (widget.userLocation == null) return '';

    final churchLoc = LatLng(
      widget.church['latitude']?.toDouble() ?? 0,
      widget.church['longitude']?.toDouble() ?? 0,
    );

    if (churchLoc.latitude == 0 || churchLoc.longitude == 0) {
      return '';
    }

    final distanceMeters = const Distance().as(LengthUnit.Meter, widget.userLocation!, churchLoc);
    final distanceKm = distanceMeters / 1000;
    // Assume average driving speed of 40 km/h for urban areas in Ethiopia (adjustable)
    const averageSpeedKmh = 40.0;
    final estimatedMinutes = (distanceKm / averageSpeedKmh) * 60;
    if (estimatedMinutes < 1) {
      return 'Less than 1 min (approx.)';
    } else {
      return '~${estimatedMinutes.toStringAsFixed(0)} min by car (approx. straight-line)';
    }
  }

  bool get _hasValidLocation {
    final lat = widget.church['latitude']?.toDouble() ?? 0;
    final long = widget.church['longitude']?.toDouble() ?? 0;
    return widget.userLocation != null && lat != 0 && long != 0;
  }

  Future<void> _launchDirections() async {
    if (!_hasValidLocation) return;

    final userLat = widget.userLocation!.latitude;
    final userLong = widget.userLocation!.longitude;
    final churchLat = widget.church['latitude'].toDouble();
    final churchLong = widget.church['longitude'].toDouble();

    Uri uri;
    if (Platform.isIOS) {
      final googleUri = Uri.parse(
        'comgooglemaps://?saddr=$userLat,$userLong&daddr=$churchLat,$churchLong&directionsmode=driving',
      );
      if (await canLaunchUrl(googleUri)) {
        uri = googleUri;
      } else {
        uri = Uri.parse(
          'http://maps.apple.com/?saddr=$userLat,$userLong&daddr=$churchLat,$churchLong&dirflg=d',
        );
      }
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$userLat,$userLong&destination=$churchLat,$churchLong&travelmode=driving',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch maps app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceTimes =
        (widget.church['serviceTimes'] as List?)?.whereType<String>().toList() ?? [];
    final estTravelTime = _calculateEstimatedTravelTime();

    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
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
                        _buildImageGallery(context),
                        
                        const SizedBox(height: 20),
                        Text(
                          widget.church['name'] ?? 'Unknown Church',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildDetailCard(
                              context,
                              icon: Icons.person,
                              title: _getLeaderTitle(widget.church['leaderTitle']),
                              value: widget.church['churchLeader'] ?? 'Not specified',
                            ),
                            if (widget.church['leaderPhone'] != null && widget.church['leaderPhone'] != 'N/A')
                              InkWell(
                                onTap: () => launchUrl(
                                  Uri.parse('tel:${widget.church['leaderPhone']}'),
                                ),
                                child: _buildDetailCard(
                                  context,
                                  icon: Icons.phone,
                                  title: 'Contact',
                                  value: widget.church['leaderPhone'],
                                  isClickable: true,
                                ),
                              ),
                            _buildDetailCard(
                              context,
                              icon: Icons.local_parking,
                              title: 'Parking',
                              value: widget.church['hasParking'] == true
                                  ? 'Available'
                                  : 'Limited',
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
                              value: '${_calculateDistance()}${estTravelTime.isNotEmpty ? '\n$estTravelTime' : ''}',
                            ),
                            if (widget.church['directionDescription'] != null && widget.church['directionDescription']!.isNotEmpty)
                              _buildDetailCard(
                                context,
                                icon: Icons.directions,
                                title: 'Directions',
                                value: widget.church['directionDescription']!,
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (serviceTimes.isNotEmpty)
                          Text(
                            'Service Schedule',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        if (serviceTimes.isNotEmpty) const SizedBox(height: 8),
                        ...serviceTimes.map(
                          (time) => Padding(
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
                          ),
                        ),
                        if (_hasValidLocation) ...[
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _launchDirections,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: const Text('Get Directions'),
                          ),
                        ],
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
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
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

// Added: Fancy Animated Splash Screen using Lottie
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Timer(const Duration(seconds: 4), () { // Adjust duration for your animation length
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MapPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/splash_logo.png', // Replace with your actual image path in assets/images
              width: screenWidth * 0.9, // Increased to make it wider
              height: screenHeight * 0.6, // Increased to make it bigger
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              'Discover Your Faith Journey',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
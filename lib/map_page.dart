import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class ChurchSearchState extends ChangeNotifier {
  String _searchQuery = '';
  List<Map<String, dynamic>> _allChurches = [];
  List<Map<String, dynamic>> _filteredChurches = [];

  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get filteredChurches => _filteredChurches;

  void updateSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
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
    notifyListeners();
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
  final List<AnimationController> _pulseControllers = [];
  final MapController _mapController = MapController();
  final Location _locationService = Location();
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  double _currentZoom = 6.0;

  final ChurchSearchState _searchState = ChurchSearchState();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchState.dispose();
    for (var controller in _pulseControllers) {
      controller.dispose();
    }
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
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
      final jsonString = await rootBundle.loadString(
        'assets/data/churches.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);
      final churches = jsonList
          .map((church) => church as Map<String, dynamic>)
          .toList();

      for (var _ in churches) {
        _pulseControllers.add(
          AnimationController(vsync: this, duration: const Duration(seconds: 2))
            ..repeat(reverse: true),
        );
      }

      _searchState.setAllChurches(churches);
    } catch (e) {
      debugPrint('Error loading churches: $e');
      _searchState.setAllChurches([]);
    }
  }

  Future<void> _getUserLocation() async {
    try {
      if (!await _locationService.serviceEnabled()) {
        await _locationService.requestService();
      }

      var permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
      }

      if (permission == PermissionStatus.granted) {
        final locationData = await _locationService.getLocation();
        setState(() {
          _userLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
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
            controller: _pulseControllers[index],
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    });
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
                    onMapEvent: (event) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _currentZoom != event.zoom) {
                          setState(() => _currentZoom = event.zoom);
                        }
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.faithmap',
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getUserLocation,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

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

    final distance = Distance().as(LengthUnit.Meter, widget.userLocation!, churchLoc);
    return '${(distance / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final serviceTimes =
        (widget.church['serviceTimes'] as List?)?.whereType<String>().toList() ?? [];

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
                              value: _calculateDistance(),
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
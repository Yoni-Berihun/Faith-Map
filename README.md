# Faith Map - Interactive Church Finder

A Flutter application that helps users find churches in Ethiopia with advanced search, filtering, and interactive map features.

## Features

### 🗺️ Interactive Map Controls
- **Multiple Map Styles**: Toggle between Street, Satellite, and Terrain views
- **Zoom Controls**: Built-in zoom in/out functionality
- **Compass**: Toggleable compass for navigation orientation
- **Scale Bar**: Toggleable scale bar showing current zoom level
- **User Location**: Real-time GPS location with error handling

### 🔍 Search and Filter Functionality
- **Search Bar**: Search churches by name, pastor, or directions
- **Language Filter**: Filter by Amharic, English, Oromo, or Tigrinya
- **Service Time Filter**: Filter by Sunday, Saturday, Weekday, or Evening services
- **Parking Filter**: Show only churches with parking available
- **Filter Chips**: Visual indicators of active filters with easy removal

### ⚡ Performance Optimizations
- **Map Tile Caching**: Reduces data usage and improves loading times
- **Marker Clustering**: Groups nearby markers based on zoom level
- **Dynamic Marker Loading**: Limits markers displayed based on zoom level
- **Efficient Filtering**: Real-time search and filter updates

### 🏛️ Church Information
- **Detailed Church Cards**: Comprehensive information including:
  - Church name and pastor
  - Service times and languages
  - Parking availability
  - Distance from user location
  - Direction descriptions
  - Contact information (phone numbers)
- **Image Carousel**: Multiple church images with auto-play
- **Interactive Markers**: Pulsing church markers with tap-to-view details

## Technical Features

### Map Integration
- **flutter_map**: Open-source mapping solution
- **Multiple Tile Providers**: OpenStreetMap, Esri Satellite, OpenTopoMap
- **Marker Clustering**: Efficient handling of multiple markers
- **Tile Caching**: Offline map tile storage

### Location Services
- **GPS Integration**: Real-time location tracking
- **Permission Handling**: Automatic location permission requests
- **Error Handling**: Graceful fallback for location errors

### UI/UX
- **Material Design 3**: Modern, accessible interface
- **Dark/Light Theme**: Automatic theme switching
- **Responsive Design**: Works on various screen sizes
- **Smooth Animations**: Pulsing markers and smooth transitions

## Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Android Studio / VS Code
- Android device or emulator

### Installation
1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Connect your Android device or start an emulator
4. Run `flutter run` to launch the app

### Dependencies
```yaml
dependencies:
  flutter_map: ^5.0.0
  location: ^8.0.1
  phosphor_flutter: ^2.0.0
  flutter_map_marker_cluster: ^1.0.0
  flutter_map_tile_caching: ^9.0.0-dev.3
  carousel_slider: ^5.0.0
  url_launcher: ^6.1.0
  shared_preferences: ^2.2.2
```

## Usage

### Basic Navigation
1. **Launch the app** - The map will load with your current location
2. **View churches** - Church markers appear as pulsing icons
3. **Tap markers** - View detailed church information
4. **Use search** - Type to find specific churches or pastors

### Advanced Features
1. **Filter churches** - Tap the filter icon in the app bar
2. **Change map style** - Use the map style toggle button
3. **Toggle controls** - Use compass and scale bar toggles
4. **Refresh data** - Use the refresh button to reload church data

### Search Tips
- Search by church name: "Addis Ababa"
- Search by pastor name: "John Doe"
- Search by location: "Central Park"
- Use filters to narrow results by language or service time

## Data Structure

Churches are stored in `assets/data/churches.json` with the following structure:
```json
{
  "id": "unique_id",
  "name": "Church Name",
  "latitude": 9.0312,
  "longitude": 38.7636,
  "images": ["image_urls"],
  "serviceTimes": ["service_schedule"],
  "pastor": "Pastor Name",
  "pastorPhone": "phone_number",
  "hasParking": true,
  "language": "Language",
  "directionDescription": "Location description"
}
```

## Performance Notes

- **Tile Caching**: Map tiles are cached locally to reduce data usage
- **Marker Optimization**: Markers are limited based on zoom level for better performance
- **Clustering**: Nearby markers are grouped to reduce visual clutter
- **Lazy Loading**: Images and data are loaded on-demand

## Troubleshooting

### Common Issues
1. **Location not working**: Ensure GPS is enabled and location permissions are granted
2. **Map not loading**: Check internet connection for initial tile loading
3. **App crashes**: Ensure all dependencies are properly installed

### Error Messages
- "Using approximate location" - GPS is not available, using default location
- "No churches found" - Try clearing search filters or refreshing data

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support or questions, please open an issue in the repository.

import 'package:flutter/material.dart';
import 'location_search_bar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

class LocationData {
  final String name;
  final double lat;
  final double lon;
  LocationData({required this.name, required this.lat, required this.lon});
}

void main() {
  runApp(const AQIApp());
}

class AQIApp extends StatelessWidget {
  const AQIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Quality Index',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF131B20),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'SpaceGrotesk'),
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  LocationData _selectedLocation = LocationData(
    name: 'Panbazaar, Guwahati, Assam',
    lat: 26.1844,
    lon: 91.7499,
  );
  bool _isLocating = false;

  Future<void> _locateMe() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
        return;
      }
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LocationData(
          name: 'Current Location',
          lat: position.latitude,
          lon: position.longitude,
        );
        _isLocating = false;
      });
    } catch (e) {
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  void _onLocationSelected(String name, double lat, double lon) {
    setState(() {
      _selectedLocation = LocationData(name: name, lat: lat, lon: lon);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      HomePage(
        location: _selectedLocation,
        onLocationSelected: _onLocationSelected,
        isLocating: _isLocating,
        onLocateMe: _locateMe,
      ),
      ForecastPage(
        location: _selectedLocation,
        onLocationSelected: _onLocationSelected,
      ),
      HeatmapsPage(
        location: _selectedLocation,
        onLocationSelected: _onLocationSelected,
      ),
    ];
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1D282F),
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFF9AB1C1),
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: ''),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: '',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final LocationData location;
  final Function(String, double, double) onLocationSelected;
  final bool isLocating;
  final VoidCallback onLocateMe;
  const HomePage({
    Key? key,
    required this.location,
    required this.onLocationSelected,
    required this.isLocating,
    required this.onLocateMe,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? pm10Avg;
  String status = '';
  String healthMsg = '';
  String? stationName;
  String? lastUpdate;
  bool isLoading = false;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    fetchAQI();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.lat != widget.location.lat ||
        oldWidget.location.lon != widget.location.lon) {
      fetchAQI();
    }
  }

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula
    const R = 6371; // km
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> fetchAQI() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final apiKey = '579b464db66ec23bdd000001340cb86febee44fe51c61072dacb3394';
      final url = Uri.parse(
        'https://api.data.gov.in/resource/3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69?api-key=$apiKey&format=json&limit=100',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List?;
        if (records != null && records.isNotEmpty) {
          // Find nearest station with a valid avg_value
          double minDist = double.infinity;
          Map<String, dynamic>? nearest;
          for (final rec in records) {
            final latStr = rec['latitude'];
            final lonStr = rec['longitude'];
            final avgStr = rec['avg_value'];
            if (latStr == null ||
                lonStr == null ||
                avgStr == null ||
                avgStr == 'NA')
              continue;
            final lat = double.tryParse(latStr);
            final lon = double.tryParse(lonStr);
            if (lat == null || lon == null) continue;
            final dist = _distance(
              widget.location.lat,
              widget.location.lon,
              lat,
              lon,
            );
            if (dist < minDist) {
              minDist = dist;
              nearest = rec;
            }
          }
          if (nearest != null) {
            final avgValue = int.tryParse(nearest['avg_value']);
            setState(() {
              pm10Avg = avgValue;
              stationName = nearest!['station'];
              lastUpdate = nearest!['last_update'];
              status = getAQIStatus(avgValue);
              healthMsg = getHealthMsg(avgValue);
              isLoading = false;
            });
          } else {
            setState(() {
              errorMsg = 'No AQI data found for this location.';
              isLoading = false;
            });
          }
        } else {
          setState(() {
            errorMsg = 'No AQI data found.';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMsg = 'Failed to fetch AQI data.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Error: $e';
        isLoading = false;
      });
    }
  }

  String getAQIStatus(int? value) {
    if (value == null) return '';
    if (value <= 50) return 'Good';
    if (value <= 100) return 'Moderate';
    if (value <= 200) return 'Unhealthy';
    if (value <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  String getHealthMsg(int? value) {
    if (value == null) return '';
    if (value <= 50)
      return 'Air quality is satisfactory, and air pollution poses little or no risk.';
    if (value <= 100)
      return 'Air quality is acceptable. Sensitive individuals should avoid outdoor activity.';
    if (value <= 200)
      return 'Everyone may begin to experience health effects; sensitive groups may experience more serious health effects.';
    if (value <= 300)
      return 'Health warnings of emergency conditions. The entire population is more likely to be affected.';
    return 'Health alert: everyone may experience more serious health effects.';
  }

  @override
  Widget build(BuildContext context) {
    final cardBgUrl =
        "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80"; // sky with clouds
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Air Quality',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF131B20),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocationSearchBar(
              onLocationSelected: widget.onLocationSelected,
              initialValue: widget.location.name,
            ),
            const SizedBox(height: 16),
            // Map at the top
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 180,
                    child: FlutterMap(
                      options: MapOptions(
                        center: LatLng(
                          widget.location.lat,
                          widget.location.lon,
                        ),
                        zoom: 13,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 40,
                              height: 40,
                              point: LatLng(
                                widget.location.lat,
                                widget.location.lon,
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: widget.isLocating ? null : widget.onLocateMe,
                    child: widget.isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // AQI Card
            if (isLoading) const Center(child: CircularProgressIndicator()),
            if (!isLoading && errorMsg != null)
              Center(
                child: Text(
                  errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            if (!isLoading && errorMsg == null && pm10Avg != null)
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(
                        image: NetworkImage(cardBgUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'PM10 Avg: $pm10Avg',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        if (stationName != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Station: $stationName',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ],
                        if (lastUpdate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Last Update: $lastUpdate',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Health message
                  Text(
                    healthMsg,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class ForecastPage extends StatelessWidget {
  final LocationData location;
  final Function(String, double, double) onLocationSelected;
  const ForecastPage({
    Key? key,
    required this.location,
    required this.onLocationSelected,
  }) : super(key: key);

  Widget buildCard(String label, String status, String aqi, String imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9AB1C1),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  aqi,
                  style: const TextStyle(
                    color: Color(0xFF9AB1C1),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(imageUrl, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Forecast',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF131B20),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LocationSearchBar(
              onLocationSelected: onLocationSelected,
              initialValue: location.name,
            ),
            const SizedBox(height: 16),
            buildCard(
              "Today",
              "Good",
              "AQI: 45",
              "https://lh3.googleusercontent.com/aida-public/AB6AXuD7zumgVuOdx6RsTXmj_OL7fZN2ssI2XYgtaIaeJ3mNCWWsmEDGKir7UBYGZcsx6AYN_79DRDzz6PASUFhgG4a7CB7L9SRAlquSs0K4Gl4qEc332GjdzhMX2ZTAHC9z_42nvkjw9KkdAZ6HSmB3aPbdAxiKMfWjt2tY1G7q1TYkdxyTdQNQmXV1vDMZL5skpvp1zFMa71_NpqefyIlv-8hmyTwfVeX8iIAQ_u_xmjPVYjFvdCTK3BpG2BuuLAHgarnezlElLHzfKg",
            ),
            buildCard(
              "Tomorrow",
              "Moderate",
              "AQI: 85",
              "https://lh3.googleusercontent.com/aida-public/AB6AXuAgdLr_ptOysol63Ss6PlNRn_P6cYe6dil-hXkoJjy-BztQWc047iBGrqp8GXUVqeYdTXF4UZe0e2sr0B-U8onjjB3_rk2gajCQHLSm5vYqhqgJiSBI2sgh-Ct37Z6qQL5OWSDpqA7tUNynmLWoddWWWy3Xf11mhSkQM62vY4Ru4FO1QlzvfMvZO7xuezBnN7_XW307z-fTIdpw_Qcyl2kbLOwS0K0dID69yUKPSwZHAouY_2VdD_cuVrueNL7meAgunMHKv6eo8Q",
            ),
            buildCard(
              "In 2 Days",
              "Unhealthy",
              "AQI: 155",
              "https://lh3.googleusercontent.com/aida-public/AB6AXuCVGqnu3w9t1NnU0_TJQrVr8mMfatraOBxq-19Q5L73sLtWwFI9mz08Pb_LcbgkIK2KXp1tgmEFWI1TBsgpz1gG6ns5akMKWlBOYUDFkUF6kHfizej9tx8MPN2zNdY3yJAvSHB7fclgmjG6Oq9A-TcU2ncdAzzbPJRCuqGFNj1dwdhk7X7spyjqMSKcgD4yZgF3HWRM8MHei2IxlU402qsrNQGGvkE61kuKpWccNnuc5ossIFz6nA0i_TgpriPBGE4CaXfloDYxaw",
            ),
          ],
        ),
      ),
    );
  }
}

class HeatmapsPage extends StatelessWidget {
  final LocationData location;
  final Function(String, double, double) onLocationSelected;
  const HeatmapsPage({
    Key? key,
    required this.location,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Heatmaps',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF131B20),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LocationSearchBar(
              onLocationSelected: onLocationSelected,
              initialValue: location.name,
            ),
            const SizedBox(height: 16),
            // AQI summary card
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D282F),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Heatmap Summary',
                          style: TextStyle(
                            color: Color(0xFF9AB1C1),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Good',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'AQI: 46',
                          style: TextStyle(
                            color: Color(0xFF9AB1C1),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/1/1b/Heatmap.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Map
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    center: LatLng(location.lat, location.lon),
                    zoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 40,
                          height: 40,
                          point: LatLng(location.lat, location.lon),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Placeholder for ML graph image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/3/3a/Plotly-dash-heatmap.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'location_search_bar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

class HomePage extends StatelessWidget {
  final LocationData location;
  final Function(String, double, double) onLocationSelected;
  const HomePage({
    Key? key,
    required this.location,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hardcoded current AQI data for demo
    final aqi = 35;
    final status = "Good";
    final healthMsg =
        "Air quality is satisfactory, and air pollution poses little or no risk.";
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
              onLocationSelected: onLocationSelected,
              initialValue: location.name,
            ),
            const SizedBox(height: 16),
            // Map at the top
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    center: LatLng(location.lat, location.lon),
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
            const SizedBox(height: 24),
            // AQI Card
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
                    'AQI: $aqi',
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
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

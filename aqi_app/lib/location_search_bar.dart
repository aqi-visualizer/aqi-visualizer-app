import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationSearchBar extends StatefulWidget {
  final Function(String name, double lat, double lon) onLocationSelected;
  final String initialValue;

  const LocationSearchBar({
    Key? key,
    required this.onLocationSelected,
    this.initialValue = '',
  }) : super(key: key);

  @override
  _LocationSearchBarState createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isLoading = true);
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'aqi-visualizer-app/1.0 (lunad@yourdomain.com)'},
    );
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      setState(() {
        _suggestions = data
            .map<Map<String, dynamic>>(
              (item) => {
                'display_name': item['display_name'],
                'lat': double.tryParse(item['lat'] ?? '0') ?? 0.0,
                'lon': double.tryParse(item['lon'] ?? '0') ?? 0.0,
              },
            )
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'search any location, city/village',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[300],
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            ),
            onChanged: (value) {
              if (value.length > 2)
                _search(value);
              else
                setState(() => _suggestions = []);
            },
            onSubmitted: (value) {
              if (_suggestions.isNotEmpty) {
                final first = _suggestions.first;
                widget.onLocationSelected(
                  first['display_name'],
                  first['lat'],
                  first['lon'],
                );
                setState(() => _suggestions = []);
              }
            },
          ),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  title: Text(
                    suggestion['display_name'],
                    style: TextStyle(fontSize: 14),
                  ),
                  onTap: () {
                    widget.onLocationSelected(
                      suggestion['display_name'],
                      suggestion['lat'],
                      suggestion['lon'],
                    );
                    _controller.text = suggestion['display_name'];
                    setState(() => _suggestions = []);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

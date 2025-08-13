import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:location/location.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  Map<String, dynamic>? _weatherData;
  String? _error;
  bool _isLoading = true;
  final Location _locationService = Location();
  final TextEditingController _searchController = TextEditingController();
  bool _usingCurrentLocation = true;
  String? _cityName; // <-- Add this line

  @override
  void initState() {
    super.initState();
    _fetchWeatherByLocation();
  }

  Future<void> _fetchWeatherByLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _usingCurrentLocation = true;
      _cityName = null; // Reset city name
    });

    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          throw Exception('Location service is disabled');
        }
      }

      PermissionStatus permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) {
          throw Exception('Location permissions denied');
        }
      }

      LocationData locationData = await _locationService.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) {
        throw Exception('Failed to get location coordinates');
      }
      // Get city name using reverse geocoding
      await _fetchCityNameFromCoords(
        locationData.latitude!,
        locationData.longitude!,
      );
      await _fetchWeatherData(
        lat: locationData.latitude!,
        lon: locationData.longitude!,
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCityNameFromCoords(double lat, double lon) async {
    try {
      const apiKey = '4361cda5ae1cfe6f2ff8a3f578b6c773';
      final url = Uri.parse(
        'https://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lon&limit=1&appid=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty && data[0]['name'] != null) {
          setState(() {
            _cityName = data[0]['name'];
          });
        }
      }
    } catch (_) {
      // ignore errors, city name will be null
    }
  }

  Future<void> _fetchWeatherByCity(String city) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _usingCurrentLocation = false;
      _cityName = city; // <-- Set city name
    });

    try {
      const apiKey = '4361cda5ae1cfe6f2ff8a3f578b6c773';
      final geoUrl = Uri.parse(
        'https://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$apiKey',
      );
      final geoResponse = await http.get(geoUrl);

      if (geoResponse.statusCode == 200) {
        final geoData = json.decode(geoResponse.body);
        if (geoData.isEmpty) {
          throw Exception('City not found');
        }
        final lat = geoData[0]['lat'];
        final lon = geoData[0]['lon'];
        // Optionally update city name from geoData
        if (geoData[0]['name'] != null) {
          setState(() {
            _cityName = geoData[0]['name'];
          });
        }
        await _fetchWeatherData(lat: lat, lon: lon);
      } else {
        throw Exception('Failed to find city: ${geoResponse.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchWeatherData({
    required double lat,
    required double lon,
  }) async {
    try {
      const apiKey = '4361cda5ae1cfe6f2ff8a3f578b6c773';
      final url = Uri.parse(
        'https://api.openweathermap.org/data/3.0/onecall?lat=$lat&lon=$lon&exclude=minutely&appid=$apiKey&units=metric',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _weatherData = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _fetchWeatherByLocation,
            tooltip: 'Use current location',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search city...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          if (_searchController.text.isNotEmpty) {
                            _fetchWeatherByCity(_searchController.text);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _fetchWeatherByCity(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SpinKitFadingCircle(color: Colors.blue, size: 50.0),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _usingCurrentLocation
                  ? _fetchWeatherByLocation
                  : () {
                      if (_searchController.text.isNotEmpty) {
                        _fetchWeatherByCity(_searchController.text);
                      }
                    },
              child: Text(
                _usingCurrentLocation
                    ? 'Retry Current Location'
                    : 'Retry Search',
              ),
            ),
          ],
        ),
      );
    }

    final current = _weatherData!['current'];
    final daily = _weatherData!['daily'][0];
    final temp = current['temp'];
    final feelsLike = current['feels_like'];
    final condition = current['weather'][0]['main'];
    final humidity = current['humidity'];
    final windSpeed = current['wind_speed'];
    final sunrise = DateTime.fromMillisecondsSinceEpoch(
      current['sunrise'] * 1000,
    );
    final sunset = DateTime.fromMillisecondsSinceEpoch(
      current['sunset'] * 1000,
    );
    final dailyHigh = daily['temp']['max'];
    final dailyLow = daily['temp']['min'];

    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            if (_cityName != null)
              Text(
                _cityName!,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            Text(
              'Current Weather',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${temp.toStringAsFixed(1)}°C',
              style: const TextStyle(fontSize: 48),
            ),
            Text(
              'Feels like ${feelsLike.toStringAsFixed(1)}°C',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(condition, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 30),
            _buildWeatherDetail('Humidity', '$humidity%'),
            _buildWeatherDetail(
              'Wind Speed',
              '${windSpeed.toStringAsFixed(1)} m/s',
            ),
            _buildWeatherDetail(
              'Sunrise',
              '${sunrise.hour}:${sunrise.minute.toString().padLeft(2, '0')}',
            ),
            _buildWeatherDetail(
              'Sunset',
              '${sunset.hour}:${sunset.minute.toString().padLeft(2, '0')}',
            ),
            _buildWeatherDetail(
              'High/Low',
              '${dailyHigh.toStringAsFixed(1)}°/${dailyLow.toStringAsFixed(1)}°',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _usingCurrentLocation
                  ? _fetchWeatherByLocation
                  : () {
                      if (_searchController.text.isNotEmpty) {
                        _fetchWeatherByCity(_searchController.text);
                      }
                    },
              child: const Text('Refresh Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

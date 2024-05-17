import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';
import 'dart:math' show cos, sqrt, asin, pi, sin, atan2;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Distance Calculator')),
        body: Center(child: DistanceCalculatorBody()),
      ),
    );
  }
}

class DistanceCalculatorBody extends StatefulWidget {
  @override
  _DistanceCalculatorBodyState createState() => _DistanceCalculatorBodyState();
}

class _DistanceCalculatorBodyState extends State<DistanceCalculatorBody> {
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  String _distanceResult = '';
  String _appLocation = '';
  String _inputLocation = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          TextField(
            controller: _latitudeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Enter Latitude'),
          ),
          TextField(
            controller: _longitudeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Enter Longitude'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _calculateDistance,
            child: _isLoading ? CircularProgressIndicator() : const Text('Calculate Distance'),
          ),
          const SizedBox(height: 20),
          Text(_distanceResult, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _shareDetails,
            child: const Text('Share All Details'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : () async {
              final latlong.LatLng? pickedLocation = await Navigator.push<latlong.LatLng?>(
                context,
                MaterialPageRoute(builder: (BuildContext context) => MapPickerScreen()),
              );
              if (pickedLocation != null) {
                setState(() {
                  _latitudeController.text = pickedLocation.latitude.toString();
                  _longitudeController.text = pickedLocation.longitude.toString();
                });
              }
            },
            child: const Text('Pick Location from Map'),
          ),
        ],
      ),
    );
  }

  Future<void> _calculateDistance() async {
    final double? latitude = double.tryParse(_latitudeController.text);
    final double? longitude = double.tryParse(_longitudeController.text);

    if (latitude == null || longitude == null || !_isValidLatitude(latitude) || !_isValidLongitude(longitude)) {
      Fluttertoast.showToast(
        msg: "Invalid latitude or longitude",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Location permissions are denied",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final double distance = _haversine(position.latitude, position.longitude, latitude, longitude);
      setState(() {
        _distanceResult = 'Distance: ${(distance * 1000).toStringAsFixed(5)} meters';
        _appLocation = '${position.latitude}, ${position.longitude}';
        _inputLocation = '$latitude, $longitude';
      });
      await Clipboard.setData(ClipboardData(text: _distanceResult));
      Fluttertoast.showToast(
        msg: "Copied distance to clipboard",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to get location",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _shareDetails() {
    final String textToShare = 'App Location: $_appLocation\n'
        'Input Location: $_inputLocation\n'
        'Distance: ${(_distanceResult.split(': ')[1]).split(' ')[0]} meters';
    Share.share(textToShare);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const double radius = 6371; // Earth's radius in kilometers
    final double deltaLat = _degreesToRadians(lat2 - lat1);
    final double deltaLon = _degreesToRadians(lon2 - lon1);
    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
            sin(deltaLon / 2) * sin(deltaLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  bool _isValidLatitude(double latitude) {
    return latitude >= -90 && latitude <= 90;
  }

  bool _isValidLongitude(double longitude) {
    return longitude >= -180 && longitude <= 180;
  }
}

class MapPickerScreen extends StatefulWidget {
  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  latlong.LatLng _pickedLocation = latlong.LatLng(0, 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _pickedLocation);
            },
          ),
        ],
      ),
      body: FlutterLocationPicker(
        initZoom: 11,
        minZoomLevel: 5,
        maxZoomLevel: 16,
        trackMyPosition: true,
        searchBarBackgroundColor: Colors.white,
        selectedLocationButtonTextstyle: const TextStyle(fontSize: 18),
        mapLanguage: 'en',
        onError: (Exception e) => print(e),
        selectLocationButtonLeadingIcon: const Icon(Icons.check),
        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', // Using a standard OSM tile URL template
        onPicked: (PickedData pickedData) {
          setState(() {
            _pickedLocation = latlong.LatLng(pickedData.latLong.latitude, pickedData.latLong.longitude);
          });
        },
        onChanged: (PickedData pickedData) {
          setState(() {
            _pickedLocation = latlong.LatLng(pickedData.latLong.latitude, pickedData.latLong.longitude);
          });
        },
        showContributorBadgeForOSM: true,
      ),
    );
  }
}
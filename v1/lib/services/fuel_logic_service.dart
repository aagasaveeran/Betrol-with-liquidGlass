import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart' hide ActivityType; 
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class TripRecord {
  final String id;
  final String title;
  final String distance; 
  final String fuelConsumed; 
  final int colorValue;
  final bool isRefuel;
  final DateTime dateTime;
  final bool isHiddenOnHome;

  TripRecord({
    required this.id,
    required this.title, 
    required this.distance, 
    required this.fuelConsumed, 
    required this.colorValue,
    required this.dateTime,
    this.isRefuel = false,
    this.isHiddenOnHome = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title, 
    'distance': distance, 
    'fuelConsumed': fuelConsumed, 
    'colorValue': colorValue,
    'isRefuel': isRefuel,
    'dateTime': dateTime.toIso8601String(),
    'isHiddenOnHome': isHiddenOnHome,
  };

  factory TripRecord.fromJson(Map<String, dynamic> json) => TripRecord(
    id: json['id'] ?? const Uuid().v4(),
    title: json['title'], 
    distance: json['distance'], 
    fuelConsumed: json['fuelConsumed'], 
    colorValue: json['colorValue'],
    isRefuel: json['isRefuel'] ?? false,
    dateTime: DateTime.parse(json['dateTime']),
    isHiddenOnHome: json['isHiddenOnHome'] ?? false,
  );
}

class FuelLogicService {
  final _activityRecognition = FlutterActivityRecognition.instance;
  final _uuid = const Uuid();
  
  Position? _lastPosition;
  double _tripDistanceBuffer = 0.0; 

  final _consumptionController = StreamController<double>.broadcast();
  final _rideStatsController = StreamController<Map<String, double>>.broadcast();

  Stream<double> get consumptionStream => _consumptionController.stream;
  Stream<Map<String, double>> get rideStatsStream => _rideStatsController.stream;

  Stream<bool> get ridingStream => _activityRecognition.activityStream.map((activity) => 
    activity.type == ActivityType.IN_VEHICLE || activity.type == ActivityType.ON_BICYCLE);

  Future<void> saveFuelLevel(double level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fuel_level', level);
  }

  Future<double> loadFuelLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('fuel_level') ?? 2.5;
  }

  // Inside FuelLogicService class
  Future<TripRecord> logRefuel(double liters, double cost) async {
    final now = DateTime.now();
    final refuelEntry = TripRecord(
      id: _uuid.v4(),
      title: "Refuel",
      distance: "₹${cost.toInt()}",
      fuelConsumed: "+${liters.toStringAsFixed(1)} L",
      colorValue: 0xFFFFB300,
      isRefuel: true,
      dateTime: now,
      isHiddenOnHome: false,
    );
    
    await _saveTrip(refuelEntry);
    return refuelEntry; // Return the record so UI can use it immediately
  }

  Future<void> dismissTripFromHome(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList('trip_history') ?? [];
    
    List<TripRecord> history = historyStrings
        .map((s) => TripRecord.fromJson(jsonDecode(s)))
        .toList();

    int index = history.indexWhere((t) => t.id == id);
    if (index != -1) {
      history[index] = TripRecord(
        id: history[index].id,
        title: history[index].title,
        distance: history[index].distance,
        fuelConsumed: history[index].fuelConsumed,
        colorValue: history[index].colorValue,
        dateTime: history[index].dateTime,
        isRefuel: history[index].isRefuel,
        isHiddenOnHome: true,
      );
      
      List<String> updatedStrings = history.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('trip_history', updatedStrings);
    }
  }

  Future<void> _saveTrip(TripRecord trip) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('trip_history') ?? [];
    history.insert(0, jsonEncode(trip.toJson())); 
    await prefs.setStringList('trip_history', history);
  }

  Future<List<TripRecord>> loadAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('trip_history') ?? [];
    return history.map((item) => TripRecord.fromJson(jsonDecode(item))).toList();
  }

  // Simplified this to always be the source of truth for the Home screen
  Future<List<TripRecord>> loadHomeHistory() async {
    final all = await loadAllHistory();
    return all.where((t) => !t.isHiddenOnHome).toList();
  }

  void _handleRideEnd() async {
    if (_tripDistanceBuffer > 0.02) { 
      final now = DateTime.now();
      await _saveTrip(TripRecord(
        id: _uuid.v4(),
        title: "Ride",
        distance: "${_tripDistanceBuffer.toStringAsFixed(2)} km",
        fuelConsumed: "-${(_tripDistanceBuffer / 45).toStringAsFixed(2)} L",
        colorValue: 0xFF60A5FA, 
        isRefuel: false,
        dateTime: now,
      ));
    }
    _tripDistanceBuffer = 0.0; 
    _rideStatsController.add({"speed": 0.0, "distance": 0.0});
  }

  void startDistanceTracking(bool isRiding) {
    if (!isRiding) {
      _handleRideEnd();
      _lastPosition = null;
      return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 2 
      ),
    ).listen((Position position) {
      if (_lastPosition != null) {
        double dist = Geolocator.distanceBetween(
          _lastPosition!.latitude, _lastPosition!.longitude, 
          position.latitude, position.longitude
        ) / 1000;
        
        _tripDistanceBuffer += dist;
        _consumptionController.add(dist / 45);

        _rideStatsController.add({
          "speed": position.speed * 3.6,
          "distance": _tripDistanceBuffer
        });
      }
      _lastPosition = position;
    });
  }

  Future<bool> requestPermissions() async {
    LocationPermission location = await Geolocator.requestPermission();
    PermissionRequestResult activity = await _activityRecognition.checkPermission();
    return location != LocationPermission.denied && 
           location != LocationPermission.deniedForever &&
           activity == PermissionRequestResult.GRANTED;
  }
}
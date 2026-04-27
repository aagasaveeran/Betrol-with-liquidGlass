import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart'; // Added for debugPrint
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
    title: json['title'] ?? "Unknown Activity", 
    distance: json['distance'] ?? "0.0", 
    fuelConsumed: json['fuelConsumed'] ?? "0.0", 
    colorValue: json['colorValue'] ?? 0xFFFFFFFF,
    isRefuel: json['isRefuel'] ?? false,
    dateTime: DateTime.parse(json['dateTime'] ?? DateTime.now().toIso8601String()),
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

  // ── PERSISTENCE METHODS ──

  Future<void> saveFuelLevel(double level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fuel_level', level);
  }

  Future<double> loadFuelLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('fuel_level') ?? 2.5;
  }

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
    
    await _saveTrip(refuelEntry); // Must await to prevent loss on close
    return refuelEntry;
  }

  Future<void> dismissTripFromHome(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAllHistory();
    
    int index = all.indexWhere((t) => t.id == id);
    if (index != -1) {
      all[index] = TripRecord(
        id: all[index].id,
        title: all[index].title,
        distance: all[index].distance,
        fuelConsumed: all[index].fuelConsumed,
        colorValue: all[index].colorValue,
        dateTime: all[index].dateTime,
        isRefuel: all[index].isRefuel,
        isHiddenOnHome: true,
      );
      
      List<String> updatedStrings = all.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('trip_history', updatedStrings);
    }
  }

  Future<void> _saveTrip(TripRecord trip) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('trip_history') ?? [];
    history.insert(0, jsonEncode(trip.toJson())); 
    await prefs.setStringList('trip_history', history);
  }

  /// ROBUST PARSING: Prevents infinite loading circle
  Future<List<TripRecord>> loadAllHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? historyStrings = prefs.getStringList('trip_history');
      
      if (historyStrings == null || historyStrings.isEmpty) return [];

      List<TripRecord> records = [];
      for (String item in historyStrings) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(item);
          records.add(TripRecord.fromJson(decoded));
        } catch (e) {
          debugPrint("Agent: Skipping corrupted history item: $e");
          continue; // Skip individual broken items
        }
      }
      return records;
    } catch (e) {
      debugPrint("Agent: Critical error loading history: $e");
      return [];
    }
  }

  Future<List<TripRecord>> loadHomeHistory() async {
    final all = await loadAllHistory();
    return all.where((t) => !t.isHiddenOnHome).toList();
  }

  // ── TRACKING LOGIC ──

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
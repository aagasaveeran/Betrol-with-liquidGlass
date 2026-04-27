import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; 
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
  final _uuid = const Uuid();
  Position? _lastPosition;
  double _tripDistanceBuffer = 0.0; 

  // --- NEW: Tracking Subscription Manager ---
  StreamSubscription<Position>? _positionSubscription;

  final _consumptionController = StreamController<double>.broadcast();
  final _rideStatsController = StreamController<Map<String, double>>.broadcast();

  Stream<double> get consumptionStream => _consumptionController.stream;
  Stream<Map<String, double>> get rideStatsStream => _rideStatsController.stream;

  // ── THE AUTOMATIC BRAIN ──
  FuelLogicService() {
    print("🧠 AGENT: Automatic Brain initialized.");
    
    Geolocator.requestPermission().then((permission) {
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        print("✅ AGENT: Permissions active. Monitoring speed for automatic tracking...");
        
        ridingStream.listen((isRiding) {
          print("🔔 AGENT: State change detected! isRiding = $isRiding");
          startDistanceTracking(isRiding);
        });
      } else {
        print("⚠️ AGENT: Location permission denied. Tracking will not work.");
      }
    });
  }

  // ── THE SPEED DETECTOR (Mock/Lockito Ready) ──
  Stream<bool> get ridingStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, 
      ),
    ).map((pos) {
      // Speed > 1.5 m/s (approx 5.4 km/h) = Riding
      bool isMoving = pos.speed > 1.5;
      print("🤖 AUTO-SPEED: ${(pos.speed * 3.6).toStringAsFixed(1)} km/h | isRiding: $isMoving");
      return isMoving;
    }).distinct(); 
  }

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
    
    await _saveTrip(refuelEntry);
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
          continue; 
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
    // 1. Kill any existing listener to prevent "Double Tracking"
    _positionSubscription?.cancel();
    
    print("🔄 DEBUG: startDistanceTracking called. isRiding = $isRiding");

    if (!isRiding) {
      print("🛑 DEBUG: Not riding. Cleaning up.");
      _handleRideEnd();
      _lastPosition = null;
      return;
    }

    print("🛰️ DEBUG: Opening Location Stream...");

    // 2. Assign the listener to our variable so we can stop it later
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 2 
      ),
    ).listen((Position position) {
      print("📍 RAW LOCATION: Lat: ${position.latitude}, Lon: ${position.longitude}");
      print("🚀 RAW SPEED: ${position.speed} m/s");

      if (_lastPosition != null) {
        double dist = Geolocator.distanceBetween(
          _lastPosition!.latitude, _lastPosition!.longitude, 
          position.latitude, position.longitude
        ) / 1000;

        // --- ADD THIS SANITY FILTER ---
        // If the "jump" is more than 0.5km in one update, it's a GPS error/snap.
        if (dist > 0.5) {
          print("⚠️ JUMP DETECTED: Ignoring fake jump of $dist km");
          _lastPosition = position; // Update position but don't count the distance
          return; 
        }
        // ------------------------------
        
        print("📏 DISTANCE DELTA: $dist km");

        _tripDistanceBuffer += dist;
        double fuelConsumed = dist / 45;
        _consumptionController.add(fuelConsumed);
        
        print("⛽ FUEL CONSUMED: $fuelConsumed | TOTAL TRIP: $_tripDistanceBuffer km");

        _rideStatsController.add({
          "speed": position.speed * 3.6,
          "distance": _tripDistanceBuffer
        });
      } else {
        print("⏳ DEBUG: First position received. Waiting for next movement...");
      }
      _lastPosition = position;
    });
  }

  Future<bool> requestPermissions() async {
    LocationPermission location = await Geolocator.requestPermission();
    return location != LocationPermission.denied && 
           location != LocationPermission.deniedForever;
  }
}
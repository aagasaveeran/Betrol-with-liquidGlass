import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import 'package:sensors_plus/sensors_plus.dart'; // New Import

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BikeFuelAgentApp());
}

class BikeFuelAgentApp extends StatelessWidget {
  const BikeFuelAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF09090B),
        fontFamily: 'SF Pro Display',
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeDashboard(),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  double _fuelLevel = 0.65;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const _BackgroundLayer(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                // PHYSICS-DRIVEN ORB
                FuelOrb(fuelLevel: _fuelLevel),
                const SizedBox(height: 15),
                _buildFuelStats(),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 150),
                    children: [
                      const Text(
                        "Activity History",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 16),
                      _buildTripTile("Office ➝ Home", "4.8 km", "-0.09 L", Colors.blue),
                      _buildTripTile("Weekend Ride", "12.4 km", "-0.25 L", Colors.purple),
                      _buildRefuelTile("Shell Station", "₹200", "+2.2 L", Colors.amber),
                      _buildTripTile("Gym ➝ Cafe", "2.1 km", "-0.04 L", Colors.pink),
                      const SizedBox(height: 20),
                      Text("ADJUST FUEL LEVEL (DEMO)", 
                        style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)),
                      Slider(
                        value: _fuelLevel,
                        activeColor: Colors.amber,
                        inactiveColor: Colors.white10,
                        onChanged: (val) => setState(() => _fuelLevel = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _FloatingLiquidGlassNavBar(),
        ],
      ),
    );
  }

  // UI Helpers
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Good Afternoon", style: TextStyle(fontSize: 14, color: Colors.white54)),
              Text("Aagasaveeran", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            ],
          ),
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white.withOpacity(0.05),
            child: const Text("AG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statColumn("LITERS", "${(_fuelLevel * 10).toStringAsFixed(1)}L"),
        Container(width: 1, height: 30, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 30)),
        _statColumn("RANGE", "${(_fuelLevel * 450).toInt()} KM"),
      ],
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1.5)),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }

  Widget _buildTripTile(String title, String dist, String fuel, Color color) {
    return _GlassCard(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(Icons.motorcycle, color: color, size: 20)),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(dist, style: const TextStyle(fontSize: 12, color: Colors.white38)),
        trailing: Text(fuel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
      ),
    );
  }

  Widget _buildRefuelTile(String station, String cost, String amount, Color color) {
    return _GlassCard(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(Icons.local_gas_station, color: color, size: 20)),
        title: Text(station, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(cost, style: const TextStyle(fontSize: 12, color: Colors.white38)),
        trailing: Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

// ── PHYSICAL FUEL ORB WIDGET ────────────────────────────────────────────────
class FuelOrb extends StatefulWidget {
  final double fuelLevel;
  final double size;
  const FuelOrb({super.key, required this.fuelLevel, this.size = 230});

  @override
  State<FuelOrb> createState() => _FuelOrbState();
}

class _FuelOrbState extends State<FuelOrb> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  
  double _tiltAngle = 0.0;
  double _sloshForce = 0.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    // Listen to Accelerometer
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      if (!mounted) return;
      setState(() {
        // Calculate tilt using atan2(x, y)
        double targetAngle = math.atan2(event.x, event.y);
        // Low-pass filter to smooth the liquid movement
        _tiltAngle = _tiltAngle * 0.8 + targetAngle * 0.2;

        // Calculate shake/slosh force (G-force change)
        double force = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        _sloshForce = (force - 9.8).abs() * 2.0; 
      });
    });
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OCLiquidGlassGroup(
      settings: const OCLiquidGlassSettings(
        refractStrength: -0.25, 
        blurRadiusPx: 0.5,
        specStrength: 60.0,
        lightbandStrength: 0.8,
      ),
      child: OCLiquidGlass(
        width: widget.size,
        height: widget.size,
        borderRadius: widget.size / 2,
        color: Colors.white.withOpacity(0.02),
        child: ClipOval(
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: _LiquidPainter(
                  waveValue: _waveController.value,
                  fillLevel: widget.fuelLevel,
                  tiltAngle: _tiltAngle,
                  sloshForce: _sloshForce,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double waveValue;
  final double fillLevel;
  final double tiltAngle;
  final double sloshForce;

  _LiquidPainter({
    required this.waveValue, 
    required this.fillLevel, 
    required this.tiltAngle,
    required this.sloshForce,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Rotate the Canvas based on device tilt
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-tiltAngle); 
    canvas.translate(-size.width / 2, -size.height / 2);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFD700).withOpacity(0.9),
          const Color(0xFFEAB308),
          const Color(0xFF451A03),
        ],
      ).createShader(Offset.zero & size);

    final path = Path();
    final fillHeight = size.height * (1 - fillLevel);

    // Draw larger than size so rotation doesn't show edges
    double overflow = 80.0;
    path.moveTo(-overflow, fillHeight);
    
    for (double x = -overflow; x <= size.width + overflow; x++) {
      // Base slosh + shake slosh
      double baseWave = math.sin((waveValue * 2 * math.pi) + (x / size.width * 2 * math.pi)) * 8;
      double shakeWave = math.sin((waveValue * 6 * math.pi) + (x / 20)) * sloshForce;
      path.lineTo(x, fillHeight + baseWave + shakeWave); 
    }

    path.lineTo(size.width + overflow, size.height + overflow);
    path.lineTo(-overflow, size.height + overflow);
    path.close();

    canvas.drawPath(path, paint);
    
    // Surface Reflection Line
    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, rimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── SUPPORTING COMPONENTS (Unchanged) ────────────────────────────────────────
class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Container(decoration: const BoxDecoration(color: Color(0xFF09090B)))),
        _blob(80, -60, 250, Colors.blue.withOpacity(0.4)),
        _blob(250, null, 220, Colors.purple.withOpacity(0.3), right: -60),
        _blob(null, 40, 200, Colors.pink.withOpacity(0.3), bottom: 20),
      ],
    );
  }

  // Renamed {double? r, double? b} to {double? right, double? bottom}
  Widget _blob(double? t, double? l, double s, Color c, {double? right, double? bottom}) {
    return Positioned(
      top: t,
      left: l,
      right: right,
      bottom: bottom,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: c, blurRadius: 100, spreadRadius: 40),
          ],
        ),
      ),
    );
  }
}
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        color: Colors.white.withOpacity(0.04)), child: child);
  }
}

class _FloatingLiquidGlassNavBar extends StatelessWidget {
  const _FloatingLiquidGlassNavBar();
  @override
  Widget build(BuildContext context) {
    return Align(alignment: Alignment.bottomCenter, child: Padding(
        padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
        child: OCLiquidGlassGroup(settings: const OCLiquidGlassSettings(refractStrength: -0.1, blurRadiusPx: 3.0),
          child: OCLiquidGlass(width: double.infinity, height: 75, borderRadius: 38, color: Colors.white.withOpacity(0.08),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                const Icon(Icons.grid_view_rounded, size: 26, color: Colors.white),
                const Icon(Icons.explore_rounded, size: 26, color: Colors.white38),
                Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.black, size: 28)),
                const Icon(Icons.history_rounded, size: 26, color: Colors.white38),
                const Icon(Icons.person_rounded, size: 26, color: Colors.white38),
              ])))));
  }
}
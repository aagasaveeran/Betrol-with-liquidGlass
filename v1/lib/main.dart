import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

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
        fontFamily: 'SF Pro Display', // Will fallback to default if not in pubspec
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
  // Fuel amount now tracks exact liters (0.0 to 5.0 Max)
  double _fuelAmount = 2.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── Layer 1: Background ──────────────────────────────────────────
          const _BackgroundLayer(),

          // ── Layer 2: Main Content ────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                
                // THE 3D PETROL ORB
                const SizedBox(height: 10),
                FuelOrb(fuelAmount: _fuelAmount),
                
                // RANGE TEXT UNDER ORB
                const SizedBox(height: 15),
                Text(
                  "Range : ${(_fuelAmount * 45).toInt()} kms", // Assuming 45km per Liter
                  style: const TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    fontFamily: 'Impact', // Use Impact or keep SF Pro with w900
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 15),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 150),
                    children: [
                      const Text(
                        "Activity History",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 16),
                      _buildTripTile("Office ➝ Home", "4.8 km", "-0.1 L", Colors.blue),
                      _buildTripTile("Weekend Ride", "12.4 km", "-0.3 L", Colors.purple),
                      _buildRefuelTile("Shell Station", "₹150", "+1.5 L", Colors.amber), // Adjusted for 5L tank demo
                      _buildTripTile("Gym ➝ Cafe", "2.1 km", "-0.05 L", Colors.pink),
                      
                      // ── Real-time Control ──
                      const SizedBox(height: 20),
                      const Text("ADJUST FUEL LEVEL (DEMO: 0L - 5L)", 
                        style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)),
                      Slider(
                        value: _fuelAmount,
                        min: 0.0,
                        max: 5.0,
                        activeColor: Colors.amber,
                        inactiveColor: Colors.white10,
                        onChanged: (val) => setState(() => _fuelAmount = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Layer 3: Nav Bar ─────────────────────────────────────────────
          const _FloatingLiquidGlassNavBar(),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---
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

// ── FUEL ORB WIDGET ──────────────────────────────────────────────────────────
class FuelOrb extends StatefulWidget {
  final double fuelAmount;
  final double size;
  const FuelOrb({super.key, required this.fuelAmount, this.size = 250});

  @override
  State<FuelOrb> createState() => _FuelOrbState();
}

class _FuelOrbState extends State<FuelOrb> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2)
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OCLiquidGlassGroup(
      settings: const OCLiquidGlassSettings(
        refractStrength: -0.2, 
        blurRadiusPx: 0.5,
        specStrength: 55.0,
        specPower: 40.0,
        lightbandStrength: 0.8,
      ),
      child: OCLiquidGlass(
        width: widget.size,
        height: widget.size,
        borderRadius: widget.size / 2,
        color: Colors.white.withOpacity(0.02),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. LIQUID LAYER
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  // Isolate the decimal part for the 1-liter fill effect
                  double fraction = widget.fuelAmount % 1.0;
                  
                  // Force full visual if resting exactly on a whole liter (e.g., 2.0L)
                  if (widget.fuelAmount > 0 && fraction == 0.0) {
                    fraction = 1.0;
                  }

                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _LiquidPainter(
                      waveValue: _waveController.value,
                      fillLevel: fraction, 
                    ),
                  );
                },
              ),

              // 2. MASSIVE BOLD TEXT LAYER
              Text(
                widget.fuelAmount.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: widget.size * 0.45, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.0,
                  height: 1.0,
                  color: Colors.white.withOpacity(0.95), 
                  shadows: const [
                    Shadow(
                      color: Colors.black54, 
                      blurRadius: 15, 
                      offset: Offset(0, 4)
                    ),
                  ]
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double waveValue;
  final double fillLevel;

  _LiquidPainter({required this.waveValue, required this.fillLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFD700).withOpacity(0.9), // Bright surface
          const Color(0xFFEAB308),                  // Core color
          const Color(0xFF451A03),                  // Dark base
        ],
      ).createShader(Offset.zero & size);

    final path = Path();
    
    // Calculate the Y coordinate based on fuel level
    final fillHeight = size.height * (1 - fillLevel);

    // Start drawing the sloshing top edge
    path.moveTo(0, fillHeight);
    for (double x = 0; x <= size.width; x++) {
      double sine = math.sin((waveValue * 2 * math.pi) + (x / size.width * 2 * math.pi));
      path.lineTo(x, fillHeight + (sine * 8)); 
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
    
    // Glossy rim
    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── SUPPORTING UI COMPONENTS ────────────────────────────────────────────────
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

  Widget _blob(double? top, double? left, double size, Color color, {double? right, double? bottom}) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: color, blurRadius: 100, spreadRadius: 40),
        ]),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        color: Colors.white.withOpacity(0.04),
      ),
      child: child,
    );
  }
}

class _FloatingLiquidGlassNavBar extends StatelessWidget {
  const _FloatingLiquidGlassNavBar();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
        child: OCLiquidGlassGroup(
          settings: const OCLiquidGlassSettings(refractStrength: -0.1, blurRadiusPx: 3.0),
          child: OCLiquidGlass(
            width: double.infinity,
            height: 75,
            borderRadius: 38,
            color: Colors.white.withOpacity(0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.grid_view_rounded, size: 26, color: Colors.white),
                const Icon(Icons.explore_rounded, size: 26, color: Colors.white38),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.black, size: 28),
                ),
                const Icon(Icons.history_rounded, size: 26, color: Colors.white38),
                const Icon(Icons.person_rounded, size: 26, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
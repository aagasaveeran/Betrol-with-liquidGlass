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
  double _fuelAmount = 2.5; // Liter amount (0.0 to 5.0)

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
                // THE SUBMERGED ORB
                FuelOrb(fuelAmount: _fuelAmount),
                
                const SizedBox(height: 15),
                Text(
                  "Range : ${(_fuelAmount * 45).toInt()} kms",
                  style: const TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    fontFamily: 'Impact',
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
                      _buildRefuelTile("Shell Station", "₹150", "+1.5 L", Colors.amber),
                      
                      const SizedBox(height: 20),
                      const Text("ADJUST FUEL LEVEL (0L - 5L)", 
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
          const _FloatingLiquidGlassNavBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Aagasaveeran", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800 , fontFamily: 'googleSans')),
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

// ── REFINED FUEL ORB (SUBMERGED TEXT LOGIC) ──────────────────────────────────
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
        refractStrength: -0.25, // Stronger refraction to warp the submerged text
        blurRadiusPx: 0.8,
        specStrength: 65.0,
        specPower: 35.0,
        lightbandStrength: 0.9,
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
              // LAYER 1: THE TEXT (Bottom - will be drowned)
              Text(
                widget.fuelAmount.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: widget.size * 0.48, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.0,
                  color: Colors.white.withOpacity(0.9),
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 15),
                  ],
                ),
              ),

              // LAYER 2: THE LIQUID (Top - washes over text)
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  double fraction = widget.fuelAmount % 1.0;
                  if (widget.fuelAmount > 0 && fraction == 0.0) fraction = 1.0;

                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _SubmergedLiquidPainter(
                      waveValue: _waveController.value,
                      fillLevel: fraction, 
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmergedLiquidPainter extends CustomPainter {
  final double waveValue;
  final double fillLevel;

  _SubmergedLiquidPainter({required this.waveValue, required this.fillLevel});

  @override
  void paint(Canvas canvas, Size size) {
    // Semi-transparent liquid so text "drowns" but is still visible
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color.fromARGB(255, 214, 189, 44).withOpacity(0.65), // Surface
          const Color.fromARGB(255, 234, 178, 8).withOpacity(0.70), // Mid
          const Color.fromARGB(255, 155, 94, 4).withOpacity(0.80), // Deep
        ],
      ).createShader(Offset.zero & size);

    final path = Path();
    final fillHeight = size.height * (1 - fillLevel);

    path.moveTo(0, fillHeight);
    for (double x = 0; x <= size.width; x++) {
      double sine = math.sin((waveValue * 2 * math.pi) + (x / size.width * 2 * math.pi));
      path.lineTo(x, fillHeight + (sine * 10)); // Dynamic sloshing
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
    
    // Highlight the "surface" line as it passes over the text
    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawPath(path, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── UI HELPERS ──────────────────────────────────────────────────────────────
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(Icons.grid_view_rounded, size: 26, color: Colors.white),
                Icon(Icons.explore_rounded, size: 26, color: Colors.white38),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.add, color: Colors.black),
                ),
                Icon(Icons.history_rounded, size: 26, color: Colors.white38),
                Icon(Icons.person_rounded, size: 26, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
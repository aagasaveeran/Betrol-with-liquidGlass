import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import 'package:sensors_plus/sensors_plus.dart';

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
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset('shaders/fuel_slosh.frag');
    setState(() => _program = program);
  }

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
                if (_program == null)
                  const SizedBox(height: 230, child: Center(child: CircularProgressIndicator()))
                else
                  FuelOrb(fuelLevel: _fuelLevel, program: _program!),
                const SizedBox(height: 15),
                _buildFuelStats(),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 150),
                    children: [
                      const Text("Activity History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildTripTile("Office ➝ Home", "4.8 km", "-0.09 L", Colors.blue),
                      _buildTripTile("Weekend Ride", "12.4 km", "-0.25 L", Colors.purple),
                      _buildRefuelTile("Shell Station", "₹200", "+2.2 L", Colors.amber),
                      const SizedBox(height: 20),
                      Slider(
                        value: _fuelLevel,
                        activeColor: Colors.amber,
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Good Afternoon", style: TextStyle(fontSize: 14, color: Colors.white54)),
            Text("Aagasaveeran", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          ]),
          CircleAvatar(radius: 25, backgroundColor: Colors.white10, child: const Text("AG")),
        ],
      ),
    );
  }

  Widget _buildFuelStats() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _statColumn("LITERS", "${(_fuelLevel * 10).toStringAsFixed(1)}L"),
      Container(width: 1, height: 30, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 30)),
      _statColumn("RANGE", "${(_fuelLevel * 450).toInt()} KM"),
    ]);
  }

  Widget _statColumn(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1.5)),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    ]);
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

class FuelOrb extends StatefulWidget {
  final double fuelLevel;
  final ui.FragmentProgram program;
  final double size;
  const FuelOrb({super.key, required this.fuelLevel, required this.program, this.size = 230});

  @override
  State<FuelOrb> createState() => _FuelOrbState();
}

class _FuelOrbState extends State<FuelOrb> with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription? _accelSubscription;
  
  double _targetX = 0.0;
  double _targetY = 9.8;

  double _currentX = 0.0;
  double _currentY = 9.8;
  double _velX = 0.0;
  double _velY = 0.0;

  @override
  void initState() {
    super.initState();
    
    _ticker = AnimationController(vsync: this, duration: const Duration(days: 365))
      ..addListener(_updatePhysics)
      ..forward();
      
    _accelSubscription = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      
      // Z-Axis Gimbal Lock Fix: When phone is flat on a table (Z is near 9.8),
      // X and Y are near 0. This causes rapid, uncontrollable spinning.
      // We blend the gravity to a safe upright vector (0, 9.8) based on how flat it is.
      double flatFactor = (event.z.abs() / 9.8).clamp(0.0, 1.0);
      double safeX = event.x * (1.0 - flatFactor) + 0.0 * flatFactor;
      double safeY = event.y * (1.0 - flatFactor) + 9.8 * flatFactor;

      _targetX = _targetX * 0.85 + safeX * 0.15;
      _targetY = _targetY * 0.85 + safeY * 0.15;
    });
  }

  void _updatePhysics() {
    // PHYSICS TUNED FOR REALISTIC, THICK LIQUID WITH LATENCY
    const double stiffness = 0.006; // Lower = much more latency, falls slowly
    const double damping = 0.96;    // Higher = thick fluid momentum, smooth resting

    double forceX = (_targetX - _currentX) * stiffness;
    double forceY = (_targetY - _currentY) * stiffness;

    _velX = (_velX + forceX) * damping;
    _velY = (_velY + forceY) * damping;

    _currentX += _velX;
    _currentY += _velY;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OCLiquidGlassGroup(
      settings: const OCLiquidGlassSettings(refractStrength: -0.25, blurRadiusPx: 0.5, specStrength: 60.0),
      child: OCLiquidGlass(
        width: widget.size,
        height: widget.size,
        borderRadius: widget.size / 2,
        color: Colors.white.withOpacity(0.02),
        child: ClipOval(
          child: AnimatedBuilder(
            animation: _ticker,
            builder: (context, _) {
              double tilt = math.atan2(_currentX, _currentY);
              double slosh = math.sqrt(_velX * _velX + _velY * _velY);
              double gForce = math.sqrt(_currentX * _currentX + _currentY * _currentY);
              

              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: ShaderPainter(
                  shader: widget.program.fragmentShader(),
                  fillLevel: widget.fuelLevel,
                  tilt: tilt,
                  time: DateTime.now().millisecondsSinceEpoch / 1000.0,
                  slosh: slosh,
                  gForce: gForce,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double fillLevel, tilt, time, slosh, gForce;

  ShaderPainter({
    required this.shader, 
    required this.fillLevel, 
    required this.tilt, 
    required this.time,
    required this.slosh,
    required this.gForce,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, fillLevel);
    shader.setFloat(3, tilt);
    shader.setFloat(4, time);
    shader.setFloat(5, slosh);     
    shader.setFloat(6, gForce); 
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) => true;
}

class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer();
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: Container(decoration: const BoxDecoration(color: Color(0xFF09090B)))),
      _blob(80, -60, 250, Colors.blue.withOpacity(0.4)),
      _blob(250, null, 220, Colors.purple.withOpacity(0.3), right: -60),
      _blob(null, 40, 200, Colors.pink.withOpacity(0.3), bottom: 20),
    ]);
  }
  Widget _blob(double? t, double? l, double s, Color c, {double? right, double? bottom}) {
    return Positioned(top: t, left: l, right: right, bottom: bottom,
      child: Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: c, blurRadius: 100, spreadRadius: 40),
      ])));
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10, width: 0.5),
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
          child: OCLiquidGlass(width: double.infinity, height: 75, borderRadius: 38, color: Colors.white10,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                const Icon(Icons.grid_view_rounded, size: 26, color: Colors.white),
                const Icon(Icons.explore_rounded, size: 26, color: Colors.white38),
                Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.black, size: 28)),
                const Icon(Icons.history_rounded, size: 26, color: Colors.white38),
                const Icon(Icons.person_rounded, size: 26, color: Colors.white38),
              ])))));
  }
}
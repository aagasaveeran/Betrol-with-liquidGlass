import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set transparent status bar for the edge-to-edge look
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
      title: 'Bike Fuel Agent',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF09090B),
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomeDashboard(),
    );
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── Layer 1: Background ──────────────────────────────────────────
          const _BackgroundLayer(),

          // ── Layer 2: Scrollable Content ───────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: _FuelHeroCard(),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 140),
                    children: [
                      const Text(
                        "Activity History",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildTripTile("Office ➝ Home", "4.8 km", "-0.09 L", Colors.blue),
                      _buildTripTile("Weekend Ride", "12.4 km", "-0.25 L", Colors.purple),
                      _buildRefuelTile("Shell Station", "₹200", "+2.2 L", Colors.amber),
                      _buildTripTile("Gym ➝ Cafe", "2.1 km", "-0.04 L", Colors.pink),
                      _buildTripTile("Cafe ➝ Home", "3.5 km", "-0.06 L", Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Layer 3: Liquid Glass Nav Bar ─────────────────────────────────
          const _FloatingLiquidGlassNavBar(),
        ],
      ),
    );
  }

  // UI Helpers
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Good Afternoon", style: TextStyle(fontSize: 15, color: Colors.white54)),
              Text("Aagasaveeran", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            ],
          ),
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFF1C1C1E),
            child: const Text("AG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTripTile(String title, String distance, String fuel, Color color) {
    return _BaseCard(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(Icons.motorcycle, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(distance, style: const TextStyle(color: Colors.white54)),
        trailing: Text(fuel, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRefuelTile(String station, String cost, String amount, Color color) {
    return _BaseCard(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(Icons.local_gas_station, color: color)),
        title: Text(station, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(cost, style: const TextStyle(color: Colors.white54)),
        trailing: Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

// ── Background with Animated Blobs ───────────────────────────────────────────
class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF59E0B)],
                stops: [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),
        _blob(80, -60, 220, Colors.teal),
        _blob(250, null, 200, Colors.indigo, right: -60),
        _blob(null, 40, 180, Colors.blue, bottom: 20),
        _blob(null, null, 200, Colors.amber, bottom: 0, right: 20),
      ],
    );
  }

  Widget _blob(double? top, double? left, double size, Color color, {double? right, double? bottom}) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 80, spreadRadius: 30)],
        ),
      ),
    );
  }
}

// ── Common Card Structure ───────────────────────────────────────────────────
class _BaseCard extends StatelessWidget {
  final Widget child;
  final double height;
  const _BaseCard({required this.child, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        color: Colors.white.withOpacity(0.05),
      ),
      child: child,
    );
  }
}

// ── Fuel Hero Card ──────────────────────────────────────────────────────────
class _FuelHeroCard extends StatelessWidget {
  const _FuelHeroCard();

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            SizedBox(
              width: 130, height: 130,
              child: CircularProgressIndicator(
                value: 0.65, strokeWidth: 10, strokeCap: StrokeCap.round,
                backgroundColor: Colors.white10, color: Colors.white,
              ),
            ),
            const SizedBox(width: 24),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("EST. RANGE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54)),
                Text("1.1 Liters", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                Text("50 km/L avg.", style: TextStyle(color: Colors.amber, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── THE REFACTORED NAV BAR (Using Package) ──────────────────────────────────
class _FloatingLiquidGlassNavBar extends StatelessWidget {
  const _FloatingLiquidGlassNavBar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30.0, left: 24, right: 24),
        child: OCLiquidGlassGroup(
          settings: const OCLiquidGlassSettings(
            refractStrength: -0.12, // High refraction for "magnification" look
            blurRadiusPx: 4.0,       // Frosted glass effect
            specStrength: 40.0,      // Sharp highlights
          ),
          child: OCLiquidGlass(
            width: double.infinity,
            height: 80,
            borderRadius: 40,
            color: Colors.white.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.grid_view_rounded, size: 28),
                const Icon(Icons.explore_rounded, color: Colors.white38),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const Icon(Icons.history_rounded, color: Colors.white38),
                const Icon(Icons.person_rounded, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
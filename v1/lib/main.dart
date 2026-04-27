import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import 'services/fuel_logic_service.dart';
import 'pages/history_page.dart';

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
  final FuelLogicService _fuelService = FuelLogicService();
  double _fuelAmount = 2.5; 
  bool _isRiding = false;
  List<TripRecord> _tripHistory = [];
  
  double _currentSpeed = 0.0;
  double _sessionDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAgent();
  }

  // ── CORE INITIALIZATION ──

  void _initializeAgent() async {
    final savedFuel = await _fuelService.loadFuelLevel();
    final savedHistory = await _fuelService.loadHomeHistory();
    
    if (mounted) {
      setState(() {
        _fuelAmount = savedFuel;
        _tripHistory = savedHistory;
      });
    }

    final granted = await _fuelService.requestPermissions();
    if (granted) _setupTracking();
  }

  void _setupTracking() {
    _fuelService.ridingStream.listen((riding) async {
      if (mounted) setState(() => _isRiding = riding);
      _fuelService.startDistanceTracking(riding);

      // Refresh list only when a ride ends
      if (!riding) {
        await Future.delayed(const Duration(milliseconds: 500));
        _refreshHistory();
      }
    });

    _fuelService.consumptionStream.listen((litersConsumed) {
      _updateFuelLevel(_fuelAmount - litersConsumed);
    });

    _fuelService.rideStatsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _currentSpeed = stats["speed"] ?? 0.0;
          _sessionDistance = stats["distance"] ?? 0.0;
        });
      }
    });
  }

  // ── STATE UPDATERS ──

  Future<void> _refreshHistory() async {
    final updated = await _fuelService.loadHomeHistory();
    if (mounted) setState(() => _tripHistory = updated);
  }

  void _updateFuelLevel(double newLevel) {
    if (!mounted) return;
    double clamped = newLevel.clamp(0.0, 5.0);
    setState(() => _fuelAmount = clamped);
    _fuelService.saveFuelLevel(clamped);
  }

void _onDismissTrip(String id) {
    // 1. Remove from local UI list immediately to prevent red screen
    setState(() {
      _tripHistory.removeWhere((trip) => trip.id == id);
    });

    // 2. Update the background storage
    _fuelService.dismissTripFromHome(id).then((_) {
      // Optional: verify sync, but usually not needed if local removal worked
      _refreshHistory();
    });
  }  // ── REFUEL LOGIC ──

  void _showRefuelSheet() {
    double litersToAdd = 1.0;
    const double petrolRate = 101.5;
    final costController = TextEditingController(text: "102");

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder( // Use sheetContext for pop
        builder: (context, setSheetState) {
          void update(double l) {
            setSheetState(() {
              litersToAdd = l;
              costController.text = (l * petrolRate).toInt().toString();
            });
          }

          return OCLiquidGlassGroup(
            settings: const OCLiquidGlassSettings(blurRadiusPx: 6.0, refractStrength: -0.2),
            child: OCLiquidGlass(
              width: double.infinity, height: 530, borderRadius: 32,
              color: Colors.white.withOpacity(0.08),
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 24, right: 24, top: 20),
                child: Column(
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 30),
                    Wrap(
                      spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                      children: [
                        _buildQuickBtn("₹30", () => update(30 / petrolRate), Colors.redAccent),
                        _buildQuickBtn("1 LTR", () => update(1.0), Colors.amber),
                        _buildQuickBtn("2 LTR", () => update(2.0), Colors.amber),
                        _buildQuickBtn("₹100", () => update(100 / petrolRate), Colors.blueAccent),
                        _buildQuickBtn("₹150", () => update(150 / petrolRate), Colors.greenAccent),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text("${litersToAdd.toStringAsFixed(2)} L", style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.amber)),
                    Slider(
                      value: litersToAdd.clamp(0.0, 5.0), min: 0.0, max: 5.0, activeColor: Colors.amber,
                      onChanged: (val) => update(val),
                    ),
                    TextField(
                      controller: costController, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                      decoration: const InputDecoration(prefixText: "TOTAL: ₹ ", border: InputBorder.none),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'Impact'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
onPressed: () async {
                      double finalCost = double.tryParse(costController.text) ?? 0.0;
                      if (finalCost < 30) return;

                      // 1. Close the sheet immediately
                      Navigator.pop(sheetContext);

                      // 2. Log to service and GET the new record back
                      TripRecord newRecord = await _fuelService.logRefuel(litersToAdd, finalCost);
                      
                      // 3. Update the global state directly
                      if (mounted) {
                        setState(() {
                          // Update Fuel Level
                          _fuelAmount = (_fuelAmount + litersToAdd).clamp(0.0, 5.0);
                          
                          // Manually insert at the top of the list for instant feedback
                          _tripHistory.insert(0, newRecord);
                        });
                      }
                      
                      // 4. Save the fuel level to persistent storage in background
                      _fuelService.saveFuelLevel(_fuelAmount);
                    },
                      child: const Text("CONFIRM FILL", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
                FuelOrb(fuelAmount: _fuelAmount),
                AnimatedOpacity(
                  opacity: _isRiding ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Visibility(
                    visible: _isRiding,
                    child: Padding(padding: const EdgeInsets.only(top: 20), child: _buildLiveHUD()),
                  ),
                ),
                const SizedBox(height: 15),
                _buildStatusChip(),
                Text("Range : ${(_fuelAmount * 45).toInt()} kms", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Impact', letterSpacing: 1.2)),
                const SizedBox(height: 15),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 150),
                    children: [
                      const Text("Recent Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      const SizedBox(height: 16),
                      if (_tripHistory.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text("No records found", style: TextStyle(color: Colors.white24, fontSize: 12)))),

                      ..._tripHistory.map((trip) => Dismissible(
                        key: Key(trip.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _onDismissTrip(trip.id),
                        background: Container(
                          alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 25), margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
                          child: const Icon(Icons.visibility_off_rounded, color: Colors.redAccent),
                        ),
                        child: trip.isRefuel 
                          ? _buildRefuelTile(trip.title, trip.distance, trip.fuelConsumed, Color(trip.colorValue), trip.dateTime)
                          : _buildTripTile(trip.title, trip.distance, trip.fuelConsumed, Color(trip.colorValue), trip.dateTime),
                      )),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        _FloatingLiquidGlassNavBar(
          onRefuelTap: _showRefuelSheet,
          onHistoryTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryPage(service: _fuelService),
              ),
            ).then((_) => _refreshHistory()); // Refresh home history when coming back
          },
        ),        ],
      ),
    );
  }

  // ── UI COMPONENTS ──

  Widget _buildLiveHUD() {
    return OCLiquidGlassGroup(
      settings: const OCLiquidGlassSettings(blurRadiusPx: 2.0, refractStrength: -0.1),
      child: OCLiquidGlass(
        width: 240, height: 70, borderRadius: 20, color: Colors.white.withOpacity(0.05),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _buildStatItem("${_currentSpeed.toInt()}", "KM/H", Colors.greenAccent),
          Container(width: 1, height: 30, color: Colors.white10),
          _buildStatItem(_sessionDistance.toStringAsFixed(2), "TRIP KM", Colors.white),
        ]),
      ),
    );
  }

  Widget _buildStatItem(String val, String label, Color color) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white54)),
    ]);
  }

  Widget _buildTripTile(String t, String d, String f, Color c, DateTime dt) => _GlassCard(
    child: ListTile(
      leading: CircleAvatar(backgroundColor: c.withOpacity(0.15), child: Icon(Icons.motorcycle, color: c, size: 20)),
      title: Text("$t • ${_getMonth(dt.month)} ${dt.day}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(d, style: const TextStyle(fontSize: 12, color: Colors.white38)),
      trailing: Text(f, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
    ),
  );

  Widget _buildRefuelTile(String s, String c, String a, Color col, DateTime dt) => _GlassCard(
    child: ListTile(
      leading: CircleAvatar(backgroundColor: col.withOpacity(0.15), child: Icon(Icons.local_gas_station, color: col, size: 20)),
      title: Text("$s • ${_getMonth(dt.month)} ${dt.day}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(c, style: const TextStyle(fontSize: 12, color: Colors.white38)),
      trailing: Text(a, style: TextStyle(fontWeight: FontWeight.bold, color: col)),
    ),
  );

  String _getMonth(int m) => ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m];

  Widget _buildQuickBtn(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _isRiding ? Colors.green.withOpacity(0.2) : Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: _isRiding ? Colors.green : Colors.white24, width: 0.5)),
      child: Text(_isRiding ? "• AGENT ACTIVE: RIDING" : "• AGENT IDLE", style: TextStyle(color: _isRiding ? Colors.green : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onLongPress: () {
        bool mockState = !_isRiding;
        setState(() {
          _isRiding = mockState;
          _currentSpeed = mockState ? 42.0 : 0.0;
        });
        _fuelService.startDistanceTracking(mockState);
        if (mockState) _updateFuelLevel(_fuelAmount - 0.1);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 15.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Aagasaveeran", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            CircleAvatar(radius: 25, backgroundColor: Colors.white.withOpacity(0.05), child: const Text("AG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}

// ── FULL HISTORY PAGE ──

class HistoryPage extends StatelessWidget {
  final FuelLogicService service;
  const HistoryPage({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: const Text("AGENT LOGS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: FutureBuilder<List<TripRecord>>(
        future: service.loadAllHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
          final logs = snapshot.data!;
          if (logs.isEmpty) return const Center(child: Text("No records found", style: TextStyle(color: Colors.white24)));

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: logs.length,
            itemBuilder: (context, i) {
              final trip = logs[i];
              return Opacity(
                opacity: trip.isHiddenOnHome ? 0.4 : 1.0,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
                  child: ListTile(
                    leading: Icon(trip.isRefuel ? Icons.local_gas_station : Icons.motorcycle, color: Color(trip.colorValue)),
                    title: Text("${trip.title} • ${trip.dateTime.day}/${trip.dateTime.month}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(trip.distance, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: Text(trip.fuelConsumed, style: TextStyle(fontWeight: FontWeight.w900, color: trip.isRefuel ? Colors.amber : Colors.white70)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── FUEL ORB ──

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
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() { _waveController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return OCLiquidGlassGroup(
      settings: const OCLiquidGlassSettings(refractStrength: -0.25, blurRadiusPx: 0.8, specStrength: 65.0, specPower: 35.0, lightbandStrength: 0.9),
      child: OCLiquidGlass(
        width: widget.size, height: widget.size, borderRadius: widget.size / 2, color: Colors.white.withOpacity(0.02),
        child: ClipOval(
          child: Stack(alignment: Alignment.center, children: [
            Text(widget.fuelAmount.toStringAsFixed(1), style: TextStyle(fontSize: widget.size * 0.40, fontWeight: FontWeight.w900, letterSpacing: -2.0, color: Colors.white.withOpacity(0.9))),
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                double fraction = widget.fuelAmount % 1.0;
                if (widget.fuelAmount > 0 && fraction == 0.0) fraction = 1.0;
                return CustomPaint(size: Size(widget.size, widget.size), painter: _SubmergedPainter(waveValue: _waveController.value, fillLevel: fraction));
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _SubmergedPainter extends CustomPainter {
  final double waveValue;
  final double fillLevel;
  _SubmergedPainter({required this.waveValue, required this.fillLevel});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFFFFD700).withOpacity(0.6), const Color(0xFFEAB308).withOpacity(0.7), const Color(0xFF451A03).withOpacity(0.8)]).createShader(Offset.zero & size);
    final path = Path();
    final fillHeight = size.height * (1 - fillLevel);
    path.moveTo(0, fillHeight);
    for (double x = 0; x <= size.width; x++) {
      double sine = math.sin((waveValue * 2 * math.pi) + (x / size.width * 2 * math.pi));
      path.lineTo(x, fillHeight + (sine * 10));
    }
    path.lineTo(size.width, size.height); path.lineTo(0, size.height); path.close();
    canvas.drawPath(path, paint);
    final rimPaint = Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 3.0;
    canvas.drawPath(path, rimPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── UI HELPERS ──

class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer();
  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: Container(color: const Color(0xFF09090B))),
    _blob(80, -60, 250, Colors.blue.withOpacity(0.4)),
    _blob(250, null, 220, Colors.purple.withOpacity(0.3), right: -60),
    _blob(null, 40, 200, Colors.pink.withOpacity(0.3), bottom: 20),
  ]);
  Widget _blob(double? t, double? l, double s, Color c, {double? right, double? bottom}) => Positioned(
    top: t, left: l, right: right, bottom: bottom,
    child: Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: c, blurRadius: 100, spreadRadius: 40)])),
  );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.08)), color: Colors.white.withOpacity(0.04)), child: child);
}

class _FloatingLiquidGlassNavBar extends StatelessWidget {
  final VoidCallback onRefuelTap;
  final VoidCallback onHistoryTap;
  const _FloatingLiquidGlassNavBar({required this.onRefuelTap, required this.onHistoryTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
        child: OCLiquidGlassGroup(
          settings: const OCLiquidGlassSettings(refractStrength: -0.1, blurRadiusPx: 3.0),
          child: OCLiquidGlass(
            width: double.infinity, height: 75, borderRadius: 38, color: Colors.white.withOpacity(0.08),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              const Icon(Icons.grid_view_rounded, size: 26, color: Colors.white38),
              const Icon(Icons.explore_rounded, size: 26, color: Colors.white38),
              GestureDetector(onTap: onRefuelTap, child: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.add, color: Colors.black))),
              GestureDetector(onTap: onHistoryTap, child: const Icon(Icons.history_rounded, size: 26, color: Colors.white)),
              const Icon(Icons.person_rounded, size: 26, color: Colors.white38),
            ]),
          ),
        ),
      ),
    );
  }
}
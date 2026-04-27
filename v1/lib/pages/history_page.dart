import 'package:flutter/material.dart';
import '../services/fuel_logic_service.dart';

class HistoryPage extends StatelessWidget {
  final FuelLogicService service;
  const HistoryPage({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: const Text(
          "AGENT LOGS",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<TripRecord>>(
        future: service.loadAllHistory(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          // 2. Error State
          if (snapshot.hasError) {
            return const Center(
              child: Text("Error loading logs. Try restarting.",
                  style: TextStyle(color: Colors.redAccent)),
            );
          }

          final logs = snapshot.data ?? [];

          // 3. Empty State
          if (logs.isEmpty) {
            return const Center(
              child: Text("No records found", style: TextStyle(color: Colors.white24)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
            itemCount: logs.length,
            itemBuilder: (context, i) {
              final trip = logs[i];
              return Opacity(
                opacity: trip.isHiddenOnHome ? 0.3 : 1.0, // Faded if hidden from home
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    leading: Icon(
                      trip.isRefuel ? Icons.local_gas_station : Icons.motorcycle,
                      color: Color(trip.colorValue),
                    ),
                    title: Text(
                      "${trip.title} • ${trip.dateTime.day} ${_getMonth(trip.dateTime.month)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(trip.distance,
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: Text(
                      trip.fuelConsumed,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: trip.isRefuel ? Colors.amber : Colors.white70,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getMonth(int m) =>
      ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m];
}
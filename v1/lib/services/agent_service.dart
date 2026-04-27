import '../services/fuel_logic_service.dart';

class AgentService {
  /// Analyzes trip history to generate a "Brain Snapshot"
  String getPersona(List<TripRecord> history) {
    if (history.isEmpty) return "I'm monitoring your patterns. Start riding to get insights.";
    
    // Simple logic: Calculate total distance to determine "Persona"
    double totalKm = 0;
    for (var trip in history) {
      // Stripping " km" from the string to get the double
      totalKm += double.tryParse(trip.distance.split(' ')[0]) ?? 0.0;
    }

    if (totalKm > 50) return "You're a Long-Haul Rider. I'll prioritize range-saving tips.";
    if (totalKm > 10) return "Urban Commuter detected. Watch those idle times at signals.";
    return "Initial patterns analyzed. Let's optimize your short sprints.";
  }

  /// Placeholder for GenAI integration (Phase 4)
  Future<String> getGenAIInsight(List<TripRecord> history) async {
    // We will connect this to an LLM (Gemini/Groq/FastAPI) next
    return "I've noticed your fuel consumption is 5% better than last week. Keep it smooth.";
  }
}
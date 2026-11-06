import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../models/charger_model.dart';
import '../models/booking_model.dart';

class HostEarningsData {
  final int totalEarnings; // paise
  final int pendingPayout; // paise
  final int completedSessions;
  final int activeChargers;
  final List<BookingModel> recentBookings;

  HostEarningsData({
    required this.totalEarnings,
    required this.pendingPayout,
    required this.completedSessions,
    required this.activeChargers,
    required this.recentBookings,
  });

  double get totalEarningsRupees => totalEarnings / 100.0;
  double get pendingPayoutRupees => pendingPayout / 100.0;
}

class AiListingSuggestion {
  final String description;
  final double suggestedPriceMin;
  final double suggestedPriceMax;

  AiListingSuggestion({
    required this.description,
    required this.suggestedPriceMin,
    required this.suggestedPriceMax,
  });
}

class HostRepository {
  final ApiClient _apiClient;

  HostRepository(this._apiClient);

  Future<HostEarningsData> getHostEarnings() async {
    final res = await _apiClient.dio.get('/host/earnings');
    final data = res.data as Map<String, dynamic>;
    final recent = (data['recent_bookings'] as List<dynamic>?)
            ?.map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return HostEarningsData(
      totalEarnings: data['total_earnings'] as int? ?? 0,
      pendingPayout: data['pending_payout'] as int? ?? 0,
      completedSessions: data['completed_sessions'] as int? ?? 0,
      activeChargers: data['active_chargers'] as int? ?? 0,
      recentBookings: recent,
    );
  }

  Future<List<ChargerModel>> getHostChargers() async {
    final res = await _apiClient.dio.get('/host/chargers');
    return (res.data as List<dynamic>)
        .map((e) => ChargerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AiListingSuggestion> generateAiListing({
    required String location,
    required String connectorType,
    required double powerKw,
    List<String> amenities = const [],
  }) async {
    final res = await _apiClient.dio.post(
      '/ai/listing',
      data: {
        'location': location,
        'connector_type': connectorType,
        'power_kw': powerKw,
        'amenities': amenities,
      },
    );
    final data = res.data as Map<String, dynamic>;
    return AiListingSuggestion(
      description: data['description'] as String,
      suggestedPriceMin: (data['suggested_price_min'] as num).toDouble(),
      suggestedPriceMax: (data['suggested_price_max'] as num).toDouble(),
    );
  }
}

final hostRepositoryProvider = Provider<HostRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HostRepository(client);
});


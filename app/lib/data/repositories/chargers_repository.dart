import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../models/charger_model.dart';
import '../local_db.dart';

class ChargersRepository {
  final ApiClient _apiClient;

  ChargersRepository(this._apiClient);

  Future<List<ChargerModel>> searchChargers({
    double lat = 28.6139,
    double lng = 77.2090,
    double radiusKm = 50.0,
    String? connectorType,
    double? minPowerKw,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
      };
      if (connectorType != null && connectorType.isNotEmpty) {
        queryParams['connector_type'] = connectorType;
      }
      if (minPowerKw != null && minPowerKw > 0) {
        queryParams['min_power_kw'] = minPowerKw;
      }

      final res = await _apiClient.dio.get('/chargers', queryParameters: queryParams);
      final list = (res.data as List<dynamic>)
          .map((e) => ChargerModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache locally for offline viewing
      await localDb.cacheChargers(list);
      return list;
    } catch (e) {
      // Fallback to offline cached chargers
      final cached = await localDb.getCachedChargers();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<ChargerModel> getChargerDetail(int id) async {
    final res = await _apiClient.dio.get('/chargers/$id');
    return ChargerModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ChargerModel> createCharger({
    required String title,
    String? description,
    required double lat,
    required double lng,
    required String address,
    required String connectorType,
    required double powerKw,
    required double pricePerKwh,
    double? pricePerHour,
    List<AvailabilitySlot> availability = const [],
  }) async {
    final res = await _apiClient.dio.post(
      '/chargers',
      data: {
        'title': title,
        'description': description,
        'lat': lat,
        'lng': lng,
        'address': address,
        'connector_type': connectorType,
        'power_kw': powerKw,
        'price_per_kwh': pricePerKwh,
        'price_per_hour': pricePerHour,
        'availability': availability.map((a) => a.toJson()).toList(),
      },
    );
    return ChargerModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ChargerModel> updateCharger(int id, Map<String, dynamic> data) async {
    final res = await _apiClient.dio.put('/chargers/$id', data: data);
    return ChargerModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> setAvailability(int chargerId, List<AvailabilitySlot> slots) async {
    await _apiClient.dio.put(
      '/chargers/$chargerId/availability',
      data: slots.map((s) => s.toJson()).toList(),
    );
  }

  Future<List<String>> uploadPhoto(int chargerId, List<int> imageBytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: filename),
    });
    final res = await _apiClient.dio.post('/chargers/$chargerId/photos', data: formData);
    final photos = (res.data['photos'] as List<dynamic>).map((e) => e.toString()).toList();
    return photos;
  }
}

final chargersRepositoryProvider = Provider<ChargersRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ChargersRepository(client);
});


import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../models/booking_model.dart';
import '../local_db.dart';

class PricePreviewResult {
  final int amount;
  final int commission;
  final int hostPayout;
  final double hours;

  PricePreviewResult({
    required this.amount,
    required this.commission,
    required this.hostPayout,
    required this.hours,
  });

  double get amountRupees => amount / 100.0;
}

class CancelResult {
  final String status;
  final int refundAmount;
  final int refundPercent;
  final String message;

  CancelResult({
    required this.status,
    required this.refundAmount,
    required this.refundPercent,
    required this.message,
  });

  double get refundRupees => refundAmount / 100.0;
}

class BookingsRepository {
  final ApiClient _apiClient;

  BookingsRepository(this._apiClient);

  Future<PricePreviewResult> previewPrice({
    required int chargerId,
    required int startTs,
    required int endTs,
  }) async {
    final res = await _apiClient.dio.post(
      '/bookings/preview',
      data: {
        'charger_id': chargerId,
        'start_ts': startTs,
        'end_ts': endTs,
      },
    );
    final data = res.data as Map<String, dynamic>;
    return PricePreviewResult(
      amount: data['amount'] as int,
      commission: data['commission'] as int,
      hostPayout: data['host_payout'] as int,
      hours: (data['hours'] as num).toDouble(),
    );
  }

  Future<BookingModel> createBooking({
    required int chargerId,
    required int startTs,
    required int endTs,
  }) async {
    final res = await _apiClient.dio.post(
      '/bookings',
      data: {
        'charger_id': chargerId,
        'start_ts': startTs,
        'end_ts': endTs,
      },
    );
    return BookingModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<BookingModel>> getMyBookings({bool asHost = false}) async {
    try {
      final res = await _apiClient.dio.get(
        '/bookings/mine',
        queryParameters: {'as_host': asHost},
      );
      final list = (res.data as List<dynamic>)
          .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!asHost) {
        await localDb.cacheBookings(list);
      }
      return list;
    } catch (e) {
      if (!asHost) {
        final cached = await localDb.getCachedBookings();
        if (cached.isNotEmpty) {
          return cached;
        }
      }
      rethrow;
    }
  }

  Future<BookingModel> getBooking(int id) async {
    final res = await _apiClient.dio.get('/bookings/$id');
    return BookingModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CancelResult> cancelBooking(int id) async {
    final res = await _apiClient.dio.post('/bookings/$id/cancel');
    final data = res.data as Map<String, dynamic>;
    return CancelResult(
      status: data['status'] as String,
      refundAmount: data['refund_amount'] as int,
      refundPercent: data['refund_percent'] as int,
      message: data['message'] as String,
    );
  }

  Future<void> completeBooking(int id) async {
    await _apiClient.dio.post('/bookings/$id/complete');
  }

  Future<void> testConfirm(int id) async {
    await _apiClient.dio.post('/payments/test-confirm/$id');
  }
}

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return BookingsRepository(client);
});


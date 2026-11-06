import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../models/review_model.dart';

class ReviewsRepository {
  final ApiClient _apiClient;

  ReviewsRepository(this._apiClient);

  Future<ReviewModel> submitReview({
    required int bookingId,
    required int rating,
    String? comment,
  }) async {
    final res = await _apiClient.dio.post(
      '/reviews',
      data: {
        'booking_id': bookingId,
        'rating': rating,
        'comment': comment,
      },
    );
    return ReviewModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<ReviewModel>> getChargerReviews(int chargerId) async {
    final res = await _apiClient.dio.get('/reviews/charger/$chargerId');
    return (res.data as List<dynamic>)
        .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ReviewsRepository(client);
});


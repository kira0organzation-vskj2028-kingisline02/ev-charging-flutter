class ReviewModel {
  final int id;
  final int bookingId;
  final int rating;
  final String? comment;
  final String createdAt;
  final String? reviewerName;

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.reviewerName,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as int,
      bookingId: json['booking_id'] as int,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      reviewerName: json['reviewer_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt,
      'reviewer_name': reviewerName,
    };
  }
}


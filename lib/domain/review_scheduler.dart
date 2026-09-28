enum ReviewRating { impossible, hard, medium, easy }

extension ReviewRatingInterval on ReviewRating {
  Duration get delay => switch (this) {
        ReviewRating.impossible => const Duration(minutes: 3),
        ReviewRating.hard => const Duration(hours: 1),
        ReviewRating.medium => const Duration(days: 3),
        ReviewRating.easy => const Duration(days: 7),
      };
}

class ReviewState {
  const ReviewState({
    required this.rating,
    required this.sameRatingCount,
    required this.anchorMinutes,
    required this.intervalMinutes,
  });

  factory ReviewState.fromJson(Map<String, dynamic> json) => ReviewState(
        rating: ReviewRating.values.byName(json['rating'] as String),
        sameRatingCount: json['sameRatingCount'] as int,
        anchorMinutes: json['anchorMinutes'] as int,
        intervalMinutes: json['intervalMinutes'] as int,
      );

  final ReviewRating rating;
  final int sameRatingCount;
  final int anchorMinutes;
  final int intervalMinutes;

  Map<String, dynamic> toJson() => {
        'rating': rating.name,
        'sameRatingCount': sameRatingCount,
        'anchorMinutes': anchorMinutes,
        'intervalMinutes': intervalMinutes,
      };
}

ReviewState calculateNextReviewState(
  ReviewRating rating,
  ReviewState? previous,
) {
  final baseMinutes = rating.delay.inMinutes;
  if (previous == null) {
    return ReviewState(
      rating: rating,
      sameRatingCount: 1,
      anchorMinutes: 0,
      intervalMinutes: baseMinutes,
    );
  }

  if (rating == ReviewRating.impossible) {
    return const ReviewState(
      rating: ReviewRating.impossible,
      sameRatingCount: 1,
      anchorMinutes: 0,
      intervalMinutes: Duration.minutesPerDay,
    );
  }

  if (rating == previous.rating) {
    final count = previous.sameRatingCount + 1;
    return ReviewState(
      rating: rating,
      sameRatingCount: count,
      anchorMinutes: previous.anchorMinutes,
      intervalMinutes: previous.anchorMinutes + (baseMinutes * count),
    );
  }

  final anchorMinutes = switch (rating) {
    ReviewRating.hard => previous.intervalMinutes ~/ 3,
    ReviewRating.medium => previous.intervalMinutes ~/ 2,
    ReviewRating.easy => previous.intervalMinutes,
    ReviewRating.impossible => 0,
  };
  return ReviewState(
    rating: rating,
    sameRatingCount: 1,
    anchorMinutes: anchorMinutes,
    intervalMinutes: anchorMinutes + baseMinutes,
  );
}

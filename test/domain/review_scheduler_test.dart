import 'package:flutter_test/flutter_test.dart';
import 'package:learninator/domain/review_scheduler.dart';

void main() {
  test('first review ratings use the expected intervals', () {
    expect(ReviewRating.impossible.delay, const Duration(minutes: 3));
    expect(ReviewRating.hard.delay, const Duration(hours: 1));
    expect(ReviewRating.medium.delay, const Duration(days: 3));
    expect(ReviewRating.easy.delay, const Duration(days: 7));
  });

  test('ten consecutive easy ratings schedule 70 days', () {
    ReviewState? state;
    for (var review = 0; review < 10; review++) {
      state = calculateNextReviewState(ReviewRating.easy, state);
    }

    expect(state!.intervalMinutes, const Duration(days: 70).inMinutes);
  });

  test('easy streak keeps the previous interval as its anchor', () {
    const previous = ReviewState(
      rating: ReviewRating.hard,
      sameRatingCount: 2,
      anchorMinutes: Duration.minutesPerDay * 13 + Duration.minutesPerHour * 16,
      intervalMinutes:
          Duration.minutesPerDay * 13 + Duration.minutesPerHour * 18,
    );

    var state = calculateNextReviewState(ReviewRating.easy, previous);
    expect(state.intervalMinutes, const Duration(days: 20, hours: 18).inMinutes);

    state = calculateNextReviewState(ReviewRating.easy, state);
    expect(state.intervalMinutes, const Duration(days: 27, hours: 18).inMinutes);

    state = calculateNextReviewState(ReviewRating.easy, state);
    expect(state.intervalMinutes, const Duration(days: 34, hours: 18).inMinutes);
  });

  test('medium halves accumulated time and adds three days', () {
    const previous = ReviewState(
      rating: ReviewRating.easy,
      sameRatingCount: 10,
      anchorMinutes: 0,
      intervalMinutes: Duration.minutesPerDay * 70,
    );

    final state = calculateNextReviewState(ReviewRating.medium, previous);

    expect(state.intervalMinutes, const Duration(days: 38).inMinutes);
  });

  test('hard takes one third of accumulated time and adds one hour', () {
    const previous = ReviewState(
      rating: ReviewRating.easy,
      sameRatingCount: 9,
      anchorMinutes: 0,
      intervalMinutes: Duration.minutesPerDay * 63,
    );

    final state = calculateNextReviewState(ReviewRating.hard, previous);

    expect(state.intervalMinutes, const Duration(days: 21, hours: 1).inMinutes);
  });

  test('impossible starts at three minutes then resets to one day', () {
    final first = calculateNextReviewState(ReviewRating.impossible, null);
    final reset = calculateNextReviewState(ReviewRating.impossible, first);

    expect(first.intervalMinutes, 3);
    expect(reset.intervalMinutes, Duration.minutesPerDay);
  });
}

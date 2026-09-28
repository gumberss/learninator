// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:learninator/main.dart';

void main() {
  testWidgets('reveals an answer and schedules the reviewed card',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const card = Flashcard(
      id: 'test-card',
      question: 'What is tested?',
      answer: 'The complete review flow.',
    );

    await tester.pumpWidget(const MyApp(initialCards: [card]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review all topics'));
    await tester.pumpAndSettle();

    expect(find.text('What is tested?'), findsOneWidget);
    expect(find.text('The complete review flow.'), findsNothing);

    await tester.tap(find.byKey(const Key('flashcard')));
    await tester.pumpAndSettle();

    expect(find.text('The complete review flow.'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flashcard')));
    await tester.pumpAndSettle();

    expect(find.text('What is tested?'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rating-medium')));
    await tester.pumpAndSettle();

    expect(find.text('You are caught up'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('nextReview.test-card'), isNotNull);
  });

  testWidgets('shows the current card topic as the title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const card = Flashcard(
      id: 'topic-card',
      topicName: 'Scalability',
      question: 'Question',
      answer: 'Answer',
    );

    await tester.pumpWidget(const MyApp(initialCards: [card]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scalability & Performance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('topic-Scalability')));
    await tester.pumpAndSettle();

    expect(find.text('Scalability'), findsOneWidget);
  });

  testWidgets('topic review only shows cards from that topic', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const cards = [
      Flashcard(
        id: 'a',
        topicName: 'Caching',
        question: 'Caching question',
        answer: 'A',
      ),
      Flashcard(
        id: 'b',
        topicName: 'Indexing',
        question: 'Indexing question',
        answer: 'B',
      ),
    ];

    await tester.pumpWidget(const MyApp(initialCards: cards));
    await tester.pumpAndSettle();
    expect(find.text('Review all topics'), findsOneWidget);
    expect(find.text('Scalability & Performance'), findsOneWidget);

    await tester.tap(find.text('Data & Storage'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('topic-Indexing')));
    await tester.pumpAndSettle();
    expect(find.text('Indexing question'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flashcard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rating-easy')));
    await tester.pumpAndSettle();
    expect(find.text('You are caught up'), findsOneWidget);
  });

  testWidgets('reset makes scheduled cards available again', (tester) async {
    SharedPreferences.setMockInitialValues({
      'nextReview.hidden-card': DateTime(2100).toIso8601String(),
    });
    const card = Flashcard(
      id: 'hidden-card',
      question: 'Visible after reset',
      answer: 'Answer',
    );

    await tester.pumpWidget(const MyApp(initialCards: [card]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review all topics'));
    await tester.pumpAndSettle();
    expect(find.text('You are caught up'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reset-reviews')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-reset-reviews')));
    await tester.pumpAndSettle();

    expect(find.text('Visible after reset'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('nextReview.hidden-card'), isNull);
    expect(preferences.getString('reviewState.hidden-card'), isNull);
  });

  test('flashcards read separate question and answer images from JSON', () {
    final card = Flashcard.fromJson({
      'id': 'image-card',
      'question': 'Question',
      'answer': 'Answer',
      'topicName': 'Architecture',
      'questionImage': 'assets/question.jpg',
      'answerImage': 'assets/answer.jpg',
    });

    expect(card.topicName, 'Architecture');
    expect(card.questionImage, 'assets/question.jpg');
    expect(card.answerImage, 'assets/answer.jpg');
  });

  test('legacy image applies to both card sides', () {
    final card = Flashcard.fromJson({
      'id': 'legacy-image-card',
      'question': 'Question',
      'answer': 'Answer',
      'image': 'assets/legacy.jpg',
    });

    expect(card.questionImage, 'assets/legacy.jpg');
    expect(card.answerImage, 'assets/legacy.jpg');
  });

  test('cards inherit the topic of their file', () {
    final card = Flashcard.fromJson(
      {'id': 'file-card', 'question': 'Q', 'answer': 'A'},
      topicName: 'Caching',
    );

    expect(card.topicName, 'Caching');
  });

  testWidgets('loads the bundled per-topic card files', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 500),
        ));
    await tester.pumpAndSettle();

    expect(find.text('Review all topics'), findsOneWidget);
    expect(find.text('Scalability & Performance'), findsOneWidget);
  });
}

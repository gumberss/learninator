import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/review_scheduler.dart';
import 'domain/topic_categories.dart';

export 'domain/review_scheduler.dart';

class Flashcard {
  const Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    this.topicName,
    this.questionImage,
    this.answerImage,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json, {String? topicName}) {
    final legacyImage = json['image'] as String?;
    return Flashcard(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      topicName: json['topicName'] as String? ?? topicName,
      questionImage: json['questionImage'] as String? ?? legacyImage,
      answerImage: json['answerImage'] as String? ?? legacyImage,
    );
  }

  final String id;
  final String question;
  final String answer;
  final String? topicName;
  final String? questionImage;
  final String? answerImage;
}

extension ReviewRatingPresentation on ReviewRating {
  String get label => switch (this) {
        ReviewRating.impossible => 'Impossible',
        ReviewRating.hard => 'Hard',
        ReviewRating.medium => 'Medium',
        ReviewRating.easy => 'Easy',
      };

  IconData get icon => switch (this) {
        ReviewRating.impossible => Icons.replay,
        ReviewRating.hard => Icons.trending_down,
        ReviewRating.medium => Icons.horizontal_rule,
        ReviewRating.easy => Icons.trending_up,
      };

  Color get color => switch (this) {
        ReviewRating.impossible => const Color(0xFFB73E3E),
        ReviewRating.hard => const Color(0xFFCB6D35),
        ReviewRating.medium => const Color(0xFF2D6A8A),
        ReviewRating.easy => const Color(0xFF397052),
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialCards});

  final List<Flashcard>? initialCards;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17212B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Learninator',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F0E8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E5A61),
          surface: const Color(0xFFFFFDF8),
        ),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: ink,
              displayColor: ink,
              fontFamily: 'serif',
            ),
      ),
      home: TopicsScreen(initialCards: initialCards),
    );
  }
}

const _reviewKeyPrefix = 'nextReview.';
const _reviewStateKeyPrefix = 'reviewState.';

bool _isDue(SharedPreferences preferences, Flashcard card, DateTime now) {
  final value = preferences.getString('$_reviewKeyPrefix${card.id}');
  final nextReview = value == null ? null : DateTime.tryParse(value);
  return nextReview == null || !nextReview.isAfter(now);
}

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key, this.initialCards});

  final List<Flashcard>? initialCards;

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  List<Flashcard> _cards = const [];
  SharedPreferences? _preferences;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final cards = widget.initialCards ?? await _readAssetCards();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _cards = cards;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The card deck could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<List<Flashcard>> _readAssetCards() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((path) =>
            path.startsWith('assets/cards/') && path.endsWith('.json'))
        .toList()
      ..sort();
    final decks = await Future.wait(paths.map(_readTopicFile));
    return decks.expand((cards) => cards).toList();
  }

  Future<List<Flashcard>> _readTopicFile(String path) async {
    final contents = await rootBundle.loadString(path);
    final deck = jsonDecode(contents) as Map<String, dynamic>;
    final topicName = deck['topicName'] as String?;
    return (deck['cards'] as List<dynamic>)
        .map((record) => Flashcard.fromJson(
              record as Map<String, dynamic>,
              topicName: topicName,
            ))
        .toList();
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _loadCards();
  }

  int _dueCount(Iterable<Flashcard> cards) {
    final now = DateTime.now();
    return cards.where((card) => _isDue(_preferences!, card, now)).length;
  }

  Future<void> _openStudy(List<Flashcard> cards, String title) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyScreen(cards: cards, title: title),
      ),
    );
    // Due counts change after reviewing.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _retry)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final topics = <String, List<Flashcard>>{};
    for (final card in _cards) {
      final topic = card.topicName;
      if (topic == null || topic.trim().isEmpty) continue;
      topics.putIfAbsent(topic, () => []).add(card);
    }

    final categories = <String, List<String>>{};
    for (final entry in topicCategories.entries) {
      final present = entry.value.where(topics.containsKey).toList();
      if (present.isNotEmpty) categories[entry.key] = present;
    }
    final known = topicCategories.values.expand((names) => names).toSet();
    final uncategorized =
        topics.keys.where((topic) => !known.contains(topic)).toList();
    if (uncategorized.isNotEmpty) {
      categories[otherCategoryName] = uncategorized;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFF17212B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.layers_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  'Learninator',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TopicTile(
              key: const Key('topic-all'),
              title: 'Review all topics',
              dueCount: _dueCount(_cards),
              highlighted: true,
              onTap: () => _openStudy(_cards, 'Learninator'),
            ),
            for (final category in categories.entries)
              _buildCategory(
                category.key,
                {for (final topic in category.value) topic: topics[topic]!},
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(String name, Map<String, List<Flashcard>> topics) {
    final categoryCards = topics.values.expand((cards) => cards).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFFFFDF8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF17212B), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ExpansionTile(
          key: Key('category-$name'),
          shape: const Border(),
          collapsedShape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          title: Text(
            name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          subtitle: Text(
            '${topics.length} topics · ${_dueCount(categoryCards)} due',
          ),
          children: [
            _TopicTile(
              key: Key('category-review-$name'),
              title: 'Review all in $name',
              dueCount: _dueCount(categoryCards),
              highlighted: true,
              onTap: () => _openStudy(categoryCards, name),
            ),
            for (final entry in topics.entries)
              _TopicTile(
                key: Key('topic-${entry.key}'),
                title: entry.key,
                dueCount: _dueCount(entry.value),
                onTap: () => _openStudy(entry.value, entry.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    super.key,
    required this.title,
    required this.dueCount,
    required this.onTap,
    this.highlighted = false,
  });

  final String title;
  final int dueCount;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: highlighted ? const Color(0xFFE7F0EA) : const Color(0xFFFFFDF8),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF17212B), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  '$dueCount due',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF56616A),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, required this.cards, required this.title});

  final List<Flashcard> cards;
  final String title;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  List<Flashcard> _cards = const [];
  SharedPreferences? _preferences;
  int _sessionTotal = 0;
  int _reviewed = 0;
  bool _answerVisible = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dueCards =
        widget.cards.where((card) => _isDue(preferences, card, now)).toList();

    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _cards = dueCards;
      _sessionTotal = dueCards.length;
      _loading = false;
    });
  }

  Future<void> _rateCard(ReviewRating rating) async {
    if (_cards.isEmpty || _preferences == null) return;
    final card = _cards.first;
    final stateKey = '$_reviewStateKeyPrefix${card.id}';
    final savedState = _preferences!.getString(stateKey);
    final previousState = savedState == null
        ? null
        : ReviewState.fromJson(
            jsonDecode(savedState) as Map<String, dynamic>,
          );
    final nextState = calculateNextReviewState(rating, previousState);
    await _preferences!.setString(stateKey, jsonEncode(nextState.toJson()));
    await _preferences!.setString(
      '$_reviewKeyPrefix${card.id}',
      DateTime.now()
          .add(Duration(minutes: nextState.intervalMinutes))
          .toIso8601String(),
    );

    if (!mounted) return;
    setState(() {
      _cards = _cards.sublist(1);
      _reviewed += 1;
      _answerVisible = false;
    });
  }

  Future<void> _confirmResetReviews() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset review dates?'),
        content: const Text('Every card will become available again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-reset-reviews'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset == true) await _resetReviewDates();
  }

  Future<void> _resetReviewDates() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final reviewKeys = preferences
        .getKeys()
        .where(
          (key) =>
              key.startsWith(_reviewKeyPrefix) ||
              key.startsWith(_reviewStateKeyPrefix),
        )
        .toList();
    for (final key in reviewKeys) {
      await preferences.remove(key);
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _reviewed = 0;
      _answerVisible = false;
    });
    await _loadCards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        children: [
          _StudyHeader(
            title: _cards.firstOrNull?.topicName ?? widget.title,
            reviewed: _reviewed,
            total: _sessionTotal,
            onReset: _confirmResetReviews,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _cards.isEmpty
                ? const _CompleteState()
                : SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          children: [
                            FlipCard(
                              key: ValueKey(_cards.first.id),
                              card: _cards.first,
                              onRevealed: () =>
                                  setState(() => _answerVisible = true),
                            ),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _answerVisible
                                  ? _RatingPanel(onRated: _rateCard)
                                  : const SizedBox(
                                      key: ValueKey('rating-placeholder'),
                                      height: 116,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StudyHeader extends StatelessWidget {
  const _StudyHeader({
    required this.title,
    required this.reviewed,
    required this.total,
    required this.onReset,
  });

  final String title;
  final int reviewed;
  final int total;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : reviewed / total;
    return Row(
      children: [
        const BackButton(key: Key('back-to-topics')),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
                backgroundColor: const Color(0xFFD9D2C5),
                color: const Color(0xFF397052),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '$reviewed / $total',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const Key('reset-reviews'),
          onPressed: onReset,
          tooltip: 'Reset review dates',
          icon: const Icon(Icons.restart_alt),
        ),
      ],
    );
  }
}

class FlipCard extends StatefulWidget {
  const FlipCard({super.key, required this.card, required this.onRevealed});

  final Flashcard card;
  final VoidCallback onRevealed;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _revealed = false;

  void _flip() {
    final showingOrHeadingToAnswer = _controller.isCompleted ||
        _controller.status == AnimationStatus.forward;
    if (showingOrHeadingToAnswer) {
      _controller.reverse();
      return;
    }
    _controller.forward();
    if (!_revealed) {
      _revealed = true;
      widget.onRevealed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Flip card',
      child: GestureDetector(
        key: const Key('flashcard'),
        behavior: HitTestBehavior.opaque,
        onTap: _flip,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final showingBack = _controller.value >= 0.5;
            final angle =
                math.pi * _controller.value + (showingBack ? math.pi : 0);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: _CardFace(
                side: showingBack ? 'ANSWER' : 'QUESTION',
                text: showingBack ? widget.card.answer : widget.card.question,
                isAnswer: showingBack,
                image: showingBack
                    ? widget.card.answerImage
                    : widget.card.questionImage,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.side,
    required this.text,
    required this.isAnswer,
    this.image,
  });

  final String side;
  final String text;
  final bool isAnswer;
  final String? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isAnswer ? const Color(0xFFE7F0EA) : const Color(0xFFFFFDF8),
        border: Border.all(color: const Color(0xFF17212B), width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B17212B),
            offset: Offset(7, 8),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            side,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isAnswer
                      ? const Color(0xFF397052)
                      : const Color(0xFFB6543F),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (image case final image? when image.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _CardImage(path: image),
                  const SizedBox(height: 14),
                ],
                Flexible(
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        text,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              isAnswer ? Icons.check_circle_outline : Icons.touch_app_outlined,
              color: const Color(0xFF56616A),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      key: const Key('card-image-error'),
      color: const Color(0xFFE2DED5),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Color(0xFF56616A)),
    );
    final isNetworkImage =
        path.startsWith('https://') || path.startsWith('http://');
    final image = isNetworkImage
        ? Image.network(
            path,
            key: const Key('card-image'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: 140,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : Image.asset(
            path,
            key: const Key('card-image'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: 140,
            errorBuilder: (context, error, stackTrace) => fallback,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(width: double.infinity, height: 140, child: image),
    );
  }
}

class _RatingPanel extends StatelessWidget {
  const _RatingPanel({required this.onRated});

  final ValueChanged<ReviewRating> onRated;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('rating-panel'),
      builder: (context, constraints) {
        final buttonWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ReviewRating.values.map((rating) {
            return SizedBox(
              width: buttonWidth,
              height: 52,
              child: FilledButton.tonalIcon(
                key: Key('rating-${rating.name}'),
                onPressed: () => onRated(rating),
                icon: Icon(rating.icon, size: 19),
                label: Text(rating.label),
                style: FilledButton.styleFrom(
                  foregroundColor: rating.color,
                  backgroundColor: rating.color.withAlpha(24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: rating.color.withAlpha(100)),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CompleteState extends StatelessWidget {
  const _CompleteState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.task_alt, size: 64, color: Color(0xFF397052)),
          const SizedBox(height: 18),
          Text(
            'You are caught up',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your next cards will appear when they are due.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

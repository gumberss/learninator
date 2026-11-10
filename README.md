# Learninator

Learninator is a focused flashcard app built with Flutter for studying **system design** concepts. It uses spaced repetition: you rate how well you remembered each card, and the app decides when you should see it again. Cards you struggle with come back soon; cards you know well are pushed further into the future.

It runs on Android and in the browser, and stores all progress locally on the device.

## Features

- **800+ system design and AI cards** across 39 topics, from caching and replication to machine learning and production AI.
- **Categories and topics**: topics are grouped into broader categories so you can study a whole area or a single subject.
- **Review all topics**: one tap to review every card that is due, across the entire deck.
- **Due counters**: every category and topic shows how many cards are waiting for review.
- **Flip cards**: tap to reveal the answer, and tap again to go back to the question as many times as you like.
- **Spaced repetition** with four ratings: Impossible, Hard, Medium, and Easy.
- **Optional images** on either side of a card (local assets or URLs).
- **Offline and private**: no account or server; progress is saved on the device.
- **Reset**: clear all review dates to make every card available again.

## Screenshots

### Main screen: categories and topics

<img width="559" height="948" alt="Main screen with the Review all topics option and expandable categories" src="https://github.com/user-attachments/assets/6b2df18b-a5fa-4104-b5f7-65797ee7d3e3" />

This is the first screen you see when opening the app.

- **Review all topics** at the top starts a session with every due card from the whole deck.
- Below it, each **category** (for example *Scalability & Performance* or *Data & Storage*) shows how many topics it contains and how many of its cards are due.
- Tapping a category expands it to show:
  - **Review all in _category_**, which reviews every due card in that category.
  - Each **topic** in the category with its own due count; tap one to review just that topic.
- Due counts refresh when you come back from a review session.

### Reviewing a topic: the question

<img width="641" height="452" alt="Review screen showing the question side of a card" src="https://github.com/user-attachments/assets/b54f2168-8389-4067-87f5-49d8b1eb725b" />

During a review session the card shows its **question** side first.

- The header shows the current card's topic, a progress bar, and how many cards you have reviewed out of the session total (for example `3 / 11`).
- The back arrow returns to the topic list, and the reset button clears all review dates.
- Try to recall the answer, then **tap the card** to flip it.

### Reviewing a topic: the answer

<img width="621" height="586" alt="Review screen showing the answer side of a card and the rating buttons" src="https://github.com/user-attachments/assets/d2f9022e-b65f-4807-91d7-76262f33897f" />

After flipping, the card shows the **answer** and the rating buttons appear.

- Tap the card again to flip back to the question; the rating buttons stay visible.
- Rate how well you remembered it: **Impossible**, **Hard**, **Medium**, or **Easy**.
- The rating schedules the card's next review and moves on to the next card. When no cards are left, you see *You are caught up*.

## How scheduling works

Each rating has a base delay:

| Rating | First review delay |
|---|---|
| Impossible | 3 minutes |
| Hard | 1 hour |
| Medium | 3 days |
| Easy | 7 days |

On later reviews the interval adapts to your history:

- **Same rating again**: the interval grows each time you repeat the rating (for example Easy, Easy, Easy spaces reviews further and further apart).
- **Different rating**: the new interval starts from part of the previous one (a third for Hard, half for Medium, all of it for Easy) plus the rating's base delay, so progress is not completely lost.
- **Impossible** on a card you have already seen resets it to one day.

A card is due when its next review date has passed. Cards you have never reviewed are always due.

## Categories

| Category | Topics |
|---|---|
| Scalability & Performance | Scalability, Load Balancing, Caching, CDN / Edge Computing, Autoscaling, Capacity Planning |
| Data & Storage | Database Design, Data Partitioning, Replication, Indexing |
| Consistency & Transactions | Consistency Models, CAP Theorem, ACID vs BASE, Distributed Transactions, Concurrency |
| APIs & Communication | API Design, Idempotency, Pagination, Rate Limiting |
| Messaging & Streaming | Message Queues, Stream Processing, Backpressure |
| Architecture & Operations | Microservices vs Monolith, Service Discovery, Configuration Management, Deployment Strategies |
| Reliability & Security | Fault Tolerance, Observability, SLA SLO SLI, Security |
| System Design | System Design Scenarios |
| AI & Machine Learning | Machine Learning |

Topics not listed in a category appear under **Other**. Categories are defined in [lib/domain/topic_categories.dart](lib/domain/topic_categories.dart).

## Adding cards

Cards live in [assets/cards/](assets/cards/), one JSON file per topic. Every `.json` file in that folder is loaded automatically, so adding a new topic is just adding a new file.

```json
{
    "topicName": "Caching",
    "cards": [
        {
            "id": "caching-1",
            "question": "What is caching?",
            "answer": "Storing frequently accessed data in a faster storage layer.",
            "questionImage": "",
            "answerImage": ""
        }
    ]
}
```

- `id` must be unique across all files; review progress is stored by ID, so do not change IDs of existing cards.
- `questionImage` and `answerImage` are optional. Use an asset path (for example `assets/images/diagram.png`) or an `http(s)` URL.
- To place a new topic in a category, add its `topicName` to [lib/domain/topic_categories.dart](lib/domain/topic_categories.dart).

## Running the app

Requirements: the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.5 or newer).

```powershell
flutter pub get
```

**Web**

```powershell
flutter run -d chrome
# or serve it and open http://localhost:8080 in any browser
flutter run -d web-server --web-port 8080
```

**Android phone**

Enable Developer options and USB debugging on the phone, connect it by USB, then:

```powershell
flutter devices
flutter run --release -d <device-id>
```

Or build an APK to install manually:

```powershell
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## Tests

```powershell
flutter analyze
flutter test
```

## Project structure

```
assets/cards/                     One JSON file per topic
lib/main.dart                     Entry point
lib/app.dart                      Topics screen, review screen, and flip card UI
lib/domain/review_scheduler.dart  Spaced repetition scheduling
lib/domain/topic_categories.dart  Topic to category mapping
test/                             Widget and scheduler tests
```

# SwipeDel

Tinder for your camera roll. Pick an album, swipe through it one card at a time, and clean up your gallery fast — **swipe left to delete, swipe right to keep**.

Built with Flutter, Android-first.

## Features

- **Album browser** — every photo & video album on your device, with a media-type filter: **All / Photos / Videos**.
- **Swipe to sort** — left marks an item for deletion, right keeps it. Big **DELETE / KEEP** cues while you drag.
- **Undo** — step back through mis-swipes, one card at a time.
- **Recoverable delete** — left-swiped items are moved to your phone's system trash in one batch when you leave an album. Nothing is deleted until then, and it stays restorable (~30 days).
- **Trash page** — see everything you've trashed, then **Restore** it to your gallery or **Delete forever** (single items or empty all).
- **Favorites** — heart any photo or video and find them in one place.
- **Fullscreen viewer** — tap a card to pinch-zoom photos or play videos, with file **size & date** shown cleanly.
- **Sort the deck** — Newest, Oldest, or **Largest first** (great for reclaiming space fast).
- **Resume & progress** — reopen an album and pick up where you left off; tiles show a progress ring, and finished albums get a **Done** badge.

## Getting started

```bash
flutter pub get
flutter run
```

Grant photo & video access on first launch. A quick in-app guide (the **?** in the header) explains the gestures anytime.

## Tech

Flutter · [photo_manager](https://pub.dev/packages/photo_manager) (gallery + trash) · [flutter_card_swiper](https://pub.dev/packages/flutter_card_swiper) · [photo_view](https://pub.dev/packages/photo_view) · [video_player](https://pub.dev/packages/video_player) · a small native Kotlin channel for permanently deleting and restoring trashed media.

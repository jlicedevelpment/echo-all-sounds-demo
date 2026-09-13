# 🎧 Echo All Sounds

A Flutter music, podcast, and audiobook player app — built from scratch as a personal project to learn Flutter and explore app monetization design.

**Live status:** in active development, currently runs on web (`flutter run -d chrome`). Android support is on the roadmap.

---

## ✨ Features

- **Real, playable audio** — no placeholders. 14 songs (via the [freepd.info](https://freepd.info) collection), 3 public-domain audiobooks (LibriVox recordings of Edgar Allan Poe), and 10 classical pieces by 9 real composers (Bach, Beethoven, Vivaldi, Tchaikovsky, and more), all public domain and properly sourced.
- **Home, Search, and Library tabs** with a persistent mini player, horizontally scrolling rows, and Apple Music–style category browsing.
- **Real playlists and albums** — songs are genuinely grouped by artist and curated into mixed playlists, not randomly generated.
- **Live internet radio** — 8 real stations including BBC Radio 1, 5 Live, and 6 Music (via an HLS bridge), Capital FM, Classic FM, and more.
- **A dedicated Classical section**, styled distinctly from the rest of the app, browsable by composer.
- **Sleep timer** — 15/30/45/60-minute auto-stop, with a live countdown in the mini player.
- **Autoplay & queue** — real sequential playback through playlists, albums, and a dedicated Queue screen.
- **Downloads, pins, and play history** — all persisted locally so they survive a refresh.
- **Full dark and light mode**, built on a proper Flutter `ThemeExtension` rather than hardcoded colors.
- **A designed-out monetization system** (demo/local-only, no real payments yet):
  - 4 flat-fee sponsor placements + 1 no-fee affiliate spot, each self-serve editable from Settings
  - Two subscription tiers — Pro (removes ads, offline, lossless) and Ad-Free (just removes the interrupting pre-song ads) — both monthly/yearly, both clearly labeled as local demos
  - A pre-song ad break for free-tier users, with a submittable "pitch us your ad" form

## 🛠 Tech Stack

- **Flutter** (web target)
- [`audioplayers`](https://pub.dev/packages/audioplayers) for playback
- [`hls.js`](https://github.com/video-dev/hls.js) (via a small JS bridge) for HLS radio streams
- Persistence via the browser's `localStorage` (no backend — this is a local-first demo app)

## 🚀 Getting Started

```bash
git clone <this-repo-url>
cd echo_all_sounds
flutter pub get
flutter run -d chrome
```

**Note:** this project currently targets web only. `dart:html` and `dart:js` are used for local storage, image picking, and the radio HLS bridge, so it won't compile for mobile/desktop without porting those first (see Roadmap).

## 🎵 Adding Audio Files

Audio files aren't committed to this repo (see `.gitignore`) since they're sourced separately. To get a fully working build:

1. Songs: `assets/audio/track1.mp3` – `track14.mp3` — from the freepd.info collection via archive.org
2. Audiobooks: `assets/audio/audiobook1.mp3` – `audiobook3.mp3` — LibriVox public-domain recordings
3. Classical: `assets/audio/classical1.mp3` – `classical10.mp3` — from a Community Audio collection on archive.org (Public Domain Mark 1.0)
4. (Optional) `assets/audio/ad_announcement.mp3` — a short spoken "Advertisement" clip, self-generated via free TTS

## 🗺 Roadmap

- [ ] Port off `dart:html`/`dart:js` (→ `shared_preferences`, `image_picker`) to support Android
- [ ] Fill out the Classical section further
- [ ] Real payment processing (Stripe) — currently Pro/Ad-Free are local-only demo toggles
- [ ] Real backend for Blend (friend-taste-matching feature) — currently a UI-only placeholder
- [ ] Publish a live web build

## 📄 License & Credits

This is a personal learning project, not for commercial distribution as-is. All bundled audio is public domain / Creative Commons, sourced from archive.org and LibriVox — see comments in `main.dart` for exact attribution per track.

---

Built solo, learning Flutter as I go. 🎶

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const EchoAllSoundsApp());
}

// Flutter's default web/desktop ScrollBehavior only allows touch/trackpad to
// drag-scroll — a plain mouse click-and-drag does nothing by default, which
// is why the horizontal rows (Trending, Radio, etc.) felt unscrollable in
// Chrome on desktop. This adds mouse to the allowed drag devices, app-wide.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

// Simple persistence via the browser's own localStorage, accessed through
// dart:js — deliberately avoids the shared_preferences package, since it
// pulls in native-code build steps that break when the Flutter SDK is
// installed at a path containing spaces.
String? _lsGet(String key) {
  try {
    final storage = js.context['localStorage'];
    final value = storage.callMethod('getItem', [key]);
    return value as String?;
  } catch (_) {
    return null;
  }
}

void _lsSet(String key, String value) {
  try {
    final storage = js.context['localStorage'];
    storage.callMethod('setItem', [key, value]);
  } catch (_) {
    // Storage unavailable — silently skip, don't crash the app.
  }
}

// Global key so a SnackBar can be shown from deep in the widget tree (e.g.
// when a download is blocked by "Wi-Fi only") without threading BuildContext
// through every download callback.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class EchoAllSoundsApp extends StatefulWidget {
  const EchoAllSoundsApp({super.key});

  @override
  State<EchoAllSoundsApp> createState() => _EchoAllSoundsAppState();
}

class _EchoAllSoundsAppState extends State<EchoAllSoundsApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    final saved = _lsGet('themeMode');
    if (saved == 'light') {
      _themeMode = ThemeMode.light;
    }
  }

  void _setThemeMode(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    _lsSet('themeMode', isDark ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echo All Sounds',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      scrollBehavior: AppScrollBehavior(),
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF9C27B0),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF9C27B0),
          secondary: const Color(0xFF9C27B0),
        ),
        extensions: const [
          AppColors(
            surface: Colors.white,
            surfaceAlt: Color(0xFFEDEDF2),
            textPrimary: Colors.black87,
            textSecondary: Colors.black54,
            textTertiary: Colors.black38,
            divider: Colors.black12,
          ),
        ],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF9C27B0),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF9C27B0),
          secondary: const Color(0xFF9C27B0),
        ),
        extensions: const [
          AppColors(
            surface: Color(0xFF1E1E1E),
            surfaceAlt: Color(0xFF282828),
            textPrimary: Colors.white,
            textSecondary: Colors.white70,
            textTertiary: Colors.white54,
            divider: Colors.white24,
          ),
        ],
      ),
      home: HomeScreen(isDarkMode: _themeMode == ThemeMode.dark, onSetDarkMode: _setThemeMode),
    );
  }
}

// Semantic colors that differ between light and dark mode — page-chrome
// surfaces (cards, dialogs, sheets, the bottom nav/mini player) and body
// text, kept separate from the fixed brand colors (purple accent, colored
// track/genre thumbnails, badge overlays) which stay the same in both
// modes by design. Access via `context.colors`.
class AppColors extends ThemeExtension<AppColors> {
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;

  const AppColors({
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
  });

  @override
  AppColors copyWith({
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final void Function(bool isDark) onSetDarkMode;
  const HomeScreen({super.key, required this.isDarkMode, required this.onSetDarkMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Real, distinct public-domain (CC0) tracks from the freepd.info collection
// via Internet Archive, bundled as local asset files. Local files play with
// zero network/CORS involved, unlike every external URL approach tried
// before this — so this is guaranteed to work once the files are in place.
// Expects 6 files at assets/audio/track1.mp3 through track6.mp3.
class DemoTrack {
  final String assetPath;
  final String title;
  const DemoTrack(this.assetPath, this.title);
}

const List<DemoTrack> demoTracks = [
  DemoTrack('audio/track1.mp3', 'Adventure'),
  DemoTrack('audio/track2.mp3', 'Ancient Rite'),
  DemoTrack('audio/track3.mp3', 'Be Chillin'),
  DemoTrack('audio/track4.mp3', 'Big Eyes'),
  DemoTrack('audio/track5.mp3', 'City Sunshine'),
  DemoTrack('audio/track6.mp3', 'Cornfield Chase'),
  DemoTrack('audio/track7.mp3', 'Black Knight'),
  DemoTrack('audio/track8.mp3', 'Emotional Blockbuster 2'),
  DemoTrack('audio/track9.mp3', 'Epic Boss Battle'),
  DemoTrack('audio/track10.mp3', 'Evil Incoming'),
  DemoTrack('audio/track11.mp3', 'Fanfare X'),
  DemoTrack('audio/track12.mp3', 'Funshine'),
  DemoTrack('audio/track13.mp3', 'Assassin'),
  DemoTrack('audio/track14.mp3', 'Behind Enemy Lines'),
];

// Real, public-domain audiobook recordings from LibriVox (via its
// archive.org mirror) — same DemoTrack shape as songs, just a separate
// pool of files so audiobook titles resolve to audiobook audio, not song
// audio. Expects assets/audio/audiobook1.mp3 through audiobook3.mp3.
const List<DemoTrack> demoAudiobooks = [
  DemoTrack('audio/audiobook1.mp3', 'The Raven'),
  DemoTrack('audio/audiobook2.mp3', 'The Tell-Tale Heart'),
  DemoTrack('audio/audiobook3.mp3', 'The Cask of Amontillado'),
];

// Author for each real audiobook — shown as a subtitle, the same way
// songArtistMap works for songs.
const Map<String, String> audiobookAuthorMap = {
  'The Raven': 'Edgar Allan Poe',
  'The Tell-Tale Heart': 'Edgar Allan Poe',
  'The Cask of Amontillado': 'Edgar Allan Poe',
};

// Real, public-domain classical recordings from a Community Audio
// collection on archive.org — same pattern as the freepd.info songs and
// LibriVox audiobooks: real pieces by real composers, bundled as local
// asset files. Expects assets/audio/classical1.mp3 through classical4.mp3.
const List<DemoTrack> demoClassical = [
  DemoTrack('audio/classical1.mp3', 'Canon in D Major'),
  DemoTrack('audio/classical2.mp3', 'Orchestral Suite No. 2: Badinerie'),
  DemoTrack('audio/classical3.mp3', "The Four Seasons: Spring (Allegro)"),
  DemoTrack('audio/classical4.mp3', 'Overture: Egmont, Op. 84'),
  DemoTrack('audio/classical5.mp3', 'Für Elise'),
  DemoTrack('audio/classical6.mp3', '1812 Overture, Op. 49'),
  DemoTrack('audio/classical7.mp3', 'Overture: William Tell'),
  DemoTrack('audio/classical8.mp3', "Midsummer Night's Dream: Wedding March"),
  DemoTrack('audio/classical9.mp3', 'Boléro'),
  DemoTrack('audio/classical10.mp3', 'Sabre Dance'),
];

// Composer for each real classical piece — shown as a subtitle, the same
// way songArtistMap works for songs.
const Map<String, String> classicalComposerMap = {
  'Canon in D Major': 'Johann Pachelbel',
  'Orchestral Suite No. 2: Badinerie': 'Johann Sebastian Bach',
  "The Four Seasons: Spring (Allegro)": 'Antonio Vivaldi',
  'Overture: Egmont, Op. 84': 'Ludwig van Beethoven',
  'Für Elise': 'Ludwig van Beethoven',
  '1812 Overture, Op. 49': 'Pyotr Ilyich Tchaikovsky',
  'Overture: William Tell': 'Gioachino Rossini',
  "Midsummer Night's Dream: Wedding March": 'Felix Mendelssohn',
  'Boléro': 'Maurice Ravel',
  'Sabre Dance': 'Aram Khachaturian',
};

// Real membership — which pieces belong to each composer, for the
// Classical section's "Browse by Composer" list.
const Map<String, List<String>> composerPieces = {
  'Johann Pachelbel': ['Canon in D Major'],
  'Johann Sebastian Bach': ['Orchestral Suite No. 2: Badinerie'],
  'Antonio Vivaldi': ["The Four Seasons: Spring (Allegro)"],
  'Ludwig van Beethoven': ['Overture: Egmont, Op. 84', 'Für Elise'],
  'Pyotr Ilyich Tchaikovsky': ['1812 Overture, Op. 49'],
  'Gioachino Rossini': ['Overture: William Tell'],
  'Felix Mendelssohn': ["Midsummer Night's Dream: Wedding March"],
  'Maurice Ravel': ['Boléro'],
  'Aram Khachaturian': ['Sabre Dance'],
};

// The full real song catalog, in a stable order used by Home's Trending
// row and other "show everything real" spots.
const List<String> allRealSongs = [
  'Adventure', 'Ancient Rite', 'Be Chillin', 'Big Eyes', 'City Sunshine', 'Cornfield Chase',
  'Black Knight', 'Emotional Blockbuster 2', 'Epic Boss Battle', 'Evil Incoming', 'Fanfare X', 'Funshine',
  'Assassin', 'Behind Enemy Lines',
];

// Which artist each real song belongs to — ties Songs, Artists, and Albums
// together so they're consistent with each other instead of independent
// fake lists.
const Map<String, String> songArtistMap = {
  'Adventure': 'Luna Ray',
  'Ancient Rite': 'Luna Ray',
  'Be Chillin': 'Luna Ray',
  'Big Eyes': 'The Wanderers',
  'City Sunshine': 'The Wanderers',
  'Cornfield Chase': 'The Wanderers',
  'Black Knight': 'Echo Park',
  'Emotional Blockbuster 2': 'Echo Park',
  'Epic Boss Battle': 'Echo Park',
  'Evil Incoming': 'Nova Sound',
  'Fanfare X': 'Nova Sound',
  'Funshine': 'Nova Sound',
  'Assassin': 'Echo Park',
  'Behind Enemy Lines': 'Nova Sound',
};

// Real membership — each artist's album contains their own 3 songs.
const Map<String, List<String>> albumSongs = {
  'Midnight Tales': ['Adventure', 'Ancient Rite', 'Be Chillin'],
  'Neon Dreams': ['Big Eyes', 'City Sunshine', 'Cornfield Chase'],
  'Quiet Storm': ['Black Knight', 'Emotional Blockbuster 2', 'Epic Boss Battle', 'Assassin'],
  'Paper Skies': ['Evil Incoming', 'Fanfare X', 'Funshine', 'Behind Enemy Lines'],
};

// Real membership — playlists mix songs across different artists/albums,
// like a real curated playlist would.
const Map<String, List<String>> playlistSongs = {
  'Chill Vibes': ['Be Chillin', 'City Sunshine', 'Cornfield Chase'],
  'Workout Mix': ['Epic Boss Battle', 'Evil Incoming', 'Black Knight'],
  'Focus Flow': ['Ancient Rite', 'Adventure', 'Fanfare X'],
  'Late Night Drive': ['Big Eyes', 'Emotional Blockbuster 2', 'Funshine'],
};

class RadioStation {
  final String name;
  final String genre;
  final String url;
  // HLS (.m3u8) streams can't be played by audioplayers directly on web —
  // they're routed through the hls.js JS bridge set up in web/index.html instead.
  final bool isHls;
  // True for the placeholder sponsored "station" slot shown in the Radio row —
  // it isn't a real stream, tapping it opens the sponsorship info dialog instead
  // of trying to play anything.
  final bool isSponsored;
  const RadioStation(this.name, this.genre, this.url, {this.isHls = false, this.isSponsored = false});
}

// Real, currently-working internet radio streams.
// BBC Radio 1 is included via an unofficial HLS URL — BBC only supports HLS/DASH
// for third-party embedding now, and this URL isn't officially documented, so it
// may stop working without notice. Everything else is a stable direct stream.
const List<RadioStation> radioStations = [
  RadioStation('Capital FM', 'Pop & Hits (UK)', 'http://media-ice.musicradio.com/CapitalMP3'),
  RadioStation('Classic FM', 'Classical (UK)', 'http://ice-sov.musicradio.com/ClassicFMMP3'),
  RadioStation('Radio Rivendell', 'Celtic & Fantasy Folk', 'https://play.radiorivendell.com/radio/8000/radio.mp3'),
  RadioStation('FIP Radio', 'Eclectic (France)', 'https://icecast.radiofrance.fr/fip-hifi.aac'),
  RadioStation('FIP Groove', 'Ambient/Chill', 'https://icecast.radiofrance.fr/fipgroove-hifi.aac?id=radiofrance'),
  RadioStation(
    'BBC Radio 1',
    'Pop & Hits (UK) · Experimental',
    'https://lsn.lv/bbcradio.m3u8?station=bbc_radio_one&bitrate=320000',
    isHls: true,
  ),
  RadioStation(
    'BBC Radio 5 Live',
    'News & Sport (UK) · Experimental',
    'https://lsn.lv/bbcradio.m3u8?station=bbc_radio_five_live&bitrate=320000',
    isHls: true,
  ),
  RadioStation(
    'BBC Radio 6 Music',
    'Alternative & Indie (UK) · Experimental',
    'https://lsn.lv/bbcradio.m3u8?station=bbc_6music&bitrate=320000',
    isHls: true,
  ),
];

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentTitle;
  String? _currentSubtitle;
  bool _isPlaying = false;

  // True while the currently-playing thing is an HLS stream handled by the
  // JS bridge in web/index.html, rather than by the audioplayers package.
  bool _usingHls = false;

  // The current autoplay queue — populated when a track is played from a
  // Library category list (Playlists, Albums, etc.) so autoplay has an
  // ordered sequence to move through when a track finishes. Empty/-1 means
  // "not currently playing through a queued list" (e.g. a one-off track).
  List<String> _queue = [];
  int _queueIndex = -1;
  String _queueCategory = '';

  // Real play history for the "Recently Played" row — most recent first,
  // capped at 8 entries, persisted so it survives a restart.
  List<Map<String, String>> _playHistory = [];
  // Real lifetime play count, uncapped — used on the Profile screen.
  int _totalPlays = 0;
  // Local-only Pro flag — no real payments/accounts behind it, just a
  // device-level toggle set from the Subscriptions screen. True Pro (tied
  // to a real purchasing account) needs a real backend, which this app
  // deliberately doesn't have yet.
  bool _isPro = false;
  // Cheaper tier (£2.49) — removes only the interrupting pre-song audio ads.
  // Sponsor banners elsewhere in the app (Trending row, Radio row, Search
  // banner, Library row, affiliate spot) are unaffected — those aren't part
  // of this tier's scope. Mutually exclusive with Pro: subscribing to one
  // clears the other, so there's always exactly one active plan.
  bool _isAdFree = false;

  // Sleep timer — when set, playback pauses automatically once the
  // countdown reaches zero. `_sleepTimerRemaining` is null whenever no
  // timer is running, so the mini player only shows it when active.
  Duration? _sleepTimerRemaining;
  Timer? _sleepTimerCountdown;

  // Persistence: playlists and pinned items are saved locally (browser
  // localStorage) so they survive a browser refresh / app restart. True
  // once the saved data (if any) has finished loading, so we don't flash
  // default demo data before the real saved data appears.
  bool _dataLoaded = false;

  // Sponsor slot data — editable from Settings → Ads & Sponsorships.
  // Each of the 4 flat-fee slots holds a name/description/optional image;
  // the affiliate merch slot holds an artist (restricted to one already in
  // the app) instead of a free-text name, plus its own description/image.
  Map<String, dynamic> _sponsorTrending = {'name': 'Your Brand Here', 'description': '', 'image': null, 'info': ''};
  Map<String, dynamic> _sponsorRadio = {'name': 'Your Station Here', 'description': '', 'image': null, 'info': ''};
  Map<String, dynamic> _sponsorSearch = {'name': 'Your Sponsor Here', 'description': '', 'image': null, 'info': ''};
  Map<String, dynamic> _sponsorLibrary = {'name': 'Your Brand Here', 'description': '', 'image': null, 'info': ''};
  Map<String, dynamic> _sponsorAffiliate = {'artist': null, 'description': '', 'image': null, 'info': ''};

  // Calls a JS bridge function defined in web/index.html, but never throws —
  // if the bridge function isn't there (e.g. index.html hasn't been set up
  // yet, or failed to load), this just does nothing instead of crashing
  // whatever Dart code called it. This keeps normal (non-HLS) playback
  // working even if the HLS bridge is broken or missing.
  void _safeJsCall(String method, [List<dynamic>? args]) {
    try {
      if (js.context.hasProperty(method)) {
        js.context.callMethod(method, args ?? []);
      }
    } catch (_) {
      // Bridge unavailable or errored — ignore, don't break audio playback.
    }
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      // Ignore audioplayers' own state updates while an HLS stream (played
      // through the separate JS bridge) is active, so the two don't fight
      // over _isPlaying.
      if (_usingHls) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
    // When a track finishes (not applicable to HLS radio, which doesn't
    // "complete"), move to the next item in the current queue if Autoplay
    // is on and there is one.
    _audioPlayer.onPlayerComplete.listen((event) {
      if (_usingHls) return;
      _handleTrackComplete();
    });
    _loadPersistedData();
  }

  bool _isAutoplayEnabled() {
    final raw = _lsGet('settings');
    if (raw == null) return true;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      return saved['autoplay'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  // Reads the Settings → Audio Ads → "Ad volume" choice and converts it to
  // a 0.0–1.0 volume level for the spoken ad clip.
  double _getAdVolume() {
    final raw = _lsGet('settings');
    if (raw == null) return 0.6;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final vol = saved['adVolume'] as String? ?? 'Normal';
      switch (vol) {
        case 'Low':
          return 0.3;
        case 'Loud':
          return 1.0;
        default:
          return 0.6;
      }
    } catch (_) {
      return 0.6;
    }
  }

  void _handleTrackComplete() {
    if (!_isAutoplayEnabled() || _queue.isEmpty || _queueIndex < 0) {
      setState(() {
        _isPlaying = false;
      });
      return;
    }
    // Move to the next item, wrapping back to the start at the end so
    // playback through a playlist/album/queue continues rather than
    // just stopping.
    final nextIndex = _queueIndex + 1 >= _queue.length ? 0 : _queueIndex + 1;
    setState(() {
      _queueIndex = nextIndex;
    });
    _playTrack(_queue[nextIndex], _queueCategory, clearQueue: false);
  }

  Future<void> _loadPersistedData() async {
    final savedPinsRaw = _lsGet('pinnedItems');
    if (savedPinsRaw != null) {
      try {
        final savedPins = (jsonDecode(savedPinsRaw) as List).cast<String>();
        _pinnedItems
          ..clear()
          ..addAll(savedPins);
      } catch (_) {
        // Corrupted or missing data — keep the defaults.
      }
    }

    final savedPlaylistsRaw = _lsGet('playlists');
    if (savedPlaylistsRaw != null) {
      try {
        final savedPlaylists = (jsonDecode(savedPlaylistsRaw) as List).cast<String>();
        _sampleItems['Playlists'] = savedPlaylists;
      } catch (_) {
        // Corrupted or missing data — keep the defaults.
      }
    }

    final savedHistoryRaw = _lsGet('playHistory');
    if (savedHistoryRaw != null) {
      try {
        final savedHistory = (jsonDecode(savedHistoryRaw) as List)
            .map((e) => (e as Map).cast<String, String>())
            .toList();
        _playHistory = savedHistory;
      } catch (_) {
        // Corrupted or missing data — keep the defaults.
      }
    }

    final savedTotalPlaysRaw = _lsGet('totalPlays');
    if (savedTotalPlaysRaw != null) {
      _totalPlays = int.tryParse(savedTotalPlaysRaw) ?? 0;
    }

    final savedIsProRaw = _lsGet('isPro');
    if (savedIsProRaw != null) {
      _isPro = savedIsProRaw == 'true';
    }

    final savedIsAdFreeRaw = _lsGet('isAdFree');
    if (savedIsAdFreeRaw != null) {
      _isAdFree = savedIsAdFreeRaw == 'true';
    }

    final savedDownloadsRaw = _lsGet('downloadedSongs');
    if (savedDownloadsRaw != null) {
      try {
        final savedDownloads = (jsonDecode(savedDownloadsRaw) as List).cast<String>();
        _downloadedSongs
          ..clear()
          ..addAll(savedDownloads);
        _sampleItems['Downloads'] = _downloadedSongs.toList();
      } catch (_) {
        // Corrupted or missing data — keep the defaults.
      }
    }

    final savedSponsorRaw = _lsGet('sponsorSettings');
    if (savedSponsorRaw != null) {
      try {
        final savedSponsor = jsonDecode(savedSponsorRaw) as Map<String, dynamic>;
        if (savedSponsor['trending'] is Map) {
          _sponsorTrending = Map<String, dynamic>.from(savedSponsor['trending'] as Map);
        }
        if (savedSponsor['radio'] is Map) {
          _sponsorRadio = Map<String, dynamic>.from(savedSponsor['radio'] as Map);
        }
        if (savedSponsor['search'] is Map) {
          _sponsorSearch = Map<String, dynamic>.from(savedSponsor['search'] as Map);
        }
        if (savedSponsor['library'] is Map) {
          _sponsorLibrary = Map<String, dynamic>.from(savedSponsor['library'] as Map);
        }
        if (savedSponsor['affiliate'] is Map) {
          _sponsorAffiliate = Map<String, dynamic>.from(savedSponsor['affiliate'] as Map);
        }
      } catch (_) {
        // Corrupted or missing data — keep the defaults.
      }
    }

    setState(() {
      _dataLoaded = true;
    });
  }

  void _saveSponsorSettings() {
    _lsSet('sponsorSettings', jsonEncode({
      'trending': _sponsorTrending,
      'radio': _sponsorRadio,
      'search': _sponsorSearch,
      'library': _sponsorLibrary,
      'affiliate': _sponsorAffiliate,
    }));
  }

  // Single per-slot updater used by the Ads & Sponsorships editor sheet —
  // each slot saves independently rather than requiring every field at once.
  void _updateSponsorSlot(String key, Map<String, dynamic> data) {
    setState(() {
      switch (key) {
        case 'trending':
          _sponsorTrending = data;
          break;
        case 'radio':
          _sponsorRadio = data;
          break;
        case 'search':
          _sponsorSearch = data;
          break;
        case 'library':
          _sponsorLibrary = data;
          break;
        case 'affiliate':
          _sponsorAffiliate = data;
          break;
      }
    });
    _saveSponsorSettings();
  }

  void _savePinnedItems() {
    _lsSet('pinnedItems', jsonEncode(_pinnedItems.toList()));
  }

  void _savePlaylists() {
    _lsSet('playlists', jsonEncode(_sampleItems['Playlists'] ?? []));
  }

  void _recordPlay(String title, String subtitle) {
    _playHistory.removeWhere((e) => e['title'] == title);
    _playHistory.insert(0, {'title': title, 'subtitle': subtitle});
    if (_playHistory.length > 8) {
      _playHistory = _playHistory.sublist(0, 8);
    }
    _lsSet('playHistory', jsonEncode(_playHistory));
    // _playHistory itself is capped at 8 (it's just "recently played"), so
    // a separate uncapped counter is kept for a real lifetime "Plays" stat
    // on the Profile screen.
    _totalPlays++;
    _lsSet('totalPlays', _totalPlays.toString());
  }

  List<_Track> get _recentlyPlayedTracks {
    if (_playHistory.isEmpty) {
      // Nothing played yet this install — show real songs instead of a
      // fake placeholder set, so even a first-time view is real content.
      return allRealSongs
          .take(8)
          .map((title) => _Track(title, songArtistMap[title] ?? '', const Color(0xFF9C27B0)))
          .toList();
    }
    return _playHistory
        .map((e) => _Track(e['title'] ?? '', e['subtitle'] ?? '', const Color(0xFF9C27B0)))
        .toList();
  }

  // Reverted from connectivity_plus back to the browser Network Information
  // API — connectivity_plus itself is fine, but it transitively pulls in
  // the `objective_c` package (for Apple-platform support), which uses
  // Dart's native-assets build hooks and breaks on this SDK's space-
  // containing install path. This browser API only reliably detects
  // Wi-Fi vs cellular on Chrome/Android — everywhere else it returns null,
  // and null means "allow the download" rather than block it, since we
  // can't actually confirm cellular is in use.
  Future<bool?> _isOnWifi() async {
    try {
      final connection = js.context['navigator']?['connection'];
      if (connection == null) return null;
      final type = connection['type'];
      if (type == null) return null;
      return type == 'wifi';
    } catch (_) {
      return null;
    }
  }

  bool _isDownloadOverWifiOnlyEnabled() {
    final raw = _lsGet('settings');
    if (raw == null) return false;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      return saved['downloadOverWifiOnly'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  void _setPro(bool value) {
    setState(() {
      _isPro = value;
      if (value) _isAdFree = false;
    });
    _lsSet('isPro', value.toString());
    if (value) _lsSet('isAdFree', 'false');
  }

  void _setAdFree(bool value) {
    setState(() {
      _isAdFree = value;
      if (value) _isPro = false;
    });
    _lsSet('isAdFree', value.toString());
    if (value) _lsSet('isPro', 'false');
  }

  // Plays a short spoken "Advertisement" audio clip, if the file exists and
  // audio ads are enabled in Settings. Wrapped defensively — the file is
  // optional (the user generates it themselves via free text-to-speech), so
  // a missing file just means no audio plays.
  Future<void> _playAdAnnouncement() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_getAdVolume());
      await _audioPlayer.play(AssetSource('audio/ad_announcement.mp3'));
      // Give the clip a moment to actually play before moving on to the
      // real song — there's no reliable "clip length" to wait for since
      // it's a user-supplied file.
      await Future.delayed(const Duration(seconds: 4));
      await _audioPlayer.setVolume(1.0);
    } catch (_) {
      // File not added yet, or failed to load — silently skip.
    }
  }

  // Brief ad break for non-Pro, non-Ad-Free users before every real song.
  // No popup — just a short "Advertisement" message on the mini player
  // while the spoken clip plays.
  Future<void> _showAdIfNeeded() async {
    if (_isPro || _isAdFree) return;

    setState(() {
      _currentTitle = 'Advertisement';
      _currentSubtitle = 'Please wait…';
    });

    await _playAdAnnouncement();
  }

  Future<void> _toggleSongDownload(String title) async {
    // Only enforce Wi-Fi-only when actually starting a new download — never
    // block removing one already downloaded.
    if (!_downloadedSongs.contains(title) && _isDownloadOverWifiOnlyEnabled()) {
      final onWifi = await _isOnWifi();
      if (onWifi == false) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Wi-Fi only for downloads is on — connect to Wi-Fi to download.')),
        );
        return;
      }
    }
    setState(() {
      if (_downloadedSongs.contains(title)) {
        _downloadedSongs.remove(title);
      } else {
        _downloadedSongs.add(title);
      }
      _sampleItems['Downloads'] = _downloadedSongs.toList();
    });
    _lsSet('downloadedSongs', jsonEncode(_downloadedSongs.toList()));
  }

  @override
  void dispose() {
    _safeJsCall('echoStopHls');
    _sleepTimerCountdown?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Checks the real song catalog first, then the real audiobook catalog,
  // falling back to the old pseudo-random song assignment for anything
  // that still doesn't have real audio (Artists, Podcasts, etc.).
  DemoTrack _resolveTrack(String title) {
    for (final t in demoTracks) {
      if (t.title == title) return t;
    }
    for (final t in demoAudiobooks) {
      if (t.title == title) return t;
    }
    for (final t in demoClassical) {
      if (t.title == title) return t;
    }
    return demoTracks[title.hashCode.abs() % demoTracks.length];
  }

  Future<void> _playTrack(String title, String subtitle, {bool clearQueue = true}) async {
    _safeJsCall('echoStopHls');
    if (clearQueue) {
      _queue = [];
      _queueIndex = -1;
      _queueCategory = '';
    }
    // Ad plays before real songs specifically (not audiobooks, not the
    // still-fake categories) — matches where the "free mode" experience
    // actually matters, since songs are the app's core content.
    final isRealSong = demoTracks.any((t) => t.title == title) ||
        demoClassical.any((t) => t.title == title);
    if (isRealSong) {
      await _showAdIfNeeded();
    }
    // Real song titles and real audiobook titles each map to their own
    // exact audio file. Anything else (an Artist name, a Podcast
    // placeholder, etc. — categories that don't have real audio yet) falls
    // back to the old pseudo-random assignment so tapping still plays
    // something.
    final track = _resolveTrack(title);
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(track.assetPath));
    setState(() {
      _currentTitle = title;
      // For the still-fake categories, the actual file being played won't
      // match the tapped title, so it's still worth showing which real file
      // is actually playing.
      _currentSubtitle = title == track.title ? subtitle : '$subtitle · Playing: ${track.title}';
      _isPlaying = true;
      _usingHls = false;
    });
    _recordPlay(title, subtitle);
  }

  // Starts playback from a specific position in a list — used when opening
  // a Playlist or Album (or jumping to an item in the Queue screen) so
  // Autoplay has an ordered sequence to continue through when each track
  // finishes.
  void _playFromList(List<String> items, int startIndex, String category) {
    setState(() {
      _queue = items;
      _queueIndex = startIndex;
      _queueCategory = category;
    });
    _playTrack(items[startIndex], category, clearQueue: false);
  }

  Future<void> _playRadio(RadioStation station) async {
    _queue = [];
    _queueIndex = -1;
    _queueCategory = '';
    if (station.isHls) {
      // Hand off to the hls.js bridge — audioplayers can't play .m3u8 on web.
      await _audioPlayer.stop();
      _safeJsCall('echoPlayHls', [station.url]);
      setState(() {
        _currentTitle = station.name;
        _currentSubtitle = 'Live Radio · ${station.genre}';
        _isPlaying = true;
        _usingHls = true;
      });
      _recordPlay(station.name, 'Live Radio · ${station.genre}');
    } else {
      _safeJsCall('echoStopHls');
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(station.url));
      setState(() {
        _currentTitle = station.name;
        _currentSubtitle = 'Live Radio · ${station.genre}';
        _isPlaying = true;
        _usingHls = false;
      });
      _recordPlay(station.name, 'Live Radio · ${station.genre}');
    }
  }

  Future<void> _togglePlayPause() async {
    if (_currentTitle == null) return;
    if (_usingHls) {
      if (_isPlaying) {
        _safeJsCall('echoPauseHls');
      } else {
        _safeJsCall('echoResumeHls');
      }
      setState(() {
        _isPlaying = !_isPlaying;
      });
    } else {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    }
  }

  // Starts (or restarts) the sleep timer — cancels any existing countdown
  // first, so picking a new duration always replaces the old one rather
  // than stacking. Ticks once a second purely to drive the mini player's
  // countdown display; the actual pause happens once remaining hits zero.
  void _startSleepTimer(Duration duration) {
    _sleepTimerCountdown?.cancel();
    setState(() {
      _sleepTimerRemaining = duration;
    });
    _sleepTimerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepTimerRemaining;
      if (remaining == null) {
        timer.cancel();
        return;
      }
      final next = remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        setState(() {
          _sleepTimerRemaining = null;
        });
        if (_isPlaying) {
          _togglePlayPause();
        }
      } else {
        setState(() {
          _sleepTimerRemaining = next;
        });
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimerCountdown?.cancel();
    _sleepTimerCountdown = null;
    setState(() {
      _sleepTimerRemaining = null;
    });
  }

  String _formatSleepTimerRemaining(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _openSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.bedtime_outlined, color: context.colors.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Sleep Timer',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_sleepTimerRemaining != null)
                ListTile(
                  leading: const Icon(Icons.timer_off_outlined, color: Colors.redAccent),
                  title: const Text('Turn off', style: TextStyle(color: Colors.redAccent)),
                  subtitle: Text(
                    'Currently stopping in ${_formatSleepTimerRemaining(_sleepTimerRemaining!)}',
                    style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                  ),
                  onTap: () {
                    _cancelSleepTimer();
                    Navigator.pop(sheetContext);
                  },
                ),
              ...[15, 30, 45, 60].map(
                (minutes) => ListTile(
                  leading: Icon(Icons.bedtime, color: context.colors.textSecondary),
                  title: Text('$minutes minutes', style: TextStyle(color: context.colors.textPrimary)),
                  onTap: () {
                    _startSleepTimer(Duration(minutes: minutes));
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _goToSearchTab() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  // ---- Shared Library data, so Home's story row and the Library tab stay in sync ----

  final List<_LibraryCategory> _categories = const [
    _LibraryCategory('Playlists', Icons.queue_music),
    _LibraryCategory('Songs', Icons.music_note),
    _LibraryCategory('Artists', Icons.person),
    _LibraryCategory('Albums', Icons.album),
    _LibraryCategory('Downloads', Icons.download_done),
    _LibraryCategory('Podcasts', Icons.mic),
    _LibraryCategory('Audiobooks', Icons.menu_book),
  ];

  final Map<String, List<String>> _sampleItems = {
    'Playlists': ['Chill Vibes', 'Workout Mix', 'Focus Flow', 'Late Night Drive'],
    'Songs': List<String>.from(allRealSongs),
    'Artists': ['Luna Ray', 'The Wanderers', 'Echo Park', 'Nova Sound'],
    'Albums': ['Midnight Tales', 'Neon Dreams', 'Quiet Storm', 'Paper Skies'],
    'Downloads': ['Offline Mix 1', 'Road Trip Playlist', 'Saved Podcast Ep.12'],
    'Podcasts': ['Mystery Hour', 'Tech Talk Daily', 'True Crime Weekly'],
    'Audiobooks': ['The Raven', 'The Tell-Tale Heart', 'The Cask of Amontillado'],
  };

  final Set<String> _pinnedItems = {'Songs|Adventure', 'Playlists|Chill Vibes'};
  final Set<String> _downloadedSongs = {};

  void _toggleItemPin(String category, String item) {
    final key = '$category|$item';
    setState(() {
      if (_pinnedItems.contains(key)) {
        _pinnedItems.remove(key);
      } else {
        _pinnedItems.add(key);
      }
    });
    _savePinnedItems();
  }

  Future<void> _openCategory(_LibraryCategory category) async {
    Map<String, List<String>>? itemSongs;
    if (category.name == 'Playlists') itemSongs = playlistSongs;
    if (category.name == 'Albums') itemSongs = albumSongs;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryItemsScreen(
          category: category.name,
          icon: category.icon,
          items: _sampleItems[category.name] ?? [],
          pinnedItems: _pinnedItems,
          onTogglePin: (item) => _toggleItemPin(category.name, item),
          onTogglePinForSongs: (item) => _toggleItemPin('Songs', item),
          onPlayFromList: _playFromList,
          downloadedSongs: _downloadedSongs,
          onToggleDownload: _toggleSongDownload,
          itemSongs: itemSongs,
        ),
      ),
    );
    setState(() {});
  }

  // Used by Home's story row, which deals in category name strings rather
  // than _LibraryCategory objects.
  void _openCategoryByName(String name) {
    _openCategory(_categories.firstWhere((c) => c.name == name));
  }

  void _openClassical() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClassicalScreen(onTrackTap: _playTrack)),
    );
  }

  void _createPlaylist() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('New Playlist', style: TextStyle(color: context.colors.textPrimary)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: TextStyle(color: context.colors.textTertiary),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.divider),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF9C27B0)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: context.colors.textTertiary)),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _sampleItems['Playlists']!.add(name);
                  });
                  _savePlaylists();
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Create', style: TextStyle(color: Color(0xFF9C27B0))),
            ),
          ],
        );
      },
    );
  }

  void _openBlend() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BlendScreen(onTrackTap: _playTrack)),
    );
  }

  void _openQueue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QueueScreen(
          queue: _queue,
          currentIndex: _queueIndex,
          category: _queueCategory,
          onJumpTo: (index) {
            setState(() {
              _queueIndex = index;
            });
            _playTrack(_queue[index], _queueCategory, clearQueue: false);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _handleAddMenuSelection(String value) {
    switch (value) {
      case 'playlist':
        _createPlaylist();
        break;
      case 'blend':
        _openBlend();
        break;
      case 'queue':
        _openQueue();
        break;
      case 'sleep_timer':
        _openSleepTimerSheet();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9C27B0)),
        ),
      );
    }

    const storyEntries = [
      _StoryEntry('Podcasts', Icons.mic),
      _StoryEntry('Audiobooks', Icons.menu_book),
      _StoryEntry('Artists', Icons.person),
      _StoryEntry('Classical', Icons.piano, isSpecial: true),
      _StoryEntry('Playlists', Icons.queue_music),
      _StoryEntry('Songs', Icons.music_note),
      _StoryEntry('Albums', Icons.album),
    ];

    final pages = [
      HomeContent(
        onTrackTap: _playTrack,
        onRadioTap: _playRadio,
        storyEntries: storyEntries,
        onCategoryTap: _openCategoryByName,
        onClassicalTap: _openClassical,
        recentlyPlayed: _recentlyPlayedTracks,
        downloadedSongs: _downloadedSongs,
        onToggleDownload: _toggleSongDownload,
        sponsorTrendingName: _sponsorTrending['name'] as String? ?? 'Your Brand Here',
        sponsorRadioName: _sponsorRadio['name'] as String? ?? 'Your Station Here',
        affiliateArtist: _sponsorAffiliate['artist'] as String?,
      ),
      SearchScreen(
        onTrackTap: _playTrack,
        downloadedSongs: _downloadedSongs,
        onToggleDownload: _toggleSongDownload,
        sponsorName: _sponsorSearch['name'] as String? ?? 'Your Sponsor Here',
      ),
      LibraryScreen(
        onTrackTap: _playTrack,
        onSearchTap: _goToSearchTab,
        categories: _categories,
        sampleItems: _sampleItems,
        pinnedItems: _pinnedItems,
        onTogglePin: _toggleItemPin,
        onOpenCategory: _openCategory,
        onAddMenuSelection: _handleAddMenuSelection,
        sponsorLibraryName: _sponsorLibrary['name'] as String? ?? 'Your Brand Here',
        sponsorTrendingData: _sponsorTrending,
        sponsorRadioData: _sponsorRadio,
        sponsorSearchData: _sponsorSearch,
        sponsorLibraryData: _sponsorLibrary,
        sponsorAffiliateData: _sponsorAffiliate,
        artistOptions: _sampleItems['Artists'] ?? [],
        onUpdateSponsorSlot: _updateSponsorSlot,
        isDarkMode: widget.isDarkMode,
        onSetDarkMode: widget.onSetDarkMode,
        totalPlays: _totalPlays,
        isPro: _isPro,
        onSetPro: _setPro,
        isAdFree: _isAdFree,
        onSetAdFree: _setAdFree,
      ),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 64,
            color: context.colors.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.music_note, color: context.colors.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentTitle ?? 'No track playing',
                        style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _currentSubtitle ?? 'Tap something to play',
                        style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_sleepTimerRemaining != null)
                  GestureDetector(
                    onTap: _openSleepTimerSheet,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bedtime, color: context.colors.textSecondary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _formatSleepTimerRemaining(_sleepTimerRemaining!),
                            style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: context.colors.textPrimary,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ],
            ),
          ),
          BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
            backgroundColor: context.colors.surface,
            selectedItemColor: const Color(0xFF9C27B0),
            unselectedItemColor: context.colors.textTertiary,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
              BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- SPONSORSHIP HELPERS ----------------

// Shown whenever the user taps an empty/placeholder sponsored slot anywhere
// in the app. Kept as a single shared dialog so the wording and contact
// details only need updating in one place once real sponsors are involved.
void showSponsorshipInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Sponsorship', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'This space is reserved for a sponsor. Sponsored placements let a '
          'brand, artist, podcast, or label appear here to Echo All Sounds '
          'listeners.\n\n'
          'Interested in sponsoring a spot like this one? Get in touch at '
          'sponsors@echoallsounds.com and we\'ll send over pricing and terms.',
          style: TextStyle(color: context.colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close', style: TextStyle(color: Color(0xFF9C27B0))),
          ),
        ],
      );
    },
  );
}

// Separate, smaller dialog for the free/affiliate-only placement — no flat
// fee, just a shared link with a commission on anything it sells, so the
// wording (and the pitch to a prospective partner) is different from the
// paid sponsorship slots above.
void showAffiliateInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Affiliate Link', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'This is a small, no-fee spot for affiliate partners — things like '
          'concert tickets, merch, or music gear. No upfront cost: you just '
          'share a trackable link and Echo All Sounds earns a commission on '
          'anything sold through it.\n\n'
          'Want a spot here? Reach out at partners@echoallsounds.com.',
          style: TextStyle(color: context.colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close', style: TextStyle(color: Color(0xFF9C27B0))),
          ),
        ],
      );
    },
  );
}

// ---------------- HOME CONTENT ----------------

// An item in Home's top story-style row. Most map straight to a real
// Library category (Playlists, Songs, Albums, etc.); Classical is special —
// it isn't a Library category, it opens its own dedicated section instead.
class _StoryEntry {
  final String name;
  final IconData icon;
  final bool isSpecial;
  const _StoryEntry(this.name, this.icon, {this.isSpecial = false});
}

class HomeContent extends StatelessWidget {
  final void Function(String title, String subtitle) onTrackTap;
  final void Function(RadioStation station) onRadioTap;
  final List<_StoryEntry> storyEntries;
  final void Function(String categoryName) onCategoryTap;
  final VoidCallback onClassicalTap;
  final List<_Track> recentlyPlayed;
  final Set<String> downloadedSongs;
  final void Function(String title) onToggleDownload;
  final String sponsorTrendingName;
  final String sponsorRadioName;
  final String? affiliateArtist;

  const HomeContent({
    super.key,
    required this.onTrackTap,
    required this.onRadioTap,
    required this.storyEntries,
    required this.onCategoryTap,
    required this.onClassicalTap,
    required this.recentlyPlayed,
    required this.downloadedSongs,
    required this.onToggleDownload,
    required this.sponsorTrendingName,
    required this.sponsorRadioName,
    required this.affiliateArtist,
  });

  Color _colorForCategory(String name) {
    switch (name) {
      case 'Podcasts':
        return const Color(0xFF3F51B5);
      case 'Audiobooks':
        return const Color(0xFF009688);
      case 'Artists':
        return const Color(0xFFE91E63);
      case 'Classical':
        return const Color(0xFFC9A961);
      case 'Playlists':
        return const Color(0xFFFF9800);
      case 'Songs':
        return const Color(0xFF4CAF50);
      case 'Albums':
        return const Color(0xFF00BCD4);
      default:
        return const Color(0xFF9C27B0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trending = allRealSongs
        .map((title) => _Track(title, songArtistMap[title] ?? '', const Color(0xFFFF9800)))
        .toList();
    // Sponsored slot — placeholder until a real sponsor is signed up. Sits
    // in the 3rd position, styled distinctly and clearly labeled so it
    // never gets confused with real tracks.
    trending.insert(
      2,
      _Track(sponsorTrendingName, 'Sponsored', const Color(0xFF4CAF50), isSponsored: true),
    );

    // Same 12 real songs, reversed order — gives Suggestions a different
    // feel from Trending without needing more real songs than exist yet.
    final suggestions = allRealSongs.reversed
        .map((title) => _Track(title, songArtistMap[title] ?? '', const Color(0xFF4CAF50)))
        .toList();

    // Radio row with a sponsored "station" slot inserted, same idea as the
    // trending row above — a separate list so the real radioStations const
    // list (used elsewhere for actual playback) stays untouched.
    final radioWithSponsor = List<RadioStation>.from(radioStations);
    radioWithSponsor.insert(
      2,
      RadioStation(sponsorRadioName, 'Sponsored', '', isSponsored: true),
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Echo All Sounds',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: storyEntries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final item = storyEntries[index];
                final color = _colorForCategory(item.name);
                return GestureDetector(
                  onTap: () => item.isSpecial ? onClassicalTap() : onCategoryTap(item.name),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _TrackRow(
            title: 'Recently Played',
            tracks: recentlyPlayed,
            onTrackTap: onTrackTap,
            downloadedSongs: downloadedSongs,
            onToggleDownload: onToggleDownload,
          ),
          const SizedBox(height: 24),
          _TrackRow(
            title: 'Trending Now',
            tracks: trending,
            onTrackTap: onTrackTap,
            downloadedSongs: downloadedSongs,
            onToggleDownload: onToggleDownload,
          ),
          const SizedBox(height: 24),
          _RadioRow(stations: radioWithSponsor, onRadioTap: onRadioTap),
          const SizedBox(height: 24),
          _TrackRow(
            title: 'Suggestions For You',
            tracks: suggestions,
            onTrackTap: onTrackTap,
            downloadedSongs: downloadedSongs,
            onToggleDownload: onToggleDownload,
          ),
          const SizedBox(height: 24),
          _AffiliateLinkRow(artistName: affiliateArtist),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Small, no-fee affiliate-only placement — deliberately slimmer and lower-key
// than the paid "SPONSORED" slots above, since it's a different offer (free
// listing, commission-based) aimed at smaller partners.
class _AffiliateLinkRow extends StatelessWidget {
  final String? artistName;
  const _AffiliateLinkRow({required this.artistName});

  @override
  Widget build(BuildContext context) {
    final label = artistName != null
        ? 'Official $artistName Merch & Tickets'
        : 'Get Tickets & Merch — affiliate partner spot';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => showAffiliateInfoDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.divider),
          ),
          child: Row(
            children: [
              Icon(Icons.link, color: context.colors.textTertiary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3F51B5).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AFFILIATE',
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final String title;
  final List<_Track> tracks;
  final void Function(String title, String subtitle) onTrackTap;
  final Set<String> downloadedSongs;
  final void Function(String title) onToggleDownload;

  const _TrackRow({
    required this.title,
    required this.tracks,
    required this.onTrackTap,
    required this.downloadedSongs,
    required this.onToggleDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final track = tracks[index];
              return GestureDetector(
                onTap: () {
                  if (track.isSponsored) {
                    showSponsorshipInfoDialog(context);
                  } else {
                    onTrackTap(track.title, track.subtitle);
                  }
                },
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: track.color,
                              borderRadius: BorderRadius.circular(8),
                              border: track.isSponsored
                                  ? Border.all(color: Colors.white38, width: 1)
                                  : null,
                            ),
                            child: Icon(
                              track.isSponsored ? Icons.campaign_outlined : Icons.music_note,
                              color: Colors.white70,
                              size: 36,
                            ),
                          ),
                          if (track.isSponsored)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SPONSORED',
                                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          if (!track.isSponsored)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => onToggleDownload(track.title),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  child: Icon(
                                    downloadedSongs.contains(track.title)
                                        ? Icons.download_done
                                        : Icons.download_outlined,
                                    color: downloadedSongs.contains(track.title)
                                        ? const Color(0xFF9C27B0)
                                        : Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  final List<RadioStation> stations;
  final void Function(RadioStation station) onRadioTap;

  const _RadioRow({required this.stations, required this.onRadioTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Radio',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final station = stations[index];
              return GestureDetector(
                onTap: () {
                  if (station.isSponsored) {
                    showSponsorshipInfoDialog(context);
                  } else {
                    onRadioTap(station);
                  }
                },
                child: SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 130,
                            height: 90,
                            decoration: BoxDecoration(
                              color: station.isSponsored ? const Color(0xFF4CAF50) : const Color(0xFF00BCD4),
                              borderRadius: BorderRadius.circular(8),
                              border: station.isSponsored
                                  ? Border.all(color: Colors.white38, width: 1)
                                  : null,
                            ),
                            child: Icon(
                              station.isSponsored ? Icons.campaign_outlined : Icons.radio,
                              color: Colors.white70,
                              size: 32,
                            ),
                          ),
                          if (station.isHls)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'HLS',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          if (station.isSponsored)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SPONSORED',
                                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        station.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                      ),
                      Text(
                        station.genre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Track {
  final String title;
  final String subtitle;
  final Color color;
  final bool isSponsored;
  const _Track(this.title, this.subtitle, this.color, {this.isSponsored = false});
}

// ---------------- SEARCH DATA ----------------

class SearchableItem {
  final String name;
  final String category;
  final IconData icon;
  final String genre;
  const SearchableItem(this.name, this.category, this.icon, this.genre);
}

const List<SearchableItem> allSearchableItems = [
  SearchableItem('Chill Vibes', 'Playlists', Icons.queue_music, 'Chill'),
  SearchableItem('Workout Mix', 'Playlists', Icons.queue_music, 'Electronic'),
  SearchableItem('Focus Flow', 'Playlists', Icons.queue_music, 'Chill'),
  SearchableItem('Late Night Drive', 'Playlists', Icons.queue_music, 'Electronic'),
  SearchableItem('Adventure', 'Songs', Icons.music_note, 'Classical'),
  SearchableItem('Ancient Rite', 'Songs', Icons.music_note, 'Classical'),
  SearchableItem('Be Chillin', 'Songs', Icons.music_note, 'Chill'),
  SearchableItem('Big Eyes', 'Songs', Icons.music_note, 'Pop'),
  SearchableItem('City Sunshine', 'Songs', Icons.music_note, 'Pop'),
  SearchableItem('Cornfield Chase', 'Songs', Icons.music_note, 'Chill'),
  SearchableItem('Black Knight', 'Songs', Icons.music_note, 'Rock'),
  SearchableItem('Emotional Blockbuster 2', 'Songs', Icons.music_note, 'Classical'),
  SearchableItem('Epic Boss Battle', 'Songs', Icons.music_note, 'Rock'),
  SearchableItem('Evil Incoming', 'Songs', Icons.music_note, 'Electronic'),
  SearchableItem('Fanfare X', 'Songs', Icons.music_note, 'Classical'),
  SearchableItem('Funshine', 'Songs', Icons.music_note, 'Pop'),
  SearchableItem('Assassin', 'Songs', Icons.music_note, 'Rock'),
  SearchableItem('Behind Enemy Lines', 'Songs', Icons.music_note, 'Electronic'),
  SearchableItem('Luna Ray', 'Artists', Icons.person, 'Pop'),
  SearchableItem('The Wanderers', 'Artists', Icons.person, 'Rock'),
  SearchableItem('Echo Park', 'Artists', Icons.person, 'Electronic'),
  SearchableItem('Nova Sound', 'Artists', Icons.person, 'Hip-Hop'),
  SearchableItem('Midnight Tales', 'Albums', Icons.album, 'Rock'),
  SearchableItem('Neon Dreams', 'Albums', Icons.album, 'Electronic'),
  SearchableItem('Quiet Storm', 'Albums', Icons.album, 'Chill'),
  SearchableItem('Paper Skies', 'Albums', Icons.album, 'Classical'),
  SearchableItem('Offline Mix 1', 'Downloads', Icons.download_done, 'Chill'),
  SearchableItem('Road Trip Playlist', 'Downloads', Icons.download_done, 'Rock'),
  SearchableItem('Saved Podcast Ep.12', 'Downloads', Icons.download_done, 'Podcasts'),
  SearchableItem('Mystery Hour', 'Podcasts', Icons.mic, 'Podcasts'),
  SearchableItem('Tech Talk Daily', 'Podcasts', Icons.mic, 'Podcasts'),
  SearchableItem('True Crime Weekly', 'Podcasts', Icons.mic, 'Podcasts'),
  SearchableItem('The Raven', 'Audiobooks', Icons.menu_book, 'Audiobooks'),
  SearchableItem('The Tell-Tale Heart', 'Audiobooks', Icons.menu_book, 'Audiobooks'),
  SearchableItem('The Cask of Amontillado', 'Audiobooks', Icons.menu_book, 'Audiobooks'),
  SearchableItem('Canon in D Major', 'Classical', Icons.piano, 'Classical'),
  SearchableItem('Orchestral Suite No. 2: Badinerie', 'Classical', Icons.piano, 'Classical'),
  SearchableItem('The Four Seasons: Spring (Allegro)', 'Classical', Icons.piano, 'Classical'),
  SearchableItem('Overture: Egmont, Op. 84', 'Classical', Icons.piano, 'Classical'),
  SearchableItem('Für Elise', 'Classical', Icons.piano, 'Classical'),
  SearchableItem('1812 Overture, Op. 49', 'Classical', Icons.piano, 'Classical'),
  SearchableItem('Overture: William Tell', 'Classical', Icons.piano, 'Classical'),
  SearchableItem("Midsummer Night's Dream: Wedding March", 'Classical', Icons.piano, 'Classical'),
  SearchableItem('Boléro', 'Classical', Icons.piano, 'Classical'),
  SearchableItem('Sabre Dance', 'Classical', Icons.piano, 'Classical'),
];

// ---------------- SEARCH SCREEN ----------------

class SearchScreen extends StatefulWidget {
  final void Function(String title, String subtitle) onTrackTap;
  final Set<String> downloadedSongs;
  final void Function(String title) onToggleDownload;
  final String sponsorName;
  const SearchScreen({
    super.key,
    required this.onTrackTap,
    required this.downloadedSongs,
    required this.onToggleDownload,
    required this.sponsorName,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  String? _activeGenre;

  List<String> _recentSearches = [
    'Lo-fi beats',
    'True crime podcasts',
    'Harry Potter audiobook',
    'Top hits 2026',
    'Chill vibes',
  ];

  final List<_Genre> _genres = const [
    _Genre('Pop', Color(0xFFE91E63)),
    _Genre('Hip-Hop', Color(0xFFFF9800)),
    _Genre('Rock', Color(0xFF795548)),
    _Genre('Podcasts', Color(0xFF3F51B5)),
    _Genre('Audiobooks', Color(0xFF009688)),
    _Genre('Chill', Color(0xFF00BCD4)),
    _Genre('Electronic', Color(0xFF9C27B0)),
    _Genre('Classical', Color(0xFF607D8B)),
  ];

  void _selectGenre(String genre) {
    setState(() {
      _activeGenre = genre;
      _query = genre;
    });
    _controller.text = genre;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: genre.length));
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _recentSearches.remove(trimmed);
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 5) {
        _recentSearches = _recentSearches.sublist(0, 5);
      }
      _query = trimmed;
      _activeGenre = null;
    });

    _controller.text = trimmed;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: trimmed.length));
    FocusScope.of(context).unfocus();
  }

  void _removeSearch(String query) {
    setState(() {
      _recentSearches.remove(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Search',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.black),
              onSubmitted: _submitSearch,
              onChanged: (value) => setState(() {
                _query = value;
                _activeGenre = null;
              }),
              decoration: InputDecoration(
                hintText: 'Songs, podcasts, audiobooks...',
                hintStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.black54),
                  onPressed: () => _submitSearch(_controller.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _query.trim().isEmpty
                  ? _buildDefaultContent()
                  : _buildResultsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    final matches = _activeGenre != null
        ? allSearchableItems.where((item) => item.genre == _activeGenre).toList()
        : allSearchableItems
            .where((item) => item.name.toLowerCase().contains(_query.trim().toLowerCase()))
            .toList();

    if (matches.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(color: context.colors.textTertiary, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final item = matches[index];
        final isSong = item.category == 'Songs';
        final isDownloaded = widget.downloadedSongs.contains(item.name);
        return ListTile(
          leading: Icon(item.icon, color: context.colors.textSecondary, size: 22),
          title: Text(item.name, style: TextStyle(color: context.colors.textPrimary)),
          subtitle: Text(item.category, style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
          trailing: isSong
              ? Tooltip(
                  message: isDownloaded ? 'Remove download' : 'Download',
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDownloaded
                            ? const Color(0xFF9C27B0).withOpacity(0.2)
                            : context.colors.textTertiary.withOpacity(0.15),
                      ),
                      child: Icon(
                        isDownloaded ? Icons.download_done : Icons.download_outlined,
                        color: isDownloaded ? const Color(0xFF9C27B0) : context.colors.textSecondary,
                        size: 20,
                      ),
                    ),
                    onPressed: () => widget.onToggleDownload(item.name),
                  ),
                )
              : null,
          onTap: () {
            _submitSearch(item.name);
            widget.onTrackTap(item.name, item.category);
          },
        );
      },
    );
  }

  Widget _buildDefaultContent() {
    return ListView(
                children: [
                  if (_recentSearches.isNotEmpty) ...[
                    Text(
                      'Recent searches',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._recentSearches.map(
                      (search) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.history, color: context.colors.textTertiary),
                        title: Text(
                          search,
                          style: TextStyle(color: context.colors.textPrimary),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.close, color: context.colors.textTertiary, size: 20),
                          onPressed: () => _removeSearch(search),
                        ),
                        onTap: () => _submitSearch(search),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  GestureDetector(
                    onTap: () => showSponsorshipInfoDialog(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B3A22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.colors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign_outlined, color: Colors.white70, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.sponsorName,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                const Text(
                                  'This search placement is available',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SPONSORED',
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    'Browse genres',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _genres.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                    ),
                    itemBuilder: (context, index) {
                      final genre = _genres[index];
                      return GestureDetector(
                        onTap: () => _selectGenre(genre.name),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: genre.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              genre.name,
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              );
  }
}

class _Genre {
  final String name;
  final Color color;
  const _Genre(this.name, this.color);
}

// ---------------- LIBRARY SCREEN ----------------

class _LibraryCategory {
  final String name;
  final IconData icon;
  const _LibraryCategory(this.name, this.icon);
}

class LibraryScreen extends StatelessWidget {
  final void Function(String title, String subtitle) onTrackTap;
  final VoidCallback onSearchTap;
  final List<_LibraryCategory> categories;
  final Map<String, List<String>> sampleItems;
  final Set<String> pinnedItems;
  final void Function(String category, String item) onTogglePin;
  final Future<void> Function(_LibraryCategory category) onOpenCategory;
  final void Function(String value) onAddMenuSelection;
  final String sponsorLibraryName;
  final Map<String, dynamic> sponsorTrendingData;
  final Map<String, dynamic> sponsorRadioData;
  final Map<String, dynamic> sponsorSearchData;
  final Map<String, dynamic> sponsorLibraryData;
  final Map<String, dynamic> sponsorAffiliateData;
  final List<String> artistOptions;
  final void Function(String key, Map<String, dynamic> data) onUpdateSponsorSlot;
  final bool isDarkMode;
  final void Function(bool isDark) onSetDarkMode;
  final int totalPlays;
  final bool isPro;
  final void Function(bool isPro) onSetPro;
  final bool isAdFree;
  final void Function(bool isAdFree) onSetAdFree;

  const LibraryScreen({
    super.key,
    required this.onTrackTap,
    required this.onSearchTap,
    required this.categories,
    required this.sampleItems,
    required this.pinnedItems,
    required this.onTogglePin,
    required this.onOpenCategory,
    required this.onAddMenuSelection,
    required this.sponsorLibraryName,
    required this.sponsorTrendingData,
    required this.sponsorRadioData,
    required this.sponsorSearchData,
    required this.sponsorLibraryData,
    required this.sponsorAffiliateData,
    required this.artistOptions,
    required this.onUpdateSponsorSlot,
    required this.isDarkMode,
    required this.onSetDarkMode,
    required this.totalPlays,
    required this.isPro,
    required this.onSetPro,
    required this.isAdFree,
    required this.onSetAdFree,
  });

  IconData _iconForCategory(String category) {
    return categories.firstWhere((c) => c.name == category).icon;
  }

  @override
  Widget build(BuildContext context) {
    final pinnedList = pinnedItems.toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          sampleItems: sampleItems,
                          pinnedItems: pinnedItems,
                          totalPlays: totalPlays,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF9C27B0),
                        ),
                        child: Icon(Icons.person, color: context.colors.textPrimary, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubscriptionsScreen(
                          isPro: isPro,
                          onSetPro: onSetPro,
                          isAdFree: isAdFree,
                          onSetAdFree: onSetAdFree,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Subscriptions',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.search, color: context.colors.textPrimary, size: 22),
                  onPressed: onSearchTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                PopupMenuButton<String>(
                  icon: Icon(Icons.add, color: context.colors.textPrimary, size: 22),
                  color: context.colors.surface,
                  padding: EdgeInsets.zero,
                  onSelected: onAddMenuSelection,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'playlist',
                      child: Text('Make Playlist', style: TextStyle(color: context.colors.textPrimary)),
                    ),
                    PopupMenuItem(
                      value: 'blend',
                      child: Text('Blend', style: TextStyle(color: context.colors.textPrimary)),
                    ),
                    PopupMenuItem(
                      value: 'queue',
                      child: Text('Queue', style: TextStyle(color: context.colors.textPrimary)),
                    ),
                    PopupMenuItem(
                      value: 'sleep_timer',
                      child: Text('Sleep Timer', style: TextStyle(color: context.colors.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.settings, color: context.colors.textPrimary, size: 22),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          sampleItems: sampleItems,
                          pinnedItems: pinnedItems,
                          sponsorTrendingData: sponsorTrendingData,
                          sponsorRadioData: sponsorRadioData,
                          sponsorSearchData: sponsorSearchData,
                          sponsorLibraryData: sponsorLibraryData,
                          sponsorAffiliateData: sponsorAffiliateData,
                          artistOptions: artistOptions,
                          onUpdateSponsorSlot: onUpdateSponsorSlot,
                          isDarkMode: isDarkMode,
                          onSetDarkMode: onSetDarkMode,
                          totalPlays: totalPlays,
                          isPro: isPro,
                          onSetPro: onSetPro,
                          isAdFree: isAdFree,
                          onSetAdFree: onSetAdFree,
                        ),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(color: context.colors.divider, height: 1),
          Expanded(
            child: ListView(
              children: [
                // Full category list — Apple Music style rows. Tap to browse items.
                ...categories.map((category) {
                  return ListTile(
                    leading: Icon(category.icon, color: context.colors.textPrimary, size: 24),
                    title: Text(
                      category.name,
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 16),
                    ),
                    trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
                    onTap: () => onOpenCategory(category),
                  );
                }),

                // Sponsored row — sits with the category list since that's the
                // first thing people scan in Library. Placeholder until a real
                // sponsor is signed up.
                ListTile(
                  leading: Icon(Icons.campaign_outlined, color: context.colors.textSecondary, size: 24),
                  title: Text(
                    sponsorLibraryName,
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 16),
                  ),
                  subtitle: Text(
                    'Sponsored placement available',
                    style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SPONSORED',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () => showSponsorshipInfoDialog(context),
                ),

                const SizedBox(height: 8),
                Divider(color: context.colors.divider, height: 1),
                const SizedBox(height: 16),

                // Pinned section — shows the actual songs/artists/etc. the user pinned
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Pinned',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (pinnedList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Open a category above and tap the pin icon on any item to add it here.',
                      style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
                    ),
                  )
                else
                  ...pinnedList.map((key) {
                    final parts = key.split('|');
                    final category = parts[0];
                    final itemName = parts[1];
                    return ListTile(
                      leading: Icon(_iconForCategory(category), color: const Color(0xFF9C27B0), size: 22),
                      title: Text(
                        itemName,
                        style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
                      ),
                      subtitle: Text(
                        category,
                        style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                      ),
                      onTap: () => onTrackTap(itemName, category),
                      trailing: IconButton(
                        icon: const Icon(Icons.push_pin, color: Color(0xFF9C27B0), size: 20),
                        onPressed: () => onTogglePin(category, itemName),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- CATEGORY ITEMS SCREEN ----------------

class CategoryItemsScreen extends StatefulWidget {
  final String category;
  final String? displayTitle;
  final IconData icon;
  final List<String> items;
  final Set<String> pinnedItems;
  final void Function(String item) onTogglePin;
  final void Function(String item) onTogglePinForSongs;
  final void Function(List<String> items, int startIndex, String category) onPlayFromList;
  final Set<String> downloadedSongs;
  final void Function(String item) onToggleDownload;
  final Map<String, List<String>>? itemSongs;

  const CategoryItemsScreen({
    super.key,
    required this.category,
    this.displayTitle,
    required this.icon,
    required this.items,
    required this.pinnedItems,
    required this.onTogglePin,
    required this.onTogglePinForSongs,
    required this.onPlayFromList,
    required this.downloadedSongs,
    required this.onToggleDownload,
    this.itemSongs,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDownloadable = widget.category == 'Songs' || widget.category == 'Audiobooks';
    final subtitleMap = widget.category == 'Songs'
        ? songArtistMap
        : widget.category == 'Audiobooks'
            ? audiobookAuthorMap
            : null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(widget.displayTitle ?? widget.category),
        foregroundColor: context.colors.textPrimary,
      ),
      body: widget.items.isEmpty
          ? Center(
              child: Text(
                'Nothing here yet.',
                style: TextStyle(color: context.colors.textTertiary),
              ),
            )
          : ListView.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final itemName = widget.items[index];
                final key = '${widget.category}|$itemName';
                final isPinned = widget.pinnedItems.contains(key);
                final isDownloaded = widget.downloadedSongs.contains(itemName);
                return ListTile(
                  leading: Icon(widget.icon, color: context.colors.textSecondary, size: 22),
                  title: Text(
                    itemName,
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
                  ),
                  subtitle: subtitleMap != null && subtitleMap.containsKey(itemName)
                      ? Text(
                          subtitleMap[itemName]!,
                          style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDownloadable)
                        Tooltip(
                          message: isDownloaded ? 'Remove download' : 'Download',
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDownloaded
                                    ? const Color(0xFF9C27B0).withOpacity(0.2)
                                    : context.colors.textTertiary.withOpacity(0.15),
                              ),
                              child: Icon(
                                isDownloaded ? Icons.download_done : Icons.download_outlined,
                                color: isDownloaded ? const Color(0xFF9C27B0) : context.colors.textSecondary,
                                size: 22,
                              ),
                            ),
                            onPressed: () => widget.onToggleDownload(itemName),
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          color: isPinned ? const Color(0xFF9C27B0) : context.colors.textTertiary,
                          size: 20,
                        ),
                        onPressed: () {
                          widget.onTogglePin(itemName);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    if (widget.itemSongs != null) {
                      final songs = widget.itemSongs![itemName] ?? [];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryItemsScreen(
                            category: 'Songs',
                            displayTitle: itemName,
                            icon: Icons.music_note,
                            items: songs,
                            pinnedItems: widget.pinnedItems,
                            onTogglePin: widget.onTogglePinForSongs,
                            onTogglePinForSongs: widget.onTogglePinForSongs,
                            onPlayFromList: widget.onPlayFromList,
                            downloadedSongs: widget.downloadedSongs,
                            onToggleDownload: widget.onToggleDownload,
                          ),
                        ),
                      );
                    } else {
                      widget.onPlayFromList(widget.items, index, widget.category);
                    }
                  },
                );
              },
            ),
    );
  }
}

// ---------------- SETTINGS SCREEN ----------------

class SettingsScreen extends StatefulWidget {
  final Map<String, List<String>> sampleItems;
  final Set<String> pinnedItems;
  final Map<String, dynamic> sponsorTrendingData;
  final Map<String, dynamic> sponsorRadioData;
  final Map<String, dynamic> sponsorSearchData;
  final Map<String, dynamic> sponsorLibraryData;
  final Map<String, dynamic> sponsorAffiliateData;
  final List<String> artistOptions;
  final void Function(String key, Map<String, dynamic> data) onUpdateSponsorSlot;
  final bool isDarkMode;
  final void Function(bool isDark) onSetDarkMode;
  final int totalPlays;
  final bool isPro;
  final void Function(bool isPro) onSetPro;
  final bool isAdFree;
  final void Function(bool isAdFree) onSetAdFree;

  const SettingsScreen({
    super.key,
    required this.sampleItems,
    required this.pinnedItems,
    required this.sponsorTrendingData,
    required this.sponsorRadioData,
    required this.sponsorSearchData,
    required this.sponsorLibraryData,
    required this.sponsorAffiliateData,
    required this.artistOptions,
    required this.onUpdateSponsorSlot,
    required this.isDarkMode,
    required this.onSetDarkMode,
    required this.totalPlays,
    required this.isPro,
    required this.onSetPro,
    required this.isAdFree,
    required this.onSetAdFree,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoplay = true;
  bool _crossfade = false;
  bool _downloadOverWifiOnly = true;
  bool _notificationsEnabled = true;
  String _audioQuality = 'High';
  String _downloadQuality = 'Normal';

  // Ad volume — how loud the spoken pre-song ad clip plays.
  String _adVolume = 'Normal';

  // Tracked locally rather than read straight from widget.isDarkMode —
  // this screen is opened via Navigator.push, which only passes props once
  // at push time, so it never automatically hears about the value changing
  // afterwards. Mirroring it into local state (seeded once in initState,
  // updated on every toggle) is what makes the switch actually slide.
  late bool _isDarkMode;

  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final raw = _lsGet('settings');
    Map<String, dynamic> saved = {};
    if (raw != null) {
      try {
        saved = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        // Corrupted data — fall back to defaults below.
      }
    }
    setState(() {
      _autoplay = saved['autoplay'] as bool? ?? true;
      _crossfade = saved['crossfade'] as bool? ?? false;
      _downloadOverWifiOnly = saved['downloadOverWifiOnly'] as bool? ?? true;
      _notificationsEnabled = saved['notificationsEnabled'] as bool? ?? true;
      _audioQuality = saved['audioQuality'] as String? ?? 'High';
      _downloadQuality = saved['downloadQuality'] as String? ?? 'Normal';
      _adVolume = saved['adVolume'] as String? ?? 'Normal';
      _settingsLoaded = true;
    });
  }

  void _saveSetting(String key, Object value) {
    final raw = _lsGet('settings');
    Map<String, dynamic> saved = {};
    if (raw != null) {
      try {
        saved = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        // Corrupted data — start fresh.
      }
    }
    saved[key] = value;
    _lsSet('settings', jsonEncode(saved));
  }

  // Opens a dropdown-+ Submit-button placeholder editor — same shape as
  // the sponsor slot editors — used for both Ad frequency and Ad volume.
  void _openDropdownSubmitSheet({
    required String title,
    required List<String> options,
    required String current,
    required void Function(String value) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DropdownSubmitSheet(
        title: title,
        options: options,
        initialValue: current,
        onSave: onSave,
      ),
    );
  }

  // Opens the "Submit an Audio Ad" placeholder — company, purpose, and
  // script — same bottom-sheet-with-Submit shape as the sponsor slot
  // editors. Not wired up to actually serve the ad yet; just captures the
  // submission for now.
  void _openAudioAdSubmissionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _AudioAdSubmissionSheet(),
    );
  }

  void _pickQuality(String title, List<String> options, String current, ValueChanged<String> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return ListTile(
                title: Text(option, style: TextStyle(color: context.colors.textPrimary)),
                trailing: option == current
                    ? const Icon(Icons.check, color: Color(0xFF9C27B0))
                    : null,
                onTap: () {
                  onSelected(option);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9C27B0)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Settings'),
        foregroundColor: context.colors.textPrimary,
      ),
      body: ListView(
        children: [
          _SettingsSectionHeader('Appearance'),
          SwitchListTile(
            secondary: Icon(
              _isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: context.colors.textSecondary,
            ),
            title: Text('Dark Mode', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text(
              'Switches the app theme. Individual screens are still being updated to fully match.',
              style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
            ),
            value: _isDarkMode,
            activeColor: const Color(0xFF9C27B0),
            onChanged: (value) {
              setState(() => _isDarkMode = value);
              widget.onSetDarkMode(value);
            },
          ),

          _SettingsSectionHeader('Account'),
          ListTile(
            leading: Icon(Icons.person, color: context.colors.textSecondary),
            title: Text('Profile', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text('Edit your name and photo', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    sampleItems: widget.sampleItems,
                    pinnedItems: widget.pinnedItems,
                    totalPlays: widget.totalPlays,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.workspace_premium, color: context.colors.textSecondary),
            title: Text('Subscription', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text(
              widget.isPro
                  ? 'Pro (local demo)'
                  : widget.isAdFree
                      ? 'Ad-Free (local demo)'
                      : 'Free plan',
              style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubscriptionsScreen(
                    isPro: widget.isPro,
                    onSetPro: widget.onSetPro,
                    isAdFree: widget.isAdFree,
                    onSetAdFree: widget.onSetAdFree,
                  ),
                ),
              );
            },
          ),

          _SettingsSectionHeader('Playback'),
          ListTile(
            leading: Icon(Icons.high_quality, color: context.colors.textSecondary),
            title: Text('Audio quality', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text(_audioQuality, style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
            onTap: () => _pickQuality(
              'Audio quality',
              ['Low', 'Normal', 'High', 'Lossless'],
              _audioQuality,
              (value) {
                setState(() => _audioQuality = value);
                _saveSetting('audioQuality', value);
              },
            ),
          ),
          SwitchListTile(
            secondary: Icon(Icons.playlist_play, color: context.colors.textSecondary),
            title: Text('Autoplay', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text('Keep playing similar content when your queue ends',
                style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
            value: _autoplay,
            activeColor: const Color(0xFF9C27B0),
            onChanged: (value) {
              setState(() => _autoplay = value);
              _saveSetting('autoplay', value);
            },
          ),
          SwitchListTile(
            secondary: Icon(Icons.graphic_eq, color: context.colors.textSecondary),
            title: Text('Crossfade', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text('Smoothly blend between tracks', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
            value: _crossfade,
            activeColor: const Color(0xFF9C27B0),
            onChanged: (value) {
              setState(() => _crossfade = value);
              _saveSetting('crossfade', value);
            },
          ),

          _SettingsSectionHeader('Downloads'),
          ListTile(
            leading: Icon(Icons.download, color: context.colors.textSecondary),
            title: Text('Download quality', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text(_downloadQuality, style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
            onTap: () => _pickQuality(
              'Download quality',
              ['Normal', 'High', 'Lossless'],
              _downloadQuality,
              (value) {
                setState(() => _downloadQuality = value);
                _saveSetting('downloadQuality', value);
              },
            ),
          ),
          SwitchListTile(
            secondary: Icon(Icons.wifi, color: context.colors.textSecondary),
            title: Text('Download over Wi-Fi only', style: TextStyle(color: context.colors.textPrimary)),
            value: _downloadOverWifiOnly,
            activeColor: const Color(0xFF9C27B0),
            onChanged: (value) {
              setState(() => _downloadOverWifiOnly = value);
              _saveSetting('downloadOverWifiOnly', value);
            },
          ),

          _SettingsSectionHeader('Audio Ads'),
          ListTile(
            leading: Icon(Icons.volume_up, color: context.colors.textSecondary),
            title: Text('Ad volume', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text(_adVolume, style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
            onTap: () => _openDropdownSubmitSheet(
              title: 'Ad volume',
              options: const ['Low', 'Normal', 'Loud'],
              current: _adVolume,
              onSave: (value) {
                setState(() => _adVolume = value);
                _saveSetting('adVolume', value);
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.campaign_outlined, color: context.colors.textSecondary),
            title: Text('Submit an Audio Ad', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text(
              'Placeholder — company, purpose, and script',
              style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
            onTap: _openAudioAdSubmissionSheet,
          ),

          _SettingsSectionHeader('Ads & Sponsorships'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline, color: context.colors.textSecondary, size: 22),
            title: Text(
              'About these placements',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'What each slot is and how it works',
              style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: context.colors.surface,
                    title: Text('About Ads & Sponsorships', style: TextStyle(color: context.colors.textPrimary)),
                    content: Text(
                      'There are 5 placements you can manage here:\n\n'
                      '• Home — Trending row\n'
                      '• Home — Radio row\n'
                      '• Search — banner\n'
                      '• Library — row\n\n'
                      'These 4 are flat-fee slots — set a sponsor name, description, '
                      'optional image, and a link/contact for each.\n\n'
                      '• Affiliate merch spot (bottom of Home)\n\n'
                      'This one is different: no flat fee, and it\'s restricted to an '
                      'artist already in the app — it can only ever carry official merch '
                      'or ticket links from a real act on the platform.',
                      style: TextStyle(color: context.colors.textSecondary, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close', style: TextStyle(color: Color(0xFF9C27B0))),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          _AdsSponsorshipSection(
            trendingData: widget.sponsorTrendingData,
            radioData: widget.sponsorRadioData,
            searchData: widget.sponsorSearchData,
            libraryData: widget.sponsorLibraryData,
            affiliateData: widget.sponsorAffiliateData,
            artistOptions: widget.artistOptions,
            onUpdateSlot: widget.onUpdateSponsorSlot,
          ),

          _SettingsSectionHeader('Notifications'),
          SwitchListTile(
            secondary: Icon(Icons.notifications, color: context.colors.textSecondary),
            title: Text('Push notifications', style: TextStyle(color: context.colors.textPrimary)),
            value: _notificationsEnabled,
            activeColor: const Color(0xFF9C27B0),
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSetting('notificationsEnabled', value);
            },
          ),

          _SettingsSectionHeader('About'),
          ListTile(
            leading: Icon(Icons.info_outline, color: context.colors.textSecondary),
            title: Text('Version', style: TextStyle(color: context.colors.textPrimary)),
            subtitle: Text('1.0.0', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
          ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: context.colors.textSecondary),
            title: Text('Terms of Service', style: TextStyle(color: context.colors.textPrimary)),
            trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: context.colors.textSecondary),
            title: Text('Privacy Policy', style: TextStyle(color: context.colors.textPrimary)),
            trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
            onTap: () {},
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('Log Out'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  const _SettingsSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF9C27B0),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// Placeholder editor for a single dropdown-style Audio Ads setting (Ad
// frequency, Ad volume) — a bottom sheet with a Submit button, same shape
// as the sponsor slot editors, since real ad-serving logic isn't wired up
// yet.
class _DropdownSubmitSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String initialValue;
  final void Function(String value) onSave;

  const _DropdownSubmitSheet({
    required this.title,
    required this.options,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<_DropdownSubmitSheet> createState() => _DropdownSubmitSheetState();
}

class _DropdownSubmitSheetState extends State<_DropdownSubmitSheet> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _submit() {
    widget.onSave(_value);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _value,
                isExpanded: true,
                dropdownColor: context.colors.surface,
                style: TextStyle(color: context.colors.textPrimary),
                items: widget.options
                    .map((option) => DropdownMenuItem<String>(value: option, child: Text(option)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _value = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Submit'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Placeholder "Submit an Audio Ad" form — company/brand name, what it's
// for, and what the ad says. A bottom sheet with a Submit button, same
// shape as the sponsor slot editors. Not wired up to actually queue or
// serve the ad yet — just captures the submission for now.
class _AudioAdSubmissionSheet extends StatefulWidget {
  const _AudioAdSubmissionSheet();

  @override
  State<_AudioAdSubmissionSheet> createState() => _AudioAdSubmissionSheetState();
}

class _AudioAdSubmissionSheetState extends State<_AudioAdSubmissionSheet> {
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _scriptController = TextEditingController();

  @override
  void dispose() {
    _companyController.dispose();
    _purposeController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  void _submit() {
    _lsSet('audioAdSubmission', jsonEncode({
      'company': _companyController.text.trim(),
      'purpose': _purposeController.text.trim(),
      'script': _scriptController.text.trim(),
    }));
    Navigator.pop(context);
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.colors.textTertiary),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: context.colors.divider),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF9C27B0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Submit an Audio Ad',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _companyController,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: _fieldDecoration('Company / brand name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _purposeController,
              maxLines: 2,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: _fieldDecoration('What is this ad for?'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _scriptController,
              maxLines: 3,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: _fieldDecoration('What should it say?'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Submit'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// In-app self-serve panel for the 4 flat-fee sponsored slots plus the
// affiliate merch spot. Each row is tappable rather than sitting open as
// always-visible fields — tapping opens a bottom sheet with the full form
// (name/artist, description, optional image, Submit). The affiliate slot
// uses a dropdown restricted to artists already in the app instead of free
// text, since it's meant to only ever carry official merch from a real act.
class _AdsSponsorshipSection extends StatelessWidget {
  final Map<String, dynamic> trendingData;
  final Map<String, dynamic> radioData;
  final Map<String, dynamic> searchData;
  final Map<String, dynamic> libraryData;
  final Map<String, dynamic> affiliateData;
  final List<String> artistOptions;
  final void Function(String key, Map<String, dynamic> data) onUpdateSlot;

  const _AdsSponsorshipSection({
    required this.trendingData,
    required this.radioData,
    required this.searchData,
    required this.libraryData,
    required this.affiliateData,
    required this.artistOptions,
    required this.onUpdateSlot,
  });

  void _openEditor(
    BuildContext context, {
    required String slotKey,
    required String slotLabel,
    required Map<String, dynamic> data,
    bool isAffiliate = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SponsorSlotEditorSheet(
        slotKey: slotKey,
        slotLabel: slotLabel,
        initialData: data,
        isAffiliate: isAffiliate,
        artistOptions: artistOptions,
        onSave: onUpdateSlot,
      ),
    );
  }

  Widget _slotTile(
    BuildContext context, {
    required String slotKey,
    required String label,
    required Map<String, dynamic> data,
    bool isAffiliate = false,
  }) {
    final displayName = isAffiliate
        ? (data['artist'] as String? ?? 'None selected')
        : (data['name'] as String? ?? '');
    final imageValue = data['image'] as String?;
    final hasImage = imageValue != null && imageValue.contains(',');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: hasImage
          ? CircleAvatar(
              backgroundColor: context.colors.divider,
              backgroundImage: MemoryImage(base64Decode(imageValue.split(',').last)),
            )
          : CircleAvatar(
              backgroundColor: context.colors.divider,
              child: Icon(Icons.campaign_outlined, color: context.colors.textTertiary, size: 18),
            ),
      title: Text(label, style: TextStyle(color: context.colors.textPrimary, fontSize: 14)),
      subtitle: Text(
        displayName,
        style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.chevron_right, color: context.colors.textTertiary),
      onTap: () => _openEditor(
        context,
        slotKey: slotKey,
        slotLabel: label,
        data: data,
        isAffiliate: isAffiliate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _slotTile(context, slotKey: 'trending', label: 'Home — Trending row', data: trendingData),
        Divider(color: context.colors.divider, height: 1),
        _slotTile(context, slotKey: 'radio', label: 'Home — Radio row', data: radioData),
        Divider(color: context.colors.divider, height: 1),
        _slotTile(context, slotKey: 'search', label: 'Search — banner', data: searchData),
        Divider(color: context.colors.divider, height: 1),
        _slotTile(context, slotKey: 'library', label: 'Library — row', data: libraryData),
        Divider(color: context.colors.divider, height: 1),
        _slotTile(
          context,
          slotKey: 'affiliate',
          label: 'Affiliate merch spot',
          data: affiliateData,
          isAffiliate: true,
        ),
      ],
    );
  }
}

// The actual editing form, shown as a bottom sheet. Uses a plain HTML file
// input under the hood for the image picker (via dart:html) rather than a
// package — this is a standard <input type="file"> element, which on mobile
// browsers automatically opens the native photo/camera picker, so it works
// the same way on phones as it does on desktop with zero extra setup.
class _SponsorSlotEditorSheet extends StatefulWidget {
  final String slotKey;
  final String slotLabel;
  final Map<String, dynamic> initialData;
  final bool isAffiliate;
  final List<String> artistOptions;
  final void Function(String key, Map<String, dynamic> data) onSave;

  const _SponsorSlotEditorSheet({
    required this.slotKey,
    required this.slotLabel,
    required this.initialData,
    required this.isAffiliate,
    required this.artistOptions,
    required this.onSave,
  });

  @override
  State<_SponsorSlotEditorSheet> createState() => _SponsorSlotEditorSheetState();
}

class _SponsorSlotEditorSheetState extends State<_SponsorSlotEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _infoController;
  String? _artist;
  String? _imageDataUrl;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name'] as String? ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialData['description'] as String? ?? '');
    _infoController = TextEditingController(text: widget.initialData['info'] as String? ?? '');
    _artist = widget.initialData['artist'] as String?;
    _imageDataUrl = widget.initialData['image'] as String?;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();
      await input.onChange.first;
      final files = input.files;
      if (files == null || files.isEmpty) {
        setState(() => _pickingImage = false);
        return;
      }
      final reader = html.FileReader();
      reader.readAsDataUrl(files.first);
      await reader.onLoadEnd.first;
      setState(() {
        _imageDataUrl = reader.result as String?;
        _pickingImage = false;
      });
    } catch (_) {
      // Picker cancelled or unsupported — just leave the image unchanged.
      setState(() => _pickingImage = false);
    }
  }

  void _removeImage() {
    setState(() => _imageDataUrl = null);
  }

  void _submit() {
    final data = <String, dynamic>{
      'description': _descriptionController.text.trim(),
      'image': _imageDataUrl,
      'info': _infoController.text.trim(),
    };
    if (widget.isAffiliate) {
      data['artist'] = _artist;
    } else {
      final typedName = _nameController.text.trim();
      data['name'] = typedName.isEmpty ? (widget.initialData['name'] as String? ?? '') : typedName;
    }
    widget.onSave(widget.slotKey, data);
    Navigator.pop(context);
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.colors.textTertiary),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: context.colors.divider),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF9C27B0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageDataUrl != null && _imageDataUrl!.contains(',');
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.slotLabel,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (widget.isAffiliate) ...[
              Text('Artist', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _artist,
                    isExpanded: true,
                    dropdownColor: context.colors.surface,
                    hint: Text('None selected', style: TextStyle(color: context.colors.textTertiary)),
                    style: TextStyle(color: context.colors.textPrimary),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None', style: TextStyle(color: context.colors.textTertiary)),
                      ),
                      ...widget.artistOptions.map(
                        (artist) => DropdownMenuItem<String?>(value: artist, child: Text(artist)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _artist = value),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _nameController,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: _fieldDecoration('Sponsor / brand name'),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: _fieldDecoration('Description / message'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _infoController,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: _fieldDecoration('Info / link (e.g. website, contact)'),
            ),
            const SizedBox(height: 16),
            Text('Image (optional)', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(_imageDataUrl!.split(',').last),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.colors.divider,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image_outlined, color: context.colors.textTertiary),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: _pickingImage ? null : _pickImage,
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF9C27B0))),
                        child: Text(
                          _pickingImage ? 'Choosing…' : (hasImage ? 'Change image' : 'Add image'),
                          style: const TextStyle(color: Color(0xFF9C27B0)),
                        ),
                      ),
                      if (hasImage)
                        TextButton(
                          onPressed: _removeImage,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Submit'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}


// ---------------- QUEUE SCREEN ----------------

// ---------------- CLASSICAL ----------------

// A separate section, styled distinctly from the rest of the app and
// structured around composers rather than "artists" — the way Apple Music
// Classical is its own dedicated space rather than just another genre tab.
// Deliberately left with no real content for now: the app's existing
// "Classical" tag is just a genre guess on a few cinematic-style tracks,
// not real classical repertoire with real composers, so nothing fake is
// shown here — it's ready for real public-domain classical recordings to
// be added later.
class ClassicalScreen extends StatelessWidget {
  final void Function(String title, String subtitle) onTrackTap;
  const ClassicalScreen({super.key, required this.onTrackTap});

  @override
  Widget build(BuildContext context) {
    final composers = composerPieces.keys.toList();
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0F),
        elevation: 0,
        foregroundColor: const Color(0xFFC9A961),
        title: const Text(
          'Classical',
          style: TextStyle(
            color: Color(0xFFC9A961),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Browse by Composer',
              style: TextStyle(
                color: Color(0xFFC9A961),
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'A dedicated space for classical recordings, separate from the rest of your library.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: composers.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0xFF2A2723), height: 1),
                itemBuilder: (context, index) {
                  final composer = composers[index];
                  final pieces = composerPieces[composer] ?? [];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.piano, color: Color(0xFFC9A961), size: 26),
                    title: Text(
                      composer,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      pieces.length == 1 ? pieces.first : '${pieces.length} recordings',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.play_circle_outline, color: Color(0xFFC9A961), size: 22),
                    onTap: () {
                      if (pieces.length == 1) {
                        onTrackTap(pieces.first, composer);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComposerPiecesScreen(
                              composer: composer,
                              pieces: pieces,
                              onTrackTap: onTrackTap,
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A composer's individual pieces, shown when a composer in the Classical
// section has more than one recording — same black/gold styling as the
// rest of the Classical space.
class ComposerPiecesScreen extends StatelessWidget {
  final String composer;
  final List<String> pieces;
  final void Function(String title, String subtitle) onTrackTap;

  const ComposerPiecesScreen({
    super.key,
    required this.composer,
    required this.pieces,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0F),
        elevation: 0,
        foregroundColor: const Color(0xFFC9A961),
        title: Text(
          composer,
          style: const TextStyle(
            color: Color(0xFFC9A961),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        itemCount: pieces.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFF2A2723), height: 1),
        itemBuilder: (context, index) {
          final piece = pieces[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.music_note, color: Color(0xFFC9A961), size: 24),
            title: Text(piece, style: const TextStyle(color: Colors.white, fontSize: 15)),
            trailing: const Icon(Icons.play_circle_outline, color: Color(0xFFC9A961), size: 22),
            onTap: () => onTrackTap(piece, composer),
          );
        },
      ),
    );
  }
}


class QueueScreen extends StatelessWidget {
  final List<String> queue;
  final int currentIndex;
  final String category;
  final void Function(int index) onJumpTo;

  const QueueScreen({
    super.key,
    required this.queue,
    required this.currentIndex,
    required this.category,
    required this.onJumpTo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Queue'),
        foregroundColor: context.colors.textPrimary,
      ),
      body: queue.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Your queue is empty.\nOpen a Playlist or Album to start one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textTertiary, fontSize: 14),
                ),
              ),
            )
          : ListView.builder(
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final isCurrent = index == currentIndex;
                return ListTile(
                  leading: Icon(
                    isCurrent ? Icons.graphic_eq : Icons.music_note,
                    color: isCurrent ? const Color(0xFF9C27B0) : context.colors.textTertiary,
                  ),
                  title: Text(
                    queue[index],
                    style: TextStyle(
                      color: isCurrent ? const Color(0xFF9C27B0) : context.colors.textPrimary,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(category, style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
                  onTap: () => onJumpTo(index),
                );
              },
            ),
    );
  }
}

// ---------------- BLEND SCREEN ----------------

class BlendScreen extends StatefulWidget {
  final void Function(String title, String subtitle) onTrackTap;
  const BlendScreen({super.key, required this.onTrackTap});

  @override
  State<BlendScreen> createState() => _BlendScreenState();
}

class _BlendScreenState extends State<BlendScreen> {
  bool _friendJoined = false;
  final String _blendCode = 'BLEND-4F82';
  final String _friendName = 'Jordan';

  List<SearchableItem> get _yourTopSongs =>
      allSearchableItems.where((i) => i.category == 'Songs').toList();

  List<SearchableItem> get _blendedPlaylist {
    final yours = _yourTopSongs;
    final friendsView = yours.reversed.toList();
    final blended = <SearchableItem>[];
    for (int i = 0; i < yours.length; i++) {
      blended.add(yours[i]);
      if (i < friendsView.length) blended.add(friendsView[i]);
    }
    final seen = <String>{};
    return blended.where((item) => seen.add(item.name)).toList();
  }

  void _copyInviteLink() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied (demo)')),
    );
  }

  void _simulateFriendJoining() {
    setState(() {
      _friendJoined = true;
    });
  }

  void _leaveBlend() {
    setState(() {
      _friendJoined = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Blend'),
        foregroundColor: context.colors.textPrimary,
      ),
      body: _friendJoined ? _buildBlendResult() : _buildInviteState(),
    );
  }

  Widget _buildInviteState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(Icons.favorite, color: context.colors.textPrimary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Blend your taste with a friend',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite a friend and Echo All Sounds will mix your favorites into one shared playlist, plus a match score based on your taste.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _blendCode,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton.icon(
                  onPressed: _copyInviteLink,
                  icon: const Icon(Icons.copy, color: Color(0xFF9C27B0), size: 18),
                  label: const Text('Copy', style: TextStyle(color: Color(0xFF9C27B0))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _simulateFriendJoining,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Simulate $_friendJoinedLabel Joining (Demo)'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is a placeholder until real friend invites are wired up to a backend.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String get _friendJoinedLabel => _friendName;

  Widget _buildBlendResult() {
    final playlist = _blendedPlaylist;
    return Column(
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatar('You', const Color(0xFF9C27B0)),
            const SizedBox(width: 12),
            const Icon(Icons.favorite, color: Colors.pinkAccent, size: 28),
            const SizedBox(width: 12),
            _buildAvatar(_friendName, const Color(0xFF3F51B5)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '83% Match',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'You and $_friendName both love similar tracks',
          style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Your Blend',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: playlist.length,
            itemBuilder: (context, index) {
              final item = playlist[index];
              return ListTile(
                leading: Icon(item.icon, color: context.colors.textSecondary, size: 22),
                title: Text(item.name, style: TextStyle(color: context.colors.textPrimary)),
                subtitle: Text(
                  index.isEven ? 'From you' : 'From $_friendName',
                  style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                ),
                onTap: () => widget.onTrackTap(item.name, item.category),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton(
            onPressed: _leaveBlend,
            child: const Text('Leave Blend', style: TextStyle(color: Colors.redAccent)),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Icon(Icons.person, color: context.colors.textPrimary, size: 28),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

// ---------------- SUBSCRIPTIONS SCREEN ----------------

class SubscriptionsScreen extends StatefulWidget {
  final bool isPro;
  final void Function(bool isPro) onSetPro;
  final bool isAdFree;
  final void Function(bool isAdFree) onSetAdFree;
  const SubscriptionsScreen({
    super.key,
    required this.isPro,
    required this.onSetPro,
    required this.isAdFree,
    required this.onSetAdFree,
  });

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _isYearly = false;

  void _subscribe() {
    widget.onSetPro(true);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Pro Activated', style: TextStyle(color: context.colors.textPrimary)),
          content: Text(
            'This is a local demo toggle, not a real purchase — no payment has '
            'been taken. Ads before songs are now off for this device.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFF9C27B0))),
            ),
          ],
        );
      },
    );
  }

  void _cancelPro() {
    widget.onSetPro(false);
  }

  void _subscribeAdFree() {
    widget.onSetAdFree(true);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Ad-Free Activated', style: TextStyle(color: context.colors.textPrimary)),
          content: Text(
            'This is a local demo toggle, not a real purchase — no payment has '
            'been taken. The interrupting pre-song audio ads are now off for '
            'this device. Sponsor banners elsewhere in the app (Trending row, '
            'Radio row, Search, Library) still show — that\'s outside this '
            'tier\'s scope.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFF9C27B0))),
            ),
          ],
        );
      },
    );
  }

  void _cancelAdFree() {
    widget.onSetAdFree(false);
  }

  @override
  Widget build(BuildContext context) {
    final priceLabel = _isYearly ? '£59.99 / year' : '£6.99 / month';
    final savingsLabel = _isYearly ? 'Save 28% vs monthly' : null;
    final adFreePriceLabel = _isYearly ? '£19.99 / year' : '£2.49 / month';
    final adFreeSavingsLabel = _isYearly ? 'Save 33% vs monthly' : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Subscriptions'),
        foregroundColor: context.colors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isPro)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF9C27B0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Color(0xFF9C27B0), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have Pro (local demo)',
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelPro,
                    child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
            )
          else if (widget.isAdFree)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4CAF50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have Ad-Free (local demo)',
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelAdFree,
                    child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),
          Text(
            'Choose your plan',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to Pro for an ad-free, offline, higher-quality experience.',
            style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Monthly / Yearly toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isYearly = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isYearly ? const Color(0xFF9C27B0) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Monthly',
                        style: TextStyle(
                          color: !_isYearly ? Colors.white : context.colors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isYearly = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isYearly ? const Color(0xFF9C27B0) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Yearly',
                        style: TextStyle(
                          color: _isYearly ? Colors.white : context.colors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Free plan card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free',
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your current plan',
                  style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                const _PlanFeatureRow(text: 'Ad-supported listening', included: true),
                const _PlanFeatureRow(text: 'Standard audio quality', included: true),
                const _PlanFeatureRow(text: 'Offline downloads', included: false),
                const _PlanFeatureRow(text: 'Skip ads', included: false),
                const _PlanFeatureRow(text: 'Exclusive content', included: false),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Ad-Free plan card — cheaper tier, removes only the interrupting
          // pre-song audio ads. Sponsor banners elsewhere in the app are
          // untouched by this tier — only Pro's other perks are still gated.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Ad-Free',
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.block, color: Color(0xFF4CAF50), size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  adFreePriceLabel,
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (adFreeSavingsLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    adFreeSavingsLabel,
                    style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'No interrupting ads — sponsor banners still show',
                  style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                const _PlanFeatureRow(text: 'No interrupting audio ads', included: true),
                const _PlanFeatureRow(text: 'Sponsor banners still shown', included: true),
                const _PlanFeatureRow(text: 'Standard audio quality', included: true),
                const _PlanFeatureRow(text: 'Offline downloads', included: false),
                const _PlanFeatureRow(text: 'Exclusive content', included: false),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _subscribeAdFree,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Get Ad-Free',
                      style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Pro plan card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Pro',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.workspace_premium, color: Colors.white, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  priceLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (savingsLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    savingsLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                const _PlanFeatureRow(text: 'Ad-free listening', included: true, light: true),
                const _PlanFeatureRow(text: 'Lossless audio quality', included: true, light: true),
                const _PlanFeatureRow(text: 'Offline downloads', included: true, light: true),
                const _PlanFeatureRow(text: 'Skip unlimited ads', included: true, light: true),
                const _PlanFeatureRow(text: 'Exclusive podcasts & content', included: true, light: true),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _subscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF9C27B0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Upgrade to Pro', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Prices shown are placeholders. Payments are not connected yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PlanFeatureRow extends StatelessWidget {
  final String text;
  final bool included;
  final bool light;

  const _PlanFeatureRow({required this.text, required this.included, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle : Icons.cancel,
            color: included ? (light ? Colors.white : const Color(0xFF9C27B0)) : context.colors.divider,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: included ? (light ? Colors.white : context.colors.textSecondary) : context.colors.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- PROFILE SCREEN ----------------

class ProfileScreen extends StatefulWidget {
  final Map<String, List<String>> sampleItems;
  final Set<String> pinnedItems;
  final int totalPlays;

  const ProfileScreen({
    super.key,
    required this.sampleItems,
    required this.pinnedItems,
    required this.totalPlays,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'You';
  String _bio = 'Music lover exploring Echo All Sounds 🎧';
  String? _photoDataUrl;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final raw = _lsGet('profile');
    if (raw == null) return;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _name = saved['name'] as String? ?? _name;
        _bio = saved['bio'] as String? ?? _bio;
        _photoDataUrl = saved['photo'] as String?;
      });
    } catch (_) {
      // Corrupted data — keep the defaults.
    }
  }

  void _saveProfile() {
    _lsSet('profile', jsonEncode({'name': _name, 'bio': _bio, 'photo': _photoDataUrl}));
  }

  // Same plain HTML file-input technique used for ad images — works the
  // same way on mobile (opens the native photo/camera picker) as desktop.
  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    try {
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();
      await input.onChange.first;
      final files = input.files;
      if (files == null || files.isEmpty) {
        setState(() => _pickingPhoto = false);
        return;
      }
      final reader = html.FileReader();
      reader.readAsDataUrl(files.first);
      await reader.onLoadEnd.first;
      setState(() {
        _photoDataUrl = reader.result as String?;
        _pickingPhoto = false;
      });
      _saveProfile();
    } catch (_) {
      setState(() => _pickingPhoto = false);
    }
  }

  void _editProfile() {
    final nameController = TextEditingController(text: _name);
    final bioController = TextEditingController(text: _bio);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Edit Profile', style: TextStyle(color: context.colors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: context.colors.textTertiary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.colors.divider),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF9C27B0)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                maxLines: 2,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Bio',
                  labelStyle: TextStyle(color: context.colors.textTertiary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.colors.divider),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF9C27B0)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: context.colors.textTertiary)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (nameController.text.trim().isNotEmpty) {
                    _name = nameController.text.trim();
                  }
                  _bio = bioController.text.trim();
                });
                _saveProfile();
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Color(0xFF9C27B0))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistsCount = widget.sampleItems['Playlists']?.length ?? 0;
    final pinnedCount = widget.pinnedItems.length;
    final downloadsCount = widget.sampleItems['Downloads']?.length ?? 0;
    final hasPhoto = _photoDataUrl != null && _photoDataUrl!.contains(',');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Profile'),
        foregroundColor: context.colors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickingPhoto ? null : _pickPhoto,
              child: Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasPhoto
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      image: hasPhoto
                          ? DecorationImage(
                              image: MemoryImage(base64Decode(_photoDataUrl!.split(',').last)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: hasPhoto
                        ? null
                        : Icon(Icons.person, color: context.colors.textPrimary, size: 44),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF9C27B0),
                        border: Border.fromBorderSide(BorderSide(color: Color(0xFF121212), width: 2)),
                      ),
                      child: Icon(
                        _pickingPhoto ? Icons.hourglass_empty : Icons.camera_alt,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _name,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Center(
              child: Text(
                _bio,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit, size: 16, color: Color(0xFF9C27B0)),
              label: const Text('Edit Profile', style: TextStyle(color: Color(0xFF9C27B0))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF9C27B0)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: context.colors.divider, height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat('Playlists', playlistsCount),
              _buildStat('Pinned', pinnedCount),
              _buildStat('Downloads', downloadsCount),
              _buildStat('Plays', widget.totalPlays),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: context.colors.divider, height: 1),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
        ),
      ],
    );
  }
}
// VideoPreloadManager.dart
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoPreloadManager {
  VideoPreloadManager._privateConstructor();
  static final VideoPreloadManager _instance = VideoPreloadManager._privateConstructor();
  factory VideoPreloadManager() => _instance;

  Map<String, List<String>> get pageCaches => _pageCaches;

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, List<String>> _pageCaches = {
    'main': [
      'assets/mainbackground.mp4',
    ],
    'calendar': [
      'assets/cloud.mp4',
      'assets/cloudscreen.mp4',
      'assets/cloud_reverse.mp4'
      'assets/happy.png',
      'assets/sad.png',
      'assets/angry.png',
      'assets/cry.png',
    ],
    'radio': [
      'assets/sea.mp4',
      'assets/seascreen.mp4',
      'assets/sea_reverse.mp4',
      'assets/images/bgm.png',
      'assets/jellyfish.png',
      'assets/jellyfish_icon.png',
      'assets/images/morning_way.png',
      'assets/images/sea_morning.png',
      'assets/images/sea_way.png',
      'assets/images/universe.png',
      'assets/images/war_song.png',
      'assets/orange.png',
      'assets/blue.png',
      'assets/purple.png',
      'assets/white.png',
      'assets/bgm/morning_way.mp3',
      'assets/bgm/sea_morning.mp3',
      'assets/bgm/sea_way.mp3',
      'assets/bgm/universe.mp3',
      'assets/bgm/war_song.mp3',
      'assets/sleep/sleep5.mp3',
      'assets/sleep/sleep10.mp3',
      'assets/sleep/sleep15.mp3',
      'assets/vision/vision5.mp3',
      'assets/vision/vision10.mp3',
      'assets/vision/vision15.mp3',
      'assets/emotion/emotion5.mp3',
      'assets/emotion/emotion10.mp3',
      'assets/emotion/emotion15.mp3',
      'assets/myself/myself5.mp3',
      'assets/myself/myself10.mp3',
      'assets/myself/myself15.mp3',
    ],
    'tarodcard': [
      'assets/card.mp4',
      'assets/card_reverse.mp4',
      'assets/Dreamidle.mp4',
      'assets/Dreamtarod.mp4',
      'assets/card_cover.png',
      'assets/card_back.png',
      'assets/cardbook.JPG',
    ],
    'chat': [
      'assets/chat.mp4',
      'assets/chatscreen.mp4',
      'assets/chatscreen_2.mp4',
      'assets/chat_reverse.mp4',
    ]
  };

  final Map<String, bool> _videoInUse = {};
  bool _isInitialized = false;
  String? _currentPageCache;

  VideoPlayerController? reverseTransitionController;

  final List<String> _persistentVideos = [
    'assets/mainbackground.mp4',
    'assets/cloud_reverse.mp4',
    'assets/sea_reverse.mp4',
    'assets/card_reverse.mp4',
    'assets/chat_reverse.mp4',
  ];

  bool get isInitialized => _isInitialized;

  String? getPathFromController(VideoPlayerController controller) {
    for (var entry in _controllers.entries) {
      if (entry.value == controller) {
        return entry.key;
      }
    }
    return null;
  }

  void markVideoInUse(String path, bool inUse) {
    if (_videoInUse.containsKey(path)) {
      _videoInUse[path] = inUse;
    }
  }

  Future<void> lazyLoadPageVideos(
      String pageName, {
        Function()? onLoadComplete,
      }) async {
    try {
      final pageVideos = _pageCaches[pageName] ?? [];
      bool allVideosLoaded = pageVideos.every(
            (path) => hasController(path) && isVideoLoaded(path),
      );

      if (!allVideosLoaded) {
        if (_currentPageCache != null && _currentPageCache != pageName) {
          await releasePageVideos(_currentPageCache!);
        }

        for (String path in pageVideos) {
          await _ensureVideoController(path);
        }

        _currentPageCache = pageName;
      }

      onLoadComplete?.call();
    } catch (e) {
      print('Lazy loading error for $pageName: $e');
      onLoadComplete?.call();
    }
  }

  Future<VideoPlayerController> _ensureVideoController(String path) async {
    if (!path.endsWith('.mp4')) {
      return VideoPlayerController.asset('assets/dummy.mp4')
        ..value = VideoPlayerValue(duration: Duration.zero);
    }

    if (hasController(path) && isVideoLoaded(path)) {
      return _controllers[path]!;
    }

    VideoPlayerController controller;
    try {
      controller = path.startsWith('http') || path.startsWith('https')
          ? VideoPlayerController.file(
        await DefaultCacheManager().getSingleFile(path),
      )
          : VideoPlayerController.asset(path);

      await controller.initialize();
      _controllers[path] = controller;
      _videoInUse[path] = false;
      print('Successfully created/reused controller for: $path');
    } catch (e) {
      print('Error initializing controller for $path: $e');
      rethrow;
    }
    return _controllers[path]!;
  }

  Future<void> preloadVideos(List<String> videoPaths) async {
    try {
      for (String path in videoPaths) {
        await _ensureVideoController(path);
      }
      _isInitialized = true;
    } catch (e) {
      print('Error preloading videos: $e');
      rethrow;
    }
  }

  Future<void> releasePageVideos(String pageName) async {
    final pageVideos = _pageCaches[pageName] ?? [];
    for (var path in pageVideos) {
      if (_persistentVideos.contains(path)) {
        continue;
      }
      await releaseVideo(path);
    }
    _currentPageCache = null;
  }

  Future<VideoPlayerController?> getController(String path) async {
    if (!path.endsWith('.mp4')) {
      return null;
    }
    try {
      final controller = await _ensureVideoController(path);
      _videoInUse[path] = true;
      return controller;
    } catch (e) {
      print('Error getting controller for $path: $e');
      return null;
    }
  }

  VideoPlayerController? getCachedController(String path) {
    return _controllers[path];
  }

  Future<void> releaseVideo(String path) async {
    if (_persistentVideos.contains(path)) {
      return;
    }
    if (!path.endsWith('.mp4')) {
      return;
    }
    try {
      final controller = _controllers[path];
      if (controller != null) {
        _videoInUse[path] = false;
        if (controller.value.isInitialized) {
          await controller.pause();
          await controller.dispose();
        }
        _controllers.remove(path);
        print('Released video: $path');
      }
    } catch (e) {
      print('Error releasing video $path: $e');
    }
  }

  Future<void> releaseUnusedVideos() async {
    final unusedPaths = _videoInUse.entries
        .where((entry) => !entry.value && !_persistentVideos.contains(entry.key))
        .map((entry) => entry.key)
        .toList();

    for (var path in unusedPaths) {
      await releaseVideo(path);
    }
  }

  void pauseVideo(String path) {
    try {
      final controller = _controllers[path];
      if (controller != null &&
          controller.value.isInitialized &&
          controller.value.isPlaying) {
        controller.pause();
        print('Paused video: $path');
      }
    } catch (e) {
      print('Error pausing video $path: $e');
    }
  }

  Future<void> resumeVideo(String path) async {
    try {
      final controller = _controllers[path];
      if (controller != null &&
          controller.value.isInitialized &&
          !controller.value.isPlaying) {
        await controller.play();
        print('Resumed video: $path');
      }
    } catch (e) {
      print('Error resuming video $path: $e');
    }
  }

  bool isVideoPlaying(String path) {
    final controller = _controllers[path];
    return controller?.value.isInitialized == true &&
        controller?.value.isPlaying == true;
  }

  bool isVideoLoaded(String path) {
    if (!path.endsWith('.mp4')) {
      return true;
    }
    final controller = _controllers[path];
    return controller?.value.isInitialized == true;
  }

  bool hasController(String path) {
    if (!path.endsWith('.mp4')) {
      return true;
    }
    return _controllers.containsKey(path);
  }

  Future<void> disposeAll() async {
    for (var path in _controllers.keys.toList()) {
      await releaseVideo(path);
    }
  }
}

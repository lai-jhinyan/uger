// lib/mainscreen.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'VideoPreloadManager.dart';
import 'RivePreloadManager.dart';
import 'chatscreen.dart';
import 'tarodscreen.dart';
import 'MoodDiary.dart';
import 'Meditation.dart';
import 'main.dart'; // 確保正確導入
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:rive/rive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:ui' show BoxFit, FittedSizes, applyBoxFit;

class BlockingPageRoute<T> extends PageRoute<T> {
  final Widget Function() pageBuilder;
  final bool Function() canRender;
  final Widget? backgroundLayer;

  BlockingPageRoute({
    required this.pageBuilder,
    required this.canRender,
    this.backgroundLayer,
  }) : super();

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 保持原始的背景層
        if (backgroundLayer != null) backgroundLayer!,

        // 條件渲染新頁面
        if (canRender())
          pageBuilder()
        else
          Container(color: Colors.transparent), // 完全透明的占位符
      ],
    );
  }

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;
}

class LazyLoadingWidget extends StatefulWidget {
  @override
  _LazyLoadingWidgetState createState() => _LazyLoadingWidgetState();
}

class _LazyLoadingWidgetState extends State<LazyLoadingWidget> {
  Artboard? _riveArtboard;
  StateMachineController? _controller;
  bool _isRiveLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  void _loadRiveFile() {
    final preloadManager = RivePreloadManager();
    final cachedArtboard = preloadManager.getArtboard('assets/loading.riv');
    if (cachedArtboard != null) {
      setState(() {
        _riveArtboard = cachedArtboard;
        _isRiveLoaded = true;
      });
    } else {
      // 理論上不會到這裡，因為已經在 main.dart 中預加載
      print('Rive file not found in cache.');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _riveArtboard != null
                ? SizedBox(
              width: 100,
              height: 100,
              child: Rive(
                artboard: _riveArtboard!,
                fit: BoxFit.contain,
              ),
            )
                : CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              '憂隔正在搬家中',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool showTouchAreas;
  final VideoPlayerController? transitionController;

  const MainScreen({
    Key? key,
    this.showTouchAreas = true,
    this.transitionController,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver, RouteAware {
  bool _isLoading = false;
  late VideoPreloadManager _preloadManager;

  VideoPlayerController? _currentVideoController;
  VideoPlayerController? _transitionVideoController;
  bool _isVideoTransitioning = false;

  // 設計尺寸 (確保與視頻原始設計比例一致, 16:9)
  static const double DESIGN_WIDTH = 1080.0;
  static const double DESIGN_HEIGHT = 1920.0;

  Size? _videoRenderSize;
  Offset _videoOffset = Offset.zero; // 新增：視頻的偏移量
  late Map<String, Map<String, double>> _scaledTouchAreas = {};

  // 使用百分比定義觸碰區塊
  final Map<String, Map<String, double>> _originalTouchAreas = {
    'calendar': {
      'left': 0.48,    // 48% of DESIGN_WIDTH
      'top': 0.5,      // 50% of DESIGN_HEIGHT
      'width': 0.32,   // 32% of DESIGN_WIDTH
      'height': 0.12,  // 12% of DESIGN_HEIGHT
      'rotation': 0.0, // 旋轉角度 (度)
    },
    'radio': {
      'left': 0.08,    // 8% of DESIGN_WIDTH
      'top': 0.675,    // 67.5% of DESIGN_HEIGHT
      'width': 0.36,   // 36% of DESIGN_WIDTH
      'height': 0.13,  // 13% of DESIGN_HEIGHT
      'rotation': -16.0,
    },
    'pencil1': {
      'left': 0.50,
      'top': 0.68,
      'width': 0.45,
      'height': 0.075,
      'rotation': 0.0,
    },
    'pencil2': {
      'left': 0.72,
      'top': 0.645,
      'width': 0.128,
      'height': 0.154,
      'rotation': 0.0,
    },
    'tarodcard': {
      'left': 0.36,
      'top': 0.80,
      'width': 0.47,
      'height': 0.075,
      'rotation': 0.0,
    },
  };

  final Map<String, String> _pageLazyLoadKeys = {
    'calendar': 'calendar',
    'radio': 'radio',
    'tarodcard': 'tarodcard',
    'pencil1': 'chat',
    'pencil2': 'chat',
  };

  @override
  void initState() {
    super.initState();
    _preloadManager = VideoPreloadManager();
    _initializeVideoController();

    if (widget.transitionController != null) {
      widget.transitionController!.addListener(_onTransitionVideoComplete);
      widget.transitionController!.play();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      MyApp.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // 在組件卸載時，標記控制器為不在使用中
    if (_currentVideoController != null) {
      _preloadManager.markVideoInUse('assets/mainbackground.mp4', false);
    }

    if (_transitionVideoController != null) {
      final transitionPath = _preloadManager.getPathFromController(_transitionVideoController!);
      if (transitionPath != null) {
        _preloadManager.markVideoInUse(transitionPath, false);
      }
      _transitionVideoController!.removeListener(_onTransitionVideoComplete);
    }

    MyApp.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (_preloadManager.reverseTransitionController != null) {
      _preloadManager.reverseTransitionController!
          .removeListener(_onReverseTransitionComplete);

      _preloadManager.reverseTransitionController!
          .addListener(_onReverseTransitionComplete);

      // 確保退場動畫從頭開始播放
      _preloadManager.reverseTransitionController!.seekTo(Duration.zero);

      _preloadManager.reverseTransitionController!.play();

      // 重置背景視頻播放
      _currentVideoController?.seekTo(Duration.zero);
      _currentVideoController?.pause();

      // 確保重置視頻轉換狀態
      setState(() {
        _isVideoTransitioning = false;
        _transitionVideoController = null;
      });
    }
  }

  void _onReverseTransitionComplete() {
    if (_preloadManager.reverseTransitionController != null &&
        _preloadManager.reverseTransitionController!.value.position >=
            _preloadManager.reverseTransitionController!.value.duration) {
      _preloadManager.reverseTransitionController!
          .removeListener(_onReverseTransitionComplete);

      // 開始播放背景視頻
      _currentVideoController?.play();

      // 釋放過渡視頻資源
      _preloadManager.releaseVideo(
          _preloadManager.reverseTransitionController!.dataSource);
      _preloadManager.reverseTransitionController = null;

      setState(() {
        // 重置所有相關狀態
        _isVideoTransitioning = false;
        _transitionVideoController = null;
      });
    }
  }

  // 新增：根據控制器獲取轉換視頻路徑
  String? _getTransitionVideoPathFromController(VideoPlayerController controller) {
    return _preloadManager.getPathFromController(controller);
  }

  Future<void> _initializeVideoController() async {
    try {
      _currentVideoController =
      await _preloadManager.getController('assets/mainbackground.mp4');
      if (_currentVideoController != null) {
        await _currentVideoController!.initialize();
        if (!mounted) return; // 檢查組件是否仍然掛載
        setState(() {});
        _currentVideoController!.play();
        _currentVideoController!.setLooping(true);
      } else {
        print('Failed to initialize main background video.');
      }
    } catch (e) {
      print('Error initializing main background video: $e');
    }
  }

  /// 使用 FittedBox 進行等比例縮放，並返回視頻和觸碰區塊的組合
  Widget _buildScaledVideo() {
    final controller = _preloadManager.getCachedController('assets/mainbackground.mp4');
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize =
          Size(constraints.maxWidth, constraints.maxHeight);
          final videoSize = controller.value.size;
          final fit = BoxFit.cover; // 使用 BoxFit.cover 填滿整個畫面

          final fittedSizes = applyBoxFit(fit, videoSize, containerSize);
          final renderSize = fittedSizes.destination;

          // 計算視頻的偏移量（BoxFit.cover 會裁切）
          final offset = Offset(
            (containerSize.width - renderSize.width) / 2,
            (containerSize.height - renderSize.height) / 2,
          );

          // 更新渲染大小和偏移量
          if (_videoRenderSize != renderSize || _videoOffset != offset) {
            _videoRenderSize = renderSize;
            _videoOffset = offset;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _calculateScaledTouchAreas();
            });
          }

          return Stack(
            children: [
              // 使用 FittedBox 進行縮放
              Positioned(
                left: offset.dx,
                top: offset.dy,
                width: renderSize.width,
                height: renderSize.height,
                child: FittedBox(
                  fit: fit,
                  child: SizedBox(
                    width: videoSize.width,
                    height: videoSize.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              // 顯示觸碰區塊
              if (widget.showTouchAreas && _scaledTouchAreas.isNotEmpty)
                ..._originalTouchAreas.keys.map((name) => _buildTouchArea(name)),
            ],
          );
        },
      ),
    );
  }

  /// 使用 FittedBox 進行等比例縮放的過渡視頻
  Widget _buildScaledTransitionVideo(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
          final videoSize = controller.value.size;
          final fit = BoxFit.cover; // 使用 BoxFit.cover 填滿整個畫面

          final fittedSizes = applyBoxFit(fit, videoSize, containerSize);
          final renderSize = fittedSizes.destination;

          // 計算視頻的偏移量（BoxFit.cover 會裁切）
          final offset = Offset(
            (containerSize.width - renderSize.width) / 2,
            (containerSize.height - renderSize.height) / 2,
          );

          return Stack(
            children: [
              Positioned(
                left: offset.dx,
                top: offset.dy,
                width: renderSize.width,
                height: renderSize.height,
                child: FittedBox(
                  fit: fit,
                  child: SizedBox(
                    width: videoSize.width,
                    height: videoSize.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startVideoTransition(String transitionVideoPath) async {
    setState(() {
      _isVideoTransitioning = true;
    });

    // 暫停當前背景視頻
    _currentVideoController?.pause();

    try {
      // 準備過渡視頻
      _transitionVideoController =
      await _preloadManager.getController(transitionVideoPath);
      if (_transitionVideoController != null) {
        // 標記過渡視頻為在使用中
        _preloadManager.markVideoInUse(transitionVideoPath, true);

        if (!_transitionVideoController!.value.isInitialized) {
          await _transitionVideoController!.initialize();
        }
        await _transitionVideoController!.seekTo(Duration.zero);
        await _transitionVideoController!.play();
        _transitionVideoController!.setLooping(false);

        // 等待第一幀準備好
        await Future.delayed(Duration(milliseconds: 50));
      }
    } catch (e) {
      print('Error during video transition: $e');
      // 在發生錯誤時恢復播放背景視頻
      _currentVideoController?.play();
      setState(() {
        _isVideoTransitioning = false;
      });
    }
  }

  void _calculateScaledTouchAreas() {
    if (_videoRenderSize == null) return;

    // 計算實際螢幕與原始設計尺寸的縮放比例
    double screenScaleX = _videoRenderSize!.width / DESIGN_WIDTH;
    double screenScaleY = _videoRenderSize!.height / DESIGN_HEIGHT;

    // 使用較大的縮放比例(保持等比例)，確保內容完全填滿螢幕
    double scaleFactor = math.max(screenScaleX, screenScaleY);

    // 計算偏移量，確保縮放中心在螢幕正中央
    double offsetX = (_videoRenderSize!.width - (DESIGN_WIDTH * scaleFactor)) / 2;
    double offsetY = (_videoRenderSize!.height - (DESIGN_HEIGHT * scaleFactor)) / 2;

    // 使用唯一的縮放和偏移計算
    _scaledTouchAreas = _originalTouchAreas.map((key, area) {
      return MapEntry(key, {
        'left': (area['left']! * DESIGN_WIDTH * scaleFactor) + offsetX,
        'top': (area['top']! * DESIGN_HEIGHT * scaleFactor) + offsetY,
        'width': area['width']! * DESIGN_WIDTH * scaleFactor,
        'height': area['height']! * DESIGN_HEIGHT * scaleFactor,
        'rotation': area['rotation']! * math.pi / 180, // 轉換為弧度
      });
    });

    // 只計算一次，避免重複計算
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildTouchArea(String name) {
    final area = _scaledTouchAreas[name];
    if (area == null) return Container();

    return Positioned(
      left: area['left']!,
      top: area['top']!,
      child: Transform.rotate(
        angle: area['rotation']!, // 已經是弧度
        alignment: Alignment.center, // 圍繞中心點旋轉
        child: GestureDetector(
          onTap: () => _handleTap(name),
          child: Container(
            width: area['width']!,
            height: area['height']!,
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(String name) async {
    if (_isLoading || _isVideoTransitioning) return;

    // 創建一個渲染控制標誌
    final ValueNotifier<bool> canRenderPage = ValueNotifier(false);

    try {
      setState(() {
        _isLoading = true;
      });

      final lazyLoadKey = _pageLazyLoadKeys[name];
      final transitionVideoPath = _getTransitionVideoPath(name);

      // 準備資源，同時保持當前層
      await _prepareResourcesForNavigation(
          name, lazyLoadKey, transitionVideoPath, canRenderPage);
    } catch (e) {
      print('頁面加載失敗: $e');
      _currentVideoController?.play();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _prepareResourcesForNavigation(
      String name,
      String? lazyLoadKey,
      String transitionVideoPath,
      ValueNotifier<bool> canRenderPage) async {
    final Completer<Map<String, dynamic>> resourceReadyCompleter =
    Completer<Map<String, dynamic>>();

    try {
      // 檢查資源是否已加載
      bool resourcesLoaded = await _checkResourcesLoaded(lazyLoadKey);

      if (!resourcesLoaded) {
        // 釋放當前緩存資源（除持久化資源外）
        await _preloadManager.releaseUnusedVideos();

        // 加載新頁面所需的資源
        if (lazyLoadKey != null) {
          await _preloadManager.lazyLoadPageVideos(
            lazyLoadKey,
            onLoadComplete: () async {
              // Ensure Rive file is also loaded for the main page
              if (lazyLoadKey == 'main') {
                await _preloadManager.lazyLoadPageVideos('main');
              }

              final controller =
              _preloadManager.getCachedController(transitionVideoPath);
              if (controller != null) {
                // 標記過渡視頻為在使用中
                _preloadManager.markVideoInUse(transitionVideoPath, true);

                resourceReadyCompleter.complete({
                  'lazyLoadComplete': true,
                  'transitionController': controller,
                  'isNewLoad': true
                });
              } else {
                resourceReadyCompleter.completeError('Failed to load transition video');
              }
            },
          );
        }
      } else {
        // 資源已加載，直接獲取過渡視頻控制器
        final controller =
        _preloadManager.getCachedController(transitionVideoPath);
        if (controller != null) {
          // 標記過渡視頻為在使用中
          _preloadManager.markVideoInUse(transitionVideoPath, true);

          resourceReadyCompleter.complete({
            'lazyLoadComplete': true,
            'transitionController': controller,
            'isNewLoad': false
          });
        } else {
          resourceReadyCompleter.completeError('Failed to load transition video');
        }
      }

      // 等待資源準備完成
      final result = await resourceReadyCompleter.future;

      // 獲取過渡視頻控制器
      final VideoPlayerController transitionController =
      result['transitionController'];

      // 確保視頻已初始化
      await _ensureVideo_initialized(transitionController);

      // 開始視頻過渡
      await _startVideoTransition(transitionVideoPath);

      // 等待過渡視頻開始渲染
      await Future.delayed(Duration(milliseconds: 50));

      // 允許頁面渲染
      canRenderPage.value = true;

      // 準備目標頁面
      Widget targetPage() => _selectTargetPage(name, transitionController);

      // 使用阻塞路由導航，保留當前背景
      Navigator.push(
        context,
        BlockingPageRoute(
          pageBuilder: targetPage,
          canRender: () => canRenderPage.value,
          backgroundLayer: _buildScaledVideo(), // 使用相同的縮放方法
        ),
      );
    } catch (e) {
      print('導航準備錯誤: $e');
      _currentVideoController?.play();
      rethrow;
    }
  }

  Future<bool> _checkResourcesLoaded(String? lazyLoadKey) async {
    if (lazyLoadKey == null) return true;
    final pageVideos = _preloadManager.pageCaches[lazyLoadKey] ?? [];
    bool allVideosLoaded = pageVideos.every((path) =>
    _preloadManager.hasController(path) &&
        _preloadManager.isVideoLoaded(path));
    return allVideosLoaded;
  }

  Future<void> _ensureVideo_initialized(VideoPlayerController controller) {
    // 創建一個 completer 來等待視頻初始化
    final completer = Completer<void>();

    void checkInitialization() {
      if (controller.value.isInitialized) {
        completer.complete();
        controller.removeListener(checkInitialization);
      }
    }

    controller.addListener(checkInitialization);

    // 觸發初始檢查並提供超時機制
    checkInitialization();

    return completer.future.timeout(
      Duration(seconds: 5),
      onTimeout: () {
        print('視頻初始化超時');
        throw TimeoutException('視頻初始化花費太長時間');
      },
    );
  }

  Widget _selectTargetPage(
      String name, VideoPlayerController transitionController) {
    switch (name) {
      case 'calendar':
        return MoodDiaryScreen(transitionController: transitionController);
      case 'radio':
        return MeditationScreen(transitionController: transitionController);
      case 'tarodcard':
        return TarodScreen(transitionController: transitionController);
      case 'pencil1':
      case 'pencil2':
      default:
        return ChatPage(transitionController: transitionController);
    }
  }

  String _getTransitionVideoPath(String name) {
    switch (name) {
      case 'calendar':
        return 'assets/cloud.mp4';
      case 'radio':
        return 'assets/sea.mp4';
      case 'tarodcard':
        return 'assets/card.mp4';
      case 'pencil1':
      case 'pencil2':
      default:
        return 'assets/chat.mp4';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景視頻和觸碰區塊
          _buildScaledVideo(),

          // 顯示退場動畫（如果存在）
          if (_preloadManager.reverseTransitionController != null &&
              _preloadManager.reverseTransitionController!.value.isInitialized &&
              _preloadManager.reverseTransitionController!.value.isPlaying)
            _buildScaledTransitionVideo(
                _preloadManager.reverseTransitionController),

          // 過渡視頻
          if (_isVideoTransitioning && _transitionVideoController != null)
            Positioned.fill(
              child: _buildScaledVideo(), // 使用相同的縮放方法
            ),

          // 加載動畫
          if (_isLoading) LazyLoadingWidget(),
        ],
      ),
    );
  }

  /// 確保 `_onTransitionVideoComplete` 方法正確定義
  void _onTransitionVideoComplete() {
    if (_transitionVideoController != null &&
        !_transitionVideoController!.value.isPlaying) {
      _transitionVideoController!.removeListener(_onTransitionVideoComplete);

      setState(() {
        _currentVideoController = _transitionVideoController;
        _transitionVideoController = null;
        _isVideoTransitioning = false;
      });

      _currentVideoController?.play();
    }
  }
}
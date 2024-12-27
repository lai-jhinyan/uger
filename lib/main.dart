import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'VideoPreloadManager.dart';
import 'RivePreloadManager.dart';
import 'package:audioplayers/audioplayers.dart';
import 'mainscreen.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image;

// 全域變數儲存使用者輸入的名稱
String globalUserName = "";

bool kRunWithoutMic = false;

bool isSimulator() {
  bool simulator = false;
  assert(simulator = true);
  return simulator;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiveFile.initialize();
  // 預加載 Rive 文件
  await RivePreloadManager().preloadRive('assets/loading.riv', stateMachineName: 'State Machine 1');
  if (isSimulator()) {
    kRunWithoutMic = true;
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // 全域共用的 AudioPlayer
  static final AudioPlayer audioPlayer = AudioPlayer();

  // 將 routeObserver 移到類外部，避免命名衝突
  static final RouteObserver<PageRoute<dynamic>> routeObserver = RouteObserver<PageRoute<dynamic>>();

  MyApp() {
    MyApp.audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // 設計稿的寬高
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Professional Login Flow',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            fontFamily: 'MyFont',
          ),
          home: SplashScreen(),
          navigatorObservers: [routeObserver],
        );
      },
    );
  }
}

/// 初始進入的 Splash 畫面
/// 1. 黑色背景、frist.png填滿整個頁面
/// 2. 淡入並停留片刻後淡出並切換至 LoginScreen
/// 並在此處開始播放背景音樂，音量由0到1淡入
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  late Animation<double> _fadeInAnimation;
  late AnimationController _fadeOutController;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeIn,
    ));

    _fadeOutController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _fadeOutController,
      curve: Curves.easeOut,
    ));

    // 開始播放
    MyApp.audioPlayer.play(AssetSource('music.mp3')).catchError((error) {
      print('音樂播放錯誤: $error');
    });
    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    await _fadeInController.forward();
    // 預加載其他資源，例如視頻、Rive 文件等
    await Future.wait([
      // 預加載 Rive 文件
      RivePreloadManager().preloadRive('assets/loading.riv', stateMachineName: 'State Machine 1'),
      // 你可以在這裡添加更多的預加載資源
    ]);
    await Future.delayed(Duration(seconds: 2)); // 停留片刻
    await _fadeOutController.forward();
    if (!mounted) return; // 檢查組件是否仍然掛載
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeOutAnimation,
        child: FadeTransition(
          opacity: _fadeInAnimation,
          child: SizedBox.expand(
            child: Image.asset(
              'assets/frist.png', // 更換為 'frist.png'
              fit: BoxFit.cover, // 填滿整個頁面
            ),
          ),
        ),
      ),
    );
  }
}

/// 登入頁面
/// 背景：loginscreen.png
/// 有一個 TextField 和「進入」按鈕，上方有「請輸入名字」的字樣
/// 若使用者未輸入名稱，點擊「進入」按鈕時給予提示
/// 點擊背景(圖片)時如鍵盤開啟則收起
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  late Animation<double> _fadeInAnimation;
  TextEditingController _nameController = TextEditingController();

  // 控制黑色覆蓋層的動畫
  late AnimationController _blackFadeController;
  late Animation<double> _blackFadeAnimation;

  bool _isBlackOverlayVisible = false;

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeIn,
    ));

    _blackFadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _blackFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_blackFadeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // 黑幕完全顯示後導航到 LoadingScreen
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => LoadingScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: Duration(milliseconds: 800),
            ),
          );
        }
      });

    _fadeInController.forward();
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _blackFadeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("請先輸入您的名稱"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 儲存名稱到全域變數
    globalUserName = name;

    // 開始黑幕淡入動畫
    setState(() {
      _isBlackOverlayVisible = true;
    });
    _blackFadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeInAnimation,
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus(); // 點擊背景收起鍵盤
          },
          child: Stack(
            children: [
              // 背景圖
              Positioned.fill(
                child: Image.asset(
                  'assets/loginscreen.png',
                  fit: BoxFit.cover,
                ),
              ),
              // 前景輸入框與按鈕
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "請輸入名字",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 4.0.w,
                              color: Colors.black54,
                              offset: Offset(2.0.w, 2.0.h),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                      TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center, // 設置文字居中
                        style: TextStyle(color: Colors.white, fontSize: 16.sp),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black54,
                          hintText: 'Your Name',
                          hintStyle: TextStyle(color: Colors.white70, fontSize: 14.sp),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      PressEffectButton(
                        text: "進入",
                        onPressed: _onLoginPressed,
                      ),
                    ],
                  ),
                ),
              ),
              // 黑色覆蓋層
              if (_isBlackOverlayVisible)
                FadeTransition(
                  opacity: _blackFadeAnimation,
                  child: Container(
                    color: Colors.black,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// LoadingScreen
/// 顯示 loading.mp4 動畫與加載資源進度
/// 完成後淡入黑幕，進入 MainScreen (位於 mainscreen.dart)
class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  double _loadingProgress = 0.0;
  String _loadingText = "喚醒憂隔中...";
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late VideoPlayerController _loadingAnimationController;
  late AnimationController _fadeOutBlackController;
  late Animation<double> _fadeOutBlackAnimation;

  final VideoPreloadManager _videoPreloadManager = VideoPreloadManager();

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    _fadeController.forward();

    _fadeOutBlackController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeOutBlackAnimation =
    Tween<double>(begin: 0.0, end: 1.0).animate(_fadeOutBlackController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // 讀取結束，前往 MainScreen
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation1, animation2) => MainScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (context, animation, secondaryAnimation,
                  child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      });

    _loadingAnimationController =
    VideoPlayerController.asset('assets/loading.mp4')
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return; // 檢查組件是否仍然掛載
        setState(() {});
        _loadingAnimationController.play();
      }).catchError((error) {
        print('Loading animation failed: $error');
      });

    _startLoading();
  }

  Widget _buildScaledVideo() {
    if (!_loadingAnimationController.value.isInitialized) {
      return Container();
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _loadingAnimationController.value.size.width,
          height: _loadingAnimationController.value.size.height,
          child: VideoPlayer(_loadingAnimationController),
        ),
      ),
    );
  }

  Future<void> _startLoading() async {
    try {
      final mainVideo = ['assets/mainbackground.mp4'];
      await _videoPreloadManager.preloadVideos(mainVideo);

      if (!mounted) return; // 檢查組件是否仍然掛載

      VideoPlayerController? videoController = await _videoPreloadManager
          .getController('assets/mainbackground.mp4');
      if (videoController != null) {
        videoController.setLooping(true);
        videoController.play();
      }

      for (int i = 0; i <= 10; i++) {
        await Future.delayed(Duration(milliseconds: 30));
        if (!mounted) return; // 檢查組件是否仍然掛載
        double progress = i / 10;
        setState(() {
          _loadingProgress = progress;
          _loadingText = progress < 1.0
              ? "正在喚醒憂隔... (${(progress * 100).toStringAsFixed(0)}%)"
              : "憂格醒來了！";
        });
      }

      if (!mounted) return; // 檢查組件是否仍然掛載

      await Future.delayed(const Duration(seconds: 2));
      await _fadeOutBlackController.forward();
    } catch (e) {
      print('加载过程中发生错误: $e');
      if (mounted) {
        setState(() {
          _loadingText = "憂隔睡死了...";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildScaledVideo(),
          Positioned(
            top: 0.25.sh,
            left: 0.1.sw,
            right: 0.1.sw,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 500),
                  transitionBuilder: (Widget child,
                      Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    _loadingText,
                    key: ValueKey<String>(_loadingText),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0.w,
                          color: Colors.black,
                          offset: Offset(2.0.w, 2.0.h),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 0.02.sh),
                SizedBox(
                  width: 0.8.sw,
                  height: 0.015.sh,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0.0075.sh),
                    child: LinearProgressIndicator(
                      value: _loadingProgress,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blueAccent),
                      minHeight: 0.015.sh,
                    ),
                  ),
                ),
              ],
            ),
          ),
          FadeTransition(
            opacity: _fadeOutBlackAnimation,
            child: Container(
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fadeOutBlackController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }
}

/// 自訂帶按壓縮放效果的按鈕
class PressEffectButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;

  const PressEffectButton({
    Key? key,
    required this.onPressed,
    required this.text,
  }) : super(key: key);

  @override
  _PressEffectButtonState createState() => _PressEffectButtonState();
}

class _PressEffectButtonState extends State<PressEffectButton> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  double get _pressScale => _isPressed ? 0.8 : 1.0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // 動畫邏輯：按壓時縮小到0.8，放開後再回到1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
    ]).animate(_animationController);

    _animationController.addStatusListener((status) {
      // 動畫結束後才執行 onPressed()
      if (status == AnimationStatus.completed) {
        widget.onPressed();
      }
    });
  }

  void _handleTap() {
    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final scale = _isPressed ? _pressScale : _scaleAnimation.value;

          return GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: _handleTap,
            child: Container(
              width: 200.w * scale,
              height: 60.h * scale,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(_isPressed ? 0.8 : 1.0),
                    Colors.lightBlueAccent.withOpacity(_isPressed ? 0.7 : 1.0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isPressed ? 0.2 : 0.4),
                    blurRadius: _isPressed ? 4.w : 12.w,
                    offset: Offset(0, _isPressed ? 2.h : 4.h),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp * scale,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 4.0.w,
                      color: Colors.black54,
                      offset: Offset(1.5.w, 1.5.h),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

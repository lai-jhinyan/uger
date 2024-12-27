import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'main.dart'; // 使用 MyApp.audioPlayer
import 'VideoPreloadManager.dart';
import 'RivePreloadManager.dart';
import 'dart:math' as math;
import 'dart:async'; // 為 Timer、StreamSubscription 加上
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart' hide LinearGradient, Image; // 避免與 Flutter 衝突

// 定義冥想模式和難度的枚舉
enum MeditationMode { sleep, myself, vision, emotion }
enum MeditationDifficulty {
  basic,
  intermediate,
  zenMaster,
}

extension MeditationDifficultyExtension on MeditationDifficulty {
  String get displayName {
    switch (this) {
      case MeditationDifficulty.basic:
        return "基礎";
      case MeditationDifficulty.intermediate:
        return "進階";
      case MeditationDifficulty.zenMaster:
        return "禪師";
      default:
        return "未知難易度";
    }
  }

  // 如果 durationInMinutes 仍然需要使用，可以保留不變
  int get durationInMinutes {
    switch (this) {
      case MeditationDifficulty.basic:
        return 5;
      case MeditationDifficulty.intermediate:
        return 10;
      case MeditationDifficulty.zenMaster:
        return 15;
      default:
        return 0;
    }
  }
}

// 數據類別來封裝選擇的設置
class MeditationSettings {
  final MeditationMode mode;
  final MeditationDifficulty difficulty;
  final String bgmImage;

  MeditationSettings({
    required this.mode,
    required this.difficulty,
    required this.bgmImage,
  });
}

// 全局音樂控制函式
Future<void> playGlobalMusic(String mp3Path) async {
  await MyApp.audioPlayer.stop();
  await MyApp.audioPlayer.setSource(AssetSource(mp3Path));
  await MyApp.audioPlayer.setReleaseMode(ReleaseMode.loop);
  await MyApp.audioPlayer.play(AssetSource(mp3Path));
}

Future<void> pauseGlobalMusic() async {
  await MyApp.audioPlayer.pause();
}

Future<void> resumeGlobalMusic() async {
  await MyApp.audioPlayer.resume();
}

void setGlobalMusicVolume(double volume) {
  MyApp.audioPlayer.setVolume(volume);
}

// 自定義圖示按鈕
class CustomIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final double scaleFactor;
  final bool isDarkMode;
  final double baseButtonSize;
  final double baseIconSize;

  const CustomIconButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.scaleFactor = 1.0,
    this.isDarkMode = false,
    this.baseButtonSize = 60.0,
    this.baseIconSize = 30.0,
    Key? key,
  }) : super(key: key);

  @override
  _CustomIconButtonState createState() => _CustomIconButtonState();
}

class _CustomIconButtonState extends State<CustomIconButton>
    with SingleTickerProviderStateMixin {
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
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.8)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: 0.8, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 1),
    ]).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onPressed();
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final baseButtonSize = widget.baseButtonSize * widget.scaleFactor;
    final baseIconSize = widget.baseIconSize * widget.scaleFactor;

    final gradientColors = widget.isActive || _isPressed
        ? (widget.isDarkMode
        ? [
      Colors.blueGrey[700]!.withOpacity(0.8),
      Colors.blueGrey.withOpacity(0.5)
    ]
        : [
      Colors.deepOrange.withOpacity(0.8),
      Colors.orangeAccent.withOpacity(0.5)
    ])
        : (widget.isDarkMode
        ? [
      Colors.blueGrey[700]!.withOpacity(0.6),
      Colors.blueGrey.withOpacity(0.5)
    ]
        : [
      Colors.deepOrange.withOpacity(0.6),
      Colors.orangeAccent.withOpacity(0.5)
    ]);

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
              width: baseButtonSize * scale,
              height: baseButtonSize * scale,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                shape: BoxShape.circle, // 改為圓形
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius:
                    (_isPressed ? 4 : 12 * widget.scaleFactor) * scale,
                    spreadRadius:
                    (_isPressed ? 1 : 2 * widget.scaleFactor) * scale,
                    offset: Offset(
                        0, (_isPressed ? 2 : 4)) *
                        widget.scaleFactor *
                        scale,
                  ),
                  BoxShadow(
                    color: _isPressed
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    blurRadius:
                    (_isPressed ? 4 : 15 * widget.scaleFactor) * scale,
                    spreadRadius:
                    (_isPressed ? 1 : -5 * widget.scaleFactor) * scale,
                    offset: _isPressed
                        ? Offset(0, 2) * scale
                        : Offset(0, -5) * widget.scaleFactor * scale,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  color: (_isPressed || widget.isActive)
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                  size: baseIconSize * scale,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 小插頁: 用於快速選擇BGM的widget
class QuickBGMSelectorSheet extends StatefulWidget {
  final ValueChanged<String> onSelectBGM;

  const QuickBGMSelectorSheet({Key? key, required this.onSelectBGM})
      : super(key: key);

  @override
  _QuickBGMSelectorSheetState createState() => _QuickBGMSelectorSheetState();
}

class _QuickBGMSelectorSheetState extends State<QuickBGMSelectorSheet> {
  final List<String> bgmImages = [
    "assets/images/bgm.png",
    "assets/images/morning_way.png",
    "assets/images/sea_morning.png",
    "assets/images/sea_way.png",
    "assets/images/universe.png",
    "assets/images/war_song.png"
  ];

  final int bigNumber = 10000;
  late PageController _pageController;
  int currentPage = 0;

  final Map<String, String> bgmMap = {
    "assets/images/bgm.png": "雲海漫步",
    "assets/images/morning_way.png": "星河悠悠",
    "assets/images/sea_morning.png": "月夜的遐想",
    "assets/images/sea_way.png": "湖心之境",
    "assets/images/universe.png": "落葉的輕語",
    "assets/images/war_song.png": "青山的心跳"
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.3,
      initialPage: bigNumber * bgmImages.length,
    );

    _pageController.addListener(() {
      setState(() {
        if (_pageController.hasClients &&
            _pageController.position.haveDimensions) {
          currentPage = _pageController.page!.round();
        } else {
          currentPage = _pageController.initialPage;
        }
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double responsiveSize(BuildContext context, double baseSize) {
    return baseSize.w;
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // 小插頁樣式：與音樂控制器底色類似 (白色不透明度0.1)，有圓角
    return Container(
      width: width,
      height: screenHeight * 0.2, // 修改為20%螢幕高度
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(40.r), // 與控制器相同圓角
      ),
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          int actualIndex = index % bgmImages.length;
          double page = _pageController.hasClients &&
              _pageController.position.haveDimensions
              ? _pageController.page!
              : _pageController.initialPage.toDouble();
          double distance = (page - index).abs();
          double scale = math.max(0.7, 1 - (distance * 0.3));

          return GestureDetector(
            onTap: () {
              String selectedBGM = bgmImages[actualIndex];
              widget.onSelectBGM(selectedBGM);
            },
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, // 確保圖片為圓形
                    image: DecorationImage(
                      image: AssetImage(bgmImages[actualIndex]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class JellyfishSheet extends StatefulWidget {
  final Function(String) onSummon;

  const JellyfishSheet({Key? key, required this.onSummon}) : super(key: key);

  @override
  _JellyfishSheetState createState() => _JellyfishSheetState();
}

class _JellyfishSheetState extends State<JellyfishSheet> {
  @override
  Widget build(BuildContext context) {
    final _MeditationScreenState? parentState =
    context.findAncestorStateOfType<_MeditationScreenState>();

    // 確保 parentState 不為空
    if (parentState == null) {
      return SizedBox.shrink();
    }

    int remaining =
        parentState._maxJellyfish - parentState._jellyfishArtboards.length;

    double responsiveSize(double baseSize) {
      return baseSize.w;
    }

    return Container(
      // 改進的小插頁外觀
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(50.r)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 25.h),
      child: SingleChildScrollView( // 添加 SingleChildScrollView
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖放區域指示器
            Container(
              width: 60.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
            SizedBox(height: 20.h),
            // 剩餘水母數量顯示
            Text(
              "剩餘水母數量：$remaining",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 25.h),
            // 水母圖片拖動區域
            Draggable<String>(
              data: 'jellyfish',
              feedback: Opacity(
                opacity: 0.8,
                child: Image.asset(
                  'assets/jellyfish.png',
                  width: 200.w, // 放大尺寸
                  height: 200.h, // 放大尺寸
                  fit: BoxFit.contain,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/jellyfish.png',
                  width: 200.w, // 放大尺寸
                  height: 200.h, // 放大尺寸
                  fit: BoxFit.contain,
                ),
              ),
              child: Image.asset(
                'assets/jellyfish.png',
                width: 200.w, // 放大尺寸
                height: 200.h, // 放大尺寸
                fit: BoxFit.contain,
              ),
              onDragStarted: () {
                print("開始拖動水母");
              },
              onDragEnd: (details) {
                print("結束拖動水母");
                // 確保這裡不調用 _summonJellyfish
              },
            ),
            SizedBox(height: 20.h),
            // 提示文字
            Text(
              "幫助水母游入海洋",
              style:
              TextStyle(color: Colors.white70, fontSize: 18.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 25.h),
            // 移除動畫速度控制滑桿
          ],
        ),
      ),
    );
  }
}

// 單例類別來管理水母數量
class JellyfishCounter {
  JellyfishCounter._privateConstructor();

  static final JellyfishCounter instance = JellyfishCounter._privateConstructor();

  final int maxCount = 5;
  int currentCount = 0;

  final StreamController<int> _controller = StreamController<int>.broadcast();

  Stream<int> get stream => _controller.stream;

  void increment() {
    if (currentCount < maxCount) {
      currentCount++;
      _controller.sink.add(currentCount);
    }
  }

  void decrement() {
    if (currentCount > 0) {
      currentCount--;
      _controller.sink.add(currentCount);
    }
  }

  void dispose() {
    _controller.close();
  }
}

class JellyfishInstance {
  final Artboard artboard;
  final double x;
  final double y;
  String name; // 水母名稱
  bool isNameVisible; // 名稱是否可見

  JellyfishInstance({
    required this.artboard,
    required this.x,
    required this.y,
    this.name = "水母",
    this.isNameVisible = false,
  });
}
// 小插頁: 用於選擇 BGM 和人聲的 widget
class MeditationSelectorSheet extends StatefulWidget {
  final ValueChanged<MeditationSettings> onApply;

  const MeditationSelectorSheet({Key? key, required this.onApply})
      : super(key: key);

  @override
  _MeditationSelectorSheetState createState() =>
      _MeditationSelectorSheetState();
}

class _MeditationSelectorSheetState extends State<MeditationSelectorSheet> {
  final List<String> bgmImages = [
    "assets/images/bgm.png",
    "assets/images/morning_way.png",
    "assets/images/sea_morning.png",
    "assets/images/sea_way.png",
    "assets/images/universe.png",
    "assets/images/war_song.png"
  ];

  final List<String> voiceImages = [
    'assets/blue.png',
    'assets/orange.png',
    'assets/purple.png',
    'assets/white.png'
  ];

  final List<String> voiceNames = [
    "藍憂隔",
    "橘憂隔",
    "紫憂隔",
    "白憂隔"
  ];

  final List<String> difficultyNames = [
    "難易度（約 5 分鐘）",
    "難易度（約 10 分鐘）",
    "難易度（約 15 分鐘）"
  ];

  late PageController bgmPageController;
  int bgmCurrentPage = 0;

  late PageController voicePageController;
  int voiceCurrentPage = 0;

  // 難度選項
  final List<MeditationDifficulty> difficultyItems = [
    MeditationDifficulty.basic,
    MeditationDifficulty.intermediate,
    MeditationDifficulty.zenMaster
  ];
  late PageController diffPageController;
  int diffCurrentPage = 0;

  double blockSize = 80.0;
  final double sectionSpacing = 10.0;

  // 定義模式和難度的選擇
  final List<String> modes = ["幫助睡眠", "自我覺察", "視覺引導", "情緒調節"];
  int selectedModeIndex = 0;
  MeditationMode _selectedMode = MeditationMode.sleep;
  MeditationDifficulty _selectedDifficulty = MeditationDifficulty.basic;

  // 名稱對應修改：
  final Map<String, String> bgmMap = {
    "assets/images/bgm.png": "星河悠悠",
    "assets/images/morning_way.png": "林間靜謐",
    "assets/images/sea_morning.png": "海洋的呢喃",
    "assets/images/sea_way.png": "湖心之境",
    "assets/images/universe.png": "雲海漫步",
    "assets/images/war_song.png": "青山脈動"
  };

  // BGM 音樂路徑映射
  final Map<String, String> bgmAudioMap = {
    "assets/images/bgm.png": "music.mp3",
    "assets/images/morning_way.png": "bgm/morning_way.mp3",
    "assets/images/sea_morning.png": "bgm/sea_morning.mp3",
    "assets/images/sea_way.png": "bgm/sea_way.mp3",
    "assets/images/universe.png": "bgm/universe.mp3",
    "assets/images/war_song.png": "bgm/war_song.mp3"
  };

  @override
  void initState() {
    super.initState();
    bgmPageController = PageController(
      viewportFraction: 0.35,
      initialPage: bgmImages.length * 10000, // 避免初始跳動
    );
    voicePageController = PageController(viewportFraction: 0.35);
    diffPageController = PageController(viewportFraction: 0.35);

    bgmPageController.addListener(() {
      setState(() {
        if (bgmPageController.hasClients &&
            bgmPageController.position.haveDimensions) {
          bgmCurrentPage = bgmPageController.page!.round();
        }
      });
    });

    voicePageController.addListener(() {
      setState(() {
        if (voicePageController.hasClients &&
            voicePageController.position.haveDimensions) {
          voiceCurrentPage = voicePageController.page!.round();
        }
      });
    });

    diffPageController.addListener(() {
      setState(() {
        if (diffPageController.hasClients &&
            diffPageController.position.haveDimensions) {
          diffCurrentPage = diffPageController.page!.round();
          _selectedDifficulty =
          MeditationDifficulty.values[diffCurrentPage % difficultyItems.length];
        }
      });
    });
  }

  @override
  void dispose() {
    bgmPageController.dispose();
    voicePageController.dispose();
    diffPageController.dispose();
    super.dispose();
  }

  // 檢查是否選擇了第一個人聲選項
  bool _isFirstVoiceOptionSelected() {
    int actualVoiceIndex = voiceCurrentPage % voiceImages.length;
    return actualVoiceIndex == 0;
  }

  // 提示訊息狀態變量
  bool _showUnavailableMessage = false;
  double _unavailableMessageOpacity = 0.0;

  // 顯示提示訊息的方法
  Future<void> _showUnavailableVoiceMessage() async {
    setState(() {
      _showUnavailableMessage = true;
      _unavailableMessageOpacity = 1.0;
    });

    // 等待兩秒
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _unavailableMessageOpacity = 0.0;
    });

    // 等待淡出動畫完成
    await Future.delayed(Duration(milliseconds: 500));

    setState(() {
      _showUnavailableMessage = false;
    });
  }

  // 構建模式選擇器
  Widget _buildModeSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double segmentWidth = constraints.maxWidth / MeditationMode.values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Duration(milliseconds: 150),
                left: _selectedMode.index * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                ),
              ),
              Row(
                children: MeditationMode.values.asMap().entries.map((entry) {
                  int idx = entry.key;
                  MeditationMode mode = entry.value;
                  bool isSelected = (idx == _selectedMode.index);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMode = mode;
                      });
                    },
                    child: SizedBox(
                      width: segmentWidth,
                      child: Center(
                        child: Text(
                          modes[idx],
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12.0,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  // 構建 BGM 選擇器
  Widget _buildBGMItemSelector() {
    return SizedBox(
      height: 110.0,
      child: PageView.builder(
        controller: bgmPageController,
        physics: BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          int actualIndex = index % bgmImages.length;
          double page = bgmPageController.hasClients &&
              bgmPageController.position.haveDimensions
              ? bgmPageController.page!
              : bgmPageController.initialPage.toDouble();
          double distance = (page - index).abs();
          double scale = math.max(0.7, 1 - (distance * 0.3));

          return GestureDetector(
            onTap: () {
              String selectedBGM = bgmImages[actualIndex];
              if (_isFirstVoiceOptionSelected()) {
                // 只有當選擇第一個人聲選項時，才能應用設置
                widget.onApply(MeditationSettings(
                  mode: _selectedMode,
                  difficulty: _selectedDifficulty,
                  bgmImage: selectedBGM,
                ));
              } else {
                // 否則，顯示提示訊息
                _showUnavailableVoiceMessage();
              }
            },
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 70.w,
                  height: 70.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, // 圓形
                    image: DecorationImage(
                      image: AssetImage(bgmImages[actualIndex]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 構建人聲選項
  Widget _buildVoiceItem(int index) {
    String imgPath = voiceImages[index];
    String voiceName = voiceNames[index];
    bool isFirst = index == 0; // 判斷是否為第一個選項

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80.w,
          height: 80.h,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2), // 添加底色
            borderRadius: BorderRadius.circular(15.0), // 圓角
            image: DecorationImage(
              image: AssetImage(imgPath),
              fit: BoxFit.cover,
              colorFilter: isFirst
                  ? null // 第一個選項不應用色彩過濾器
                  : ColorFilter.mode(
                  Colors.black.withOpacity(0.3), BlendMode.darken), // 其他選項應用色彩過濾器
            ),
          ),
      child: Padding(
        padding: const EdgeInsets.only(top: 2.0), // 調整頂部內邊距
          child: Center(
            child: isFirst
                ? SizedBox.shrink() // 第一個選項不顯示文字
                : Text(
              "敬請期待", // 顯示動態名稱
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp, // 調整文字大小
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        ),
      ],
    );
  }

  // 構建人聲選項選擇器
  Widget _buildVoiceItemSelector() {
    final total = voiceImages.length;
    return SizedBox(
      height: 160.h, // 增加高度以容納名稱
      child: PageView.builder(
        controller: voicePageController,
        itemCount: total,
        physics: BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          double page = voicePageController.hasClients &&
              voicePageController.position.haveDimensions
              ? voicePageController.page!
              : voicePageController.initialPage.toDouble();
          double distance = (page - index).abs();
          double scale = math.max(0.5, 1 - (distance * 0.3));
          return Center(
            child: Transform.scale(
              scale: scale,
              child: _buildVoiceItem(index),
            ),
          );
        },
      ),
    );
  }

  // 構建難易度選項選擇器
  Widget _buildDifficultyItemSelector() {
    return SizedBox(
      height: 110.0,
      child: PageView.builder(
        controller: diffPageController,
        itemCount: difficultyItems.length,
        physics: BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          MeditationDifficulty difficulty = difficultyItems[index];
          String displayName = difficulty.displayName;

          double page = diffPageController.hasClients &&
              diffPageController.position.haveDimensions
              ? diffPageController.page!
              : diffPageController.initialPage.toDouble();
          double distance = (page - index).abs();
          double scale = math.max(0.7, 1 - (distance * 0.3));

          return Center(
            child: Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDifficulty = difficulty;
                  });
                },
                child: Container(
                  width: blockSize,
                  height: blockSize,
                  decoration: BoxDecoration(
                    color: _selectedDifficulty == difficulty
                        ? Colors.orangeAccent.withOpacity(0.5)
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20.0), // 圓角
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayName,
                    style: TextStyle(
                        color: Colors.white, fontSize: 14.0),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 獲取當前選中的 BGM 圖片路徑
  String getSelectedBGMImage() {
    int actualIndex = bgmCurrentPage % bgmImages.length;
    return bgmImages[actualIndex];
  }

  @override
  Widget build(BuildContext context) {
    int diffActualIndex =
    diffPageController.hasClients && diffPageController.position.haveDimensions
        ? diffPageController.page!.round() % difficultyItems.length
        : 0;
    MeditationDifficulty diffItem = difficultyItems[diffActualIndex];
    String diffTitle = diffItem.displayName;

    int voiceActualIndex =
    voicePageController.hasClients && voicePageController.position.haveDimensions
        ? voicePageController.page!.round() % voiceImages.length
        : 0;
    String voiceTitle = "聲音選擇（${voiceNames[voiceActualIndex]}）";

    String bgmImg = getSelectedBGMImage();
    String bgmTitle = bgmMap[bgmImg] ?? "未知曲目";

    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10.0),
                  width: 40.0,
                  height: 5.0,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                _buildModeSelector(),
                SizedBox(height: 20.0),
                Text(
                  bgmTitle,
                  style: TextStyle(color: Colors.white, fontSize: 14.0),
                ),
                SizedBox(height: 10.0),
                _buildBGMItemSelector(),
                SizedBox(height: sectionSpacing),
                Text(
                  voiceTitle,
                  style: TextStyle(color: Colors.white, fontSize: 14.0),
                ),
                SizedBox(height: 10.0),
                _buildVoiceItemSelector(),
                SizedBox(height: sectionSpacing),
                Text(
                  diffTitle,
                  style: TextStyle(color: Colors.white, fontSize: 14.0),
                ),
                SizedBox(height: 10.0),
                _buildDifficultyItemSelector(),
                SizedBox(height: sectionSpacing),
                Padding(
                  padding: EdgeInsets.zero,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.withOpacity(0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      padding: EdgeInsets.symmetric(
                          horizontal: 40.0, vertical: 12.0),
                    ),
                    onPressed: () {
                      if (_isFirstVoiceOptionSelected()) {
                        String selectedBGM = getSelectedBGMImage();
                        widget.onApply(MeditationSettings(
                          mode: _selectedMode,
                          difficulty: _selectedDifficulty,
                          bgmImage: selectedBGM,
                        ));
                      } else {
                        _showUnavailableVoiceMessage();
                      }
                    },
                    child: Text(
                      "應用",
                      style: TextStyle(fontSize: 16.0, color: Colors.white),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        // 提示訊息覆蓋層
        if (_showUnavailableMessage)
          Center(
            child: AnimatedOpacity(
              opacity: _unavailableMessageOpacity,
              duration: Duration(milliseconds: 500),
              child: Container(
                padding:
                EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  "該人聲尚未開放",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


// MeditationScreen 類別
class MeditationScreen extends StatefulWidget {
  final VideoPlayerController? transitionController;

  const MeditationScreen({
    Key? key,
    this.transitionController,
  }) : super(key: key);

  @override
  _MeditationScreenState createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen>
    with WidgetsBindingObserver, RouteAware, TickerProviderStateMixin {
  static const double baseWidth = 375.0;

  VideoPlayerController? _videoController;
  late VideoPreloadManager _preloadManager;
  bool _canRenderContent = false;
  bool _isSheetOpen = false;
  bool _isQuickSheetOpen = false;
  bool _isJellyfishSheetOpen = false;

  bool _isInitialized = false;
  bool _isSliderDragging = false;

  bool _isDragging = false;
  bool _isInTopHalf = false;

  late AnimationController _sheetAnimationController;
  late AnimationController _controllerAnimationController;
  late AnimationController _quickSheetAnimationController;
  late AnimationController _jellyfishSheetAnimationController;

  bool _showUnavailableMessage = false;
  double _unavailableMessageOpacity = 0.0;

  bool _isTransitionCompleted = false;
  double _sliderValue = 100.0;

  double get _voiceProgressPercent {
    if (_voiceDuration.inSeconds == 0) return 0.0;
    return _voicePosition.inSeconds / _voiceDuration.inSeconds;
  }

  final Map<String, String> bgmMap = {
    "assets/images/bgm.png": "星河悠悠",
    "assets/images/morning_way.png": "林間靜謐",
    "assets/images/sea_morning.png": "海洋的呢喃",
    "assets/images/sea_way.png": "湖心之境",
    "assets/images/universe.png": "雲海漫步",
    "assets/images/war_song.png": "青山脈動"
  };

  Map<String, String> bgmNameMap = {
    'bgm/morning_way.mp3': 'Morning Way',
    'bgm/sea_morning.mp3': 'Sea Morning',
    'bgm/sea_way.mp3': 'Sea Way',
    'bgm/universe.mp3': 'Universe',
    'bgm/war_song.mp3': 'War Song',
  };

  final Map<String, String> bgmAudioMap = {
  "assets/images/bgm.png": "music.mp3",
  "assets/images/morning_way.png": "bgm/morning_way.MP3",
  "assets/images/sea_morning.png": "bgm/sea_morning.MP3",
  "assets/images/sea_way.png": "bgm/sea_way.MP3",
  "assets/images/universe.png": "bgm/universe.MP3",
  "assets/images/war_song.png": "bgm/war_song.MP3"
  };

  String _currentBGMImage = "assets/images/bgm.png";

  late AnimationController _rotateController;
  bool _isPlayingMusic = true;
  bool _isPausedIcon = true;
  String _currentSongName = "星河悠悠";

  // 新增人聲音樂播放器
  final AudioPlayer _voiceAudioPlayer = AudioPlayer();

  // 追蹤人聲音樂播放進度
  Duration _voiceDuration = Duration.zero;
  Duration _voicePosition = Duration.zero;
  StreamSubscription? _voicePositionSubscription;
  StreamSubscription? _voiceDurationSubscription;

  // 定義預設位置列表
  List<Offset> predefinedPositions = [];
  int nextPositionIndex = 0;

  // 問候語顯示變數
  String? _currentDisplayedGreeting;
  late AnimationController _greetingAnimationController;
  late Animation<double> _greetingOpacity;
  bool _isGreetingVisible = false;

  // 水母名稱顯示變數
  String? _currentDisplayedName;
  late AnimationController _nameAnimationController;
  late Animation<double> _nameOpacity;
  bool _isNameVisible = false;

  // 初始化水母列表，最多五隻
  List<JellyfishInstance> _jellyfishArtboards = [];
  final int _maxJellyfish = 5;

  // 問候語列表
  final List<String> greetings = [
    "你好，$globalUserName！讓我們一起冥想吧！",
    "歡迎回來，$globalUserName！開始你的冥想之旅。",
    "嗨，$globalUserName！放鬆心情，享受冥想。",
    "祝福你，$globalUserName！冥想時光開始了。",
    "感謝你的到來，$globalUserName！讓我們一起冥想。"
  ];

  bool _isFirstEntry = true; // 新增變數以追蹤是否首次進入頁面

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _preloadManager = VideoPreloadManager();
    _initializeAllVideoControllers();

    // 初始化問候語動畫控制器
    _greetingAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _greetingOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _greetingAnimationController,
        curve: Curves.easeIn,
      ),
    );

    // 初始化水母名稱動畫控制器
    _nameAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _nameAnimationController,
        curve: Curves.easeIn,
      ),
    );

    // 初始化其他動畫控制器
    _sheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controllerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _quickSheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _jellyfishSheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 8),
    )..repeat();

    // 初始化 BGM 圖片和名稱
    _currentBGMImage = "assets/images/bgm.png";
    _currentSongName = bgmMap[_currentBGMImage] ?? "未知曲目";

    setGlobalMusicVolume(_sliderValue / 50.0);

    // 初始化人聲音樂播放器
    setVoiceMusicVolume(1.0); // 預設人聲音樂音量為最大

    // 監聽人聲音樂的播放進度
    _voiceDurationSubscription = _voiceAudioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _voiceDuration = duration;
      });
    });

    _voicePositionSubscription = _voiceAudioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _voicePosition = position;
      });
    });

    // 監聽人聲音樂播放完成
    _voiceAudioPlayer.onPlayerComplete.listen((event) {
      // 根據需要執行操作，如自動切換到下一首
    });
  }

  // Method to show the unavailable voice message
  Future<void> _showUnavailableVoiceMessage() async {
    setState(() {
      _showUnavailableMessage = true;
      _unavailableMessageOpacity = 1.0;
    });

    // 等待兩秒
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _unavailableMessageOpacity = 0.0;
    });

    // 等待淡出動畫完成
    await Future.delayed(Duration(milliseconds: 500));

    setState(() {
      _showUnavailableMessage = false;
    });
  }

  // 初始化預設位置的方法
  void _initializePredefinedPositions() {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // 定義5個均勻分佈的位置
    predefinedPositions = [
      Offset(screenWidth * 0.25, screenHeight * 0.25),
      Offset(screenWidth * 0.75, screenHeight * 0.25),
      Offset(screenWidth * 0.25, screenHeight * 0.75),
      Offset(screenWidth * 0.75, screenHeight * 0.75),
      Offset(screenWidth * 0.5, screenHeight * 0.5),
    ];
  }

  @override
  void dispose() {
    // 取消訂閱路由觀察者
    MyApp.routeObserver.unsubscribe(this);

    // 移除小部件觀察者
    WidgetsBinding.instance.removeObserver(this);

    // 銷毀所有 AnimationController
    _sheetAnimationController.dispose();
    _controllerAnimationController.dispose();
    _quickSheetAnimationController.dispose();
    _jellyfishSheetAnimationController.dispose();
    _rotateController.dispose();
    _greetingAnimationController.dispose();
    _nameAnimationController.dispose();

    // 移除所有 AnimationController 的監聽器
    _greetingAnimationController.removeStatusListener((status) {});
    _nameAnimationController.removeStatusListener((status) {});

    // 釋放人聲音樂播放器資源
    _voicePositionSubscription?.cancel();
    _voiceDurationSubscription?.cancel();
    _voiceAudioPlayer.dispose();

    // 關閉 JellyfishCounter 的 StreamController
    JellyfishCounter.instance.dispose();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializePredefinedPositions();
      _isInitialized = true;

      // 如果有需要，可以在這裡進行其他初始化操作
    }
  }

  @override
  void didPopNext() {
    if (_preloadManager.reverseTransitionController != null) {
      _preloadManager.reverseTransitionController!
          .addListener(_onReverseTransitionComplete);
      _preloadManager.reverseTransitionController!.play();

      _videoController?.seekTo(Duration.zero);
      _videoController?.pause();

      setState(() {});
    }
  }

  // 設置人聲音樂音量
  void setVoiceMusicVolume(double volume) {
    _voiceAudioPlayer.setVolume(volume);
  }

  void _showGreeting() {
    setState(() {
      _isGreetingVisible = true;
      // 隨機選取一條問候語
      _currentDisplayedGreeting =
      greetings[math.Random().nextInt(greetings.length)];
    });
    _greetingAnimationController.forward();

    // 問候語淡入完成後，等待5秒再淡出
    void _statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) { // 確保 widget 仍在 widget 樹中
            _greetingAnimationController.reverse();
          }
        });
      }
      if (status == AnimationStatus.dismissed) {
        if (mounted) { // 確保 widget 仍在 widget 樹中
          setState(() {
            _isGreetingVisible = false;
            _currentDisplayedGreeting = null;
          });
        }
        // 移除監聽器以避免重複添加
        _greetingAnimationController.removeStatusListener(_statusListener);
      }
    }

    _greetingAnimationController.addStatusListener(_statusListener);
  }

  void _onReverseTransitionComplete() {
    if (_preloadManager.reverseTransitionController != null &&
        !_preloadManager.reverseTransitionController!.value.isPlaying) {
      _preloadManager.reverseTransitionController!
          .removeListener(_onReverseTransitionComplete);

      // Start playing main background video
      _videoController?.play();

      // Optionally release transition video resources
      _preloadManager.releaseVideo('assets/sea_reverse.mp4');
      _preloadManager.reverseTransitionController = null;

      setState(() {});
    }
  }

  Future<void> _initializeAllVideoControllers() async {
    try {
      await _preloadManager.lazyLoadPageVideos('radio');

      if (widget.transitionController != null) {
        await widget.transitionController!.seekTo(Duration.zero);
        widget.transitionController!.setLooping(false);
        widget.transitionController!
            .addListener(_onTransitionVideoComplete);
        widget.transitionController!.play();
      }

      _videoController =
      await _preloadManager.getController('assets/seascreen.mp4');
      if (_videoController != null) {
        await _videoController!.seekTo(Duration.zero);
        await _videoController!.setLooping(true);
        await _videoController!.setPlaybackSpeed(0.8);
        await _videoController!.setVolume(0.0);
        await _videoController!.pause();
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Comprehensive initialization error: $e');
    }
  }

  void _toggleJellyfishSheet() {
    if (_isQuickSheetOpen) _toggleQuickSheet();
    if (_isSheetOpen) _hideSheet();
    if (_isJellyfishSheetOpen) {
      _jellyfishSheetAnimationController.reverse();
      _isJellyfishSheetOpen = false;
    } else {
      _jellyfishSheetAnimationController.forward(from: 0);
      _isJellyfishSheetOpen = true;
    }
    setState(() {});
  }

  void _summonJellyfish(String name) async {
    if (_jellyfishArtboards.length >= _maxJellyfish) {
      // 顯示提示對話框
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("提示"),
          content: Text("水母都遙遊在大海中了"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("確定"),
            ),
          ],
        ),
      );
      return;
    }

    try {
      // 載入 Rive 文件
      final data = await rootBundle.load('assets/jellyfish.riv');
      final file = RiveFile.import(data);

      // 從 Artboard 中獲取主要 Artboard
      final artboard = file.mainArtboard.instance();

      // 添加狀態機控制器
      StateMachineController? controller =
      StateMachineController.fromArtboard(artboard, 'State Machine 1');
      if (controller != null) {
        artboard.addController(controller);
      } else {
        print("無法找到狀態機控制器 'State Machine 1' 在 jellyfish.riv");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("無法載入水母動畫")),
        );
        return;
      }

      // 獲取位置
      double x, y;
      if (nextPositionIndex < predefinedPositions.length) {
        x = predefinedPositions[nextPositionIndex].dx - 100.w; // 調整為左上角坐標
        y = predefinedPositions[nextPositionIndex].dy - 100.h;
        nextPositionIndex++;
      } else {
        // 如果預設位置已用完，則隨機生成
        double screenWidth = MediaQuery.of(context).size.width;
        double screenHeight = MediaQuery.of(context).size.height;

        double jellyfishWidth = 200.w; // 水母寬度
        double jellyfishHeight = 200.h; // 水母高度

        double margin = 50.w; // 邊緣距離

        double minX = margin;
        double maxX = screenWidth - jellyfishWidth - margin;
        double minY = margin;
        double maxY = screenHeight - jellyfishHeight - margin;

        // 簡單的隨機分佈
        x = math.Random().nextDouble() * (maxX - minX) + minX;
        y = math.Random().nextDouble() * (maxY - minY) + minY;

        // 避免水母過於集中，可以檢查與現有水母的距離
        bool isTooClose = false;
        double minDistance = 150.w; // 最小距離

        for (var existing in _jellyfishArtboards) {
          double dx = existing.x - x;
          double dy = existing.y - y;
          double distance = math.sqrt(dx * dx + dy * dy);
          if (distance < minDistance) {
            isTooClose = true;
            break;
          }
        }

        if (isTooClose) {
          // 重新生成位置
          x = math.Random().nextDouble() * (maxX - minX) + minX;
          y = math.Random().nextDouble() * (maxY - minY) + minY;
          // 可以重複檢查，直到找到合適的位置
          // 這裡僅重新生成一次
        }
      }

      // 將新的 JellyfishInstance 添加到列表中
      setState(() {
        _jellyfishArtboards.add(JellyfishInstance(
          artboard: artboard,
          x: x,
          y: y,
          name: name.trim(), // 確保名稱正確設置
        ));
      });
    } catch (e) {
      print('載入 jellyfish.riv 錯誤: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("無法載入水母動畫")),
      );
    }
  }

  Widget _buildVideoDragTarget() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final insertCancelWidth = screenWidth * 0.15; // 15% 的寬度

    return Positioned.fill(
      child: DragTarget<String>(
        onWillAccept: (data) {
          return data == 'jellyfish';
        },
        onAccept: (data) async {
          if (_isInTopHalf) {
            // 放入區域
            if (_jellyfishArtboards.length >= _maxJellyfish) {
              // 顯示提示對話框
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("提示"),
                  content: Text("水母都遙遊在大海中了"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text("確定"),
                    ),
                  ],
                ),
              );
            } else {
              // 放入區域
              String? name = await _showNameDialog();
              if (name != null && name.trim().isNotEmpty) {
                _summonJellyfish(name.trim());
              }
            }
          } else {
            // 取消區域，不進行任何操作
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("取消放入水母")),
            );
          }
          setState(() {
            _isDragging = false;
            _isInTopHalf = false;
          });
        },
        onMove: (details) {
          final isInTop = details.offset.dy < screenHeight / 2;
          setState(() {
            _isDragging = true;
            _isInTopHalf = isInTop;
          });
        },
        onLeave: (data) {
          setState(() {
            _isDragging = false;
            _isInTopHalf = false;
          });
        },
        builder: (context, candidateData, rejectedData) {
          return Stack(
            children: [
              IgnorePointer(
                ignoring: true,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                  ),
                ),
              ),
              if (_isDragging && _currentDisplayedGreeting == null) ...[
                if (_isInTopHalf)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: screenHeight * 0.5, // 上半部 50%
                    child: Container(
                      color: Colors.green.withOpacity(0.5),
                      child: Center(
                        child: Text(
                          "放入",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: screenHeight * 0.5, // 下半部 50%
                    child: Container(
                      color: Colors.red.withOpacity(0.5),
                      child: Center(
                        child: Text(
                          "取消",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
              ],
            ],
          );
        },
      ),
    );
  }

  void _onTransitionVideoComplete() {
    if (widget.transitionController != null &&
        widget.transitionController!.value.position >=
            widget.transitionController!.value.duration) {
      print("Transition video completed.");
      Future.delayed(const Duration(milliseconds: 0), () {
        widget.transitionController!.removeListener(_onTransitionVideoComplete);
        widget.transitionController?.pause();
        widget.transitionController?.seekTo(Duration.zero);

        if (_videoController != null && _videoController!.value.isInitialized) {
          _videoController?.seekTo(Duration.zero);
          _videoController?.play();
          print("Background video is playing: ${_videoController!.value.isPlaying}");
        }

        setState(() {
          _canRenderContent = true;
          _isTransitionCompleted = true;
        });

        _showGreeting();
      });
    }
  }

  void _showSheet() {
    if (_isJellyfishSheetOpen) {
      // 當水母插頁開啟時，不開啟大插頁
      return;
    }

    if (_isQuickSheetOpen) _toggleQuickSheet();

    _sheetAnimationController.forward();
    _controllerAnimationController.forward();
    setState(() {
      _isSheetOpen = true;
    });
  }

  void _hideSheet() {
    _sheetAnimationController.reverse();
    _controllerAnimationController.reverse();
    setState(() {
      _isSheetOpen = false;
    });
  }

  void _toggleQuickSheet() {
    if (_isSheetOpen) {
      // 當大插頁開啟時，不允許開啟小插頁
      return;
    }

    if (_isQuickSheetOpen) {
      _quickSheetAnimationController.reverse();
      _isQuickSheetOpen = false;
    } else {
      _quickSheetAnimationController.forward(from: 0);
      _isQuickSheetOpen = true;
    }
    setState(() {});
  }

  // 命名確認對話框
  Future<String?> _showNameDialog() async {
    String? name;
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title:
          Text('為水母命名', style: TextStyle(color: Colors.black)),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
                hintText: '輸入水母名稱',
                hintStyle: TextStyle(color: Colors.grey)),
            onChanged: (value) {
              name = value;
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('取消',
                  style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                name = null;
              },
            ),
            TextButton(
              child: Text('確認',
                  style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    return name;
  }

  Future<void> _togglePlayPause() async {
    if (_isPlayingMusic) {
      // 暫停 BGM 和人聲音樂
      await pauseGlobalMusic();
      await _voiceAudioPlayer.pause();
      _rotateController.stop();
    } else {
      // 恢復 BGM 和人聲音樂
      await resumeGlobalMusic();
      await _voiceAudioPlayer.resume();
      _rotateController.repeat();
    }
    setState(() {
      _isPlayingMusic = !_isPlayingMusic;
      _isPausedIcon = !_isPausedIcon;
    });
  }

  // 初始化水平方向手勢偵測器
  Widget _buildHorizontalGestureDetector({required Widget child}) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 10 && !_isQuickSheetOpen) {
          // 左向右滑開啟小插頁
          _toggleQuickSheet();
        } else if (details.delta.dx < -10 && _isQuickSheetOpen) {
          // 右向左滑關閉小插頁
          _toggleQuickSheet();
        }
      },
      child: child,
    );
  }

  Widget _buildJellyfishOverlays() {
    if (_jellyfishArtboards.isEmpty) return SizedBox.shrink();
    return Stack(
      children: _jellyfishArtboards.map((instance) {
        return Positioned(
          left: instance.x,
          top: instance.y,
          width: 200.w, // 保持原寬度
          height: 200.h, // 保持原高度
          child: GestureDetector(
            onLongPress: () {
              // 彈出修改名稱對話框
              _showRenameDialog(instance);
            },
            onTap: () {
              // 顯示水母名稱
              _showJellyfishName(instance);
            },
            child: Rive(
              artboard: instance.artboard,
              fit: BoxFit.contain,
            ),
          ),
        );
      }).toList(),
    );
  }

  // 在 _MeditationScreenState 中新增方法
  Future<void> _showRenameDialog(JellyfishInstance instance) async {
    String? newName = instance.name;
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.4), // 降低背景透明度
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r), // 圓角
          ),
          title: Text(
            '修改水母名稱',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: '輸入新的水母名稱',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onChanged: (value) {
              newName = value;
            },
            controller: TextEditingController(text: instance.name),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                '取消',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                '確認',
                style: TextStyle(color: Colors.blue),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    if (newName != null && newName!.trim().isNotEmpty) {
      setState(() {
        instance.name = newName!.trim();
      });
    }
  }

  void _showJellyfishName(JellyfishInstance instance) {
    if (_isNameVisible) {
      // 如果已經有名稱顯示，先淡出當前名稱
      _nameAnimationController.reverse().then((_) {
        setState(() {
          _currentDisplayedName = "這是「${instance.name}」";
        });
        _nameAnimationController.forward();
      });
    } else {
      setState(() {
        _currentDisplayedName = "這是「${instance.name}」";
        _isNameVisible = true;
      });
      _nameAnimationController.forward();
    }

    // 設置定時器，在3秒後淡出
    Timer(Duration(seconds: 3), () {
      _nameAnimationController.reverse().then((_) {
        setState(() {
          _isNameVisible = false;
          _currentDisplayedName = null;
        });
      });
    });
  }

  Widget _buildScaledVideo() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return GestureDetector(
        onTap: () {
          if (_isQuickSheetOpen) {
            _toggleQuickSheet();
          }
        },
        child: Container(),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_isQuickSheetOpen) {
          _toggleQuickSheet();
        }
      },
      child: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final videoSize = _videoController!.value.size;
            final fit = BoxFit.cover;
            final fittedSizes =
            applyBoxFit(fit, videoSize, Size(constraints.maxWidth, constraints.maxHeight));
            final renderSize = fittedSizes.destination;
            final offset = Offset(
              (constraints.maxWidth - renderSize.width) / 2,
              (constraints.maxHeight - renderSize.height) / 2,
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
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),
                // 顯示所有水母
                _buildJellyfishOverlays(),
              ],
            );
          },
        ),
      ),
    );
  }

  // 保留 _buildScaledTransitionVideo 方法不變
  Widget _buildScaledTransitionVideo(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final videoSize = controller.value.size;
          final fit = BoxFit.cover;
          final fittedSizes =
          applyBoxFit(fit, videoSize, Size(constraints.maxWidth, constraints.maxHeight));
          final renderSize = fittedSizes.destination;
          final offset = Offset(
            (constraints.maxWidth - renderSize.width) / 2,
            (constraints.maxHeight - renderSize.height) / 2,
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

  Widget _buildPlaybackController(double screenWidth, double screenHeight) {
    final iconToShow = _isPausedIcon ? Icons.pause : Icons.play_arrow;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 10 && _isSheetOpen) {
          _hideSheet();
        }
      },
      child: Container(
        width: screenHeight * 0.2, // 設置為頁面高度的20%
        height: 70.h, // 減少容器高度
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(40.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h), // 減少垂直內邊距
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _toggleQuickSheet,
              child: RotationTransition(
                turns: _rotateController,
                child: ClipOval( // 使用 ClipOval 確保圓形
                  child: Image.asset(
                    _currentBGMImage,
                    width: 40.w,
                    height: 40.w,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SizedBox(width: 5.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min, // 設置為主軸最小尺寸
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center, // 改為居中對齊
                children: [
                  Text(
                    bgmMap[_currentBGMImage] ?? "未知曲目",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp, // 減小字體大小
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center, // 文字居中
                  ),
                  SizedBox(height: 3.h), // 減少間距
                  Stack(
                    alignment: Alignment.centerLeft, // 調整對齊方式
                    children: [
                      Container(
                        height: 5.h, // 控制進度條的高度
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2.5.r),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.6 * _voiceProgressPercent, // 根據進度調整寬度
                            decoration: BoxDecoration(
                              color: Colors.blueAccent, // 您可以根據需要更改顏色
                              borderRadius: BorderRadius.circular(2.5.r),
                            ),
                          ),
                        ),
                      ),
                      // 音量滑桿
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 0, // 隱藏滑軌
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 12.r),
                        ),
                        child: Slider(
                          value: _sliderValue,
                          min: 0,
                          max: 100,
                          activeColor: Colors.transparent, // 透明以顯示自定義進度條
                          inactiveColor: Colors.transparent,
                          label: _sliderValue.toStringAsFixed(0),
                          onChangeStart: (value) {
                            setState(() {
                              _isSliderDragging = true;
                            });
                          },
                          onChangeEnd: (value) {
                            setState(() {
                              _isSliderDragging = false;
                            });
                          },
                          onChanged: (double value) {
                            setState(() {
                              _sliderValue = value;
                            });
                            setGlobalMusicVolume(_sliderValue / 100.0);
                          },
                        ),
                      ),
                      if (_isSliderDragging)
                        Positioned(
                          right: 5.w, // 減少滑桿旁的右側位置
                          child: Text(
                            "${_sliderValue.toInt()}%",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp, // 減小字體大小
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 5.w),
            CustomIconButton(
              icon: iconToShow,
              onPressed: _togglePlayPause,
              isActive: false,
              scaleFactor: 1.0,
              isDarkMode: true,
              baseButtonSize: 40.w,
              baseIconSize: 30.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJellyfishSheet() {
    double height = MediaQuery.of(context).size.height * 0.5; // 確保高度為50%
    return AnimatedBuilder(
      animation: _jellyfishSheetAnimationController,
      builder: (context, child) {
        final offset = Tween<double>(begin: height, end: 0.0).animate(
            CurvedAnimation(
                parent: _jellyfishSheetAnimationController,
                curve: Curves.easeInOut))
            .value;
        return Stack(
          children: [
            // 當插頁開啟時，添加一個透明背景來捕捉點擊事件
            if (_isJellyfishSheetOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    _toggleJellyfishSheet(); // 點擊外部區域收回插頁
                  },
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -offset, // 從螢幕下方往上移動
              height: height, // 確保高度為50%
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy > 10) {
                    _toggleJellyfishSheet();
                  }
                },
                child: JellyfishSheet(
                  onSummon: (name) {
                    _summonJellyfish(name);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalMargin = 0.05.sw;
    final controllerHeight = 80.h;
    final sheetHeight = screenHeight - (controllerHeight + 0.05.sh);
    double gap = 0.03.sh;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildHorizontalGestureDetector(
        child: GestureDetector(
          onVerticalDragUpdate: _handleSwipe,
          onTap: () {
            if (_isQuickSheetOpen) _toggleQuickSheet();
          },
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // 背景影片
                      if (_canRenderContent) _buildScaledVideo(),
                      if (widget.transitionController != null &&
                          widget.transitionController!.value.isInitialized &&
                          widget.transitionController!.value.isPlaying)
                        Opacity(
                          opacity: 1.0,
                          child: _buildScaledTransitionVideo(
                              widget.transitionController),
                        ),

                      // 問候語顯示（與水母名稱相同位置）
                      if (_isGreetingVisible && _currentDisplayedGreeting != null)
                        Positioned(
                          top: screenHeight * 0.35.h, // 使用百分比定位，稍微偏上
                          left: 0,
                          right: 0,
                          child: FadeTransition(
                            opacity: _greetingOpacity,
                            child: Center(
                              child: Text(
                                _currentDisplayedGreeting!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20.sp, // 調小字體
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center, // 置中顯示
                              ),
                            ),
                          ),
                        ),

                      if (_isNameVisible && _currentDisplayedName != null)
                        Positioned(
                          top: 100.h, // 與問候語相同位置
                          left: 0,
                          right: 0,
                          child: FadeTransition(
                            opacity: _nameOpacity,
                            child: Center(
                              child: Text(
                                _currentDisplayedName!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 大插頁
                      if (_isTransitionCompleted)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          left: 0,
                          right: 0,
                          bottom: _isSheetOpen
                              ? 0
                              : -0.75.sh,
                          height: 0.75.sh,
                          child: Container(
                            color: Colors.black.withOpacity(0.1),
                            child: MeditationSelectorSheet(
                              onApply: _applyMeditationSettings,
                            ),
                          ),
                        ),

                      // 播放控制器（僅當大插頁未開啟且水母插頁未開啟）
                      if (_isTransitionCompleted && !_isJellyfishSheetOpen)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          left: horizontalMargin,
                          right: horizontalMargin,
                          top: _isSheetOpen
                              ? 0.8.sh - (0.7.sh)
                              : 0.8.sh,
                          height: 80.h,
                          child: !_isJellyfishSheetOpen
                              ? _buildPlaybackController(
                              screenWidth, screenHeight)
                              : SizedBox.shrink(), // 隱藏音樂控制器
                        ),

                      // 小插頁（Quick Sheet）僅當大插頁未開啟時顯示
                      if (!_isSheetOpen)
                        AnimatedBuilder(
                          animation: _quickSheetAnimationController,
                          builder: (context, child) {
                            final quickSheetWidth = screenWidth;
                            final quickSheetOffset = Tween<double>(
                                begin: -quickSheetWidth, end: 0.0)
                                .animate(CurvedAnimation(
                                parent: _quickSheetAnimationController,
                                curve: Curves.easeInOut))
                                .value;

                            return Positioned(
                              top: (0.8.sh) - 80.h - gap,
                              left: quickSheetOffset + horizontalMargin,
                              width: screenWidth - (horizontalMargin * 2),
                              height: 80.h,
                              child: QuickBGMSelectorSheet(
                                onSelectBGM: (selectedBGM) {
                                  _updateBGMImage(selectedBGM);
                                },
                              ),
                            );
                          },
                        ),

                      // 返回主頁面和水母按鈕
                      if (_canRenderContent && _isTransitionCompleted)
                        Positioned(
                          top: 50.h, // 根據需要調整
                          left: 25.w, // 根據需要調整
                          right: 25.w, // 根據需要調整
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (!_isSheetOpen) // 當大插頁未開啟時顯示房子圖示
                                GestureDetector(
                                  onTap: () async {
                                    // 返回主頁的邏輯
                                    final preloadManager = VideoPreloadManager();
                                    bool reverseVideoLoaded = preloadManager
                                        .hasController('assets/sea_reverse.mp4') &&
                                        preloadManager
                                            .isVideoLoaded('assets/sea_reverse.mp4');

                                    if (!reverseVideoLoaded) {
                                      await preloadManager.lazyLoadPageVideos('radio');
                                    }

                                    VideoPlayerController? reverseTransitionController =
                                    await preloadManager.getController('assets/sea_reverse.mp4');

                                    if (reverseTransitionController != null) {
                                      await reverseTransitionController.seekTo(Duration.zero);
                                      await reverseTransitionController.pause();
                                      preloadManager.reverseTransitionController =
                                          reverseTransitionController;
                                      Navigator.of(context).pop();
                                    } else {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(5.w), // 調整內邊距
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle, // 保留圓形形狀以便添加陰影
                                      boxShadow: [ // 添加與水母圖示相同的陰影設定
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 12.r,
                                          spreadRadius: 2.r,
                                          offset: Offset(0, 4.h),
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.1),
                                          blurRadius: 15.r,
                                          spreadRadius: -5.r,
                                          offset: Offset(0, -5.h),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.home,
                                      color: Colors.white,
                                      size: 20.sp, // 調整圖示大小
                                    ),
                                  ),
                                ),
                              if (!_isSheetOpen) // 當大插頁未開啟時顯示水母圖示
                                GestureDetector( // 使用 GestureDetector 來顯示圖片
                                  onTap: () {
                                    if (_isQuickSheetOpen) _toggleQuickSheet();
                                    if (_isSheetOpen) _hideSheet();
                                    // 點擊水母圖示顯示水母插頁
                                    _toggleJellyfishSheet();
                                  },
                                  child: Container(
                                    width: 30.w,
                                    height: 30.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: AssetImage('assets/jellyfish_icon.png'), // 使用預加載好的圖示
                                        fit: BoxFit.cover,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 12.r,
                                          spreadRadius: 2.r,
                                          offset: Offset(0, 4.h),
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.1),
                                          blurRadius: 15.r,
                                          spreadRadius: -5.r,
                                          offset: Offset(0, -5.h),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              // 水母插頁（Jellyfish Sheet）
              _buildJellyfishSheet(),

              // 添加全局 DragTarget（視頻區域）
              _buildVideoDragTarget(),
            ],
          ),
        ),
      ),
    );
  }

  // 水平方向手勢偵測器處理
  void _handleSwipe(DragUpdateDetails details) {
    if (_isJellyfishSheetOpen) {
      // 當水母插頁開啟時，不允許開啟大插頁
      return;
    }

    if (!_isSheetOpen && details.delta.dy < -10) {
      _showSheet();
    } else if (_isSheetOpen && details.delta.dy > 10) {
      _hideSheet();
    }
  }

  void _updateBGMImage(String newImage) {
    setState(() {
      _currentBGMImage = newImage;
      _currentSongName = bgmMap[_currentBGMImage] ?? "未知曲目";
    });
    playGlobalMusic(bgmAudioMap[_currentBGMImage]!); // 確保 bgmMap 中的值是相對路徑，如 'bgm/morning_way.mp3'
    setGlobalMusicVolume(_sliderValue / 100.0);
    _isPlayingMusic = true;
    _rotateController.repeat();
    _isPausedIcon = true;
    if (_isQuickSheetOpen) _toggleQuickSheet();
  }

// 播放人聲音樂的方法
  void _playVoiceMusic(MeditationMode mode, MeditationDifficulty difficulty) async {
    String voicePath = getVoiceAudioPath(mode, difficulty);
    await _voiceAudioPlayer.stop(); // 停止之前的人聲音樂
    await _voiceAudioPlayer.setSource(AssetSource(voicePath)); // 不添加 'assets/' 前綴
    await _voiceAudioPlayer.setReleaseMode(ReleaseMode.loop); // 根據需要設定循環模式
    await _voiceAudioPlayer.play(AssetSource(voicePath));
  }

  // 定義應用選擇的方法
  void _applyMeditationSettings(MeditationSettings settings) {
    // 更新 BGM 圖片和播放
    _updateBGMImage(settings.bgmImage);

    // 播放人聲音樂
    _playVoiceMusic(settings.mode, settings.difficulty);
  }

// 定義模式和難度的映射
  Map<MeditationDifficulty, int> difficultyToLevel = {
    MeditationDifficulty.basic: 5,
    MeditationDifficulty.intermediate: 10,
    MeditationDifficulty.zenMaster: 15,
  };

// 方法來獲取人聲音樂路徑
  String getVoiceAudioPath(MeditationMode mode, MeditationDifficulty difficulty) {
    String modeString = mode.toString().split('.').last.toLowerCase(); // sleep, vision, emotion, myself
    int level = difficultyToLevel[difficulty]!; // 使用索引方式訪問 Map，確保鍵存在
    return '$modeString/${modeString}$level.mp3'; // 不包含 'assets/' 前綴
  }

  // 定義模式和難度的映射
  Map<MeditationMode, String> modeToString = {
    MeditationMode.sleep: "幫助睡眠",
    MeditationMode.myself: "自我覺察",
    MeditationMode.vision: "視覺引導",
    MeditationMode.emotion: "情緒調節",
  };
}

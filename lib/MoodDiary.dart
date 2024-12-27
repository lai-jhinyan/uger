import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive; // 使用別名
import 'package:video_player/video_player.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'VideoPreloadManager.dart';
import 'SaveDiaryScreen.dart'; // 新增的保存日記頁面

class MoodDiaryScreen extends StatefulWidget {
  final VideoPlayerController? transitionController;

  const MoodDiaryScreen({
    Key? key,
    this.transitionController,
  }) : super(key: key);

  @override
  _MoodDiaryScreenState createState() => _MoodDiaryScreenState();
}

class _MoodDiaryScreenState extends State<MoodDiaryScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  late VideoPreloadManager _preloadManager;
  bool _canRenderContent = false;

  // 日記輸入控制器，分別對應早晨和晚上
  final Map<String, TextEditingController> _diaryControllers = {
    'Morning': TextEditingController(),
    'Evening': TextEditingController(),
  };

  // 當前選中的情緒，分別對應早晨和晚上
  final Map<String, String?> _selectedMoods = {
    'Morning': null,
    'Evening': null,
  };

  // 當前選中的圖片，分別對應早晨和晚上
  final Map<String, File?> _selectedImages = {
    'Morning': null,
    'Evening': null,
  };

  // 情緒圖標列表，使用自定義圖片和更新顏色
  final List<Map<String, dynamic>> _moodIcons = [
    {'image': 'assets/happy.png', 'label': '愉快', 'color': Colors.yellow},
    {'image': 'assets/cry.png', 'label': '悲傷', 'color': Colors.blue},
    {'image': 'assets/angry.png', 'label': '憤怒', 'color': Colors.red},
    {'image': 'assets/sad.png', 'label': '低落', 'color': Colors.green},
  ];

  // 時段選擇：早晨和晚上
  final List<String> _timePeriods = ['Morning', 'Evening'];
  String _selectedPeriod = 'Morning'; // 默認選擇早晨

  // 選擇的日期，預設為今天
  DateTime _selectedDate = DateTime.now();

  bool _isExiting = false; // 新增的狀態變數

  // 保存日記列表
  List<Map<String, dynamic>> _savedDiaries = [];

  // 退場過渡視頻控制器
  VideoPlayerController? _reverseTransitionController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preloadManager = VideoPreloadManager();
    _initializeAllVideoControllers();
    _loadSavedDiaries(); // 加載已保存的日記
  }

  // 初始化所有視頻控制器
  Future<void> _initializeAllVideoControllers() async {
    try {
      bool resourcesLoaded = _preloadManager.hasController('assets/cloudscreen.mp4') &&
          _preloadManager.isVideoLoaded('assets/cloudscreen.mp4');

      if (!resourcesLoaded) {
        await _preloadManager.releaseUnusedVideos();
        await _preloadManager.lazyLoadPageVideos('calendar');
      }

      if (widget.transitionController != null) {
        await widget.transitionController!.seekTo(Duration.zero);
        widget.transitionController!.setLooping(false);
        widget.transitionController!.addListener(_onTransitionVideoComplete);
        widget.transitionController!.play();
      }

      _videoController =
      await _preloadManager.getController('assets/cloudscreen.mp4');

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

  void _onTransitionVideoComplete() {
    if (widget.transitionController != null &&
        widget.transitionController!.value.position >=
            widget.transitionController!.value.duration) {
      widget.transitionController!.removeListener(_onTransitionVideoComplete);
      widget.transitionController?.pause();
      widget.transitionController?.seekTo(Duration.zero);

      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController?.seekTo(Duration.zero);
        _videoController?.play();
        print('Background video guaranteed start');
      }

      setState(() {
        _canRenderContent = true;
      });
    }
  }

  Widget _buildScaledVideo() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Container();
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
          final videoSize = _videoController!.value.size;
          final fit = BoxFit.cover;

          final fittedSizes = applyBoxFit(fit, videoSize, containerSize);
          final renderSize = fittedSizes.destination;

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
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScaledTransitionVideo(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
          final videoSize = controller.value.size;
          final fit = BoxFit.cover;
          final fittedSizes = applyBoxFit(fit, videoSize, containerSize);
          final renderSize = fittedSizes.destination;

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

  // 保存日記方法，分別處理早晨和晚上
  void _saveDiary(String period) async {
    final mood = _selectedMoods[period];
    final diary = _diaryControllers[period]?.text;
    final image = _selectedImages[period];

    if (mood != null && diary != null && diary.isNotEmpty) {
      // 構建日記條目
      Map<String, dynamic> diaryEntry = {
        'date': _selectedDate.toIso8601String(),
        'period': period,
        'mood': mood,
        'diary': diary,
        'imagePath': image != null ? image.path : null,
      };

      // 加載已保存的日記列表
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> savedDiaries = prefs.getStringList('savedDiaries') ?? [];

      // 將新的日記條目添加到列表中
      savedDiaries.add(json.encode(diaryEntry));

      // 保存回 shared_preferences
      await prefs.setStringList('savedDiaries', savedDiaries);

      // 清空當前圖片
      setState(() {
        _selectedImages[period] = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$period 的日記已保存')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請選擇$period 的情緒並輸入日記內容')),
      );
    }
  }

  // 加載已保存的日記
  Future<void> _loadSavedDiaries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedDiaries = prefs.getStringList('savedDiaries') ?? [];

    setState(() {
      _savedDiaries = savedDiaries
          .map((diary) => json.decode(diary) as Map<String, dynamic>)
          .toList();
    });
  }

  // 日記輸入框，分別對應早晨和晚上
  Widget _buildDiaryInput(String period) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _diaryControllers[period],
          maxLines: 4,
          maxLength: 300,
          style: TextStyle(color: Colors.white, fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: '$period 的日記內容...',
            hintStyle: TextStyle(color: Colors.white54, fontSize: 14.sp),
            filled: true,
            fillColor: Colors.white30.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
              borderSide: BorderSide(color: Colors.white30),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        // 圖片解析按鈕
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(period),
              icon: Icon(Icons.photo_library, color: Colors.purple[300], size: 24.sp),
              label: Text('圖片解析', style: TextStyle(color: Colors.purple[300], fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white70,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.r),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            // 顯示已選擇的圖片
            _selectedImages[period] != null
                ? Expanded(
              child: Container(
                height: 100.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.r),
                  image: DecorationImage(
                    image: FileImage(_selectedImages[period]!),
                    fit: BoxFit.contain, // 保持圖片完整顯示
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImages[period] = null;
                          });
                        },
                        child: CircleAvatar(
                          radius: 12.r,
                          backgroundColor: Colors.red,
                          child: Icon(
                            Icons.close,
                            size: 14.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
                : Container(),
          ],
        ),
        SizedBox(height: 10.h),
        // 查看保存日記按鈕
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _openSaveDiaryScreen,
            child: Text(
              '查看保存的日記',
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
          ),
        ),
      ],
    );
  }

  // 打開保存日記頁面
  void _openSaveDiaryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaveDiaryScreen(savedDiaries: _savedDiaries),
      ),
    ).then((_) {
      // 當返回時，重新加載已保存的日記
      _loadSavedDiaries();
    });
  }

  // 修改圖片選擇方法
  Future<void> _pickImage(String period, {ImageSource? source}) async {
    if (source == null) {
      // 顯示選擇來源的對話框
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library, color: Colors.purple[300]),
                  title: Text('從圖庫選擇'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(period, source: ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Colors.purple[300]),
                  title: Text('拍照'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(period, source: ImageSource.camera);
                  },
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImages[period] = File(pickedFile.path);
        });

        // 自動進行圖片解析，並覆蓋舊的文字
        await _processImageToText(period, File(pickedFile.path));
      }
    } catch (e) {
      print('Image picker error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('圖片獲取失敗')),
      );
    }
  }

  // 新增：圖片解析處理函數
  Future<void> _processImageToText(String period, File imageFile) async {
    try {
      // 顯示加載對話框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: Container(
              width: 200.w,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20.h),
                  Text('正在解析圖片...', style: TextStyle(fontSize: 16.sp)),
                ],
              ),
            ),
          );
        },
      );

      // 1. 上傳圖片到 /upload 端點
      String uploadUrl = 'https://5e18-2407-4d00-3c01-92f8-544d-9f4c-180e-3b6f.ngrok-free.app/upload'; // 替換為您的後端上傳端點

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      var uploadResponse = await request.send();

      if (uploadResponse.statusCode != 200) {
        Navigator.of(context).pop(); // 關閉加載對話框
        var responseBody = await uploadResponse.stream.bytesToString();
        throw Exception('圖片上傳失敗，狀態碼: ${uploadResponse.statusCode}, 錯誤信息: $responseBody');
      }

      var uploadResponseBody = await uploadResponse.stream.bytesToString();
      var uploadJson = json.decode(uploadResponseBody);

      if (uploadJson['filename'] == null) {
        Navigator.of(context).pop(); // 關閉加載對話框
        throw Exception('後端未返回文件名，回應內容: $uploadResponseBody');
      }

      String uploadedFilename = uploadJson['filename'];
      print('上傳成功，文件名：$uploadedFilename');

      // 2. 調用 /analyze 端點進行圖片解析
      String analyzeUrl = 'https://5e18-2407-4d00-3c01-92f8-544d-9f4c-180e-3b6f.ngrok-free.app/analyze'; // 替換為您的後端分析端點

      var analyzeResponse = await http.post(
        Uri.parse(analyzeUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'filename': uploadedFilename}),
      );

      if (analyzeResponse.statusCode != 200) {
        Navigator.of(context).pop(); // 關閉加載對話框
        var responseBody = analyzeResponse.body;
        throw Exception('圖片解析失敗，狀態碼: ${analyzeResponse.statusCode}, 錯誤信息: $responseBody');
      }

      var analyzeJson = json.decode(analyzeResponse.body);

      if (analyzeJson['result'] == null) {
        Navigator.of(context).pop(); // 關閉加載對話框
        throw Exception('後端未返回解析結果，回應內容: ${analyzeResponse.body}');
      }

      String parsedText;

      if (analyzeJson['result'] is String) {
        parsedText = analyzeJson['result'];
      } else if (analyzeJson['result'] is List) {
        // 如果 result 是列表，將其轉換為單一字符串
        parsedText = (analyzeJson['result'] as List).join(' ');
      } else {
        throw Exception('未知的 result 類型');
      }

      print('解析結果：$parsedText');

      // 更新日記內容，覆蓋舊的文字
      setState(() {
        _diaryControllers[period]?.text = parsedText;
      });

      Navigator.of(context).pop(); // 關閉加載對話框

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('圖片解析完成')),
      );
    } catch (e) {
      print('圖片解析錯誤：$e');
      Navigator.of(context).pop(); // 確保加載對話框被關閉
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('圖片解析失敗：$e')),
      );
    }
  }

  // 情緒選擇方法，分別對應早晨和晚上
  void _selectMood(String period, String mood) {
    setState(() {
      _selectedMoods[period] = mood;
    });
  }

  // 構建情緒選擇器，分別對應早晨和晚上
  Widget _buildMoodSelector(String period) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 四種情緒
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 1,
      ),
      itemCount: _moodIcons.length,
      itemBuilder: (context, index) {
        final mood = _moodIcons[index];
        final isSelected = _selectedMoods[period] == mood['label'];
        return GestureDetector(
          onTap: () => _selectMood(period, mood['label']),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? (mood['color'] as Color).withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(
                color: isSelected
                    ? mood['color'] as Color
                    : Colors.white,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: (mood['color'] as Color).withOpacity(0.5),
                  spreadRadius: 2.r,
                  blurRadius: 5.r,
                  offset: Offset(0, 3.h),
                ),
              ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  mood['image'],
                  width: 40.w,
                  height: 40.h,
                ),
                SizedBox(height: 5.h),
                Text(
                  mood['label'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 打開日曆的彈出窗口
  void _openCalendar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.r)),
      ),
      builder: (context) {
        return GestureDetector(
          onTap: () {}, // 防止點擊彈出窗口內部時觸發收起
          child: Container(
            padding: EdgeInsets.all(20.w),
            child: TableCalendar(
              firstDay: DateTime(2000),
              lastDay: DateTime(2100),
              focusedDay: _selectedDate,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDate, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = selectedDay;
                  // 加載選定日期的日記和情緒
                  // 例如，從數據庫中讀取數據並設置到 _diaryControllers 和 _selectedMoods
                  _loadSavedDiaries();
                });
                Navigator.pop(context); // 關閉日曆
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Colors.white70,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: TextStyle(color: Colors.purple[300]),
                selectedTextStyle: TextStyle(color: Colors.purple[300]),
                todayTextStyle: TextStyle(color: Colors.purple[300]),
                outsideDecoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                holidayTextStyle: TextStyle(color: Colors.redAccent),
                weekendTextStyle: TextStyle(color: Colors.purpleAccent),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Colors.purple[300],
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white70),
                weekendStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        );
      },
    );
  }

  // 隱藏鍵盤
  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  void didPopNext() {
    final preloadManager = VideoPreloadManager();
    if (preloadManager.reverseTransitionController != null) {
      preloadManager.reverseTransitionController!.addListener(_onReverseTransitionComplete);
      preloadManager.reverseTransitionController!.play();
    }
    _initializeAllVideoControllers().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onReverseTransitionComplete() {
    final preloadManager = VideoPreloadManager();
    if (preloadManager.reverseTransitionController != null &&
        !preloadManager.reverseTransitionController!.value.isPlaying) {
      preloadManager.reverseTransitionController!.removeListener(_onReverseTransitionComplete);
      preloadManager.releaseVideo('assets/card_reverse.mp4');
      preloadManager.reverseTransitionController = null;

      if (mounted) { // 檢查是否仍然掛載
        // 播放背景影片或恢復該頁狀態
        _videoController?.play();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _diaryControllers.values.forEach((controller) => controller.dispose());
    // 不要釋放 _videoController 和 _reverseTransitionController
    // _videoController?.dispose();
    // _reverseTransitionController?.dispose();
    super.dispose();
  }

  // 保存日記頁面外的視圖構建
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // 確保頁面會隨鍵盤調整
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: _hideKeyboard, // 點擊鍵盤以外的區域隱藏鍵盤
        child: Stack(
          children: [
            // 背景視頻
            if (_canRenderContent) _buildScaledVideo(),

            // 過渡視頻層
            if (widget.transitionController != null &&
                widget.transitionController!.value.isInitialized &&
                widget.transitionController!.value.isPlaying)
              Opacity(
                opacity: 1.0,
                child: _buildScaledTransitionVideo(widget.transitionController),
              ),

            if (_canRenderContent)
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 返回按鈕，改為播放退場過渡視頻
                        GestureDetector(
                          onTap: () async {
                            final preloadManager = VideoPreloadManager();
                            bool reverseVideoLoaded = preloadManager.hasController('assets/cloud_reverse.mp4') &&
                                preloadManager.isVideoLoaded('assets/cloud_reverse.mp4');

                            if (!reverseVideoLoaded) {
                              await preloadManager.lazyLoadPageVideos('tarodcard');
                              // 'tarodcard'是上一範例中預載頁面的名稱依據您的實際需求調整
                              // 確保已載入 reverse transition 影片
                            }

                            VideoPlayerController? reverseTransitionController =
                            await preloadManager.getController('assets/cloud_reverse.mp4');

                            if (reverseTransitionController != null) {
                              await reverseTransitionController.seekTo(Duration.zero);
                              await reverseTransitionController.pause();
                              preloadManager.reverseTransitionController = reverseTransitionController;
                              Navigator.of(context).pop();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Container(
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 24.sp,
                            ),
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // 日期選擇按鈕
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.calendar_today, color: Colors.white70, size: 24.sp),
                              onPressed: _openCalendar,
                            ),
                          ],
                        ),

                        SizedBox(height: 20.h),

                        // 時段切換
                        ToggleButtons(
                          isSelected: _timePeriods.map((period) => _selectedPeriod == period).toList(),
                          borderRadius: BorderRadius.circular(15.r),
                          selectedColor: Colors.purple[300],
                          fillColor: Colors.white70,
                          color: Colors.white,
                          onPressed: (index) {
                            setState(() {
                              _selectedPeriod = _timePeriods[index];
                            });

                            // 當切換時，根據選擇的時段和日期加載相應的日記
                            _loadSavedDiaries();
                          },
                          children: _timePeriods.map((period) {
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: Text(
                                period,
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        ),

                        SizedBox(height: 30.h),

                        // 當前選擇的時段的情緒選擇
                        Text(
                          '${_selectedPeriod} 的心情',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        _buildMoodSelector(_selectedPeriod),

                        SizedBox(height: 20.h),

                        // 當前選擇的時段的日記輸入
                        Text(
                          '${_selectedPeriod} 的日記',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        _buildDiaryInput(_selectedPeriod),

                        SizedBox(height: 20.h),

                        // 保存按鈕
                        ElevatedButton(
                          onPressed: () => _saveDiary(_selectedPeriod),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white70,
                            padding: EdgeInsets.symmetric(horizontal: 50.w, vertical: 15.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                          ),
                          child: Text(
                            '保存${_selectedPeriod} 日記',
                            style: TextStyle(color: Colors.purple[300], fontSize: 16.sp),
                          ),
                        ),

                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

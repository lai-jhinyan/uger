import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'VideoPreloadManager.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rive/rive.dart' as rive;
import 'package:video_player/video_player.dart';

import 'main.dart'; // 確保其中有定義 kRunWithoutMic

class AppSession {
  static bool hasPlayedHello = false;
}

class ChatPage extends StatefulWidget {
  final VideoPlayerController? transitionController;

  const ChatPage({Key? key, this.transitionController}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

enum CharacterState { Idle, Talking, Thinking }

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _messageScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final ScrollController _greetingScrollController = ScrollController();
  final ScrollController _errorScrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();

  Timer? _textAnimationTimer;

  int _textAnimationIndex = 0;
  int lineCount = 1;

  double _inputHeight = 90;
  double _inputWidth = 300;

  String _greetingText = '';
  String _responseText = '';
  String _errorMessageText = '';

  bool _isThinking = false;
  bool _showErrorMessage = false;
  bool _showGreeting = false;
  bool _isInputVisible = false;
  bool _isHistoryVisible = false;
  bool _controllersInitialized = false;
  bool _isDataLoadingSuccessful = false;
  bool _isListening = false;
  bool _isRecording = false;
  bool _hasEnteredIdle2 = false;

  bool _isAudioMode = false;
  bool _isResponseComplete = false;
  bool _isAudioPlaying = false;
  bool _isDisplayingResponse = false;
  bool _isAudioReady = false;
  bool responseAdded = false;

  bool _isInitialized = false;
  Timer? _recordingTimer;
  bool _isSpeechAvailable = false;
  late double scaledButtonWidth;
  late double scaledButtonHeight;
  late FastForwardAnimationController _fastForwardController;

  String _fullResponseText = '';

  bool _isTextDisplayingResponse = false;
  bool _isAudioDisplayingResponse = false;
  bool _isFastForwarded = false;

  late double _baseInputHeight;
  late double _maxInputHeight;

  late AnimationController _animationController;
  late Animation<double> _animation;

  List<ChatMessage> messages = [];

  final String _voiceEnabledUrl =
      'https://3f93-140-124-28-151.ngrok-free.app/generate_text';
  final String _voiceGenerateUrl =
      'https://3f93-140-124-28-151.ngrok-free.app/generate_audio/';
  final String _textOnlyUrl =
      'https://3f93-140-124-28-151.ngrok-free.app/generate_text';

  final double designWidth = 2160.0;
  final double designHeight = 3840.0;

  final double originalInputWidth = 1600.0;
  final double originalInputHeight = 500.0;
  final double originalButtonWidth = 380.0;
  final double originalButtonHeight = 380.0;

  // 將角色原始大小加大
  final double originalCharacterWidth = 2400.0;
  final double originalCharacterHeight = 2400.0;

  CharacterState _currentState = CharacterState.Idle;
  rive.Artboard? _riveArtboard;
  rive.StateMachineController? _stateMachineController;
  rive.SMINumber? _numberInput;

  final List<String> _greetings = [
    "$globalUserName你好呀！點擊下方的按鈕與我聊天吧\n(,,・ω・,,)",
    "很高興見到$globalUserName～ 使用下方按鈕讓我們來說說話吧！\n٩(｡・ω・｡)و",
    "今天過得如何呀～$globalUserName 請使用下方按鈕跟憂格說說吧！\n(๑•̀ㅂ•́)و✧",
  ];

  late VideoPreloadManager _preloadManager;
  VideoPlayerController? _backgroundVideoController;      // 亮色模式背景
  VideoPlayerController? _darkBackgroundVideoController;  // 暗色模式背景

  bool _canRenderContent = false;
  bool _isDarkMode = false;  // 新增深色模式狀態
  double _lightBgOpacity = 1.0; // 控制上層亮色背景的透明度

  @override
  void initState() {
    super.initState();

    _fastForwardController = FastForwardAnimationController(
      vsync: this,
      onAnimationComplete: () {
        _scrollToBottom(isFastForward: true);
        _skipAnimationOrStopAudio();
      },
    );

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);

    _controller.addListener(() => _onTextChanged(_controller.text));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _baseInputHeight = MediaQuery.of(context).size.height * 0.1;
          _maxInputHeight = MediaQuery.of(context).size.height * 0.35;
          _inputHeight = _baseInputHeight;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAnimation();
    });

    _initializeApp();

    _preloadManager = VideoPreloadManager();
    _initializeAllVideoControllers();
  }

  Future<void> _initializeAllVideoControllers() async {
    try {
      // 進入時先確保為亮色模式(因為進場動畫與退場動畫都是亮色版本)
      _setLightMode();

      bool resourcesLoaded =
          _preloadManager.hasController('assets/chatscreen.mp4') &&
              _preloadManager.isVideoLoaded('assets/chatscreen.mp4');

      bool darkResourcesLoaded =
          _preloadManager.hasController('assets/chatscreen_2.mp4') &&
              _preloadManager.isVideoLoaded('assets/chatscreen_2.mp4');

      if (!resourcesLoaded || !darkResourcesLoaded) {
        await _preloadManager.releaseUnusedVideos();
        await _preloadManager.lazyLoadPageVideos('chat');       // chatscreen.mp4
        await _preloadManager.lazyLoadPageVideos('chat_dark');  // chatscreen_2.mp4
      }

      if (widget.transitionController != null) {
        // 有過場動畫時，先播放過場動畫，暫不顯示聊天內容 (_canRenderContent = false)
        await widget.transitionController!.seekTo(Duration.zero);
        widget.transitionController!.setLooping(false);
        widget.transitionController!.addListener(_onTransitionVideoComplete);
        widget.transitionController!.play();
      } else {
        // 無過場動畫時，直接顯示
        setState(() {
          _canRenderContent = true;
        });
      }

      _backgroundVideoController =
      await _preloadManager.getController('assets/chatscreen.mp4');

      _darkBackgroundVideoController =
      await _preloadManager.getController('assets/chatscreen_2.mp4');

      if (_backgroundVideoController != null) {
        await _backgroundVideoController!.seekTo(Duration.zero);
        await _backgroundVideoController!.setLooping(true);
        await _backgroundVideoController!.setVolume(0.0);
        // 等過場動畫播完再play，先pause
        await _backgroundVideoController!.pause();
      }

      if (_darkBackgroundVideoController != null) {
        await _darkBackgroundVideoController!.seekTo(Duration.zero);
        await _darkBackgroundVideoController!.setLooping(true);
        await _darkBackgroundVideoController!.setVolume(0.0);
        // 深色背景預設暫停
        await _darkBackgroundVideoController!.pause();
      }
    } catch (e) {
      print('初始化影片控制器時發生錯誤: $e');
      setState(() {
        _canRenderContent = true;
      });
    }
  }


  void _onTransitionVideoComplete() {
    if (widget.transitionController != null &&
        widget.transitionController!.value.position >=
            widget.transitionController!.value.duration) {
      widget.transitionController!.removeListener(_onTransitionVideoComplete);
      widget.transitionController?.pause();
      widget.transitionController?.seekTo(Duration.zero);

      // 過場動畫播放結束，確保為亮色模式並開始播放亮色背景
      _setLightMode();
      if (_backgroundVideoController != null &&
          _backgroundVideoController!.value.isInitialized) {
        _backgroundVideoController?.seekTo(Duration.zero);
        _backgroundVideoController?.play();
      }

      setState(() {
        // 過場動畫完畢後才顯示聊天內容
        _canRenderContent = true;
      });
    }
  }

  Future<void> _initializeApp() async {
    await _initializeRiveAsync();
    await _initializeControllers();
    _checkFirstEntry();

    if (kRunWithoutMic) {
      setState(() {
        _isAudioMode = false;
      });
    } else {
    }
  }


  void _preloadAnimation() {
    setState(() {
      _isInputVisible = true;
    });
    Future.delayed(Duration(milliseconds: 35), () {
      if (mounted) {
        setState(() {
          _isInputVisible = false;
        });
      }
    });
  }

  void _checkFirstEntry() {
    if (!AppSession.hasPlayedHello) {
      _playInitialAnimation();
      AppSession.hasPlayedHello = true;
    } else {
      setState(() {
        _currentState = CharacterState.Idle;
        _setRiveState(CharacterState.Idle);
      });
    }
  }

  Future<void> _initializeControllers() async {
    final videoManager = VideoPreloadManager();
    await videoManager.lazyLoadPageVideos('chat', onLoadComplete: () {
      if (mounted) {
        setState(() {
          _controllersInitialized = true;
        });
      }
    });
  }

  Future<void> _initializeRiveAsync() async {
    try {
      await rive.RiveFile.initialize();
      final data = await rootBundle.load('assets/face.riv');
      final file = rive.RiveFile.import(data);
      final artboard = file.mainArtboard;

      var controller =
      rive.StateMachineController.fromArtboard(artboard, 'State Machine 1');
      if (controller != null) {
        artboard.addController(controller);
        _stateMachineController = controller;

        rive.SMINumber? numberInput;
        for (var input in controller.inputs) {
          if (input.name == 'number' && input is rive.SMINumber) {
            numberInput = input;
            break;
          }
        }

        if (numberInput != null) {
          _numberInput = numberInput;
        } else {
          var fallbackInput = controller.inputs.firstWhere(
                  (input) => input is rive.SMINumber,
              orElse: () => throw 'No SMINumber input found');
          if (fallbackInput is rive.SMINumber) {
            _numberInput = fallbackInput;
          }
        }

        setState(() {
          _riveArtboard = artboard;
        });
      } else {
        print('無法找到狀態機控制器 "State Machine 1"');
      }
    } catch (e) {
      print('初始化 Rive 文件時發生錯誤：$e');
    }
  }

  void _playInitialAnimation() {
    setState(() {
      _currentState = CharacterState.Talking;
      _setRiveState(CharacterState.Talking);
      _showGreeting = true;
      _showCustomGreeting();
    });

    Future.delayed(Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showGreeting = false;
          _currentState = CharacterState.Idle;
          _setRiveState(CharacterState.Idle);
        });
      }
    });
  }

  void _setRiveState(CharacterState state) {
    if (_numberInput != null && _numberInput is rive.SMINumber) {
      switch (state) {
        case CharacterState.Idle:
          (_numberInput as rive.SMINumber).value = 1.0;
          break;
        case CharacterState.Talking:
          (_numberInput as rive.SMINumber).value = 2.0;
          break;
        case CharacterState.Thinking:
          (_numberInput as rive.SMINumber).value = 3.0;
          break;
      }
    }
  }

  void _changeState(CharacterState newState) {
    if (_currentState == newState) return;
    setState(() {
      _currentState = newState;
      _setRiveState(newState);
    });
  }

  void _showCustomGreeting() {
    final random = Random();
    _greetingText = _greetings[random.nextInt(_greetings.length)];
  }

  void _onTextChanged(String text) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(fontSize: 16.0, color: Colors.black.withOpacity(0.5)),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    textPainter.layout(maxWidth: _inputWidth * 7 / 8);

    final newHeight =
    (textPainter.height + 32.0).clamp(_baseInputHeight, _maxInputHeight);

    if (newHeight != _inputHeight) {
      setState(() {
        _inputHeight = newHeight;
      });
    }
  }

  void _showResponseInHistory(String responseText) {
    setState(() {
      messages.add(ChatMessage(text: responseText, isUser: false));
    });
  }

  void _toggleVoiceFeature() {
    if (kRunWithoutMic) {
      setState(() {
        _isAudioMode = false;
      });
      return;
    }

    setState(() {
      _isAudioMode = !_isAudioMode;
      _isFastForwarded = false;

      if (!_isAudioMode) {
        if (_audioPlayer.playing) {
          _audioPlayer.stop();
        }
        _isAudioPlaying = false;
        _isAudioDisplayingResponse = false;
      } else {
        _isTextDisplayingResponse = false;
        _isResponseComplete = false;
      }
    });
  }

  // 切換至亮色模式，確保亮色背景播放（進出場動畫都是亮色版）
  void _setLightMode() {
    if (_isDarkMode) {
      setState(() {
        _isDarkMode = false;
        _lightBgOpacity = 1.0;
      });

      _darkBackgroundVideoController?.pause();
      if (_backgroundVideoController != null &&
          _backgroundVideoController!.value.isInitialized) {
        _backgroundVideoController?.seekTo(Duration.zero);
        _backgroundVideoController?.play();
      }
    }
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      _lightBgOpacity = _isDarkMode ? 0.0 : 1.0;
    });

    if (_isDarkMode) {
      // 暗色模式下：暫停亮色背景，播放深色背景
      _backgroundVideoController?.pause();
      if (_darkBackgroundVideoController != null &&
          _darkBackgroundVideoController!.value.isInitialized) {
        _darkBackgroundVideoController?.seekTo(Duration.zero);
        _darkBackgroundVideoController?.play();
      }
    } else {
      // 亮色模式下：暫停深色背景，播放亮色背景
      _darkBackgroundVideoController?.pause();
      if (_backgroundVideoController != null &&
          _backgroundVideoController!.value.isInitialized) {
        _backgroundVideoController?.seekTo(Duration.zero);
        _backgroundVideoController?.play();
      }
    }
  }

  Future<void> sendMessage() async {
    final String message = _controller.text.trim();
    if (message.isEmpty) return;

    _changeState(CharacterState.Thinking);
    setState(() {
      messages.add(ChatMessage(text: message, isUser: true));
      _inputHeight = _baseInputHeight;
      _isThinking = true;
      _responseText = '';
      _isInputVisible = false;
      _isResponseComplete = false;
      _isAudioDisplayingResponse = false;
      _isTextDisplayingResponse = false;
      _isFastForwarded = false;
    });
    _controller.clear();
    try {
      final response = await http
          .post(
        Uri.parse(!_isAudioMode ? _textOnlyUrl : _voiceEnabledUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final responseText =
            responseData['response_text']?.toString().trim() ?? 'No response';
        final responseId = responseData['response_id'];

        setState(() {
          _isThinking = false;
          _fullResponseText = responseText;
        });
        if (_isAudioMode) {
          await generateAndPlayAudio(responseId, responseText);
        } else {
          _responseText = responseText;
          _showResponseInHistory(responseText);
          _startResponseSequence(responseText, responseId);
        }
      } else {
        _handleErrorResponse('Error: ${response.statusCode}');
      }
    } catch (e) {
      _handleErrorResponse('Error: ${e.toString()}');
    }
  }

  void _startResponseSequence(String responseText, String responseId) {
    if (_isAudioMode) {
      generateAndPlayAudio(responseId, responseText);
    } else {
      _changeState(CharacterState.Talking);
      _animateTextDisplay(responseText);
    }
  }

  void _animateTextDisplay(String text) {
    int currentIndex = 0;
    const duration = Duration(milliseconds: 150);
    _textAnimationTimer?.cancel();

    setState(() {
      _isTextDisplayingResponse = true;
      _responseText = '';
      _fullResponseText = text;
      _isFastForwarded = false;
    });

    _textAnimationTimer = Timer.periodic(duration, (timer) {
      if (currentIndex < text.length) {
        setState(() {
          _responseText = text.substring(0, currentIndex + 1);
        });
        currentIndex++;
        if (_isAtBottom()) {
          _scrollToBottom();
        }
      } else {
        timer.cancel();
        setState(() {
          _isTextDisplayingResponse = false;
          _isResponseComplete = true;
        });
        _changeState(CharacterState.Idle);
      }
    });
  }

  bool _isAtBottom() {
    return _messageScrollController.hasClients &&
        _messageScrollController.position.pixels >=
            _messageScrollController.position.maxScrollExtent - 50;
  }

  void _handleErrorResponse(String errorMessage) {
    final String displayMessage = "抱歉，生成文字遇到問題，請重試。";

    setState(() {
      _isThinking = false;
      _responseText = '';
      _changeState(CharacterState.Idle);
      _showErrorOnScreen(displayMessage);
    });
  }

  void _handleAudioGenerationError(String errorMessage) {
    setState(() {
      _isThinking = false;
      _isAudioPlaying = false;
      _isResponseComplete = true;
      _changeState(CharacterState.Idle);
    });

    String displayMessage;
    if (errorMessage.contains('timed out')) {
      displayMessage = "抱歉，生成音頻超時。請稍候再試。";
    } else {
      displayMessage = "抱歉，生成音頻時遇到了問題。請重試。";
    }

    _showErrorOnScreen(displayMessage);
    _showResponseInHistory(displayMessage);
  }

  void _showErrorOnScreen(String text) {
    setState(() {
      _showErrorMessage = true;
      _errorMessageText = text;
    });

    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showErrorMessage = false;
        });
      }
    });
  }

  void _toggleInputVisibility() {
    setState(() {
      _isInputVisible = !_isInputVisible;
      if (_isInputVisible) {
        _focusNode.requestFocus();
        _changeState(CharacterState.Idle);
      } else {
        _focusNode.unfocus();
        if (!_isAudioPlaying && !_isTextDisplayingResponse) {
          _changeState(CharacterState.Idle);
        }
      }
    });
  }


  Future<void> generateAndPlayAudio(String responseId, String responseText,
      {double speed = 1.0}) async {
    if (kRunWithoutMic) {
      print('模擬器環境，音頻生成功能已停用');
      setState(() {
        _isThinking = false;
        _isAudioPlaying = false;
        _isResponseComplete = true;
        _responseText = responseText;
        _showResponseInHistory(responseText);
        _changeState(CharacterState.Idle);
      });
      return;
    }

    try {
      setState(() {
        _isThinking = true;
        _isAudioPlaying = true;
        _isResponseComplete = false;
        _responseText = '';
        _isTextDisplayingResponse = false;
        _isDisplayingResponse = false;
        _isFastForwarded = false;
      });

      final completer = Completer<Map<String, dynamic>>();
      final timer = Timer(Duration(seconds: 90), () {
        if (!completer.isCompleted) {
          completer.completeError('Audio generation timed out');
        }
      });

      http
          .post(
        Uri.parse('$_voiceGenerateUrl$responseId'),
        headers: {'Content-Type': 'application/json'},
      )
          .then((response) {
        if (!completer.isCompleted) {
          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            completer.complete(responseData);
          } else {
            completer.completeError('生成音頻失敗：${response.statusCode}');
          }
        }
      }).catchError((error) {
        if (!completer.isCompleted) {
          completer.completeError('生成音頻時出錯：$error');
        }
      });

      final generateData = await completer.future;
      timer.cancel();

      if (generateData['status'] == 'success') {
        final String audioUrl = generateData['file_url'] ?? '';
        if (audioUrl.isNotEmpty) {
          await _audioPlayer.setUrl(audioUrl);
          setState(() {
            _isThinking = false;
            _isAudioReady = true;
          });

          bool hasStartedPlaying = false;
          _audioPlayer.playingStream.listen((isPlaying) {
            if (isPlaying && !hasStartedPlaying) {
              if (_isFastForwarded) return;
              hasStartedPlaying = true;
              setState(() {
                _isAudioPlaying = true;
                _isResponseComplete = false;
                _isDisplayingResponse = true;
                _showResponseInHistory(responseText);
              });
              _changeState(CharacterState.Talking);
              _startTextDisplay(responseText);
            }
          });

          _audioPlayer.playerStateStream.listen((playerState) {
            if (playerState.processingState == ProcessingState.completed) {
              setState(() {
                _isAudioPlaying = false;
                _isResponseComplete = true;
                _isDisplayingResponse = false;
              });
              _changeState(CharacterState.Idle);
            }
          });
          await _audioPlayer.play();
        } else {
          throw ('音頻 URL 為空或無效');
        }
      } else {
        throw ('生成音頻失敗：${generateData['message']}');
      }
    } catch (e) {
      _handleAudioGenerationError(e.toString());
    }
  }

  void _startTextDisplay(String text) {
    _textAnimationIndex = 0;
    _textAnimationTimer?.cancel();

    setState(() {
      _fullResponseText = text;
      _responseText = '';
      _isDisplayingResponse = true;
      _isResponseComplete = false;
    });

    final characterDuration = _isAudioMode
        ? (_audioPlayer.duration?.inMilliseconds ?? 3000) / text.length
        : 50.0;

    _textAnimationTimer = Timer.periodic(
      Duration(milliseconds: characterDuration.round()),
          (timer) {
        if (_textAnimationIndex < text.length) {
          setState(() {
            _responseText = text.substring(0, _textAnimationIndex + 1);
          });
          _textAnimationIndex++;
          if (_isAudioMode && _isAtBottom()) {
            _scrollToBottom();
          }
        } else {
          timer.cancel();
          _completeTextDisplay();
        }
      },
    );
  }

  void _completeTextDisplay() {
    _textAnimationTimer?.cancel();
    setState(() {
      _responseText = _fullResponseText;
      _isDisplayingResponse = false;
      _isResponseComplete = true;
    });
    _changeState(CharacterState.Idle);
  }

  void _scrollToBottom({bool isFastForward = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageScrollController.hasClients) {
        final maxScrollExtent = _messageScrollController.position.maxScrollExtent;
        if (isFastForward) {
          _messageScrollController.jumpTo(maxScrollExtent);
        } else if (_messageScrollController.position.pixels >=
            maxScrollExtent - 50) {
          _messageScrollController.animateTo(
            maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _showHistory() {
    setState(() {
      _isHistoryVisible = !_isHistoryVisible;
      if (_isHistoryVisible) {
        _focusNode.unfocus();
      }
    });
  }

  void _skipTextAnimation() {
    _textAnimationTimer?.cancel();
    setState(() {
      _responseText = _fullResponseText;
      _isTextDisplayingResponse = false;
      _isResponseComplete = true;
      _isFastForwarded = true;
    });
    _changeState(CharacterState.Idle);
  }

  void _skipAudioPlayback() async {
    _textAnimationTimer?.cancel();
    setState(() {
      _responseText = _fullResponseText;
      _isAudioDisplayingResponse = false;
      _isTextDisplayingResponse = false;
      _isResponseComplete = true;
      _isAudioPlaying = false;
      _isFastForwarded = true;
    });

    if (_audioPlayer.playing) {
      await _audioPlayer.stop();
    }

    _changeState(CharacterState.Idle);
  }

  void _skipAnimationOrStopAudio() {
    if (_isAudioMode && _isAudioPlaying) {
      _skipAudioPlayback();
    } else if (!_isAudioMode && _isTextDisplayingResponse) {
      _skipTextAnimation();
    }
  }

  bool _isExiting = false;

// 退場時先切回亮色模式，再播放退場動畫，結束後 pop
  Future<void> _playExitAnimationAndPop() async {
    if (_isExiting) return;
    _isExiting = true; // 確保只執行一次

    // 先確保亮色模式
    _setLightMode();

    final preloadManager = VideoPreloadManager();
    bool reverseVideoLoaded =
        preloadManager.hasController('assets/chat_reverse.mp4') &&
            preloadManager.isVideoLoaded('assets/chat_reverse.mp4');

    if (!reverseVideoLoaded) {
      // 如果退場動畫還沒載入，先載入
      await preloadManager.lazyLoadPageVideos('chat_reverse');
    }

    VideoPlayerController? reverseTransitionController =
    await preloadManager.getController('assets/chat_reverse.mp4');

    if (reverseTransitionController != null) {
      // 重設退場動畫控制器
      await reverseTransitionController.seekTo(Duration.zero);
      await reverseTransitionController.pause();

      // 仿照 mooddiary.dart 的作法：將 reverseTransitionController 存入 preloadManager
      preloadManager.reverseTransitionController = reverseTransitionController;

      // 不使用 popUntil，直接 pop 回主畫面
      Navigator.of(context).pop();
    } else {
      // 沒有退場動畫資源時，直接返回主畫面
      Navigator.of(context).pop();
    }
  }


  Widget _buildScaledVideo(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
          final videoSize = controller.value.size;
          final fit = BoxFit.cover; // 使用與參考檔案相同的 BoxFit.cover

          // 計算縮放後的大小
          final fittedSizes = applyBoxFit(fit, videoSize, containerSize);
          final renderSize = fittedSizes.destination;

          // 計算影片置中的偏移量
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

  Widget _buildScaledTransitionVideo(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
          final videoSize = controller.value.size;
          final fit = BoxFit.cover; // 跟 MoodDiaryScreen 一致，改為 cover

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

  Widget _buildBackgroundStack(BuildContext context) {
    // 根據模式動態顯示背景影片，亮色與暗色
    return Stack(
      children: [
        if (_darkBackgroundVideoController != null)
          Positioned.fill(
            child: _buildScaledVideo(_darkBackgroundVideoController),
          ),
        if (_backgroundVideoController != null)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _lightBgOpacity,
              duration: Duration(milliseconds: 500),
              child: _buildScaledVideo(_backgroundVideoController),
            ),
          ),
      ],
    );
  }

  Widget _buildModeToggleButton(double scaleFactor) {
    return CustomIconButton(
      icon: Icons.brightness_6,
      onPressed: _toggleDarkMode,
      isActive: _isDarkMode,
      scaleFactor: scaleFactor,
      isDarkMode: _isDarkMode,
    );
  }

  Widget _buildChatButton() {
    double scaleFactor = _getScaleFactor(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        double deviceHeight = MediaQuery.of(context).size.height;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleInputVisibility,
          onLongPressStart: (_) {
            if (!kRunWithoutMic) {
            } else {
              print('模擬器環境，無法啟動錄音');
            }
          },
          onLongPressEnd: (_) {
            if (!kRunWithoutMic) {
            }
            setState(() {
              _isInputVisible = true;
              _isRecording = false;
            });
            _focusNode.requestFocus();
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 35),
                curve: Curves.easeInOut,
                margin: EdgeInsets.only(
                  bottom: (MediaQuery.of(context).viewInsets.bottom / 1.25) +
                      (deviceHeight / 11.5),
                ),
                width: _isInputVisible
                    ? originalInputWidth * scaleFactor
                    : originalButtonWidth * scaleFactor,
                height: _isInputVisible
                    ? _inputHeight
                    : originalButtonHeight * scaleFactor,
                decoration: BoxDecoration(
                  color: _isRecording
                      ? Colors.red.withOpacity(0.7)
                      : _isDarkMode
                      ? Colors.blueGrey[700]!.withOpacity(0.7)
                      : Colors.orangeAccent[700]!.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(
                      _isInputVisible ? 200 * scaleFactor : 160 * scaleFactor),
                ),
                  child: _isInputVisible
                      ? _buildInputField()
                      : Icon(
                    Icons.chat,
                    color: _isRecording
                        ? Colors.white
                        : (_isDarkMode
                        ? Colors.white
                        : Colors.white),
                    size: 200 * scaleFactor,
                  ),
                ),
              if (_isRecording)
                Container(
                  margin: EdgeInsets.only(
                    bottom:
                    (MediaQuery.of(context).viewInsets.bottom / 1.5) +
                        (deviceHeight / 11.5),
                  ),
                  child: SizedBox(
                    width: originalButtonWidth * scaleFactor * 1.2,
                    height: originalButtonHeight * scaleFactor * 1.2,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFastForwardButton() {
    double scaleFactor = _getScaleFactor(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        double deviceHeight = MediaQuery.of(context).size.height;

        return AnimatedBuilder(
          animation: _fastForwardController.scaleAnimation,
          builder: (context, child) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _fastForwardController.forward();
              },
              child: Container(
                margin: EdgeInsets.only(
                  bottom: (MediaQuery.of(context).viewInsets.bottom / 1.5) +
                      (deviceHeight / 11.5),
                ),
                width: originalButtonWidth * scaleFactor *
                    _fastForwardController.scaleAnimation.value,
                height: originalButtonHeight * scaleFactor *
                    _fastForwardController.scaleAnimation.value,
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? Colors.blueGrey[700]!.withOpacity(0.5)
                      : Colors.orangeAccent[700]!.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(160 * scaleFactor),
                ),
                child: Icon(
                  Icons.fast_forward,
                  color: _isDarkMode ? Colors.white : Colors.white,
                  size: 50 * _fastForwardController.scaleAnimation.value,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBackToHomeButton() {
    double scaleFactor = _getScaleFactor(context);
    return Positioned(
      top: 330 * scaleFactor,
      left: 70 * scaleFactor,
      child: CustomIconButton(
        icon: Icons.home,
        onPressed: () async {
          await _playExitAnimationAndPop();
        },
        isActive: false,
        scaleFactor: scaleFactor,
        isDarkMode: _isDarkMode,
      ),
    );
  }

  Widget _buildInputField() {
    double scaleFactor = _getScaleFactor(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15 * scaleFactor),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.8)
                    : Colors.white,
                fontSize: 90 * scaleFactor,
              ),
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '訴說心中的煩惱...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white.withOpacity(0.8),
                  fontSize: 90 * scaleFactor,
                ),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 100 * scaleFactor, vertical: 15 * scaleFactor),
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              onChanged: _onTextChanged,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 10.0),
            child: IconButton(
              icon: Icon(
                Icons.send,
                color: _isDarkMode ? Colors.white : Colors.white.withOpacity(0.8),
                size: 130 * scaleFactor,
              ),
              onPressed: sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double scaleFactor = _getScaleFactor(context);

    Color backgroundColor = _isDarkMode ? Color(0xFF2D3E50) : Colors.orange[100]!;
    Color textColor = _isDarkMode ? Colors.white : Colors.white;
    Color bubbleUserColor = _isDarkMode ? Colors.teal : Colors.purple[200]!;
    Color bubbleBotColor = _isDarkMode ? Colors.blueGrey[700]! : Colors.orange;
    Color dialogBackgroundColor = _isDarkMode
        ? Colors.black.withOpacity(0.5)
        : Colors.orangeAccent[700]!.withOpacity(0.5);

    final double characterOffsetY = 200.0 * scaleFactor;
    final double sidePanelWidth = designWidth * 0.7 * scaleFactor;
    final double responseMaxHeightFactor = 0.25;

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 0 && !_isHistoryVisible) {
              setState(() {
                _isHistoryVisible = true;
                _isInputVisible = false;
              });
            } else if (details.primaryVelocity! < 0 && _isHistoryVisible) {
              setState(() {
                _isHistoryVisible = false;
              });
            }
          }
        },
        onTap: () {
          _focusNode.unfocus();
          setState(() {
            _isInputVisible = false;
            if (_isHistoryVisible) {
              _isHistoryVisible = false;
            }
          });
        },
        child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double canvasWidth = constraints.maxWidth;
                double canvasHeight = constraints.maxHeight;

                return Stack(
                  children: [
                    // 背景顯示
                    if (_canRenderContent) _buildBackgroundStack(context),

                    if (_canRenderContent) ...[
                      Positioned(
                        left: (canvasWidth - originalCharacterWidth * scaleFactor) / 2,
                        top: (canvasHeight - originalCharacterHeight * scaleFactor) / 2 +
                            characterOffsetY,
                        child: SizedBox(
                          width: originalCharacterWidth * scaleFactor,
                          height: originalCharacterHeight * scaleFactor,
                          child: _riveArtboard == null
                              ? SizedBox()
                              : rive.Rive(
                            artboard: _riveArtboard!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      if (_showGreeting && _currentState == CharacterState.Talking)
                        Positioned(
                          top: 750 * scaleFactor,
                          left: 300 * scaleFactor,
                          right: 300 * scaleFactor,
                          child: AnimatedOpacity(
                            opacity: 1.0,
                            duration: Duration(seconds: 2),
                            child: Container(
                              padding: EdgeInsets.only(
                                left: 42 * scaleFactor,
                                top: 35 * scaleFactor,
                                right: 42 * scaleFactor,
                                bottom: 35 * scaleFactor,
                              ),
                              decoration: BoxDecoration(
                                color: dialogBackgroundColor,
                                borderRadius:
                                BorderRadius.circular(70 * scaleFactor),
                              ),
                              child: SingleChildScrollView(
                                controller: _greetingScrollController,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding:
                                      EdgeInsets.all(40 * scaleFactor),
                                      child: AnimatedTextKit(
                                        animatedTexts: [
                                          TypewriterAnimatedText(
                                            _greetingText,
                                            textAlign: TextAlign.justify,
                                            textStyle: TextStyle(
                                              fontSize: 90 * scaleFactor,
                                              color: textColor,
                                              height: 2,
                                            ),
                                            speed:
                                            Duration(milliseconds: 162),
                                            cursor: '',
                                          ),
                                        ],
                                        totalRepeatCount: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_showErrorMessage)
                        Positioned(
                          top: 750 * scaleFactor,
                          left: 300 * scaleFactor,
                          right: 300 * scaleFactor,
                          child: Opacity(
                            opacity: 0.8,
                            child: Container(
                              padding: EdgeInsets.only(
                                left: 42 * scaleFactor,
                                top: 35 * scaleFactor,
                                right: 42 * scaleFactor,
                                bottom: 35 * scaleFactor,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                borderRadius:
                                BorderRadius.circular(70 * scaleFactor),
                              ),
                              child: SingleChildScrollView(
                                controller: _errorScrollController,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding:
                                      EdgeInsets.all(40 * scaleFactor),
                                      child: AnimatedTextKit(
                                        animatedTexts: [
                                          TypewriterAnimatedText(
                                            _errorMessageText,
                                            textAlign: TextAlign.justify,
                                            textStyle: TextStyle(
                                              color:
                                              Colors.white.withOpacity(0.9),
                                              fontSize: 90 * scaleFactor,
                                              height: 1.5,
                                            ),
                                            speed:
                                            Duration(milliseconds: 162),
                                            cursor: '',
                                          ),
                                        ],
                                        totalRepeatCount: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_isThinking)
                        Positioned(
                          top: 750 * scaleFactor,
                          left: 300 * scaleFactor,
                          right: 300 * scaleFactor,
                          child: Container(
                            padding: EdgeInsets.only(
                              left: 42 * scaleFactor,
                              top: 35 * scaleFactor,
                              right: 42 * scaleFactor,
                              bottom: 35 * scaleFactor,
                            ),
                            decoration: BoxDecoration(
                              color: dialogBackgroundColor,
                              borderRadius:
                              BorderRadius.circular(70 * scaleFactor),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding:
                                  EdgeInsets.all(40 * scaleFactor),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "思考中",
                                        style: TextStyle(
                                          fontSize: 90 * scaleFactor,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                      SizedBox(width: 20 * scaleFactor),
                                      LoadingAnimationWidget.staggeredDotsWave(
                                        color:
                                        Colors.white.withOpacity(0.8),
                                        size: 90 * scaleFactor,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_responseText.isNotEmpty)
                        Positioned(
                          top: 750 * scaleFactor,
                          left: 300 * scaleFactor,
                          right: 300 * scaleFactor,
                          child: Container(
                            padding: EdgeInsets.only(
                              left: 50 * scaleFactor,
                              top: 40 * scaleFactor,
                              right: 50 * scaleFactor,
                              bottom: 40 * scaleFactor,
                            ),
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? Colors.blueGrey[700]!.withOpacity(0.5)
                                  : Colors.orangeAccent[700]!.withOpacity(0.5),
                              borderRadius:
                              BorderRadius.circular(85 * scaleFactor),
                            ),
                            constraints: BoxConstraints(
                              maxHeight:
                              designHeight * responseMaxHeightFactor *
                                  scaleFactor,
                            ),
                            child: SingleChildScrollView(
                              controller: _messageScrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Text(
                                _responseText,
                                style: TextStyle(
                                  fontSize: 90 * scaleFactor,
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.white,
                                  height: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!_isHistoryVisible)
                        Align(
                          alignment: Alignment(0.0, 0.85), // 0.0為水平置中, 0.8為稍微在底部上方一點(1是最底, -1是最頂)
                          child: (
                              (!_isAudioMode &&
                                  _isTextDisplayingResponse &&
                                  !_isFastForwarded) ||
                                  (_isAudioMode &&
                                      _isAudioPlaying &&
                                      _isDisplayingResponse &&
                                      !_isFastForwarded))
                              ? _buildFastForwardButton()
                              : _buildChatButton(),
                        ),
                      Positioned(
                        top: 330 * scaleFactor,
                        right: 70 * scaleFactor,
                        child: Row(
                          children: [
                            CustomIconButton(
                              icon: _isAudioMode
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              onPressed: _toggleVoiceFeature,
                              isActive: _isAudioMode,
                              scaleFactor: scaleFactor,
                              isDarkMode: _isDarkMode,
                            ),
                            SizedBox(width: 40 * scaleFactor),
                            CustomIconButton(
                              icon: Icons.history,
                              onPressed: _showHistory,
                              isActive: _isHistoryVisible,
                              scaleFactor: scaleFactor,
                              isDarkMode: _isDarkMode,
                            ),
                            SizedBox(width: 40 * scaleFactor),
                            _buildModeToggleButton(scaleFactor),
                          ],
                        ),
                      ),
                      _buildBackToHomeButton(),
                    ],
                    // 若有transitionController且在播放，將過場動畫疊加在最上方
                    if (widget.transitionController != null &&
                        widget.transitionController!.value.isInitialized &&
                        widget.transitionController!.value.isPlaying)
                      Opacity(
                        opacity: 1.0,
                        child: _buildScaledTransitionVideo(widget.transitionController),
                      ),
                    AnimatedPositioned(
                      duration: Duration(milliseconds: 300),
                      left: _isHistoryVisible ? 0 : -sidePanelWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: sidePanelWidth,
                        color: _isDarkMode
                            ? Colors.blueGrey[700]!.withOpacity(0.5)
                            : Colors.black.withOpacity(0.5),
                        child: Scrollbar(
                          thumbVisibility: true,
                          controller: _historyScrollController,
                          child: ListView.builder(
                            controller: _historyScrollController,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              return ChatMessageWidget(
                                message: messages[index],
                                userColor: bubbleUserColor,
                                botColor: bubbleBotColor,
                                textColor: textColor,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _textAnimationTimer?.cancel();
    _recordingTimer?.cancel();

    try {
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
      _animationController.dispose();
    } catch (e) {
      print('處理動畫控制器時出錯：$e');
    }

    try {
      if (_audioPlayer.playing) {
        _audioPlayer.stop();
      }
      _audioPlayer.dispose();
    } catch (e) {
      print('處理音頻播放器時出錯：$e');
    }

    _messageScrollController.dispose();
    _historyScrollController.dispose();
    _greetingScrollController.dispose();
    _errorScrollController.dispose();
    _focusNode.dispose();

    _controller.dispose();
    _fastForwardController.dispose();
    _stateMachineController?.dispose();

    super.dispose();
  }

  // 設計縮放比例計算
  double _getScaleFactor(BuildContext context) {
    double deviceWidth = MediaQuery.of(context).size.width;
    double deviceHeight = MediaQuery.of(context).size.height;

    double scaleFactorWidth = deviceWidth / designWidth;
    double scaleFactorHeight = deviceHeight / designHeight;

    return scaleFactorWidth < scaleFactorHeight ? scaleFactorWidth : scaleFactorHeight;
  }
}

// 定義聊天訊息類別
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

// 定義聊天訊息 widget
class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final Color userColor;
  final Color botColor;
  final Color textColor;

  ChatMessageWidget({
    required this.message,
    required this.userColor,
    required this.botColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: message.isUser ? userColor : botColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: message.isUser ? Colors.white : textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class CustomIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final double scaleFactor;
  final bool isDarkMode;

  const CustomIconButton({
    required this.icon,
    required this.onPressed,
    required this.isActive,
    required this.scaleFactor,
    required this.isDarkMode,
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
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
    ]).animate(_animationController);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onPressed();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final baseButtonSize = 250.0 * widget.scaleFactor;
    final baseIconSize = 120.0 * widget.scaleFactor;

    final gradientColors = widget.isActive || _isPressed
        ? (widget.isDarkMode
        ? [Colors.blueGrey[700]!.withOpacity(0.8), Colors.blueGrey.withOpacity(0.5)]
        : [Colors.deepOrange.withOpacity(0.8), Colors.orangeAccent.withOpacity(0.5)])
        : (widget.isDarkMode
        ? [Colors.blueGrey[700]!.withOpacity(0.6), Colors.blueGrey.withOpacity(0.5)]
        : [Colors.deepOrange.withOpacity(0.6), Colors.orangeAccent.withOpacity(0.5)]);

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
              margin: EdgeInsets.all(12 * widget.scaleFactor),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius:
                BorderRadius.circular(baseButtonSize * scale / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius:
                    (_isPressed ? 4 : 12 * widget.scaleFactor) * scale,
                    spreadRadius:
                    (_isPressed ? 1 : 2 * widget.scaleFactor) * scale,
                    offset:
                    Offset(0, _isPressed ? 2 : 4) * widget.scaleFactor * scale,
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
                      ? Colors.white.withOpacity(1.0)
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

class FastForwardAnimationController {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final TickerProvider vsync;
  final VoidCallback onAnimationComplete;

  FastForwardAnimationController({
    required this.vsync,
    required this.onAnimationComplete,
  }) {
    _initializeAnimation();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: vsync,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
    ]).animate(_animationController);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        onAnimationComplete();
      }
    });
  }

  Animation<double> get scaleAnimation => _scaleAnimation;

  void forward() {
    _animationController.forward(from: 0);
  }

  void dispose() {
    _animationController.dispose();
  }
}
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';

class OptimizedImageSequencePlayer extends StatefulWidget {
  final List<ui.Image> images;
  final double frameRate;
  final bool isLooping;
  final VoidCallback? onCompleted;
  final OptimizedImageSequenceController? controller;

  const OptimizedImageSequencePlayer({
    Key? key,
    required this.images,
    this.frameRate = 23.976,
    this.isLooping = true,
    this.onCompleted,
    this.controller,
  }) : super(key: key);

  @override
  OptimizedImageSequencePlayerState createState() => OptimizedImageSequencePlayerState();
}

class OptimizedImageSequencePlayerState extends State<OptimizedImageSequencePlayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isVisible = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _initializeAnimation();
  }

  void _initializeAnimation() {
    final totalDuration = (widget.images.length / widget.frameRate);
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (totalDuration * 1000).round()),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.isLooping) {
          _animationController.repeat();
        } else {
          widget.onCompleted?.call();
        }
      }
    });

    _animation = _animationController.drive(
      Tween<double>(begin: 0, end: (widget.images.length - 1).toDouble()),
    );

    _isInitialized = true;
    widget.controller?._updatePlayingState(true);
    _startPlayback();
  }

  void _startPlayback() {
    if (!mounted || !_isVisible) return;
    _animationController.repeat();
  }

  void play() {
    if (mounted && _isVisible) {
      _animationController.repeat();
      widget.controller?._updatePlayingState(true);
    }
  }

  void pause() {
    _animationController.stop();
    widget.controller?._updatePlayingState(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isVisible = state == AppLifecycleState.resumed;
    if (_isVisible) {
      play();
    } else {
      pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size lastSize = constraints.biggest;
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              int frameIndex = _animation.value.floor();
              if (frameIndex >= widget.images.length) frameIndex = widget.images.length - 1;
              return CustomPaint(
                painter: _CachedImagePainter(
                  image: widget.images[frameIndex],
                  lastSize: lastSize,
                ),
                size: Size.infinite,
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    widget.controller?._detach();
    super.dispose();
  }
}

class _CachedImagePainter extends CustomPainter {
  final ui.Image image;
  final Size lastSize;
  Rect? _cachedRect;
  Size? _cachedSize;

  _CachedImagePainter({
    required this.image,
    required this.lastSize,
  });

  void _updateCachedRect(Size size) {
    if (_cachedRect == null || _cachedSize != size) {
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final scale = max(size.width / imageSize.width, size.height / imageSize.height);

      final scaledWidth = imageSize.width * scale;
      final scaledHeight = imageSize.height * scale;
      final left = (size.width - scaledWidth) / 2;
      final top = (size.height - scaledHeight) / 2;

      _cachedRect = Rect.fromLTWH(left, top, scaledWidth, scaledHeight);
      _cachedSize = size;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _updateCachedRect(lastSize);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      _cachedRect!,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_CachedImagePainter oldPainter) {
    return image != oldPainter.image;
  }
}

class OptimizedImageSequenceController {
  OptimizedImageSequencePlayerState? _state;
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  bool get isPlaying => isPlayingNotifier.value;

  void _attach(OptimizedImageSequencePlayerState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
    isPlayingNotifier.value = false;
  }

  void _updatePlayingState(bool playing) {
    isPlayingNotifier.value = playing;
  }

  void play() => _state?.play();
  void pause() => _state?.pause();

  void dispose() {
    _state = null;
    isPlayingNotifier.dispose();
  }
}

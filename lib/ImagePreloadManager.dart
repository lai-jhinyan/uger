import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';

class ImagePreloadManager {
  ImagePreloadManager._privateConstructor();
  static final ImagePreloadManager _instance = ImagePreloadManager._privateConstructor();
  factory ImagePreloadManager() => _instance;

  final Map<String, List<ui.Image>> _uiImageSequences = {};

  /// 预加载特定序列的所有图片并转换为 ui.Image
  Future<void> preloadImageSequence(String sequenceName, int frameCount) async {
    if (_uiImageSequences.containsKey(sequenceName)) return;

    List<ui.Image> uiImages = [];
    for (int i = 0; i < frameCount; i++) {
      String imagePath = 'assets/$sequenceName/a$i.jpg';
      AssetImage imageProvider = AssetImage(imagePath);

      try {
        final uiImage = await _loadUiImage(imageProvider);
        if (uiImage != null) {
          uiImages.add(uiImage);
        }
      } catch (e) {
        print('Failed to preload image: $imagePath - Error: $e');
      }
    }
    _uiImageSequences[sequenceName] = uiImages;
    print('Sequence $sequenceName loaded with ${uiImages.length} frames.');
  }

  Future<ui.Image?> _loadUiImage(ImageProvider provider) async {
    try {
      final completer = Completer<ui.Image>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
            (ImageInfo info, bool _) => completer.complete(info.image),
        onError: (exception, stackTrace) {
          print('Error loading image: $exception');
          completer.completeError(exception);
        },
      );
      stream.addListener(listener);
      final uiImage = await completer.future;
      stream.removeListener(listener);
      return uiImage;
    } catch (e) {
      print('Failed to load ui.Image: $e');
      return null;
    }
  }

  /// 获取特定序列的 ui.Image 列表
  List<ui.Image>? getUiImageSequence(String sequenceName) {
    return _uiImageSequences[sequenceName];
  }

  void clear() {
    _uiImageSequences.clear();
  }
}

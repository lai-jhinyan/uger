// lib/RivePreloadManager.dart
import 'package:rive/rive.dart';
import 'package:flutter/services.dart';

class RivePreloadManager {
  // 單例模式
  RivePreloadManager._privateConstructor();
  static final RivePreloadManager _instance = RivePreloadManager._privateConstructor();
  factory RivePreloadManager() {
    return _instance;
  }

  // 用於緩存已加載的 RiveFile 和 Artboard
  final Map<String, RiveFile> _fileCache = {};
  final Map<String, Artboard> _artboardCache = {};

  // 用於緩存狀態機控制器
  final Map<String, StateMachineController> _stateMachineControllers = {};

  // 預加載 Rive 文件
  Future<void> preloadRive(String assetPath, {String? stateMachineName}) async {
    // 若已加載過就不重覆加載
    if (_artboardCache.containsKey(assetPath) && _fileCache.containsKey(assetPath)) {
      return;
    }

    try {
      final data = await rootBundle.load(assetPath);
      final file = RiveFile.import(data);

      // 取得主Artboard
      final artboard = file.mainArtboard;

      // 如果有指定狀態機名稱則加上控制器
      if (stateMachineName != null) {
        final controller = StateMachineController.fromArtboard(artboard, stateMachineName);
        if (controller != null) {
          artboard.addController(controller);
          _stateMachineControllers[assetPath] = controller;
        }
      }

      // 存入快取
      _fileCache[assetPath] = file;
      _artboardCache[assetPath] = artboard;
      print('Rive file $assetPath loaded and cached.');
    } catch (e) {
      print('Error preloading Rive file $assetPath: $e');
    }
  }

  // 獲取已緩存的 Artboard
  Artboard? getArtboard(String assetPath) {
    return _artboardCache[assetPath];
  }

  // 獲取已緩存的 RiveFile
  RiveFile? getFile(String assetPath) {
    return _fileCache[assetPath];
  }

  // 獲取已緩存的 StateMachineController
  StateMachineController? getStateMachineController(String assetPath) {
    return _stateMachineControllers[assetPath];
  }
}

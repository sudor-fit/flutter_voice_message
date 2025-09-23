import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:voice_message_package/src/helpers/play_status.dart';
import 'package:voice_message_package/src/helpers/utils.dart';

/// A controller for managing voice playback.
///
/// The [VoiceController] class provides functionality for playing, pausing, stopping, and seeking voice playback.
/// It uses the [just_audio](https://pub.dev/packages/just_audio) package for audio playback.
/// The controller also supports changing the playback speed and provides UI updates through a [ValueNotifier].
///
/// Example usage:
/// ```dart
/// VoiceController voiceController = VoiceController(
///   audioSrc: 'path/to/audio.mp3',
///   maxDuration: Duration(minutes: 5),
///   isFile: true,
///   onComplete: () {
///   },
///   onPause: () {
///   },
///   onPlaying: () {
///   },
/// );
///
class VoiceController extends MyTicker {
  final String audioSrc;
  late Duration maxDuration;
  Duration currentDuration = Duration.zero;
  final Function() onComplete;
  final Function() onPlaying;
  final Function() onPause;
  final Function(Object)? onError;
  final double noiseWidth = 44.w();
  late AnimationController animController;
  final AudioPlayer _player = AudioPlayer();
  final bool isFile;
  final String? cacheKey;
  final Future<String> pathToFolder;
  PlayStatus playStatus = PlayStatus.init;
  PlaySpeed speed = PlaySpeed.x1;
  ValueNotifier updater = ValueNotifier(null);
  List<double>? randoms;
  StreamSubscription? positionStream;
  StreamSubscription? playerStateStream;
  double? downloadProgress = 0;
  final int noiseCount;

  /// Gets the current playback position of the voice.
  double get currentMillSeconds {
    final c = currentDuration.inMilliseconds.toDouble();
    if (c >= maxMillSeconds) {
      return maxMillSeconds;
    }
    return c;
  }

  bool isSeeking = false;

  bool get isPlaying => playStatus == PlayStatus.playing;

  bool get isInit => playStatus == PlayStatus.init;

  bool get isDownloading => playStatus == PlayStatus.downloading;

  bool get isDownloadError => playStatus == PlayStatus.downloadError;

  bool get isStop => playStatus == PlayStatus.stop;

  bool get isPause => playStatus == PlayStatus.pause;

  double get maxMillSeconds => maxDuration.inMilliseconds.toDouble();

  StreamSubscription<FileResponse>? downloadStreamSubscription;

  /// Creates a new [VoiceController] instance.
  VoiceController({
    required this.audioSrc,
    required this.maxDuration,
    required this.isFile,
    required this.onComplete,
    required this.onPause,
    required this.onPlaying,
    required this.pathToFolder,
    this.noiseCount = 24,
    this.onError,
    this.randoms,
    this.cacheKey,
  }) {
    if (randoms?.isEmpty ?? true) _setRandoms();
    animController = AnimationController(
      vsync: this,
      upperBound: noiseWidth,
      duration: maxDuration,
    );
    init();
    _listenToRemindingTime();
    _listenToPlayerState();
  }

  /// Initializes the voice controller.
  Future init() async {
    _updateUi();
  }

  Future play() async {
    try {
      debugPrint('VOICE CONTROLLER: Starting play() - audioSrc: $audioSrc');
      debugPrint('VOICE CONTROLLER: isFile: $isFile');

      playStatus = PlayStatus.downloading;
      _updateUi();

      if (isFile) {
        debugPrint('VOICE CONTROLLER: Getting local file from cache');
        final path = await _getFileFromCache();
        debugPrint('VOICE CONTROLLER: Local file path: $path');
        // await setMaxDuration(path);
        await startPlaying(path!);
        onPlaying();
      } else {
        debugPrint('VOICE CONTROLLER: Starting remote file download/stream');
        downloadStreamSubscription = _getFileFromCacheWithProgress().listen(
            (FileResponse fileResponse) async {
          if (fileResponse is FileInfo) {
            debugPrint(
                'VOICE CONTROLLER: Download complete, file path: ${fileResponse.file.path}');
            await startPlaying(fileResponse.file.path);
            onPlaying();
          } else if (fileResponse is DownloadProgress) {
            debugPrint(
                'VOICE CONTROLLER: Download progress: ${fileResponse.progress}');
            _updateUi();
            downloadProgress = fileResponse.progress;
          }
        }, onError: (error) {
          debugPrint('VOICE CONTROLLER: Download stream error: $error');
          playStatus = PlayStatus.downloadError;
          _updateUi();
          if (onError != null) {
            onError!(error);
          }
        });
      }
    } catch (err, stackTrace) {
      debugPrint('VOICE CONTROLLER ERROR in play(): $err');
      debugPrint('VOICE CONTROLLER ERROR audioSrc: $audioSrc');
      debugPrint('VOICE CONTROLLER ERROR stack: $stackTrace');

      playStatus = PlayStatus.downloadError;
      _updateUi();
      if (onError != null) {
        onError!(err);
      } else {
        rethrow;
      }
    }
  }

  void _listenToRemindingTime() {
    positionStream = _player.positionStream.listen((Duration p) async {
      if (!isDownloading) currentDuration = p;

      final value = (noiseWidth * currentMillSeconds) / maxMillSeconds;
      animController.value = value;
      _updateUi();
      if (p.inMilliseconds >= maxMillSeconds) {
        await _player.stop();
        currentDuration = Duration.zero;
        playStatus = PlayStatus.init;
        animController.reset();
        _updateUi();
        onComplete();
      }
    });
  }

  void _updateUi() {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    updater.notifyListeners();
  }

  /// Stops playing the voice.
  Future stopPlaying() async {
    await _player.pause();
    playStatus = PlayStatus.stop;
  }

  /// Starts playing the voice.
  Future startPlaying(String path) async {
    try {
      debugPrint('VOICE CONTROLLER: Setting file path: $path');
      await _player.setFilePath(path);
    } catch (e, stackTrace) {
      debugPrint('VOICE CONTROLLER ERROR in setFilePath: $e');
      debugPrint('VOICE CONTROLLER ERROR path: $path');
      debugPrint('VOICE CONTROLLER ERROR stack: $stackTrace');
      rethrow;
    }

    try {
      debugPrint('VOICE CONTROLLER: Starting playback');
      await _player.play();
    } catch (e, stackTrace) {
      debugPrint('VOICE CONTROLLER ERROR in startPlaying: $e');
      debugPrint('VOICE CONTROLLER ERROR stack: $stackTrace');
      rethrow;
    }

    try {
      debugPrint('VOICE CONTROLLER: Setting speed to ${speed.getSpeed}');
      await _player.setSpeed(speed.getSpeed);

      debugPrint('VOICE CONTROLLER: Playback started successfully');
    } catch (e, stackTrace) {
      debugPrint('VOICE CONTROLLER ERROR in setSpeed: $e');
      debugPrint('VOICE CONTROLLER ERROR stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    await positionStream?.cancel();
    await playerStateStream?.cancel();
    animController.dispose();
  }

  /// Seeks to the given [duration].
  void onSeek(Duration duration) {
    isSeeking = false;
    currentDuration = duration;
    _updateUi();
    _player.seek(duration);
  }

  /// Pauses the voice playback.
  void pausePlaying() {
    _player.pause();
    playStatus = PlayStatus.pause;
    _updateUi();
    onPause();
  }

  Future<String?> _getFileFromCache() async {
    if (isFile) {
      return audioSrc;
    }

    // Extract extension from URL
    final uri = Uri.parse(audioSrc);
    final pathSegments = uri.pathSegments;
    String fileExtension = '';

    if (pathSegments.isNotEmpty) {
      final fileName = pathSegments.last;
      final dotIndex = fileName.lastIndexOf('.');
      if (dotIndex != -1) {
        fileExtension = fileName.substring(dotIndex);
        debugPrint(
            'VOICE CONTROLLER: Extracted extension from URL: $fileExtension');
      }
    }

    // Clear cache for .octet-stream files to force re-download with correct extension
    try {
      final cachedFile =
          await DefaultCacheManager().getFileFromCache(cacheKey ?? audioSrc);
      if (cachedFile?.file.path.endsWith('.octet-stream') == true) {
        debugPrint('VOICE CONTROLLER: Clearing cached .octet-stream file');
        await DefaultCacheManager().removeFile(cacheKey ?? audioSrc);
      }
    } catch (e) {
      debugPrint('VOICE CONTROLLER: Cache check error: $e');
    }

    // Use custom cache manager that forces file extension
    final p =
        await _getSingleFileWithExtension(audioSrc, fileExtension, cacheKey);
    debugPrint('VOICE CONTROLLER: Final cached file path: $p');
    return p;
  }

  /// Custom method to download file with forced extension
  Future<String> _getSingleFileWithExtension(
      String url, String extension, String? key) async {
    try {
      // Try to get from cache first
      final fileInfo = await DefaultCacheManager().getFileFromCache(key ?? url);
      if (fileInfo != null && !fileInfo.file.path.endsWith('.octet-stream')) {
        debugPrint(
            'VOICE CONTROLLER: Using cached file: ${fileInfo.file.path}');
        return fileInfo.file.path;
      }

      // Download the file
      debugPrint(
          'VOICE CONTROLLER: Downloading file with forced extension: $extension');
      final file = await DefaultCacheManager().getSingleFile(url, key: key);

      // If the cached file has wrong extension, rename it
      if (extension.isNotEmpty && !file.path.endsWith(extension)) {
        final correctPath =
            file.path.replaceAll(RegExp(r'\.[^.]*$'), extension);
        debugPrint('VOICE CONTROLLER: Renaming ${file.path} to $correctPath');

        try {
          final renamedFile = await file.copy(correctPath);
          await file.delete(); // Delete the old file
          return renamedFile.path;
        } catch (e) {
          debugPrint(
              'VOICE CONTROLLER: Failed to rename file: $e, using original');
          return file.path;
        }
      }

      return file.path;
    } catch (e) {
      debugPrint('VOICE CONTROLLER: Error in _getSingleFileWithExtension: $e');
      rethrow;
    }
  }

  Stream<FileResponse> _getFileFromCacheWithProgress() async* {
    if (isFile) {
      throw Exception("This method is not applicable for local files.");
    }

    // Extract extension from URL for progress downloads
    final uri = Uri.parse(audioSrc);
    final pathSegments = uri.pathSegments;
    String fileExtension = '';

    if (pathSegments.isNotEmpty) {
      final fileName = pathSegments.last;
      final dotIndex = fileName.lastIndexOf('.');
      if (dotIndex != -1) {
        fileExtension = fileName.substring(dotIndex);
        debugPrint(
            'VOICE CONTROLLER: Progress download extension: $fileExtension');
      }
    }

    // Clear any existing .octet-stream files
    try {
      final cachedFile =
          await DefaultCacheManager().getFileFromCache(cacheKey ?? audioSrc);
      if (cachedFile?.file.path.endsWith('.octet-stream') == true) {
        debugPrint(
            'VOICE CONTROLLER: Progress - Clearing cached .octet-stream file');
        await DefaultCacheManager().removeFile(cacheKey ?? audioSrc);
      }
    } catch (e) {
      debugPrint('VOICE CONTROLLER: Progress - Cache check error: $e');
    }

    await for (final response in DefaultCacheManager()
        .getFileStream(audioSrc, key: cacheKey, withProgress: true)) {
      if (response is FileInfo) {
        debugPrint(
            'VOICE CONTROLLER: Progress download complete: ${response.file.path}');

        // Check if we need to rename the file to correct extension
        if (fileExtension.isNotEmpty &&
            !response.file.path.endsWith(fileExtension)) {
          try {
            final correctPath = response.file.path
                .replaceAll(RegExp(r'\.[^.]*$'), fileExtension);
            debugPrint(
                'VOICE CONTROLLER: Progress - Renaming ${response.file.path} to $correctPath');

            final renamedFile = await response.file.copy(correctPath);
            await response.file.delete();

            // Yield the FileInfo with the renamed file
            yield FileInfo(renamedFile, FileSource.Online, response.validTill,
                response.originalUrl);
          } catch (e) {
            debugPrint(
                'VOICE CONTROLLER: Progress - Failed to rename: $e, using original');
            yield response;
          }
        } else {
          yield response;
        }
      } else {
        // Pass through DownloadProgress and other responses
        yield response;
      }
    }
  }

  void cancelDownload() {
    playStatus = PlayStatus.init;
    _updateUi();
  }

  /// Resumes the voice playback.
  void _listenToPlayerState() {
    playerStateStream = _player.playerStateStream.listen((event) async {
      if (event.processingState == ProcessingState.completed) {
        // TODO resurrect this code if needed
        // await _player.stop();
        // currentDuration = Duration.zero;
        // playStatus = PlayStatus.init;
        // animController.reset();
        // _updateUi();
        // onComplete(id);
      } else if (event.playing) {
        playStatus = PlayStatus.playing;
        _updateUi();
      }
    });
  }

  /// Changes the speed of the voice playback.
  void changeSpeed() {
    // Function implementation goes here
    switch (speed) {
      case PlaySpeed.x1:
        speed = PlaySpeed.x1_25;
        break;
      case PlaySpeed.x1_25:
        speed = PlaySpeed.x1_5;
        break;
      case PlaySpeed.x1_5:
        speed = PlaySpeed.x1_75;
        break;
      case PlaySpeed.x1_75:
        speed = PlaySpeed.x2;
        break;
      case PlaySpeed.x2:
        speed = PlaySpeed.x2_25;
        break;
      case PlaySpeed.x2_25:
        speed = PlaySpeed.x1;
        break;
    }
    _player.setSpeed(speed.getSpeed);
    _updateUi();
  }

  /// Changes the speed of the voice playback.
  void onChangeSliderStart(double value) {
    isSeeking = true;

    /// pause the voice
    pausePlaying();
  }

  void _setRandoms() {
    randoms = [];
    for (var i = 0; i < noiseCount; i++) {
      randoms!.add(5.74.w() * Random().nextDouble() + .26.w());
    }
  }

  /// Changes the speed of the voice playback.
  void onChanging(double d) {
    currentDuration = Duration(milliseconds: d.toInt());
    final value = (noiseWidth * d) / maxMillSeconds;
    animController.value = value;
    _updateUi();
  }

  ///
  String get remindingTime {
    if (currentDuration == Duration.zero) {
      return maxDuration.formattedTime;
    }
    if (isSeeking || isPause) {
      return currentDuration.formattedTime;
    }
    if (isInit) {
      return maxDuration.formattedTime;
    }
    return currentDuration.formattedTime;
  }

  /// Sets the maximum duration of the voice.
  Future setMaxDuration(String path) async {
    try {
      /// get the max duration from the path or cloud
      final maxDuration = await _player.setFilePath(path);
      if (maxDuration != null) {
        this.maxDuration = maxDuration;
        animController.duration = maxDuration;
      }
    } catch (err) {
      if (kDebugMode) {
        ///
        debugPrint("cant get the max duration from the path $path");
      }
      if (onError != null) {
        onError!(err);
      }
    }
  }
}

/// A custom [TickerProvider] implementation for the voice controller.
///
/// This class provides the necessary functionality for controlling the voice playback.
/// It implements the [TickerProvider] interface, allowing it to create [Ticker] objects
/// that can be used to schedule animations or other periodic tasks.
///
/// Example usage:
/// ```dart
/// VoiceController voiceController = VoiceController();
/// voiceController.start();
/// voiceController.stop();
/// ```

///
/// This class extends [TickerProvider] and provides a custom ticker for the voice controller.
/// It can be used to create animations or perform actions at regular intervals.
class MyTicker extends TickerProvider {
  @override

  /// Creates a new ticker.
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }
}

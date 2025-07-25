import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:voice_message_package/voice_message_package.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

///
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.grey.shade200,
          body: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 50.h),
                  VoiceMessageView(
                    controller: VoiceController(
                      audioSrc:
                          'https://dl.solahangs.com/Music/1403/02/H/128/Hiphopologist%20-%20Shakkak%20%28128%29.mp3',
                      maxDuration: const Duration(seconds: 10),
                      isFile: false,
                      pathToFolder: getVoiceMessageDir(),
                      onComplete: () {
                        /// do something on complete
                      },
                      onPause: () {
                        /// do something on pause
                      },
                      onPlaying: () {
                        /// do something on playing
                      },
                      onError: (err) {
                        /// do somethin on error
                      },
                    ),
                    innerPadding: 12,
                    cornerRadius: 20,
                  ),
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ),
      );

  static Future<String> getVoiceMessageDir() async {
    final cachePath = await _getCacheFolderPath();

    // Putting remote files into `voiceMessage` directory, not `voiceNote`,
    // because that folder is for recorded message to send
    return _createDirIfMissing("$cachePath/voiceMessage");
  }

  static Future<String> _getCacheFolderPath() async =>
      (await getTemporaryDirectory()).path;

  static Future<String> _createDirIfMissing(String path) async {
    if (!await pathExists(path)) {
      await createDirectory(path);
    }

    return path;
  }

  static Future<bool> pathExists(String path) async =>
      await File(path).exists();

  static Future<Directory> createDirectory(String path) async =>
      await Directory(path).create(recursive: true);
}

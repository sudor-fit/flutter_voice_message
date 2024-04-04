import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:voice_message_package/voice_message_package.dart';

void main() => runApp(const MyApp());

///
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Sizer(
        builder: (_, __, ___) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.grey.shade200,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  VoiceMessageView(
                    controller: VoiceController(
                      audioSrc:
                          'https://dl.musichi.ir/1401/06/21/Ghors%202.mp3',
                      maxDuration: const Duration(seconds: 10),
                      isFile: false,
                      //TODO change to real path
                      pathToFolder: "path/to/voice/folder",
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
                ],
              ),
            ),
          ),
        ),
      );
}

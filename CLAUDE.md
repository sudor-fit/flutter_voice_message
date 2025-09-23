# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter package called `voice_message_package` that provides voice message playback functionality for chat applications. The package allows users to play/pause voice messages with visual waveform representations and seeking capabilities.

## Architecture

### Core Components

**VoiceController** (`lib/src/voice_controller.dart`): The main controller managing audio playback, caching, downloading, and state management. Uses `just_audio` for audio playback and `flutter_cache_manager` for caching remote audio files.

**VoiceMessageView** (`lib/src/voice_message_view.dart`): The main UI widget that displays the voice message player with play/pause button, waveform visualization, and speed controls.

### Key Features

- Audio caching with proper file extension handling
- Playback speed control (1.0x to 2.25x)
- Visual waveform with seeking capability
- Support for both local files and remote URLs
- Custom audio player controls with animations

### Dependencies

- `just_audio`: Audio playback engine
- `flutter_cache_manager`: Handles audio file caching
- `syncfusion_flutter_sliders`: Used for custom slider components
- `http`: Network requests

## Development Commands

### Package Development
```bash
# Get dependencies
flutter pub get

# Run static analysis
flutter analyze

# Format code
dart format .

# Run tests (if any exist)
flutter test
```

### Example App Development
```bash
# Navigate to example directory
cd example/

# Get dependencies
flutter pub get

# Run example app
flutter run

# Build for specific platform
flutter build ios
flutter build android
flutter build web
```

## File Structure

```
lib/
├── src/
│   ├── helpers/
│   │   ├── play_status.dart      # PlayStatus and PlaySpeed enums
│   │   └── utils.dart            # Utility extensions for responsive design
│   ├── widgets/                  # UI component widgets
│   ├── voice_controller.dart     # Main audio controller logic
│   └── voice_message_view.dart   # Main UI widget
└── voice_message_package.dart    # Package exports
```

## Important Notes

- The package handles audio file caching intelligently, including proper file extension management
- Debug logging is extensive in VoiceController - look for `VOICE CONTROLLER:` prefixed logs
- The controller uses a custom TickerProvider (`MyTicker`) for animations
- Audio duration must be provided to the controller; it doesn't auto-detect from remote URLs
- File extension handling is critical for proper audio playback, especially for cached files

## Common Development Tasks

- To modify audio playback behavior, work with `VoiceController`
- To change UI appearance, modify `VoiceMessageView` and related widgets
- Audio caching logic is in the `_getFileFromCache` methods of `VoiceController`
- Waveform visualization is handled by the `Noises` widget component
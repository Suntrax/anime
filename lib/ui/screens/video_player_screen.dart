import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? headers;
  final String? subtitleUrl;

  const VideoPlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.headers,
    this.subtitleUrl,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late BetterPlayerController _betterPlayerController;
  bool _isHandlingError = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    // 1. General Player Configuration
    BetterPlayerConfiguration betterPlayerConfiguration = const BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
      fullScreenByDefault: true,
      allowedScreenSleep: false,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enableAudioTracks: true,
        enableSubtitles: true,
        enableQualities: true,
        loadingWidget: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );

    // 2. Setup Subtitles (if available)
    List<BetterPlayerSubtitlesSource>? subtitles;
    if (widget.subtitleUrl != null && widget.subtitleUrl!.isNotEmpty) {
      subtitles = [
        BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.network,
          name: "English",
          urls: [widget.subtitleUrl!],
          selectedByDefault: true,
        )
      ];
    }

    // 3. Setup Data Source with Network Stability Headers
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.url,
      headers: {
        ...?widget.headers,
        "Connection": "keep-alive", // Prevents many "unexpected end of stream" errors
      },
      subtitles: subtitles,
      videoFormat: BetterPlayerVideoFormat.hls,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 15000,
        maxBufferMs: 60000,
        bufferForPlaybackMs: 5000,
        bufferForPlaybackAfterRebufferMs: 10000,
      ),
    );

    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);

    // 4. CRASH PREVENTION: Global Event Listener
    _betterPlayerController.addEventsListener((event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
        debugPrint("Playback Error Event: ${event.parameters}");
        _handlePlaybackError("Video stream disconnected.");
      }

      if (event.betterPlayerEventType == BetterPlayerEventType.openFullscreen ||
          event.betterPlayerEventType == BetterPlayerEventType.hideFullscreen) {
        if (mounted) setState(() {});
      }
    });

    // 5. CRASH PREVENTION: Safe Async Initialization
    Future.microtask(() async {
      try {
        await _betterPlayerController.setupDataSource(dataSource);
      } catch (e) {
        debugPrint("Initial Setup Failure: $e");
        _handlePlaybackError("Could not connect to video server.");
      }
    });
  }

  void _handlePlaybackError(String message) {
    if (_isHandlingError || !mounted) return;
    
    setState(() {
      _isHandlingError = true;
      _hasError = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );

    // Safely exit the screen back to Home/Details
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    // Force native resources to release immediately
    _betterPlayerController.dispose(forceDispose: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: (_betterPlayerController.isFullScreen || _hasError)
          ? null
          : AppBar(
              title: Text(widget.title),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
      body: Center(
        child: _hasError
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 60),
                  SizedBox(height: 16),
                  Text(
                    "Connection Reset\nTry a different server",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              )
            : BetterPlayer(controller: _betterPlayerController),
      ),
    );
  }
}
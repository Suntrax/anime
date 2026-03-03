import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomPlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? headers;
  final String? subtitleUrl;
  final VoidCallback? onNextEpisode;

  const CustomPlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.headers,
    this.subtitleUrl,
    this.onNextEpisode,
  });

  @override
  State<CustomPlayerScreen> createState() => _CustomPlayerScreenState();
}

class _CustomPlayerScreenState extends State<CustomPlayerScreen> {
  // Start hidden so it only shows on user tap
  bool _showControls = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Force landscape for a better anime experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // Reset to portrait when leaving the player
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = true; 
      _startHideTimer(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // 1. NATIVE PLAYER VIEW
            Center(
              child: AndroidView(
                viewType: 'exo_player_view',
                creationParams: {
                  "url": widget.url,
                  "subtitleUrl": widget.subtitleUrl,
                  "headers": widget.headers,
                },
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),

            // 2. UI OVERLAY (Fade in/out)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  children: [
                    // Top Bar: Back Button and Title
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Bar: Next Episode Button
                    if (widget.onNextEpisode != null)
                      Positioned(
                        bottom: 40,
                        right: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Close current player
                            widget.onNextEpisode!(); // Start next episode scrape/play
                          },
                          icon: const Icon(Icons.skip_next, size: 24),
                          label: const Text(
                            "NEXT EPISODE",
                            style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
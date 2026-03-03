import 'package:flutter/material.dart';
import 'video_player_screen.dart';
import 'custom_player_screen.dart';
import '../../services/anime_service.dart';
import 'dart:convert';

/// Global function to handle episode scraping and navigation
void _playEpisode(BuildContext context, dynamic anime, int episodeNum, String selectedPlayer) async {
  final String animeName = anime['title']['romaji'] ?? anime['title']['english'];
  final int totalEpisodes = anime['episodes'] ?? 0;
  final int lastAired = anime['nextAiringEpisode'] != null 
      ? anime['nextAiringEpisode']['episode'] - 1 
      : (totalEpisodes == 0 ? 9999 : totalEpisodes);

  // Guard against unreleased episodes
  if (episodeNum > lastAired) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Episode has not aired yet!")),
    );
    return; 
  }

  final colorScheme = Theme.of(context).colorScheme;
  
  // Show Loading Overlay
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(
      child: CircularProgressIndicator(color: colorScheme.primary),
    ),
  );

  // Scrape each episode when needed (No caching)
  final result = await AniwatchService.getStreamLink(animeName, episodeNum);

  if (!context.mounted) return;
  Navigator.pop(context); // Remove Loader

  if (result != null) {
    // --- ADD THESE DEBUG LOGS ---
    print("DEBUG: Final Stream URL: ${result.url}");
    print("DEBUG: Headers: ${jsonEncode(result.headers)}");
    if (result.subtitleUrl != null) print("DEBUG: Subtitle: ${result.subtitleUrl}");
    // ----------------------------
    Widget playerScreen;
    if (selectedPlayer == "custom") {
      playerScreen = CustomPlayerScreen(
        url: result.url, 
        title: "$animeName - Ep $episodeNum",
        headers: result.headers,
        subtitleUrl: result.subtitleUrl,
        onNextEpisode: episodeNum < lastAired 
            ? () => _playEpisode(context, anime, episodeNum + 1, selectedPlayer)
            : null,
      );
    } else {
      playerScreen = VideoPlayerScreen(
        url: result.url,
        title: "$animeName - Ep $episodeNum",
        headers: result.headers,
        subtitleUrl: result.subtitleUrl,
      );
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => playerScreen));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to find stream for this episode.")),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final bool isInitialChecking;
  final VoidCallback onLogin;
  final Future<void> Function() onRefresh;
  final bool isOled;
  final String selectedPlayer;

  const HomeScreen({
    super.key,
    this.userData,
    required this.isInitialChecking,
    required this.onLogin,
    required this.onRefresh,
    required this.isOled,
    required this.selectedPlayer,
  });

  @override
  Widget build(BuildContext context) {
    if (isInitialChecking) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      );
    }

    if (userData == null || userData!['Viewer'] == null) {
      return _buildLoginView(context);
    }

    final viewer = userData!['Viewer'];
    final watching = (userData!['watching']['lists'] as List).isNotEmpty
        ? userData!['watching']['lists'][0]['entries'] as List
        : [];
    final planning = (userData!['planning']['lists'] as List).isNotEmpty
        ? userData!['planning']['lists'][0]['entries'] as List
        : [];

    return RefreshIndicator(
      onRefresh: onRefresh,
      backgroundColor: isOled ? Colors.black : Theme.of(context).colorScheme.surfaceContainer,
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 70, 0, 120),
        children: [
          _buildHeader(context, viewer),
          const SizedBox(height: 30),
          _buildSection(context, "Currently Watching", watching, true),
          const SizedBox(height: 30),
          _buildSection(context, "Planning to Watch", planning, false),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic viewer) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: NetworkImage(viewer['avatar']['large']),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome back,", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
                  Text(viewer['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${viewer['statistics']['anime']['episodesWatched']}", 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
              const Text("Episodes", style: TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List entries, bool isWatching) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 260, 
          child: entries.isEmpty
              ? const Center(child: Text("Empty", style: TextStyle(color: Colors.white24)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => AnimeHomeCard(
                    entry: entries[i], 
                    isOled: isOled, 
                    selectedPlayer: selectedPlayer,
                    showQuickPlay: isWatching,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLoginView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text("Sync with AniList to see your library", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: onLogin, 
            child: const Text("Login to AniList")
          ),
        ],
      )
    );
  }
}

class AnimeHomeCard extends StatelessWidget {
  final dynamic entry;
  final bool isOled;
  final String selectedPlayer;
  final bool showQuickPlay;

  const AnimeHomeCard({
    super.key, 
    required this.entry, 
    required this.isOled, 
    required this.selectedPlayer,
    required this.showQuickPlay,
  });

  String _getEpisodeStatus() {
    final media = entry['media'];
    final int current = entry['progress'] ?? 0;
    final int total = media['episodes'] ?? 0;
    final String status = media['status'] ?? '';
    final String totalStr = total == 0 ? '?' : total.toString();
    
    bool isCurrentlyAiring = status == 'RELEASING' || status == 'NOT_YET_RELEASED';

    if (isCurrentlyAiring && media['nextAiringEpisode'] != null) {
      int latestAired = media['nextAiringEpisode']['episode'] - 1;
      return "$current / $latestAired / $totalStr";
    }

    return "$current / $totalStr";
  }

  @override
  Widget build(BuildContext context) {
    final anime = entry['media'];
    final colorScheme = Theme.of(context).colorScheme;
    final int nextEp = (entry['progress'] ?? 0) + 1;

    return GestureDetector(
      onTap: () => _showAnimeDetails(context),
      child: Container(
        width: 140, 
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        anime['coverImage']['large'], 
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                      ),
                    ),
                  ),
                  if (showQuickPlay)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Material(
                        color: colorScheme.primary,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          onTap: () => _playEpisode(context, anime, nextEp, selectedPlayer),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              anime['title']['english'] ?? anime['title']['romaji'],
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              _getEpisodeStatus(),
              style: TextStyle(
                fontSize: 11, 
                color: colorScheme.primary, 
                fontWeight: FontWeight.w800
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnimeDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isOled ? Colors.black : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AnimeDetailSheet(entry: entry, isOled: isOled, selectedPlayer: selectedPlayer),
    );
  }
}

class _AnimeDetailSheet extends StatelessWidget {
  final dynamic entry;
  final bool isOled;
  final String selectedPlayer;
  const _AnimeDetailSheet({required this.entry, required this.isOled, required this.selectedPlayer});

  @override
  Widget build(BuildContext context) {
    final anime = entry['media'];
    final colorScheme = Theme.of(context).colorScheme;
    final int currentProgress = entry['progress'] ?? 0;
    final int total = anime['episodes'] ?? 0;
    int lastAired = anime['nextAiringEpisode'] != null ? anime['nextAiringEpisode']['episode'] - 1 : (total == 0 ? 9999 : total);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 40, 
            height: 4, 
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4), 
              borderRadius: BorderRadius.circular(2)
            ),
          ),
          const SizedBox(height: 20),
          Text(
            anime['title']['english'] ?? anime['title']['romaji'], 
            textAlign: TextAlign.center, 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, 
                mainAxisSpacing: 10, 
                crossAxisSpacing: 10
              ),
              itemCount: total == 0 ? lastAired : total,
              itemBuilder: (context, i) {
                int epNumber = i + 1;
                bool isWatched = epNumber <= currentProgress;
                bool hasAired = epNumber <= lastAired;
                return GestureDetector(
                  onTap: hasAired ? () => _playEpisode(context, anime, epNumber, selectedPlayer) : null,
                  child: Opacity(
                    opacity: hasAired ? 1.0 : 0.3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isWatched ? colorScheme.primary.withOpacity(0.2) : colorScheme.surfaceVariant,
                        border: isWatched ? Border.all(color: colorScheme.primary) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "$epNumber", 
                        style: TextStyle(
                          color: isWatched ? colorScheme.primary : colorScheme.onSurfaceVariant, 
                          fontWeight: isWatched ? FontWeight.bold : FontWeight.normal
                        )
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
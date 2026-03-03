import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/anilist_api.dart';
import '../widgets/glass_components.dart';

class ExploreScreen extends StatelessWidget {
  final VoidCallback onSearchToggle;
  final bool isOled;
  const ExploreScreen({super.key, required this.onSearchToggle, required this.isOled});

  void _showDetails(BuildContext context, int id) async {
    final details = await AniListApi.fetchAnimeDetails(id);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _AnimeDetailsSheet(anime: details, isOled: isOled),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Removed AppBar to allow Carousel to expand to the top
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _SeasonalCarousel(isOled: isOled, onDetails: (id) => _showDetails(context, id)),
              const _SectionHeader(title: "Recently Updated"),
              _HorizontalSwipeRow(sort: "UPDATED_AT_DESC", isOled: isOled, onDetails: (id) => _showDetails(context, id)),
              const _SectionHeader(title: "Trending Movies"),
              _HorizontalSwipeRow(sort: "TRENDING_DESC", isMovie: true, isOled: isOled, onDetails: (id) => _showDetails(context, id)),
              const _SectionHeader(title: "Top Rated"),
              _HorizontalSwipeRow(sort: "SCORE_DESC", isOled: isOled, onDetails: (id) => _showDetails(context, id)),
            ],
          ),
          // Overlay UI for Title and Search over the carousel
          Positioned(
            top: 50, left: 20, right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Explore", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 10)])),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 30),
                  onPressed: onSearchToggle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonalCarousel extends StatefulWidget {
  final bool isOled;
  final Function(int) onDetails;
  const _SeasonalCarousel({required this.isOled, required this.onDetails});

  @override
  State<_SeasonalCarousel> createState() => _SeasonalCarouselState();
}

class _SeasonalCarouselState extends State<_SeasonalCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_controller.hasClients) {
        int next = (_controller.page?.toInt() ?? 0) + 1;
        _controller.animateToPage(next % 5, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: AniListApi.fetchSeasonal(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 350, child: Center(child: CircularProgressIndicator()));
        return SizedBox(
          height: 380, // Taller to expand past the header
          child: PageView.builder(
            controller: _controller,
            itemCount: snap.data!.length,
            itemBuilder: (c, i) {
              final anime = snap.data![i];
              return GestureDetector(
                onTap: () => widget.onDetails(anime['id']),
                child: Stack(
                  children: [
                    // Blurry Background Image
                    if (anime['bannerImage'] != null)
                      Positioned.fill(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Image.network(anime['bannerImage'], fit: BoxFit.cover),
                        ),
                      ),
                    Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter))),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                      child: Row(
                        children: [
                          GlassCard(isOled: widget.isOled, padding: 0, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(anime['coverImage']['large'], width: 120, height: 170, fit: BoxFit.cover))),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(anime['title']['romaji'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), maxLines: 3),
                                const SizedBox(height: 8),
                                Text(anime['genres'].take(2).join(' • '), style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text("Episodes: ${anime['nextAiringEpisode']?['episode'] ?? anime['episodes'] ?? '?'}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// --- RESTORED DESCRIPTION SHEET ---
class _AnimeDetailsSheet extends StatelessWidget {
  final dynamic anime;
  final bool isOled;
  const _AnimeDetailsSheet({required this.anime, required this.isOled});

  @override
  Widget build(BuildContext context) {
    final String cleanDesc = (anime['description'] ?? "").replaceAll(RegExp(r'<[^>]*>'), '');
    final List characters = anime['characters']?['edges'] ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: isOled ? Colors.black : const Color(0xFF1E293B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: ListView(
          controller: scroll,
          children: [
            if (anime['bannerImage'] != null) Image.network(anime['bannerImage'], height: 200, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(anime['title']['romaji'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text("SYNOPSIS", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  Text(cleanDesc, style: const TextStyle(color: Colors.white70, height: 1.5)),
                  const SizedBox(height: 30),
                  const Text("CHARACTERS", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _CharacterList(edges: characters, isOled: isOled),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _CharacterList extends StatelessWidget {
  final List edges;
  final bool isOled;
  const _CharacterList({required this.edges, required this.isOled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: edges.length,
        itemBuilder: (c, i) => Container(
          width: 260,
          margin: const EdgeInsets.only(right: 15),
          child: GlassCard(
            isOled: isOled,
            child: Row(
              children: [
                CircleAvatar(radius: 40, backgroundImage: NetworkImage(edges[i]['node']['image']['large'])),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(edges[i]['node']['name']['full'], 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      // FIX: Check if voiceActors list is not empty before accessing [0]
                      Text(
                        (edges[i]['voiceActors'] != null && edges[i]['voiceActors'].isNotEmpty)
                            ? "VA: ${edges[i]['voiceActors'][0]['name']['full']}"
                            : "VA: Unknown",
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Add the onDetails callback to _HorizontalSwipeRow similarly...
class _HorizontalSwipeRow extends StatelessWidget {
  final String sort;
  final bool isMovie;
  final bool isOled;
  final Function(int) onDetails;
  const _HorizontalSwipeRow({required this.sort, this.isMovie = false, required this.isOled, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: FutureBuilder<List>(
        future: AniListApi.fetchAnimeList(sort: sort, isMovie: isMovie),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: snap.data!.length,
            itemBuilder: (c, i) {
              final anime = snap.data![i];
              return GestureDetector(
                onTap: () => onDetails(anime['id']),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassCard(isOled: isOled, padding: 0, child: Image.network(anime['coverImage']['large'], height: 180, width: 130, fit: BoxFit.cover)),
                      const SizedBox(height: 8),
                      Text(anime['title']['romaji'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(15), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
}
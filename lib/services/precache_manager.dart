import 'anime_service.dart';

class PrecacheManager {
  static final Map<String, AniwatchStreamResult> _cache = {};

  // Unique key based on Anime Name and Episode
  static String _generateKey(String animeName, int episode) => 
      "${animeName.toLowerCase()}_ep$episode";

  // Store a result
  static void addToCache(String animeName, int episode, AniwatchStreamResult result) {
    _cache[_generateKey(animeName, episode)] = result;
  }

  // Retrieve a result
  static AniwatchStreamResult? getFromCache(String animeName, int episode) {
    return _cache[_generateKey(animeName, episode)];
  }

  // Background scraping logic
  static Future<void> cacheEpisode(String animeName, int episode) async {
    // Don't re-scrape if we already have it
    if (getFromCache(animeName, episode) != null) return;

    print("Background Pre-caching: $animeName - Episode $episode");
    final result = await AniwatchService.getStreamLink(animeName, episode);
    if (result != null) {
      addToCache(animeName, episode, result);
    }
  }
}
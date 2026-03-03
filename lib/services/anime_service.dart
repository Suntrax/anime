import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class AniwatchStreamResult {
  final String url;
  final bool isDirectStream;
  final Map<String, String>? headers;
  final String? subtitleUrl;

  AniwatchStreamResult({
    required this.url, 
    required this.isDirectStream, 
    this.headers,
    this.subtitleUrl,
  });
}

class AniwatchService {
  static const String apiBase = "http://YOUR-SERVER/api/v2/hianime";

  static Future<T?> _retry<T>(Future<T> Function() request, {int retries = 3}) async {
    int attempt = 0;
    while (attempt < retries) {
      try {
        return await request().timeout(const Duration(seconds: 10));
      } catch (e) {
        attempt++;
        print("Network attempt $attempt failed: $e");
        if (attempt >= retries) return null;
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return null;
  }

  static Future<AniwatchStreamResult?> getStreamLink(String animeName, int episodeNumber) async {
    // Logic is stored in 'result'
    final result = await _retry(() async {
      print("--- ANIWATCH SCRAPE START: $animeName ---");

      // 1. SEARCH
      final searchRes = await http.get(Uri.parse("$apiBase/search?q=${Uri.encodeComponent(animeName)}"));
      final searchData = jsonDecode(searchRes.body);

      if (searchData['status'] != 200 || searchData['data']['animes'].isEmpty) {
        print("Search failed for: $animeName");
        return null; 
      }

      final List results = searchData['data']['animes'];
      String? animeId;

      for (var result in results) {
        String resultTitle = result['name'].toString().toLowerCase();
        if (resultTitle == animeName.toLowerCase()) {
          animeId = result['id'];
          break;
        }
      }

      animeId ??= results[0]['id'];

      // 2. GET EPISODE LIST
      final epRes = await http.get(Uri.parse("$apiBase/anime/$animeId/episodes"));
      final epData = jsonDecode(epRes.body);
      final List episodes = epData['data']['episodes'];

      final targetEp = episodes.firstWhere(
        (e) => e['number'].toString() == episodeNumber.toString(),
        orElse: () => null,
      );

      if (targetEp == null) return null;
      final String episodeId = targetEp['episodeId'];

      // 3. GET SOURCES (2 Passes, Multi-Server)
      final servers = ['hd-1', 'megacloud', 'hd-2'];
      
      for (int pass = 1; pass <= 2; pass++) {
        print("--- STARTING PASS $pass ---");
        for (String server in servers) {
          print("Trying server: $server");
          final watchUrl = "$apiBase/episode/sources?animeEpisodeId=$episodeId&server=$server&category=sub";
          final watchRes = await http.get(Uri.parse(watchUrl));
          final watchData = jsonDecode(watchRes.body);

          if (watchRes.statusCode == 200 && 
              watchData['status'] == 200 && 
              watchData['data']['sources'] != null && 
              (watchData['data']['sources'] as List).isNotEmpty) {
            
            final data = watchData['data'];
            final String streamUrl = data['sources'][0]['url'];
            
            String? englishSub;
            if (data['tracks'] != null) {
              final List tracks = data['tracks'];
              final targetTrack = tracks.firstWhere(
                (track) => track['lang'] == 'English',
                orElse: () => null,
              );
              englishSub = targetTrack?['url'];
            }

            // Standardized Headers
            Map<String, String> headers = {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
              "Referer": "https://megacloud.tv/",
              "Origin": "https://megacloud.tv/",
            };

            // Override with API headers if provided
            if (data['headers'] != null) {
              final Map<String, dynamic> apiHeaders = data['headers'];
              apiHeaders.forEach((k, v) => headers[k] = v.toString());
            }

            print("Successfully retrieved stream from $server on Pass $pass");
            return AniwatchStreamResult(
              url: streamUrl, 
              isDirectStream: true, 
              headers: headers,
              subtitleUrl: englishSub,
            );
          }
        }
        // Small delay between pass 1 and 2 to allow API to refresh
        if (pass == 1) await Future.delayed(const Duration(seconds: 1));
      }
      print("All servers failed twice for $episodeId");
      return null; 
    });

    return result; // Return the actual result here!
  }
}
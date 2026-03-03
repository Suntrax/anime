import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AniListApi {
  static const String baseUrl = 'https://graphql.anilist.co';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> fetchAnimeDetails(int id) async {
    const query = r'''query ($id: Int) {
      Media(id: $id) {
        id title { romaji } description bannerImage siteUrl
        characters(role: MAIN, sort: [RELEVANCE]) {
          edges {
            node { name { full } image { large } }
            voiceActors(language: JAPANESE) { name { full } image { large } }
          }
        }
      }
    }''';
    final res = await http.post(Uri.parse(baseUrl), 
        headers: await _getHeaders(), 
        body: jsonEncode({'query': query, 'variables': {'id': id}}));
    return jsonDecode(res.body)['data']['Media'];
  }

  static Future<List> fetchAnimeList({required String sort, bool isMovie = false}) async {
    const query = '''query(\$sort: [MediaSort], \$type: MediaType, \$format: MediaFormat){ 
      Page(perPage: 10){ media(sort: \$sort, type: \$type, format: \$format){ 
      id title{ romaji } episodes coverImage{ large } } } }''';
    
    final response = await http.post(Uri.parse(baseUrl), 
      headers: await _getHeaders(), 
      body: jsonEncode({'query': query, 'variables': {
        'sort': [sort], 'type': 'ANIME', 'format': isMovie ? 'MOVIE' : null
      }}));
    return jsonDecode(response.body)['data']['Page']['media'] ?? [];
  }

  static Future<List> fetchSeasonal() async {
    const query = r'''query { Page(perPage: 5) { media(type: ANIME, status: RELEASING, sort: TRENDING_DESC) {
      id title { romaji } bannerImage averageScore genres episodes nextAiringEpisode { episode }
      coverImage { large } siteUrl description
    } } }''';
    final response = await http.post(Uri.parse(baseUrl), 
        headers: await _getHeaders(), body: jsonEncode({'query': query}));
    return jsonDecode(response.body)['data']['Page']['media'] ?? [];
  }

  static Future<List> searchAnime(String search) async {
    const query = r'''query($s: String){ Page{ media(search: $s, type: ANIME){ id title{ romaji } coverImage{ large } episodes } } }''';
    final res = await http.post(Uri.parse(baseUrl), 
        headers: await _getHeaders(), body: jsonEncode({'query': query, 'variables': {'s': search}}));
    return jsonDecode(res.body)['data']['Page']['media'] ?? [];
  }
}
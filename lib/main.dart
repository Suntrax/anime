import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'ui/screens/explore_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/widgets/search_overlay.dart';
import 'ui/widgets/glass_components.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  runApp(const AniApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class AniApp extends StatefulWidget {
  const AniApp({super.key});
  @override
  State<AniApp> createState() => _AniAppState();
}

class _AniAppState extends State<AniApp> {
  bool _isOledMode = false;
  bool _useMaterialYou = false;
  String _selectedPlayer = "better";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isOledMode = prefs.getBool('isOled') ?? false;
      _useMaterialYou = prefs.getBool('useMaterialYou') ?? false;
      _selectedPlayer = prefs.getString('preferred_player') ?? "better";
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: _useMaterialYou,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue, 
        scaffoldBackgroundColor: _isOledMode ? Colors.black : null,
      ),
      home: MainScaffold(
        isOled: _isOledMode,
        useMaterialYou: _useMaterialYou,
        selectedPlayer: _selectedPlayer,
        onSettingsChanged: (oled, mat, player) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isOled', oled);
          await prefs.setBool('useMaterialYou', mat);
          await prefs.setString('preferred_player', player);
          setState(() {
            _isOledMode = oled;
            _useMaterialYou = mat;
            _selectedPlayer = player;
          });
        },
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  final bool isOled;
  final bool useMaterialYou;
  final String selectedPlayer;
  final Function(bool, bool, String) onSettingsChanged;
  
  const MainScaffold({
    super.key, 
    required this.isOled, 
    required this.useMaterialYou, 
    required this.selectedPlayer,
    required this.onSettingsChanged
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late PageController _pageController;
  int _selectedIndex = 1; 
  bool _isSearching = false;
  bool _isInitialChecking = true; // NEW: Track the startup check
  String? _accessToken;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      _accessToken = token;
      await _fetchUserProfile(token);
    }
    setState(() => _isInitialChecking = false);
  }

  Future<void> _login() async {
    await dotenv.load(fileName: ".env");
    final clientId = dotenv.env['API_KEY'];
    const callbackUrlScheme = "animescraper";
    final url = 'https://anilist.co/api/v2/oauth/authorize?client_id=$clientId&response_type=token';

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url, 
        callbackUrlScheme: callbackUrlScheme,
      );
      final fragmentUrl = result.replaceFirst('#', '?');
      final token = Uri.parse(fragmentUrl).queryParameters['access_token'];
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        setState(() {
          _accessToken = token;
          _isInitialChecking = true; // Show loader while fetching new login data
        });
        await _fetchUserProfile(token); 
        setState(() => _isInitialChecking = false);
      }
    } catch (e) {
      debugPrint("Login error: $e");
    }
  }

  Future<void> _fetchUserProfile(String token) async {
    const viewerQuery = 'query { Viewer { name avatar { large } statistics { anime { episodesWatched } } } }';
    try {
      final viewerRes = await http.post(
        Uri.parse('https://graphql.anilist.co'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'query': viewerQuery}),
      );

      if (viewerRes.statusCode == 200) {
        final viewerData = jsonDecode(viewerRes.body)['data']['Viewer'];
        final String name = viewerData['name'];

        final listQuery = '''
          query {
            watching: MediaListCollection(userName: "$name", type: ANIME, status: CURRENT) {
              lists { entries { progress media { id status episodes title { english romaji } coverImage { large } nextAiringEpisode { episode } } } }
            }
            planning: MediaListCollection(userName: "$name", type: ANIME, status: PLANNING) {
              lists { entries { progress media { id status episodes title { english romaji } coverImage { large } nextAiringEpisode { episode } } } }
            }
          }
        ''';

        final listRes = await http.post(
          Uri.parse('https://graphql.anilist.co'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'query': listQuery}),
        );

        if (listRes.statusCode == 200) {
          setState(() {
            _userData = {
              'Viewer': viewerData,
              'watching': jsonDecode(listRes.body)['data']['watching'],
              'planning': jsonDecode(listRes.body)['data']['planning'],
            };
          });
        }
      } else if (viewerRes.statusCode == 401) {
        _logout();
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    setState(() { 
      _accessToken = null; 
      _userData = null; 
    });
    _pageController.jumpToPage(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _selectedIndex = i),
            children: [
              ExploreScreen(onSearchToggle: () => setState(() => _isSearching = true), isOled: widget.isOled),
              HomeScreen(
                userData: _userData, 
                isInitialChecking: _isInitialChecking, // NEW PASS
                onLogin: _login, 
                isOled: widget.isOled,
                selectedPlayer: widget.selectedPlayer,
                onRefresh: () async {
                  if (_accessToken != null) await _fetchUserProfile(_accessToken!);
                },
              ),
              SettingsScreen(
                isLoggedIn: _accessToken != null,
                onLogin: _login,
                isOled: widget.isOled,
                useMaterialYou: widget.useMaterialYou,
                selectedPlayer: widget.selectedPlayer,
                onOledChanged: (v) => widget.onSettingsChanged(v, widget.useMaterialYou, widget.selectedPlayer),
                onMaterialChanged: (v) => widget.onSettingsChanged(widget.isOled, v, widget.selectedPlayer),
                onPlayerChanged: (v) => widget.onSettingsChanged(widget.isOled, widget.useMaterialYou, v),
                onLogout: _logout,
                refresh: () => setState(() {}),
              ),
            ],
          ),
          if (_isSearching) SearchOverlay(onClose: () => setState(() => _isSearching = false), isOled: widget.isOled),
          Align(
            alignment: Alignment.bottomCenter,
            child: _Navbar(currentIndex: _selectedIndex, isOled: widget.isOled, onTap: (i) => _pageController.jumpToPage(i)),
          ),
        ],
      ),
    );
  }
}

class _Navbar extends StatelessWidget {
  final int currentIndex;
  final bool isOled;
  final Function(int) onTap;
  const _Navbar({required this.currentIndex, required this.isOled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(30),
      child: GlassCard(
        isOled: isOled, padding: 5,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(onPressed: () => onTap(0), icon: Icon(Icons.explore, color: currentIndex == 0 ? Colors.blue : Colors.white24)),
            IconButton(onPressed: () => onTap(1), icon: Icon(Icons.home, color: currentIndex == 1 ? Colors.blue : Colors.white24)),
            IconButton(onPressed: () => onTap(2), icon: Icon(Icons.settings, color: currentIndex == 2 ? Colors.blue : Colors.white24)),
          ],
        ),
      ),
    );
  }
}

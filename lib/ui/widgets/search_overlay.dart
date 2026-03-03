import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/anilist_api.dart';
import 'glass_components.dart';

class SearchOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final bool isOled;
  const SearchOverlay({super.key, required this.onClose, required this.isOled});

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  List _results = [];
  Timer? _debounce;

  void _onSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        if (mounted) setState(() => _results = []);
        return;
      }
      
      final results = await AniListApi.searchAnime(query);
      
      // FIX: Check if the user hasn't closed the overlay already
      if (mounted) {
        setState(() => _results = results);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          children: [
            GlassCard(
              isOled: widget.isOled,
              padding: 5,
              child: TextField(
                autofocus: true,
                onChanged: _onSearch,
                textAlign: TextAlign.start, // Align text to start horizontally
                textAlignVertical: TextAlignVertical.center, // Center text vertically
                style: const TextStyle(fontSize: 16, color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search AniList...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.blue),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: widget.onClose,
                  ),
                  border: InputBorder.none,
                  // Content padding is the key to vertical centering
                  contentPadding: const EdgeInsets.symmetric(vertical: 12), 
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (c, i) => ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_results[i]['coverImage']['large'], width: 45, height: 60, fit: BoxFit.cover)),
                  title: Text(_results[i]['title']['romaji'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text("Episodes: ${_results[i]['episodes'] ?? '?'}", style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
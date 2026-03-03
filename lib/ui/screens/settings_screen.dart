import 'package:flutter/material.dart';
import '../widgets/glass_components.dart';

class SettingsScreen extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin, refresh;
  final bool isOled;
  final bool useMaterialYou;
  final String selectedPlayer;
  final Function(bool) onOledChanged;
  final Function(bool) onMaterialChanged;
  final Function(String) onPlayerChanged;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key, 
    required this.isLoggedIn, 
    required this.onLogin, 
    required this.refresh,
    required this.isOled,
    required this.useMaterialYou,
    required this.selectedPlayer,
    required this.onOledChanged,
    required this.onMaterialChanged,
    required this.onPlayerChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      children: [
        const Text("Settings", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 25),
        
        const Text("Appearance", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GlassCard(isOled: isOled, child: Column(
          children: [
            SwitchListTile(
              activeThumbColor: Colors.blue, 
              title: const Text("OLED Mode"), 
              value: isOled, 
              onChanged: onOledChanged,
            ),
            SwitchListTile(
              activeThumbColor: Colors.blue, 
              title: const Text("Material You"), 
              value: useMaterialYou, 
              onChanged: onMaterialChanged,
            ),
          ],
        )),
        
        const SizedBox(height: 25),
        
        const Text("Player Choice", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GlassCard(isOled: isOled, child: Column(
          children: [
            RadioListTile<String>(
              title: const Text("BetterPlayer (Stable)"),
              subtitle: const Text("Rich features: Subtitles & PiP"),
              value: "better",
              groupValue: selectedPlayer,
              onChanged: (v) => onPlayerChanged(v!),
            ),
            RadioListTile<String>(
              title: const Text("Darling Engine (Native)"),
              subtitle: const Text("Powered by ExoPlayer for maximum performance"),
              value: "custom", // Keeping "custom" as value to avoid breaking logic elsewhere
              groupValue: selectedPlayer,
              onChanged: (v) => onPlayerChanged(v!),
            ),
          ],
        )),
        
        const SizedBox(height: 25),
        
        const Text("Account", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GlassCard(isOled: isOled, child: ListTile(
          title: Text(isLoggedIn ? "Log Out" : "Log In to AniList"),
          leading: Icon(isLoggedIn ? Icons.logout : Icons.login, color: Colors.blue),
          onTap: isLoggedIn ? onLogout : onLogin,
        )),
      ],
    );
  }
}
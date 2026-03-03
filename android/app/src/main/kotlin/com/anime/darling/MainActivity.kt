package com.anime.darling

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.media3.common.util.UnstableApi

class MainActivity: FlutterActivity() {
    @OptIn(UnstableApi::class) 
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "exo_player_view", ExoPlayerViewFactory()
        )
    }
}
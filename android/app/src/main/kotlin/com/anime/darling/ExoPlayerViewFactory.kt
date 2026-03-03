package com.anime.darling

import android.content.Context
import androidx.media3.common.util.UnstableApi
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

@UnstableApi
class ExoPlayerViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String, Any?>
        return ExoPlayerView(context, creationParams)
    }
}
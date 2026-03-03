package com.anime.darling

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.util.Log
import android.view.View
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.CaptionStyleCompat
import androidx.media3.ui.PlayerView
import io.flutter.plugin.platform.PlatformView
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import java.util.concurrent.TimeUnit

@UnstableApi
class ExoPlayerView(context: Context, creationParams: Map<String, Any?>) : PlatformView {
    private val playerView: PlayerView = PlayerView(context)
    private val player: ExoPlayer

    // Interceptor to catch and log network-level issues
    class RetryInterceptor(private val maxRetries: Int = 3) : Interceptor {
        override fun intercept(chain: Interceptor.Chain): Response {
            var request = chain.request()
            var response: Response? = null
            var tryCount = 0
            
            while (tryCount < maxRetries) {
                try {
                    response = chain.proceed(request)
                    if (response.isSuccessful) return response
                    // Log failure for debugging
                    Log.w("ExoPlayerNet", "Request failed with code: ${response.code} (Try ${tryCount + 1})")
                } catch (e: Exception) {
                    Log.e("ExoPlayerNet", "Network error: ${e.message}")
                    if (tryCount >= maxRetries - 1) throw e
                }
                tryCount++
                Thread.sleep(1000L * tryCount)
            }
            return response!!
        }
    }

    init {
        val url = creationParams["url"] as String
        val subtitleUrl = creationParams["subtitleUrl"] as? String
        val headers = creationParams["headers"] as? Map<String, String> ?: emptyMap()

        // 1. Build OkHttpClient
        val client = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .addInterceptor(RetryInterceptor())
            .followRedirects(true)
            .followSslRedirects(true)
            .build()

        // 2. Configure DataSource with Headers
        // HLS streams require headers for every segment (.ts) file. 
        // Setting them here ensures they are sent with every internal request.
        val dataSourceFactory = OkHttpDataSource.Factory(client)
        
        if (headers.isNotEmpty()) {
            dataSourceFactory.setDefaultRequestProperties(headers)
        }

        // Apply User-Agent specifically if present, else use default
        val userAgent = headers["User-Agent"] ?: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        dataSourceFactory.setUserAgent(userAgent)

        val mediaSourceFactory = DefaultMediaSourceFactory(context)
            .setDataSourceFactory(dataSourceFactory)

        // 3. Build Player
        player = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()
        
        playerView.player = player

        // 4. Add Detailed Error Listener
        player.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                val cause = error.cause
                Log.e("ExoPlayerView", "CRITICAL ERROR: ${error.errorCodeName} (${error.errorCode})")
                Log.e("ExoPlayerView", "Message: ${error.message}")
                if (cause is java.io.IOException) {
                    Log.e("ExoPlayerView", "Likely a network or header issue.")
                }
            }
        })

        // 5. Setup UI
        setupPlayerUI()

        // 6. Construct MediaItem
        val mediaItemBuilder = MediaItem.Builder()
            .setUri(url)
            .setMimeType(MimeTypes.APPLICATION_M3U8) // Forced as requested

        // 7. Add Subtitles
        if (!subtitleUrl.isNullOrEmpty()) {
            val subMimeType = when {
                subtitleUrl.contains(".vtt") -> MimeTypes.TEXT_VTT
                subtitleUrl.contains(".srt") -> MimeTypes.APPLICATION_SUBRIP
                subtitleUrl.contains(".ass") || subtitleUrl.contains(".ssa") -> MimeTypes.TEXT_SSA
                else -> MimeTypes.TEXT_VTT
            }

            val subtitleConfig = MediaItem.SubtitleConfiguration.Builder(Uri.parse(subtitleUrl))
                .setMimeType(subMimeType)
                .setLanguage("en")
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .build()
            mediaItemBuilder.setSubtitleConfigurations(listOf(subtitleConfig))
        }

        // 8. Prepare & Play
        playerView.visibility = View.VISIBLE
        player.setMediaItem(mediaItemBuilder.build())
        player.prepare()
        player.playWhenReady = true
    }

    private fun setupPlayerUI() {
        playerView.apply {
            setShowSubtitleButton(true)
            setShowVrButton(false)
            setShowNextButton(false)
            setShowPreviousButton(false)
            controllerAutoShow = true
            setControllerShowTimeoutMs(3000)
            
            try {
                val settingsButton = findViewById<View>(androidx.media3.ui.R.id.exo_settings)
                settingsButton?.visibility = View.GONE
            } catch (e: Exception) {}

            subtitleView?.apply {
                setStyle(CaptionStyleCompat(
                    Color.WHITE, Color.TRANSPARENT, Color.TRANSPARENT,
                    CaptionStyleCompat.EDGE_TYPE_OUTLINE, Color.BLACK, null
                ))
                setFractionalTextSize(0.06f)
            }
        }
    }

    override fun getView(): View = playerView

    override fun dispose() {
        player.stop()
        player.release()
    }
}
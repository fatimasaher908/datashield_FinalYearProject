package com.example.datashield_fyp

import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.FrameLayout
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.ui.PlayerView
import io.flutter.plugin.platform.PlatformView

class DataShieldVideoView(
    context: Context,
    private val videoPath: String
) : PlatformView {

    private val playerView: PlayerView
    private val player: ExoPlayer

    init {

        /*
         * Get the normal Android decoders first.
         *
         * Then remove Huawei's problematic hardware decoder:
         *
         * OMX.hisi.video.decoder.avc
         *
         * We prefer Google's software codec if available.
         */
        val softwareCodecSelector =
            MediaCodecSelector { mimeType, requiresSecureDecoder, requiresTunnelingDecoder ->

                MediaCodecSelector.DEFAULT
                    .getDecoderInfos(
                        mimeType,
                        requiresSecureDecoder,
                        requiresTunnelingDecoder
                    )
                    .filter { codecInfo ->

                        val name =
                            codecInfo.name.lowercase()

                        /*
                         * Explicitly reject Huawei HiSilicon AVC decoder.
                         */
                        if (
                            name ==
                            "omx.hisi.video.decoder.avc"
                        ) {
                            false
                        } else {
                            true
                        }
                    }
            }

        val renderersFactory =
            DefaultRenderersFactory(context)
                .setEnableDecoderFallback(true)
                .setMediaCodecSelector(
                    softwareCodecSelector
                )

        player =
            ExoPlayer.Builder(
                context,
                renderersFactory
            )
                .build()

        playerView =
            PlayerView(context).apply {

                useController = true

                player = this@DataShieldVideoView.player

                layoutParams =
                    FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
            }

        val mediaItem =
            MediaItem.fromUri(
                Uri.fromFile(
                    java.io.File(videoPath)
                )
            )

        player.setMediaItem(mediaItem)

        player.prepare()

        player.playWhenReady = true
    }

    override fun getView(): View {
        return playerView
    }

    override fun dispose() {
        player.release()
    }
}
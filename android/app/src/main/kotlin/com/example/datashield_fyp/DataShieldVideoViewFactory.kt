package com.example.datashield_fyp

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class DataShieldVideoViewFactory :
    PlatformViewFactory(
        StandardMessageCodec.INSTANCE
    ) {

    override fun create(
        context: Context,
        viewId: Int,
        args: Any?
    ): PlatformView {

        val videoPath =
            args as? String
                ?: throw IllegalArgumentException(
                    "Video path is missing."
                )

        return DataShieldVideoView(
            context,
            videoPath
        )
    }
}
package com.example.test7

import android.content.Context
import android.view.View
import android.widget.VideoView
import io.flutter.plugin.platform.PlatformView
import io.flutter.embedding.engine.loader.FlutterLoader
import android.net.Uri


class NativeVideoView(context: Context, id: Int, params: Map<String, Any>?) : PlatformView {
    private val videoView: VideoView = VideoView(context)

    init {
        val videoName = params?.get("videoName") as? String ?: "idle.mp4"
        val flutterLoader = FlutterLoader()
        flutterLoader.startInitialization(context)
        flutterLoader.ensureInitializationComplete(context, null)
        val key = flutterLoader.getLookupKeyForAsset("assets/$videoName")
        val assetManager = context.assets
        val assetFileDescriptor = assetManager.openFd(key)
        val uri = Uri.parse("file://" + assetFileDescriptor.fileDescriptor)
        videoView.setVideoURI(uri)
        videoView.setOnCompletionListener {
            videoView.start()
        }
        videoView.start()
    }

    override fun getView(): View {
        return videoView
    }

    override fun dispose() {}
}

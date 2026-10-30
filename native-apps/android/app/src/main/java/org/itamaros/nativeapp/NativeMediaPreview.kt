package org.itamaros.nativeapp

import android.media.MediaPlayer
import android.net.Uri
import android.widget.ImageView
import android.widget.MediaController
import android.widget.VideoView
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView

// Preview a user-selected image, video or audio file. Source URIs come from
// Android's system file/photo pickers; no broad storage permission is requested.
@Composable
fun NativeMediaPreview(uri: Uri) {
    val context = LocalContext.current
    val type = remember(uri) { context.contentResolver.getType(uri).orEmpty() }
    when {
        type.startsWith("image/") -> {
            AndroidView(
                factory = { viewContext ->
                    ImageView(viewContext).apply {
                        adjustViewBounds = true
                        scaleType = ImageView.ScaleType.FIT_CENTER
                        setImageURI(uri)
                        contentDescription = "Selected image"
                    }
                },
                update = { it.setImageURI(uri) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 200.dp)
            )
        }

        type.startsWith("video/") -> {
            val video = remember(uri) { mutableStateOf<VideoView?>(null) }
            AndroidView(
                factory = { viewContext ->
                    VideoView(viewContext).apply {
                        setVideoURI(uri)
                        setMediaController(MediaController(viewContext))
                        setOnPreparedListener { start() }
                        video.value = this
                    }
                },
                modifier = Modifier.fillMaxWidth().heightIn(min = 250.dp)
            )
            DisposableEffect(uri) {
                onDispose { video.value?.stopPlayback() }
            }
        }

        type.startsWith("audio/") -> {
            val player = remember(uri) { MediaPlayer() }
            var isReady by remember(uri) { mutableStateOf(false) }
            var isPlaying by remember(uri) { mutableStateOf(false) }
            var error by remember(uri) { mutableStateOf<String?>(null) }

            DisposableEffect(uri) {
                try {
                    player.setDataSource(context, uri)
                    player.setOnPreparedListener {
                        isReady = true
                        it.start()
                        isPlaying = true
                    }
                    player.setOnCompletionListener { isPlaying = false }
                    player.setOnErrorListener { _, _, _ ->
                        error = "Unable to decode this audio file."
                        true
                    }
                    player.prepareAsync()
                } catch (e: Exception) {
                    error = "Audio playback unavailable: ${e.localizedMessage}"
                }
                onDispose {
                    player.reset()
                    player.release()
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Audio file", style = MaterialTheme.typography.titleLarge)
                if (!isReady && error == null) CircularProgressIndicator()
                if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(enabled = isReady, onClick = {
                        if (isPlaying) player.pause() else player.start()
                        isPlaying = !isPlaying
                    }) { Text(if (isPlaying) "Pause" else "Play") }
                    Button(enabled = isReady, onClick = {
                        player.seekTo(0)
                        player.start()
                        isPlaying = true
                    }) { Text("Restart") }
                }
            }
        }

        else -> Text("Unsupported media format. Choose an image, video or audio file.")
    }
}

package org.itamaros.nativeapp

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext

private tailrec fun Context.hostActivity(): Activity? = when(this) {
    is Activity -> this
    is ContextWrapper -> baseContext.hostActivity()
    else -> null
}

/** Rotate only while Cloud Climb gameplay is visible. Account setup stays flexible. */
@Composable
fun CloudClimbLandscape() {
    val activity=LocalContext.current.hostActivity()
    DisposableEffect(activity) {
        val original=activity?.requestedOrientation
        if(activity!=null) {
            activity.requestedOrientation=ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        }
        onDispose {
            if(activity!=null && original!=null)activity.requestedOrientation=original
        }
    }
}

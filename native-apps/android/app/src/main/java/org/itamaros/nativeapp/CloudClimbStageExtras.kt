package org.itamaros.nativeapp

import android.os.SystemClock
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import kotlin.math.abs
import kotlin.math.sin

/** Deterministic original Cloud Climb stage elements shared by offline and online gameplay.
 * Does not grant coins, worlds or any rewards.
 */
object CloudClimbStageExtras {
    private val patrols = intArrayOf(2, 4)
    private val springs = intArrayOf(1, 5)
    const val CHECKPOINT_INDEX = 3

    fun enemyX(platform: Triple<Float, Float, Float>, index: Int, seconds: Float): Float =
        platform.first + platform.third / 2f +
            sin(seconds * (1.45f + index * .15f) + index) *
            (platform.third * .28f)

    fun danger(px: Float, py: Float, platforms: List<Triple<Float, Float, Float>>,
               seconds: Float): Boolean = patrols.any { index ->
        val p=platforms.getOrNull(index) ?: return@any false
        abs(px-enemyX(p,index,seconds)) < 16f && abs(py-(p.second-10f)) < 17f
    }

    fun spring(platformIndex: Int, playerX: Float,
               platform: Triple<Float,Float,Float>): Boolean =
        platformIndex in springs &&
            abs(playerX-(platform.first+platform.third*.22f)) < 18f

    fun isCheckpoint(index: Int): Boolean = index == CHECKPOINT_INDEX

    fun DrawScope.render(platforms: List<Triple<Float,Float,Float>>,
                         sx: Float, sy: Float, seconds: Float, checkpointActive: Boolean) {
        for(index in springs) {
            val p=platforms.getOrNull(index) ?: continue
            val x=(p.first+p.third*.22f)*sx
            drawRoundRect(Color(0xFFFFD66D),
                topLeft=Offset(x-15f*sx,(p.second-9f)*sy),
                size=Size(30f*sx,9f*sy))
            drawCircle(Color(0xFFFF5B93),5f*sx,Offset(x,(p.second-13f)*sy))
        }
        platforms.getOrNull(CHECKPOINT_INDEX)?.let { p ->
            val x=(p.first+p.third/2f)*sx
            drawLine(Color(0xFFDAF7FF),Offset(x,(p.second-42f)*sy),
                Offset(x,(p.second-4f)*sy),strokeWidth=3f*sx)
            drawCircle(if(checkpointActive)Color(0xFF63FFC8) else Color(0xFFFFE58D),
                radius=11f*sx,center=Offset(x,(p.second-37f)*sy))
        }
        for(index in patrols) {
            val p=platforms.getOrNull(index) ?: continue
            val x=enemyX(p,index,seconds)*sx
            val y=(p.second-13f)*sy
            drawCircle(Color(0xFF723EEB),radius=13f*sx,center=Offset(x,y))
            drawCircle(Color(0xFFFEFEFF),radius=4f*sx,center=Offset(x-4f*sx,y-2f*sy))
            drawCircle(Color(0xFFFEFEFF),radius=4f*sx,center=Offset(x+4f*sx,y-2f*sy))
            drawCircle(Color(0xFF192452),radius=2f*sx,center=Offset(x-4f*sx,y-2f*sy))
            drawCircle(Color(0xFF192452),radius=2f*sx,center=Offset(x+4f*sx,y-2f*sy))
        }
    }

    fun timeSeconds(): Float = SystemClock.elapsedRealtime()/1000f
}

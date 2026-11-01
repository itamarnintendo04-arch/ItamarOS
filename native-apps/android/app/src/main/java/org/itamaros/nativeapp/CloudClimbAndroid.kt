package org.itamaros.nativeapp

import android.content.Context
import android.os.SystemClock
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import org.json.JSONObject
import kotlin.math.abs

/**
 * Original Cloud Climb platformer prototype. Progress is saved on this device,
 * per signed-in account, not synced to Supabase or to other players.
 */
@Composable
fun CloudClimbAndroid(api: AndroidConnectApi, match: JSONObject?, slot: Int, onExit: () -> Unit) {
    val room = match?.optString("code").orEmpty()
    val roomSeed = match?.optInt("seed") ?: 0
    val context = LocalContext.current
    val accountKey = "cloud_climb_v1_" + (api.userID?.toString() ?: "guest")
    val prefs = remember(accountKey) {
        context.getSharedPreferences(accountKey, Context.MODE_PRIVATE)
    }
    var level by remember(accountKey) { mutableIntStateOf(prefs.getInt("level", 1).coerceAtLeast(1)) }
    var coins by remember(accountKey) { mutableIntStateOf(prefs.getInt("coins", 0).coerceAtLeast(0)) }
    var hearts by remember(accountKey) { mutableIntStateOf(prefs.getInt("hearts", 3).coerceIn(0, 3)) }
    var bossHealth by remember(accountKey) { mutableIntStateOf(prefs.getInt("boss_health", 3).coerceIn(1, 3)) }
    var shopDue by remember(accountKey) { mutableIntStateOf(prefs.getInt("shop_due", 0).coerceAtLeast(0)) }
    var gameOver by remember(accountKey) { mutableStateOf(prefs.getBoolean("game_over", false) || hearts == 0) }
    var paused by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    var px by remember { mutableFloatStateOf(48f) }
    var py by remember { mutableFloatStateOf(430f) }
    var vy by remember { mutableFloatStateOf(0f) }
    var landed by remember { mutableStateOf(true) }
    var left by remember { mutableStateOf(false) }
    var right by remember { mutableStateOf(false) }
    var jump by remember { mutableStateOf(false) }
    var lastBossHit by remember { mutableLongStateOf(0L) }
    val seed = roomSeed xor (level * 2039)
    val platforms = remember(seed) { cloudStages(seed) }
    val bossX = platforms.last().first + platforms.last().third / 2f
    val bossStage = level % 30 == 0

    // Save after each meaningful change and on room exit; no manual save required.
    LaunchedEffect(accountKey, level, coins, hearts, bossHealth, shopDue, gameOver) {
        prefs.edit()
            .putInt("level", level).putInt("coins", coins).putInt("hearts", hearts)
            .putInt("boss_health", bossHealth).putInt("shop_due", shopDue)
            .putBoolean("game_over", gameOver).apply()
    }
    fun resetPosition() {
        px = 48f; py = 430f; vy = 0f; landed = true
        jump = false; left = false; right = false
    }
    fun advanceStage() {
        val completed = level
        coins += 10
        level += 1
        bossHealth = 3
        shopDue = if (completed % 10 == 0 && hearts < 3) completed else 0
        message = "Level " + completed + " complete! +10 coins."
        resetPosition()
    }
    fun loseHeart() {
        hearts = (hearts - 1).coerceAtLeast(0)
        resetPosition()
        if (hearts == 0) {
            gameOver = true
            message = "No hearts left. Try again from level " + level + "."
        } else message = "You fell! " + hearts + " hearts remaining."
    }
    DisposableEffect(room) {
        ItamarGamepad.enabled = true
        onDispose { ItamarGamepad.reset() }
    }
    LaunchedEffect(room, slot, level, paused, shopDue, gameOver) {
        if (room.isBlank() || slot == 0 || paused || shopDue != 0 || gameOver) return@LaunchedEffect
        var lastSent = 0L
        while (true) {
            delay(33)
            val dir = ((if (left) -1f else 0f) + (if (right) 1f else 0f) +
                ItamarGamepad.axis + (if (ItamarGamepad.left) -1f else 0f) +
                (if (ItamarGamepad.right) 1f else 0f)).coerceIn(-1f, 1f)
            px = (px + dir * 3.2f).coerceIn(12f, 388f)
            if ((jump || ItamarGamepad.jump) && landed) { vy = -9f; landed = false }
            jump = false
            val previousBottom = py + 3f
            vy = (vy + 0.38f).coerceAtMost(10f)
            py += vy
            if (vy >= 0f) {
                landed = false
                for (platform in platforms) {
                    if (px + 11f > platform.first && px - 11f < platform.first + platform.third &&
                        previousBottom <= platform.second && py + 3f >= platform.second) {
                        py = platform.second - 3f
                        vy = 0f; landed = true
                        break
                    }
                }
            }
            if (py > 495f) { loseHeart(); continue }
            if (landed && py < 110f && !bossStage) { advanceStage(); continue }
            val time = SystemClock.elapsedRealtime()
            if (time - lastSent > 650L) {
                lastSent = time
                try {
                    api.request("/rest/v1/rpc/itamar_party_position", "POST",
                        JSONObject().put("p_code", room)
                            .put("p_x", px.toDouble() * 1024 / 400)
                            .put("p_y", py.toDouble() * 2048 / 500))
                } catch (_: Exception) {}
            }
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Cloud Climb · Level " + level,
            style = MaterialTheme.typography.titleMedium)
        Text("❤️ " + hearts + "/3    🪙 " + coins +
            if (bossStage) "    Boss: " + bossHealth + "/3" else "")
        Text("Complete the top platform to clear a level. Boss every 30 levels. +10 coins per clear.")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { paused = !paused; left = false; right = false },
                enabled = !gameOver && shopDue == 0) {
                Text(if (paused) "Resume" else "Pause")
            }
            OutlinedButton(onClick = onExit) { Text("Exit to menu") }
        }
        if (gameOver) {
            Text(message)
            Button(onClick = {
                hearts = 3; bossHealth = 3; gameOver = false
                message = "Retry level " + level
                resetPosition()
            }) { Text("Try again") }
        } else if (shopDue != 0) {
            Text("Level " + shopDue + " cleared! Buy 1 missing heart for 100 coins?")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = {
                    if (coins >= 100 && hearts < 3) {
                        coins -= 100; hearts += 1
                        message = "1 heart restored."
                        shopDue = 0
                    }
                }, enabled = coins >= 100 && hearts < 3) {
                    Text("Buy heart · 100 🪙")
                }
                OutlinedButton(onClick = { shopDue = 0 }) { Text("Skip") }
            }
        } else if (paused) {
            Text("Paused. Your progress is saved.")
            Button(onClick = { paused = false }) { Text("Resume") }
            Button(onClick = onExit) { Text("Exit to menu") }
        } else {
            Canvas(modifier = Modifier.fillMaxWidth().aspectRatio(4f / 5f)) {
                val sx = size.width / 400f; val sy = size.height / 500f
                drawRect(Color(0xFF25377D))
                platforms.forEachIndexed { index, platform ->
                    drawRoundRect(
                        color = if (index == 0) Color(0xFF4BE4BE) else Color(0xFFC0E9FF),
                        topLeft = Offset(platform.first * sx, platform.second * sy),
                        size = Size(platform.third * sx, 12f * sy),
                        cornerRadius = CornerRadius(5f))
                }
                if (bossStage) {
                    drawCircle(Color(0xFFAF4EF2), 21f * sx, Offset(bossX * sx, 65f * sy))
                    drawCircle(Color.White, 6f * sx, Offset(bossX * sx, 63f * sy))
                }
                val colors = listOf(Color(0xFFFFA43A), Color(0xFFFF79A5),
                    Color(0xFF61F4E0), Color(0xFFFFE172))
                val positions = match?.optJSONObject("positions")
                for (id in 1..4) {
                    val remote = positions?.optJSONObject(id.toString())
                    val x = if (id == slot) px else remote?.optDouble("x")?.toFloat()?.times(400f / 1024f)
                    val y = if (id == slot) py else remote?.optDouble("y")?.toFloat()?.times(500f / 2048f)
                    if (x != null && y != null) {
                        drawRoundRect(color = colors[id - 1],
                            topLeft = Offset((x - 12) * sx, (y - 22) * sy),
                            size = Size(24f * sx, 24f * sy), cornerRadius = CornerRadius(5f))
                    }
                }
            }
            if (bossStage) {
                Button(onClick = {
                    val now = SystemClock.elapsedRealtime()
                    if (landed && py < 115f && abs(px - bossX) < 85f &&
                        now - lastBossHit >= 900L) {
                        lastBossHit = now
                        if (bossHealth == 1) advanceStage() else bossHealth -= 1
                    }
                }, enabled = landed && py < 115f && abs(px - bossX) < 85f) {
                    Text("Strike boss (3 hits)")
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TextButton(onClick = {}) { Text("◀", modifier = Modifier.pointerInput(Unit) {
                    detectTapGestures(onPress = { left = true; tryAwaitRelease(); left = false })
                }) }
                TextButton(onClick = {}) { Text("▶", modifier = Modifier.pointerInput(Unit) {
                    detectTapGestures(onPress = { right = true; tryAwaitRelease(); right = false })
                }) }
                Button(onClick = { jump = true }) { Text("Jump") }
            }
        }
        if (message.isNotEmpty() && !gameOver) Text(message, style = MaterialTheme.typography.bodySmall)
        Text("On-device save by account. Online positions are experimental, not cross-device save sync.",
            style = MaterialTheme.typography.bodySmall)
    }
}
private fun cloudStages(seed: Int): List<Triple<Float, Float, Float>> {
    var state = seed.toLong() and 0xffffffffL
    fun next(): Float {
        state = state * 6364136223846793005L + 1442695040888963407L
        return ((state ushr 32) % 1000).toFloat() / 1000f
    }
    val result = mutableListOf(Triple(0f, 472f, 400f))
    repeat(6) { row ->
        val x = 16f + next() * 205f
        result.add(Triple(x, 405f - row * 61f, 130f + next() * 40f))
    }
    return result
}

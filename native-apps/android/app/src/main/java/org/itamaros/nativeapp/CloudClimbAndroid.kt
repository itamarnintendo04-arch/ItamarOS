package org.itamaros.nativeapp

import android.content.Context
import android.os.SystemClock
import android.view.InputDevice
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.Alignment
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
    var controllerConnected by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }
    var autoHideControls by remember(accountKey) {
        mutableStateOf(prefs.getBoolean("auto_hide_controls", true))
    }
    var showControlHints by remember(accountKey) {
        mutableStateOf(prefs.getBoolean("show_control_hints", true))
    }
    var nightSky by remember(accountKey) {
        mutableStateOf(prefs.getBoolean("night_sky", false))
    }
    var syncReady by remember(accountKey) { mutableStateOf(false) }
    var syncRevision by remember(accountKey) { mutableLongStateOf(0L) }
    var syncRefresh by remember(accountKey) { mutableIntStateOf(0) }
    var syncStatus by remember(accountKey) { mutableStateOf("Local save") }
    val showTouchControls = !(autoHideControls && controllerConnected)
    val darkBackground = if (nightSky) Color(0xFF151438) else Color(0xFF1C427D)
    val lightBackground = if (nightSky) Color(0xFF423064) else Color(0xFF4AAFD4)
    val goldAccent = Color(0xFFFFD57C)

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
    LaunchedEffect(accountKey, syncRefresh) {
        syncReady = false
        if (api.userID.isNullOrBlank()) {
            syncStatus = "Local save · Sign in with verified SMS to sync"
            return@LaunchedEffect
        }
        try {
            val remote = JSONObject(api.request("/rest/v1/rpc/itamar_cloud_climb_state", "POST", JSONObject()))
            if (remote.optBoolean("exists", false)) {
                level = remote.optInt("level", 1).coerceAtLeast(1)
                coins = remote.optInt("coins", 0).coerceAtLeast(0)
                hearts = remote.optInt("hearts", 3).coerceIn(0, 3)
                bossHealth = remote.optInt("boss_health", 3).coerceIn(1, 3)
                shopDue = remote.optInt("shop_due", 0).coerceAtLeast(0)
                gameOver = remote.optBoolean("game_over", false)
            }
            syncRevision = remote.optLong("revision", 0L)
            syncStatus = "Cloud save connected · Same verified phone, same account"
            syncReady = true
        } catch (_: Exception) {
            syncStatus = "Local save · Cloud sync unavailable"
        }
    }
    LaunchedEffect(accountKey, level, coins, hearts, bossHealth, shopDue, gameOver, syncReady) {
        if (!syncReady) return@LaunchedEffect
        delay(350)
        try {
            val response = JSONObject(api.request("/rest/v1/rpc/itamar_cloud_climb_save",
                "POST", JSONObject()
                    .put("p_level", level).put("p_coins", coins).put("p_hearts", hearts)
                    .put("p_boss_health", bossHealth).put("p_shop_due", shopDue)
                    .put("p_game_over", gameOver).put("p_revision", syncRevision)))
            if (response.optBoolean("saved")) {
                syncRevision = response.optLong("revision", syncRevision)
                syncStatus = "Cloud progress saved to your account"
            } else {
                syncStatus = "Updated on another device · Reloading cloud save"
                syncReady = false
                syncRefresh += 1
            }
        } catch (_: Exception) {
            syncStatus = "Local save · Cloud sync will retry on next update"
        }
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
    LaunchedEffect(room) {
        while (true) {
            controllerConnected = InputDevice.getDeviceIds().any { id ->
                InputDevice.getDevice(id)?.let { device ->
                    device.sources and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD ||
                    device.sources and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK
                } ?: false
            }
            delay(750)
        }
    }
    LaunchedEffect(room) {
        var previous = false
        while (true) {
            val isPressed = ItamarGamepad.pause
            if (isPressed && !previous && !gameOver && shopDue == 0) {
                paused = !paused
                left = false; right = false; jump = false
            }
            previous = isPressed
            delay(70)
        }
    }
    DisposableEffect(room) {
        ItamarGamepad.enabled = true
        onDispose { ItamarGamepad.reset() }
    }
    fun strikeBoss() {
        val now = SystemClock.elapsedRealtime()
        if (bossStage && !paused && !gameOver && shopDue == 0 &&
            landed && py < 115f && abs(px - bossX) < 85f &&
            now - lastBossHit >= 900L) {
            lastBossHit = now
            if (bossHealth == 1) advanceStage() else bossHealth -= 1
        }
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
            if (ItamarGamepad.attack) strikeBoss()
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

    Column(
        modifier = Modifier.fillMaxWidth()
            .background(Brush.verticalGradient(listOf(darkBackground, lightBackground)), RoundedCornerShape(24.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("☁  CLOUD CLIMB", color = Color.White, style = MaterialTheme.typography.headlineMedium)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("LEVEL " + level, color = goldAccent, style = MaterialTheme.typography.titleLarge)
            Spacer(Modifier.weight(1f))
            Text("❤️ " + hearts + "/3  🪙 " + coins, color = Color.White)
        }
        if (bossStage) Text("BOSS ENCOUNTER · " + bossHealth + "/3",
            color = goldAccent, style = MaterialTheme.typography.titleMedium)
        if (showControlHints) Text(
            "Reach the top platform. Earn 10 coins per stage · Boss every 30 levels.",
            color = Color.White.copy(alpha = 0.9f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { settingsOpen = true },
                colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.White)) { Text("⚙ Settings") }
            OutlinedButton(onClick = { paused = !paused; left = false; right = false },
                enabled = !gameOver && shopDue == 0) {
                Text(if (paused) "Resume" else "Pause")
            }
            OutlinedButton(onClick = onExit,
                colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.White)) {
                Text("Exit to Menu")
            }
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
                drawRect(brush = Brush.verticalGradient(listOf(darkBackground, lightBackground)))
                repeat(12) { i ->
                    val x = (((i * 127 + 31) % 389) + 5) * sx
                    val y = (((i * 83 + 51) % 420) + 10) * sy
                    drawCircle(Color.White.copy(alpha = if (nightSky) 0.55f else 0.23f),
                        radius = (if (nightSky) 2f else 9f) * sx,
                        center = Offset(x, y))
                }
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
            if (bossStage && showTouchControls) {
                Button(onClick = { strikeBoss() },
                    enabled = landed && py < 115f && abs(px - bossX) < 85f) {
                    Text("Strike Boss")
                }
            }
            if (showTouchControls) Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
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
        Text(
            if (controllerConnected) "🎮 Controller connected · A: Jump · X: Attack · Start: Pause"
            else if (showControlHints) "Touch controls · Connect a controller to hide them automatically."
            else "",
            color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodySmall)
        Text(syncStatus, color = goldAccent, style = MaterialTheme.typography.bodySmall)
        if (settingsOpen) AlertDialog(
            onDismissRequest = { settingsOpen = false },
            title = { Text("Cloud Climb Settings") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Auto-hide touch controls", modifier = Modifier.weight(1f))
                        Switch(checked = autoHideControls, onCheckedChange = {
                            autoHideControls = it; prefs.edit().putBoolean("auto_hide_controls", it).apply()
                        })
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Show control tips", modifier = Modifier.weight(1f))
                        Switch(checked = showControlHints, onCheckedChange = {
                            showControlHints = it; prefs.edit().putBoolean("show_control_hints", it).apply()
                        })
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Twilight sky theme", modifier = Modifier.weight(1f))
                        Switch(checked = nightSky, onCheckedChange = {
                            nightSky = it; prefs.edit().putBoolean("night_sky", it).apply()
                        })
                    }
                    Text("Account: verified phone SMS sign-in through ItamarOS Connect.")
                    Text("Progress: " + syncStatus)
                }
            },
            confirmButton = { TextButton(onClick = { settingsOpen = false }) { Text("Done") } }
        )
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

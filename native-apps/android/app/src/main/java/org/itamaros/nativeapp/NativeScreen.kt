package org.itamaros.nativeapp

import android.os.Build
import android.net.Uri
import android.widget.VideoView
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.runtime.key
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import java.util.Locale
import java.util.TimeZone
import kotlin.random.Random

private data class Service(val name: String, val region: String? = null, val pkg: String? = null)

private val services = listOf(
    Service("Netflix", pkg = "com.netflix.ninja"),
    Service("Disney+", pkg = "com.disney.disneyplus"),
    Service("Apple TV"),
    Service("YouTube", pkg = "com.google.android.youtube.tv"),
    Service("Prime Video", pkg = "com.amazon.amazonvideo.livingroom"),
    Service("כאן BOX", region = "IL"),
    Service("yes+", region = "IL"),
    Service("HOT", region = "IL"),
    Service("Hulu", region = "US"),
    Service("Peacock", region = "US")
)

private fun country(): String {
    val zone = TimeZone.getDefault().id
    if (zone == "Asia/Jerusalem" || zone == "Asia/Tel_Aviv") return "IL"
    return Locale.getDefault().country.ifBlank { "Unknown" }
}

@Composable
fun NativeAppScreen(
    isTv: Boolean,
    device: String,
    status: String,
    updateStatus: String,
    bestScore: Int,
    selectedMedia: Uri?,
    onCheckUpdates: () -> Unit,
    onLaunchService: (String?, String) -> Unit,
    onChooseUSB: () -> Unit,
    onExport: () -> Unit,
    onStorageSettings: () -> Unit,
    onChooseMedia: () -> Unit,
    onSaveScore: (Int) -> Unit
) {
    var current by remember { mutableStateOf("Home") }
    val tabs = if (isTv) listOf("Home", "Games", "Streaming", "Settings")
        else listOf("Home", "Games", "Player", "Settings")
    Scaffold { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            Row(modifier = Modifier.fillMaxWidth().padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                tabs.forEach { tab ->
                    FilledTonalButton(onClick = { current = tab }, modifier = Modifier.weight(1f)) {
                        Text(tab, maxLines = 1)
                    }
                }
            }
            HorizontalDivider()
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(22.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                when (current) {
                    "Home" -> item {
                        Column(horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.fillMaxWidth()) {
                            Icon(
                                painter = painterResource(R.drawable.itamaros_logo),
                                contentDescription = "ItamarOS logo",
                                modifier = Modifier.size(126.dp)
                            )
                            Text("ItamarOS 1.1", style = MaterialTheme.typography.headlineLarge)
                            Text("Native Android application • Not a WebView", color = MaterialTheme.colorScheme.secondary)
                            Text("Device: $device", modifier = Modifier.padding(top = 14.dp))
                            Text(if (isTv) "Android TV / Google TV" else "Android phone or tablet")
                            Text("This application does not replace Android or a TV operating system.",
                                modifier = Modifier.padding(top = 20.dp))
                            Text("Privacy: no GPS permission; local game score remains on this device.")
                        }
                    }
                    "Games" -> item {
                        NativeGuessGame(bestScore, onSaveScore)
                    }
                    "Player" -> item {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            Text("Native media", style = MaterialTheme.typography.headlineMedium)
                            Text("Local playback uses Android VideoView and the system MediaPlayer engine, not a website.")
                            if (selectedMedia != null) {
                                key(selectedMedia) {
                                    AndroidView(
                                        factory = { context ->
                                            VideoView(context).apply {
                                                setVideoURI(selectedMedia)
                                                setMediaController(android.widget.MediaController(context))
                                                setOnPreparedListener { start() }
                                            }
                                        },
                                        modifier = Modifier.fillMaxWidth().heightIn(min = 260.dp)
                                    )
                                }
                            }
                            Button(onClick = onChooseMedia) { Text("Choose local audio/video") }
                        }
                    }
                    "Streaming" -> if (isTv) item {
                        TVServiceScreen(onLaunchService)
                    }
                    "Settings" -> item {
                        NativeSettings(isTv, device, status, updateStatus,
                            onCheckUpdates, onChooseUSB, onExport, onStorageSettings)
                    }
                }
            }
        }
    }
}

@Composable
private fun NativeGuessGame(bestScore: Int, onSaveScore: (Int) -> Unit) {
    var target by remember { mutableIntStateOf(Random.nextInt(1, 21)) }
    var guess by remember { mutableIntStateOf(10) }
    var current by remember { mutableIntStateOf(0) }
    var message by remember { mutableStateOf("Guess a number from 1 to 20.") }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Number Guess", style = MaterialTheme.typography.headlineMedium)
        Text(message)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Button(onClick = { guess = (guess - 1).coerceAtLeast(1) }) { Text("−") }
            Text("$guess", style = MaterialTheme.typography.headlineMedium)
            Button(onClick = { guess = (guess + 1).coerceAtMost(20) }) { Text("+") }
        }
        Button(onClick = {
            if (guess == target) {
                current += 1
                onSaveScore(maxOf(bestScore, current))
                target = Random.nextInt(1, 21)
                message = "Correct! A new number has been selected."
            } else message = if (guess < target) "Higher!" else "Lower!"
        }) { Text("Submit guess") }
        Text("Score: $current · Best saved score: $bestScore")
        Text("Your best score is stored with Android SharedPreferences, not in a browser.")
    }
}

@Composable
private fun TVServiceScreen(onLaunchService: (String?, String) -> Unit) {
    val detected = remember { country() }
    var selectedRegion by remember { mutableStateOf(detected) }
    val available = services.filter { it.region == null || it.region == selectedRegion }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("TV Streaming", style = MaterialTheme.typography.headlineMedium)
        Text("Country: $selectedRegion · Estimated from time zone / device region, not GPS.")
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            listOf("IL", "US", "Other").forEach { c ->
                Button(onClick = { selectedRegion = c }) { Text(c) }
            }
        }
        available.forEach { service ->
            FilledTonalButton(
                onClick = { onLaunchService(service.pkg, service.name) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 60.dp)
            ) { Text(service.name) }
        }
        Text("Native launch is possible only when the official app is installed and visible to this device. Unknown packages are not guessed.")
    }
}

@Composable
private fun NativeSettings(
    isTv: Boolean,
    device: String,
    status: String,
    updates: String,
    check: () -> Unit,
    chooseUSB: () -> Unit,
    export: () -> Unit,
    storageSettings: () -> Unit
) {
    var largeText by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Settings", style = MaterialTheme.typography.headlineMedium)
        Text("System & device", fontWeight = FontWeight.Bold)
        Text("Manufacturer and model: $device")
        Text("Android version: ${Build.VERSION.RELEASE}")
        Text("Release information: $updates")
        Button(onClick = check) { Text("Check for app updates") }
        HorizontalDivider()
        Text("Accessibility", fontWeight = FontWeight.Bold)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Large text preference", modifier = Modifier.weight(1f))
            Switch(checked = largeText, onCheckedChange = { largeText = it })
        }
        HorizontalDivider()
        Text("Storage & USB", fontWeight = FontWeight.Bold)
        if (isTv) {
            Text("Choose a folder on USB/SD to export your own app data. If the TV allows app movement, Android system app settings may offer 'Move to SD/USB'. This app cannot force its own installation location.")
        } else {
            Text("Choose any document-provider folder, including a supported USB device, to export app data.")
        }
        Button(onClick = chooseUSB) { Text("Choose external storage folder") }
        Button(onClick = export) { Text("Export app data to selected folder") }
        Button(onClick = storageSettings) { Text("Open Android app storage settings") }
        Text(status, color = MaterialTheme.colorScheme.secondary)
        HorizontalDivider()
        Text("Network, Wi-Fi, Bluetooth, audio, permissions, and system updates must be changed through Android Settings.")
        Text("No universal TV USB operating-system installer exists. This is an app, not Android firmware.")
    }
}

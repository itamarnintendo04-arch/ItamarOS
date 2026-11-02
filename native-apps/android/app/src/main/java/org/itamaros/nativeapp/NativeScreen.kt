package org.itamaros.nativeapp

import android.os.Build
import android.net.Uri
import android.content.Context
import androidx.compose.ui.platform.LocalContext
import android.widget.VideoView
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.runtime.key
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.foundation.background
import androidx.compose.ui.graphics.Brush
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Settings
import androidx.compose.ui.unit.sp
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
    groupInvite: String?,
    contactUsername: String?,
    desktopRequest: String?,
    cloudClimbRequest: String?,
    device: String,
    status: String,
    updateStatus: String,
    updateDownloadAvailable: Boolean,
    onDownloadUpdate: () -> Unit,
    downloadState: ItamarApkUpdate.Snapshot,
    onInstallDownloadedUpdate: () -> Unit,
    onSetAutoDownloadUpdates: (Boolean) -> Unit,
    bestScore: Int,
    selectedMedia: Uri?,
    selectedApkName: String?,
    onCheckUpdates: () -> Unit,
    onEnableUpdateAlerts: () -> Unit,
    onSetAutoUpdateChecks: (Boolean) -> Unit,
    onLaunchService: (String?, String) -> Unit,
    onOpenStoreListing: (String) -> Unit,
    onBrowseStore: () -> Unit,
    onChooseUSB: () -> Unit,
    onExport: () -> Unit,
    onStorageSettings: () -> Unit,
    onChooseMedia: () -> Unit,
    onChoosePhotos: () -> Unit,
    onChooseApk: () -> Unit,
    onInstallApk: () -> Unit,
    onSaveScore: (Int) -> Unit
) {
    var current by remember { mutableStateOf("Home") }
    val accountApi=remember { AndroidConnectApi() }
    var accountUsername by remember { mutableStateOf<String?>(null) }
    if(accountUsername==null) {
        Column(
            modifier=Modifier.fillMaxSize().background(Brush.verticalGradient(
                listOf(ItamarColors.midnight,ItamarColors.navy,ItamarColors.midnight)))
                .verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement=Arrangement.spacedBy(12.dp)
        ){
            ItamarHeroCard(isTv,device)
            Text("Welcome to ItamarOS",style=MaterialTheme.typography.headlineMedium)
            Text("Your account keeps your apps and games connected across devices.")
            AndroidConnectScreen(
                api=accountApi,authOnly=true,
                cloudClimbRequest=cloudClimbRequest,
                onAccountReady={ accountUsername=it }
            )
        }
        return
    }
    LaunchedEffect(groupInvite, contactUsername, desktopRequest, cloudClimbRequest) {
        if (!isTv && (groupInvite != null || contactUsername != null ||
            desktopRequest != null || cloudClimbRequest != null)) current = "Connect"
    }
    val tabs = if (isTv) listOf("Home", "Store", "Streaming", "Settings")
        else listOf("Home", "Connect", "Games", "Player", "Apps", "Settings")
    // Bottom tab bar on phones/tablets; top D-pad controls remain on TV.
    Scaffold(bottomBar = {
        if (!isTv) {
            NavigationBar(containerColor=ItamarColors.midnight,tonalElevation = 3.dp) {
                tabs.forEach { tab ->
                    val symbol = when(tab) {
                        "Connect" -> Icons.Filled.Chat
                        "Games" -> Icons.Filled.SportsEsports
                        "Player" -> Icons.Filled.PlayCircle
                        "Apps" -> Icons.Filled.Apps
                        "Settings" -> Icons.Filled.Settings
                        else -> Icons.Filled.Home
                    }
                    NavigationBarItem(
                        selected = current == tab,
                        onClick = { current = tab },
                        icon = { ItamarAppTabIcon(tab,current==tab) },
                        label = { Text(AndroidLanguage.tab(tab), fontSize = 10.sp,
                            maxLines = 1, softWrap = false) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor=ItamarColors.cyan,
                            selectedTextColor=ItamarColors.cyan,
                            unselectedTextColor=ItamarColors.muted,
                            indicatorColor=ItamarColors.navy),
                        alwaysShowLabel = true
                    )
                }
            }
        }
    }) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)
            .background(Brush.verticalGradient(listOf(
                ItamarColors.midnight, ItamarColors.navy,ItamarColors.midnight)))) {
            if (isTv) {
                Row(modifier = Modifier.fillMaxWidth().padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    tabs.forEach { tab ->
                        FilledTonalButton(onClick = { current = tab },
                            modifier = Modifier.weight(1f)) {
                            Text(AndroidLanguage.tab(tab), maxLines = 1)
                        }
                    }
                }
                HorizontalDivider()
            }
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(22.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                when (current) {
                    "Home" -> item {
                        Column(modifier=Modifier.fillMaxWidth(),
                            verticalArrangement=Arrangement.spacedBy(16.dp)) {
                            ItamarHeroCard(isTv,device)
                            Text("Version 1.7 · Native Android",color=ItamarColors.muted,
                                style=MaterialTheme.typography.titleSmall)
                            Text("Connect with friends, play native games and enjoy your media.",
                                color=MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("This app does not replace Android. Your local game score stays on this device.",
                                color=ItamarColors.muted,style=MaterialTheme.typography.bodySmall)
                        }
                    }
                    "Connect" -> if (!isTv) item {
                        AndroidConnectScreen(api=accountApi,groupInvite = groupInvite, contactUsername = contactUsername, desktopRequest = desktopRequest, cloudClimbRequest=cloudClimbRequest, onSignOut={accountUsername=null})
                    }
                    "Games" -> item {
                        MobileGamesHub(accountApi)
                    }
                    "Store" -> if (isTv) item {
                        TVStoreScreen(status, onOpenStoreListing, onBrowseStore)
                    }
                    "Player" -> item {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            Text("ItamarOS Player", style = MaterialTheme.typography.headlineMedium)
                            Text("Preview images, watch videos and play audio from your device.")
                            if (selectedMedia != null) {
                                key(selectedMedia) { NativeMediaPreview(selectedMedia) }
                            }
                            Button(onClick = onChooseMedia) {
                                Text("Choose image, video or audio from Files")
                            }
                            if (!isTv) {
                                Button(onClick = onChoosePhotos) {
                                    Text("Choose photo or video from Gallery")
                                }
                            }
                        }
                    }
                    "Apps" -> if (!isTv) item {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            Text("APK files", style = MaterialTheme.typography.headlineMedium)
                            Text("Choose an APK you trust. Android's system installer checks the package and asks for your permission. ItamarOS cannot silently install apps.")
                            Button(onClick = onChooseApk) { Text("Choose APK from Files") }
                            if (selectedApkName != null) {
                                Text("Selected: $selectedApkName")
                                Button(onClick = onInstallApk) {
                                    Text("Review installation in Android")
                                }
                            }
                            Text(status, color = MaterialTheme.colorScheme.secondary)
                        }
                    }
                    "Streaming" -> if (isTv) item {
                        TVServiceScreen(onLaunchService)
                    }
                    "Settings" -> item {
                        if (!isTv) {
                            AndroidConnectSyncSettings()
                            HorizontalDivider()
                            AndroidLanguageSettings()
                        }
                        NativeSettings(isTv, device, status, updateStatus, updateDownloadAvailable,
                            downloadState, onCheckUpdates, onDownloadUpdate,
                            onInstallDownloadedUpdate, onChooseUSB, onExport, onStorageSettings,
                            onEnableUpdateAlerts, onSetAutoUpdateChecks, onSetAutoDownloadUpdates)
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
    updateDownloadAvailable: Boolean,
    downloadState: ItamarApkUpdate.Snapshot,
    check: () -> Unit,
    downloadUpdate: () -> Unit,
    installUpdate: () -> Unit,
    chooseUSB: () -> Unit,
    export: () -> Unit,
    storageSettings: () -> Unit,
    enableUpdateAlerts: () -> Unit,
    setAutoUpdateChecks: (Boolean) -> Unit,
    setAutoDownloadUpdates: (Boolean) -> Unit
) {
    val context=LocalContext.current
    val prefs=remember { context.getSharedPreferences("itamaros_native",Context.MODE_PRIVATE) }
    var autoChecking by remember { mutableStateOf(prefs.getBoolean("autoUpdateChecks",true)) }
    var autoDownload by remember { mutableStateOf(prefs.getBoolean("autoDownloadUpdates",false)) }
    var largeText by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Settings", style = MaterialTheme.typography.headlineMedium)
        Text("System & device", fontWeight = FontWeight.Bold)
        Text("Manufacturer and model: $device")
        Text("Android version: ${Build.VERSION.RELEASE}")
        Card(shape=RoundedCornerShape(22.dp),
            colors=CardDefaults.cardColors(containerColor=ItamarColors.panel)) {
            Column(modifier=Modifier.padding(17.dp),
                verticalArrangement=Arrangement.spacedBy(13.dp)) {
                Row(verticalAlignment=Alignment.CenterVertically) {
                    ItamarAppTabIcon("Settings",true)
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text("Software Update",style=MaterialTheme.typography.titleLarge,
                            fontWeight=FontWeight.Bold)
                        Text("Automatic checks · Verified APKs · You approve installation",
                            style=MaterialTheme.typography.labelSmall,color=ItamarColors.muted)
                    }
                }
                Text(updates,color=ItamarColors.muted)
                Row(verticalAlignment=Alignment.CenterVertically) {
                    Text("Check for updates automatically",
                        modifier=Modifier.weight(1f))
                    Switch(checked=autoChecking,onCheckedChange={
                        autoChecking=it
                        if(!it) {
                            autoDownload=false
                            setAutoDownloadUpdates(false)
                        }
                        setAutoUpdateChecks(it)
                    })
                }
                Row(verticalAlignment=Alignment.CenterVertically) {
                    Column(modifier=Modifier.weight(1f)) {
                        Text("Automatically download on Wi-Fi")
                        Text("Off by default · only verified published releases",
                            style=MaterialTheme.typography.bodySmall,color=ItamarColors.muted)
                    }
                    Switch(checked=autoDownload,onCheckedChange={
                        autoDownload=it
                        if(it) {
                            autoChecking=true
                            setAutoUpdateChecks(true)
                        }
                        setAutoDownloadUpdates(it)
                    })
                }
                Button(onClick=enableUpdateAlerts) {
                    Text("Enable update notifications")
                }
                OutlinedButton(onClick=check) { Text("Check now") }
                if(updateDownloadAvailable &&
                    downloadState.phase !in listOf("ready","downloading","pending","paused")) {
                    Button(onClick=downloadUpdate) { Text("Download verified APK") }
                }
                if(downloadState.phase in listOf("downloading","pending","paused")) {
                    LinearProgressIndicator(progress={downloadState.percent/100f},
                        modifier=Modifier.fillMaxWidth())
                }
                if(downloadState.phase!="none")
                    Text(downloadState.message,style=MaterialTheme.typography.bodySmall,
                        color=ItamarColors.cyan)
                if(downloadState.ready) {
                    Button(onClick=installUpdate,modifier=Modifier.fillMaxWidth()) {
                        Text("Install update · Android approval")
                    }
                } else if(downloadState.phase=="failed" && updateDownloadAvailable) {
                    OutlinedButton(onClick=downloadUpdate) { Text("Retry download") }
                }
                Text("Installation is not silent. Android may require permission to install updates and may reject APKs signed with a different certificate. Background checks are best effort.",
                    style=MaterialTheme.typography.bodySmall,color=ItamarColors.muted)
            }
        }
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

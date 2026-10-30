package org.itamaros.nativeapp

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

// Official Google Play listing links only. Google Play decides TV compatibility and installation.
// This is NOT an independent APK marketplace or a silent installer.
private data class TVStoreListing(val title: String, val packageId: String, val category: String)
private val tvListings = listOf(
    TVStoreListing("VLC for Android", "org.videolan.vlc", "Apps"),
    TVStoreListing("Kodi", "org.xbmc.kodi", "Apps"),
    TVStoreListing("Plex", "com.plexapp.android", "Apps"),
    TVStoreListing("Spotify", "com.spotify.tv.android", "Apps"),
    TVStoreListing("YouTube", "com.google.android.youtube.tv", "Apps"),
    TVStoreListing("Beach Buggy Racing", "com.vectorunit.purple.googleplay", "Games"),
    TVStoreListing("Crossy Road", "com.yodo1.crossyroad", "Games"),
    TVStoreListing("BADLAND", "com.frogmind.badland", "Games")
)

@Composable
fun TVStoreScreen(status: String, onOpenListing: (String) -> Unit, onBrowseStore: () -> Unit) {
    var category by remember { mutableStateOf("Apps") }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth()) {
        Text("ItamarOS TV Store", style = MaterialTheme.typography.headlineMedium)
        Text("Real TV app and game discovery through the device's official Google Play Store.")
        Text("Google Play checks whether an app is compatible with this TV. Only Play can download and install it. Availability varies by TV and country.")
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            listOf("Apps", "Games").forEach { label ->
                FilterChip(selected = category == label, onClick = { category = label },
                    label = { Text(label) })
            }
        }
        tvListings.filter { it.category == category }.forEach { listing ->
            FilledTonalButton(onClick = { onOpenListing(listing.packageId) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)) {
                Text("View in Google Play · ${listing.title}")
            }
        }
        Button(onClick = onBrowseStore, modifier = Modifier.fillMaxWidth()) {
            Text("Open the TV's Google Play Store")
        }
        Text(status, color = MaterialTheme.colorScheme.secondary)
    }
}

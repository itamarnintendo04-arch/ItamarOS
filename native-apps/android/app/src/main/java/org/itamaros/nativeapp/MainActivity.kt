package org.itamaros.nativeapp

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import android.provider.Settings
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.json.JSONObject
import java.net.URL
import java.util.TimeZone
import java.util.Locale

class MainActivity : ComponentActivity() {
    private var status by mutableStateOf("Native app ready")
    private var selectedTree by mutableStateOf<Uri?>(null)
    private var updateStatus by mutableStateOf("Not checked yet")
    private var isTv = false
    private val prefs by lazy { getSharedPreferences("itamaros_native", MODE_PRIVATE) }

    private val chooseUSB = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri ->
        if (uri == null) {
            status = "No destination selected. Nothing was copied."
            return@registerForActivityResult
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            selectedTree = uri
            prefs.edit().putString("usbFolder", uri.toString()).apply()
            status = "Selected folder. Use Export app data to copy a backup to external storage."
        } catch (e: Exception) {
            status = "Could not access folder: ${e.localizedMessage}"
        }
    }

    private val chooseMedia = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            // A native media player app handles the selected document, not a WebView.
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, contentResolver.getType(uri) ?: "video/*")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(intent)
                status = "Media handed to a native Android player."
            } catch (e: Exception) {
                status = "No compatible native media app installed."
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        isTv = uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        selectedTree = prefs.getString("usbFolder", null)?.let(Uri::parse)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                NativeAppScreen(
                    isTv = isTv,
                    device = android.os.Build.MANUFACTURER + " " + android.os.Build.MODEL,
                    status = status,
                    updateStatus = updateStatus,
                    bestScore = prefs.getInt("bestGuess", 0),
                    onCheckUpdates = ::checkUpdates,
                    onLaunchService = ::launchTVService,
                    onChooseUSB = { chooseUSB.launch(null) },
                    onExport = ::exportToSelectedFolder,
                    onStorageSettings = ::openAppStorageSettings,
                    onChooseMedia = { chooseMedia.launch(arrayOf("audio/*", "video/*")) },
                    onSaveScore = { value -> prefs.edit().putInt("bestGuess", value).apply() }
                )
            }
        }
    }

    private fun checkUpdates() {
        updateStatus = "Checking GitHub for native app release information…"
        Thread {
            val result = try {
                val connection = URL(
                    "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/updates/native-apps.json"
                ).openConnection()
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                val data = connection.getInputStream().bufferedReader().use { it.readText() }
                val manifest = JSONObject(data)
                val version = manifest.optString("version")
                if (manifest.optInt("schemaVersion") != 1) "Invalid release metadata."
                else if (version != "1.1.0") "Source version: $version; install an actual signed update only through your platform's authorized app store."
                else "App source version 1.1.0. No signed production app release is published."
            } catch (e: Exception) {
                "Unable to check updates: ${e.localizedMessage}"
            }
            runOnUiThread { updateStatus = result }
        }.start()
    }

    private fun launchTVService(pkg: String?, name: String) {
        if (!isTv) {
            status = "TV streaming is available on TVs only."
            return
        }
        if (pkg == null) {
            status = "Open $name from TV Home. The installed app package is not yet verified for your model."
            return
        }
        try {
            val intent = packageManager.getLeanbackLaunchIntentForPackage(pkg)
            if (intent == null) {
                status = "$name is not installed or cannot be opened on this TV."
                return
            }
            startActivity(intent)
            status = "Requested the installed $name application."
        } catch (e: Exception) {
            status = "Unable to open $name: ${e.localizedMessage}"
        }
    }

    private fun exportToSelectedFolder() {
        val folder = selectedTree
        if (folder == null) {
            status = "Connect a drive and choose an external folder first."
            return
        }
        try {
            val document = DocumentsContract.buildDocumentUriUsingTree(
                folder, DocumentsContract.getTreeDocumentId(folder)
            )
            val result = DocumentsContract.createDocument(
                contentResolver, document, "application/json", "ItamarOS-App-Backup.json"
            ) ?: throw IllegalStateException("The selected destination is not writable.")
            val json = JSONObject()
                .put("format", "ItamarOS Native Android backup")
                .put("version", "1.1.0")
                .put("bestGuess", prefs.getInt("bestGuess", 0))
                .toString(2)
            contentResolver.openOutputStream(result, "w")?.use {
                it.write(json.toByteArray(Charsets.UTF_8))
            } ?: throw IllegalStateException("Cannot write to the destination.")
            status = "App data exported to the selected folder. The app itself has not moved."
        } catch (e: Exception) {
            status = "Export failed: ${e.localizedMessage}. Make sure the drive is attached and writable."
        }
    }

    private fun openAppStorageSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        try {
            startActivity(intent)
            status = "Opened system app settings. A 'Move to USB/SD' option appears only if your TV allows it."
        } catch (e: Exception) {
            status = "This TV has no accessible app storage settings screen."
        }
    }
}

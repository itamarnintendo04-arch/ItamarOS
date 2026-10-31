package org.itamaros.nativeapp

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.provider.OpenableColumns
import androidx.activity.result.PickVisualMediaRequest
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
    private var selectedMedia by mutableStateOf<Uri?>(null)
    private var selectedApk by mutableStateOf<Uri?>(null)
    private var selectedApkName by mutableStateOf<String?>(null)
    private var bestScore by mutableIntStateOf(0)
    private var updateStatus by mutableStateOf("Not checked yet")
    private var incomingGroupInvite by mutableStateOf<String?>(null)
    private var incomingContact by mutableStateOf<String?>(null)
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
            try {
                selectedMedia = uri
                status = "Opened selected media inside ItamarOS native Android Player."
            } catch (e: Exception) {
                status = "Unable to open local media: ${e.localizedMessage}"
            }
        }
    }

    private val chooseGallery = registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            selectedMedia = uri
            status = "Selected media from your gallery."
        }
    }

    private val chooseApk = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri == null) return@registerForActivityResult
        val fileName = try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: Exception) { null }
        if (fileName == null || !fileName.endsWith(".apk", ignoreCase = true)) {
            selectedApk = null
            selectedApkName = null
            status = "Choose an actual .apk file, not a web page or ZIP."
            return@registerForActivityResult
        }
        selectedApk = uri
        selectedApkName = fileName
        status = "Selected $fileName. Android will ask you to review any installation."
    }

    private fun installChosenApk() {
        val uri = selectedApk
        if (uri == null) {
            status = "Select an APK first."
            return
        }
        try {
            val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                data = uri
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            status = "Android installer opened. No app is installed unless you approve it."
        } catch (e: Exception) {
            status = "Android installer unavailable: ${e.localizedMessage}. Device security restrictions must be respected."
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        processIncomingLink(intent)
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        isTv = uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        selectedTree = prefs.getString("usbFolder", null)?.let(Uri::parse)
        bestScore = prefs.getInt("bestGuess", 0)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                NativeAppScreen(
                    isTv = isTv,
                    groupInvite = incomingGroupInvite,
                    contactUsername = incomingContact,
                    device = android.os.Build.MANUFACTURER + " " + android.os.Build.MODEL,
                    status = status,
                    updateStatus = updateStatus,
                    updateDownloadAvailable = updateApkUrl != null,
                    onDownloadUpdate = ::openUpdateDownload,
                    bestScore = bestScore,
                    selectedMedia = selectedMedia,
                    selectedApkName = selectedApkName,
                    onCheckUpdates = ::checkUpdates,
                    onLaunchService = ::launchTVService,
                    onOpenStoreListing = ::openPlayStoreListing,
                    onBrowseStore = ::openTVPlayStore,
                    onChooseUSB = { chooseUSB.launch(null) },
                    onExport = ::exportToSelectedFolder,
                    onStorageSettings = ::openAppStorageSettings,
                    onChooseMedia = { chooseMedia.launch(arrayOf("image/*", "audio/*", "video/*")) },
                    onChoosePhotos = { chooseGallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo)) },
                    onChooseApk = { chooseApk.launch(arrayOf("application/vnd.android.package-archive", "application/octet-stream")) },
                    onInstallApk = ::installChosenApk,
                    onSaveScore = { value ->
                        bestScore = value
                        prefs.edit().putInt("bestGuess", value).apply()
                    }
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        processIncomingLink(intent)
    }

    private fun processIncomingLink(incoming: Intent?) {
        val uri = incoming?.data ?: return
        if (uri.scheme != "itamaros") return
        if (uri.host == "group") {
            val code = uri.getQueryParameter("invite")
            incomingGroupInvite = code?.takeIf { it.matches(Regex("[a-f0-9]{48}")) }
        } else if (uri.host == "contact") {
            val user = uri.getQueryParameter("username")
            incomingContact = user?.takeIf { it.matches(Regex("[a-z0-9_.]{3,24}")) }
        }
    }

    private var updateApkUrl by mutableStateOf<String?>(null)

    private fun checkUpdates() {
        updateStatus = "Checking public release metadata…"
        updateApkUrl = null
        Thread {
            val result = try {
                val connection = URL(
                    "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/updates/native-apps.json"
                ).openConnection()
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                val data = connection.getInputStream().bufferedReader().use { it.readText() }
                val manifest = JSONObject(data)
                val id = if (isTv) "itamaros-android-tv" else "itamaros-android"
                val components = manifest.getJSONArray("components")
                val component = (0 until components.length())
                    .map { components.getJSONObject(it) }
                    .firstOrNull { it.optString("id") == id }
                val installed = packageManager.getPackageInfo(packageName, 0).versionName ?: "0.0.0"
                val remote = component?.optString("version").orEmpty()
                val asset = component?.optString("package").orEmpty()
                val trustedLink = asset.startsWith(
                    "https://github.com/itamarnintendo04-arch/ItamarOS/releases/download/"
                ) && asset.endsWith(".apk")
                val newer = remote.split('.').map { it.toIntOrNull() ?: 0 }
                    .let { r -> installed.split('.').map { it.toIntOrNull() ?: 0 }.let { local ->
                        (0 until maxOf(r.size, local.size)).firstNotNullOfOrNull { index ->
                            val diff = r.getOrElse(index) { 0 } - local.getOrElse(index) { 0 }
                            if (diff == 0) null else diff > 0
                        } ?: false
                    } }

                if (manifest.optInt("schemaVersion") != 1 || component == null) {
                    "Invalid or missing Android release metadata."
                } else if (newer && trustedLink) {
                    runOnUiThread { updateApkUrl = asset }
                    "Android $remote is published as an unverified preview APK. Download it from GitHub, then review installation in Android. Updating in place requires the same signing key as the installed version."
                } else if (newer) {
                    "Android source version $remote is newer, but no downloadable APK for this device is published."
                } else {
                    "Installed version $installed. Latest source version $remote. No newer APK found."
                }
            } catch (e: Exception) {
                "Unable to check releases: ${e.localizedMessage}"
            }
            runOnUiThread { updateStatus = result }
        }.start()
    }

    private fun openUpdateDownload() {
        val url = updateApkUrl ?: return
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            status = "Opened official GitHub APK download. Android must approve installation; no update has been installed yet."
        } catch (e: Exception) {
            status = "Unable to open release link: ${e.localizedMessage}"
        }
    }

    private fun launchTVService(pkg: String?, name: String) {
        if (!isTv) {
            status = "TV streaming is available on TVs only."
            return
        }
        try {
            // For services with no reliable fixed Android TV package ID, discover installed
            // Leanback launchers by their visible labels instead of guessing package names.
            val discovered = if (pkg == null) {
                val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER)
                packageManager.queryIntentActivities(intent, 0).firstOrNull { info ->
                    val label = info.loadLabel(packageManager).toString()
                    label.equals(name, ignoreCase = true) ||
                        label.replace(" ", "").equals(name.replace(" ", ""), ignoreCase = true)
                }?.activityInfo?.packageName
            } else pkg
            val intent = discovered?.let { packageManager.getLeanbackLaunchIntentForPackage(it) }
            if (intent == null) {
                status = "$name cannot be opened as an installed TV app. Find it using the TV's official app store."
            } else {
                startActivity(intent)
                status = "Opened the installed $name app."
            }
        } catch (e: Exception) {
            status = "Unable to open $name: ${e.localizedMessage}"
        }
    }

    private fun openPlayStoreListing(packageId: String) {
        if (!isTv) return
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageId")).apply {
                setPackage("com.android.vending")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            status = "Google Play will check compatibility and handle installation."
        } catch (e: Exception) {
            status = "Google Play is unavailable on this TV. No application was installed."
        }
    }

    private fun openTVPlayStore() {
        if (!isTv) return
        try {
            val intent = packageManager.getLeanbackLaunchIntentForPackage("com.android.vending")
                ?: packageManager.getLaunchIntentForPackage("com.android.vending")
            if (intent == null) {
                status = "Google Play is not available on this TV."
                return
            }
            startActivity(intent)
            status = "Opened Google Play on your TV."
        } catch (e: Exception) {
            status = "Cannot open Google Play: ${e.localizedMessage}"
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
                .put("version", "1.3.0")
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

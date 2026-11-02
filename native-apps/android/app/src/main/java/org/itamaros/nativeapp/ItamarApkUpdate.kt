package org.itamaros.nativeapp

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Environment
import android.provider.Settings
import org.json.JSONObject
import java.security.MessageDigest

/**
 * Updates can be discovered/downloaded automatically after opt-in.
 * The Android package installer must still authorize installation.
 *
 * Only verified release APKs with an explicit SHA-256 in the published manifest
 * can enter this path; CI debug artifacts and old releases never auto-install.
 */
object ItamarApkUpdate {
    const val MANIFEST_URL =
        "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/updates/native-apps.json"
    data class PublishedApk(val version: String, val url: String, val sha256: String)
    data class Snapshot(val phase: String, val message: String, val percent: Int = 0) {
        val ready get() = phase == "ready"
    }

    fun newer(remote: String, installed: String): Boolean {
        val rule = Regex("^[0-9]+(\\.[0-9]+){1,3}$")
        if (!rule.matches(remote) || !rule.matches(installed)) return false
        val r = remote.split('.').map { it.toLongOrNull() ?: 0L }
        val i = installed.split('.').map { it.toLongOrNull() ?: 0L }
        for (n in 0 until maxOf(r.size, i.size)) {
            val difference = r.getOrElse(n) { 0L }.compareTo(i.getOrElse(n) { 0L })
            if (difference != 0) return difference > 0
        }
        return false
    }

    fun publishedTarget(manifest: JSONObject, isTv: Boolean, installed: String): PublishedApk? {
        if (manifest.optInt("schemaVersion") != 1) return null
        val id = if (isTv) "itamaros-android-tv" else "itamaros-android"
        val components = manifest.optJSONArray("components") ?: return null
        val component = (0 until components.length()).mapNotNull { components.optJSONObject(it) }
            .firstOrNull { it.optString("id") == id } ?: return null
        val version = component.optString("version")
        if (!newer(version, installed) ||
            component.optString("releaseStatus") != "published-verified") return null
        val uri = Uri.parse(component.optString("package"))
        if (uri.scheme != "https" || uri.host != "github.com" ||
            !uri.path.orEmpty().startsWith("/itamarnintendo04-arch/ItamarOS/releases/download/") ||
            uri.lastPathSegment?.endsWith(".apk") != true ||
            !uri.query.isNullOrBlank() || !uri.fragment.isNullOrBlank()) return null
        val sha = component.optString("sha256").lowercase()
        if (!Regex("^[a-f0-9]{64}$").matches(sha)) return null
        return PublishedApk(version, uri.toString(), sha)
    }

    private fun pref(ctx: Context) =
        ctx.getSharedPreferences("itamaros_native", Context.MODE_PRIVATE)
    private fun manager(ctx: Context) =
        ctx.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    @Synchronized
    fun enqueue(ctx: Context, update: PublishedApk, automatic: Boolean): Long {
        val p = pref(ctx)
        val existing = p.getLong("updateDownloadId", -1L)
        if (existing > 0 && p.getString("updateDownloadUrl", "") == update.url) {
            val state = stateOf(ctx, existing)
            if (state != DownloadManager.STATUS_FAILED) return existing
            manager(ctx).remove(existing)
        }
        val request = DownloadManager.Request(Uri.parse(update.url))
            .setTitle("ItamarOS " + update.version)
            .setDescription("Verified update APK · Android will ask before installation")
            .setMimeType("application/vnd.android.package-archive")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverRoaming(false)
            // Automatic downloads do not consume mobile data without user action.
            .setAllowedOverMetered(!automatic)
            .setDestinationInExternalFilesDir(ctx, Environment.DIRECTORY_DOWNLOADS,
                "itamaros-update-" + update.version + ".apk")
        val downloadId = manager(ctx).enqueue(request)
        p.edit().putLong("updateDownloadId", downloadId)
            .putString("updateDownloadUrl", update.url)
            .putString("updateDownloadVersion", update.version)
            .putString("updateDownloadSHA256", update.sha256)
            .remove("updateVerifiedId").apply()
        return downloadId
    }

    private fun stateOf(ctx: Context, id: Long): Int {
        manager(ctx).query(DownloadManager.Query().setFilterById(id)).use { c ->
            if (!c.moveToFirst()) return DownloadManager.STATUS_FAILED
            return c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
        }
    }

    /** Caller should use Dispatchers.IO: digest can read tens of megabytes. */
    fun snapshot(ctx: Context): Snapshot {
        val p = pref(ctx)
        val id = p.getLong("updateDownloadId", -1L)
        if (id <= 0) return Snapshot("none", "No update downloaded")
        val downloads = manager(ctx)
        downloads.query(DownloadManager.Query().setFilterById(id)).use { c ->
            if (!c.moveToFirst()) return Snapshot("failed", "Download not found. Try again.")
            val state = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            when (state) {
                DownloadManager.STATUS_PENDING ->
                    return Snapshot("pending", "Update waiting for network")
                DownloadManager.STATUS_PAUSED ->
                    return Snapshot("paused", "Download paused. Check Wi-Fi.")
                DownloadManager.STATUS_RUNNING -> {
                    val done = c.getLong(c.getColumnIndexOrThrow(
                        DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                    val total = c.getLong(c.getColumnIndexOrThrow(
                        DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                    val percent = if (total > 0) ((done * 100L / total).toInt()).coerceIn(0, 99) else 0
                    return Snapshot("downloading", "Downloading update · $percent%", percent)
                }
                DownloadManager.STATUS_SUCCESSFUL -> {
                    if (p.getLong("updateVerifiedId", -1L) == id)
                        return Snapshot("ready", "Update verified. Ready for Android approval.", 100)
                    val expected = p.getString("updateDownloadSHA256", "").orEmpty()
                    val uri = downloads.getUriForDownloadedFile(id)
                        ?: return Snapshot("failed", "Cannot open downloaded update")
                    val actual = MessageDigest.getInstance("SHA-256")
                    try {
                        ctx.contentResolver.openInputStream(uri)?.use { input ->
                            val buffer = ByteArray(65536)
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                actual.update(buffer, 0, count)
                            }
                        } ?: return Snapshot("failed", "Cannot read downloaded update")
                    } catch (_: Exception) {
                        return Snapshot("failed", "Cannot verify downloaded update")
                    }
                    val hash = actual.digest().joinToString("") { "%02x".format(it) }
                    if (hash != expected) {
                        downloads.remove(id)
                        p.edit().remove("updateVerifiedId").apply()
                        return Snapshot("failed", "Security check failed: APK checksum differs. Download again.")
                    }
                    p.edit().putLong("updateVerifiedId", id).apply()
                    return Snapshot("ready", "Update verified. Tap Install to approve in Android.", 100)
                }
                else -> return Snapshot("failed", "Download failed. Retry after checking connection.")
            }
        }
    }

    /** Caller is responsible for presenting a clear, user-triggered install button. */
    fun openInstaller(ctx: Context): String {
        val p = pref(ctx)
        val id = p.getLong("updateDownloadId", -1L)
        if (id <= 0 || p.getLong("updateVerifiedId", -1L) != id ||
            stateOf(ctx, id) != DownloadManager.STATUS_SUCCESSFUL)
            return "Update is not yet verified. Download it first."
        if (android.os.Build.VERSION.SDK_INT >= 26 &&
            !ctx.packageManager.canRequestPackageInstalls()) {
            val settings = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:" + ctx.packageName))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(settings)
            return "Allow updates from ItamarOS in Android Settings, then tap Install again."
        }
        val uri = manager(ctx).getUriForDownloadedFile(id)
            ?: return "Downloaded APK is unavailable."
        val install = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        ctx.startActivity(install)
        return "Android installer opened. Review and approve the update."
    }
}

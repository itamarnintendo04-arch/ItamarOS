package org.itamaros.nativeapp

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URL
import java.util.concurrent.TimeUnit

/** Best-effort periodic release checks. Downloads are opt-in; installation
 * always requires the user to open/review Android's installer. */
class ItamarUpdateWorker(context:Context, params:WorkerParameters)
    : CoroutineWorker(context,params) {
    override suspend fun doWork():Result = withContext(Dispatchers.IO) {
        val ctx=applicationContext
        val prefs=ctx.getSharedPreferences("itamaros_native",Context.MODE_PRIVATE)
        if (!prefs.getBoolean("autoUpdateChecks",true)) return@withContext Result.success()
        try {
            val conn=URL(ItamarApkUpdate.MANIFEST_URL).openConnection()
            conn.connectTimeout=12000
            conn.readTimeout=12000
            val json=conn.getInputStream().bufferedReader().use {it.readText()}
            val isTv=ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
            val installed=ctx.packageManager.getPackageInfo(ctx.packageName,0).versionName ?: "0.0.0"
            val update=ItamarApkUpdate.publishedTarget(JSONObject(json),isTv,installed)
                ?:return@withContext Result.success()

            if (prefs.getBoolean("autoDownloadUpdates",false)) {
                // DownloadManager downloads only on unmetered connections for auto mode.
                // No background installer launch or silent package installation.
                ItamarApkUpdate.enqueue(ctx,update,automatic=true)
                return@withContext Result.success()
            }
            if (prefs.getString("lastUpdateNotified","")==update.version)
                return@withContext Result.success()
            if (!prefs.getBoolean("updateAlerts",false))
                return@withContext Result.success()
            if (Build.VERSION.SDK_INT>=33 &&
                ContextCompat.checkSelfPermission(ctx,Manifest.permission.POST_NOTIFICATIONS)!=
                PackageManager.PERMISSION_GRANTED) return@withContext Result.success()

            val manager=ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(NotificationChannel(
                "itamaros_updates","ItamarOS software updates",NotificationManager.IMPORTANCE_DEFAULT))
            val launch=Intent(ctx,MainActivity::class.java).apply {
                flags=Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending=PendingIntent.getActivity(ctx,0,launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val note=NotificationCompat.Builder(ctx,"itamaros_updates")
                .setSmallIcon(R.drawable.itamaros_logo)
                .setContentTitle("ItamarOS update " + update.version + " available")
                .setContentText("Open ItamarOS to download this verified APK.")
                .setContentIntent(pending)
                .setAutoCancel(true)
                .build()
            manager.notify(18001,note)
            prefs.edit().putString("lastUpdateNotified",update.version).apply()
            Result.success()
        } catch (_:Exception) {
            Result.retry()
        }
    }
    companion object {
        fun schedule(ctx:Context,enabled:Boolean) {
            val manager=WorkManager.getInstance(ctx)
            if(!enabled) {
                manager.cancelUniqueWork("ItamarOS release checks")
                return
            }
            val constraints=Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED).build()
            val request=PeriodicWorkRequestBuilder<ItamarUpdateWorker>(6,TimeUnit.HOURS)
                .setConstraints(constraints)
                .build()
            manager.enqueueUniquePeriodicWork("ItamarOS release checks",
                ExistingPeriodicWorkPolicy.KEEP,request)
        }
    }
}

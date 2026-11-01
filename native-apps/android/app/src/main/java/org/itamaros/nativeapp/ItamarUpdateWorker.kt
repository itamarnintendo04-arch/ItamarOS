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

/** Periodic best-effort checks. Will not download or install APKs in background. */
class ItamarUpdateWorker(context:Context,params:WorkerParameters):CoroutineWorker(context,params){
    override suspend fun doWork():Result = withContext(Dispatchers.IO) {
        val ctx=applicationContext
        val prefs=ctx.getSharedPreferences("itamaros_native",Context.MODE_PRIVATE)
        if(!prefs.getBoolean("autoUpdateChecks",true))return@withContext Result.success()
        try{
            val conn=URL("https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/updates/native-apps.json")
                .openConnection()
            conn.connectTimeout=12000
            conn.readTimeout=12000
            val data=conn.getInputStream().bufferedReader().use{it.readText()}
            val manifest=JSONObject(data)
            if(manifest.optInt("schemaVersion")!=1)return@withContext Result.success()
            val isTv=ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
            val componentID=if(isTv)"itamaros-android-tv" else "itamaros-android"
            val components=manifest.getJSONArray("components")
            val target=(0 until components.length()).map{components.getJSONObject(it)}
                .firstOrNull{it.optString("id")==componentID}
                ?:return@withContext Result.success()
            val remote=target.optString("version")
            val asset=target.optString("package")
            val installed=ctx.packageManager.getPackageInfo(ctx.packageName,0).versionName?:"0.0.0"
            val trusted=asset.startsWith("https://github.com/itamarnintendo04-arch/ItamarOS/releases/download/") &&
                asset.endsWith(".apk") && target.optString("releaseStatus")!="source-only"
            if(!trusted||!newer(remote,installed))return@withContext Result.success()
            if(prefs.getString("lastUpdateNotified",null)==remote)return@withContext Result.success()
            if(!prefs.getBoolean("updateAlerts",false))return@withContext Result.success()
            if(Build.VERSION.SDK_INT>=33 &&
                ContextCompat.checkSelfPermission(ctx,Manifest.permission.POST_NOTIFICATIONS)!=
                PackageManager.PERMISSION_GRANTED)return@withContext Result.success()
            val notificationManager=ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(NotificationChannel(
                "itamaros_updates","ItamarOS software updates",NotificationManager.IMPORTANCE_DEFAULT))
            val intent=Intent(Intent.ACTION_VIEW,android.net.Uri.parse(asset))
            val pending=PendingIntent.getActivity(ctx,0,intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notice=NotificationCompat.Builder(ctx,"itamaros_updates")
                .setSmallIcon(R.drawable.itamaros_logo)
                .setContentTitle("ItamarOS update "+remote+" available")
                .setContentText("Review the published APK on GitHub before installing.")
                .setContentIntent(pending)
                .setAutoCancel(true)
                .build()
            notificationManager.notify(18001,notice)
            prefs.edit().putString("lastUpdateNotified",remote).apply()
            Result.success()
        }catch(e:Exception){Result.retry()}
    }
    private fun newer(remote:String,installed:String):Boolean{
        val r=remote.split('.').map{it.toIntOrNull()?:0}
        val i=installed.split('.').map{it.toIntOrNull()?:0}
        for(index in 0 until maxOf(r.size,i.size)){
            val difference=r.getOrElse(index){0}-i.getOrElse(index){0}
            if(difference!=0)return difference>0
        }
        return false
    }
    companion object{
        fun schedule(ctx:Context,enabled:Boolean){
            val wm=WorkManager.getInstance(ctx)
            if(!enabled){wm.cancelUniqueWork("ItamarOS release checks");return}
            val constraints=Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            val work=PeriodicWorkRequestBuilder<ItamarUpdateWorker>(6,TimeUnit.HOURS)
                .setConstraints(constraints).build()
            wm.enqueueUniquePeriodicWork("ItamarOS release checks",
                ExistingPeriodicWorkPolicy.KEEP,work)
        }
    }
}

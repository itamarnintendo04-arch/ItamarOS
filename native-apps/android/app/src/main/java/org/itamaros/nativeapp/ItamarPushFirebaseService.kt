package org.itamaros.nativeapp

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.UUID

/** Firebase's transport cannot work until the owner configures the actual Firebase app. */
class ItamarPushFirebaseService:FirebaseMessagingService(){
    override fun onNewToken(token:String){
        super.onNewToken(token)
        // A new token is persisted privately, but associated with an account only when
        // the user has explicitly enabled push and authenticated in ItamarOS Connect.
        getSharedPreferences("itamaros_push",Context.MODE_PRIVATE)
            .edit().putString("pendingToken",token).apply()
    }
}
object ItamarAndroidPush {
    fun canConfigure():Boolean=
        BuildConfig.ITAMAR_FIREBASE_APP_ID.isNotBlank() &&
        BuildConfig.ITAMAR_FIREBASE_API_KEY.isNotBlank() &&
        BuildConfig.ITAMAR_FIREBASE_PROJECT_ID.isNotBlank() &&
        BuildConfig.ITAMAR_FIREBASE_SENDER_ID.isNotBlank()
    fun deviceId(context:Context):String{
        val prefs=context.getSharedPreferences("itamaros_push",Context.MODE_PRIVATE)
        val existing=prefs.getString("deviceId",null)
        if(existing!=null)return existing
        val created=UUID.randomUUID().toString()
        prefs.edit().putString("deviceId",created).apply()
        return created
    }
    fun register(context:Context,api:AndroidConnectApi,onResult:(String)->Unit){
        if(Build.VERSION.SDK_INT>=33 &&
           ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS)
               != PackageManager.PERMISSION_GRANTED){
            onResult("Android notification permission is required.")
            return
        }
        if(!canConfigure()){
            onResult("Firebase is not configured. Chat push cannot be enabled yet.")
            return
        }
        if(api.token==null || api.userID==null){
            onResult("Sign in and create your @username before enabling push.")
            return
        }
        try{
            if(FirebaseApp.getApps(context).none{it.name==FirebaseApp.DEFAULT_APP_NAME}){
                val options=FirebaseOptions.Builder()
                    .setApplicationId(BuildConfig.ITAMAR_FIREBASE_APP_ID)
                    .setApiKey(BuildConfig.ITAMAR_FIREBASE_API_KEY)
                    .setGcmSenderId(BuildConfig.ITAMAR_FIREBASE_SENDER_ID)
                    .setProjectId(BuildConfig.ITAMAR_FIREBASE_PROJECT_ID).build()
                FirebaseApp.initializeApp(context,options)
            }
            FirebaseMessaging.getInstance().token.addOnCompleteListener{ task->
                if(!task.isSuccessful || task.result.isNullOrBlank()){
                    onResult("Firebase token unavailable: check Firebase app registration.")
                    return@addOnCompleteListener
                }
                val token=task.result
                CoroutineScope(Dispatchers.IO).launch{
                    try{
                        api.request("/rest/v1/rpc/itamar_push_register","POST",
                            JSONObject().put("p_device_id",deviceId(context))
                                .put("p_provider","fcm").put("p_token",token))
                        context.getSharedPreferences("itamaros_push",Context.MODE_PRIVATE)
                            .edit().putBoolean("enabled",true).apply()
                        withContext(Dispatchers.Main){
                            onResult("Device registered for push; server delivery requires Firebase credentials.")
                        }
                    }catch(e:Exception){
                        withContext(Dispatchers.Main){
                            onResult("Could not register device: "+(e.localizedMessage?:"unknown error"))
                        }
                    }
                }
            }
        }catch(e:Exception){
            onResult("Firebase initialization failed: "+(e.localizedMessage?:"check configuration"))
        }
    }
    fun unregister(context:Context,api:AndroidConnectApi,onResult:(String)->Unit){
        CoroutineScope(Dispatchers.IO).launch{
            try{
                api.request("/rest/v1/rpc/itamar_push_unregister","POST",
                    JSONObject().put("p_device_id",deviceId(context)))
                context.getSharedPreferences("itamaros_push",Context.MODE_PRIVATE)
                    .edit().putBoolean("enabled",false).apply()
                withContext(Dispatchers.Main){onResult("Chat push disabled for this device.")}
            }catch(e:Exception){
                withContext(Dispatchers.Main){
                    onResult("Could not unregister: "+(e.localizedMessage?:"unknown error"))
                }
            }
        }
    }
}

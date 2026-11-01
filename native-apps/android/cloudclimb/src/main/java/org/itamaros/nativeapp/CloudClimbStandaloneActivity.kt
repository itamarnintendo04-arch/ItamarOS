package org.itamaros.nativeapp

import android.graphics.Bitmap
import android.graphics.Color as AndroidColor
import android.os.Bundle
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Independent Cloud Climb APK. Reuses ItamarOS gameplay and multiplayer RPCs.
 * The QR holds only an expiring request ID; the secret is kept in app memory.
 * Account sign-in on a new device is a prototype with a short-lived bearer
 * session obtained after approval in the already signed-in ItamarOS app.
 */
class CloudClimbStandaloneActivity : ComponentActivity() {
    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (ItamarGamepad.motion(event)) return true
        return super.dispatchGenericMotionEvent(event)
    }
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (ItamarGamepad.key(event)) return true
        return super.dispatchKeyEvent(event)
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme=darkColorScheme()) {
                CloudClimbStandaloneHome()
            }
        }
    }
}

private const val BROKER="https://itamaros-store-api.onrender.com/api/connect/pair"

private suspend fun pairingCall(path:String,body:JSONObject): Pair<Int,JSONObject> =
    withContext(Dispatchers.IO) {
        val connection=URL(BROKER+path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod="POST"
            connection.connectTimeout=10000
            connection.readTimeout=10000
            connection.doOutput=true
            connection.setRequestProperty("Content-Type","application/json")
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val status=connection.responseCode
            val value=(if(status in 200..299)connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            status to JSONObject(value.ifEmpty { "{}" })
        } finally { connection.disconnect() }
    }

private fun qrBitmap(contents:String):Bitmap {
    val hints=mapOf<EncodeHintType,Any>(
        EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.H,
        EncodeHintType.MARGIN to 3
    )
    val matrix=MultiFormatWriter().encode(contents,BarcodeFormat.QR_CODE,480,480,hints)
    val pixels=IntArray(480*480)
    for(y in 0 until 480)for(x in 0 until 480) {
        pixels[y*480+x]=if(matrix[x,y])AndroidColor.BLACK else AndroidColor.WHITE
    }
    return Bitmap.createBitmap(pixels,480,480,Bitmap.Config.ARGB_8888).also {
        it.setPixels(pixels,0,480,0,0,480,480)
    }
}

@Composable
private fun CloudClimbStandaloneHome(){
    val api=remember { AndroidConnectApi() }
    var isAuthenticated by remember { mutableStateOf(false) }
    var localPlay by remember { mutableStateOf(false) }
    var wantQR by remember { mutableStateOf(false) }
    var requestId by remember { mutableStateOf("") }
    var claimSecret by remember { mutableStateOf("") }
    var qrUrl by remember { mutableStateOf("") }
    var expiry by remember { mutableLongStateOf(0L) }
    var status by remember { mutableStateOf("Choose Play Offline or Link ItamarOS Account") }
    var connecting by remember { mutableStateOf(false) }

    LaunchedEffect(wantQR) {
        if(!wantQR)return@LaunchedEffect
        connecting=true
        try {
            val (code,reply)=pairingCall("/start",JSONObject())
            if(code!=200)throw IllegalStateException(reply.optString("error","Unable to create QR"))
            requestId=reply.getString("requestId")
            claimSecret=reply.getString("claimSecret")
            qrUrl=reply.getString("approveUrl")
            expiry=reply.getLong("expiresAt")
            status="Scan this QR using the ItamarOS app on a trusted signed-in phone."
        }catch(e:Exception){status=e.localizedMessage?:"QR unavailable";wantQR=false}
        finally{connecting=false}
    }
    LaunchedEffect(requestId,claimSecret,wantQR) {
        if(!wantQR||requestId.isBlank()||claimSecret.isBlank())return@LaunchedEffect
        while(wantQR && System.currentTimeMillis()<expiry) {
            delay(2300)
            try {
                val (code,res)=pairingCall("/claim",JSONObject()
                    .put("requestId",requestId).put("claimSecret",claimSecret))
                if(code==202)continue
                if(code==200 && res.optString("status")=="approved" &&
                    res.optString("accessToken").isNotBlank() &&
                    res.optString("userId").isNotBlank()) {
                    api.token=res.getString("accessToken")
                    api.userID=res.getString("userId")
                    isAuthenticated=true
                    requestId="";claimSecret="";qrUrl="";wantQR=false
                    status="Connected with your existing ItamarOS account. Room codes are shared."
                    break
                }
                status=res.optString("error","Request expired. Generate another QR.")
                wantQR=false
            }catch(e:Exception){status="Waiting for approval · Check your connection"}
        }
        if(wantQR && System.currentTimeMillis()>=expiry) {
            wantQR=false;requestId="";claimSecret="";qrUrl=""
            status="QR expired. Generate a new code."
        }
    }
    Column(modifier=Modifier.fillMaxSize().padding(18.dp),
        verticalArrangement=Arrangement.spacedBy(14.dp)) {
        Text("☁️ CLOUD CLIMB",style=MaterialTheme.typography.headlineLarge)
        Text("Original platform adventure · Independent Preview")
        if(localPlay) {
            val local=remember { JSONObject().put("code","local-cloudclimb")
                .put("seed",1475).put("game","cloud_climb").put("status","playing") }
            CloudClimbAndroid(api,local,1,onExit={localPlay=false})
        }else if(isAuthenticated) {
            Text("Signed in as account "+api.userID.orEmpty().take(8))
            Text("Use the same 10-character Cloud Climb room codes as the main ItamarOS app.")
            ItamarPartyGamesAndroid(api,defaultGame="cloud_climb")
            OutlinedButton(onClick={
                api.token=null;api.userID=null;isAuthenticated=false
            }){Text("Sign out")}
        }else{
            Button(onClick={localPlay=true},modifier=Modifier.fillMaxWidth()){
                Text("Play Offline Demo")
            }
            Button(onClick={wantQR=!wantQR},
                enabled=!connecting,modifier=Modifier.fillMaxWidth()){
                Text(if(wantQR)"Cancel account linking" else "Link ItamarOS Account · QR")
            }
            if(wantQR && qrUrl.isNotBlank()) {
                val qr=remember(qrUrl) { qrBitmap(qrUrl) }
                Box(contentAlignment=Alignment.Center,
                    modifier=Modifier.fillMaxWidth()) {
                    Image(qr.asImageBitmap(),contentDescription="One-time ItamarOS account login QR",
                        modifier=Modifier.size(248.dp))
                    Surface(shape=RoundedCornerShape(12.dp),color=androidx.compose.ui.graphics.Color.White) {
                        Image(painterResource(R.drawable.itamaros_logo),
                            contentDescription="ItamarOS logo",
                            modifier=Modifier.padding(6.dp).size(39.dp))
                    }
                }
                Text("Verify your identity in the main ItamarOS app, then explicitly approve this login.")
                Text("Code: "+requestId.take(6).uppercase(),style=MaterialTheme.typography.titleMedium)
            }
            Text(status)
            Text("QR linking uses a temporary signed-in session. A device with an existing ItamarOS login is required. No SMS is sent by this app.")
            Text("Never approve a QR request you did not initiate.")
        }
    }
}
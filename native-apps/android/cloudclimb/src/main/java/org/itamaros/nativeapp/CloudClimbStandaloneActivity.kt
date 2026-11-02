package org.itamaros.nativeapp

import android.graphics.Bitmap
import android.content.Intent
import android.net.Uri
import android.graphics.Color as AndroidColor
import android.os.Bundle
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.style.TextAlign
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch
import androidx.compose.ui.text.input.PasswordVisualTransformation
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
    val context=LocalContext.current
    var isAuthenticated by remember { mutableStateOf(false) }
    var localPlay by remember { mutableStateOf(false) }
    var wantQR by remember { mutableStateOf(false) }
    var useItamarOSApp by remember { mutableStateOf(false) }
    var requestId by remember { mutableStateOf("") }
    var claimSecret by remember { mutableStateOf("") }
    var qrUrl by remember { mutableStateOf("") }
    var expiry by remember { mutableLongStateOf(0L) }
    var status by remember { mutableStateOf("Choose Play Offline or Link ItamarOS Account") }
    var connecting by remember { mutableStateOf(false) }
    var manualLogin by remember { mutableStateOf(false) }
    var manualIdentifier by remember { mutableStateOf("") }
    var manualPassword by remember { mutableStateOf("") }
    var manualCode by remember { mutableStateOf("") }
    var manualCodeRequested by remember { mutableStateOf(false) }
    val scope= rememberCoroutineScope()

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
            status=if(useItamarOSApp)
                "Confirm the login in ItamarOS, then return to Cloud Climb."
            else "Scan this QR using ItamarOS on your trusted signed-in phone."
            if(useItamarOSApp) {
                // Only the request ID crosses the app boundary, never the claim secret
                // or a Supabase access token. Require user verification in ItamarOS.
                val deepLink=Uri.Builder().scheme("itamaros").authority("cloud-climb")
                    .appendQueryParameter("request",requestId).build()
                try {
                    context.startActivity(Intent(Intent.ACTION_VIEW,deepLink)
                        .setPackage("org.itamaros.nativeapp"))
                }catch(_:Exception){
                    status="Could not open ItamarOS. Install the current app or use QR linking."
                }
            }
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
                    requestId="";claimSecret="";qrUrl="";wantQR=false;useItamarOSApp=false
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
    if (localPlay) {
        val local=remember { JSONObject().put("code","local-cloudclimb")
            .put("seed",1475).put("game","cloud_climb").put("status","playing") }
        CloudClimbAndroid(api,local,1,onExit={localPlay=false})
    } else {
        Box(
            modifier=Modifier.fillMaxSize().background(
                Brush.verticalGradient(listOf(
                    Color(0xFF0C1B46), Color(0xFF1B4D9E), Color(0xFF45BFE2)
                ))
            )
        ) {
            Column(
                modifier=Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                    .padding(horizontal=22.dp, vertical=28.dp),
                horizontalAlignment=Alignment.CenterHorizontally,
                verticalArrangement=Arrangement.spacedBy(14.dp)
            ) {
                Spacer(Modifier.height(6.dp))
                Box(
                    modifier=Modifier.size(174.dp),
                    contentAlignment=Alignment.Center
                ) {
                    Text("☁", fontSize=118.sp, color=Color.White.copy(alpha=0.25f),
                        modifier=Modifier.align(Alignment.BottomStart))
                    Surface(
                        shape=RoundedCornerShape(34.dp),
                        color=Color.White.copy(alpha=0.96f),
                        shadowElevation=15.dp
                    ) {
                        Image(
                            painterResource(R.drawable.cloud_climb_icon),
                            contentDescription="Cloud Climb game icon",
                            modifier=Modifier.padding(15.dp).size(110.dp)
                        )
                    }
                    Text("✦", fontSize=34.sp, color=Color(0xFFFFE680),
                        modifier=Modifier.align(Alignment.TopEnd))
                }
                Text(
                    "Cloud Climb By ItamarOS",
                    fontSize=34.sp, fontWeight=FontWeight.Black,
                    fontFamily=FontFamily(Font(R.font.fredoka)), letterSpacing=(-0.5).sp,
                    color=Color.White, textAlign=TextAlign.Center,
                    lineHeight=39.sp
                )
                Text(
                    "A sky-high platform adventure",
                    fontSize=16.sp, fontWeight=FontWeight.SemiBold,
                    fontFamily=FontFamily(Font(R.font.fredoka)),
                    color=Color(0xFFC5F5FF), textAlign=TextAlign.Center
                )
                Text(
                    "Sign in to play online, or explore the offline demo.",
                    fontSize=14.sp, color=Color.White.copy(alpha=0.83f),
                    textAlign=TextAlign.Center
                )
                Spacer(Modifier.height(4.dp))
                if (isAuthenticated) {
                    Surface(
                        modifier=Modifier.fillMaxWidth(),
                        shape=RoundedCornerShape(20.dp),
                        color=Color.White.copy(alpha=0.14f)
                    ) {
                        Column(Modifier.padding(15.dp),
                            verticalArrangement=Arrangement.spacedBy(7.dp)) {
                            Text("✓ Signed in with ItamarOS",
                                fontWeight=FontWeight.Bold,color=Color.White)
                            Text("Account "+api.userID.orEmpty().take(8),
                                color=Color.White.copy(alpha=0.78f))
                        }
                    }
                    ItamarPartyGamesAndroid(api,defaultGame="cloud_climb")
                    OutlinedButton(onClick={
                        api.token=null;api.userID=null;isAuthenticated=false
                    }){Text("Sign out",color=Color.White)}
                } else {
                    Button(
                        onClick={useItamarOSApp=true;wantQR=true},
                        enabled=!connecting && !wantQR,
                        modifier=Modifier.fillMaxWidth().heightIn(min=65.dp),
                        shape=RoundedCornerShape(20.dp),
                        colors=ButtonDefaults.buttonColors(
                            containerColor=Color(0xFF466BFA),
                            contentColor=Color.White
                        )
                    ) {
                        Image(
                            painterResource(R.drawable.itamaros_logo),
                            contentDescription=null,
                            modifier=Modifier.size(33.dp)
                        )
                        Spacer(Modifier.width(12.dp))
                        Text(if(connecting)"Connecting…" else "Sign in with ItamarOS",
                            fontWeight=FontWeight.Bold,fontSize=17.sp,
                            fontFamily=FontFamily(Font(R.font.fredoka)))
                    }
                    OutlinedButton(
                        onClick={
                            manualLogin=!manualLogin
                            manualCodeRequested=false;manualCode=""
                        },
                        enabled=!connecting && !wantQR,
                        modifier=Modifier.fillMaxWidth()
                    ) {
                        Text(if(manualLogin)"Hide manual login" else "Sign in manually",
                            color=Color.White)
                    }
                    if(manualLogin && !wantQR){
                        Column(Modifier.fillMaxWidth(),
                            verticalArrangement=Arrangement.spacedBy(9.dp)){
                            OutlinedTextField(
                                value=manualIdentifier,
                                onValueChange={manualIdentifier=it.take(254)},
                                label={Text("Email or phone number")},
                                singleLine=true,
                                modifier=Modifier.fillMaxWidth(),
                                colors=OutlinedTextFieldDefaults.colors(
                                    focusedTextColor=Color.White,
                                    unfocusedTextColor=Color.White,
                                    focusedLabelColor=Color.White,
                                    unfocusedLabelColor=Color.White
                                )
                            )
                            OutlinedTextField(
                                value=manualPassword,
                                onValueChange={manualPassword=it.take(256)},
                                label={Text("Password (optional)")},
                                singleLine=true,
                                visualTransformation=PasswordVisualTransformation(),
                                modifier=Modifier.fillMaxWidth(),
                                colors=OutlinedTextFieldDefaults.colors(
                                    focusedTextColor=Color.White,
                                    unfocusedTextColor=Color.White,
                                    focusedLabelColor=Color.White,
                                    unfocusedLabelColor=Color.White
                                )
                            )
                            Button(
                                onClick={
                                    scope.launch {
                                        connecting=true
                                        try{
                                            api.loginManually(manualIdentifier,manualPassword)
                                            manualPassword="";manualCode=""
                                            manualCodeRequested=false;manualLogin=false
                                            isAuthenticated=true
                                            status="Signed in with your ItamarOS account."
                                        }catch(e:Exception){
                                            status=e.localizedMessage ?: "Manual login failed"
                                        }finally{connecting=false}
                                    }
                                },
                                enabled=!connecting && manualIdentifier.isNotBlank()
                                    && manualPassword.isNotBlank()
                            ){Text("Sign in with password")}
                            OutlinedButton(
                                onClick={
                                    scope.launch {
                                        connecting=true
                                        try{
                                            api.requestExistingSms(manualIdentifier.trim())
                                            manualCodeRequested=true
                                            status="Check your registered phone for a login SMS."
                                        }catch(e:Exception){
                                            status=e.localizedMessage ?: "Could not send SMS"
                                        }finally{connecting=false}
                                    }
                                },
                                enabled=!connecting && manualIdentifier.isNotBlank()
                            ){Text("Send SMS login code instead",color=Color.White)}
                            if(manualCodeRequested){
                                OutlinedTextField(
                                    value=manualCode,onValueChange={manualCode=it.take(8)},
                                    label={Text("SMS verification code")},singleLine=true,
                                    modifier=Modifier.fillMaxWidth()
                                )
                                Button(onClick={
                                    scope.launch{
                                        connecting=true
                                        try{
                                            api.verifySms(manualIdentifier.trim(),manualCode.trim())
                                            manualPassword="";manualCode=""
                                            manualCodeRequested=false;manualLogin=false
                                            isAuthenticated=true
                                            status="Your ItamarOS account is connected."
                                        }catch(e:Exception){
                                            status=e.localizedMessage ?: "Invalid SMS code"
                                        }finally{connecting=false}
                                    }
                                },enabled=!connecting && manualCode.isNotBlank()){
                                    Text("Verify SMS and sign in")
                                }
                            }
                            Text("Without a password, use SMS or approve a QR code in an already signed-in ItamarOS app. SMS may have a cost.",
                                color=Color.White.copy(alpha=0.77f),fontSize=12.sp)
                        }
                    }
                    OutlinedButton(
                        onClick={localPlay=true},
                        modifier=Modifier.fillMaxWidth().heightIn(min=61.dp),
                        shape=RoundedCornerShape(20.dp),
                        border=androidx.compose.foundation.BorderStroke(
                            1.dp,Color.White.copy(alpha=0.55f)
                        )
                    ) {
                        Text("🎮 Play Offline Demo",fontSize=17.sp,
                            fontWeight=FontWeight.Bold,color=Color.White)
                    }
                    TextButton(
                        onClick={useItamarOSApp=false;wantQR=true},
                        enabled=!connecting && !wantQR
                    ) {
                        Text("Use a QR code instead", color=Color.White.copy(alpha=0.9f))
                    }
                    if (wantQR) {
                        Text("Compare this code in ItamarOS: "+
                            requestId.take(6).uppercase(),
                            fontWeight=FontWeight.Bold,color=Color.White,
                            textAlign=TextAlign.Center)
                        TextButton(onClick={
                            wantQR=false;requestId="";claimSecret="";qrUrl=""
                        }){Text("Cancel Account Linking",color=Color.White)}
                    }
                    if (wantQR && !useItamarOSApp && qrUrl.isNotBlank()) {
                        val qr=remember(qrUrl) { qrBitmap(qrUrl) }
                        Box(contentAlignment=Alignment.Center,
                            modifier=Modifier.fillMaxWidth()) {
                            Image(qr.asImageBitmap(),
                                contentDescription="One-time ItamarOS login QR",
                                modifier=Modifier.size(248.dp))
                            Surface(shape=RoundedCornerShape(12.dp),
                                color=Color.White) {
                                Image(painterResource(R.drawable.itamaros_logo),
                                    contentDescription="ItamarOS logo",
                                    modifier=Modifier.padding(6.dp).size(39.dp))
                            }
                        }
                        Text("Verify your identity and explicitly approve this login.",
                            color=Color.White,textAlign=TextAlign.Center)
                    }
                }
                Surface(
                    modifier=Modifier.fillMaxWidth(),
                    shape=RoundedCornerShape(17.dp),
                    color=Color.White.copy(alpha=0.12f)
                ) {
                    Column(Modifier.padding(15.dp),
                        verticalArrangement=Arrangement.spacedBy(7.dp)) {
                        Text(status,color=Color.White,
                            fontSize=13.sp,textAlign=TextAlign.Center,
                            modifier=Modifier.fillMaxWidth())
                        if (!isAuthenticated) {
                            Text(
                                "Your password is never shared. Approve only a sign-in you started yourself.",
                                color=Color.White.copy(alpha=0.73f),
                                fontSize=12.sp,textAlign=TextAlign.Center
                            )
                        }
                    }
                }
            }
        }
    }
}
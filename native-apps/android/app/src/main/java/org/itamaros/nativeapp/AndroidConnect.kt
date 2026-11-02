package org.itamaros.nativeapp

import android.content.Intent
import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest
import com.google.android.gms.auth.api.identity.Identity
import java.io.ByteArrayOutputStream
import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

// Session-only REST client. There is NO upload of the device's address book.
class AndroidConnectApi {
    private val base = BuildConfig.ITAMAR_SUPABASE_URL.trimEnd('/')
    private val key = BuildConfig.ITAMAR_SUPABASE_PUBLISHABLE_KEY
    var token:String?=null
    var userID:String?=null
    val configured=base.startsWith("https://")&&base.contains(".supabase.co")&&key.isNotBlank()

    suspend fun request(path:String,method:String="GET",body:JSONObject?=null,authenticated:Boolean=true):String=
      withContext(Dispatchers.IO) {
        if(!configured)throw IllegalStateException("Cloud messaging not configured")
        val conn=URL(base+path).openConnection() as HttpURLConnection
        try {
            conn.requestMethod=method
            conn.connectTimeout=15000
            conn.readTimeout=15000
            conn.setRequestProperty("apikey",key)
            if(authenticated){
                val auth=token?:throw IllegalStateException("Sign in first")
                conn.setRequestProperty("Authorization","Bearer "+auth)
            }
            if(body!=null){
                conn.doOutput=true
                conn.setRequestProperty("Content-Type","application/json")
                conn.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}
            }
            val success=conn.responseCode in 200..299
            val text=(if(success)conn.inputStream else conn.errorStream)
                ?.bufferedReader()?.use{it.readText()}.orEmpty()
            if(!success){
                val reason=runCatching{JSONObject(text).optString("message")}.getOrNull().orEmpty()
                throw IllegalStateException(if(reason.isNotEmpty())reason else "HTTP "+conn.responseCode)
            }
            text
        }finally{conn.disconnect()}
      }
    suspend fun login(email:String,password:String,register:Boolean){
        val path=if(register)"/auth/v1/signup" else "/auth/v1/token?grant_type=password"
        val r=JSONObject(request(path,"POST",JSONObject().put("email",email).put("password",password),false))
        token=r.optString("access_token").ifEmpty{throw IllegalStateException("Confirm your email, then sign in")}
        userID=r.optJSONObject("user")?.optString("id")
    }
    // Manual Cloud Climb login uses the SAME Supabase user as ItamarOS.
    suspend fun loginManually(identifier:String,password:String){
        val clean=identifier.trim()
        require(password.isNotBlank()){"Enter your password"}
        val body=JSONObject().put("password",password)
        when{
            Regex("^\\+[1-9][0-9]{7,14}$").matches(clean)->body.put("phone",clean)
            android.util.Patterns.EMAIL_ADDRESS.matcher(clean).matches()->body.put("email",clean)
            else->throw IllegalArgumentException("Enter a valid registered email or international phone number")
        }
        val result=JSONObject(request("/auth/v1/token?grant_type=password","POST",body,false))
        val session=result.optString("access_token")
        val uid=result.optJSONObject("user")?.optString("id").orEmpty()
        if(session.isBlank()||uid.isBlank())throw IllegalStateException("Invalid sign-in response")
        token=session;userID=uid
    }
    suspend fun requestExistingSms(phone:String){
        require(Regex("^\\+[1-9][0-9]{7,14}$").matches(phone)){
            "Enter the phone number registered with your ItamarOS account"
        }
        request("/auth/v1/otp","POST",
            JSONObject().put("phone",phone).put("create_user",false),false)
    }
    // Email/password accounts require email confirmation; phone and photo are optional.
    suspend fun registerAccount(email:String,password:String,handle:String,phone:String){
        require(android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()){"Enter a valid email"}
        require(password.length>=8){"Password must have at least 8 characters"}
        require(Regex("^[a-z0-9_.]{3,24}$").matches(handle)){"Username must have 3–24 valid characters"}
        require(phone.isEmpty()||Regex("^\+[1-9][0-9]{7,14}$").matches(phone)){
            "Optional phone must start with +country code"
        }
        val metadata=JSONObject().put("preferred_username",handle)
        if(phone.isNotEmpty())metadata.put("unverified_contact_phone",phone)
        request("/auth/v1/signup","POST",JSONObject()
            .put("email",email).put("password",password)
            .put("data",metadata),false)
        // The user is not considered signed-in until their email has been confirmed.
    }
    suspend fun requestedUsername():String{
        val result=JSONObject(request("/auth/v1/user","GET"))
        return result.optJSONObject("user_metadata")?.optString("preferred_username").orEmpty()
    }
    suspend fun approveDesktopPairing(request:String){
        require(Regex("[A-Za-z0-9_-]{24,40}").matches(request)){"Invalid QR request"}
        val jwt=token?:throw IllegalStateException("Sign in to Connect first")
        withContext(Dispatchers.IO){
            val conn=URL("https://itamaros-store-api.onrender.com/api/connect/pair/approve")
                .openConnection() as HttpURLConnection
            try {
                conn.requestMethod="POST"
                conn.connectTimeout=10000
                conn.readTimeout=10000
                conn.doOutput=true
                conn.setRequestProperty("Content-Type","application/json")
                conn.setRequestProperty("Authorization","Bearer "+jwt)
                val payload=JSONObject().put("requestId",request).toString()
                conn.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
                if(conn.responseCode !in 200..299){
                    val error=runCatching {
                        JSONObject(conn.errorStream?.bufferedReader()?.use{it.readText()}.orEmpty())
                            .optString("error")
                    }.getOrNull().orEmpty()
                    throw IllegalStateException(error.ifBlank{"Computer approval rejected"})
                }
            } finally { conn.disconnect() }
        }
    }
    suspend fun requestSms(phone:String){
        require(Regex("^\\+[1-9][0-9]{7,14}$").matches(phone)) {
            "Enter an international phone number belonging to you"
        }
        request("/auth/v1/otp","POST",JSONObject().put("phone",phone),false)
    }
    suspend fun verifySms(phone:String,code:String){
        require(Regex("^[0-9]{4,8}$").matches(code)){"Enter the SMS verification code"}
        val result=JSONObject(request("/auth/v1/verify","POST",JSONObject()
            .put("phone",phone).put("token",code).put("type","sms"),false))
        token=result.optString("access_token").ifEmpty {
            throw IllegalStateException("The code was not verified")
        }
        userID=result.optJSONObject("user")?.optString("id")
    }
    suspend fun setOptionalPassword(value:String){
        require(value.length>=8){"Optional password must be at least 8 characters"}
        request("/auth/v1/user","PUT",JSONObject().put("password",value))
    }
    suspend fun profile():JSONObject?{
        val id=userID?:return null
        val result=JSONArray(request("/rest/v1/itamar_profiles?id=eq."+id+"&select=id,username,display_name,avatar_path,read_receipts_enabled"))
        return if(result.length()>0)result.getJSONObject(0)else null
    }
    suspend fun createProfile(name:String,handle:String){
        val body=JSONObject().put("username",handle.lowercase()).put("display_name",name).put("about","")
        if(profile()==null){
            body.put("id",userID)
            request("/rest/v1/itamar_profiles","POST",body)
        }else{
            request("/rest/v1/itamar_profiles?id=eq."+userID,"PATCH",body)
        }
    }
    suspend fun rooms()=JSONArray(request("/rest/v1/rpc/itamar_my_rooms","POST",JSONObject()))
    suspend fun messages(room:String)=JSONArray(request("/rest/v1/itamar_messages?room_id=eq."+room+
        "&select=id,body,sender_id,attachment_path,attachment_name&order=created_at.asc&limit=100"))
    suspend fun send(room:String,text:String){
        request("/rest/v1/itamar_messages","POST",JSONObject()
            .put("room_id",room).put("sender_id",userID).put("body",text))
    }
    suspend fun create(kind:String,title:String,username:String){
        if(kind=="group"){
            val values=JSONArray()
            username.split(',').map{it.trim().removePrefix("@")}.filter{it.isNotEmpty()}.forEach{values.put(it)}
            request("/rest/v1/rpc/itamar_create_group","POST",
                JSONObject().put("p_title",title).put("p_usernames",values))
        }else{
            request("/rest/v1/rpc/itamar_create_room","POST",
                JSONObject().put("p_title",title).put("p_kind",kind).put("p_username",username))
        }
    }
    suspend fun contacts()=JSONArray(request("/rest/v1/rpc/itamar_my_contacts","POST",JSONObject()))
    suspend fun addContact(username:String){
        request("/rest/v1/rpc/itamar_add_contact","POST",
            JSONObject().put("p_username",username).put("p_nickname",""))
    }
    suspend fun findPhone(phone:String)=JSONArray(request("/rest/v1/rpc/itamar_find_verified_phone",
        "POST",JSONObject().put("p_phone",phone)))
    suspend fun mute(room:String,enabled:Boolean){
        request("/rest/v1/rpc/itamar_set_mute","POST",JSONObject().put("p_room",room).put("p_muted",enabled))
    }
    suspend fun polls(room:String)=JSONArray(request("/rest/v1/itamar_polls?room_id=eq."+room+
        "&select=id,question,options,closed&order=created_at.desc"))
    suspend fun vote(poll:String,option:Int){
        request("/rest/v1/rpc/itamar_vote_poll","POST",
            JSONObject().put("p_poll",poll).put("p_option",option))
    }

    suspend fun uploadAvatar(context:Context,uri:Uri,group:String?=null):String {
        val id=userID?:throw IllegalStateException("Sign in")
        val image=withContext(Dispatchers.IO) {
            context.contentResolver.openInputStream(uri)?.use { input->
                BitmapFactory.decodeStream(input)
            }?:throw IllegalStateException("Invalid photo")
        }
        val stream=ByteArrayOutputStream()
        try{
            if(image.width>4096||image.height>4096)throw IllegalStateException("Choose an image no larger than 4096px")
            image.compress(Bitmap.CompressFormat.JPEG,75,stream)
        }finally{image.recycle()}
        val bytes=stream.toByteArray()
        if(bytes.isEmpty()||bytes.size>3*1024*1024)
            throw IllegalStateException("Profile photo must be less than 3 MB")
        val path=(if(group==null)"profiles/"+id else "groups/"+group)+"/"+
            java.util.UUID.randomUUID().toString()+".jpg"
        withContext(Dispatchers.IO){
            val conn=URL(base+"/storage/v1/object/itamar-connect-avatars/"+path).openConnection() as HttpURLConnection
            try{
                conn.requestMethod="POST";conn.doOutput=true
                conn.setRequestProperty("apikey",key)
                conn.setRequestProperty("Authorization","Bearer "+(token?:""))
                conn.setRequestProperty("Content-Type","image/jpeg")
                conn.outputStream.use{it.write(bytes)}
                if(conn.responseCode !in 200..299)
                    throw IllegalStateException("Avatar upload rejected")
            }finally{conn.disconnect()}
        }
        return path
    }
    suspend fun profilePreferences(avatar:String?,receipts:Boolean){
        request("/rest/v1/rpc/itamar_set_profile_prefs","POST",JSONObject()
            .put("p_avatar",avatar ?: JSONObject.NULL).put("p_receipts",receipts))
    }
    suspend fun groupDetails(room:String,title:String,description:String,avatar:String?){
        request("/rest/v1/rpc/itamar_set_group_details","POST",JSONObject()
            .put("p_room",room).put("p_title",title).put("p_description",description)
            .put("p_avatar",avatar ?: JSONObject.NULL))
    }
    fun avatarLink(path:String)=base+"/storage/v1/object/public/itamar-connect-avatars/"+path
    suspend fun addGroupMember(room:String,username:String){
        request("/rest/v1/rpc/itamar_group_manage","POST",JSONObject()
            .put("p_room",room).put("p_operation","add")
            .put("p_username",username).put("p_title",""))
    }
    suspend fun makeInvite(room:String):String {
        val text=request("/rest/v1/rpc/itamar_make_group_invite","POST",
            JSONObject().put("p_room",room))
        return text.trim().trim('"')
    }
    suspend fun acceptInvite(token:String) {
        request("/rest/v1/rpc/itamar_accept_group_invite","POST",
            JSONObject().put("p_secret",token))
    }
    suspend fun renameGroup(room:String,title:String,description:String){
        request("/rest/v1/rpc/itamar_set_group_details","POST",
            JSONObject().put("p_room",room).put("p_title",title)
                .put("p_description",description).put("p_avatar",JSONObject.NULL))
    }
    suspend fun edit(id:String,text:String){
        request("/rest/v1/rpc/itamar_edit_message","POST",
            JSONObject().put("p_message",id).put("p_body",text))
    }
    suspend fun delete(id:String){
        request("/rest/v1/rpc/itamar_delete_message","POST",
            JSONObject().put("p_message",id))
    }
    suspend fun sendOnce(room:String,text:String){
        request("/rest/v1/rpc/itamar_send_once_text","POST",
            JSONObject().put("p_room",room).put("p_text",text))
    }
    suspend fun openOnce(id:String):String =
        request("/rest/v1/rpc/itamar_open_once_text","POST",
            JSONObject().put("p_message",id)).trim().trim('"')
    suspend fun acknowledge(room:String,opened:Boolean){
        request("/rest/v1/rpc/itamar_ack_messages","POST",
            JSONObject().put("p_room",room).put("p_opened",opened))
    }
    suspend fun receipt(messageID:String):Pair<Int,Int>{
        val result=JSONArray(request("/rest/v1/itamar_message_receipts?message_id=eq."+
            messageID+"&select=delivered_at,read_at"))
        var delivered=0;var read=0
        for(i in 0 until result.length()){
            val r=result.optJSONObject(i)?:continue
            if(!r.isNull("delivered_at"))delivered++
            if(!r.isNull("read_at"))read++
        }
        return delivered to read
    }
    suspend fun reply(room:String,parent:String,text:String) {
        request("/rest/v1/rpc/itamar_send_reply","POST",JSONObject()
            .put("p_room",room).put("p_parent",parent).put("p_body",text))
    }
    suspend fun disappearingText(room:String,text:String,seconds:Int) {
        if(seconds !in listOf(3600,86400,604800))throw IllegalArgumentException("Invalid timer")
        request("/rest/v1/rpc/itamar_send_disappearing_text","POST",JSONObject()
            .put("p_room",room).put("p_body",text).put("p_seconds",seconds))
    }
    suspend fun react(id:String,emoji:String) {
        request("/rest/v1/rpc/itamar_react","POST",JSONObject()
            .put("p_message",id).put("p_emoji",emoji))
    }
    suspend fun removeReaction(id:String) {
        request("/rest/v1/rpc/itamar_remove_reaction","POST",JSONObject().put("p_message",id))
    }
    suspend fun reactions(items:JSONArray):Map<String,List<String>>{
        val ids=(0 until items.length()).mapNotNull{items.optJSONObject(it)?.optString("id")}
        if(ids.isEmpty())return emptyMap()
        val response=JSONArray(request("/rest/v1/itamar_reactions?message_id=in.("+
            ids.takeLast(80).joinToString(",")+")&select=message_id,emoji"))
        val results=mutableMapOf<String,MutableList<String>>()
        for(i in 0 until response.length()){
            val row=response.optJSONObject(i)?:continue
            results.getOrPut(row.optString("message_id")){mutableListOf()}.add(row.optString("emoji"))
        }
        return results
    }
    suspend fun report(id:String,reason:String) {
        request("/rest/v1/rpc/itamar_report_message","POST",JSONObject()
            .put("p_message",id).put("p_reason",reason).put("p_detail",""))
    }
    suspend fun block(id:String) {
        val mine=userID?:throw IllegalStateException("Sign in first")
        if(mine==id)return
        request("/rest/v1/itamar_blocks","POST",JSONObject()
            .put("blocker_id",mine).put("blocked_id",id))
    }
    suspend fun uploadAttachment(context:Context,uri:Uri,room:String){
        if(!configured)throw IllegalStateException("Connect is not configured")
        val mime=context.contentResolver.getType(uri)
            ?: if(uri.path?.endsWith(".m4a",ignoreCase=true)==true)"audio/mp4"
               else throw IllegalStateException("Unknown file type")
        val allowed=setOf("image/jpeg","image/png","image/gif","image/webp","image/heic",
            "video/mp4","video/quicktime","audio/mpeg","audio/mp4","audio/wav",
            "application/pdf","text/plain","text/vcard","text/calendar")
        if(mime !in allowed)throw IllegalStateException("Choose a supported image, video, audio or document")
        val name=context.contentResolver.query(uri,arrayOf(OpenableColumns.DISPLAY_NAME),null,null,null)?.use{
            if(it.moveToFirst())it.getString(0)else null
        }?:"attachment"
        val fileName=name.take(80).replace("/","_")
        val bytes=withContext(Dispatchers.IO){
            val data=ByteArrayOutputStream()
            context.contentResolver.openInputStream(uri)?.use{input->
                val buffer=ByteArray(8192)
                while(true){
                    val count=input.read(buffer)
                    if(count<0)break
                    data.write(buffer,0,count)
                    if(data.size()>20*1024*1024)throw IllegalStateException("20 MB maximum")
                }
            }?:throw IllegalStateException("Cannot open attachment")
            data.toByteArray()
        }
        if(bytes.isEmpty())throw IllegalStateException("Empty attachment")
        val path=room+"/" + java.util.UUID.randomUUID().toString()+"/"+Uri.encode(fileName)
        withContext(Dispatchers.IO){
            val connection=URL(base+"/storage/v1/object/itamar-connect-media/"+path)
                .openConnection() as HttpURLConnection
            try{
                connection.requestMethod="POST";connection.doOutput=true
                connection.setRequestProperty("apikey",key)
                connection.setRequestProperty("Authorization","Bearer "+(token?:""))
                connection.setRequestProperty("Content-Type",mime)
                connection.setRequestProperty("x-upsert","false")
                connection.outputStream.use{it.write(bytes)}
                if(connection.responseCode !in 200..299)
                    throw IllegalStateException("Attachment upload denied: HTTP "+connection.responseCode)
            }finally{connection.disconnect()}
        }
        request("/rest/v1/itamar_messages","POST",JSONObject()
            .put("room_id",room).put("sender_id",userID)
            .put("body","📎 "+fileName).put("attachment_path",path)
            .put("attachment_name",fileName).put("attachment_mime",mime))
    }
    suspend fun setPhone(phone:String){
        request("/auth/v1/user","PUT",JSONObject().put("phone",phone))
    }
    suspend fun verifyPhone(phone:String,code:String){
        request("/auth/v1/verify","POST",JSONObject().put("phone",phone)
            .put("token",code).put("type","phone_change"))
    }
    suspend fun phoneDiscovery(enabled:Boolean){
        request("/rest/v1/rpc/itamar_set_phone_discovery","POST",JSONObject().put("p_enabled",enabled))
    }
    suspend fun newPoll(room:String,question:String,options:String){
        val choices=JSONArray()
        options.split("\n").map{it.trim()}.filter{it.isNotEmpty()}.forEach{choices.put(it)}
        request("/rest/v1/rpc/itamar_create_poll","POST",JSONObject()
            .put("p_room",room).put("p_question",question).put("p_options",choices).put("p_multiple",false))
    }
}

@Composable
private fun PublicAvatar(path:String?){
    var photo by remember(path){mutableStateOf<Bitmap?>(null)}
    LaunchedEffect(path) {
        photo=null
        if(path!=null && path.matches(Regex("(profiles|groups)/[a-f0-9-]+/[a-f0-9-]+\\.jpg"))){
            photo=withContext(Dispatchers.IO) {
                runCatching {
                    val base=BuildConfig.ITAMAR_SUPABASE_URL.trimEnd('/')
                    URL(base+"/storage/v1/object/public/itamar-connect-avatars/"+path)
                        .openStream().use{BitmapFactory.decodeStream(it)}
                }.getOrNull()
            }
        }
    }
    if(photo!=null)Image(photo!!.asImageBitmap(),contentDescription="Profile or group image",
       modifier=Modifier.size(96.dp))
}
@Composable
private fun PublicContactQR(username:String){
    val url="https://itamaros-web-emulator.onrender.com/contact.html?username="+username
    PublicLinkQR(url)
}
@Composable
private fun PublicLinkQR(url:String){
    val bitmap=remember(url){
        runCatching{
            val encoded=MultiFormatWriter().encode(url,BarcodeFormat.QR_CODE,200,200)
            Bitmap.createBitmap(200,200,Bitmap.Config.ARGB_8888).apply{
                for(y in 0 until 200)for(x in 0 until 200)
                    setPixel(x,y,if(encoded[x,y])android.graphics.Color.BLACK else android.graphics.Color.WHITE)
            }
        }.getOrNull()
    }
    if(bitmap!=null)Image(bitmap.asImageBitmap(),contentDescription="Public username QR",modifier=Modifier.size(200.dp))
}

@Composable
fun AndroidConnectScreen(
    api: AndroidConnectApi,
    groupInvite:String?=null,
    contactUsername:String?=null,
    desktopRequest:String?=null,
    cloudClimbRequest:String?=null,
    authOnly:Boolean=false,
    onAccountReady:(String)->Unit={},
    onSignOut:()->Unit={}
){
    val ctx=LocalContext.current
    val scope=rememberCoroutineScope()
    var signed by remember(api){mutableStateOf(api.token!=null)}
    var registration by remember{mutableStateOf(false)}
    var email by remember{mutableStateOf("")}
    var registrationUsername by remember{mutableStateOf("")}
    var password by remember{mutableStateOf("")}
    var signInPhone by remember{mutableStateOf("")}
    var otpInput by remember{mutableStateOf("")}
    var codeRequested by remember{mutableStateOf(false)}
    var pendingDesktopRequest by remember{mutableStateOf("")}
    var pendingCloudClimb by remember { mutableStateOf(false) }
    var desktopApprovalStatus by remember{mutableStateOf("")}
    var credentialRequest by remember { mutableStateOf("") }
    val approvalCredentialPrompt = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val pending = credentialRequest
        credentialRequest = ""
        if (result.resultCode == Activity.RESULT_OK &&
            pending == pendingDesktopRequest && pending.isNotBlank()) {
            scope.launch {
                try {
                    api.approveDesktopPairing(pending)
                    pendingDesktopRequest = ""
                    desktopApprovalStatus = if(pendingCloudClimb)
                        "Cloud Climb account approved. Return to Cloud Climb to finish."
                    else "Verified. Login approved on your other device."
                } catch (e: Exception) {
                    desktopApprovalStatus = e.localizedMessage ?: "Unable to approve login"
                }
            }
        } else {
            desktopApprovalStatus = "Device verification was cancelled or failed. Login not approved."
        }
    }
    var pendingSignupAvatar by remember{mutableStateOf<Uri?>(null)}
    var syncOnThisDevice by remember {
        mutableStateOf(ctx.getSharedPreferences("itamaros_native",Context.MODE_PRIVATE)
            .getBoolean("connectSync",true))
    }
    var handle by remember{mutableStateOf("")}
    var displayName by remember{mutableStateOf("")}
    var tab by remember{mutableStateOf("Chats")}
    var kind by remember{mutableStateOf("chat")}
    var title by remember{mutableStateOf("")}
    var other by remember{mutableStateOf("")}
    var rooms by remember{mutableStateOf(JSONArray())}
    var contacts by remember{mutableStateOf(JSONArray())}
    var messages by remember{mutableStateOf(JSONArray())}
    var polls by remember{mutableStateOf(JSONArray())}
    var selectedRoom by remember{mutableStateOf("")}
    var message by remember{mutableStateOf("")}
    var question by remember{mutableStateOf("")}
    var pollOptions by remember{mutableStateOf("Yes\nNo")}
    var lookupResult by remember{mutableStateOf("")}
    var notice by remember{mutableStateOf("")}
    var pushNotice by remember{mutableStateOf("")}
    var inviteToken by remember{mutableStateOf("")}
    var inviteToJoin by remember{mutableStateOf("")}
    var groupDescription by remember{mutableStateOf("")}
    var editingID by remember{mutableStateOf("")}
    var viewOnce by remember{mutableStateOf(false)}
    var openedSecret by remember{mutableStateOf("")}
    var receipts by remember{mutableStateOf(mapOf<String,Pair<Int,Int>>())}
    var reactions by remember{mutableStateOf(mapOf<String,List<String>>())}
    var reactionTarget by remember{mutableStateOf("")}
    val voiceRecorder=remember{AndroidVoiceNoteRecorder(ctx)}
    var recordingVoice by remember{mutableStateOf(false)}
    var replyTarget by remember{mutableStateOf("")}
    var expiringSeconds by remember{mutableIntStateOf(0)}
    var reportTarget by remember{mutableStateOf("")}
    var profileAvatar by remember{mutableStateOf<String?>(null)}
    var roomAvatar by remember{mutableStateOf<String?>(null)}
    var readReceiptPreference by remember{mutableStateOf(true)}
    var avatarTarget by remember{mutableStateOf("")}
    LaunchedEffect(groupInvite) {
        if(groupInvite?.matches(Regex("[a-f0-9]{48}"))==true) {
            inviteToJoin=groupInvite
            tab="Profile"
        }
    }
    LaunchedEffect(desktopRequest,cloudClimbRequest) {
        val request=cloudClimbRequest ?: desktopRequest
        if(request?.matches(Regex("[A-Za-z0-9_-]{24,40}"))==true){
            pendingDesktopRequest=request
            pendingCloudClimb=cloudClimbRequest!=null
            desktopApprovalStatus=""
        }
    }
    LaunchedEffect(contactUsername) {
        if(contactUsername?.matches(Regex("[a-z0-9_.]{3,24}"))==true) {
            other=contactUsername
            tab="Contacts"
        }
    }
    var ownPhone by remember{mutableStateOf("")}
    var ownCode by remember{mutableStateOf("")}
    var searchable by remember{mutableStateOf(false)}

    // Google Play services proposes SIM-based phone numbers in a system chooser.
    // Never silently read, save or send a phone number; the user must select it.
    var hintForProfile by remember { mutableStateOf(false) }
    var hintWasManual by remember { mutableStateOf(false) }
    val phoneHintLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val selected = result.data?.let { returnedIntent ->
                runCatching {
                    Identity.getSignInClient(ctx).getPhoneNumberFromIntent(returnedIntent)
                        .replace(Regex("[\\s()-]"), "")
                }.getOrNull()
            }
            if (selected != null && Regex("^\\+[1-9][0-9]{7,14}$").matches(selected)) {
                if (hintForProfile) ownPhone = selected else signInPhone = selected
                notice = "Number suggested by your device. Confirm it before sending an SMS."
            } else if (hintWasManual) {
                notice = "No international number was available. Enter it with +country code."
            }
        }
    }
    fun offerPhoneHint(forProfile: Boolean, manual: Boolean) {
        hintForProfile = forProfile
        hintWasManual = manual
        val request = GetPhoneNumberHintIntentRequest.builder().build()
        try {
            Identity.getSignInClient(ctx).getPhoneNumberHintIntent(request)
                .addOnSuccessListener { intent ->
                    try {
                        phoneHintLauncher.launch(IntentSenderRequest.Builder(intent).build())
                    } catch (_: Exception) {
                        if (manual) notice = "Device number suggestion unavailable. Enter your number."
                    }
                }
                .addOnFailureListener {
                    if (manual) notice = "No phone number suggestion. Enter your number manually."
                }
        } catch (_: Exception) {
            if (manual) notice = "Device number suggestion unavailable. Enter your number."
        }
    }
    LaunchedEffect(api.configured, signed) {
        // One automatic suggestion at first sign-in; user can decline, or type instead.
        val prefs = ctx.getSharedPreferences("itamaros_native", Context.MODE_PRIVATE)
        if (api.configured && !signed && signInPhone.isBlank() &&
            !prefs.getBoolean("phone_hint_first_signin_shown", false)) {
            prefs.edit().putBoolean("phone_hint_first_signin_shown", true).apply()
            offerPhoneHint(forProfile = false, manual = false)
        }
    }

    fun perform(action:suspend()->Unit){
        scope.launch{try{action();notice=""}catch(e:Exception){notice=e.localizedMessage?:"Operation failed"}}
    }
    val chooseSignupAvatar=rememberLauncherForActivityResult(ActivityResultContracts.GetContent()){ uri ->
        pendingSignupAvatar=uri
    }
    val chooseAvatar=rememberLauncherForActivityResult(ActivityResultContracts.GetContent()){ uri ->
        if(uri!=null){
            perform{
                val group=if(avatarTarget=="group")selectedRoom else null
                val path=api.uploadAvatar(ctx,uri,group)
                if(group==null){
                    profileAvatar=path
                    api.profilePreferences(profileAvatar,readReceiptPreference)
                }else{
                    roomAvatar=path
                    api.groupDetails(selectedRoom,title,groupDescription,roomAvatar)
                    rooms=api.rooms()
                }
            }
        }
    }
    val pushPermission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){ granted ->
        if(granted)ItamarAndroidPush.register(ctx,api){ pushNotice=it }
        else pushNotice="Chat notification permission declined."
    }
    val microphonePermission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){ granted ->
        if(granted) {
            try{voiceRecorder.start();recordingVoice=true}
            catch(e:Exception){notice=e.localizedMessage?:"Cannot record audio"}
        } else {notice="Microphone permission declined"}
    }
    DisposableEffect(Unit) {
        onDispose { voiceRecorder.discard() }
    }
    val chooseAttachment=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){ uri ->
        if(uri!=null && selectedRoom.isNotBlank()){
            perform {
                api.uploadAttachment(ctx,uri,selectedRoom)
                messages=api.messages(selectedRoom)
            }
        }
    }
    if(!api.configured){
        Text("ItamarOS Connect needs a separately configured Supabase project before real chats can synchronize.")
        Text("No contacts are uploaded and no online accounts are created until cloud mode is configured.")
        return
    }
    if(!signed){
        Text("ItamarOS Connect",style=MaterialTheme.typography.headlineMedium)
        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){
            Button(onClick={registration=false},enabled=registration){Text("Sign In")}
            Button(onClick={registration=true},enabled=!registration){Text("Create account")}
        }
        Text(if(registration)
            "Username, email and password are required. Phone and photo are optional. Check your email for the confirmation link."
            else "Sign in with your ItamarOS email and password. QR approval is supported in Cloud Climb.")
        if(registration){
            OutlinedTextField(registrationUsername,
                {registrationUsername=it.lowercase().trim().take(24)},
                label={Text("Username *")},singleLine=true)
        }
        OutlinedTextField(email,{email=it.trim().take(254)},
            label={Text("Email *")},singleLine=true,
            keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Email))
        OutlinedTextField(password,{password=it},
            label={Text("Password * (at least 8 characters)")},
            visualTransformation=PasswordVisualTransformation(),singleLine=true)
        if(registration){
            OutlinedTextField(signInPhone,{signInPhone=it.trim()},
                label={Text("Phone (optional; unverified)")},singleLine=true,
                keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Phone))
            TextButton(onClick={offerPhoneHint(forProfile=false,manual=true)}) {
                Text("Suggest my phone number (Android, with approval)")
            }
            Button(onClick={chooseSignupAvatar.launch("image/*")}){
                Text(if(pendingSignupAvatar==null)"Choose profile photo (optional)" else "Photo selected — change")
            }
            Button(onClick={perform{
                api.registerAccount(email.trim(),password,
                    registrationUsername.trim().lowercase(),signInPhone.trim())
                password=""
                registration=false
                notice="Registration requested. Confirm your email, then sign in. No SMS needed."
            }},enabled=android.util.Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches()
                && password.length>=8 && Regex("^[a-z0-9_.]{3,24}$").matches(registrationUsername)
                && (signInPhone.isBlank()||Regex("^\+[1-9][0-9]{7,14}$").matches(signInPhone.trim()))){
                Text("Create account — send verification email")
            }
        }else{
            Button(onClick={perform{
                api.login(email.trim(),password,register=false)
                password=""
                val p=api.profile()
                handle=p?.optString("username").orEmpty()
                if(p==null){handle=api.requestedUsername();tab="Profile"}
                displayName=p?.optString("display_name").orEmpty()
                signed=true
                if(p!=null && authOnly)onAccountReady(p.optString("username"))
                if(p!=null && pendingSignupAvatar!=null){
                    profileAvatar=api.uploadAvatar(ctx,pendingSignupAvatar!!)
                    api.profilePreferences(profileAvatar,true)
                    pendingSignupAvatar=null
                }
                if(syncOnThisDevice&&p!=null){rooms=api.rooms()}
            }},enabled=android.util.Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches()
                && password.isNotEmpty()){
                Text("Sign in")
            }
            Text("Forgot your password? Use the password reset link on the ItamarOS website.")
        }
        if(notice.isNotEmpty())Text(notice,color=MaterialTheme.colorScheme.primary)
        return
    }

    if(!syncOnThisDevice){
        Text("Cloud sync is disabled on this tablet/device.")
        Text("Cloud messages remain on the server while sync is disabled.")
        Button(onClick={
            ctx.getSharedPreferences("itamaros_native",Context.MODE_PRIVATE)
                .edit().putBoolean("connectSync",true).apply()
            syncOnThisDevice=true
        }){Text("Enable sync for this device")}
        Button(onClick={perform{
            runCatching { api.request("/rest/v1/rpc/itamar_push_unregister","POST",
                JSONObject().put("p_device_id",ItamarAndroidPush.deviceId(ctx))) }
            api.token=null;api.userID=null;signed=false;onSignOut()
        }}){Text("Sign out")}
        return
    }
    if(authOnly){
        Text("Choose your ItamarOS username to continue",style=MaterialTheme.typography.titleLarge)
        Text("All app features need a unique username. Use 3–24 lowercase letters, numbers, _ or .")
        OutlinedTextField(handle,{handle=it.lowercase().removePrefix("@").take(24)},
            label={Text("Unique @username")},singleLine=true)
        OutlinedTextField(displayName,{displayName=it.take(70)},
            label={Text("Display name (optional)")},singleLine=true)
        Button(onClick={perform {
            val clean=handle.lowercase().trim()
            require(Regex("^[a-z0-9_.]{3,24}$").matches(clean)){"Enter a valid username"}
            api.createProfile(displayName.ifBlank{clean},clean)
            if(pendingSignupAvatar!=null){
                val path=api.uploadAvatar(ctx,pendingSignupAvatar!!)
                api.profilePreferences(path,true)
                pendingSignupAvatar=null
            }
            onAccountReady(clean)
        }},enabled=Regex("^[a-z0-9_.]{3,24}$").matches(handle)){
            Text("Save username and enter ItamarOS")
        }
        if(notice.isNotBlank())Text(notice,color=MaterialTheme.colorScheme.error)
        return
    }
    LaunchedEffect(api.token) {
        if(api.token!=null && api.userID!=null) {
            try {
                val p=api.profile()
                if(p!=null){
                    handle=p.optString("username")
                    displayName=p.optString("display_name")
                    profileAvatar=p.optString("avatar_path")
                    if(syncOnThisDevice)rooms=api.rooms()
                }
            } catch(_:Exception) { /* User can retry through Profile. */ }
        }
    }
    if(pendingDesktopRequest.isNotBlank()){
        Card {
            Column(modifier=Modifier.padding(14.dp)) {
                Text(if(pendingCloudClimb) "Approve Cloud Climb Login" else "Approve Computer Login",
                    style=MaterialTheme.typography.titleMedium)
                Text("Compare this code with the one in "+
                    (if(pendingCloudClimb) "Cloud Climb: " else "your computer: ")+
                    pendingDesktopRequest.take(6).uppercase())
                Text(if(pendingCloudClimb)
                    "Only approve if you opened Cloud Climb yourself. It can access your ItamarOS account with a temporary session."
                    else "Only approve your own computer. It receives temporary message access, not your password or SMS code.")
                Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){
                    Button(onClick={
                        val manager=ctx.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        if (!manager.isDeviceSecure) {
                            desktopApprovalStatus="Set up a device PIN, password or pattern before approving."
                        } else {
                            val credentialIntent=manager.createConfirmDeviceCredentialIntent(
                                "Approve ItamarOS login",
                                if(pendingCloudClimb) "Verify it is you to connect Cloud Climb"
                                else "Confirm it is you before approving this device"
                            )
                            if (credentialIntent!=null) {
                                credentialRequest=pendingDesktopRequest
                                approvalCredentialPrompt.launch(credentialIntent)
                            } else {
                                desktopApprovalStatus="Secure device confirmation is unavailable."
                            }
                        }
                    }){Text("Verify device and approve")}
                    TextButton(onClick={pendingDesktopRequest=""}){Text("Cancel")}
                }
            }
        }
    }
    if(desktopApprovalStatus.isNotBlank()) {
        Text(desktopApprovalStatus)
        if(pendingCloudClimb && desktopApprovalStatus.startsWith("Cloud Climb account approved")) {
            OutlinedButton(onClick={
                try {
                    ctx.startActivity(Intent(Intent.ACTION_VIEW,
                        Uri.parse("cloudclimb://login-return"))
                        .setPackage("org.itamaros.cloudclimb"))
                }catch(_:Exception){
                    desktopApprovalStatus="Open Cloud Climb manually to finish linking."
                }
            }){Text("Return to Cloud Climb")}
        }
    }
    Text("ItamarOS Connect",style=MaterialTheme.typography.headlineMedium)
    if(api.token!=null){
        Button(onClick={
            if(android.os.Build.VERSION.SDK_INT>=33 &&
               androidx.core.content.ContextCompat.checkSelfPermission(ctx,
                   android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED){
                pushPermission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            }else ItamarAndroidPush.register(ctx,api){pushNotice=it}
        }){Text("Enable chat Push notifications")}
        TextButton(onClick={ItamarAndroidPush.unregister(ctx,api){pushNotice=it}}){
            Text("Disable chat Push on this device")
        }
        if(pushNotice.isNotEmpty())Text(pushNotice,style=MaterialTheme.typography.bodySmall)
    }
    Row(modifier=Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(5.dp)){
        listOf("Chats","Groups","Channels","Contacts","Updates","Profile").forEach{value->
            FilterChip(selected=tab==value,onClick={tab=value;selectedRoom=""},label={Text(value)})
        }
    }
    if(notice.isNotEmpty())Text(notice,color=MaterialTheme.colorScheme.error)
    when(tab){
        "Profile"->{
            Text("Public profile")
            OutlinedTextField(displayName,{displayName=it},label={Text("Name")})
            OutlinedTextField(handle,{handle=it},label={Text("Unique @username")})
            Button(onClick={perform{
                api.createProfile(displayName,handle)
                if(pendingSignupAvatar!=null){
                    profileAvatar=api.uploadAvatar(ctx,pendingSignupAvatar!!)
                    api.profilePreferences(profileAvatar,readReceiptPreference)
                    pendingSignupAvatar=null
                }
            }}){Text("Save profile")}
            PublicAvatar(profileAvatar)
            Button(onClick={avatarTarget="profile";chooseAvatar.launch("image/*")}){
                Text("Choose profile photo")
            }
            Row {
                Checkbox(readReceiptPreference,onCheckedChange={choice->
                    readReceiptPreference=choice
                    perform{api.profilePreferences(profileAvatar,choice)}
                })
                Text("Enable blue read receipts")
            }
            Text("Disabling read receipts also hides other people's read receipts from you.")
            if(handle.isNotEmpty()){
                PublicContactQR(handle)
                Button(onClick={
                    ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply{
                        type="text/plain"
                        putExtra(Intent.EXTRA_TEXT,"https://itamaros-web-emulator.onrender.com/contact.html?username="+handle)
                    },"Share QR link"))
                }){Text("Share contact QR")}
            }
            Text("Optional verified phone. Only searchable if you opt in.")
            OutlinedTextField(ownPhone,{ownPhone=it},
                label={Text("My phone (+international)")},
                keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Phone))
            TextButton(onClick={offerPhoneHint(forProfile=true,manual=true)}) {
                Text("Suggest number from this device")
            }
            Button(onClick={perform{api.setPhone(ownPhone)}},enabled=ownPhone.startsWith("+")){Text("Send verification SMS")}
            OutlinedTextField(ownCode,{ownCode=it},label={Text("SMS verification code")})
            Button(onClick={perform{api.verifyPhone(ownPhone,ownCode)}},
                enabled=ownCode.isNotBlank()){Text("Verify my phone")}
            Row{
                Checkbox(searchable,onCheckedChange={searchable=it})
                Text("Allow finding me by verified phone")
            }
            Button(onClick={perform{api.phoneDiscovery(searchable)}}){Text("Save phone privacy")}
            OutlinedTextField(inviteToJoin,{inviteToJoin=it},label={Text("Group invitation code (optional)")})
            Button(onClick={perform{
                api.acceptInvite(inviteToJoin)
                inviteToJoin=""
                rooms=api.rooms()
            }},enabled=inviteToJoin.length==48){Text("Accept and join invited group")}
            Button(onClick={perform{
            runCatching { api.request("/rest/v1/rpc/itamar_push_unregister","POST",
                JSONObject().put("p_device_id",ItamarAndroidPush.deviceId(ctx))) }
            api.token=null;api.userID=null;signed=false;onSignOut()
        }}){Text("Sign out")}
        }
        "Contacts"->{
            Button(onClick={perform{contacts=api.contacts()}}){Text("Refresh synced contacts")}
            for(i in 0 until contacts.length()){
                val contact=contacts.optJSONObject(i)?:continue
                Text(contact.optString("display_name")+" · @"+contact.optString("username"))
            }
            OutlinedTextField(other,{other=it},label={Text("@username or verified +phone")})
            Button(onClick={perform{
                if(other.startsWith("+")){
                    val results=api.findPhone(other)
                    lookupResult=if(results.length()>0)results.getJSONObject(0).optString("username") else ""
                    if(lookupResult.isEmpty())throw IllegalStateException("No opted-in account found. Invite this person.")
                }else{api.addContact(other);contacts=api.contacts()}
            }}){Text(if(other.startsWith("+"))"Check phone" else "Save contact")}
            if(lookupResult.isNotEmpty())
                Button(onClick={perform{api.addContact(lookupResult);contacts=api.contacts()}}){
                    Text("Add @"+lookupResult)
                }
            Button(onClick={
                ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply{
                    type="text/plain"
                    putExtra(Intent.EXTRA_TEXT,"Try ItamarOS Connect: https://itamaros-web-emulator.onrender.com/downloads.html")
                },"Invite by SMS, WhatsApp or another app"))
            }){Text("Invite friend")}
        }
        else->{
            Button(onClick={perform{rooms=api.rooms()}}){Text("Refresh rooms")}
            if(selectedRoom.isEmpty()){
                val filter=when(tab){"Groups"->"group";"Channels"->"channel";"Chats"->"chat";else->""}
                for(i in 0 until rooms.length()){
                    val room=rooms.optJSONObject(i)?:continue
                    if(filter.isNotEmpty()&&room.optString("kind")!=filter)continue
                    val id=room.optString("id")
                    Row {
                        TextButton(onClick={perform{
                            selectedRoom=id
                            title=room.optString("title")
                            groupDescription=room.optString("description")
                            roomAvatar=room.optString("avatar_path").takeIf{it.isNotEmpty() && it!="null"}
                            messages=api.messages(id)
                            reactions=api.reactions(messages)
                            api.acknowledge(id,true)
                            if(room.optString("kind")=="group")polls=api.polls(id)
                        }}){Text(room.optString("title"))}
                        Button(onClick={perform{api.mute(id,!room.optBoolean("muted"));rooms=api.rooms()}}){
                            Text(if(room.optBoolean("muted"))"Unmute" else "Mute")
                        }
                    }
                }
                if(tab!="Updates"){
                    Text("Create conversation")
                    Row(modifier=Modifier.horizontalScroll(rememberScrollState())){
                        listOf("chat","group","channel").forEach{t->
                            FilterChip(selected=kind==t,onClick={kind=t},label={Text(t)})
                        }
                    }
                    OutlinedTextField(title,{title=it},label={Text("Title")})
                    if(kind!="channel")
                        OutlinedTextField(other,{other=it},label={Text(if(kind=="group")"Usernames, comma separated" else "@username")})
                    Button(onClick={perform{api.create(kind,title,other);rooms=api.rooms()}}){Text("Create")}
                }else Text("Updates from unmuted chats and channels. Push notifications require APNs/FCM.")
            }else{
                Button(onClick={
                    if(recordingVoice){voiceRecorder.discard();recordingVoice=false}
                    selectedRoom=""
                }){Text("← Back")}
                for(i in 0 until messages.length()){
                    val entry=messages.optJSONObject(i)?:continue
                    val id=entry.optString("id")
                    val own=entry.optString("sender_id")==api.userID
                    val deleted=entry.optString("deleted_at")!="null"&&!entry.isNull("deleted_at")
                    Text((if(own)"You: " else "Member: ")+
                        (if(deleted)"Message deleted" else entry.optString("body"))+
                        (if(!entry.isNull("edited_at"))" (edited)" else ""))
                    if(!deleted && !entry.optBoolean("is_view_once",false)){
                        val sharedURL=Regex("https?://[^\\s]+").find(entry.optString("body"))?.value
                        if(sharedURL!=null){
                            Button(onClick={
                                ctx.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(sharedURL)))
                            }){Text("Open shared link")}
                        }
                    }
                    if(!entry.isNull("reply_to")){
                        val parentID=entry.optString("reply_to")
                        val parent=(0 until messages.length()).mapNotNull{messages.optJSONObject(it)}
                            .firstOrNull{it.optString("id")==parentID}
                        if(parent!=null)Text("↪ "+parent.optString("body").take(80))
                    }
                    if(!entry.isNull("expires_at"))Text("⏳ Disappearing text")
                    val reactionsHere=reactions[id].orEmpty()
                    if(reactionsHere.isNotEmpty()){
                        Text(reactionsHere.groupingBy{it}.eachCount()
                            .entries.joinToString(" · "){it.key+" "+it.value})
                    }
                    if(!deleted){
                        Row {
                            Button(onClick={reactionTarget=if(reactionTarget==id)"" else id}){Text("React")}
                            if(!entry.optBoolean("is_view_once"))
                                Button(onClick={replyTarget=id}){Text("Reply")}
                            if(!own){
                                Button(onClick={reportTarget=id}){Text("Report")}
                            }
                        }
                        if(reactionTarget==id){
                            Row(modifier=Modifier.horizontalScroll(rememberScrollState())){
                                listOf("👍","❤️","😂","😮","😢","🙏","🎉").forEach{emoji->
                                    TextButton(onClick={perform{
                                        api.react(id,emoji)
                                        reactions=api.reactions(messages)
                                        reactionTarget=""
                                    }}){Text(emoji)}
                                }
                            }
                        }
                        if(reportTarget==id){
                            Text("Save a report (human review not yet available)")
                            Row(modifier=Modifier.horizontalScroll(rememberScrollState())){
                                listOf("Spam","Harassment","Threats","Other").forEach{reason->
                                    TextButton(onClick={perform{
                                        api.report(id,reason)
                                        reportTarget=""
                                    }}){Text(reason)}
                                }
                            }
                            if(!own) Button(onClick={perform{
                                api.block(entry.optString("sender_id"))
                                reportTarget=""
                            }}){Text("Block sender")}
                        }
                    }
                    if(own && !deleted){
                        Button(onClick={perform{
                            val res=api.receipt(id)
                            receipts=receipts+(id to res)
                        }}){
                            val current=receipts[id]
                            Text(if((current?.second ?: 0)>0)"✓✓ Read"
                                 else if((current?.first ?: 0)>0)"✓✓ Delivered" else "✓ Sent")
                        }
                        Row {
                            Button(onClick={editingID=id;message=entry.optString("body")}){Text("Edit")}
                            Button(onClick={perform{
                                api.delete(id)
                                messages=api.messages(selectedRoom)
                            }}){Text("Delete")}
                        }
                    }
                    if(entry.optBoolean("is_view_once",false)&&!own&&!deleted){
                        Button(onClick={perform{
                            openedSecret=api.openOnce(id)
                        }}){Text("Open once")}
                    }
                }
                if(openedSecret.isNotBlank()){
                    AlertDialog(onDismissRequest={openedSecret=""},
                        title={Text("View-once text")},
                        text={Text(openedSecret+"\n\nScreenshots cannot be prevented.")},
                        confirmButton={TextButton(onClick={openedSecret=""}){Text("Close")}})
                }
                if(replyTarget.isNotEmpty()){
                    Row {
                        Text("Reply to message")
                        TextButton(onClick={replyTarget=""}){Text("Cancel")}
                    }
                }
                if(editingID.isBlank()) {
                    Row {
                        Checkbox(viewOnce,onCheckedChange={viewOnce=it})
                        Text("View once (text only)")
                    }
                    Row(modifier=Modifier.horizontalScroll(rememberScrollState())){
                        listOf(0,3600,86400,604800).forEach{seconds->
                            val title=when(seconds){3600->"1 hour";86400->"1 day";604800->"7 days";else->"Keep"}
                            FilterChip(selected=expiringSeconds==seconds,
                                onClick={expiringSeconds=seconds},label={Text(title)})
                        }
                    }
                }else Text("Editing message")
                OutlinedTextField(message,{message=it},label={Text("Message or link")})
                Button(onClick={perform{
                    when {
                        editingID.isNotBlank()->{api.edit(editingID,message);editingID=""}
                        replyTarget.isNotBlank()->{api.reply(selectedRoom,replyTarget,message);replyTarget=""}
                        viewOnce->{api.sendOnce(selectedRoom,message);viewOnce=false}
                        expiringSeconds>0->api.disappearingText(selectedRoom,message,expiringSeconds)
                        else->api.send(selectedRoom,message)
                    }
                    message=""
                    messages=api.messages(selectedRoom)
                    reactions=api.reactions(messages)
                }}){Text(if(editingID.isNotBlank())"Save edit" else "Send")}
                if(editingID.isNotBlank()) Button(onClick={editingID="";message=""}){Text("Cancel edit")}
                if(recordingVoice){
                    Row {
                        Text("Recording voice note")
                        Button(onClick={
                            try{
                                val recorded=voiceRecorder.stop()
                                recordingVoice=false
                                if(recorded!=null)perform{
                                    try {
                                        api.uploadAttachment(ctx,Uri.fromFile(recorded),selectedRoom)
                                        messages=api.messages(selectedRoom)
                                    } finally {recorded.delete()}
                                }
                            }catch(e:Exception){recordingVoice=false;notice=e.localizedMessage?:"Cannot send recording"}
                        }){Text("Stop and send")}
                        Button(onClick={voiceRecorder.discard();recordingVoice=false}){Text("Discard")}
                    }
                }else{
                    Button(onClick={microphonePermission.launch(android.Manifest.permission.RECORD_AUDIO)}){
                        Text("Record voice message (up to 90 seconds)")
                    }
                }
                Button(onClick={chooseAttachment.launch(arrayOf("image/*","video/*","audio/*","application/pdf","text/plain","text/vcard","text/calendar"))}){
                    Text("Attach media, file or contact card (max 20 MB)")
                }
                if(tab=="Groups"){
                    OutlinedTextField(title,{title=it},label={Text("Group name")})
                    OutlinedTextField(groupDescription,{groupDescription=it},label={Text("Description (optional)")})
                    Button(onClick={perform{api.groupDetails(selectedRoom,title,groupDescription,roomAvatar)}}){
                        Text("Save group name and description")
                    }
                    PublicAvatar(roomAvatar)
                    Button(onClick={avatarTarget="group";chooseAvatar.launch("image/*")}){
                        Text("Choose group photo")
                    }
                    OutlinedTextField(other,{other=it},
                        label={Text("Add member directly by @username")})
                    Button(onClick={perform{api.addGroupMember(selectedRoom,other)}}){
                        Text("Add member")
                    }
                    Button(onClick={perform{inviteToken=api.makeInvite(selectedRoom)}}){
                        Text("Create shareable invite (48 hours)")
                    }
                    if(inviteToken.isNotBlank()){
                        val groupLink="https://itamaros-web-emulator.onrender.com/join.html?invite="+inviteToken
                        PublicLinkQR(groupLink)
                        Button(onClick={
                            ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply{
                                type="text/plain";putExtra(Intent.EXTRA_TEXT,groupLink)
                            },"Share group invitation"))
                        }){Text("Invite via link or message")}
                    }
                    Text("Polls",style=MaterialTheme.typography.titleMedium)
                    for(i in 0 until polls.length()){
                        val poll=polls.optJSONObject(i)?:continue
                        Text(poll.optString("question"))
                        val opts=poll.optJSONArray("options")?:JSONArray()
                        for(j in 0 until opts.length()){
                            Button(onClick={perform{api.vote(poll.optString("id"),j)}}){Text(opts.optString(j))}
                        }
                    }
                    OutlinedTextField(question,{question=it},label={Text("Poll question")})
                    OutlinedTextField(pollOptions,{pollOptions=it},label={Text("Options, one per line")})
                    Button(onClick={perform{api.newPoll(selectedRoom,question,pollOptions);polls=api.polls(selectedRoom)}}){Text("Publish poll")}
                }
            }
        }
    }
}

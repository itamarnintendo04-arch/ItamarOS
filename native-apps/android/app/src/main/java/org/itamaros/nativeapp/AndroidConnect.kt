package org.itamaros.nativeapp

import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
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
private class AndroidConnectApi {
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
    suspend fun profile():JSONObject?{
        val id=userID?:return null
        val result=JSONArray(request("/rest/v1/itamar_profiles?id=eq."+id+"&select=id,username,display_name"))
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
        "&select=id,body,sender_id&order=created_at.asc&limit=100"))
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
private fun PublicContactQR(username:String){
    val url="https://itamaros-web-emulator.onrender.com/contact.html?username="+username
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
fun AndroidConnectScreen(){
    val api=remember{AndroidConnectApi()}
    val ctx=LocalContext.current
    val scope=rememberCoroutineScope()
    var signed by remember{mutableStateOf(false)}
    var registration by remember{mutableStateOf(false)}
    var email by remember{mutableStateOf("")}
    var password by remember{mutableStateOf("")}
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
    var ownPhone by remember{mutableStateOf("")}
    var ownCode by remember{mutableStateOf("")}
    var searchable by remember{mutableStateOf(false)}

    fun perform(action:suspend()->Unit){
        scope.launch{try{action();notice=""}catch(e:Exception){notice=e.localizedMessage?:"Operation failed"}}
    }
    if(!api.configured){
        Text("ItamarOS Connect needs a separately configured Supabase project before real chats can synchronize.")
        Text("No contacts are uploaded and no online accounts are created until cloud mode is configured.")
        return
    }
    if(!signed){
        Text("ItamarOS Connect",style=MaterialTheme.typography.headlineMedium)
        OutlinedTextField(email,{email=it},label={Text("Email")})
        OutlinedTextField(password,{password=it},label={Text("Password")})
        Button(onClick={
            perform{
                api.login(email,password,registration)
                signed=true
                val p=api.profile()
                handle=p?.optString("username").orEmpty()
                displayName=p?.optString("display_name").orEmpty()
                rooms=api.rooms()
            }
        },enabled=email.contains("@")&&password.length>=6){Text(if(registration)"Register" else "Sign in")}
        TextButton(onClick={registration=!registration}){Text("Switch sign-in / registration")}
        if(notice.isNotEmpty())Text(notice,color=MaterialTheme.colorScheme.error)
        return
    }

    Text("ItamarOS Connect",style=MaterialTheme.typography.headlineMedium)
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
            Button(onClick={perform{api.createProfile(displayName,handle)}}){Text("Create profile")}
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
            OutlinedTextField(ownPhone,{ownPhone=it},label={Text("My phone (+international)")})
            Button(onClick={perform{api.setPhone(ownPhone)}},enabled=ownPhone.startsWith("+")){Text("Send verification SMS")}
            OutlinedTextField(ownCode,{ownCode=it},label={Text("SMS verification code")})
            Button(onClick={perform{api.verifyPhone(ownPhone,ownCode)}},
                enabled=ownCode.isNotBlank()){Text("Verify my phone")}
            Row{
                Checkbox(searchable,onCheckedChange={searchable=it})
                Text("Allow finding me by verified phone")
            }
            Button(onClick={perform{api.phoneDiscovery(searchable)}}){Text("Save phone privacy")}
            Button(onClick={api.token=null;api.userID=null;signed=false}){Text("Sign out")}
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
                            messages=api.messages(id)
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
                Button(onClick={selectedRoom=""}){Text("← Back")}
                for(i in 0 until messages.length()){
                    val entry=messages.optJSONObject(i)?:continue
                    Text((if(entry.optString("sender_id")==api.userID)"You: " else "Member: ")+entry.optString("body"))
                }
                OutlinedTextField(message,{message=it},label={Text("Message or link")})
                Button(onClick={perform{api.send(selectedRoom,message);message="";messages=api.messages(selectedRoom)}}){Text("Send")}
                if(tab=="Groups"){
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

package org.itamaros.nativeapp

import android.content.Intent
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
    suspend fun uploadAttachment(context:Context,uri:Uri,room:String){
        if(!configured)throw IllegalStateException("Connect is not configured")
        val mime=context.contentResolver.getType(uri)?:throw IllegalStateException("Unknown file type")
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
fun AndroidConnectScreen(groupInvite:String?=null,contactUsername:String?=null){
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
    var inviteToken by remember{mutableStateOf("")}
    var inviteToJoin by remember{mutableStateOf("")}
    var groupDescription by remember{mutableStateOf("")}
    var editingID by remember{mutableStateOf("")}
    var viewOnce by remember{mutableStateOf(false)}
    var openedSecret by remember{mutableStateOf("")}
    var receipts by remember{mutableStateOf(mapOf<String,Pair<Int,Int>>())}
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
    LaunchedEffect(contactUsername) {
        if(contactUsername?.matches(Regex("[a-z0-9_.]{3,24}"))==true) {
            other=contactUsername
            tab="Contacts"
        }
    }
    var ownPhone by remember{mutableStateOf("")}
    var ownCode by remember{mutableStateOf("")}
    var searchable by remember{mutableStateOf(false)}

    fun perform(action:suspend()->Unit){
        scope.launch{try{action();notice=""}catch(e:Exception){notice=e.localizedMessage?:"Operation failed"}}
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
        OutlinedTextField(email,{email=it},label={Text("Email")})
        OutlinedTextField(password,{password=it},label={Text("Password")})
        Button(onClick={
            perform{
                api.login(email,password,registration)
                signed=true
                val p=api.profile()
                handle=p?.optString("username").orEmpty()
                displayName=p?.optString("display_name").orEmpty()
                profileAvatar=p?.optString("avatar_path")?.takeIf{it.isNotEmpty()&&it!="null"}
                readReceiptPreference=p?.optBoolean("read_receipts_enabled",true)?:true
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
            if(!profileAvatar.isNullOrBlank()) Text("Profile photo saved")
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
            OutlinedTextField(inviteToJoin,{inviteToJoin=it},label={Text("Group invitation code (optional)")})
            Button(onClick={perform{
                api.acceptInvite(inviteToJoin)
                inviteToJoin=""
                rooms=api.rooms()
            }},enabled=inviteToJoin.length==48){Text("Accept and join invited group")}
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
                            title=room.optString("title")
                            groupDescription=room.optString("description")
                            roomAvatar=room.optString("avatar_path").takeIf{it.isNotEmpty() && it!="null"}
                            messages=api.messages(id)
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
                Button(onClick={selectedRoom=""}){Text("← Back")}
                for(i in 0 until messages.length()){
                    val entry=messages.optJSONObject(i)?:continue
                    val id=entry.optString("id")
                    val own=entry.optString("sender_id")==api.userID
                    val deleted=entry.optString("deleted_at")!="null"&&!entry.isNull("deleted_at")
                    Text((if(own)"You: " else "Member: ")+
                        (if(deleted)"Message deleted" else entry.optString("body"))+
                        (if(!entry.isNull("edited_at"))" (edited)" else ""))
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
                if(editingID.isBlank()) {
                    Row {
                        Checkbox(viewOnce,onCheckedChange={viewOnce=it})
                        Text("View once (text only)")
                    }
                }else Text("Editing message")
                OutlinedTextField(message,{message=it},label={Text("Message or link")})
                Button(onClick={perform{
                    when {
                        editingID.isNotBlank()->{api.edit(editingID,message);editingID=""}
                        viewOnce->{api.sendOnce(selectedRoom,message);viewOnce=false}
                        else->api.send(selectedRoom,message)
                    }
                    message=""
                    messages=api.messages(selectedRoom)
                }}){Text(if(editingID.isNotBlank())"Save edit" else "Send")}
                if(editingID.isNotBlank()) Button(onClick={editingID="";message=""}){Text("Cancel edit")}
                Button(onClick={chooseAttachment.launch(arrayOf("image/*","video/*","audio/*","application/pdf","text/plain","text/vcard","text/calendar"))}){
                    Text("Attach media, file or contact card (max 20 MB)")
                }
                if(tab=="Groups"){
                    OutlinedTextField(title,{title=it},label={Text("Group name")})
                    OutlinedTextField(groupDescription,{groupDescription=it},label={Text("Description (optional)")})
                    Button(onClick={perform{api.groupDetails(selectedRoom,title,groupDescription,roomAvatar)}}){
                        Text("Save group name and description")
                    }
                    if(!roomAvatar.isNullOrBlank())Text("Group photo saved")
                    Button(onClick={avatarTarget="group";chooseAvatar.launch("image/*")}){
                        Text("Choose group photo")
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

package org.itamaros.nativeapp

import android.content.Intent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject

/** Same verified Supabase RPC games as iOS, no copied commercial assets. */
@Composable
fun ItamarPartyGamesAndroid(api: AndroidConnectApi,defaultGame:String="connect_four"){
    val scope=rememberCoroutineScope()
    val context=LocalContext.current
    var selected by remember { mutableStateOf(defaultGame) }
    var match by remember { mutableStateOf<JSONObject?>(null) }
    var roomInput by remember { mutableStateOf("") }
    var invite by remember { mutableStateOf("") }
    var problem by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val code=match?.optString("code").orEmpty()
    val myId=api.userID
    val slot=when(myId){
        match?.optString("host_id")->1
        match?.optString("player2")->2
        match?.optString("player3")->3
        match?.optString("player4")->4
        else->0
    }
    val myMark=if(slot==1)"X" else "O"
    val active=match?.optString("status").orEmpty()
    fun submit(block:suspend()->Unit){
        if(busy)return
        busy=true
        scope.launch{
            try{block();problem=""}
            catch(e:Exception){problem=e.localizedMessage?:"Server request failed"}
            finally{busy=false}
        }
    }
    LaunchedEffect(code){
        while(code.isNotBlank()){
            delay(700)
            try{
                val changed=JSONObject(api.request("/rest/v1/rpc/itamar_party_state","POST",
                    JSONObject().put("p_code",code)))
                if(match?.optString("code")==code)match=changed
            }catch(_:Exception){}
        }
    }
    Column(verticalArrangement=Arrangement.spacedBy(12.dp)){
        Text("ItamarOS Online",style=MaterialTheme.typography.headlineMedium)
        if(match==null){
            Text("Every player needs a unique @username. Rooms use 10-character codes.")
            listOf("connect_four" to "Connect Four (2)",
                "rock_paper_scissors" to "Rock Paper Scissors (2)",
                "cloud_climb" to "Cloud Climb (up to 4)").forEach{(kind,title)->
                FilterChip(selected=selected==kind,onClick={selected=kind},label={Text(title)})
            }
            Button(onClick={submit{
                match=JSONObject(api.request("/rest/v1/rpc/itamar_party_create","POST",
                    JSONObject().put("p_game",selected)))
            }},enabled=!busy){Text("Create room")}
            OutlinedTextField(roomInput,{roomInput=it.uppercase()
                .filter{c->c in '0'..'9'||c in 'A'..'F'}.take(10)},
                label={Text("Enter code")},singleLine=true)
            Button(onClick={submit{
                match=JSONObject(api.request("/rest/v1/rpc/itamar_party_join","POST",
                    JSONObject().put("p_code",roomInput)))
            }},enabled=roomInput.length==10&&!busy){Text("Join room")}
        }else{
            Text("Room code: "+code,style=MaterialTheme.typography.titleLarge)
            val maxPlayers=if(match?.optString("game")=="cloud_climb")4 else 2
            val count=listOf("host_id","player2","player3","player4")
                .count{match?.optString(it).orEmpty().let{v->v.isNotEmpty()&&v!="null"}}
            Text("Players: "+count+" / "+maxPlayers)
            if(match?.optString("game")=="cloud_climb"){
                Text("Code-only. Invitations and share buttons are disabled.")
                CloudClimbAndroid(api, match, slot, onExit = {
                    match = null; roomInput = ""; problem = ""
                })
            }else {
                if(active=="waiting"){
                    Text("Waiting for the other player")
                    Button(onClick={
                        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply{
                            type="text/plain"
                            putExtra(Intent.EXTRA_TEXT,"Join my ItamarOS game with room code "+code)
                        },"Invite"))
                    }){Text("Share code")}
                    OutlinedTextField(invite,{invite=it.take(25)},label={Text("Invite @username in chat")})
                    Button(onClick={submit{
                        api.request("/rest/v1/rpc/itamar_party_invite","POST",
                            JSONObject().put("p_code",code).put("p_username",invite))
                        invite=""
                    }},enabled=invite.isNotBlank()&&!busy){Text("Send chat invitation")}
                }else if(match?.optString("game")=="connect_four"){
                    val winner=match?.optString("winner").orEmpty()
                    Text(if(active=="finished")winText(winner,myMark)
                         else if(match?.optInt("turn_slot")==slot)"Your turn" else "Other player's turn")
                    val board=match?.optString("board").orEmpty().padEnd(42,'_')
                    for(row in 0..5){
                        Row(horizontalArrangement=Arrangement.spacedBy(2.dp),
                            modifier=Modifier.fillMaxWidth()){
                            for(column in 0..6){
                                val cell=board[row*7+column]
                                Button(onClick={submit{
                                    match=JSONObject(api.request("/rest/v1/rpc/itamar_party_move","POST",
                                        JSONObject().put("p_code",code).put("p_column",column)))
                                }},enabled=active=="playing"&&!busy&&match?.optInt("turn_slot")==slot
                                        &&board[column]=='_',
                                    modifier=Modifier.weight(1f).heightIn(min=42.dp),
                                    contentPadding=PaddingValues(0.dp)){
                                    Text(if(cell=='_')"·" else cell.toString())
                                }
                            }
                        }
                    }
                }else{
                    val winner=match?.optString("winner").orEmpty()
                    Text(if(active=="finished")winText(winner,myMark)
                         else if(match?.optString("your_choice").isNullOrBlank())"Choose secretly"
                         else "Waiting for the other player")
                    if(active=="finished"){
                        val choices=match?.optJSONArray("revealed_choices")
                        if(choices!=null&&choices.length()==2)
                            Text("Player 1: "+choices.optString(0)+" · Player 2: "+choices.optString(1))
                    }else{
                        Row(horizontalArrangement=Arrangement.spacedBy(4.dp)){
                            listOf("rock","paper","scissors").forEach{choice->
                                Button(onClick={submit{
                                    match=JSONObject(api.request("/rest/v1/rpc/itamar_party_move","POST",
                                        JSONObject().put("p_code",code).put("p_choice",choice)))
                                }},enabled=active=="playing"&&!busy&&
                                    match?.optString("your_choice").isNullOrBlank()){
                                    Text(choice)
                                }
                            }
                        }
                    }
                }
            }
            OutlinedButton(onClick={match=null;roomInput="";problem=""}){Text("Leave room view")}
        }
        if(busy)LinearProgressIndicator(modifier=Modifier.fillMaxWidth())
        if(problem.isNotEmpty())Text(problem,color=MaterialTheme.colorScheme.error)
    }
}
private fun winText(winner:String,myMark:String)=when(winner){
    "draw"->"Draw!"
    myMark->"You won!"
    else->"Other player won!"
}

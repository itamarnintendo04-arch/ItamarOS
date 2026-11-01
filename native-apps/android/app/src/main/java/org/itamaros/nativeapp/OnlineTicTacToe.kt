package org.itamaros.nativeapp

import android.content.Intent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject

// Identical Supabase RPC/turn authority as the iOS client. No peer-to-peer trust.
@Composable
fun OnlineTicTacToeAndroid(api: AndroidConnectApi) {
    val ctx=LocalContext.current
    val scope=rememberCoroutineScope()
    var match by remember{mutableStateOf<JSONObject?>(null)}
    var typedCode by remember{mutableStateOf("")}
    var inviteName by remember{mutableStateOf("")}
    var error by remember{mutableStateOf("")}
    var busy by remember{mutableStateOf(false)}
    val code=match?.optString("code").orEmpty()
    val myPiece=if(match?.optString("host_id")==api.userID) "X" else "O"
    val isTurn=match?.optString("status")=="playing" && match?.optString("turn")==myPiece

    fun runAction(action:suspend()->Unit){
        if(busy)return
        busy=true
        scope.launch {
            try { action();error="" }
            catch(e:Exception){error=e.localizedMessage?:"Network request failed"}
            finally{busy=false}
        }
    }
    LaunchedEffect(code) {
        if(code.isNotEmpty()){
            while(true) {
                delay(2200)
                try {
                    val updated=JSONObject(api.request("/rest/v1/rpc/itamar_game_get","POST",
                        JSONObject().put("p_code",code)))
                    if(match?.optString("code")==code)match=updated
                }catch(_:Exception){ /* Keep the last known board during transient outages. */ }
            }
        }
    }
    Column(verticalArrangement=Arrangement.spacedBy(12.dp),modifier=Modifier.fillMaxWidth()){
        Text("Tic-Tac-Toe · Online",style=MaterialTheme.typography.titleLarge)
        Text("Two phones, Android and iPhone supported. A verified username is required.")
        if(match==null){
            Button(onClick={runAction {
                match=JSONObject(api.request("/rest/v1/rpc/itamar_game_create","POST",JSONObject()))
            }},enabled=!busy){Text("Create online game")}
            OutlinedTextField(typedCode,{typedCode=it.uppercase().filter{c->c in '0'..'9'||c in 'A'..'F'}.take(10)},
                label={Text("Enter 10-character code")},singleLine=true)
            Button(onClick={runAction{
                match=JSONObject(api.request("/rest/v1/rpc/itamar_game_join","POST",
                    JSONObject().put("p_code",typedCode)))
            }},enabled=typedCode.length==10&&!busy){Text("Join by code")}
        }else{
            Text("Room code: $code",style=MaterialTheme.typography.titleMedium)
            Button(onClick={
                val invite="Join my ItamarOS Tic-Tac-Toe game! Open Games → Online match and enter code $code"
                ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply{
                    type="text/plain"; putExtra(Intent.EXTRA_TEXT,invite)
                },"Send game invitation"))
            }){Text("Share game code")}
            if(match?.optString("status")=="waiting"){
                Text("Waiting for player two…")
                OutlinedTextField(inviteName,{inviteName=it.take(25)},
                    label={Text("Invite by @username in chat")},singleLine=true)
                Button(onClick={runAction{
                    api.request("/rest/v1/rpc/itamar_game_invite","POST",
                        JSONObject().put("p_code",code).put("p_username",inviteName.trim()))
                    inviteName=""
                }},enabled=inviteName.isNotBlank()&&!busy){Text("Send chat invitation")}
            }else{
                val winner=match?.optString("winner").orEmpty()
                val status=match?.optString("status").orEmpty()
                Text(if(status=="finished"){
                    if(winner=="draw")"Draw!" else if(winner==myPiece)"You won!" else "Other player won!"
                } else if(isTurn) "Your turn ($myPiece)" else "Other player's turn")
                val board=match?.optString("board").orEmpty().padEnd(9,'_')
                for(row in 0..2){
                    Row(horizontalArrangement=Arrangement.spacedBy(8.dp),modifier=Modifier.fillMaxWidth()){
                        for(col in 0..2){
                            val position=row*3+col
                            val piece=board[position]
                            OutlinedButton(
                                onClick={runAction{
                                    match=JSONObject(api.request("/rest/v1/rpc/itamar_game_move","POST",
                                        JSONObject().put("p_code",code).put("p_position",position)))
                                }},
                                enabled=isTurn&&piece=='_'&&!busy,
                                modifier=Modifier.weight(1f).heightIn(min=70.dp)
                            ){ Text(if(piece=='_')"·" else piece.toString(),
                                style=MaterialTheme.typography.headlineLarge) }
                        }
                    }
                }
            }
            OutlinedButton(onClick={match=null;typedCode="";error=""}){Text("Back to online lobby")}
        }
        if(busy)LinearProgressIndicator(modifier=Modifier.fillMaxWidth())
        if(error.isNotBlank())Text(error,color=MaterialTheme.colorScheme.error)
        Text("Matches expire after 24 hours. Codes are private: only share with people you trust.",
            style=MaterialTheme.typography.bodySmall)
    }
}

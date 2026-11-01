package org.itamaros.nativeapp

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import org.json.JSONObject

/** Original hand-drawn platformer test stage; coordinates synced with Supabase.
 * This is still a prototype, not a low-latency authoritative game server.
 */
@Composable
fun CloudClimbAndroid(api:AndroidConnectApi,match:JSONObject?,slot:Int){
    val room=match?.optString("code").orEmpty()
    val seed=match?.optInt("seed")?:0
    val platforms=remember(seed){cloudStages(seed)}
    var px by remember{mutableFloatStateOf(48f)}
    var py by remember{mutableFloatStateOf(430f)}
    var vy by remember{mutableFloatStateOf(0f)}
    var landed by remember{mutableStateOf(true)}
    var left by remember{mutableStateOf(false)}
    var right by remember{mutableStateOf(false)}
    var jump by remember{mutableStateOf(false)}

    DisposableEffect(room){
        ItamarGamepad.enabled=true
        onDispose{ItamarGamepad.reset()}
    }
    LaunchedEffect(room,slot){
        if(room.isBlank()||slot==0)return@LaunchedEffect
        var lastSent=0L
        while(true){
            delay(33)
            val dir=((if(left)-1f else 0f)+(if(right)1f else 0f)+
                ItamarGamepad.axis+(if(ItamarGamepad.left)-1f else 0f)+
                (if(ItamarGamepad.right)1f else 0f)).coerceIn(-1f,1f)
            px=(px+dir*3.2f).coerceIn(12f,388f)
            if((jump||ItamarGamepad.jump)&&landed){vy=-9f;landed=false}
            jump=false
            val previousBottom=py+3f
            vy=(vy+0.38f).coerceAtMost(10f)
            py+=vy
            if(vy>=0f){
                for(stage in platforms){
                    if(px+11f>stage.first && px-11f<stage.first+stage.third &&
                        previousBottom<=stage.second && py+3f>=stage.second){
                        py=stage.second-3f
                        vy=0f
                        landed=true
                        break
                    }
                }
            }
            if(py>495f){px=48f;py=430f;vy=0f;landed=true}
            val time=android.os.SystemClock.elapsedRealtime()
            if(time-lastSent>650L){
                lastSent=time
                try{
                    api.request("/rest/v1/rpc/itamar_party_position","POST",
                        JSONObject().put("p_code",room)
                            .put("p_x",px.toDouble()*1024/400)
                            .put("p_y",py.toDouble()*2048/500))
                }catch(_:Exception){}
            }
        }
    }
    Column(verticalArrangement=Arrangement.spacedBy(10.dp)){
        Text(if(match?.optString("status")=="waiting")"Waiting for another player"
             else "Climb the sky platforms together",style=MaterialTheme.typography.titleMedium)
        Text("Online co-op prototype. Share your code only by reading it to friends.")
        Canvas(modifier=Modifier.fillMaxWidth().aspectRatio(4f/5f)){
            val sx=size.width/400f;val sy=size.height/500f
            drawRect(Color(0xFF25377D))
            platforms.forEachIndexed{index,p->
                drawRoundRect(
                    color=if(index==0) Color(0xFF4BE4BE) else Color(0xFFC0E9FF),
                    topLeft=Offset(p.first*sx,p.second*sy),
                    size=Size(p.third*sx,12f*sy),cornerRadius=CornerRadius(5f))
            }
            val colors=listOf(Color(0xFFFFA43A),Color(0xFFFF79A5),
                Color(0xFF61F4E0),Color(0xFFFFE172))
            val positions=match?.optJSONObject("positions")
            for(id in 1..4){
                val remote=positions?.optJSONObject(id.toString())
                val x=if(id==slot)px else remote?.optDouble("x")?.toFloat()?.times(400f/1024f)
                val y=if(id==slot)py else remote?.optDouble("y")?.toFloat()?.times(500f/2048f)
                if(x!=null && y!=null){
                    drawRoundRect(color=colors[id-1],
                        topLeft=Offset((x-12)*sx,(y-22)*sy),
                        size=Size(24f*sx,24f*sy),cornerRadius=CornerRadius(5f))
                }
            }
        }
        Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){
            TextButton(onClick={}){Text("◀",modifier=Modifier.pointerInput(Unit){
                detectTapGestures(onPress={left=true;tryAwaitRelease();left=false})
            }) }
            TextButton(onClick={}){Text("▶",modifier=Modifier.pointerInput(Unit){
                detectTapGestures(onPress={right=true;tryAwaitRelease();right=false})
            }) }
            Button(onClick={jump=true}){Text("Jump")}
        }
        Text(if(ItamarGamepad.detected)"Controller connected and input received"
             else "Touch or use a compatible Xbox, PlayStation, or Switch controller.")
    }
}
private fun cloudStages(seed:Int):List<Triple<Float,Float,Float>>{
    var state=seed.toLong() and 0xffffffffL
    fun next():Float{
        state=state*6364136223846793005L+1442695040888963407L
        return ((state ushr 32)%1000).toFloat()/1000f
    }
    val result=mutableListOf(Triple(0f,472f,400f))
    repeat(6){row->
        val x=16f+next()*205f
        result.add(Triple(x,405f-row*61f,130f+next()*40f))
    }
    return result
}

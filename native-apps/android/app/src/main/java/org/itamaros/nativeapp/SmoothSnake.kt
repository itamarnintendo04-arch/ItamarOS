package org.itamaros.nativeapp

import android.os.SystemClock
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.input.pointer.pointerInput
import kotlinx.coroutines.delay
import kotlin.math.ceil
import kotlin.math.hypot
import kotlin.random.Random

private const val ARENA=400f
private const val SPACE=11f
private const val SNAKE_SIZE=8f

private data class SmoothSnakeState(
    val body:List<Offset>,
    val food:Offset?,
    val heading:Offset,
    val wanted:Offset,
    val score:Int=0,
    val running:Boolean=false,
    val over:Boolean=false
)

private fun freshSmoothSnake():SmoothSnakeState=SmoothSnakeState(
    body=List(13){i->Offset(200f-i*SPACE,200f)},
    food=Offset(314f,188f),heading=Offset(1f,0f),wanted=Offset(1f,0f)
)

private fun pointDistance(a:Offset,b:Offset)=hypot(a.x-b.x,a.y-b.y)
private fun randomSmoothFood(points:List<Offset>):Offset?{
    repeat(250){
        val point=Offset(Random.nextFloat()*364f+18f,Random.nextFloat()*364f+18f)
        if(points.all{pointDistance(point,it)>25f})return point
    }
    return null
}
private fun advanceSmoothSnake(source:SmoothSnakeState,dt:Float):SmoothSnakeState {
    if(!source.running||source.over)return source
    val body=source.body.toMutableList()
    var food=source.food
    var score=source.score
    val speed=minOf(230f,76f+score*11f)
    val interpolation=(dt*10f).coerceIn(0f,1f)
    val vector=source.heading*(1f-interpolation)+source.wanted*interpolation
    val direction=vector/vector.getDistance().coerceAtLeast(0.01f)
    val distance=speed*dt
    val steps=maxOf(1,ceil(distance/5f).toInt())
    repeat(steps){
        val head=body.first()+direction*(distance/steps)
        if(head.x<SNAKE_SIZE||head.y<SNAKE_SIZE||
           head.x>ARENA-SNAKE_SIZE||head.y>ARENA-SNAKE_SIZE||
           body.drop(8).any{pointDistance(head,it)<SNAKE_SIZE*1.4f})
            return source.copy(body=body,heading=direction,score=score,
                               food=food,over=true,running=false)
        body[0]=head
        for(i in 1 until body.size){
            val prev=body[i-1]
            val point=body[i]
            val gap=pointDistance(prev,point)
            if(gap>SPACE)body[i]=point+(prev-point)*((gap-SPACE)/gap)
        }
        if(food!=null&&pointDistance(head,food)<19f){
            body.add(body.last());score++
            food=randomSmoothFood(body)
            if(food==null)return source.copy(body=body,score=score,heading=direction,
                                                food=null,running=false,over=true)
        }
    }
    return source.copy(body=body,heading=direction,food=food,score=score)
}

@Composable
fun SmoothSnakeGame() {
    var game by remember { mutableStateOf(freshSmoothSnake()) }
    val speed=minOf(230f,76f+game.score*11f)
    LaunchedEffect(game.running){
        if(!game.running)return@LaunchedEffect
        var last=SystemClock.elapsedRealtimeNanos()
        while(game.running&&!game.over){
            delay(16)
            val now=SystemClock.elapsedRealtimeNanos()
            val dt=((now-last)/1_000_000_000f).coerceIn(0f,0.035f)
            last=now
            game=advanceSmoothSnake(game,dt)
        }
    }
    Text("Snake · Score: "+game.score+" · Speed: "+speed.toInt()+" px/s"+
        if(game.over)" · Game over" else "")
    Canvas(modifier=Modifier.fillMaxWidth().aspectRatio(1f)
        .pointerInput(Unit) {
            detectDragGestures { change,drag ->
                change.consume()
                if(drag.getDistance()>1f){
                    val target=drag/drag.getDistance()
                    if(target.x*game.heading.x+target.y*game.heading.y>-.8f)
                        game=game.copy(wanted=target)
                }
            }
        }) {
        val scale=size.minDimension/ARENA
        drawRect(Color(0xFFD9F5E9))
        for(i in 0 until 45){
            val x=((i*79+47)%400)*scale
            val y=((i*131+36)%400)*scale
            drawCircle(Color(0x221C8B5B),3f*scale,Offset(x,y))
        }
        game.food?.let { fruit ->
            val center=fruit*scale
            drawCircle(Color(0xFFE43F56),8f*scale,center+Offset(-5f*scale,2f*scale))
            drawCircle(Color(0xFFFF5270),8f*scale,center+Offset(5f*scale,2f*scale))
            drawLine(Color(0xFF855A36),center,center+Offset(2f*scale,-14f*scale),
                     strokeWidth=3f*scale,cap=StrokeCap.Round)
            drawCircle(Color(0xFF52B67A),4.5f*scale,center+Offset(8f*scale,-14f*scale))
        }
        val points=game.body
        for(i in points.size-1 downTo 1){
            drawLine(Color(0xFF218B63),points[i]*scale,points[i-1]*scale,
                     strokeWidth=19f*scale,cap=StrokeCap.Round)
            drawLine(Color(0xFF76DE9A),points[i]*scale,points[i-1]*scale,
                     strokeWidth=12f*scale,cap=StrokeCap.Round)
        }
        val face=points.first()*scale
        drawCircle(Color(0xFF76DE9A),11f*scale,face)
        val h=game.heading
        for(side in listOf(-5f,5f)){
            val eye=face+Offset((h.x*4f-h.y*side)*scale,(h.y*4f+h.x*side)*scale)
            drawCircle(Color.White,3.9f*scale,eye)
            drawCircle(Color(0xFF1F3943),2f*scale,
                       eye+Offset(h.x*1.3f*scale,h.y*1.3f*scale))
        }
    }
    Text("Drag to steer smoothly. Every cherry increases speed.")
    Row {
        Button(onClick={
            game=if(game.over)freshSmoothSnake() else game.copy(running=!game.running)
        }) { Text(if(game.over)"Try again" else if(game.running)"Pause" else "Start") }
        Button(onClick={game=freshSmoothSnake()}) { Text("Restart") }
    }
}

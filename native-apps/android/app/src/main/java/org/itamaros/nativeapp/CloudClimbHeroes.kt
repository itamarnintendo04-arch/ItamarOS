package org.itamaros.nativeapp

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.unit.dp

/** Original cosmetic characters. IDs correspond to the existing game rewards. */
data class CloudHero(val id:String,val name:String,val icon:String,val tint:Color,val scarf:Color)

object CloudHeroes {
    val all:List<CloudHero> = listOf(
        CloudHero("starter","Cloud Scout","☁️",Color.White,Color(0xFF1768EA)),
        CloudHero("sky_01","Sky Fox","🦊",Color(0xFFFFAF63),Color(0xFF3869EA)),
        CloudHero("sky_02","Nimbus Cat","🐱",Color(0xFFFFE5AD),Color(0xFF7D4EE8)),
        CloudHero("sky_03","Breeze Bunny","🐰",Color(0xFFFFDAF1),Color(0xFF2185D7)),
        CloudHero("sky_04","Rain Penguin","🐧",Color(0xFF9FD9ED),Color(0xFFEE8C3B)),
        CloudHero("sky_05","Star Pup","🐶",Color(0xFFFFD19C),Color(0xFF41B58E)),
        CloudHero("sky_06","Cloud Bear","🐻",Color(0xFFE9C49C),Color(0xFFF15A8C)),
        CloudHero("sky_07","Comet Owl","🦉",Color(0xFFC8ABF9),Color(0xFFFFCF54)),
        CloudHero("sky_08","Mist Koala","🐨",Color(0xFFC7D2DD),Color(0xFF40C8E8)),
        CloudHero("sky_09","Aurora Dragon","🐉",Color(0xFF91E3B7),Color(0xFFEF72D6)),
        CloudHero("sky_10","Kite Frog","🐸",Color(0xFFA6EC6D),Color(0xFF225DC6)),
        CloudHero("sky_11","Moon Bat","🦇",Color(0xFFB49AD8),Color(0xFFFFD667)),
        CloudHero("sky_12","Sun Lion","🦁",Color(0xFFFFCE63),Color(0xFFE87532))
    ) + listOf("💎","🪄","🌸","🪸","🧊","🌿","🌋","🌙","⚡","🌈").mapIndexed { i,icon ->
        val tints=listOf(Color(0xFF64DDF5),Color(0xFFB19DFF),Color(0xFFFFA9CE),
            Color(0xFFFFB38A),Color(0xFFAFEAFF),Color(0xFFB7F18F),
            Color(0xFFFF9B72),Color(0xFFB0B8ED),Color(0xFFFFE978),Color(0xFFFFD1FF))
        CloudHero("mystery_world_${i+1}","World ${i+1} Mystery",icon,tints[i],Color(0xFF2155BE))
    }
    fun get(id:String):CloudHero=all.firstOrNull { it.id==id } ?: all.first()
    fun unlocked(id:String,owned:Set<String>)=id=="starter"||id in owned
}

/** Draw a colorful jumping mascot instead of the previous placeholder square. */
fun DrawScope.drawCloudHero(id:String,x:Float,y:Float,sx:Float,sy:Float) {
    val hero=CloudHeroes.get(id)
    val cx=x*sx;val cy=y*sy
    drawCircle(Color(0x55082C7C),radius=15f*sx,center=Offset(cx,cy+8f*sy))
    drawRoundRect(hero.tint,topLeft=Offset(cx-12f*sx,cy-17f*sy),
        size=Size(24f*sx,25f*sy),cornerRadius=CornerRadius(11f*sx,11f*sy))
    if(hero.id!="starter") {
        drawCircle(hero.tint,radius=5.5f*sx,center=Offset(cx-10f*sx,cy-19f*sy))
        drawCircle(hero.tint,radius=5.5f*sx,center=Offset(cx+10f*sx,cy-19f*sy))
    }
    drawRoundRect(hero.scarf,topLeft=Offset(cx-13f*sx,cy-5f*sy),
        size=Size(26f*sx,5f*sy),cornerRadius=CornerRadius(3f*sx,3f*sy))
    drawCircle(Color(0xFF14253B),radius=2.7f*sx,center=Offset(cx-5f*sx,cy-10f*sy))
    drawCircle(Color(0xFF14253B),radius=2.7f*sx,center=Offset(cx+5f*sx,cy-10f*sy))
    drawCircle(Color(0xFFFA789B),radius=2.1f*sx,center=Offset(cx,cy-4f*sy))
}

@Composable
fun CloudHeroWardrobe(owned:Set<String>,selected:String,onSelect:(String)->Unit) {
    Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
        Text("CHARACTERS · ${owned.size+1}/23 unlocked",
            color=Color.White,style=MaterialTheme.typography.titleMedium)
        Text("Select an unlocked hero. Characters are cosmetic.",
            color=Color.White.copy(alpha=.8f),style=MaterialTheme.typography.bodySmall)
        Row(modifier=Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement=Arrangement.spacedBy(8.dp)) {
            CloudHeroes.all.forEach { hero ->
                val open=CloudHeroes.unlocked(hero.id,owned)
                OutlinedButton(onClick={ if(open)onSelect(hero.id) },enabled=open,
                    contentPadding=PaddingValues(horizontal=9.dp,vertical=7.dp),
                    colors=ButtonDefaults.outlinedButtonColors(
                        contentColor=Color.White,
                        containerColor=if(selected==hero.id)Color(0xFF315ABB) else Color(0xFF1C365D),
                        disabledContainerColor=Color(0xFF182740),
                        disabledContentColor=Color.White.copy(alpha=.48f)
                    )) {
                    Column(horizontalAlignment=Alignment.CenterHorizontally) {
                        Text(hero.icon,style=MaterialTheme.typography.headlineMedium)
                        Text(hero.name,style=MaterialTheme.typography.labelSmall)
                        Text(if(!open)"LOCKED" else if(selected==hero.id)"EQUIPPED" else "SELECT",
                            style=MaterialTheme.typography.labelSmall)
                    }
                }
            }
        }
    }
}

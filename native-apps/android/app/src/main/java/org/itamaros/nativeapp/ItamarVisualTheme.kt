package org.itamaros.nativeapp

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/** A shared native visual language, including distinct glyphs for every tab. */
object ItamarColors {
    val midnight = Color(0xFF0A1227)
    val navy = Color(0xFF15244A)
    val indigo = Color(0xFF445BDB)
    val cyan = Color(0xFF56D5FF)
    val violet = Color(0xFFA88AFF)
    val teal = Color(0xFF55DFC8)
    val gold = Color(0xFFFFCE7A)
    val muted = Color(0xFFBAC8ED)
    val panel = Color(0xFF19294C)
}

@Composable
fun ItamarVisualTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = ItamarColors.cyan,
            onPrimary = ItamarColors.midnight,
            primaryContainer = ItamarColors.navy,
            secondary = ItamarColors.violet,
            secondaryContainer = ItamarColors.panel,
            background = ItamarColors.midnight,
            surface = ItamarColors.navy,
            surfaceVariant = ItamarColors.panel,
            onBackground = Color(0xFFF7FAFF),
            onSurface = Color(0xFFF7FAFF),
            onSurfaceVariant = ItamarColors.muted
        ),
        shapes = Shapes(
            small = RoundedCornerShape(11.dp),
            medium = RoundedCornerShape(18.dp),
            large = RoundedCornerShape(26.dp)
        ),
        content = content
    )
}

@Composable
fun ItamarAppTabIcon(tab: String, selected: Boolean) {
    val (symbol, tone) = when(tab) {
        "Connect" -> Icons.Filled.Chat to ItamarColors.teal
        "Games" -> Icons.Filled.SportsEsports to ItamarColors.violet
        "Player" -> Icons.Filled.PlayCircle to ItamarColors.gold
        "Apps", "Store" -> Icons.Filled.Apps to ItamarColors.cyan
        "Settings" -> Icons.Filled.Settings to Color(0xFFB3C9FF)
        "Streaming" -> Icons.Filled.PlayCircle to ItamarColors.teal
        else -> Icons.Filled.Home to ItamarColors.cyan
    }
    Box(
        modifier = Modifier.size(35.dp).clip(RoundedCornerShape(12.dp))
            .background(if(selected) Brush.linearGradient(listOf(tone.copy(alpha=.38f),
                ItamarColors.indigo.copy(alpha=.45f)))
                else Brush.linearGradient(listOf(ItamarColors.panel,ItamarColors.panel))),
        contentAlignment = Alignment.Center
    ) {
        Icon(symbol, contentDescription = null,
            tint = if(selected) Color.White else tone, modifier=Modifier.size(21.dp))
    }
}

@Composable
fun ItamarHeroCard(isTv: Boolean, device: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(28.dp),
        border = BorderStroke(1.dp, ItamarColors.cyan.copy(alpha=.32f)),
        colors=CardDefaults.cardColors(containerColor=ItamarColors.navy)
    ) {
        Column(
            modifier=Modifier.fillMaxWidth().background(
                Brush.linearGradient(listOf(
                    ItamarColors.indigo.copy(alpha=.4f),
                    ItamarColors.navy,ItamarColors.midnight
                ))
            ).padding(24.dp),
            verticalArrangement=Arrangement.spacedBy(11.dp),
            horizontalAlignment=Alignment.CenterHorizontally
        ) {
            Surface(shape=RoundedCornerShape(25.dp),
                color=Color.White.copy(alpha=.08f)) {
                Icon(painterResource(R.drawable.itamaros_logo),
                    contentDescription="ItamarOS",tint=Color.Unspecified,
                    modifier=Modifier.padding(14.dp).size(95.dp))
            }
            Text("ItamarOS",style=MaterialTheme.typography.headlineLarge,
                fontWeight=FontWeight.ExtraBold,color=Color.White)
            Text("Your space. Your games. Your world.",
                color=ItamarColors.muted,style=MaterialTheme.typography.bodyMedium)
            Surface(color=ItamarColors.cyan.copy(alpha=.12f),
                shape=RoundedCornerShape(50.dp)) {
                Text(if(isTv) "ANDROID TV EXPERIENCE" else "ANDROID EXPERIENCE",
                    modifier=Modifier.padding(horizontal=16.dp,vertical=8.dp),
                    color=ItamarColors.cyan,style=MaterialTheme.typography.labelMedium)
            }
            Text(device,color=ItamarColors.muted,
                style=MaterialTheme.typography.labelSmall)
        }
    }
}

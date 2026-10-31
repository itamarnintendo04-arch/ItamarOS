package org.itamaros.nativeapp

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import java.util.Locale

// Local preference only. Android's device language is the default.
// Main navigation is translated; long-form and developer screens are being localized.
object AndroidLanguage {
    var choice by mutableStateOf("system")
    fun language():String = if(choice=="system") Locale.getDefault().language else choice
    private val labels=mapOf(
        "en" to listOf("Home","Connect","Games","Player","Apps","Settings"),
        "he" to listOf("בית","הודעות","משחקים","נגן","יישומים","הגדרות"),
        "ar" to listOf("الرئيسية","التواصل","الألعاب","المشغل","التطبيقات","الإعدادات"),
        "es" to listOf("Inicio","Conectar","Juegos","Reproductor","Aplicaciones","Ajustes"),
        "fr" to listOf("Accueil","Connecter","Jeux","Lecteur","Applications","Paramètres"),
        "de" to listOf("Startseite","Connect","Spiele","Player","Apps","Einstellungen"),
        "pt" to listOf("Início","Conectar","Jogos","Reprodutor","Aplicações","Definições"),
        "ru" to listOf("Главная","Контакты","Игры","Плеер","Приложения","Настройки"),
        "ja" to listOf("ホーム","連絡","ゲーム","プレーヤー","アプリ","設定"),
        "zh" to listOf("主页","联系","游戏","播放器","应用","设置"),
        "it" to listOf("Home","Contatti","Giochi","Lettore","App","Impostazioni"),
        "hi" to listOf("होम","संपर्क","गेम","प्लेयर","ऐप","सेटिंग्स"),
        "tr" to listOf("Ana sayfa","Bağlan","Oyunlar","Oynatıcı","Uygulamalar","Ayarlar"),
        "ko" to listOf("홈","연결","게임","플레이어","앱","설정")
    )
    fun tab(key:String):String {
        val index=listOf("Home","Connect","Games","Player","Apps","Settings").indexOf(key)
        return if(index<0)key else (labels[language()]?:labels["en"]!!)[index]
    }
}
@Composable
fun AndroidLanguageSettings(){
    val context=LocalContext.current
    LaunchedEffect(Unit){
        AndroidLanguage.choice=context.getSharedPreferences("itamaros_native",0)
            .getString("language","system")?:"system"
    }
    Text("App language",style=MaterialTheme.typography.titleMedium)
    Text("Uses your device's language by default. More screens will be translated in later updates.",
        style=MaterialTheme.typography.bodySmall)
    Row(modifier=Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement=Arrangement.spacedBy(6.dp)){
        listOf(
            "system" to "Device", "en" to "English", "he" to "עברית",
            "ar" to "العربية", "es" to "Español", "fr" to "Français",
            "de" to "Deutsch","pt" to "Português","ru" to "Русский",
            "ja" to "日本語", "zh" to "中文", "it" to "Italiano",
            "hi" to "हिन्दी","tr" to "Türkçe","ko" to "한국어"
        ).forEach { (code,name) ->
            FilterChip(selected=AndroidLanguage.choice==code,
                onClick={
                    AndroidLanguage.choice=code
                    context.getSharedPreferences("itamaros_native",0)
                        .edit().putString("language",code).apply()
                },label={Text(name)})
        }
    }
}

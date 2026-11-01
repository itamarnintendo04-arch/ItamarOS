package org.itamaros.nativeapp

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext

/** Local-only preference. Existing messages on other devices are never deleted. */
@Composable
fun AndroidConnectSyncSettings(){
    val context=LocalContext.current
    val preferences=remember { context.getSharedPreferences("itamaros_native",Context.MODE_PRIVATE) }
    var enabled by remember { mutableStateOf(preferences.getBoolean("connectSync",true)) }
    Text("ItamarConnect sync",style=MaterialTheme.typography.titleMedium)
    Row {
        Text("Sync chats and contacts on this device",modifier=Modifier.weight(1f))
        Switch(checked=enabled,onCheckedChange={ value ->
            enabled=value
            preferences.edit().putBoolean("connectSync",value).apply()
        })
    }
    Text("When disabled, ItamarConnect won't fetch your cloud conversations or saved contacts on this device. It won't delete existing messages elsewhere. A sign-in session may remain until you sign out.",
        style=MaterialTheme.typography.bodySmall)
}

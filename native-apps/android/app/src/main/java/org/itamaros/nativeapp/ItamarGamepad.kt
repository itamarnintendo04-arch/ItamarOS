package org.itamaros.nativeapp

import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

// Generic Android controller input; Xbox / PlayStation / Switch compatibility depends on
// the Android version, pairing, manufacturer, and exposed gamepad input profile.
object ItamarGamepad {
    var enabled=false
    var axis by mutableFloatStateOf(0f)
    var jump by mutableStateOf(false)
    var left by mutableStateOf(false)
    var right by mutableStateOf(false)
    var attack by mutableStateOf(false)
    var pause by mutableStateOf(false)
    var detected by mutableStateOf(false)
    fun motion(event: MotionEvent):Boolean {
        if(!enabled || event.source and InputDevice.SOURCE_JOYSTICK != InputDevice.SOURCE_JOYSTICK)return false
        axis=event.getAxisValue(MotionEvent.AXIS_X).coerceIn(-1f,1f)
        detected=true
        return true
    }
    fun key(event: KeyEvent):Boolean {
        if(!enabled || (event.source and InputDevice.SOURCE_GAMEPAD != InputDevice.SOURCE_GAMEPAD &&
             event.source and InputDevice.SOURCE_DPAD != InputDevice.SOURCE_DPAD))return false
        val down=event.action==KeyEvent.ACTION_DOWN
        when(event.keyCode){
            KeyEvent.KEYCODE_DPAD_LEFT->left=down
            KeyEvent.KEYCODE_DPAD_RIGHT->right=down
            KeyEvent.KEYCODE_BUTTON_A,KeyEvent.KEYCODE_BUTTON_B,
            KeyEvent.KEYCODE_DPAD_UP->jump=down
            KeyEvent.KEYCODE_BUTTON_X,KeyEvent.KEYCODE_BUTTON_Y->attack=down
            KeyEvent.KEYCODE_BUTTON_START->pause=down
            else->return false
        }
        detected=true
        return true
    }
    fun reset(){enabled=false;axis=0f;jump=false;left=false;right=false;attack=false;pause=false;detected=false}
}

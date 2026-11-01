package org.itamaros.nativeapp

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File
import java.util.UUID

// Only starts after a real user tap and system permission.
// Recorded AAC audio stays in app cache until the user explicitly sends it.
class AndroidVoiceNoteRecorder(private val context: Context) {
    private var recorder: MediaRecorder? = null
    private var file: File? = null
    var isRecording: Boolean = false
        private set

    @Suppress("DEPRECATION")
    fun start() {
        if(isRecording)return
        val result=File(context.cacheDir,"ItamarOS-Voice-"+UUID.randomUUID()+".m4a")
        val audio=if(Build.VERSION.SDK_INT>=31)MediaRecorder(context) else MediaRecorder()
        try {
            audio.setAudioSource(MediaRecorder.AudioSource.MIC)
            audio.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            audio.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            audio.setAudioEncodingBitRate(64000)
            audio.setAudioSamplingRate(24000)
            audio.setOutputFile(result.absolutePath)
            audio.setMaxDuration(90000)
            audio.prepare()
            audio.start()
            recorder=audio
            file=result
            isRecording=true
        } catch(error:Exception) {
            try { audio.reset();audio.release() } catch(_:Exception) {}
            result.delete()
            throw error
        }
    }
    fun stop():File? {
        if(!isRecording)return null
        val captured=file
        try{
            recorder?.stop()
            return captured?.takeIf{it.exists()&&it.length()>0}
        }catch(error:Exception){
            captured?.delete()
            throw error
        }finally{
            recorder?.release()
            recorder=null
            file=null
            isRecording=false
        }
    }
    fun discard() {
        if(!isRecording)return
        try { recorder?.stop() }catch(_:Exception){}
        recorder?.release()
        recorder=null
        file?.delete()
        file=null
        isRecording=false
    }
}

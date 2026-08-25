package com.example.ecoair

import android.speech.tts.TextToSpeech
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val voiceChannel = "ecoair/voice"
    private var textToSpeech: TextToSpeech? = null
    private var isTtsReady = false
    private var pendingText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        textToSpeech = TextToSpeech(this, this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, voiceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text")?.trim()
                        if (text.isNullOrEmpty()) {
                            result.error(
                                "EMPTY_TEXT",
                                "There is no air quality report to read.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        speak(text)
                        result.success(null)
                    }

                    "stop" -> {
                        textToSpeech?.stop()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onInit(status: Int) {
        isTtsReady = status == TextToSpeech.SUCCESS
        if (!isTtsReady) {
            pendingText = null
            return
        }

        textToSpeech?.language = Locale.US
        pendingText?.let {
            speak(it)
            pendingText = null
        }
    }

    private fun speak(text: String) {
        if (!isTtsReady) {
            pendingText = text
            return
        }

        textToSpeech?.setSpeechRate(0.92f)
        textToSpeech?.setPitch(1.0f)
        textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "ecoair_voice_report")
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        super.onDestroy()
    }
}

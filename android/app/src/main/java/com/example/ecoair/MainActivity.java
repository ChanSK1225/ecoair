package com.example.ecoair;

import android.speech.tts.TextToSpeech;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.Locale;
import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.UtteranceProgressListener;

public class MainActivity extends FlutterActivity implements TextToSpeech.OnInitListener {
    private static final String VOICE_CHANNEL = "ecoair/voice";
    private static final String PAYMENT_CHANNEL = "ecoair/payment";
    private TextToSpeech textToSpeech;
    private boolean isTtsReady = false;
    private String pendingText;
    private MethodChannel.Result voiceResult;
    private String activeVoiceId;
    private boolean ttsFailed;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private MethodChannel.Result permissionResult;
    private static final String WARNING_CHANNEL = "ecoair_weather";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        textToSpeech = new TextToSpeech(this, this);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), PAYMENT_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (!"openUrl".equals(call.method)) {
                    result.notImplemented();
                    return;
                }

                String url = call.argument("url");
                if (url == null || url.trim().isEmpty()) {
                    result.error("EMPTY_URL", "No checkout URL was provided.", null);
                    return;
                }
                try {
                    Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                    startActivity(intent);
                    result.success(null);
                } catch (Exception error) {
                    result.error("OPEN_URL_FAILED", "Could not open Stripe Checkout.", null);
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "ecoair/notifications")
            .setMethodCallHandler((call, result) -> {
                NotificationManager manager = getSystemService(NotificationManager.class);
                if (Build.VERSION.SDK_INT >= 26) {
                    manager.createNotificationChannel(new NotificationChannel(WARNING_CHANNEL, "EcoAir weather warnings", NotificationManager.IMPORTANCE_DEFAULT));
                }
                switch (call.method) {
                    case "requestPermission":
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (permissionResult != null) { result.success(false); return; }
                            permissionResult = result;
                            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 2073);
                        } else { result.success(manager.areNotificationsEnabled()); }
                        break;
                    case "clear":
                        manager.cancelAll();
                        result.success(null);
                        break;
                    case "show":
                        if (!manager.areNotificationsEnabled() || (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)) {
                            result.success(false); return;
                        }
                        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(WARNING_CHANNEL).getImportance() == NotificationManager.IMPORTANCE_NONE) {
                            result.success(false); return;
                        }
                        String title = call.argument("title");
                        String body = call.argument("body");
                        Integer id = call.argument("id");
                        Intent intent = new Intent(this, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                        PendingIntent pending = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                        Notification.Builder builder = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, WARNING_CHANNEL) : new Notification.Builder(this);
                        builder.setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title).setContentText(body)
                            .setStyle(new Notification.BigTextStyle().bigText(body)).setContentIntent(pending).setAutoCancel(true);
                        manager.notify(id == null ? 2073 : id, builder.build());
                        result.success(true);
                        break;
                    default: result.notImplemented();
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), VOICE_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "speak":
                        String text = call.argument("text");
                        if (text == null || text.trim().isEmpty()) {
                            result.error(
                                "EMPTY_TEXT",
                                "There is no air quality report to read.",
                                null
                            );
                            return;
                        }

                        finishVoice("CANCELLED", "Previous speech was replaced.");
                        voiceResult = result;
                        activeVoiceId = "ecoair_voice_" + System.nanoTime();
                        speak(text.trim());
                        handler.postDelayed(() -> {
                            if (voiceResult == result) finishVoice("TTS_TIMEOUT", "Speech did not start. Check the Android text-to-speech engine.");
                        }, 15000);
                        break;
                    case "stop":
                        pendingText = null;
                        finishVoice("CANCELLED", "Speech stopped.");
                        if (textToSpeech != null) {
                            textToSpeech.stop();
                        }
                        result.success(null);
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            });
    }

    @Override
    public void onInit(int status) {
        isTtsReady = status == TextToSpeech.SUCCESS;
        ttsFailed = !isTtsReady;
        if (!isTtsReady) {
            pendingText = null;
            finishVoice("TTS_UNAVAILABLE", "Text-to-speech initialization failed. Check the installed speech engine.");
            return;
        }

        if (textToSpeech != null) {
            int language = textToSpeech.setLanguage(Locale.US);
            if (language == TextToSpeech.LANG_MISSING_DATA || language == TextToSpeech.LANG_NOT_SUPPORTED) {
                ttsFailed = true;
                isTtsReady = false;
                finishVoice("TTS_LANGUAGE", "Install English voice data in Android text-to-speech settings.");
                return;
            }
            textToSpeech.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override public void onStart(String id) { runOnUiThread(() -> { if (id.equals(activeVoiceId)) finishVoice(null, null); }); }
                @Override public void onDone(String id) { }
                @Override public void onError(String id) { runOnUiThread(() -> { if (id.equals(activeVoiceId)) finishVoice("TTS_ERROR", "The speech engine could not play this report."); }); }
            });
        }
        if (pendingText != null) {
            String text = pendingText;
            pendingText = null;
            speak(text);
        }
    }

    private void speak(String text) {
        if (ttsFailed) {
            finishVoice("TTS_UNAVAILABLE", "English speech is unavailable. Check the Android speech engine and voice data.");
            return;
        }
        if (!isTtsReady) {
            pendingText = text;
            return;
        }
        if (textToSpeech == null) {
            finishVoice("TTS_UNAVAILABLE", "The speech engine is unavailable.");
            return;
        }

        textToSpeech.setSpeechRate(0.92f);
        textToSpeech.setPitch(1.0f);
        if (textToSpeech.speak(text, TextToSpeech.QUEUE_FLUSH, null, activeVoiceId) == TextToSpeech.ERROR) {
            finishVoice("TTS_ERROR", "The speech engine rejected this report.");
        }
    }

    private void finishVoice(String code, String message) {
        if (voiceResult == null) return;
        MethodChannel.Result result = voiceResult;
        voiceResult = null;
        if (code == null) result.success(null); else result.error(code, message, null);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == 2073 && permissionResult != null) {
            permissionResult.success(grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED);
            permissionResult = null;
        }
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        finishVoice("CANCELLED", "Speech stopped.");
        if (permissionResult != null) { permissionResult.success(false); permissionResult = null; }
        if (textToSpeech != null) {
            textToSpeech.stop();
            textToSpeech.shutdown();
        }
        super.onDestroy();
    }
}

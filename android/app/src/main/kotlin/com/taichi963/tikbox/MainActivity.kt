package com.taichi963.tikbox

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.taichi963.tikbox/gift_vibration",
        ).setMethodCallHandler { call, result ->
            if (call.method != "vibrateGift") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val value = call.argument<Int>("value") ?: 0
            result.success(vibrateGift(value))
        }
    }

    private fun vibrateGift(value: Int): Boolean {
        val vibrator = currentVibrator() ?: return false
        if (!vibrator.hasVibrator()) {
            return false
        }

        val durationMillis = when {
            value >= 100 -> 90L
            value >= 10 -> 65L
            else -> 50L
        }
        val amplitude = when {
            value >= 100 -> 230
            value >= 10 -> 190
            else -> 160
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(durationMillis, amplitude),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(durationMillis)
        }
        return true
    }

    private fun currentVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }
}

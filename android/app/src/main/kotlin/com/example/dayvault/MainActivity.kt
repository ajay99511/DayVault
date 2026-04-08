package com.example.dayvault

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity for DayVault.
 *
 * Note: AICore (ML Kit) platform channel has been stubbed out.
 * The ML Kit dependency was removed to reduce APK size.
 * All AI functionality now uses flutter_gemma exclusively.
 *
 * To re-enable AICore:
 * 1. Add `implementation("com.google.mlkit:genai-prompt:1.0.0-beta2")` to build.gradle.kts
 * 2. Restore the original MainActivity.kt from Git history
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "dayvault/aicore"
        private const val TAG = "DayVaultAICore"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkStatus" -> {
                        // Stub: AICore not available (ML Kit removed)
                        result.success(mapOf(
                            "platformSupported" to false,
                            "statusCode" to 0, // UNAVAILABLE
                            "statusLabel" to "UNAVAILABLE",
                            "message" to "AICore (ML Kit) was removed to reduce APK size. Use Gemma instead.",
                        ))
                    }
                    "downloadModel" -> {
                        // Stub: Cannot download (ML Kit removed)
                        result.success(mapOf(
                            "platformSupported" to false,
                            "statusCode" to 0, // UNAVAILABLE
                            "statusLabel" to "UNAVAILABLE",
                            "message" to "AICore (ML Kit) was removed to reduce APK size.",
                        ))
                    }
                    "generate" -> {
                        // Stub: Cannot generate (ML Kit removed)
                        result.error(
                            "aicore_removed",
                            "AICore (ML Kit) was removed to reduce APK size. Use Gemma for AI functionality.",
                            null,
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

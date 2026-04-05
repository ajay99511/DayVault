package com.example.dayvault

import android.os.Build
import android.util.Log
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.GenerateContentRequest
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "dayvault/aicore"
        private const val TAG = "DayVaultAICore"
    }

    private val aiExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val downloadInFlight = AtomicBoolean(false)
    private val generativeModelFutures: GenerativeModelFutures by lazy {
        GenerativeModelFutures.from(Generation.getClient())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkStatus" -> handleCheckStatus(result)
                    "downloadModel" -> handleDownloadModel(result)
                    "generate" -> handleGenerate(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        aiExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun isPlatformEligible(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
    }

    private fun handleCheckStatus(result: MethodChannel.Result) {
        if (!isPlatformEligible()) {
            replySuccess(
                result,
                statusPayload(
                    FeatureStatus.UNAVAILABLE,
                    "Requires Android API 26+.",
                ),
            )
            return
        }

        aiExecutor.execute {
            try {
                val status = generativeModelFutures.checkStatus().get(15, TimeUnit.SECONDS)
                replySuccess(result, statusPayload(status))
            } catch (e: TimeoutException) {
                replyError(result, "timeout", "AICore status check timed out.", e.message)
            } catch (e: Exception) {
                replyError(result, "status_failed", "AICore status check failed.", e.message)
            }
        }
    }

    private fun handleDownloadModel(result: MethodChannel.Result) {
        if (!isPlatformEligible()) {
            replySuccess(
                result,
                statusPayload(
                    FeatureStatus.UNAVAILABLE,
                    "Requires Android API 26+.",
                ),
            )
            return
        }

        aiExecutor.execute {
            try {
                val status = generativeModelFutures.checkStatus().get(15, TimeUnit.SECONDS)
                when (status) {
                    FeatureStatus.AVAILABLE -> {
                        replySuccess(
                            result,
                            statusPayload(FeatureStatus.AVAILABLE, "AICore model already available."),
                        )
                    }

                    FeatureStatus.DOWNLOADING -> {
                        downloadInFlight.set(true)
                        replySuccess(
                            result,
                            statusPayload(FeatureStatus.DOWNLOADING, "AICore model download in progress."),
                        )
                    }

                    FeatureStatus.DOWNLOADABLE -> {
                        if (downloadInFlight.compareAndSet(false, true)) {
                            generativeModelFutures.download(
                                object : DownloadCallback {
                                    override fun onDownloadStarted(totalBytesToDownload: Long) {
                                        Log.d(TAG, "AICore download started. bytes=$totalBytesToDownload")
                                    }

                                    override fun onDownloadProgress(totalBytesDownloaded: Long) {
                                        Log.d(TAG, "AICore download progress bytes=$totalBytesDownloaded")
                                    }

                                    override fun onDownloadCompleted() {
                                        Log.d(TAG, "AICore download completed.")
                                        downloadInFlight.set(false)
                                    }

                                    override fun onDownloadFailed(e: GenAiException) {
                                        Log.e(TAG, "AICore download failed: ${e.message}")
                                        downloadInFlight.set(false)
                                    }
                                },
                            )
                        }

                        replySuccess(
                            result,
                            statusPayload(
                                FeatureStatus.DOWNLOADING,
                                "Requested AICore model download.",
                            ),
                        )
                    }

                    else -> {
                        replySuccess(
                            result,
                            statusPayload(
                                FeatureStatus.UNAVAILABLE,
                                "AICore model unavailable on this device.",
                            ),
                        )
                    }
                }
            } catch (e: Exception) {
                downloadInFlight.set(false)
                replyError(result, "download_failed", "AICore download request failed.", e.message)
            }
        }
    }

    private fun handleGenerate(call: MethodCall, result: MethodChannel.Result) {
        if (!isPlatformEligible()) {
            replyError(result, "unsupported", "Requires Android API 26+.", null)
            return
        }

        val prompt = (call.argument<String>("prompt") ?: "").trim()
        if (prompt.isEmpty()) {
            replyError(result, "invalid_prompt", "Prompt cannot be empty.", null)
            return
        }

        aiExecutor.execute {
            try {
                val status = generativeModelFutures.checkStatus().get(15, TimeUnit.SECONDS)
                if (status != FeatureStatus.AVAILABLE) {
                    replyError(
                        result,
                        "not_ready",
                        "AICore model is not available.",
                        statusLabel(status),
                    )
                    return@execute
                }

                val requestBuilder = GenerateContentRequest.Builder(TextPart(prompt))

                val response = generativeModelFutures.generateContent(requestBuilder.build())
                    .get(180, TimeUnit.SECONDS)
                val text = response.candidates.firstOrNull()?.text.orEmpty()

                replySuccess(
                    result,
                    mapOf(
                        "statusCode" to status,
                        "statusLabel" to statusLabel(status),
                        "platformSupported" to true,
                        "text" to text,
                    ),
                )
            } catch (e: TimeoutException) {
                replyError(result, "timeout", "AICore generation timed out.", e.message)
            } catch (e: GenAiException) {
                replyError(result, "genai_error", "AICore generation failed.", e.message)
            } catch (e: Exception) {
                replyError(result, "generation_failed", "AICore generation failed.", e.message)
            }
        }
    }

    private fun statusPayload(status: Int, message: String? = null): Map<String, Any?> {
        return mapOf(
            "platformSupported" to isPlatformEligible(),
            "statusCode" to status,
            "statusLabel" to statusLabel(status),
            "message" to message,
        )
    }

    private fun statusLabel(status: Int): String {
        return when (status) {
            FeatureStatus.UNAVAILABLE -> "UNAVAILABLE"
            FeatureStatus.DOWNLOADABLE -> "DOWNLOADABLE"
            FeatureStatus.DOWNLOADING -> "DOWNLOADING"
            FeatureStatus.AVAILABLE -> "AVAILABLE"
            else -> "UNKNOWN"
        }
    }

    private fun replySuccess(result: MethodChannel.Result, payload: Any?) {
        runOnUiThread { result.success(payload) }
    }

    private fun replyError(
        result: MethodChannel.Result,
        code: String,
        message: String,
        details: String?,
    ) {
        runOnUiThread { result.error(code, message, details) }
    }
}

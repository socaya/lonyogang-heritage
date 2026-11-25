package com.lonyogang.lonyogang_heritage

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterFragmentActivity() {
    private val alias = "lonyogang.session.credentials.v2"
    private val prefs by lazy { getSharedPreferences("secure_session_v2", MODE_PRIVATE) }
    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private fun key(create: Boolean): SecretKey {
        val store = keyStore()
        val existing = store.getKey(alias, null) as? SecretKey
        if (existing != null) return existing
        check(create) { "Credential key unavailable" }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .build())
        }.generateKey()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val vault = BiometricVault(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lonyogang/biometric_vault").setMethodCallHandler(vault::handle)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lonyogang/secure_session").setMethodCallHandler { call, result ->
            try {
                if (Build.VERSION.SDK_INT < 23) {
                    result.error("unsupported", "Secure session storage requires Android 6 or later", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "write" -> {
                        val value = call.argument<String>("value") ?: error("Missing credentials")
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.ENCRYPT_MODE, key(true))
                        val encoded = Base64.encodeToString(cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
                        check(prefs.edit().putString("envelope", encoded).commit())
                        result.success(null)
                    }
                    "read" -> {
                        val encoded = prefs.getString("envelope", null)
                        if (encoded == null) result.success(null)
                        else {
                            val bytes = Base64.decode(encoded, Base64.NO_WRAP)
                            check(bytes.size > 28)
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
                            result.success(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
                        }
                    }
                    "clear" -> {
                        check(prefs.edit().remove("envelope").commit())
                        keyStore().deleteEntry(alias)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("secure_storage_failed", "Secure session storage unavailable", null)
            }
        }
    }
}

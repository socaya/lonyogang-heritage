package com.lonyogang.lonyogang_heritage

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.KeyInfo
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec

internal class BiometricVault(private val activity: FragmentActivity) {
    private val alias = "lonyogang.vault.biometric.v3"
    private val prefs = activity.getSharedPreferences("biometric_vault_v3", android.content.Context.MODE_PRIVATE)
    private var busy = false
    private fun store() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private fun available() = Build.VERSION.SDK_INT >= 30 &&
        BiometricManager.from(activity).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
    private fun clear() {
        store().deleteEntry(alias)
        check(prefs.edit().clear().commit())
    }
    private fun prompt(cipher: Cipher, title: String, result: MethodChannel.Result, action: (Cipher) -> Any?) {
        busy = true
        try {
            val prompt = BiometricPrompt(activity, ContextCompat.getMainExecutor(activity),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        busy = false
                        result.error("biometric_cancelled", "Biometric authentication unavailable or cancelled", null)
                    }
                    override fun onAuthenticationSucceeded(auth: BiometricPrompt.AuthenticationResult) {
                        try {
                            val authenticated = auth.cryptoObject?.cipher ?: error("Missing authenticated cipher")
                            result.success(action(authenticated))
                        } catch (_: Exception) {
                            result.error("biometric_failed", "Secure biometric operation failed", null)
                        } finally { busy = false }
                    }
                })
            prompt.authenticate(BiometricPrompt.PromptInfo.Builder()
                .setTitle(title).setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText("Use passphrase").build(), BiometricPrompt.CryptoObject(cipher))
        } catch (e: Exception) { busy = false; throw e }
    }
    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        try {
            if (busy) { result.error("busy", "Authentication in progress", null); return }
            when (call.method) {
                "available" -> result.success(available())
                "linked" -> result.success(Build.VERSION.SDK_INT >= 30 && prefs.contains("envelope") && store().containsAlias(alias))
                "clear" -> { if (Build.VERSION.SDK_INT >= 30) clear(); result.success(null) }
                "enroll" -> {
                    check(available())
                    val secret = call.argument<String>("passphrase") ?: error("Missing passphrase")
                    clear()
                    val key = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
                        init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                            .setKeySize(256).setRandomizedEncryptionRequired(true)
                            .setUserAuthenticationRequired(true)
                            .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                            .setInvalidatedByBiometricEnrollment(true).build())
                    }.generateKey()
                    val info = SecretKeyFactory.getInstance(key.algorithm, "AndroidKeyStore").getKeySpec(key, KeyInfo::class.java) as KeyInfo
                    if (!info.isInsideSecureHardware) { clear(); error("Hardware protection unavailable") }
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key) }
                    prompt(cipher, "Link vault biometrics", result) { authenticated ->
                        val bytes = secret.toByteArray(Charsets.UTF_8)
                        try {
                            val encrypted = authenticated.doFinal(bytes)
                            check(prefs.edit().putString("envelope", Base64.encodeToString(authenticated.iv + encrypted, Base64.NO_WRAP)).commit())
                            null
                        } finally { bytes.fill(0) }
                    }
                }
                "unlock" -> {
                    check(available())
                    val envelope = Base64.decode(prefs.getString("envelope", null) ?: error("Not linked"), Base64.NO_WRAP)
                    check(envelope.size > 28)
                    val key = store().getKey(alias, null) as? SecretKey ?: error("Key unavailable")
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
                        init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, envelope.copyOfRange(0, 12)))
                    }
                    prompt(cipher, "Unlock portfolio", result) { authenticated ->
                        val bytes = authenticated.doFinal(envelope.copyOfRange(12, envelope.size))
                        try { String(bytes, Charsets.UTF_8) } finally { bytes.fill(0) }
                    }
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) { result.error("biometric_unavailable", "Use your vault passphrase", null) }
    }
}

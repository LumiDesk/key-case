package top.talyra42.keycase

import android.os.Bundle
import android.widget.Toast
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.ViewModelProvider
import top.talyra42.keycase.data.BiometricVault
import top.talyra42.keycase.ui.KeyCaseApp
import top.talyra42.keycase.ui.MainViewModel

class MainActivity : FragmentActivity() {
    private lateinit var viewModel: MainViewModel
    private val biometricVault by lazy { BiometricVault(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        viewModel = ViewModelProvider(this)[MainViewModel::class.java]
        setContent {
            KeyCaseApp(viewModel)
        }
    }

    fun isBiometricAvailable(): Boolean = biometricVault.isAvailable()

    fun isBiometricEnrolled(): Boolean = biometricVault.isEnrolled()

    fun enableBiometric(onResult: (Boolean) -> Unit) {
        val vaultKey = viewModel.copyVaultKeyForBiometric()
        if (vaultKey == null) {
            onResult(false)
            return
        }
        biometricVault.enable(this, vaultKey) { ok, message ->
            vaultKey.fill(0)
            if (!ok && !message.isNullOrBlank()) {
                Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
            }
            onResult(ok)
        }
    }

    fun disableBiometric() {
        biometricVault.clear()
    }

    fun unlockWithBiometric(onError: (String) -> Unit) {
        biometricVault.unlock(
            activity = this,
            onSuccess = { vaultKey -> viewModel.unlockWithVaultKey(vaultKey) },
            onError = { message ->
                Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
                onError(message)
            },
        )
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations) {
            viewModel.onHostStopped()
        }
    }
}

package top.talyra42.keycase.data

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Locks the vault when the whole app goes to the background.
 *
 * The previous implementation used an Activity Handler, which fired for
 * external pickers and was easy to bypass. ProcessLifecycleOwner observes the
 * app rather than a single Activity; [shouldSkip] is consumed once for
 * user-triggered external activities (scanner, document pickers).
 */
class AutoLockManager(
    private val autoLockSeconds: () -> Int,
    private val shouldSkip: () -> Boolean,
    private val onLock: () -> Unit,
) : DefaultLifecycleObserver {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var pendingLock: Job? = null

    override fun onStart(owner: LifecycleOwner) {
        pendingLock?.cancel()
        pendingLock = null
        // Consume a one-shot external-activity flag even if the app returned
        // before ProcessLifecycleOwner reported ON_STOP; otherwise a stale flag
        // would suppress the next real background lock.
        shouldSkip()
    }

    override fun onStop(owner: LifecycleOwner) {
        if (shouldSkip()) return
        val seconds = autoLockSeconds().coerceAtLeast(0)
        if (seconds == 0) {
            onLock()
        } else {
            pendingLock?.cancel()
            pendingLock = scope.launch {
                delay(seconds * 1000L)
                onLock()
            }
        }
    }

    fun close() {
        pendingLock?.cancel()
        pendingLock = null
        scope.cancel()
    }
}

package top.talyra42.keycase.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import top.talyra42.keycase.ui.AppSettings
import top.talyra42.keycase.ui.DarkMode

private fun Color.containerOn(background: Color, alpha: Float): Color =
    copy(alpha = alpha).compositeOver(background)

@Composable
fun KeyCaseTheme(
    settings: AppSettings,
    content: @Composable () -> Unit,
) {
    val dark = when (settings.darkMode) {
        DarkMode.SYSTEM -> isSystemInDarkTheme()
        DarkMode.LIGHT -> false
        DarkMode.DARK -> true
    }
    val accent = AccentPalette[settings.accentIndex.coerceIn(0, AccentPalette.lastIndex)]

    val scheme = if (dark) {
        darkColorScheme(
            primary = accent,
            onPrimary = Color.White,
            primaryContainer = accent.containerOn(DarkSurface, 0.28f),
            onPrimaryContainer = Color(0xFFDCE7FF),
            secondary = accent,
            onSecondary = Color.White,
            secondaryContainer = accent.containerOn(DarkSurface, 0.20f),
            onSecondaryContainer = Color(0xFFDCE7FF),
            tertiary = accent,
            background = DarkBackground,
            onBackground = DarkInk,
            surface = DarkSurface,
            onSurface = DarkInk,
            surfaceVariant = DarkSurfaceVariant,
            onSurfaceVariant = DarkMuted,
            outline = DarkOutline,
            error = Color(0xFFFFB4AB),
            onError = Color(0xFF690005),
        )
    } else {
        lightColorScheme(
            primary = accent,
            onPrimary = Color.White,
            primaryContainer = accent.containerOn(LightBackground, 0.14f),
            onPrimaryContainer = accent,
            secondary = accent,
            onSecondary = Color.White,
            secondaryContainer = accent.containerOn(LightBackground, 0.10f),
            onSecondaryContainer = accent,
            tertiary = accent,
            background = LightBackground,
            onBackground = LightInk,
            surface = LightSurface,
            onSurface = LightInk,
            surfaceVariant = LightSurfaceVariant,
            onSurfaceVariant = LightMuted,
            outline = LightOutline,
            error = Color(0xFFBA1A1A),
            onError = Color.White,
        )
    }

    MaterialTheme(
        colorScheme = scheme,
        typography = Typography,
        content = content,
    )
}

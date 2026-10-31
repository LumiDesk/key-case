package top.talyra42.keycase.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.unit.dp
import top.talyra42.keycase.ui.AppSettings
import top.talyra42.keycase.ui.DarkMode

private fun Color.tintOn(background: Color, alpha: Float): Color =
    copy(alpha = alpha).compositeOver(background)

private fun onAccent(accent: Color): Color =
    if (accent.luminance() > 0.30f) Color(0xFF111827) else Color.White

private val KeyCaseShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(10.dp),
    medium = RoundedCornerShape(14.dp),
    large = RoundedCornerShape(18.dp),
    extraLarge = RoundedCornerShape(24.dp),
)

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
    val accent = settings.customAccent?.let { Color(it) }
        ?: AccentPalette[settings.accentIndex.coerceIn(0, AccentPalette.lastIndex)]
    val ink = onAccent(accent)

    val scheme = if (dark) {
        darkColorScheme(
            primary = accent,
            onPrimary = ink,
            primaryContainer = accent.tintOn(DarkSurface, 0.20f),
            onPrimaryContainer = Color(0xFFF1F5FB),
            secondary = accent,
            onSecondary = ink,
            secondaryContainer = accent.tintOn(DarkSurface, 0.12f),
            onSecondaryContainer = Color(0xFFF1F5FB),
            tertiary = accent,
            onTertiary = ink,
            background = DarkBackground,
            onBackground = DarkInk,
            surface = DarkSurface,
            onSurface = DarkInk,
            surfaceVariant = DarkSurfaceVariant,
            onSurfaceVariant = DarkMuted,
            surfaceTint = accent,
            outline = DarkOutline,
            outlineVariant = DarkOutlineVariant,
            error = Color(0xFFFFB4AB),
            onError = Color(0xFF690005),
            errorContainer = Color(0xFF93000A),
            onErrorContainer = Color(0xFFFFDAD6),
        )
    } else {
        lightColorScheme(
            primary = accent,
            onPrimary = ink,
            primaryContainer = accent.tintOn(LightSurface, 0.10f),
            onPrimaryContainer = accent,
            secondary = accent,
            onSecondary = ink,
            secondaryContainer = accent.tintOn(LightSurface, 0.07f),
            onSecondaryContainer = accent,
            tertiary = accent,
            onTertiary = ink,
            background = LightBackground,
            onBackground = LightInk,
            surface = LightSurface,
            onSurface = LightInk,
            surfaceVariant = LightSurfaceVariant,
            onSurfaceVariant = LightMuted,
            surfaceTint = accent,
            outline = LightOutline,
            outlineVariant = LightOutlineVariant,
            error = Danger,
            onError = Color.White,
            errorContainer = Color(0xFFFFE4E1),
            onErrorContainer = Color(0xFF7F1D1D),
        )
    }

    MaterialTheme(
        colorScheme = scheme,
        typography = Typography,
        shapes = KeyCaseShapes,
        content = content,
    )
}

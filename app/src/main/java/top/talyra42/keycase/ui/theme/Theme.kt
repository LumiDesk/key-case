package top.talyra42.keycase.ui.theme

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
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

private fun contrastRatio(a: Color, b: Color): Float {
    val first = maxOf(a.luminance(), b.luminance())
    val second = minOf(a.luminance(), b.luminance())
    return (first + 0.05f) / (second + 0.05f)
}

internal fun onAccent(accent: Color): Color {
    val ink = Color(0xFF111827)
    return if (contrastRatio(accent, ink) >= contrastRatio(accent, Color.White)) {
        ink
    } else {
        Color.White
    }
}

private fun readableOn(background: Color, preferred: Color): Color {
    if (contrastRatio(background, preferred) >= 4.5f) return preferred
    val ink = Color(0xFF111827)
    val white = Color.White
    return if (contrastRatio(background, ink) >= contrastRatio(background, white)) ink else white
}

private val KeyCaseShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(10.dp),
    medium = RoundedCornerShape(14.dp),
    large = RoundedCornerShape(18.dp),
    extraLarge = RoundedCornerShape(24.dp),
)

@Composable
private fun animated(target: Color, label: String): Color =
    animateColorAsState(
        targetValue = target,
        animationSpec = tween(durationMillis = 360),
        label = label,
    ).value

private fun lightScheme(accent: Color): ColorScheme {
    val ink = onAccent(accent)
    val primaryContainer = accent.tintOn(LightSurface, 0.10f)
    val secondaryContainer = accent.tintOn(LightSurface, 0.07f)
    return lightColorScheme(
        primary = accent,
        onPrimary = ink,
        primaryContainer = primaryContainer,
        onPrimaryContainer = readableOn(primaryContainer, accent),
        secondary = accent,
        onSecondary = ink,
        secondaryContainer = secondaryContainer,
        onSecondaryContainer = readableOn(secondaryContainer, accent),
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

private fun darkScheme(accent: Color): ColorScheme {
    val ink = onAccent(accent)
    val primaryContainer = accent.tintOn(DarkSurface, 0.20f)
    val secondaryContainer = accent.tintOn(DarkSurface, 0.12f)
    return darkColorScheme(
        primary = accent,
        onPrimary = ink,
        primaryContainer = primaryContainer,
        onPrimaryContainer = readableOn(primaryContainer, Color(0xFFF1F5FB)),
        secondary = accent,
        onSecondary = ink,
        secondaryContainer = secondaryContainer,
        onSecondaryContainer = readableOn(secondaryContainer, Color(0xFFF1F5FB)),
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
}

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
    val base = if (dark) darkScheme(accent) else lightScheme(accent)

    // A color change or light/dark switch animates every large surface, so the
    // UI does not flash between two unrelated palettes.
    val scheme = base.copy(
        primary = animated(base.primary, "primary"),
        onPrimary = animated(base.onPrimary, "onPrimary"),
        primaryContainer = animated(base.primaryContainer, "primaryContainer"),
        background = animated(base.background, "background"),
        onBackground = animated(base.onBackground, "onBackground"),
        surface = animated(base.surface, "surface"),
        onSurface = animated(base.onSurface, "onSurface"),
        surfaceVariant = animated(base.surfaceVariant, "surfaceVariant"),
        onSurfaceVariant = animated(base.onSurfaceVariant, "onSurfaceVariant"),
        outline = animated(base.outline, "outline"),
        outlineVariant = animated(base.outlineVariant, "outlineVariant"),
    )

    MaterialTheme(
        colorScheme = scheme,
        typography = Typography,
        shapes = KeyCaseShapes,
        content = content,
    )
}

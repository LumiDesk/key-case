package top.talyra42.keycase.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import top.talyra42.keycase.core.model.VaultItem

data class LetterSection(
    val letter: String,
    val items: List<VaultItem>,
)

val AlphabetLetters: List<String> = ('A'..'Z').map(Char::toString) + "#"

fun letterOf(title: String): String {
    val first = title.trim().firstOrNull()?.uppercaseChar() ?: '#'
    return if (first in 'A'..'Z') first.toString() else "#"
}

fun sectionsOf(
    items: List<VaultItem>,
    ascending: Boolean = true,
    titleOf: (VaultItem) -> String = { it.title.ifBlank { it.issuer } },
): List<LetterSection> {
    val sorted = items.sortedWith(
        compareBy<VaultItem> { letterOf(titleOf(it)) == "#" }
            .thenBy { titleOf(it).lowercase() },
    )
    val groups = sorted.groupBy { letterOf(titleOf(it)) }
    val letters = groups.keys
        .filter { it != "#" }
        .let { if (ascending) it.sorted() else it.sortedDescending() }
        .let { it + if ("#" in groups) listOf("#") else emptyList() }
    return letters.map { letter ->
        val group = groups.getValue(letter)
        LetterSection(
            letter = letter,
            items = if (ascending) group else group.reversed(),
        )
    }
}

@Composable
fun LetterSectionHeader(letter: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = letter,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(18.dp),
        )
        HorizontalDivider(
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.outlineVariant,
        )
    }
}

@Composable
fun AlphabetIndex(
    letters: List<String>,
    active: String?,
    listState: LazyListState,
    sectionStarts: Map<String, Int>,
    availableLetters: Set<String>,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    var heightPx by remember { mutableIntStateOf(0) }
    var pressedLetter by remember { mutableStateOf<String?>(null) }

    fun letterAt(y: Float): String? {
        if (heightPx <= 0 || letters.isEmpty()) return null
        val index = (y / heightPx * letters.size).toInt().coerceIn(0, letters.lastIndex)
        return letters[index]
    }

    fun jumpTo(letter: String?) {
        if (letter == null || letter !in availableLetters) return
        sectionStarts[letter]?.let { index ->
            scope.launch { listState.scrollToItem(index) }
        }
    }

    Box(
        modifier = modifier
            .onSizeChanged { heightPx = it.height }
            .pointerInput(letters, heightPx, sectionStarts, availableLetters) {
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    var current = letterAt(down.position.y)
                    pressedLetter = current
                    jumpTo(current)
                    down.consume()
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull { it.id == down.id } ?: break
                        if (!change.pressed) break
                        val next = letterAt(change.position.y)
                        if (next != current) {
                            current = next
                            pressedLetter = next
                            jumpTo(next)
                        }
                        change.consume()
                    }
                    pressedLetter = null
                }
            },
        contentAlignment = Alignment.CenterEnd,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            letters.forEach { letter ->
                val available = letter in availableLetters
                Text(
                    text = letter,
                    fontSize = 9.sp,
                    lineHeight = 12.sp,
                    fontWeight = if (letter == active || letter == pressedLetter) {
                        FontWeight.Bold
                    } else {
                        FontWeight.Normal
                    },
                    color = when {
                        letter == pressedLetter || letter == active -> MaterialTheme.colorScheme.primary
                        available -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                        else -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.22f)
                    },
                    modifier = Modifier
                        .width(18.dp)
                        .padding(vertical = 1.dp),
                )
            }
        }
        pressedLetter?.let { letter ->
            Surface(
                modifier = Modifier
                    .align(Alignment.Center)
                    .offset(x = (-48).dp)
                    .size(42.dp),
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
                shadowElevation = 6.dp,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        text = letter,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
    }
}

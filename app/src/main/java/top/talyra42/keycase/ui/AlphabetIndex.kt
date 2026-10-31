package top.talyra42.keycase.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
    val letters = groups.keys.sortedWith(
        compareBy<String> { it == "#" }.thenBy { it },
    )
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
    Column(
        modifier = modifier.padding(end = 2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        letters.forEach { letter ->
            val available = letter in availableLetters
            Text(
                text = letter,
                fontSize = 9.sp,
                lineHeight = 12.sp,
                fontWeight = if (letter == active) FontWeight.Bold else FontWeight.Normal,
                color = when {
                    letter == active -> MaterialTheme.colorScheme.primary
                    available -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                    else -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.22f)
                },
                modifier = Modifier
                    .width(18.dp)
                    .clickable(enabled = available) {
                        sectionStarts[letter]?.let { index ->
                            scope.launch { listState.animateScrollToItem(index) }
                        }
                    }
                    .padding(vertical = 1.dp),
            )
        }
    }
}

package top.talyra42.keycase.ui

import org.junit.Assert.assertEquals
import org.junit.Test
import top.talyra42.keycase.core.model.VaultItem

class AlphabetIndexTest {
    private fun item(title: String) = VaultItem(id = title, title = title)

    @Test
    fun groupsLatinTitlesAndPutsOtherScriptsLast() {
        val sections = sectionsOf(
            listOf(item("GitHub"), item("Airbnb"), item("支付宝"), item("Deno")),
        )

        assertEquals(listOf("A", "D", "G", "#"), sections.map { it.letter })
        assertEquals("Airbnb", sections.first().items.first().title)
    }

    @Test
    fun descendingOrderReversesItemsInsideSection() {
        val sections = sectionsOf(
            listOf(item("Alpha"), item("Aurora")),
            ascending = false,
        )

        assertEquals(listOf("Aurora", "Alpha"), sections.first().items.map { it.title })
    }

    @Test
    fun nonLatinTitleUsesHash() {
        assertEquals("#", letterOf("支付宝"))
        assertEquals("G", letterOf("github"))
    }
}

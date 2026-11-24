package com.aboutpainttools.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.aboutpainttools.core.MangaCoreNative

/**
 * Adaptive Jetpack Compose workspace skeleton for Android Pads and Foldable Phones (v1.1).
 * Switches deterministically across Compact (folded cover), Dual-Pane across vertical hinge,
 * Tabletop (half-open horizontal hinge), and Full Tablet Studio based on `manga-core` layout hints.
 */
@Composable
fun AdaptiveStudioScreen(
    postureCode: Int,
    widthDp: Float,
    heightDp: Float,
    modifier: Modifier = Modifier
) {
    val layoutHint = MangaCoreNative.recommendWorkspaceLayout(
        platformCode = MangaCoreNative.PLATFORM_ANDROID_PAD_FOLDABLE,
        postureCode = postureCode,
        widthDp = widthDp,
        heightDp = heightDp
    )

    Surface(modifier = modifier.fillMaxSize()) {
        when (layoutHint) {
            0 -> { // SinglePaneCompact (folded cover screen)
                Box(modifier = Modifier.fillMaxSize().padding(12.dp), contentAlignment = Alignment.Center) {
                    Text("Compact Studio: Light Novel / Voice Continuity / Quick Sketch")
                }
            }
            2 -> { // DualPaneAcrossHinge (unfolded vertical hinge)
                Row(
                    modifier = Modifier.fillMaxSize().padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    Box(modifier = Modifier.weight(1f).fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Left Pane: Novel Final & Read-Only AI Ref")
                    }
                    Box(modifier = Modifier.weight(1f).fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Right Pane: Vulkan Manga Canvas (S-Pen / M-Pencil)")
                    }
                }
            }
            3 -> { // TabletopCanvasTopControlsBottom (half-open foldable)
                Column(
                    modifier = Modifier.fillMaxSize().padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Box(modifier = Modifier.weight(1f).fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Top Display: Live Manga Canvas / Storyboard Preview")
                    }
                    Box(modifier = Modifier.weight(1f).fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Bottom Display: Touch Tool Deck / Light Novel Keyboard")
                    }
                }
            }
            else -> { // TabletTouchStudio
                Box(modifier = Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                    Text("Android Pad Touch Studio (Vulkan FrontBuffer + 5-Language UI)")
                }
            }
        }
    }
}

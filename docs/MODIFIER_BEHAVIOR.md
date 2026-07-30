# Modifier Key Behavior

Mac Smooth Scroll reads modifier keys from the first physical wheel event in a
burst. That assignment remains frozen until the burst ends, so releasing or
pressing a key cannot change an already-animating scroll tail.

## Priority rules

1. **Horizontal scrolling** converts vertical-dominant wheel input to the
   horizontal axis. It can combine with Faster or Precision.
2. **Precision scrolling** wins when Precision and Faster are both active,
   including when both actions use the same key.
3. **Faster scrolling** applies when its key is active and Precision is not.
4. **Zoom** is forwarded only when Horizontal, Faster, and Precision are all
   inactive. Other modifier flags are not forwarded.

Horizontal is considered active only when it actually converts
vertical-dominant input. If the physical input is already horizontal-dominant,
an overlapping Zoom assignment can still be forwarded.

## Shared assignments

| Assignments using the same key | Result |
| --- | --- |
| Horizontal + Precision | Horizontal conversion with precision speed |
| Horizontal + Faster | Horizontal conversion with faster speed |
| Horizontal + Zoom | Horizontal when conversion applies; otherwise Zoom |
| Precision + Faster | Precision |
| Precision + Zoom | Precision |
| Faster + Zoom | Faster |

Zoom relies on the foreground application supporting modifier-scroll zoom.
Mac Smooth Scroll does not install a global keyboard hook or implement its own
application-specific zoom command.

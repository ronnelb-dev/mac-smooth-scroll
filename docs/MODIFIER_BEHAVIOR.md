# Modifier Key Behavior

Mac Smooth Scroll reads transform modifier keys from the first physical wheel
event in a burst. Those assignments remain frozen until the burst ends, so
releasing or pressing a transform key cannot change an already-animating scroll
tail. Bypass is the exception: it is evaluated for every physical wheel event
so it can stop a tail immediately.

## Priority rules

1. **Bypass smooth scrolling** immediately stops the current animated tail and
   sends the physical wheel event to the foreground application unchanged.
2. **Horizontal scrolling** converts vertical-dominant wheel input to the
   horizontal axis. It can combine with Faster or Precision.
3. **Precision scrolling** wins when Precision and Faster are both active,
   including when both actions use the same key.
4. **Faster scrolling** applies when its key is active and Precision is not.
5. **Zoom** is forwarded only when Horizontal, Faster, and Precision are all
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
| Bypass + any assignment | Native wheel event; no transformation |

Zoom relies on the foreground application supporting modifier-scroll zoom.
Mac Smooth Scroll does not install a global keyboard hook or implement its own
application-specific zoom command. Bypass is evaluated on each physical wheel
event.

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
5. **Zoom** generates the selected Pinch-style or Page zoom action only when
   Horizontal, Faster, and Precision are all inactive. Other modifier flags
   are not forwarded.

Horizontal is considered active only when it actually converts
vertical-dominant input. If the physical input is already horizontal-dominant,
an overlapping Zoom assignment can still be activated.

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

Pinch-style Zoom generates magnification begin/change/end events and adds an
initial responsiveness adjustment for Chrome and related Chromium browsers.
Page zoom sends Command-plus or Command-minus to the frontmost app, with no
inertial tail and a maximum of ten steps per second. The receiving application
must support the selected behavior. Bypass is evaluated on each physical wheel
event.

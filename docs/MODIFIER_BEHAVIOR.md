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

The **Assignment Guidance** section in Settings updates immediately when two or
more actions share a modifier. It labels compatible combinations separately
from priority rules and states the resulting behavior in text, so the meaning
does not depend on color. Assignments remain unchanged until the user edits a
picker.

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
The app validates that native magnification events can be constructed before
using this path; when they are unavailable, Pinch-style falls back to Page
zoom instead of consuming the wheel input.

Page zoom resolves the virtual keys and required Shift/Option flags that
produce `+` and `-` in the active macOS keyboard layout. It also attaches the
matching Unicode character to each synthetic event, then uses a U.S. ANSI
fallback only when the current layout cannot resolve one of those characters.
Commands have no inertial tail and are capped at ten steps per second. The
receiving application must support the selected behavior. Bypass is evaluated
on each physical wheel event.

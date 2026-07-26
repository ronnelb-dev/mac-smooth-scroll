# Mac Smooth Scroll Roadmap

This roadmap keeps reliability, privacy, and predictable macOS behavior ahead
of feature breadth. GitHub issues are the source of truth for implementation
details and status.

## Current milestone: v0.3.0 — Reliability and compatibility

[View the v0.3.0 milestone on GitHub](https://github.com/ronnelb-dev/mac-smooth-scroll/milestone/1)

The goal of v0.3.0 is to make source and preview builds easier to verify,
diagnose, and test across supported Apple Silicon Macs.

- [#7 — Create a repeatable manual macOS regression checklist](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/7)
- [#8 — Improve event-tap diagnostics and recovery feedback](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/8)
- [#9 — Expand tests for event filtering and gesture-phase lifecycle](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/9)
- [#10 — Define modifier conflicts and zoom behavior](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/10)
- [#11 — Document an Apple Silicon compatibility matrix](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/11)

No target date is assigned. The milestone is complete when its behavior,
automated coverage, manual QA, and documentation are ready—not when a calendar
deadline arrives.

## Future backlog

These ideas are intentionally outside the v0.3.0 reliability scope:

- [#12 — Add per-app scrolling profiles](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/12)
- [#13 — Add per-mouse settings](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/13)
- [#14 — Publish a notarized public binary](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/14)

Issue #14 is blocked until the project has a personal Apple Developer Program
membership and Developer ID Application certificate. Work-team credentials
must not be used for this personal project. Until then, downloadable builds
remain clearly labeled, unnotarized previews rather than production releases.

## Completed foundation

- Native arm64 SwiftUI/AppKit application and embedded login helper
- Accessibility onboarding and external-wheel event transformation
- Menu-bar-only mode and background launch at login
- GPL-3.0 license
- Protected `main` branch and required Apple Silicon CI
- Ad-hoc local signing with explicit opt-in for certificate signing
- Preview DMG packaging with mounted-content and SHA-256 verification
- Contributor, security, privacy, troubleshooting, and issue templates
- XCTest coverage for launch parsing, settings persistence, scroll-input
  transformation, and motion physics

## Current non-goals

- Intel Mac support
- Publishing an unnotarized production binary
- Using private macOS APIs
- Collecting analytics, telemetry, or raw input history
- Adding per-app or per-mouse profiles to v0.3.0

## Proposing changes

Open a
[feature request](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/new?template=feature_request.yml)
for new roadmap ideas. Large changes should be discussed before implementation
and should preserve the project's local-only privacy model.

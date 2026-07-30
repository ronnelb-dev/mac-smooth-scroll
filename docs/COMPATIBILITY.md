# Compatibility Matrix

- Matrix version: **1**
- Last updated: **2026-07-30**
- Runtime baseline: **Mac Smooth Scroll 0.4.0 (6)** at commit [`c70d2ed`](https://github.com/ronnelb-dev/mac-smooth-scroll/commit/c70d2edf6bb7c2948dabf06794a0d6b73d1cfb4f)

Mac Smooth Scroll supports Apple Silicon and has a deployment target of macOS
13 or later. A supported target is not automatically a verified hardware
combination.

Apple's [macOS version list](https://support.apple.com/en-us/109033) identifies
Ventura 13, Sonoma 14, Sequoia 15, and Tahoe 26 as the supported major-version
sequence covered here. Apple also identifies
[Tahoe 26 as the latest macOS generation](https://support.apple.com/en-us/122867).

## Status definitions

| Status | Meaning |
| --- | --- |
| **Manual verified** | The relevant physical-input checklist passed on the recorded hardware and commit. |
| **Build verified** | XCTest, arm64 build, packaging, and release validation passed, but physical input was not tested. |
| **Failed** | A reproducible compatibility problem has a focused linked GitHub issue. |
| **Untested** | No acceptable evidence has been submitted. |

Unit tests and successful packaging do not prove wheel feel, device
classification, native pass-through, Accessibility behavior, or login-session
behavior on a specific Mac.

## Current automated evidence

| Date | macOS | Apple Silicon | App commit | Evidence | Status |
| --- | --- | --- | --- | --- | --- |
| 2026-07-30 | macOS 15, GitHub-hosted runner | arm64; generation not reported | `c70d2ed` | [Apple Silicon CI run 30540381466](https://github.com/ronnelb-dev/mac-smooth-scroll/actions/runs/30540381466): 81 tests, app/DMG build, preview validation | **Build verified** |
| 2026-07-30 | macOS 26.5.1 (25F80) | M4 | `c70d2ed` | Local `swift test --arch arm64`, app/DMG build, nested signature validation, checksum, and mounted-DMG validation | **Build verified** |

The GitHub-hosted runner confirms arm64 with `uname -m`, but GitHub does not
provide an M-series generation to this workflow. It is therefore not evidence
for an M1, M2, M3, M4, or later hardware row.

## macOS matrix

| macOS | Automated build/package | External-wheel behavior | Trackpad/Magic Mouse pass-through | Overall |
| --- | --- | --- | --- | --- |
| Ventura 13 | Untested | Untested | Untested | **Untested** |
| Sonoma 14 | Untested | Untested | Untested | **Untested** |
| Sequoia 15 | Verified on hosted arm64 runner | Untested | Untested | **Build verified** |
| Tahoe 26 | Verified locally on 26.5.1/M4 | Untested | Untested | **Build verified** |

## Apple Silicon matrix

| Generation | Automated build/package | Physical scrolling | Latest evidence | Overall |
| --- | --- | --- | --- | --- |
| M1 | Untested | Untested | None | **Untested** |
| M2 | Untested | Untested | None | **Untested** |
| M3 | Untested | Untested | None | **Untested** |
| M4 | Verified on macOS 26.5.1 | Untested | 2026-07-30, `c70d2ed` | **Build verified** |
| M5 or later | Untested | Untested | None | **Untested** |

## Input-device matrix

| Input category | Required behavior | Manual evidence | Status |
| --- | --- | --- | --- |
| Standard notched external wheel | Discrete input is transformed once into smooth pixel scrolling. | None | **Untested** |
| Free-spinning external wheel | Discrete wheel input remains responsive without duplicate or runaway motion. | None | **Untested** |
| Built-in or external trackpad | Continuous native scrolling passes through unchanged. | None | **Untested** |
| Magic Mouse | Continuous native scrolling passes through unchanged. | None | **Untested** |
| Horizontal-capable external wheel | Dominant-axis and horizontal-modifier behavior remain predictable. | None | **Untested** |

XCTest covers the discrete/continuous/synthetic classification decisions, but
those tests do not identify a real device or exercise its driver.

## Display matrix

| Refresh rate | Automated motion integration | Physical animation review | Status |
| --- | --- | --- | --- |
| 60 Hz | Covered by deterministic motion tests | Untested | **Untested** |
| 120 Hz | Covered by deterministic motion tests | Untested | **Untested** |
| 144 Hz | Covered by deterministic motion tests | Untested | **Untested** |
| Other | Untested | Untested | **Untested** |

## Mouse-utility coexistence

| Utility | Expected behavior | Manual evidence | Status |
| --- | --- | --- | --- |
| None | Mac Smooth Scroll owns discrete-wheel transformation. | None | **Untested** |
| Mac Mouse Fix | Mac Smooth Scroll detects the app/helper, pauses, and resumes after it quits. | None | **Untested** |
| Logitech Options or Options+ | No automatic detection; record duplication, distortion, or blocking. | None | **Untested** |
| LinearMouse | No automatic detection; record duplication, distortion, or blocking. | None | **Untested** |
| SteerMouse | No automatic detection; record duplication, distortion, or blocking. | None | **Untested** |
| Other | Record the exact utility and version. | None | **Untested** |

## Manual verification records

No complete physical-device result has been submitted yet. Add one row per
tested combination; do not replace an older row when the app commit, macOS,
Mac generation, or mouse changes.

| Date | App commit | macOS | Apple Silicon | Mouse/input | Wheel | Display | Utilities | Checklist scope | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| — | — | — | — | — | — | — | — | — | **Untested** |

## Compatibility failures

Keep investigations in focused GitHub issues rather than expanding this file
with logs or debugging transcripts.

| Combination | Symptom | Issue | Status |
| --- | --- | --- | --- |
| None recorded | — | — | — |

When a test fails:

1. Open a focused [bug report](https://github.com/ronnelb-dev/mac-smooth-scroll/issues/new?template=bug_report.yml).
2. Include the app commit, macOS version/build, Apple Silicon generation,
   mouse model, wheel type, display refresh rate, other mouse utilities, and
   the smallest reliable reproduction.
3. Link the issue from the failures table.
4. Mark the affected matrix cells **Failed**; do not mark an entire generation
   failed when the evidence applies only to one mouse or macOS combination.

## Submitting a successful result

Open a focused pull request that adds one manual verification row and updates
only the cells supported by that row. Include:

- Test date
- Full app commit
- App version and build
- macOS version and build
- M-series generation
- Mouse or native-input model
- Notched, free-spinning, or continuous input type
- Display refresh rate
- Other running mouse utilities
- Checklist sections run
- Pass, Fail, Blocked, or Not run result

Do not include usernames, computer names, serial numbers, hardware UUIDs,
device identifiers, certificates, private keys, Accessibility database
exports, raw mouse activity, or unrelated filesystem paths.

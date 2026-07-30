## Summary

<!-- What does this change? -->

## Why

<!-- What problem does it solve? Link related issues with "Closes #123" when appropriate. -->

## Testing

<!-- List automated checks. For behavior changes, include the compact result
template from docs/MANUAL_REGRESSION_CHECKLIST.md. -->

## Screenshots

<!-- Include before/after screenshots for visible interface changes, or write "Not applicable." -->

## Checklist

- [ ] The production arm64 build succeeds.
- [ ] Apple Silicon CI passes.
- [ ] The main app and login helper remain ad-hoc signed unless an identity was explicitly supplied.
- [ ] User-facing behavior and documentation are updated where necessary.
- [ ] No binaries, certificates, private keys, credentials, or personal information are included.
- [ ] The change is compatible with GPL-3.0.

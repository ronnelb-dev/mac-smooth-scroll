# Contributing to Mac Smooth Scroll

Thanks for your interest in improving Mac Smooth Scroll.

## Before starting

- Search existing issues and pull requests for related work.
- Open a feature request before investing in a large behavioral or interface change.
- Report security vulnerabilities privately according to [SECURITY.md](SECURITY.md).
- Keep changes focused and avoid unrelated formatting or refactoring.

## Development requirements

- Apple Silicon Mac
- macOS 13 or later
- Xcode command-line tools

Build the production app bundle with:

```sh
./Scripts/build-app.sh
```

The script signs local builds ad-hoc by default. Do not use an employer,
organization, or distribution certificate unless you own it and explicitly
intend to use it for this project.

## Before opening a pull request

Run:

```sh
swift test --arch arm64
swift build -c release --arch arm64
zsh -n Scripts/build-app.sh
plutil -lint Resources/Info.plist Resources/Launcher-Info.plist
git diff --check
./Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Mac Smooth Scroll.app"
```

For behavior changes, run the relevant sections of the
[manual macOS regression checklist](docs/MANUAL_REGRESSION_CHECKLIST.md) and
paste its compact result template into the pull request. Mark unavailable
hardware and third-party utilities **Not run** rather than treating them as
passing.

## Pull requests

- Create a focused branch from `main`.
- Use clear commit messages.
- Complete the pull-request template.
- Keep Apple Silicon CI green.
- Add or update documentation when behavior changes.
- Do not include generated `.build` or `dist` contents.
- Do not commit certificates, private keys, provisioning profiles, notarization
  credentials, crash reports with personal data, or other secrets.

## License

By contributing, you agree that your contributions will be licensed under the
[GNU General Public License v3.0](LICENSE).

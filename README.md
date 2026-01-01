# Browser

Flutter desktop web browser with tabs, bookmarks, history.

## Install

```bash
git clone https://github.com/bniladridas/browser.git
cd browser
flutter pub get
flutter run
```

## Use

Enter URLs. Navigate via buttons or shortcuts: `Cmd+L` focus, `Cmd+R` refresh, `Alt+Left/Right` back/forward.

## Develop

Requires Flutter >=3.0.0.

Run `./check.sh` for checks.

Build: `flutter build macos`.

### Generated Files

This project uses `.gitattributes` to mark generated files (e.g., from `freezed`, `build_runner`) as `linguist-generated`. This hides them from GitHub diffs and language statistics, keeping pull requests focused on hand-written code.

Common generated paths include:
- `build/**` and `.dart_tool/**` (Flutter build artifacts)
- `lib/**/*.freezed.dart` and `lib/**/*.g.dart` (code-generated Dart files)
- Platform-specific directories like `android/**`, `ios/**`

To unmark a specific file, add `-linguist-generated` in `.gitattributes`.

## Contribute

Fork, branch, edit, run `./check.sh`, commit, PR with labels for version bump.

## License

MIT.

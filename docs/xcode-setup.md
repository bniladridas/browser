# Xcode Setup

## Accepting Xcode License

After installing Xcode, you must accept the license agreement:

```bash
sudo xcodebuild -license
```

Scroll to the bottom and type `agree` to accept.

## Switching to Xcode (if using Command Line Tools)

If you have both Xcode and Command Line Tools installed, you may need to switch:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Verify with:
```bash
xcodebuild -version
```

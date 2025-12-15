# Troubleshooting

## macOS Flutter Run Issues

If `flutter run` fails with "unable to find utility 'xcodebuild'", even if command line tools are installed:

1. Ensure full Xcode is installed from the App Store.
2. Switch xcode-select to point to Xcode:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
3. Accept the Xcode license:
   ```bash
   sudo xcodebuild -license accept
   ```
4. Try `flutter run` again.
# Browser

[![CI](https://github.com/bniladridas/browser/workflows/Flutter%20CI/badge.svg)](https://github.com/bniladridas/browser/actions)

A simple Flutter desktop application that provides a URL launcher interface.

## Installation

```bash
git clone https://github.com/bniladridas/browser.git
cd browser
flutter pub get
flutter run
```

## Usage

Launch the application and enter a URL in the text field at the top. Press Enter to open the URL in your system's default web browser.

The app automatically prepends `https://` if the URL does not start with `http://` or `https://`.

<!-- prettier-ignore -->
```dart
// Example usage in code
void _loadUrl(String url) async {
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}
```

## Features

- Simple URL input interface
- Automatic protocol detection and addition
- Error handling with snackbar notifications
- Window focus on startup
- Cross-platform desktop support (macOS, Windows, Linux)

## Development

### Prerequisites

- Flutter SDK >=3.0.0
- Dart SDK >=3.0.0

### Running Checks

Run `./check.sh` to lint, test, and build the project.

```bash
./check.sh
```

### Building

To build for macOS:

```bash
flutter build macos
```

### CI/CD

This project uses GitHub Actions for continuous integration. The workflow:

- Runs on macOS
- Installs latest stable Flutter
- Executes `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build macos`
- Triggers on pushes and pull requests to main and master branches

## Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Make your changes.
4. Run `./check.sh` to ensure code quality.
5. Commit your changes (`git commit -m 'Add some amazing feature'`).
6. Push to the branch (`git push origin feature/amazing-feature`).
7. Open a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

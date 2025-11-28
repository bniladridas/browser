# Browser with Terminal

A Flutter application that provides a simple URL launcher and a basic Linux terminal emulator.

## Features

- **Browser Tab**: Enter URLs to launch in your system's default browser.
- **Terminal Tab**: Emulate a Linux terminal with support for basic commands like `cd`, `pwd`, `ls`, and execution of system commands.

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/bniladridas/browser.git
   cd browser
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Usage

- Switch between Browser and Terminal tabs using the bottom navigation.
- In Browser tab, enter a URL and press Enter to open it.
- In Terminal tab, type commands and press Enter. Supports `cd`, `pwd`, `ls`, and other executables.

## Development

Run `./check.sh` to lint, test, and build the project.

### CI/CD

This project uses GitHub Actions for continuous integration. The workflow runs on macOS, installs Flutter, and executes linting, tests, and builds on pushes and pull requests to the main branch.

## Contributing

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Run `./check.sh` to ensure quality.
5. Submit a pull request.

## License

This project is licensed under the MIT License.

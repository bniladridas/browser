import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  late final Terminal terminal;
  late final String currentDir;
  String inputBuffer = '';

  @override
  void initState() {
    super.initState();
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/';
    currentDir = home;
    terminal = Terminal();
    terminal.onOutput = _handleOutput;
    terminal.write('Welcome to Linux Terminal Emulator\r\n');
    _printPrompt();
  }

  void _printPrompt() {
    terminal.write('$currentDir \$ ');
  }

  void _handleOutput(String output) {
    inputBuffer += output;
    if (inputBuffer.contains('\r') || inputBuffer.contains('\n')) {
      final lines = inputBuffer.split(RegExp(r'[\r\n]+'));
      for (final line in lines) {
        if (line.isNotEmpty) {
          _processCommand(line.trim());
        }
      }
      inputBuffer = '';
    }
  }

  void _processCommand(String command) {
    if (command.isEmpty) {
      _printPrompt();
      return;
    }

    final parts = command.split(' ');
    final cmd = parts[0];
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    switch (cmd) {
      case 'cd':
        _handleCd(args);
        break;
      case 'pwd':
        terminal.write('$currentDir\r\n');
        _printPrompt();
        break;
      case 'ls':
        _handleLs(args);
        break;
      default:
        _runCommand(cmd, args);
        break;
    }
  }

  void _handleCd(List<String> args) {
    if (args.isEmpty) {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        currentDir = home;
      }
    } else {
      final newDir = args[0];
      final fullPath = newDir.startsWith('/') ? newDir : '$currentDir/$newDir';
      if (Directory(fullPath).existsSync()) {
        currentDir = fullPath;
      } else {
        terminal.write('cd: $newDir: No such file or directory\r\n');
      }
    }
    _printPrompt();
  }

  void _handleLs(List<String> args) {
    try {
      final dir = Directory(currentDir);
      final entities = dir.listSync();
      for (final entity in entities) {
        final name = entity.path.split('/').last;
        terminal.write('$name\r\n');
      }
    } catch (e) {
      terminal.write('ls: $e\r\n');
    }
    _printPrompt();
  }

  void _runCommand(String cmd, List<String> args) async {
    try {
      final result = await Process.run(cmd, args, workingDirectory: currentDir);
      if (result.stdout.isNotEmpty) {
        terminal.write('${result.stdout}'.replaceAll('\n', '\r\n'));
      }
      if (result.stderr.isNotEmpty) {
        terminal.write('${result.stderr}'.replaceAll('\n', '\r\n'));
      }
    } on ProcessException catch (e) {
      terminal.write('Error: ${e.message}\r\n');
    } catch (e) {
      terminal.write('Error: $e\r\n');
    }
    _printPrompt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linux Terminal'),
      ),
      body: TerminalView(terminal),
    );
  }
}

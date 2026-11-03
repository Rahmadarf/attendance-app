import 'dart:async';

import 'package:flutter/material.dart';

/// Full-screen confirmation that closes itself, so the next person can step up.
class ResultScreen extends StatefulWidget {
  final String name;
  final String message;
  final bool ok;
  final Duration autoClose;

  const ResultScreen({
    super.key,
    required this.name,
    required this.message,
    this.ok = true,
    this.autoClose = const Duration(seconds: 4),
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Timer? _timer;

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.autoClose, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.ok ? Colors.green : Theme.of(context).colorScheme.error;
    return Scaffold(
      body: InkWell(
        onTap: _close,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.ok ? Icons.check_circle : Icons.info,
                    size: 96, color: color),
                const SizedBox(height: 16),
                if (widget.name.isNotEmpty)
                  Text(widget.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(widget.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: color)),
                const SizedBox(height: 24),
                Text('Ketuk untuk menutup',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

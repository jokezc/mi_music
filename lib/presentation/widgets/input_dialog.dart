import 'package:flutter/material.dart';
import 'package:mi_music/core/constants/strings_zh.dart';

class InputDialog extends StatefulWidget {
  final String title;
  final String? initialValue;
  final String labelText;
  final String confirmText;
  final String cancelText;

  const InputDialog({
    super.key,
    required this.title,
    this.initialValue,
    required this.labelText,
    this.confirmText = S.confirm,
    this.cancelText = S.cancel,
  });

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.labelText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelText),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.pop(context, text);
            }
          },
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

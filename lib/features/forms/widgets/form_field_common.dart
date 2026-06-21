import 'package:flutter/material.dart';

/// A question label with an optional red required-asterisk.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, required this.required});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
              ]
            : null,
      ),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}

/// Inline validation error shown beneath a field.
class FieldError extends StatelessWidget {
  const FieldError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
      ),
    );
  }
}

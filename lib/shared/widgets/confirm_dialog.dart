import 'package:flutter/material.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'OK',
  String cancelLabel = 'Avbryt',
  Color? okColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: okColor != null
              ? FilledButton.styleFrom(backgroundColor: okColor)
              : null,
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

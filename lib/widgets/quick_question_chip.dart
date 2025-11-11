import 'package:flutter/material.dart';

class QuickQuestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const QuickQuestionChip({
    Key? key,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return ActionChip(
      label: Text(text),
      onPressed: onTap,
      backgroundColor: isDarkMode
          ? const Color(0xFF2C2C2C)
          : Colors.red[50],
      labelStyle: TextStyle(
        color: isDarkMode ? Colors.red[300] : Colors.red[700],
      ),
    );
  }
}

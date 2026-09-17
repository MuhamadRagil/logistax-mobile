import 'package:flutter/material.dart';

/// Tombol utama dengan loading state.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outlined;
  final Color? color;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    if (outlined) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: color != null
            ? OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color!))
            : null,
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: color != null ? ElevatedButton.styleFrom(backgroundColor: color) : null,
      child: child,
    );
  }
}

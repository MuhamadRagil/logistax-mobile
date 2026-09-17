import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final Widget? suffix;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.suffix,
    this.prefixIcon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          enabled: enabled,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class ArenaTextField extends StatefulWidget {
  const ArenaTextField({
    super.key,
    required this.label,
    this.hint,
    this.value,
    this.controller,
    this.maxLines = 1,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
  }) : assert(
          value == null || controller == null,
          'Provide either value or controller, not both',
        );

  final String label;
  final String? hint;
  final String? value;
  final TextEditingController? controller;
  final int maxLines;
  final bool obscureText;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  @override
  State<ArenaTextField> createState() => _ArenaTextFieldState();
}

class _ArenaTextFieldState extends State<ArenaTextField> {
  late final TextEditingController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.value ?? '');
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(ArenaTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external value changes only if we own the controller
    if (_ownsController &&
        widget.value != null &&
        widget.value != _controller.text) {
      _controller.text = widget.value!;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: widget.maxLines,
      obscureText: widget.obscureText,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
    );
  }
}

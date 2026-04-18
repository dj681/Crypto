import 'package:flutter/material.dart';

/// A numerical PIN entry pad that emits a complete PIN string.
/// [pinLength] defaults to 6.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    this.pinLength = 6,
    required this.onCompleted,
    this.errorMessage,
  });

  final int pinLength;

  /// Called when the user has entered [pinLength] digits.
  final ValueChanged<String> onCompleted;

  /// When non-null, displayed as an error below the dots.
  final String? errorMessage;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _onDigit(String digit) {
    if (_pin.length >= widget.pinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == widget.pinLength) {
      widget.onCompleted(_pin);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  /// Clears the entered PIN (called externally after a failed attempt).
  void reset() => setState(() => _pin = '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.pinLength,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
        if (widget.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Digit grid
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map(
              (d) => _DigitButton(
                label: '$d',
                onPressed: () => _onDigit('$d'),
              ),
            ),
            const SizedBox.shrink(), // placeholder
            _DigitButton(label: '0', onPressed: () => _onDigit('0')),
            IconButton(
              onPressed: _onDelete,
              icon: const Icon(Icons.backspace_outlined),
              tooltip: 'Effacer',
            ),
          ],
        ),
      ],
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

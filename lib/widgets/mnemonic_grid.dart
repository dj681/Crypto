import 'package:flutter/material.dart';

/// Displays a BIP-39 mnemonic phrase as a numbered word grid.
class MnemonicGrid extends StatelessWidget {
  const MnemonicGrid({
    super.key,
    required this.mnemonic,
    this.obscured = false,
  });

  final String mnemonic;

  /// When true the words are hidden (used during confirmation step).
  final bool obscured;

  @override
  Widget build(BuildContext context) {
    final words = mnemonic.trim().split(RegExp(r'\s+'));
    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                '${index + 1}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  obscured ? '•••' : words[index],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: obscured ? 2 : 0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

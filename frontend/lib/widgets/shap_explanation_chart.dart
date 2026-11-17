import 'package:flutter/material.dart';

class ShapExplanationChart extends StatelessWidget {
  final Map<String, double> shapValues;

  const ShapExplanationChart({super.key, required this.shapValues});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entries = shapValues.entries.toList();

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Explanation details are not available yet.'),
      );
    }

    final maxValue = entries
        .map((entry) => entry.value.abs())
        .reduce((a, b) => a > b ? a : b);

    final scale = maxValue == 0 ? 1.0 : maxValue;

    final positiveColor = theme.brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade700;

    final negativeColor = theme.brightness == Brightness.dark
        ? Colors.red.shade300
        : Colors.red.shade700;

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why this caregiver was chosen',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'These factors show what made this caregiver a stronger '
              'or weaker match for your care needs.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            ...entries.map((entry) {
              final value = entry.value;
              final isPositive = value >= 0;
              final fraction = value.abs() / scale;
              final barColor = isPositive ? positiveColor : negativeColor;

              return Padding(
                padding: const EdgeInsets.only(bottom: 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 7),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final halfWidth = constraints.maxWidth / 2;
                        final barWidth = halfWidth * fraction;

                        return SizedBox(
                          height: 17,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: halfWidth,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 1.5,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              if (isPositive)
                                Positioned(
                                  left: halfWidth,
                                  top: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: barWidth,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  left: halfWidth - barWidth,
                                  top: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: barWidth,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        bottomLeft: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPositive ? 'Supports the match' : 'Reduces the match',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: barColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 2),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, color: positiveColor, size: 10),
                const SizedBox(width: 5),
                Text('Supports the match', style: theme.textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(Icons.circle, color: negativeColor, size: 10),
                const SizedBox(width: 5),
                Text('Reduces the match', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/responsive/breakpoints.dart';

class DesktopOrdersGrid extends ConsumerWidget {
  const DesktopOrdersGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.header,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = context.screenWidth >= 1500 ? 3 : 2;
    final rows = (itemCount + columns - 1) ~/ columns;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: desktopContentMaxWidth),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows + (header == null ? 0 : 1),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (header != null && index == 0) return header!;
            final first = (index - (header == null ? 0 : 1)) * columns;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                for (var column = 0; column < columns; column++)
                  Expanded(
                    child: first + column < itemCount
                        ? itemBuilder(context, first + column)
                        : const SizedBox.shrink(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../shared/responsive/breakpoints.dart';

class AdminContentLayout extends StatelessWidget {
  const AdminContentLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.isDesktop) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: child,
      ),
    );
  }
}

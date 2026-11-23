import 'package:flutter/material.dart';

import '../../../shared/responsive/breakpoints.dart';

class ProfileLayout extends StatelessWidget {
  const ProfileLayout({
    super.key,
    required this.avatar,
    required this.settings,
  });

  final List<Widget> avatar;
  final List<Widget> settings;

  @override
  Widget build(BuildContext context) {
    final desktop = context.isDesktop;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: desktop ? desktopContentMaxWidth : 640,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: desktop
              ? [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 360,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: avatar,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: settings,
                        ),
                      ),
                    ],
                  ),
                ]
              : [...avatar, const SizedBox(height: 16), ...settings],
        ),
      ),
    );
  }
}

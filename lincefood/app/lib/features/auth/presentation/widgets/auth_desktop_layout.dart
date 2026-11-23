import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/responsive/breakpoints.dart';

class AuthDesktopLayout extends ConsumerWidget {
  const AuthDesktopLayout({required this.form, super.key});

  final Widget form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: desktopContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xffffe59a),
                        Color(0xffffad71),
                        Color(0xffffa4ae),
                      ],
                    ),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/mojarra/mojarra_sola.png',
                            height: 220,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Lincefood',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xff492519),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tu cafetería, a un antojo de distancia.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: const Color(0xff492519)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Card(margin: EdgeInsets.zero, child: form),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

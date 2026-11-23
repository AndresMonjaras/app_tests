import 'package:flutter/widgets.dart';

/// Anchos (en dp) a partir de los cuales la interfaz cambia de distribucion.
/// Movil: menos de 768. Tableta: 768 a 1023. Escritorio: 1024 o mas.
const double tabletBreakpoint = 768;
const double desktopBreakpoint = 1024;

/// Ancho maximo del contenido en escritorio para que no se estire en
/// monitores muy grandes.
const double desktopContentMaxWidth = 1280;

bool isDesktopWidth(double width) => width >= desktopBreakpoint;

bool isTabletOrWiderWidth(double width) => width >= tabletBreakpoint;

/// Atajos que leen el ancho de la ventana actual.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isDesktop => isDesktopWidth(screenWidth);
  bool get isTabletOrWider => isTabletOrWiderWidth(screenWidth);
}

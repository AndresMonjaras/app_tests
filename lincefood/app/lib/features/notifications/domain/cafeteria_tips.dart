/// Consejos iniciales de la cafetería. Los ids son estables: sirven para
/// recordar qué consejos ya eliminó cada usuario.
class CafeteriaTip {
  const CafeteriaTip({required this.id, required this.text});

  final String id;
  final String text;
}

const cafeteriaTips = <CafeteriaTip>[
  CafeteriaTip(
    id: 'tip_receso',
    text: 'Realiza tu pedido antes del receso para evitar filas.',
  ),
  CafeteriaTip(
    id: 'tip_listo',
    text: 'Recoge tus alimentos cuando recibas el aviso de pedido listo.',
  ),
  CafeteriaTip(
    id: 'tip_qr',
    text: 'Ten preparado tu código QR antes de llegar a la cafetería.',
  ),
  CafeteriaTip(
    id: 'tip_menu',
    text: 'Consulta el menú para conocer los platillos disponibles.',
  ),
  CafeteriaTip(
    id: 'tip_revision',
    text: 'Revisa tu pedido antes de confirmar el pago.',
  ),
];

/// Quita los consejos que el usuario ya eliminó, manteniendo el orden original.
List<CafeteriaTip> visibleCafeteriaTips(Set<String> dismissedIds) {
  return [
    for (final tip in cafeteriaTips)
      if (!dismissedIds.contains(tip.id)) tip,
  ];
}

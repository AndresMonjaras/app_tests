enum PickupMode {
  inStore('in_store', 'Recoger en cafetería'),
  takeAway('take_away', 'Para llevar');

  const PickupMode(this.code, this.label);

  final String code;
  final String label;

  static PickupMode fromCode(Object? value) {
    for (final mode in PickupMode.values) {
      if (mode.code == value) return mode;
    }
    return PickupMode.inStore;
  }
}

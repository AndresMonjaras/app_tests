class OnboardingStep {
  const OnboardingStep({required this.title, required this.description});

  final String title;
  final String description;

  static const steps = [
    OnboardingStep(
      title: 'Pide antes de tu descanso',
      description: 'Elige tus alimentos con anticipación.',
    ),
    OnboardingStep(
      title: 'Paga de forma segura',
      description: 'Confirma tu pedido con un pago protegido.',
    ),
    OnboardingStep(
      title: 'Recoge cuando este listo',
      description: 'Te avisaremos cuando puedas pasar por tu pedido.',
    ),
  ];
}

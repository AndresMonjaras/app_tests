import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../payments/domain/payment_gateway.dart';
import '../../payments/presentation/payment_dependencies.dart';
import '../domain/service_plan.dart';

final createMembershipPaymentProvider =
    Provider<
      Future<({String clientSecret, String intentId})> Function(
        String,
        MembershipPeriod,
      )
    >((ref) {
      return (planId, period) async {
        final result =
            await FirebaseFunctions.instanceFor(region: 'us-central1')
                .httpsCallable('createMembershipPaymentIntent')
                .call({'planId': planId, 'period': period.name});
        final data = result.data;
        if (data is Map) {
          final secret = data['clientSecret'];
          final id = data['paymentIntentId'];
          if (secret is String &&
              secret.isNotEmpty &&
              id is String &&
              id.isNotEmpty) {
            return (clientSecret: secret, intentId: id);
          }
        }
        throw StateError('No se pudo iniciar el pago.');
      };
    });

final membershipCheckoutProvider =
    NotifierProvider.autoDispose<MembershipCheckout, MembershipCheckoutState>(
      MembershipCheckout.new,
    );

class MembershipCheckoutState {
  const MembershipCheckoutState({
    this.period = MembershipPeriod.monthly,
    this.busy = false,
    this.intentId,
    this.message,
  });

  final MembershipPeriod period;
  final bool busy;
  final String? intentId;
  final String? message;
}

class MembershipCheckout extends Notifier<MembershipCheckoutState> {
  @override
  MembershipCheckoutState build() => const MembershipCheckoutState();

  void selectPeriod(MembershipPeriod period) {
    if (state.busy) return;
    state = MembershipCheckoutState(period: period, intentId: state.intentId);
  }

  Future<void> pay(String planId) async {
    if (state.busy || !ref.read(paymentConfiguredProvider)) return;
    final period = state.period;
    state = MembershipCheckoutState(period: period, busy: true);
    try {
      final gateway = ref.read(paymentGatewayProvider);
      final payment = await ref.read(createMembershipPaymentProvider)(
        planId,
        period,
      );
      if (!ref.mounted) return;
      await gateway.presentPaymentSheet(payment.clientSecret);
      if (!ref.mounted) return;
      state = MembershipCheckoutState(
        period: period,
        intentId: payment.intentId,
      );
    } on PaymentCancelledException {
      if (!ref.mounted) return;
      state = MembershipCheckoutState(
        period: period,
        message: 'Pago cancelado.',
      );
    } on PaymentConfigurationException {
      if (!ref.mounted) return;
      state = MembershipCheckoutState(
        period: period,
        message: 'Pagos no configurados.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (!ref.mounted) return;
      state = MembershipCheckoutState(
        period: period,
        message: error.message ?? 'No se pudo iniciar el pago.',
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = MembershipCheckoutState(
        period: period,
        message: 'No se pudo procesar el pago. Inténtalo de nuevo.',
      );
    }
  }
}

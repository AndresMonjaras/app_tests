import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/payment_state.dart';
import 'payment_controller.dart';

export 'payment_dependencies.dart';

final paymentControllerProvider =
    NotifierProvider<PaymentController, PaymentState>(PaymentController.new);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/router/back_navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cerca/application/cerca_controller.dart';
import '../../../cerca/application/cerca_format.dart';
import '../../../cerca/application/cerca_state.dart';
import '../../../cerca/domain/entities/fee_type.dart';
import '../../../cerca/presentation/widgets/cerca_header.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/primary_action_button.dart';
import '../../../job_request/application/active_job_controller.dart';

class AppFeeScreen extends ConsumerStatefulWidget {
  const AppFeeScreen({super.key});

  @override
  ConsumerState<AppFeeScreen> createState() => _AppFeeScreenState();
}

class _AppFeeScreenState extends ConsumerState<AppFeeScreen> {
  bool _paying = false;

  Future<void> _pay(String paymentMethod) async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final payment = await ref.read(activeJobControllerProvider.notifier).payFee(paymentMethod);
      final result = ref.read(activeJobControllerProvider);
      if (result.hasError) throw result.error!;
      ref.read(cercaControllerProvider.notifier).payFee();
      if (!mounted) return;
      if (payment?.simulated ?? false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago simulado — no se cobró dinero real.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      context.go(RoutePaths.tracking);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'No se pudo procesar el pago.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cercaControllerProvider);
    final controller = ref.watch(cercaControllerProvider.notifier);
    final fee = controller.currentFeeConfig;
    // The amount is server-authoritative (set once when the job is created);
    // the fee config's own amount is only used as a placeholder while the
    // job is still loading, so the amount never visibly jumps after load.
    final feeAmount = ref.watch(activeJobControllerProvider).value?.feeAmount ?? fee.amount;

    void goBack() {
      switch (state.feeType) {
        case FeeType.bidding:
          context.go(RoutePaths.jobBidding);
        case FeeType.project:
          context.go(RoutePaths.jobProjectQuote);
        case FeeType.direct:
          context.go(RoutePaths.jobDirect);
      }
    }

    return BackFallbackScope(
      onFallback: goBack,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              CercaHeader(title: 'Pago del servicio Cerca', onBack: goBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cercaSurfaceTint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              fee.title.toUpperCase(),
                              style: CercaText.sora(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.cercaPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(formatSoles(feeAmount), style: CercaText.lora(fontSize: 32)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(fee.desc, style: CercaText.sora(fontSize: 12.5, color: AppColors.cercaTextSecondary, height: 1.6)),
                      const SizedBox(height: 18),
                      Text('Método de pago', style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final method in PaymentMethodKind.values) ...[
                            Expanded(
                              child: _PaymentChip(
                                label: _paymentLabel(method),
                                active: state.payment == method,
                                onTap: () => controller.setPayment(method),
                              ),
                            ),
                            if (method != PaymentMethodKind.values.last) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.cercaSuccessBg,
                          border: Border.all(color: AppColors.cercaSuccessBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'El costo del trabajo (mano de obra, materiales y movilización si aplica) se acuerda y se paga siempre directo con el técnico o equipo. Esta tarifa es solo por el servicio de Cerca.',
                          style: CercaText.sora(fontSize: 11.5, color: AppColors.cercaSuccessText, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PrimaryActionButton(
                label: _paying ? 'Procesando…' : 'Pagar ${formatSoles(feeAmount)} y contactar',
                enabled: !_paying,
                onTap: () => _pay(_paymentLabel(state.payment)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _paymentLabel(PaymentMethodKind kind) {
  return switch (kind) {
    PaymentMethodKind.card => 'Tarjeta',
    PaymentMethodKind.cash => 'Efectivo',
    PaymentMethodKind.transfer => 'Transferencia',
  };
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.cercaPrimary : Colors.white,
          border: Border.all(color: active ? AppColors.cercaPrimary : AppColors.cercaBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: CercaText.sora(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.cercaTextPrimary),
        ),
      ),
    );
  }
}

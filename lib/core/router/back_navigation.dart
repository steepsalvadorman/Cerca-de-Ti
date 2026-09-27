import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension BackNavigation on BuildContext {
  /// Returns to the previous screen when one was pushed below this one, or
  /// to [fallback] when this screen was reached with `go` (nothing to pop).
  void goBack(String fallback) => canPop() ? pop() : go(fallback);
}

/// Makes the system back button/gesture behave like the screen's own
/// "Volver": a normal pop when there is a screen below, otherwise
/// [onFallback] — instead of Android closing the app because the stack
/// only holds this one page.
class BackFallbackScope extends StatelessWidget {
  const BackFallbackScope({
    super.key,
    required this.onFallback,
    required this.child,
  });

  final VoidCallback onFallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onFallback();
      },
      child: child,
    );
  }
}

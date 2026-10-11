import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

import 'seriolab_loader.dart';

/// Seriolab's signature pull-to-refresh indicator featuring the animated
/// laboratory beaker loader.
class SeriolabRefreshIndicator extends StatelessWidget {
  const SeriolabRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      offsetToArmed: 65.0,
      builder: (context, child, controller) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final value = controller.value.clamp(0.0, 1.0);
            return Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!controller.isIdle)
                  Positioned(
                    top: 16.0 * controller.value,
                    child: Opacity(
                      opacity: value,
                      child: const SizedBox(
                        height: 48,
                        width: 48,
                        child: SeriolabLoader(size: 38.0),
                      ),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(0, 60.0 * controller.value),
                  child: child,
                ),
              ],
            );
          },
        );
      },
      child: child,
    );
  }
}

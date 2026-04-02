import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accessibility_provider.dart';

class AccessibleLayout extends ConsumerWidget {
  final Widget child;
  final String? onActivateSpeak;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onDoubleTap;

  const AccessibleLayout({
    super.key,
    required this.child,
    this.onActivateSpeak,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final vx = details.primaryVelocity;
          if (vx == null) return;
          if (vx < 0) {
            onSwipeLeft?.call();
          } else if (vx > 0) {
            onSwipeRight?.call();
          }
        },
        onDoubleTap: () {
          if (onActivateSpeak != null) {
            ref.read(accessibilityProvider.notifier).speak(onActivateSpeak!);
          }
          onDoubleTap?.call();
        },
        child: child,
      ),
    );
  }
}

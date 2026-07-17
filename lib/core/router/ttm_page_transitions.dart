import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// go_router 전환: 짧은 페이드 + 아주 작은 슬라이드 (티어 B 느낌).
CustomTransitionPage<void> ttmFadeSlidePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.028),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

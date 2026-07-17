import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// 가입 단계 완료 — 체크 스케일 플래시.
Future<void> showSignupStepDoneFlash(
  BuildContext context, {
  required String title,
  Duration hold = const Duration(milliseconds: 1200),
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _DoneFlashLayer(
      title: title,
      hold: hold,
      onEnd: () {
        entry.remove();
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  overlay.insert(entry);
  await done.future;
}

class _DoneFlashLayer extends StatefulWidget {
  const _DoneFlashLayer({
    required this.title,
    required this.hold,
    required this.onEnd,
  });

  final String title;
  final Duration hold;
  final VoidCallback onEnd;

  @override
  State<_DoneFlashLayer> createState() => _DoneFlashLayerState();
}

class _DoneFlashLayerState extends State<_DoneFlashLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtl;
  late final Animation<double> _scale;
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    _scaleCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _scale = CurvedAnimation(parent: _scaleCtl, curve: Curves.elasticOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _opacity = 1);
        _scaleCtl.forward();
      }
    });
    Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      await Future<void>.delayed(widget.hold);
      if (!mounted) return;
      setState(() => _opacity = 0);
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (mounted) widget.onEnd();
    });
  }

  @override
  void dispose() {
    _scaleCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 280),
      child: Material(
        color: Colors.black.withValues(alpha: 0.52),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: TtmColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TtmTypography.display.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.6,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 14,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

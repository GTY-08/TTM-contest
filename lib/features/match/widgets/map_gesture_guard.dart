import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// [ListView]·[CustomScrollView] 안의 지도가 스크롤 제스처와 겹치지 않도록 한다.
class MapGestureGuard extends StatelessWidget {
  const MapGestureGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
      },
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

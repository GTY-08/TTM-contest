import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 홈 하단 탭 인덱스. 설정·다른 화면에서 알림 탭 등으로 이동할 때 사용.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

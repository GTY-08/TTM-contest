import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// 네이버 지도 네이티브 뷰를 넣을 수 있는 플랫폼(Android/iOS)인지.
bool get ttmSupportsEmbeddedNaverMap =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

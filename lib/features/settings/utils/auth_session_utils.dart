import 'package:supabase_flutter/supabase_flutter.dart';

import '../settings_copy.dart';

/// 현재 세션의 주 로그인 provider (`email`, `kakao`, `google`, `apple` 등).
String? sessionPrimaryProvider(User? user) {
  final identities = user?.identities;
  if (identities == null || identities.isEmpty) {
    return user?.appMetadata['provider'] as String?;
  }
  return identities.first.provider;
}

bool sessionHasEmailProvider(User? user) {
  return user?.identities?.any((i) => i.provider == 'email') ?? false;
}

String providerSubtitle(String? provider) {
  switch (provider) {
    case 'email':
      return SettingsCopy.providerSubtitleEmail();
    case 'kakao':
      return SettingsCopy.providerSubtitleKakao();
    case 'google':
      return SettingsCopy.providerSubtitleGoogle();
    case 'apple':
      return SettingsCopy.providerSubtitleApple();
    default:
      return SettingsCopy.providerSubtitleUnknown();
  }
}

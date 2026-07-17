/// 설정 화면·다이얼로그 문자열 (단일 진실 원천).
abstract final class SettingsCopy {
  static const appBarTitle = '설정';

  static const saveSuccess = '저장했어요.';
  static const saveFailure = '저장하지 못했어요. 다시 시도해 주세요.';

  // ── 계정 탭 ─────────────────────────────────────────────
  static const accountBannerTitle = '계정과 로그인';
  static const accountBannerBody = '로그인 정보와 비밀번호를 관리해요.';

  static const loginAccountTitle = '로그인 계정';
  static const loginProviderTitle = '로그인 방식';
  static const passwordChangeTitle = '비밀번호 변경';
  static const passwordChangeSubtitle = '앱에서 바로 바꿀 수 있어요';
  static const passwordChangeDisabledSubtitle = '소셜 로그인 계정은 해당 서비스에서 변경해 주세요';
  static const passwordResetTitle = '비밀번호 재설정 메일';
  static const passwordResetSubtitle = '가입한 이메일로 링크를 보내요';
  static const socialKakaoTitle = '카카오 로그인';
  static const socialGoogleTitle = 'Google 로그인';
  static const socialAppleTitle = 'Apple 로그인';
  static const socialAvailable = '로그인 화면에서 사용할 수 있어요';
  static const socialCurrent = '현재 로그인 방식이에요';
  static const socialAppleComingSoon = 'iOS 네이티브 연동 후 제공 예정';

  static const logoutButton = '로그아웃';
  static const logoutDialogTitle = '로그아웃할까요?';
  static const logoutDialogBody = '다시 로그인하려면 이메일이나 소셜 계정이 필요해요.';
  static const logoutConfirm = '로그아웃';
  static const deleteAccountButton = '계정 삭제';
  static const deleteAccountDialogTitle = '계정을 삭제할까요?';
  static const deleteAccountDialogBody =
      '계정은 즉시 로그인할 수 없게 처리되고, 프로필 개인정보는 비식별화됩니다. 정산, 신고, 분쟁 대응에 필요한 거래 기록은 법령과 정책에 따라 보관될 수 있습니다.';
  static const deleteAccountConfirm = '삭제';
  static const deleteAccountSuccess = '계정이 삭제되었습니다.';
  static const deleteAccountFailure = '계정을 삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  static const cancel = '취소';

  static const resetMailDialogTitle = '재설정 메일을 보낼까요?';
  static String resetMailDialogBody(String email) =>
      '$email 주소로 비밀번호 재설정 링크를 보내요.';
  static const resetMailSuccess = '메일을 보냈어요. 받은편지함을 확인해 주세요.';
  static const resetMailNoEmail = '이메일 계정이 없어요.';

  static String providerSubtitleEmail() => '이메일로 로그인 중';
  static String providerSubtitleKakao() => '카카오로 로그인 중';
  static String providerSubtitleGoogle() => 'Google로 로그인 중';
  static String providerSubtitleApple() => 'Apple로 로그인 중';
  static String providerSubtitleUnknown() => '로그인 방식을 확인할 수 없어요';

  // ── 알림 탭 ─────────────────────────────────────────────
  static const notifyBannerTitle = '알림';
  static const notifyBannerBody =
      '주변 심부름 요청과 매칭 소식을 받는 방법을 골라요. 기기에서 알림을 허용해야 푸시가 와요.';

  static const notifyModePushTitle = '푸시만';
  static const notifyModePushSubtitle = '잠금 화면에만 알려요';
  static const notifyModeInAppTitle = '푸시 + 앱 안';
  static const notifyModeInAppSubtitle = '앱을 켜 두면 화면 안에서도 볼 수 있어요';
  static const notifyModeVibrateTitle = '푸시 + 앱 안 + 진동';
  static const notifyModeVibrateSubtitle = '중요한 알림에 진동이 함께 와요';

  static const notifyPermissionTitle = '기기 알림 권한';
  static const notifyPermissionSubtitle = '꺼져 있으면 푸시가 오지 않을 수 있어요';
  static const notifyPermissionOpen = '설정 열기';

  static const marketingTitle = '마케팅 알림';
  static const marketingSubtitle = '이벤트·혜택 소식 (선택)';
  static const marketingFootnote = '언제든 끌 수 있어요';
  static const goNotificationsTitle = '주변 심부름 찾기';
  static const goNotificationsSubtitle = '홈의 찾기 탭으로 이동';

  // ── 작업 탭 ─────────────────────────────────────────────
  static const workerBannerTitle = '작업 조건';
  static const workerBannerBody = '활동 중일 때만 주변 요청을 받아요. 거리와 태그는 매칭 알림에 반영돼요.';

  static const workerDistanceTitle = '최대 이동 거리';
  static const workerDistanceSubtitle = '이 거리 안의 요청만 알려요';
  static const workerTagsTitle = '선호 태그';
  static const workerTagsSubtitle = '선택한 종류의 요청을 우선해요';
  static const workerLocationBannerTitle = '위치 정보';
  static const workerLocationBannerBody =
      '활동 ON일 때 대략적인 위치를 사용해요. 매칭 후에는 상대와 위치를 공유할 수 있어요.';
  static const workerPenaltyTitle = '이용 제한';
  static const workerPenaltyNone = '현재 제한 없음';
  static String workerPenaltyUntil(String remaining) =>
      '$remaining 후 다시 이용할 수 있어요';
  static const workerGoHomeTitle = '활동 상태 바꾸기';
  static const workerGoHomeSubtitle = '홈에서 활동 ON/OFF';

  // ── 표시 탭 ─────────────────────────────────────────────
  static const displayBannerTitle = '화면 표시';
  static const displayBannerBody = '눈에 편한 밝기를 선택해요.';

  static const themeSystemTitle = '시스템 설정 따름';
  static const themeSystemSubtitle = '기기 밝기 모드와 같아요';
  static const themeLightTitle = '라이트';
  static const themeLightSubtitle = '밝은 배경';
  static const themeDarkTitle = '다크';
  static const themeDarkSubtitle = '어두운 배경';

  static const premiumTestTitle = '프리미엄 모드 (테스트)';
  static const premiumTestSubtitleOn = '수수료 5% · 동시 3건 · 최대 반경 즉시 알림 · 골드 배지';
  static const premiumTestSubtitleOff = '일반: 요청+작업 합산 1건 · 수수료 10%';
  static const premiumTestBannerTitle = '프리미엄 테스트';
  static const premiumTestBannerBody =
      'Google Play 정기결제 연동 전까지 관리자만 테스트 모드를 켤 수 있어요.';

  // ── 앱 탭 ─────────────────────────────────────────────────
  static const appVersionTitle = '버전';
  static const appName = '틈틈';
  static const appVersion = '1.0.0+1';
  static const permissionsBannerTitle = '권한 안내';
  static const permissionsBannerBody =
      '위치·알림·카메라는 기능별로 요청해요. 거부해도 일부 기능만 제한돼요.';
  static const permissionsOpenTitle = '시스템 설정 열기';
  static const permissionsOpenSubtitle = '앱 권한을 변경할 수 있어요';
  static const contactTitle = '고객센터';
  static const contactSubtitle = '자주 묻는 질문 · 문의 접수';
  static const onboardingPreview = '온보딩 미리보기 (개발)';
  static const developerSectionTitle = '개발자';
  static const developerModeTitle = '개발자 모드';
  static const developerModeOnSubtitle = '숨겨진 개발 탭과 진단 정보를 표시해요.';
  static const developerModeOffSubtitle = '진단 정보가 필요할 때만 켜세요.';
  static const onboardingPreviewSubtitle = '온보딩 흐름을 다시 확인해요.';
}

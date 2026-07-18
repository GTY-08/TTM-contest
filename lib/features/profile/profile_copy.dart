/// 프로필 탭·닉네임 수정 문자열.
abstract final class ProfileCopy {
  static const appBarTitle = '프로필';

  static const photoChange = '프로필 사진 변경';
  static const nicknameEdit = '닉네임 수정';

  static const premiumTitle = '틈틈 프리미엄';
  static const premiumBenefits = '동시 운동 참여 3건 · 최대 반경 즉시 알림 · 일반 매칭 운영';
  static const premiumActiveLabel = '프리미엄 회원';
  static const premiumPriceHint = '월 19,900원';
  static const premiumCta = '자세히 보기';

  static const historyWorkerTab = '참여 내역';
  static const historyRequesterTab = '운영 내역';
  static const historyEmptyTitle = '아직 내역이 없어요';
  static const historyEmptySubtitle = '완료한 운동 활동이 여기에 쌓여요';

  static const nicknameScreenTitle = '닉네임 수정';
  static const nicknameHint = '2~12자, 다른 사람에게 보이는 이름이에요';
  static const nicknameDuplicate = '이미 사용 중인 닉네임이에요';
  static const nicknameInvalid = '2~12자로 입력해 주세요.';
  static const nicknameSave = '저장';

  static String ratingLine(double rating, int count) =>
      '★ ${rating.toStringAsFixed(1)} · 받은 평가 $count개';
}

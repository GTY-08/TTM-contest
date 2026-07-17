/// 그래픽 사용 원칙 (MVP).
///
/// 3D·외주 없이도 “가볍게 다채로운” 인상을 내기 위해, 화면별 시각 요소의
/// **개수와 역할**을 제한한다. (앱인토스 그래픽 가이드의 방향성만 참고)
class GraphicPolicy {
  const GraphicPolicy._();

  /// 화면당 이모지 상한.
  ///
  /// - 이모지는 “보조 감정” 역할에만 쓰고, 핵심 정보 전달은 텍스트/아이콘으로 한다.
  static const int maxEmojisPerScreen = 2;

  /// 한 화면에서 눈에 띄는 그라데이션/글로우 포인트 권장 상한.
  ///
  /// - 버튼/배너/카드 등 “포인트” 역할만 허용하고, 난립은 금지.
  static const int maxStrongGradientAccentsPerScreen = 2;
}

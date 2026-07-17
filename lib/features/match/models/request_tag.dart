/// 매칭 태그 목록. 요청 생성·작업자 선호 태그에 공통으로 쓰는 가벼운 사전.
///
/// 정식 분류 체계가 나오기 전까지는 한국어 라벨 자체를 키로 쓴다.
/// (`tags text[]` 컬럼에 한국어가 들어가도 되도록 RLS/체크는 자유 형식.)
class TtmRequestTags {
  const TtmRequestTags._();

  static const String delivery = '배달';
  static const String purchase = '구매';
  static const String cleaning = '청소';
  static const String waiting = '대기';
  static const String moving = '운반';
  static const String document = '문서';
  static const String pet = '반려';
  static const String etc = '기타';

  static const List<String> all = [
    delivery,
    purchase,
    cleaning,
    waiting,
    moving,
    document,
    pet,
    etc,
  ];
}

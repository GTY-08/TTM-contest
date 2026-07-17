/// 정식 출시 전 MVP 빌드 표식.
///
/// APK 배포·스플래시 표시·`docs/HANDOFF.md` §「빌드 표식」을 **함께** 갱신한다.
abstract final class TtmAppBuildInfo {
  /// 로컬(KST) 기준 최종 수정 시각. `DateTime` 은 기기 타임존으로 해석된다.
  static final DateTime lastModified = DateTime(2026, 6, 22, 13, 32, 3);

  /// 스플래시·문서용 — `MM-dd HH:mm:ss`
  static String get lastModifiedLabel {
    final d = lastModified;
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi:$ss';
  }

  /// 문서용 — `yyyy-MM-dd HH:mm:ss`
  static String get lastModifiedDocumentLabel {
    final d = lastModified;
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$mi:$ss';
  }
}

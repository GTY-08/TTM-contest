import 'package:flutter/material.dart';

/// 틈틈(TTM) 컬러 토큰.
///
/// `plans/틈틈_디자인_시스템.md` §2의 매트릭스를 그대로 옮긴 단일 진실 원천.
/// 화면 코드는 절대 raw `Color(0x...)` 를 박지 말고 이 클래스를 통해서만 색을 가져온다.
class TtmColors {
  const TtmColors._();

  // ── Brand ───────────────────────────────────────────────
  /// 틈틈 메인 그린. 메인 액션·강조에 사용.
  static const Color primary = Color(0xFF38B27C);

  /// 카드 하이라이트·선택 상태 배경. (틈틈 민트)
  static const Color primaryLight = Color(0xFFDDF1E9);

  /// 다크 모드에서 명도를 한 단계 밝힌 Primary.
  static const Color primaryDark = Color(0xFF5CC48A);

  /// 틈틈 딥 그린. 성공·완료·브랜드 보조에 사용.
  static const Color deepGreen = Color(0xFF185944);

  /// 진짜 위험/오류/마감 임박에만 쓰는 코랄. 일반 취소 버튼에는 쓰지 않는다.
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFFF0F0);

  /// 프리미엄 왕관·구독 강조 골드. (틈틈 옐로우)
  static const Color premiumGold = Color(0xFFF0CC63);

  // ── Light ───────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFFEFCF7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEEEAE3);
  static const Color lightOnSurface = Color(0xFF263331);
  static const Color lightSubtle = Color(0xFF6B7280);
  static const Color lightDivider = Color(0xFFE5E7EB);

  // ── Dark ────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceAlt = Color(0xFF262626);
  static const Color darkOnSurface = Color(0xFFF0F0F0);
  static const Color darkSubtle = Color(0xFF9CA3AF);
  static const Color darkDivider = Color(0xFF2A2A2A);

  // ── Status (작업자 상태 뱃지) ─────────────────────────
  static const Color statusOnline = primary;
  static const Color statusOffline = Color(0xFF9CA3AF);
  static const Color statusBusy = Color(0xFFE6A23C);

  // ── 시맨틱 (Accent 코랄과 구분 — 성공·정보·대기 등) ───
  /// 완료·성공 메시지. 위험 UI에는 쓰지 않는다.
  static const Color success = Color(0xFF185944);

  /// 안내·링크성 보조. 브랜드 그린 계열의 차분한 톤.
  static const Color info = Color(0xFF1E8A60);

  /// 대기·주의. Accent(삭제·오류)와 다른 앰버 톤.
  static const Color warning = Color(0xFFB45309);

  /// Uber식 전환 CTA·프로모 밴드 (블루그린과 병행).
  static const Color ctaInk = Color(0xFF1A1A1A);

  /// 링크·ETA·보조 metric (Primary 와 구분). 그린 틴트 슬레이트.
  static const Color infoSlate = Color(0xFF3D6657);
  static const Color infoBg = Color(0xFFE2F4EC);
}

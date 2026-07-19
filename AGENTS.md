# 운동 틈틈(TTM) 프로젝트 에이전트 지침

이 파일은 Codex CLI, Cursor 및 기타 AI 코딩 에이전트가 항상 우선 적용하는 핵심 규칙이다.

## 프로젝트

- Flutter + Riverpod + go_router 기반 앱
- Flutter 버전은 FVM으로 고정한다: `.fvmrc` 기준 `3.44.4`
- Supabase PostgreSQL/PostGIS/Realtime/RLS/RPC 백엔드
- FCM 푸시, 네이버 지도, Android 우선
- 패키지명: `com.ttm.ttm_app`
- 사용자 UI와 상세 보고는 한국어
- 한 계정으로 레이드 모집자(운영자)와 참가자 역할 모두 수행
- 서비스는 근처 사람들과 짧게 함께 운동하는 실시간 운동 메이트 매칭이다(레이드 · 빠른 운동 매칭 · 활동 포인트)

## 작업 전 확인

항상 먼저 확인:

1. `docs/HANDOFF.md`
2. `docs/앱_가이드.md`
3. 현재 작업과 직접 관련된 코드

작업 유형별로 필요한 문서만 추가로 읽는다.

- 구조·매칭·채팅·위치: `docs/AGENT_ARCHITECTURE.md`
- Supabase·RLS·migration·secret: `docs/AGENT_BACKEND.md`
- 디자인: `docs/AGENT_DESIGN.md`
- 무선 디버깅·APK 설치: `docs/AGENT_DEVICE_DEPLOYMENT.md`
- 검사·QA·완료 보고: `docs/AGENT_QA.md`
- 현재 우선순위: `docs/AGENT_PRIORITIES.md`

관련 작업이 아니면 상세 문서를 전부 읽지 않는다.

## 핵심 코드 규칙

- Supabase 호출은 가능한 repository 계층에 둔다.
- 화면에서 직접 `.from(...)`, `.rpc(...)` 호출을 새로 늘리지 않는다.
- Riverpod provider로 화면과 repository를 연결한다.
- 반복 UI는 `lib/shared/widgets/`로 분리한다.
- 라우팅은 `lib/core/router/app_router.dart`의 `AppRoutes`를 기준으로 한다.
- 기존 아키텍처, 라우팅, 상태관리 체계를 임의로 교체하지 않는다.
- 문서와 코드가 다르면 코드를 우선 확인하고 문서를 갱신한다.

## 변경 제한

사용자의 명시적 요청 없이 다음을 하지 않는다.

- 결제·구독·활동 포인트 로직 변경
- 외부 본인확인·전자서명 구조 변경
- 기존 migration 파일 수정
- 원격 DB reset 또는 migration repair
- 더미 데이터 삭제·갱신
- 전체 디자인 시스템 교체
- secret 요청·출력·커밋
- `.env.local` 내용 출력

일반적인 Supabase migration은 dry-run 후 적용할 수 있다. 데이터 삭제, 대량 파괴, 권한 노출, 결제, 외부 인증 관련 변경은 사용자 승인을 받는다.

## 기본 검사

Flutter 변경:

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```

DB 변경:

```bash
supabase db push --dry-run
```

## 완료 보고

1. 작업 요약
2. 수정·추가 파일
3. migration/RPC 변경
4. 사용자 흐름 변화
5. 검사 결과
6. 원격 DB 적용 여부
7. 실기기 QA 항목
8. 남은 문제 제안

## Full Access 작업 범위

Codex가 Full Access 권한으로 실행되더라도 다음 범위 안에서만 스스로 실행한다.

자동 실행 가능:

- 현재 Git 저장소 내부 파일 생성·수정
- `fvm dart format`
- `fvm flutter analyze`
- `fvm flutter test`
- 디버그 APK 빌드
- 연결된 개발 기기에 디버그 APK 설치
- `git status`, `git diff`, `git log`
- 비파괴적인 Supabase migration의 dry-run
- 사용자 지시에 따른 일반 migration 적용

반드시 사용자 승인을 받을 작업:

- `git reset --hard`
- `git clean -fd` 또는 `git clean -fdx`
- 강제 push
- 브랜치 또는 태그 삭제
- 현재 저장소 밖 파일 수정·삭제
- 재귀적 파일 삭제 명령
- 원격 DB reset
- migration history repair
- 운영 데이터의 대량 `DELETE` 또는 `UPDATE`
- RLS를 비활성화하거나 권한을 확대하는 변경
- service role key 또는 secret 조회
- 결제·구독·활동 포인트·외부 인증 변경

사용자 승인이 필요한 작업은 실행 전에 명령, 영향 범위, 복구 방법을 짧게 설명한다.

# 틈틈(TTM) — 현재 작업 이행 문서

> 이 문서는 현재 틈틈의 구현 상태와 다음 작업을 빠르게 파악하기 위한 인수인계 문서다.  
> 실제 코드, 현재 Git 브랜치, 최근 Supabase migration이 이 문서보다 우선한다.  
> 문서와 코드가 다르면 코드를 기준으로 판단하고 이 문서를 갱신한다.

**문서 갱신 기준**: `2026-07-19`  
**기준 저장소**: `GTY-08/TTM-contest`  
**기준 브랜치**: `main`  
**현재 서비스 방향**: 청소년의 일상적인 운동 참여를 돕는 위치 기반 운동 레이드·1대1 매칭 플랫폼

---

## 1. 프로젝트 개요

- 서비스명: 틈틈
- 코드명: TTM
- 패키지명: `com.ttm.ttm_app`
- 문제 정의: 청소년 기초 체력 약화와 일상적 운동 참여 부족
- 핵심 해결 방식:
  - 주변 운동 레이드 탐색 및 참가
  - 무료 자동 생성 레이드
  - 프리미엄 사용자의 레이드 직접 개설
  - 위치·운동 조건 기반 1대1 빠른 매칭
  - 출석 기록과 포인트 보상
- 앱: Flutter + Dart + Riverpod + go_router
- 백엔드: Supabase + PostgreSQL + PostGIS + Realtime + RLS + RPC
- 푸시: Firebase Cloud Messaging
- 지도·위치: Naver Map + geolocator
- 관리자 페이지: React + Vite + Supabase
- 대상 플랫폼:
  - 현재 시연·검증 기준: Android
  - 구조: Flutter 단일 코드베이스 기반 크로스플랫폼
  - iOS: 확장 가능한 구조이나 실제 빌드·권한·푸시·지도 설정 검증은 완료로 단정하지 않음
- 계정 구조: 한 계정이 일반 참가자와 프리미엄 레이드 운영자 역할을 모두 수행할 수 있음

### 한 줄 설명

> 틈틈은 위치 기반 운동 레이드와 1대1 매칭을 통해 청소년의 일상적인 운동 참여를 돕는 플랫폼이다.

---

## 2. 현재 서비스의 핵심 구조

현재 틈틈은 세 가지 운동 연결 방식을 중심으로 구성되어 있다.

### 2.1 자동 생성 레이드

- 등록된 운동 장소와 운영 조건을 기반으로 무료 레이드를 제공
- 사용자는 주변 레이드를 확인하고 바로 참가
- 별도의 프리미엄 운영자가 없는 레이드
- 레이드 종료 후 참가자들이 서로의 참여 여부를 확인
- 확인된 활동은 포인트와 활동 기록에 반영

### 2.2 프리미엄 레이드

- 프리미엄 사용자가 원하는 장소와 시간에 직접 개설
- 운동 종목, 제목, 설명, 시간, 인원, 강도, 초보자 허용 여부, 참가비 설정
- 참가자는 신청 메시지를 보내고 운영자가 승인·대기·거절
- 신청자와 운영자 간 1대1 채팅 제공
- 승인된 참가자는 단체 채팅과 위치 공유 사용
- 운동 종료 후 운영자가 출석 상태를 기록하고 레이드 완료

### 2.3 1대1 빠른 운동 매칭

- 현재 위치 또는 등록된 운동 장소를 기준으로 가까운 한 명과 연결
- 운동 종목, 운동 시간, 강도, 파트너 수준, 최대 거리 설정
- 가까운 후보부터 단계적으로 탐색 범위를 확장
- 상대방이 제안을 수락하면 1대1 매칭 확정
- 전용 채팅과 실시간 위치 지도 제공
- 운동 완료 시 두 참여자 모두 활동 포인트 지급

### 2.4 긴급 참가자 모집

- 기존 레이드의 인원이 부족할 때 사용하는 보조 모집 기능
- 대기자에게 먼저 알린 뒤 주변 거리 범위를 단계적으로 확대
- 목표 인원을 최소 인원 또는 최대 인원으로 설정
- 무료 레이드는 즉시 승인
- 유료 레이드는 운영자가 직접 승인하거나 즉시 승인하도록 설정 가능

---

## 3. 현재 앱의 6개 탭

현재 실제 홈 셸은 다음 6개 탭으로 구성된다.

```text
홈
매칭 만들기
찾기
내 활동
리워드
프로필
```

### 홈

- 사용자 인사와 운동 참여 유도
- 지금 운동 1대1 매칭 진입
- 가까운 레이드 및 추천 레이드
- 현재 진행 중인 매칭·레이드 상태
- 운동 선호 및 활동 가능 상태 안내

### 매칭 만들기

- 프리미엄 사용자: 레이드 생성 폼 제공
- 일반 사용자: 프리미엄 기능 안내
- 지도에서 운동 장소 선택
- 운동 종목·시간·인원·강도·참가비 설정

### 찾기

- 주변 레이드 목록 및 지도 탐색
- 거리, 운동 종목, 무료·유료 여부 기준 확인
- 자동 레이드와 프리미엄 레이드 탐색
- 레이드 상세 화면 진입 및 참가

### 내 활동

- 참가하거나 운영한 레이드
- 현재 1대1 운동 매칭
- 신청·승인·진행·완료 상태 확인
- 운동 활동 이력 확인

### 리워드

- 현재 포인트와 누적 포인트
- 활동 레벨
- 포인트 거래 내역
- 리워드 상품 및 교환 내역
- 운동 참여를 지속하도록 유도하는 보상 구조

### 프로필

- 닉네임과 프로필 이미지
- 운동 선호 설정
- 운동 수준과 활동 가능 요일·시간
- 최대 이동 가능 거리
- 프리미엄 상태
- 운영·참여 활동 통계
- 설정 화면 진입

---

## 4. 주요 코드 위치

### 앱 셸과 라우팅

```text
lib/features/home/screens/home_screen.dart
lib/core/router/app_router.dart
```

### 레이드 도메인

```text
lib/features/raid/models/raid_models.dart
lib/features/raid/models/exercise_matching_models.dart
lib/features/raid/providers/raid_providers.dart
lib/features/raid/repositories/raid_repository.dart
```

### 핵심 화면

```text
lib/features/raid/screens/raid_home_tab.dart
lib/features/raid/screens/raid_browse_tab.dart
lib/features/raid/screens/raid_create_tab.dart
lib/features/raid/screens/raid_activity_tab.dart
lib/features/raid/screens/raid_reward_tab.dart
lib/features/raid/screens/raid_detail_screen.dart
lib/features/raid/screens/raid_chat_screen.dart
lib/features/raid/screens/raid_application_chat_screen.dart
lib/features/raid/screens/exercise_quick_match_screen.dart
lib/features/raid/screens/exercise_quick_chat_screen.dart
lib/features/raid/screens/exercise_preferences_screen.dart
```

### 지도와 위치

```text
lib/features/raid/services/exercise_location_service.dart
lib/features/raid/widgets/raid_live_map.dart
lib/features/raid/widgets/quick_match_live_map.dart
lib/features/match/widgets/meet_point_map_picker.dart
```

### 프리미엄

```text
lib/features/premium/screens/premium_screen.dart
lib/core/constants/premium_constants.dart
```

### 푸시

```text
lib/core/push/
supabase/functions/_shared/
supabase/functions/match-tick/
```

### 환경 변수

```text
lib/core/config/env.dart
.env.example
.gitignore
pubspec.yaml
```

### 관리자 페이지

```text
admin/src/pages/
admin/src/components/
admin/src/lib/
```

### 웹

```text
web/
```

### DB 및 서버 로직

```text
supabase/migrations/
supabase/functions/
```

---

## 5. 핵심 사용자 흐름

## 5.1 자동 생성 레이드 참가

```text
홈 또는 찾기
→ 주변 자동 레이드 확인
→ 레이드 상세
→ 위치 기반 참가 가능 여부 확인
→ 바로 참가
→ 단체 채팅
→ 운동 진행
→ 레이드 종료
→ 참가자 간 출석 상호 확인
→ 포인트·활동 기록 반영
```

특징:

- 참가비 없음
- 운영자 승인 없이 참가 확정
- 별도 운영자가 없으므로 참가자들이 서로의 참여를 검증
- 본인을 제외한 다른 참가자에 대해 다음 의견 제출

```text
참여 확인
확인 불가
미참여
```

주의:

- 이는 단순한 1대1 상호 승인 방식이 아니라 여러 참가자가 서로에게 의견을 보내는 다자간 검증 구조다.
- 최종 출석 확정 기준은 Supabase의 출석 투표 RPC와 migration을 확인해야 한다.

---

## 5.2 프리미엄 레이드 생성과 운영

```text
매칭 만들기
→ 장소 선택
→ 운동 종목·제목·설명 입력
→ 시작 시간·운동 시간 설정
→ 최소·최대 인원 설정
→ 운동 강도·초보자 허용 여부 설정
→ 참가비 입력
→ 레이드 생성
→ 참가 신청 접수
→ 신청자 1대1 채팅
→ 승인·대기·거절
→ 단체 채팅
→ 운동 진행
→ 운영자 출석 기록
→ 레이드 완료
→ 포인트·가상 정산 기록 반영
```

운영자 출석 상태:

```text
참석
지각
중도 이탈
불참
```

주의:

- 프리미엄 레이드의 출석은 참가자 상호 확인이 아니라 운영자가 기록한다.
- 레이드 완료 전에 참가자별 출석 상태가 모두 결정되어야 한다.
- 불참자 감점과 참가자 보너스는 서버의 완료 RPC에서 처리한다.

---

## 5.3 1대1 빠른 운동 매칭

```text
홈 또는 지금 운동 매칭
→ 운동 제안 받기 ON
→ 현재 위치 또는 등록 장소 선택
→ 운동 종목 선택
→ 운동 시간 선택
→ 강도·파트너 수준·거리 선택
→ 운동 파트너 찾기
→ 가까운 후보부터 단계적 탐색
→ 상대방에게 제안
→ 상대방 수락
→ 1대1 매칭 확정
→ 전용 채팅과 실시간 위치 확인
→ 운동 완료
→ 두 참여자 모두 포인트 지급
```

현재 주요 조건:

- 운동 제안 받기 상태는 일정 시간 동안 유지
- 매칭 탐색은 10단계 진행 상태로 표시
- 매칭 상대는 한 명
- 운동 완료 시 두 참여자 모두 `100P` 지급
- 중복 완료 호출은 서버에서 멱등적으로 처리되어야 함

현재 운동 종목 예시:

```text
걷기
러닝
배드민턴
농구
기초 체력
```

---

## 5.4 긴급 참가자 모집

```text
레이드 상세
→ 긴급 모집 설정
→ 목표 인원 선택
→ 승인 방식 선택
→ 대기자 알림
→ 1km 범위
→ 3km 범위
→ 5km 범위
→ 참가 제안 수락
→ 목표 인원 충족 시 종료
```

목표 인원:

```text
최소 인원까지
최대 인원까지
```

승인 방식:

```text
무료 레이드: 즉시 승인
유료 레이드: 직접 승인 또는 즉시 승인
```

---

## 6. 운동 선호와 매칭 조건

현재 운동 선호 데이터는 다음을 저장한다.

```text
활동 기준 위치
선호 운동 종목
운동 수준
활동 가능 요일
활동 가능 시작 시간
활동 가능 종료 시간
최대 이동 거리
```

중요한 현재 한계:

- 한 요일에 여러 개의 분리된 여유 시간대를 저장하는 구조가 아님
- 학교 시간표·학원 일정과 직접 연동하지 않음
- 현재는 하나의 시작 시간과 종료 시간 범위를 중심으로 선호를 관리
- “다음 일정 전까지”와 같은 정밀한 시간 제약 매칭은 구현 완료로 설명하지 않음

설명 시에는 다음과 같이 표현한다.

> 틈틈은 사용자의 위치와 운동 조건을 바탕으로 주변 레이드와 운동 상대를 연결하여, 운동 상대 탐색과 일정 조율의 부담을 줄인다.

짧은 여유 시간을 정밀 분석해 자동 배치하는 서비스라고 과장하지 않는다.

---

## 7. 레이드 생성과 운동 장소

### 프리미엄 레이드 생성 항목

```text
운동 장소
운동 종목
제목
설명
시작 시간
운동 시간
최소 참가 인원
최대 참가 인원
운동 강도
초보자 참가 가능 여부
참가비
```

### 장소 구조

- 등록된 운동 장소 선택
- 지도에서 사용자 지정 장소 선택
- 장소 검색 Edge Function
- 좌표의 주소·장소명 역변환 Edge Function
- 참가 시 위치 정확도와 레이드 범위 검증

### 자동 레이드 장소 관리

관리자 페이지에서 운동 장소별로 다음 값을 관리할 수 있다.

```text
활성 요일
자동 시작 시간
기본 운동 시간
최소 참가 인원
최대 참가 인원
운동 종목 및 장소 상태
```

자동 레이드 생성 주기와 실제 원격 배포 상태는 Supabase cron·Edge Function·migration을 다시 확인한다.

---

## 8. 채팅과 위치

### 채팅 종류

```text
레이드 단체 채팅
프리미엄 레이드 신청자 1대1 채팅
1대1 빠른 운동 매칭 채팅
```

지원 기능:

- 텍스트 메시지
- 이미지 첨부
- 읽음 상태
- 입력 중 표시
- 신고와 채팅 컨텍스트
- 종료 후 채팅 기록 확인

### 위치

- 레이드 집합 장소 지도
- 승인된 참가자 간 최근 위치 공유
- 1대1 매칭 참여자 간 실시간 위치 지도
- 위치 권한이 없으면 집합 장소 중심으로 표시
- 실시간 위치는 화면을 보는 동안 주기적으로 갱신

보안 원칙:

- 매칭·승인 전에는 상대의 정확한 좌표를 불필요하게 노출하지 않음
- 정확한 위치는 같은 레이드 또는 1대1 매칭의 승인된 참여자에게만 제공
- DB에서는 RLS와 RPC 반환 범위를 함께 확인
- 지도·GPS·백그라운드 위치는 Android 실기기 QA 필수

---

## 9. 출석·완료·포인트

### 자동 생성 레이드

- 레이드 종료 후 참가자들이 다른 참가자의 참여 여부에 투표
- 선택값:

```text
present
cannot_confirm
absent
```

- 화면 표시:

```text
참여 확인
확인 불가
미참여
```

### 프리미엄 레이드

- 운영자가 참가자의 출석 상태를 직접 기록
- 선택값:

```text
present
late
left_early
absent
```

### 1대1 운동 매칭

- 매칭 참여자가 운동 완료를 실행
- 정상 완료 시 두 참여자 모두 `100P`
- 이미 완료된 매칭은 중복 보상되지 않아야 함

### 리워드 구조

현재 코드에는 다음 개념이 존재한다.

```text
포인트 지갑
현재 포인트
누적 포인트
활동 레벨
포인트 거래 내역
리워드 카탈로그
교환 신청
운영·참여 활동 요약
```

포인트는 실제 현금이 아니라 서비스 내 활동 보상으로 다룬다.

---

## 10. 프리미엄과 참가비

### 현재 프리미엄 표시 정책

- 상품 ID: `ttm_premium_monthly`
- UI 표시 가격: 월 `19,900원`
- 주요 혜택:
  - 레이드 직접 개설
  - 참가 신청자 승인과 정원 관리
  - 참가비와 취소 기준 설정
  - 누적 운동 시간과 활동 통계

### 실제 구현 상태

중요:

- `in_app_purchase` 의존성은 존재
- 현재 프리미엄 화면의 가입 버튼은 실제 결제를 실행하지 않고 안내 메시지만 표시
- 따라서 Google Play 정기 구독이 실제 운영 연동 완료되었다고 설명하지 않음
- 프리미엄 계정 여부는 현재 프로필 데이터의 `isPremium` 상태를 기준으로 동작

### 참가비와 가상 결제

현재 모델과 RPC에는 다음 개념이 존재한다.

```text
참가비
결제 상태
보관 상태
취소 환불
레이드 완료
운영자 정산
가상 지갑·원장
```

대회 설명 기준:

> 현재 MVP에서는 실제 금융 계좌 및 PG사와 연동하지 않고, 가상 지갑을 활용해 참가비 보관·환불·정산 과정을 구현했다.

주의:

- 실제 PG 결제 또는 법적 에스크로가 연동되었다고 설명하지 않음
- 실제 금융 기능으로 확장할 때는 PG 계약, 환불 정책, 전자금융·개인정보 검토 필요
- 결제·정산·포인트 정책은 사용자 승인 없이 임의 변경하지 않음

---

## 11. 라우팅

라우팅은 다음 파일을 기준으로 한다.

```text
lib/core/router/app_router.dart
```

현재 주요 경로:

```text
/splash
/onboarding
/login
/login/email
/signup
/signup/email
/home

/raid/:id
/raid/:id/chat
/raid/:id/applications/:participantId/chat

/quick-match
/quick-match/:id
/quick-match/:id/chat

/profile/exercise
/premium
/reset-password
/dev
```

### 홈 탭 딥링크 예시

```text
/home?tab=create
/home?tab=find
/home?tab=activity
/home?tab=reward
/home?tab=profile
```

### 레거시 요청 경로

기존 심부름 서비스의 다음 경로와 화면 코드가 아직 저장소에 남아 있다.

```text
/request/new
/request/:id/waiting
/request/:id/general
/request/:id/edit
/request/:id/active
/request/:id/chat
```

주의:

- 현재 홈 탭은 레이드 중심으로 전환됨
- 레거시 경로는 핵심 시연 흐름에서 사용하지 않음
- 기존 심부름 기능을 신규 레이드 코드와 섞어 수정하지 않음
- 대회 이후 정리할 때 참조 관계와 딥링크를 확인한 뒤 단계적으로 제거

---

## 12. Supabase 원칙

### 상태 변경

- 중요한 상태 변경은 RPC 사용
- Flutter 화면에서 직접 핵심 상태를 `.update()`하지 않음
- 동시 참가·수락·완료는 서버에서 원자적으로 처리
- 클라이언트는 결과를 받아 provider를 갱신

### 보안

- public 테이블은 RLS 활성화를 전제로 함
- 앱에는 publishable/anon key만 사용
- service role key는 앱·문서·로그·저장소에 포함하지 않음
- `SECURITY DEFINER` 함수는 `SET search_path = public` 확인
- 정확한 위치 데이터는 승인된 참여자에게만 반환
- 채팅·참가·위치 테이블의 RLS를 기능 변경 시 함께 확인

### 주요 RPC 예시

레이드:

```text
list_raids
list_my_raids
get_raid_detail
create_premium_raid
get_raid_join_eligibility
join_free_raid_nearby
apply_premium_raid_nearby
review_raid_application
leave_raid
record_raid_attendance
cast_attendance_vote
finalize_raid
```

운동 선호와 1대1 매칭:

```text
get_my_exercise_preferences
upsert_my_exercise_preferences
set_exercise_match_availability
create_exercise_quick_match
advance_exercise_quick_match
get_my_exercise_quick_match
list_my_exercise_match_offers
respond_exercise_match_offer
cancel_exercise_quick_match
complete_exercise_quick_match
```

긴급 모집:

```text
start_raid_recruitment
get_raid_recruitment_status
list_my_raid_recruitment_offers
respond_raid_recruitment_offer
```

RPC 이름은 Flutter repository와 최신 migration을 함께 확인한 뒤 수정한다.

---

## 13. Migration 작업 원칙

새 DB 변경은 반드시 새 파일로 추가한다.

```text
supabase/migrations/<timestamp>_<description>.sql
```

원칙:

- 기존 migration 수정 금지
- 원격 DB에 `supabase db reset` 실행 금지
- 승인 없는 migration history repair 금지
- 동일 SQL이 수동으로 적용되어 있을 가능성 확인
- 파괴적 변경 전 사용자 승인
- RLS·함수 권한·인덱스·Realtime 대상 테이블을 함께 검토

DB 작업 순서:

```text
관련 모델·repository·migration 확인
→ 새 migration 작성
→ supabase db push --dry-run
→ SQL과 권한 검토
→ 비파괴적 변경 적용
→ Flutter provider·화면 갱신
→ 실기기 QA
```

파괴적 변경 예시:

```text
대량 DELETE
대량 UPDATE
테이블·컬럼 DROP
RLS 비활성화
과도한 권한 확대
결제·포인트 원장 수정
운영 데이터 손실
```

---

## 14. 관리자 페이지와 웹

### 관리자 페이지

`admin/`에는 React + Vite 기반 관리자 페이지가 있다.

현재 주요 관리 범위:

```text
대시보드
운동 장소
사용자
신고
이용 제한
감사 로그
지원 문의
기존 요청·정산 관련 레거시 화면
```

운동 장소 페이지는 자동 레이드 운영 조건을 관리하는 핵심 화면이다.

주의:

- 관리자 페이지에는 기존 심부름 서비스 화면이 일부 남아 있음
- 현재 운동 레이드 서비스와 직접 관련 없는 화면은 신규 작업에서 우선 사용하지 않음
- 관리자 권한 검증은 클라이언트 표시뿐 아니라 Supabase에서 다시 확인

### 웹

`web/`에는 다음 성격의 페이지가 포함되어 있다.

```text
서비스 소개
계정 관련 페이지
개인정보처리방침
이용약관
계정 삭제
공지
고객지원
```

주의:

- 기존 심부름 서비스 문구와 이미지가 남아 있을 수 있음
- 대외 공개 전에 운동 레이드 서비스 설명과 일치하는지 검수
- 앱과 웹의 인증·개인정보 문구가 서로 충돌하지 않게 관리

---

## 15. 환경 변수와 시크릿

실제 환경 변수 파일:

```text
.env.local
```

제출·공유용 예시 파일:

```text
.env.example
```

현재 주요 환경 변수:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
NAVER_MAP_CLIENT_ID
NAVER_MAP_CLIENT_SECRET
FIREBASE_PROJECT_ID
SUPABASE_PASSWORD_RESET_REDIRECT_URL
SUPABASE_EMAIL_CONFIRM_REDIRECT_URL
```

원칙:

- `.env.local`은 Git에 커밋하지 않음
- `.env.example`에는 실제 키를 넣지 않음
- service role key, Toss secret key, Firebase 개인키를 앱 번들에 넣지 않음
- Android의 실제 `google-services.json`은 저장소에 커밋하지 않음
- iOS의 실제 `GoogleService-Info.plist`도 저장소에 커밋하지 않음
- 릴리스 서명키와 `key.properties`를 공유하지 않음

### 로컬 실행 시 주의

현재 `pubspec.yaml`은 `.env.local`을 asset으로 등록한다.

따라서 새 환경에서는:

```text
.env.example 복사
→ 파일명을 .env.local로 변경
→ 본인의 개발용 키 입력
→ flutter pub get
→ 빌드·실행
```

실제 API 키 없이 소스 코드만 검토하는 것은 정상이다.  
다만 `.env.local` 파일이 아예 없으면 Flutter asset 검사 단계에서 빌드가 실패할 수 있다.

---

## 16. 플랫폼과 배포

### Android

현재 대회 시연과 주요 QA의 기준 플랫폼이다.

기본 명령:

```bash
fvm flutter devices
fvm flutter run -d <device_id>
fvm flutter build apk --debug
```

검증 대상:

```text
로그인과 온보딩
위치 권한
네이버 지도
주변 레이드 조회
무료 레이드 참가
프리미엄 레이드 생성·신청·승인
1대1 매칭
푸시 알림
채팅
실시간 위치
출석
포인트
```

### iOS

- Flutter 공용 Dart 코드는 재사용 가능
- iOS Runner, 권한, APNs, Firebase, 지도, Apple 로그인, 인앱결제 설정 검증 필요
- 현재는 “iOS까지 출시 완료”가 아니라 “iOS로 확장 가능한 크로스플랫폼 구조”로 설명

---

## 17. 기본 검사

Flutter:

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```

Supabase:

```bash
supabase db push --dry-run
```

관리자 페이지:

```bash
cd admin
npm ci
npm run build
```

주의:

- Flutter 의존성·SDK·환경 변수 파일이 없는 환경에서는 검사 실패 원인을 구분
- Vercel 성공만으로 Flutter Android 빌드 성공을 단정하지 않음
- UI, 지도, 권한, 푸시는 정적 분석 외에 실기기 QA 필요

---

## 18. 현재 확인이 필요한 항목

다음 항목은 문서만으로 완료 상태를 단정하지 않고 코드·원격 DB·실기기에서 확인한다.

- 최신 Android APK가 현재 `main` 코드로 빌드되었는지
- 원격 Supabase에 최신 migration이 모두 적용되었는지
- 자동 레이드 생성 스케줄과 Edge Function 배포 상태
- FCM 운영 환경과 푸시 outbox 처리 상태
- 지도 검색·역지오코딩 Edge Function 배포 상태
- 자동 레이드 출석 투표의 최종 집계 기준
- 포인트 보상과 불참 감점의 중복 방지
- 1대1 완료 RPC의 권한과 멱등성
- 실제 참가비 보관·환불·정산 RPC의 동작 범위
- 프리미엄 `isPremium` 테스트 계정 상태
- 프리미엄 Google Play 구독의 실제 미연동 상태 유지 여부
- 레거시 심부름 화면이 시연 중 노출되지 않는지
- iOS 프로젝트와 빌드 설정 상태
- 관리자 운동 장소 설정과 자동 레이드 생성 결과가 일치하는지

---

## 19. 현재 알려진 한계와 기술 부채

```text
1. 실제 Google Play 프리미엄 결제가 연결되지 않음
2. 실제 PG·금융 에스크로가 연결되지 않음
3. iOS 빌드와 플랫폼별 설정이 검증되지 않음
4. 학교·학원 사이의 여러 여유 시간대를 정밀하게 저장하지 않음
5. 기존 심부름 기능의 화면·라우트·관리자 페이지가 일부 남아 있음
6. 원격 Supabase migration과 로컬 파일의 일치 여부를 별도 확인해야 함
7. Flutter 앱 전체 CI 결과가 저장소 상태만으로 보장되지 않음
8. 지도·푸시·실시간 위치 기능은 외부 키와 실기기 환경에 의존함
```

대회 발표에서는 구현되지 않은 기능을 완료된 것처럼 설명하지 않는다.

---

## 20. 현재 우선순위

### 대회 제출·시연 단계

```text
1. 기능 추가보다 현재 흐름 안정화
2. 자동 레이드 참가와 상호 출석 확인 QA
3. 프리미엄 레이드 생성·신청·승인·완료 QA
4. 1대1 빠른 매칭·채팅·완료·포인트 QA
5. 시연용 계정과 레이드 데이터 준비
6. 보고서·영상·앱 문구 일치 확인
7. 소스 ZIP에서 실제 시크릿 제외 확인
8. main 브랜치와 제출 파일의 코드 일치 확인
```

### 대회 이후 개선 후보

```text
1. 실제 프리미엄 정기 구독 연동
2. 실제 PG 결제·환불·정산 구조 도입
3. iOS 프로젝트 설정과 App Store 배포 준비
4. 레거시 심부름 코드와 라우트 제거
5. 여러 활동 가능 시간대와 일정 제약 매칭
6. 자동 레이드 생성 규칙 고도화
7. 출석 투표 분쟁·이의제기 UX 개선
8. Flutter CI와 통합 테스트 강화
```

---

## 21. 작업 시작 체크리스트

```text
1. git status 확인
2. 현재 브랜치와 최신 commit 확인
3. 관련 화면·provider·repository·migration 함께 확인
4. 레이드 기능인지 레거시 심부름 기능인지 구분
5. DB 상태 변경은 RPC 우선
6. RLS와 정확한 위치 노출 범위 확인
7. 최소 변경으로 구현
8. format·analyze·test 실행
9. Android 실기기에서 핵심 흐름 QA
10. 변경 요약과 미검증 항목 기록
```

---

## 22. 기능별 수정 시 확인 범위

### 레이드 목록·상세

```text
raid_models.dart
raid_repository.dart
raid_providers.dart
raid_home_tab.dart
raid_browse_tab.dart
raid_detail_screen.dart
관련 migration
```

### 프리미엄 레이드 생성

```text
raid_create_tab.dart
premium_screen.dart
premium_constants.dart
create_premium_raid RPC
참가비·신청·승인 migration
```

### 1대1 빠른 매칭

```text
exercise_matching_models.dart
exercise_quick_match_screen.dart
exercise_quick_chat_screen.dart
exercise_location_service.dart
quick_match_live_map.dart
매칭·제안·완료 migration
match-tick Edge Function
```

### 출석과 포인트

```text
raid_detail_screen.dart
raid_reward_tab.dart
raid_models.dart
record_raid_attendance
cast_attendance_vote
finalize_raid
complete_exercise_quick_match
포인트·활동 요약 migration
```

### 채팅과 위치

```text
raid_chat_screen.dart
raid_application_chat_screen.dart
exercise_quick_chat_screen.dart
ChatAttachmentRepository
RaidLiveMap
QuickMatchLiveMap
Realtime 정책과 RLS
```

---

## 23. 갱신 규칙

다음 상황에서 이 문서를 갱신한다.

- 홈 탭과 라우팅 구조 변경
- 자동·프리미엄·1대1 매칭 흐름 변경
- 운동 선호 데이터 구조 변경
- 핵심 RPC 추가·삭제·이름 변경
- 출석과 포인트 정책 변경
- 참가비·환불·정산 구조 변경
- 프리미엄 결제 연동 상태 변경
- Supabase RLS와 위치 공개 정책 변경
- Android·iOS 배포 상태 변경
- 레거시 심부름 코드 제거
- 관리자 운동 장소와 자동 레이드 운영 방식 변경

완료된 기능을 기록할 때는 날짜만 적지 말고 다음을 함께 적는다.

```text
관련 코드 경로
관련 RPC와 migration
실제 QA 환경
성공·실패 결과
남은 제한 사항
```

# match-tick

매칭 단계를 한 칸 진행하거나, 시각이 지난 모든 요청을 일괄 진행하는 Edge Function.

## 배포

```bash
supabase functions deploy match-tick --no-verify-jwt
```

`--no-verify-jwt` 는 pg_cron / 클라이언트가 anon key 만 가지고 호출할 수 있도록 한 것이며,
내부에선 `SUPABASE_SERVICE_ROLE_KEY` 로 RPC 를 직접 호출한다.

## 사용

```bash
curl -X POST $SUPABASE_URL/functions/v1/match-tick \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -d '{"request_id":"<uuid>"}'
```

`request_id` 를 비우면 `tick_all_due_requests` 로 모든 due open 요청을 진행.

## 10단계 루프

요청 생성 시 `create_request_open` 이 즉시 1단계 매칭을 동기 호출하므로,
이 함수는 **이후 단계의 진행자** 역할만 한다.

운영에서는 둘 중 하나:

1. **pg_cron**: `cron.schedule('match-tick','* * * * *', $$select net.http_post(...)$$)`
   1분에 한 번 호출(15초 이하 지연을 원하면 클라이언트 보조 틱과 함께 사용).
2. **Database Webhook**: `requests` 의 `next_advance_at` 갱신을 트리거로 잡거나,
   Flutter 측에서 직접 호출.

## FCM

`notifications` INSERT·`requests`/`messages` 변경 시 `push_outbox` 에 적재되고,
`match-tick` 종료 시·`send-push` Edge·(설정 시) pg_net 이 **FCM HTTP v1** 으로 발송한다.

자세한 설정: [`../send-push/README.md`](../send-push/README.md)

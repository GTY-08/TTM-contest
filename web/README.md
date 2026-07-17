# TTM public website

The site is deployed from this directory. Its account modal uses the same
Supabase project as the Flutter app.

Required Vercel environment variables:

```text
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY
NEXBESIGN_IDENTITY_URL
MOBILEOK_IDENTITY_URL
```

`SUPABASE_PUBLISHABLE_KEY` must be a browser-safe publishable key. Never set a
secret or `service_role` key here. `NEXBESIGN_IDENTITY_URL` defaults to the
production bank-certificate verification page when omitted.
`MOBILEOK_IDENTITY_URL` defaults to the development PASS verification page
(`https://verify-dev.ttmttm.com/window_popup.html`) when omitted.

Supabase Auth must allow both production site URLs as email confirmation and
OAuth redirects:

```text
https://www.ttmttm.com/**
https://ttmttm.com/**
```

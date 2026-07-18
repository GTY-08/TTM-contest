import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type ReverseRegionPart = { name?: string };
type ReverseLand = {
  name?: string;
  number1?: string;
  number2?: string;
  addition0?: { value?: string };
  addition1?: { value?: string };
};
type ReverseResult = {
  name?: string;
  region?: {
    area1?: ReverseRegionPart;
    area2?: ReverseRegionPart;
    area3?: ReverseRegionPart;
    area4?: ReverseRegionPart;
  };
  land?: ReverseLand;
};

const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Connection": "keep-alive",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers });
}

function firstEnv(names: string[]) {
  for (const name of names) {
    const value = Deno.env.get(name) ?? "";
    if (value) return value;
  }
  return "";
}

function clean(parts: Array<string | undefined>) {
  return parts.map((part) => part?.trim() ?? "").filter(Boolean);
}

function formatResult(result: ReverseResult) {
  const region = result.region ?? {};
  const land = result.land ?? {};
  const number = clean([land.number1, land.number2]).join("-");
  const address = clean([
    region.area1?.name,
    region.area2?.name,
    region.area3?.name,
    region.area4?.name,
    land.name,
    number,
  ]).join(" ");
  const building = clean([
    land.addition0?.value,
    land.addition1?.value,
  ])[0];
  const label = building || land.name?.trim() || region.area3?.name?.trim() ||
    "선택한 운동 장소";
  return { label, address: address || label };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ ok: false, reason: "method_not_allowed" }, 405);
  }

  let latitude: number;
  let longitude: number;
  try {
    const body = await req.json();
    latitude = Number(body?.latitude);
    longitude = Number(body?.longitude);
  } catch (_) {
    return json({ ok: false, reason: "invalid_body" }, 400);
  }
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
    latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 ||
    (latitude === 0 && longitude === 0)) {
    return json({ ok: false, reason: "invalid_location" }, 400);
  }

  const clientId = firstEnv([
    "NAVER_MAP_CLIENT_ID",
    "NAVER_MAPS_CLIENT_ID",
    "NAVER_CLIENT_ID",
    "NCP_APIGW_API_KEY_ID",
    "X_NCP_APIGW_API_KEY_ID",
  ]);
  const clientSecret = firstEnv([
    "NAVER_MAP_CLIENT_SECRET",
    "NAVER_MAPS_CLIENT_SECRET",
    "NAVER_CLIENT_SECRET",
    "NCP_APIGW_API_KEY",
    "X_NCP_APIGW_API_KEY",
  ]);
  if (!clientId || !clientSecret) {
    return json({ ok: false, reason: "missing_naver_map_secret" }, 500);
  }

  const url = new URL(
    "https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc",
  );
  url.searchParams.set("coords", `${longitude},${latitude}`);
  url.searchParams.set("orders", "roadaddr,addr");
  url.searchParams.set("output", "json");

  try {
    const response = await fetch(url, {
      headers: {
        "X-NCP-APIGW-API-KEY-ID": clientId,
        "X-NCP-APIGW-API-KEY": clientSecret,
      },
    });
    if (!response.ok) {
      return json({ ok: false, reason: "naver_reverse_failed" }, 502);
    }
    const payload = await response.json();
    const results = Array.isArray(payload?.results)
      ? payload.results as ReverseResult[]
      : [];
    if (results.length === 0) {
      return json({ ok: false, reason: "location_not_found" }, 404);
    }
    const preferred = results.find((result) => result.name === "roadaddr") ??
      results[0];
    return json({ ok: true, ...formatResult(preferred) });
  } catch (_) {
    return json({ ok: false, reason: "reverse_lookup_unavailable" }, 502);
  }
});

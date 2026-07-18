import { useEffect, useMemo, useState } from 'react';

import { LoadingState } from '../components/LoadingState';
import { callRpc } from '../lib/supabase';

type VenueRow = {
  id: string;
  name: string;
  address: string;
  category: string;
  latitude: number;
  longitude: number;
  supported_exercises: string[];
  active_days: number[];
  auto_start_times: string[];
  default_duration_minutes: number;
  recommended_min_participants: number;
  max_participants: number;
  default_intensity: string;
  beginner_friendly: boolean;
  is_active: boolean;
};

type VenueForm = {
  id: string | null;
  name: string;
  address: string;
  category: string;
  latitude: string;
  longitude: string;
  exercises: string[];
  activeDays: number[];
  startTimes: string;
  durationMinutes: string;
  minParticipants: string;
  maxParticipants: string;
  intensity: string;
  beginnerFriendly: boolean;
  isActive: boolean;
};

const exerciseOptions = [
  ['walking', '걷기'],
  ['running', '러닝'],
  ['fitness', '맨몸 운동'],
  ['badminton', '배드민턴'],
  ['basketball', '농구'],
  ['soccer', '축구'],
  ['cycling', '자전거'],
] as const;

const dayOptions = [
  [1, '월'],
  [2, '화'],
  [3, '수'],
  [4, '목'],
  [5, '금'],
  [6, '토'],
  [7, '일'],
] as const;

const emptyForm: VenueForm = {
  id: null,
  name: '',
  address: '',
  category: 'sports_facility',
  latitude: '',
  longitude: '',
  exercises: ['walking', 'running'],
  activeDays: [1, 2, 3, 4, 5, 6, 7],
  startTimes: '07:00, 18:00',
  durationMinutes: '60',
  minParticipants: '3',
  maxParticipants: '12',
  intensity: 'medium',
  beginnerFriendly: true,
  isActive: true,
};

function normalizeVenue(value: unknown): VenueRow {
  const row = (value ?? {}) as Record<string, unknown>;
  return {
    id: String(row.id ?? ''),
    name: String(row.name ?? ''),
    address: String(row.address ?? ''),
    category: String(row.category ?? 'sports_facility'),
    latitude: Number(row.latitude ?? 0),
    longitude: Number(row.longitude ?? 0),
    supported_exercises: Array.isArray(row.supported_exercises)
      ? row.supported_exercises.map(String)
      : [],
    active_days: Array.isArray(row.active_days)
      ? row.active_days.map(Number)
      : [],
    auto_start_times: Array.isArray(row.auto_start_times)
      ? row.auto_start_times.map(String)
      : [],
    default_duration_minutes: Number(row.default_duration_minutes ?? 60),
    recommended_min_participants: Number(
      row.recommended_min_participants ?? 3,
    ),
    max_participants: Number(row.max_participants ?? 12),
    default_intensity: String(row.default_intensity ?? 'medium'),
    beginner_friendly: Boolean(row.beginner_friendly),
    is_active: Boolean(row.is_active),
  };
}

export function ExerciseVenuesPage() {
  const [venues, setVenues] = useState<VenueRow[]>([]);
  const [form, setForm] = useState<VenueForm>(emptyForm);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const selectedLabel = useMemo(
    () => (form.id ? '장소 수정' : '새 장소 등록'),
    [form.id],
  );

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const rows = await callRpc<unknown[]>('admin_list_exercise_venues');
      setVenues((rows ?? []).map(normalizeVenue));
    } catch (e) {
      setError(e instanceof Error ? e.message : '장소 목록을 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  function edit(row: VenueRow) {
    setNotice(null);
    setForm({
      id: row.id,
      name: row.name,
      address: row.address,
      category: row.category,
      latitude: String(row.latitude),
      longitude: String(row.longitude),
      exercises: row.supported_exercises,
      activeDays: row.active_days,
      startTimes: row.auto_start_times
        .map((time) => time.slice(0, 5))
        .join(', '),
      durationMinutes: String(row.default_duration_minutes),
      minParticipants: String(row.recommended_min_participants),
      maxParticipants: String(row.max_participants),
      intensity: row.default_intensity,
      beginnerFriendly: row.beginner_friendly,
      isActive: row.is_active,
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function toggleExercise(value: string) {
    setForm((current) => ({
      ...current,
      exercises: current.exercises.includes(value)
        ? current.exercises.filter((item) => item !== value)
        : [...current.exercises, value],
    }));
  }

  function toggleDay(value: number) {
    setForm((current) => ({
      ...current,
      activeDays: current.activeDays.includes(value)
        ? current.activeDays.filter((item) => item !== value)
        : [...current.activeDays, value].sort(),
    }));
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setNotice(null);

    const latitude = Number(form.latitude);
    const longitude = Number(form.longitude);
    const times = form.startTimes
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean);
    if (!form.name.trim() || !form.address.trim()) {
      setError('장소명과 주소를 입력해 주세요.');
      return;
    }
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      setError('올바른 위도와 경도를 입력해 주세요.');
      return;
    }
    if (form.exercises.length === 0 || form.activeDays.length === 0 || times.length === 0) {
      setError('지원 운동, 운영 요일, 자동 생성 시간을 하나 이상 선택해 주세요.');
      return;
    }

    setSaving(true);
    try {
      await callRpc('admin_upsert_exercise_venue', {
        p_id: form.id,
        p_name: form.name.trim(),
        p_address: form.address.trim(),
        p_category: form.category,
        p_lat: latitude,
        p_lng: longitude,
        p_supported_exercises: form.exercises,
        p_active_days: form.activeDays,
        p_auto_start_times: times,
        p_default_duration_minutes: Number(form.durationMinutes),
        p_recommended_min_participants: Number(form.minParticipants),
        p_max_participants: Number(form.maxParticipants),
        p_default_intensity: form.intensity,
        p_beginner_friendly: form.beginnerFriendly,
        p_is_active: form.isActive,
      });
      setNotice(form.id ? '장소를 수정했습니다.' : '새 장소를 등록했습니다.');
      setForm(emptyForm);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : '장소를 저장하지 못했습니다.');
    } finally {
      setSaving(false);
    }
  }

  if (loading && venues.length === 0) return <LoadingState />;

  return (
    <section className="page venue-page">
      <div className="page-title">
        <h2>레이드 장소 관리</h2>
        <p>앱 지도에 노출되고 자동 레이드가 열리는 고정 운동 장소를 관리합니다.</p>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {notice ? <p className="success-message">{notice}</p> : null}

      <form className="panel venue-form" onSubmit={(event) => void submit(event)}>
        <div className="section-header">
          <h3>{selectedLabel}</h3>
          <div className="row-actions">
            <a
              href={`https://map.naver.com/p/search/${encodeURIComponent(form.address || form.name || '운동장')}`}
              target="_blank"
              rel="noreferrer"
            >
              네이버 지도에서 확인
            </a>
            {form.id ? (
              <button type="button" onClick={() => setForm(emptyForm)}>
                새 장소 입력
              </button>
            ) : null}
          </div>
        </div>

        <div className="venue-field-grid">
          <label>
            장소명
            <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </label>
          <label>
            시설 분류
            <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
              <option value="sports_facility">체육 시설</option>
              <option value="park">공원</option>
              <option value="school">학교 운동장</option>
              <option value="trail">산책로</option>
            </select>
          </label>
          <label className="wide-field">
            주소
            <input value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
          </label>
          <label>
            위도
            <input inputMode="decimal" value={form.latitude} onChange={(e) => setForm({ ...form, latitude: e.target.value })} />
          </label>
          <label>
            경도
            <input inputMode="decimal" value={form.longitude} onChange={(e) => setForm({ ...form, longitude: e.target.value })} />
          </label>
        </div>

        <fieldset>
          <legend>지원 운동</legend>
          <div className="check-grid">
            {exerciseOptions.map(([value, label]) => (
              <label key={value}>
                <input type="checkbox" checked={form.exercises.includes(value)} onChange={() => toggleExercise(value)} />
                {label}
              </label>
            ))}
          </div>
        </fieldset>

        <fieldset>
          <legend>운영 요일</legend>
          <div className="check-grid compact">
            {dayOptions.map(([value, label]) => (
              <label key={value}>
                <input type="checkbox" checked={form.activeDays.includes(value)} onChange={() => toggleDay(value)} />
                {label}
              </label>
            ))}
          </div>
        </fieldset>

        <div className="venue-field-grid four">
          <label className="wide-field">
            자동 레이드 시작 시간
            <input value={form.startTimes} onChange={(e) => setForm({ ...form, startTimes: e.target.value })} placeholder="07:00, 18:00" />
            <small>여러 시간은 쉼표로 구분합니다.</small>
          </label>
          <label>
            운동 시간(분)
            <input type="number" min="20" max="240" value={form.durationMinutes} onChange={(e) => setForm({ ...form, durationMinutes: e.target.value })} />
          </label>
          <label>
            최소 인원
            <input type="number" min="3" max="100" value={form.minParticipants} onChange={(e) => setForm({ ...form, minParticipants: e.target.value })} />
          </label>
          <label>
            최대 인원
            <input type="number" min="3" max="200" value={form.maxParticipants} onChange={(e) => setForm({ ...form, maxParticipants: e.target.value })} />
          </label>
          <label>
            기본 강도
            <select value={form.intensity} onChange={(e) => setForm({ ...form, intensity: e.target.value })}>
              <option value="low">가볍게</option>
              <option value="medium">보통</option>
              <option value="high">강하게</option>
            </select>
          </label>
        </div>

        <div className="check-grid status-options">
          <label>
            <input type="checkbox" checked={form.beginnerFriendly} onChange={(e) => setForm({ ...form, beginnerFriendly: e.target.checked })} />
            초보자 참여 가능
          </label>
          <label>
            <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} />
            앱에 장소 노출
          </label>
        </div>

        <button className="primary-button venue-submit" type="submit" disabled={saving}>
          {saving ? '저장 중...' : selectedLabel}
        </button>
      </form>

      <div className="venue-list-head">
        <h3>등록된 장소 {venues.length}개</h3>
        <button type="button" onClick={() => void load()}>새로고침</button>
      </div>
      <div className="venue-card-grid">
        {venues.map((venue) => (
          <article className={`venue-card ${venue.is_active ? '' : 'inactive'}`} key={venue.id}>
            <div>
              <span className={`status ${venue.is_active ? 'success' : ''}`}>
                {venue.is_active ? '운영 중' : '숨김'}
              </span>
              <h3>{venue.name}</h3>
              <p>{venue.address}</p>
            </div>
            <dl>
              <dt>좌표</dt><dd>{venue.latitude.toFixed(5)}, {venue.longitude.toFixed(5)}</dd>
              <dt>지원 운동</dt><dd>{venue.supported_exercises.join(', ')}</dd>
              <dt>자동 시작</dt><dd>{venue.auto_start_times.map((time) => time.slice(0, 5)).join(', ')}</dd>
              <dt>정원</dt><dd>{venue.recommended_min_participants}~{venue.max_participants}명</dd>
            </dl>
            <button type="button" onClick={() => edit(venue)}>수정</button>
          </article>
        ))}
      </div>
    </section>
  );
}

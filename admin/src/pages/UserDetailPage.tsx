import { FormEvent, useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { LoadingState } from '../components/LoadingState';
import { FieldGrid, RecordList } from '../components/ReadableData';
import {
  durationLabel,
  durationToEndsAt,
  RestrictionDurationPicker,
  type RestrictionDurationHours,
} from '../components/RestrictionDurationPicker';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate, shortId, toText } from '../lib/format';
import {
  effectiveRestrictionStatus,
  isActiveRestriction,
  restrictionStatusLabel,
  restrictionTypeLabel,
  restrictionTypes,
} from '../lib/restrictions';
import { callRpc } from '../lib/supabase';
import type { JsonMap } from '../types/admin';

type RestrictionForm = {
  type: string;
  reason: string;
  durationHours: RestrictionDurationHours;
};

const initialForm: RestrictionForm = {
  type: 'warning',
  reason: '',
  durationHours: 48,
};

export function UserDetailPage() {
  const { id } = useParams();
  const [detail, setDetail] = useState<JsonMap | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [form, setForm] = useState<RestrictionForm>(initialForm);

  async function load() {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<{ detail: JsonMap }>('admin_get_user_detail', {
        p_user_id: id,
      });
      setDetail(data.detail);
    } catch (e) {
      setError(e instanceof Error ? e.message : '사용자 상세를 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const restrictions = useMemo(
    () => (Array.isArray(detail?.restrictions) ? (detail.restrictions as JsonMap[]) : []),
    [detail],
  );
  const activeRestrictions = restrictions.filter((item) => isActiveRestriction(item));
  const profile = (detail?.profile ?? {}) as JsonMap;

  async function createRestriction(event: FormEvent) {
    event.preventDefault();
    if (!id || saving) return;
    if (!form.reason.trim()) {
      setError('제재 사유를 입력해 주세요.');
      return;
    }

    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      await callRpc('admin_create_user_restriction', {
        p_user_id: id,
        p_restriction_type: form.type,
        p_reason: form.reason.trim(),
        p_ends_at: durationToEndsAt(form.durationHours),
      });
      setForm(initialForm);
      setNotice('제재를 생성했습니다.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : '제재 생성에 실패했습니다.');
    } finally {
      setSaving(false);
    }
  }

  async function revokeRestriction(restrictionId: unknown) {
    if (saving) return;
    const idText = String(restrictionId ?? '');
    if (!idText) {
      setError('해제할 제재 ID가 없습니다.');
      return;
    }

    const reason = window.prompt('해제 사유를 입력하세요. 비워도 해제할 수 있습니다.');
    if (reason === null) return;
    if (!window.confirm('이 제재를 해제하시겠습니까?')) return;

    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      await callRpc('admin_revoke_user_restriction', {
        p_restriction_id: idText,
        p_reason: reason.trim() ? reason.trim() : null,
      });
      setNotice('제재를 해제했습니다.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : '제재 해제에 실패했습니다.');
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <LoadingState />;

  return (
    <section className="page">
      <div className="page-title">
        <Link to="/users">사용자 목록</Link>
        <h2>사용자 상세</h2>
        <p>{id}</p>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {notice ? <p className="success-message">{notice}</p> : null}

      <div className="detail-grid">
        <article className="panel">
          <h3>프로필</h3>
          <FieldGrid
            fields={[
              { label: '닉네임', value: profile.nickname },
              { label: '이메일', value: profile.email },
              { label: '전화번호', value: profile.phone },
              { label: '평점', value: `${toText(profile.rating)} (${toText(profile.rating_count)})` },
              { label: '가입일', value: profile.created_at, type: 'date' },
            ]}
          />
        </article>

        <article className="panel">
          <h3>적용 중인 제재</h3>
          {activeRestrictions.length === 0 ? (
            <p className="muted">현재 적용 중인 제재가 없습니다.</p>
          ) : (
            <div className="restriction-stack">
              {activeRestrictions.map((item) => (
                <RestrictionCard
                  key={String(item.id)}
                  item={item}
                  saving={saving}
                  onRevoke={revokeRestriction}
                />
              ))}
            </div>
          )}
        </article>

        <article className="panel wide">
          <h3>새 제재 생성</h3>
          <form className="restriction-form" onSubmit={createRestriction}>
            <label>
              제재 유형
              <select
                value={form.type}
                onChange={(event) => setForm((prev) => ({ ...prev, type: event.target.value }))}
              >
                {restrictionTypes.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
            </label>
            <label className="wide-field">
              사유
              <textarea
                value={form.reason}
                onChange={(event) => setForm((prev) => ({ ...prev, reason: event.target.value }))}
                placeholder="운영자가 추후 봐도 이해할 수 있게 구체적으로 입력"
                rows={3}
              />
            </label>
            <label>
              적용 기간
              <RestrictionDurationPicker
                value={form.durationHours}
                onChange={(durationHours) => setForm((prev) => ({ ...prev, durationHours }))}
              />
            </label>
            <button className="primary-button" type="submit" disabled={saving}>
              {saving ? '처리 중...' : `${restrictionTypeLabel(form.type)} ${durationLabel(form.durationHours)} 적용`}
            </button>
          </form>
          <div className="restriction-help">
            {restrictionTypes.map((item) => (
              <p key={item.value}>
                <strong>{item.label}</strong>
                <span>{item.description}</span>
              </p>
            ))}
          </div>
        </article>

        <article className="panel wide">
          <h3>전체 제재 이력</h3>
          {restrictions.length === 0 ? (
            <p className="muted">제재 이력이 없습니다.</p>
          ) : (
            <div className="restriction-stack">
              {restrictions.map((item) => (
                <RestrictionCard
                  key={String(item.id)}
                  item={item}
                  saving={saving}
                  onRevoke={revokeRestriction}
                />
              ))}
            </div>
          )}
        </article>

        <article className="panel wide">
          <h3>활동 이력</h3>
          <RecordList title="요청 이력" rows={detail?.request_history ?? []} />
          <RecordList title="작업 이력" rows={detail?.work_history ?? []} />
          <RecordList title="후기" rows={detail?.reviews ?? []} />
        </article>

        <article className="panel wide">
          <h3>신고 및 취소 이력</h3>
          <RecordList title="사용자 신고" rows={detail?.user_reports ?? []} />
          <RecordList title="메시지 신고" rows={detail?.message_reports ?? []} />
          <RecordList title="취소 이력" rows={detail?.cancel_events ?? []} />
        </article>
      </div>
    </section>
  );
}

function RestrictionCard({
  item,
  saving,
  onRevoke,
}: {
  item: JsonMap;
  saving: boolean;
  onRevoke: (restrictionId: unknown) => void;
}) {
  const effectiveStatus = effectiveRestrictionStatus(item);
  const active = effectiveStatus === 'active';

  return (
    <div className={`restriction-card ${active ? 'active' : 'inactive'}`}>
      <div>
        <div className="restriction-card-title">
          <strong>{restrictionTypeLabel(item.restriction_type)}</strong>
          <StatusBadge status={restrictionStatusLabel(effectiveStatus)} />
        </div>
        <p>{toText(item.reason)}</p>
        <small>
          ID {shortId(item.id)} · 생성 {formatDate(item.created_at)} · 종료 {formatDate(item.ends_at)}
          {item.revoked_at ? ` · 해제 ${formatDate(item.revoked_at)}` : ''}
        </small>
      </div>
      {active ? (
        <button type="button" disabled={saving} onClick={() => onRevoke(item.id)}>
          제재 해제
        </button>
      ) : null}
    </div>
  );
}

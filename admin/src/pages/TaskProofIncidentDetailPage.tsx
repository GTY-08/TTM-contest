import { FormEvent, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { FieldGrid, KeyValueList, RecordList } from '../components/ReadableData';
import {
  durationLabel,
  durationToEndsAt,
  RestrictionDurationPicker,
  type RestrictionDurationHours,
} from '../components/RestrictionDurationPicker';
import { LoadingState } from '../components/LoadingState';
import { StatusBadge } from '../components/StatusBadge';
import { restrictionTypeLabel, restrictionTypes } from '../lib/restrictions';
import { callRpc, supabase } from '../lib/supabase';
import type { JsonMap } from '../types/admin';
import { incidentTypeLabel, sourceLabel } from './TaskProofIncidentsPage';

export function TaskProofIncidentDetailPage() {
  const { id } = useParams();
  const [detail, setDetail] = useState<JsonMap | null>(null);
  const [signedImageUrl, setSignedImageUrl] = useState<string | null>(null);
  const [restrictionType, setRestrictionType] = useState('warning');
  const [durationHours, setDurationHours] = useState<RestrictionDurationHours>(72);
  const [note, setNote] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function load() {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<JsonMap>('admin_get_task_proof_incident', {
        p_incident_id: id,
      });
      setDetail(data);
      const proof = data.proof as JsonMap | undefined;
      const path = String(proof?.image_url ?? '');
      if (path) {
        const { data: signed, error: signError } = await supabase.storage
          .from('task_proofs')
          .createSignedUrl(path, 3600);
        if (signError) throw signError;
        setSignedImageUrl(signed.signedUrl);
      } else {
        setSignedImageUrl(null);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : '인증 사건을 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  async function resolve(action: 'resolved' | 'dismissed', applyRestriction: boolean) {
    if (!id || !note.trim()) {
      setError('처리 근거를 입력해 주세요.');
      return;
    }
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      await callRpc('admin_resolve_task_proof_incident', {
        p_incident_id: id,
        p_action: action,
        p_admin_note: note.trim(),
        p_restriction_type: applyRestriction ? restrictionType : null,
        p_restriction_ends_at: applyRestriction ? durationToEndsAt(durationHours) : null,
      });
      setNotice(action === 'dismissed' ? '사건을 기각했습니다.' : '사건 처리와 제재 적용을 완료했습니다.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : '사건 처리에 실패했습니다.');
    } finally {
      setSaving(false);
    }
  }

  function submitRestriction(event: FormEvent) {
    event.preventDefault();
    void resolve('resolved', true);
  }

  if (loading) return <LoadingState />;
  const incident = detail?.incident as JsonMap | undefined;
  const proof = detail?.proof as JsonMap | undefined;

  return (
    <section className="page">
      <div className="page-title">
        <Link to="/proof-incidents">작업 인증 사건</Link>
        <h2>{incidentTypeLabel(incident?.incident_type)}</h2>
        <p>사진과 누적 이력을 확인한 뒤 기각하거나 제재를 적용합니다.</p>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {notice ? <p className="success-message">{notice}</p> : null}

      <div className="detail-grid">
        <article className="panel">
          <h3>사건 정보</h3>
          <FieldGrid
            fields={[
              { label: '상태', value: <StatusBadge status={incident?.status} /> },
              { label: '발생 경로', value: sourceLabel(incident?.source) },
              { label: '사유', value: incident?.reason },
              { label: '인증 기한', value: incident?.due_at, type: 'date' },
              { label: '발생일', value: incident?.created_at, type: 'date' },
              { label: '관리자 메모', value: incident?.admin_note },
            ]}
          />
        </article>

        <article className="panel">
          <h3>작업자</h3>
          <KeyValueList data={detail?.worker as JsonMap | undefined} />
        </article>

        <article className="panel wide">
          <h3>반려된 인증 사진</h3>
          {signedImageUrl ? (
            <a href={signedImageUrl} target="_blank" rel="noreferrer">
              <img className="proof-evidence-image" src={signedImageUrl} alt="반려된 작업 인증" />
            </a>
          ) : (
            <p className="muted">기한 누락 사건에는 제출 사진이 없습니다.</p>
          )}
          {proof ? <KeyValueList data={proof} /> : null}
        </article>

        <article className="panel wide">
          <h3>수동 제재</h3>
          <form className="restriction-form" onSubmit={submitRestriction}>
            <label>
              제재 유형
              <select value={restrictionType} onChange={(event) => setRestrictionType(event.target.value)}>
                {restrictionTypes.map((item) => (
                  <option key={item.value} value={item.value}>{item.label}</option>
                ))}
              </select>
            </label>
            <label className="wide-field">
              처리 근거
              <textarea value={note} onChange={(event) => setNote(event.target.value)} rows={3} />
            </label>
            <label>
              적용 기간
              <RestrictionDurationPicker value={durationHours} onChange={setDurationHours} />
            </label>
            <button className="primary-button" type="submit" disabled={saving}>
              {saving ? '처리 중' : `${restrictionTypeLabel(restrictionType)} ${durationLabel(durationHours)} 적용`}
            </button>
          </form>
          <div className="action-row">
            <button type="button" disabled={saving} onClick={() => void resolve('dismissed', false)}>
              제재 없이 기각
            </button>
          </div>
        </article>

        <article className="panel wide">
          <h3>관련 요청 및 누적 사건</h3>
          <KeyValueList data={detail?.request as JsonMap | undefined} />
          <RecordList title="최근 인증 사건" rows={(detail?.recent_incidents as JsonMap[]) ?? []} />
        </article>
      </div>
    </section>
  );
}

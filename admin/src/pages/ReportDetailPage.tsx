import { FormEvent, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { LoadingState } from '../components/LoadingState';
import { ChatTranscript, FieldGrid, KeyValueList, RecordList } from '../components/ReadableData';
import {
  durationLabel,
  durationToEndsAt,
  RestrictionDurationPicker,
  type RestrictionDurationHours,
} from '../components/RestrictionDurationPicker';
import { StatusBadge } from '../components/StatusBadge';
import { restrictionTypeLabel, restrictionTypes } from '../lib/restrictions';
import { callRpc } from '../lib/supabase';
import type { JsonMap } from '../types/admin';
import { reportTypeLabel } from './ReportsPage';

const statuses = [
  ['reviewing', '검토 중'],
  ['resolved', '처리 완료'],
  ['dismissed', '기각'],
] as const;

export function ReportDetailPage() {
  const { type, id } = useParams();
  const [detail, setDetail] = useState<JsonMap | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [restrictionType, setRestrictionType] = useState('warning');
  const [restrictionReason, setRestrictionReason] = useState('');
  const [durationHours, setDurationHours] = useState<RestrictionDurationHours>(48);

  async function load() {
    if (!type || !id) return;
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<{ detail: JsonMap }>('admin_get_report_detail', {
        p_report_type: type,
        p_report_id: id,
      });
      setDetail(data.detail);
    } catch (e) {
      setError(e instanceof Error ? e.message : '신고 상세를 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [type, id]);

  async function updateStatus(status: string) {
    if (!type || !id || saving) return;
    const note = window.prompt('관리자 메모를 입력하세요.');
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      await callRpc('admin_update_report_status', {
        p_report_type: type,
        p_report_id: id,
        p_status: status,
        p_admin_note: note,
      });
      setNotice('신고 상태를 변경했습니다.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : '신고 상태 변경에 실패했습니다.');
    } finally {
      setSaving(false);
    }
  }

  async function restrictReportedUser(event: FormEvent) {
    event.preventDefault();
    if (saving) return;
    const report = detail?.report as JsonMap | undefined;
    const reportedUserId = report?.reported_user_id;
    if (!reportedUserId) return;
    if (!restrictionReason.trim()) {
      setError('제재 사유를 입력해 주세요.');
      return;
    }
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      await callRpc('admin_create_user_restriction', {
        p_user_id: reportedUserId,
        p_restriction_type: restrictionType,
        p_reason: restrictionReason.trim(),
        p_ends_at: durationToEndsAt(durationHours),
      });
      setNotice('신고 대상자에게 제재를 적용했습니다.');
      setRestrictionReason('');
    } catch (e) {
      setError(e instanceof Error ? e.message : '제재 적용에 실패했습니다.');
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <LoadingState />;
  const report = detail?.report as JsonMap | undefined;

  return (
    <section className="page">
      <div className="page-title">
        <Link to="/reports">신고 목록</Link>
        <h2>신고 상세</h2>
        <p>
          {reportTypeLabel(type)} / {id}
        </p>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {notice ? <p className="success-message">{notice}</p> : null}

      <div className="action-row">
        {statuses.map(([status, label]) => (
          <button key={status} type="button" disabled={saving} onClick={() => void updateStatus(status)}>
            {label}
          </button>
        ))}
      </div>

      <div className="detail-grid">
        <article className="panel">
          <h3>신고 내용</h3>
          <FieldGrid
            fields={[
              { label: '유형', value: reportTypeLabel(detail?.report_type) },
              { label: '상태', value: <StatusBadge status={report?.status} /> },
              { label: '분류', value: report?.category },
              { label: '설명', value: report?.description },
              { label: '신고 당시 메시지', value: report?.message_snapshot },
              { label: '접수일', value: report?.created_at, type: 'date' },
              { label: '검토일', value: report?.reviewed_at, type: 'date' },
              { label: '관리자 메모', value: report?.admin_note },
            ]}
          />
        </article>

        <article className="panel">
          <h3>신고자 / 대상자</h3>
          <KeyValueList title="신고자" data={detail?.reporter as JsonMap | undefined} />
          <KeyValueList title="대상자" data={detail?.reported_user as JsonMap | undefined} />
        </article>

        <article className="panel wide">
          <h3>대상자 제재</h3>
          <form className="restriction-form" onSubmit={restrictReportedUser}>
            <label>
              제재 유형
              <select value={restrictionType} onChange={(event) => setRestrictionType(event.target.value)}>
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
                value={restrictionReason}
                onChange={(event) => setRestrictionReason(event.target.value)}
                placeholder="신고 내용과 처리 근거를 입력"
                rows={3}
              />
            </label>
            <label>
              적용 기간
              <RestrictionDurationPicker value={durationHours} onChange={setDurationHours} />
            </label>
            <button className="primary-button" type="submit" disabled={saving}>
              {saving ? '처리 중...' : `${restrictionTypeLabel(restrictionType)} ${durationLabel(durationHours)} 적용`}
            </button>
          </form>
        </article>

        <article className="panel wide">
          <h3>관련 요청</h3>
          <KeyValueList data={detail?.request as JsonMap | undefined} />
        </article>

        <article className="panel wide">
          <h3>채팅방 전체 대화</h3>
          <ChatTranscript rows={detail?.messages ?? []} />
        </article>

        <article className="panel wide">
          <h3>취소 및 최근 신고 이력</h3>
          <RecordList title="취소 이력" rows={detail?.cancel_events ?? []} />
          <RecordList title="대상자 최근 신고" rows={detail?.recent_reports_for_user ?? []} />
        </article>
      </div>
    </section>
  );
}

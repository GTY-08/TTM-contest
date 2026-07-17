import { formatNumber } from '../lib/format';

export function MetricCard({
  label,
  value,
  tone = 'neutral',
}: {
  label: string;
  value: unknown;
  tone?: 'neutral' | 'success' | 'warning' | 'danger';
}) {
  return (
    <div className={`metric-card ${tone}`}>
      <span>{label}</span>
      <strong>{formatNumber(value)}</strong>
    </div>
  );
}

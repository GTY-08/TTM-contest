export type RestrictionDurationHours = number | null;

type Unit = 'hours' | 'days' | 'months';

const maxHours = 24 * 365;

const presets: Array<{ label: string; hours: RestrictionDurationHours }> = [
  { label: '무기한', hours: null },
  { label: '12시간', hours: 12 },
  { label: '48시간', hours: 48 },
  { label: '7일', hours: 24 * 7 },
  { label: '14일', hours: 24 * 14 },
  { label: '30일', hours: 24 * 30 },
  { label: '3개월', hours: 24 * 30 * 3 },
  { label: '6개월', hours: 24 * 30 * 6 },
  { label: '1년', hours: maxHours },
];

const unitOptions: Array<{ value: Unit; label: string; multiplier: number }> = [
  { value: 'hours', label: '시간', multiplier: 1 },
  { value: 'days', label: '일', multiplier: 24 },
  { value: 'months', label: '개월', multiplier: 24 * 30 },
];

export function durationToEndsAt(hours: RestrictionDurationHours): string | null {
  if (hours === null) return null;
  const normalized = clampHours(hours);
  return new Date(Date.now() + normalized * 60 * 60 * 1000).toISOString();
}

export function durationLabel(hours: RestrictionDurationHours): string {
  if (hours === null) return '무기한';
  const normalized = clampHours(hours);
  if (normalized < 24) return `${normalized}시간`;
  if (normalized % (24 * 30) === 0) return `${normalized / (24 * 30)}개월`;
  if (normalized % 24 === 0) return `${normalized / 24}일`;
  return `${normalized}시간`;
}

export function RestrictionDurationPicker({
  value,
  onChange,
}: {
  value: RestrictionDurationHours;
  onChange: (value: RestrictionDurationHours) => void;
}) {
  const unit = bestUnit(value);
  const unitMeta = unitOptions.find((item) => item.value === unit) ?? unitOptions[0];
  const numericValue = value === null ? '' : Math.max(1, Math.round(value / unitMeta.multiplier));
  const sliderValue = value === null ? 0 : clampHours(value);

  function setNumeric(nextValue: string, nextUnit = unit) {
    if (!nextValue.trim()) {
      onChange(null);
      return;
    }
    const amount = Number(nextValue);
    if (!Number.isFinite(amount) || amount <= 0) return;
    const meta = unitOptions.find((item) => item.value === nextUnit) ?? unitOptions[0];
    onChange(clampHours(Math.round(amount * meta.multiplier)));
  }

  return (
    <div className="duration-picker">
      <div className="duration-picker-head">
        <strong>제재 기간</strong>
        <span>{durationLabel(value)}</span>
      </div>

      <div className="duration-ticks" aria-label="빠른 기간 선택">
        {presets.map((item) => (
          <button
            type="button"
            key={item.label}
            className={item.hours === value ? 'active' : ''}
            onClick={() => onChange(item.hours)}
          >
            {item.label}
          </button>
        ))}
      </div>

      <div className="duration-direct">
        <input
          type="number"
          min={1}
          value={numericValue}
          placeholder="직접 입력"
          onChange={(event) => setNumeric(event.target.value)}
        />
        <select
          value={unit}
          onChange={(event) => {
            const nextUnit = event.target.value as Unit;
            if (value === null) return;
            setNumeric(String(numericValue || 1), nextUnit);
          }}
        >
          {unitOptions.map((item) => (
            <option key={item.value} value={item.value}>
              {item.label}
            </option>
          ))}
        </select>
        <button type="button" onClick={() => onChange(null)}>
          무기한
        </button>
      </div>

      <input
        type="range"
        min={1}
        max={maxHours}
        step={1}
        value={sliderValue || 1}
        disabled={value === null}
        onChange={(event) => onChange(clampHours(Number(event.target.value)))}
      />
      <small className="duration-help">
        슬라이더는 1시간 단위로 조정됩니다. 숫자 입력으로 시간, 일, 개월 단위를 직접 지정할 수 있습니다.
      </small>
    </div>
  );
}

function clampHours(value: number): number {
  return Math.max(1, Math.min(maxHours, Math.round(value)));
}

function bestUnit(value: RestrictionDurationHours): Unit {
  if (value === null) return 'hours';
  if (value >= 24 * 30 && value % (24 * 30) === 0) return 'months';
  if (value >= 24 && value % 24 === 0) return 'days';
  return 'hours';
}

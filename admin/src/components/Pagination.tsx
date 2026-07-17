export function Pagination({
  page,
  total,
  pageSize,
  onPageChange,
}: {
  page: number;
  total: number;
  pageSize: number;
  onPageChange: (page: number) => void;
}) {
  const lastPage = Math.max(0, Math.ceil(total / pageSize) - 1);

  return (
    <div className="pagination">
      <button type="button" disabled={page <= 0} onClick={() => onPageChange(page - 1)}>
        이전
      </button>
      <span>
        {page + 1} / {lastPage + 1}
      </span>
      <button
        type="button"
        disabled={page >= lastPage}
        onClick={() => onPageChange(page + 1)}
      >
        다음
      </button>
    </div>
  );
}

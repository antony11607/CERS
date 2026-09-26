export default function DataTable({ columns, rows, emptyMessage = 'No data available.' }) {
  if (!rows || rows.length === 0) {
    return (
      <div className="flex min-h-[160px] items-center justify-center rounded-2xl border border-dashed border-[#e7dede] bg-[#fdfbfb] text-sm text-[#7c7c7c]">
        {emptyMessage}
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-2xl border border-[#ece8e8] bg-white">
      <table className="min-w-full text-left text-sm">
        <thead className="bg-[#faf7f7] text-[#6f6f6f]">
          <tr>
            {columns.map((column) => (
              <th key={column.key} className="px-4 py-3 font-medium">
                {column.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={row.id || rowIndex} className="border-t border-[#f1ecec]">
              {columns.map((column) => (
                <td key={`${row.id || rowIndex}-${column.key}`} className="px-4 py-3 align-middle text-[#2b2b2b]">
                  {column.render ? column.render(row[column.key], row) : row[column.key] ?? '—'}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

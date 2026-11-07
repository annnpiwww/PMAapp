/// Neutralizes spreadsheet formula injection (CSV/Excel/Google Sheets) by
/// prefixing a single quote `'` when the cell value starts with `=`, `+`, `-`,
/// `@`, `\t` (tab), or `\r` (carriage return).
String escapeSpreadsheetCell(String v) {
  if (v.isEmpty) return v;
  final first = v[0];
  if (first == '=' ||
      first == '+' ||
      first == '-' ||
      first == '@' ||
      first == '\t' ||
      first == '\r') {
    return "'$v";
  }
  return v;
}

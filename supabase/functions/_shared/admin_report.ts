// Pure helpers for admin_pos 'Lapor Error' report validation, message formatting,
// and byte-identical Dart ErrorReport.toDeskripsi port.
// Contract: docs/contracts/admin-lapor.md

export interface ValidatedAdminReport {
  tanggal: string; // dd-MM-yyyy
  tanggalIso: string; // yyyy-MM-dd
  waktu: string; // HH.mm
  kendala: string;
  penyebab: string; // '-' when empty
  solusi_sementara: string; // '-' when empty
  durasi_error: string; // '-' when empty
  ada_foto: boolean;
}

export type ValidateReportResult =
  | { ok: true; report: ValidatedAdminReport }
  | { ok: false; field: string };

const DATE_DD_MM_YYYY = /^(\d{2})-(\d{2})-(\d{4})$/;
const TIME_HH_MM = /^(\d{2})\.(\d{2})$/;
// Control characters (C0 + DEL), after rejecting bare \r lines
// deno-lint-ignore no-control-regex
const CONTROL_CHARS_REGEX = /[\x00-\x1F\x7F]+/g;

function cleanStringField(raw: unknown): { ok: true; value: string } | { ok: false } {
  if (typeof raw !== 'string') return { ok: false };
  // Reject \r-only lines or bare carriage returns
  if (/\r(?!\n)/.test(raw)) return { ok: false };
  const normalized = raw
    .replace(/\r\n/g, ' ')
    .replace(/[\n\t]/g, ' ')
    .replace(CONTROL_CHARS_REGEX, '')
    .trim();
  return { ok: true, value: normalized };
}

export function validateReport(raw: unknown): ValidateReportResult {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { ok: false, field: 'report' };
  }
  const obj = raw as Record<string, unknown>;

  const tglClean = cleanStringField(obj.tanggal);
  if (!tglClean.ok) return { ok: false, field: 'tanggal' };
  const dMatch = DATE_DD_MM_YYYY.exec(tglClean.value);
  if (!dMatch) return { ok: false, field: 'tanggal' };
  const day = Number(dMatch[1]);
  const month = Number(dMatch[2]);
  const year = Number(dMatch[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31 || year < 2000 || year > 2100) {
    return { ok: false, field: 'tanggal' };
  }
  const dt = new Date(Date.UTC(year, month - 1, day));
  if (
    dt.getUTCFullYear() !== year ||
    dt.getUTCMonth() !== month - 1 ||
    dt.getUTCDate() !== day
  ) {
    return { ok: false, field: 'tanggal' };
  }
  const tanggalIso = `${dMatch[3]}-${dMatch[2]}-${dMatch[1]}`;

  const wktClean = cleanStringField(obj.waktu);
  if (!wktClean.ok) return { ok: false, field: 'waktu' };
  const tMatch = TIME_HH_MM.exec(wktClean.value);
  if (!tMatch) return { ok: false, field: 'waktu' };
  const hour = Number(tMatch[1]);
  const minute = Number(tMatch[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return { ok: false, field: 'waktu' };
  }

  const kendalaClean = cleanStringField(obj.kendala);
  if (
    !kendalaClean.ok ||
    kendalaClean.value.length < 1 ||
    kendalaClean.value.length > 300 ||
    kendalaClean.value === '-'
  ) {
    return { ok: false, field: 'kendala' };
  }

  const optionalFields = ['penyebab', 'solusi_sementara', 'durasi_error'] as const;
  const optValues: Record<typeof optionalFields[number], string> = {
    penyebab: '-',
    solusi_sementara: '-',
    durasi_error: '-',
  };

  for (const key of optionalFields) {
    const rawVal = obj[key];
    if (rawVal === undefined || rawVal === null) {
      optValues[key] = '-';
      continue;
    }
    const cleaned = cleanStringField(rawVal);
    if (!cleaned.ok || cleaned.value.length > 300) {
      return { ok: false, field: key };
    }
    optValues[key] = cleaned.value.length > 0 ? cleaned.value : '-';
  }

  if (typeof obj.ada_foto !== 'boolean') {
    return { ok: false, field: 'ada_foto' };
  }

  return {
    ok: true,
    report: {
      tanggal: tglClean.value,
      tanggalIso,
      waktu: wktClean.value,
      kendala: kendalaClean.value,
      penyebab: optValues.penyebab,
      solusi_sementara: optValues.solusi_sementara,
      durasi_error: optValues.durasi_error,
      ada_foto: obj.ada_foto,
    },
  };
}

export function salam(waktu: string): string {
  const m = /^(\d{1,2})[:.](\d{2})$/.exec(waktu.trim());
  const hour = m ? Number(m[1]) : 0;
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}

export function buildAdminMessage(
  report: {
    tanggal: string;
    waktu: string;
    kendala: string;
    penyebab?: string;
    solusi_sementara?: string;
    durasi_error?: string;
    ada_foto: boolean;
  },
  posName: string,
): string {
  const greeting = salam(report.waktu);
  const loc = posName.trim();
  const kendala = report.kendala.trim();
  const penyebab = (report.penyebab ?? '').trim() || '-';
  const solusi = (report.solusi_sementara ?? '').trim() || '-';
  const durasi = (report.durasi_error ?? '').trim() || '-';

  const lines = [
    `${greeting}, izin melaporkan, telah terjadi kendala dengan kronologi sebagai berikut:`,
    '',
    `Tanggal : ${report.tanggal.trim()}`,
    `Waktu : ${report.waktu.trim()}`,
    '',
    `Lokasi : ${loc}`,
    '',
    `Kendala : ${kendala}`,
    '',
    `Penyebab : ${penyebab}`,
    '',
    `Solusi sementara : ${solusi}`,
    '',
    `Durasi Error : ${durasi}`,
  ];

  if (report.ada_foto) {
    lines.push('', 'Berikut kami lampirkan dokumentasi kerusakan.');
  }
  lines.push('', 'Terima kasih.');

  return lines.join('\n');
}

export function buildDeskripsi(
  message: string,
  posName: string,
  report: {
    tanggal: string;
    waktu: string;
    kendala: string;
    penyebab?: string;
    solusi_sementara?: string;
  },
): string {
  const lines: string[] = [];
  const tgl = report.tanggal.trim();
  const wkt = report.waktu.trim();
  if (tgl.length > 0 && wkt.length > 0) {
    lines.push(`Tanggal : ${tgl}`);
    lines.push(`Waktu : ${wkt}`);
  }
  const loc = posName.trim();
  if (loc.length > 0) lines.push(`Lokasi : ${loc}`);
  const k = report.kendala.trim();
  if (k.length > 0 && k !== '-') lines.push(`Kendala : ${k}`);
  const p = (report.penyebab ?? '').trim();
  if (p.length > 0 && p !== '-') lines.push(`Penyebab : ${p}`);
  const s = (report.solusi_sementara ?? '').trim();
  if (s.length > 0 && s !== '-') lines.push(`Solusi sementara : ${s}`);

  const header = lines.join('\n');
  const orig = message.trim();
  if (orig.length === 0) return header;
  if (header.length === 0) {
    return orig.length > 2000 ? orig.slice(0, 2000) : orig;
  }

  const prefix = `${header}\n\n`;
  const available = 2000 - prefix.length;
  if (available <= 0) {
    return header.length > 2000 ? header.slice(0, 2000) : header;
  }
  if (orig.length > available) {
    return prefix + orig.slice(0, available);
  }
  return prefix + orig;
}

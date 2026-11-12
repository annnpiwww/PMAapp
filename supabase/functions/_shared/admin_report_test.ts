import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  buildAdminMessage,
  buildDeskripsi,
  salam,
  validateReport,
} from './admin_report.ts';

Deno.test('admin_report: golden test matches exact message and Dart ErrorReport.toDeskripsi output', () => {
  const validated = validateReport({
    tanggal: '11-11-2026',
    waktu: '10.00',
    kendala: 'Gate in 1 tidak keluar karcis',
    penyebab: '',
    solusi_sementara: 'Buka manual',
    durasi_error: '',
    ada_foto: true,
    unknown_extra_key: 'ignored',
  });

  assertEquals(validated.ok, true);
  if (!validated.ok) return;

  const posName = 'Mie Gacoan Nani Wartabone';
  const msg = buildAdminMessage(validated.report, posName);

  const expectedMessage =
    'Selamat pagi, izin melaporkan, telah terjadi kendala dengan kronologi sebagai berikut:\n\n' +
    'Tanggal : 11-11-2026\n' +
    'Waktu : 10.00\n\n' +
    'Lokasi : Mie Gacoan Nani Wartabone\n\n' +
    'Kendala : Gate in 1 tidak keluar karcis\n\n' +
    'Penyebab : -\n\n' +
    'Solusi sementara : Buka manual\n\n' +
    'Durasi Error : -\n\n' +
    'Berikut kami lampirkan dokumentasi kerusakan.\n\n' +
    'Terima kasih.';

  assertEquals(msg, expectedMessage);

  const deskripsi = buildDeskripsi(msg, posName, validated.report);
  const expectedGoldenDeskripsiFromDart =
    'Tanggal : 11-11-2026\n' +
    'Waktu : 10.00\n' +
    'Lokasi : Mie Gacoan Nani Wartabone\n' +
    'Kendala : Gate in 1 tidak keluar karcis\n' +
    'Solusi sementara : Buka manual\n\n' +
    expectedMessage;

  assertEquals(deskripsi, expectedGoldenDeskripsiFromDart);
});

Deno.test('admin_report: salam boundaries (<11 pagi, <15 siang, <18 sore, else malam)', () => {
  assertEquals(salam('00.00'), 'Selamat pagi');
  assertEquals(salam('10.59'), 'Selamat pagi');
  assertEquals(salam('11.00'), 'Selamat siang');
  assertEquals(salam('14.59'), 'Selamat siang');
  assertEquals(salam('15.00'), 'Selamat sore');
  assertEquals(salam('17.59'), 'Selamat sore');
  assertEquals(salam('18.00'), 'Selamat malam');
  assertEquals(salam('23.59'), 'Selamat malam');
});

Deno.test('admin_report: validateReport strips control chars, rejects bare CR and enforces field limits', () => {
  // Strip control chars in kendala
  const withCtrl = validateReport({
    tanggal: '11-11-2026',
    waktu: '14.30',
    kendala: 'Palang\x00\x07 macet',
    ada_foto: false,
  });
  assertEquals(withCtrl.ok, true);
  if (withCtrl.ok) {
    assertEquals(withCtrl.report.kendala, 'Palang macet');
    assertEquals(withCtrl.report.penyebab, '-');
    assertEquals(withCtrl.report.solusi_sementara, '-');
    assertEquals(withCtrl.report.durasi_error, '-');
    assertEquals(withCtrl.report.tanggalIso, '2026-11-11');
  }

  // Reject bare \r
  const bareCr = validateReport({
    tanggal: '11-11-2026',
    waktu: '14.30',
    kendala: 'Line1\rLine2',
    ada_foto: false,
  });
  assertEquals(bareCr, { ok: false, field: 'kendala' });

  // Reject rollover date
  const badDate = validateReport({
    tanggal: '31-02-2026',
    waktu: '14.30',
    kendala: 'Printer mati',
    ada_foto: false,
  });
  assertEquals(badDate, { ok: false, field: 'tanggal' });

  // Reject invalid waktu
  const badTime = validateReport({
    tanggal: '11-11-2026',
    waktu: '24.00',
    kendala: 'Printer mati',
    ada_foto: false,
  });
  assertEquals(badTime, { ok: false, field: 'waktu' });

  // Reject > 300 chars
  const tooLongKendala = validateReport({
    tanggal: '11-11-2026',
    waktu: '14.30',
    kendala: 'x'.repeat(301),
    ada_foto: false,
  });
  assertEquals(tooLongKendala, { ok: false, field: 'kendala' });

  const tooLongPenyebab = validateReport({
    tanggal: '11-11-2026',
    waktu: '14.30',
    kendala: 'Valid',
    penyebab: 'p'.repeat(301),
    ada_foto: false,
  });
  assertEquals(tooLongPenyebab, { ok: false, field: 'penyebab' });
});

Deno.test('admin_report: buildDeskripsi truncates total length to 2000 chars', () => {
  const report = {
    tanggal: '11-11-2026',
    waktu: '10.00',
    kendala: 'Gate error',
    penyebab: 'Kabel putus',
    solusi_sementara: 'Buka manual',
  };
  const longMessage = 'M'.repeat(2500);
  const desc = buildDeskripsi(longMessage, 'Pos A', report);
  assertEquals(desc.length, 2000);
});

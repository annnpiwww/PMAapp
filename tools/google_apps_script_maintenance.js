/**
 * GOOGLE APPS SCRIPT - BSS PARKING TIMEMARK MAINTENANCE & ERROR SYNC
 * 
 * Target Spreadsheet:
 * https://docs.google.com/spreadsheets/d/1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg/edit?hl=id&gid=0#gid=0
 * 
 * Sheet yang didukung:
 * 1. 'Maintenance' -> Log form checklist maintenance
 * 2. 'Error'       -> Log tiket error lokasi/alat (Manado only)
 * 
 * SECURITY (SEC-08):
 * - Secret token verified via Script Properties (`SECRET` or `GOOGLE_SHEETS_SECRET`).
 * - Formula injection prevention: prefix strings starting with [=+\-@\t\r] with single quote (').
 * 
 * CARA DEPLOY KE GOOGLE APPS SCRIPT:
 * 1. Buka spreadsheet: https://docs.google.com/spreadsheets/d/1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg
 * 2. Klik menu: Ekstensi -> Apps Script
 * 3. Hapus semua kode default, lalu PASTE kode di bawah ini (Ctrl+A, Ctrl+V).
 * 4. PENTING: Untuk update kode tanpa mengubah URL Webhook:
 *    Klik tombol "Deploy" (Terapkan) -> "Manage deployments" (Kelola penerapan)
 *    -> Klik ikon pensil (edit) di deployment aktif -> Version: pilih "New version" (Versi baru)
 *    -> Klik "Deploy" (Terapkan). Dengan cara ini URL Webhook TIDAK BERUBAH.
 * 5. Jika deployment baru pertama kali:
 *    Project Settings (ikon gerigi) -> Script Properties -> Add script property:
 *    Property: SECRET
 *    Value: <isi dengan secret GOOGLE_SHEETS_SECRET yang ada di Supabase secrets>
 *    Lalu Deploy -> New deployment -> Web app -> Anyone -> Deploy.
 */

const SPREADSHEET_ID = '1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg';
const SHEET_NAME = 'Maintenance'; // Otomatis dibuat jika belum ada

function sanitizeForSheet(val) {
  if (val == null) return '';
  const s = String(val);
  // SEC-08: Formula injection prevention
  if (/^[=+\-@\t\r]/.test(s)) {
    return "'" + s;
  }
  return s;
}

function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({
    status: 'ok',
    message: 'BSS Parking Timemark Maintenance & Error Sync API is running.'
  })).setMimeType(ContentService.MimeType.JSON);
}

function handleError(ss, data) {
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const ERROR_SHEET_NAME = 'Error';
    let sheet = ss.getSheetByName(ERROR_SHEET_NAME);

    if (!sheet) {
      sheet = ss.insertSheet(ERROR_SHEET_NAME);
      const headers = [
        'ID Tiket',
        'Tanggal Lapor',
        'Waktu Lapor',
        'Lokasi',
        'Kendala',
        'Penyebab',
        'Solusi Sementara',
        'Pelapor',
        'Status',
        'Teknisi',
        'Solusi Perbaikan',
        'Selesai',
        'Durasi Perbaikan',
        'Catatan'
      ];
      sheet.appendRow(headers);

      const headerRange = sheet.getRange(1, 1, 1, 14);
      headerRange.setBackground('#1E489C')
                 .setFontColor('#FFFFFF')
                 .setFontWeight('bold')
                 .setHorizontalAlignment('center')
                 .setVerticalAlignment('middle');
      sheet.setRowHeight(1, 36);
      sheet.setFrozenRows(1);

      sheet.setColumnWidth(1, 140); // ID Tiket
      sheet.setColumnWidth(2, 110); // Tanggal Lapor
      sheet.setColumnWidth(3, 90);  // Waktu Lapor
      sheet.setColumnWidth(4, 120); // Lokasi
      sheet.setColumnWidth(5, 220); // Kendala
      sheet.setColumnWidth(6, 200); // Penyebab
      sheet.setColumnWidth(7, 200); // Solusi Sementara
      sheet.setColumnWidth(8, 140); // Pelapor
      sheet.setColumnWidth(9, 110); // Status
      sheet.setColumnWidth(10, 140); // Teknisi
      sheet.setColumnWidth(11, 200); // Solusi Perbaikan
      sheet.setColumnWidth(12, 150); // Selesai
      sheet.setColumnWidth(13, 130); // Durasi Perbaikan
      sheet.setColumnWidth(14, 220); // Catatan
      // Teks biasa: tanpa ini "05.35" jadi angka dan "07-11-2026" jadi tanggal sesuai locale.
      sheet.getRange('A:N').setNumberFormat('@');
    }

    const lastRow = sheet.getLastRow();
    let foundRow = -1;
    if (lastRow > 1) {
      const ids = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
      const targetId = String(data.id || '').trim();
      for (let i = 0; i < ids.length; i++) {
        if (String(ids[i][0]).trim() === targetId) {
          foundRow = i + 2;
          break;
        }
      }
    }

    const stage = String(data.stage || 'open').toLowerCase();

    if (stage === 'open') {
      if (foundRow === -1) {
        sheet.appendRow([
          sanitizeForSheet(data.id || ''),
          sanitizeForSheet(data.tanggalLapor || ''),
          sanitizeForSheet(data.waktuLapor || ''),
          sanitizeForSheet(data.lokasi || ''),
          sanitizeForSheet(data.kendala || ''),
          sanitizeForSheet(data.penyebab || ''),
          sanitizeForSheet(data.solusiSementara || ''),
          sanitizeForSheet(data.pelapor || ''),
          sanitizeForSheet('Belum selesai'),
          sanitizeForSheet(''),
          sanitizeForSheet(''),
          sanitizeForSheet(''),
          sanitizeForSheet(''),
          sanitizeForSheet('')
        ]);
        const targetRow = sheet.getLastRow();
        const rowRange = sheet.getRange(targetRow, 1, 1, 14);
        rowRange.setVerticalAlignment('top').setWrap(true);
        sheet.getRange(targetRow, 9).setBackground('#FEF2F2').setFontColor('#991B1B');
        return ContentService.createTextOutput(JSON.stringify({
          status: 'success',
          message: 'Tiket error (open) berhasil dicatat.',
          row: targetRow
        })).setMimeType(ContentService.MimeType.JSON);
      } else {
        return ContentService.createTextOutput(JSON.stringify({
          status: 'success',
          message: 'Tiket error (open) sudah ada, tidak ada perubahan.',
          row: foundRow
        })).setMimeType(ContentService.MimeType.JSON);
      }
    } else if (stage === 'done') {
      if (foundRow !== -1) {
        // Update existing row (keep open-stage columns unless empty)
        const currentVals = sheet.getRange(foundRow, 1, 1, 8).getValues()[0];
        if (!currentVals[1] && data.tanggalLapor) sheet.getRange(foundRow, 2).setValue(sanitizeForSheet(data.tanggalLapor));
        if (!currentVals[2] && data.waktuLapor) sheet.getRange(foundRow, 3).setValue(sanitizeForSheet(data.waktuLapor));
        if (!currentVals[3] && data.lokasi) sheet.getRange(foundRow, 4).setValue(sanitizeForSheet(data.lokasi));
        if (!currentVals[4] && data.kendala) sheet.getRange(foundRow, 5).setValue(sanitizeForSheet(data.kendala));
        if (data.penyebab != null && data.penyebab !== '') sheet.getRange(foundRow, 6).setValue(sanitizeForSheet(data.penyebab));
        if (!currentVals[6] && data.solusiSementara) sheet.getRange(foundRow, 7).setValue(sanitizeForSheet(data.solusiSementara));
        if (!currentVals[7] && data.pelapor) sheet.getRange(foundRow, 8).setValue(sanitizeForSheet(data.pelapor));

        sheet.getRange(foundRow, 9).setValue(sanitizeForSheet('Selesai')).setBackground('#F0FDF4').setFontColor('#166534');
        sheet.getRange(foundRow, 10).setValue(sanitizeForSheet(data.teknisi || ''));
        sheet.getRange(foundRow, 11).setValue(sanitizeForSheet(data.solusiPerbaikan || ''));
        sheet.getRange(foundRow, 12).setValue(sanitizeForSheet(data.selesai || ''));
        sheet.getRange(foundRow, 13).setValue(sanitizeForSheet(data.durasiPerbaikan || ''));
        sheet.getRange(foundRow, 14).setValue(sanitizeForSheet(data.catatan || ''));

        sheet.getRange(foundRow, 1, 1, 14).setVerticalAlignment('top').setWrap(true);

        return ContentService.createTextOutput(JSON.stringify({
          status: 'success',
          message: 'Tiket error (done) berhasil diperbarui.',
          row: foundRow
        })).setMimeType(ContentService.MimeType.JSON);
      } else {
        // Append full row
        sheet.appendRow([
          sanitizeForSheet(data.id || ''),
          sanitizeForSheet(data.tanggalLapor || ''),
          sanitizeForSheet(data.waktuLapor || ''),
          sanitizeForSheet(data.lokasi || ''),
          sanitizeForSheet(data.kendala || ''),
          sanitizeForSheet(data.penyebab || ''),
          sanitizeForSheet(data.solusiSementara || ''),
          sanitizeForSheet(data.pelapor || ''),
          sanitizeForSheet('Selesai'),
          sanitizeForSheet(data.teknisi || ''),
          sanitizeForSheet(data.solusiPerbaikan || ''),
          sanitizeForSheet(data.selesai || ''),
          sanitizeForSheet(data.durasiPerbaikan || ''),
          sanitizeForSheet(data.catatan || '')
        ]);
        const targetRow = sheet.getLastRow();
        const rowRange = sheet.getRange(targetRow, 1, 1, 14);
        rowRange.setVerticalAlignment('top').setWrap(true);
        sheet.getRange(targetRow, 9).setBackground('#F0FDF4').setFontColor('#166534');
        return ContentService.createTextOutput(JSON.stringify({
          status: 'success',
          message: 'Tiket error (done) berhasil ditambahkan.',
          row: targetRow
        })).setMimeType(ContentService.MimeType.JSON);
      }
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: 'Unknown stage: ' + stage
    })).setMimeType(ContentService.MimeType.JSON);

  } finally {
    lock.releaseLock();
  }
}

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return ContentService.createTextOutput(JSON.stringify({
        status: 'error',
        message: 'Bad Request: empty body'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    const data = JSON.parse(e.postData.contents);

    // SEC-08: Token verification from Script Properties
    const scriptProps = PropertiesService.getScriptProperties();
    const expectedSecret = scriptProps.getProperty('SECRET') ||
                           scriptProps.getProperty('GOOGLE_SHEETS_SECRET') ||
                           scriptProps.getProperty('SECRET_TOKEN');

    const receivedToken = data.secretToken || (e.parameter && e.parameter.secretToken);

    if (expectedSecret && receivedToken !== expectedSecret) {
      return ContentService.createTextOutput(JSON.stringify({
        status: 'error',
        message: 'Unauthorized: invalid or missing secretToken'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    const ss = SpreadsheetApp.openById(SPREADSHEET_ID);

    // Rute tiket error (Manado)
    if (data.kind === 'error') {
      return handleError(ss, data);
    }

    let sheet = ss.getSheetByName(SHEET_NAME);
    
    // Jika sheet belum ada, buat baru & beri header rapi
    if (!sheet) {
      sheet = ss.insertSheet(SHEET_NAME);
      const headers = ['Tanggal', 'Lokasi', 'It Support', 'Approve', 'Perlu perbaikan'];
      sheet.appendRow(headers);
      
      // Styling Header
      const headerRange = sheet.getRange(1, 1, 1, 5);
      headerRange.setBackground('#1E489C')
                 .setFontColor('#FFFFFF')
                 .setFontWeight('bold')
                 .setHorizontalAlignment('center')
                 .setVerticalAlignment('middle');
      sheet.setRowHeight(1, 36);
      sheet.setColumnWidth(1, 170); // Tanggal
      sheet.setColumnWidth(2, 220); // Lokasi
      sheet.setColumnWidth(3, 160); // It Support
      sheet.setColumnWidth(4, 300); // Approve
      sheet.setColumnWidth(5, 300); // Perlu perbaikan
    }

    // Format tanggal & waktu
    const rawTanggal = data.tanggal || Utilities.formatDate(new Date(), 'Asia/Makassar', 'dd/MM/yyyy HH:mm') + ' WITA';
    const rawLokasi = data.lokasi || '-';
    const rawItSupport = data.itSupport || data.teknisi || '-';
    
    // Format list poin Approve (Lolos)
    let approveText = '-';
    if (Array.isArray(data.approve)) {
      approveText = data.approve.map(sanitizeForSheet).join('\n');
    } else if (data.approve) {
      approveText = sanitizeForSheet(String(data.approve));
    } else if (data.daftarLolos) {
      approveText = sanitizeForSheet(String(data.daftarLolos));
    }
    
    // Format list poin Perlu Perbaikan (Masalah)
    let perluPerbaikanText = '-';
    if (Array.isArray(data.perluPerbaikan)) {
      perluPerbaikanText = data.perluPerbaikan.map(sanitizeForSheet).join('\n');
    } else if (data.perluPerbaikan) {
      perluPerbaikanText = sanitizeForSheet(String(data.perluPerbaikan));
    } else if (data.daftarPerbaikan) {
      perluPerbaikanText = sanitizeForSheet(String(data.daftarPerbaikan));
    }

    // Tambahkan baris data baru dengan sanitasi formula injection
    sheet.appendRow([
      sanitizeForSheet(rawTanggal),
      sanitizeForSheet(rawLokasi),
      sanitizeForSheet(rawItSupport),
      approveText,
      perluPerbaikanText
    ]);

    const lastRow = sheet.getLastRow();
    const rowRange = sheet.getRange(lastRow, 1, 1, 5);
    rowRange.setVerticalAlignment('top')
            .setWrap(true);
            
    // Beri warna latar lembut jika ada temuan perbaikan
    if (perluPerbaikanText !== '-' && perluPerbaikanText.trim().length > 0) {
      sheet.getRange(lastRow, 5).setBackground('#FEF2F2').setFontColor('#991B1B');
    }
    if (approveText !== '-' && approveText.trim().length > 0) {
      sheet.getRange(lastRow, 4).setBackground('#F0FDF4').setFontColor('#166534');
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      message: 'Data maintenance berhasil disinkronkan ke Google Sheet.',
      row: lastRow
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

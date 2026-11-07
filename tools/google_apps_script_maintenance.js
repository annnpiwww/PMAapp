/**
 * GOOGLE APPS SCRIPT - BSS PARKING TIMEMARK MAINTENANCE SYNC
 * 
 * Target Spreadsheet:
 * https://docs.google.com/spreadsheets/d/1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg/edit?hl=id&gid=0#gid=0
 * 
 * Judul Kolom Tabel:
 * [Tanggal] [Lokasi] [It Support] [Approve] [Perlu perbaikan]
 * 
 * SECURITY (SEC-08):
 * - Secret token verified via Script Properties (`SECRET` or `GOOGLE_SHEETS_SECRET`).
 * - Formula injection prevention: prefix strings starting with [=+\-@\t\r] with single quote (').
 * 
 * CARA DEPLOY KE GOOGLE APPS SCRIPT:
 * 1. Buka spreadsheet: https://docs.google.com/spreadsheets/d/1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg
 * 2. Klik menu: Ekstensi -> Apps Script
 * 3. Hapus semua kode default, lalu PASTE kode di bawah ini (Ctrl+A, Ctrl+V).
 * 4. Buka Project Settings (ikon gerigi) -> Script Properties -> Add script property:
 *    Property: SECRET
 *    Value: <isi dengan secret GOOGLE_SHEETS_SECRET yang ada di Supabase secrets>
 * 5. Klik tombol "Terapkan" (Deploy) -> "Penerapan baru" (New deployment).
 * 6. Pilih jenis: "Aplikasi web" (Web app).
 * 7. Deskripsi: "BSS Maintenance Sync v2 Secured".
 * 8. Jalankan sebagai: "Saya" (Me).
 * 9. Yang memiliki akses: "Siapa saja" (Anyone).
 * 10. Klik "Terapkan" (Deploy), lalu simpan URL Webhook.
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
    message: 'BSS Parking Timemark Maintenance Sync API is running.'
  })).setMimeType(ContentService.MimeType.JSON);
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

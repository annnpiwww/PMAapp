/**
 * GOOGLE APPS SCRIPT - BSS PARKING TIMEMARK MAINTENANCE SYNC
 * 
 * Target Spreadsheet:
 * https://docs.google.com/spreadsheets/d/1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg/edit?hl=id&gid=0#gid=0
 * 
 * Judul Kolom Tabel:
 * [Tanggal] [Lokasi] [It Support] [Approve] [Perlu perbaikan]
 * 
 * CARA DEPLOY KE GOOGLE APPS SCRIPT:
 * 1. Buka spreadsheet: https://docs.google.com/spreadsheets/d/1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg
 * 2. Klik menu: Ekstensi -> Apps Script
 * 3. Hapus semua kode default, lalu PASTE kode di bawah ini (Ctrl+A, Ctrl+V).
 * 4. Klik tombol "Terapkan" (Deploy) -> "Penerapan baru" (New deployment).
 * 5. Pilih jenis: "Aplikasi web" (Web app).
 * 6. Deskripsi: "BSS Maintenance Sync v1".
 * 7. Jalankan sebagai: "Saya" (Me).
 * 8. Yang memiliki akses: "Siapa saja" (Anyone) -> SANGAT PENTING agar HP bisa kirim data tanpa login Google!
 * 9. Klik "Terapkan" (Deploy), lalu Salin URL Aplikasi Web (format: https://script.google.com/macros/s/.../exec).
 */

const SPREADSHEET_ID = '1b-ifRsQzt1yfyoBxgx5fV3pveYkXAHyt3LwW4xS7eqg';
const SHEET_NAME = 'Maintenance'; // Otomatis dibuat jika belum ada

function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({
    status: 'ok',
    message: 'BSS Parking Timemark Maintenance Sync API is running.'
  })).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
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

    const data = JSON.parse(e.postData.contents);
    
    // Format tanggal & waktu
    const tanggal = data.tanggal || Utilities.formatDate(new Date(), 'Asia/Makassar', 'dd/MM/yyyy HH:mm') + ' WITA';
    const lokasi = data.lokasi || '-';
    const itSupport = data.itSupport || data.teknisi || '-';
    
    // Format list poin Approve (Lolos)
    let approveText = '-';
    if (Array.isArray(data.approve)) {
      approveText = data.approve.join('\n');
    } else if (data.approve) {
      approveText = String(data.approve);
    } else if (data.daftarLolos) {
      approveText = String(data.daftarLolos);
    }
    
    // Format list poin Perlu Perbaikan (Masalah)
    let perluPerbaikanText = '-';
    if (Array.isArray(data.perluPerbaikan)) {
      perluPerbaikanText = data.perluPerbaikan.join('\n');
    } else if (data.perluPerbaikan) {
      perluPerbaikanText = String(data.perluPerbaikan);
    } else if (data.daftarPerbaikan) {
      perluPerbaikanText = String(data.daftarPerbaikan);
    }

    // Tambahkan baris data baru
    sheet.appendRow([
      tanggal,
      lokasi,
      itSupport,
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

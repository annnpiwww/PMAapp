import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const require = createRequire('/home/annnpii/.npm-global/lib/node_modules/playwright/package.json');
const { chromium } = require('playwright');

const outDir = path.resolve('docs/design/updater');
const pngDir = path.join(outDir, 'png');
fs.mkdirSync(pngDir, { recursive: true });

const screens = [
  { id: 'u1', fullPage: false, label: 'U1 · Pembaruan Opsional' },
  { id: 'u2', fullPage: false, label: 'U2 · Mengunduh' },
  { id: 'u3', fullPage: true, label: 'U3 · Izin & Siap Pasang' },
  { id: 'u4', fullPage: false, label: 'U4 · Pembaruan Wajib' },
  { id: 'u5', fullPage: true, label: 'U5 · Varian Error' },
  { id: 'a1', fullPage: true, label: 'A1 · Rilis Aplikasi (SPV)' },
  { id: 'a2', fullPage: true, label: 'A2 · Unggah & Dialog' },
];

const forbiddenUserWords = /\b(sha|sha-256|sha256|abi|apk|versioncode|version_code)\b/i;

const browser = await chromium.launch({ headless: true });

const auditResults = [];

try {
  for (const s of screens) {
    const fileUrl = pathToFileURL(path.join(outDir, `${s.id}.html`)).href;

    for (const theme of ['light', 'dark']) {
      const ctx = await browser.newContext({
        viewport: { width: 390, height: 844 },
        deviceScaleFactor: 2,
      });
      const page = await ctx.newPage();
      await page.goto(`${fileUrl}?theme=${theme}`, { waitUntil: 'networkidle' });
      await page.evaluate(() => document.fonts.ready);

      const metrics = await page.evaluate(() => {
        const overflowX = document.documentElement.scrollWidth > window.innerWidth;
        const buttons = [...document.querySelectorAll('button, [role="button"], [role="switch"]')];
        const smallTargets = buttons
          .map((el) => {
            const r = el.getBoundingClientRect();
            return { text: (el.innerText || el.getAttribute('aria-label') || '').trim(), w: Math.round(r.width), h: Math.round(r.height) };
          })
          .filter((b) => b.w > 0 && b.h > 0 && (b.w < 44 || b.h < 44));
        const textNodes = [...document.querySelectorAll('body *')]
          .filter((el) => el.children.length === 0 && el.innerText && el.innerText.trim().length > 0);
        const smallFonts = textNodes
          .map((el) => ({ text: el.innerText.trim().slice(0, 30), size: parseFloat(getComputedStyle(el).fontSize) }))
          .filter((t) => t.size < 12);
        const bodyText = document.body.innerText;
        const hasEmOrEnDash = /[\u2014\u2013]/.test(bodyText);
        return { overflowX, smallTargets, smallFonts, hasEmOrEnDash, bodyText };
      });

      const hasForbiddenWord = s.id.startsWith('u') ? forbiddenUserWords.test(metrics.bodyText) : false;
      auditResults.push({
        screen: `${s.id}-${theme}`,
        overflowX: metrics.overflowX,
        smallTargets: metrics.smallTargets,
        smallFonts: metrics.smallFonts,
        hasEmOrEnDash: metrics.hasEmOrEnDash,
        hasForbiddenWord,
      });

      await page.screenshot({
        path: path.join(pngDir, `${s.id}-${theme}.png`),
        fullPage: s.fullPage,
      });
      await ctx.close();
    }

    if (s.id === 'u2' || s.id === 'u4') {
      const ctx360 = await browser.newContext({
        viewport: { width: 360, height: 800 },
        deviceScaleFactor: 2,
      });
      const p360 = await ctx360.newPage();
      await p360.goto(`${fileUrl}?theme=light`, { waitUntil: 'networkidle' });
      await p360.evaluate(() => document.fonts.ready);
      const ov360 = await p360.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
      auditResults.push({ screen: `${s.id}-360-light`, overflowX: ov360 });
      await p360.screenshot({ path: path.join(pngDir, `${s.id}-360-light.png`), fullPage: false });
      await ctx360.close();
    }
  }

  // Compose board.png (all 7 light screens) using base64 data URIs
  const boardItems = screens.map((s) => {
    const b64 = fs.readFileSync(path.join(pngDir, `${s.id}-light.png`)).toString('base64');
    return { label: s.label, src: `data:image/png;base64,${b64}` };
  });

  const boardHtml = `<!doctype html>
  <html lang="id">
  <head><meta charset="utf-8"><style>
    @font-face { font-family: 'Figtree'; src: url('data:font/ttf;base64,${fs.readFileSync(path.resolve('assets/fonts/Figtree-Bold.ttf')).toString('base64')}') format('truetype'); font-weight: 700; }
    @font-face { font-family: 'Figtree'; src: url('data:font/ttf;base64,${fs.readFileSync(path.resolve('assets/fonts/Figtree-ExtraBold.ttf')).toString('base64')}') format('truetype'); font-weight: 800; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Figtree', sans-serif; background: #E9EEF5; color: #000000; padding: 36px; width: 2960px; }
    header { margin-bottom: 28px; display: flex; justify-content: space-between; align-items: baseline; border-bottom: 2px solid #CBD5E1; padding-bottom: 16px; }
    h1 { font-size: 36px; font-weight: 800; color: #1A428A; }
    .sub { font-size: 20px; font-weight: 700; color: #475569; }
    .grid { display: grid; grid-template-columns: repeat(7, 390px); gap: 28px; align-items: start; }
    .col { display: flex; flex-direction: column; gap: 12px; }
    .lbl { font-size: 20px; font-weight: 800; color: #0F172A; }
    .frame { width: 390px; border-radius: 20px; overflow: hidden; box-shadow: 0 10px 30px rgba(15, 23, 42, 0.16); border: 2px solid #CBD5E1; background: #FFFFFF; }
    .frame img { width: 100%; display: block; }
  </style></head>
  <body>
    <header>
      <h1>PMApp In-App Updater · Mockup Board (Light)</h1>
      <div class="sub">DESIGN.md Tiket · v2.0.141 -> v2.0.142 · 390px</div>
    </header>
    <div class="grid">
      ${boardItems.map((item) => `
        <div class="col">
          <div class="lbl">${item.label}</div>
          <div class="frame"><img src="${item.src}" alt="${item.label}"></div>
        </div>
      `).join('')}
    </div>
  </body></html>`;

  const boardCtx = await browser.newContext({ viewport: { width: 2960, height: 2200 }, deviceScaleFactor: 1 });
  const boardPage = await boardCtx.newPage();
  await boardPage.setContent(boardHtml, { waitUntil: 'networkidle' });
  await boardPage.evaluate(() => document.fonts.ready);
  await boardPage.screenshot({ path: path.join(pngDir, 'board.png'), fullPage: true });
  await boardCtx.close();

  console.log(JSON.stringify(auditResults, null, 2));
} finally {
  await browser.close();
}

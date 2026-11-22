#!/usr/bin/env node
// Publish split-per-ABI PMApp release APKs to Supabase app-releases edge function.
// Usage: node tools/publish_release.mjs --changelog <text> [--mandatory] [--min-version x.y.z] [--dry-run]

import { createHash } from 'node:crypto';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_SUPABASE_URL = 'https://sxsjixnnlzhjinzcyhjb.supabase.co';
const DEFAULT_SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4c2ppeG5ubHpoamluemN5aGpiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMDUwNjYsImV4cCI6MjEwMTU4MTA2Nn0.8syTnWhD9yC6SxzTY8K_UEyXKQ8GTlyuHTWYa8eoLTs';

const ABI_TARGETS = [
  { abi: 'arm64-v8a', offset: 2000, file: 'app-arm64-v8a-release.apk' },
  { abi: 'armeabi-v7a', offset: 1000, file: 'app-armeabi-v7a-release.apk' },
];

const SEMVER_RE = /^[0-9]+\.[0-9]+\.[0-9]+$/;

function parseArgs(argv) {
  let changelog = '';
  let hasChangelog = false;
  let mandatory = false;
  let minVersion = null;
  let dryRun = false;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--changelog') {
      changelog = argv[++i] ?? '';
      hasChangelog = true;
    } else if (arg === '--mandatory') {
      mandatory = true;
    } else if (arg === '--min-version') {
      minVersion = argv[++i] ?? '';
    } else if (arg === '--dry-run') {
      dryRun = true;
    } else if (arg === '--help' || arg === '-h') {
      console.log(
        'Usage: node tools/publish_release.mjs --changelog <text> [--mandatory] [--min-version x.y.z] [--dry-run]',
      );
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!hasChangelog || changelog.trim().length === 0) {
    throw new Error('--changelog <text> is required');
  }
  if (changelog.length > 2000) {
    throw new Error('--changelog must be <= 2000 characters');
  }
  if (minVersion !== null && !SEMVER_RE.test(minVersion)) {
    throw new Error('--min-version must match X.Y.Z');
  }

  return { changelog, mandatory, minVersion, dryRun };
}

function loadEnvFile(filePath) {
  if (!existsSync(filePath)) return {};
  const result = {};
  const raw = readFileSync(filePath, 'utf8');
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    result[key] = val;
  }
  return result;
}

function readPubspecVersion(repoRoot) {
  const pubspecPath = resolve(repoRoot, 'pubspec.yaml');
  const raw = readFileSync(pubspecPath, 'utf8');
  const match = raw.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$/m);
  if (!match) {
    throw new Error(`Could not parse version: X.Y.Z+B from ${pubspecPath}`);
  }
  const versionName = match[1];
  const baseVersionCode = Number(match[2]);
  if (!Number.isInteger(baseVersionCode) || baseVersionCode <= 0) {
    throw new Error(`Invalid base version code in ${pubspecPath}`);
  }
  return { versionName, baseVersionCode };
}

function sha256File(filePath) {
  const buf = readFileSync(filePath);
  const sha256 = createHash('sha256').update(buf).digest('hex');
  return { buf, sha256, sizeBytes: statSync(filePath).size };
}

async function callJson(url, headers, payload) {
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      ...headers,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    const msg = typeof data?.error === 'string' ? data.error : `HTTP ${res.status}`;
    throw new Error(`${url} failed (${res.status}): ${msg}`);
  }
  return data;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const repoRoot = resolve(scriptDir, '..');
  const { versionName, baseVersionCode } = readPubspecVersion(repoRoot);

  const apkDir = resolve(repoRoot, 'build/app/outputs/flutter-apk');
  const artifacts = ABI_TARGETS.map((target) => {
    const apkPath = resolve(apkDir, target.file);
    if (!existsSync(apkPath)) {
      throw new Error(`Missing release APK: ${apkPath}`);
    }
    const { buf, sha256, sizeBytes } = sha256File(apkPath);
    const versionCode = baseVersionCode + target.offset;
    return {
      abi: target.abi,
      apkPath,
      versionCode,
      baseVersionCode,
      versionName,
      sha256,
      sizeBytes,
      buf,
    };
  });

  if (opts.dryRun) {
    console.log(
      `[dry-run] version=${versionName}+${baseVersionCode} mandatory=${opts.mandatory} min_version=${opts.minVersion ?? 'null'}`,
    );
    for (const a of artifacts) {
      console.log(
        `${a.abi}: version_code=${a.versionCode} size=${a.sizeBytes} sha256=${a.sha256.slice(0, 12)}... status=dry-run`,
      );
    }
    return;
  }

  const fileEnv = loadEnvFile(resolve(homedir(), '.config/pmapp-release.env'));
  const user = process.env.PMAPP_RELEASE_USER || fileEnv.PMAPP_RELEASE_USER || '';
  const password = process.env.PMAPP_RELEASE_PASSWORD || fileEnv.PMAPP_RELEASE_PASSWORD || '';
  if (!user || !password) {
    throw new Error(
      'Missing credentials: set PMAPP_RELEASE_USER & PMAPP_RELEASE_PASSWORD or create ~/.config/pmapp-release.env',
    );
  }

  const supabaseUrl =
    process.env.SUPABASE_URL || fileEnv.SUPABASE_URL || DEFAULT_SUPABASE_URL;
  const anonKey =
    process.env.SUPABASE_ANON_KEY || fileEnv.SUPABASE_ANON_KEY || DEFAULT_SUPABASE_ANON_KEY;

  const baseHeaders = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
  };

  const loginRes = await callJson(`${supabaseUrl}/functions/v1/auth-login`, baseHeaders, {
    identity: user,
    password,
  });
  const sessionToken = loginRes?.token;
  if (typeof sessionToken !== 'string' || sessionToken.length === 0) {
    throw new Error('auth-login did not return a session token');
  }

  const adminHeaders = {
    ...baseHeaders,
    'x-app-session': sessionToken,
  };
  const fnUrl = `${supabaseUrl}/functions/v1/app-releases`;

  for (const a of artifacts) {
    const created = await callJson(fnUrl, adminHeaders, {
      action: 'create_upload',
      abi: a.abi,
      version_code: a.versionCode,
      base_version_code: a.baseVersionCode,
      version_name: a.versionName,
      sha256: a.sha256,
      size_bytes: a.sizeBytes,
      changelog: opts.changelog,
      mandatory: opts.mandatory,
      min_supported_version: opts.minVersion,
    });

    const uploadRes = await fetch(created.upload.signedUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/vnd.android.package-archive',
        'x-upsert': 'false',
      },
      body: a.buf,
    });
    if (!uploadRes.ok) {
      throw new Error(`Signed upload failed for ${a.abi} (${uploadRes.status})`);
    }

    const published = await callJson(fnUrl, adminHeaders, {
      action: 'publish',
      id: created.id,
    });

    const status = published?.release?.status ?? 'published';
    console.log(
      `${a.abi}: version_code=${a.versionCode} size=${a.sizeBytes} sha256=${a.sha256.slice(0, 12)}... status=${status}`,
    );
  }
}

main().catch((err) => {
  console.error(`publish_release error: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});

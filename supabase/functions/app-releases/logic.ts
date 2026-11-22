export const APP_ID = 'pmapp';
export const MAX_APK_BYTES = 52_428_800; // 50 MiB Free Tier limit
export const MAX_CHANGELOG_CHARS = 2000;

export const ABI_OFFSET = {
  'armeabi-v7a': 1000,
  'arm64-v8a': 2000,
  'x86_64': 4000,
} as const;

export type Abi = keyof typeof ABI_OFFSET;

const SEMVER_RE = /^([0-9]+)\.([0-9]+)\.([0-9]+)$/;
const SHA256_RE = /^[0-9a-f]{64}$/;

export function isAbi(value: unknown): value is Abi {
  return typeof value === 'string' && Object.prototype.hasOwnProperty.call(ABI_OFFSET, value);
}

export function parseSemver(value: unknown): [number, number, number] | null {
  if (typeof value !== 'string') return null;
  const match = SEMVER_RE.exec(value);
  if (!match) return null;
  const major = Number(match[1]);
  const minor = Number(match[2]);
  const patch = Number(match[3]);
  if (!Number.isSafeInteger(major) || !Number.isSafeInteger(minor) || !Number.isSafeInteger(patch)) {
    return null;
  }
  return [major, minor, patch];
}

export function compareSemver(a: string, b: string): number {
  const pa = parseSemver(a);
  const pb = parseSemver(b);
  if (!pa || !pb) {
    throw new Error('Invalid semver');
  }
  for (let i = 0; i < 3; i++) {
    if (pa[i] < pb[i]) return -1;
    if (pa[i] > pb[i]) return 1;
  }
  return 0;
}

export function objectPath(abi: Abi, versionCode: number): string {
  return `prod/${versionCode}-${abi}.apk`;
}

export interface ValidatedCreateInput {
  abi: Abi;
  base_version_code: number;
  version_code: number;
  version_name: string;
  sha256: string;
  size_bytes: number;
  changelog: string;
  mandatory: boolean;
  min_supported_version: string | null;
}

export type ValidateResult<T> =
  | { ok: true; value: T }
  | { ok: false; errors: Record<string, string> };

function isPositiveInt(v: unknown): v is number {
  return typeof v === 'number' && Number.isInteger(v) && v > 0;
}

export function validateCreate(input: unknown): ValidateResult<ValidatedCreateInput> {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    return { ok: false, errors: { body: 'must be a JSON object' } };
  }

  const obj = input as Record<string, unknown>;
  const errors: Record<string, string> = {};

  const abiValid = isAbi(obj.abi);
  if (!abiValid) {
    errors.abi = 'must be one of arm64-v8a, armeabi-v7a, x86_64';
  }

  const baseValid = isPositiveInt(obj.base_version_code);
  if (!baseValid) {
    errors.base_version_code = 'must be a positive integer';
  }

  const codeValid = isPositiveInt(obj.version_code);
  if (!codeValid) {
    errors.version_code = 'must be a positive integer';
  } else if (abiValid && baseValid) {
    const expected = (obj.base_version_code as number) + ABI_OFFSET[obj.abi as Abi];
    if (obj.version_code !== expected) {
      errors.version_code = `must equal base_version_code + ${ABI_OFFSET[obj.abi as Abi]} (${expected})`;
    }
  }

  if (parseSemver(obj.version_name) === null) {
    errors.version_name = 'must be semver X.Y.Z';
  }

  if (typeof obj.sha256 !== 'string' || !SHA256_RE.test(obj.sha256)) {
    errors.sha256 = 'must be 64-char lowercase hex SHA-256';
  }

  if (!isPositiveInt(obj.size_bytes) || obj.size_bytes > MAX_APK_BYTES) {
    errors.size_bytes = `must be integer between 1 and ${MAX_APK_BYTES}`;
  }

  const changelog = obj.changelog === undefined ? '' : obj.changelog;
  if (typeof changelog !== 'string' || changelog.length > MAX_CHANGELOG_CHARS) {
    errors.changelog = `must be a string up to ${MAX_CHANGELOG_CHARS} characters`;
  }

  const mandatory = obj.mandatory === undefined ? false : obj.mandatory;
  if (typeof mandatory !== 'boolean') {
    errors.mandatory = 'must be a boolean';
  }

  const minSupported = obj.min_supported_version === undefined ? null : obj.min_supported_version;
  if (minSupported !== null && parseSemver(minSupported) === null) {
    errors.min_supported_version = 'must be null or semver X.Y.Z';
  }

  if (Object.keys(errors).length > 0) {
    return { ok: false, errors };
  }

  return {
    ok: true,
    value: {
      abi: obj.abi as Abi,
      base_version_code: obj.base_version_code as number,
      version_code: obj.version_code as number,
      version_name: obj.version_name as string,
      sha256: obj.sha256 as string,
      size_bytes: obj.size_bytes as number,
      changelog: changelog as string,
      mandatory: mandatory as boolean,
      min_supported_version: minSupported as string | null,
    },
  };
}

export interface ValidatedLatestInput {
  abi: Abi;
  current_code: number;
  current_version: string;
}

export function validateLatestInput(input: unknown): ValidateResult<ValidatedLatestInput> {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    return { ok: false, errors: { body: 'must be a JSON object' } };
  }
  const obj = input as Record<string, unknown>;
  const errors: Record<string, string> = {};

  if (!isAbi(obj.abi)) {
    errors.abi = 'must be one of arm64-v8a, armeabi-v7a, x86_64';
  }
  if (!isPositiveInt(obj.current_code)) {
    errors.current_code = 'must be a positive integer';
  }
  if (parseSemver(obj.current_version) === null) {
    errors.current_version = 'must be semver X.Y.Z';
  }

  if (Object.keys(errors).length > 0) {
    return { ok: false, errors };
  }

  return {
    ok: true,
    value: {
      abi: obj.abi as Abi,
      current_code: obj.current_code as number,
      current_version: obj.current_version as string,
    },
  };
}

export interface ReleaseDecisionInput {
  currentCode: number;
  currentVersion: string;
  release: {
    version_code: number;
    mandatory: boolean;
    min_supported_version: string | null;
  };
}

export function decideUpdate({
  currentCode,
  currentVersion,
  release,
}: ReleaseDecisionInput): { update: boolean; mandatory: boolean } {
  const update = release.version_code > currentCode;
  if (!update) {
    return { update: false, mandatory: false };
  }
  const belowMin =
    release.min_supported_version !== null &&
    release.min_supported_version !== undefined &&
    compareSemver(currentVersion, release.min_supported_version) < 0;
  return {
    update: true,
    mandatory: release.mandatory || belowMin,
  };
}

export function parsePublisherUids(raw: string | undefined): Set<string> {
  if (!raw) return new Set();
  const uids = raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  return new Set(uids);
}

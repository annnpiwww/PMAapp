import { assertEquals, assertThrows } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  ABI_OFFSET,
  CABANG_VALUES,
  compareSemver,
  decideUpdate,
  isAbi,
  MAX_APK_BYTES,
  normalizeCabang,
  objectPath,
  parsePublisherUids,
  parseSemver,
  pickRelease,
  validateCreate,
  validateLatestInput,
  validateTargetCabang,
} from './logic.ts';

const VALID_SHA = 'a'.repeat(64);

function validPayload(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    abi: 'arm64-v8a',
    base_version_code: 2154,
    version_code: 4154,
    version_name: '2.0.141',
    sha256: VALID_SHA,
    size_bytes: 24_926_834,
    changelog: 'Baseline 2.0.141',
    mandatory: false,
    min_supported_version: null,
    ...overrides,
  };
}

Deno.test('ABI_OFFSET and version_code mapping (including 2154 -> 3154/4154/6154)', () => {
  assertEquals(2154 + ABI_OFFSET['armeabi-v7a'], 3154);
  assertEquals(2154 + ABI_OFFSET['arm64-v8a'], 4154);
  assertEquals(2154 + ABI_OFFSET['x86_64'], 6154);
  assertEquals(isAbi('arm64-v8a'), true);
  assertEquals(isAbi('armeabi-v7a'), true);
  assertEquals(isAbi('x86_64'), true);
  assertEquals(isAbi('universal'), false);
});

Deno.test('parseSemver and compareSemver', () => {
  assertEquals(parseSemver('2.0.141'), [2, 0, 141]);
  assertEquals(parseSemver('2.0'), null);
  assertEquals(parseSemver('v2.0.141'), null);
  assertEquals(compareSemver('2.0.141', '2.0.142'), -1);
  assertEquals(compareSemver('2.0.142', '2.0.142'), 0);
  assertEquals(compareSemver('2.1.0', '2.0.999'), 1);
  assertThrows(() => compareSemver('bad', '2.0.0'));
});

Deno.test('validateCreate accepts valid arm32 and arm64 payloads', () => {
  const arm64 = validateCreate(validPayload());
  assertEquals(arm64.ok, true);

  const arm32 = validateCreate(
    validPayload({ abi: 'armeabi-v7a', base_version_code: 2154, version_code: 3154 }),
  );
  assertEquals(arm32.ok, true);
});

Deno.test('validateCreate rejects bad abi, mismatched offset, uppercase/short sha, 60MB size, bad semver', () => {
  const badAbi = validateCreate(validPayload({ abi: 'mips' }));
  assertEquals(badAbi.ok, false);
  if (!badAbi.ok) assertEquals(typeof badAbi.errors.abi, 'string');

  const badOffset = validateCreate(validPayload({ abi: 'arm64-v8a', base_version_code: 2154, version_code: 3154 }));
  assertEquals(badOffset.ok, false);
  if (!badOffset.ok) assertEquals(typeof badOffset.errors.version_code, 'string');

  const upperSha = validateCreate(validPayload({ sha256: 'A'.repeat(64) }));
  assertEquals(upperSha.ok, false);
  if (!upperSha.ok) assertEquals(typeof upperSha.errors.sha256, 'string');

  const shortSha = validateCreate(validPayload({ sha256: 'abc123' }));
  assertEquals(shortSha.ok, false);
  if (!shortSha.ok) assertEquals(typeof shortSha.errors.sha256, 'string');

  const oversize = validateCreate(validPayload({ size_bytes: 60 * 1024 * 1024 }));
  assertEquals(oversize.ok, false);
  if (!oversize.ok) assertEquals(typeof oversize.errors.size_bytes, 'string');
  assertEquals(MAX_APK_BYTES, 52_428_800);

  const badSemver = validateCreate(validPayload({ version_name: '2.0' }));
  assertEquals(badSemver.ok, false);
  if (!badSemver.ok) assertEquals(typeof badSemver.errors.version_name, 'string');

  const badMinSemver = validateCreate(validPayload({ min_supported_version: '2.0.141-rc1' }));
  assertEquals(badMinSemver.ok, false);
  if (!badMinSemver.ok) assertEquals(typeof badMinSemver.errors.min_supported_version, 'string');
});

Deno.test('objectPath builds deterministic server path ignoring any caller-supplied path', () => {
  const input = validPayload({ apk_path: '../../evil/override.apk', path: 'foo.apk' });
  const validated = validateCreate(input);
  assertEquals(validated.ok, true);
  if (validated.ok) {
    assertEquals(objectPath(validated.value.abi, validated.value.version_code), 'prod/4154-arm64-v8a.apk');
  }
  assertEquals(objectPath('armeabi-v7a', 3154), 'prod/3154-armeabi-v7a.apk');
});

Deno.test('decideUpdate handles equal, higher, arm32->arm64, mandatory flag, and min_supported_version', () => {
  assertEquals(
    decideUpdate({
      currentCode: 4154,
      currentVersion: '2.0.141',
      release: { version_code: 4154, mandatory: true, min_supported_version: '2.0.150' },
    }),
    { update: false, mandatory: false },
  );

  assertEquals(
    decideUpdate({
      currentCode: 4153,
      currentVersion: '2.0.140',
      release: { version_code: 4154, mandatory: false, min_supported_version: null },
    }),
    { update: true, mandatory: false },
  );

  // arm32 APK (3154) installed on arm64 phone against arm64 release (4155)
  assertEquals(
    decideUpdate({
      currentCode: 3154,
      currentVersion: '2.0.141',
      release: { version_code: 4155, mandatory: false, min_supported_version: null },
    }),
    { update: true, mandatory: false },
  );

  // mandatory via flag
  assertEquals(
    decideUpdate({
      currentCode: 4154,
      currentVersion: '2.0.141',
      release: { version_code: 4155, mandatory: true, min_supported_version: null },
    }),
    { update: true, mandatory: true },
  );

  // mandatory via min_supported_version when current < min
  assertEquals(
    decideUpdate({
      currentCode: 4154,
      currentVersion: '2.0.141',
      release: { version_code: 4155, mandatory: false, min_supported_version: '2.0.142' },
    }),
    { update: true, mandatory: true },
  );

  // not mandatory when current == min
  assertEquals(
    decideUpdate({
      currentCode: 4154,
      currentVersion: '2.0.142',
      release: { version_code: 4155, mandatory: false, min_supported_version: '2.0.142' },
    }),
    { update: true, mandatory: false },
  );
});

Deno.test('validateLatestInput and parsePublisherUids', () => {
  assertEquals(
    validateLatestInput({ abi: 'arm64-v8a', current_code: 4153, current_version: '2.0.140' }).ok,
    true,
  );
  assertEquals(
    validateLatestInput({ abi: 'bad', current_code: 0, current_version: '2.0' }).ok,
    false,
  );
  assertEquals(parsePublisherUids(undefined).size, 0);
  assertEquals(parsePublisherUids('  ').size, 0);
  const uids = parsePublisherUids(' usr_farhan , usr_aan ');
  assertEquals(uids.has('usr_farhan'), true);
  assertEquals(uids.has('usr_aan'), true);
  assertEquals(uids.size, 2);
});

Deno.test('normalizeCabang handles canonical values, aliases, whitespace, case, and unknown inputs', () => {
  assertEquals(CABANG_VALUES, ['manado', 'bali', 'ho']);
  assertEquals(normalizeCabang('manado'), 'manado');
  assertEquals(normalizeCabang(' KC Manado '), 'manado');
  assertEquals(normalizeCabang('mdo'), 'manado');
  assertEquals(normalizeCabang('DPS'), 'bali');
  assertEquals(normalizeCabang('kc bali'), 'bali');
  assertEquals(normalizeCabang('HO Makassar'), 'ho');
  assertEquals(normalizeCabang('ho'), 'ho');
  assertEquals(normalizeCabang('makassar'), null);
  assertEquals(normalizeCabang('jakarta'), null);
  assertEquals(normalizeCabang(''), null);
  assertEquals(normalizeCabang(123), null);
  assertEquals(normalizeCabang(null), null);
});

Deno.test('validateTargetCabang normalizes, dedupes, sorts, and rejects invalid values', () => {
  assertEquals(validateTargetCabang(undefined), { ok: true, value: null });
  assertEquals(validateTargetCabang(null), { ok: true, value: null });
  assertEquals(validateTargetCabang(['Bali', 'manado', 'bali', 'KC Manado']), {
    ok: true,
    value: ['bali', 'manado'],
  });

  const emptyArr = validateTargetCabang([]);
  assertEquals(emptyArr.ok, false);
  if (!emptyArr.ok) assertEquals(typeof emptyArr.errors.target_cabang, 'string');

  const badBranch = validateTargetCabang(['jakarta']);
  assertEquals(badBranch.ok, false);
  if (!badBranch.ok) {
    assertEquals(badBranch.errors.target_cabang, 'target_cabang: unknown cabang jakarta');
  }

  const nonArray = validateTargetCabang('manado');
  assertEquals(nonArray.ok, false);
  if (!nonArray.ok) assertEquals(typeof nonArray.errors.target_cabang, 'string');
});

Deno.test('validateCreate accepts valid target_cabang and rejects invalid target_cabang', () => {
  const omitted = validateCreate(validPayload());
  assertEquals(omitted.ok, true);
  if (omitted.ok) assertEquals(omitted.value.target_cabang, null);

  const targeted = validateCreate(validPayload({ target_cabang: ['KC Manado', 'dps'] }));
  assertEquals(targeted.ok, true);
  if (targeted.ok) assertEquals(targeted.value.target_cabang, ['bali', 'manado']);

  const invalid = validateCreate(validPayload({ target_cabang: ['jakarta'] }));
  assertEquals(invalid.ok, false);
  if (!invalid.ok) {
    assertEquals(invalid.errors.target_cabang, 'target_cabang: unknown cabang jakarta');
  }
});

Deno.test('pickRelease picks highest matching release for caller branch or global fallback', () => {
  const mixed = [
    { version_code: 4156, target_cabang: ['manado'] },
    { version_code: 4155, target_cabang: null },
  ];
  assertEquals(pickRelease(mixed, 'manado')?.version_code, 4156);
  assertEquals(pickRelease(mixed, 'bali')?.version_code, 4155);
  assertEquals(pickRelease(mixed, null)?.version_code, 4155);

  const multiTarget = [{ version_code: 4156, target_cabang: ['bali', 'manado'] }];
  assertEquals(pickRelease(multiTarget, 'bali')?.version_code, 4156);
  assertEquals(pickRelease(multiTarget, 'ho'), null);
  assertEquals(pickRelease(multiTarget, null), null);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync} from 'node:crypto';
import {createAppleClient} from './app_store_readiness.mjs';
import {selectQABuild, candidateStatus, attachInternalGroup} from './testflight_candidate.mjs';
import * as qa from './testflight_candidate.mjs';

function complianceFixture() {
  const source = 'a'.repeat(40), tree = 'b'.repeat(40), sha = 'c'.repeat(64);
  const config = {source, app_tree: tree, run: 100, build: '13', build_id: 'b13', ipa_sha256: sha, complete_export_compliance: true};
  const provenance = {application_source: source, application_tree: tree, controller_source: source, run: '100',
    engine: {upstream_engine: '124ecf55b0f0969b7859d2f803f0bc3a0049a4dc'},
    distribution: {code_signed: true, upload_accepted: true, bundle_id: 'com.ahmadalawi.hashiya', version: '0.6.0', build: '13', sha256: sha}};
  const processing = {id: 'b13', build: '13', version: '0.6.0', processing_confirmed: true};
  const readiness = {privacy_audit_complete: true, encryption_classification_complete: true, excluded_territories: ['FRA']};
  const declaration = {id: 'approved', attributes: {appEncryptionDeclarationState: 'APPROVED', containsThirdPartyCryptography: true,
    containsProprietaryCryptography: false, availableOnFrenchStore: false, exempt: true}};
  const build = {id: 'b13', attributes: {version: '13', processingState: 'VALID', expired: false, usesNonExemptEncryption: null},
    relationships: {app: {data: {id: '6818288428'}}, preReleaseVersion: {data: {id: 'train'}}}};
  const calls = [];
  const client = {
    async get(path) {
      if (path.startsWith('builds/')) return {data: structuredClone(build), included: [{id: 'train', type: 'preReleaseVersions', attributes: {version: '0.6.0'}}]};
      return {data: [declaration]};
    },
    async patch(path, body) {calls.push({path, body});Object.assign(build.attributes, body.data.attributes);
      if (body.data.relationships) build.relationships.appEncryptionDeclaration = body.data.relationships.appEncryptionDeclaration;}
  };
  return {evidence: {config, provenance, processing, readiness}, client, calls, declaration, build};
}

test('complete internal QA classifies only the exact signed accepted processed build using approved Apple exemption', async () => {
  const f = complianceFixture(), report = await qa.completeInternalQA(f.client, f.evidence);
  assert.equal(report.export_compliance_confirmed, true);
  assert.equal(f.build.attributes.usesNonExemptEncryption, false);
  assert.equal(report.apple_declaration_id, 'approved');
  assert.deepEqual(f.calls.map(x => x.path), ['builds/b13']);
});

test('nonexempt standard encryption requires the exact approved declaration relationship', async () => {
  const f = complianceFixture(); f.declaration.attributes.exempt = false;
  await qa.completeInternalQA(f.client, f.evidence);
  assert.equal(f.build.attributes.usesNonExemptEncryption, true);
  assert.deepEqual(f.build.relationships.appEncryptionDeclaration.data, {type: 'appEncryptionDeclarations', id: 'approved'});
});

test('wrong source, hash, upload or Apple train cannot alter compliance', async () => {
  for (const mutate of [f => f.evidence.provenance.application_source = 'f'.repeat(40),
    f => f.evidence.provenance.distribution.sha256 = 'd'.repeat(64), f => f.evidence.provenance.distribution.upload_accepted = false,
    f => f.build.relationships.app.data.id = 'other', f => f.build.attributes.processingState = 'PROCESSING']) {
    const f = complianceFixture(); mutate(f);
    await assert.rejects(qa.completeInternalQA(f.client, f.evidence), /QA /);assert.equal(f.calls.length, 0);
  }
});

test('unapproved, unclassified or incompatible declarations never guess encryption answers', async () => {
  for (const mutate of [a => a.appEncryptionDeclarationState = 'IN_REVIEW', a => a.containsThirdPartyCryptography = false,
    a => a.availableOnFrenchStore = true, a => delete a.exempt]) {
    const f = complianceFixture(); mutate(f.declaration.attributes);
    await assert.rejects(qa.completeInternalQA(f.client, f.evidence), /QA /);assert.equal(f.calls.length, 0);
  }
});

test('compliance completion is idempotent and requires actual Apple readback', async () => {
  const f = complianceFixture();await qa.completeInternalQA(f.client, f.evidence);
  await qa.completeInternalQA(f.client, f.evidence);assert.equal(f.calls.length, 1);
  const broken = complianceFixture();broken.client.patch = async (path, body) => broken.calls.push({path, body});
  await assert.rejects(qa.completeInternalQA(broken.client, broken.evidence), /QA .*readback/);
});

test('compliance receipts exclude private declaration documents and export codes', async () => {
  const f = complianceFixture();f.declaration.attributes.documentUrl = 'https://private.invalid/signed';f.declaration.attributes.codeValue = 'private-code';
  const report = await qa.completeInternalQA(f.client, f.evidence);
  assert.equal(JSON.stringify(report).includes('private.invalid'), false);
  assert.equal(JSON.stringify(report).includes('private-code'), false);
});

test('only an unambiguous existing internal group is selected automatically', () => {
  const internal = {id: 'team', attributes: {isInternalGroup: true}};
  const external = {id: 'public', attributes: {isInternalGroup: false}};
  assert.equal(qa.chooseInternalGroup([external, internal]), 'team');
  assert.equal(qa.chooseInternalGroup([external]), '');
  assert.equal(qa.chooseInternalGroup([internal, {...internal, id: 'other'}]), '');
});

test('explicitly audited unchanged encryption can reuse the live prior Apple classification when no declaration exists', async () => {
  const f = complianceFixture();f.evidence.config.reuse_published_encryption_version = '0.4.2';
  const original = f.client.get;
  f.client.get = async path => {
    if (path.includes('/appEncryptionDeclarations?')) return {data: []};
    if (path.includes('/appStoreVersions?')) return {data: [{id: 'live', attributes: {versionString: '0.4.2', platform: 'IOS', appStoreState: 'READY_FOR_DISTRIBUTION'}}]};
    if (path.startsWith('appStoreVersions/')) return {data: {id: 'live', attributes: {versionString: '0.4.2', platform: 'IOS'}, relationships: {app: {data: {id: '6818288428'}}, build: {data: {id: 'old'}}}}};
    if (path.startsWith('builds/old?')) return {data: {id: 'old', attributes: {processingState: 'VALID', usesNonExemptEncryption: false}, relationships: {app: {data: {id: '6818288428'}}, preReleaseVersion: {data: {id: 'oldtrain'}}}}, included: [{id: 'oldtrain', type: 'preReleaseVersions', attributes: {version: '0.4.2'}}]};
    return original(path);
  };
  const r = await qa.completeInternalQA(f.client, f.evidence);
  assert.equal(r.export_compliance_confirmed, true);assert.equal(r.published_classification_build, 'old');
  assert.equal(f.build.attributes.usesNonExemptEncryption, false);
  f.evidence.config.reuse_published_encryption_version = '';
  await assert.rejects(qa.completeInternalQA(f.client, f.evidence), /QA /);
});

const row = (build, version = '0.6.0', processing = 'VALID') => ({id: `build-${build}`, build, version, processing});

test('QA build allocation preserves13 when available and ignores other marketing versions', () => {
  assert.equal(selectQABuild([]).build, '13');
  assert.equal(selectQABuild([row('13', '0.4.2')]).build, '13');
});
test('QA allocation never reuses an uploaded or processing build and respects monotonic numbering', () => {
  assert.equal(selectQABuild([row('13', '0.6.0', 'PROCESSING')]).build, '14');
  assert.equal(selectQABuild([row('15')]).build, '16');
  assert.equal(selectQABuild([row('13.2.1'), row('14')]).build, '15');
});
test('Malformed or exhausted current-train build numbers fail closed', () => {
  assert.throws(() => selectQABuild([row('bad')]), /build number/);
  assert.throws(() => selectQABuild([row('9999')]), /exhausted/);
});
test('Exact build processing and beta state are separate from upload acceptance', () => {
  assert.equal(candidateStatus([], null, '13').pending, true);
  assert.equal(candidateStatus([row('13', '0.6.0', 'PROCESSING')], null, '13').pending, true);
  assert.equal(candidateStatus([row('13', '0.4.2')], null, '13').pending, true);
  assert.throws(() => candidateStatus([row('13', '0.6.0', 'INVALID')], null, '13'), /INVALID/);
  const missing = candidateStatus([row('13')], {internalBuildState: 'MISSING_EXPORT_COMPLIANCE'}, '13');
  assert.equal(missing.processing_confirmed, true);
  assert.equal(missing.internal_testing_ready, false);
  assert.equal(missing.pending, false);
  const ready = candidateStatus([row('13')], {internalBuildState: 'READY_FOR_BETA_TESTING'}, '13');
  assert.equal(ready.internal_testing_ready, true);
  assert.equal(ready.production_qualified, false);
});
test('Expired Apple builds cannot be reported as ready for internal testing', () => {
  assert.throws(() => candidateStatus([{...row('13'), expired: true}], {internalBuildState: 'READY_FOR_BETA_TESTING'}, '13'), /expired/);
});
test('Shared Apple client refuses foreign pagination origins before sending authentication', async () => {
  assert.throws(() => createAppleClient({}), /credentials/);
  const {privateKey} = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
  const client = createAppleClient({ASC_KEY_ID: 'UNITTEST', ASC_ISSUER_ID: 'unit-test',
    ASC_PRIVATE_KEY_BASE64: Buffer.from(privateKey.export({type: 'pkcs8', format: 'pem'})).toString('base64')});
  await assert.rejects(client.get('https://example.invalid/v1/builds'), /unexpected endpoint/);
  await assert.rejects(client.get('https://api.appstoreconnect.apple.com/not-v1/builds'), /unexpected endpoint/);
});
test('No selected internal group causes no Apple writes or tester invitations', async () => {
  const client = {get() {throw new Error('No request expected');}, post() {throw new Error('No write expected');}};
  assert.equal((await attachInternalGroup(client, '', row('13'))).assigned, false);
});
test('Only an existing internal group for this exact app may receive the exact build', async () => {
  const calls = [];
  const client = {
    async get(path) {
      if (path.endsWith('/builds?limit=200')) return {data: calls.flatMap(c => c.body.data)};
      return {data: {id: 'group1', attributes: {isInternalGroup: true}, relationships: {app: {data: {id: '6818288428'}}}}};
    },
    async post(path, body) {calls.push({path, body});return {};}
  };
  await attachInternalGroup(client, 'group1', row('13'));
  assert.deepEqual(calls, [{path: 'betaGroups/group1/relationships/builds', body: {data: [{type: 'builds', id: 'build-13'}]}}]);
  await attachInternalGroup(client, 'group1', row('13'));
  assert.equal(calls.length, 1, 'Already-associated builds must not be written twice');
  client.get = async () => ({data: {attributes: {isInternalGroup: false}, relationships: {app: {data: {id: '6818288428'}}}}});
  await assert.rejects(attachInternalGroup(client, 'external', row('13')), /internal group/);
  client.get = async () => ({data: {attributes: {isInternalGroup: true}, relationships: {app: {data: {id: 'other'}}}}});
  await assert.rejects(attachInternalGroup(client, 'wrong-app', row('13')), /internal group/);
  assert.equal(calls.length, 1);
});

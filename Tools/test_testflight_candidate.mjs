import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync} from 'node:crypto';
import {createAppleClient} from './app_store_readiness.mjs';
import {selectQABuild, candidateStatus, attachInternalGroup} from './testflight_candidate.mjs';

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

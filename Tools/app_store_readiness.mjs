// Read-only Apple readiness probe. Never persist or print private keys or JWTs.
import {sign} from 'node:crypto';
import {writeFileSync} from 'node:fs';

const output = process.argv[2] || 'apple-readiness.json';
const names = ['APPLE_DISTRIBUTION_P12_BASE64', 'APPLE_DISTRIBUTION_P12_PASSWORD',
  'APPLE_PROVISIONING_PROFILE_BASE64', 'ASC_PRIVATE_KEY_BASE64', 'ASC_KEY_ID', 'ASC_ISSUER_ID'];
const report = {source: process.env.GITHUB_SHA || null, bundle_id: 'com.ahmadalawi.hashiya',
  read_only: true, configured: Object.fromEntries(names.map(n => [n, Boolean(process.env[n])]))};
const save = () => writeFileSync(output, JSON.stringify(report, null, 2) + '\n');

try {
  const missing = names.filter(n => !process.env[n]);
  if (missing.length) {
    report.missing = missing; save();
    console.log(JSON.stringify({ready: false, missing})); process.exit(2);
  }
  const now = Math.floor(Date.now() / 1000);
  const encode = x => Buffer.from(JSON.stringify(x)).toString('base64url');
  const message = encode({alg: 'ES256', kid: process.env.ASC_KEY_ID, typ: 'JWT'}) + '.'
    + encode({iss: process.env.ASC_ISSUER_ID, iat: now, exp: now + 600, aud: 'appstoreconnect-v1'});
  const signature = sign('sha256', Buffer.from(message), {
    key: Buffer.from(process.env.ASC_PRIVATE_KEY_BASE64, 'base64'), dsaEncoding: 'ieee-p1363'
  }).toString('base64url');
  const token = message + '.' + signature;
  async function get(path) {
    const response = await fetch('https://api.appstoreconnect.apple.com/v1/' + path,
      {headers: {Authorization: 'Bearer ' + token}, signal: AbortSignal.timeout(30000)});
    const body = await response.json();
    if (!response.ok) throw new Error('Apple API HTTP ' + response.status + ': '
      + (body.errors || []).map(e => e.code || e.status || 'UNKNOWN').join(','));
    return body;
  }
  const apps = await get('apps?filter[bundleId]=com.ahmadalawi.hashiya&limit=10');
  const app = apps.data.find(a => a.attributes.bundleId === report.bundle_id);
  if (!app) throw new Error('The API key cannot access the Tayya app record');
  report.app = {id: app.id, name: app.attributes.name, bundle_id: app.attributes.bundleId};
  const versions = await get('apps/' + app.id + '/appStoreVersions?filter[platform]=IOS&limit=20');
  report.versions = versions.data.map(v => ({id: v.id, version: v.attributes.versionString,
    state: v.attributes.appStoreState, release_type: v.attributes.releaseType}));
  // Filtering/inclusion belongs to the build collection, not app's relationship endpoint.
  const builds = await get('builds?filter[app]=' + app.id + '&filter[version]=13&include=preReleaseVersion&limit=20');
  const trains = new Map((builds.included || []).map(v => [v.id, v.attributes.version]));
  report.build13 = builds.data.map(b => ({id: b.id, build: b.attributes.version,
    version: trains.get(b.relationships?.preReleaseVersion?.data?.id) || null,
    processing: b.attributes.processingState}));
  report.version_0_6_build_13_exists = report.build13.some(b => b.version === '0.6.0');
  report.ready_for_distribution_authentication = true;
  save(); console.log(JSON.stringify(report));
} catch (error) {
  // Error objects from signing libraries can include internals; do not log them.
  report.error = error.message.startsWith('Apple API ') || error.message.startsWith('The API key ')
    ? error.message : 'Credential format or read-only network probe failed; no secret material logged';
  save(); console.error(report.error); process.exitCode = 1;
}

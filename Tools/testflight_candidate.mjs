// Internal QA only. Shared Apple authentication, original native distributor.
// No Store version creation, review submission, tester invitations or release.
import {readFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createAppleClient} from './app_store_readiness.mjs';

const APP = '6818288428', VERSION = '0.6.0';
const scope = {label: 'TestFlight QA Candidate — Not Production Qualified', production_qualified: false,
  physical_device_tests_completed: false, app_store_review_submitted: false, public_release_requested: false};

export function selectQABuild(rows) {
  const current = rows.filter(r => r.version === VERSION);
  let greatest = 12;
  for (const r of current) {
    if (!/^[1-9]\d{0,3}(?:\.\d{1,2}){0,2}$/.test(r.build)) throw new Error('QA invalid current-train build number');
    greatest = Math.max(greatest, Number(r.build.split('.')[0]));
  }
  if (greatest >= 9999) throw new Error('QA integer build range exhausted');
  return {build: String(greatest + 1), version: VERSION,
    previously_used_builds: current.map(r => ({build: r.build, processing: r.processing})),
    reason: greatest === 12 ? 'Build13 is available' : 'Use a fresh build above all existing train builds'};
}

export function candidateStatus(rows, detail, build) {
  const found = rows.filter(r => r.version === VERSION && r.build === build);
  if (found.length > 1) throw new Error('QA ambiguous exact build');
  const result = {...scope, version: VERSION, build, processing_confirmed: false,
    internal_testing_ready: false, pending: true};
  if (!found.length) return {...result, state: 'AWAITING_APPLE_BUILD_RECORD'};
  const row = found[0];
  if (row.expired) throw new Error('QA Apple build is expired');
  if (['FAILED', 'INVALID'].includes(row.processing)) throw new Error('QA Apple processing ' + row.processing);
  if (row.processing !== 'VALID') return {...result, id: row.id, state: row.processing};
  const state = detail?.internalBuildState;
  return {...result, id: row.id, processing_confirmed: true,
    internal_testing_ready: ['READY_FOR_BETA_TESTING', 'IN_BETA_TESTING'].includes(state),
    pending: !state || state === 'PROCESSING', state: state || 'AWAITING_BETA_DETAIL',
    expired: Boolean(detail?.expired)};
}

export async function attachInternalGroup(client, groupID, row) {
  if (!groupID) return {assigned: false, reason: 'No existing internal group selected; no testers changed'};
  if (!/^[a-zA-Z0-9-]{1,80}$/.test(groupID) || row.version !== VERSION || row.processing !== 'VALID') {
    throw new Error('QA invalid internal group or unprocessed build');
  }
  const group = (await client.get(`betaGroups/${groupID}?include=app`)).data;
  if (!group?.attributes?.isInternalGroup || group.relationships?.app?.data?.id !== APP) {
    throw new Error('QA expected an existing internal group for this app');
  }
  const path = `betaGroups/${groupID}/builds?limit=200`;
  const existing = await client.get(path);
  if (!existing.data.some(r => r.id === row.id)) {
    await client.post(`betaGroups/${groupID}/relationships/builds`, {data: [{type: 'builds', id: row.id}]});
  }
  if (!(await client.get(path)).data.some(r => r.id === row.id)) throw new Error('QA internal group association is not confirmed');
  return {assigned: true, group_id: groupID, build_id: row.id, testers_invited: false, external_testing: false};
}

export function chooseInternalGroup(groups) {
  const internal = groups.filter(g => g.attributes?.isInternalGroup === true);
  return internal.length === 1 ? internal[0].id : '';
}

async function buildRows(client) {
  const app = (await client.get('apps/' + APP)).data;
  if (app?.attributes?.bundleId !== 'com.ahmadalawi.hashiya') throw new Error('QA Apple app identity mismatch');
  const rows = [];
  let path = `builds?filter[app]=${APP}&include=preReleaseVersion&limit=200`;
  for (let page = 0; path; page++) {
    if (page >= 5) throw new Error('QA build listing exceeds bounded pagination; inspect before allocation');
    const response = await client.get(path);
    const trains = new Map((response.included || []).filter(r => r.type === 'preReleaseVersions').map(r => [r.id, r.attributes.version]));
    for (const r of response.data) {
      const version = trains.get(r.relationships?.preReleaseVersion?.data?.id);
      if (!version) throw new Error('QA marketing version missing from Apple build response');
      rows.push({id: r.id, build: r.attributes.version, version, processing: r.attributes.processingState,
        expired: Boolean(r.attributes.expired)});
    }
    path = response.links?.next || null;
  }
  return rows;
}

async function main() {
  const [command, output] = process.argv.slice(2);
  if (!['select', 'status', 'assign', 'complete'].includes(command) || !output) throw new Error('QA command must be select/status/assign/complete plus a report path');
  let report = {...scope, controller_source: process.env.GITHUB_SHA || null, run: process.env.GITHUB_RUN_ID || null};
  try {
    const client = createAppleClient(), rows = await buildRows(client);
    if (command === 'complete') {
      const read = path => JSON.parse(readFileSync(path, 'utf8'));
      const evidence = {config: read('Store/internal-qa.json'), provenance: read('InternalQA/Proof/provenance.json'),
        processing: read('InternalQA/Proof/apple-processing.json'), readiness: read('Store/release-readiness.json')};
      await completeInternalQA(client, evidence, actual => {report = {...report, ...actual};writeFileSync(output, JSON.stringify(report, null, 2) + '\n');});
    } else if (command === 'select') report = {...report, ...selectQABuild(rows), read_only: true};
    else {
      const build = process.env.TAYYA_QA_BUILD;
      if (!/^[1-9]\d{0,3}$/.test(build || '')) throw new Error('QA selected build is invalid');
      const row = rows.find(r => r.version === VERSION && r.build === build);
      let detail = null;
      if (row?.processing === 'VALID') {
        try {detail = (await client.get(`builds/${encodeURIComponent(row.id)}/buildBetaDetail`)).data?.attributes;}
        catch (error) {if (error.status !== 404) throw error;}
      }
      report = {...report, ...candidateStatus(rows, detail, build), read_only: command !== 'assign'};
      if (detail?.expired) throw new Error('QA Apple build is expired');
      if (report.pending) process.exitCode = 10;
      else if (!report.internal_testing_ready) process.exitCode = 1;
      else if (command === 'assign') {
        let groupID = process.env.TAYYA_QA_INTERNAL_GROUP || '';
        if (!groupID) {
          const groups = await client.get('apps/' + APP + '/betaGroups?limit=200');
          if (groups.links?.next) throw new Error('QA internal group listing is paginated');
          report.available_internal_groups = groups.data.filter(g => g.attributes?.isInternalGroup === true)
            .map(g => ({id: g.id, name: g.attributes.name}));
          groupID = chooseInternalGroup(groups.data);
        }
        report.internal_group = await attachInternalGroup(client, groupID, row);
      }
    }
    writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify(report));
  } catch (error) {
    report.error = /^(QA |Apple API )/.test(error.message) ? error.message : 'QA Apple operation failed; credentials and personal data withheld';
    writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
    console.error(report.error); process.exitCode = 1;
  }
}
if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  main().catch(() => {console.error('QA invocation failed; no private data logged');process.exitCode = 1;});
}

export async function completeInternalQA(client, evidence, onReceipt = () => {}) {
  const {config: c, provenance: p, processing: s, readiness: r} = evidence;
  const reject = message => {throw new Error('QA ' + message);};
  if (c.complete_export_compliance !== true || !/^[a-f0-9]{40}$/.test(c.source || '')
    || !/^[a-f0-9]{40}$/.test(c.app_tree || '') || !/^[a-f0-9]{64}$/.test(c.ipa_sha256 || '')
    || !/^[1-9]\d{0,3}$/.test(c.build || '') || Number(c.build) < 13 || !/^\d+$/.test(String(c.run))) reject('explicit exact candidate evidence missing');
  if (p.application_source !== c.source || p.application_tree !== c.app_tree || p.controller_source !== c.source
    || String(p.run) !== String(c.run) || p.engine?.upstream_engine !== '124ecf55b0f0969b7859d2f803f0bc3a0049a4dc'
    || p.distribution?.code_signed !== true || p.distribution?.upload_accepted !== true
    || p.distribution.bundle_id !== 'com.ahmadalawi.hashiya' || p.distribution.version !== VERSION
    || p.distribution.build !== c.build || p.distribution.sha256 !== c.ipa_sha256
    || s.id !== c.build_id || s.build !== c.build || s.version !== VERSION || s.processing_confirmed !== true)
    reject('signed accepted exact source/build proof mismatch');
  if (r.privacy_audit_complete !== true || r.encryption_classification_complete !== true
    || !r.excluded_territories?.includes('FRA')) reject('reviewed encryption/privacy baseline missing');
  const path = 'builds/' + encodeURIComponent(c.build_id) + '?include=app,preReleaseVersion,appEncryptionDeclaration';
  const readBuild = async () => {
    const response = await client.get(path), b = response.data;
    const train = response.included?.find(v => v.type === 'preReleaseVersions' && v.id === b.relationships?.preReleaseVersion?.data?.id);
    if (b.id !== c.build_id || b.attributes.version !== c.build || b.attributes.processingState !== 'VALID'
      || b.attributes.expired || b.relationships?.app?.data?.id !== APP || train?.attributes.version !== VERSION)
      reject('Apple build identity/train/processing mismatch');
    return b;
  };
  let build = await readBuild();
  const declarations = await client.get('apps/' + APP + '/appEncryptionDeclarations?limit=200');
  if (declarations.links?.next) reject('encryption declaration listing is paginated; inspect before selection');
  const compatible = declarations.data.filter(d => d.attributes?.appEncryptionDeclarationState === 'APPROVED'
    && d.attributes.containsThirdPartyCryptography === true && d.attributes.containsProprietaryCryptography === false
    && d.attributes.availableOnFrenchStore === false && typeof d.attributes.exempt === 'boolean');
  const report = {...scope, application_source: c.source, version: VERSION, build: c.build, apple_build_id: c.build_id,
    signed_ipa_sha256: c.ipa_sha256, export_compliance_confirmed: false,
    observed_declarations: declarations.data.map(d => ({id: d.id,
      state: d.attributes?.appEncryptionDeclarationState, exempt: d.attributes?.exempt,
      third_party: d.attributes?.containsThirdPartyCryptography, proprietary: d.attributes?.containsProprietaryCryptography,
      france: d.attributes?.availableOnFrenchStore}))};
  onReceipt(report);
  // Reuse Apple's approved classification for the unchanged standard engine.
  // A missing or ambiguous official classification is never guessed or created.
  let declaration, nonExempt;
  if (compatible.length === 1) {
    declaration = compatible[0];nonExempt = !declaration.attributes.exempt;
    report.apple_declaration_id = declaration.id;
    report.apple_classifies_exempt = declaration.attributes.exempt;
  } else if (!declarations.data.length && c.reuse_published_encryption_version === '0.4.2') {
    // Exempt builds need not have a declaration resource. Reuse only the
    // explicitly audited, actually published Apple classification, never an
    // inference that standard third-party encryption means no encryption.
    const versions = await client.get('apps/' + APP + '/appStoreVersions?filter[platform]=IOS&limit=200');
    if (versions.links?.next) reject('published version listing is paginated');
    const live = versions.data.filter(v => v.attributes.versionString === '0.4.2' && v.attributes.platform === 'IOS'
      && ['READY_FOR_DISTRIBUTION', 'READY_FOR_SALE'].includes(v.attributes.appVersionState || v.attributes.appStoreState));
    if (live.length !== 1) reject('audited prior version is not the actual published version');
    const version = (await client.get('appStoreVersions/' + encodeURIComponent(live[0].id) + '?include=app,build')).data;
    if (version.attributes.versionString !== '0.4.2' || version.relationships?.app?.data?.id !== APP
      || !version.relationships?.build?.data?.id) reject('prior published app/build differs');
    const previousID = version.relationships.build.data.id;
    const previous = await client.get('builds/' + encodeURIComponent(previousID) + '?include=app,preReleaseVersion');
    const b = previous.data, train = previous.included?.find(v => v.type === 'preReleaseVersions'
      && v.id === b.relationships?.preReleaseVersion?.data?.id);
    if (b.id !== previousID || b.relationships?.app?.data?.id !== APP || train?.attributes.version !== '0.4.2'
      || b.attributes.processingState !== 'VALID' || b.attributes.usesNonExemptEncryption !== false)
      reject('prior Apple exemption is absent or belongs to another source/train');
    nonExempt = false;report.published_classification_version = '0.4.2';report.published_classification_build = b.id;
  } else reject('expected one compatible approved Apple encryption declaration');
  const relation = build.relationships?.appEncryptionDeclaration?.data?.id;
  if (relation && relation !== declaration?.id) reject('preserve a different existing build encryption declaration');
  if (build.attributes.usesNonExemptEncryption !== nonExempt || (nonExempt && relation !== declaration.id)) {
    const data = {type: 'builds', id: c.build_id, attributes: {usesNonExemptEncryption: nonExempt}};
    if (nonExempt) data.relationships = {appEncryptionDeclaration: {data: {type: 'appEncryptionDeclarations', id: declaration.id}}};
    await client.patch('builds/' + encodeURIComponent(c.build_id), {data});
    build = await readBuild();
  }
  if (build.attributes.usesNonExemptEncryption !== nonExempt
    || (nonExempt && build.relationships?.appEncryptionDeclaration?.data?.id !== declaration.id)) reject('Apple compliance readback differs');
  report.export_compliance_confirmed = true;
  onReceipt(report);
  return report;
}

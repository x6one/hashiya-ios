// Internal QA only. Shared Apple authentication, original native distributor.
// No Store version creation, review submission, tester invitations or release.
import {writeFileSync} from 'node:fs';
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
  if (!['select', 'status', 'assign'].includes(command) || !output) throw new Error('QA command must be select/status/assign plus a report path');
  let report = {...scope, controller_source: process.env.GITHUB_SHA || null, run: process.env.GITHUB_RUN_ID || null};
  try {
    const client = createAppleClient(), rows = await buildRows(client);
    if (command === 'select') report = {...report, ...selectQABuild(rows), read_only: true};
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
      else if (command === 'assign') report.internal_group = await attachInternalGroup(client, process.env.TAYYA_QA_INTERNAL_GROUP || '', row);
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

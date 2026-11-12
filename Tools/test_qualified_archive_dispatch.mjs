import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {validateQualification} from './publish_store_listing.mjs';

const workflow=readFileSync(new URL('../.github/workflows/tayya-update-publication.yml',import.meta.url),'utf8');
const script=workflow.split("<<'JS_DISPATCH'\n")[1].split('\n          JS_DISPATCH')[0].split('\n').map(line=>line.slice(10)).filter(line=>!line.startsWith('import ')).join('\n');
const source='a'.repeat(40);
const complete=names=>names.map(name=>({name,status:'completed',conclusion:'success'}));
const gates=['tools','regression (iPhone)','regression (iPad)','test (iPhone)','test (iPad)','production-review / gallery','device-package / ios-engine'];
const baseline=()=>({
  config:{app_id:'6818288428',bundle_id:'com.ahmadalawi.hashiya',version:'0.6.2',build:'17',publish_binary:true,app_ref:'integration/tayya-precision-ink',app_source:source,qualified_run:42,artwork_run:43},
  release:{event:'push',head_sha:source,name:'iPhone and iPad preflight',conclusion:'success'},
  jobs:{total_count:7,jobs:complete(gates)},
  artwork:{head_sha:source,name:'Tayya Store readiness and actual medium-phone captures',conclusion:'success'},
  artworkJobs:{total_count:3,jobs:complete(['Native store capture (iPhone)','Native store capture (iPad)','artwork'])},
  ref:{object:{sha:source}},project:"MARKETING_VERSION: '0.6.2'\nCURRENT_PROJECT_VERSION: '17'\n",previous:{total_count:0}
});
function evaluate(fixture,code=script){
  const calls=[],receipts=[];
  const replies=new Map([
    ['actions/runs/42',fixture.release],['actions/runs/42/jobs?per_page=100',fixture.jobs],
    ['actions/runs/43',fixture.artwork],['actions/runs/43/jobs?per_page=100',fixture.artworkJobs],
    ['git/ref/heads/integration/tayya-precision-ink',fixture.ref],
    ['contents/project.yml?ref='+source,{content:Buffer.from(fixture.project).toString('base64')}],
    ['actions/workflows/office-engine-spike.yml/runs?event=workflow_dispatch&head_sha='+source+'&per_page=100',fixture.previous]
  ]);
  let error;
  try{vm.runInNewContext(code,{
    assert,Buffer,validateQualification,
    readFileSync:()=>JSON.stringify(fixture.config),writeFileSync:(...args)=>receipts.push(args),
    execFileSync:(exe,args)=>{
      assert.equal(exe,'gh');
      if(args.includes('POST')){calls.push(args);return '';}
      const key=args[1].replace('repos/x6one/hashiya-ios/','');
      assert.ok(replies.has(key),'Unexpected read '+key);return JSON.stringify(replies.get(key));
    }
  });}catch(e){error=e;}
  return {calls,receipts,error};
}
const good=evaluate(baseline());assert.ifError(good.error);assert.equal(good.calls.length,1);
for(const input of ['inputs[expected_source]='+source,'inputs[publish_to_apple]=true','inputs[sign_archive]=false'])assert.ok(good.calls[0].includes(input));
assert.equal(JSON.parse(good.receipts[0][1]).upload_confirmed,false);
const rejected=[
  ['pending release',f=>f.release.conclusion=null],
  ['failed phone',f=>f.jobs.jobs.find(j=>j.name==='test (iPhone)').conclusion='failure'],
  ['missing original pad regression',f=>f.jobs.jobs=f.jobs.jobs.filter(j=>j.name!=='regression (iPad)')],
  ['skipped gallery',f=>f.jobs.jobs.find(j=>j.name==='production-review / gallery').conclusion='skipped'],
  ['missing Office',f=>{f.jobs.jobs.pop();f.jobs.total_count--;}],
  ['other source',f=>f.release.head_sha='b'.repeat(40)],
  ['not push qualification',f=>f.release.event='workflow_dispatch'],
  ['skipped iPad artwork',f=>f.artworkJobs.jobs[1].conclusion='skipped'],
  ['moved branch',f=>f.ref.object.sha='b'.repeat(40)],
  ['wrong build',f=>f.project=f.project.replace("'17'","'16'")],
  ['existing signed dispatch',f=>f.previous.total_count=1],
  ['wrong bundle',f=>f.config.bundle_id='other.app']
];
for(const [name,change] of rejected){const f=baseline();change(f);const r=evaluate(f);assert.ok(r.error,name);assert.equal(r.calls.length,0,name);}
// Replay the previous prepared script: both newly added barriers were absent.
const old=script.split('\n').filter(l=>!l.includes('artwork_run')&&!l.includes('const artwork=')&&!l.includes('artworkJobs')&&!l.includes("c.app_source,'artwork'")&&!l.includes('const previous=')&&!l.includes('previous.total_count')).join('\n');
for(const change of [f=>f.artworkJobs.jobs[1].conclusion='skipped',f=>f.previous.total_count=1]){
  const f=baseline();change(f);assert.equal(evaluate(f,old).calls.length,1,'Previous prepared handoff did not guard this regression');
}
console.log('13 conditional-dispatch scenarios passed; prior prepared script replay exposed both missing barriers. No real API write or upload performed.');

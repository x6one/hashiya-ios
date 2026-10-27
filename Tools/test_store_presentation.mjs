import test from 'node:test';
import assert from 'node:assert/strict';
import * as publisher from './publish_store_listing.mjs';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';

function repository(root,name,text){
  const path=join(root,name);mkdirSync(join(path,'App'),{recursive:true});
  writeFileSync(join(path,'App','Main.swift'),text);
  const git=(...args)=>execFileSync('git',['-C',path,...args],{encoding:'utf8'}).trim();
  git('init','-q');git('add','App');git('-c','user.name=Unit Test','-c','user.email=unit@example.invalid','commit','-qm','fixture');
  return {path,git,source:git('rev-parse','HEAD'),tree:git('rev-parse','HEAD:App')};
}
test('Attest the separate qualified application checkout, not the controller App directory',()=>{
  assert.equal(typeof publisher.validateApplicationCheckout,'function','The actual application checkout must be attested');
  const root=mkdtempSync(join(tmpdir(),'tayya-store-source-'));
  try{
    const app=repository(root,'qualified','let candidate = 1'),controller=repository(root,'controller','let old = 0');
    const config={app_source:app.source,app_tree:app.tree};
    assert.equal(publisher.validateApplicationCheckout(config,app.path),app.tree);
    assert.throws(()=>publisher.validateApplicationCheckout(config,controller.path),/checkout|source/);
    writeFileSync(join(app.path,'App','Main.swift'),'let candidate = 2');
    assert.throws(()=>publisher.validateApplicationCheckout(config,app.path),/dirty|modified/);
  }finally{rmSync(root,{recursive:true,force:true});}
});
test('Differing photographed and qualified App trees require explicit exact-source native-gallery and release-delta evidence',()=>{
  assert.equal(typeof publisher.validatePresentationCompatibility,'function');
  const c={app_source:'a'.repeat(40),app_tree:'b'.repeat(40),artwork_source:'c'.repeat(40),artwork_app_tree:'d'.repeat(40),qualified_run:123};
  const changed=['App/Canvas.swift'];
  const proof={candidate_source:c.app_source,candidate_app_tree:c.app_tree,artwork_source:c.artwork_source,artwork_app_tree:c.artwork_app_tree,native_gallery_run:123,native_gallery_reviewed:true,source_diff_reviewed:true,mode:'debug-only-source-delta-and-native-gallery-review',files:[{path:changed[0],debug_only_delta:true,literal_strings_unchanged:true,release_sha256:'e'.repeat(64),artwork_release_sha256:'e'.repeat(64)}]};
  assert.throws(()=>publisher.validatePresentationCompatibility(c,null,changed));
  assert.equal(publisher.validatePresentationCompatibility(c,proof,changed),true);
  for(const mutate of [p=>p.candidate_source='f'.repeat(40),p=>p.native_gallery_reviewed=false,p=>p.files[0].release_sha256='f'.repeat(64),p=>p.files=[]]){
    const p=structuredClone(proof);mutate(p);assert.throws(()=>publisher.validatePresentationCompatibility(c,p,changed));
  }
  assert.throws(()=>publisher.validatePresentationCompatibility(c,proof,[...changed,'App/Assets.xcassets/Contents.json']));
});
test('Byte-identical App trees retain the original artwork guard without inventing a compatibility review',()=>{
  assert.equal(typeof publisher.validatePresentationCompatibility,'function');
  assert.equal(publisher.validatePresentationCompatibility({app_tree:'b'.repeat(40),artwork_app_tree:'b'.repeat(40)},null,[]),true);
});
test('Prepare ar/en names, subtitles, privacy URLs and categories only in editable App Info',async()=>{
  assert.equal(typeof publisher.prepareDraftAppInfo,'function');
  const writes=[];const metadata={privacy_url:'https://example.invalid/privacy',suggested_primary_category:'EDUCATION',suggested_secondary_category:'PRODUCTIVITY',localizations:{'ar-SA':{name:'طَيّة — Tayya',subtitle:'دفاترك وملاحظاتك'},'en-US':{name:'Tayya — طَيّة',subtitle:'Read and write'}}};
  const api=async(method,path,payload)=>{
    if(method!=='GET'){writes.push({method,path,payload});return {data:{id:'new-en'}};}
    if(path.startsWith('apps/6818288428/appInfos?'))return {data:[{id:'live',attributes:{state:'READY_FOR_DISTRIBUTION'}},{id:'draft',attributes:{state:'PREPARE_FOR_SUBMISSION'},relationships:{}}]};
    if(path==='appInfos/draft/ageRatingDeclaration')return {data:{id:'age1',attributes:{advertising:false,unrestrictedWebAccess:false}}};
    if(path==='appInfos/draft/appInfoLocalizations?limit=200')return {data:[{id:'ar',attributes:{locale:'ar-SA',name:'old',subtitle:'old',privacyPolicyUrl:'https://example.invalid/old'}}]};
    throw new Error('Unexpected AppInfo API '+path);
  };
  const result=await publisher.prepareDraftAppInfo(api,{app_id:'6818288428'},metadata);
  assert.equal(result.age_rating_record_preserved,true);assert.equal(result.localizations_prepared,2);
  assert.deepEqual(writes.map(w=>[w.method,w.path]),[['PATCH','appInfos/draft'],['PATCH','appInfoLocalizations/ar'],['POST','appInfoLocalizations']]);
  assert.equal(writes[1].payload.data.attributes.privacyPolicyUrl,metadata.privacy_url);
  assert.equal(writes[2].payload.data.relationships.appInfo.data.id,'draft');
  assert.equal(writes.some(w=>w.path.includes('live')||w.path.includes('ageRating')),false);
});
test('Missing or ambiguous editable App Info preserves the current live listing',async()=>{
  assert.equal(typeof publisher.prepareDraftAppInfo,'function');
  for(const data of [[{id:'live',attributes:{state:'READY_FOR_DISTRIBUTION'}}],[{id:'a',attributes:{state:'PREPARE_FOR_SUBMISSION'}},{id:'b',attributes:{state:'PREPARE_FOR_SUBMISSION'}}]]){
    let writes=0;const api=async(method)=>{if(method!=='GET')writes++;return {data};};
    await assert.rejects(publisher.prepareDraftAppInfo(api,{app_id:'6818288428'},{privacy_url:'https://example.invalid/privacy',localizations:{}}),/editable|ambiguous/);
    assert.equal(writes,0);
  }
});

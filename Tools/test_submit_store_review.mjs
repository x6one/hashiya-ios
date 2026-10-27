import test from 'node:test';
import assert from 'node:assert/strict';
import {submitQualifiedReview} from './submit_store_review.mjs';

function context() {
  const config={app_id:'6818288428',bundle_id:'com.ahmadalawi.hashiya',version:'0.6.0',build:'13',app_source:'a'.repeat(40),app_tree:'b'.repeat(40),qualified_run:100,publish_binary:true,submit_for_review:true,release_after_approval:true};
  const processing={application_source:config.app_source,application_tree:config.app_tree,qualified_run:100,version:'0.6.0',build:'13',apple_build_id:'build13',signed_ipa_sha256:'c'.repeat(64),upload_accepted:true,apple_processing_confirmed:true,processing_state:'VALID'};
  const listing={app_id:config.app_id,version:'0.6.0',build:'13',application_tree:config.app_tree,app_store_version_id:'version06',result:'new-version-metadata-and-branded-images-ready',screenshots:[]};
  for(const locale of ['ar-SA','en-US'])for(const family of ['iPhone','iPad'])for(let i=0;i<6;i++)listing.screenshots.push({id:locale+family+i,locale,family,state:'COMPLETE'});
  return {config,processing,listing};
}
function apple() {
  const writes=[];
  const version={type:'appStoreVersions',id:'version06',attributes:{versionString:'0.6.0',platform:'IOS',releaseType:'MANUAL',appVersionState:'PREPARE_FOR_SUBMISSION'},relationships:{app:{data:{type:'apps',id:'6818288428'}},build:{data:null}}};
  const build={type:'builds',id:'build13',attributes:{version:'13',processingState:'VALID',expired:false,usesNonExemptEncryption:false},relationships:{app:{data:{type:'apps',id:'6818288428'}},preReleaseVersion:{data:{type:'preReleaseVersions',id:'train06'}}}};
  const submissions=[],items=[];
  async function api(method,path,payload){
    if(method!=='GET')writes.push({method,path,payload});
    if(path==='apps/6818288428')return {data:{attributes:{bundleId:'com.ahmadalawi.hashiya'}}};
    if(['appStoreVersions/version06?include=build','appStoreVersions/version06?include=app,build'].includes(path))return {data:structuredClone(version)};
    if(['builds/build13?include=app,preReleaseVersion','builds/build13?include=app,preReleaseVersion,appEncryptionDeclaration'].includes(path))return {data:structuredClone(build),included:[{type:'preReleaseVersions',id:'train06',attributes:{version:'0.6.0'}}]};
    if(path==='appStoreVersions/version06'&&method==='PATCH'){
      Object.assign(version.attributes,payload.data.attributes);version.relationships.build=payload.data.relationships.build;return {data:structuredClone(version)};
    }
    if(path.startsWith('reviewSubmissions?'))return {data:structuredClone(submissions)};
    if(path==='reviewSubmissions'&&method==='POST'){
      const row={id:'review1',attributes:{state:'READY_FOR_REVIEW'}};submissions.push(row);return {data:structuredClone(row)};
    }
    if(['reviewSubmissions/review1/items?limit=200','reviewSubmissions/review1/items?include=appStoreVersion&limit=200'].includes(path))return {data:structuredClone(items)};
    if(path==='reviewSubmissionItems'&&method==='POST'){
      const row={id:'item1',relationships:payload.data.relationships};items.push(row);return {data:structuredClone(row)};
    }
    if(path==='reviewSubmissions/review1'&&method==='PATCH'){
      assert.equal(payload.data.attributes.submitted,true);submissions[0].attributes.state='WAITING_FOR_REVIEW';version.attributes.appVersionState='WAITING_FOR_REVIEW';return {data:structuredClone(submissions[0])};
    }
    if(path==='reviewSubmissions/review1')return {data:structuredClone(submissions[0])};
    throw new Error('Unexpected test API '+method+' '+path);
  }
  return {api,writes,version,build,submissions,items};
}
test('Attach the exact processed build, choose automatic release, then submit the current Apple Review API',async()=>{
  const a=apple(),c=context();const report=await submitQualifiedReview(a.api,c);
  assert.equal(report.apple_review_state,'WAITING_FOR_REVIEW');assert.equal(report.submitted_for_review,true);assert.equal(report.public_release_confirmed,false);
  assert.deepEqual(a.writes.map(w=>[w.method,w.path]),[['PATCH','appStoreVersions/version06'],['POST','reviewSubmissions'],['POST','reviewSubmissionItems'],['PATCH','reviewSubmissions/review1']]);
  assert.deepEqual(a.writes[0].payload.data.relationships.build.data,{type:'builds',id:'build13'});
  assert.equal(a.writes[0].payload.data.attributes.releaseType,'AFTER_APPROVAL');
  assert.deepEqual(a.writes[1].payload.data.relationships.app.data,{type:'apps',id:'6818288428'});
  assert.deepEqual(a.writes[2].payload.data.relationships.appStoreVersion.data,{type:'appStoreVersions',id:'version06'});
  const count=a.writes.length;await submitQualifiedReview(a.api,c);assert.equal(a.writes.length,count,'Never submit a second review when Apple is already reviewing this exact build');
});
test('Missing authorization, qualification provenance or completed images prevents any Apple request',async()=>{
  for(const mutate of [c=>c.config.submit_for_review=false,c=>c.processing.apple_processing_confirmed=false,c=>c.processing.application_source='d'.repeat(40),c=>c.processing.signed_ipa_sha256='',c=>c.listing.screenshots[0].state='PROCESSING']){
    const c=context();mutate(c);let calls=0;
    await assert.rejects(submitQualifiedReview(async()=>{calls++;throw new Error('No API access allowed');},c));assert.equal(calls,0);
  }
});
test('A wrong, expired, invalid or unclassified Apple build cannot be attached',async()=>{
  for(const mutate of [a=>a.build.attributes.version='14',a=>a.build.attributes.expired=true,a=>a.build.attributes.processingState='INVALID',a=>a.build.attributes.usesNonExemptEncryption=null,a=>a.build.relationships.app.data.id='other']){
    const a=apple();mutate(a);await assert.rejects(submitQualifiedReview(a.api,context()));assert.equal(a.writes.length,0);
  }
});
test('Preserve another submission rather than adding unrelated review content',async()=>{
  const a=apple();a.submissions.push({id:'review1',attributes:{state:'READY_FOR_REVIEW'}});a.items.push({id:'other',relationships:{appStoreVersion:{data:{id:'another-version'}}}});
  await assert.rejects(submitQualifiedReview(a.api,context()),/another|unrelated/);assert.equal(a.writes.length,0);
});
test('Resolve existing draft item relationships explicitly and reuse the same review item',async()=>{
  const a=apple();a.submissions.push({id:'review1',attributes:{state:'READY_FOR_REVIEW'}});
  a.items.push({id:'item1',relationships:{appStoreVersion:{data:{type:'appStoreVersions',id:'version06'}}}});
  const api=async(method,path,payload)=>{
    if(path==='reviewSubmissions/review1/items?limit=200')return {data:[{id:'item1',relationships:{appStoreVersion:{links:{related:'appStoreVersions/version06'}}}}]};
    if(path==='reviewSubmissions/review1/items?include=appStoreVersion&limit=200')return {data:structuredClone(a.items)};
    return a.api(method,path,payload);
  };
  const report=await submitQualifiedReview(api,context());assert.equal(report.submitted_for_review,true);
  assert.deepEqual(a.writes.map(w=>w.path),['appStoreVersions/version06','reviewSubmissions/review1']);
});
test('Resolve and verify an existing nonexempt encryption declaration without inventing questionnaire answers',async()=>{
  for(const approved of [true,false]){
    const a=apple();a.build.attributes.usesNonExemptEncryption=true;
    a.build.relationships.appEncryptionDeclaration={data:{type:'appEncryptionDeclarations',id:'encryption1'}};
    const api=async(method,path,payload)=>{
      if(path==='builds/build13?include=app,preReleaseVersion'){
        const r=await a.api(method,path,payload);delete r.data.relationships.appEncryptionDeclaration;return r;
      }
      if(path==='builds/build13?include=app,preReleaseVersion,appEncryptionDeclaration')return a.api(method,'builds/build13?include=app,preReleaseVersion',payload);
      if(path==='appEncryptionDeclarations/encryption1?include=app')return {data:{attributes:{appEncryptionDeclarationState:approved?'APPROVED':'REJECTED'},relationships:{app:{data:{id:'6818288428'}}}}};
      return a.api(method,path,payload);
    };
    if(approved)assert.equal((await submitQualifiedReview(api,context())).submitted_for_review,true);
    else {await assert.rejects(submitQualifiedReview(api,context()),/not approved/);assert.equal(a.writes.length,0);}
  }
});
test('Refuse a same-number Store version that belongs to another Apple app before any write',async()=>{
  const a=apple();a.version.relationships.app={data:{type:'apps',id:'another-app'}};
  await assert.rejects(submitQualifiedReview(a.api,context()),/another|identity/);assert.equal(a.writes.length,0);
});
test('Final Apple readback must still identify the submitted exact build and automatic release policy',async()=>{
  for(const mutate of [v=>v.relationships.build.data.id='another-build',v=>v.attributes.releaseType='MANUAL']){
    const a=apple(),receipts=[];let versionReads=0;
    const api=async(method,path,payload)=>{
      const response=await a.api(method,path,payload);
      if(method==='GET'&&path==='appStoreVersions/version06?include=app,build'&&++versionReads===3)mutate(response.data);
      return response;
    };
    await assert.rejects(submitQualifiedReview(api,context(),r=>receipts.push(r)),/final Apple readback/);
    assert.equal(receipts.at(-1).submitted_for_review,false,'Accepted submission request is not exact-build confirmation');
  }
});

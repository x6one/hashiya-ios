import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, writeFileSync, readFileSync, mkdirSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {deflateSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {validateArtwork,reusableScreenshot,validateQualification} from './publish_store_listing.mjs';

const sha = b => createHash('sha256').update(b).digest('hex');
function png(w,h,alpha=false) {
  const crc = b => {let c=0xffffffff;for(const n of b){c^=n;for(let k=0;k<8;k++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;};
  const chunk=(name,data)=>{const type=Buffer.from(name),size=Buffer.alloc(4),sum=Buffer.alloc(4);size.writeUInt32BE(data.length);sum.writeUInt32BE(crc(Buffer.concat([type,data])));return Buffer.concat([size,type,data,sum]);};
  const header=Buffer.alloc(13);header.writeUInt32BE(w,0);header.writeUInt32BE(h,4);header[8]=8;header[9]=alpha?6:2;
  return Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),chunk('IHDR',header),chunk('IDAT',deflateSync(Buffer.alloc((w*(alpha?4:3)+1)*h))),chunk('IEND',Buffer.alloc(0))]);
}
function fixture() {
  const root=mkdtempSync(join(tmpdir(),'tayya-store-contract-'));
  const config={app_id:'6818288428',bundle_id:'com.ahmadalawi.hashiya',version:'0.6.0',build:'13',artwork_source:'a'.repeat(40),artwork_run:'42'};
  const images=[];
  for(const [family,w,h] of [['iPhone',1206,2622],['iPad',2064,2752]]) {
    mkdirSync(join(root,family,'originals'),{recursive:true});const bytes=png(w,h);
    for(let n=1;n<=6;n++) {
      const file=family+'/'+n+'.png',original_file='originals/'+n+'.png';
      writeFileSync(join(root,file),bytes);writeFileSync(join(root,family,original_file),bytes);
      images.push({family,file,original_file,width:w,height:h,sha256:sha(bytes),original_sha256:sha(bytes),source_capture:{source:config.artwork_source,test_url:'https://github.com/x6one/hashiya-ios/actions/runs/42/job/9'}});
    }
  }
  const save=()=>writeFileSync(join(root,'manifest.json'),JSON.stringify({source:config.artwork_source,run:'42',images}));save();
  return {root,config,images,save,close:()=>rmSync(root,{recursive:true,force:true})};
}
test('accepts the12 genuine-sized RGB files and their intact originals',()=>{const f=fixture();try{assert.equal(validateArtwork(f.root,f.config).length,12);}finally{f.close();}});
test('rejects accidentally targeting the published older version',()=>{const f=fixture();try{assert.throws(()=>validateArtwork(f.root,{...f.config,version:'0.4.2'}),/authorized/i);}finally{f.close();}});
test('rejects a path outside the verified artwork root',()=>{const f=fixture();try{f.images[0].file='../outside.png';f.save();assert.throws(()=>validateArtwork(f.root,f.config),/path/i);}finally{f.close();}});
test('rejects PNG alpha even when its file checksum is valid',()=>{const f=fixture();try{const row=f.images[0],b=png(row.width,row.height,true);writeFileSync(join(f.root,row.file),b);row.sha256=sha(b);f.save();assert.throws(()=>validateArtwork(f.root,f.config),/RGB|alpha/i);}finally{f.close();}});
test('rejects a modified screenshot or mismatched source revision',()=>{const f=fixture();try{const row=f.images[0];writeFileSync(join(f.root,row.file),Buffer.from('modified'));assert.throws(()=>validateArtwork(f.root,f.config),/hash|PNG/i);writeFileSync(join(f.root,row.file),readFileSync(join(f.root,row.family,row.original_file)));row.source_capture.source='b'.repeat(40);f.save();assert.throws(()=>validateArtwork(f.root,f.config),/source/i);}finally{f.close();}});
test('rejects photos from a different test run even when the source commit and image bytes match',()=>{const f=fixture();try{f.images[0].source_capture.test_url='https://github.com/x6one/hashiya-ios/actions/runs/41/job/9';f.save();assert.throws(()=>validateArtwork(f.root,f.config),/run/i);}finally{f.close();}});
test('reuses a completed owned upload without transferring its bytes again',()=>{
  const existing=[{id:'completed',type:'appScreenshots',attributes:{fileName:'Tayya-Studio2-iPhone-01.png',sourceFileChecksum:'abc',assetDeliveryState:{state:'COMPLETE',errors:[],warnings:[]}}}];
  assert.equal(reusableScreenshot(existing,'Tayya-Studio2-iPhone-01.png','abc')?.id,'completed');
});
test('does not reuse a failed Apple asset even when its filename and checksum match',()=>{
  const existing=[{id:'failed',type:'appScreenshots',attributes:{fileName:'Tayya-Studio2-iPhone-01.png',sourceFileChecksum:'abc',assetDeliveryState:{state:'FAILED',errors:[{code:'IMAGE_PROCESSING_FAILED',description:'Image rejected'}],warnings:[]}}}];
  assert.equal(reusableScreenshot(existing,'Tayya-Studio2-iPhone-01.png','abc'),undefined);
});
test('does not treat an uncompleted transfer as a reusable processed screenshot',()=>{
  const existing=[{id:'unfinished',type:'appScreenshots',attributes:{fileName:'Tayya-Studio2-iPhone-01.png',sourceFileChecksum:'abc',assetDeliveryState:{state:'AWAITING_UPLOAD',errors:[],warnings:[]}}}];
  assert.equal(reusableScreenshot(existing,'Tayya-Studio2-iPhone-01.png','abc'),undefined);
});
test('accepts all seven actual release gates while ignoring an unrelated skipped diagnostic',()=>{
  const run={head_sha:'a'.repeat(40),name:'iPhone and iPad preflight',conclusion:'success'};
  const jobs=['tools','regression (iPhone)','regression (iPad)','test (iPhone)','test (iPad)','production-review / gallery','device-package / ios-engine'].map(name=>({name,status:'completed',conclusion:'success'}));
  jobs.push({name:'Focused diagnostic',status:'completed',conclusion:'skipped'});
  assert.equal(validateQualification(run,jobs,'a'.repeat(40),'release'),true);
});
test('rejects a green tools-only workflow which never ran the required native gates',()=>{
  const run={head_sha:'a'.repeat(40),name:'iPhone and iPad preflight',conclusion:'success'};
  const jobs=[{name:'tools',status:'completed',conclusion:'success'}];
  assert.throws(()=>validateQualification(run,jobs,'a'.repeat(40),'release'),/gate|test/i);
});
test('rejects an artwork workflow whose required native iPad capture was skipped',()=>{
  const run={head_sha:'a'.repeat(40),name:'Tayya Store readiness and actual medium-phone captures',conclusion:'success'};
  const jobs=[{name:'Native store capture (iPhone)',status:'completed',conclusion:'success'},{name:'Native store capture (iPad)',status:'completed',conclusion:'skipped'},{name:'artwork',status:'completed',conclusion:'success'}];
  assert.throws(()=>validateQualification(run,jobs,'a'.repeat(40),'artwork'),/gate|test/i);
});
test('accepts separately rendered images while keeping the original native run provenance',()=>{
  const f=fixture();try{
    f.config.render_run='43';f.config.renderer_source='b'.repeat(40);
    const manifest=JSON.parse(readFileSync(join(f.root,'manifest.json'),'utf8'));
    Object.assign(manifest,{render_run:'43',renderer_source:'b'.repeat(40)});
    writeFileSync(join(f.root,'manifest.json'),JSON.stringify(manifest));
    assert.equal(validateArtwork(f.root,f.config).length,12);
  }finally{f.close();}
});
test('rejects a separately rendered artifact from the wrong renderer source',()=>{
  const f=fixture();try{
    f.config.render_run='43';f.config.renderer_source='b'.repeat(40);
    const manifest=JSON.parse(readFileSync(join(f.root,'manifest.json'),'utf8'));
    Object.assign(manifest,{render_run:'43',renderer_source:'c'.repeat(40)});
    writeFileSync(join(f.root,'manifest.json'),JSON.stringify(manifest));
    assert.throws(()=>validateArtwork(f.root,f.config),/render/i);
  }finally{f.close();}
});
test('accepts an actual complete render job independently of its native capture job',()=>{
  const run={head_sha:'b'.repeat(40),name:'Tayya Store artwork and approved publication',conclusion:'success'};
  assert.equal(validateQualification(run,[{name:'artwork',status:'completed',conclusion:'success'}],'b'.repeat(40),'render'),true);
});
test('rejects an overall green controller run which did not actually render the images',()=>{
  const run={head_sha:'b'.repeat(40),name:'Tayya Store artwork and approved publication',conclusion:'success'};
  assert.throws(()=>validateQualification(run,[{name:'artwork',status:'completed',conclusion:'skipped'}],'b'.repeat(40),'render'),/gate/i);
});

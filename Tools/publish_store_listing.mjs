// Prepare the exact qualified release; submit review only through the separately authorized guarded mode.
import {readFileSync,writeFileSync,realpathSync} from 'node:fs';
import {resolve,dirname,basename,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash,sign} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {submitQualifiedReview} from './submit_store_review.mjs';

const hash=(b,algorithm='sha256')=>createHash(algorithm).update(b).digest('hex');
const read=p=>JSON.parse(readFileSync(p,'utf8'));
export async function prepareDraftAppInfo(api,config,metadata) {
  if(config.app_id!=='6818288428')throw new Error('App Info target identity differs');
  const response=await api('GET','apps/'+config.app_id+'/appInfos?include=primaryCategory,secondaryCategory&limit=200');
  if(response.links?.next)throw new Error('App Info listing is paginated; inspect before modifying it');
  const editable=response.data.filter(info=>(info.attributes.state||info.attributes.appStoreState)==='PREPARE_FOR_SUBMISSION');
  if(editable.length!==1)throw new Error('Missing or ambiguous editable App Info; preserve the live listing');
  const info=editable[0],id=encodeURIComponent(info.id);
  if(!/^https:\/\//.test(metadata.privacy_url||''))throw new Error('A current HTTPS privacy URL is required');
  for(const locale of ['ar-SA','en-US']){
    const copy=metadata.localizations?.[locale];
    if(!copy?.name||[...copy.name].length>30||!copy.subtitle||[...copy.subtitle].length>30)
      throw new Error('App Info localization is missing or too long');
  }
  const age=(await api('GET',`appInfos/${id}/ageRatingDeclaration`)).data;
  if(!age?.id||!age.attributes||!Object.keys(age.attributes).length)throw new Error('Existing age-rating record is unavailable; do not invent questionnaire answers');
  const relationships={};
  for(const [field,value] of [['primaryCategory',metadata.suggested_primary_category],['secondaryCategory',metadata.suggested_secondary_category]]){
    if(value&&info.relationships?.[field]?.data?.id!==value)relationships[field]={data:{type:'appCategories',id:value}};
  }
  if(Object.keys(relationships).length)await api('PATCH',`appInfos/${id}`,{data:{type:'appInfos',id:info.id,relationships}});
  const locales=await api('GET',`appInfos/${id}/appInfoLocalizations?limit=200`);
  if(locales.links?.next)throw new Error('App Info localization listing is paginated');
  for(const locale of ['ar-SA','en-US']){
    const copy=metadata.localizations[locale],attrs={name:copy.name,subtitle:copy.subtitle,privacyPolicyUrl:metadata.privacy_url};
    const existing=locales.data.find(row=>row.attributes.locale===locale);
    if(existing){
      if(Object.entries(attrs).some(([key,value])=>existing.attributes[key]!==value))
        await api('PATCH','appInfoLocalizations/'+encodeURIComponent(existing.id),{data:{type:'appInfoLocalizations',id:existing.id,attributes:attrs}});
    }else await api('POST','appInfoLocalizations',{data:{type:'appInfoLocalizations',attributes:{locale,...attrs},relationships:{appInfo:{data:{type:'appInfos',id:info.id}}}}});
  }
  return {editable_app_info_id:info.id,localizations_prepared:2,age_rating_record_preserved:true,live_app_info_modified:false};
}

export function validateApplicationCheckout(config,path) {
  const root=realpathSync(path);
  const git=(...args)=>execFileSync('git',['-C',root,...args],{encoding:'utf8'}).trim();
  const tree=git('rev-parse','HEAD:App');
  if(git('rev-parse','HEAD')!==config.app_source||tree!==config.app_tree)
    throw new Error('Actual application checkout source differs from the qualified candidate');
  if(git('diff','--name-only','HEAD')||git('ls-files','--others','--exclude-standard','App','NativeOffice'))
    throw new Error('Actual application checkout is dirty or modified');
  return tree;
}

// This validates a recorded source/visual review, not an exemption from the
// exact-source native/gallery gates. Original photo hashes remain unchanged.
export function validatePresentationCompatibility(config,proof,changedFiles) {
  const artworkTree=config.artwork_app_tree??config.app_tree;
  if(!/^[a-f0-9]{40}$/.test(config.app_tree||'')||!/^[a-f0-9]{40}$/.test(artworkTree||''))
    throw new Error('Invalid photographed/qualified App tree');
  if(artworkTree===config.app_tree)return true;
  if(!proof||proof.mode!=='debug-only-source-delta-and-native-gallery-review'
    ||proof.candidate_source!==config.app_source||proof.candidate_app_tree!==config.app_tree
    ||proof.artwork_source!==config.artwork_source||proof.artwork_app_tree!==artworkTree
    ||String(proof.native_gallery_run)!==String(config.qualified_run)
    ||proof.native_gallery_reviewed!==true||proof.source_diff_reviewed!==true)
    throw new Error('Exact-source native-gallery and presentation compatibility review is missing');
  if(!Array.isArray(changedFiles)||!changedFiles.length||!Array.isArray(proof.files)
    ||proof.files.length!==changedFiles.length||new Set(proof.files.map(r=>r.path)).size!==changedFiles.length)
    throw new Error('Presentation review does not cover the complete App delta');
  for(const path of changedFiles){
    const row=proof.files.find(r=>r.path===path);
    if(!path.startsWith('App/')||!path.endsWith('.swift')||!row||row.debug_only_delta!==true
      ||row.literal_strings_unchanged!==true||!/^[a-f0-9]{64}$/.test(row.release_sha256||'')
      ||row.release_sha256!==row.artwork_release_sha256)
      throw new Error('Presentation changed or its exact release-source review is incomplete');
  }
  return true;
}

export function validateQualification(run,jobs,source,kind) {
  const name=kind==='release'?'iPhone and iPad preflight':kind==='render'?'Tayya Store artwork and approved publication':'Tayya Store readiness and actual medium-phone captures';
  if(run.head_sha!==source||run.name!==name||run.conclusion!=='success')throw new Error('The immutable source run did not qualify');
  const required=kind==='release'
    ? ['tools','regression (iPhone)','regression (iPad)','test (iPhone)','test (iPad)','production-review / gallery','device-package / ios-engine']
    : kind==='render'?['artwork']:['Native store capture (iPhone)','Native store capture (iPad)','artwork'];
  for(const name of required)if(!jobs.some(j=>j.name===name&&j.status==='completed'&&j.conclusion==='success'))
    throw new Error('Required native gate did not pass: '+name);
  return true;
}
export function reusableScreenshot(existing,name,checksum) {
  return existing.find(s=>s.attributes.fileName===name&&s.attributes.sourceFileChecksum===checksum
    && ['COMPLETE','UPLOAD_COMPLETE'].includes(s.attributes.assetDeliveryState?.state)
    && !s.attributes.assetDeliveryState?.errors?.length);
}
export function validateArtwork(root,config) {
  if(config.app_id!=='6818288428'||config.bundle_id!=='com.ahmadalawi.hashiya'||config.version!=='0.6.0'||String(config.build)!=='13')
    throw new Error('Only the authorized Tayya0.6.0(13) draft may be changed');
  const base=realpathSync(root),manifest=read(resolve(base,'manifest.json'));
  if(!/^[a-f0-9]{40}$/.test(config.artwork_source)||manifest.source!==config.artwork_source)
    throw new Error('Artwork source revision differs from the approved native capture');
  if(!/^\d+$/.test(String(config.artwork_run))||String(manifest.run)!==String(config.artwork_run))throw new Error('Artwork run differs from the qualified capture');
  if(config.render_run!==undefined&&(!/^\d+$/.test(String(config.render_run))||!/^[a-f0-9]{40}$/.test(config.renderer_source)
      ||String(manifest.render_run)!==String(config.render_run)||manifest.renderer_source!==config.renderer_source))throw new Error('Artwork renderer identity mismatch');
  if(manifest.images?.length!==12)throw new Error('Exactly12 validated artwork images are required');
  const seen=new Set(),counts={iPhone:0,iPad:0};
  function inside(file) {
    if(typeof file!=='string'||file.includes('\\')||file.startsWith('/')||file.split('/').includes('..'))throw new Error('Unsafe artwork path');
    const path=realpathSync(resolve(base,file));
    if(!path.startsWith(base+sep))throw new Error('Artwork path escapes its root');
    return path;
  }
  const files=manifest.images.map(row=>{
    if(!Object.hasOwn(counts,row.family)||seen.has(row.file))throw new Error('Duplicate or unsupported device artwork');
    seen.add(row.file);counts[row.family]++;
    if(row.source_capture?.source!==config.artwork_source)throw new Error('Screenshot source revision mismatch');
    const testPrefix='https://github.com/x6one/hashiya-ios/actions/runs/'+config.artwork_run+'/job/';
    if(!row.source_capture?.test_url?.startsWith(testPrefix)||!/^\d+$/.test(row.source_capture.test_url.slice(testPrefix.length)))throw new Error('Screenshot test run mismatch');
    const path=inside(row.file),bytes=readFileSync(path);
    if(hash(bytes)!==row.sha256)throw new Error('Artwork file hash mismatch');
    if(bytes.length<33||bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')throw new Error('Not a PNG');
    if(bytes[24]!==8||bytes[25]!==2)throw new Error('Store images must be8bit RGB without alpha');
    const wanted=row.family==='iPhone'?[1206,2622]:[2064,2752];
    if(bytes.readUInt32BE(16)!==wanted[0]||bytes.readUInt32BE(20)!==wanted[1]||row.width!==wanted[0]||row.height!==wanted[1])throw new Error('Wrong native device dimensions');
    const original=inside(dirname(row.file)+'/'+row.original_file);
    if(hash(readFileSync(original))!==row.original_sha256)throw new Error('Original screenshot hash mismatch');
    return {...row,path,bytes,md5:hash(bytes,'md5')};
  });
  if(counts.iPhone!==6||counts.iPad!==6)throw new Error('Six images per device are required');
  return files;
}

async function main() {
  const args=process.argv.slice(2),arg=(name,fallback)=>{const i=args.indexOf(name);return i<0?fallback:args[i+1];};
  const config=read(arg('--config','Store/publication.json'));
  const files=validateArtwork(arg('--artwork','StoreArtwork/Tayya-App-Store-Visuals'),config);
  if(args.includes('--validate-only')){console.log('Validated12 RGB files, target identity and all native source hashes');return;}
  const appTree=validateApplicationCheckout(config,arg('--application-path','.'));
  const artworkTree=config.artwork_app_tree??config.app_tree;
  const changedAppFiles=artworkTree===appTree?[]:execFileSync('git',['diff','--name-only',config.artwork_source,config.app_source,'--','App'],{encoding:'utf8'}).trim().split('\n').filter(Boolean);
  validatePresentationCompatibility(config,artworkTree===appTree?null:read('Store/presentation-compatibility.json'),changedAppFiles);
  const report={app_id:config.app_id,version:config.version,build:config.build,artwork_source:config.artwork_source,
    application_tree:appTree,run:process.env.GITHUB_RUN_ID,mode:'prepare-draft-only',screenshots:[],screenshot_sets:[]};
  const reportFile=arg('--report','store-listing-report.json');
  const save=()=>writeFileSync(reportFile,JSON.stringify(report,null,2)+'\n');
  const metadata=read('Store/metadata.json');
  if(metadata.version!==config.version||String(metadata.build)!==String(config.build)||metadata.bundle_id!==config.bundle_id)throw new Error('Store copy belongs to another release');
  if(!process.env.GH_TOKEN)throw new Error('Missing read-only Actions verification token');
  const qualifications=[[config.qualified_run,config.app_source,'release'],[config.artwork_run,config.artwork_source,'artwork']];
  if(config.render_run!==undefined)qualifications.push([config.render_run,config.renderer_source,'render']);
  for(const [id,source,kind] of qualifications){
    if(!/^\d+$/.test(String(id))||!/^[a-f0-9]{40}$/.test(source))throw new Error('Invalid pinned qualification identity');
    async function github(suffix){
      const response=await fetch('https://api.github.com/repos/x6one/hashiya-ios/actions/runs/'+id+suffix,{headers:{Authorization:'Bearer '+process.env.GH_TOKEN,Accept:'application/vnd.github+json'},signal:AbortSignal.timeout(30000)});
      if(!response.ok)throw new Error('Actions qualification read HTTP '+response.status);
      return response.json();
    }
    const run=await github(''),jobs=await github('/jobs?per_page=100');
    validateQualification(run,jobs.jobs,source,kind);
  }
  if(args.includes('--qualify-only')){console.log('Verified every pinned native, artwork and renderer gate without Apple writes');return;}
  for(const name of ['ASC_PRIVATE_KEY_BASE64','ASC_KEY_ID','ASC_ISSUER_ID'])if(!process.env[name])throw new Error('Missing credential: '+name);
  const enc=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
  function jwt(){const now=Math.floor(Date.now()/1000),s=enc({alg:'ES256',kid:process.env.ASC_KEY_ID,typ:'JWT'})+'.'+enc({iss:process.env.ASC_ISSUER_ID,iat:now,exp:now+600,aud:'appstoreconnect-v1'});return s+'.'+sign('sha256',Buffer.from(s),{key:Buffer.from(process.env.ASC_PRIVATE_KEY_BASE64,'base64'),dsaEncoding:'ieee-p1363'}).toString('base64url');}
  async function api(method,path,data,allow404=false){
    const response=await fetch('https://api.appstoreconnect.apple.com/v1/'+path,{method,headers:{Authorization:'Bearer '+jwt(),'Content-Type':'application/json'},body:data?JSON.stringify(data):undefined,signal:AbortSignal.timeout(30000)});
    if(response.status===204)return null;
    const body=await response.json();
    if(allow404&&response.status===404)return null;
    if(!response.ok)throw new Error('Apple API '+method+' '+path.split('?')[0]+' HTTP '+response.status+': '+(body.errors||[]).map(e=>e.code||e.status).join(','));
    return body;
  }
  const payload=(type,attributes,relationships,id)=>({data:{type,...(id?{id}:{}),...(attributes?{attributes}:{}),...(relationships?{relationships}:{})}});
  const rel=(type,id)=>({data:{type,id}});
  if(args.includes('--submit-review')){
    const reviewFile=arg('--report','store-app-review-report.json');
    let receipt={app_id:config.app_id,version:config.version,build:config.build,submitted_for_review:false,public_release_confirmed:false};
    const saveReview=value=>{receipt={controller_source:process.env.GITHUB_SHA,controller_run:process.env.GITHUB_RUN_ID,...value};writeFileSync(reviewFile,JSON.stringify(receipt,null,2)+'\n');};
    saveReview(receipt);
    try{
      const listing=read('StoreDraft/store-listing-report.json'),processing=read('store-processing-report.json');
      if(processing.controller_source!==process.env.GITHUB_SHA)throw new Error('App Review: processing receipt belongs to another controller source');
      await submitQualifiedReview(api,{config,processing,listing},saveReview);
      if(!receipt.submitted_for_review)process.exitCode=10;
      console.log(JSON.stringify(receipt));
    }catch(error){
      receipt.error=/^(App Review: |Apple API )/.test(error.message)?error.message:'App Review failed; private data withheld';
      saveReview(receipt);throw new Error(receipt.error);
    }
    return;
  }
  try {
    const app=(await api('GET','apps/'+config.app_id)).data;
    if(app.attributes.bundleId!==config.bundle_id)throw new Error('The Apple app does not match the authorized bundle');
    const versions=(await api('GET','apps/'+config.app_id+'/appStoreVersions?filter[platform]=IOS&limit=20')).data;
    const live=versions.find(v=>v.attributes.appStoreState==='READY_FOR_SALE');
    let version=versions.find(v=>v.attributes.versionString===config.version);
    if(version&&!['PREPARE_FOR_SUBMISSION','REJECTED','METADATA_REJECTED','DEVELOPER_REJECTED'].includes(version.attributes.appStoreState))throw new Error('Preserve submitted or published version: '+version.attributes.appStoreState);
    if(!version)version=(await api('POST','appStoreVersions',payload('appStoreVersions',{platform:'IOS',versionString:config.version,releaseType:live?.attributes.releaseType||'AFTER_APPROVAL',copyright:'2026 Ahmad Alawi'},{app:rel('apps',config.app_id)}))).data;
    report.app_store_version_id=version.id;report.published_version_preserved=live?.attributes.versionString||null;save();
    report.app_info=await prepareDraftAppInfo(api,config,metadata);save();
    const localizations=(await api('GET','appStoreVersions/'+version.id+'/appStoreVersionLocalizations?limit=200')).data;
    for(const [locale,copy] of Object.entries(metadata.localizations)){
      let localization=localizations.find(l=>l.attributes.locale===locale);
      const attrs={description:copy.description,keywords:copy.keywords,promotionalText:copy.promotional_text,whatsNew:copy.whats_new,supportUrl:metadata.support_url};
      if(!localization)localization=(await api('POST','appStoreVersionLocalizations',payload('appStoreVersionLocalizations',{locale,...attrs},{appStoreVersion:rel('appStoreVersions',version.id)}))).data;
      else await api('PATCH','appStoreVersionLocalizations/'+localization.id,payload('appStoreVersionLocalizations',attrs,null,localization.id));
      let sets=(await api('GET','appStoreVersionLocalizations/'+localization.id+'/appScreenshotSets?limit=50')).data;
      const inventories=new Map();
      for(const set of sets){
        const images=(await api('GET','appScreenshotSets/'+set.id+'/appScreenshots?limit=50')).data;
        inventories.set(set.id,images);
        report.screenshot_sets.push({locale,id:set.id,display:set.attributes.screenshotDisplayType,
          images:images.map(s=>({id:s.id,file:s.attributes.fileName,checksum:s.attributes.sourceFileChecksum}))});
        save();
        if(images.length&&!['APP_IPHONE_61','APP_IPAD_PRO_3GEN_129'].includes(set.attributes.screenshotDisplayType))
          throw new Error('Preserved additional draft screenshot set '+set.attributes.screenshotDisplayType+'; inspect inherited images before declaring the Store ready');
      }
      // Arabic is the approved initial marketing language, including secondary localization media.
      for(const [family,display] of [['iPhone','APP_IPHONE_61'],['iPad','APP_IPAD_PRO_3GEN_129']]){
        let set=sets.find(s=>s.attributes.screenshotDisplayType===display);
        if(!set)set=(await api('POST','appScreenshotSets',payload('appScreenshotSets',{screenshotDisplayType:display},{appStoreVersionLocalization:rel('appStoreVersionLocalizations',localization.id)}))).data;
        const existing=inventories.get(set.id)||[];
        if(existing.some(s=>!s.attributes.fileName.startsWith('Tayya-Studio2-')))throw new Error('Preserved unmanaged screenshots in the new draft; inspect before replacing');
        const desired=files.filter(f=>f.family===family),ordered=[];
        const desiredNames=new Set(desired.map(f=>'Tayya-Studio2-'+family+'-'+basename(f.file)));
        for(const stale of existing.filter(s=>!desiredNames.has(s.attributes.fileName)))await api('DELETE','appScreenshots/'+stale.id);
        for(const file of desired){
          const name='Tayya-Studio2-'+family+'-'+basename(file.file);
          let shot=reusableScreenshot(existing,name,file.md5);
          if(!shot){
            for(const stale of existing.filter(s=>s.attributes.fileName===name))await api('DELETE','appScreenshots/'+stale.id);
            shot=(await api('POST','appScreenshots',payload('appScreenshots',{fileName:name,fileSize:file.bytes.length},{appScreenshotSet:rel('appScreenshotSets',set.id)}))).data;
            if(!shot.attributes.uploadOperations?.length)throw new Error('Apple image reservation provided no upload operations');
            for(const op of shot.attributes.uploadOperations||[]){
              if(!op.url.startsWith('https://')||op.offset<0||op.length<=0||op.offset+op.length>file.bytes.length)throw new Error('Invalid Apple asset upload operation');
              const response=await fetch(op.url,{method:op.method,headers:Object.fromEntries((op.requestHeaders||[]).map(h=>[h.name,h.value])),body:file.bytes.subarray(op.offset,op.offset+op.length),signal:AbortSignal.timeout(60000)});
              if(!response.ok)throw new Error('Apple image transfer HTTP '+response.status);
            }
            await api('PATCH','appScreenshots/'+shot.id,payload('appScreenshots',{uploaded:true,sourceFileChecksum:file.md5},null,shot.id));
          }
          report.screenshots.push({id:shot.id,locale,family,file:basename(file.file),sha256:file.sha256,state:'processing'});save();
          ordered.push({type:'appScreenshots',id:shot.id});
          console.log('Prepared '+locale+'/'+family+'/'+basename(file.file));
        }
        await api('PATCH','appScreenshotSets/'+set.id+'/relationships/appScreenshots',{data:ordered});
        const actual=(await api('GET','appScreenshotSets/'+set.id+'/appScreenshots?limit=50')).data;
        if(actual.length!==6||actual.some((s,i)=>s.id!==ordered[i].id))throw new Error('Apple screenshot order differs from the approved six-image sequence');
      }
    }
    let review=await api('GET','appStoreVersions/'+version.id+'/appStoreReviewDetail',null,true);
    if(review)await api('PATCH','appStoreReviewDetails/'+review.data.id,payload('appStoreReviewDetails',{demoAccountRequired:false,notes:metadata.review.notes},null,review.data.id));
    else if(live){
      const previous=await api('GET','appStoreVersions/'+live.id+'/appStoreReviewDetail',null,true);
      const attrs=previous?.data?.attributes;
      if(!attrs?.contactEmail||!attrs?.contactPhone)throw new Error('Existing Apple review contact details are unavailable; never invent them');
      const contact=Object.fromEntries(['contactFirstName','contactLastName','contactEmail','contactPhone'].map(k=>[k,attrs[k]]));
      await api('POST','appStoreReviewDetails',payload('appStoreReviewDetails',{...contact,demoAccountRequired:false,notes:metadata.review.notes},{appStoreVersion:rel('appStoreVersions',version.id)}));
    }
    const deadline=Date.now()+180000;
    while(true){
      for(const image of report.screenshots.filter(s=>s.state!=='COMPLETE')){
        const attrs=(await api('GET','appScreenshots/'+image.id)).data.attributes;
        image.state=attrs.assetDeliveryState?.state||'UNKNOWN';
        if(image.state==='FAILED'||attrs.assetDeliveryState?.errors?.length)throw new Error('Apple image processing failed for '+image.id);
      }
      save();if(report.screenshots.every(s=>s.state==='COMPLETE'))break;
      if(Date.now()>deadline)throw new Error('Apple screenshot processing remains incomplete; keep evidence instead of claiming success');
      await new Promise(r=>setTimeout(r,2000));
    }
    report.result='new-version-metadata-and-branded-images-ready';report.submitted_for_review=false;report.binary_uploaded_by_this_script=false;save();
    console.log('Verified '+report.screenshots.length+' completed Apple screenshots; published version preserved; no review submission');
  }catch(error){report.error=error.message.startsWith('Apple API ')||error.message.startsWith('Preserved ')||error.message.startsWith('Existing ')||error.message.startsWith('Apple image ')||error.message.startsWith('Apple screenshot ')?error.message:'Store preparation failed; no key, JWT, contact data or signed upload URL logged';save();throw new Error(report.error);}
}
if(process.argv[1]&&fileURLToPath(import.meta.url)===resolve(process.argv[1]))main().catch(error=>{console.error(error.message);process.exitCode=1;});

// Apple App Store Connect OpenAPI4.5.1 review contract (official specification
// SHA2567b826ae9ca3e45b0e7df2643cbb811c9930632640944db11a8af4586fab9db46).
// The caller must first revalidate all exact-source GitHub release/artwork gates.
// No credential handling, binary upload, age/privacy guesses or retry loop here.
const APP='6818288428', BUNDLE='com.ahmadalawi.hashiya', VERSION='0.6.0';
const fail=message=>{throw new Error('App Review: '+message);};
const relation=(type,id)=>({data:{type,id}});
const payload=(type,id,attributes,relationships)=>({data:{type,...(id?{id}:{}),...(attributes?{attributes}:{}),...(relationships?{relationships}:{})}});
const state=v=>v.attributes.appVersionState||v.attributes.appStoreState;
const inflight=new Set(['WAITING_FOR_REVIEW','IN_REVIEW','PENDING_APPLE_RELEASE','PENDING_RELEASE','PROCESSING_FOR_APP_STORE','READY_FOR_SALE','READY_FOR_DISTRIBUTION']);

export function validateReviewEvidence({config:c,processing:p,listing:l}) {
  if(c.app_id!==APP||c.bundle_id!==BUNDLE||c.version!==VERSION||!/^\d+$/.test(String(c.build))||Number(c.build)<13)fail('wrong authorized target');
  if(c.publish_binary!==true||c.submit_for_review!==true||c.release_after_approval!==true)fail('explicit release authorization absent');
  if(!/^[a-f0-9]{40}$/.test(c.app_source)||!/^[a-f0-9]{40}$/.test(c.app_tree))fail('invalid immutable application identity');
  if(p.application_source!==c.app_source||p.application_tree!==c.app_tree||String(p.qualified_run)!==String(c.qualified_run)
    ||p.version!==VERSION||String(p.build)!==String(c.build)||p.upload_accepted!==true
    ||p.apple_processing_confirmed!==true||p.processing_state!=='VALID'||!p.apple_build_id
    ||!/^[a-f0-9]{64}$/.test(p.signed_ipa_sha256||''))fail('exact accepted and processed source proof missing');
  if(l.app_id!==APP||l.version!==VERSION||String(l.build)!==String(c.build)||l.application_tree!==c.app_tree
    ||!l.app_store_version_id||l.result!=='new-version-metadata-and-branded-images-ready')fail('listing belongs to another or incomplete candidate');
  const images=l.screenshots||[];
  if(images.length!==24||new Set(images.map(i=>i.id)).size!==24)fail('expected24 distinct completed image resources');
  for(const locale of ['ar-SA','en-US'])for(const family of ['iPhone','iPad']){
    const group=images.filter(i=>i.locale===locale&&i.family===family);
    if(group.length!==6||group.some(i=>i.state!=='COMPLETE'))fail('unprocessed or missing localized screenshots');
  }
}

export async function submitQualifiedReview(api,context,onReceipt=()=>{}) {
  validateReviewEvidence(context);
  const {config:c,processing:p,listing:l}=context;
  const versionID=encodeURIComponent(l.app_store_version_id),buildID=encodeURIComponent(p.apple_build_id);
  const report={application_source:c.app_source,qualified_run:c.qualified_run,version:VERSION,build:String(c.build),
    apple_build_id:p.apple_build_id,signed_ipa_sha256:p.signed_ipa_sha256,app_store_version_id:l.app_store_version_id,
    requested_release_type:'AFTER_APPROVAL',submitted_for_review:false,public_release_confirmed:false};
  const save=()=>onReceipt(structuredClone(report));
  const app=(await api('GET','apps/'+APP)).data;
  if(app.attributes.bundleId!==BUNDLE)fail('Apple app identity mismatch');
  let version=(await api('GET',`appStoreVersions/${versionID}?include=app,build`)).data;
  if(version.relationships?.app?.data?.id!==APP||version.attributes.versionString!==VERSION||version.attributes.platform!=='IOS')fail('refuse to change another Store version');
  const response=await api('GET',`builds/${buildID}?include=app,preReleaseVersion,appEncryptionDeclaration`),build=response.data;
  const train=(response.included||[]).find(r=>r.type==='preReleaseVersions'&&r.id===build.relationships?.preReleaseVersion?.data?.id);
  if(build.id!==p.apple_build_id||build.attributes.version!==String(c.build)||build.attributes.processingState!=='VALID'
    ||build.attributes.expired||build.relationships?.app?.data?.id!==APP||train?.attributes.version!==VERSION)fail('Apple build is wrong, expired, unprocessed or belongs to another app/train');
  if(typeof build.attributes.usesNonExemptEncryption!=='boolean')fail('export compliance has not been classified; never guess an encryption answer');
  if(build.attributes.usesNonExemptEncryption){
    const id=build.relationships?.appEncryptionDeclaration?.data?.id;
    if(!id)fail('nonexempt encryption requires the correct approved declaration');
    const declaration=(await api('GET',`appEncryptionDeclarations/${encodeURIComponent(id)}?include=app`)).data;
    if(declaration.relationships?.app?.data?.id!==APP||declaration.attributes.appEncryptionDeclarationState!=='APPROVED')fail('encryption declaration is not approved for this app');
  }
  if(inflight.has(state(version))){
    if(version.relationships?.build?.data?.id!==p.apple_build_id)fail('another build is already submitted or distributed');
    if(version.attributes.releaseType!=='AFTER_APPROVAL')fail('existing submission does not use the authorized automatic release policy');
    report.version_state=state(version);report.apple_review_state=state(version);
    report.submitted_for_review=true;report.existing_submission_preserved=true;save();return report;
  }
  if(!['PREPARE_FOR_SUBMISSION','READY_FOR_REVIEW','REJECTED','METADATA_REJECTED','DEVELOPER_REJECTED'].includes(state(version)))fail('version state is not safely editable: '+state(version));
  const submissions=await api('GET',`reviewSubmissions?filter[app]=${APP}&filter[platform]=IOS&limit=200`);
  if(submissions.links?.next)fail('review listing is paginated; inspect before creating another submission');
  const drafts=submissions.data.filter(r=>r.attributes.state==='READY_FOR_REVIEW');
  if(drafts.length>1)fail('multiple existing draft reviews are ambiguous');
  let review=drafts[0],items=[];
  if(review){
    const listed=await api('GET',`reviewSubmissions/${encodeURIComponent(review.id)}/items?include=appStoreVersion&limit=200`);
    if(listed.links?.next)fail('review item listing is paginated');
    items=listed.data;
    if(items.some(i=>i.relationships?.appStoreVersion?.data?.id!==l.app_store_version_id))fail('preserve another or unrelated review item');
  }
  await api('PATCH',`appStoreVersions/${versionID}`,payload('appStoreVersions',l.app_store_version_id,{releaseType:'AFTER_APPROVAL'},
    {build:relation('builds',p.apple_build_id)}));
  report.last_confirmed_operation='build-attached-and-release-policy-requested';save();
  version=(await api('GET',`appStoreVersions/${versionID}?include=app,build`)).data;
  if(version.relationships?.build?.data?.id!==p.apple_build_id||version.attributes.releaseType!=='AFTER_APPROVAL')fail('build attachment/release policy readback did not match');
  if(!review){
    review=(await api('POST','reviewSubmissions',payload('reviewSubmissions',null,{platform:'IOS'},{app:relation('apps',APP)}))).data;
    report.review_submission_id=review.id;report.last_confirmed_operation='review-draft-created';save();
  }else report.review_submission_id=review.id;
  if(!items.some(i=>i.relationships?.appStoreVersion?.data?.id===l.app_store_version_id)){
    await api('POST','reviewSubmissionItems',payload('reviewSubmissionItems',null,null,
      {reviewSubmission:relation('reviewSubmissions',review.id),appStoreVersion:relation('appStoreVersions',l.app_store_version_id)}));
    report.last_confirmed_operation='review-item-added';save();
  }
  await api('PATCH',`reviewSubmissions/${encodeURIComponent(review.id)}`,payload('reviewSubmissions',review.id,{submitted:true}));
  report.last_confirmed_operation='submission-request-accepted';save();
  const actual=(await api('GET',`reviewSubmissions/${encodeURIComponent(review.id)}`)).data;
  version=(await api('GET',`appStoreVersions/${versionID}?include=app,build`)).data;
  report.observed_apple_build_id=version.relationships?.build?.data?.id||null;
  report.observed_release_type=version.attributes.releaseType||null;
  save();
  if(version.relationships?.app?.data?.id!==APP||version.attributes.versionString!==VERSION
    ||version.attributes.platform!=='IOS'||report.observed_apple_build_id!==p.apple_build_id
    ||report.observed_release_type!=='AFTER_APPROVAL')fail('final Apple readback changed the app, build or release policy');
  report.apple_review_state=actual.attributes.state;report.version_state=state(version);
  report.submitted_for_review=['WAITING_FOR_REVIEW','IN_REVIEW','COMPLETING','COMPLETE'].includes(actual.attributes.state);
  // Storefront availability must be checked separately; API acceptance alone
  // never becomes a claim that0.6.0 is publicly available.
  save();return report;
}

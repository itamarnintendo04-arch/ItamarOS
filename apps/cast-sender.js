/* ItamarMirror: supported media sending (NOT an AirPlay / Cast receiver).
 * Google Cast: official Web Sender framework, default media receiver.
 * AirPlay: native browser media route picker where exposed by WebKit.
 */
(()=>{'use strict';
const $=id=>document.getElementById(id);
let castReady=false;
let selectedUrl=null;
const media=$('airplayVideo'),status=$('castStatus'),castButton=$('googleCastButton');
const types={mp4:'video/mp4',m4v:'video/mp4',webm:'video/webm',m3u8:'application/x-mpegURL',
 mp3:'audio/mpeg',m4a:'audio/mp4',aac:'audio/aac',wav:'audio/wav',ogg:'audio/ogg'};
function validatedURL(){
 let url;
 try{url=new URL($('castMediaUrl').value.trim())}catch{throw Error('Enter a valid HTTPS media URL.')}
 if(url.protocol!=='https:'||url.username||url.password||!url.hostname)
   throw Error('Only public HTTPS media URLs without usernames or passwords are supported.');
 const suffix=(url.pathname.split('.').pop()||'').toLowerCase();
 const type=types[suffix];
 if(!type)throw Error('Use MP4, WebM, HLS (.m3u8), MP3, M4A, AAC, WAV or OGG.');
 return {url:url.href,type};
}
function report(message){status.textContent=message;}
$('loadMedia').onclick=()=>{
 try{
  const entry=validatedURL();
  selectedUrl=entry;
  media.src=entry.url;media.load();
  report('Media URL loaded. You may play it locally, choose AirPlay, or Cast it to a compatible device.');
 }catch(e){report(e.message)}
};
$('airplayPick').onclick=()=>{
 if(!selectedUrl){report('Load a publicly accessible HTTPS media URL first.');return}
 if(typeof media.webkitShowPlaybackTargetPicker==='function'){
   media.webkitShowPlaybackTargetPicker();
   report('AirPlay output selection opened. A nearby supported AirPlay device is required.');
 }else report('AirPlay output selection is unavailable here. Use Safari / the Apple system playback controls.');
};
window.__onGCastApiAvailable=(isAvailable)=>{
 if(!isAvailable||!window.cast?.framework||!window.chrome?.cast?.media){
  report('Google Cast SDK is unavailable in this browser. Try a supported desktop Chrome browser over HTTPS.');
  return;
 }
 try{
  cast.framework.CastContext.getInstance().setOptions({
   receiverApplicationId:chrome.cast.media.DEFAULT_MEDIA_RECEIVER_APP_ID,
   autoJoinPolicy:chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED
  });
  castReady=true;
  const launcher=document.createElement('google-cast-launcher');
  launcher.setAttribute('aria-label','Choose a Google Cast device');
  launcher.style.width='46px';launcher.style.height='46px';
  launcher.style.verticalAlign='middle';
  castButton.replaceChildren(launcher);
 }catch(e){report('Cast initialization failed: '+(e?.message||'unsupported device'))}
};
$('sendCast').onclick=async()=>{
 try{
  const entry=selectedUrl||validatedURL();
  if(!castReady)throw Error('Google Cast not available. Use a supported Chrome desktop browser and Cast device.');
  const context=cast.framework.CastContext.getInstance();
  if(!context.getCurrentSession())await context.requestSession();
  const session=context.getCurrentSession();
  if(!session)throw Error('No Cast device selected.');
  const mediaInfo=new chrome.cast.media.MediaInfo(entry.url,entry.type);
  mediaInfo.metadata=new chrome.cast.media.GenericMediaMetadata();
  mediaInfo.metadata.title='ItamarMirror media';
  await session.loadMedia(new chrome.cast.media.LoadRequest(mediaInfo));
  report('Sent media playback request to your selected Google Cast receiver.');
 }catch(e){report(e?.message||'Could not start casting.')}
};
window.addEventListener('pagehide',()=>{media.pause();media.removeAttribute('src')});
})();
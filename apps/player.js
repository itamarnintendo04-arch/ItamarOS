/* ItamarOS Player – HTML media playback with browser-supported features. */
(()=>{
'use strict';
let state=null;
const $=id=>document.getElementById(id);
const make=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e};
const btn=(label,handler)=>{const b=make('button',label);b.type='button';b.onclick=handler;return b};
const fmt=s=>Number.isFinite(s)?Math.floor(s/3600)>0?Math.floor(s/3600)+':'+String(Math.floor(s/60)%60).padStart(2,'0')+':'+String(Math.floor(s%60)).padStart(2,'0'):Math.floor(s/60)+':'+String(Math.floor(s%60)).padStart(2,'0'):'--:--';
function preference(){try{return JSON.parse(localStorage.getItem('itamaros-player-prefs')||'{}')}catch{return {}}}
function persist(){if(!state)return;const m=state.media;localStorage.setItem('itamaros-player-prefs',JSON.stringify({volume:m.volume,rate:m.playbackRate,loop:state.loop,shuffle:state.shuffle,brightness:state.brightness,contrast:state.contrast,saturation:state.saturation,eqGains:state.eqGains,aspect:state.aspect,rotation:state.rotation,mirror:state.mirror,zoom:state.zoom}))}
function status(text){const e=$('player-message');if(e)e.textContent=text}
function release(){if(!state)return;const s=state;if(s.audioContext)s.audioContext.close().catch(()=>{});if(s.media){s.media.pause();s.media.removeAttribute('src');s.media.load()}if(s.image)s.image.removeAttribute('src')for(const url of s.urls)URL.revokeObjectURL(url);state=null}
function cleanupDetached(){if(state&&!document.contains(state.media))release()}
function mount(){
 cleanupDetached();release();
 const c=$('content');if(!c)return;
 c.replaceChildren();
 const root=make('section',undefined,'ios-feature');root.id='itamar-player';c.append(root);
 root.append(make('h2','▶ ItamarOS Player'));
 root.append(make('p','Local audio, video, images (including animated GIFs), and direct media URLs. Supported formats depend on your browser and device.','ios-caption'));
 const chooser=make('div',undefined,'ios-drop');chooser.textContent='Drop media here, or choose files below.';root.append(chooser);
 const row=make('div',undefined,'ios-row');const picker=make('input');picker.type='file';picker.multiple=true;picker.accept='audio/*,video/*,image/*,.gif,.png,.jpg,.jpeg,.webp,.mp3,.wav,.ogg,.opus,.flac,.m4a,.mp4,.webm,.mov,.mkv';picker.setAttribute('aria-label','Add audio, video, image and animated GIF files');row.append(picker);
 row.append(btn('Clear playlist',()=>{if(!state)return;state.media.pause();state.queue=[];state.index=-1;state.media.removeAttribute('src');state.media.load();state.image.hidden=true;state.image.removeAttribute('src');state.media.hidden=false;for(const u of state.urls)URL.revokeObjectURL(u);state.urls.clear();renderList();status('Playlist cleared.')}));
 root.append(row);
 const urlrow=make('div',undefined,'ios-row');const url=make('input');url.type='url';url.placeholder='https://example.com/video.mp4';url.setAttribute('aria-label','Direct media URL');url.style.flex='1';urlrow.append(url,btn('Add URL',()=>{try{const u=new URL(url.value.trim());if(!['http:','https:'].includes(u.protocol))throw Error();addTrack({name:u.pathname.split('/').pop()||u.hostname,url:u.href,local:false});url.value='';status('Added direct media URL. Playback may be blocked by the server or codec.')}catch{status('Enter a valid HTTP(S) URL pointing directly to media.')}}));root.append(urlrow);
 const viewer=make('div',undefined,'ios-media-viewer');root.append(viewer);
 const screen=make('video');screen.controls=true;screen.playsInline=true;screen.preload='metadata';screen.setAttribute('aria-label','Audio or video playback');viewer.append(screen);
 const image=make('img',undefined,'ios-media-image');image.alt='Selected image or animated GIF';image.hidden=true;image.setAttribute('decoding','async');viewer.append(image);
 const transport=make('div',undefined,'ios-row');
 transport.append(btn('⏮ Previous',()=>move(-1)),btn('⏯ Play / Pause',()=>state.media.paused?play():state.media.pause()),btn('⏭ Next',()=>move(1)),btn('−10s',()=>seek(-10)),btn('+10s',()=>seek(10)));
 const time=make('span','00:00 / 00:00','ios-caption');time.id='player-time';transport.append(time);root.append(transport);
 const settings=make('div',undefined,'ios-row');
 const volume=make('input');volume.type='range';volume.min=0;volume.max=1;volume.step=.01;volume.value=preference().volume??1;volume.setAttribute('aria-label','Volume');
 const rate=make('select');for(const v of [.25,.5,.75,1,1.25,1.5,1.75,2,3,4]){const o=make('option',v+'×');o.value=v;rate.append(o)}rate.value=String(preference().rate||1);
 const loop=make('input');loop.type='checkbox';loop.checked=Boolean(preference().loop);
 const shuffle=make('input');shuffle.type='checkbox';shuffle.checked=Boolean(preference().shuffle);
 const label=(txt,item)=>{const l=make('label',txt);l.append(item);return l};
 settings.append(label('Volume',volume),label('Speed',rate),label('Loop playlist',loop),label('Shuffle',shuffle));root.append(settings);
 const tools=make('div',undefined,'ios-row');
 const fileSubs=make('input');fileSubs.type='file';fileSubs.accept='.vtt,.srt,text/vtt,text/plain';fileSubs.setAttribute('aria-label','Add subtitles VTT or SRT');tools.append(fileSubs);
 tools.append(btn('Fullscreen',async()=>{try{if(document.fullscreenElement)await document.exitFullscreen();else await screen.requestFullscreen()}catch{status('Fullscreen is not supported on this device.')}}));
 tools.append(btn('Picture in Picture',async()=>{try{if(document.pictureInPictureElement)await document.exitPictureInPicture();else if(screen.requestPictureInPicture)await screen.requestPictureInPicture();else throw Error()}catch{status('Picture-in-picture is unavailable for this media or browser.')}}));
 tools.append(btn('Media info',mediaInfo));
 tools.append(btn('Screenshot',capture));
 tools.append(btn('Start / Stop recording',record));
 root.append(tools);
 const extras=make('details');extras.append(make('summary','Advanced playback settings'));
 const div=make('div',undefined,'ios-pane');
 const abrow=make('div',undefined,'ios-row');
 abrow.append(btn('Set A',()=>{state.pointA=screen.currentTime;status('Point A: '+fmt(state.pointA))}));
 abrow.append(btn('Set B',()=>{if(state.pointA===null){status('Set A first.');return}state.pointB=screen.currentTime;status('A–B repeat active: '+fmt(state.pointA)+' to '+fmt(state.pointB))}));
 abrow.append(btn('Clear A–B',()=>{state.pointA=null;state.pointB=null;status('A–B repeat disabled.')}));
 div.append(make('p','A–B repeat: play a selected portion repeatedly.','ios-caption'),abrow);
 const gainrow=make('div',undefined,'ios-row ios-eq');
 gainrow.append(btn('Enable 10-band equalizer',enableEQ));
 const preset=make('select');preset.setAttribute('aria-label','Equalizer preset');
 for(const n of ['Custom','Flat','Bass Boost','Treble Boost','Speech']){const o=make('option',n);o.value=n;preset.append(o)}
 preset.onchange=()=>{const values={Flat:[0,0,0,0,0,0,0,0,0,0],'Bass Boost':[8,7,5,3,0,0,0,0,0,0],'Treble Boost':[0,0,0,0,0,1,3,5,7,8],Speech:[-3,-2,-1,0,3,5,4,0,-2,-3]}[preset.value];if(!values)return;for(const [i,slider] of [...document.querySelectorAll('#itamar-player [data-band]')].entries()){slider.value=String(values[i]);slider.dispatchEvent(new Event('input',{bubbles:true}))}};
 gainrow.append(preset);
 const eqBands=[60,170,310,600,1000,3000,6000,12000,14000,16000];
 for(const freq of eqBands){
 const slider=make('input');slider.type='range';slider.min=-12;slider.max=12;slider.step=1;slider.value=preference().eqGains?.[freq]??0;slider.dataset.band=String(freq);slider.setAttribute('aria-label',freq+' Hz equalizer');
 slider.oninput=()=>{state.eqGains[freq]=Number(slider.value);if(state.filters?.[freq])state.filters[freq].gain.value=Number(slider.value);persist()};
 gainrow.append(label(freq+' Hz',slider));
 }div.append(make('p','10-band equalizer (Web Audio API; local media recommended).','ios-caption'),gainrow);
 const videoFilters=make('div',undefined,'ios-row');
 for(const [key,min,max,step,value] of [['brightness',50,200,5,100],['contrast',50,200,5,100],['saturation',0,200,5,100]]){
 const slider=make('input');slider.type='range';slider.min=min;slider.max=max;slider.step=step;slider.value=preference()[key]??value;slider.setAttribute('aria-label',key);
 slider.oninput=()=>{state[key]=Number(slider.value);updateFilter();persist()};videoFilters.append(label(key,slider))
 }div.append(make('p','Video filters: brightness, contrast and saturation.','ios-caption'),videoFilters);
 const videoRow=make('div',undefined,'ios-row');
 const aspect=make('select');aspect.setAttribute('aria-label','Aspect ratio');
 for(const [v,name] of [['auto','Original'],['16 / 9','16:9'],['4 / 3','4:3'],['1 / 1','1:1'],['21 / 9','21:9']]){const o=make('option',name);o.value=v;aspect.append(o)}
 aspect.value=preference().aspect||'auto';aspect.onchange=()=>{state.aspect=aspect.value;updateFilter();persist()};
 const zoom=make('input');zoom.type='range';zoom.min=1;zoom.max=2;zoom.step=.1;zoom.value=preference().zoom||1;zoom.setAttribute('aria-label','Video zoom');
 zoom.oninput=()=>{state.zoom=Number(zoom.value);updateFilter();persist()};
 videoRow.append(label('Aspect ratio',aspect),label('Zoom',zoom));
 videoRow.append(btn('Rotate 90°',()=>{state.rotation=(state.rotation+90)%360;updateFilter();persist()}));
 videoRow.append(btn('Mirror',()=>{state.mirror=!state.mirror;updateFilter();persist()}));
 div.append(videoRow);
 const subRow=make('div',undefined,'ios-row');
 subRow.append(btn('Subtitle −0.25s',()=>shiftSubtitles(-.25)));
 subRow.append(btn('Subtitle +0.25s',()=>shiftSubtitles(.25)));
 subRow.append(btn('CC on/off',toggleSubtitles));
 div.append(make('p','Subtitle timing controls (loaded external subtitles only).','ios-caption'),subRow);
 extras.append(div);root.append(extras);
 root.append(make('h3','Playlist'));
 const list=make('ul',undefined,'ios-list');list.id='player-playlist';root.append(list);
 const message=make('p','','ios-caption');message.id='player-message';message.setAttribute('role','status');root.append(message);
 root.append(make('p','Browser limitations: no guaranteed MKV/AVI/HEVC support; no native DVD/Blu-ray discs, casting, device capture, transcoding, chapter navigation, multi-audio-track selection, or VLC plug-ins.','ios-caption'));
 state={media:screen,image,queue:[],index:-1,urls:new Set(),loop:loop.checked,shuffle:shuffle.checked,pointA:null,pointB:null,recording:null,parts:[],audioContext:null,filters:null,eqGains:{...(preference().eqGains||{})},brightness:Number(preference().brightness??100),contrast:Number(preference().contrast??100),saturation:Number(preference().saturation??100),aspect:preference().aspect||'auto',rotation:Number(preference().rotation||0),mirror:Boolean(preference().mirror),zoom:Number(preference().zoom||1)};
 screen.volume=Number(volume.value);screen.playbackRate=Number(rate.value);updateFilter();
 volume.oninput=()=>{screen.volume=Number(volume.value);persist()};rate.onchange=()=>{screen.playbackRate=Number(rate.value);persist()};
 loop.onchange=()=>{state.loop=loop.checked;persist()};shuffle.onchange=()=>{state.shuffle=shuffle.checked;persist()};
 screen.ontimeupdate=()=>{time.textContent=fmt(screen.currentTime)+' / '+fmt(screen.duration);if(state&&state.pointB!==null&&state.pointA!==null&&screen.currentTime>=state.pointB)screen.currentTime=state.pointA};
 screen.onloadedmetadata=()=>time.textContent=fmt(screen.currentTime)+' / '+fmt(screen.duration);
 screen.onended=()=>move(1,true);
 screen.onerror=()=>status('Playback failed. This format, URL or codec may be unsupported by your browser.');
 picker.onchange=()=>{for(const f of picker.files||[])addFile(f);picker.value=''};
 const drop=(event)=>{event.preventDefault();chooser.classList.remove('dragging');for(const f of event.dataTransfer?.files||[])addFile(f)};
 chooser.ondragover=e=>{e.preventDefault();chooser.classList.add('dragging')};
 chooser.ondragleave=()=>chooser.classList.remove('dragging');chooser.ondrop=drop;
 fileSubs.onchange=async()=>{const f=fileSubs.files?.[0];if(!f)return;try{let text=await f.text();if(/\.srt$/i.test(f.name))text='WEBVTT\n\n'+text.replace(/(\d\d:\d\d:\d\d),(\d\d\d)/g,'$1.$2');if(!text.trimStart().startsWith('WEBVTT'))throw Error('Subtitles must be valid .srt or .vtt text');for(const old of screen.querySelectorAll('track'))old.remove();const subURL=URL.createObjectURL(new Blob([text],{type:'text/vtt'}));state.urls.add(subURL);const track=make('track');track.kind='subtitles';track.label=f.name;track.srclang='en';track.src=subURL;track.default=true;screen.append(track);track.addEventListener('load',()=>{track.track.mode='showing'});status('Subtitles loaded. Choose CC in the player controls if needed.')}catch(e){status('Unable to load subtitles: '+e.message)}};
 document.onkeydown=function(event){if(!state||!document.contains(screen)||$('window')?.classList.contains('hidden'))return;if(['INPUT','TEXTAREA','SELECT','BUTTON'].includes(document.activeElement?.tagName))return;if(event.code==='Space'){event.preventDefault();screen.paused?play():screen.pause()}else if(event.code==='ArrowRight'){event.preventDefault();seek(5)}else if(event.code==='ArrowLeft'){event.preventDefault();seek(-5)}};
 status('Choose audio, video, images or animated GIFs to get started. Playlist is kept for this session.');
}
function updateFilter(){if(!state)return;
 const m=state.media;m.style.filter='brightness('+state.brightness+'%) contrast('+state.contrast+'%) saturate('+state.saturation+'%)';
 m.style.aspectRatio=state.aspect;m.style.objectFit='contain';
 m.style.transform='rotate('+state.rotation+'deg) scaleX('+(state.mirror?-1:1)+') scale('+state.zoom+')';if(state.image){state.image.style.filter=m.style.filter;state.image.style.aspectRatio=state.aspect;state.image.style.objectFit='contain';state.image.style.transform=m.style.transform}
}
function isImage(track){return /\.(gif|png|jpe?g|webp|bmp|avif|svg)(?:$|[?#])/i.test(track.name||'') || /^image\//i.test(track.type||'')}
function addFile(file){if(!state)return;const object=URL.createObjectURL(file);state.urls.add(object);addTrack({name:file.name,url:object,local:true,type:file.type})}
function addTrack(track){if(!state)return;state.queue.push(track);renderList();if(state.index<0)select(0)}
function renderList(){if(!state)return;const root=$('player-playlist');if(!root)return;root.replaceChildren();state.queue.forEach((item,i)=>{const li=make('li');const b=btn((i===state.index?'▶ ':'')+item.name,()=>select(i,true));li.append(b,btn('↑',()=>reorder(i,-1)),btn('↓',()=>reorder(i,1)),btn('×',()=>remove(i)));root.append(li)});if(!state.queue.length)root.append(make('li','No media selected.'))}
function reorder(i,d){if(!state)return;const j=i+d;if(j<0||j>=state.queue.length)return;[state.queue[i],state.queue[j]]=[state.queue[j],state.queue[i]];if(state.index===i)state.index=j;else if(state.index===j)state.index=i;renderList()}
function remove(i){if(!state)return;const old=state.queue.splice(i,1)[0];if(old?.local){URL.revokeObjectURL(old.url);state.urls.delete(old.url)}if(state.index===i){state.index=-1;state.media.pause();state.media.removeAttribute('src');state.media.load();state.image.hidden=true;state.image.removeAttribute('src');state.media.hidden=false;if(state.queue.length)select(Math.min(i,state.queue.length-1))}else if(i<state.index)state.index--;renderList()}
function select(i,auto=false){if(!state||i<0||i>=state.queue.length)return;const s=state;s.pointA=null;s.pointB=null;s.index=i;const track=s.queue[i];
 if(isImage(track)){s.media.pause();s.media.removeAttribute('src');s.media.load();s.media.hidden=true;s.image.hidden=false;s.image.src=track.url;status('Showing '+track.name+( /\.gif$/i.test(track.name)?' — animated GIF':' — image')+'.');}
 else{s.image.removeAttribute('src');s.image.hidden=true;s.media.hidden=false;s.media.src=track.url;s.media.load();status('Selected: '+track.name);if(auto)play();}
 renderList()}
function play(){if(!state||state.index<0)return;if(isImage(state.queue[state.index])){status('Images are displayed directly. Animated GIFs animate automatically.');return}state.media.play().catch(e=>status('Unable to play: '+(e.message||'Unsupported format')))}
function move(delta,automatic=false){if(!state||!state.queue.length)return;let n=state.index+delta;if(state.shuffle&&state.queue.length>1){do{n=Math.floor(Math.random()*state.queue.length)}while(n===state.index)}else if(n>=state.queue.length){if(!state.loop){if(automatic){state.media.pause();return}n=0}else n=0}else if(n<0)n=state.loop?state.queue.length-1:0;select(n,true)}
function seek(offset){if(state&&Number.isFinite(state.media.duration))state.media.currentTime=Math.max(0,Math.min(state.media.duration,state.media.currentTime+offset))}
function enableEQ(){
 if(!state)return;
 try{
  if(!state.audioContext){
   const C=window.AudioContext||window.webkitAudioContext;if(!C)throw Error('Web Audio is unsupported');
   const ctx=new C();const source=ctx.createMediaElementSource(state.media);
   const filters={};let last=source;
   const bands=[60,170,310,600,1000,3000,6000,12000,14000,16000];
   for(let i=0;i<bands.length;i++){const f=bands[i];const bi=ctx.createBiquadFilter();
    bi.type=i===0?'lowshelf':i===bands.length-1?'highshelf':'peaking';
    bi.frequency.value=Math.min(f,ctx.sampleRate/2-100);bi.Q.value=1;bi.gain.value=Number(state.eqGains[f]||0);
    last.connect(bi);last=bi;filters[f]=bi;
   }last.connect(ctx.destination);state.audioContext=ctx;state.filters=filters;
  }state.audioContext.resume();status('10-band equalizer enabled.');
 }catch(e){status('Equalizer could not start: '+e.message)}
}
function shiftSubtitles(delta){
 if(!state)return;const tracks=state.media.textTracks;if(!tracks?.length){status('Load an external subtitle file first.');return}
 const cues=tracks[0].cues;if(!cues||!cues.length){status('Subtitle cues are not ready yet.');return}
 try{for(const cue of cues){cue.startTime=Math.max(0,cue.startTime+delta);cue.endTime=Math.max(cue.startTime+.05,cue.endTime+delta)}status('Subtitle timing shifted by '+delta+' seconds.')}catch{status('Subtitle adjustment is not supported by this browser.')}
}
function toggleSubtitles(){if(!state||!state.media.textTracks?.length){status('Load subtitles first.');return}const t=state.media.textTracks[0];t.mode=t.mode==='showing'?'hidden':'showing';status('Subtitles '+(t.mode==='showing'?'enabled.':'disabled.'))}
function mediaInfo(){if(!state||state.index<0){status('Select a media item first.');return}const m=state.media,track=state.queue[state.index];if(isImage(track)){status('Image: '+track.name+(state.image?.naturalWidth?' · '+state.image.naturalWidth+'×'+state.image.naturalHeight:'')+(/\.gif$/i.test(track.name)?' · animated GIF':''));return}status('Media: '+track.name+' · Duration: '+fmt(m.duration)+(m.videoWidth?' · '+m.videoWidth+'×'+m.videoHeight:'')+' · Speed: '+m.playbackRate+'×')}
function capture(){if(!state)return;const media=state.media;if(!media.videoWidth||!media.videoHeight){status('A video frame is needed for screenshots.');return}try{const canvas=document.createElement('canvas');canvas.width=media.videoWidth;canvas.height=media.videoHeight;canvas.getContext('2d').drawImage(media,0,0);canvas.toBlob(blob=>{if(!blob){status('Screenshot failed');return}const u=URL.createObjectURL(blob),a=make('a');a.href=u;a.download='ItamarOS-screenshot.png';a.click();setTimeout(()=>URL.revokeObjectURL(u),3000)},'image/png')}catch{status('Screenshot blocked, possibly because media comes from another website.')} }
function record(){
 if(!state)return;const s=state;if(s.recording&&s.recording.state!=='inactive'){s.recording.stop();status('Recording stopped. Download should begin.');return}
 const media=s.media;if(!media.captureStream&&!media.mozCaptureStream){status('Recording is not supported by this browser.');return}if(!window.MediaRecorder){status('MediaRecorder is unavailable.');return}
 try{const stream=(media.captureStream||media.mozCaptureStream).call(media);
 const mime=['video/webm;codecs=vp9,opus','video/webm;codecs=vp8,opus','video/webm','audio/webm'].find(x=>MediaRecorder.isTypeSupported(x))||'';
 const r=new MediaRecorder(stream,mime?{mimeType:mime}:{});
 const chunks=[];r.ondataavailable=e=>{if(e.data?.size)chunks.push(e.data)};
 r.onstop=()=>{if(!chunks.length){status('No recording data captured.');return}const blob=new Blob(chunks,{type:r.mimeType||'video/webm'}),u=URL.createObjectURL(blob),a=make('a');a.href=u;a.download='ItamarOS-recording.webm';a.click();setTimeout(()=>URL.revokeObjectURL(u),5000);status('Recording saved.')};
 r.start(1000);s.recording=r;status('Recording active. Press Start / Stop recording again to save.');
 }catch(e){status('Recording unavailable: '+e.message)}
}
window.ItamarPlayer={mount,release};
})();
/* Kenney CC0 sounds are downloaded at build time and bundled under /assets/sfx.
   Audio is optional, off when user chooses mute, and never auto-starts. */
(()=>{
'use strict';
const FILES=Object.freeze({
 tap:'click_002.wav',
 move:'click_005.wav',
 collect:'drop_001.wav',
 win:'confirmation_001.wav',
 error:'error_004.wav',
 gameover:'bong_001.wav'
});
const STORAGE='itamaros-game-sfx-enabled';
let enabled=true;
try{enabled=localStorage.getItem(STORAGE)!=='false'}catch{}
let context=null;
function fallback(type){
 try{
  const AudioContext=window.AudioContext||window.webkitAudioContext;
  if(!AudioContext)return;
  context??=new AudioContext();
  if(context.state==='suspended')context.resume().catch(()=>{});
  const osc=context.createOscillator(),gain=context.createGain();
  const now=context.currentTime;
  const freq={tap:510,move:370,collect:750,win:920,error:140,gameover:100}[type]||430;
  osc.type=type==='error'?'triangle':'sine';
  osc.frequency.setValueAtTime(freq,now);
  osc.frequency.exponentialRampToValueAtTime(Math.max(60,freq*(type==='gameover'?.4:1.18)),now+.13);
  gain.gain.setValueAtTime(.035,now);
  gain.gain.exponentialRampToValueAtTime(.001,now+.15);
  osc.connect(gain).connect(context.destination);
  osc.start(now);osc.stop(now+.16);
 }catch{}
}
function play(type='tap'){
 if(!enabled)return;
 const file=FILES[type]||FILES.tap;
 try{
  const a=new Audio('/assets/sfx/'+file);
  a.volume=.38;
  a.play().catch(()=>fallback(type));
 }catch{fallback(type)}
}
function toggle(){
 enabled=!enabled;
 try{localStorage.setItem(STORAGE, String(enabled))}catch{}
 return enabled;
}
function isEnabled(){return enabled}
window.ItamarGameAudio={play,toggle,isEnabled,files:FILES};
})();

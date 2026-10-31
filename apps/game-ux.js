/* ItamarOS Games UX: original colorful vector illustrations, pointer gestures,
   and optional Kenney CC0 sound effects (downloaded at build time). */
(()=>{
'use strict';
const ART={
 '2048':'<rect x="9" y="9" width="30" height="30" rx="7" fill="#f8bb4f"/><rect x="43" y="9" width="30" height="30" rx="7" fill="#ef6a64"/><rect x="9" y="43" width="30" height="30" rx="7" fill="#66c4f4"/><rect x="43" y="43" width="30" height="30" rx="7" fill="#a78bfa"/><g fill="#fff" font-size="14" font-weight="800" text-anchor="middle"><text x="24" y="30">2</text><text x="58" y="30">4</text><text x="24" y="64">8</text><text x="58" y="64">16</text></g>',
 snake:'<path d="M10 55C20 69 42 69 48 53C53 39 26 40 31 24C34 11 54 12 62 23" fill="none" stroke="#2eaa7c" stroke-width="16" stroke-linecap="round"/><path d="M10 55C20 69 42 69 48 53C53 39 26 40 31 24C34 11 54 12 62 23" fill="none" stroke="#87eac2" stroke-width="6" stroke-linecap="round"/><ellipse cx="64" cy="25" rx="14" ry="12" fill="#69da9b"/><circle cx="67" cy="20" r="3" fill="#173b2d"/><path d="M75 29l7 3-7 3" fill="none" stroke="#f66587" stroke-width="2" stroke-linecap="round"/><circle cx="15" cy="19" r="8" fill="#e84f68"/><circle cx="24" cy="21" r="8" fill="#f66179"/><path d="M20 14q2-8 8-8" stroke="#398654" stroke-width="3" fill="none"/>',
 memory:'<rect x="10" y="14" width="40" height="51" rx="7" fill="#b4a5f8" transform="rotate(-13 30 39)"/><rect x="32" y="14" width="40" height="51" rx="7" fill="#69c7f2" transform="rotate(9 52 39)"/><path d="M49 27l4 9 10 1-8 7 2 10-9-5-8 5 2-10-8-7 10-1z" fill="#ffdc6d" stroke="#fff" stroke-width="2"/>',
 tictactoe:'<rect x="9" y="8" width="66" height="66" rx="12" fill="#2a6090"/><path d="M31 17v47M53 17v47M18 31h48M18 53h48" stroke="#89c1ef" stroke-width="3"/><path d="M19 19l9 9m0-9-9 9M56 57l8 8m0-8-8 8" stroke="#ffbc62" stroke-width="4" stroke-linecap="round"/><circle cx="41" cy="42" r="7" stroke="#f174a8" stroke-width="4" fill="none"/>',
 guess:'<circle cx="41" cy="41" r="31" fill="#f9b96c"/><circle cx="41" cy="41" r="23" fill="#fce1a1"/><text x="41" y="57" fill="#62498e" font-size="49" font-weight="900" text-anchor="middle">?</text>',
 reaction:'<path d="M45 7L18 47h22l-7 30L67 34H46L55 7z" fill="#f8cf63" stroke="#f1904d" stroke-width="3" stroke-linejoin="round"/><circle cx="70" cy="63" r="6" fill="#74d6fa"/><circle cx="14" cy="20" r="4" fill="#c9a1ff"/>',
 rps:'<path d="M22 65l-7-21q-3-8 3-10q5-2 9 4V21q0-8 7-8t7 8V13q0-7 7-7t7 7v7q3-6 8-4q7 3 4 11l-5 23-8 16z" fill="#f6b89c" stroke="#de846e" stroke-width="3"/><path d="M30 42v13m12-12v12m13-12v12" stroke="#df8c73" stroke-width="2"/>',
 math:'<rect x="10" y="10" width="62" height="62" rx="14" fill="#68c2f8"/><path d="M27 25v22M16 36h22" stroke="#fff" stroke-width="6" stroke-linecap="round"/><path d="M48 29h16M48 43h16" stroke="#fff" stroke-width="6" stroke-linecap="round"/><circle cx="51" cy="58" r="3" fill="#ffe09c"/><circle cx="62" cy="58" r="3" fill="#ffe09c"/>',
 word:'<rect x="5" y="19" width="25" height="36" rx="5" fill="#af91f9"/><rect x="29" y="11" width="25" height="36" rx="5" fill="#ed8caa"/><rect x="53" y="19" width="25" height="36" rx="5" fill="#73cfbd"/><g fill="#fff" font-size="22" text-anchor="middle" font-weight="800"><text x="17" y="44">A</text><text x="41" y="36">B</text><text x="65" y="44">C</text></g>',
 pattern:'<circle cx="25" cy="25" r="16" fill="#f57877"/><circle cx="57" cy="25" r="16" fill="#6aa7f8"/><circle cx="25" cy="57" r="16" fill="#f6d26d"/><circle cx="57" cy="57" r="16" fill="#74dcb0"/><path d="M26 17v16m-8-8h16M53 21h8M20 52l9 10m0-10-9 10" stroke="#fff" stroke-width="3" opacity=".9"/>',
 connect:'<rect x="8" y="10" width="68" height="63" rx="11" fill="#317cca"/><g stroke="#13386b" stroke-width="2"><circle cx="22" cy="26" r="8" fill="#f3756b"/><circle cx="41" cy="26" r="8" fill="#fff7dc"/><circle cx="60" cy="26" r="8" fill="#f6cf68"/><circle cx="22" cy="45" r="8" fill="#f6cf68"/><circle cx="41" cy="45" r="8" fill="#f3756b"/><circle cx="60" cy="45" r="8" fill="#f6cf68"/><circle cx="22" cy="64" r="8" fill="#fff7dc"/><circle cx="41" cy="64" r="8" fill="#f3756b"/><circle cx="60" cy="64" r="8" fill="#fff7dc"/></g>'
};
ART.words=ART.word;ART.rockpaperscissors=ART.rps;ART.guessnumber=ART.guess;
function illustration(key){
 const clean=String(key).toLowerCase().replace(/[^a-z0-9]/g,'');
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 svg.setAttribute('viewBox','0 0 84 84');svg.setAttribute('aria-hidden','true');svg.classList.add('itamar-art');
 svg.innerHTML=ART[clean]||ART.guess;
 return svg;
}
function swipe(element, callback, minimum=20){
 element.style.touchAction='none';
 let start=null;
 element.addEventListener('pointerdown',event=>{
  if(event.button!==0)return;start={x:event.clientX,y:event.clientY,id:event.pointerId};
  try{element.setPointerCapture(event.pointerId)}catch{}
 });
 element.addEventListener('pointerup',event=>{
  if(!start||start.id!==event.pointerId)return;
  const dx=event.clientX-start.x,dy=event.clientY-start.y;start=null;
  if(Math.max(Math.abs(dx),Math.abs(dy))<minimum)return;
  callback(Math.abs(dx)>Math.abs(dy)?(dx>0?'right':'left'):(dy>0?'down':'up'),{dx,dy,x:event.clientX,y:event.clientY});
 });
 element.addEventListener('pointercancel',()=>{start=null});
 return element;
}
const sourceFiles={tap:'click1.wav',move:'switch14.wav',collect:'switch17.wav',win:'switch5.wav',error:'switch8.wav',flip:'click3.wav'};
let soundOn=false;
try{soundOn=localStorage.getItem('itamaros-games-sound')!=='off'}catch{soundOn=true}
let audioCtx=null;
function sound(id){
 if(!soundOn)return;
 const file=sourceFiles[id]||sourceFiles.tap;
 try{
  const audio=new Audio('/assets/sfx/'+file);
  audio.volume=.4;
  const pending=audio.play();
  if(pending&&pending.catch)pending.catch(()=>tone(id));
 }catch{tone(id)}
}
function tone(id){
 // Offline fallback before imported CC0 assets are published.
 try{
  const Cls=window.AudioContext||window.webkitAudioContext;if(!Cls)return;
  audioCtx ||=new Cls();
  if(audioCtx.state==='suspended')audioCtx.resume().catch(()=>{});
  const osc=audioCtx.createOscillator(),gain=audioCtx.createGain(),now=audioCtx.currentTime;
  osc.type='sine';osc.frequency.setValueAtTime(id==='win'?740:id==='error'?190:id==='collect'?600:400,now);
  osc.frequency.exponentialRampToValueAtTime(id==='error'?115:270,now+.09);
  gain.gain.setValueAtTime(.075,now);
  gain.gain.exponentialRampToValueAtTime(.001,now+.12);
  osc.connect(gain).connect(audioCtx.destination);osc.start(now);osc.stop(now+.13);
 }catch{}
}
function toggleSound(){
 soundOn=!soundOn;
 try{localStorage.setItem('itamaros-games-sound',soundOn?'on':'off')}catch{}
 return soundOn;
}
window.ItamarGameUX={illustration,swipe,sound,toggleSound,get soundOn(){return soundOn}};
})();
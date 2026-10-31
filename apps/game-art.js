/* Original ItamarOS colorful SVG game illustrations; no external image requests. */
(()=>{
'use strict';
const palette={
 '2048':['#635bff','#43d9ff'],
 snake:['#13a78a','#89e86c'],
 memory:['#eb5baa','#ffb65d'],
 tictactoe:['#226edb','#62e6d8'],
 guess:['#814ef3','#ffa857'],
 reaction:['#f75582','#ffdb70'],
 rps:['#4f89ff','#ef80cf'],
 math:['#40a8ba','#baf47f'],
 word:['#9e57e7','#8ce4f9'],
 pattern:['#ea6498','#71d6fc'],
 connect:['#2859c1','#f9d150'],
 words:['#c86bfb','#ffdb86']
};
const g=(content,x=340,y=78)=>`<g transform="translate(${x} ${y})">${content}</g>`;
const eye=(x,y)=>`<circle cx="${x}" cy="${y}" r="7" fill="#fff"/><circle cx="${x+2}" cy="${y}" r="3.5" fill="#1d3654"/><circle cx="${x+3}" cy="${y-2}" r="1.5" fill="#fff"/>`;
const cherry=`<path d="M2-11 Q-3-39 16-50" stroke="#704031" stroke-width="6" fill="none" stroke-linecap="round"/><path d="M4-37Q12-63 32-51Q23-30 4-37" fill="#67ce75"/><circle cx="-12" cy="6" r="23" fill="#f43b60" stroke="#c31e4a" stroke-width="4"/><circle cx="12" cy="11" r="23" fill="#ec3455" stroke="#c31e4a" stroke-width="4"/><ellipse cx="-18" cy="-4" rx="7" ry="11" fill="#ffbdc9" opacity=".8"/>`;
const art={
snake:g(`<g transform="translate(-70 15) rotate(-12)"><path d="M-111 12Q-100-43-59-31T16 4Q46 18 69-9" stroke="#197e64" stroke-width="49" stroke-linecap="round" fill="none"/><path d="M-111 12Q-100-43-59-31T16 4Q46 18 69-9" stroke="#71de91" stroke-width="39" stroke-linecap="round" fill="none"/><ellipse cx="65" cy="-15" rx="53" ry="40" fill="#86f4a0" stroke="#19886f" stroke-width="5"/>${eye(79,-24)}${eye(104,-25)}<path d="M74-2Q92 14 104-2" stroke="#277d67" stroke-width="4" fill="none" stroke-linecap="round"/><path d="M115-1l22 1m-7-3l7 3-7 6" stroke="#fd727f" stroke-width="4" stroke-linecap="round"/></g>`)+g(cherry,523,82),
'2048':g(`<g transform="rotate(-10)"><rect x="-99" y="-61" width="82" height="82" rx="18" fill="#ffe88a" stroke="#fff5c9" stroke-width="6"/><rect x="-8" y="-44" width="82" height="82" rx="18" fill="#f68e92" stroke="#fff3ca" stroke-width="6"/><rect x="87" y="-62" width="70" height="70" rx="16" fill="#93f3e5" stroke="#fff9d2" stroke-width="6"/><text x="-58" y="-8" fill="#493a72" font-size="33" font-weight="900" text-anchor="middle">2</text><text x="33" y="11" fill="#56294b" font-size="33" font-weight="900" text-anchor="middle">4</text><text x="122" y="-16" fill="#26636c" font-size="31" font-weight="900" text-anchor="middle">8</text></g>`),
memory:g(`<g transform="rotate(-12)"><rect x="-96" y="-56" rx="15" width="100" height="120" fill="#fff0b1" stroke="#fff" stroke-width="6"/><path d="M-44-13L-30 8-46 37-74 7Z" fill="#f86c95"/><rect x="-15" y="-64" rx="15" width="100" height="120" fill="#91dce8" stroke="#fff" stroke-width="6"/><path d="M35-20l9 18 21 3-15 15 4 22-19-10-19 10 4-22-16-15 22-3Z" fill="#ffec76"/></g>`),
tictactoe:g(`<rect x="-104" y="-65" rx="18" width="212" height="130" fill="#effcff" opacity=".95"/><path d="M-35-60V60M36-60V60M-101-23H104M-101 24H104" stroke="#9dbbce" stroke-width="6"/><path d="M-85-48l32 31m0-31-32 31" stroke="#ef6387" stroke-width="9" stroke-linecap="round"/><circle cx="2" cy="-34" r="18" stroke="#31c4a3" stroke-width="9" fill="none"/><path d="M50 31l38 26m0-26-38 26" stroke="#ef6387" stroke-width="9" stroke-linecap="round"/></g>`),
guess:g(`<circle cx="0" cy="-7" r="65" fill="#fff4c6" stroke="#fff" stroke-width="7"/><path d="M-18-23Q-16-52 8-45Q40-38 18-9Q1 3 0 17" stroke="#6248a6" stroke-width="13" fill="none" stroke-linecap="round"/><circle cy="41" r="8" fill="#6248a6"/>`),
reaction:g(`<path d="M14-71l-72 90h50l-14 69L71-20H18Z" fill="#ffeb75" stroke="#fff" stroke-width="7" stroke-linejoin="round"/><path d="M-100-51l-25-15m10 63-24 0M109 12l28 0M92-49l20-15" stroke="#fff" stroke-width="9" stroke-linecap="round"/>`),
rps:g(`<g transform="rotate(-8)"><path d="M-100 44Q-125-6-93-33Q-70-57-52-26L-33-49Q-16-66-1-48L16-25Q43-25 53 12Q70 65 31 69H-71Z" fill="#ffcfab" stroke="#fff" stroke-width="7"/><path d="M-4-12l25-50q8-16 21-4 8 6 3 20L31-5 53-47q7-17 22-9 12 7 6 23L52 36" fill="#ffdcb6" stroke="#fff" stroke-width="7" stroke-linecap="round"/></g>`),
math:g(`<rect x="-115" y="-62" width="230" height="124" rx="19" fill="#f5ffdf" stroke="#fff" stroke-width="7"/><path d="M-80-12H-21M-50-42V18M17-12h64M17 14h64" stroke="#5b9f88" stroke-width="10" stroke-linecap="round"/><circle cx="49" cy="-40" r="5" fill="#5b9f88"/>`),
word:g(`<g transform="rotate(-9)"><rect x="-108" y="-52" width="75" height="88" rx="13" fill="#fff4ae" stroke="#fff" stroke-width="5"/><rect x="-20" y="-45" width="75" height="88" rx="13" fill="#abf1de" stroke="#fff" stroke-width="5"/><rect x="67" y="-64" width="75" height="88" rx="13" fill="#ffd1d3" stroke="#fff" stroke-width="5"/><text x="-70" y="6" font-size="48" fill="#795084" font-weight="800" text-anchor="middle">A</text><text x="17" y="16" font-size="48" fill="#367b86" font-weight="800" text-anchor="middle">B</text><text x="104" y="-4" font-size="48" fill="#a25677" font-weight="800" text-anchor="middle">C</text></g>`),
words:g(`<rect x="-96" y="-54" width="80" height="80" rx="12" fill="#9be6f1"/><rect x="-7" y="-31" width="80" height="80" rx="12" fill="#ffdf8c"/><text x="-56" y="6" font-size="43" fill="#26647b" font-weight="900" text-anchor="middle">W</text><text x="33" y="26" font-size="43" fill="#965c2f" font-weight="900" text-anchor="middle">O</text></g>`),
pattern:g(`<circle cx="-70" cy="-26" r="37" fill="#ff738c" stroke="#fff" stroke-width="6"/><rect x="-25" y="-61" width="68" height="68" rx="17" fill="#ffe679" stroke="#fff" stroke-width="6"/><path d="M63-49l53 44-53 44-53-44Z" fill="#82deff" stroke="#fff" stroke-width="6"/><circle cx="-49" cy="54" r="20" fill="#9b8bfa" stroke="#fff" stroke-width="5"/>`),
connect:g(`<rect x="-127" y="-72" rx="22" width="254" height="144" fill="#2785da" stroke="#fff" stroke-width="7"/>${Array.from({length:5},(_,r)=>Array.from({length:8},(_,c)=>`<circle cx="${-105+c*30}" cy="${-52+r*26}" r="10" fill="${(c+r)%4===0?'#ff6578':(c+r)%3===0?'#ffdc5b':'#e1f5ff'}"/>`).join('')).join('')}`),
'Number Guess':g(`<circle cx="0" cy="-7" r="65" fill="#fff4c6" stroke="#fff" stroke-width="7"/><path d="M-18-23Q-16-52 8-45Q40-38 18-9Q1 3 0 17" stroke="#6248a6" stroke-width="13" fill="none" stroke-linecap="round"/><circle cy="41" r="8" fill="#6248a6"/>`),
'Rock Paper Scissors':g(`<path d="M-90 43Q-106-21-68-31L-40-47Q-12-40-18-10L-7-47Q11-67 26-44L41-10Q83-5 71 43L52 61H-64Z" fill="#ffd8ae" stroke="#fff" stroke-width="7"/>`),
'Connect Four':g(`<rect x="-90" y="-65" rx="18" width="180" height="130" fill="#287cce" stroke="#fff" stroke-width="7"/><circle cx="-50" cy="-30" r="21" fill="#ff5d7b"/><circle cx="8" cy="-30" r="21" fill="#ffdf62"/><circle cx="-50" cy="29" r="21" fill="#ffdf62"/><circle cx="8" cy="29" r="21" fill="#ff5d7b"/></g>`)
};
function svgFor(key){
 const [start,end]=palette[key]||['#377fe5','#a774ec'];
 const body=art[key]||art[key.toLowerCase()]||art.pattern;
 return `<svg xmlns="http://www.w3.org/2000/svg" width="640" height="160" viewBox="0 0 640 160"><defs><linearGradient id="bg" x2="1" y2="1"><stop stop-color="${start}"/><stop offset="1" stop-color="${end}"/></linearGradient></defs><rect x="2" y="2" width="636" height="156" rx="27" fill="url(#bg)"/><circle cx="120" cy="-20" r="92" fill="#fff" opacity=".14"/><circle cx="570" cy="172" r="116" fill="#fff" opacity=".13"/><path d="M14 110Q142 20 256 112T638 68" stroke="#fff" stroke-width="8" stroke-opacity=".16" fill="none"/>${body}</svg>`;
}
function decorate(area,key){
 if(!area || !area.append || !art[key])return;
 const img=document.createElement('img');
 img.className='ios-game-illustration';
 img.src='data:image/svg+xml;charset=UTF-8,'+encodeURIComponent(svgFor(key));
 img.alt='Colorful original cartoon illustration for '+key;
 img.decoding='async';
 area.append(img);
 area.dataset.illustrated=key;
}
window.ItamarGameArt={decorate,svgFor};
})();

/* ItamarOS More Games: six extra offline mini-games with browser-local progress. */
(()=>{
'use strict';
const KEY='itamaros-mini-games-v1';
const dictionary=['planet','rocket','galaxy','puzzle','winter','island','orange','violin','camera','jungle','purple','friend','dragon','stream','ocean'];
const $=id=>document.getElementById(id);
const el=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n};
const button=(text,fn)=>{const b=el('button',text);b.type='button';b.onclick=()=>{window.ItamarGameAudio?.play('tap');fn()};return b};
const art=(area,key)=>window.ItamarGameArt?.decorate(area,key);
const effect=kind=>window.ItamarGameAudio?.play(kind);
function load(){try{return JSON.parse(localStorage.getItem(KEY))||{}}catch{return {}}}
let data=load(),active='guess',mountRoot=null,timer=null;
function save(){try{localStorage.setItem(KEY,JSON.stringify(data))}catch{}}
function section(text){const n=el('p',text);n.className='ios-caption';return n}
function resetTimer(){if(timer)clearTimeout(timer);timer=null}
function clear(){resetTimer();const box=$('ios-mini-area');if(box)box.replaceChildren();return box}
function pick(n){return Math.floor(Math.random()*n)}
function record(key,value){data.stats??={};data.stats[key]=value;save()}

// Two-person games use local pass-and-play or an offline bot.
function matchSettings(box,id,onChange){
 data.matchSettings??={};
 const state=data.matchSettings[id]??={mode:'friend',difficulty:'medium'};
 const label=section('Who do you want to play against?');box.append(label);
 const mode=el('select');
 for(const [value,name] of [['friend','With a friend'],['bot','Against a bot']]){
  const o=el('option',name);o.value=value;mode.append(o)
 }
 mode.value=state.mode;mode.setAttribute('aria-label','Choose opponent');box.append(mode);
 const difficulty=el('select');
 for(const [value,name] of [['easy','Easy'],['medium','Medium'],['hard','Hard']]){
  const o=el('option',name);o.value=value;difficulty.append(o)
 }
 difficulty.value=state.difficulty;difficulty.setAttribute('aria-label','Bot difficulty');
 difficulty.hidden=state.mode!=='bot';box.append(difficulty);
 mode.onchange=()=>{state.mode=mode.value;save();onChange()};
 difficulty.onchange=()=>{state.difficulty=difficulty.value;save();onChange()};
 if(state.mode==='friend')box.append(section('Two friends play in turns on this device.'));
 return state;
}

function mount(parent){
 if(!parent)return;mountRoot=el('section');mountRoot.className='ios-pane';
 mountRoot.append(el('h3','More ItamarOS Games · Instant play'));
 const nav=el('div');nav.className='ios-row';
 for(const [id,name] of [['guess','🔢 Number Guess'],['math','➕ Math Sprint'],['rps','✊ Rock Paper Scissors'],['reaction','⚡ Reaction Test'],['words','🔤 Word Scramble'],['connect','🔴 Connect Four']]){
  const b=button(name,()=>show(id));b.dataset.mini=id;nav.append(b)
 }
 mountRoot.append(nav);const area=el('div');area.id='ios-mini-area';mountRoot.append(area);
 mountRoot.append(section('Your scores and unfinished games are saved in this browser.'));parent.append(mountRoot);
 show(active);
}
function show(name){active=name;const area=clear();if(!area)return;
 for(const b of mountRoot.querySelectorAll('[data-mini]'))b.classList.toggle('ios-active',b.dataset.mini===name);
 if(name==='guess')guess(area);else if(name==='math')math(area);else if(name==='rps')rps(area);else if(name==='reaction')reaction(area);else if(name==='words')words(area);else connect(area)
}
function guess(box){
 let g=data.guess;if(!g||typeof g.target!=='number')g=data.guess={target:1+pick(100),tries:0,won:false};
 box.append(el('h4','Guess the secret number (1–100)'),section('Use the clues to find the number.'));art(box,'guess');
 const label=el('label','Your guess');const input=el('input');input.type='number';input.min=1;input.max=100;input.placeholder='1–100';label.append(input);box.append(label);
 const msg=section(g.won?'Solved in '+g.tries+' guesses!':'Make a guess.');box.append(msg);
 const submit=()=>{const n=Number(input.value);if(!Number.isInteger(n)||n<1||n>100){msg.textContent='Choose a whole number 1–100.';return}if(g.won)return;g.tries++;if(n===g.target){g.won=true;effect('win');msg.textContent='Correct in '+g.tries+' guesses!';data.stats??={};data.stats.guessWins=(data.stats.guessWins||0)+1}else msg.textContent=n<g.target?'Higher!':'Lower!';save()};
 box.append(button('Guess',submit),button('New number',()=>{data.guess={target:1+pick(100),tries:0,won:false};save();show('guess')}));
 input.addEventListener('keydown',e=>{if(e.key==='Enter')submit()});box.append(section('Total wins: '+(data.stats?.guessWins||0)))
}
function makeQuestion(){const a=1+pick(20),b=1+pick(20),op=pick(3);return {a,b,op,answer:op===0?a+b:op===1?a*b:a-b}}
function math(box){let g=data.math;if(!g||!g.question)g=data.math={score:0,streak:0,question:makeQuestion()};
 box.append(el('h4','Math Sprint'));art(box,'math');const score=section('Correct: '+g.score+' · Streak: '+g.streak+' · Best: '+(data.stats?.mathBest||0));box.append(score);
 const p=el('h3');box.append(p);const input=el('input');input.type='number';input.placeholder='Your answer';input.setAttribute('aria-label','Math answer');box.append(input);
 const msg=section('Solve as many as you can.');box.append(msg);
 const refresh=()=>{p.textContent=g.question.a+' '+['+','×','−'][g.question.op]+' '+g.question.b+' = ?';score.textContent='Correct: '+g.score+' · Streak: '+g.streak+' · Best: '+(data.stats?.mathBest||0)};
 const answer=()=>{if(input.value==='')return;const n=Number(input.value);if(n===g.question.answer){effect('collect');g.score++;g.streak++;data.stats??={};data.stats.mathBest=Math.max(data.stats.mathBest||0,g.streak);msg.textContent='Correct!'}else{g.streak=0;msg.textContent='Not quite. Answer: '+g.question.answer}g.question=makeQuestion();input.value='';save();refresh()};
 box.append(button('Answer',answer),button('Reset score',()=>{data.math={score:0,streak:0,question:makeQuestion()};save();show('math')}));
 input.addEventListener('keydown',e=>{if(e.key==='Enter')answer()});refresh()
}
function rps(box){
 const names=['Rock','Paper','Scissors'];
 box.append(el('h4','Rock Paper Scissors'));art(box,'rps');
 const g=data.rpsMatch??={pending:null,history:[]};
 const config=matchSettings(box,'rps',()=>{g.pending=null;g.history=[];save();show('rps')});
 const score=section('Wins: '+(data.stats?.rpsWin||0)+' · Losses: '+(data.stats?.rpsLoss||0)+' · Draws: '+(data.stats?.rpsTie||0));box.append(score);
 const msg=el('h3',g.pending===null?(config.mode==='bot'?'Choose your move':'Player 1: choose secretly'):'Player 2: choose without seeing Player 1’s move');
 box.append(msg);
 for(const [i,emoji] of ['✊','✋','✌️'].entries())box.append(button(emoji+' '+names[i],()=>{
  if(config.mode==='friend'&&g.pending===null){g.pending=i;save();msg.textContent='Player 1 choice saved. Pass the device to Player 2.';return}
  const mine=g.pending===null?i:g.pending;
  let other=i;
  if(config.mode==='bot'){
   const history=g.history||[];
   other=pick(3);
   if(config.difficulty!=='easy'&&history.length){
    const counts=[0,1,2].map(n=>history.filter(x=>x===n).length);
    const predict=counts.indexOf(Math.max(...counts));
    if(Math.random()<(config.difficulty==='hard'?.85:.45))other=(predict+1)%3;
   }
  }
  const outcome=(mine-other+3)%3;
  data.stats??={};
  const key=outcome===0?'rpsTie':outcome===1?'rpsWin':'rpsLoss';
  data.stats[key]=(data.stats[key]||0)+1;
  effect(outcome===1?'win':outcome===2?'error':'move');
  g.history??=[];g.history.push(mine);g.pending=null;save();
  msg.textContent='Player 1: '+names[mine]+' · '+(config.mode==='bot'?'Bot':'Player 2')+': '+names[other]+' — '+(outcome===0?'Draw':outcome===1?'Player 1 wins!':(config.mode==='bot'?'Bot':'Player 2')+' wins!');
  score.textContent='Wins: '+(data.stats.rpsWin||0)+' · Losses: '+(data.stats.rpsLoss||0)+' · Draws: '+(data.stats.rpsTie||0);
 }));
 box.append(button('New match',()=>{g.pending=null;g.history=[];save();show('rps')}));
}
function reaction(box){box.append(el('h4','Reaction Test'));art(box,'reaction');
 const best=section('Best: '+(data.stats?.reactionBest?data.stats.reactionBest+' ms':'—'));box.append(best);
 const display=el('h3','Press Start and wait until GO!');box.append(display);
 let stage='ready',started=0;
 const action=button('Start',()=>{if(stage==='waiting'){resetTimer();stage='ready';display.textContent='Too early! Press Start again.';action.textContent='Start';return}
 if(stage==='go'){const ms=Math.round(performance.now()-started);stage='ready';data.stats??={};data.stats.reactionBest=Math.min(data.stats.reactionBest||Infinity,ms);save();display.textContent='Reaction: '+ms+' ms';best.textContent='Best: '+data.stats.reactionBest+' ms';action.textContent='Start again';return}
 stage='waiting';display.textContent='Wait for GO!';action.textContent='Wait…';timer=setTimeout(()=>{stage='go';started=performance.now();effect('collect');display.textContent='GO!';action.textContent='Tap NOW!'},1200+pick(2400))});
 box.append(action);
}
function shuffled(word){let chars=word.split('');for(let i=chars.length-1;i>0;i--){const j=pick(i+1);[chars[i],chars[j]]=[chars[j],chars[i]]}return chars.join('')}
function words(box){let g=data.words;if(!g||!g.word)g=data.words={word:dictionary[pick(dictionary.length)],score:0};box.append(el('h4','Word Scramble'));art(box,'words');
 const word=el('h3');let mixed=shuffled(g.word);if(mixed===g.word)mixed=g.word.slice(1)+g.word[0];word.textContent=mixed.toUpperCase();box.append(word);
 const input=el('input');input.placeholder='Unscramble the word';input.setAttribute('aria-label','Unscrambled word');box.append(input);
 const msg=section('Score: '+g.score+' · Best: '+(data.stats?.wordBest||0));box.append(msg);
 const submit=()=>{if(input.value.trim().toLowerCase()!==g.word){msg.textContent='Try another spelling!';return}effect('win');g.score++;data.stats??={};data.stats.wordBest=Math.max(data.stats.wordBest||0,g.score);g.word=dictionary[pick(dictionary.length)];save();show('words')};
 box.append(button('Check',submit),button('Skip word',()=>{g.word=dictionary[pick(dictionary.length)];g.score=0;save();show('words')}));
 input.addEventListener('keydown',e=>{if(e.key==='Enter')submit()})
}
function connect(box){
 let g=data.connect;
 if(!g||!Array.isArray(g.board)||g.board.length!==42)g=data.connect={board:Array(42).fill(0),turn:1,winner:0};
 box.append(el('h4','Connect Four'));art(box,'connect');
 const config=matchSettings(box,'connect',()=>{data.connect={board:Array(42).fill(0),turn:1,winner:0};save();show('connect')});
 const status=section('');box.append(status);
 const tray=el('div','🔴 Drag a disc to the board or tap a column');tray.className='ios-disc-tray';tray.setAttribute('role','note');box.append(tray);
 const grid=el('div');grid.className='ios-connect-grid';grid.style.cssText='display:grid;grid-template-columns:repeat(7,minmax(30px,1fr));gap:4px;max-width:440px;margin:12px auto;background:#2861aa;padding:6px;border-radius:10px';box.append(grid);
 let dragging=false;
 tray.addEventListener('pointerdown',e=>{if(e.button!==undefined&&e.button!==0)return;dragging=true;tray.classList.add('dragging')});
 document.addEventListener('pointerup',e=>{if(!dragging)return;dragging=false;tray.classList.remove('dragging');const bounds=grid.getBoundingClientRect?.();if(!bounds||e.clientX<bounds.left||e.clientX>bounds.right||e.clientY<bounds.top||e.clientY>bounds.bottom)return;const column=Math.min(6,Math.max(0,Math.floor((e.clientX-bounds.left)/bounds.width*7)));drop(column)});
 tray.style.touchAction='none';grid.style.touchAction='none';
 const won=(board,color)=>{for(let y=0;y<6;y++)for(let x=0;x<7;x++)if(board[y*7+x]===color)for(const [dx,dy] of [[1,0],[0,1],[1,1],[-1,1]])if([0,1,2,3].every(t=>{const cx=x+dx*t,cy=y+dy*t;return cx>=0&&cx<7&&cy>=0&&cy<6&&board[cy*7+cx]===color}))return true;return false};
 const legal=b=>[0,1,2,3,4,5,6].filter(c=>!b[c]);
 const place=(b,c,color)=>{const next=b.slice();for(let row=5;row>=0;row--)if(!next[row*7+c]){next[row*7+c]=color;return next}return null};
 const evaluate=b=>{let score=0;for(let row=0;row<6;row++){if(b[row*7+3]===2)score+=6;if(b[row*7+3]===1)score-=6;
   for(let col=0;col<7;col++)for(const [dx,dy] of [[1,0],[0,1],[1,1],[-1,1]]){
    if(col+dx*3<0||col+dx*3>=7||row+dy*3>=6)continue;
    const cells=[0,1,2,3].map(t=>b[(row+dy*t)*7+col+dx*t]);
    const mine=cells.filter(n=>n===2).length,other=cells.filter(n=>n===1).length;
    if(!other)score+=[0,1,9,75,500][mine];if(!mine)score-=[0,1,9,75,500][other];
   }
  }return score};
 const minimax=(b,depth,player)=>{if(won(b,2))return 10000+depth;if(won(b,1))return -10000-depth;
  const available=legal(b);if(!available.length)return 0;if(depth===0)return evaluate(b);
  return player===2?Math.max(...available.map(c=>minimax(place(b,c,2),depth-1,1))):Math.min(...available.map(c=>minimax(place(b,c,1),depth-1,2)))};
 const botCol=()=>{
  const cols=legal(g.board);if(!cols.length)return null;
  if(config.difficulty==='easy')return cols[pick(cols.length)];
  for(const color of [2,1])for(const c of cols)if(won(place(g.board,c,color),color))return c;
  if(config.difficulty==='medium')return cols[pick(cols.length)];
  const ranked=cols.map(c=>({c,score:minimax(place(g.board,c,2),3,1)+(3-Math.abs(c-3))*2}));
  const best=Math.max(...ranked.map(x=>x.score));
  const tied=ranked.filter(x=>x.score===best);
  return tied[pick(tied.length)].c;
 };
 const draw=()=>{grid.replaceChildren();for(let row=0;row<6;row++)for(let col=0;col<7;col++){
  const token=g.board[row*7+col],b=button(token===1?'🔴':token===2?'🟡':'⚪',()=>drop(col));
  b.style.cssText='padding:4px;min-width:0;font-size:clamp(18px,4vw,31px);background:#4479c3;color:#fff';
  b.setAttribute('aria-label','Column '+(col+1)+' row '+(row+1));
  b.disabled=!!g.winner||(config.mode==='bot'&&g.turn===2);grid.append(b)
 }
 status.textContent=g.winner===3?'Draw!':g.winner?'Winner: '+(g.winner===1?'Player 1':(config.mode==='bot'?'Bot':'Player 2')):'Turn: '+(g.turn===1?'Player 1':(config.mode==='bot'?'Bot':'Player 2'));
 };
 function apply(column){
  if(g.winner)return;const next=place(g.board,column,g.turn);if(!next)return;
  g.board=next;if(won(next,g.turn)){g.winner=g.turn;data.stats??={};const key=g.turn===1?'connectRed':'connectYellow';data.stats[key]=(data.stats[key]||0)+1}
  else if(g.board.every(Boolean))g.winner=3;else g.turn=3-g.turn;
  effect(g.winner?'win':'move');save();draw();
  if(config.mode==='bot'&&g.turn===2&&!g.winner)timer=setTimeout(()=>{if(active!=='connect'||data.connect!==g)return;const c=botCol();if(c!==null)apply(c)},450);
 }
 function drop(column){if(config.mode==='bot'&&g.turn===2)return;apply(column)}
 draw();if(config.mode==='bot'&&g.turn===2&&!g.winner)timer=setTimeout(()=>{if(active==='connect'&&data.connect===g){const c=botCol();if(c!==null)apply(c)}},450);
 box.append(button('New round',()=>{data.connect={board:Array(42).fill(0),turn:1,winner:0};save();show('connect')}));
 box.append(section('Player 1 wins: '+(data.stats?.connectRed||0)+' · Opponent wins: '+(data.stats?.connectYellow||0)));
}
window.ItamarMoreGames={mount,cleanup:resetTimer};
})();

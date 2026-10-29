/* ItamarOS More Games: six extra offline mini-games with browser-local progress. */
(()=>{
'use strict';
const KEY='itamaros-mini-games-v1';
const dictionary=['planet','rocket','galaxy','puzzle','winter','island','orange','violin','camera','jungle','purple','friend','dragon','stream','ocean'];
const $=id=>document.getElementById(id);
const el=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n};
const button=(text,fn)=>{const b=el('button',text);b.type='button';b.onclick=fn;return b};
function load(){try{return JSON.parse(localStorage.getItem(KEY))||{}}catch{return {}}}
let data=load(),active='guess',mountRoot=null,timer=null;
function save(){try{localStorage.setItem(KEY,JSON.stringify(data))}catch{}}
function section(text){const n=el('p',text);n.className='ios-caption';return n}
function resetTimer(){if(timer)clearTimeout(timer);timer=null}
function clear(){resetTimer();const box=$('ios-mini-area');if(box)box.replaceChildren();return box}
function pick(n){return Math.floor(Math.random()*n)}
function record(key,value){data.stats??={};data.stats[key]=value;save()}
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
 box.append(el('h4','Guess the secret number (1–100)'),section('Use the clues to find the number.'));
 const label=el('label','Your guess');const input=el('input');input.type='number';input.min=1;input.max=100;input.placeholder='1–100';label.append(input);box.append(label);
 const msg=section(g.won?'Solved in '+g.tries+' guesses!':'Make a guess.');box.append(msg);
 const submit=()=>{const n=Number(input.value);if(!Number.isInteger(n)||n<1||n>100){msg.textContent='Choose a whole number 1–100.';return}if(g.won)return;g.tries++;if(n===g.target){g.won=true;msg.textContent='Correct in '+g.tries+' guesses!';data.stats??={};data.stats.guessWins=(data.stats.guessWins||0)+1}else msg.textContent=n<g.target?'Higher!':'Lower!';save()};
 box.append(button('Guess',submit),button('New number',()=>{data.guess={target:1+pick(100),tries:0,won:false};save();show('guess')}));
 input.addEventListener('keydown',e=>{if(e.key==='Enter')submit()});box.append(section('Total wins: '+(data.stats?.guessWins||0)))
}
function makeQuestion(){const a=1+pick(20),b=1+pick(20),op=pick(3);return {a,b,op,answer:op===0?a+b:op===1?a*b:a-b}}
function math(box){let g=data.math;if(!g||!g.question)g=data.math={score:0,streak:0,question:makeQuestion()};
 box.append(el('h4','Math Sprint'));const score=section('Correct: '+g.score+' · Streak: '+g.streak+' · Best: '+(data.stats?.mathBest||0));box.append(score);
 const p=el('h3');box.append(p);const input=el('input');input.type='number';input.placeholder='Your answer';input.setAttribute('aria-label','Math answer');box.append(input);
 const msg=section('Solve as many as you can.');box.append(msg);
 const refresh=()=>{p.textContent=g.question.a+' '+['+','×','−'][g.question.op]+' '+g.question.b+' = ?';score.textContent='Correct: '+g.score+' · Streak: '+g.streak+' · Best: '+(data.stats?.mathBest||0)};
 const answer=()=>{if(input.value==='')return;const n=Number(input.value);if(n===g.question.answer){g.score++;g.streak++;data.stats??={};data.stats.mathBest=Math.max(data.stats.mathBest||0,g.streak);msg.textContent='Correct!'}else{g.streak=0;msg.textContent='Not quite. Answer: '+g.question.answer}g.question=makeQuestion();input.value='';save();refresh()};
 box.append(button('Answer',answer),button('Reset score',()=>{data.math={score:0,streak:0,question:makeQuestion()};save();show('math')}));
 input.addEventListener('keydown',e=>{if(e.key==='Enter')answer()});refresh()
}
function rps(box){const names=['Rock','Paper','Scissors'];box.append(el('h4','Rock Paper Scissors'));
 const score=section('Wins: '+(data.stats?.rpsWin||0)+' · Losses: '+(data.stats?.rpsLoss||0)+' · Draws: '+(data.stats?.rpsTie||0));box.append(score);
 const msg=el('h3','Choose your move');box.append(msg);
 for(const [i,emoji] of ['✊','✋','✌️'].entries())box.append(button(emoji+' '+names[i],()=>{const c=pick(3);const result=(i-c+3)%3;data.stats??={};const key=result===0?'rpsTie':result===1?'rpsWin':'rpsLoss';data.stats[key]=(data.stats[key]||0)+1;save();msg.textContent='You: '+names[i]+' · Computer: '+names[c]+' — '+(result===0?'Draw':result===1?'You win!':'Computer wins');score.textContent='Wins: '+(data.stats.rpsWin||0)+' · Losses: '+(data.stats.rpsLoss||0)+' · Draws: '+(data.stats.rpsTie||0)}))
}
function reaction(box){box.append(el('h4','Reaction Test'));
 const best=section('Best: '+(data.stats?.reactionBest?data.stats.reactionBest+' ms':'—'));box.append(best);
 const display=el('h3','Press Start and wait until GO!');box.append(display);
 let stage='ready',started=0;
 const action=button('Start',()=>{if(stage==='waiting'){resetTimer();stage='ready';display.textContent='Too early! Press Start again.';action.textContent='Start';return}
 if(stage==='go'){const ms=Math.round(performance.now()-started);stage='ready';data.stats??={};data.stats.reactionBest=Math.min(data.stats.reactionBest||Infinity,ms);save();display.textContent='Reaction: '+ms+' ms';best.textContent='Best: '+data.stats.reactionBest+' ms';action.textContent='Start again';return}
 stage='waiting';display.textContent='Wait for GO!';action.textContent='Wait…';timer=setTimeout(()=>{stage='go';started=performance.now();display.textContent='GO!';action.textContent='Tap NOW!'},1200+pick(2400))});
 box.append(action);
}
function shuffled(word){let chars=word.split('');for(let i=chars.length-1;i>0;i--){const j=pick(i+1);[chars[i],chars[j]]=[chars[j],chars[i]]}return chars.join('')}
function words(box){let g=data.words;if(!g||!g.word)g=data.words={word:dictionary[pick(dictionary.length)],score:0};box.append(el('h4','Word Scramble'));
 const word=el('h3');let mixed=shuffled(g.word);if(mixed===g.word)mixed=g.word.slice(1)+g.word[0];word.textContent=mixed.toUpperCase();box.append(word);
 const input=el('input');input.placeholder='Unscramble the word';input.setAttribute('aria-label','Unscrambled word');box.append(input);
 const msg=section('Score: '+g.score+' · Best: '+(data.stats?.wordBest||0));box.append(msg);
 const submit=()=>{if(input.value.trim().toLowerCase()!==g.word){msg.textContent='Try another spelling!';return}g.score++;data.stats??={};data.stats.wordBest=Math.max(data.stats.wordBest||0,g.score);g.word=dictionary[pick(dictionary.length)];save();show('words')};
 box.append(button('Check',submit),button('Skip word',()=>{g.word=dictionary[pick(dictionary.length)];g.score=0;save();show('words')}));
 input.addEventListener('keydown',e=>{if(e.key==='Enter')submit()})
}
function connect(box){
 let g=data.connect;if(!g||!Array.isArray(g.board)||g.board.length!==42)g=data.connect={board:Array(42).fill(0),turn:1,winner:0};
 box.append(el('h4','Connect Four · Local 2-player'));
 const status=section(g.winner===3?'Draw!':g.winner?'Winner: '+(g.winner===1?'Red':'Yellow'):'Turn: '+(g.turn===1?'Red':'Yellow'));box.append(status);
 const grid=el('div');grid.style.cssText='display:grid;grid-template-columns:repeat(7,minmax(30px,1fr));gap:4px;max-width:440px;margin:12px auto;background:#2861aa;padding:6px;border-radius:10px';box.append(grid);
 const won=(board,color,x,y)=>[[1,0],[0,1],[1,1],[1,-1]].some(([dx,dy])=>{let n=1;for(const sign of [-1,1]){let px=x+dx*sign,py=y+dy*sign;while(px>=0&&px<7&&py>=0&&py<6&&board[py*7+px]===color){n++;px+=dx*sign;py+=dy*sign}}return n>=4});
 const draw=()=>{grid.replaceChildren();for(let row=0;row<6;row++)for(let column=0;column<7;column++){const token=g.board[row*7+column];const b=button(token===1?'🔴':token===2?'🟡':'⚪',()=>drop(column));b.style.cssText='padding:4px;min-width:0;font-size:clamp(18px,4vw,31px);background:#4479c3;color:#fff';b.setAttribute('aria-label','Column '+(column+1)+' row '+(row+1));grid.append(b)}status.textContent=g.winner===3?'Draw!':g.winner?'Winner: '+(g.winner===1?'Red':'Yellow'):'Turn: '+(g.turn===1?'Red':'Yellow')};
 function drop(column){if(g.winner)return;let row=-1;for(let y=5;y>=0;y--)if(!g.board[y*7+column]){row=y;break}if(row<0)return;g.board[row*7+column]=g.turn;if(won(g.board,g.turn,column,row)){g.winner=g.turn;data.stats??={};const key=g.turn===1?'connectRed':'connectYellow';data.stats[key]=(data.stats[key]||0)+1}else if(g.board.every(Boolean))g.winner=3;else g.turn=g.turn===1?2:1;save();draw()}
 draw();box.append(button('New round',()=>{data.connect={board:Array(42).fill(0),turn:1,winner:0};save();show('connect')}));
 box.append(section('Red wins: '+(data.stats?.connectRed||0)+' · Yellow wins: '+(data.stats?.connectYellow||0)))
}
window.ItamarMoreGames={mount,cleanup:resetTimer};
})();

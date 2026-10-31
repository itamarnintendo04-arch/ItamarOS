/* ItamarOS Games – standalone browser games, persistent local saves, offline play after load. */
(()=>{
'use strict';
const KEY='itamaros-games-v1';
let current='2048',root=null,timer=null,flipTimeout=null;
const icons=['🍀','🌈','⭐','🎯','🎵','🚀','🐱','🌟'];
const $=id=>document.getElementById(id);
const make=(tag,txt,cls)=>{const node=document.createElement(tag);if(txt!==undefined)node.textContent=txt;if(cls)node.className=cls;return node};
const button=(txt,fn)=>{const b=make('button',txt);b.type='button';b.addEventListener('click',()=>{window.ItamarGameAudio?.play('tap');fn()});return b};
const effect=kind=>window.ItamarGameAudio?.play(kind);
const artwork=(area,game)=>window.ItamarGameArt?.decorate(area,game);
// Pointer gestures work with touch, pen and mouse. Keyboard remains accessible.
function swipe(element,onDirection,continuous=false){
 let start=null,last=null;
 const direction=(dx,dy)=>{
  if(Math.max(Math.abs(dx),Math.abs(dy))<17)return false;
  onDirection(Math.abs(dx)>Math.abs(dy)?(dx>0?'right':'left'):(dy>0?'down':'up'));
  return true;
 };
 element.style.touchAction='none';
 element.addEventListener('pointerdown',e=>{if(e.button!==undefined&&e.button!==0)return;start={x:e.clientX,y:e.clientY,id:e.pointerId};last={x:e.clientX,y:e.clientY};element.setPointerCapture?.(e.pointerId)});
 element.addEventListener('pointermove',e=>{if(!start||start.id!==e.pointerId||!continuous)return;if(direction(e.clientX-last.x,e.clientY-last.y))last={x:e.clientX,y:e.clientY}});
 element.addEventListener('pointerup',e=>{if(start&&start.id===e.pointerId){if(!continuous)direction(e.clientX-start.x,e.clientY-start.y);else direction(e.clientX-last.x,e.clientY-last.y)}start=null;last=null});
 element.addEventListener('pointercancel',()=>{start=null;last=null});
}
const empty2048=()=>Array(16).fill(0);
function defaults(){return {scores:{'2048':0,snake:0,memory:0,tictactoe:0,reaction:0,guess:0,rps:0,math:0,word:0,pattern:0},extras:{guess:{target:0,tries:0,last:''},rps:{wins:0,losses:0,ties:0},math:{correct:0,total:0,question:null},word:{completed:0,current:0},pattern:{wins:0,level:0,sequence:[]}},game2048:{board:empty2048(),score:0,over:false},snake:{body:[{x:5,y:7},{x:4,y:7},{x:3,y:7}],food:{x:10,y:7},dir:{x:1,y:0},next:{x:1,y:0},score:0,over:false,running:false},memory:{cards:[],matched:[],moves:0,finished:false},tictactoe:{board:Array(9).fill(''),turn:'X',winner:'',wins:{X:0,O:0,tie:0}}}}
function load(){try{const s=JSON.parse(localStorage.getItem(KEY));if(!s||typeof s!=='object')return defaults();const d=defaults();for(const k of Object.keys(d))if(k in s&&s[k]&&typeof s[k]==='object')d[k]={...d[k],...s[k]};if(!Array.isArray(d.game2048.board)||d.game2048.board.length!==16)d.game2048=defaults().game2048;if(!Array.isArray(d.tictactoe.board)||d.tictactoe.board.length!==9)d.tictactoe=defaults().tictactoe;if(!Array.isArray(d.snake.body)||!d.snake.body.length)d.snake=defaults().snake;return d}catch{return defaults()}}
let saveData=load();
const save=()=>{try{localStorage.setItem(KEY,JSON.stringify(saveData))}catch{}};
function stopTimers(){clearInterval(timer);timer=null;clearTimeout(flipTimeout);flipTimeout=null}
function cleanup(){stopTimers()}
function mount(){
 stopTimers();root=$('content');if(!root)return;root.replaceChildren();
 const wrapper=make('section',undefined,'ios-feature');wrapper.id='itamar-games';root.append(wrapper);
 wrapper.append(make('h2','🎮 ItamarOS Games'));
 wrapper.append(make('p','Play instantly with colorful artwork, swipe controls and optional CC0 sound effects. Local scores stay saved on this device.','ios-caption'));
 const sound=button('🔊 Sound: '+(window.ItamarGameAudio?.isEnabled()===false?'Off':'On'),()=>{
  const on=window.ItamarGameAudio?.toggle();
  sound.textContent='🔊 Sound: '+(on?'On':'Off');
 });sound.setAttribute('aria-label','Toggle game sound effects');wrapper.append(sound);
 const bar=make('div',undefined,'ios-row');
 for(const [id,name] of [['2048','🔢 2048'],['snake','🐍 Snake'],['memory','🧠 Memory Match'],['tictactoe','⭕ Tic-Tac-Toe'],['guess','🎯 Guess'],['reaction','⚡ Reaction'],['rps','✂️ Rock Paper Scissors'],['math','🧠 Math Sprint'],['word','🔤 Word Mix'],['pattern','🎨 Pattern Memory']]){
  const b=button(name,()=>switchTo(id));b.dataset.game=id;bar.append(b)
 }wrapper.append(bar);
 const area=make('div');area.id='itamar-game-area';wrapper.append(area);
 const foot=make('p','Saves are local to this browser. Clearing browser data also clears these saves.','ios-caption');wrapper.append(foot);
 switchTo(current);
 if(window.ItamarMoreGames)window.ItamarMoreGames.mount(wrapper);
}
function switchTo(game){
 stopTimers();current=game;
 for(const b of root?.querySelectorAll('[data-game]')||[])b.classList.toggle('ios-active',b.dataset.game===game);
 const area=$('itamar-game-area');if(!area)return;area.replaceChildren();
 if(game==='2048')render2048();else if(game==='snake'){saveData.snake.running=false;save();renderSnake()}else if(game==='memory'){showing=[];renderMemory()}else if(game==='tictactoe')renderTicTacToe();else if(game==='guess')renderGuess();else if(game==='reaction')renderReaction();else if(game==='rps')renderRPS();else if(game==='math')renderMath();else if(game==='word')renderWord();else if(game==='pattern')renderPattern();
}
function reset2048(){const game=saveData.game2048={board:empty2048(),score:0,over:false};spawn(game.board);spawn(game.board);save();render2048()}
function spawn(board){const spots=[];for(let i=0;i<16;i++)if(board[i]===0)spots.push(i);if(!spots.length)return false;const pos=spots[Math.floor(Math.random()*spots.length)];board[pos]=Math.random()<.9?2:4;return true}
function play2048(direction){
 const g=saveData.game2048;if(g.over)return;
 const before=g.board.join(',');
 const lines=[];
 for(let r=0;r<4;r++){const indices=[];for(let c=0;c<4;c++){
   let i;if(direction==='left')i=r*4+c;else if(direction==='right')i=r*4+3-c;else if(direction==='up')i=c*4+r;else i=(3-c)*4+r;indices.push(i)
 }lines.push(indices)}
 for(const indices of lines){
  const vals=indices.map(i=>g.board[i]).filter(Boolean);
  const merged=[];for(let i=0;i<vals.length;i++){if(i+1<vals.length&&vals[i]===vals[i+1]){merged.push(vals[i]*2);g.score+=vals[i]*2;i++}else merged.push(vals[i])}
  while(merged.length<4)merged.push(0);for(let k=0;k<4;k++)g.board[indices[k]]=merged[k]
 }
 if(before===g.board.join(','))return;
 spawn(g.board);saveData.scores['2048']=Math.max(saveData.scores['2048'],g.score);
 if(!g.board.includes(0)){g.over=!['up','down','left','right'].some(d=>canMove(g.board,d))}
 effect('move');save();render2048();
}
function canMove(board){if(board.includes(0))return true;for(let i=0;i<16;i++){if(i%4<3&&board[i]===board[i+1])return true;if(i<12&&board[i]===board[i+4])return true}return false}
function render2048(){
 const a=$('itamar-game-area');if(!a||current!=='2048')return;a.replaceChildren();
 const g=saveData.game2048;if(g.board.every(v=>v===0)){spawn(g.board);spawn(g.board);save()}
 a.append(make('h3','2048 · Merge matching tiles'));artwork(a,'2048');
 a.append(make('p','Score: '+g.score+' · Best: '+saveData.scores['2048']));
 const grid=make('div',undefined,'ios-board ios-2048');for(const n of g.board){const tile=make('div',n||'');if(n)tile.dataset.number=n;grid.append(tile)}a.append(grid);
 swipe(grid,play2048);
 a.append(make('p','Swipe the tile board in any direction, or use arrow keys on a computer.','ios-caption'));
 if(g.over)a.append(make('p','No moves left. Start a new game.','ios-danger'));
 a.append(button('New 2048 game',()=>{if(confirm('Start a new 2048 game? Your best score remains saved.'))reset2048()}));
 // No on-screen direction buttons; the grid itself is the gesture controller.
}
const SIDE=16;
function randomFood(body){const occupied=new Set(body.map(p=>p.x+','+p.y)),spaces=[];for(let y=0;y<SIDE;y++)for(let x=0;x<SIDE;x++)if(!occupied.has(x+','+y))spaces.push({x,y});return spaces.length?spaces[Math.floor(Math.random()*spaces.length)]:null}
function snakeReset(){stopTimers();saveData.snake=defaults().snake;save();renderSnake()}
function snakeDirection(x,y){const g=saveData.snake;if(x===-g.dir.x&&y===-g.dir.y)return;g.next={x,y};save()}
function snakeTick(){
 const g=saveData.snake;if(!g.running||g.over)return;
 g.dir={...g.next};const head={x:g.body[0].x+g.dir.x,y:g.body[0].y+g.dir.y};
 const eat=head.x===g.food?.x&&head.y===g.food?.y;
 const occupied=eat?g.body:g.body.slice(0,-1);
 if(head.x<0||head.y<0||head.x>=SIDE||head.y>=SIDE||occupied.some(p=>p.x===head.x&&p.y===head.y)){
  g.over=true;g.running=false;stopTimers();effect('gameover');save();drawSnake();updateSnakeText();return
 }
 g.body.unshift(head);
 if(eat){effect('collect');g.score++;saveData.scores.snake=Math.max(saveData.scores.snake,g.score);g.food=randomFood(g.body);if(!g.food){g.over=true;g.running=false;stopTimers()}}else g.body.pop();
 save();drawSnake();updateSnakeText();
}
function startSnake(){const g=saveData.snake;if(g.over){snakeReset();return}g.running=!g.running;if(g.running){timer=setInterval(()=>{if(!$('snake-board')||!document.contains($('snake-board'))||$('window')?.classList.contains('hidden')){stopTimers();g.running=false;save();return}snakeTick()},140)}else stopTimers();save();renderSnake()}
function updateSnakeText(){const p=$('snake-score');if(p){const g=saveData.snake;p.textContent='Score: '+g.score+' · Best: '+saveData.scores.snake+(g.over?' · Game over':'')}}
function drawSnake(){
 const c=$('snake-board');if(!c)return;
 const ctx=c.getContext('2d');const cell=c.width/SIDE;
 ctx.fillStyle='#0c2541';ctx.fillRect(0,0,c.width,c.height);
 ctx.fillStyle='#a9c4e5';for(let k=1;k<SIDE;k++){ctx.fillRect(k*cell,0,1,c.height);ctx.fillRect(0,k*cell,c.width,1)}
 const g=saveData.snake;
 if(g.food){ctx.fillStyle='#f79970';ctx.beginPath();ctx.arc((g.food.x+.5)*cell,(g.food.y+.5)*cell,cell*.39,0,Math.PI*2);ctx.fill()}
 g.body.forEach((p,i)=>{ctx.fillStyle=i===0?'#b9f8b4':'#61d296';ctx.fillRect(p.x*cell+2,p.y*cell+2,cell-4,cell-4)});
}
function renderSnake(){
 const a=$('itamar-game-area');if(!a||current!=='snake')return;a.replaceChildren();
 const g=saveData.snake;
 a.append(make('h3','Snake'));artwork(a,'snake');
 const score=make('p','', 'ios-caption');score.id='snake-score';a.append(score);
 const c=make('canvas',undefined,'ios-snake');c.id='snake-board';c.width=400;c.height=400;c.setAttribute('aria-label','Snake play board');a.append(c);drawSnake();updateSnakeText();
 swipe(c,d=>{const v={up:[0,-1],down:[0,1],left:[-1,0],right:[1,0]}[d];snakeDirection(...v)},true);
 a.append(button(g.over?'Try again':'Start / Pause',startSnake),button('New game',()=>{if(confirm('Start a new Snake game?'))snakeReset()}));
 a.append(make('p','Drag your finger along the board to steer the cartoon snake. Keyboard arrows also work.','ios-caption'));
}
function randomize(array){for(let i=array.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[array[i],array[j]]=[array[j],array[i]]}return array}
function memoryReset(){saveData.memory={cards:randomize(icons.flatMap(x=>[x,x])),matched:[],moves:0,finished:false};save();renderMemory()}
let showing=[];
function memoryPick(i){
 const g=saveData.memory;if(g.finished||showing.includes(i)||g.matched.includes(i)||showing.length>=2)return;
 showing.push(i);renderMemory();
 if(showing.length===2){
   g.moves++;
   if(g.cards[showing[0]]===g.cards[showing[1]]){
    g.matched.push(...showing);showing=[];
    effect('collect');if(g.matched.length===g.cards.length){effect('win');g.finished=true;saveData.scores.memory=saveData.scores.memory?Math.min(saveData.scores.memory,g.moves):g.moves}
    save();renderMemory()
   }else{save();flipTimeout=setTimeout(()=>{showing=[];renderMemory()},850)}
 }
}
function renderMemory(){
 const a=$('itamar-game-area');if(!a||current!=='memory')return;a.replaceChildren();const g=saveData.memory;
 if(!g.cards.length){memoryReset();return}
 a.append(make('h3','Memory Match'));artwork(a,'memory');
 a.append(make('p','Moves: '+g.moves+' · Best completion: '+(saveData.scores.memory||'—')+' moves'));
 const grid=make('div',undefined,'ios-board ios-memory');
 g.cards.forEach((symbol,i)=>{const flipped=g.matched.includes(i)||showing.includes(i);const b=button(flipped?symbol:'?',()=>memoryPick(i));b.setAttribute('aria-label','Memory card '+(i+1)+(flipped?', '+symbol:''));b.classList.toggle('found',g.matched.includes(i));if(g.matched.includes(i))b.disabled=true;grid.append(b)});
 a.append(grid);
 if(g.finished)a.append(make('p','All pairs matched! Your result has been saved.','ios-success'));
 a.append(button('New memory game',()=>{if(confirm('Start new Memory Match game?')){showing=[];clearTimeout(flipTimeout);memoryReset()}}));
}
const lines=[[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
function tictactoeResult(board){for(const line of lines){const [a,b,c]=line;if(board[a]&&board[a]===board[b]&&board[a]===board[c])return board[a]}return board.every(Boolean)?'tie':''}
function ticMove(i){const g=saveData.tictactoe;if(g.winner||g.board[i])return;g.board[i]=g.turn;g.winner=tictactoeResult(g.board);if(g.winner){effect('win');g.wins[g.winner]=(g.wins[g.winner]||0)+1}else g.turn=g.turn==='X'?'O':'X';save();renderTicTacToe()}
function renderTicTacToe(){
 const a=$('itamar-game-area');if(!a||current!=='tictactoe')return;a.replaceChildren();const g=saveData.tictactoe;
 a.append(make('h3','Tic-Tac-Toe · 2 players'));artwork(a,'tictactoe');
 a.append(make('p',g.winner?(g.winner==='tie'?'Draw!':'Winner: '+g.winner):'Turn: '+g.turn));
 const board=make('div',undefined,'ios-board');board.style.gridTemplateColumns='repeat(3,1fr)';board.style.maxWidth='300px';
 g.board.forEach((v,i)=>{const b=button(v||'·',()=>ticMove(i));b.style.cssText='aspect-ratio:1;font-size:32px;min-height:70px';b.disabled=Boolean(v||g.winner);board.append(b)});a.append(board);
 a.append(make('p','X wins: '+g.wins.X+' · O wins: '+g.wins.O+' · Draws: '+g.wins.tie));
 a.append(button('Next round',()=>{g.board=Array(9).fill('');g.turn='X';g.winner='';save();renderTicTacToe()}));
}

const rand=(low,high)=>Math.floor(Math.random()*(high-low+1))+low;
function message(area,text){const p=make('p',text,'ios-caption');area.append(p);return p}
function renderGuess(){
 const a=$('itamar-game-area');if(!a||current!=='guess')return;
 const g=saveData.extras.guess;if(!g.target){g.target=rand(1,100);g.tries=0;g.last='';save()}
 a.replaceChildren();a.append(make('h3','Guess the number'));artwork(a,'guess');
 message(a,'A secret number from 1 to 100. Try to find it!');
 message(a,'Attempts: '+g.tries+' · Best (fewest): '+(saveData.scores.guess||'—'));
 const row=make('div',undefined,'ios-row'),input=make('input');input.type='number';input.min='1';input.max='100';input.placeholder='1–100';input.setAttribute('aria-label','Your guess');row.append(input);
 const submit=()=>{
  const value=Number(input.value);if(!Number.isInteger(value)||value<1||value>100)return;
  g.tries++;if(value===g.target){effect('win');g.last='Correct! It took '+g.tries+' attempts.';if(!saveData.scores.guess||g.tries<saveData.scores.guess)saveData.scores.guess=g.tries;g.target=0}else g.last=value<g.target?'Too low!':'Too high!';
  save();renderGuess()
 };
 row.append(button('Guess',submit));a.append(row);
 if(g.last)message(a,g.last);
 a.append(button('New number',()=>{g.target=rand(1,100);g.tries=0;g.last='';save();renderGuess()}));
}
let reactionReadyAt=0,reactionStart=0;
function renderReaction(){
 const a=$('itamar-game-area');if(!a||current!=='reaction')return;
 a.replaceChildren();a.append(make('h3','Reaction timer'));artwork(a,'reaction');
 message(a,'Press Start, then wait for the button to turn green. Do not press too early.');
 message(a,'Fastest time: '+(saveData.scores.reaction?saveData.scores.reaction+' ms':'—'));
 const result=message(a,'Ready?');
 const b=button('Start',()=>{
  if(b.textContent==='Start'){
    clearTimeout(flipTimeout);b.textContent='Wait…';result.textContent='Wait for green!';
    reactionReadyAt=0;reactionStart=0;
    flipTimeout=setTimeout(()=>{reactionReadyAt=Date.now();reactionStart=reactionReadyAt;effect('collect');b.textContent='GO!';b.style.background='#83da9f';result.textContent='Click now!'},rand(900,2700));
  }else if(!reactionReadyAt){
    clearTimeout(flipTimeout);b.textContent='Start';result.textContent='Too early! Try again.';
  }else{
    const delta=Date.now()-reactionStart;
    if(delta>0&&(!saveData.scores.reaction||delta<saveData.scores.reaction)){saveData.scores.reaction=delta;save()}
    b.textContent='Start';b.style.background='';reactionReadyAt=0;result.textContent='Your reaction time: '+delta+' ms';save();
  }
 });
 a.append(b);
}
const rpsChoices=['Rock','Paper','Scissors'];
function renderRPS(){
 const a=$('itamar-game-area');if(!a||current!=='rps')return;a.replaceChildren();
 const g=saveData.extras.rps;a.append(make('h3','Rock Paper Scissors'));artwork(a,'rps');
 message(a,'You vs the computer. No wagers, just fun.');
 message(a,'Wins: '+g.wins+' · Losses: '+g.losses+' · Ties: '+g.ties);
 const result=message(a,'Choose your move');
 const row=make('div',undefined,'ios-row');
 for(let i=0;i<3;i++)row.append(button(['✊ Rock','✋ Paper','✌️ Scissors'][i],()=>{
   const cpu=rand(0,2);const outcome=(i-cpu+3)%3===0?'tie':(i-cpu+3)%3===1?'win':'loss';
   g[outcome==='win'?'wins':outcome==='loss'?'losses':'ties']++;
   effect(outcome==='win'?'win':outcome==='loss'?'error':'move');if(outcome==='win')saveData.scores.rps++;
   save();result.textContent='Computer chose '+rpsChoices[cpu]+'. '+(outcome==='win'?'You won!':outcome==='loss'?'Computer won.':'Tie!');
   const score=a.querySelector?.('[data-score]');if(score)score.textContent='Wins: '+g.wins+' · Losses: '+g.losses+' · Ties: '+g.ties;
 }));
 a.append(row);
 const total=message(a,'Wins: '+g.wins+' · Losses: '+g.losses+' · Ties: '+g.ties);total.dataset.score='1';
}
function nextMath(){
 const g=saveData.extras.math;
 const a=rand(1,20),b=rand(1,20),op=['+','−','×'][rand(0,2)];
 const answer=op==='+'?a+b:op==='−'?a-b:a*b;
 g.question={a,b,op,answer};
 save();
}
function renderMath(){
 const a=$('itamar-game-area');if(!a||current!=='math')return;a.replaceChildren();
 const g=saveData.extras.math;if(!g.question)nextMath();
 a.append(make('h3','Math Sprint'));artwork(a,'math');message(a,'Correct: '+g.correct+' / '+g.total);
 const q=g.question;message(a,q.a+' '+q.op+' '+q.b+' = ?');
 const row=make('div',undefined,'ios-row'),input=make('input');input.type='number';input.placeholder='Answer';row.append(input);
 const result=message(a,'');
 row.append(button('Check',()=>{
   if(input.value.trim()===''||!Number.isFinite(Number(input.value)))return;
   g.total++;const correct=Number(input.value)===q.answer;if(correct){effect('collect');g.correct++;saveData.scores.math=Math.max(g.correct,saveData.scores.math)}result.textContent=correct?'Correct!':'Answer: '+q.answer;
   nextMath();save();renderMath()
 }));a.append(row);
 a.append(button('Skip problem',()=>{nextMath();renderMath()}));
}
const wordBank=[['star','A bright object in the night sky'],['planet','A world orbiting a star'],['cloud','You see it in the sky'],['ocean','A large body of saltwater'],['music','Sounds arranged in rhythm'],['forest','Many trees growing together'],['puzzle','A game that tests your thinking'],['camera','Used to capture photos'],['rocket','A vehicle that travels to space'],['screen','Displays images and text']];
function renderWord(){
 const a=$('itamar-game-area');if(!a||current!=='word')return;a.replaceChildren();
 const g=saveData.extras.word;
 const [word,hint]=wordBank[g.current%wordBank.length];
 const letters=word.toUpperCase().split(''),shuffled=letters.slice().sort(()=>Math.random()-.5).join(' ');
 a.append(make('h3','Word Mix'));artwork(a,'word');
 message(a,'Solved: '+g.completed+' · Progress: '+((g.current%wordBank.length)+1)+' / '+wordBank.length);
 message(a,'Hint: '+hint);message(a,'Letters: '+shuffled);
 const row=make('div',undefined,'ios-row'),input=make('input');input.type='text';input.placeholder='Unscramble the word';row.append(input);const output=message(a,'');
 row.append(button('Submit',()=>{if(input.value.trim().toLowerCase()===word){effect('win');g.completed++;g.current++;saveData.scores.word=Math.max(saveData.scores.word,g.completed);save();renderWord()}else output.textContent='Try again!'}));a.append(row);
}
let patternShow=false,patternIndex=0;
function renderPattern(){
 const a=$('itamar-game-area');if(!a||current!=='pattern')return;a.replaceChildren();
 const g=saveData.extras.pattern;if(!Array.isArray(g.sequence))g.sequence=[];
 a.append(make('h3','Pattern Memory'));artwork(a,'pattern');
 message(a,'Remember the sequence of numbers, then repeat it.');
 message(a,'Level: '+g.level+' · Highest level: '+saveData.scores.pattern);
 const display=message(a,g.sequence.length?'Ready to view your sequence?':'Start a new round.');
 const start=button(g.sequence.length?'Show pattern':'Start',()=>{
  if(!g.sequence.length){g.sequence=[rand(1,4)];g.level=1;save()}
  display.textContent='Sequence: '+g.sequence.join(' – ');
  patternShow=true;patternIndex=0;start.disabled=true;
  clearTimeout(flipTimeout);flipTimeout=setTimeout(()=>{display.textContent='Now repeat the pattern below';patternShow=false;start.disabled=false},Math.max(1100,g.sequence.length*850));
 });a.append(start);
 const row=make('div',undefined,'ios-row');
 for(let n=1;n<=4;n++)row.append(button(String(n),()=>{
  if(patternShow||!g.sequence.length||display.textContent!=='Now repeat the pattern below')return;
  if(g.sequence[patternIndex]!==n){effect('error');display.textContent='Try again! Tap Show pattern.';patternIndex=0;return}
  patternIndex++;
  if(patternIndex===g.sequence.length){effect('win');g.wins++;g.level++;saveData.scores.pattern=Math.max(saveData.scores.pattern,g.level);g.sequence.push(rand(1,4));save();patternIndex=0;display.textContent='Correct! Next level ready.';start.textContent='Show pattern'}
 }));
 a.append(row);a.append(button('Restart',()=>{g.sequence=[];g.level=0;save();patternIndex=0;renderPattern()}));
}
document.addEventListener('keydown',event=>{
 if(!root||!$('itamar-games')||!document.contains(root)||$('window')?.classList.contains('hidden'))return;
 if(['INPUT','TEXTAREA','SELECT'].includes(document.activeElement?.tagName))return;
 const dirs={ArrowUp:[0,-1],ArrowDown:[0,1],ArrowLeft:[-1,0],ArrowRight:[1,0]};
 if(!dirs[event.code])return;
 if(current==='2048'){event.preventDefault();play2048(event.code.slice(5).toLowerCase())}
 if(current==='snake'){event.preventDefault();snakeDirection(...dirs[event.code])}
});
document.addEventListener('visibilitychange',()=>{if(document.hidden&&saveData.snake.running){saveData.snake.running=false;stopTimers();save();if(current==='snake')renderSnake()}});
window.ItamarGames={mount,cleanup};
})();
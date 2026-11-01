/* ItamarOS Games – standalone browser games, persistent local saves, offline play after load. */
(()=>{
'use strict';
const KEY='itamaros-games-v1';
let current='2048',root=null,timer=null,flipTimeout=null,snakeFrame=null,lastSnakeAt=0,snakeSaveAt=0;
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

function matchFor(game){
 saveData.matches??={};
 return saveData.matches[game]??={mode:'friend',difficulty:'medium'};
}
function matchControls(area,game,reset){
 const match=matchFor(game);
 const title=make('p','Who do you want to play against?','ios-caption');area.append(title);
 const opponent=make('select');opponent.setAttribute('aria-label','Choose opponent');
 for(const [value,label] of [['friend','With a friend'],['bot','Against a bot']]){
  const option=make('option',label);option.value=value;opponent.append(option)
 }
 opponent.value=match.mode;area.append(opponent);
 const level=make('select');level.setAttribute('aria-label','Bot difficulty');
 for(const [value,label] of [['easy','Easy'],['medium','Medium'],['hard','Hard']]){
  const option=make('option',label);option.value=value;level.append(option)
 }
 level.value=match.difficulty;level.hidden=match.mode!=='bot';area.append(level);
 opponent.onchange=()=>{match.mode=opponent.value;save();reset()};
 level.onchange=()=>{match.difficulty=level.value;save();reset()};
 if(match.mode==='friend')area.append(make('p','Two friends play in turns on the same device.','ios-caption'));
 return match;
}

function stopTimers(){clearInterval(timer);timer=null;clearTimeout(flipTimeout);flipTimeout=null;if(snakeFrame!==null)cancelAnimationFrame(snakeFrame);snakeFrame=null;lastSnakeAt=0}
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
 stopTimers();memoryToken++;ticToken++;current=game;
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
// Pixel-based physics instead of a grid: 60Hz drawing and continuous motion.
const WORLD=400,SNAKE_SPACING=10,SNAKE_RADIUS=8;
function freshSnake(){
 const body=Array.from({length:13},(_,i)=>({x:200-i*SNAKE_SPACING,y:200}));
 return {smooth:true,body,food:{x:320,y:188},dir:{x:1,y:0},
  next:{x:1,y:0},score:0,over:false,running:false};
}
function snakeState(){
 const current=saveData.snake;
 if(!current?.smooth||!Array.isArray(current.body)||current.body.length<2){
  saveData.snake=freshSnake();save();
 }
 return saveData.snake;
}
function randomSnakeFood(body){
 for(let i=0;i<250;i++){
  const point={x:18+Math.random()*(WORLD-36),y:18+Math.random()*(WORLD-36)};
  if(body.every(p=>Math.hypot(p.x-point.x,p.y-point.y)>25))return point;
 }
 return null;
}
function snakeReset(){
 stopTimers();saveData.snake=freshSnake();save();renderSnake();
}
function snakeDirection(x,y){
 const g=snakeState(),length=Math.hypot(x,y);
 if(length<.01)return;
 const target={x:x/length,y:y/length};
 if(target.x*g.dir.x+target.y*g.dir.y<-.8)return;
 g.next=target;
}
function snakeTick(dt){
 const g=snakeState();if(!g.running||g.over)return;
 const speed=Math.min(230,76+g.score*11);
 // Smooth steering means no discrete 16 x 16 cell movement.
 const blend=Math.min(1,dt*10);
 let dx=g.dir.x*(1-blend)+g.next.x*blend;
 let dy=g.dir.y*(1-blend)+g.next.y*blend;
 const len=Math.hypot(dx,dy)||1;g.dir={x:dx/len,y:dy/len};
 const travel=speed*dt,parts=Math.max(1,Math.ceil(travel/5));
 for(let step=0;step<parts;step++){
  const head=g.body[0],next={x:head.x+g.dir.x*travel/parts,y:head.y+g.dir.y*travel/parts};
  if(next.x<SNAKE_RADIUS||next.y<SNAKE_RADIUS||
      next.x>WORLD-SNAKE_RADIUS||next.y>WORLD-SNAKE_RADIUS||
      g.body.slice(8).some(p=>Math.hypot(next.x-p.x,next.y-p.y)<SNAKE_RADIUS*1.4)){
   g.over=true;g.running=false;stopTimers();effect('gameover');save();return;
  }
  // Advance the head first; following body points preserve fixed spacing.
  g.body[0]=next;
  for(let i=1;i<g.body.length;i++){
   const previous=g.body[i-1],current=g.body[i];
   const distance=Math.hypot(current.x-previous.x,current.y-previous.y);
   if(distance>SNAKE_SPACING){
    const factor=(distance-SNAKE_SPACING)/distance;
    g.body[i]={x:current.x+(previous.x-current.x)*factor,
                y:current.y+(previous.y-current.y)*factor};
   }
  }
  if(g.food&&Math.hypot(next.x-g.food.x,next.y-g.food.y)<19){
   const end=g.body[g.body.length-1];g.body.push({...end});
   g.score++;saveData.scores.snake=Math.max(saveData.scores.snake,g.score);
   effect('collect');g.food=randomSnakeFood(g.body);
   if(!g.food){g.over=true;g.running=false;stopTimers()}
   save();
  }
 }
}
function snakeLoop(now){
 const g=snakeState();
 if(!g.running||g.over){snakeFrame=null;return}
 const canvas=$('snake-board');
 if(!canvas||!canvas.isConnected||$('window')?.classList.contains('hidden')||document.hidden){
  g.running=false;stopTimers();save();return;
 }
 const dt=lastSnakeAt?Math.min(.035,Math.max(0,(now-lastSnakeAt)/1000)):0;
 lastSnakeAt=now;snakeTick(dt);drawSnake();updateSnakeText();
 if(now-snakeSaveAt>1200){save();snakeSaveAt=now}
 if(g.running)snakeFrame=requestAnimationFrame(snakeLoop);else snakeFrame=null;
}
function startSnake(){
 const g=snakeState();if(g.over){snakeReset();return}
 g.running=!g.running;stopTimers();save();renderSnake();
 if(g.running)snakeFrame=requestAnimationFrame(snakeLoop);
}
function updateSnakeText(){
 const p=$('snake-score');if(!p)return;
 const g=snakeState(),speed=Math.min(230,76+g.score*11);
 p.textContent='Score: '+g.score+' · Best: '+saveData.scores.snake+
   ' · Speed: '+Math.round(speed)+' px/s'+(g.over?' · Game over':'');
}
function drawSnake(){
 const canvas=$('snake-board');if(!canvas)return;
 const ctx=canvas.getContext('2d');if(!ctx)return;
 const g=snakeState();
 const grad=ctx.createLinearGradient(0,0,WORLD,WORLD);
 grad.addColorStop(0,'#ecffeb');grad.addColorStop(1,'#b8e9dc');
 ctx.fillStyle=grad;ctx.fillRect(0,0,WORLD,WORLD);
 // Decorative grass, but NO underlying movement grid.
 for(let i=0;i<55;i++){
  const x=(i*79+47)%WORLD,y=(i*137+29)%WORLD;
  ctx.fillStyle='rgba(37,137,93,.09)';ctx.beginPath();ctx.arc(x,y,3,0,Math.PI*2);ctx.fill();
 }
 if(g.food){
  const {x,y}=g.food;ctx.fillStyle='#e43f56';
  for(const n of [-5,5]){ctx.beginPath();ctx.arc(x+n,y+3,8,0,Math.PI*2);ctx.fill()}
  ctx.strokeStyle='#816344';ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(x,y-4);ctx.lineTo(x+2,y-15);ctx.stroke();
  ctx.fillStyle='#58b757';ctx.beginPath();ctx.ellipse(x+7,y-13,7,3,-.4,0,Math.PI*2);ctx.fill();
 }
 const body=g.body;
 if(body.length){
  ctx.strokeStyle='#248966';ctx.lineWidth=SNAKE_RADIUS*2+3;
  ctx.lineCap='round';ctx.lineJoin='round';ctx.beginPath();
  ctx.moveTo(body[body.length-1].x,body[body.length-1].y);
  for(let i=body.length-2;i>=0;i--)ctx.lineTo(body[i].x,body[i].y);
  ctx.stroke();
  ctx.strokeStyle='#7de4a0';ctx.lineWidth=SNAKE_RADIUS*1.25;ctx.stroke();
  const head=body[0],dx=g.dir.x,dy=g.dir.y,nx=-dy,ny=dx;
  ctx.fillStyle='#7de4a0';ctx.beginPath();ctx.arc(head.x,head.y,11,0,Math.PI*2);ctx.fill();
  for(const offset of [-5,5]){
   const x=head.x+dx*4+nx*offset,y=head.y+dy*4+ny*offset;
   ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(x,y,3.7,0,Math.PI*2);ctx.fill();
   ctx.fillStyle='#243a46';ctx.beginPath();ctx.arc(x+dx*1.2,y+dy*1.2,1.9,0,Math.PI*2);ctx.fill();
  }
 }
}
function renderSnake(){
 const a=$('itamar-game-area');if(!a||current!=='snake')return;
 a.replaceChildren();const g=snakeState();
 a.append(make('h3','Snake · Smooth movement'));artwork(a,'snake');
 const score=make('p','','ios-caption');score.id='snake-score';a.append(score);
 const c=make('canvas',undefined,'ios-snake');c.id='snake-board';
 c.width=WORLD;c.height=WORLD;c.setAttribute('aria-label','Continuous Snake game board');
 c.style.touchAction='none';a.append(c);
 const steer=e=>{
  const rect=c.getBoundingClientRect();
  const target={x:(e.clientX-rect.left)*WORLD/rect.width,
                y:(e.clientY-rect.top)*WORLD/rect.height};
  const head=snakeState().body[0];
  if(head)snakeDirection(target.x-head.x,target.y-head.y);
 };
 c.addEventListener('pointerdown',e=>{
  if(e.button!==undefined&&e.button!==0)return;
  c.setPointerCapture?.(e.pointerId);steer(e);
 });
 c.addEventListener('pointermove',e=>{if(e.buttons||e.pressure>0)steer(e)});
 a.append(button(g.over?'Try again':g.running?'Pause':'Start',startSnake),
          button('New game',()=>{if(confirm('Start a new Snake game?'))snakeReset()}));
 a.append(make('p','Move smoothly anywhere on the board. Drag toward a direction or use arrow keys. Every cherry speeds up the snake.','ios-caption'));
 drawSnake();updateSnakeText();
}
function randomize(array){for(let i=array.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[array[i],array[j]]=[array[j],array[i]]}return array}
let showing=[],memoryToken=0,ticToken=0;
function memoryReset(){
 memoryToken++;showing=[];
 saveData.memory={cards:randomize(icons.flatMap(x=>[x,x])),matched:[],moves:0,finished:false,turn:0,points:[0,0],known:{}};
 save();renderMemory();
}
function memoryPick(i,byBot=false){
 const g=saveData.memory,m=matchFor('memory');
 if(g.finished||showing.includes(i)||g.matched.includes(i)||showing.length>=2||(m.mode==='bot'&&g.turn===1&&!byBot))return;
 showing.push(i);
 g.known??={};g.points??=[0,0];g.turn??=0;
 if(m.mode==='bot'&&(m.difficulty==='hard'||(m.difficulty==='medium'&&Math.random()<.55)))g.known[i]=g.cards[i];
 renderMemory();
 if(showing.length===2){
  g.moves++;const a=showing[0],b=showing[1],token=memoryToken;
  flipTimeout=setTimeout(()=>{
   if(token!==memoryToken||current!=='memory')return;
   if(g.cards[a]===g.cards[b]){
    g.matched.push(a,b);g.points[g.turn]++;effect('collect');
    if(g.matched.length===g.cards.length){effect('win');g.finished=true;saveData.scores.memory=saveData.scores.memory?Math.min(saveData.scores.memory,g.moves):g.moves}
   }else g.turn=1-g.turn;
   showing=[];save();renderMemory();
   if(!g.finished&&m.mode==='bot'&&g.turn===1)memoryBotTurn();
  },850);
 }
}
function memoryBotTurn(){
 const g=saveData.memory,m=matchFor('memory'),token=memoryToken;
 flipTimeout=setTimeout(()=>{
  if(token!==memoryToken||current!=='memory'||g.finished||g.turn!==1||showing.length)return;
  const possible=g.cards.map((_,i)=>i).filter(i=>!g.matched.includes(i)),knowledge=g.known||{};
  const known=possible.filter(i=>knowledge[i]!==undefined);
  const knownPair=known.find(i=>known.some(j=>j!==i&&knowledge[i]===knowledge[j]));
  const first=(m.difficulty!=='easy'&&knownPair!==undefined)?knownPair:possible[Math.floor(Math.random()*possible.length)];
  if(first===undefined)return;memoryPick(first,true);
  flipTimeout=setTimeout(()=>{
   if(token!==memoryToken||current!=='memory'||showing.length!==1||showing[0]!==first)return;
   const rest=possible.filter(i=>i!==first&&!g.matched.includes(i));
   const remembered=rest.find(i=>knowledge[i]===g.cards[first]);
   const second=(m.difficulty!=='easy'&&remembered!==undefined)?remembered:rest[Math.floor(Math.random()*rest.length)];
   if(second!==undefined)memoryPick(second,true);
  },370);
 },470);
}
function renderMemory(){
 const a=$('itamar-game-area');if(!a||current!=='memory')return;a.replaceChildren();const g=saveData.memory;
 if(!g.cards.length){memoryReset();return}
 g.turn??=0;g.points??=[0,0];g.known??={};
 a.append(make('h3','Memory Match'));artwork(a,'memory');
 const m=matchControls(a,'memory',memoryReset);
 a.append(make('p','Pairs: Player 1 '+g.points[0]+' · '+(m.mode==='bot'?'Bot':'Player 2')+' '+g.points[1]));
 if(g.finished)a.append(make('p',g.points[0]===g.points[1]?'Draw!':g.points[0]>g.points[1]?'Player 1 wins!':(m.mode==='bot'?'Bot':'Player 2')+' wins!','ios-success'));
 else a.append(make('p','Turn: '+(g.turn===0?'Player 1':m.mode==='bot'?'Bot':'Player 2')+' · Moves: '+g.moves));
 const grid=make('div',undefined,'ios-board ios-memory');
 g.cards.forEach((symbol,i)=>{
  const flipped=g.matched.includes(i)||showing.includes(i);
  const b=button(flipped?symbol:'?',()=>memoryPick(i));
  b.setAttribute('aria-label','Memory card '+(i+1)+(flipped?', '+symbol:''));
  b.classList.toggle('found',g.matched.includes(i));
  b.disabled=g.finished||g.matched.includes(i)||showing.length>=2||(m.mode==='bot'&&g.turn===1);
  grid.append(b);
 });a.append(grid);
 a.append(make('p','Best completed: '+(saveData.scores.memory||'—')+' moves','ios-caption'));
 a.append(button('New memory game',()=>memoryReset()));
}
const lines=[[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
function tictactoeResult(board){for(const line of lines){const [a,b,c]=line;if(board[a]&&board[a]===board[b]&&board[a]===board[c])return board[a]}return board.every(Boolean)?'tie':''}
function ticReset(){ticToken++;const g=saveData.tictactoe;g.board=Array(9).fill('');g.turn='X';g.winner='';save();renderTicTacToe()}
function ticMinimax(board,maximize,depth){
 const outcome=tictactoeResult(board);if(outcome==='O')return 10-depth;if(outcome==='X')return depth-10;if(outcome==='tie')return 0;
 const free=board.map((s,i)=>s?null:i).filter(i=>i!==null);
 if(maximize)return Math.max(...free.map(i=>{const next=board.slice();next[i]='O';return ticMinimax(next,false,depth+1)}));
 return Math.min(...free.map(i=>{const next=board.slice();next[i]='X';return ticMinimax(next,true,depth+1)}));
}
function ticBotPick(){
 const g=saveData.tictactoe,m=matchFor('tictactoe');
 const free=g.board.map((s,i)=>s?null:i).filter(i=>i!==null);
 if(!free.length)return null;
 if(m.difficulty==='easy')return free[Math.floor(Math.random()*free.length)];
 if(m.difficulty==='medium'){
  for(const p of ['O','X'])for(const i of free){const b=g.board.slice();b[i]=p;if(tictactoeResult(b)===p)return i}
  return free[Math.floor(Math.random()*free.length)];
 }
 const scores=free.map(i=>{const b=g.board.slice();b[i]='O';return {i,score:ticMinimax(b,false,0)}});
 const best=Math.max(...scores.map(x=>x.score));
 const tied=scores.filter(x=>x.score===best);
 return tied[Math.floor(Math.random()*tied.length)].i;
}
function ticMove(i,fromBot=false){
 const g=saveData.tictactoe,m=matchFor('tictactoe');
 if(g.winner||g.board[i]||(m.mode==='bot'&&g.turn==='O'&&!fromBot))return;
 g.board[i]=g.turn;g.winner=tictactoeResult(g.board);
 if(g.winner){effect('win');g.wins[g.winner]=(g.wins[g.winner]||0)+1}else g.turn=g.turn==='X'?'O':'X';
 save();renderTicTacToe();
 if(!g.winner&&m.mode==='bot'&&g.turn==='O'){
  const token=ticToken;
  flipTimeout=setTimeout(()=>{
   if(token!==ticToken||current!=='tictactoe'||g.turn!=='O'||g.winner)return;
   const move=ticBotPick();if(move!==null)ticMove(move,true);
  },400);
 }
}
function renderTicTacToe(){
 const a=$('itamar-game-area');if(!a||current!=='tictactoe')return;a.replaceChildren();const g=saveData.tictactoe;
 a.append(make('h3','Tic-Tac-Toe'));artwork(a,'tictactoe');
 const m=matchControls(a,'tictactoe',ticReset);
 a.append(make('p',g.winner?(g.winner==='tie'?'Draw!':'Winner: '+(g.winner==='X'?'Player 1':m.mode==='bot'?'Bot':'Player 2')):'Turn: '+(g.turn==='X'?'Player 1':m.mode==='bot'?'Bot':'Player 2')));
 const board=make('div',undefined,'ios-board');board.style.gridTemplateColumns='repeat(3,1fr)';board.style.maxWidth='300px';
 g.board.forEach((v,i)=>{const b=button(v||'·',()=>ticMove(i));b.style.cssText='aspect-ratio:1;font-size:32px;min-height:70px';b.disabled=Boolean(v||g.winner||(m.mode==='bot'&&g.turn==='O'));board.append(b)});a.append(board);
 a.append(make('p','X wins: '+g.wins.X+' · O wins: '+g.wins.O+' · Draws: '+g.wins.tie));
 a.append(button('Next round',ticReset));
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
 const g=saveData.extras.rps;g.history??=[];g.pending??=null;
 a.append(make('h3','Rock Paper Scissors'));artwork(a,'rps');
 const m=matchControls(a,'rps',()=>{g.history=[];g.pending=null;g.last='';save();renderRPS()});
 message(a,'Player 1 wins: '+g.wins+' · Losses: '+g.losses+' · Draws: '+g.ties);
 message(a,g.pending===null?(m.mode==='bot'?'Choose your move.':'Player 1: choose secretly.'):'Pass the device to Player 2. Their turn!');
 const result=message(a,g.last||'');
 const row=make('div',undefined,'ios-row');
 for(let i=0;i<3;i++)row.append(button(['✊ Rock','✋ Paper','✌️ Scissors'][i],()=>{
  if(m.mode==='friend'&&g.pending===null){
   g.pending=i;g.last='Player 1 locked in a choice.';save();renderRPS();return
  }
  const mine=g.pending===null?i:g.pending;
  let other=i;
  if(m.mode==='bot'){
   other=rand(0,2);
   if(m.difficulty!=='easy'&&g.history.length){
    const counts=[0,1,2].map(n=>g.history.filter(x=>x===n).length);
    const predicted=counts.indexOf(Math.max(...counts));
    if(Math.random()<(m.difficulty==='hard'?.85:.45))other=(predicted+1)%3;
   }
  }
  const outcome=(mine-other+3)%3===0?'tie':(mine-other+3)%3===1?'win':'loss';
  g[outcome==='win'?'wins':outcome==='loss'?'losses':'ties']++;
  if(outcome==='win')saveData.scores.rps++;
  g.last='Player 1: '+rpsChoices[mine]+' · '+(m.mode==='bot'?'Bot':'Player 2')+': '+rpsChoices[other]+'. '+(outcome==='win'?'Player 1 wins!':outcome==='loss'?(m.mode==='bot'?'Bot':'Player 2')+' wins!':'Draw!');
  g.history.push(mine);g.pending=null;
  effect(outcome==='win'?'win':outcome==='loss'?'error':'move');save();renderRPS();
 }));
 a.append(row);
 a.append(button('New match',()=>{g.pending=null;g.history=[];g.last='';save();renderRPS()}));
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
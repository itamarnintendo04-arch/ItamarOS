/* ItamarOS Games – standalone browser games, persistent local saves, offline play after load. */
(()=>{
'use strict';
const KEY='itamaros-games-v1';
let current='2048',root=null,timer=null,flipTimeout=null;
const icons=['🍀','🌈','⭐','🎯','🎵','🚀','🐱','🌟'];
const $=id=>document.getElementById(id);
const make=(tag,txt,cls)=>{const node=document.createElement(tag);if(txt!==undefined)node.textContent=txt;if(cls)node.className=cls;return node};
const button=(txt,fn)=>{const b=make('button',txt);b.type='button';b.addEventListener('click',fn);return b};
const empty2048=()=>Array(16).fill(0);
function defaults(){return {scores:{'2048':0,snake:0,memory:0,tictactoe:0},game2048:{board:empty2048(),score:0,over:false},snake:{body:[{x:5,y:7},{x:4,y:7},{x:3,y:7}],food:{x:10,y:7},dir:{x:1,y:0},next:{x:1,y:0},score:0,over:false,running:false},memory:{cards:[],matched:[],moves:0,finished:false},tictactoe:{board:Array(9).fill(''),turn:'X',winner:'',wins:{X:0,O:0,tie:0}}}}
function load(){try{const s=JSON.parse(localStorage.getItem(KEY));if(!s||typeof s!=='object')return defaults();const d=defaults();for(const k of Object.keys(d))if(k in s&&s[k]&&typeof s[k]==='object')d[k]={...d[k],...s[k]};if(!Array.isArray(d.game2048.board)||d.game2048.board.length!==16)d.game2048=defaults().game2048;if(!Array.isArray(d.tictactoe.board)||d.tictactoe.board.length!==9)d.tictactoe=defaults().tictactoe;if(!Array.isArray(d.snake.body)||!d.snake.body.length)d.snake=defaults().snake;return d}catch{return defaults()}}
let saveData=load();
const save=()=>{try{localStorage.setItem(KEY,JSON.stringify(saveData))}catch{}};
function stopTimers(){clearInterval(timer);timer=null;clearTimeout(flipTimeout);flipTimeout=null}
function cleanup(){stopTimers()}
function mount(){
 stopTimers();root=$('content');if(!root)return;root.replaceChildren();
 const wrapper=make('section',undefined,'ios-feature');wrapper.id='itamar-games';root.append(wrapper);
 wrapper.append(make('h2','🎮 ItamarOS Games'));
 wrapper.append(make('p','Play instantly. Your scores and progress are saved in this browser. No account or download required.','ios-caption'));
 const bar=make('div',undefined,'ios-row');
 for(const [id,name] of [['2048','🔢 2048'],['snake','🐍 Snake'],['memory','🧠 Memory Match'],['tictactoe','⭕ Tic-Tac-Toe']]){
  const b=button(name,()=>switchTo(id));b.dataset.game=id;bar.append(b)
 }wrapper.append(bar);
 const area=make('div');area.id='itamar-game-area';wrapper.append(area);
 const foot=make('p','Saves are local to this browser. Clearing browser data also clears these saves.','ios-caption');wrapper.append(foot);
 switchTo(current);
}
function switchTo(game){
 stopTimers();current=game;
 for(const b of root?.querySelectorAll('[data-game]')||[])b.classList.toggle('ios-active',b.dataset.game===game);
 const area=$('itamar-game-area');if(!area)return;area.replaceChildren();
 if(game==='2048')render2048();else if(game==='snake'){saveData.snake.running=false;save();renderSnake()}else if(game==='memory'){showing=[];renderMemory()}else renderTicTacToe();
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
 save();render2048();
}
function canMove(board){if(board.includes(0))return true;for(let i=0;i<16;i++){if(i%4<3&&board[i]===board[i+1])return true;if(i<12&&board[i]===board[i+4])return true}return false}
function render2048(){
 const a=$('itamar-game-area');if(!a||current!=='2048')return;a.replaceChildren();
 const g=saveData.game2048;if(g.board.every(v=>v===0)){spawn(g.board);spawn(g.board);save()}
 a.append(make('h3','2048 · Merge matching tiles'));
 a.append(make('p','Score: '+g.score+' · Best: '+saveData.scores['2048']));
 const grid=make('div',undefined,'ios-board ios-2048');for(const n of g.board){const tile=make('div',n||'');if(n)tile.dataset.number=n;grid.append(tile)}a.append(grid);
 const controls=make('div',undefined,'ios-dpad');
 controls.append(make('span'),button('↑',()=>play2048('up')),make('span'),button('←',()=>play2048('left')),button('↓',()=>play2048('down')),button('→',()=>play2048('right')));
 a.append(controls);
 if(g.over)a.append(make('p','No moves left. Start a new game.','ios-danger'));
 a.append(button('New 2048 game',()=>{if(confirm('Start a new 2048 game? Your best score remains saved.'))reset2048()}));
 a.append(make('p','Use arrow keys or the on-screen arrows to slide tiles.','ios-caption'));
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
  g.over=true;g.running=false;stopTimers();save();drawSnake();updateSnakeText();return
 }
 g.body.unshift(head);
 if(eat){g.score++;saveData.scores.snake=Math.max(saveData.scores.snake,g.score);g.food=randomFood(g.body);if(!g.food){g.over=true;g.running=false;stopTimers()}}else g.body.pop();
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
 a.append(make('h3','Snake'));
 const score=make('p','', 'ios-caption');score.id='snake-score';a.append(score);
 const c=make('canvas',undefined,'ios-snake');c.id='snake-board';c.width=400;c.height=400;c.setAttribute('aria-label','Snake play board');a.append(c);drawSnake();updateSnakeText();
 const controls=make('div',undefined,'ios-dpad');
 controls.append(make('span'),button('↑',()=>snakeDirection(0,-1)),make('span'),button('←',()=>snakeDirection(-1,0)),button('↓',()=>snakeDirection(0,1)),button('→',()=>snakeDirection(1,0)));
 a.append(controls);
 a.append(button(g.over?'Try again':'Start / Pause',startSnake),button('New game',()=>{if(confirm('Start a new Snake game?'))snakeReset()}));
 a.append(make('p','Arrow keys or touch controls; avoid the walls and your tail.','ios-caption'));
 // mobile swipe support
 let start=null;c.addEventListener('touchstart',e=>{if(e.touches.length===1)start={x:e.touches[0].clientX,y:e.touches[0].clientY}},{passive:true});
 c.addEventListener('touchend',e=>{if(!start||!e.changedTouches.length)return;const dx=e.changedTouches[0].clientX-start.x,dy=e.changedTouches[0].clientY-start.y;start=null;if(Math.max(Math.abs(dx),Math.abs(dy))<18)return;if(Math.abs(dx)>Math.abs(dy))snakeDirection(Math.sign(dx),0);else snakeDirection(0,Math.sign(dy))},{passive:true});
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
    if(g.matched.length===g.cards.length){g.finished=true;saveData.scores.memory=saveData.scores.memory?Math.min(saveData.scores.memory,g.moves):g.moves}
    save();renderMemory()
   }else{save();flipTimeout=setTimeout(()=>{showing=[];renderMemory()},850)}
 }
}
function renderMemory(){
 const a=$('itamar-game-area');if(!a||current!=='memory')return;a.replaceChildren();const g=saveData.memory;
 if(!g.cards.length){memoryReset();return}
 a.append(make('h3','Memory Match'));
 a.append(make('p','Moves: '+g.moves+' · Best completion: '+(saveData.scores.memory||'—')+' moves'));
 const grid=make('div',undefined,'ios-board ios-memory');
 g.cards.forEach((symbol,i)=>{const flipped=g.matched.includes(i)||showing.includes(i);const b=button(flipped?symbol:'?',()=>memoryPick(i));b.setAttribute('aria-label','Memory card '+(i+1)+(flipped?', '+symbol:''));b.classList.toggle('found',g.matched.includes(i));if(g.matched.includes(i))b.disabled=true;grid.append(b)});
 a.append(grid);
 if(g.finished)a.append(make('p','All pairs matched! Your result has been saved.','ios-success'));
 a.append(button('New memory game',()=>{if(confirm('Start new Memory Match game?')){showing=[];clearTimeout(flipTimeout);memoryReset()}}));
}
const lines=[[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
function tictactoeResult(board){for(const line of lines){const [a,b,c]=line;if(board[a]&&board[a]===board[b]&&board[a]===board[c])return board[a]}return board.every(Boolean)?'tie':''}
function ticMove(i){const g=saveData.tictactoe;if(g.winner||g.board[i])return;g.board[i]=g.turn;g.winner=tictactoeResult(g.board);if(g.winner){g.wins[g.winner]=(g.wins[g.winner]||0)+1}else g.turn=g.turn==='X'?'O':'X';save();renderTicTacToe()}
function renderTicTacToe(){
 const a=$('itamar-game-area');if(!a||current!=='tictactoe')return;a.replaceChildren();const g=saveData.tictactoe;
 a.append(make('h3','Tic-Tac-Toe · 2 players'));
 a.append(make('p',g.winner?(g.winner==='tie'?'Draw!':'Winner: '+g.winner):'Turn: '+g.turn));
 const board=make('div',undefined,'ios-board');board.style.gridTemplateColumns='repeat(3,1fr)';board.style.maxWidth='300px';
 g.board.forEach((v,i)=>{const b=button(v||'·',()=>ticMove(i));b.style.cssText='aspect-ratio:1;font-size:32px;min-height:70px';b.disabled=Boolean(v||g.winner);board.append(b)});a.append(board);
 a.append(make('p','X wins: '+g.wins.X+' · O wins: '+g.wins.O+' · Draws: '+g.wins.tie));
 a.append(button('Next round',()=>{g.board=Array(9).fill('');g.turn='X';g.winner='';save();renderTicTacToe()}));
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
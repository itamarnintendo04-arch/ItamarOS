/* Power controls for browser/Electron ItamarOS emulator.
 * Only virtual session power; never turns off the physical device. */
(()=>{'use strict';
const menu=document.getElementById('appmenu');
const panel=document.createElement('div');
panel.id='itamar-power-dialog';
panel.hidden=true;
panel.setAttribute('role','dialog');
panel.setAttribute('aria-modal','true');
panel.setAttribute('aria-label','Power options');
panel.innerHTML=[
 '<section class="it-power-panel">',
 '<h2>⏻ ItamarOS Power</h2>',
 '<p>Select what happens to this ItamarOS emulator session.</p>',
 '<div class="it-power-options">',
 '<button type="button" data-mode="sleep">🌙 Sleep</button>',
 '<button type="button" data-mode="restart">↻ Restart</button>',
 '<button type="button" data-mode="shutdown">⏻ Shut down</button>',
 '</div><button type="button" id="itPowerCancel">Cancel</button>',
 '<p class="it-power-note">These options affect the emulator, not your physical computer or phone.</p>',
 '</section>'
].join('');
const overlay=document.createElement('div');
overlay.id='itamar-power-overlay';
overlay.hidden=true;
overlay.setAttribute('role','status');
const notice=document.createElement('h1');
const desc=document.createElement('p');
const wake=document.createElement('button');
wake.type='button';
wake.textContent='⏻ Wake ItamarOS';
wake.onclick=()=>{
 overlay.hidden=true;
 document.body.classList.remove('itamar-emulator-asleep');
};
overlay.append(notice,desc,wake);
document.body.append(panel,overlay);
function close(){panel.hidden=true}
function open(){menu.hidden=true;panel.hidden=false;panel.querySelector('#itPowerCancel').focus();}
window.ItamarPower=Object.freeze({open});
panel.addEventListener('click',e=>{
 const button=e.target.closest('button');if(!button)return;
 if(button.id==='itPowerCancel'){close();return}
 const mode=button.dataset.mode;
 if(!['sleep','restart','shutdown'].includes(mode))return;
 close();
 if(mode==='restart'){location.reload();return}
 overlay.hidden=false;
 document.body.classList.add('itamar-emulator-asleep');
 if(mode==='sleep'){
   notice.textContent='🌙 ItamarOS is sleeping';
   desc.textContent='Your emulator is paused. Tap Wake to return.';
   wake.textContent='Wake ItamarOS';
 }else{
   notice.textContent='⏻ ItamarOS has shut down';
   desc.textContent='The emulator session is off. Your locally saved files and games remain stored.';
   wake.textContent='⏻ Power on ItamarOS';
 }
 wake.focus();
});
panel.addEventListener('keydown',e=>{if(e.key==='Escape')close()});
})();
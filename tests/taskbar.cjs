'use strict';
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../apps/taskbar.js'),'utf8');

class Element {
 constructor(tag='div'){this.tagName=tag.toUpperCase();this.children=[];this.childNodes=this.children;this.textContent='';this.id='';this.style={};this.dataset={};this.events={};this.attributes={};this.hidden=false;
  const flags=new Set();this.classList={add:x=>flags.add(x),remove:x=>flags.delete(x),contains:x=>flags.has(x),toggle:(x,on)=>{if(on===undefined? !flags.has(x):on)flags.add(x);else flags.delete(x)}};
 }
 append(...nodes){this.children.push(...nodes);this.childNodes=this.children}
 replaceChildren(...nodes){this.children=nodes;this.childNodes=this.children}
 remove(){this.removed=true}
 setAttribute(k,v){this.attributes[k]=v}
 addEventListener(k,cb){this.events[k]=cb}
}
const content=new Element(),win=new Element(),title=new Element(),bar=new Element();
const map={content,window:win,title,'taskbar-apps':bar};
win.classList.remove('hidden');
content.append(new Element('input'));
const saved=new Map();
const listeners={};
const document={
 body:{dataset:{device:'desktop'}},
 readyState:'complete',
 getElementById:id=>map[id]||null,
 createElement:tag=>new Element(tag),
 addEventListener:(type,fn)=>{listeners[type]=fn}
};
const window={
 innerWidth:1440,innerHeight:900,
 launch:id=>{win.classList.remove('hidden');title.textContent=id;const node=new Element('textarea');node.dataset.id=id;content.replaceChildren(node)},
 closeWindow:()=>win.classList.add('hidden'),
 minimizeWindow:()=>win.classList.add('hidden'),
 dispatchEvent(){}
};
const localStorage={getItem:k=>saved.get(k)||null,setItem:(k,v)=>saved.set(k,v)};
const context={document,window,localStorage,CustomEvent:class{constructor(name,data){this.type=name;this.detail=data?.detail}},console};
vm.runInNewContext(source,context);
const mgr=window.ItamarTaskbar;
assert.ok(mgr);
assert.ok(mgr.getPinned().includes('files'));
assert.equal(mgr.getActive(),'welcome','Welcome is initially running');

window.launch('files');
assert.equal(mgr.getActive(),'files');
const originalNode=content.childNodes[0];
originalNode.textContent='Draft work';
window.launch('settings');
assert.ok(mgr.getRunning().includes('files'));
assert.ok(mgr.getRunning().includes('settings'));
window.launch('files');
assert.equal(content.childNodes[0],originalNode,'Open app content should be preserved between taskbar switches');
assert.equal(content.childNodes[0].textContent,'Draft work');

window.minimizeWindow();
assert.equal(win.classList.contains('hidden'),true);
window.launch('files');
assert.equal(win.classList.contains('hidden'),false,'Pinned/running app should be restorable');

mgr.togglePin('files');
assert.ok(!mgr.getPinned().includes('files'));
assert.ok(saved.has('itamaros-taskbar-v1'));
mgr.togglePin('files');
assert.ok(mgr.getPinned().includes('files'));
window.closeWindow();
assert.ok(!mgr.getRunning().includes('files'),'Closing removes a running app');
assert.ok(mgr.getPinned().includes('files'),'Closing does not unpin');
assert.ok(bar.childNodes.some(n=>n.title.includes('Files')),'Pinned app remains visible');
assert.equal(mgr.open('streaming'),false,'TV-only streaming unavailable outside TV');
console.log('ItamarOS Taskbar: pin/unpin, switch, preserved DOM, minimize, close and TV gating passed.');

'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {discoverWindowsStartApps,isStartShortcut}=require('../desktop/windows-apps.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'itamaros-windows-apps-'));
try{
  const appdata=path.join(root,'appdata');
  const programdata=path.join(root,'programdata');
  const personal=path.join(appdata,'Microsoft','Windows','Start Menu','Programs');
  const common=path.join(programdata,'Microsoft','Windows','Start Menu','Programs');
  fs.mkdirSync(path.join(personal,'Accessories'),{recursive:true});
  fs.mkdirSync(path.join(common,'Startup'),{recursive:true});
  fs.writeFileSync(path.join(personal,'Accessories','Calculator.lnk'),'fake shortcut');
  fs.writeFileSync(path.join(common,'Paint.lnk'),'fake shortcut');
  fs.writeFileSync(path.join(common,'Startup','Hidden.lnk'),'fake shortcut');
  fs.writeFileSync(path.join(common,'not-a-shortcut.txt'),'ignore');
  fs.writeFileSync(path.join(common,'calculator.lnk'),'duplicate');
  const data=discoverWindowsStartApps({platform:'win32',env:{APPDATA:appdata,ProgramData:programdata}});
  assert.deepEqual(data.apps.map(a=>a.name),['Calculator','Paint']);
  assert.equal(data.pathsById.size,2);
  assert.ok(data.apps.every(a=>typeof a.id==='string'&& !('path' in a)));
  assert.ok(data.apps.every(a=>isStartShortcut(data.pathsById.get(a.id),data.roots)));
  assert.equal(isStartShortcut(path.join(root,'elsewhere.lnk'),data.roots),false);
  assert.equal(isStartShortcut(path.join(common,'not-a-shortcut.txt'),data.roots),false);
  assert.equal(discoverWindowsStartApps({platform:'linux',env:{APPDATA:appdata,ProgramData:programdata}}).apps.length,0);
  console.log('Windows app bridge: sorted .lnk names, scoped root, dedup and startup exclusions passed.');
}finally{fs.rmSync(root,{recursive:true,force:true})}

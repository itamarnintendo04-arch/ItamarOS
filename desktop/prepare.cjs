'use strict';
/* Copy ONLY reviewed static demo resources into the Electron package. */
const fs=require('node:fs'),path=require('node:path');
const repo=path.resolve(__dirname,'..'),out=path.join(__dirname,'web');
const list=['index.html','setup.html','downloads.html','manifest.webmanifest','sw.js',
'apps/addons.css','apps/player.js','apps/games.js','apps/more-games.js','apps/itamio.js','apps/updates.js',
'assets/itamaros-icon.svg','updates/stable.json','updates/native-stable.json'];
fs.rmSync(out,{recursive:true,force:true});fs.mkdirSync(out,{recursive:true});
for(const relative of list){const source=path.resolve(repo,relative);
if(!source.startsWith(repo+path.sep)||!fs.statSync(source).isFile())throw Error('Unexpected demo asset: '+relative);
const target=path.join(out,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(source,target)}
console.log('Packaged '+list.length+' static emulator assets into desktop/web.');

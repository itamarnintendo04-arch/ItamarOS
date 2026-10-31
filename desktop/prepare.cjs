'use strict';
/* Copy ONLY reviewed static demo resources into the Electron package. */
const fs=require('node:fs'),path=require('node:path');
const repo=path.resolve(__dirname,'..'),out=path.join(__dirname,'web');
const list=['index.html','setup.html','downloads.html','feedback.html','itamarcode/resources/itamarcode-icon.svg','manifest.webmanifest','sw.js',
'apps/addons.css','apps/player.js','apps/game-art.js','apps/game-audio.js','apps/games.js','apps/more-games.js','apps/tv-streaming.js','apps/settings.js','apps/taskbar.js','apps/updates.js',
'assets/itamaros-icon.svg',
'assets/branding/itamaros-logo.png','assets/branding/itamaros-logo.webp','assets/branding/itamaros-mark-512.png',
'assets/branding/itamaros-icon-192.png','assets/branding/itamaros-maskable-512.png',
'assets/branding/itamaros-apple-touch-180.png','assets/branding/itamaros-favicon-32.png',
'updates/stable.json','updates/native-stable.json'];
const sounds=path.join(repo,'assets','sfx');
if(fs.existsSync(sounds))for(const sound of fs.readdirSync(sounds)){if(sound.endsWith('.wav')||sound.endsWith('.txt'))list.push('assets/sfx/'+sound)}
for(const icon of fs.readdirSync(path.join(repo,'assets','icons'))){if(icon.endsWith('.svg'))list.push('assets/icons/'+icon)}
fs.rmSync(out,{recursive:true,force:true});fs.mkdirSync(out,{recursive:true});
for(const relative of list){const source=path.resolve(repo,relative);
if(!source.startsWith(repo+path.sep)||!fs.statSync(source).isFile())throw Error('Unexpected demo asset: '+relative);
const target=path.join(out,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(source,target)}
console.log('Packaged '+list.length+' static emulator assets into desktop/web.');

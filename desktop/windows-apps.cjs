'use strict';
/* Read Windows Start Menu .lnk entries only, never registry keys or arbitrary files.
 * The map is retained in Electron's private main process. No absolute path is
 * disclosed to the browser. Skip Startup, symbolic links, nested loops. */
const fs=require('node:fs');
const path=require('node:path');

function discoverWindowsStartApps(options={}){
 const platform=options.platform||process.platform;
 const env=options.env||process.env;
 const io=options.fs||fs;
 const entries=[];
 const pathsById=new Map();
 if(platform!=='win32')return {apps:entries,pathsById,roots:[]};
 const roots=[env.APPDATA&&path.join(env.APPDATA,'Microsoft','Windows','Start Menu','Programs'),
              env.ProgramData&&path.join(env.ProgramData,'Microsoft','Windows','Start Menu','Programs')]
    .filter(Boolean).map(p=>path.resolve(p));
 const seen=new Set();
 function walk(dir,depth){
  if(depth>5||entries.length>=500)return;
  let children;
  try{children=io.readdirSync(dir,{withFileTypes:true})}catch{return}
  for(const node of children){
   if(entries.length>=500)break;
   if(node.isSymbolicLink?.())continue;
   const candidate=path.join(dir,node.name);
   if(node.isDirectory()){
     if(node.name.toLowerCase()==='startup')continue;
     walk(candidate,depth+1);
   }else if(node.isFile()&&/\.lnk$/i.test(node.name)){
     const title=node.name.replace(/\.lnk$/i,'').trim();
     if(!title||title.startsWith('.')||seen.has(title.toLowerCase()))continue;
     const id=String(entries.length+1);
     seen.add(title.toLowerCase());
     entries.push({id,name:title,group:title[0].toLocaleUpperCase('en-US')});
     pathsById.set(id,candidate);
   }
  }
 }
 roots.forEach(root=>walk(root,0));
 entries.sort((a,b)=>a.name.localeCompare(b.name));
 return {apps:entries,pathsById,roots};
}
function isStartShortcut(filename,roots,io=fs){
 if(typeof filename!=='string'||!/\.lnk$/i.test(filename))return false;
 const resolved=path.resolve(filename).toLowerCase();
 if(!roots.some(root=>resolved.startsWith(path.resolve(root).toLowerCase()+path.sep.toLowerCase())))return false;
 try{
  const stat=io.lstatSync(filename);
  return stat.isFile()&&!stat.isSymbolicLink();
 }catch{return false}
}
module.exports={discoverWindowsStartApps,isStartShortcut};

'use strict';
/* Secure, single-user Electron wrapper around the ItamarOS browser demo.
 * Never runs installers, changes partitions, or exposes a Node bridge. */
const {app,BrowserWindow,shell,ipcMain,session}=require('electron');
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.webmanifest':'application/manifest+json; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.webp':'image/webp','.ico':'image/x-icon'};
let local=null;
let mainWindow=null;
let youtubeWindow=null;
let localOrigin='';
const trustedExternal=u=>{try{const url=new URL(u);return url.protocol==='https:'}catch{return false}};
async function openExternal(url){if(trustedExternal(url))await shell.openExternal(url)}

function isYouTubeHost(host){
 const h=String(host).toLowerCase();
 return h==='youtube.com'||h.endsWith('.youtube.com')||h==='youtu.be';
}
function openYouTubeWebView(){
 if(youtubeWindow&&!youtubeWindow.isDestroyed()){youtubeWindow.focus();return true}
 const youtubeSession=session.fromPartition('persist:itamaros-youtube');
 // WebView browsing cannot access the desktop OS without explicit trusted permissions.
 youtubeSession.setPermissionRequestHandler((_contents,_permission,callback)=>callback(false));
 youtubeWindow=new BrowserWindow({
   width:1160,height:760,minWidth:620,minHeight:450,
   title:'YouTube WebView · ItamarOS',icon:path.join(__dirname,'assets','itamaros-mark-512.png'),
   backgroundColor:'#0c1020',autoHideMenuBar:true,
   webPreferences:{
     partition:'persist:itamaros-youtube',
     nodeIntegration:false,contextIsolation:true,sandbox:true,
     webSecurity:true,allowRunningInsecureContent:false,webviewTag:false
   }
 });
 youtubeWindow.on('closed',()=>{youtubeWindow=null});
 youtubeWindow.webContents.setWindowOpenHandler(({url})=>{
   if(trustedExternal(url))openExternal(url).catch(()=>{});
   return {action:'deny'}
 });
 youtubeWindow.webContents.on('will-navigate',(event,destination)=>{
   let allowed=false;try{const u=new URL(destination);allowed=u.protocol==='https:'&&isYouTubeHost(u.hostname)}catch{}
   if(!allowed){event.preventDefault();openExternal(destination).catch(()=>{})}
 });
 youtubeWindow.webContents.on('will-attach-webview',event=>event.preventDefault());
 youtubeWindow.loadURL('https://www.youtube.com/').catch(()=>{if(youtubeWindow&&!youtubeWindow.isDestroyed())youtubeWindow.loadURL('https://www.youtube.com/').catch(()=>{})});
 return true;
}

async function main(){
 const root=path.resolve(app.getAppPath(),'web');
 if(!fs.existsSync(path.join(root,'index.html')))throw Error('Missing packaged emulator files. Run npm start from the desktop directory.');
 local=http.createServer((req,res)=>{
  const u=new URL(req.url,'http://localhost');let rel;
  try{rel=decodeURIComponent(u.pathname)}catch{res.writeHead(400);res.end();return}
  if(rel==='/'||rel==='/index.html')rel='/index.html';
  if(rel.includes('\\')||rel.includes('\0')||rel.split('/').includes('..')){res.writeHead(403);res.end();return}
  const name=path.resolve(root,'.'+rel);
  if(name!==root&&!name.startsWith(root+path.sep)){res.writeHead(403);res.end();return}
  let data;try{const st=fs.statSync(name);if(!st.isFile())throw Error();data=fs.readFileSync(name)}catch{res.writeHead(404);res.end('Not found');return}
  res.writeHead(200,{'Content-Type':mime[path.extname(name)]||'application/octet-stream','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'});
  res.end(data)
 });
 await new Promise((resolve,reject)=>{local.once('error',reject);local.listen(0,'127.0.0.1',resolve)});
 const url='http://127.0.0.1:'+local.address().port+'/';
 const win=new BrowserWindow({width:1270,height:820,minWidth:850,minHeight:590,autoHideMenuBar:true,title:'ItamarOS Demo 1.1',icon:path.join(__dirname,'assets','itamaros-mark-512.png'),webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true,webSecurity:true,preload:path.join(__dirname,'preload.cjs')}});
 const origin=new URL(url).origin;
 localOrigin=origin;
 mainWindow=win;
 win.webContents.setWindowOpenHandler(details=>{openExternal(details.url).catch(()=>{});return {action:'deny'}});
 win.webContents.on('will-navigate',(event,target)=>{if(new URL(target).origin!==origin){event.preventDefault();openExternal(target).catch(()=>{})}});
 win.webContents.on('will-redirect',(event,target)=>{if(new URL(target).origin!==origin){event.preventDefault();openExternal(target).catch(()=>{})}});
 await win.loadURL(url)
}
app.whenReady().then(()=>{
  ipcMain.handle('itamaros:youtube-webview',event=>{
    if(!mainWindow||mainWindow.isDestroyed()||event.sender!==mainWindow.webContents)return false;
    try{if(new URL(event.senderFrame.url).origin!==localOrigin)return false}catch{return false}
    return openYouTubeWebView()
  });
  return main();
}).catch(error=>{console.error(error);app.quit()});
app.on('window-all-closed',()=>app.quit());
app.on('before-quit',()=>{if(local)local.close()});

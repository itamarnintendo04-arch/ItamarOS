'use strict';
const {app,BrowserWindow,shell,session,dialog}=require('electron');
const path=require('node:path');
const HOME='https://itamaros-web-emulator.onrender.com/';
function external(url){
 try{const u=new URL(url);if(u.protocol!=='https:'&&u.protocol!=='http:')return false;
  shell.openExternal(u.href);return true
 }catch{return false}
}
function makeWindow(){
 const win=new BrowserWindow({
  width:1280,height:800,minWidth:720,minHeight:540,backgroundColor:'#0b1b35',
  title:'ItamarOS Demo 1.1',autoHideMenuBar:true,show:false,
  webPreferences:{
   nodeIntegration:false,contextIsolation:true,sandbox:true,
   webSecurity:true,allowRunningInsecureContent:false,webviewTag:false,
   nativeWindowOpen:false
  }
 });
 win.once('ready-to-show',()=>win.show());
 win.webContents.setWindowOpenHandler(({url})=>{external(url);return {action:'deny'}});
 win.webContents.on('will-navigate',(event,url)=>{
  try{const u=new URL(url);if(u.origin!==new URL(HOME).origin){event.preventDefault();external(url)}}
  catch{event.preventDefault()}
 });
 win.webContents.on('will-attach-webview',e=>e.preventDefault());
 win.loadURL(HOME+'?edition=desktop-demo').catch(()=>{
  win.loadFile(path.join(__dirname,'assets','offline.html')).catch(()=>{});
 });
 win.webContents.on('render-process-gone',(_e,details)=>console.error('Renderer stopped:',details.reason));
 return win;
}
app.whenReady().then(()=>{
 session.defaultSession.setPermissionRequestHandler((contents,permission,callback)=>{
  // The web demo does not require webcam/mic/geolocation notifications by default.
  callback(false);
 });
 makeWindow();
 app.on('activate',()=>{if(BrowserWindow.getAllWindows().length===0)makeWindow()});
});
app.on('window-all-closed',()=>{if(process.platform!=='darwin')app.quit()});

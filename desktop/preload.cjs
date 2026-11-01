'use strict';
const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('ItamarRuntime',Object.freeze({
  edition:'desktop-demo',platform:process.platform,version:'1.1.0',
  nativeInstaller:false,
  openYouTubeWebView:()=>ipcRenderer.invoke('itamaros:youtube-webview'),
  listWindowsApps:()=>ipcRenderer.invoke('itamaros:list-windows-apps'),
  openWindowsApp:(id)=>ipcRenderer.invoke('itamaros:open-windows-app',id)
}));

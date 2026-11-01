'use strict';
const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('itamarConnect',{
 start:()=>ipcRenderer.invoke('pair:start'),
 poll:()=>ipcRenderer.invoke('pair:poll'),
 status:()=>ipcRenderer.invoke('auth:status'),
 logout:()=>ipcRenderer.invoke('auth:logout'),
 api:(method,route,body)=>ipcRenderer.invoke('chat:request',{method,route,body}),
 openHelp:()=>ipcRenderer.invoke('open:help')
});

'use strict';
const path=require('node:path');
const {app,BrowserWindow,ipcMain,shell}=require('electron');
const QRCode=require('qrcode');
const BROKER='https://itamaros-store-api.onrender.com/api/connect/pair';
const SUPABASE='https://slqjkysinhfkqjoigfuz.supabase.co';
const KEY='sb_publishable__WVo13dRVkDYChuGxHxk9A_CDoVR9ts'; // public key, not secret.
let windowRef=null;
let ticket=null;
let currentToken=null;
let expiresAt=0;
let activeUserId=null;

function reset(){ticket=null;currentToken=null;expiresAt=0;activeUserId=null}
async function request(url,options={}){
 const response=await fetch(url,{...options,signal:AbortSignal.timeout(12000)});
 let data;
 try{data=await response.json()}catch{data={error:'Unexpected response from server'}}
 if(!response.ok && response.status!==202)throw new Error(data.error||'Request failed ('+response.status+')');
 return {status:response.status,data};
}
const asJSON=(body)=>({method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
ipcMain.handle('pair:start',async()=>{
 reset();
 const {data}=await request(BROKER+'/start',asJSON({}));
 const {requestId,claimSecret,approveUrl,expiresAt:expiry}=data;
 if(!/^[\w-]{20,40}$/.test(requestId)||!/^[\w-]{30,50}$/.test(claimSecret)||
    !approveUrl.startsWith('https://itamaros-web-emulator.onrender.com/connect-approve.html#request='))throw Error('Pairing server returned invalid details');
 ticket={requestId,claimSecret,expiry};
 const qr=await QRCode.toDataURL(approveUrl,{errorCorrectionLevel:'M',margin:2,width:330});
 return {qr,shortCode:requestId.slice(0,6).toUpperCase(),expiresAt:expiry,approveUrl};
});
ipcMain.handle('pair:poll',async()=>{
 if(currentToken && expiresAt>Date.now()+5000)return {status:'approved',userId:activeUserId,expiresAt};
 if(!ticket)throw Error('Generate a new QR code');
 if(ticket.expiry<Date.now()){ticket=null;throw Error('QR expired. Generate a new code.')}
 const {status,data}=await request(BROKER+'/claim',asJSON({requestId:ticket.requestId,claimSecret:ticket.claimSecret}));
 if(status===202)return {status:'waiting'};
 if(data.status!=='approved'||!data.accessToken||!data.userId||data.expiresAt<Date.now()+10_000)throw Error('Invalid approval');
 currentToken=data.accessToken;expiresAt=data.expiresAt;activeUserId=data.userId;ticket=null;
 return {status:'approved',userId:activeUserId,expiresAt};
});
ipcMain.handle('auth:status',()=>({signedIn:Boolean(currentToken && expiresAt>Date.now()+5000),userId:activeUserId,expiresAt}));
ipcMain.handle('auth:logout',()=>{reset();return true});
const allowedGET=/^\/rest\/v1\/itamar_(profiles|messages|rooms|blocks)(\?.*)?$/;
const allowedPOST=/^\/rest\/v1\/(?:itamar_(profiles|messages|blocks)|rpc\/itamar_(my_rooms_v2|create_room|join_channel|set_mute|ack_messages))$/;
const allowedDELETE=/^\/rest\/v1\/itamar_blocks\?.+$/;
ipcMain.handle('chat:request',async(_event,{method,route,body}={})=>{
 if(!currentToken||expiresAt<=Date.now()+5000){reset();throw Error('Desktop session expired. Pair with your phone again.')}
 if(typeof route!=='string'||route.length>1200||
   !((method==='GET'&&allowedGET.test(route))||
     (method==='POST'&&allowedPOST.test(route))||
     (method==='DELETE'&&allowedDELETE.test(route)))){
  throw Error('Unsupported chat request');
 }
 const headers={'apikey':KEY,'Authorization':'Bearer '+currentToken};
 const opts={method,headers};
 if(method==='POST'){
  headers['Content-Type']='application/json';
  if(route==='/rest/v1/itamar_profiles')headers['Prefer']='resolution=merge-duplicates';
  opts.body=JSON.stringify(body||{});
 }
 const {data}=await request(SUPABASE+route,opts);
 return data;
});
ipcMain.handle('open:help',()=>shell.openExternal('https://itamaros-web-emulator.onrender.com/connect.html'));
function createWindow(){
 windowRef=new BrowserWindow({
  width:1080,height:730,minWidth:660,minHeight:530,
  title:'ItamarOS Connect',
  backgroundColor:'#eaf2fd',
  webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,webSecurity:true}
 });
 windowRef.loadFile(path.join(__dirname,'index.html'));
 windowRef.webContents.setWindowOpenHandler(()=>({action:'deny'}));
 windowRef.webContents.on('will-navigate',event=>event.preventDefault());
}
app.whenReady().then(()=>{
 createWindow();
 app.on('activate',()=>{if(BrowserWindow.getAllWindows().length===0)createWindow()});
});
app.on('window-all-closed',()=>{reset();if(process.platform!=='darwin')app.quit()});

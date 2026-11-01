import http from 'node:http';
import { handleMcp } from './mcp.js';
import { handlePairing } from './pairing.js';

const port=Number(process.env.PORT)||10000;
const catalog=[
{id:'firefox',name:'Firefox',publisher:'Mozilla',officialWebsite:'https://www.mozilla.org/firefox/',installerUrl:null,reviewStatus:'catalog_only'},
{id:'vlc',name:'VLC Media Player',publisher:'VideoLAN',officialWebsite:'https://www.videolan.org/vlc/',installerUrl:null,reviewStatus:'catalog_only'},
{id:'gimp',name:'GIMP',publisher:'GIMP Team',officialWebsite:'https://www.gimp.org/',installerUrl:null,reviewStatus:'catalog_only'},
{id:'blender',name:'Blender',publisher:'Blender Foundation',officialWebsite:'https://www.blender.org/',installerUrl:null,reviewStatus:'catalog_only'},
{id:'obs',name:'OBS Studio',publisher:'OBS Project',officialWebsite:'https://obsproject.com/',installerUrl:null,reviewStatus:'catalog_only'}];

function send(res,status,body){
  res.writeHead(status,{
    'content-type':'application/json; charset=utf-8',
    'access-control-allow-origin':'*',
    'cache-control':'no-store',
    'x-content-type-options':'nosniff'
  });
  res.end(JSON.stringify(body));
}
const allowedOrigins=new Set([
  'https://chatgpt.com',
  'https://chat.openai.com',
  'https://itamaros-store-api.onrender.com'
]);
const server=http.createServer((req,res)=>{
  const path=new URL(req.url||'/', 'http://localhost').pathname;
  if(path.startsWith('/api/connect/pair/')){
    Promise.resolve(handlePairing(req,res,path)).catch(error=>{
      console.error('Pairing request failed:',error?.message||'error');
      if(!res.headersSent)send(res,500,{error:'Pairing unavailable'});
    });
    return;
  }
  if(path==='/mcp'){
    // Read-only public tools. Deny unexpected browser origins.
    if(req.headers.origin && !allowedOrigins.has(req.headers.origin)){
      return send(res,403,{error:'Origin not allowed'});
    }
    Promise.resolve(handleMcp(req,res)).catch(error=>{
      console.error('MCP request failed',error);
      if(!res.headersSent)send(res,500,{error:'MCP request failed'});
      else if(!res.writableEnded)res.end();
    });
    return;
  }
  if(req.method==='GET'&&path==='/health')return send(res,200,{ok:true,service:'ItamarOS Store API',mcp:'/mcp'});
  if(req.method==='GET'&&path==='/api/apps')return send(res,200,{apps:catalog,notice:'Curated official websites only; no executable downloads or scanning yet.'});
  if(req.method==='GET'&&path.startsWith('/api/apps/')){
    const app=catalog.find(a=>a.id===path.slice(10));
    return send(res,app?200:404,app||{error:'Not found'});
  }
  if(req.method==='POST'&&path==='/api/suggestions')return send(res,501,{error:'Suggestions are not accepted until a reviewed, persistent moderation system is configured.'});
  return send(res,404,{error:'Not found'});
});
server.requestTimeout=30000;
server.listen(port,'0.0.0.0',()=>console.log('ItamarOS Store API + MCP listening on '+port));

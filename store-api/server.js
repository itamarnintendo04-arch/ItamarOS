import http from 'node:http';
const port=Number(process.env.PORT)||10000;
const catalog=[
{id:'firefox',name:'Firefox',publisher:'Mozilla',officialWebsite:'https://www.mozilla.org/firefox/',installerUrl:null,reviewStatus:'catalog_only'},
{id:'vlc',name:'VLC Media Player',publisher:'VideoLAN',officialWebsite:'https://www.videolan.org/vlc/',installerUrl:null,reviewStatus:'catalog_only'},
{id:'gimp',name:'GIMP',publisher:'GIMP Team',officialWebsite:'https://www.gimp.org/',installerUrl:null,reviewStatus:'catalog_only'},
{id:'blender',name:'Blender',publisher:'Blender Foundation',officialWebsite:'https://www.blender.org/',installerUrl:null,reviewStatus:'catalog_only'},
{id:'obs',name:'OBS Studio',publisher:'OBS Project',officialWebsite:'https://obsproject.com/',installerUrl:null,reviewStatus:'catalog_only'}];
function send(res,status,body){res.writeHead(status,{'content-type':'application/json; charset=utf-8','access-control-allow-origin':'*','cache-control':'no-store','x-content-type-options':'nosniff'});res.end(JSON.stringify(body))}
const server=http.createServer((req,res)=>{const path=new URL(req.url,'http://localhost').pathname;if(req.method==='GET'&&path==='/health')return send(res,200,{ok:true,service:'ItamarOS Store API'});if(req.method==='GET'&&path==='/api/apps')return send(res,200,{apps:catalog,notice:'Curated official websites only; no executable downloads or scanning yet.'});if(req.method==='GET'&&path.startsWith('/api/apps/')){const app=catalog.find(a=>a.id===path.slice(10));return send(res,app?200:404,app||{error:'Not found'})}if(req.method==='POST'&&path==='/api/suggestions')return send(res,501,{error:'Suggestions are not accepted until a reviewed, persistent moderation system is configured.'});return send(res,404,{error:'Not found'})});
server.listen(port,'0.0.0.0',()=>console.log('ItamarOS Store API listening on '+port));
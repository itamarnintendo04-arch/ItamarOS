import { createServer } from 'node:http';
import { createMcpHandler, McpServer } from '@modelcontextprotocol/server';
import { toNodeHandler } from '@modelcontextprotocol/node';
import * as z from 'zod/v4';

const REPO='itamarnintendo04-arch/ItamarOS';
const WEB='https://github.com/'+REPO;
const API='https://api.github.com/repos/'+REPO;
const PORT=Number(process.env.PORT||3000);
const MAX_BODY=64*1024;
async function getPublicGitHub(path){
  const controller=new AbortController();
  const timeout=setTimeout(()=>controller.abort(),7000);
  try{
    const response=await fetch(API+path,{headers:{
      Accept:'application/vnd.github+json',
      'User-Agent':'ItamarOS-ChatGPT-MCP/0.1.0'
    },signal:controller.signal});
    if(!response.ok)throw new Error('GitHub unavailable (HTTP '+response.status+')');
    return response.json();
  }finally{clearTimeout(timeout)}
}
function output(body){return {content:[{type:'text',text:JSON.stringify(body)}]}}
const factory=()=>{
  const server=new McpServer({name:'ItamarOS',version:'0.1.0'},
                             {capabilities:{tools:{}}});
  server.registerTool('itamaros_about',{
    description:'Read-only information about the public ItamarOS GitHub repository and its supported applications. No private account data.',
    inputSchema:z.object({})
  },async()=>output({
    name:'ItamarOS',
    repository:WEB,
    downloads:WEB+'/blob/main/downloads.html',
    components:['Emulator','ItamarConnect','ItamarMirror','ItamarPhone','ItamarOS Games','Native app prototypes'],
    caution:'Prototype source is not a certified full operating system. AirPlay/Google Cast media sending differs from full-screen mirroring.'
  }));
  server.registerTool('itamaros_latest_releases',{
    description:'List recent public GitHub releases of ItamarOS, without claiming an unverified binary exists.',
    inputSchema:z.object({limit:z.number().int().min(1).max(10).default(5)})
  },async({limit})=>{
    try{
      const releases=await getPublicGitHub('/releases?per_page='+limit);
      return output(releases.slice(0,limit).map(item=>({
        tag:item.tag_name,title:item.name,created:item.published_at,
        page:item.html_url,prerelease:item.prerelease,
        assets:(item.assets||[]).map(asset=>({
          name:asset.name,url:asset.browser_download_url,size:asset.size
        }))
      })));
    }catch(e){return output({error:String(e.message),repository:WEB+'/releases'})}
  });
  server.registerTool('itamaros_builds',{
    description:'Read the status of recent public GitHub Actions native Android/iOS validation runs, without guaranteeing installability.',
    inputSchema:z.object({limit:z.number().int().min(1).max(10).default(5)})
  },async({limit})=>{
    try{
      const data=await getPublicGitHub('/actions/runs?per_page=25');
      return output((data.workflow_runs||[]).slice(0,limit).map(run=>({
        name:run.name,status:run.status,conclusion:run.conclusion,
        url:run.html_url,created_at:run.created_at
      })));
    }catch(e){return output({error:String(e.message),repository:WEB+'/actions'})}
  });
  return server;
};
const mcp=createMcpHandler(factory);
const handleMcp=toNodeHandler(mcp);
const server=createServer(async(req,res)=>{
  const pathname=new URL(req.url||'/', 'http://localhost').pathname;
  if(pathname==='/health'){
    res.writeHead(200,{'Content-Type':'application/json','Cache-Control':'no-store'});
    res.end(JSON.stringify({status:'ok',service:'itamaros-readonly-mcp'}));return;
  }
  if(pathname==='/mcp'){
    // MCP endpoints are read only and contain no user credentials or secrets.
    await handleMcp(req,res);return;
  }
  res.writeHead(404,{'Content-Type':'application/json'});
  res.end(JSON.stringify({error:'Not found'}));
});
server.requestTimeout=30000;
server.listen(PORT,'0.0.0.0',()=>console.log('ItamarOS MCP listening on '+PORT));

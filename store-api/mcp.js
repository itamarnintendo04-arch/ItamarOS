import {createMcpHandler,McpServer} from '@modelcontextprotocol/server';
import {toNodeHandler} from '@modelcontextprotocol/node';
import * as z from 'zod/v4';

const REPO='itamarnintendo04-arch/ItamarOS';
const WEB='https://github.com/'+REPO;
const API='https://api.github.com/repos/'+REPO;
async function getPublicGitHub(path){
  const response=await fetch(API+path,{
    headers:{Accept:'application/vnd.github+json','User-Agent':'ItamarOS-ChatGPT-MCP/0.2'},
    signal:AbortSignal.timeout(7000)
  });
  if(!response.ok)throw new Error('GitHub unavailable (HTTP '+response.status+')');
  return response.json();
}
const output=(body)=>({content:[{type:'text',text:JSON.stringify(body)}]});
const handler=createMcpHandler(()=>{
  const server=new McpServer({name:'ItamarOS',version:'0.2.0'},{capabilities:{tools:{}}});
  server.registerTool('itamaros_about',{
    description:'Read-only public information about ItamarOS and its project components.',
    inputSchema:z.object({})
  },async()=>output({
    name:'ItamarOS',repository:WEB,downloads:WEB+'/blob/main/downloads.html',
    components:['ItamarOS Emulator','ItamarConnect','ItamarMirror','ItamarPhone','ItamarOS Games','Native prototypes'],
    status:'Prototype software, not a certified replacement operating system.'
  }));
  server.registerTool('itamaros_latest_releases',{
    description:'Find the latest publicly downloadable ItamarOS GitHub release assets for Android, iOS and desktop. Does not imply files are safe, signed or installable.',
    inputSchema:z.object({limit:z.number().int().min(1).max(10).default(5)})
  },async({limit})=>{
    try{
      const releases=await getPublicGitHub('/releases?per_page='+limit);
      return output(releases.slice(0,limit).map(item=>({
        tag:item.tag_name,title:item.name,published:item.published_at,
        page:item.html_url,prerelease:item.prerelease,
        assets:(item.assets||[]).map(asset=>({
          name:asset.name,url:asset.browser_download_url,size:asset.size
        }))
      })));
    }catch(e){return output({error:String(e.message),releases:WEB+'/releases'});}
  });
  server.registerTool('itamaros_builds',{
    description:'Read GitHub Actions build and validation status. Successful validation does not guarantee a usable app.',
    inputSchema:z.object({limit:z.number().int().min(1).max(10).default(5)})
  },async({limit})=>{
    try{
      const data=await getPublicGitHub('/actions/runs?per_page=25');
      return output((data.workflow_runs||[]).slice(0,limit).map(run=>({
        name:run.name,status:run.status,conclusion:run.conclusion,
        url:run.html_url,created_at:run.created_at
      })));
    }catch(e){return output({error:String(e.message),actions:WEB+'/actions'});}
  });
  return server;
});
export const handleMcp=toNodeHandler(handler);

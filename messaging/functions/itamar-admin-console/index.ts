// Administrative invitation generator. NEVER grants rights by email string or static PIN.
// Requires verified signed-in user with operator-assigned app_metadata.itamaros_admin === true.
import {createClient} from "npm:@supabase/supabase-js@2.118.0";
const apiUrl=Deno.env.get("SUPABASE_URL") || "";
const publicKey=Deno.env.get("SUPABASE_ANON_KEY") || "";
const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const allowedOrigins=new Set(["https://itamaros-web-emulator.onrender.com"]);
const json=(data:unknown,status=200,origin="")=>new Response(JSON.stringify(data),{
 status,headers:{"content-type":"application/json","cache-control":"no-store",
 ...(allowedOrigins.has(origin)?{"access-control-allow-origin":origin,"vary":"Origin"}:{})}
});
Deno.serve(async (req:Request)=>{
 const origin=req.headers.get("Origin")||"";
 if(req.method==="OPTIONS"){
  if(!allowedOrigins.has(origin))return new Response(null,{status:403});
  return new Response(null,{headers:{"access-control-allow-origin":origin,
   "access-control-allow-headers":"authorization,apikey,content-type",
   "access-control-allow-methods":"POST,OPTIONS","vary":"Origin"}});
 }
 if(req.method!=="POST")return json({error:"Method not allowed"},405,origin);
 if(origin && !allowedOrigins.has(origin))return json({error:"Origin not allowed"},403,origin);
 if(!apiUrl||!publicKey||!serviceKey)return json({error:"Service not configured"},503,origin);
 const authorization=req.headers.get("Authorization")||"";
 if(!authorization.startsWith("Bearer ") || authorization.length>6000)
  return json({error:"Sign in required"},401,origin);
 const token=authorization.slice(7);
 const verifier=createClient(apiUrl,publicKey,{auth:{persistSession:false}});
 const {data:auth,error:authError}=await verifier.auth.getUser(token);
 const user=auth?.user;
 if(authError || !user || !user.email_confirmed_at ||
    user.app_metadata?.itamaros_admin !== true) {
  return json({error:"Administrator authorization required"},403,origin);
 }
 let input:Record<string,unknown>;
 try{input=await req.json()}catch{return json({error:"Invalid JSON"},400,origin)}
 const manager=createClient(apiUrl,serviceKey,{auth:{persistSession:false}});
 const action=input.action;
 if(action==="list"){
  const page=Number(input.page)||1;
  if(!Number.isInteger(page)||page<1||page>100)return json({error:"Invalid page"},400,origin);
  const {data,error}=await manager.auth.admin.listUsers({page,perPage:50});
  if(error)return json({error:"Could not list accounts"},500,origin);
  return json({users:(data?.users||[]).map(u=>({
   id:u.id,email:u.email||"",confirmed:Boolean(u.email_confirmed_at),
   created_at:u.created_at
  })),page},200,origin);
 }
 if(action==="invite"){
  const email=String(input.email||"").trim().toLowerCase();
  if(email.length>254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))
   return json({error:"Invalid email"},400,origin);
  // No email is sent automatically. The administrator must copy the generated link.
  // The recipient must control the mailbox to redeem the provider-issued, expiring link.
  const {data,error}=await manager.auth.admin.generateLink({
   type:"invite",email,
   options:{redirectTo:"https://itamaros-web-emulator.onrender.com/accept-invite.html"}
  });
  if(error || !data?.properties?.action_link){
   return json({error:error?.message||"Could not generate invitation"},400,origin);
  }
  return json({email,invite_link:data.properties.action_link,
   note:"Send privately to the invited email address only. The link is one-time and expiring."},200,origin);
 }
 return json({error:"Unknown operation"},400,origin);
});
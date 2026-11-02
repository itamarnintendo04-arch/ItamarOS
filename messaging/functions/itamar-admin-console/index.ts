// Server-side administration. No client-controlled badges, roles or password access.
import {createClient} from "npm:@supabase/supabase-js@2.118.0";
const apiUrl=Deno.env.get("SUPABASE_URL")||"";
const publicKey=Deno.env.get("SUPABASE_ANON_KEY")||"";
const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";
const allowedOrigins=new Set(["https://itamaros-web-emulator.onrender.com"]);
const json=(data:unknown,status=200,origin="")=>new Response(JSON.stringify(data),{
 status,headers:{"content-type":"application/json","cache-control":"no-store",
 ...(allowedOrigins.has(origin)?{"access-control-allow-origin":origin,"vary":"Origin"}:{})}
});
const uuid=(value:unknown)=>typeof value==="string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
const avatar=(path:unknown)=>typeof path==="string" &&
 /^profiles\/[0-9a-f-]{36}\/[0-9a-f-]{36}\.(?:jpg|png|webp)$/i.test(path)
 ?apiUrl+"/storage/v1/object/public/itamar-connect-avatars/"+path:null;
Deno.serve(async(req:Request)=>{
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
 if(!authorization.startsWith("Bearer ")||authorization.length>6000)
  return json({error:"Sign in required"},401,origin);
 const token=authorization.slice(7);
 const verifier=createClient(apiUrl,publicKey,{auth:{persistSession:false}});
 const {data:auth,error:authError}=await verifier.auth.getUser(token);
 const user=auth?.user;
 if(authError||!user||!user.email_confirmed_at||
    user.app_metadata?.itamaros_admin!==true)
  return json({error:"Administrator authorization required"},403,origin);
 const manager=createClient(apiUrl,serviceKey,{auth:{persistSession:false}});
 let input:Record<string,unknown>;
 try{input=await req.json()}catch{return json({error:"Invalid JSON"},400,origin)}
 const action=input.action;
 if(action==="list"){
  const page=Number(input.page)||1;
  if(!Number.isInteger(page)||page<1||page>100)
   return json({error:"Invalid page"},400,origin);
  const {data,error}=await manager.auth.admin.listUsers({page,perPage:50});
  if(error)return json({error:"Could not list accounts"},500,origin);
  const users=data?.users||[];
  const ids=users.map(u=>u.id);
  const [profiles,badges]=await Promise.all([
   ids.length?manager.from("itamar_profiles").select("id,username,display_name,avatar_path").in("id",ids):{data:[]},
   ids.length?manager.from("itamar_profile_badges").select("user_id,badge").in("user_id",ids):{data:[]}
  ]);
  if(profiles.error||badges.error)return json({error:"Could not load profile data"},500,origin);
  const profileMap=new Map((profiles.data||[]).map(p=>[p.id,p]));
  const badgeMap=new Map((badges.data||[]).map(b=>[b.user_id,b.badge]));
  return json({users:users.map(u=>({
   id:u.id,
   email:u.email||"",
   confirmed:Boolean(u.email_confirmed_at),
   display_name:profileMap.get(u.id)?.display_name||"",
   username:profileMap.get(u.id)?.username||"",
   avatar_url:avatar(profileMap.get(u.id)?.avatar_path),
   badge:badgeMap.get(u.id)||null,
   created_at:u.created_at
  })),page,has_more:users.length===50},200,origin);
 }
 if(action==="invite"){
  const email=String(input.email||"").trim().toLowerCase();
  if(email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))
   return json({error:"Invalid email"},400,origin);
  const {data,error}=await manager.auth.admin.generateLink({
   type:"invite",email,
   options:{redirectTo:"https://itamaros-web-emulator.onrender.com/accept-invite.html"}
  });
  if(error||!data?.properties?.action_link)
   return json({error:error?.message||"Could not generate invitation"},400,origin);
  await manager.from("itamar_admin_audit").insert({actor_id:user.id,action:"invite_generated"});
  return json({email,invite_link:data.properties.action_link,
   note:"Send privately to the invited email address. Password is chosen by its recipient."},200,origin);
 }
 if(action==="set_badge"){
  if(!uuid(input.target_id))return json({error:"Invalid user ID"},400,origin);
  const target=String(input.target_id);
  if(target===user.id)return json({error:"You cannot change your own administrator badge"},403,origin);
  if(input.badge!=="blue"&&input.badge!==null)
   return json({error:"Administrators may only award/remove blue verification"},400,origin);
  const {data:targetData,error:targetError}=await manager.auth.admin.getUserById(target);
  if(targetError||!targetData?.user||!targetData.user.email_confirmed_at)
   return json({error:"Recipient must have a confirmed account"},400,origin);
  if(targetData.user.app_metadata?.itamaros_admin===true)
   return json({error:"Cannot modify another administrator's badge"},403,origin);
  const {data:existing,error:existingError}=await manager.from("itamar_profile_badges")
   .select("badge").eq("user_id",target).maybeSingle();
  if(existingError)return json({error:"Badge lookup failed"},500,origin);
  if(existing?.badge==="green")return json({error:"Green badge is protected"},403,origin);
  if(input.badge==="blue"){
   const {error}=await manager.from("itamar_profile_badges").upsert({
    user_id:target,badge:"blue",awarded_by:user.id,awarded_at:new Date().toISOString()
   },{onConflict:"user_id"});
   if(error)return json({error:"Could not award verification"},500,origin);
  }else{
   const {error}=await manager.from("itamar_profile_badges").delete()
    .eq("user_id",target).eq("badge","blue");
   if(error)return json({error:"Could not remove verification"},500,origin);
  }
  await manager.from("itamar_admin_audit").insert({
   actor_id:user.id,target_id:target,action:input.badge==="blue"?"badge_blue_awarded":"badge_blue_removed"
  });
  return json({ok:true,badge:input.badge},200,origin);
 }
 if(action==="send_notice"){
  if(!uuid(input.target_id))return json({error:"Invalid user ID"},400,origin);
  const target=String(input.target_id);
  const body=String(input.body||"").trim();
  if(body.length<1||body.length>1500)return json({error:"Message must contain 1–1500 characters"},400,origin);
  const {data:recipient,error:recipientError}=await manager.auth.admin.getUserById(target);
  if(recipientError||!recipient?.user)return json({error:"Recipient does not exist"},404,origin);
  const recent=await manager.from("itamar_admin_notices").select("id",{count:"exact",head:true})
   .eq("sender_id",user.id).gte("created_at",new Date(Date.now()-60*60*1000).toISOString());
  if(recent.error)return json({error:"Rate-limit lookup failed"},500,origin);
  if((recent.count||0)>=50)return json({error:"Hourly message limit reached"},429,origin);
  const {error}=await manager.from("itamar_admin_notices").insert({
   sender_id:user.id,recipient_id:target,body
  });
  if(error)return json({error:"Could not deliver in-app message"},500,origin);
  await manager.from("itamar_admin_audit").insert({actor_id:user.id,target_id:target,action:"official_message_sent"});
  return json({ok:true,info:"In-app message saved for the user's official inbox"},200,origin);
 }
 return json({error:"Unknown operation"},400,origin);
});
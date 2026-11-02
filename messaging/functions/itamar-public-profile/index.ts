// Read-only public profile lookup by stable UUID. Never returns email, phone, password or private messages.
import {createClient} from "npm:@supabase/supabase-js@2.118.0";
const apiUrl=Deno.env.get("SUPABASE_URL")||"";
const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";
const origins=new Set(["https://itamaros-web-emulator.onrender.com"]);
const json=(data:unknown,status=200,origin="")=>new Response(JSON.stringify(data),{status,headers:{
 "content-type":"application/json","cache-control":"public, max-age=60",
 ...(origins.has(origin)?{"access-control-allow-origin":origin,"vary":"Origin"}:{})
}});
Deno.serve(async(req:Request)=>{
 const origin=req.headers.get("Origin")||"";
 if(req.method==="OPTIONS"){
  if(!origins.has(origin))return new Response(null,{status:403});
  return new Response(null,{headers:{"access-control-allow-origin":origin,
    "access-control-allow-headers":"apikey,authorization,content-type",
    "access-control-allow-methods":"GET,OPTIONS","vary":"Origin"}});
 }
 if(req.method!=="GET")return json({error:"Use GET"},405,origin);
 if(origin && !origins.has(origin))return json({error:"Origin not allowed"},403,origin);
 if(!apiUrl||!serviceKey)return json({error:"Unavailable"},503,origin);
 const url=new URL(req.url);
 const id=url.searchParams.get("id")||"";
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id))
  return json({error:"Enter a valid profile ID"},400,origin);
 const manager=createClient(apiUrl,serviceKey,{auth:{persistSession:false}});
 const [{data:profile,error:profileError},{data:badge,error:badgeError}]=await Promise.all([
  manager.from("itamar_profiles").select("id,username,display_name,about,avatar_path").eq("id",id).maybeSingle(),
  manager.from("itamar_profile_badges").select("badge").eq("user_id",id).maybeSingle()
 ]);
 if(profileError||badgeError)return json({error:"Profile unavailable"},500,origin);
 const user=await manager.auth.admin.getUserById(id);
 if(user.error||!user.data.user)return json({error:"Profile not found"},404,origin);
 const avatarPath=profile?.avatar_path||"";
 const safeAvatar=/^profiles\/[0-9a-f-]{36}\/[0-9a-f-]{36}\.(jpg|png|webp)$/i.test(avatarPath);
 const publicName=profile?.display_name?.trim()||"ItamarOS member";
 return json({
  id,
  username:profile?.username||"user_"+id.split("-")[0],
  display_name:publicName,
  about:(profile?.about||"").slice(0,160),
  avatar_url:safeAvatar?apiUrl+"/storage/v1/object/public/itamar-connect-avatars/"+avatarPath:null,
  badge:badge?.badge||null,
  profile_url:"https://itamaros-web-emulator.onrender.com/profile.html?id="+id
 },200,origin);
});
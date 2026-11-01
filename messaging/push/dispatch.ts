// ItamarOS push dispatcher for Supabase Edge Functions (Deno).
// IMPORTANT: this does NOT deliver until APNs/FCM + dispatch credentials are installed
// as Edge Function environment secrets and an authenticated scheduler is configured.
// No message content, account identifiers or device token is logged.
type Device={id:string;user_id:string;device_id:string;provider:"apns"|"fcm";token:string};
type Event={id:string;recipient_id:string;room_id:string;title:string;body:string;attempts:number};
const env=(key:string)=>Deno.env.get(key)?.trim()||"";
const secret=()=>env("ITAMAR_PUSH_DISPATCH_SECRET");
const encode=(data:Uint8Array):string=>{
 let binary="";for(const byte of data)binary+=String.fromCharCode(byte);
 return btoa(binary).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"");
};
const utf=(s:string)=>new TextEncoder().encode(s);
const b64=(s:string)=>encode(utf(s));
const pkcs8=(pem:string)=>{
 const raw=atob(pem.replace(/-----BEGIN [^-]+-----/g,"")
                    .replace(/-----END [^-]+-----/g,"").replace(/\s+/g,""));
 return Uint8Array.from(raw,c=>c.charCodeAt(0));
};
async function signedJwt(header:object,payload:object,algorithm:"ES256"|"RS256",keyPem:string){
 const segments=b64(JSON.stringify(header))+"."+b64(JSON.stringify(payload));
 const key=await crypto.subtle.importKey("pkcs8",pkcs8(keyPem),
   algorithm==="ES256"?{name:"ECDSA",namedCurve:"P-256"}:
     {name:"RSASSA-PKCS1-v1_5",hash:"SHA-256"},false,["sign"]);
 const signature=await crypto.subtle.sign(algorithm==="ES256"?{name:"ECDSA",hash:"SHA-256"}:
   {name:"RSASSA-PKCS1-v1_5"},key,utf(segments));
 return segments+"."+encode(new Uint8Array(signature));
}
async function apns(device:Device,event:Event){
 const now=Math.floor(Date.now()/1000);
 const jwt=await signedJwt({alg:"ES256",kid:env("APNS_KEY_ID")},
   {iss:env("APNS_TEAM_ID"),iat:now},"ES256",env("APNS_PRIVATE_KEY_P8").replace(/\\n/g,"\n"));
 const api=env("APNS_ENVIRONMENT")==="production"?"https://api.push.apple.com":"https://api.sandbox.push.apple.com";
 const answer=await fetch(api+"/3/device/"+device.token,{
   method:"POST",
   headers:{"authorization":"bearer "+jwt,"apns-topic":env("APNS_BUNDLE_ID"),
      "apns-push-type":"alert","apns-priority":"10",
      "content-type":"application/json"},
   body:JSON.stringify({aps:{alert:{title:event.title,body:event.body},sound:"default"},
     room:event.room_id,type:"itamaros-message"})
 });
 if(!answer.ok)throw Error("APNs HTTP "+answer.status);
}
async function googleAccessToken(){
 const now=Math.floor(Date.now()/1000);
 const assertion=await signedJwt({alg:"RS256",typ:"JWT"},
   {iss:env("FIREBASE_CLIENT_EMAIL"),scope:"https://www.googleapis.com/auth/firebase.messaging",
    aud:"https://oauth2.googleapis.com/token",iat:now,exp:now+3600},
   "RS256",env("FIREBASE_PRIVATE_KEY").replace(/\\n/g,"\n"));
 const result=await fetch("https://oauth2.googleapis.com/token",{
   method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},
   body:new URLSearchParams({grant_type:"urn:ietf:params:oauth:grant-type:jwt-bearer",assertion})
 });
 if(!result.ok)throw Error("Firebase OAuth HTTP "+result.status);
 const response=await result.json();
 if(typeof response.access_token!=="string")throw Error("Firebase OAuth did not issue access token");
 return response.access_token as string;
}
async function fcm(device:Device,event:Event){
 const token=await googleAccessToken();
 const result=await fetch("https://fcm.googleapis.com/v1/projects/"+
   encodeURIComponent(env("FIREBASE_PROJECT_ID"))+"/messages:send",{
   method:"POST",headers:{"authorization":"Bearer "+token,"content-type":"application/json"},
   body:JSON.stringify({message:{token:device.token,
     notification:{title:event.title,body:event.body},
     data:{room:event.room_id,type:"itamaros-message"},
     android:{priority:"high"}}})
 });
 if(!result.ok)throw Error("FCM HTTP "+result.status);
}
function credentialsReady(){
 return Boolean(env("SUPABASE_URL") &&
    (env("SUPABASE_SERVICE_ROLE_KEY")||env("SUPABASE_SECRET_KEYS")) &&
    secret() && env("APNS_TEAM_ID") && env("APNS_KEY_ID") &&
    env("APNS_PRIVATE_KEY_P8") && env("APNS_BUNDLE_ID") &&
    env("FIREBASE_PROJECT_ID") && env("FIREBASE_CLIENT_EMAIL") && env("FIREBASE_PRIVATE_KEY"));
}
function serviceKey(){
 const value=env("SUPABASE_SERVICE_ROLE_KEY");
 if(value)return value;
 try {
   const keys=JSON.parse(env("SUPABASE_SECRET_KEYS"));
   return typeof keys.default==="string"?keys.default:"";
 }catch{return ""}
}
async function dbGet<T>(path:string):Promise<T>{
 const key=serviceKey();
 const response=await fetch(env("SUPABASE_URL")+"/rest/v1/"+path,
   {headers:{apikey:key,authorization:"Bearer "+key}});
 if(!response.ok)throw Error("Database HTTP "+response.status);
 return response.json() as Promise<T>;
}
async function dbUpdate(id:string,values:object){
 const key=serviceKey();
 const response=await fetch(env("SUPABASE_URL")+"/rest/v1/itamar_push_outbox?id=eq."+
    encodeURIComponent(id),{
    method:"PATCH",headers:{apikey:key,authorization:"Bearer "+key,
        "content-type":"application/json","prefer":"return=minimal"},body:JSON.stringify(values)
  });
 if(!response.ok)throw Error("Database update HTTP "+response.status);
}
Deno.serve(async request=>{
 if(request.method!=="POST")return new Response("Method not allowed",{status:405});
 // Do not allow anyone to trigger pushes if credentials or the dispatch secret are missing.
 if(!credentialsReady())return new Response("Push credentials not configured",{status:503});
 if(request.headers.get("x-itamar-dispatch-secret")!==secret())
    return new Response("Unauthorized",{status:401});
 try{
   const events=await dbGet<Event[]>(
     "itamar_push_outbox?status=eq.pending&order=created_at.asc&limit=15"+
     "&select=id,recipient_id,room_id,title,body,attempts");
   let success=0,failed=0;
   for(const e of events){
     const devices=await dbGet<Device[]>("itamar_push_devices?user_id=eq."+
       encodeURIComponent(e.recipient_id)+"&enabled=eq.true&select=id,user_id,device_id,provider,token");
     if(devices.length===0){
       await dbUpdate(e.id,{status:"failed",last_error:"No opted-in devices",attempts:e.attempts+1});
       failed++;
       continue;
     }
     let sent=0;let lastError="";
     for(const device of devices){
       try{
         if(device.provider==="apns")await apns(device,e);
         else if(device.provider==="fcm")await fcm(device,e);
         sent++;
       }catch(ex){
         lastError=ex instanceof Error ? ex.message.slice(0,140) : "Push transport error";
       }
     }
     await dbUpdate(e.id,{
       status:sent>0?"sent":(e.attempts>=4?"failed":"pending"),
       attempts:e.attempts+1,processed_at:sent>0?new Date().toISOString():null,
       last_error:sent>0?null:(lastError||"No successful target")
     });
     if(sent>0)success++;else failed++;
   }
   return Response.json({processed:events.length,success,failed});
 }catch(error){
   return Response.json({error:error instanceof Error?error.message:"Dispatch failed"},{status:500});
 }
});

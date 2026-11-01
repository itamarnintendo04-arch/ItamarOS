import { randomBytes, timingSafeEqual } from 'node:crypto';

const SUPABASE_URL='https://slqjkysinhfkqjoigfuz.supabase.co';
// Public/publishable client key, never a service-role or Twilio secret.
const PUBLIC_KEY='sb_publishable__WVo13dRVkDYChuGxHxk9A_CDoVR9ts';
const APPROVAL_ORIGIN='https://itamaros-web-emulator.onrender.com';
const REQUEST_TTL=180_000;
const pending=new Map();
const starts=new Map();
const encode=(bytes)=>randomBytes(bytes).toString('base64url');
const json=(res,status,body,origin)=>{
 const headers={
  'content-type':'application/json; charset=utf-8',
  'cache-control':'no-store, private',
  'x-content-type-options':'nosniff',
  'referrer-policy':'no-referrer',
  'vary':'Origin'
 };
 if(origin===APPROVAL_ORIGIN){
   headers['access-control-allow-origin']=APPROVAL_ORIGIN;
   headers['access-control-allow-methods']='POST, OPTIONS';
   headers['access-control-allow-headers']='Content-Type, Authorization';
 }
 res.writeHead(status,headers);
 res.end(JSON.stringify(body));
};
function clean(){
 const now=Date.now();
 for(const [id,entry] of pending){if(entry.expires<now)pending.delete(id)}
 for(const [id,times] of starts){if(now-times.start>60_000)starts.delete(id)}
}
function parseBody(req){
 return new Promise((resolve,reject)=>{
  const parts=[];let bytes=0;
  req.on('data',part=>{
    bytes+=part.length;
    if(bytes>4096){reject(new Error('Request too large'));req.destroy();return}
    parts.push(part);
  });
  req.on('end',()=>{try{resolve(JSON.parse(Buffer.concat(parts).toString('utf8')))}catch{reject(new Error('Invalid JSON'))}});
  req.on('error',reject);
 });
}
function sameSecret(provided,expected){
 if(typeof provided!=='string'||provided.length!==expected.length)return false;
 const a=Buffer.from(provided);const b=Buffer.from(expected);
 return a.length===b.length && timingSafeEqual(a,b);
}
async function verifiedIdentity(accessToken){
 if(typeof accessToken!=='string'||accessToken.length<30||accessToken.length>4096) return null;
 const result=await fetch(SUPABASE_URL+'/auth/v1/user',{
  headers:{'Authorization':'Bearer '+accessToken,'apikey':PUBLIC_KEY},
  signal:AbortSignal.timeout(8000)
 });
 if(!result.ok)return null;
 const person=await result.json();
 if(!person.id||!(person.phone_confirmed_at||person.email_confirmed_at))return null;
 return person;
}
export async function handlePairing(req,res,path){
 const origin=req.headers.origin;
 if(origin && origin!==APPROVAL_ORIGIN)return json(res,403,{error:'Origin not allowed'});
 if(req.method==='OPTIONS')return json(res,204,{},origin);
 if(req.method!=='POST')return json(res,405,{error:'Use POST'},origin);
 clean();
 let body;
 try{body=await parseBody(req)}catch{return json(res,400,{error:'Invalid request'},origin)}
 if(path==='/api/connect/pair/start'){
  if(pending.size>=500)return json(res,429,{error:'Pairing is busy'},origin);
  const ip=(req.headers['x-forwarded-for']||req.socket.remoteAddress||'unknown').toString().split(',')[0].trim().slice(0,70);
  const rate=starts.get(ip);
  if(rate && rate.count>=20)return json(res,429,{error:'Too many requests'},origin);
  starts.set(ip,rate?{start:rate.start,count:rate.count+1}:{start:Date.now(),count:1});
  const id=encode(20),secret=encode(32),expires=Date.now()+REQUEST_TTL;
  pending.set(id,{secret,expires,status:'pending',token:null,exp:null,account:null,attempts:0});
  return json(res,200,{requestId:id,claimSecret:secret,expiresAt:expires,
    approveUrl:APPROVAL_ORIGIN+'/connect-approve.html#request='+encodeURIComponent(id)},origin);
 }
 if(path==='/api/connect/pair/approve'){
  const item=pending.get(body.requestId);
  if(!item||item.status!=='pending')return json(res,404,{error:'Request expired or already approved'},origin);
  const authorization=req.headers.authorization||'';
  const jwt=authorization.startsWith('Bearer ')?authorization.slice(7):'';
  let person=null;
  try{person=await verifiedIdentity(jwt)}catch{return json(res,503,{error:'Authentication provider unavailable'},origin)}
  if(!person)return json(res,401,{error:'An existing verified ItamarOS account session is required'},origin);
  const raw=jwt.split('.')[1];
  let expires=Date.now()+45*60_000;
  try{const payload=JSON.parse(Buffer.from(raw,'base64url').toString());if(Number.isFinite(payload.exp))expires=Math.min(expires,payload.exp*1000)}catch{}
  if(expires<=Date.now()+30_000)return json(res,401,{error:'Session nearly expired; reopen Connect on your phone'},origin);
  item.token=jwt;item.exp=expires;item.account=person.id;item.status='approved';
  return json(res,200,{approved:true},origin);
 }
 if(path==='/api/connect/pair/claim'){
  const item=pending.get(body.requestId);
  if(!item)return json(res,410,{error:'Pairing expired; generate a new QR'},origin);
  item.attempts++;
  if(item.attempts>120){pending.delete(body.requestId);return json(res,429,{error:'Too many attempts'},origin)}
  if(!sameSecret(body.claimSecret,item.secret))return json(res,403,{error:'Invalid pairing secret'},origin);
  if(item.status!=='approved')return json(res,202,{status:'waiting'},origin);
  pending.delete(body.requestId);
  return json(res,200,{status:'approved',accessToken:item.token,expiresAt:item.exp,userId:item.account},origin);
 }
 return json(res,404,{error:'Not found'},origin);
}

import http from 'node:http';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import path from 'node:path';
const root=process.cwd(),dataDir=process.env.DATA_DIR||'data'; await fs.mkdir(dataDir,{recursive:true});
let users=JSON.parse(await fs.readFile(path.join(dataDir,'users.json'),'utf8').catch(()=>'{}'));
const oauthStates=new Map();
const sessions=new Map(); let writes=Promise.resolve();
function persist(){writes=writes.then(()=>fs.writeFile(path.join(dataDir,'users.json'),JSON.stringify(users)));return writes;}
const hash=(p,s)=>crypto.scryptSync(p,s,64).toString('hex');
const reply=(res,status,obj)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(obj));};
http.createServer(async(req,res)=>{try{
const url=new URL(req.url,'http://localhost');
if(url.pathname==='/auth/google'){
if(!process.env.GOOGLE_CLIENT_ID||!process.env.GOOGLE_CLIENT_SECRET){res.writeHead(302,{Location:'/?auth=unconfigured'});return res.end();}
const state=crypto.randomBytes(24).toString('hex');oauthStates.set(state,Date.now());
const target=new URL('https://accounts.google.com/o/oauth2/v2/auth');target.search=new URLSearchParams({client_id:process.env.GOOGLE_CLIENT_ID,redirect_uri:process.env.PUBLIC_URL+'/auth/google/callback',response_type:'code',scope:'openid email',state}).toString();res.writeHead(302,{Location:target.toString(),'Set-Cookie':`oauth=${state}; HttpOnly; SameSite=Lax; Path=/; Max-Age=600`});return res.end();}
if(url.pathname==='/auth/google/callback'){
const state=url.searchParams.get('state'), cookie=(req.headers.cookie||'').match(/oauth=([a-f0-9]+)/)?.[1];
if(!state||state!==cookie||!oauthStates.has(state)||Date.now()-oauthStates.get(state)>600000)return reply(res,400,{error:'Expired sign-in attempt.'});oauthStates.delete(state);
const tokenResponse=await fetch('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({code:url.searchParams.get('code'),client_id:process.env.GOOGLE_CLIENT_ID,client_secret:process.env.GOOGLE_CLIENT_SECRET,redirect_uri:process.env.PUBLIC_URL+'/auth/google/callback',grant_type:'authorization_code'})});
const tokens=await tokenResponse.json();if(!tokenResponse.ok)return reply(res,401,{error:'Google sign-in failed.'});
const profileResponse=await fetch('https://openidconnect.googleapis.com/v1/userinfo',{headers:{Authorization:'Bearer '+tokens.access_token}});const profile=await profileResponse.json();if(!profileResponse.ok||!profile.email_verified)return reply(res,401,{error:'A verified Google email is required.'});
const e=profile.email.toLowerCase();if(!users[e]){users[e]={google:profile.sub,state:null};await persist();}
const t=crypto.randomBytes(32).toString('hex');sessions.set(t,e);res.writeHead(302,{Location:'/', 'Set-Cookie':`session=${t}; HttpOnly; SameSite=Strict; Path=/${process.env.NODE_ENV==='production'?'; Secure':''}`});return res.end();}
if(url.pathname.startsWith('/api/')){
let raw=''; for await(const chunk of req){raw+=chunk;if(raw.length>2000000){reply(res,413,{error:'Request too large'});return;}}
const body=raw?JSON.parse(raw):{};const token=(req.headers.cookie||'').match(/session=([a-f0-9]+)/)?.[1];const email=sessions.get(token);
if(url.pathname==='/api/register'||url.pathname==='/api/login'){
const e=String(body.email||'').trim().toLowerCase(), p=String(body.password||'');
if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)||p.length<8)return reply(res,400,{error:'Enter a valid email and a password of at least 8 characters.'});
if(url.pathname==='/api/register') {if(users[e])return reply(res,409,{error:'Account already exists.'});const salt=crypto.randomBytes(16).toString('hex');users[e]={salt,hash:hash(p,salt),state:null};await persist();}
else if(!users[e]?.hash||!crypto.timingSafeEqual(Buffer.from(users[e].hash,'hex'),Buffer.from(hash(p,users[e].salt),'hex')))return reply(res,401,{error:'Incorrect email or password.'});
const t=crypto.randomBytes(32).toString('hex');sessions.set(t,e);res.setHeader('Set-Cookie',`session=${t}; HttpOnly; SameSite=Strict; Path=/${process.env.NODE_ENV==='production'?'; Secure':''}`);return reply(res,200,{email:e,state:users[e].state});}
if(url.pathname==='/api/logout'){sessions.delete(token);res.setHeader('Set-Cookie','session=; Max-Age=0; Path=/');return reply(res,200,{});}
if(!email)return reply(res,401,{error:'Sign in to sync your settlement.'});
if(url.pathname==='/api/save'&&req.method==='POST'){users[email].state=body.state;await persist();return reply(res,200,{saved:true});}
if(url.pathname==='/api/me')return reply(res,200,{email,state:users[email].state});return reply(res,404,{error:'Not found'});
}
const file=url.pathname==='/'?'index.html':url.pathname.slice(1);const resolved=path.resolve(root,'public',file);if(!resolved.startsWith(path.resolve(root,'public')+path.sep))return reply(res,403,{});
res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':'text/html');res.end(await fs.readFile(resolved));
}catch(e){reply(res,e.code==='ENOENT'?404:500,{error:'Request could not be completed.'});}}).listen(process.env.PORT||3000,'0.0.0.0',()=>console.log('Gravehold listening on port '+(process.env.PORT||3000)));

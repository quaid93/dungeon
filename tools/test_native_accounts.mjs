import {spawn} from 'node:child_process';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const data=await mkdtemp(join(tmpdir(),'gravehold-accounts-'));
const server=spawn(process.execPath,['server.js'],{env:{...process.env,PORT:'3197',DATA_DIR:data},stdio:['ignore','pipe','inherit']});
try {
 await new Promise((resolve,reject)=>{server.stdout.once('data',resolve);server.once('error',reject);server.once('exit',code=>reject(new Error(`Server exited ${code}`)));});
 const child=spawn(process.env.GODOT_BIN||'godot',['--headless','--path','godot','--script','res://tests/test_accounts.gd','--','http://127.0.0.1:3197'],{stdio:'inherit'});
 process.exitCode=await new Promise((resolve,reject)=>{child.once('exit',resolve);child.once('error',reject);});
} finally { server.kill(); await new Promise(resolve=>server.once('exit',resolve)); await rm(data,{recursive:true,force:true}); }
